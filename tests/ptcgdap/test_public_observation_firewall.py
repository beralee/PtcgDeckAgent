from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope
from scripts.ai.ptcgdap.public_observation_firewall import (
    PublicFirewallError,
    PublicObservationFirewall,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"
VECTORS = load_json_strict(CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json")


class _StringSubclass(str):
    pass


def _materialize(value: object) -> object:
    if isinstance(value, dict):
        if value.get("host_type") == "string_name" and set(value) == {"host_type", "value"}:
            return _StringSubclass(value["value"])
        if value.get("host_type") == "unsafe_integer" and set(value) == {"host_type", "decimal"}:
            return int(value["decimal"])
        return {key: _materialize(child) for key, child in value.items()}
    if isinstance(value, list):
        return [_materialize(child) for child in value]
    return value


def _apply_mutation(root: object, mutation: dict) -> None:
    parent = root
    path = mutation["path"]
    for segment in path[:-1]:
        parent = parent[segment]
    key = path[-1]
    if mutation["op"] == "set":
        parent[key] = _materialize(copy.deepcopy(mutation["value"]))
    elif mutation["op"] == "delete":
        del parent[key]
    elif mutation["op"] == "append":
        parent[key].append(_materialize(copy.deepcopy(mutation["value"])))
    else:
        raise AssertionError(mutation["op"])


def _case_input(case: dict) -> dict:
    value = _materialize(copy.deepcopy(VECTORS["base_observations"][case["base"]]))
    for mutation in case["mutations"]:
        _apply_mutation(value, mutation)
    return value


class PublicObservationFirewallTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.firewall = PublicObservationFirewall.load_default()

    def test_all_shared_vectors_match_exact_tree_hash_status_and_issue(self) -> None:
        self.assertEqual(len(VECTORS["cases"]), 23)
        for case in VECTORS["cases"]:
            with self.subTest(case=case["id"]):
                parsed = parse_raw_cabt_envelope(_case_input(case), contract_root=CONTRACT_ROOT)
                result = self.firewall.project(parsed)
                self.assertEqual(result.status, case["status"])
                self.assertEqual(result.public_observation, case["expected_public_observation"])
                self.assertEqual(result.public_observation_hash, case["expected_public_observation_hash"])
                first_code = result.issues[0]["code"] if result.issues else None
                self.assertEqual(first_code, case["expected_issue_code"])
                self.assertTrue(result.validate_integrity(parsed))
                serialized = result.to_public_dict()
                self.assertEqual(serialized["status"], case["status"])
                self.assertNotIn("raw_private_hash", serialized)
                self.assertNotIn("token_free_callback_hash", serialized)
                text = json.dumps(serialized, sort_keys=True)
                self.assertNotIn("search_begin_input", text)
                for sentinel in VECTORS["sentinel_strings"]:
                    self.assertNotIn(sentinel, text)
                if result.accepted:
                    self.assertTrue(result.provenance)
                    self.assertEqual(result.issues, [])
                    self.assertTrue(all(record["authority"] == "official_cabt_wire" for record in result.provenance))
                else:
                    self.assertEqual(result.provenance, [])
                    self.assertIsNone(result.public_observation)
                    self.assertIsNone(result.public_observation_hash)

    def test_real_public_goldens_and_binary64_framework_values_are_accepted(self) -> None:
        fixture_root = ROOT / "tests" / "ptcgdap" / "fixtures" / "public"
        for name in (
            "initial_callback",
            "normal_single_select",
            "optional_zero_deck_search",
            "normal_multi_select",
            "ordered_skill_multi_select",
            "engine_only_area_log",
        ):
            with self.subTest(name=name):
                parsed = parse_raw_cabt_envelope(load_json_strict(fixture_root / f"{name}.json"), contract_root=CONTRACT_ROOT)
                self.assertTrue(parsed.policy_eligible, parsed.safe_diagnostics())
                result = self.firewall.project(parsed)
                self.assertTrue(result.accepted, result.issues)
                self.assertTrue(result.validate_integrity(parsed))

    def test_getters_are_deep_copy_and_cross_envelope_binding_is_rejected(self) -> None:
        regular = next(case for case in VECTORS["cases"] if case["id"] == "regular-accepted")
        other = next(case for case in VECTORS["cases"] if case["id"] == "opponent-active-concealed-accepted")
        parsed = parse_raw_cabt_envelope(_case_input(regular), contract_root=CONTRACT_ROOT)
        other_parsed = parse_raw_cabt_envelope(_case_input(other), contract_root=CONTRACT_ROOT)
        result = self.firewall.project(parsed)
        returned_tree = result.public_observation
        returned_tree["current"]["turn"] = 999999
        returned_provenance = result.provenance
        returned_provenance[0]["output_pointer"] = "/PRIVATE_SENTINEL"
        returned_dict = result.to_public_dict()
        returned_dict["issues"] = [{"code": "PRIVATE_SENTINEL"}]
        self.assertEqual(result.public_observation, regular["expected_public_observation"])
        self.assertNotIn("PRIVATE_SENTINEL", json.dumps(result.to_public_dict(), sort_keys=True))
        self.assertTrue(result.validate_integrity(parsed))
        self.assertFalse(result.validate_integrity(other_parsed))

        bound_parsed = parse_raw_cabt_envelope(_case_input(regular), contract_root=CONTRACT_ROOT)
        bound_result = self.firewall.project(bound_parsed)
        object.__setattr__(
            bound_parsed.envelope,
            "_known_view",
            {"select": None, "logs": [], "current": None},
        )
        self.assertFalse(bound_result.validate_integrity(bound_parsed))
        with self.assertRaises(PublicFirewallError) as raised:
            bound_result.to_public_dict()
        self.assertEqual(raised.exception.code, "result_integrity_invalid")

        limited = PublicObservationFirewall.load_default()
        limited_profile = limited._contracts.profile
        limited_profile["limits"]["max_public_tree_nodes"] = 2
        object.__setattr__(limited._contracts, "_profile", limited_profile)
        with self.assertRaises(PublicFirewallError) as raised:
            limited._provenance({"select": None, "logs": [], "current": None}, None)
        self.assertEqual(raised.exception.code, "public_projection_limit")

    def test_ordinary_internal_mutation_fails_closed_and_never_echoes(self) -> None:
        case = next(case for case in VECTORS["cases"] if case["id"] == "regular-accepted")
        parsed = parse_raw_cabt_envelope(_case_input(case), contract_root=CONTRACT_ROOT)
        field_names = ("_public_observation", "_public_observation_hash", "_provenance", "_issues", "_snapshot")
        for field_name in field_names:
            with self.subTest(field=field_name):
                result = self.firewall.project(parsed)
                object.__setattr__(result, field_name, "PRIVATE_MUTATION_SENTINEL")
                self.assertFalse(result.validate_integrity(parsed))
                with self.assertRaises(PublicFirewallError) as raised:
                    result.to_public_dict()
                self.assertEqual(raised.exception.code, "result_integrity_invalid")
                self.assertNotIn("PRIVATE_MUTATION_SENTINEL", str(raised.exception))

    def test_wrong_input_objects_and_self_consistent_contract_rewrite_reject(self) -> None:
        for value in (None, {}, object()):
            with self.subTest(value=type(value).__name__):
                result = self.firewall.project(value)
                self.assertEqual(result.status, "rejected")
                self.assertEqual(result.issues[0]["code"], "invalid_envelope")
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir) / "contracts" / "ptcgdap"
            root.mkdir(parents=True)
            for path in CONTRACT_ROOT.glob("*.json"):
                (root / path.name).write_bytes(path.read_bytes())
            profile_path = root / "cabt_public_firewall_profile.json"
            profile = load_json_strict(profile_path)
            profile["visibility_rules"]["hand"] = "forged permissive authority"
            profile_path.write_text(json.dumps(profile), encoding="utf-8")
            bundle_path = root / "cabt_public_firewall_bundle.json"
            bundle = load_json_strict(bundle_path)
            from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, sha256_bytes
            for entry in bundle["artifacts"]:
                if entry["path"].endswith("cabt_public_firewall_profile.json"):
                    entry["canonical_sha256"] = sha256_bytes(canonical_json_v1_bytes(profile))
            bundle_path.write_text(json.dumps(bundle), encoding="utf-8")
            with self.assertRaises(PublicFirewallError) as raised:
                PublicObservationFirewall.load_from_root(root)
            self.assertEqual(raised.exception.code, "firewall_contract_error")


if __name__ == "__main__":
    unittest.main()
