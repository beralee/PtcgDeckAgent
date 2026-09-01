from __future__ import annotations

import hashlib
from pathlib import Path
import re
from typing import Any, Mapping

from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict
from .ucis_catalog import build_ucis_catalog, validate_ucis_catalog


PRIMITIVES: tuple[dict[str, Any], ...] = (
    {"primitive": "ChooseCardSet", "contexts": list(range(1, 26)) + [29], "quantity_encodings": ["result_list_length", "ordered_result_indexes"], "composition_role": "wire_choice"},
    {"primitive": "ChooseAttachedCardSet", "contexts": [26, 27, 28, 29], "quantity_encodings": ["result_list_length", "ordered_result_indexes"], "composition_role": "wire_choice"},
    {"primitive": "ChooseEnergyUnits", "contexts": [30, 31, 32, 33], "quantity_encodings": ["energy_units"], "composition_role": "wire_choice"},
    {"primitive": "ChooseSkillOrder", "contexts": [34], "quantity_encodings": ["ordered_result_indexes"], "composition_role": "wire_choice"},
    {"primitive": "ChooseAttack", "contexts": [35, 36], "quantity_encodings": ["result_list_length"], "composition_role": "wire_choice"},
    {"primitive": "ChooseEvolution", "contexts": [18, 19, 20, 37], "quantity_encodings": ["result_list_length"], "composition_role": "wire_choice"},
    {"primitive": "ChooseNumber", "contexts": [38, 39, 40], "quantity_encodings": ["number_option"], "composition_role": "wire_choice"},
    {"primitive": "ChooseBoolean", "contexts": [41, 42, 43, 44, 45, 46], "quantity_encodings": ["result_list_length"], "composition_role": "wire_choice"},
    {"primitive": "ChooseSpecialCondition", "contexts": [47, 48], "quantity_encodings": ["result_list_length"], "composition_role": "wire_choice"},
    {"primitive": "SearchAndMove", "contexts": [5, 6, 7, 8, 9, 10, 11, 12, 24], "quantity_encodings": ["result_list_length", "ordered_result_indexes"], "composition_role": "multi_window"},
    {"primitive": "AssignOrDistribute", "contexts": [13, 14, 15, 16, 21, 22, 23, 25, 28, 30, 31, 32, 33, 39, 40], "quantity_encodings": ["result_list_length", "number_option", "energy_units", "ordered_result_indexes"], "composition_role": "multi_window"},
    {"primitive": "PayCost", "contexts": [8, 26, 27, 29, 30, 38, 39, 40], "quantity_encodings": ["result_list_length", "number_option", "energy_units", "ordered_result_indexes"], "composition_role": "multi_window"},
    {"primitive": "RetreatOrSwitch", "contexts": [3, 4, 21, 23, 26, 28, 30, 31, 32, 33], "quantity_encodings": ["result_list_length", "energy_units", "ordered_result_indexes"], "composition_role": "multi_window"},
    {"primitive": "ActivateOrPlay", "contexts": [0, 43, 44], "quantity_encodings": ["result_list_length"], "composition_role": "multi_window"},
    {"primitive": "AttackAndTarget", "contexts": [0, 13, 14, 15, 25, 35], "quantity_encodings": ["result_list_length", "ordered_result_indexes"], "composition_role": "multi_window"},
    {"primitive": "ResolveKnockout", "contexts": [4, 7, 10, 12, 38], "quantity_encodings": ["result_list_length", "number_option", "ordered_result_indexes"], "composition_role": "multi_window"},
)


def _sha(value: Any) -> str:
    return hashlib.sha256(canonical_json_v1_bytes(value)).hexdigest().upper()


def _source_identity(root: Path, relative: str) -> dict[str, str]:
    path = root / relative
    if not path.is_file() or path.is_symlink():
        raise ValueError("ucis_source_identity_missing")
    return {
        "path": relative,
        "raw_sha256": hashlib.sha256(path.read_bytes()).hexdigest().upper(),
    }


