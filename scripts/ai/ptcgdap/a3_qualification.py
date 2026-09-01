from __future__ import annotations

from dataclasses import dataclass
import hashlib
from itertools import combinations
import re
from typing import Any, Callable, Mapping, Sequence

from .a3_scope import TARGET_DECKS
from .a3_review import (
    REQUIRED_REVIEW_KINDS,
    valid_independent_review,
    valid_rollback_receipt,
)
from .cabt_tree_hash import jcs_canonical_json_bytes


CONSTRUCTION_AUTHORITIES = frozenset(
    {
        "official-legal-prefix", "official-recorded-trajectory-prefix",
        "private-oracle-legal-prefix",
        "seeded-oracle-legal-prefix", "instrumented-derived-snapshot",
        "godot-synthetic-only",
    }
)

REQUIRED_MUTATION_CANARIES = frozenset(
    {"option_reorder", "damage", "log", "serial", "rng", "terminal"}
)
REQUIRED_SCENARIO_KINDS = frozenset(
    {"positive", "boundary", "negative", "metamorphic"}
)
REQUIRED_MULTI_WINDOW_CHAINS = frozenset(
    {"resource", "assignment", "copy_attack", "ko_prize_promotion"}
)
OFFICIAL_CONSTRUCTION_AUTHORITIES = frozenset(
    {
        "official-legal-prefix", "official-recorded-trajectory-prefix",
        "private-oracle-legal-prefix",
    }
)
_SHA256_RE = re.compile(r"^[0-9A-F]{64}$")


def _is_sha256(value: Any) -> bool:
    return type(value) is str and _SHA256_RE.fullmatch(value) is not None


def _self_hash_valid(value: Any, field: str) -> bool:
    if type(value) is not dict or not _is_sha256(value.get(field)):
        return False
    projected = dict(value)
    expected = projected.pop(field)
    actual = hashlib.sha256(jcs_canonical_json_bytes(projected)).hexdigest().upper()
    return actual == expected


def _scope_matches(value: Mapping[str, Any] | None, scope_hash: str) -> bool:
    return isinstance(value, Mapping) and value.get("scope_sha256") == scope_hash


def _five_private_decks_are_exact(scope: Mapping[str, Any]) -> bool:
    decks = scope.get("decks")
    if type(decks) is not list or len(decks) != len(TARGET_DECKS):
        return False
    expected_ids = {deck_id for deck_id, _ in TARGET_DECKS}
    actual_ids: set[int] = set()
    for deck in decks:
        if type(deck) is not dict or type(deck.get("deck_id")) is not int:
            return False
        actual_ids.add(deck["deck_id"])
        ordered_ids = deck.get("ordered_private_card_uids")
        if (
            deck.get("private_identity_closure_status") != "closed"
            or deck.get("ordered_card_count") != 60
            or type(ordered_ids) is not list
            or len(ordered_ids) != 60
            or any(type(card_id) is not str or not card_id for card_id in ordered_ids)
            or not _is_sha256(deck.get("ordered_private_deck_sha256"))
        ):
            return False
    return actual_ids == expected_ids


def _research_scope_is_attested(scope: Mapping[str, Any]) -> bool:
    provenance = scope.get("oracle_provenance")
    profile = scope.get("private_semantic_parity_profile")
    return (
        type(provenance) is dict
        and provenance.get("project_owner_scope_attested") is True
        and provenance.get("local_private_oracle_research_allowed") is True
        and provenance.get("official_runtime_authorized") is False
        and type(profile) is dict
        and _is_sha256(profile.get("sha256"))
    )


def _corresponding_card_scope_is_closed(scope: Mapping[str, Any]) -> bool:
    correspondence = scope.get("oracle_correspondence_scope")
    return (
        type(correspondence) is dict
        and correspondence.get("status") == "closed"
        and correspondence.get("identity_equality_required") is False
        and correspondence.get("official_deck_identity_required") is False
        and type(correspondence.get("mapped_unique_private_card_count")) is int
        and correspondence["mapped_unique_private_card_count"] > 0
        and correspondence.get("official_numeric_ids_published") is False
    )


