from __future__ import annotations

import copy
import hashlib
import struct
import sys
import unittest
from pathlib import Path
from typing import Any
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.cabt_tree_hash import (
    DEFAULT_LIMITS,
    CabtTreeHashError,
    CabtTreeHashLimits,
    cabt_tree_hash,
    jcs_canonical_json_bytes,
    jcs_canonicalize_json_bytes,
    normalize_search_capability,
    public_observation_hash,
    raw_private_hash,
    token_free_callback_hash,
)
from scripts.ai.ptcgdap.source_lock import load_json_strict


VECTORS_PATH = (
    ROOT / "contracts" / "ptcgdap" / "cabt_tree_hash_conformance_vectors.json"
)
VECTORS = load_json_strict(VECTORS_PATH)

RFC8785_APPENDIX_B_HEX = {
    "0000000000000000",
    "8000000000000000",
    "0000000000000001",
    "8000000000000001",
    "7fefffffffffffff",
    "ffefffffffffffff",
    "4340000000000000",
    "c340000000000000",
    "4430000000000000",
    "7fffffffffffffff",
    "7ff0000000000000",
    "44b52d02c7e14af5",
    "44b52d02c7e14af6",
    "44b52d02c7e14af7",
    "444b1ae4d6e2ef4e",
    "444b1ae4d6e2ef4f",
    "444b1ae4d6e2ef50",
    "3eb0c6f7a0b5ed8c",
    "3eb0c6f7a0b5ed8d",
    "41b3de4355555553",
    "41b3de4355555554",
    "41b3de4355555555",
    "41b3de4355555556",
    "41b3de4355555557",
    "becbf647612f3696",
    "43143ff3c1cb0959",
}


def _limits(overrides: dict[str, int] | None = None) -> CabtTreeHashLimits:
    values = {
        "max_input_bytes": DEFAULT_LIMITS.max_input_bytes,
        "max_depth": DEFAULT_LIMITS.max_depth,
        "max_nodes": DEFAULT_LIMITS.max_nodes,
        "max_output_bytes": DEFAULT_LIMITS.max_output_bytes,
    }
    values.update(overrides or {})
    return CabtTreeHashLimits(**values)


def _factory(name: str) -> Any:
    if name == "nan":
        return float("nan")
    if name == "positive_infinity":
        return float("inf")
    if name == "negative_infinity":
        return float("-inf")
    if name == "safe_integer_max_plus_one":
        return 9007199254740992
    if name == "safe_integer_min_minus_one":
        return -9007199254740992
    if name == "lone_high_surrogate_value":
        return "\ud800"
    if name == "lone_low_surrogate_key":
        return {"\udfff": 1}
    if name == "noncharacter_value_fdd0":
        return "\ufdd0"
    if name == "noncharacter_key_plane_1":
        return {"\U0001fffe": 1}
    if name == "list_cycle":
        value: list[Any] = []
        value.append(value)
        return value
    if name == "object_cycle":
        value: dict[str, Any] = {}
        value["self"] = value
        return value
    if name == "non_string_key":
        return {1: "not-json"}
    if name == "tuple_value":
        return (1, 2)
    if name == "nested_list_depth_3":
        return [[[0]]]
    if name == "four_node_tree":
        return [0, 1, 2]
    if name == "six_output_bytes":
        return "abcd"
    if name == "one_member_object":
        return {"a": 0}
    raise AssertionError(f"unknown vector factory: {name}")


def _json_pointer_get(root: Any, pointer: str) -> Any:
    if pointer == "":
        return root
    if not pointer.startswith("/"):
        raise AssertionError(f"invalid vector JSON pointer: {pointer!r}")
    current = root
    for raw_token in pointer[1:].split("/"):
        token = raw_token.replace("~1", "/").replace("~0", "~")
        if isinstance(current, list):
            current = current[int(token)]
        else:
            current = current[token]
    return current


def _json_pointer_set(root: Any, pointer: str, value: Any) -> None:
    parent_pointer, _, raw_leaf = pointer.rpartition("/")
    parent = _json_pointer_get(root, parent_pointer)
    leaf = raw_leaf.replace("~1", "/").replace("~0", "~")
    if isinstance(parent, list):
        parent[int(leaf)] = value
    else:
        parent[leaf] = value