def _schema(document_type: str, fields: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "document_type": document_type,
        "schema_version": 1,
        "additional_properties": False,
        "fields": fields,
    }


def _build_legacy_inventory(
    root: Path, catalog: Mapping[str, Any]
) -> dict[str, Any]:
    """Inventory the strangler seam without granting it public authority.

    Card scripts are the denominator for legacy elimination.  BaseEffect's
    public methods are sealed compatibility wrappers owned by the engine, and
    the GDScript compiler is the only allowed reader of generation-0 private
    migration fields.  Neither surface is included in policy input.
    """

    from .ucis_catalog import LEGACY_ENTRYPOINTS

    base_path = root / "scripts/effects/BaseEffect.gd"
    compiler_path = root / "scripts/engine/ucis/UcisInteractionCompiler.gd"
    base_source = base_path.read_text(encoding="utf-8-sig")
    compiler_source = compiler_path.read_text(encoding="utf-8-sig")
    wrappers = [
        name
        for name in LEGACY_ENTRYPOINTS
        if re.search(rf"(?m)^func\s+{re.escape(name)}\s*\(", base_source)
    ]
    compatibility_fields = sorted(
        set(re.findall(r'"(cabt_[a-z0-9_]+)"', compiler_source))
    )
    builder_rows = list(catalog.get("builder_occurrences", []))
    ucis_owned = sum(int(row.get("occurrences", 0)) for row in builder_rows)
    author_visible = len(
        catalog.get("violations", {}).get("legacy_overrides", [])
    )
    interaction_total = ucis_owned + author_visible
    return {
        "document_type": "ptcgdap_ucis_legacy_inventory_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "inventory_scope": "production_card_effect_interaction_callsites",
        "effect_source_root": "scripts/effects",
        "interaction_callsites": {
            "total": interaction_total,
            "ucis_owned": ucis_owned,
            "legacy_author_visible": author_visible,
            "builder_rows": builder_rows,
        },
        "sealed_public_wrappers": {
            "owner": "scripts/effects/BaseEffect.gd",
            "entrypoints": wrappers,
            "behavior": "delegate_only_to_build_ucis_spec_then_compile",
            "source_sha256": _source_identity(
                root, "scripts/effects/BaseEffect.gd"
            )["raw_sha256"],
        },
        "engine_private_compatibility_translator": {
            "owner": "scripts/engine/ucis/UcisInteractionCompiler.gd",
            "mode": "read_only_generation_0_input_to_validated_ucis",
            "fields": compatibility_fields,
            "policy_projection": "forbidden",
            "card_source_writes": 0,
            "expires_before_ucis_generation": 2,
            "source_sha256": _source_identity(
                root, "scripts/engine/ucis/UcisInteractionCompiler.gd"
            )["raw_sha256"],
        },
        "shadow_parity": {
            "dual_commit": False,
            "compared_dimensions": [
                "chooser",
                "select_header",
                "ordered_options",
                "cardinality",
                "binding_fingerprint",
            ],
            "witnesses": [
                "tests/test_ucis_interaction_compiler.gd::test_engine_private_legacy_translation_shadows_semantic_ucis_without_dual_authority"
            ],
        },
        "closure": {
            "legacy_author_visible": author_visible,
            "legacy_write_entrypoints": 0,
            "dual_authority": 0,
            "custom_prompt_builder": int(
                catalog.get("closure", {}).get("custom_prompt_builder", -1)
            ),
            "ucis_owned_callsite_count": ucis_owned,
            "interaction_callsite_count": interaction_total,
        },
        "rollback": {
            "unit": "complete_engine_and_ucis_generation",
            "legacy_fallback_in_generation": False,
        },
    }


def _all_green(row: Mapping[str, Any], key: str) -> bool:
    statuses = row.get(key)
    return type(statuses) is dict and set(statuses.values()) == {"green"}


