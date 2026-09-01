from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from scripts.ai.ptcgdap.shadow_match_owner_gate import ShadowMatchOwnerGate
from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from scripts.ai.ptcgdap.shadow_engine_command_applier import (
    EXPECTED_BUNDLE_CANONICAL_SHA256,
    ShadowEngineApplyResult,
    ShadowEngineCommandApplier,
    ShadowExecutedWitness,
)
from tests.ptcgdap.test_godot_action_ticket import ticket_context
from tests.ptcgdap.test_shadow_prompt_broker import open_prompt


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads(
    (ROOT / "contracts/ptcgdap/shadow_engine_command_applier_conformance_vectors.json").read_text(encoding="utf-8")
)
SCHEMA = json.loads(
    (ROOT / "contracts/ptcgdap/shadow_engine_command_applier.schema.json").read_text(encoding="utf-8")
)
EXPECTED_BUNDLE = "7539A9D5120666AEBA1325DD6623F437831A024996BD612F3EC677F78C9F8F4C"


class ReversibleCommand:
    def __init__(
        self,
        name: str,
        *,
        capture_ok: bool = True,
        apply_ok: bool = True,
        restore_ok: bool = True,
        raise_capture: bool = False,
        raise_apply: bool = False,
        raise_restore: bool = False,
    ) -> None:
        self.name = name
        self.value = 0
        self.capture_ok = capture_ok
        self.apply_ok = apply_ok
        self.restore_ok = restore_ok
        self.raise_capture = raise_capture
        self.raise_apply = raise_apply
        self.raise_restore = raise_restore
        self.private_state = "PRIVATE_STATE_SENTINEL"

    def shadow_capture(self):
        if self.raise_capture:
            raise RuntimeError("PRIVATE_STATE_SENTINEL")
        return {"ok": self.capture_ok, "snapshot": {"value": self.value, "private": self.private_state}}

    def shadow_apply(self):
        if self.raise_apply:
            raise RuntimeError("PRIVATE_COMMAND_SENTINEL")
        if not self.apply_ok:
            return False
        self.value += 1
        return True

    def shadow_restore(self, snapshot):
        if self.raise_restore:
            raise RuntimeError("PRIVATE_STATE_SENTINEL")
        if not self.restore_ok:
            return False
        self.value = snapshot["value"]
        return True


class InvalidCommand:
    pass


def committed_fixture(
    *,
    first: ReversibleCommand | None = None,
    second: ReversibleCommand | None = None,
    duplicate: bool = False,
    invalid: bool = False,
    commit: bool = True,
):
    ctx = ticket_context("policy_ordered")
    first = first or ReversibleCommand("first")
    second = second or ReversibleCommand("second")
    selected = [first, second]
    commands = [ReversibleCommand(f"unused-{index}") for index in range(len(ctx["commands"]))]
    # The locked policy_ordered fixture selects option indexes [1, 0].
    commands[1] = first
    commands[0] = first if duplicate else InvalidCommand() if invalid else second
    binding_owner = GodotOptionBinding()
    bound = binding_owner.bind(
        port=ctx["port"], snapshot=ctx["snapshot"], current_source=ctx["source"], window=ctx["window"],
        callback_binding_hash=ctx["callback_hash"], private_commands=commands,
        private_object_refs=ctx["private_refs"],
    )
    if not bound.accepted:
        raise AssertionError(bound.to_public_dict())
    ctx["binding_owner"] = binding_owner
    ctx["binding"] = bound.binding
    ctx["commands"] = commands
    broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
    opened = open_prompt(broker, ctx, "W5")
    if not opened.accepted:
        raise AssertionError(opened.to_public_dict())
    if not commit:
        return ctx, broker, opened, selected
    prepared = broker.prepare_selection(opened.prompt, ctx["resolution"])
    if not prepared.accepted:
        raise AssertionError(prepared.to_public_dict())
    committed = broker.commit_prompt(opened.prompt)
    if not committed.accepted:
        raise AssertionError(committed.to_public_dict())
    return ctx, broker, committed, selected