def _materialize_canonical_input(vector: dict[str, Any]) -> Any:
    if vector["kind"] == "unicode_codepoints":
        return "".join(chr(codepoint) for codepoint in vector["input_unicode_codepoints"])
    value = copy.deepcopy(vector["input"])
    for patch in vector.get("ieee754_patches", []):
        binary64 = struct.unpack(">d", bytes.fromhex(patch["ieee754_hex"]))[0]
        _json_pointer_set(value, patch["pointer"], binary64)
        actual = _json_pointer_get(value, patch["pointer"])
        if struct.pack(">d", actual).hex() != patch["ieee754_hex"]:
            raise AssertionError(f"binary64 patch drift: {patch!r}")
    return value


class CabtTreeHashVectorContractTests(unittest.TestCase):
    def test_vector_artifact_is_complete_and_language_neutral(self) -> None:
        self.assertEqual(VECTORS["schema_version"], 1)
        self.assertEqual(VECTORS["profile_id"], "cabt_tree_hash_v1")
        self.assertIn("synthetic", VECTORS["search_token_policy"])
        self.assertIn("no real", VECTORS["search_token_policy"])
        self.assertIn("Python integer nodes", VECTORS["authority"]["profile_scope"])
        self.assertNotIn(b"\x00", VECTORS_PATH.read_bytes())
        self.assertEqual(
            set(VECTORS["domain_prefixes"]),
            {"raw_private", "token_free_callback", "public_observation"},
        )

        record_sections = (
            "canonicalization_vectors",
            "domain_hash_vectors",
            "accepted_boundary_vectors",
            "invalid_vectors",
        )
        record_ids = [
            record["id"]
            for section in record_sections
            for record in VECTORS[section]
        ]
        self.assertEqual(len(record_ids), len(set(record_ids)))

        domain_ids = {vector["id"] for vector in VECTORS["domain_hash_vectors"]}
        allowed_domains = {"raw_private", "token_free_callback", "public_observation"}
        for vector in VECTORS["domain_hash_vectors"]:
            self.assertIn(vector["domain"], allowed_domains, vector["id"])
        for relation in VECTORS["relations"]:
            self.assertIn(relation["kind"], {"equal_hash", "different_hash"})
            self.assertIn(relation["left"], domain_ids)
            self.assertIn(relation["right"], domain_ids)
        for vector in VECTORS["accepted_boundary_vectors"]:
            self.assertIn(
                vector["operation"],
                {"canonicalize_tree", "parse_and_canonicalize"},
                vector["id"],
            )
        for vector in VECTORS["invalid_vectors"]:
            self.assertIn(
                vector["operation"],
                {"canonicalize_tree", "parse_and_canonicalize", "hash_domain"},
                vector["id"],
            )
            if vector["operation"] == "parse_and_canonicalize":
                encoded_text = "input_json_utf8" in vector
                encoded_hex = "input_utf8_hex" in vector
                self.assertNotEqual(encoded_text, encoded_hex, vector["id"])
                if encoded_hex:
                    self.assertRegex(vector["input_utf8_hex"], r"^(?:[0-9A-F]{2})+$")
        bom_vector = next(
            vector
            for vector in VECTORS["invalid_vectors"]
            if vector["id"] == "utf8-bom-prefix"
        )
        self.assertEqual(bom_vector["input_utf8_hex"], "EFBBBF7B7D")
        self.assertEqual(bom_vector["expected_error_code"], "invalid_json")
        number_vectors = [
            vector
            for vector in VECTORS["canonicalization_vectors"]
            if vector["kind"] == "ieee754_binary64"
        ]
        self.assertEqual(len(number_vectors), len(RFC8785_APPENDIX_B_HEX))
        self.assertEqual(
            {vector["ieee754_hex"] for vector in number_vectors},
            RFC8785_APPENDIX_B_HEX,
        )
        for vector in number_vectors:
            self.assertRegex(vector["ieee754_hex"], r"^[0-9a-f]{16}$")
            self.assertNotEqual(
                "expected_canonical_utf8" in vector,
                "expected_error_code" in vector,
                vector["id"],
            )
        escaping = next(
            vector
            for vector in VECTORS["canonicalization_vectors"]
            if vector["id"] == "jcs-string-escaping"
        )
        self.assertEqual(escaping["kind"], "unicode_codepoints")
        self.assertNotIn("input", escaping)
        self.assertEqual(escaping["input_unicode_codepoints"][0], 0)

        for vector in VECTORS["canonicalization_vectors"]:
            self.assertIn(
                vector["kind"],
                {"ieee754_binary64", "json_tree", "unicode_codepoints"},
                vector["id"],
            )
            if vector["kind"] == "unicode_codepoints":
                for codepoint in vector["input_unicode_codepoints"]:
                    self.assertIs(type(codepoint), int)
                    self.assertGreaterEqual(codepoint, 0)
                    self.assertLessEqual(codepoint, 0x10FFFF)
                    self.assertFalse(0xD800 <= codepoint <= 0xDFFF)
                    self.assertFalse(
                        0xFDD0 <= codepoint <= 0xFDEF
                        or codepoint & 0xFFFF in {0xFFFE, 0xFFFF}
                    )
            if vector["kind"] != "json_tree":
                continue
            float_pointers: set[str] = set()
            stack: list[tuple[str, Any]] = [("", vector["input"])]
            while stack:
                pointer, current = stack.pop()
                if type(current) is float:
                    float_pointers.add(pointer)
                elif isinstance(current, list):
                    stack.extend(
                        (f"{pointer}/{index}", child)
                        for index, child in enumerate(current)
                    )
                elif isinstance(current, dict):
                    stack.extend(
                        (
                            f"{pointer}/{key.replace('~', '~0').replace('/', '~1')}",
                            child,
                        )
                        for key, child in current.items()
                    )
            patches = vector.get("ieee754_patches", [])
            patch_pointers = [patch["pointer"] for patch in patches]
            self.assertEqual(len(patch_pointers), len(set(patch_pointers)), vector["id"])
            for patch in patches:
                self.assertRegex(patch["ieee754_hex"], r"^[0-9a-f]{16}$")
                self.assertIsNone(_json_pointer_get(vector["input"], patch["pointer"]))
            self.assertEqual(float_pointers, set(), vector["id"])

    def test_default_limits_are_pinned_by_the_vector_artifact(self) -> None:
        self.assertEqual(
            {
                "max_input_bytes": DEFAULT_LIMITS.max_input_bytes,
                "max_depth": DEFAULT_LIMITS.max_depth,
                "max_nodes": DEFAULT_LIMITS.max_nodes,
                "max_output_bytes": DEFAULT_LIMITS.max_output_bytes,
                "safe_integer_min": -9007199254740991,
                "safe_integer_max": 9007199254740991,
            },
            VECTORS["limits"],
        )


