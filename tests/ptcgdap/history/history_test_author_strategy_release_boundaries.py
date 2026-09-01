from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AuthorStrategyReleaseBoundaryTests(unittest.TestCase):
    def test_runtime_release_gate_owns_fixed_product_documents(self) -> None:
        path = ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd"
        text = path.read_text(encoding="utf-8")
        self.assertIn('res://contracts/ptcgdap/author_strategy_release_bundle.json', text)
        self.assertIn('res://data/ptcgdap/author_strategy_release_trust_store.json', text)
        self.assertIn('res://data/ptcgdap/author_strategy_device_acceptance_profile.json', text)
        self.assertNotIn("trusted_hash", text)
        self.assertNotIn("accept_any_key", text)
        for forbidden in ("OS.execute", "HTTPClient", "HTTPRequest", "TCPServer", "PacketPeerUDP", "load_resource_pack"):
            self.assertNotIn(forbidden, text)

    def test_package_loaders_reference_the_fixed_release_gate_not_a_caller_trust_input(self) -> None:
        python_text = (ROOT / "scripts/ai/ptcgdap/author_strategy_package.py").read_text(encoding="utf-8")
        godot_text = (ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd").read_text(encoding="utf-8")
        self.assertIn("AuthorStrategyReleaseGate", python_text)
        self.assertIn("AuthorStrategyReleaseGate.gd", godot_text)
        self.assertNotIn("accept_any_key", python_text + godot_text)
        self.assertNotIn("caller_public_key", python_text + godot_text)

    def test_release_presets_explicitly_include_all_ptcgdap_contracts_and_data(self) -> None:
        text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        for preset in ("Windows Desktop", "Android"):
            marker = f'name="{preset}"'
            start = text.index(marker)
            end = text.find("\n[preset.", start + 1)
            block = text[start:] if end < 0 else text[start:end]
            self.assertIn("contracts/ptcgdap/**", block)
            self.assertIn("data/**", block)

    def test_battle_setup_start_gate_remains_closed_during_release_infrastructure_work(self) -> None:
        text = (ROOT / "scenes/battle_setup/BattleSetup.gd").read_text(encoding="utf-8")
        start = text.index("func _author_strategy_start_allowed() -> bool:")
        block = text[start:text.index("\nfunc ", start + 1)]
        self.assertIn("return false", block)

    def test_device_scripts_do_not_depend_on_repository_local_codex_skills(self) -> None:
        for relative in (
            "scripts/tools/export_ptcgdap_device_release.ps1",
            "scripts/tools/run_ptcgdap_device_acceptance.ps1",
            "scripts/tools/run_android_ui_e2e.ps1",
            "tools/ptcgdap/build_author_strategy_device_report.py",
        ):
            text = (ROOT / relative).read_text(encoding="utf-8")
            self.assertNotIn(".codex\\skills", text)
            self.assertNotIn(".codex/skills", text)

    def test_formal_device_report_builder_uses_only_the_fixed_product_profile(self) -> None:
        text = (ROOT / "tools/ptcgdap/build_author_strategy_device_report.py").read_text(encoding="utf-8")
        self.assertIn(
            'PROFILE_RELATIVE = Path("data/ptcgdap/author_strategy_device_acceptance_profile.json")',
            text,
        )
        self.assertNotIn('add_argument("--profile"', text)
        self.assertNotIn("profile_override", text)

    def test_windows_only_export_manifest_does_not_claim_android_scope(self) -> None:
        text = (ROOT / "scripts/tools/export_ptcgdap_device_release.ps1").read_text(encoding="utf-8")
        self.assertIn("release_target_platforms = $exportedPlatforms", text)
        self.assertIn("Android is deferred by D041", text)
        self.assertIn("if (-not $WindowsOnly)", text)

    def test_windows_export_containers_are_canonicalized_before_inspection_and_hashing(self) -> None:
        text = (ROOT / "scripts/tools/export_ptcgdap_device_release.ps1").read_text(encoding="utf-8")
        self.assertIn('tools\\ptcgdap\\canonicalize_godot_export.py', text)
        expected_order = (
            'Invoke-GodotExport -Mode "--export-pack" -Preset "Windows Desktop" -Target $windowsPack',
            'Invoke-CanonicalizeGodotContainer -Kind "zip" -Path $windowsPack',
            '& $PythonExe $inspector $windowsPack --output $windowsInventory',
            'Invoke-GodotExport -Mode "--export-pack" -Preset "Windows Desktop" -Target $windowsPck',
            'Invoke-CanonicalizeGodotContainer -Kind "pck" -Path $windowsPck',
            '& $GodotExe --headless --main-pack $windowsPck',
            'Invoke-GodotExport -Mode "--export-release" -Preset "Windows Desktop" -Target $windowsExe',
            'Invoke-CanonicalizeGodotContainer -Kind "embedded-exe" -Path $windowsExe',
            'Add-OutputRecord -Kind "resource_zip" -Platform "windows" -Path $windowsPack',
        )
        positions = [text.index(marker) for marker in expected_order]
        self.assertEqual(positions, sorted(positions))


if __name__ == "__main__":
    unittest.main()
