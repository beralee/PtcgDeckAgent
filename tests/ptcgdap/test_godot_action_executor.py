from __future__ import annotations

import copy
import gc
import json
from pathlib import Path
import unittest
import weakref

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.godot_action_executor import (
    GodotActionCommitResult,
    GodotActionExecutor,
    GodotActionPreflightResult,
    GodotPreparedActionBatch,
)
from scripts.ai.ptcgdap.godot_action_ticket import GodotActionTicketOwner
from tests.ptcgdap.test_godot_action_ticket import HostRef, claim, issue, ticket_context


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads((ROOT / "contracts/ptcgdap/godot_action_executor_conformance_vectors.json").read_text(encoding="utf-8"))
FORBIDDEN = {
    "session_id", "callback_binding_hash", "current_source", "private_engine_command",
    "private_object_refs", "binding_resolutions", "command_refs", "private_refs",
}


def claimed_context():
    ctx = ticket_context("policy_ordered")
    ticket_owner = GodotActionTicketOwner()
    issued = issue(ticket_owner, ctx)
    if not issued.accepted:
        raise AssertionError(issued.to_public_dict())
    claimed = claim(ticket_owner, issued.ticket, ctx)
    if not claimed.accepted:
        raise AssertionError(claimed.to_public_dict())
    return ctx, ticket_owner, claimed


def prepare(executor, ctx, _ticket_owner, _claimed, **overrides):
    values = {
        "ticket_owner": _ticket_owner,
        "claim_result": _claimed,
        "binding_owner": ctx["binding_owner"],
        "binding": ctx["binding"],
        "port": ctx["port"],
        "snapshot": ctx["snapshot"],
        "current_source": ctx["source"],
        "window": ctx["window"],
        "callback_binding_hash": ctx["callback_hash"],
    }
    values.update(overrides)
    return executor.prepare(**values)


def commit(executor, batch, ctx, _ticket_owner, **overrides):
    values = {
        "ticket_owner": _ticket_owner,
        "binding_owner": ctx["binding_owner"],
        "binding": ctx["binding"],
        "port": ctx["port"],
        "snapshot": ctx["snapshot"],
        "current_source": ctx["source"],
        "window": ctx["window"],
        "callback_binding_hash": ctx["callback_hash"],
    }
    values.update(overrides)
    return executor.commit(batch, **values)


def install_dead_command_ref(ctx, index: int) -> None:
    temporary = HostRef()
    dead = weakref.ref(temporary)
    del temporary
    gc.collect()
    state = ctx["binding_owner"]._current
    refs = list(state.command_refs)
    refs[index] = dead
    state.command_refs = tuple(refs)