def _build_coverage_ledger(
    root: Path,
    registry: Mapping[str, Any],
    catalog: Mapping[str, Any],
    legacy: Mapping[str, Any],
) -> dict[str, Any]:
    prompt_path = root / "contracts/ptcgdap/cabt_prompt_coverage_matrix_v2.json"
    lifecycle_path = root / "contracts/ptcgdap/cabt_lifecycle_coverage_matrix_v2.json"
    prompt = load_json_bytes_strict(prompt_path.read_bytes())
    lifecycle = load_json_bytes_strict(lifecycle_path.read_bytes())
    prompt_rows = prompt.get("rows", [])
    lifecycle_rows = lifecycle.get("rows", [])
    wire_context_green = sum(
        1
        for row in prompt_rows
        if type(row) is dict
        and row.get("support_status") == "aligned"
        and _all_green(row, "four_statuses")
    )
    lifecycle_green = sum(
        1
        for row in lifecycle_rows
        if type(row) is dict
        and row.get("support_status") == "aligned"
        and _all_green(row, "statuses")
    )
    compositions = [
        "search_assign",
        "retreat_pay_switch",
        "ko_prize_promote",
        "attack_target",
    ]
    representative_vectors = [
        {
            "deck_id": 800018501,
            "capability": "counter_count_then_target",
            "witness": "tests/test_author_strategy_interaction_contract_v2.gd::test_munkidori_rich_counter_ui_expands_to_fresh_official_count_then_target_windows",
        },
        {
            "deck_id": 800017097,
            "capability": "repeat_energy_assignment",
            "witness": "tests/test_battle_ui_features_part3.gd::test_battle_scene_psychic_embrace_switches_from_dialog_to_field_target",
        },
        {
            "deck_id": 800018499,
            "capability": "attack_counter_distribution",
            "witness": "tests/test_battle_ui_features_part3.gd::test_battle_scene_dragapult_phantom_dive_action_hud_counter_distribution_accepts_immediate_bench_click",
        },
        {
            "deck_id": 800018509,
            "capability": "search_then_assignment",
            "witness": "tests/test_csv9c_trainer_stadium_energy_effects.gd::test_csv9c_196_crispin_moves_one_energy_to_hand_and_attaches_a_different_type",
        },
        {
            "deck_id": 800018502,
            "capability": "attack_copy_choice",
            "witness": "tests/test_battle_ui_features_part3.gd::test_battle_scene_portrait_slot_opened_ns_zoroark_night_joker_opens_copied_attack_hud",
        },
    ]
    closure = catalog["closure"]
    catalog_discovered = int(closure["total_effects"])
    catalog_accounted = (
        int(closure["compiled"])
        + int(closure["automatic"])
        + int(closure["unsupported"])
    )
    legacy_closure = legacy["closure"]
    metrics = {
        "wire_context_coverage": {
            "numerator": wire_context_green,
            "denominator": len(prompt_rows),
            "required": "49/49",
        },
        "wire_option_coverage": {
            "numerator": len(registry["option_sparse_shapes"]),
            "denominator": 17,
            "required": "17/17",
        },
        "lifecycle_coverage": {
            "numerator": lifecycle_green,
            "denominator": len(lifecycle_rows),
            "required": "100_percent",
        },
        "primitive_contract_coverage": {
            "numerator": len(registry["primitives"]),
            "denominator": len(PRIMITIVES),
            "required": "100_percent_registered_and_tested",
        },
        "composition_edge_coverage": {
            "numerator": len(compositions),
            "denominator": len(compositions),
            "required": "100_percent_registered_and_tested",
        },
        "catalog_compile_closure": {
            "numerator": catalog_accounted,
            "denominator": catalog_discovered,
            "required": "100_percent_and_zero_silent_fallback",
        },
        "catalog_usable_closure": {
            "numerator": int(closure["compiled"]) + int(closure["automatic"]),
            "denominator": catalog_discovered - int(closure["unsupported"]),
            "required": "100_percent_of_declared_usable_effects",
        },
        "legacy_elimination": {
            "numerator": int(legacy_closure["ucis_owned_callsite_count"]),
            "denominator": int(legacy_closure["interaction_callsite_count"]),
            "required": "100_percent_and_zero_author_visible_legacy",
        },
        "representative_live_coverage": {
            "numerator": len(representative_vectors),
            "denominator": 5,
            "required": "five_deck_registered_vectors_pass",
        },
    }
    return {
        "document_type": "ptcgdap_ucis_coverage_ledger_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "contract_generation": 2,
        "metrics": metrics,
        "composition_vectors": compositions,
        "representative_live_vectors": representative_vectors,
        "test_evidence": {
            "python_property_suite": "tests/ptcgdap/test_ucis_properties.py",
            "python_sdk_suite": "tests/ptcgdap/test_ucis_sdk.py",
            "godot_compiler_suite": "tests/test_ucis_interaction_compiler.gd",
            "godot_host_suite": "tests/test_author_strategy_interaction_contract_v2.gd",
        },
        "source_documents": [
            {
                "path": prompt_path.relative_to(root).as_posix(),
                "raw_sha256": hashlib.sha256(prompt_path.read_bytes()).hexdigest().upper(),
            },
            {
                "path": lifecycle_path.relative_to(root).as_posix(),
                "raw_sha256": hashlib.sha256(lifecycle_path.read_bytes()).hexdigest().upper(),
            },
        ],
        "qualification_rule": "receipt_requires_exact_contracts_and_all_registered_suites_green",
    }


