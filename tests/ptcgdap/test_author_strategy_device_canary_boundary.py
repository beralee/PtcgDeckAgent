from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class AuthorStrategyDeviceCanaryBoundaryTests(unittest.TestCase):
    def test_canary_is_explicit_production_signed_and_never_ordinary_player_start(self) -> None:
        canary = (ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsDeviceCanaryGate.gd").read_text(encoding="utf-8")
        execution = (ROOT / "scripts/ai/ptcgdap/host/godot/AuthorStrategyWindowsExecutionGate.gd").read_text(encoding="utf-8")
        release = (ROOT / "scripts/ai/ptcgdap/packages/AuthorStrategyReleaseGate.gd").read_text(encoding="utf-8")
        self.assertIn("--ptcgdap-production-device-canary", canary)
        self.assertIn("production_release", canary)
        self.assertIn("execution_trusted", canary)
        self.assertIn("evaluate_device_canary_package", canary)
        self.assertIn("request_match_handle", canary)
        self.assertNotIn("request_ready_match_handle", canary)
        self.assertIn("device_canary_allowed", release)
        self.assertIn("player_start_allowed\": false", release.lower())
        self.assertIn("DeviceCanaryGateScript", execution)
        self.assertIn("return DeviceCanaryGateScript", execution)

    def test_formal_os_lane_selects_canary_but_development_lane_stays_separate(self) -> None:
        ui = (ROOT / "scripts/tools/run_ptcgdap_windows_ui_match.ps1").read_text(encoding="utf-8")
        harness = (ROOT / "scripts/tools/run_ptcgdap_windows_os_isolation_acceptance.ps1").read_text(encoding="utf-8")
        rollback = (ROOT / "scripts/tools/run_ptcgdap_author_strategy_rollback_drill.ps1").read_text(encoding="utf-8")
        entrypoint = (ROOT / "scripts/tools/run_ptcgdap_windows_ui_match.gd").read_text(encoding="utf-8")
        self.assertIn("ProductionDeviceCanary", ui)
        self.assertIn("--ptcgdap-production-device-canary", ui)
        self.assertIn("-ProductionDeviceCanary:(-not $DevelopmentAuditOnly)", harness)
        self.assertIn("ProductionDeviceCanary", rollback)
        self.assertIn("--ptcgdap-production-device-canary", rollback)
        self.assertIn("device_canary", entrypoint)
        self.assertIn("activation_mode_conflict", entrypoint)


if __name__ == "__main__":
    unittest.main()
