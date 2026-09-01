from __future__ import annotations

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "tools" / "run_ptcgdap_windows_os_isolation_acceptance.ps1"


class AuthorStrategyWindowsOsIsolationToolTests(unittest.TestCase):
    def test_harness_is_admin_only_exact_program_scoped_and_restores_host_state(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        lowered = text.lower()
        self.assertIn("WindowsPrincipal", text)
        self.assertIn("Administrator", text)
        self.assertIn("New-NetFirewallRule", text)
        self.assertIn("Remove-NetFirewallRule", text)
        self.assertIn("-Direction Outbound", text)
        self.assertIn("-Direction Inbound", text)
        self.assertIn("-Program $executablePath", text)
        self.assertIn("finally", text)
        self.assertIn("auditpol.exe", text)
        self.assertIn("/backup", text)
        self.assertIn("/restore", text)
        self.assertNotIn("netsh advfirewall reset", lowered)
        self.assertNotIn("set-netfirewallprofile", lowered)
        self.assertNotIn("disable-netadapter", lowered)
        self.assertNotIn("stop-service", lowered)

    def test_harness_audits_attempts_and_children_with_os_event_sources(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        for event_id in (4688, 5154, 5155, 5156, 5157, 5158, 5159):
            self.assertIn(str(event_id), text)
        self.assertIn("windows_filtering_platform_security_events_5154_5159_v1", text)
        self.assertIn("windows_security_process_creation_4688_v1", text)
        self.assertIn("positive control", text.lower())
        self.assertIn("networkPositiveControlPort", text)
        self.assertIn("$_.source_port -eq [string]$networkPositiveControlPort", text)
        self.assertIn("$_.destination_port -eq [string]$networkPositiveControlPort", text)
        self.assertIn("target_process_ids", text)
        self.assertIn("socket_attempts", text)
        self.assertIn("dns_attempts", text)
        self.assertIn("http_attempts", text)
        self.assertIn("external_process_attempts", text)
        self.assertIn("child_process_ids", text)

    def test_harness_runs_three_real_ui_matches_and_builds_closed_formal_inputs(self) -> None:
        text = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("run_ptcgdap_windows_ui_match.ps1", text)
        self.assertIn("run_ptcgdap_author_strategy_rollback_drill.ps1", text)
        self.assertIn("$index -le 3", text)
        self.assertIn("author_strategy_windows_network_audit_v1", text)
        self.assertIn("author_strategy_windows_process_audit_v1", text)
        self.assertIn("author_strategy_windows_full_match_audit_v1", text)
        self.assertIn("author_strategy_windows_rollback_audit_v1", text)
        self.assertIn("author_strategy_device_measurement_input_v1", text)
        self.assertIn("build_author_strategy_device_report.py", text)
        self.assertIn('$signatureScope -ne "production_release"', text)
        self.assertIn("decision_samples_minimum", text)
        self.assertIn("Refusing to overwrite", text)


if __name__ == "__main__":
    unittest.main()
