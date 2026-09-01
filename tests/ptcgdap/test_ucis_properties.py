from __future__ import annotations

from copy import deepcopy
import random
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


def _step(
    registry,
    primitive_name: str,
    *,
    step_id: str = "step-1",
    context_raw: int | None = None,
    quantity_encoding: str | None = None,
) -> dict:
    primitive = registry.primitives[primitive_name]
    selected_context = primitive.contexts[0] if context_raw is None else context_raw
    row = registry.context_rows[selected_context]
    return {
        "step_id": step_id,
        "primitive": primitive_name,
        "context_name": row.context_name,
        "option_type_name": row.option_type_names[0],
        "source_zone_query": "current_public_frontier",
        "candidate_predicate": "legal_current_options",
        "target_predicate": "legal_current_targets",
        "quantity_encoding": quantity_encoding or primitive.quantity_encodings[0],
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


def _effect(registry, steps: list[dict], *, effect_ref: str = "test:property") -> dict:
    capabilities = list(dict.fromkeys(step["primitive"] for step in steps))
    return {
        "schema_version": 1,
        "effect_ref": effect_ref,
        "resolution_kind": "interactive",
        "program_kind": steps[0]["primitive"],
        "capability_ids": capabilities,
        "steps": steps,
        "chooser_rule": "engine_current_chooser",
        "visibility_rule": "acting_seat_public_only",
        "lifecycle_anchor": "current_effect_checkpoint",
        "continuation_rule": "ordered_steps",
        "stop_rule": "program_complete",
        "information_checkpoints": ["fresh_reobserve"],
        "source_hash": "A" * 64,
    }


class UcisPropertyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        from scripts.ai.ptcgdap.ucis import UcisCompiler, UcisRegistry

        cls.registry = UcisRegistry.load(ROOT)
        cls.compiler = UcisCompiler(cls.registry)

    def _compile(self, raw: dict):
        from scripts.ai.ptcgdap.ucis import CardEffectSpec

        return self.compiler.compile_effect(CardEffectSpec.from_mapping(raw))

    def test_every_registered_primitive_context_option_quantity_combination_is_deterministic(self) -> None:
        combinations: list[tuple[str, int, str]] = []
        for primitive_name, primitive in self.registry.primitives.items():
            for context_raw in primitive.contexts:
                for quantity in primitive.quantity_encodings:
                    combinations.append((primitive_name, context_raw, quantity))
        random.Random(0x55434953).shuffle(combinations)

        for primitive_name, context_raw, quantity in combinations:
            raw = _effect(
                self.registry,
                [
                    _step(
                        self.registry,
                        primitive_name,
                        context_raw=context_raw,
                        quantity_encoding=quantity,
                    )
                ],
                effect_ref=f"property:{primitive_name}:{context_raw}:{quantity}",
            )
            first = self._compile(raw)
            reordered = {key: deepcopy(raw[key]) for key in reversed(tuple(raw))}
            reordered["steps"] = [
                {key: value for key, value in reversed(tuple(raw["steps"][0].items()))}
            ]
            second = self._compile(reordered)
            row = self.registry.context_rows[context_raw]
            self.assertEqual(first, second)
            self.assertEqual(first.steps[0].select_type_raw, row.select_type_raw)
            self.assertEqual(first.steps[0].context_raw, context_raw)
            self.assertIn(first.steps[0].option_type_raw, row.option_types)

    def test_invalid_and_mutated_specs_fail_closed_with_stable_errors(self) -> None:
        from scripts.ai.ptcgdap.ucis import CardEffectSpec, UcisError

        valid = _effect(self.registry, [_step(self.registry, "ChooseCardSet")])
        mutations = (
            (lambda raw: raw["steps"][0].__setitem__("context_name", "UNKNOWN"), "ucis_unknown_context"),
            (lambda raw: raw["steps"][0].__setitem__("option_type_name", "ATTACK"), "ucis_context_option_mismatch"),
            (lambda raw: raw["steps"][0].__setitem__("quantity_encoding", "private_count"), "ucis_quantity_encoding_mismatch"),
            (lambda raw: raw["steps"][0].__setitem__("next_checkpoint_rule", "reuse_old_window"), "ucis_stale_continuation_forbidden"),
            (lambda raw: raw["steps"][0].__setitem__("capability_ids", ["PayCost"]), "ucis_step_capability_not_declared"),
            (lambda raw: raw["steps"].append(deepcopy(raw["steps"][0])), "ucis_duplicate_step_id"),
            (lambda raw: raw.__setitem__("source_hash", "a" * 64), "ucis_invalid_source_hash"),
            (lambda raw: raw.__setitem__("private_state", True), "ucis_effect_spec_fields_invalid"),
            (
                lambda raw: (
                    raw.__setitem__("program_kind", "CustomInteraction"),
                    raw.__setitem__("capability_ids", ["CustomInteraction"]),
                    raw["steps"][0].__setitem__("primitive", "CustomInteraction"),
                    raw["steps"][0].__setitem__("capability_ids", ["CustomInteraction"]),
                ),
                "ucis_unknown_primitive",
            ),
        )
        for mutate, error in mutations:
            raw = deepcopy(valid)
            mutate(raw)
            with self.subTest(error=error), self.assertRaisesRegex(UcisError, f"^{error}$"):
                self._compile(raw)

        raw = deepcopy(valid)
        raw["steps"][0]["option_index"] = 0
        with self.assertRaisesRegex(UcisError, "^ucis_step_spec_fields_invalid$"):
            CardEffectSpec.from_mapping(raw)

    def test_program_lifecycle_reobserves_and_keeps_only_semantic_state(self) -> None:
        from scripts.ai.ptcgdap.ucis import UcisError, begin_program

        raw = _effect(
            self.registry,
            [
                _step(self.registry, "SearchAndMove", step_id="search"),
                _step(self.registry, "AssignOrDistribute", step_id="assign"),
            ],
        )
        instance = begin_program(self._compile(raw), "effect-instance:test")
        state = {
            "observation_generation": 1,
            "public_state_hash": "B" * 64,
            "legality": {
                "ordered_option_fingerprints": ["card:a", "card:b"],
                "min_count": 0,
                "max_count": 2,
                "remain_energy_cost": 3,
            },
        }
        first = instance.next_step(state)
        self.assertEqual(first.ordered_option_fingerprints, ("card:a", "card:b"))
        reordered = deepcopy(state)
        reordered["legality"]["ordered_option_fingerprints"] = ["card:b", "card:a"]
        self.assertEqual(
            instance.next_step(reordered).ordered_option_fingerprints,
            ("card:b", "card:a"),
        )
        self.assertFalse(any("index" in key or "window" in key for key in vars(instance)))

        with self.assertRaisesRegex(UcisError, "^ucis_fresh_reobserve_required$"):
            instance.advance_after_reobserve(
                {"observation_generation": 1, "public_state_hash": "C" * 64}
            )
        instance.advance_after_reobserve(
            {"observation_generation": 2, "public_state_hash": "C" * 64},
            paid=1,
            semantic_refs=("pokemon:bench-1",),
        )
        second_state = deepcopy(state)
        second_state["observation_generation"] = 2
        second_state["public_state_hash"] = "C" * 64
        second = instance.next_step(second_state)
        self.assertEqual(second.step.primitive, "AssignOrDistribute")
        self.assertEqual(instance.semantic_refs, ("pokemon:bench-1",))
        instance.advance_after_reobserve(
            {"observation_generation": 3, "public_state_hash": "D" * 64}
        )
        self.assertEqual(instance.next_step(second_state), "COMPLETE")

        hidden = deepcopy(state)
        hidden["opponent_hand"] = ["secret"]
        with self.assertRaisesRegex(UcisError, "^ucis_public_projection_rejected$"):
            begin_program(self._compile(raw), "effect-instance:hidden").next_step(hidden)

    def test_required_multistep_compositions_compile_without_custom_escape(self) -> None:
        compositions = {
            "search_assign": (
                _step(self.registry, "SearchAndMove", step_id="search", context_raw=24),
                _step(self.registry, "AssignOrDistribute", step_id="assign", context_raw=21),
            ),
            "retreat_pay_switch": (
                _step(self.registry, "RetreatOrSwitch", step_id="retreat", context_raw=3),
                _step(self.registry, "PayCost", step_id="pay", context_raw=26),
                _step(self.registry, "RetreatOrSwitch", step_id="switch", context_raw=3),
            ),
            "ko_prize_promote": (
                _step(self.registry, "ResolveKnockout", step_id="ko", context_raw=38),
                _step(self.registry, "ResolveKnockout", step_id="prize", context_raw=7),
                _step(self.registry, "ResolveKnockout", step_id="promote", context_raw=4),
            ),
            "attack_target": (
                _step(self.registry, "AttackAndTarget", step_id="attack", context_raw=35),
                _step(self.registry, "AttackAndTarget", step_id="target", context_raw=13),
            ),
        }
        for name, steps in compositions.items():
            program = self._compile(_effect(self.registry, list(steps), effect_ref=f"composition:{name}"))
            self.assertEqual(program.status, "compiled")
            self.assertEqual(
                tuple(step.step_id for step in program.steps),
                tuple(step["step_id"] for step in steps),
            )
            self.assertNotIn("CustomInteraction", program.capability_ids)

    def test_metamorphic_context_and_runtime_order_change_only_the_owned_dimension(self) -> None:
        from scripts.ai.ptcgdap.ucis import begin_program

        damage = _effect(
            self.registry,
            [_step(self.registry, "AssignOrDistribute", context_raw=13)],
            effect_ref="metamorphic:counter",
        )
        remove = deepcopy(damage)
        remove["steps"][0]["context_name"] = "REMOVE_DAMAGE_COUNTER"
        first = self._compile(damage)
        second = self._compile(remove)
        self.assertEqual(first.steps[0].primitive, second.steps[0].primitive)
        self.assertEqual(first.steps[0].option_type_raw, second.steps[0].option_type_raw)
        self.assertNotEqual(first.steps[0].context_raw, second.steps[0].context_raw)
        self.assertNotEqual(first.program_hash, second.program_hash)

        instance = begin_program(first, "effect-instance:order")
        base = {
            "observation_generation": 1,
            "public_state_hash": "E" * 64,
            "legality": {
                "ordered_option_fingerprints": ["pokemon:a", "pokemon:b"],
                "min_count": 1,
                "max_count": 1,
            },
        }
        reversed_state = deepcopy(base)
        reversed_state["legality"]["ordered_option_fingerprints"].reverse()
        self.assertEqual(instance.next_step(base).ordered_option_fingerprints, ("pokemon:a", "pokemon:b"))
        self.assertEqual(instance.next_step(reversed_state).ordered_option_fingerprints, ("pokemon:b", "pokemon:a"))
        self.assertEqual(first.program_hash, instance.program.program_hash)

    def test_language_neutral_program_roundtrip_and_hash_mutation_gate(self) -> None:
        from scripts.ai.ptcgdap.ucis import UcisError

        program = self._compile(
            _effect(
                self.registry,
                [
                    _step(self.registry, "SearchAndMove", step_id="search", context_raw=24),
                    _step(self.registry, "AssignOrDistribute", step_id="assign", context_raw=21),
                ],
                effect_ref="roundtrip:program",
            )
        )
        document = program.to_mapping()
        self.assertEqual(self.compiler.validate_program(document), program)
        self.assertEqual(set(document), {
            "source_effect_ref", "program_kind", "capability_ids", "ordered_steps",
            "chooser_rule", "visibility_rule", "lifecycle_anchor", "continuation_rule",
            "stop_rule", "information_checkpoints", "contract_generation",
            "compiler_generation", "source_hash", "status", "unsupported_reason",
            "program_hash",
        })
        mutated = deepcopy(document)
        mutated["ordered_steps"][0]["context_raw"] = 5
        with self.assertRaisesRegex(UcisError, "ucis_program_hash_invalid|ucis_compiled_step_registry_invalid"):
            self.compiler.validate_program(mutated)


if __name__ == "__main__":
    unittest.main()