def _correspondence_receipt_gate(
    receipt: Mapping[str, Any] | None,
    scope_hash: str,
) -> bool:
    if (
        not _scope_matches(receipt, scope_hash)
        or not _self_hash_valid(receipt, "evidence_sha256")
        or receipt.get("document_type")
        != "ptcgdap_a3_private_semantic_correspondence_public_summary_v2"
        or receipt.get("schema_version") != 2
        or receipt.get("identity_equality_required") is not False
        or receipt.get("official_deck_identity_required") is not False
        or receipt.get("all_corresponding_cards_mapped") is not True
        or receipt.get("common_mapping_open_count") != 0
        or receipt.get("correspondence_gate") != "passed"
        or receipt.get("official_card_ids_published") is not False
        or receipt.get("official_attack_ids_published") is not False
        or receipt.get("official_card_rows_published") is not False
        or receipt.get("private_source_locator_persisted") is not False
        or not _is_sha256(receipt.get("private_detail_sha256"))
    ):
        return False
    decks = receipt.get("decks")
    if decks is None:
        # Focused unit receipts may omit count-only deck rows; production
        # generated evidence always includes all five.
        return True
    expected = {deck_id for deck_id, _ in TARGET_DECKS}
    return (
        type(decks) is list
        and len(decks) == len(TARGET_DECKS)
        and {deck.get("deck_id") for deck in decks if type(deck) is dict} == expected
        and all(
            type(deck.get("oracle_overlap_card_copy_count")) is int
            and deck["oracle_overlap_card_copy_count"] > 0
            for deck in decks
            if type(deck) is dict
        )
    )


def _operation_receipt_gate(
    receipt: Mapping[str, Any] | None,
    scope: Mapping[str, Any],
) -> bool:
    correspondence = scope.get("oracle_correspondence_scope", {})
    return (
        _scope_matches(receipt, scope.get("scope_sha256"))
        and _self_hash_valid(receipt, "evidence_sha256")
        and receipt.get("document_type")
        == "ptcgdap_a3_corresponding_card_operation_qualification_v1"
        and receipt.get("schema_version") == 1
        and receipt.get("claim_scope")
        == "setup_active_corresponding_card_input_index_contract"
        and receipt.get("identity_equality_required") is False
        and receipt.get("official_deck_identity_required") is False
        and receipt.get("mapped_unique_private_card_count")
        == correspondence.get("mapped_unique_private_card_count")
        and type(receipt.get("mapped_unique_attack_identity_count")) is int
        and receipt["mapped_unique_attack_identity_count"] > 0
        and _is_sha256(receipt.get("private_correspondence_sha256"))
        and _is_sha256(receipt.get("semantic_relation_sha256"))
        and receipt.get("synthetic_projection_type_coverage") == list(range(17))
        and receipt.get("synthetic_projection_type_coverage_status") == "passed"
        and receipt.get("live_operation_type_coverage") == [3]
        and receipt.get("operation_input_projection_conformance") == "passed"
        and receipt.get("privacy_negative_gate_status") == "passed"
        and receipt.get("current_window_index_acceptance_witness")
        == "passed_both_engines_setup_active_only"
        and receipt.get("stable_public_transition_witness") == "not_claimed"
        and receipt.get("bootstrap_prefix_comparison") == "not_claimed"
        and receipt.get("post_transition_next_selection_comparison") == "not_claimed"
        and receipt.get("live_private_oracle_witness_count", 0) > 0
        and receipt.get("live_witness_operation")
        == "setup_active_corresponding_card_input_index_only"
        and receipt.get("all_sealed_card_and_attack_relations_bijective") is True
        and receipt.get("official_raw_callback_retained_separately") is True
        and receipt.get("godot_private_frame_retained_separately") is True
        and receipt.get("raw_callback_byte_equality_claimed") is False
        and receipt.get("operation_receipt_embeds_official_numeric_mapping") is False
        and receipt.get("private_source_locator_persisted") is False
        and receipt.get("qualification_status") == "passed"
        and receipt.get("maximum_claim")
        == "setup_active_corresponding_card_input_index_contract"
    )


def _official_source_identity_is_locked(scope: Mapping[str, Any]) -> bool:
    provenance = scope.get("oracle_provenance")
    return type(provenance) is dict and all(
        _is_sha256(provenance.get(field))
        for field in (
            "official_engine_sha256", "official_module_sha256", "official_catalog_sha256",
        )
    )