def aligned_gate(ctx, broker):
    gate = ShadowMatchOwnerGate()
    result = gate.begin_match(ctx["snapshot"].match_generation, "aligned_shadow", broker)
    if not result.accepted:
        raise AssertionError(result.to_public_dict())
    return gate


def _all_keys(value):
    if type(value) is dict:
        result = set(value)
        for item in value.values():
            result.update(_all_keys(item))
        return result
    if type(value) is list:
        result = set()
        for item in value:
            result.update(_all_keys(item))
        return result
    return set()


class ShadowEngineCommandApplierTests(unittest.TestCase):
    def test_contract_anchor_and_ordered_success_witness(self) -> None:
        self.assertEqual(EXPECTED_BUNDLE_CANONICAL_SHA256, EXPECTED_BUNDLE)
        ctx, broker, committed, selected = committed_fixture()
        applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
        result = applier.apply(committed)
        self.assert_result(result, applier, True, "", "executed", False, False)
        self.assertEqual([command.value for command in selected], [1, 1])
        witness = result.witness
        self.assertIsInstance(witness, ShadowExecutedWitness)
        self.assertTrue(witness.validate_integrity(applier))
        self.assertEqual(witness.selected_indexes, (1, 0))
        self.assertEqual(witness.resolution_count, 2)
        self.assertEqual(witness.witness_snapshot(), result.to_public_dict()["witness"])
        Draft202012Validator(SCHEMA).validate(result.to_public_dict())
        serialized = json.dumps(result.to_public_dict(), sort_keys=True)
        for sentinel in VECTORS["private_sentinels"]:
            self.assertNotIn(sentinel, serialized)
        forbidden_keys = {
            "private_engine_command", "private_object_refs", "captured_state", "session_id",
            "callback_binding_hash", "current_source", "broker", "gate",
        }
        self.assertTrue(forbidden_keys.isdisjoint(_all_keys(result.to_public_dict())))

    def test_every_shared_vector_executes_without_skip(self) -> None:
        self.assertEqual(len(VECTORS["cases"]), 11)
        for case in VECTORS["cases"]:
            with self.subTest(case=case["case_id"]):
                result, applier, selected = self._run_scenario(case["scenario"])
                public = result.to_public_dict()
                self.assertEqual(public["accepted"], case["expected_accepted"])
                self.assertEqual(public["error_code"], case["expected_error"])
                self.assertEqual(applier.audit_snapshot()["state"], case["expected_state"])
                self.assertEqual(public["rolled_back"], case["expected_rolled_back"])
                self.assertEqual(public["poisoned"], case["expected_poisoned"])
                self.assertEqual([command.value for command in selected], case["expected_calls"])
                self.assertTrue(result.validate_integrity(applier))
                Draft202012Validator(SCHEMA).validate(public)

    def test_capture_apply_restore_exceptions_are_closed_and_private_free(self) -> None:
        cases = (
            (ReversibleCommand("first", raise_capture=True), ReversibleCommand("second"), "capture_failed", "aborted"),
            (ReversibleCommand("first"), ReversibleCommand("second", raise_apply=True), "command_apply_failed", "aborted"),
            (
                ReversibleCommand("first", raise_restore=True),
                ReversibleCommand("second", raise_apply=True),
                "rollback_failed",
                "poisoned",
            ),
        )
        for first, second, error, state in cases:
            with self.subTest(error=error):
                ctx, broker, committed, _ = committed_fixture(first=first, second=second)
                applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
                result = applier.apply(committed)
                self.assertEqual(result.error_code, error)
                self.assertEqual(applier.audit_snapshot()["state"], state)
                self.assertTrue(result.validate_integrity(applier))
                serialized = json.dumps(result.to_public_dict(), sort_keys=True)
                self.assertNotIn("PRIVATE_", serialized)

    def test_mutation_and_copied_serialization_never_gain_authority(self) -> None:
        ctx, broker, committed, _ = committed_fixture()
        applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
        result = applier.apply(committed)
        copied = copy.deepcopy(result.to_public_dict())
        copied["witness"]["selected_indexes"] = [999999]
        self.assertFalse(hasattr(copied, "validate_integrity"))
        self.assertTrue(result.validate_integrity(applier))
        object.__setattr__(result.witness, "selected_indexes", (999999,))
        self.assertFalse(result.witness.validate_integrity(applier))
        self.assertFalse(result.validate_integrity(applier))
        self.assertEqual(result.to_public_dict(), {
            "accepted": False,
            "error_code": "invalid_applier",
            "witness": None,
            "rolled_back": False,
            "poisoned": False,
        })

    def test_wrong_gate_broker_and_result_fail_before_command_capture(self) -> None:
        ctx, broker, committed, selected = committed_fixture()
        legacy = ShadowMatchOwnerGate()
        self.assertTrue(legacy.begin_match(ctx["snapshot"].match_generation, "legacy").accepted)
        legacy_applier = ShadowEngineCommandApplier(legacy, broker)
        self.assertEqual(legacy_applier.apply(committed).error_code, "owner_mode_not_aligned")
        other = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        wrong = ShadowEngineCommandApplier(aligned_gate(ctx, broker), other)
        self.assertEqual(wrong.apply(committed).error_code, "broker_not_current")
        self.assertEqual([command.value for command in selected], [0, 0])

    def test_executed_witness_remains_a_non_authoritative_audit_after_reobserve(self) -> None:
        ctx, broker, committed, _ = committed_fixture()
        applier = ShadowEngineCommandApplier(aligned_gate(ctx, broker), broker)
        result = applier.apply(committed)
        before = result.to_public_dict()
        self.assertTrue(broker.reset_match(ctx["snapshot"].match_generation + 1, "session:next"))
        self.assertTrue(applier.validate_integrity())
        self.assertTrue(result.validate_integrity(applier))
        self.assertEqual(result.to_public_dict(), before)
        self.assertFalse(before["witness"]["authoritative"])

    def _run_scenario(self, scenario: str):
        first = ReversibleCommand("first")
        second = ReversibleCommand("second")
        duplicate = scenario == "duplicate_command"
        invalid = scenario == "invalid_command"
        if scenario == "capture_failure":
            first.capture_ok = False
        elif scenario in {"apply_failure_restored", "restore_failure"}:
            second.apply_ok = False
            first.restore_ok = scenario != "restore_failure"
        ctx, broker, committed, selected = committed_fixture(
            first=first, second=second, duplicate=duplicate, invalid=invalid,
            commit=scenario != "uncommitted_result",
        )
        gate = aligned_gate(ctx, broker)
        pinned = broker
        if scenario == "legacy_gate":
            gate = ShadowMatchOwnerGate()
            gate.begin_match(ctx["snapshot"].match_generation, "legacy")
        elif scenario == "wrong_broker":
            pinned = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        applier = ShadowEngineCommandApplier(gate, pinned)
        if scenario == "mutated_result":
            object.__setattr__(committed, "error_code", "PRIVATE_COMMAND_SENTINEL")
        result = applier.apply(committed)
        if scenario == "replay":
            first_result = result
            self.assertTrue(first_result.accepted)
            result = applier.apply(committed)
        return result, applier, selected

    def assert_result(self, result, applier, accepted, error, state, rolled_back, poisoned) -> None:
        self.assertIsInstance(result, ShadowEngineApplyResult)
        self.assertEqual(result.accepted, accepted)
        self.assertEqual(result.error_code, error)
        self.assertEqual(result.rolled_back, rolled_back)
        self.assertEqual(result.poisoned, poisoned)
        self.assertEqual(applier.audit_snapshot()["state"], state)
        self.assertTrue(result.validate_integrity(applier))


if __name__ == "__main__":
    unittest.main()
