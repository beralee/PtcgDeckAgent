from __future__ import annotations

import copy
import gc
import json
from pathlib import Path
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from scripts.ai.ptcgdap.godot_action_ticket import GodotActionTicketOwner
from tests.ptcgdap.test_godot_option_binding import HostRef, VECTORS as BINDING_VECTORS, build_window, context


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads(
    (ROOT / "contracts/ptcgdap/godot_action_ticket_conformance_vectors.json").read_text(encoding="utf-8")
)


def ticket_context(selection_variant: str = "policy_ordered"):
    fixture, refs, source, _old_window, commands, private_refs, port, snapshot = context()
    window_spec = copy.deepcopy(fixture["window"])
    window_spec["select"]["option"][0]["area"] = VECTORS["fixture"]["binding_fixture_patch"]["window_option_0_area"]
    window = build_window(window_spec)
    self_public = window.to_public_dict()
    if self_public["decision_state"] != "policy_allowed":
        raise AssertionError(self_public)
    binding_owner = GodotOptionBinding()
    bound = binding_owner.bind(
        port=port,
        snapshot=snapshot,
        current_source=source,
        window=window,
        callback_binding_hash=fixture["callback_binding_hash"],
        private_commands=commands,
        private_object_refs=private_refs,
    )
    if not bound.accepted:
        raise AssertionError(bound.to_public_dict())
    variant = VECTORS["fixture"]["selection_variants"][selection_variant]
    attempt = list(variant["attempt_indexes"]) if variant["attempt_kind"] == "exact_indexes" else "invalid-policy-output"
    resolution = CabtSelectionSanitizer.resolve_policy_attempt(window, attempt)
    if not resolution.validate_integrity(window) or list(resolution.selected_indexes) != variant["selected_indexes"]:
        raise AssertionError(resolution.to_public_dict())
    return {
        "fixture": fixture,
        "refs": refs,
        "source": source,
        "window": window,
        "commands": commands,
        "private_refs": private_refs,
        "port": port,
        "snapshot": snapshot,
        "binding_owner": binding_owner,
        "binding": bound.binding,
        "resolution": resolution,
        "session_id": VECTORS["fixture"]["session_id"],
        "public_hash": VECTORS["fixture"]["public_observation_hash"],
        "callback_hash": VECTORS["fixture"]["callback_binding_hash"],
    }


def issue(owner: GodotActionTicketOwner, ctx: dict, **overrides):
    values = {
        "session_id": ctx["session_id"],
        "public_observation_hash": ctx["public_hash"],
        "binding_owner": ctx["binding_owner"],
        "binding": ctx["binding"],
        "port": ctx["port"],
        "snapshot": ctx["snapshot"],
        "current_source": ctx["source"],
        "window": ctx["window"],
        "callback_binding_hash": ctx["callback_hash"],
        "selection_resolution": ctx["resolution"],
    }
    values.update(overrides)
    return owner.issue(**values)


def claim(owner: GodotActionTicketOwner, ticket, ctx: dict, **overrides):
    values = {
        "ticket": ticket,
        "session_id": ctx["session_id"],
        "public_observation_hash": ctx["public_hash"],
        "binding_owner": ctx["binding_owner"],
        "binding": ctx["binding"],
        "port": ctx["port"],
        "snapshot": ctx["snapshot"],
        "current_source": ctx["source"],
        "window": ctx["window"],
        "callback_binding_hash": ctx["callback_hash"],
    }
    values.update(overrides)
    return owner.claim(**values)


def drop_ref(ctx: dict, *, command: bool) -> None:
    index = ctx["resolution"].selected_indexes[0] if command else 0
    target = ctx["commands"][index] if command else ctx["private_refs"][index][0]
    if command:
        ctx["commands"][index] = None
    else:
        ctx["private_refs"][index][0] = None
    for key, value in list(ctx["refs"].items()):
        if value is target:
            del ctx["refs"][key]
    del target
    gc.collect()