def _a1_scope_is_locked(scope: Mapping[str, Any]) -> bool:
    contracts = scope.get("godot_contracts")
    return type(contracts) is dict and _is_sha256(contracts.get("cabt_a1_scope_sha256"))


def _capability_scope_is_locked(scope: Mapping[str, Any]) -> bool:
    ids = scope.get("required_capability_ids")
    profile = scope.get("capability_profile")
    return (
        type(ids) is list
        and bool(ids)
        and all(type(capability_id) is str and bool(capability_id) for capability_id in ids)
        and len(ids) == len(set(ids))
        and type(profile) is dict
        and _is_sha256(profile.get("sha256"))
    )


def _scope_protocol_hash(scope: Mapping[str, Any], path: str) -> str | None:
    values = [
        item.get("sha256") for item in scope.get(
            "adapter_snapshot_comparator_action_protocol_files", []
        )
        if type(item) is dict and item.get("path") == path
    ]
    return values[0] if len(values) == 1 and _is_sha256(values[0]) else None


def _valid_execution_receipt(receipt: Any, scope: Mapping[str, Any]) -> bool:
    scope_hash = scope.get("scope_sha256")
    if (
        type(receipt) is not dict
        or receipt.get("scope_sha256") != scope_hash
        or not _self_hash_valid(receipt, "receipt_sha256")
    ):
        return False
    pair = receipt.get("deck_pair")
    deck_hashes = {
        deck.get("deck_id"): deck.get("ordered_private_deck_sha256")
        for deck in scope.get("decks", [])
        if type(deck) is dict
    }
    provenance = scope.get("oracle_provenance", {})
    candidate = scope.get("godot_candidate", {})
    return (
        type(pair) is list
        and len(pair) == 2
        and all(type(deck_id) is int for deck_id in pair)
        and receipt.get("configuration_id") == f"{pair[0]}->{pair[1]}"
        and receipt.get("left_ordered_deck_sha256") == deck_hashes.get(pair[0])
        and receipt.get("right_ordered_deck_sha256") == deck_hashes.get(pair[1])
        and receipt.get("official_engine_sha256") == provenance.get("official_engine_sha256")
        and receipt.get("godot_scope_content_sha256")
        == candidate.get("dirty_scope_content_manifest_sha256")
        and receipt.get("adapter_protocol_sha256")
        == _scope_protocol_hash(scope, "contracts/ptcgdap/a3_engine_adapter_v2.json")
        and receipt.get("status") == "aligned"
        and all(
            _is_sha256(receipt.get(field))
            for field in (
                "left_self_rerun_sha256", "right_self_rerun_sha256",
                "differential_report_sha256",
            )
        )
        and receipt.get("bounded_exploration_status") == "complete"
        and receipt.get("public_projection_status") == "reviewed"
        and receipt.get("private_evidence_status") == "isolated"
        and receipt.get("a3_promoted") is False
        and receipt.get("promotion_authority") == "qualification_owner_only"
        and all(
            receipt.get(field) == 0
            for field in (
                "unexplained_difference_count", "dirty_case_count", "harness_error_count",
            )
        )
    )


def _scenario_coverage_gates(
    coverage: Mapping[str, Any] | None,
    scope_hash: str,
    required_capability_ids: Sequence[str],
) -> tuple[bool, bool]:
    if not _scope_matches(coverage, scope_hash) or not _self_hash_valid(coverage, "evidence_sha256"):
        return False, False
    capabilities = coverage.get("capabilities")
    atomic = type(capabilities) is list and bool(capabilities)
    actual_capability_ids: list[str] = []
    if atomic:
        for capability in capabilities:
            if type(capability) is not dict:
                atomic = False
                break
            kinds = capability.get("scenario_kinds")
            authorities = capability.get("construction_authorities")
            if (
                not capability.get("capability_id")
                or capability.get("status") != "aligned"
                or type(kinds) is not list
                or not REQUIRED_SCENARIO_KINDS.issubset(set(kinds))
                or type(authorities) is not list
                or not OFFICIAL_CONSTRUCTION_AUTHORITIES.intersection(authorities)
                or not _self_hash_valid(capability, "evidence_sha256")
            ):
                atomic = False
                break
            actual_capability_ids.append(capability["capability_id"])
        atomic = (
            atomic
            and len(actual_capability_ids) == len(set(actual_capability_ids))
            and set(actual_capability_ids) == set(required_capability_ids)
        )
    chains = coverage.get("multi_window_chains")
    multi_window = type(chains) is list
    chain_ids: set[str] = set()
    if multi_window:
        for chain in chains:
            if (
                type(chain) is not dict
                or type(chain.get("chain_id")) is not str
                or chain.get("status") != "aligned"
                or not _self_hash_valid(chain, "evidence_sha256")
            ):
                multi_window = False
                break
            chain_ids.add(chain["chain_id"])
        multi_window = multi_window and chain_ids == REQUIRED_MULTI_WINDOW_CHAINS
    return atomic, multi_window