class JcsCanonicalizationTests(unittest.TestCase):
    def test_all_rfc8785_appendix_b_number_vectors(self) -> None:
        for vector in VECTORS["canonicalization_vectors"]:
            if vector["kind"] != "ieee754_binary64":
                continue
            value = struct.unpack(">d", bytes.fromhex(vector["ieee754_hex"]))[0]
            with self.subTest(vector=vector["id"]):
                if "expected_error_code" in vector:
                    with self.assertRaises(CabtTreeHashError) as raised:
                        jcs_canonical_json_bytes(value)
                    self.assertEqual(raised.exception.code, vector["expected_error_code"])
                else:
                    self.assertEqual(
                        jcs_canonical_json_bytes(value),
                        vector["expected_canonical_utf8"].encode("utf-8"),
                    )

    def test_tree_vectors_cover_utf16_sort_escaping_and_no_normalization(self) -> None:
        for vector in VECTORS["canonicalization_vectors"]:
            if vector["kind"] not in {"json_tree", "unicode_codepoints"}:
                continue
            with self.subTest(vector=vector["id"]):
                self.assertEqual(
                    jcs_canonical_json_bytes(_materialize_canonical_input(vector)),
                    vector["expected_canonical_utf8"].encode("utf-8"),
                )

    def test_utf16_sort_differs_from_python_codepoint_sort(self) -> None:
        value = {"דּ": "bmp", "😀": "supplementary"}
        self.assertEqual(list(sorted(value)), ["דּ", "😀"])
        self.assertEqual(
            jcs_canonical_json_bytes(value),
            "{\"😀\":\"supplementary\",\"דּ\":\"bmp\"}".encode("utf-8"),
        )

    def test_bool_is_a_literal_not_an_integer(self) -> None:
        self.assertEqual(jcs_canonical_json_bytes([True, False]), b"[true,false]")

    def test_cabt_safe_integer_profile_does_not_reclassify_binary64(self) -> None:
        self.assertEqual(
            jcs_canonical_json_bytes(float(2**53)),
            b"9007199254740992",
        )
        with self.assertRaises(CabtTreeHashError) as raised:
            jcs_canonical_json_bytes(2**53)
        self.assertEqual(raised.exception.code, "unsafe_integer")

    def test_accepted_boundaries_and_escaped_surrogate_pair(self) -> None:
        for vector in VECTORS["accepted_boundary_vectors"]:
            limits = _limits(vector.get("limits"))
            with self.subTest(vector=vector["id"]):
                if vector["operation"] == "canonicalize_tree":
                    actual = jcs_canonical_json_bytes(
                        _factory(vector["factory"]),
                        limits=limits,
                    )
                else:
                    actual = jcs_canonicalize_json_bytes(
                        vector["input_json_utf8"].encode("utf-8"),
                        limits=limits,
                    )
                self.assertEqual(
                    actual,
                    vector["expected_canonical_utf8"].encode("utf-8"),
                )
