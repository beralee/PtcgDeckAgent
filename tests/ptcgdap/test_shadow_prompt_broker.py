from __future__ import annotations

import copy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker, ShadowPromptBrokerResult, ShadowPromptHandle
from tests.ptcgdap.test_godot_action_ticket import ticket_context
from tests.ptcgdap.test_godot_option_binding import build_window


ROOT = Path(__file__).resolve().parents[2]
VECTORS = json.loads((ROOT / "contracts/ptcgdap/shadow_prompt_broker_conformance_vectors.json").read_text(encoding="utf-8"))
SCHEMA = json.loads((ROOT / "contracts/ptcgdap/shadow_prompt_broker.schema.json").read_text(encoding="utf-8"))
FORBIDDEN = set(VECTORS["private_sentinels"]) | {
    "session_id", "callback_binding_hash", "current_source", "private_engine_command",
    "private_object_refs", "private_resolutions", "ticket", "preflight",
}


def open_prompt(broker: ShadowPromptBroker, ctx: dict, family: str = "W3", **overrides):
    values = {
        "prompt_family": family,
        "port": ctx["port"],
        "snapshot": ctx["snapshot"],
        "binding_owner": ctx["binding_owner"],
        "binding": ctx["binding"],
        "current_source": ctx["source"],
        "window": ctx["window"],
        "callback_binding_hash": ctx["callback_hash"],
    }
    values.update(overrides)
    return broker.open_prompt(**values)


def next_context(ctx: dict, *, reuse_window: bool = False) -> dict:
    source = dict(ctx["source"])
    source["select"] = copy.deepcopy(ctx["source"]["select"])
    source["turn_action_count"] += 1
    if not reuse_window:
        source["select"]["option"][1]["index"] += 10
    published = ctx["port"].publish(source, ctx["snapshot"].decision_generation + 1, ctx["snapshot"].chooser_player_index)
    if not published.accepted:
        raise AssertionError(published.error_code)
    if reuse_window:
        window = ctx["window"]
    else:
        spec = copy.deepcopy(ctx["fixture"]["window"])
        spec["select"]["option"][0]["area"] = 3
        spec["select"]["option"][1]["index"] += 10
        window = build_window(spec)
    binding_owner = GodotOptionBinding()
    bound = binding_owner.bind(
        port=ctx["port"], snapshot=published.snapshot, current_source=source, window=window,
        callback_binding_hash=ctx["callback_hash"], private_commands=ctx["commands"],
        private_object_refs=ctx["private_refs"],
    )
    if not bound.accepted:
        raise AssertionError(bound.to_public_dict())
    result = dict(ctx)
    result.update({
        "source": source, "snapshot": published.snapshot, "window": window,
        "binding_owner": binding_owner, "binding": bound.binding,
        "resolution": CabtSelectionSanitizer.resolve_policy_attempt(window, [0]),
    })
    return result