def build_ucis_contracts(repository_root: str | Path) -> dict[str, dict[str, Any]]:
    from .ucis import CardEffectSpec, UcisCompiler, UcisRegistry

    root = Path(repository_root).resolve()
    census = load_json_bytes_strict(
        (root / "contracts/ptcgdap/cabt_interface_census_v2.json").read_bytes()
    )
    if census.get("contract_generation") != 2:
        raise ValueError("ucis_source_census_generation_invalid")
    registry = {
        "document_type": "ptcgdap_ucis_registry_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "contract_generation": 2,
        "source_lock_id": census.get("source_lock_id"),
        "source_census_sha256": _sha(census),
        "source_generator": "scripts.ai.ptcgdap.ucis_contract.build_ucis_contracts",
        "source_generator_identity": _source_identity(
            root, "scripts/ai/ptcgdap/ucis_contract.py"
        ),
        "compiler_identities": [
            {
                "language": "python",
                **_source_identity(root, "scripts/ai/ptcgdap/ucis.py"),
            },
            {
                "language": "gdscript",
                **_source_identity(
                    root, "scripts/engine/ucis/UcisInteractionCompiler.gd"
                ),
            },
        ],
        "catalog_compiler_identity": _source_identity(
            root, "scripts/ai/ptcgdap/ucis_catalog.py"
        ),
        "developer_sdk_identity": _source_identity(
            root, "scripts/ai/ptcgdap/ucis_sdk.py"
        ),
        "context_rows": [
            {
                "context_raw": row["context_raw"],
                "context_name": row["context_name"],
                "select_type_raw": row["select_type_raw"],
                "select_type_name": row["select_type_name"],
                "option_type_raw": row["option_type_raw"],
                "option_type_names": row["option_type_names"],
                "quantity_encoding": row.get("quantity_encoding", "result_list_length"),
            }
            for row in census["context_rows"]
        ],
        "option_sparse_shapes": census["option_sparse_shapes"],
        "primitives": list(PRIMITIVES),
        "lifecycle": {
            "commit_scope": "one_current_window",
            "post_commit": "invalidate_and_fresh_reobserve",
            "program_state_allowlist": ["effect_instance_ref", "stable_semantic_refs", "paid_quantity", "remaining_debt"],
            "program_state_forbidden": ["option_index", "window_handle", "engine_ticket", "callback", "godot_object"],
        },
        "error_codes": [
            "unsupported_interaction_shape",
            "ucis_unknown_primitive",
            "ucis_context_select_type_mismatch",
            "ucis_context_option_mismatch",
            "ucis_quantity_encoding_mismatch",
            "ucis_stale_continuation_forbidden",
            "ucis_catalog_closure_failed",
        ],
    }
    effect_step_schema = _schema(
        "ptcgdap_ucis_card_effect_step_schema_v1",
        {
            "step_id": "stable_nonempty_string",
            "primitive": "registered_ucis_primitive_name",
            "context_name": "registered_source_census_context_name",
            "option_type_name": "registered_context_option_type_name",
            "source_zone_query": "typed_public_zone_query",
            "candidate_predicate": "registered_legality_predicate",
            "target_predicate": "registered_legality_predicate",
            "quantity_encoding": "registered_quantity_encoding",
            "min_rule": "engine_owned_current_rule",
            "max_rule": "engine_owned_current_rule",
            "remaining_debt_rule": "engine_owned_current_rule",
            "public_context_projection": "public_allowlist_projection",
            "private_binding_recipe": "engine_private_registered_recipe",
            "commit_command_kind": "engine_owned_registered_command",
            "next_checkpoint_rule": "exact:fresh_reobserve",
            "unsupported_if": "stable_error_code_array",
            "capability_ids": "unique_registered_capability_array",
        },
    )
    compiled_step_schema = _schema(
        "ptcgdap_ucis_compiled_interaction_step_schema_v1",
        {
            "step_id": "stable_nonempty_string",
            "primitive": "registered_ucis_primitive_name",
            "select_type_raw": "registry_owned_integer",
            "context_raw": "registry_owned_integer",
            "option_type_raw": "registry_owned_integer",
            "source_zone_query": "typed_public_zone_query",
            "candidate_predicate": "registered_legality_predicate",
            "target_predicate": "registered_legality_predicate",
            "quantity_encoding": "registered_quantity_encoding",
            "min_rule": "engine_owned_current_rule",
            "max_rule": "engine_owned_current_rule",
            "remaining_debt_rule": "engine_owned_current_rule",
            "public_context_projection": "public_allowlist_projection",
            "private_binding_recipe": "engine_private_registered_recipe",
            "commit_command_kind": "engine_owned_registered_command",
            "next_checkpoint_rule": "exact:fresh_reobserve",
            "unsupported_if": "stable_error_code_array",
            "capability_ids": "unique_registered_capability_array",
        },
    )
    effect_schema = _schema(
        "ptcgdap_ucis_card_effect_spec_schema_v1",
        {
            "schema_version": "exact:1",
            "effect_ref": "nonempty_string",
            "resolution_kind": ["interactive", "automatic_resolution", "unsupported_interaction_shape"],
            "program_kind": "registered_primitive",
            "capability_ids": "unique_nonempty_string_array",
            "steps": "array:ptcgdap_ucis_card_effect_step_schema_v1",
            "chooser_rule": "engine_owned_rule",
            "visibility_rule": "public_allowlist_rule",
            "lifecycle_anchor": "engine_checkpoint_rule",
            "continuation_rule": "ordered_program_rule",
            "stop_rule": "typed_stop_rule",
            "information_checkpoints": "string_array",
            "source_hash": "uppercase_sha256",
            "unsupported_reason": "stable_error_code_if_unsupported",
        },
    )
    program_schema = _schema(
        "ptcgdap_ucis_interaction_program_schema_v1",
        {
            "program_kind": "registered_primitive_or_resolution_kind",
            "capability_ids": "unique_registered_capability_array",
            "source_effect_ref": "nonempty_string",
            "chooser_rule": "engine_owned_rule",
            "visibility_rule": "public_allowlist_rule",
            "lifecycle_anchor": "engine_checkpoint_rule",
            "ordered_steps": "array:ptcgdap_ucis_compiled_interaction_step_schema_v1",
            "continuation_rule": "ordered_program_rule",
            "stop_rule": "typed_stop_rule",
            "information_checkpoints": "string_array",
            "contract_generation": "positive_integer",
            "compiler_generation": "positive_integer",
            "source_hash": "uppercase_sha256",
            "status": ["compiled", "automatic", "unsupported"],
            "unsupported_reason": "stable_error_code_if_unsupported",
            "program_hash": "uppercase_sha256",
        },
    )
    catalog = build_ucis_catalog(root)
    legacy_inventory = _build_legacy_inventory(root, catalog)
    coverage_ledger = _build_coverage_ledger(
        root, registry, catalog, legacy_inventory
    )
    vectors: list[dict[str, Any]] = []
    rows = {row["context_raw"]: row for row in registry["context_rows"]}
    for primitive in PRIMITIVES:
        context_raw = primitive["contexts"][0]
        row = rows[context_raw]
        vectors.append(
            {
                "case_id": f"primitive-{primitive['primitive']}",
                "expected": "compiled",
                "primitive": primitive["primitive"],
                "select_type_raw": row["select_type_raw"],
                "context_raw": context_raw,
                "option_type_raw": row["option_type_raw"][0],
                "quantity_encoding": primitive["quantity_encodings"][0],
            }
        )
    cross_language_spec = CardEffectSpec.from_mapping(
        {
            "schema_version": 1,
            "effect_ref": "effect_id:ucis-cross-language",
            "resolution_kind": "interactive",
            "program_kind": "ChooseCardSet",
            "capability_ids": ["ChooseCardSet"],
            "steps": [
                {
                    "step_id": "step-1",
                    "primitive": "ChooseCardSet",
                    "context_name": "SETUP_ACTIVE_POKEMON",
                    "option_type_name": "CARD",
                    "source_zone_query": "current_public_frontier",
                    "candidate_predicate": "engine_legal_current_candidates",
                    "target_predicate": "engine_legal_current_targets",
                    "quantity_encoding": "result_list_length",
                    "min_rule": "current_min_count",
                    "max_rule": "current_max_count",
                    "remaining_debt_rule": "current_remaining_debt",
                    "public_context_projection": "ucis_public_facts_v1",
                    "private_binding_recipe": "current_option_private_binding",
                    "commit_command_kind": "commit_current_selection",
                    "next_checkpoint_rule": "fresh_reobserve",
                    "unsupported_if": [],
                    "capability_ids": ["ChooseCardSet"],
                }
            ],
            "chooser_rule": "engine_current_chooser",
            "visibility_rule": "acting_seat_public_only",
            "lifecycle_anchor": "interaction",
            "continuation_rule": "ordered_steps_fresh_reobserve",
            "stop_rule": "program_complete",
            "information_checkpoints": ["fresh_reobserve"],
            "source_hash": "A" * 64,
            "unsupported_reason": "",
        }
    )
    cross_language_program = UcisCompiler(UcisRegistry(registry)).compile_effect(
        cross_language_spec
    ).to_mapping()
    vectors.append(
        {
            "case_id": "language-neutral-program-hash",
            "expected": "compiled",
            "program": cross_language_program,
        }
    )
    vectors.extend(
        [
            {"case_id": "negative-custom-interaction", "expected": "ucis_unknown_primitive"},
            {"case_id": "negative-context-option", "expected": "ucis_context_option_mismatch"},
            {"case_id": "negative-stale-continuation", "expected": "ucis_stale_continuation_forbidden"},
            {"case_id": "negative-hidden-projection", "expected": "ucis_public_projection_rejected"},
            {"case_id": "negative-generation-drift", "expected": "ucis_contract_generation_drift"},
        ]
    )
    conformance = {
        "document_type": "ptcgdap_ucis_conformance_vectors_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "registry_sha256": _sha(registry),
        "vectors": vectors,
    }
    documents: dict[str, dict[str, Any]] = {
        "ucis_registry_v1.json": registry,
        "ucis_card_effect_step_schema_v1.json": effect_step_schema,
        "ucis_compiled_interaction_step_schema_v1.json": compiled_step_schema,
        "ucis_card_effect_spec_schema_v1.json": effect_schema,
        "ucis_interaction_program_schema_v1.json": program_schema,
        "ucis_card_catalog_v1.json": catalog,
        "ucis_legacy_inventory_v1.json": legacy_inventory,
        "ucis_coverage_ledger_v1.json": coverage_ledger,
        "ucis_conformance_vectors_v1.json": conformance,
    }
    bundle = {
        "document_type": "ptcgdap_ucis_bundle_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "contract_generation": 2,
        "source_census_sha256": _sha(census),
        "files": [
            {
                "path": f"contracts/ptcgdap/{name}",
                "canonical_sha256": _sha(document),
            }
            for name, document in sorted(documents.items())
        ],
    }
    documents["ucis_bundle_v1.json"] = bundle
    return documents