class GodotActionExecutorTests(unittest.TestCase):
    def test_success_is_ordered_atomic_and_public_audit_is_private_free(self) -> None:
        ctx, owner, claimed = claimed_context()
        executor = GodotActionExecutor()
        prepared = prepare(executor, ctx, owner, claimed)
        self.assertIsInstance(prepared, GodotActionPreflightResult)
        self.assertTrue(prepared.accepted)
        self.assertTrue(prepared.validate_integrity(executor))
        batch = prepared.preflight
        self.assertIsInstance(batch, GodotPreparedActionBatch)
        self.assertTrue(batch.validate_integrity(executor))
        audit = prepared.to_public_dict()["audit"]
        self.assertEqual(audit["selected_indexes"], [1, 0])
        self.assertEqual(audit["resolution_count"], 2)
        self.assertEqual(audit["state"], "prepared")
        serialized = json.dumps(prepared.to_public_dict(), sort_keys=True)
        self.assertFalse(any(name in serialized for name in FORBIDDEN))

        committed = commit(executor, batch, ctx, owner)
        self.assertIsInstance(committed, GodotActionCommitResult)
        self.assertTrue(committed.accepted)
        self.assertTrue(committed.validate_integrity(executor))
        self.assertEqual([item.option_index for item in committed.binding_resolutions], [1, 0])
        self.assertIs(committed.binding_resolutions[0].private_engine_command, ctx["commands"][1])
        self.assertIs(committed.binding_resolutions[1].private_engine_command, ctx["commands"][0])
        self.assertEqual(committed.to_public_dict()["audit"]["state"], "committed")
        self.assertFalse(any(name in json.dumps(committed.to_public_dict(), sort_keys=True) for name in FORBIDDEN))
        schema = json.loads((ROOT / "contracts/ptcgdap/godot_action_executor.schema.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema)
        validator.validate({"schema_version": 1, "profile_id": audit["executor_profile"], "kind": "preflight_result", "value": prepared.to_public_dict()})
        validator.validate({"schema_version": 1, "profile_id": audit["executor_profile"], "kind": "commit_result", "value": committed.to_public_dict()})

    def test_shared_transition_vectors_are_executed(self) -> None:
        ctx, owner, claimed = claimed_context()
        for case in VECTORS["transition_cases"]:
            executor = GodotActionExecutor()
            steps: list[str] = []
            case_id = case["id"]
            if case_id == "prepare-commit-replay":
                prepared = prepare(executor, ctx, owner, claimed)
                steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
                first = commit(executor, prepared.preflight, ctx, owner)
                steps.append("commit_accept" if first.accepted else "commit_reject")
                replay = commit(executor, prepared.preflight, ctx, owner)
                steps.append("commit_already_committed" if replay.error_code == "already_committed" else "commit_other")
            elif case_id == "prepare-abort-commit":
                prepared = prepare(executor, ctx, owner, claimed)
                steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
                steps.append("abort_accept" if executor.abort(prepared.preflight) else "abort_reject")
                result = commit(executor, prepared.preflight, ctx, owner)
                steps.append("commit_preflight_aborted" if result.error_code == "preflight_aborted" else "commit_other")
            elif case_id == "failed-prepare-is-atomic":
                result = prepare(executor, ctx, owner, claimed, callback_binding_hash="B" * 64)
                steps.extend(["prepare_reject" if not result.accepted else "prepare_accept", "state_none" if executor.current_preflight() is None else "state_active"])
            elif case_id == "failed-commit-aborts-without-output":
                prepared = prepare(executor, ctx, owner, claimed)
                steps.append("prepare_accept" if prepared.accepted else "prepare_reject")
                changed = copy.deepcopy(ctx["source"])
                changed["turn_action_count"] += 1
                result = commit(executor, prepared.preflight, ctx, owner, current_source=changed)
                steps.extend(["commit_reject" if not result.accepted and not result.binding_resolutions else "commit_other", "state_aborted" if prepared.preflight.state == "aborted" else "state_other"])
            elif case_id == "ordered-multi-preserved":
                prepared = prepare(executor, ctx, owner, claimed)
                steps.append("prepare_indexes_1_0" if prepared.preflight.to_public_dict()["selected_indexes"] == [1, 0] else "prepare_order_other")
                result = commit(executor, prepared.preflight, ctx, owner)
                steps.append("commit_indexes_1_0" if [item.option_index for item in result.binding_resolutions] == [1, 0] else "commit_order_other")
            else:
                self.fail(case_id)
            self.assertEqual(steps, case["steps"], case_id)

    def test_preflight_shared_failure_vectors(self) -> None:
        expected = {case["id"]: case["expected"] for case in VECTORS["preflight_cases"]}
        self.assertEqual(len(expected), 13)

        def run(case_id: str):
            ctx, owner, claimed = claimed_context()
            executor = GodotActionExecutor()
            if case_id == "preflight-success":
                return executor, prepare(executor, ctx, owner, claimed)
            if case_id == "preflight-invalid-owner":
                return executor, prepare(executor, ctx, owner, claimed, ticket_owner=object())
            if case_id == "preflight-invalid-claim":
                return executor, prepare(executor, ctx, owner, claimed, claim_result={})
            if case_id == "preflight-rejected-claim":
                other_ctx = ticket_context("policy_ordered")
                rejected_owner = GodotActionTicketOwner()
                issued = issue(rejected_owner, other_ctx)
                rejected = claim(rejected_owner, issued.ticket, other_ctx, session_id="session:wrong")
                return executor, prepare(executor, other_ctx, rejected_owner, rejected)
            if case_id == "preflight-invalid-binding-owner":
                return executor, prepare(executor, ctx, owner, claimed, binding_owner=object())
            if case_id == "preflight-binding-stale":
                ctx["binding_owner"]._current = None
                return executor, prepare(executor, ctx, owner, claimed)
            if case_id == "preflight-snapshot-stale":
                other = ticket_context("policy_ordered")
                return executor, prepare(executor, ctx, owner, claimed, snapshot=other["snapshot"])
            if case_id == "preflight-window-stale":
                other = ticket_context("policy_ordered")
                return executor, prepare(executor, ctx, owner, claimed, window=other["window"])
            if case_id == "preflight-callback-drift":
                return executor, prepare(executor, ctx, owner, claimed, callback_binding_hash="B" * 64)
            if case_id == "preflight-selection-reordered":
                object.__setattr__(claimed, "binding_resolutions", tuple(reversed(claimed.binding_resolutions)))
                return executor, prepare(executor, ctx, owner, claimed)
            if case_id == "preflight-resolution-mutated":
                object.__setattr__(claimed.binding_resolutions[0], "private_engine_command", HostRef())
                return executor, prepare(executor, ctx, owner, claimed)
            if case_id == "preflight-reference-released":
                install_dead_command_ref(ctx, claimed.binding_resolutions[0].option_index)
                return executor, prepare(executor, ctx, owner, claimed)
            if case_id == "preflight-active-exists":
                self.assertTrue(prepare(executor, ctx, owner, claimed).accepted)
                return executor, prepare(executor, ctx, owner, claimed)
            self.fail(case_id)

        for case_id, expectation in expected.items():
            with self.subTest(case_id=case_id):
                result_owner, result = run(case_id)
                public = result.to_public_dict()
                self.assertEqual(public, {**expectation, "audit": public.get("audit")})
                self.assertEqual(result.accepted, expectation["accepted"])
                self.assertEqual(result.error_code, expectation["error_code"])
                self.assertTrue(result.validate_integrity(result_owner))
                if not result.accepted:
                    self.assertIsNone(result.preflight)
                    self.assertIsNone(result.to_public_dict()["audit"])

    def test_commit_shared_failure_vectors(self) -> None:
        expected = {case["id"]: case["expected"] for case in VECTORS["commit_cases"]}
        self.assertEqual(len(expected), 10)

        for case_id, expectation in expected.items():
            with self.subTest(case_id=case_id):
                ctx, owner, claimed = claimed_context()
                executor = GodotActionExecutor()
                prepared = prepare(executor, ctx, owner, claimed)
                self.assertTrue(prepared.accepted)
                batch = prepared.preflight
                result_owner = executor
                if case_id == "commit-success":
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-invalid-preflight":
                    result = commit(executor, {}, ctx, owner)
                elif case_id == "commit-cross-owner":
                    result_owner = GodotActionExecutor()
                    result = commit(result_owner, batch, ctx, owner)
                elif case_id == "commit-mutated-preflight":
                    object.__setattr__(batch, "preflight_id", "0" * 64)
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-stale-batch":
                    executor._active = None
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-replay":
                    self.assertTrue(commit(executor, batch, ctx, owner).accepted)
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-aborted":
                    self.assertTrue(executor.abort(batch))
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-context-drift":
                    changed = copy.deepcopy(ctx["source"])
                    changed["turn_action_count"] += 1
                    result = commit(executor, batch, ctx, owner, current_source=changed)
                elif case_id == "commit-resolution-mutated":
                    object.__setattr__(claimed.binding_resolutions[0], "private_engine_command", HostRef())
                    result = commit(executor, batch, ctx, owner)
                elif case_id == "commit-reference-released":
                    install_dead_command_ref(ctx, claimed.binding_resolutions[0].option_index)
                    result = commit(executor, batch, ctx, owner)
                else:
                    self.fail(case_id)
                self.assertEqual(result.accepted, expectation["accepted"])
                self.assertEqual(result.error_code, expectation["error_code"])
                self.assertTrue(result.validate_integrity(result_owner))
                if not result.accepted:
                    self.assertEqual(result.binding_resolutions, ())

    def test_failed_prepare_and_commit_are_atomic(self) -> None:
        ctx, owner, claimed = claimed_context()
        executor = GodotActionExecutor()
        failed = prepare(executor, ctx, owner, claimed, callback_binding_hash="B" * 64)
        self.assertFalse(failed.accepted)
        self.assertIsNone(executor.current_preflight())
        self.assertEqual(executor._next_generation, 1)

        prepared = prepare(executor, ctx, owner, claimed)
        changed = copy.deepcopy(ctx["source"])
        changed["turn_action_count"] += 1
        failed_commit = commit(executor, prepared.preflight, ctx, owner, current_source=changed)
        self.assertFalse(failed_commit.accepted)
        self.assertEqual(failed_commit.binding_resolutions, ())
        self.assertEqual(prepared.preflight.state, "aborted")
        self.assertEqual(prepared.preflight.to_public_dict()["state"], "aborted")

    def test_owner_result_and_batch_mutation_fail_closed(self) -> None:
        ctx, owner, claimed = claimed_context()
        executor = GodotActionExecutor()
        prepared = prepare(executor, ctx, owner, claimed)
        batch = prepared.preflight
        object.__setattr__(prepared, "error_code", "private-sentinel")
        self.assertFalse(prepared.validate_integrity(executor))
        self.assertEqual(prepared.to_public_dict(), {})
        object.__setattr__(batch, "preflight_generation", 99)
        self.assertFalse(batch.validate_integrity(executor))
        self.assertEqual(batch.to_public_dict(), {})

    def test_exact_types_capacity_and_next_preflight(self) -> None:
        ctx, owner, claimed = claimed_context()
        executor = GodotActionExecutor()
        executor._next_generation = True
        rejected = prepare(executor, ctx, owner, claimed)
        self.assertEqual(rejected.error_code, "executor_integrity_invalid")

        executor = GodotActionExecutor()
        executor._next_generation = 9007199254740992
        rejected = prepare(executor, ctx, owner, claimed)
        self.assertEqual(rejected.error_code, "preflight_space_exhausted")

        executor = GodotActionExecutor()
        first = prepare(executor, ctx, owner, claimed)
        self.assertTrue(commit(executor, first.preflight, ctx, owner).accepted)
        second = prepare(executor, ctx, owner, claimed)
        self.assertTrue(second.accepted)
        self.assertEqual(second.preflight.preflight_generation, 2)
        self.assertNotEqual(first.preflight.preflight_id, second.preflight.preflight_id)


if __name__ == "__main__":
    unittest.main()
