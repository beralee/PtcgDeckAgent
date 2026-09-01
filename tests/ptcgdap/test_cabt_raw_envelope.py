from __future__ import annotations

import copy
import json
import math
import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.ai.ptcgdap.cabt_envelope import (
    parse_raw_cabt_envelope,
    parse_raw_cabt_json_bytes,
)
from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "tests" / "ptcgdap" / "fixtures" / "public"
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"


def _fixture(name: str) -> dict:
    value = load_json_strict(FIXTURE_ROOT / f"{name}.json")
    if not isinstance(value, dict):
        raise AssertionError(f"fixture {name} is not an object")
    return value


def _enum_by_pointer(envelope: object) -> dict[str, dict]:
    return {entry["pointer"]: entry for entry in envelope.enum_values}


class RawCabtEnvelopeTests(unittest.TestCase):
    def test_every_public_golden_round_trips_without_aliasing_or_field_loss(self) -> None:
        fixture_names = (
            "initial_callback",
            "normal_single_select",
            "optional_zero_deck_search",
            "normal_multi_select",
            "ordered_skill_multi_select",
            "engine_only_area_log",
            "unknown_additive_and_enum",
        )
        bundle = load_json_strict(CONTRACT_ROOT / "cabt_contract_bundle.json")
        expected_contract_hash = sha256_bytes(canonical_json_v1_bytes(bundle))

        for fixture_name in fixture_names:
            with self.subTest(fixture=fixture_name):
                original = _fixture(fixture_name)
                caller_tree = copy.deepcopy(original)
                result = parse_raw_cabt_envelope(caller_tree, contract_root=CONTRACT_ROOT)
                self.assertIsNotNone(result.envelope, result.safe_diagnostics())
                envelope = result.envelope
                self.assertEqual(envelope.raw_payload, original)
                self.assertEqual(envelope.to_host_dict()["raw_payload"], original)
                self.assertEqual(envelope.source_contract_hash, expected_contract_hash)
                self.assertEqual(envelope.firewall_status, "pending")
                self.assertIsNone(envelope.public_observation_hash)

                original_private_hash = envelope.raw_private_hash
                caller_tree["caller_mutation"] = ["must", "not", "alias"]
                returned = envelope.raw_payload
                returned["getter_mutation"] = True
                self.assertNotIn("caller_mutation", envelope.raw_payload)
                self.assertNotIn("getter_mutation", envelope.raw_payload)
                self.assertEqual(envelope.raw_private_hash, original_private_hash)

    def test_nested_unknown_values_are_quarantined_from_known_view(self) -> None:
        result = parse_raw_cabt_envelope(
            _fixture("unknown_additive_and_enum"), contract_root=CONTRACT_ROOT
        )
        self.assertIsNotNone(result.envelope)
        envelope = result.envelope
        known = envelope.known_view

        self.assertNotIn("futureHostField", known)
        self.assertNotIn("futureSelectField", known["select"])
        self.assertNotIn("futureOptionPayload", known["select"]["option"][0])
        self.assertNotIn("futureLogPayload", known["logs"][0])
        self.assertEqual(set(known), {"select", "logs", "current"})
        self.assertNotIn("search_begin_input", known)

        unknown = {entry["pointer"]: entry for entry in envelope.unknown_fields}
        self.assertEqual(unknown["/futureHostField"]["json_type"], "object")
        self.assertEqual(unknown["/select/futureSelectField"]["json_type"], "object")
        self.assertEqual(
            unknown["/select/option/0/futureOptionPayload"]["json_type"], "object"
        )
        self.assertEqual(unknown["/logs/0/futureLogPayload"]["json_type"], "object")
        serialized_unknown = json.dumps(envelope.unknown_fields, sort_keys=True)
        self.assertNotIn("append-only", serialized_unknown)
        self.assertNotIn('"keep"', serialized_unknown)

    def test_presence_distinguishes_missing_null_and_value_at_sparse_fields(self) -> None:
        initial = parse_raw_cabt_envelope(
            _fixture("initial_callback"), contract_root=CONTRACT_ROOT
        ).envelope
        multi = parse_raw_cabt_envelope(
            _fixture("normal_multi_select"), contract_root=CONTRACT_ROOT
        ).envelope
        single = parse_raw_cabt_envelope(
            _fixture("normal_single_select"), contract_root=CONTRACT_ROOT
        ).envelope

        self.assertEqual(initial.field_presence["/select"], "null")
        self.assertEqual(initial.field_presence["/step"], "value")
        self.assertEqual(initial.field_presence["/remainingOverageTime"], "value")
        self.assertEqual(multi.field_presence["/step"], "missing")
        self.assertEqual(multi.field_presence["/remainingOverageTime"], "value")
        self.assertEqual(single.field_presence["/select/deck"], "null")
        self.assertEqual(single.field_presence["/select/option/0/type"], "value")
        self.assertEqual(single.field_presence["/select/option/0/number"], "missing")
        self.assertEqual(single.framework["step"], 1)
        self.assertEqual(single.framework["remaining_overage_time"], 599.685885)

    def test_enum_metadata_preserves_known_engine_only_and_unknown_raw_values(self) -> None:
        known = parse_raw_cabt_envelope(
            _fixture("normal_single_select"), contract_root=CONTRACT_ROOT
        )
        engine_only = parse_raw_cabt_envelope(
            _fixture("engine_only_area_log"), contract_root=CONTRACT_ROOT
        )
        unknown = parse_raw_cabt_envelope(
            _fixture("unknown_additive_and_enum"), contract_root=CONTRACT_ROOT
        )

        known_entries = _enum_by_pointer(known.envelope)
        self.assertEqual(
            known_entries["/select/type"],
            {
                "pointer": "/select/type",
                "raw_int": 9,
                "known_name": "YES_NO",
                "authority": "official_known",
            },
        )
        self.assertEqual(known_entries["/select/context"]["known_name"], "IS_FIRST")
        self.assertEqual(known_entries["/select/option/0/type"]["known_name"], "YES")

        engine_entries = _enum_by_pointer(engine_only.envelope)
        self.assertEqual(engine_entries["/logs/1/toArea"]["raw_int"], 14)
        self.assertEqual(
            engine_entries["/logs/1/toArea"]["authority"], "locked_engine_only"
        )
        self.assertEqual(
            engine_entries["/logs/1/toArea"]["known_name"], "DECK_BOTTOM_INTERNAL"
        )
        self.assertTrue(engine_only.policy_eligible)

        unknown_entries = _enum_by_pointer(unknown.envelope)
        self.assertEqual(unknown_entries["/select/type"]["raw_int"], 99)
        self.assertIsNone(unknown_entries["/select/type"]["known_name"])
        self.assertEqual(unknown_entries["/select/type"]["authority"], "unknown_future")
        self.assertFalse(unknown.policy_eligible)
        self.assertEqual(
            {(issue.code, issue.pointer, issue.severity) for issue in unknown.issues},
            {
                ("unknown_enum_value", "/select/type", "error"),
                ("unknown_enum_value", "/select/context", "error"),
                ("unknown_enum_value", "/select/option/0/type", "error"),
                ("unknown_enum_value", "/logs/0/type", "error"),
            },
        )

    def test_search_token_is_opaque_and_never_enters_safe_metadata_or_diagnostics(self) -> None:
        raw = _fixture("normal_single_select")
        raw["search_begin_input"] = "top-secret-token"
        result = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)

        self.assertTrue(result.policy_eligible)
        envelope = result.envelope
        self.assertTrue(envelope.opaque_search_capability_present)
        self.assertNotIn("search_begin_input", envelope.known_view)
        safe = envelope.safe_metadata()
        safe_text = json.dumps(safe, sort_keys=True)
        self.assertNotIn("top-secret-token", safe_text)
        self.assertNotIn("raw_payload", safe)
        self.assertNotIn("raw_private_hash", safe)
        self.assertNotIn("token_free_callback_hash", safe)
        self.assertNotIn("search_begin_input", safe_text)
        self.assertNotIn("top-secret-token", json.dumps(result.safe_diagnostics()))

    def test_unknown_json_pointer_segments_are_escaped_without_copying_values(self) -> None:
        raw = _fixture("initial_callback")
        raw["a/b~c"] = {"private-value": 42}
        raw["secret-key-name"] = None
        envelope = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT).envelope
        unknown = {entry["pointer"]: entry for entry in envelope.unknown_fields}
        self.assertEqual(unknown["/a~1b~0c"]["json_type"], "object")
        self.assertNotIn("private-value", json.dumps(envelope.unknown_fields))
        self.assertIn("/secret-key-name", unknown)
        self.assertNotIn("secret-key-name", json.dumps(envelope.safe_metadata()))

    def test_structural_errors_are_bounded_and_fail_closed_without_false_reset(self) -> None:
        missing_select = _fixture("initial_callback")
        del missing_select["select"]
        missing_result = parse_raw_cabt_envelope(
            missing_select, contract_root=CONTRACT_ROOT
        )
        self.assertIsNone(missing_result.envelope)
        self.assertFalse(missing_result.policy_eligible)
        self.assertIn(
            ("missing_required_field", "/select", "error"),
            {(issue.code, issue.pointer, issue.severity) for issue in missing_result.issues},
        )

        bool_enum = _fixture("normal_single_select")
        bool_enum["select"]["type"] = True
        bool_result = parse_raw_cabt_envelope(bool_enum, contract_root=CONTRACT_ROOT)
        self.assertIsNotNone(bool_result.envelope)
        self.assertFalse(bool_result.policy_eligible)
        self.assertIn("invalid_enum_type", {issue.code for issue in bool_result.issues})
        self.assertEqual(
            set(bool_result.envelope.known_view),
            {"select", "logs", "current"},
            "nested typed-view errors must not violate the envelope root schema",
        )
        self.assertNotIn("type", bool_result.envelope.known_view["select"])

        float_enum = _fixture("normal_single_select")
        float_enum["select"]["type"] = 9.0
        float_result = parse_raw_cabt_envelope(float_enum, contract_root=CONTRACT_ROOT)
        self.assertIsNotNone(float_result.envelope)
        self.assertFalse(float_result.policy_eligible)
        self.assertIn("invalid_enum_type", {issue.code for issue in float_result.issues})

        bad_search = _fixture("initial_callback")
        bad_search["search_begin_input"] = {"token": "must-not-echo"}
        search_result = parse_raw_cabt_envelope(bad_search, contract_root=CONTRACT_ROOT)
        self.assertIsNone(search_result.envelope)
        self.assertNotIn("must-not-echo", json.dumps(search_result.safe_diagnostics()))

        nonfinite = _fixture("initial_callback")
        nonfinite["remainingOverageTime"] = math.inf
        finite_result = parse_raw_cabt_envelope(nonfinite, contract_root=CONTRACT_ROOT)
        self.assertIsNone(finite_result.envelope)
        self.assertIn("invalid_json_tree", {issue.code for issue in finite_result.issues})

        cyclic = _fixture("initial_callback")
        cyclic["cycle"] = cyclic
        cycle_result = parse_raw_cabt_envelope(cyclic, contract_root=CONTRACT_ROOT)
        self.assertIsNone(cycle_result.envelope)
        self.assertIn("cyclic_json_tree", {issue.code for issue in cycle_result.issues})

    def test_unicode_noncharacters_in_keys_and_values_fail_closed(self) -> None:
        invalid_cases = (
            ("bmp-value", "\ufdd0", False),
            ("plane-value", "\U0001fffe", False),
            ("last-scalar-key", "\U0010ffff", True),
        )
        for case_name, noncharacter, use_as_key in invalid_cases:
            with self.subTest(case=case_name):
                raw = _fixture("initial_callback")
                if use_as_key:
                    raw[noncharacter] = "must-not-be-inspected"
                else:
                    raw["future"] = noncharacter

                result = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)

                self.assertIsNone(result.envelope)
                self.assertFalse(result.policy_eligible)
                self.assertEqual(result.issues[0].code, "invalid_unicode")
                self.assertNotIn(noncharacter, json.dumps(result.safe_diagnostics()))

    def test_strict_bytes_parser_rejects_duplicates_depth_and_size_as_diagnostics(self) -> None:
        bom_result = parse_raw_cabt_json_bytes(
            b"\xef\xbb\xbf" + json.dumps(_fixture("initial_callback")).encode("utf-8"),
            contract_root=CONTRACT_ROOT,
        )
        self.assertIsNone(bom_result.envelope)
        self.assertFalse(bom_result.policy_eligible)
        self.assertEqual(bom_result.issues[0].code, "invalid_json_bytes")

        duplicate = (
            b'{"select":null,"select":null,"logs":[],"current":null,'
            b'"search_begin_input":null}'
        )
        duplicate_result = parse_raw_cabt_json_bytes(
            duplicate, contract_root=CONTRACT_ROOT
        )
        self.assertIsNone(duplicate_result.envelope)
        self.assertEqual(duplicate_result.issues[0].code, "invalid_json_bytes")

        oversized = json.dumps(_fixture("initial_callback")).encode("utf-8")
        size_result = parse_raw_cabt_json_bytes(
            oversized, contract_root=CONTRACT_ROOT, max_bytes=16
        )
        self.assertIsNone(size_result.envelope)
        self.assertEqual(size_result.issues[0].code, "json_input_too_large")

        deep: object = "leaf"
        for _ in range(140):
            deep = {"child": deep}
        raw = _fixture("initial_callback")
        raw["future"] = deep
        depth_result = parse_raw_cabt_envelope(raw, contract_root=CONTRACT_ROOT)
        self.assertIsNone(depth_result.envelope)
        self.assertEqual(depth_result.issues[0].code, "json_tree_too_deep")

    def test_contract_bundle_requires_the_exact_unique_artifact_id_path_set(self) -> None:
        mutations = ("missing_typed_profile", "duplicate_entry", "remapped_profile")
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                isolated_root = Path(directory) / "contracts" / "ptcgdap"
                shutil.copytree(CONTRACT_ROOT, isolated_root)
                bundle_path = isolated_root / "cabt_contract_bundle.json"
                bundle = load_json_strict(bundle_path)
                entries = bundle["artifacts"]
                typed = next(entry for entry in entries if entry["id"] == "typed_view_profile")
                raw = next(entry for entry in entries if entry["id"] == "raw_envelope_schema")
                if mutation == "missing_typed_profile":
                    entries.remove(typed)
                elif mutation == "duplicate_entry":
                    entries.append(copy.deepcopy(typed))
                else:
                    typed["path"] = raw["path"]
                    typed["canonical_sha256"] = raw["canonical_sha256"]
                bundle_path.write_text(
                    json.dumps(bundle, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8",
                )

                result = parse_raw_cabt_envelope(
                    _fixture("initial_callback"), contract_root=isolated_root
                )

                self.assertIsNone(result.envelope)
                self.assertEqual(result.issues[0].code, "contract_runtime_error")


if __name__ == "__main__":
    unittest.main()