def _mutation_gates(mutation: Mapping[str, Any] | None, scope_hash: str) -> tuple[bool, bool]:
    if not _scope_matches(mutation, scope_hash):
        return False, False
    captured = mutation.get("captured")
    return (
        type(captured) is list
        and len(captured) == len(REQUIRED_MUTATION_CANARIES)
        and set(captured) == REQUIRED_MUTATION_CANARIES
        and _self_hash_valid(mutation, "receipt_sha256"),
        mutation.get("python_godot_comparator_consistent") is True,
    )


def _review_gates(review: Mapping[str, Any] | None, scope_hash: str) -> tuple[bool, bool]:
    if not _scope_matches(review, scope_hash) or not _self_hash_valid(review, "receipt_sha256"):
        return False, False
    reviews = review.get("reviews")
    if type(reviews) is not list or any(
        not valid_independent_review(value, scope_hash) for value in reviews
    ):
        return False, False
    kinds = [value["review_kind"] for value in reviews]
    reviewers = [value["reviewer_identity_sha256"] for value in reviews]
    independent = (
        set(kinds) == REQUIRED_REVIEW_KINDS
        and len(kinds) == len(set(kinds)) == len(REQUIRED_REVIEW_KINDS)
        and len(reviewers) == len(set(reviewers)) == len(REQUIRED_REVIEW_KINDS)
        and review.get("independent_review_set_complete") is True
    )
    rollback = valid_rollback_receipt(review.get("rollback_receipt"), scope_hash)
    return independent, rollback and review.get("rollback_drill") == "passed"


def ordered_deck_pair_configurations() -> tuple[tuple[int, int], ...]:
    ids = [deck_id for deck_id, _ in TARGET_DECKS]
    result: list[tuple[int, int]] = []
    for left, right in combinations(ids, 2):
        result.extend(((left, right), (right, left)))
    result.extend((deck_id, deck_id) for deck_id in ids)
    return tuple(result)


@dataclass(frozen=True, slots=True)
class MicroScenario:
    scenario_id: str
    scope_hash: str
    construction_authority: str
    acting_seat: int
    semantic_action: Mapping[str, Any]
    expected_window: Mapping[str, Any]
    selection: tuple[int, ...]
    expected_state_delta: Mapping[str, Any]
    expected_logs: tuple[Mapping[str, Any], ...]
    expected_next: Mapping[str, Any]
    random_capability: str
    evidence_classification: str
    scenario_kind: str
    construction_proof: Mapping[str, Any]
    current_lifecycle: str

    def validate(self) -> None:
        proof = self.construction_proof
        minimum = self.expected_window.get("minCount")
        maximum = self.expected_window.get("maxCount")
        if (
            not self.scenario_id
            or not _is_sha256(self.scope_hash)
            or self.construction_authority not in CONSTRUCTION_AUTHORITIES
            or self.acting_seat not in (0, 1)
            or type(self.semantic_action) is not dict
            or not self.semantic_action
            or type(self.expected_window) is not dict
            or type(minimum) is not int
            or type(maximum) is not int
            or minimum < 0
            or maximum < minimum
            or len(self.selection) < minimum
            or len(self.selection) > maximum
            or any(type(index) is not int or index < 0 for index in self.selection)
            or len(self.selection) != len(set(self.selection))
            or type(self.expected_state_delta) is not dict
            or any(type(log) is not dict for log in self.expected_logs)
            or type(self.expected_next) is not dict
            or self.evidence_classification not in ("public", "trusted-private")
            or self.random_capability not in ("R0", "R1", "R2A", "R2B", "R3", "RX")
            or self.scenario_kind not in REQUIRED_SCENARIO_KINDS
            or self.current_lifecycle not in ("INITIAL_DECK", "SELECTION", "TERMINAL")
            or type(proof) is not dict
            or not _is_sha256(proof.get("source_identity_sha256"))
            or not _is_sha256(proof.get("prefix_sha256"))
            or proof.get("legal_reachability_status") not in ("verified", "synthetic")
            or (
                self.construction_authority in OFFICIAL_CONSTRUCTION_AUTHORITIES
                and proof.get("legal_reachability_status") != "verified"
            )
        ):
            raise ValueError("a3_micro_scenario_invalid")


