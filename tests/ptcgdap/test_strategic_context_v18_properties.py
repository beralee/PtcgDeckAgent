from __future__ import annotations

import copy
import unittest

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer, CabtSelectionWindow
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import PolicyDecisionFactory, StrategicContextCompiler

from tests.ptcgdap.test_strategic_context_v18 import CONTRACT_ROOT, VECTORS


FIREWALL_VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")


class _StringSubclass(str):
    pass


def _accepted(mutator=None):
    raw = copy.deepcopy(FIREWALL_VECTORS["base_observations"]["regular"])
    if mutator is not None:
        mutator(raw)
    parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    result = PublicObservationFirewall.load_default().project(parsed)
    assert result.accepted, result.error_code
    public = result.public_observation
    assert public is not None and public["current"] is not None and public["select"] is not None
    built = CabtSelectionWindow.build(
        copy.deepcopy(public["select"]),
        public_observation_hash=result.public_observation_hash,
        public_hash_authority=VECTORS["fixture"]["public_hash_authority"],
        chooser_player_index=public["current"]["yourIndex"],
    )
    assert built.window is not None, built.to_public_dict()
    context_result = StrategicContextCompiler.build(result, built.window)
    assert context_result.accepted, context_result.error_code
    assert context_result.context is not None
    return result, built.window, context_result.context


class StrategicContextV18PropertyTests(unittest.TestCase):
    def test_public_mutations_rebind_context_and_remain_deterministic(self) -> None:
        _, base_window, base_context = _accepted()

        def set_turn(raw):
            raw["current"]["turn"] = 1

        def set_action_count(raw):
            raw["current"]["turnActionCount"] = 2

        def set_overage(raw):
            raw["remainingOverageTime"] = 598

        def set_deck_count(raw):
            raw["current"]["players"][0]["deckCount"] = 49

        def set_hand_card(raw):
            raw["current"]["players"][0]["hand"][0]["id"] = 104

        def remove_prize(raw):
            raw["current"]["players"][1]["prize"].pop()

        def reorder_options(raw):
            raw["select"]["option"].reverse()

        for mutator in (
            set_turn,
            set_action_count,
            set_overage,
            set_deck_count,
            set_hand_card,
            remove_prize,
            reorder_options,
        ):
            with self.subTest(mutator=mutator.__name__):
                _, window, context = _accepted(mutator)
                _, repeat_window, repeat_context = _accepted(mutator)
                self.assertNotEqual(context.context_hash, base_context.context_hash)
                self.assertNotEqual(window.public_observation_hash, base_window.public_observation_hash)
                self.assertEqual(context.context_hash, repeat_context.context_hash)
                self.assertEqual(window.window_id, repeat_window.window_id)
                self.assertTrue(context.validate_integrity())

    def test_every_policy_attempt_yields_legal_same_window_audit_or_closed_rejection(self) -> None:
        _, window, context = _accepted()
        policy_hash = "A" * 64
        proposals = ([0], [1], [], [0, 1], [0, 0], [-1], [2], [True], ["0"], None)
        for index, proposal in enumerate(proposals):
            with self.subTest(proposal=proposal):
                resolution = CabtSelectionSanitizer.resolve_policy_attempt(window, proposal)
                self.assertTrue(resolution.validate_integrity(window))
                built = PolicyDecisionFactory.build(
                    context,
                    window,
                    resolution,
                    policy_hash=policy_hash,
                    scene_id="property-scene",
                    decision_id=f"property-{index}",
                    determinism_key="property-seed",
                )
                self.assertTrue(built.accepted, built.error_code)
                decision = built.decision
                self.assertIsNotNone(decision)
                self.assertTrue(decision.validate_integrity(context, window, resolution))
                selected = decision.agent_output()
                self.assertEqual(selected, list(resolution.selected_indexes))
                self.assertEqual(len(selected), 1)
                self.assertEqual(len(set(selected)), len(selected))
                self.assertTrue(all(type(value) is int and 0 <= value < window.option_count for value in selected))
                serialized = decision.to_public_dict()
                expected_intent = [
                    {"index": value, "fingerprint": window.option_fingerprints[value]}
                    for value in selected
                ]
                self.assertEqual(serialized["selected_semantic_intent"]["options"], expected_intent)

        for outcome in ("exception", "timeout"):
            resolution = CabtSelectionSanitizer.resolve_policy_attempt(window, outcome=outcome)
            built = PolicyDecisionFactory.build(
                context,
                window,
                resolution,
                policy_hash=policy_hash,
                scene_id="fault-scene",
                decision_id=outcome,
                determinism_key="fault-seed",
            )
            self.assertTrue(built.accepted, built.error_code)
            self.assertEqual(built.decision.agent_output(), list(resolution.selected_indexes))

    def test_stale_bindings_and_non_exact_identity_inputs_fail_closed(self) -> None:
        _, window_a, context_a = _accepted()

        def reorder_options(raw):
            raw["select"]["option"].reverse()

        _, window_b, context_b = _accepted(reorder_options)
        resolution_a = CabtSelectionSanitizer.resolve_policy_attempt(window_a, [0])
        accepted = PolicyDecisionFactory.build(
            context_a,
            window_a,
            resolution_a,
            policy_hash="B" * 64,
            scene_id="scene-a",
            decision_id="decision-a",
            determinism_key="seed-a",
        )
        self.assertTrue(accepted.accepted)
        self.assertFalse(accepted.decision.validate_integrity(context_b, window_b, resolution_a))

        stale_calls = (
            (context_a, window_b, resolution_a, "B" * 64, "scene", "decision", "seed", "invalid_context"),
            (context_b, window_b, resolution_a, "B" * 64, "scene", "decision", "seed", "invalid_resolution"),
        )
        for context, window, resolution, policy_hash, scene_id, decision_id, seed, error in stale_calls:
            result = PolicyDecisionFactory.build(
                context,
                window,
                resolution,
                policy_hash=policy_hash,
                scene_id=scene_id,
                decision_id=decision_id,
                determinism_key=seed,
            )
            self.assertFalse(result.accepted)
            self.assertEqual(result.error_code, error)

        exact_type_faults = (
            {"policy_hash": "b" * 64},
            {"policy_hash": True},
            {"scene_id": _StringSubclass("scene")},
            {"decision_id": _StringSubclass("decision")},
            {"determinism_key": _StringSubclass("seed")},
        )
        for fault in exact_type_faults:
            kwargs = {
                "policy_hash": "B" * 64,
                "scene_id": "scene",
                "decision_id": "decision",
                "determinism_key": "seed",
            }
            kwargs.update(fault)
            result = PolicyDecisionFactory.build(context_a, window_a, resolution_a, **kwargs)
            self.assertFalse(result.accepted)
            self.assertIn(result.error_code, {"invalid_policy_hash", "invalid_decision_identity"})


if __name__ == "__main__":
    unittest.main()
