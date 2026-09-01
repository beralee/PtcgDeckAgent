from __future__ import annotations

from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PTCGABC_ROOT = Path(r"D:\ai\code\ptcgabc")
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import (  # noqa: E402
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)
from tools.ptcgdap.build_card_id_catalog import (  # noqa: E402
    ARTIFACT_PATHS,
    CatalogBuildError,
    _load_local_deck,
    build_catalog_documents,
    render_catalog_documents,
    validate_catalog_documents,
)


SOURCE_LOCK_SHA256 = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
P1_CONTRACT_SHA256 = "2CD02F54538985426EFDB057F3A6BDA4AD154DD171BCC03667D42D102982D294"
P2_WP1_MANIFEST_RAW_SHA256 = "1465FF641BCF722DA3AD411F02DF8377B26872723509EABC355EE1167A1C20E9"
P2_WP1_MANIFEST_CANONICAL_SHA256 = "81BDB4B254B1A7246F1A071FB0D1ABF2125B9AF31BE6FCB20A9F7DA0DA0C8A3C"
EXPECTED_NULL_PRINTINGS = [916, 925, 929, 947, 992, 998, 999, 1083]
EXPECTED_BRIDGE = {
    ("CSVE1C", "DAR"): (7, {}),
    ("CSV7C", "059"): (104, {"0": 131}),
    ("CSV8C", "094"): (112, {"0": 141}),
    ("LEN_DRI", "134"): (646, {"0": 934, "1": 935}),
    ("LEN_DRI", "135"): (647, {"0": 936}),
    ("LEN_DRI", "136"): (648, {"0": 937}),
    ("CSV8C", "173"): (1080, {}),
    ("CSV8C", "183"): (1097, {}),
    ("LEN_DRI", "169"): (1259, {}),
}
EXPECTED_LOCAL_HASHES = {
    "data/bundled_user/cards/CSVE1C_DAR.json": (
        "B86CF49A7890C45951CDB80C87BC75F0392812C5370DA66866FCC979DC79CAB2",
        "B29AF1051D130851567F72BA2759A71B9BF51405DDF15305645B3C0BFF218084",
    ),
    "data/bundled_user/cards/CSV7C_059.json": (
        "042936F1770BD8B9B9A06EDFA28DE212CA04A0D5022E1EB8B915F705323B2499",
        "6342EEAB3468FF43718D841C9DD55E750F0FFA27ECB8622FD5478AA820AFDD95",
    ),
    "data/bundled_user/cards/CSV8C_094.json": (
        "9EEDD84B0FDA69DFBED0A32C0321C2E4B9A8A4B6C905D22F3EB8FEBBAB56C2A1",
        "8540B67BA8C3F5D45AC0F9E372A7C3B7BDCA7F3F050D4159D704C08E18526A8F",
    ),
    "data/bundled_user/cards/LEN_DRI_134.json": (
        "7A09714B9835766BF5BAC71C0D2FEC1735E908D97980E3E06FBDBCE39B1D27E2",
        "D7259EED7B9B583DFF95AC92D7CF1E258B84B1F678F21C1743563AC03929C733",
    ),
    "data/bundled_user/cards/LEN_DRI_135.json": (
        "1BD94CB5EAC1EA0021F423A07A23508059E4BCEAB288B90620D71B51F63706C4",
        "651B012760D24BBC2E09BCC2A4A1F5010AEB595B4C98046246CC669C2362E824",
    ),
    "data/bundled_user/cards/LEN_DRI_136.json": (
        "5EFA9B7F30F3ADA7DF097D68A6D7851553E9C3E5490406239DA2434406716D3C",
        "A041E7168A5CA50C82E76DDBA0CEC6F2C7F66C34593B4D6A9A8C68690664021A",
    ),
    "data/bundled_user/cards/CSV8C_173.json": (
        "4FF6B61A942B6D7023AC4FEB149E701ACCC70F556F0F53B8CBD69227E26FE3EE",
        "DE4487B0030DEBAFE37303E51E978E3FA5C0C09BCADDD8245B365F2ED988ED94",
    ),
    "data/bundled_user/cards/CSV8C_183.json": (
        "713F2B15DED2F144E562667A5B7AC853E6770DDA3616934882664BF67D9AA457",
        "FB05919614D31D6362E7CBCDDCB7137EC1EC2AB160B4D20FA8E0634F3E2A0AB2",
    ),
    "data/bundled_user/cards/LEN_DRI_169.json": (
        "486CEC705A0DAB6D855C938CF43291ECBCFD36C646F105D129F5E549B8BD3642",
        "28079978B465F21F50CE9FDDA8B7EB9B6406C409F29BDCDC9D67E747FEAF3E1B",
    ),
}


class CardIdCatalogBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.documents = build_catalog_documents(ROOT, PTCGABC_ROOT)
        cls.master = cls.documents["official_master"]
        cls.bridge = cls.documents["exact_bridge"]
        cls.source_manifest = cls.documents["source_manifest"]
        cls.vectors = cls.documents["conformance_vectors"]
        cls.bundle = cls.documents["bundle"]

    def test_official_master_is_complete_identity_only_and_not_future_dense_contract(self) -> None:
        cards = self.master["cards"]
        attacks = self.master["attacks"]
        self.assertEqual(len(cards), 1267)
        self.assertEqual(len(attacks), 1556)
        self.assertEqual([record["official_card_id"] for record in cards], sorted(record["official_card_id"] for record in cards))
        self.assertEqual([record["official_attack_id"] for record in attacks], sorted(record["official_attack_id"] for record in attacks))
        self.assertEqual(len({record["official_card_id"] for record in cards}), 1267)
        self.assertEqual(len({record["official_attack_id"] for record in attacks}), 1556)

        cards_by_id = {record["official_card_id"]: record for record in cards}
        attacks_by_id = {record["official_attack_id"]: record for record in attacks}
        flattened = []
        for card in cards:
            self.assertEqual(
                set(card),
                {
                    "official_card_id",
                    "exact_english_printing_or_null",
                    "ordered_official_attack_ids",
                },
            )
            for ordinal, attack_id in enumerate(card["ordered_official_attack_ids"]):
                flattened.append(attack_id)
                self.assertEqual(
                    attacks_by_id[attack_id],
                    {
                        "official_attack_id": attack_id,
                        "owner_official_card_id": card["official_card_id"],
                        "owner_attack_ordinal": ordinal,
                    },
                )
        self.assertEqual(len(flattened), 1556)
        self.assertEqual(len(set(flattened)), 1556)
        self.assertEqual(set(flattened), set(attacks_by_id))

        self.assertEqual(
            [
                card_id
                for card_id, card in cards_by_id.items()
                if card["exact_english_printing_or_null"] is None
            ],
            EXPECTED_NULL_PRINTINGS,
        )
        self.assertEqual(cards_by_id[7]["exact_english_printing_or_null"], {"expansion": "SVE", "collection_no": "7"})
        self.assertEqual(cards_by_id[103]["exact_english_printing_or_null"], {"expansion": "TWM", "collection_no": "51"})
        self.assertEqual(cards_by_id[103]["ordered_official_attack_ids"], [130])
        self.assertEqual(cards_by_id[860]["exact_english_printing_or_null"], {"expansion": "ASC", "collection_no": "46"})
        self.assertEqual(cards_by_id[860]["ordered_official_attack_ids"], [1239])

        evidence = self.master["source_evidence"]
        self.assertEqual(evidence["current_official_card_count"], 1267)
        self.assertEqual(evidence["current_official_attack_count"], 1556)
        self.assertEqual(evidence["english_csv_data_row_count"], 2022)
        self.assertEqual(evidence["printing_null_official_card_ids"], EXPECTED_NULL_PRINTINGS)
        self.assertEqual(
            evidence["id_range_semantics"],
            "observed_current_source_evidence_only_not_a_future_dense_id_contract",
        )
        forbidden_keys = {"name", "text", "effect", "image", "display_name", "localized_name"}
        for record in cards + attacks:
            self.assertTrue(forbidden_keys.isdisjoint(record))

    def test_exact_bridge_contains_only_nine_reviewed_printings_and_six_attack_ids(self) -> None:
        entries = self.bridge["entries"]
        self.assertEqual(len(entries), 9)
        actual = {}
        mapped_attacks = []
        source_paths = set()
        for entry in entries:
            key = (entry["local_printing"]["set_code"], entry["local_printing"]["card_index"])
            actual[key] = (
                entry["official_card_id"],
                entry["local_attack_index_to_official_attack_id"],
            )
            source_path = entry["source_file"]
            source_paths.add(source_path)
            expected_raw, expected_canonical = EXPECTED_LOCAL_HASHES[source_path]
            self.assertEqual(entry["source_root_id"], "ptcgdap")
            self.assertEqual(entry["source_raw_sha256"], expected_raw)
            self.assertEqual(entry["source_canonical_json_v1_sha256"], expected_canonical)
            mapped_attacks.extend(entry["local_attack_index_to_official_attack_id"].values())
        self.assertEqual(actual, EXPECTED_BRIDGE)
        self.assertEqual(source_paths, set(EXPECTED_LOCAL_HASHES))
        self.assertEqual(len(mapped_attacks), 6)
        self.assertEqual(len(set(mapped_attacks)), 6)

        scope = self.bridge["bridge_scope"]
        self.assertEqual(scope["entry_count"], 9)
        self.assertEqual(scope["official_marnie_unique_card_id_count"], 19)
        self.assertEqual(scope["official_marnie_bridge_unique_card_id_count"], 9)
        self.assertEqual(scope["official_marnie_bridge_card_count"], 34)
        self.assertEqual(scope["local_800018501_bridge_unique_printing_count"], 4)
        self.assertEqual(scope["local_800018501_bridge_card_count"], 15)
        self.assertFalse(scope["local_800018501_cabt_exportable"])
        self.assertEqual(scope["inference_policy"], "denied_exact_entries_only")

    def test_source_manifest_pins_parent_and_every_verified_input_without_absolute_paths(self) -> None:
        self.assertEqual(
            self.source_manifest["source_lock"],
            {
                "lock_id": "ptcgdap-source-lock-2026-08-09-p1wp1",
                "canonical_sha256": SOURCE_LOCK_SHA256,
            },
        )
        official_bundle = self.source_manifest["official_bundle"]
        self.assertEqual(official_bundle["manifest_raw_sha256"], "9728A4409F2D8378F161E6BF33A871186C583CEAD3222372A5C4E092C5CB356C")
        self.assertEqual(official_bundle["file_count"], 60)
        self.assertEqual(official_bundle["total_bytes"], 327589562)

        inputs = self.source_manifest["inputs"]
        self.assertEqual(len(inputs), len({entry["id"] for entry in inputs}))
        self.assertEqual(len(inputs), len({(entry["root_id"], entry["path"]) for entry in inputs}))
        self.assertTrue(all("\\" not in entry["path"] and not Path(entry["path"]).is_absolute() for entry in inputs))
        by_id = {entry["id"]: entry for entry in inputs}
        self.assertEqual(by_id["official_en_card_data_csv"]["raw_sha256"], "A0EA63CF7ADCB65D35436CE0EB390DE6E2E35654A7C67C065A45F4ABAA00F373")
        self.assertEqual(by_id["official_cg_api_py"]["raw_sha256"], "593F1298E52A635F90F8F505A52113E9AF114F444C293404E37906F18EE06CED")
        self.assertEqual(by_id["official_cg_sim_py"]["raw_sha256"], "1555F57F5D22BF4C09D70E0E667A916E575E68C9DD1DE9EAD34BA5E7E4968655")
        self.assertEqual(by_id["official_cg_dll"]["raw_sha256"], "A3A401D0F5CCC3474B9C8A7A2431920C4B728D28105A510AA6927AD6283E5CF7")
        self.assertEqual(by_id["official_api_h"]["raw_sha256"], "786ACAE884631BDCBAB0311471316BC75D62ACB465B8011BF09DAD05628BCAFD")
        self.assertEqual(by_id["official_to_json_h"]["raw_sha256"], "84EE63939863493520EBE29E8CA717217EBF90191829EA80D1349942AA867602")
        self.assertEqual(by_id["official_marnie_deck"]["raw_sha256"], "48F1A03E8AB8162F6DC608E6743A4F3B32004CB702CA447050E62055B85DEFBF")
        self.assertEqual(by_id["local_800018501_deck"]["canonical_json_v1_sha256"], "CB2FD50F40D75BDD9E38B826580A516BDCE7C51B17A43C63CE58E0CC19127CAB")

        local_sources = [entry for entry in inputs if entry["role"] == "reviewed_exact_local_printing_source"]
        self.assertEqual(len(local_sources), 9)
        for entry in local_sources:
            expected_raw, expected_canonical = EXPECTED_LOCAL_HASHES[entry["path"]]
            self.assertEqual(entry["raw_sha256"], expected_raw)
            self.assertEqual(entry["canonical_json_v1_sha256"], expected_canonical)

        derived = self.source_manifest["derived_source_facts"]
        self.assertEqual(
            derived["all_card_json"],
            {
                "producer_input_ids": [
                    "official_cg_api_py",
                    "official_cg_sim_py",
                    "official_cg_dll",
                ],
                "api_symbol": "AllCard",
                "bytes": 461443,
                "raw_sha256": "D7E29C6284BDB4D3A1EAABC38C247A1522F6E924AD3F81B569AA6D97FD49C80C",
                "record_count": 1267,
            },
        )
        self.assertEqual(
            derived["all_attack_json"],
            {
                "producer_input_ids": [
                    "official_cg_api_py",
                    "official_cg_sim_py",
                    "official_cg_dll",
                ],
                "api_symbol": "AllAttack",
                "bytes": 206848,
                "raw_sha256": "EA1E10F6F031FC973E16F4B5DAFCD9CF116AAD2FAB7A82723E693E8DD9EA00E5",
                "record_count": 1556,
            },
        )

    def test_bundle_binds_exact_five_artifacts_and_parent_hashes_without_self_reference(self) -> None:
        self.assertEqual(self.bundle["schema_version"], 1)
        self.assertEqual(self.bundle["artifact_id"], "ptcgdap-card-id-catalog-bundle-p2-wp2-v1")
        self.assertEqual(self.bundle["digest_mode"], "canonical_json_v1")
        self.assertEqual(self.bundle["source_lock_canonical_sha256"], SOURCE_LOCK_SHA256)
        self.assertEqual(
            self.bundle["parent_p1_contract"],
            {
                "contract_id": "ptcgdap-cabt-contract-p1-wp3-v1",
                "canonical_sha256": P1_CONTRACT_SHA256,
            },
        )
        self.assertEqual(
            self.bundle["parent_p2_wp1"],
            {
                "work_package": "P2-WP1",
                "manifest_path": "artifacts/ptcgdap/p2_wp1/manifest.json",
                "manifest_raw_sha256": P2_WP1_MANIFEST_RAW_SHA256,
                "manifest_canonical_sha256": P2_WP1_MANIFEST_CANONICAL_SHA256,
            },
        )
        expected_ids = {"schema", "source_manifest", "official_master", "exact_bridge", "conformance_vectors"}
        entries = self.bundle["artifacts"]
        self.assertEqual({entry["id"] for entry in entries}, expected_ids)
        self.assertEqual(len(entries), 5)
        self.assertEqual(len({entry["path"] for entry in entries}), 5)
        for entry in entries:
            document = self.documents[entry["id"]]
            self.assertEqual(entry["path"], ARTIFACT_PATHS[entry["id"]])
            self.assertEqual(entry["canonical_sha256"], sha256_bytes(canonical_json_v1_bytes(document)))
        bundle_text = canonical_json_v1_bytes(self.bundle).decode("utf-8")
        self.assertNotIn("bundle_sha256", bundle_text)
        self.assertNotIn("self_sha256", bundle_text)

    def test_conformance_vectors_use_copy_only_uniform_dto_and_do_not_cycle_to_bundle(self) -> None:
        self.assertEqual(
            self.vectors["result_contract"],
            {
                "fields_in_order": ["ok", "error_code", "value"],
                "success": {"ok": True, "error_code": None},
                "failure": {"ok": False, "value": None},
                "copy_only": True,
                "rejected_value_echo": "forbidden",
            },
        )
        vector_ids = [vector["id"] for vector in self.vectors["vectors"]]
        self.assertEqual(len(vector_ids), len(set(vector_ids)))
        self.assertEqual(len(vector_ids), 104)
        operations = {vector["operation"] for vector in self.vectors["vectors"]}
        self.assertTrue(
            {
                "lookup_official_card",
                "lookup_official_attack",
                "lookup_local_printing",
                "lookup_local_attack",
                "lookup_local_printing_for_official_card",
                "lookup_official_printing",
                "validate_local_source",
                "artifact_canonical_sha256",
            }.issubset(operations)
        )
        self.assertNotIn("validate_projection", operations)
        self.assertNotIn("validate_local_source_hash", operations)
        allowed_codes = set(self.vectors["stable_error_codes"])
        for vector in self.vectors["vectors"]:
            expected = vector["expected"]
            self.assertEqual(set(expected), {"ok", "error_code", "value"})
            if expected["ok"]:
                self.assertIsNone(expected["error_code"])
            else:
                self.assertIsNone(expected["value"])
                self.assertIn(expected["error_code"], allowed_codes)
                self.assertNotIn(str(vector["input"]), str(expected))
        vectors_text = canonical_json_v1_bytes(self.vectors).decode("utf-8")
        self.assertNotIn("ptcgdap-card-id-catalog-bundle-p2-wp2-v1", vectors_text)
        self.assertNotIn("bundle_sha256", vectors_text)
        by_operation: dict[str, list[dict[str, object]]] = {}
        for vector in self.vectors["vectors"]:
            by_operation.setdefault(vector["operation"], []).append(vector)
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation["lookup_local_printing"]
                    if vector["expected"]["ok"]
                ]
            ),
            9,
        )
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation["lookup_local_attack"]
                    if vector["expected"]["ok"]
                ]
            ),
            6,
        )
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation[
                        "lookup_local_printing_for_official_card"
                    ]
                    if vector["expected"]["error_code"]
                    == "official_card_unmapped"
                ]
            ),
            10,
        )
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation["lookup_official_printing"]
                    if vector["expected"]["error_code"]
                    == "official_printing_unavailable"
                ]
            ),
            8,
        )
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation["validate_local_source"]
                    if vector["expected"]["ok"]
                ]
            ),
            9,
        )
        self.assertEqual(
            len(
                [
                    vector
                    for vector in by_operation["validate_local_source"]
                    if vector["expected"]["error_code"]
                    == "local_source_hash_mismatch"
                ]
            ),
            9,
        )

    def test_schema_and_semantic_validator_reject_duplicate_owner_and_bridge_mutations(self) -> None:
        schema = self.documents["schema"]
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertFalse(schema["unevaluatedProperties"])
        self.assertEqual(schema["$defs"]["safe_integer"]["maximum"], 9007199254740991)
        self.assertEqual(schema["$defs"]["safe_integer"]["minimum"], -9007199254740991)

        duplicate = deepcopy(self.documents)
        duplicate["official_master"]["cards"][1]["official_card_id"] = duplicate["official_master"]["cards"][0]["official_card_id"]
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(duplicate)
        self.assertEqual(caught.exception.code, "master_card_order_or_duplicate")
        self.assertEqual(str(caught.exception), "master_card_order_or_duplicate")

        wrong_owner = deepcopy(self.documents)
        wrong_owner["official_master"]["attacks"][130]["owner_official_card_id"] = 7
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(wrong_owner)
        self.assertEqual(caught.exception.code, "master_attack_owner_mismatch")

        inferred_bridge = deepcopy(self.documents)
        inferred_bridge["exact_bridge"]["entries"].append(
            {
                "official_card_id": 103,
                "local_printing": {"set_code": "TWM", "card_index": "51"},
                "source_root_id": "ptcgdap",
                "source_file": "data/bundled_user/cards/CSVE1C_DAR.json",
                "source_bytes": 0,
                "source_raw_sha256": "0" * 64,
                "source_canonical_json_v1_sha256": "0" * 64,
                "local_attack_index_to_official_attack_id": {"0": 130},
            }
        )
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(inferred_bridge)
        self.assertEqual(caught.exception.code, "bridge_entry_set_mismatch")

        source_drift = deepcopy(self.documents)
        source_drift["source_manifest"]["inputs"][-1]["raw_sha256"] = "0" * 64
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(source_drift)
        self.assertEqual(caught.exception.code, "source_manifest_mismatch")

        bridge_source_drift = deepcopy(self.documents)
        bridge_source_drift["exact_bridge"]["entries"][0][
            "source_canonical_json_v1_sha256"
        ] = "0" * 64
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(bridge_source_drift)
        self.assertEqual(caught.exception.code, "bridge_entry_set_mismatch")

        vector_drift = deepcopy(self.documents)
        vector_drift["conformance_vectors"]["vectors"][0]["expected"][
            "value"
        ]["official_card_id"] = 8
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(vector_drift)
        self.assertEqual(caught.exception.code, "conformance_vectors_invalid")

        bundle_cycle = deepcopy(self.documents)
        bundle_cycle["bundle"]["artifacts"][0]["path"] = ARTIFACT_PATHS[
            "bundle"
        ]
        with self.assertRaises(CatalogBuildError) as caught:
            validate_catalog_documents(bundle_cycle)
        self.assertEqual(caught.exception.code, "catalog_bundle_invalid")

    def test_local_deck_shape_rejects_non_records_and_duplicate_printings(self) -> None:
        cases = (
            {
                "cards": [
                    {"set_code": "SET", "card_index": "1", "count": 60},
                    "not-a-record",
                ]
            },
            {
                "cards": [
                    {"set_code": "SET", "card_index": "1", "count": 30},
                    {"set_code": "SET", "card_index": "1", "count": 30},
                ]
            },
        )
        for index, value in enumerate(cases):
            with self.subTest(case=index), tempfile.TemporaryDirectory() as temp:
                path = Path(temp) / "deck.json"
                path.write_text(json.dumps(value), encoding="utf-8")
                with self.assertRaises(CatalogBuildError) as caught:
                    _load_local_deck(path)
                self.assertEqual(caught.exception.code, "local_deck_invalid")

    def test_rendered_artifacts_are_reproducible_canonical_input_with_lf_only(self) -> None:
        rendered = render_catalog_documents(self.documents)
        self.assertEqual(set(rendered), set(ARTIFACT_PATHS.values()))
        for artifact_id, relative_path in ARTIFACT_PATHS.items():
            with self.subTest(artifact=artifact_id):
                payload = rendered[relative_path]
                self.assertTrue(payload.endswith(b"\n"))
                self.assertNotIn(b"\r", payload)
                reparsed = load_json_strict(ROOT / relative_path)
                self.assertEqual(reparsed, self.documents[artifact_id])
                self.assertEqual((ROOT / relative_path).read_bytes(), payload)
                self.assertEqual(
                    hashlib.sha256(canonical_json_v1_bytes(reparsed)).hexdigest().upper(),
                    sha256_bytes(canonical_json_v1_bytes(self.documents[artifact_id])),
                )


if __name__ == "__main__":
    unittest.main()