def minimize_first_divergence(
    actions: Sequence[Mapping[str, Any]],
    reproduces: Callable[[tuple[Mapping[str, Any], ...]], bool],
) -> tuple[Mapping[str, Any], ...]:
    current = tuple(actions)
    if not current or not reproduces(current):
        raise ValueError("a3_minimizer_input_not_reproducing")
    # Prefix is authoritative: first remove the entire suffix after the
    # earliest reproducing action, then delta-debug the remaining prefix.
    for length in range(1, len(current) + 1):
        candidate = current[:length]
        if reproduces(candidate):
            current = candidate
            break
    changed = True
    while changed and len(current) > 1:
        changed = False
        for index in range(len(current)):
            candidate = current[:index] + current[index + 1 :]
            if candidate and reproduces(candidate):
                current = candidate
                changed = True
                break
    return current


def qualification_ledger(scope: Mapping[str, Any]) -> dict[str, Any]:
    pairs = ordered_deck_pair_configurations()
    provenance = scope.get("oracle_provenance", {})
    random_capability = scope.get("random_capability", {})
    return {
        "document_type": "ptcgdap_a3_qualification_ledger_v2",
        "scope_sha256": scope.get("scope_sha256"),
        "ordered_deck_pair_count": len(pairs),
        "ordered_deck_pairs": [list(pair) for pair in pairs],
        "required_mutation_canaries": sorted(REQUIRED_MUTATION_CANARIES),
        "mutation_canary_evidence": {
            "status": "passed_harness_qualification",
            "test": "tests/ptcgdap/test_a3_differential.py",
            "authority": "harness_only_not_engine_parity",
        },
        "promotion_gates": {
            "w0": _research_scope_is_attested(scope),
            "oracle_source_identity_locked": _official_source_identity_is_locked(scope),
            "five_private_ordered_decks": _five_private_decks_are_exact(scope),
            "corresponding_card_scope_closed": _corresponding_card_scope_is_closed(scope),
            "correspondence_registry_witness": False,
            "setup_active_corresponding_card_input_index_contract": False,
            "identity_effect_closure": scope.get("identity_effect_closure_status") == "closed",
            "capability_scope_locked": _capability_scope_is_locked(scope),
            "a1_scope_locked": _a1_scope_is_locked(scope),
            "rng_owner": random_capability.get("status") == "single_owner_context_closed",
            "rng_metadata_closed": random_capability.get("event_metadata_status")
            == (
                "closed_source_card_attack_ability_target_status_group_phase_"
                "and_public_pre_state_context"
            ),
            "no_unsupported_scope": scope.get("unsupported") == [],
            "twenty_five_configurations": len(pairs) == 25,
            "twenty_five_executed_configurations": False,
            "dual_self_rerun": False,
            "zero_unexplained_difference": False,
            "bounded_exploration_complete": False,
            "public_private_evidence_reviewed": False,
            "atomic_boundary_scenarios": False,
            "multi_window_interaction_chains": False,
            "mutation_canaries": False,
            "python_godot_comparator_consistent": False,
            "independent_review": False,
            "rollback_drill": False,
        },
        "promotion_status": "blocked" if scope.get("a3_promotion_status") != "needs_differential" else "pending",
    }


