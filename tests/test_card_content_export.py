"""The production export gate must reject an app without card updates."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from inspect_app_update_export import card_content_checks


class CardContentExportTests(unittest.TestCase):
    def fixture(self):
        members = {
            "project.binary": b"autoload/CardContentBootstrap\0*res://scripts/card_content/ContentBootstrap.gd\0"
                              b"autoload/CardContentUpdater\0*res://scripts/card_content/ContentUpdater.gd\0",
            "data/card_content/trust.json": (ROOT / "data/card_content/trust.json").read_bytes(),
            "data/card_content/runtime_classes.json": (ROOT / "data/card_content/runtime_classes.json").read_bytes(),
            ".godot/global_script_class_cache.cfg": b'list=[{ "class": &"CardData", "path": "res://scripts/data/CardData.gd" }]',
            "scripts/data/CardData.gdc": b"compiled-script",
        }
        for name in ("ContentBootstrap", "ContentUpdater", "ContentManifest", "ContentStore", "ContentPaths", "ContentUpdatePanel"):
            members["scripts/card_content/" + name + ".gdc"] = b"compiled-script"
        return members

    def test_complete_compiled_client_contains_content_runtime(self):
        self.assertTrue(all(card_content_checks(self.fixture()).values()))

    def test_old_app_update_only_client_is_rejected(self):
        members = {"project.binary": b"*res://scripts/update/AppUpdater.gd"}
        checks = card_content_checks(members)
        self.assertFalse(checks["card_content_bootstrap_autoload"])
        self.assertFalse(checks["card_content_updater_autoload"])
        self.assertFalse(all(checks.values()))

    def test_missing_runtime_member_cannot_pass_production_gate(self):
        for name in self.fixture():
            with self.subTest(missing=name):
                members = self.fixture()
                del members[name]
                self.assertFalse(all(card_content_checks(members).values()))

    def test_resources_without_autoload_registration_are_not_enough(self):
        for script in ("ContentBootstrap", "ContentUpdater"):
            with self.subTest(script=script):
                members = self.fixture()
                members["project.binary"] = members["project.binary"].replace(script.encode(), b"Missing")
                self.assertFalse(all(card_content_checks(members).values()))

    def test_invalid_or_empty_trust_and_class_inventory_are_rejected(self):
        for path in ("data/card_content/trust.json", "data/card_content/runtime_classes.json"):
            for body in (b"{}", b"[]", b"broken json"):
                with self.subTest(path=path, body=body):
                    members = self.fixture()
                    members[path] = body
                    self.assertFalse(all(card_content_checks(members).values()))

    def test_exported_class_index_cannot_point_to_excluded_test_copies(self):
        members = self.fixture()
        members[".godot/global_script_class_cache.cfg"] = (
            b'list=[{ "class": &"CardData", "path": "res://artifacts/card_content/probe/source/scripts/data/CardData.gd" }]')
        self.assertFalse(card_content_checks(members)["card_content_class_index_closed"])

    def test_card_acceptance_artifacts_are_hidden_from_parent_godot_import(self):
        self.assertTrue((ROOT / "artifacts/.gdignore").is_file(),
                        "Copied class_name scripts must not replace production global classes")

    def test_godot_may_keep_excluded_test_classes_in_its_exported_index(self):
        members = self.fixture()
        members[".godot/global_script_class_cache.cfg"] += b'\n{"path": "res://tests/test_example.gd"}'
        self.assertTrue(card_content_checks(members)["card_content_class_index_closed"])

    def test_packaging_lab_script_too_does_not_make_its_global_class_safe(self):
        members = self.fixture()
        members[".godot/global_script_class_cache.cfg"] += b'\n{"path": "res://artifacts/Copy.gd"}'
        members["artifacts/Copy.gdc"] = b"compiled-copy"
        self.assertFalse(card_content_checks(members)["card_content_class_index_closed"])


if __name__ == "__main__":
    unittest.main()