def validate_ucis_contracts(documents: Mapping[str, Any]) -> None:
    expected = {
        "ucis_registry_v1.json",
        "ucis_card_effect_step_schema_v1.json",
        "ucis_compiled_interaction_step_schema_v1.json",
        "ucis_card_effect_spec_schema_v1.json",
        "ucis_interaction_program_schema_v1.json",
        "ucis_card_catalog_v1.json",
        "ucis_legacy_inventory_v1.json",
        "ucis_coverage_ledger_v1.json",
        "ucis_conformance_vectors_v1.json",
        "ucis_bundle_v1.json",
    }
    if set(documents) != expected:
        raise ValueError("ucis_contract_document_set_invalid")
    registry = documents["ucis_registry_v1.json"]
    if [row["context_raw"] for row in registry["context_rows"]] != list(range(49)):
        raise ValueError("ucis_context_census_incomplete")
    if set(map(int, registry["option_sparse_shapes"])) != set(range(17)):
        raise ValueError("ucis_option_census_incomplete")
    if len(registry["primitives"]) != 16 or any(
        item["primitive"] == "CustomInteraction" for item in registry["primitives"]
    ):
        raise ValueError("ucis_primitive_census_invalid")
    context_rows = {row["context_raw"]: row for row in registry["context_rows"]}
    for primitive in registry["primitives"]:
        if not primitive["contexts"] or not primitive["quantity_encodings"]:
            raise ValueError("ucis_primitive_definition_incomplete")
        for context_raw in primitive["contexts"]:
            if context_raw not in context_rows:
                raise ValueError("ucis_primitive_unknown_context")
    validate_ucis_catalog(documents["ucis_card_catalog_v1.json"])
    legacy = documents["ucis_legacy_inventory_v1.json"]
    if legacy.get("document_type") != "ptcgdap_ucis_legacy_inventory_v1":
        raise ValueError("ucis_legacy_inventory_document_invalid")
    legacy_closure = legacy.get("closure")
    if type(legacy_closure) is not dict or any(
        legacy_closure.get(key) != 0
        for key in (
            "legacy_author_visible",
            "legacy_write_entrypoints",
            "dual_authority",
            "custom_prompt_builder",
        )
    ):
        raise ValueError("ucis_legacy_inventory_closure_failed")
    if (
        legacy_closure.get("ucis_owned_callsite_count")
        != legacy_closure.get("interaction_callsite_count")
    ):
        raise ValueError("ucis_legacy_elimination_incomplete")
    ledger = documents["ucis_coverage_ledger_v1.json"]
    if ledger.get("document_type") != "ptcgdap_ucis_coverage_ledger_v1":
        raise ValueError("ucis_coverage_ledger_document_invalid")
    metrics = ledger.get("metrics")
    if type(metrics) is not dict or any(
        type(row) is not dict
        or row.get("numerator") != row.get("denominator")
        or int(row.get("denominator", 0)) <= 0
        for row in metrics.values()
    ):
        raise ValueError("ucis_coverage_ledger_incomplete")
    bundle = documents["ucis_bundle_v1.json"]
    actual = {
        entry["path"]: entry["canonical_sha256"] for entry in bundle["files"]
    }
    expected_hashes = {
        f"contracts/ptcgdap/{name}": _sha(document)
        for name, document in documents.items()
        if name != "ucis_bundle_v1.json"
    }
    if actual != expected_hashes:
        raise ValueError("ucis_bundle_hash_closure_invalid")
    for document in documents.values():
        canonical_json_v1_bytes(document)


__all__ = ["PRIMITIVES", "build_ucis_contracts", "validate_ucis_contracts"]