class GodotActionTicketTests(unittest.TestCase):
    def test_shared_transition_vectors(self) -> None:
        self.assertEqual(len(VECTORS["transition_cases"]), 5)
        for case in VECTORS["transition_cases"]:
            with self.subTest(case=case["id"]):
                ctx = ticket_context("policy_ordered")
                owner = GodotActionTicketOwner()
                first = issue(owner, ctx)
                self.assertTrue(first.accepted)
                scenario = case["scenario"]
                if scenario == "idempotent_issue":
                    result = issue(owner, ctx)
                    actual = result.error_code
                    self.assertIs(result.ticket, first.ticket)
                elif scenario == "active_conflict":
                    fallback = CabtSelectionSanitizer.resolve_policy_attempt(ctx["window"], "bad")
                    actual = issue(owner, ctx, selection_resolution=fallback).error_code
                    self.assertIs(owner.current_ticket(), first.ticket)
                elif scenario == "new_binding_revokes":
                    replacements = [HostRef() for _ in ctx["commands"]]
                    rebound = ctx["binding_owner"].bind(
                        port=ctx["port"], snapshot=ctx["snapshot"], current_source=ctx["source"],
                        window=ctx["window"], callback_binding_hash=ctx["callback_hash"],
                        private_commands=replacements, private_object_refs=ctx["private_refs"],
                    )
                    self.assertTrue(rebound.accepted)
                    self.assertEqual(claim(owner, first.ticket, ctx).error_code, "binding_not_current")
                    actual = claim(owner, first.ticket, ctx).error_code
                elif scenario == "successful_claim_closes_binding":
                    self.assertTrue(claim(owner, first.ticket, ctx).accepted)
                    actual = issue(owner, ctx).error_code
                elif scenario == "failed_context_attempt_atomic":
                    actual = claim(owner, first.ticket, ctx, session_id="session:other").error_code
                    self.assertTrue(claim(owner, first.ticket, ctx).accepted)
                else:
                    raise AssertionError(scenario)
                self.assertEqual(actual, case["expected_error"])

    def test_shared_issue_vectors(self) -> None:
        for case in VECTORS["issue_cases"]:
            with self.subTest(case=case["id"]):
                ctx = ticket_context(case["selection_variant"])
                owner = GodotActionTicketOwner()
                overrides = {}
                fault = case["fault"]
                if fault == "session_type":
                    overrides["session_id"] = True
                elif fault == "session_format":
                    overrides["session_id"] = "bad session"
                elif fault == "public_hash_type":
                    overrides["public_observation_hash"] = True
                elif fault == "public_hash_mismatch":
                    overrides["public_observation_hash"] = "B" * 64
                elif fault == "binding_copy":
                    overrides["binding"] = copy.deepcopy(ctx["binding"].to_public_dict())
                elif fault == "stale_snapshot":
                    self.assertTrue(
                        ctx["port"].publish(
                            ctx["source"],
                            ctx["fixture"]["decision_generation"] + 1,
                            ctx["fixture"]["chooser_player_index"],
                        ).accepted
                    )
                elif fault == "window_copy":
                    spec = copy.deepcopy(ctx["fixture"]["window"])
                    spec["select"]["option"][0]["area"] = 2
                    overrides["window"] = build_window(spec)
                elif fault == "resolution_copy":
                    overrides["selection_resolution"] = copy.deepcopy(ctx["resolution"].to_public_dict())
                elif fault == "callback_drift":
                    overrides["callback_binding_hash"] = "B" * 64
                elif fault == "active_ticket_conflict":
                    first_ctx = ticket_context("policy_ordered")
                    ctx = first_ctx
                    first = issue(owner, ctx)
                    self.assertTrue(first.accepted)
                    fallback = CabtSelectionSanitizer.resolve_policy_attempt(ctx["window"], "bad")
                    overrides["selection_resolution"] = fallback
                elif fault == "claimed_binding_reissue":
                    first = issue(owner, ctx)
                    self.assertTrue(first.accepted)
                    self.assertTrue(claim(owner, first.ticket, ctx).accepted)
                elif fault != "none":
                    raise AssertionError(fault)
                result = issue(owner, ctx, **overrides)
                self.assertEqual(result.accepted, case["expected"]["accepted"])
                self.assertEqual(result.error_code, case["expected"]["error_code"])
                self.assertEqual(result.to_public_dict(), case["expected"])
                self.assertTrue(result.validate_integrity(owner))
                if result.accepted:
                    self.assertIs(result.ticket, owner.current_ticket())
                    self.assertTrue(result.ticket.validate_integrity(owner))
                else:
                    self.assertIsNone(result.ticket)

    def test_shared_claim_vectors(self) -> None:
        for case in VECTORS["claim_cases"]:
            with self.subTest(case=case["id"]):
                ctx = ticket_context(case["selection_variant"])
                owner = GodotActionTicketOwner()
                issued = issue(owner, ctx)
                self.assertTrue(issued.accepted)
                ticket = issued.ticket
                overrides = {}
                fault = case["fault"]
                if fault == "session_drift":
                    overrides["session_id"] = "session:other"
                elif fault == "callback_drift":
                    overrides["callback_binding_hash"] = "B" * 64
                elif fault == "public_hash_drift":
                    overrides["public_observation_hash"] = "B" * 64
                elif fault == "ticket_copy":
                    ticket = copy.deepcopy(ticket.to_public_dict())
                elif fault == "cross_owner":
                    owner = GodotActionTicketOwner()
                elif fault == "stale_binding":
                    replacement_commands = [HostRef() for _ in ctx["commands"]]
                    replacement = ctx["binding_owner"].bind(
                        port=ctx["port"], snapshot=ctx["snapshot"], current_source=ctx["source"],
                        window=ctx["window"], callback_binding_hash=ctx["callback_hash"],
                        private_commands=replacement_commands, private_object_refs=ctx["private_refs"],
                    )
                    self.assertTrue(replacement.accepted)
                elif fault == "dead_command":
                    drop_ref(ctx, command=True)
                elif fault == "dead_private_ref":
                    drop_ref(ctx, command=False)
                elif fault == "double_claim":
                    self.assertTrue(claim(owner, ticket, ctx).accepted)
                elif fault == "ticket_mutation":
                    object.__setattr__(ticket, "ticket_id", "B" * 64)
                elif fault != "none":
                    raise AssertionError(fault)
                result = claim(owner, ticket, ctx, **overrides)
                self.assertEqual(result.accepted, case["expected"]["accepted"])
                self.assertEqual(result.error_code, case["expected"]["error_code"])
                self.assertEqual(result.to_public_dict(), case["expected"])
                self.assertTrue(result.validate_integrity(owner))
                if result.accepted:
                    self.assertEqual(len(result.binding_resolutions), len(ctx["resolution"].selected_indexes))
                    for resolved, index in zip(result.binding_resolutions, ctx["resolution"].selected_indexes, strict=True):
                        self.assertIs(resolved.private_engine_command, ctx["commands"][index])
                elif fault in {"session_drift", "callback_drift", "public_hash_drift"}:
                    retry = claim(owner, issued.ticket, ctx)
                    self.assertTrue(retry.accepted, retry.to_public_dict())

    def test_issue_is_idempotent_and_conflict_is_atomic(self) -> None:
        ctx = ticket_context("policy_ordered")
        owner = GodotActionTicketOwner()
        first = issue(owner, ctx)
        retry = issue(owner, ctx)
        self.assertTrue(first.accepted)
        self.assertTrue(retry.accepted)
        self.assertIs(first.ticket, retry.ticket)
        self.assertEqual(first.to_public_dict(), retry.to_public_dict())
        fallback = CabtSelectionSanitizer.resolve_policy_attempt(ctx["window"], "bad")
        conflict = issue(owner, ctx, selection_resolution=fallback)
        self.assertEqual(conflict.error_code, "active_ticket_exists")
        self.assertIs(owner.current_ticket(), first.ticket)
        self.assertTrue(claim(owner, first.ticket, ctx).accepted)
        self.assertEqual(issue(owner, ctx).error_code, "binding_already_claimed")

    def test_new_binding_revokes_old_ticket_without_executing(self) -> None:
        ctx = ticket_context("policy_ordered")
        owner = GodotActionTicketOwner()
        first = issue(owner, ctx)
        replacement_commands = [HostRef() for _ in ctx["commands"]]
        replacement = ctx["binding_owner"].bind(
            port=ctx["port"], snapshot=ctx["snapshot"], current_source=ctx["source"],
            window=ctx["window"], callback_binding_hash=ctx["callback_hash"],
            private_commands=replacement_commands, private_object_refs=ctx["private_refs"],
        )
        self.assertTrue(replacement.accepted)
        stale = claim(owner, first.ticket, ctx)
        self.assertEqual(stale.error_code, "binding_not_current")
        self.assertEqual(claim(owner, first.ticket, ctx).error_code, "ticket_revoked")
        self.assertFalse(any(hasattr(item, "execute") for item in stale.binding_resolutions))

    def test_serialization_never_echoes_private_context_or_claims(self) -> None:
        ctx = ticket_context("policy_ordered")
        owner = GodotActionTicketOwner()
        issued = issue(owner, ctx)
        claimed = claim(owner, issued.ticket, ctx)
        for result in (issued, claimed):
            encoded = json.dumps(result.to_public_dict())
            for forbidden in (
                "session:alpha", "callback_binding_hash", "private_engine_command", "private_object_refs",
                "command:", "object:", "card:", "binding_owner", "claim_resolutions",
            ):
                self.assertNotIn(forbidden, encoded)
        public = issued.ticket.to_public_dict()
        public["selected_indexes"].append(999)
        self.assertNotIn(999, issued.ticket.to_public_dict()["selected_indexes"])
        self.assertTrue(issued.ticket.validate_integrity(owner))


if __name__ == "__main__":
    unittest.main()