class ShadowPromptBrokerTests(unittest.TestCase):
    def test_every_w1_w7_family_uses_one_contract_and_schema(self) -> None:
        validator = Draft202012Validator(SCHEMA)
        self.assertEqual(len(VECTORS["family_cases"]), 7)
        for case in VECTORS["family_cases"]:
            with self.subTest(case=case["case_id"]):
                ctx = ticket_context("fallback_single")
                broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
                result = open_prompt(broker, ctx, case["family"])
                self.assertEqual(result.accepted, case["expected_accepted"])
                self.assertTrue(result.validate_integrity(broker))
                self.assertEqual(result.prompt.state, case["expected_state"])
                validator.validate(result.to_public_dict())

    def test_ordered_prepare_commit_is_same_window_atomic_and_private_free(self) -> None:
        ctx = ticket_context("policy_ordered")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        opened = open_prompt(broker, ctx, "W5")
        prepared = broker.prepare_selection(opened.prompt, ctx["resolution"])
        self.assertTrue(prepared.accepted)
        self.assertEqual(prepared.prompt.state, "prepared")
        self.assertEqual(prepared.to_public_dict()["audit"]["witness"], {"accepted": True, "bound": True, "committed": False})
        committed = broker.commit_prompt(opened.prompt)
        self.assertTrue(committed.accepted)
        self.assertEqual([item.option_index for item in committed.private_resolutions], [1, 0])
        audit = committed.to_public_dict()["audit"]
        self.assertEqual(audit["state"], "awaiting_reobserve")
        self.assertEqual(audit["resolution_count"], 2)
        self.assertEqual(audit["witness"], {"accepted": True, "bound": True, "committed": True})
        serialized = json.dumps(committed.to_public_dict(), sort_keys=True)
        self.assertFalse(any(token in serialized for token in FORBIDDEN))
        Draft202012Validator(SCHEMA).validate(committed.to_public_dict())
        replay = broker.commit_prompt(opened.prompt)
        self.assertFalse(replay.accepted)
        self.assertEqual(replay.error_code, "reobserve_required")
        self.assertEqual(replay.private_resolutions, ())

    def test_reobserve_requires_newer_snapshot_and_distinct_window_binding(self) -> None:
        ctx = ticket_context("fallback_single")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        prompt = open_prompt(broker, ctx, "W1").prompt
        self.assertTrue(broker.prepare_selection(prompt, ctx["resolution"]).accepted)
        self.assertTrue(broker.commit_prompt(prompt).accepted)
        stale = open_prompt(broker, ctx, "W2")
        self.assertEqual(stale.error_code, "stale_decision_generation")
        reused = next_context(ctx, reuse_window=True)
        same = open_prompt(broker, reused, "W2")
        self.assertEqual(same.error_code, "same_window_reused")

        fresh = next_context(reused, reuse_window=False)
        opened = open_prompt(broker, fresh, "W2")
        self.assertTrue(opened.accepted, opened.to_public_dict())
        self.assertEqual(prompt.state, "superseded")
        self.assertEqual(broker.prepare_selection(prompt, ctx["resolution"]).error_code, "prompt_not_current")

    def test_failures_abort_atomically_and_cross_owner_fails_closed(self) -> None:
        ctx = ticket_context("fallback_single")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        prompt = open_prompt(broker, ctx).prompt
        active = open_prompt(broker, ctx, "W4")
        self.assertEqual(active.error_code, "active_prompt_exists")
        other = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        cross = other.prepare_selection(prompt, ctx["resolution"])
        self.assertEqual(cross.error_code, "cross_owner")
        wrong = ticket_context("fallback_single")["resolution"]
        rejected = broker.prepare_selection(prompt, wrong)
        self.assertEqual(rejected.error_code, "selection_invalid")
        self.assertEqual(rejected.private_resolutions, ())
        self.assertEqual(prompt.state, "aborted")

        issue_ctx = ticket_context("fallback_single")
        issue_broker = ShadowPromptBroker(issue_ctx["snapshot"].match_generation, issue_ctx["session_id"])
        issue_prompt = open_prompt(issue_broker, issue_ctx).prompt
        issue_ctx["source"]["turn_action_count"] += 1
        issue_failed = issue_broker.prepare_selection(issue_prompt, issue_ctx["resolution"])
        self.assertEqual(issue_failed.error_code, "ticket_issue_failed")
        self.assertEqual(issue_failed.private_resolutions, ())

        ctx2 = ticket_context("fallback_single")
        broker2 = ShadowPromptBroker(ctx2["snapshot"].match_generation, ctx2["session_id"])
        prompt2 = open_prompt(broker2, ctx2).prompt
        self.assertTrue(broker2.prepare_selection(prompt2, ctx2["resolution"]).accepted)
        ctx2["source"]["turn_action_count"] += 1
        failed = broker2.commit_prompt(prompt2)
        self.assertEqual(failed.error_code, "commit_failed")
        self.assertEqual(failed.private_resolutions, ())
        self.assertEqual(prompt2.state, "aborted")

    def test_reset_and_ordinary_mutation_do_not_create_authority(self) -> None:
        ctx = ticket_context("fallback_single")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        prompt = open_prompt(broker, ctx).prompt
        self.assertTrue(broker.reset_match(ctx["snapshot"].match_generation + 1, "session:next"))
        self.assertEqual(broker.prepare_selection(prompt, ctx["resolution"]).error_code, "match_generation_mismatch")
        self.assertEqual(prompt.state, "superseded")
        object.__setattr__(prompt, "window_id", "0" * 64)
        self.assertFalse(prompt.validate_integrity(broker))
        self.assertEqual(prompt.to_public_dict(), {})
        forged = ShadowPromptBrokerResult._from_owner(broker, True, "", prompt)
        self.assertFalse(forged.validate_integrity(broker))
        self.assertNotIn("0" * 64, json.dumps(forged.to_public_dict()))


if __name__ == "__main__":
    unittest.main()
