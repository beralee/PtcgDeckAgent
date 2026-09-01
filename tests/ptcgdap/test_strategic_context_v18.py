from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionSanitizer, CabtSelectionWindow
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall
from scripts.ai.ptcgdap.source_lock import load_json_strict
from scripts.ai.ptcgdap.strategic_context_v18 import (
    CONTEXT_PREFIX,
    PolicyDecisionFactory,
    StrategicContextCompiler,
    StrategicContractError,
)


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
VECTORS = load_json_strict(CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json")
FIREWALL_VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")


class _Fake:
    def validate_integrity(self, *_args: object) -> bool:
        return True


def _firewall_case(case_id: str):
    case = next(value for value in FIREWALL_VECTORS["cases"] if value["id"] == case_id)
    raw = copy.deepcopy(FIREWALL_VECTORS["base_observations"][case["base"]])
    for mutation in case["mutations"]:
        parent = raw
        for segment in mutation["path"][:-1]:
            parent = parent[segment]
        key = mutation["path"][-1]
        if mutation["op"] == "set":
            parent[key] = copy.deepcopy(mutation["value"])
        elif mutation["op"] == "delete":
            del parent[key]
        elif mutation["op"] == "append":
            parent[key].append(copy.deepcopy(mutation["value"]))
    parsed = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
    return parsed, PublicObservationFirewall.load_default().project(parsed)


def _window(result, *, public_hash: str | None = None, chooser: int | None = None, select: dict | None = None):
    public = result.public_observation
    assert public is not None and public["current"] is not None and public["select"] is not None
    built = CabtSelectionWindow.build(
        copy.deepcopy(select if select is not None else public["select"]),
        public_observation_hash=public_hash or result.public_observation_hash,
        public_hash_authority=VECTORS["fixture"]["public_hash_authority"],
        chooser_player_index=public["current"]["yourIndex"] if chooser is None else chooser,
    )
    assert built.window is not None, built.to_public_dict()
    return built.window


class StrategicContextV18Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.parsed, cls.firewall_result = _firewall_case("regular-accepted")
        cls.window = _window(cls.firewall_result)

    def test_exact_firewall_and_window_build_expected_context(self) -> None:
        built = StrategicContextCompiler.build(self.firewall_result, self.window)
        self.assertTrue(built.accepted, built.error_code)
        context = built.context
        self.assertIsNotNone(context)
        self.assertTrue(context.validate_integrity())
        self.assertEqual(context.to_public_dict(), VECTORS["fixture"]["expected_context"])
        self.assertEqual(self.window.to_public_dict(), VECTORS["fixture"]["expected_window"])
        serialized = json.dumps(context.to_public_dict(), sort_keys=True)
        for sentinel in VECTORS["private_sentinels"]:
            self.assertNotIn(sentinel, serialized)
        for key in ("search_begin_input", "raw_private_hash", "token_free_callback_hash", "callback", "binding", "ticket"):
            self.assertNotIn(key, serialized)

    def test_context_rejections_are_closed_and_do_not_echo_inputs(self) -> None:
        _, rejected = _firewall_case(next(case["id"] for case in FIREWALL_VECTORS["cases"] if case["status"] == "rejected"))
        public = self.firewall_result.public_observation
        alternate_select = copy.deepcopy(public["select"]); alternate_select["option"].reverse()
        faults = {
            "rejected_firewall": (rejected, self.window),
            "window_hash_mismatch": (self.firewall_result, _window(self.firewall_result, public_hash="B" * 64)),
            "chooser_mismatch": (self.firewall_result, _window(self.firewall_result, chooser=1)),
            "select_mismatch": (self.firewall_result, _window(self.firewall_result, select=alternate_select)),
            "initial_select_null": (_firewall_case("initial-accepted")[1], None),
            "fake_firewall_result": (_Fake(), self.window),
            "fake_window": (self.firewall_result, _Fake()),
        }
        for case in VECTORS["context_rejections"]:
            with self.subTest(case=case["id"]):
                result = StrategicContextCompiler.build(*faults[case["fault"]])
                self.assertFalse(result.accepted)
                self.assertEqual(result.error_code, case["expected_error_code"])
                self.assertIsNone(result.context)
                self.assertNotIn("PRIVATE", result.error_code)

    def test_all_shared_policy_and_fallback_decisions_match_exactly(self) -> None:
        context = StrategicContextCompiler.build(self.firewall_result, self.window).context
        self.assertIsNotNone(context)
        for case in VECTORS["decision_cases"]:
            with self.subTest(case=case["id"]):
                if case["resolution_owner"] == "policy":
                    resolution = CabtSelectionSanitizer.resolve_policy_attempt(self.window, case["selected_indexes"])
                elif case["resolution_reason_code"] == "policy_timeout":
                    resolution = CabtSelectionSanitizer.resolve_policy_attempt(self.window, outcome="timeout")
                else:
                    resolution = CabtSelectionSanitizer.resolve_policy_attempt(self.window, [0, 1])
                self.assertTrue(resolution.validate_integrity(self.window))
                result = PolicyDecisionFactory.build(
                    context,
                    self.window,
                    resolution,
                    policy_hash=case["policy_hash"],
                    scene_id=case["scene_id"],
                    decision_id=case["decision_id"],
                    determinism_key=case["determinism_key"],
                )
                self.assertTrue(result.accepted, result.error_code)
                decision = result.decision
                self.assertIsNotNone(decision)
                self.assertTrue(decision.validate_integrity(context, self.window, resolution))
                self.assertEqual(decision.to_public_dict(), case["expected_decision"])
                self.assertEqual(decision.agent_output(), case["selected_indexes"])

    def test_decision_rejections_fail_closed(self) -> None:
        context = StrategicContextCompiler.build(self.firewall_result, self.window).context
        resolution = CabtSelectionSanitizer.resolve_policy_attempt(self.window, [0])
        case = VECTORS["decision_cases"][0]
        other_window = _window(self.firewall_result, select={**self.firewall_result.public_observation["select"], "option": list(reversed(self.firewall_result.public_observation["select"]["option"]))})
        calls = {
            "different_window": (context, other_window, resolution, case["policy_hash"], case["scene_id"], case["decision_id"], case["determinism_key"]),
            "fake_resolution": (context, self.window, _Fake(), case["policy_hash"], case["scene_id"], case["decision_id"], case["determinism_key"]),
            "lowercase_policy_hash": (context, self.window, resolution, case["policy_hash"].lower(), case["scene_id"], case["decision_id"], case["determinism_key"]),
            "empty_scene_id": (context, self.window, resolution, case["policy_hash"], "", case["decision_id"], case["determinism_key"]),
        }
        for spec in VECTORS["decision_rejections"]:
            args = calls[spec["fault"]]
            result = PolicyDecisionFactory.build(
                args[0], args[1], args[2], policy_hash=args[3], scene_id=args[4], decision_id=args[5], determinism_key=args[6]
            )
            self.assertFalse(result.accepted, spec["id"])
            self.assertEqual(result.error_code, spec["expected_error_code"])
            self.assertIsNone(result.decision)

    def test_context_and_decision_mutation_fail_closed_without_echo(self) -> None:
        context = StrategicContextCompiler.build(self.firewall_result, self.window).context
        resolution = CabtSelectionSanitizer.resolve_policy_attempt(self.window, [0])
        case = VECTORS["decision_cases"][0]
        decision = PolicyDecisionFactory.build(context, self.window, resolution, policy_hash=case["policy_hash"], scene_id=case["scene_id"], decision_id=case["decision_id"], determinism_key=case["determinism_key"]).decision
        object.__setattr__(context, "_snapshot", {"private": "PRIVATE_SENTINEL"})
        self.assertFalse(context.validate_integrity())
        with self.assertRaisesRegex(StrategicContractError, "context_integrity_invalid"):
            context.to_public_dict()
        self.assertFalse(decision.validate_integrity(context, self.window, resolution))
        self.assertEqual(decision.agent_output(), [])
        with self.assertRaisesRegex(StrategicContractError, "decision_integrity_invalid"):
            decision.to_public_dict()

        rebound = StrategicContextCompiler.build(self.firewall_result, self.window).context
        forged = rebound.to_public_dict()
        forged["public_state"]["acting_player"]["hand"][0]["id"] = 999999
        unsigned = {key: copy.deepcopy(value) for key, value in forged.items() if key != "context_hash"}
        forged["context_hash"] = hashlib.sha256(CONTEXT_PREFIX + jcs_canonical_json_bytes(unsigned)).hexdigest().upper()
        object.__setattr__(rebound, "_snapshot", forged)
        self.assertFalse(rebound.validate_integrity(), "self-consistent rehash must not replace bound firewall authority")
        with self.assertRaisesRegex(StrategicContractError, "context_integrity_invalid"):
            rebound.to_public_dict()

    def test_contract_whitespace_is_allowed_but_semantic_resign_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="ptcgdap-p4-wp1-contract-") as temp:
            root = Path(temp)
            for name in (
                "strategic_context_v18.schema.json",
                "strategic_context_v18_profile.json",
                "strategic_context_v18_conformance_vectors.json",
                "strategic_context_v18_bundle.json",
            ):
                shutil.copyfile(CONTRACT_ROOT / name, root / name)
            with (root / "strategic_context_v18_profile.json").open("ab") as handle:
                handle.write(b" \n")
            self.assertTrue(StrategicContextCompiler.build(self.firewall_result, self.window, contract_root=root).accepted)
            profile = load_json_strict(root / "strategic_context_v18_profile.json")
            profile["scope"] = "forged-private-owner"
            (root / "strategic_context_v18_profile.json").write_text(json.dumps(profile), encoding="utf-8")
            result = StrategicContextCompiler.build(self.firewall_result, self.window, contract_root=root)
            self.assertFalse(result.accepted)
            self.assertEqual(result.error_code, "contract_error")


if __name__ == "__main__":
    unittest.main()
