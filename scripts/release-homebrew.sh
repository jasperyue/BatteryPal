#!/bin/bash
# Publish the committed version; never replace assets on an existing release.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REPO="jasperyue/BatteryPie"
TAP_REPO="jasperyue/homebrew-tap"
VERSION=$(cat VERSION)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION' >&2; exit 1; }
TAG="v$VERSION"
ASSET="BatteryPie-$VERSION-arm64.dmg"
NOTES="$ROOT/docs/RELEASE-$TAG.md"
RESUME=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --resume) RESUME=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: bash scripts/release-homebrew.sh [--dry-run] [--resume]"
      echo "Uses VERSION, BUILD_NUMBER and docs/RELEASE-v<VERSION>.md."
      echo "--dry-run: print the plan without building or publishing."
      echo "--resume: reuse and verify existing release assets, then finish the tap update."
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done
fail() { echo "Error: $*" >&2; exit 1; }
[[ -f "$NOTES" ]] || fail "Missing release notes: $NOTES"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || fail "Release packaging requires an Apple Silicon Mac."
for tool in gh git python3 ruby shasum hdiutil; do
  command -v "$tool" >/dev/null || fail "Missing command: $tool"
done
COMMIT=$(git rev-parse HEAD)
if $DRY_RUN; then
  echo "Version: $VERSION; source: $COMMIT"
  echo "Build and verify $ASSET; push origin HEAD; publish $REPO/$TAG."
  echo "Verify the uploaded DMG and update $TAP_REPO/Casks/battery-pie.rb."
  echo "No files, GitHub releases or tap contents were changed."
  exit 0
fi
[[ -z "$(git status --porcelain)" ]] || fail "Commit or stash source changes first."
BRANCH=$(git symbolic-ref --short HEAD) || fail "Check out a branch before releasing."
ORIGIN=$(git remote get-url origin)
case "$ORIGIN" in
  https://github.com/jasperyue/BatteryPie.git|https://github.com/jasperyue/BatteryPie|git@github.com:jasperyue/BatteryPie.git) ;;
  *) fail "origin must point to $REPO." ;;
esac
gh auth status >/dev/null 2>&1 || fail "Run gh auth login first."
mkdir -p "$ROOT/.build"
WORK=$(mktemp -d "$ROOT/.build/release.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
trap 'echo "Release stopped. After fixing the error, use --resume if a Release already exists. See docs/RELEASING.md." >&2' ERR
# Fetch tap metadata before publishing so missing permissions/configuration fail early.
gh api "repos/$TAP_REPO/contents/Casks/battery-pie.rb" > "$WORK/cask.json"
gh api "repos/$TAP_REPO" --jq '.permissions.push' > "$WORK/tap-permission"
[[ "$(cat "$WORK/tap-permission")" == true ]] || fail "GitHub account cannot push to $TAP_REPO."
if gh api "repos/$REPO/releases/tags/$TAG" > "$WORK/release.json" 2> "$WORK/release-error"; then
  $RESUME || fail "$TAG already exists. Use --resume to finish it without replacing assets."
  REMOTE_COMMIT=$(gh api "repos/$REPO/commits/$TAG" --jq '.sha')
  [[ "$REMOTE_COMMIT" == "$COMMIT" ]] || fail "$TAG points to a different source commit."
  mkdir "$WORK/download"
  gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --pattern "$ASSET.sha256" --dir "$WORK/download"
else
  # Only a confirmed 404 means a new release; network/auth errors must not create one.
  [[ "$(cat "$WORK/release-error")" == *"HTTP 404"* ]] || { cat "$WORK/release-error" >&2; fail "Cannot check the existing release."; }
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    [[ "$(git rev-parse "$TAG^{commit}")" == "$COMMIT" ]] || fail "Local $TAG points to a different commit."
  fi
  bash "$ROOT/scripts/package-dmg.sh"
  [[ "$(git rev-parse HEAD)" == "$COMMIT" && -z "$(git status --porcelain)" ]] || fail "Source changed during packaging; aborting publish."
  git push origin "HEAD:refs/heads/$BRANCH"
  if ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then git tag "$TAG" "$COMMIT"; fi
  git push origin "refs/tags/$TAG"
  gh release create "$TAG" "$ROOT/dist/$ASSET" "$ROOT/dist/$ASSET.sha256" \
    --repo "$REPO" --verify-tag --draft --title "Battery Pie $VERSION" --notes-file "$NOTES"
  mkdir "$WORK/download"
  gh release download "$TAG" --repo "$REPO" --pattern "$ASSET" --pattern "$ASSET.sha256" --dir "$WORK/download"
fi
# Compare the downloaded bytes to the checksum, not to a freshly rebuilt DMG.
SHA=$(shasum -a 256 "$WORK/download/$ASSET" | awk '{print $1}')
EXPECTED=$(awk 'NR == 1 {print $1}' "$WORK/download/$ASSET.sha256")
[[ "$SHA" == "$EXPECTED" ]] || fail "Uploaded DMG checksum mismatch."
hdiutil verify "$WORK/download/$ASSET"
python3 "$ROOT/scripts/release-cask.py" "$WORK/cask.json" "$VERSION" "$SHA" "$WORK/cask.rb" "$WORK/payload.json"
ruby -c "$WORK/cask.rb"
# Publish only after assets and cask syntax have been verified.
gh release edit "$TAG" --repo "$REPO" --draft=false
if [[ -f "$WORK/payload.json" ]]; then
  gh api --method PUT "repos/$TAP_REPO/contents/Casks/battery-pie.rb" --input "$WORK/payload.json" > "$WORK/tap-result.json"
else
  echo "Tap already matches this release."
fi
echo "Published: https://github.com/$REPO/releases/tag/$TAG"
echo "Users can run: brew update && brew upgrade --cask jasperyue/tap/battery-pie"
echo "If an upload or tap update failed, rerun with --resume; existing assets are reused."