class DomainHashTests(unittest.TestCase):
    def test_domain_prefixes_include_exact_nul_separators(self) -> None:
        for domain, expected_hex in VECTORS["domain_prefixes"].items():
            expected = (
                b"PTCGDAP\x00CABT_TREE_HASH_V1\x00"
                + domain.encode("ascii")
                + b"\x00"
            )
            self.assertEqual(expected.hex().upper(), expected_hex, domain)

    def test_domain_vectors_match_independently_pinned_bytes_and_hashes(self) -> None:
        computed: dict[str, str] = {}
        for vector in VECTORS["domain_hash_vectors"]:
            value = vector["input"]
            if vector["domain"] == "token_free_callback":
                normalized = normalize_search_capability(value)
                self.assertEqual(normalized, vector["expected_normalized_input"])
                canonical_value = normalized
            else:
                canonical_value = value
            expected_canonical = vector["expected_canonical_utf8"].encode("utf-8")
            self.assertEqual(jcs_canonical_json_bytes(canonical_value), expected_canonical)
            expected_prefix = bytes.fromhex(VECTORS["domain_prefixes"][vector["domain"]])
            independent = hashlib.sha256(expected_prefix + expected_canonical).hexdigest().upper()
            self.assertEqual(independent, vector["expected_sha256"], vector["id"])
            actual = cabt_tree_hash(value, vector["domain"])
            self.assertEqual(actual, vector["expected_sha256"], vector["id"])
            computed[vector["id"]] = actual

        for relation in VECTORS["relations"]:
            with self.subTest(relation=relation):
                if relation["kind"] == "equal_hash":
                    self.assertEqual(computed[relation["left"]], computed[relation["right"]])
                else:
                    self.assertEqual(relation["kind"], "different_hash")
                    self.assertNotEqual(computed[relation["left"]], computed[relation["right"]])

    def test_convenience_functions_are_exact_domain_wrappers(self) -> None:
        vectors = {vector["id"]: vector for vector in VECTORS["domain_hash_vectors"]}
        raw = vectors["raw-private-search-alpha"]
        token_free = vectors["token-free-search-alpha"]
        public = vectors["public-projection-from-unknown-mode-1"]
        self.assertEqual(raw_private_hash(raw["input"]), raw["expected_sha256"])
        self.assertEqual(
            token_free_callback_hash(token_free["input"]),
            token_free["expected_sha256"],
        )
        self.assertEqual(
            public_observation_hash(public["input"]),
            public["expected_sha256"],
        )

    def test_search_normalization_is_a_deep_copy_and_only_replaces_the_root(self) -> None:
        vector = next(
            item
            for item in VECTORS["domain_hash_vectors"]
            if item["id"] == "token-free-search-alpha"
        )
        source = copy.deepcopy(vector["input"])
        before = copy.deepcopy(source)

        normalized = normalize_search_capability(source)

        self.assertEqual(source, before)
        self.assertIsNot(normalized, source)
        self.assertIsNot(normalized["futureRoot"], source["futureRoot"])
        self.assertEqual(normalized, vector["expected_normalized_input"])
        self.assertEqual(
            normalized["futureRoot"]["nested"]["search_begin_input"],
            "preserve-me",
        )


