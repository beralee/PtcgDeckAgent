from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ENTRY = ROOT / "scripts/tools/run_ptcgdap_windows_offline_entry.ps1"


class WindowsOfflineEntryTests(unittest.TestCase):
    def test_project_owned_windows_entry_exists(self) -> None:
        self.assertTrue(ENTRY.is_file())

    def test_entry_orchestrates_build_install_and_real_ui_launch(self) -> None:
        text = ENTRY.read_text(encoding="utf-8")
        self.assertIn("export_ptcgdap_device_release.ps1", text)
        self.assertIn("-WindowsOnly", text)
        self.assertIn("run_ptcgdap_windows_ui_match.ps1", text)
        self.assertIn("-SkipExport", text)
        self.assertIn("install", text.lower())
        self.assertIn("fresh-user", text)
        self.assertIn("Push-Location -LiteralPath $installRoot", text)
        self.assertIn("real_mouse_input_proven", text)
        self.assertIn("complete_match_finished", text)

    def test_entry_requires_the_device_manifest_closure_in_export_inventory(self) -> None:
        text = ENTRY.read_text(encoding="utf-8")
        for required in (
            "contracts/ptcgdap/device_manifest_v1.schema.json",
            "contracts/ptcgdap/device_manifest_v1_profile.json",
            "contracts/ptcgdap/device_manifest_v1_bundle.json",
            "data/ptcgdap/marnie_windows_device_manifest_v1.json",
            "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gdc",
            "scripts/ai/ptcgdap/runtime/local/DeviceManifest.gd.remap",
        ):
            self.assertIn(required, text)
        self.assertIn("Get-FileHash", text)
        self.assertIn("Refusing to overwrite", text)

    def test_entry_is_non_formal_windows_only_and_has_no_skill_dependency(self) -> None:
        text = ENTRY.read_text(encoding="utf-8")
        self.assertNotIn(".codex\\skills", text)
        self.assertNotIn(".codex/skills", text)
        self.assertIn('os_network_isolation_proven = $false', text)
        self.assertIn('device_profile_approved = $false', text)
        self.assertIn('production_ready = $false', text)
        self.assertIn('a5_claimed = $false', text)
        self.assertIn('android_claimed = $false', text)
        self.assertNotIn("New-NetFirewallRule", text)
        self.assertNotIn("auditpol.exe", text)


if __name__ == "__main__":
    unittest.main()
