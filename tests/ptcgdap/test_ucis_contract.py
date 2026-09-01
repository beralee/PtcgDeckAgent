from __future__ import annotations

import json
import hashlib
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class UcisContractTests(unittest.TestCase):
    def test_registry_is_source_bound_and_covers_every_official_wire_atom(self) -> None:
        from scripts.ai.ptcgdap.ucis import UcisRegistry

        registry = UcisRegistry.load(ROOT)
        self.assertEqual(registry.contract_generation, 2)
        self.assertEqual(registry.ucis_generation, 1)
        self.assertEqual(set(registry.context_rows), set(range(49)))
        self.assertEqual(set(registry.option_shapes), set(range(17)))
        self.assertEqual(len(registry.primitives), 16)
        self.assertNotIn("CustomInteraction", registry.primitives)
        document = json.loads(
            (ROOT / "contracts/ptcgdap/ucis_registry_v1.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            {row["language"] for row in document["compiler_identities"]},
            {"python", "gdscript"},
        )
        for identity in (
            document["source_generator_identity"],
            document["catalog_compiler_identity"],
            document["developer_sdk_identity"],
            *document["compiler_identities"],
        ):
            path = ROOT / identity["path"]
            self.assertEqual(
                identity["raw_sha256"],
                hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            )

    def test_all_required_domain_primitives_compile_to_registered_wire_atoms(self) -> None:
        from scripts.ai.ptcgdap.ucis import CardEffectSpec, UcisCompiler, UcisRegistry

        registry = UcisRegistry.load(ROOT)
        compiler = UcisCompiler(registry)
        for primitive_name, primitive in registry.primitives.items():
            context_raw = primitive.contexts[0]
            row = registry.context_rows[context_raw]
            spec = CardEffectSpec.from_mapping(
                {
                    "schema_version": 1,
                    "effect_ref": f"test:{primitive_name}",
                    "resolution_kind": "interactive",
                    "program_kind": primitive_name,
                    "capability_ids": [primitive_name],
                    "steps": [
                        {
                            "step_id": "step-1",
                            "primitive": primitive_name,
                            "context_name": row.context_name,
                            "option_type_name": row.option_type_names[0],
                            "source_zone_query": "current_public_frontier",
                            "candidate_predicate": "legal_current_options",
                            "target_predicate": "legal_current_targets",
                            "quantity_encoding": primitive.quantity_encodings[0],
                            "min_rule": "current_min_count",
                            "max_rule": "current_max_count",
                            "remaining_debt_rule": "current_remaining_debt",
                            "public_context_projection": "ucis_public_facts_v1",
                            "private_binding_recipe": "current_option_private_binding",
                            "commit_command_kind": "commit_current_selection",
                            "next_checkpoint_rule": "fresh_reobserve",
                            "unsupported_if": [],
                            "capability_ids": [primitive_name],
                        }
                    ],
                    "chooser_rule": "engine_current_chooser",
                    "visibility_rule": "acting_seat_public_only",
                    "lifecycle_anchor": "current_effect_checkpoint",
                    "continuation_rule": "ordered_steps",
                    "stop_rule": "program_complete",
                    "information_checkpoints": ["fresh_reobserve"],
                    "source_hash": "A" * 64,
                }
            )
            program = compiler.compile_effect(spec)
            self.assertEqual(program.status, "compiled", primitive_name)
            self.assertEqual(program.steps[0].context_raw, context_raw)

    def test_invalid_context_option_pair_and_custom_escape_fail_closed(self) -> None:
        from scripts.ai.ptcgdap.ucis import CardEffectSpec, UcisCompiler, UcisError, UcisRegistry

        registry = UcisRegistry.load(ROOT)
        compiler = UcisCompiler(registry)
        base = {
            "schema_version": 1,
            "effect_ref": "test:invalid",
            "resolution_kind": "interactive",
            "program_kind": "ChooseCardSet",
            "capability_ids": ["ChooseCardSet"],
            "chooser_rule": "engine_current_chooser",
            "visibility_rule": "acting_seat_public_only",
            "lifecycle_anchor": "current_effect_checkpoint",
            "continuation_rule": "ordered_steps",
            "stop_rule": "program_complete",
            "information_checkpoints": ["fresh_reobserve"],
            "source_hash": "B" * 64,
        }
        invalid_step = {
            "step_id": "bad",
            "primitive": "ChooseCardSet",
            "context_name": "SETUP_ACTIVE_POKEMON",
            "option_type_name": "ATTACK",
            "source_zone_query": "current_public_frontier",
            "candidate_predicate": "legal_current_options",
            "target_predicate": "legal_current_targets",
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
        with self.assertRaisesRegex(UcisError, "ucis_context_option_mismatch"):
            compiler.compile_effect(CardEffectSpec.from_mapping({**base, "steps": [invalid_step]}))
        with self.assertRaisesRegex(UcisError, "ucis_unknown_primitive"):
            compiler.compile_effect(
                CardEffectSpec.from_mapping(
                    {
                        **base,
                        "program_kind": "CustomInteraction",
                        "capability_ids": ["CustomInteraction"],
                        "steps": [{**invalid_step, "primitive": "CustomInteraction"}],
                    }
                )
            )

    def test_generated_catalog_closes_all_bundled_cards_and_legacy_author_entrypoints(self) -> None:
        from scripts.ai.ptcgdap.ucis_catalog import build_ucis_catalog, validate_ucis_catalog

        catalog = build_ucis_catalog(ROOT)
        validate_ucis_catalog(catalog)
        closure = catalog["closure"]
        self.assertEqual(closure["total_cards"], 797)
        self.assertEqual(closure["unregistered"], 0)
        self.assertEqual(closure["legacy_author_visible"], 0)
        self.assertEqual(closure["custom_prompt_builder"], 0)
        self.assertEqual(closure["silent_fallback"], 0)
        self.assertEqual(
            closure["compiled"] + closure["automatic"] + closure["unsupported"],
            closure["total_effects"],
        )

    def test_legacy_inventory_and_coverage_denominators_are_closed(self) -> None:
        legacy = json.loads(
            (ROOT / "contracts/ptcgdap/ucis_legacy_inventory_v1.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            legacy["closure"]["ucis_owned_callsite_count"],
            legacy["closure"]["interaction_callsite_count"],
        )
        for key in (
            "legacy_author_visible",
            "legacy_write_entrypoints",
            "dual_authority",
            "custom_prompt_builder",
        ):
            self.assertEqual(legacy["closure"][key], 0)
        self.assertFalse(legacy["shadow_parity"]["dual_commit"])
        self.assertEqual(
            legacy["engine_private_compatibility_translator"]["policy_projection"],
            "forbidden",
        )

        ledger = json.loads(
            (ROOT / "contracts/ptcgdap/ucis_coverage_ledger_v1.json").read_text(
                encoding="utf-8"
            )
        )
        for name, metric in ledger["metrics"].items():
            with self.subTest(metric=name):
                self.assertGreater(metric["denominator"], 0)
                self.assertEqual(metric["numerator"], metric["denominator"])
        self.assertEqual(
            ledger["metrics"]["wire_context_coverage"],
            {"numerator": 49, "denominator": 49, "required": "49/49"},
        )

    def test_runtime_attestation_is_source_exact_and_partitions_every_effect(self) -> None:
        from scripts.ai.ptcgdap.ucis_catalog import build_ucis_catalog

        attestation = json.loads(
            (ROOT / "contracts/ptcgdap/ucis_runtime_attestation_v1.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(attestation["document_type"], "ptcgdap_ucis_runtime_attestation_v1")
        self.assertEqual(attestation["invalid_specs"], [])
        self.assertEqual(attestation["closure"]["total_cards"], 797)
        self.assertEqual(attestation["closure"]["total_effects"], 730)
        self.assertEqual(attestation["closure"]["unregistered"], 0)
        self.assertEqual(attestation["closure"]["silent_fallback"], 0)
        self.assertEqual(
            attestation["closure"]["compiled"]
            + attestation["closure"]["automatic"]
            + attestation["closure"]["unsupported"],
            730,
        )
        unsupported = [row for row in attestation["cards"] if row["status"] == "unsupported"]
        self.assertTrue(all(row["unsupported_reason"] for row in unsupported))
        catalog = build_ucis_catalog(ROOT)
        self.assertEqual(catalog["closure"]["compiled"], attestation["closure"]["compiled"])
        self.assertEqual(catalog["closure"]["automatic"], attestation["closure"]["automatic"])
        self.assertEqual(catalog["closure"]["unsupported"], attestation["closure"]["unsupported"])

    def test_effect_sources_cannot_override_legacy_prompt_entrypoints_or_import_host_authority(self) -> None:
        forbidden_methods = (
            "get_interaction_steps",
            "get_preview_interaction_steps",
            "get_on_play_interaction_steps",
            "get_attack_interaction_steps",
            "get_attack_preview_interaction_steps",
            "get_followup_interaction_steps",
            "get_followup_attack_interaction_steps",
            "get_granted_attack_interaction_steps",
            "get_followup_granted_attack_interaction_steps",
            "get_knockout_interaction_steps",
            "get_end_turn_interaction_steps",
            "get_reactive_interaction_steps",
            "get_trigger_interaction_steps",
        )
        forbidden_authority = (
            "BattleScene",
            "DecisionPort",
            "A3ExternalDecisionPort",
            "AIStepResolver",
            "_pending_choice",
            "window_id",
            "option_index",
            "ActionTicket",
            "cabt_",
        )
        violations: list[str] = []
        for path in sorted((ROOT / "scripts/effects").rglob("*.gd")):
            if path.name == "BaseEffect.gd":
                continue
            source = path.read_text(encoding="utf-8-sig")
            for method in forbidden_methods:
                if re.search(rf"\b{re.escape(method)}\s*\(", source):
                    violations.append(f"{path.relative_to(ROOT)} references {method}")
            for token in forbidden_authority:
                if token in source:
                    violations.append(f"{path.relative_to(ROOT)} contains {token}")
        self.assertEqual(violations, [])

    def test_generated_documents_are_exact_and_bundle_closed(self) -> None:
        from scripts.ai.ptcgdap.ucis_contract import build_ucis_contracts, validate_ucis_contracts
        from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes

        documents = build_ucis_contracts(ROOT)
        validate_ucis_contracts(documents)
        for name, document in documents.items():
            path = ROOT / "contracts/ptcgdap" / name
            self.assertTrue(path.is_file(), name)
            self.assertEqual(path.read_bytes(), canonical_json_v1_bytes(document), name)


if __name__ == "__main__":
    unittest.main()
