from __future__ import annotations

import importlib
import inspect
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.source_lock import load_json_bytes_strict


ROOT = Path(__file__).resolve().parents[2]
MODULE_NAME = "scripts.ai.ptcgdap.card_id_catalog"
VECTORS_PATH = (
    ROOT / "contracts/ptcgdap/card_id_catalog_conformance_vectors.json"
)
TRUSTED_CANDIDATE_BUNDLE_SHA256 = (
    "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
)
PAYLOAD_PATHS = (
    "contracts/ptcgdap/card_id_catalog.schema.json",
    "contracts/ptcgdap/card_id_catalog_source_manifest.json",
    "contracts/ptcgdap/card_id_catalog_bundle.json",
    "contracts/ptcgdap/card_id_catalog_conformance_vectors.json",
    "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
    "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
    "data/bundled_user/cards/CSVE1C_DAR.json",
    "data/bundled_user/cards/CSV7C_059.json",
    "data/bundled_user/cards/CSV8C_094.json",
    "data/bundled_user/cards/LEN_DRI_134.json",
    "data/bundled_user/cards/LEN_DRI_135.json",
    "data/bundled_user/cards/LEN_DRI_136.json",
    "data/bundled_user/cards/CSV8C_173.json",
    "data/bundled_user/cards/CSV8C_183.json",
    "data/bundled_user/cards/LEN_DRI_169.json",
)


def _runtime_module():
    return importlib.import_module(MODULE_NAME)


def _shared_vectors() -> list[dict[str, object]]:
    document = load_json_bytes_strict(VECTORS_PATH.read_bytes())
    assert type(document) is dict
    vectors = document["vectors"]
    assert type(vectors) is list
    return vectors


def _materialize_vector_value(value: object) -> object:
    if type(value) is dict:
        if value.get("host_type") == "bool" and set(value) == {
            "host_type",
            "value",
        }:
            return value["value"]
        if value.get("host_type") == "unsafe_integer" and set(value) == {
            "decimal",
            "host_type",
        }:
            return int(value["decimal"])
        if value.get("host_type") == "integer" and set(value) == {
            "host_type",
            "value",
        }:
            return int(value["value"])
        return {key: _materialize_vector_value(child) for key, child in value.items()}
    if type(value) is list:
        return [_materialize_vector_value(child) for child in value]
    return value


def _run_vector(catalog: object, vector: dict[str, object]) -> dict[str, object]:
    operation = vector["operation"]
    values = _materialize_vector_value(vector["input"])
    assert type(values) is dict
    if operation == "lookup_official_card":
        return catalog.lookup_official_card(values["official_card_id"])
    if operation == "lookup_official_attack":
        return catalog.lookup_official_attack(values["official_attack_id"])
    if operation == "lookup_local_printing":
        printing = values["local_printing"]
        return catalog.lookup_local_printing(
            printing["set_code"], printing["card_index"]
        )
    if operation == "lookup_local_attack":
        printing = values["local_printing"]
        return catalog.lookup_local_attack(
            printing["set_code"],
            printing["card_index"],
            values["local_attack_index"],
        )
    if operation == "lookup_local_printing_for_official_card":
        return catalog.lookup_local_printing_for_official_card(
            values["official_card_id"]
        )
    if operation == "lookup_official_printing":
        return catalog.official_printing_for(values["official_card_id"])
    if operation == "artifact_canonical_sha256":
        return catalog.artifact_canonical_sha256(values["artifact_id"])
    if operation == "validate_local_source":
        printing = values["local_printing"]
        source_path = ROOT / values["source_file"]
        materialization = values["materialization"]
        if materialization == "bytes":
            actual_source = source_path.read_bytes()
        elif materialization == "mutated_tree":
            actual_source = load_json_bytes_strict(source_path.read_bytes())
            mutation = values["mutation"]
            actual_source[mutation["field"]] = mutation["value"]
        else:
            raise AssertionError(
                f"test dispatcher does not own materialization: {materialization!r}"
            )
        return catalog.validate_local_source(
            printing["set_code"], printing["card_index"], actual_source
        )
    raise AssertionError(f"test dispatcher does not own operation: {operation!r}")


