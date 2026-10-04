#!/usr/bin/env python3
import base64
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("release_cask", Path(__file__).with_name("release-cask.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

CASK = '''cask "battery-pie" do
  version "1.1.0"
  sha256 "OLD_SHA"
  url "https://github.com/jasperyue/BatteryPie/releases/download/v#{version}/BatteryPie-#{version}-arm64.dmg"
  depends_on macos: :ventura
  app "Battery Pie.app"
end
'''.replace("OLD_SHA", "a" * 64)


class ReleaseCaskTests(unittest.TestCase):
    def prepare(self, content=CASK, version="1.2.0", sha="b" * 64):
        metadata = {"content": base64.b64encode(content.encode()).decode(), "sha": "remote-blob"}
        return module.prepare(metadata, version, sha)

    def test_update_preserves_other_fields_and_remote_sha(self):
        updated, payload = self.prepare()
        self.assertEqual(updated, CASK.replace('version "1.1.0"', 'version "1.2.0"').replace("a" * 64, "b" * 64))
        self.assertEqual(payload["sha"], "remote-blob")
        self.assertEqual(base64.b64decode(payload["content"]).decode(), updated)

    def test_matching_release_is_noop(self):
        _, payload = self.prepare(version="1.1.0", sha="a" * 64)
        self.assertIsNone(payload)

    def test_same_version_cannot_replace_checksum(self):
        with self.assertRaises(ValueError):
            self.prepare(version="1.1.0")

    def test_cannot_downgrade_tap(self):
        with self.assertRaises(ValueError):
            self.prepare(version="1.0.9")

    def test_unexpected_cask_and_invalid_input_fail(self):
        for content, version, sha in [
            (CASK.replace("BatteryPie-#{version}", "Other-#{version}"), "1.2.0", "b" * 64),
            (CASK + '  version "2.0.0"\n', "1.2.0", "b" * 64),
            (CASK, "1.2.0;bad", "b" * 64),
            (CASK, "1.2.0", "bad"),
        ]:
            with self.assertRaises(ValueError):
                self.prepare(content, version, sha)


if __name__ == "__main__":
    unittest.main()
