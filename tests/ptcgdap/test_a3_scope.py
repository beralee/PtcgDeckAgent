from __future__ import annotations

import unittest
from pathlib import Path

from scripts.ai.ptcgdap.a3_scope import TARGET_DECKS, build_five_deck_scope
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "data" / "ptcgdap" / "a3" / "five_deck_scope_v2.json"


class A3ScopeTests(unittest.TestCase):
    def test_generated_scope_is_exact(self) -> None:
        self.assertEqual(load_json_strict(GENERATED), build_five_deck_scope(ROOT))

    def test_all_five_decks_are_accounted_for_without_overclaiming_authority(self) -> None:
        scope = build_five_deck_scope(ROOT)
        self.assertEqual([deck["deck_id"] for deck in scope["decks"]], [deck_id for deck_id, _ in TARGET_DECKS])
        self.assertTrue(all(sum(entry["count"] for entry in deck["entries"]) == 60 for deck in scope["decks"]))
        self.assertTrue(all(len(deck["ordered_private_card_uids"]) == 60 for deck in scope["decks"]))
        self.assertTrue(scope["oracle_provenance"]["project_owner_scope_attested"])
        self.assertTrue(scope["oracle_provenance"]["local_private_oracle_research_allowed"])
        self.assertFalse(scope["oracle_provenance"]["official_runtime_authorized"])
        self.assertEqual(scope["a3_promotion_status"], "needs_differential")
        self.assertNotIn("official_native_parity_execution_without_w0_authorization", scope["unsupported"])
        self.assertNotIn("five_exact_ordered_decks_unavailable_in_locked_official_catalog", scope["unsupported"])
        self.assertEqual(scope["identity_effect_closure_status"], "closed")
        self.assertTrue(all(deck["unresolved"] == [] for deck in scope["decks"]))

    def test_public_scope_uses_private_ids_and_hides_oracle_numeric_ids(self) -> None:
        scope = build_five_deck_scope(ROOT)
        serialized = str(scope)
        self.assertNotIn("ordered_official_card_ids", serialized)
        self.assertNotIn("official_card_id'", serialized)
        self.assertNotIn("ordered_official_attack_ids", serialized)
        self.assertGreater(scope["oracle_correspondence_scope"]["mapped_card_copy_count"], 0)
        self.assertFalse(scope["oracle_correspondence_scope"]["official_numeric_ids_published"])
        profile = load_json_strict(
            ROOT / "contracts/ptcgdap/a3_private_semantic_parity_profile_v1.json"
        )
        self.assertFalse(
            profile["identity_domains"]["official_numeric_identity_equality_required"]
        )

    def test_semantic_rng_call_sites_have_one_owner(self) -> None:
        scope = build_five_deck_scope(ROOT)
        self.assertEqual(scope["random_capability"]["rng_callsite_violations"], [])
        self.assertEqual(
            scope["random_capability"]["event_metadata_status"],
            "closed_source_card_attack_ability_target_status_group_phase_and_public_pre_state_context",
        )
        self.assertTrue(scope["random_capability"]["conditioned_tape_context_bound"])

    def test_scope_pins_candidate_and_differential_protocol_content(self) -> None:
        scope = load_json_strict(GENERATED)
        self.assertEqual(len(scope["godot_candidate"]["dirty_scope_content_manifest_sha256"]), 64)
        paths = {
            item["path"]
            for item in scope["adapter_snapshot_comparator_action_protocol_files"]
        }
        self.assertIn("scripts/ai/ptcgdap/a3_entity_relation.py", paths)
        self.assertIn("scripts/ai/ptcgdap/a3_self_replay.py", paths)
        self.assertIn("scripts/ai/ptcgdap/a3_match_plan.py", paths)
        self.assertIn("contracts/ptcgdap/a3_engine_adapter_v2.json", paths)
        inventory = load_json_strict(ROOT / "evidence/ptcgdap/w0/private_oracle_inventory_v1.json")
        self.assertEqual(
            scope["oracle_provenance"]["official_engine_sha256"],
            inventory["critical_identities"]["official_engine"]["sha256"],
        )
        self.assertTrue(scope["oracle_provenance"]["project_owner_scope_attested"])
        self.assertEqual(scope["random_capability"]["status"], "single_owner_context_closed")
        self.assertTrue(scope["engine_adapter_capability"]["godot_event_driven_jsonline"])
        self.assertEqual(scope["unsupported"], [])
        self.assertIn("same_seed_official_rng", scope["non_claims"])


if __name__ == "__main__":
    unittest.main()
