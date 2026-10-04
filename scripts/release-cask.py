#!/usr/bin/env python3
"""Prepare a GitHub Contents API update while preserving the existing cask."""
import base64
import json
import re
import sys
from pathlib import Path


def prepare(metadata, version, sha):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Invalid release version")
    if not re.fullmatch(r"[0-9a-f]{64}", sha):
        raise ValueError("Invalid SHA-256")
    content = base64.b64decode(metadata["content"]).decode("utf-8")
    if 'cask "battery-pie" do' not in content:
        raise ValueError("Unexpected cask")
    expected_url = 'https://github.com/jasperyue/BatteryPie/releases/download/v#{version}/BatteryPie-#{version}-arm64.dmg'
    if expected_url not in content:
        raise ValueError("Unexpected release URL; review the cask before publishing")
    current = re.findall(r'^  version "([^"]+)"$', content, re.M)
    if len(current) != 1 or not re.fullmatch(r"\d+\.\d+\.\d+", current[0]):
        raise ValueError("Expected one numeric cask version")
    if tuple(map(int, current[0].split("."))) > tuple(map(int, version.split("."))):
        raise ValueError("Refusing to downgrade the tap")
    updated, count = re.subn(r'^  version "[^"]+"$', f'  version "{version}"', content, flags=re.M)
    updated, hashes = re.subn(r'^  sha256 "[0-9a-f]{64}"$', f'  sha256 "{sha}"', updated, flags=re.M)
    if count != 1 or hashes != 1:
        raise ValueError("Expected one version and one SHA-256")
    if current[0] == version and updated != content:
        raise ValueError("Same version has a different checksum; publish a new version")
    payload = None if updated == content else {
        "message": f"Update Battery Pie to {version}",
        "content": base64.b64encode(updated.encode("utf-8")).decode("ascii"),
        "sha": metadata["sha"],
    }
    return updated, payload


if __name__ == "__main__":
    metadata_file, version, sha, cask_file, payload_file = sys.argv[1:]
    updated, payload = prepare(json.loads(Path(metadata_file).read_text()), version, sha)
    Path(cask_file).write_text(updated)
    if payload is not None:
        Path(payload_file).write_text(json.dumps(payload))
