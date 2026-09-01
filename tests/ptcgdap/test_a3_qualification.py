from __future__ import annotations

import hashlib
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.a3_qualification import (
    A3QualificationOwner,
    MicroScenario,
    minimize_first_divergence,
    ordered_deck_pair_configurations,
    qualification_evidence,
    qualification_ledger,
)
from scripts.ai.ptcgdap.a3_scope import TARGET_DECKS
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]


class A3QualificationTests(unittest.TestCase):
    @staticmethod
    def _seal(value: dict, field: str) -> dict:
        result = dict(value)
        result[field] = hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()
        return result

    @staticmethod
    def _closed_scope() -> dict:
        decks = [{
            "deck_id": deck_id,
            "deck_name": deck_name,
            "ordered_card_count": 60,
            "ordered_private_card_uids": [f"PRIVATE_{deck_id}"] * 60,
            "ordered_private_deck_sha256": f"{ordinal + 1:064X}",
            "private_identity_closure_status": "closed",
            "private_effect_closure_status": "closed",
            "identity_effect_closure_status": "closed",
            "unresolved": [],
        } for ordinal, (deck_id, deck_name) in enumerate(TARGET_DECKS)]
        return {
            "scope_sha256": "A" * 64,
            "a3_promotion_status": "needs_differential",
            "identity_effect_closure_status": "closed",
            "capability_profile": {"sha256": "F" * 64},
            "required_capability_ids": ["fixture.capability"],
            "decks": decks,
            "oracle_provenance": {
                "official_runtime_authorized": False,
                "project_owner_scope_attested": True,
                "local_private_oracle_research_allowed": True,
                "maximum_claim": "research_private_id_corresponding_card_a3",
                "official_engine_sha256": "B" * 64,
                "official_module_sha256": "C" * 64,
                "official_catalog_sha256": "D" * 64,
            },
            "godot_contracts": {"cabt_a1_scope_sha256": "E" * 64},
            "godot_candidate": {"dirty_scope_content_manifest_sha256": "9" * 64},
            "adapter_snapshot_comparator_action_protocol_files": [{
                "path": "contracts/ptcgdap/a3_engine_adapter_v2.json",
                "sha256": "8" * 64,
            }],
            "private_semantic_parity_profile": {"sha256": "7" * 64},
            "oracle_correspondence_scope": {
                "status": "closed",
                "identity_equality_required": False,
                "official_deck_identity_required": False,
                "mapped_unique_private_card_count": 1,
                "official_numeric_ids_published": False,
            },
            "random_capability": {
                "status": "single_owner_context_closed",
                "event_metadata_status": (
                    "closed_source_card_attack_ability_target_status_group_phase_"
                    "and_public_pre_state_context"
                ),
            },
            "unsupported": [],
        }

    def test_exact_25_ordered_pair_configurations_cover_both_seats_and_mirrors(self) -> None:
        pairs = ordered_deck_pair_configurations()
        self.assertEqual(len(pairs), 25)
        self.assertEqual(len(set(pairs)), 25)
        ids = {left for left, _ in pairs}
        self.assertTrue(all((left, right) in pairs and (right, left) in pairs for left in ids for right in ids))

    def test_micro_scenario_requires_authority_and_random_classification(self) -> None:
        values = dict(
            scenario_id="s", scope_hash="A" * 64,
            construction_authority="godot-synthetic-only", acting_seat=0,
            semantic_action={"kind": "fixture"},
            expected_window={"minCount": 1, "maxCount": 1}, selection=(0,),
            expected_state_delta={}, expected_logs=(), expected_next={},
            random_capability="R0", evidence_classification="public",
            scenario_kind="positive",
            construction_proof={
                "source_identity_sha256": "B" * 64,
                "prefix_sha256": "C" * 64,
                "legal_reachability_status": "synthetic",
            },
            current_lifecycle="SELECTION",
        )
        scenario = MicroScenario(**values)
        scenario.validate()
        invalid = MicroScenario(**{**values, "construction_authority": "invented"})
        with self.assertRaisesRegex(ValueError, "a3_micro_scenario_invalid"):
            invalid.validate()

    def test_first_divergence_minimizer_keeps_smallest_reproducing_prefix(self) -> None:
        actions = ({"id": 1}, {"id": 2}, {"id": 3}, {"id": 4})
        minimized = minimize_first_divergence(actions, lambda values: any(value["id"] == 3 for value in values))
        self.assertEqual(minimized, ({"id": 3},))

    def test_current_ledger_is_blocked_without_turning_negative_evidence_green(self) -> None:
        scope = load_json_strict(ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json")
        ledger = qualification_ledger(scope)
        self.assertEqual(ledger["ordered_deck_pair_count"], 25)
        self.assertTrue(ledger["promotion_gates"]["w0"])
        self.assertTrue(ledger["promotion_gates"]["five_private_ordered_decks"])
        self.assertTrue(ledger["promotion_gates"]["corresponding_card_scope_closed"])
        self.assertTrue(ledger["promotion_gates"]["identity_effect_closure"])
        self.assertTrue(ledger["promotion_gates"]["rng_owner"])
        self.assertTrue(ledger["promotion_gates"]["rng_metadata_closed"])
        self.assertFalse(
            ledger["promotion_gates"][
                "setup_active_corresponding_card_input_index_contract"
            ]
        )
        self.assertEqual(ledger["promotion_status"], "pending")

    def test_generated_blocked_evidence_is_exact_and_has_rollback_identity(self) -> None:
        scope = load_json_strict(ROOT / "data/ptcgdap/a3/five_deck_scope_v2.json")
        generated = load_json_strict(ROOT / "evidence/ptcgdap/a3/qualification_v2.json")
        mutation = load_json_strict(ROOT / "evidence/ptcgdap/a3/mutation_receipt_v2.json")
        scenario_coverage = load_json_strict(
            ROOT / "evidence/ptcgdap/a3/scenario_coverage_v2.json"
        )
        review = load_json_strict(ROOT / "evidence/ptcgdap/a3/review_qualification_v2.json")
        correspondence = load_json_strict(
            ROOT / "evidence/ptcgdap/a3/private_semantic_correspondence_summary_v2.json"
        )
        operation = load_json_strict(
            ROOT / "evidence/ptcgdap/a3/corresponding_card_operation_qualification_v1.json"
        )
        self.assertEqual(
            generated,
            A3QualificationOwner.evaluate(
                scope,
                mutation_receipt=mutation,
                scenario_coverage=scenario_coverage,
                review_receipt=review,
                correspondence_receipt=correspondence,
                operation_receipt=operation,
            ),
        )
        self.assertFalse(generated["a3_promoted"])
        self.assertEqual(generated["rollback"]["current_scope_sha256"], scope["scope_sha256"])

    def test_empty_or_duplicate_execution_receipts_cannot_promote(self) -> None:
        scope = self._closed_scope()
        empty = A3QualificationOwner.evaluate(scope)
        self.assertFalse(empty["a3_promoted"])
        self.assertFalse(empty["ledger"]["promotion_gates"]["twenty_five_executed_configurations"])

        pair = ordered_deck_pair_configurations()[0]
        deck_hashes = {
            deck["deck_id"]: deck["ordered_private_deck_sha256"] for deck in scope["decks"]
        }
        receipt = self._seal({
            "scope_sha256": scope["scope_sha256"],
            "configuration_id": f"{pair[0]}->{pair[1]}",
            "deck_pair": list(pair),
            "left_ordered_deck_sha256": deck_hashes[pair[0]],
            "right_ordered_deck_sha256": deck_hashes[pair[1]],
            "official_engine_sha256": scope["oracle_provenance"]["official_engine_sha256"],
            "godot_scope_content_sha256": scope["godot_candidate"]["dirty_scope_content_manifest_sha256"],
            "adapter_protocol_sha256": "8" * 64,
            "status": "aligned",
            "left_self_rerun_sha256": "B" * 64,
            "right_self_rerun_sha256": "C" * 64,
            "differential_report_sha256": "D" * 64,
            "bounded_exploration_status": "complete",
            "public_projection_status": "reviewed",
            "private_evidence_status": "isolated",
            "unexplained_difference_count": 0,
            "dirty_case_count": 0,
            "harness_error_count": 0,
            "a3_promoted": False,
            "promotion_authority": "qualification_owner_only",
        }, "receipt_sha256")
        duplicate = A3QualificationOwner.evaluate(scope, execution_receipts=[receipt, receipt])
        self.assertFalse(duplicate["a3_promoted"])
        self.assertIn("execution_configuration_set_mismatch", duplicate["known_gaps"])

    def test_only_qualification_owner_can_promote_an_exact_complete_ledger(self) -> None:
        scope = self._closed_scope()
        deck_hashes = {
            deck["deck_id"]: deck["ordered_private_deck_sha256"] for deck in scope["decks"]
        }
        receipts = []
        for ordinal, pair in enumerate(ordered_deck_pair_configurations()):
            token = f"{ordinal + 1:064X}"
            receipts.append(self._seal({
                "scope_sha256": scope["scope_sha256"],
                "configuration_id": f"{pair[0]}->{pair[1]}",
                "deck_pair": list(pair),
                "left_ordered_deck_sha256": deck_hashes[pair[0]],
                "right_ordered_deck_sha256": deck_hashes[pair[1]],
                "official_engine_sha256": scope["oracle_provenance"]["official_engine_sha256"],
                "godot_scope_content_sha256": scope["godot_candidate"]["dirty_scope_content_manifest_sha256"],
                "adapter_protocol_sha256": "8" * 64,
                "status": "aligned",
                "left_self_rerun_sha256": token,
                "right_self_rerun_sha256": token,
                "differential_report_sha256": token,
                "bounded_exploration_status": "complete",
                "public_projection_status": "reviewed",
                "private_evidence_status": "isolated",
                "unexplained_difference_count": 0,
                "dirty_case_count": 0,
                "harness_error_count": 0,
                "a3_promoted": False,
                "promotion_authority": "qualification_owner_only",
            }, "receipt_sha256"))
        capability = self._seal({
            "capability_id": "fixture.capability",
            "status": "aligned",
            "scenario_kinds": ["positive", "boundary", "negative", "metamorphic"],
            "construction_authorities": ["private-oracle-legal-prefix"],
        }, "evidence_sha256")
        chains = [self._seal({
            "chain_id": name,
            "status": "aligned",
        }, "evidence_sha256") for name in (
            "resource", "assignment", "copy_attack", "ko_prize_promotion",
        )]
        coverage = {
            "scope_sha256": scope["scope_sha256"],
            "capabilities": [capability],
            "multi_window_chains": chains,
        }
        coverage = self._seal(coverage, "evidence_sha256")
        reviews = []
        for ordinal, kind in enumerate(
            ("ptcg_rules", "differential_architecture", "privacy_projection")
        ):
            reviews.append(self._seal({
                "document_type": "ptcgdap_a3_independent_review_v2",
                "scope_sha256": scope["scope_sha256"],
                "review_kind": kind,
                "reviewer_identity_sha256": f"{ordinal + 10:064X}",
                "independent_from_implementation": True,
                "decision": "approved",
                "blocking_finding_count": 0,
                "reviewed_artifact_sha256s": ["3" * 64],
            }, "review_sha256"))
        rollback_receipt = self._seal({
            "document_type": "ptcgdap_a3_rollback_drill_v2",
            "current_scope_sha256": scope["scope_sha256"],
            "previous_promoted_scope_sha256": "4" * 64,
            "status": "passed",
            "negative_evidence_retained": True,
            "new_scope_not_deleted": True,
        }, "drill_sha256")
        review = self._seal({
            "document_type": "ptcgdap_a3_review_qualification_v2",
            "scope_sha256": scope["scope_sha256"],
            "reviews": reviews,
            "ptcg_rules_review": "approved",
            "differential_architecture_review": "approved",
            "privacy_projection_review": "approved",
            "distinct_reviewer_count": 3,
            "independent_review_set_complete": True,
            "rollback_receipt": rollback_receipt,
            "rollback_drill": "passed",
        }, "receipt_sha256")
        mutation = self._seal({
            "scope_sha256": scope["scope_sha256"],
            "captured": ["option_reorder", "damage", "log", "serial", "rng", "terminal"],
            "python_godot_comparator_consistent": True,
        }, "receipt_sha256")
        correspondence = self._seal({
            "document_type": "ptcgdap_a3_private_semantic_correspondence_public_summary_v2",
            "schema_version": 2,
            "scope_sha256": scope["scope_sha256"],
            "identity_equality_required": False,
            "official_deck_identity_required": False,
            "all_corresponding_cards_mapped": True,
            "common_mapping_open_count": 0,
            "correspondence_gate": "passed",
            "official_card_ids_published": False,
            "official_attack_ids_published": False,
            "official_card_rows_published": False,
            "private_source_locator_persisted": False,
            "private_detail_sha256": "6" * 64,
        }, "evidence_sha256")
        operation = self._seal({
            "document_type": "ptcgdap_a3_corresponding_card_operation_qualification_v1",
            "schema_version": 1,
            "scope_sha256": scope["scope_sha256"],
            "claim_scope": "setup_active_corresponding_card_input_index_contract",
            "identity_equality_required": False,
            "official_deck_identity_required": False,
            "mapped_unique_private_card_count": 1,
            "mapped_unique_attack_identity_count": 1,
            "private_correspondence_sha256": "7" * 64,
            "semantic_relation_sha256": "8" * 64,
            "synthetic_projection_type_coverage": list(range(17)),
            "synthetic_projection_type_coverage_status": "passed",
            "live_operation_type_coverage": [3],
            "operation_input_projection_conformance": "passed",
            "privacy_negative_gate_status": "passed",
            "current_window_index_acceptance_witness": (
                "passed_both_engines_setup_active_only"
            ),
            "stable_public_transition_witness": "not_claimed",
            "bootstrap_prefix_comparison": "not_claimed",
            "post_transition_next_selection_comparison": "not_claimed",
            "live_private_oracle_witness_count": 1,
            "live_witness_operation": "setup_active_corresponding_card_input_index_only",
            "all_sealed_card_and_attack_relations_bijective": True,
            "official_raw_callback_retained_separately": True,
            "godot_private_frame_retained_separately": True,
            "raw_callback_byte_equality_claimed": False,
            "operation_receipt_embeds_official_numeric_mapping": False,
            "legacy_public_contracts_may_contain_official_numeric_ids": True,
            "private_source_locator_persisted": False,
            "qualification_status": "passed",
            "maximum_claim": "setup_active_corresponding_card_input_index_contract",
        }, "evidence_sha256")
        result = A3QualificationOwner.evaluate(
            scope,
            execution_receipts=receipts,
            scenario_coverage=coverage,
            review_receipt=review,
            mutation_receipt=mutation,
            correspondence_receipt=correspondence,
            operation_receipt=operation,
        )
        self.assertTrue(result["a3_promoted"], result["ledger"]["promotion_gates"])
        self.assertEqual(
            result["maximum_claim"], "research_private_id_corresponding_card_a3"
        )
        self.assertTrue(all(result["ledger"]["promotion_gates"].values()))


if __name__ == "__main__":
    unittest.main()
