from __future__ import annotations

import hashlib
from pathlib import Path
import re
import unittest

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_strict


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "artifacts/ptcgdap/p3_wp6/work_package.json"
MANIFEST = ROOT / "artifacts/ptcgdap/p3_wp6/manifest.json"
PY_OWNER = ROOT / "scripts/ai/ptcgdap/shadow_match_owner_gate.py"
GD_OWNER = ROOT / "scripts/engine/decision/ShadowMatchOwnerGate.gd"
BUNDLE = ROOT / "contracts/ptcgdap/shadow_match_owner_gate_bundle.json"
PROFILE = ROOT / "contracts/ptcgdap/shadow_match_owner_gate_profile.json"
VECTORS = ROOT / "contracts/ptcgdap/shadow_match_owner_gate_conformance_vectors.json"


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class P3Wp6BoundaryTests(unittest.TestCase):
    def test_governance_parent_cursor_and_alignment_are_exact(self) -> None:
        work = load_json_strict(WORK)
        expected_status = "shadow" if MANIFEST.exists() or work["implementation_state"] == "completed" else "planned"
        self.assertEqual(work["status"], expected_status)
        self.assertEqual(work["entry_evidence"]["parent_manifest_raw_sha256"], "53F4B45A44070C47F29E03864AB6536258D8C99EFFB6CA673A45033EFD52CC4D")
        self.assertEqual(work["entry_evidence"]["parent_manifest_canonical_sha256"], "AFE61216187676B481D0E3D4DA4662C004AA212E4D023F5ACE109A417C6E132F")
        self.assertEqual(work["entry_evidence"]["parent_candidate_canonical_sha256"], "8E6F2429E9276F7BB8774C71894454A6EADCF1BA397BAEE575FF7648325D2C1F")
        self.assertEqual(work["alignment_claim"], {"A0":"partial / not claimed","A1":"not evaluated","A2":"not evaluated","A3":"not evaluated","A4":"not evaluated","A5":"not evaluated"})
        self.assertEqual(work["next_permitted_work"]["work_package"], "P3-WP7")

    def test_contract_is_exact_subordinate_owner_gate(self) -> None:
        bundle = load_json_strict(BUNDLE)
        profile = load_json_strict(PROFILE)
        vectors = load_json_strict(VECTORS)
        self.assertEqual(bundle["contract_id"], "ptcgdap-shadow-match-owner-gate-p3-wp6-v1")
        self.assertEqual(bundle["parent_prompt_broker_bundle_canonical_sha256"], "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E")
        self.assertEqual(profile["owner_modes"], ["legacy", "aligned_shadow"])
        self.assertTrue(profile["semantics"]["owner_mode_immutable_during_active_match"])
        self.assertTrue(profile["semantics"]["rollback_applies_to_next_strictly_newer_match_only"])
        self.assertFalse(profile["semantics"]["engine_method_invocation"])
        self.assertGreaterEqual(len(vectors["cases"]), 14)
        for entry in bundle["artifacts"]:
            self.assertEqual(entry["canonical_sha256"], sha(canonical_json_v1_bytes(load_json_strict(ROOT / entry["path"]))))

    def test_parent_contracts_and_source_lock_remain_unchanged(self) -> None:
        anchors = {
            "contracts/ptcgdap/shadow_prompt_broker_bundle.json": "D19EC7B9B77370312C82E0572DFB016B75E3FE9F438B6C1EFFD50E0AB43C551E",
            "contracts/ptcgdap/godot_action_executor_bundle.json": "45952BE629AE98EB6070C77188FD6A2C2A644C4B6A36876193BB745B7CDA4E92",
            "docs/ptcgdap/SOURCE_LOCK.json": "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205",
        }
        for path, expected in anchors.items():
            self.assertEqual(sha(canonical_json_v1_bytes(load_json_strict(ROOT / path))), expected, path)

    def test_runtime_has_only_approved_shadow_dependencies(self) -> None:
        py = PY_OWNER.read_text(encoding="utf-8")
        gd = GD_OWNER.read_text(encoding="utf-8")
        forbidden = [
            "GameStateMachine", "GameState", "BattleScene", "AIOpponent", "DeckStrategy", "HeadlessMatchBridge",
            "_pending_choice", "_dialog_data", "requests", "urllib", "socket", "subprocess", "ptcgabc",
            "FileAccess.open(\"user://", "OS.execute", "HTTPRequest", "RandomNumberGenerator",
        ]
        for token in forbidden:
            self.assertNotIn(token, py, token)
            self.assertNotIn(token, gd, token)
        self.assertNotRegex(py, r"\b(eval|exec)\s*\(")
        self.assertEqual(
            set(re.findall(r'preload\("[^"]*/([^/"]+)"\)', gd)),
            {"CabtJsonTree.gd", "ShadowPromptBroker.gd"},
        )

    def test_no_live_or_project_consumer_exists(self) -> None:
        needles = ["ShadowMatchOwnerGate", "scripts/engine/decision/ShadowMatchOwnerGate.gd"]
        allowed_shadow_consumers = {
            "scripts/ai/ptcgdap/shadow_engine_command_applier.py",
            "scripts/engine/decision/ShadowEngineCommandApplier.gd",
            "scripts/ai/ptcgdap/shadow_whole_match_harness.py",
            "scripts/engine/decision/ShadowWholeMatchHarness.gd",
        }
        offenders = []
        for base in (ROOT / "scripts", ROOT / "scenes"):
            if not base.exists():
                continue
            for path in base.rglob("*"):
                if not path.is_file() or path in {GD_OWNER, PY_OWNER} or path.suffix.lower() not in {".gd", ".py", ".tscn", ".tres"}:
                    continue
                text = path.read_text(encoding="utf-8", errors="ignore")
                relative = path.relative_to(ROOT).as_posix()
                if any(needle in text for needle in needles) and relative not in allowed_shadow_consumers:
                    offenders.append(path.relative_to(ROOT).as_posix())
        project = (ROOT / "project.godot").read_text(encoding="utf-8", errors="ignore")
        self.assertFalse(any(needle in project for needle in needles))
        self.assertEqual(offenders, [])
        self.assertTrue(all((ROOT / path).exists() for path in allowed_shadow_consumers))

    def test_audit_is_private_free_and_nonauthoritative(self) -> None:
        schema_text = (ROOT / "contracts/ptcgdap/shadow_match_owner_gate.schema.json").read_text(encoding="utf-8")
        profile = load_json_strict(PROFILE)
        for key in profile["private_fields_forbidden_from_audit"]:
            self.assertNotIn(f'"{key}"', schema_text)
        self.assertIn('"authoritative"', schema_text)
        self.assertNotIn("private_resolutions", schema_text)


if __name__ == "__main__":
    unittest.main()
