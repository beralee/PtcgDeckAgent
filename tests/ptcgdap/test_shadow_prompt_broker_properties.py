from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer
from scripts.ai.ptcgdap.godot_option_binding import GodotOptionBinding
from scripts.ai.ptcgdap.shadow_prompt_broker import ShadowPromptBroker
from tests.ptcgdap.test_godot_action_ticket import ticket_context
from tests.ptcgdap.test_godot_option_binding import build_window
from tests.ptcgdap.test_shadow_prompt_broker import open_prompt


class ShadowPromptBrokerPropertyTests(unittest.TestCase):
    def test_all_families_and_selection_orders_commit_once_then_require_reobserve(self) -> None:
        for family in ("W1", "W2", "W3", "W4", "W5", "W6", "W7"):
            for variant in ("fallback_single", "policy_ordered"):
                with self.subTest(family=family, variant=variant):
                    ctx = ticket_context(variant)
                    broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
                    prompt = open_prompt(broker, ctx, family).prompt
                    self.assertTrue(broker.prepare_selection(prompt, ctx["resolution"]).accepted)
                    result = broker.commit_prompt(prompt)
                    self.assertTrue(result.accepted)
                    self.assertEqual([x.option_index for x in result.private_resolutions], list(ctx["resolution"].selected_indexes))
                    self.assertFalse(broker.commit_prompt(prompt).accepted)

    def test_seeded_multi_prompt_chain_never_reuses_window_or_index_authority(self) -> None:
        ctx = ticket_context("fallback_single")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        old_prompts = []
        base_generation = ctx["snapshot"].decision_generation
        base_option_index = ctx["fixture"]["source"]["select"]["option"][1]["index"]
        base_action_count = ctx["fixture"]["source"]["turn_action_count"]
        for generation, family in enumerate(("W1", "W2", "W3", "W4", "W5", "W6", "W7"), 1):
            if generation > 1:
                source = dict(ctx["source"])
                source["select"] = copy.deepcopy(ctx["source"]["select"])
                source["select"]["option"][1]["index"] = base_option_index + generation * 100
                source["turn_action_count"] = base_action_count + generation
                published = ctx["port"].publish(source, base_generation + generation - 1, 0)
                spec = copy.deepcopy(ctx["fixture"]["window"])
                spec["select"]["option"][0]["area"] = 3
                spec["select"]["option"][1]["index"] = base_option_index + generation * 100
                window = build_window(spec)
                owner = GodotOptionBinding()
                bound = owner.bind(
                    port=ctx["port"], snapshot=published.snapshot, current_source=source, window=window,
                    callback_binding_hash=ctx["callback_hash"], private_commands=ctx["commands"], private_object_refs=ctx["private_refs"],
                )
                ctx.update({"source":source,"snapshot":published.snapshot,"window":window,"binding_owner":owner,"binding":bound.binding,"resolution":CabtSelectionSanitizer.resolve_policy_attempt(window,[0])})
            prompt = open_prompt(broker, ctx, family).prompt
            self.assertTrue(broker.prepare_selection(prompt, ctx["resolution"]).accepted)
            self.assertTrue(broker.commit_prompt(prompt).accepted)
            for old in old_prompts:
                self.assertNotEqual(old.window_id, prompt.window_id)
                self.assertFalse(broker.prepare_selection(old, ctx["resolution"]).accepted)
            old_prompts.append(prompt)

    def test_invalid_family_and_invalid_selection_types_never_emit_resolutions(self) -> None:
        ctx = ticket_context("fallback_single")
        broker = ShadowPromptBroker(ctx["snapshot"].match_generation, ctx["session_id"])
        self.assertEqual(open_prompt(broker, ctx, "W0").error_code, "invalid_family")
        prompt = open_prompt(broker, ctx, "W7").prompt
        for value in (None, [0], (0,), True, 0, "0"):
            other_ctx = ticket_context("fallback_single")
            owner = ShadowPromptBroker(other_ctx["snapshot"].match_generation, other_ctx["session_id"])
            current = open_prompt(owner, other_ctx, "W7").prompt
            result = owner.prepare_selection(current, value)
            self.assertFalse(result.accepted)
            self.assertEqual(result.private_resolutions, ())


if __name__ == "__main__":
    unittest.main()
