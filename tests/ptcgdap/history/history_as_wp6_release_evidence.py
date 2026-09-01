from __future__ import annotations

import hashlib
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict
from tests.ptcgdap.dragapult_acceptance_rollback import restore_pre_dragapult_bytes


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "artifacts/ptcgdap/as_wp6/manifest.json"
SUMMARY_PATH = ROOT / "artifacts/ptcgdap/as_wp6/evidence_summary.json"
EXPECTED_MANIFEST_CANONICAL = "40CCDE19DA7D3D76750493E7177EE3E5E8B8320107E590E97DB0F8F753067690"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class AsWp6ReleaseEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = load_json_strict(MANIFEST_PATH)
        cls.summary = load_json_strict(SUMMARY_PATH)

    def test_manifest_binds_evidence_docs_and_implementation(self) -> None:
        self.assertEqual(
            EXPECTED_MANIFEST_CANONICAL,
            sha(canonical_json_v1_bytes(self.manifest)),
        )
        for group in (
            "evidence_files",
            "documentation_hashes",
            "implementation_hashes",
            "validation_hashes",
        ):
            for entry in self.manifest[group]:
                path = ROOT / entry["path"]
                self.assertTrue(path.is_file(), entry["path"])
                value = restore_pre_dragapult_bytes(entry["path"], path.read_bytes())
                self.assertEqual(entry["raw_sha256"], sha(value), entry["path"])
                if "bytes" in entry:
                    self.assertEqual(entry["bytes"], len(value), entry["path"])
                if "canonical_sha256" in entry:
                    self.assertEqual(
                        entry["canonical_sha256"],
                        sha(canonical_json_v1_bytes(load_json_strict(path))),
                        entry["path"],
                    )

    def test_release_and_device_evidence_cannot_authorize_player_start(self) -> None:
        release = self.summary["release_contract"]
        candidate = self.summary["builtin_candidate"]
        emulator = self.summary["android_emulator_development_probe"]
        self.assertEqual("unprovisioned", release["production_trust_status"])
        self.assertEqual("unprovisioned", release["release_approval_status"])
        self.assertEqual("proposed", release["device_profile_status"])
        self.assertEqual("unprovisioned", release["device_canary_approval_status"])
        self.assertEqual(0, release["approved_device_canary_count"])
        self.assertFalse(release["player_start_allowed"])
        self.assertEqual(["windows"], release["release_target_platforms"])
        self.assertEqual(["android"], release["deferred_platforms"])
        self.assertEqual("test_fixture_only", candidate["signature_scope"])
        self.assertFalse(candidate["execution_trusted"])
        self.assertFalse(candidate["cabt_exportable"])
        self.assertEqual("godot_local_card_uid_v1", candidate["card_id_domain"])
        self.assertEqual("ptcgdap.marnie.windows-local", candidate["adapter_id"])
        self.assertEqual(7, candidate["adapter_rule_count"])
        self.assertTrue(candidate["adapter_card_predicates_exact_manifest_members"])
        self.assertTrue(candidate["adapter_official_numeric_card_ids_rejected"])
        self.assertTrue(candidate["config_deck_manifest_raw_sha256_bound"])
        self.assertTrue(candidate["local_uid_shadow_match_host_supported"])
        self.assertEqual("godot_local_card_uid_v1", candidate["local_uid_shadow_match_host_card_id_domain"])
        self.assertFalse(candidate["local_uid_live_execution_supported"])
        self.assertFalse(emulator["physical_device"])
        self.assertFalse(emulator["formal_device_report"])
        self.assertFalse(emulator["full_match_completed"])
        self.assertFalse(emulator["a5_claimed"])
        self.assertEqual("implementation_in_progress_external_approval_required", self.manifest["status"])
        self.assertEqual("partial / not claimed", self.manifest["alignment"]["A0"])
        self.assertEqual("not evaluated", self.manifest["alignment"]["A5"])
        builder = self.summary["formal_device_report_builder"]
        self.assertEqual("proposed", builder["current_profile_status"])
        self.assertTrue(builder["current_repository_invocation_refused_before_output"])
        self.assertFalse(builder["formal_device_report_generated"])
        self.assertFalse(builder["a5_claimed"])
        qualification = self.summary["windows_profile_qualification"]
        self.assertEqual(3, qualification["ordinary_ui_terminal_games"])
        self.assertEqual(173, qualification["decision_samples"])
        self.assertEqual(173, qualification["policy_successes"])
        self.assertEqual(172, qualification["engine_commits"])
        self.assertEqual(0, qualification["failure_counters_total"])
        self.assertEqual(6, qualification["candidate_thresholds_met"])
        self.assertEqual(0, qualification["candidate_thresholds_failed"])
        self.assertFalse(qualification["profile_approval_granted"])
        self.assertFalse(qualification["formal_device_report"])
        self.assertFalse(qualification["os_network_isolation_proven"])
        self.assertFalse(qualification["production_ready"])
        self.assertFalse(qualification["a5_claimed"])
        canary = self.summary["device_canary_contract"]
        self.assertTrue(canary["approval_store_fixed"])
        self.assertFalse(canary["caller_overrides_allowed"])
        self.assertFalse(canary["ordinary_player_start_allowed"])
        self.assertFalse(canary["future_evidence_hashes_required_for_canary"])
        self.assertEqual(0, canary["production_key_count"])
        self.assertEqual(0, canary["approved_device_canary_count"])
        self.assertFalse(canary["positive_production_canary_run"])
        self.assertEqual(22, canary["export_runtime_required_paths"])
        self.assertEqual(22, canary["export_runtime_present_paths"])

    def test_export_evidence_is_exact_and_does_not_overclaim_device_acceptance(self) -> None:
        windows = self.summary["windows_export"]
        provisional = self.summary["windows_provisional_device_probe"]
        android = self.summary["android_export"]
        self.assertTrue(windows["deterministic_repeat_equal"])
        self.assertTrue(windows["runtime_probe_accepted"])
        self.assertFalse(windows["runtime_probe_execution_trusted"])
        self.assertEqual(19, windows["required_path_count"])
        self.assertEqual(19, windows["present_required_path_count"])
        self.assertEqual(["windows"], windows["release_target_platforms"])
        self.assertEqual(["android"], windows["deferred_platforms"])
        self.assertFalse(provisional["formal_device_report"])
        self.assertFalse(provisional["a5_claimed"])
        self.assertEqual("proposed", provisional["profile_approval_status"])
        self.assertEqual(3, len(provisional["cold_start_msec"]))
        self.assertEqual(3, len(provisional["startup_peak_working_set_mib"]))
        self.assertIn("network_blocked", provisional["unmeasured_gates"])
        self.assertIn("complete_match_finished", provisional["unmeasured_gates"])
        probe_path = ROOT / provisional["path"]
        probe = load_json_strict(probe_path)
        schema = load_json_strict(ROOT / "contracts/ptcgdap/author_strategy_release.schema.json")
        Draft202012Validator(schema).validate(probe)
        self.assertEqual(provisional["bytes"], probe_path.stat().st_size)
        self.assertEqual(provisional["raw_sha256"], sha(probe_path.read_bytes()))
        self.assertEqual(provisional["canonical_sha256"], sha(canonical_json_v1_bytes(probe)))
        self.assertEqual(provisional["cold_start_msec"], [sample["elapsed_msec"] for sample in probe["cold_start_probe"]["samples"]])
        self.assertEqual(provisional["startup_peak_working_set_mib"], [sample["peak_working_set_mib"] for sample in probe["cold_start_probe"]["samples"]])
        self.assertEqual(10, android["required_path_count"])
        self.assertEqual(10, android["present_required_path_count"])
        self.assertEqual("debug", android["build_mode"])
        self.assertFalse(android["aligned_author_strategy_path_requires_network"])
        self.assertIn("arm64-v8a", android["native_code"])

    def test_governance_limits_remain_explicit(self) -> None:
        decisions = (ROOT / "docs/ptcgdap/07-decisions-risks-and-open-questions.md").read_text(encoding="utf-8")
        slice_doc = (ROOT / "docs/ptcgdap/06-first-vertical-slice.md").read_text(encoding="utf-8")
        gaps = (ROOT / "artifacts/ptcgdap/as_wp6/known_gaps.md").read_text(encoding="utf-8")
        self.assertIn("accepted（2026-08-11；由 D034–D039 细化并实施）", decisions)
        self.assertIn("resolved: yes — 仅批准 Marnie 作为首个 offline vertical slice", decisions)
        self.assertIn("Q002 已 resolved: yes — 仅批准 Marnie 作为首个 offline vertical slice", slice_doc)
        for fragment in (
            "9 个 ID、34/60 exact bridge",
            "10 个 ID、26/60 未映射",
            "cabt_exportable=false",
            "物理 Android arm64",
            "W0、W2–W7 live/canary",
        ):
            self.assertIn(fragment, gaps)


if __name__ == "__main__":
    unittest.main()