class FailClosedTests(unittest.TestCase):
    def _run_invalid_vector(self, vector: dict[str, Any]) -> None:
        limits = _limits(vector.get("limits"))
        operation = vector["operation"]
        if operation == "canonicalize_tree":
            jcs_canonical_json_bytes(_factory(vector["factory"]), limits=limits)
            return
        if operation == "parse_and_canonicalize":
            if "input_utf8_hex" in vector:
                data = bytes.fromhex(vector["input_utf8_hex"])
            else:
                data = vector["input_json_utf8"].encode("utf-8")
            jcs_canonicalize_json_bytes(
                data,
                limits=limits,
            )
            return
        if operation == "hash_domain":
            cabt_tree_hash(vector["input"], vector["domain"], limits=limits)
            return
        raise AssertionError(f"unknown invalid-vector operation: {operation}")

    def test_invalid_unicode_duplicate_nonfinite_cycle_types_domains_and_bounds(self) -> None:
        for vector in VECTORS["invalid_vectors"]:
            with self.subTest(vector=vector["id"]):
                with self.assertRaises(CabtTreeHashError) as raised:
                    self._run_invalid_vector(vector)
                self.assertEqual(raised.exception.code, vector["expected_error_code"])

    def test_python_arbitrary_integers_fail_in_nested_locations(self) -> None:
        for value in (9007199254740992, -9007199254740992, 10**1000):
            with self.subTest(value=value):
                with self.assertRaises(CabtTreeHashError) as raised:
                    jcs_canonical_json_bytes({"nested": [value]})
                self.assertEqual(raised.exception.code, "unsafe_integer")

    def test_all_i_json_noncharacter_boundaries_fail_in_values_and_keys(self) -> None:
        noncharacters = (
            0xFDD0,
            0xFDEF,
            0xFFFE,
            0xFFFF,
            0x1FFFE,
            0x1FFFF,
            0x10FFFE,
            0x10FFFF,
        )
        for codepoint in noncharacters:
            character = chr(codepoint)
            for value in (character, {character: "key"}):
                with self.subTest(codepoint=f"U+{codepoint:04X}", value_type=type(value)):
                    with self.assertRaises(CabtTreeHashError) as raised:
                        jcs_canonical_json_bytes(value)
                    self.assertEqual(raised.exception.code, "invalid_unicode")

    def test_bytes_preflight_enforces_tree_bounds_before_materialization(self) -> None:
        loader = "scripts.ai.ptcgdap.cabt_tree_hash.load_json_bytes_strict"
        cases = (
            (b"[0,0,0]", {"max_nodes": 3}, "node_limit"),
            (b"[[0]]", {"max_depth": 1}, "depth_limit"),
            (b"[0,]", {"max_nodes": 2}, "invalid_json"),
            (b'{"a":0,"b":}', {"max_nodes": 2}, "invalid_json"),
        )
        for data, limits, expected_code in cases:
            with self.subTest(data=data):
                with mock.patch(loader, side_effect=AssertionError("must not materialize")):
                    with self.assertRaises(CabtTreeHashError) as raised:
                        jcs_canonicalize_json_bytes(data, limits=_limits(limits))
                self.assertEqual(raised.exception.code, expected_code)

    def test_shared_but_acyclic_container_is_accepted(self) -> None:
        shared = {"b": 2, "a": 1}
        self.assertEqual(
            jcs_canonical_json_bytes([shared, shared]),
            b'[{"a":1,"b":2},{"a":1,"b":2}]',
        )

    def test_invalid_limits_fail_with_a_stable_error(self) -> None:
        for call in (
            lambda: jcs_canonical_json_bytes({}, limits=None),
            lambda: jcs_canonicalize_json_bytes(b"{}", limits=None),
            lambda: cabt_tree_hash({}, "public_observation", limits=None),
        ):
            with self.subTest(call=call):
                with self.assertRaises(CabtTreeHashError) as raised:
                    call()
                self.assertEqual(raised.exception.code, "invalid_limits")


if __name__ == "__main__":
    unittest.main()