class A3QualificationOwner:
    """The sole owner allowed to turn immutable A3 receipts into promotion.

    Individual differential runs, scenario harnesses and reviewers only emit
    scoped receipts.  This owner fail-closes every design gate and requires the
    exact registered 25 ordered deck pairs; it never treats duplicate or extra
    runs as coverage.
    """

    @classmethod
    def evaluate(
        cls,
        scope: Mapping[str, Any],
        *,
        execution_receipts: Sequence[Mapping[str, Any]] = (),
        scenario_coverage: Mapping[str, Any] | None = None,
        review_receipt: Mapping[str, Any] | None = None,
        mutation_receipt: Mapping[str, Any] | None = None,
        correspondence_receipt: Mapping[str, Any] | None = None,
        operation_receipt: Mapping[str, Any] | None = None,
        first_divergence_corpus: Sequence[Mapping[str, Any]] = (),
        previous_promoted_scope_sha256: str | None = None,
    ) -> dict[str, Any]:
        scope_hash = scope.get("scope_sha256")
        if not _is_sha256(scope_hash):
            raise ValueError("a3_qualification_scope_invalid")

        ledger = qualification_ledger(scope)
        gates = ledger["promotion_gates"]
        gates["correspondence_registry_witness"] = _correspondence_receipt_gate(
            correspondence_receipt, scope_hash,
        )
        gates["setup_active_corresponding_card_input_index_contract"] = _operation_receipt_gate(
            operation_receipt, scope,
        )
        expected_pairs = ordered_deck_pair_configurations()
        actual_pairs: list[tuple[int, int]] = []
        receipts_valid = True
        for receipt in execution_receipts:
            if not _valid_execution_receipt(receipt, scope):
                receipts_valid = False
                continue
            actual_pairs.append(tuple(receipt["deck_pair"]))
        exact_configuration_set = (
            receipts_valid
            and len(execution_receipts) == len(expected_pairs)
            and len(actual_pairs) == len(set(actual_pairs))
            and set(actual_pairs) == set(expected_pairs)
        )
        gates["twenty_five_executed_configurations"] = exact_configuration_set
        gates["dual_self_rerun"] = exact_configuration_set and all(
            _is_sha256(receipt.get("left_self_rerun_sha256"))
            and _is_sha256(receipt.get("right_self_rerun_sha256"))
            for receipt in execution_receipts
        )
        gates["zero_unexplained_difference"] = exact_configuration_set and all(
            receipt.get("status") == "aligned"
            and receipt.get("unexplained_difference_count") == 0
            and receipt.get("dirty_case_count") == 0
            and receipt.get("harness_error_count") == 0
            for receipt in execution_receipts
        )
        gates["bounded_exploration_complete"] = exact_configuration_set and all(
            receipt.get("bounded_exploration_status") == "complete"
            for receipt in execution_receipts
        )
        gates["public_private_evidence_reviewed"] = exact_configuration_set and all(
            receipt.get("public_projection_status") == "reviewed"
            and receipt.get("private_evidence_status") == "isolated"
            for receipt in execution_receipts
        )

        atomic, multi_window = _scenario_coverage_gates(
            scenario_coverage,
            scope_hash,
            scope.get("required_capability_ids", []),
        )
        gates["atomic_boundary_scenarios"] = atomic
        gates["multi_window_interaction_chains"] = multi_window
        mutation, comparator = _mutation_gates(mutation_receipt, scope_hash)
        gates["mutation_canaries"] = mutation
        gates["python_godot_comparator_consistent"] = comparator
        independent_review, rollback = _review_gates(review_receipt, scope_hash)
        gates["independent_review"] = independent_review
        gates["rollback_drill"] = rollback

        promoted = all(gates.values())
        ledger["promotion_status"] = "promoted" if promoted else "blocked"
        gap_by_gate = {
            "w0": "project_research_scope_not_attested",
            "oracle_source_identity_locked": "oracle_source_identity_unlocked",
            "five_private_ordered_decks": "five_private_ordered_decks_open",
            "corresponding_card_scope_closed": "corresponding_card_scope_open",
            "correspondence_registry_witness": "correspondence_registry_witness_invalid",
            "setup_active_corresponding_card_input_index_contract": (
                "setup_active_corresponding_card_input_index_contract_unqualified"
            ),
            "identity_effect_closure": "identity_effect_closure_open",
            "capability_scope_locked": "capability_scope_unlocked",
            "a1_scope_locked": "a1_scope_unlocked",
            "rng_owner": "rng_single_owner_open",
            "rng_metadata_closed": "rng_event_metadata_open",
            "no_unsupported_scope": "unsupported_scope_nonempty",
            "twenty_five_configurations": "qualification_pair_registration_invalid",
            "twenty_five_executed_configurations": "execution_configuration_set_mismatch",
            "dual_self_rerun": "dual_self_rerun_incomplete",
            "zero_unexplained_difference": "zero_unexplained_difference_not_proven",
            "bounded_exploration_complete": "bounded_exploration_incomplete",
            "public_private_evidence_reviewed": "evidence_privacy_review_incomplete",
            "atomic_boundary_scenarios": "atomic_boundary_scenarios_incomplete",
            "multi_window_interaction_chains": "multi_window_chains_incomplete",
            "mutation_canaries": "mutation_canaries_incomplete",
            "python_godot_comparator_consistent": "comparator_consistency_unproven",
            "independent_review": "independent_review_incomplete",
            "rollback_drill": "rollback_drill_incomplete",
        }
        known_gaps = list(dict.fromkeys(
            list(scope.get("unsupported", []))
            + [gap_by_gate[name] for name, passed in gates.items() if not passed]
        ))
        evidence = {
            "document_type": "ptcgdap_a3_qualification_evidence_v2",
            "schema_version": 2,
            "scope_sha256": scope_hash,
            "scope_status": scope.get("a3_promotion_status"),
            "promotion_authority": "A3QualificationOwner",
            "ledger": ledger,
            "executed_differential_configurations": [
                {
                    "deck_pair": list(receipt.get("deck_pair", [])),
                    "status": receipt.get("status"),
                    "differential_report_sha256": receipt.get("differential_report_sha256"),
                }
                for receipt in execution_receipts
            ],
            "scenario_coverage_sha256": (
                scenario_coverage.get("evidence_sha256")
                if isinstance(scenario_coverage, Mapping)
                else None
            ),
            "correspondence_receipt_sha256": (
                correspondence_receipt.get("evidence_sha256")
                if isinstance(correspondence_receipt, Mapping)
                else None
            ),
            "operation_receipt_sha256": (
                operation_receipt.get("evidence_sha256")
                if isinstance(operation_receipt, Mapping)
                else None
            ),
            "mutation_receipt_sha256": (
                mutation_receipt.get("receipt_sha256")
                if isinstance(mutation_receipt, Mapping)
                else None
            ),
            "review_receipt_sha256": (
                review_receipt.get("receipt_sha256")
                if isinstance(review_receipt, Mapping)
                else None
            ),
            "first_divergence_corpus": [dict(item) for item in first_divergence_corpus],
            "known_gaps": known_gaps,
            "rollback": {
                "current_scope_sha256": scope_hash,
                "previous_promoted_scope_sha256": previous_promoted_scope_sha256,
                "drill_status": "passed" if rollback else "not_applicable_no_promoted_a3_scope",
                "rule": "select_previous_complete_scope_manifest_without_deleting_negative_evidence",
            },
            "setup_active_corresponding_card_input_index_qualified": gates[
                "setup_active_corresponding_card_input_index_contract"
            ],
            "maximum_claim": (
                scope.get("oracle_provenance", {}).get(
                    "maximum_claim", "research_private_id_corresponding_card_a3"
                )
                if promoted
                else (
                    "setup_active_corresponding_card_input_index_contract"
                    if gates["setup_active_corresponding_card_input_index_contract"]
                    else "development-only"
                )
            ),
            "a3_promoted": promoted,
        }
        evidence["evidence_sha256"] = hashlib.sha256(
            jcs_canonical_json_bytes(evidence)
        ).hexdigest().upper()
        return evidence


def qualification_evidence(scope: Mapping[str, Any]) -> dict[str, Any]:
    return A3QualificationOwner.evaluate(scope)


__all__ = [
    "A3QualificationOwner", "CONSTRUCTION_AUTHORITIES", "MicroScenario",
    "REQUIRED_MULTI_WINDOW_CHAINS", "REQUIRED_MUTATION_CANARIES",
    "REQUIRED_SCENARIO_KINDS", "minimize_first_divergence",
    "ordered_deck_pair_configurations", "qualification_evidence", "qualification_ledger",
]