def _copy_payload(target_root: Path) -> None:
    for relative_path in PAYLOAD_PATHS:
        source = ROOT / relative_path
        target = target_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


class CardIdCatalogOwnerTests(unittest.TestCase):
    def test_runtime_owner_module_exposes_fixed_trust_api(self) -> None:
        module = _runtime_module()
        self.assertTrue(hasattr(module, "CardIdCatalog"))
        self.assertTrue(hasattr(module, "CardIdCatalogError"))
        self.assertEqual(
            module.TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256,
            TRUSTED_CANDIDATE_BUNDLE_SHA256,
        )
        for method in (
            module.CardIdCatalog.load_default,
            module.CardIdCatalog.load_trusted_bundle,
        ):
            parameters = inspect.signature(method).parameters
            self.assertNotIn("trusted_hash", parameters)
            self.assertNotIn("expected_hash", parameters)
            self.assertNotIn("expected_sha256", parameters)
        self.assertFalse(hasattr(module.CardIdCatalog, "validate_projection"))
        with self.assertRaises(TypeError):
            module.CardIdCatalog()

    def test_default_load_is_complete_before_authority_is_exposed(self) -> None:
        module = _runtime_module()
        catalog = module.CardIdCatalog.load_default()
        audit = catalog.audit_snapshot()
        self.assertEqual(audit["status"], "loaded")
        self.assertEqual(audit["official_card_count"], 1267)
        self.assertEqual(audit["official_attack_count"], 1556)
        self.assertEqual(audit["mapped_local_printing_count"], 9)
        self.assertEqual(audit["verified_artifact_count"], 5)
        self.assertEqual(audit["verified_local_source_count"], 9)
        self.assertEqual(audit["authority"], "shadow_coordinate_lookup_only")
        self.assertFalse(audit["live_consumer_authorized"])
        self.assertEqual(
            catalog.catalog_hash(),
            module.TRUSTED_CATALOG_BUNDLE_CANONICAL_SHA256,
        )

    def test_all_current_shared_vectors_match_uniform_copy_only_dto(self) -> None:
        catalog = _runtime_module().CardIdCatalog.load_default()
        for vector in _shared_vectors():
            with self.subTest(vector=vector["id"]):
                actual = _run_vector(catalog, vector)
                self.assertEqual(list(actual), ["ok", "error_code", "value"])
                self.assertEqual(actual, vector["expected"])

    def test_required_aliases_preserve_exact_identity_and_type_semantics(self) -> None:
        catalog = _runtime_module().CardIdCatalog.load_default()
        self.assertEqual(
            catalog.is_known_official_card_id(860),
            {"ok": True, "error_code": None, "value": True},
        )
        self.assertEqual(
            catalog.is_known_official_card_id(1268),
            {"ok": True, "error_code": None, "value": False},
        )
        self.assertEqual(
            catalog.lookup_official_card_id("CSV7C", "059"),
            {"ok": True, "error_code": None, "value": 104},
        )
        self.assertEqual(
            catalog.lookup_official_attack_id("LEN_DRI", "134", 1),
            {"ok": True, "error_code": None, "value": 935},
        )
        self.assertEqual(
            catalog.official_attack_owner(935),
            {
                "ok": True,
                "error_code": None,
                "value": {
                    "owner_official_card_id": 646,
                    "owner_attack_ordinal": 1,
                },
            },
        )
        for invalid in (True, 9_007_199_254_740_992, "104", 104.0, None):
            with self.subTest(invalid=invalid):
                self.assertEqual(
                    catalog.lookup_official_card(invalid),
                    {"ok": False, "error_code": "input_type_invalid", "value": None},
                )

    def test_no_guessing_and_known_unmapped_remain_distinct_from_unknown(self) -> None:
        catalog = _runtime_module().CardIdCatalog.load_default()
        self.assertEqual(
            catalog.lookup_official_card(103)["value"]["ordered_official_attack_ids"],
            [130],
        )
        self.assertEqual(
            catalog.lookup_official_card(860)["value"]["ordered_official_attack_ids"],
            [1239],
        )
        for set_code, card_index in (("CSV9.5C", "043"), ("CSV10C", "146")):
            with self.subTest(set_code=set_code, card_index=card_index):
                self.assertEqual(
                    catalog.lookup_official_card_id(set_code, card_index),
                    {
                        "ok": False,
                        "error_code": "local_printing_unmapped",
                        "value": None,
                    },
                )
        self.assertEqual(
            catalog.lookup_local_printing_for_official_card(860)["error_code"],
            "official_card_unmapped",
        )
        self.assertEqual(
            catalog.lookup_local_printing_for_official_card(1268)["error_code"],
            "official_card_unknown",
        )

    def test_results_and_audit_are_deep_copies_and_instance_is_immutable(self) -> None:
        module = _runtime_module()
        catalog = module.CardIdCatalog.load_default()
        result = catalog.lookup_official_card(646)
        result["value"]["ordered_official_attack_ids"].append(999_999)
        self.assertEqual(
            catalog.lookup_official_card(646)["value"]["ordered_official_attack_ids"],
            [934, 935],
        )
        audit = catalog.audit_snapshot()
        audit["official_card_count"] = 0
        self.assertEqual(catalog.audit_snapshot()["official_card_count"], 1267)
        with self.assertRaises((AttributeError, TypeError)):
            catalog.source_contract_hash = "0" * 64

    def test_local_source_validation_accepts_actual_bytes_or_tree_only(self) -> None:
        catalog = _runtime_module().CardIdCatalog.load_default()
        source = ROOT / "data/bundled_user/cards/CSV7C_059.json"
        source_bytes = source.read_bytes()
        source_tree = load_json_bytes_strict(source_bytes)
        expected = {"ok": True, "error_code": None, "value": True}
        self.assertEqual(
            catalog.validate_local_source("CSV7C", "059", source_bytes), expected
        )
        self.assertEqual(
            catalog.validate_local_source("CSV7C", "059", source_tree), expected
        )
        self.assertNotIn(
            "expected_hash", inspect.signature(catalog.validate_local_source).parameters
        )
        drifted = dict(source_tree)
        drifted["card_index"] = "060"
        failure = catalog.validate_local_source("CSV7C", "059", drifted)
        self.assertEqual(
            failure,
            {
                "ok": False,
                "error_code": "local_source_hash_mismatch",
                "value": None,
            },
        )
        self.assertNotIn("060", json.dumps(failure, sort_keys=True))

    def test_trusted_loader_fails_closed_for_bundle_artifact_and_source_tamper(self) -> None:
        module = _runtime_module()
        cases = (
            (
                "bundle",
                "contracts/ptcgdap/card_id_catalog_bundle.json",
                (b'"schema_version": 1', b'"schema_version": 2'),
                "catalog_bundle_trust_anchor_mismatch",
            ),
            (
                "artifact",
                "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
                (b'"schema_version": 1', b'"schema_version": 2'),
                "catalog_artifact_hash_mismatch",
            ),
            (
                "source",
                "data/bundled_user/cards/CSV7C_059.json",
                None,
                "source_hash_mismatch",
            ),
        )
        for case_name, relative_path, replacement, error_code in cases:
            with self.subTest(case=case_name), tempfile.TemporaryDirectory() as temp:
                copied_root = Path(temp)
                _copy_payload(copied_root)
                target = copied_root / relative_path
                source = target.read_bytes()
                if replacement is None:
                    target.write_bytes(source + b"\n ")
                else:
                    before, after = replacement
                    self.assertEqual(source.count(before), 1)
                    target.write_bytes(source.replace(before, after, 1))
                with self.assertRaises(module.CardIdCatalogError) as raised:
                    module.CardIdCatalog.load_trusted_bundle(copied_root)
                self.assertEqual(raised.exception.code, error_code)
                self.assertEqual(str(raised.exception), error_code)

    def test_canonical_artifacts_accept_insignificant_whitespace(self) -> None:
        module = _runtime_module()
        with tempfile.TemporaryDirectory() as temp:
            copied_root = Path(temp)
            _copy_payload(copied_root)
            for relative_path in (
                "contracts/ptcgdap/card_id_catalog_bundle.json",
                "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
            ):
                target = copied_root / relative_path
                target.write_bytes(target.read_bytes() + b"\n \t")
            catalog = module.CardIdCatalog.load_trusted_bundle(copied_root)
            self.assertEqual(catalog.catalog_hash(), TRUSTED_CANDIDATE_BUNDLE_SHA256)

    def test_trusted_loader_rejects_missing_source_without_partial_authority(self) -> None:
        module = _runtime_module()
        with tempfile.TemporaryDirectory() as temp:
            copied_root = Path(temp)
            _copy_payload(copied_root)
            (copied_root / "data/bundled_user/cards/CSV7C_059.json").unlink()
            with self.assertRaises(module.CardIdCatalogError) as raised:
                module.CardIdCatalog.load_trusted_bundle(copied_root)
            self.assertEqual(raised.exception.code, "source_file_missing")

    def test_duplicate_partial_attack_and_owner_mutations_fail_closed(self) -> None:
        module = _runtime_module()
        cases = (
            (
                "duplicate-bundle-key",
                "contracts/ptcgdap/card_id_catalog_bundle.json",
                b'{\n  "artifact_id"',
                b'{\n  "schema_version": 1,\n  "artifact_id"',
                "catalog_bundle_trust_anchor_mismatch",
            ),
            (
                "partial-attack-map",
                "data/ptcgdap/card_id_catalog/marnie_exact_print_bridge_v1.json",
                b'"0": 934,\n        "1": 935',
                b'"0": 934',
                "catalog_artifact_hash_mismatch",
            ),
            (
                "attack-owner",
                "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json",
                b'"official_attack_id": 1,\n      "owner_attack_ordinal": 0,\n      "owner_official_card_id": 21',
                b'"official_attack_id": 1,\n      "owner_attack_ordinal": 0,\n      "owner_official_card_id": 22',
                "catalog_artifact_hash_mismatch",
            ),
        )
        for case_name, relative_path, before, after, error_code in cases:
            with self.subTest(case=case_name), tempfile.TemporaryDirectory() as temp:
                copied_root = Path(temp)
                _copy_payload(copied_root)
                target = copied_root / relative_path
                source = target.read_bytes()
                self.assertEqual(source.count(before), 1)
                target.write_bytes(source.replace(before, after, 1))
                with self.assertRaises(module.CardIdCatalogError) as raised:
                    module.CardIdCatalog.load_trusted_bundle(copied_root)
                self.assertEqual(raised.exception.code, error_code)
                self.assertEqual(str(raised.exception), error_code)

    def test_internal_tamper_is_detected_before_query_authority(self) -> None:
        module = _runtime_module()
        catalog = module.CardIdCatalog.load_default()
        object.__setattr__(catalog, "_runtime_integrity_sha256", "0" * 64)
        self.assertEqual(
            catalog.lookup_official_card(104),
            {"ok": False, "error_code": "catalog_integrity_invalid", "value": None},
        )
        with self.assertRaises(module.CardIdCatalogError) as raised:
            catalog.audit_snapshot()
        self.assertEqual(raised.exception.code, "catalog_integrity_invalid")

    def test_query_keys_and_integrity_baseline_cannot_be_rebound(self) -> None:
        module = _runtime_module()
        expected = {
            "ok": False,
            "error_code": "catalog_integrity_invalid",
            "value": None,
        }

        def rebaseline(catalog: object) -> None:
            object.__setattr__(
                catalog,
                "_runtime_integrity_sha256",
                module._runtime_integrity_digest(
                    catalog.source_contract_hash,
                    catalog._artifact_hashes,
                    catalog._cards,
                    catalog._attacks,
                    catalog._local_entries,
                    catalog._source_bindings,
                    catalog._audit,
                ),
            )

        cases = (
            (
                "card-key",
                "_cards",
                lambda catalog: ((2001, catalog._cards[0][1]),) + catalog._cards[1:],
                lambda catalog: catalog.lookup_official_card(2001),
            ),
            (
                "attack-key",
                "_attacks",
                lambda catalog: ((2001, catalog._attacks[0][1]),)
                + catalog._attacks[1:],
                lambda catalog: catalog.lookup_official_attack(2001),
            ),
            (
                "local-entry-key",
                "_local_entries",
                lambda catalog: (
                    ("FORGED", catalog._local_entries[0][1], catalog._local_entries[0][2]),
                )
                + catalog._local_entries[1:],
                lambda catalog: catalog.lookup_local_printing(
                    "FORGED", catalog._local_entries[0][1]
                ),
            ),
            (
                "source-binding-key",
                "_source_bindings",
                lambda catalog: (
                    (
                        "FORGED",
                        catalog._source_bindings[0][1],
                        catalog._source_bindings[0][2],
                    ),
                )
                + catalog._source_bindings[1:],
                lambda catalog: catalog.validate_local_source(
                    "FORGED", catalog._source_bindings[0][1], b"{}"
                ),
            ),
        )
        for case_name, field_name, replacement, query in cases:
            with self.subTest(case=case_name):
                catalog = module.CardIdCatalog.load_default()
                object.__setattr__(catalog, field_name, replacement(catalog))
                rebaseline(catalog)
                self.assertEqual(query(catalog), expected)
                with self.assertRaises(module.CardIdCatalogError) as raised:
                    catalog.audit_snapshot()
                self.assertEqual(raised.exception.code, "catalog_integrity_invalid")

    def test_malformed_internal_slots_never_escape_raw_exceptions(self) -> None:
        module = _runtime_module()
        expected = {
            "ok": False,
            "error_code": "catalog_integrity_invalid",
            "value": None,
        }
        mutations = (
            ("cards-none", "_cards", None),
            ("artifact-hashes-none", "_artifact_hashes", None),
            ("audit-none", "_audit", None),
            ("audit-bad-slot", "_audit", object()),
            ("integrity-hash-bad-slot", "_runtime_integrity_sha256", object()),
        )
        for mutation_name, field_name, value in mutations:
            with self.subTest(mutation=mutation_name):
                catalog = module.CardIdCatalog.load_default()
                object.__setattr__(catalog, field_name, value)
                query_results = (
                    catalog.artifact_canonical_sha256("schema"),
                    catalog.is_known_official_card_id(104),
                    catalog.lookup_official_card(104),
                    catalog.official_printing_for(104),
                    catalog.lookup_official_attack(131),
                    catalog.official_attack_owner(131),
                    catalog.lookup_local_printing("CSV7C", "059"),
                    catalog.lookup_official_card_id("CSV7C", "059"),
                    catalog.lookup_local_printing_for_official_card(104),
                    catalog.lookup_local_attack("CSV7C", "059", 0),
                    catalog.lookup_official_attack_id("CSV7C", "059", 0),
                    catalog.validate_local_source("CSV7C", "059", b"{}"),
                )
                for result in query_results:
                    self.assertEqual(result, expected)
                for metadata_query in (catalog.catalog_hash, catalog.audit_snapshot):
                    with self.assertRaises(module.CardIdCatalogError) as raised:
                        metadata_query()
                    self.assertEqual(
                        raised.exception.code, "catalog_integrity_invalid"
                    )
                    self.assertEqual(str(raised.exception), "catalog_integrity_invalid")

    def test_runtime_owner_has_no_oracle_engine_or_legacy_dependency(self) -> None:
        module = _runtime_module()
        source = Path(module.__file__).read_text(encoding="utf-8")
        prohibited = (
            "ctypes",
            "subprocess",
            "socket",
            "urllib",
            "requests",
            "import os",
            "ptcgabc",
            "CardData",
            "CardDatabase",
            "CardCatalogIndex",
            "GameState",
            "AIOpponent",
            "validate_projection",
        )
        for token in prohibited:
            with self.subTest(token=token):
                self.assertNotIn(token, source)


if __name__ == "__main__":
    unittest.main()
