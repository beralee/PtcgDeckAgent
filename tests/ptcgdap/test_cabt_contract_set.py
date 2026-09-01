from __future__ import annotations

import copy
from dataclasses import replace
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

from scripts.ai.ptcgdap.cabt_selection import CabtSelectionContracts
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.contract_set import (
    CabtContractSet,
    MAX_CONTRACT_BYTES,
    load_contract_set,
)
from scripts.ai.ptcgdap.source_lock import (
    canonical_json_v1_bytes,
    load_json_strict,
    sha256_bytes,
)


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts" / "ptcgdap"


def _write_json(path: Path, value: object) -> None:
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _deck_hash(card_ids: list[int]) -> str:
    digest = hashlib.sha256()
    digest.update(b"PTCGDAP\x00CABT_INITIAL_DECK_V1\x00")
    digest.update(jcs_canonical_json_bytes({"card_ids": card_ids}))
    return digest.hexdigest().upper()


class CabtContractSetTests(unittest.TestCase):
    def test_verified_set_is_immutable_and_document_getters_do_not_alias(self) -> None:
        contracts = load_contract_set(CONTRACT_ROOT)
        self.assertIsInstance(contracts, CabtContractSet)
        with self.assertRaises(TypeError):
            CabtContractSet()
        with self.assertRaises(TypeError):
            replace(contracts, source_lock_id="caller-controlled")

        profile = contracts.selection_profile
        profile["profile_id"] = "caller-controlled"
        self.assertEqual(
            contracts.selection_profile["profile_id"],
            "cabt_selection_profile_v1",
        )
        selection = CabtSelectionContracts.from_contract_set(contracts)
        self.assertEqual(selection.source_contract_hash, contracts.source_contract_hash)
        self.assertFalse(hasattr(CabtSelectionContracts, "from_documents"))

        tampered = load_contract_set(CONTRACT_ROOT)
        object.__setattr__(tampered, "source_lock_id", "caller-controlled")
        self.assertFalse(tampered.is_loader_verified)
        with self.assertRaises(ValueError):
            CabtSelectionContracts.from_contract_set(tampered)

    def test_missing_bundle_rejects_before_any_selection_authority_exists(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            isolated_root = Path(directory) / "contracts" / "ptcgdap"
            shutil.copytree(CONTRACT_ROOT, isolated_root)
            (isolated_root / "cabt_contract_bundle.json").unlink()
            with self.assertRaises(OSError):
                load_contract_set(isolated_root)

    def test_self_consistent_rehashed_contract_tampering_cannot_reuse_wp3_id(self) -> None:
        mutations = (
            "pinned_authority",
            "selection_profile",
            "option_shapes",
            "enum_snapshot",
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as directory:
                isolated_root = Path(directory) / "contracts" / "ptcgdap"
                shutil.copytree(CONTRACT_ROOT, isolated_root)
                bundle_path = isolated_root / "cabt_contract_bundle.json"
                bundle = load_json_strict(bundle_path)

                if mutation in ("pinned_authority", "selection_profile"):
                    artifact_id = "selection_profile"
                    document_path = isolated_root / "cabt_selection_profile.json"
                    document = load_json_strict(document_path)
                    if mutation == "pinned_authority":
                        authority = document["initial_deck_contract"][
                            "conformance_authority"
                        ]
                        authority["card_ids"][-1] += 1
                        authority["deck_hash"] = _deck_hash(authority["card_ids"])
                    else:
                        document["input_authority"][
                            "accepted_public_hash_authorities"
                        ].append("caller_self_attested")
                elif mutation == "option_shapes":
                    artifact_id = "option_sparse_shapes"
                    document_path = isolated_root / "cabt_option_sparse_shapes.json"
                    document = load_json_strict(document_path)
                    document["shapes"]["1"].append("serial")
                else:
                    artifact_id = "enum_snapshot"
                    document_path = isolated_root / "cabt_enum_snapshot.json"
                    document = load_json_strict(document_path)
                    document["enums"]["AreaType"]["CALLER_FUTURE"] = 99

                _write_json(document_path, document)
                new_hash = sha256_bytes(canonical_json_v1_bytes(document))
                entry = next(
                    item for item in bundle["artifacts"] if item["id"] == artifact_id
                )
                entry["canonical_sha256"] = new_hash
                _write_json(bundle_path, bundle)

                internally_reloaded = load_json_strict(document_path)
                self.assertEqual(
                    sha256_bytes(canonical_json_v1_bytes(internally_reloaded)),
                    new_hash,
                )
                with self.assertRaises(ValueError):
                    load_contract_set(isolated_root)

    def test_bundle_and_artifact_raw_bytes_share_the_godot_two_mib_limit(self) -> None:
        cases = (
            "cabt_contract_bundle.json",
            "cabt_enum_snapshot.json",
        )
        for filename in cases:
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as directory:
                isolated_root = Path(directory) / "contracts" / "ptcgdap"
                shutil.copytree(CONTRACT_ROOT, isolated_root)
                path = isolated_root / filename
                original = path.read_bytes()
                path.write_bytes(b" " * (MAX_CONTRACT_BYTES + 1) + original)
                with self.assertRaises(ValueError):
                    load_contract_set(isolated_root)

        with tempfile.TemporaryDirectory() as directory:
            isolated_root = Path(directory) / "contracts" / "ptcgdap"
            shutil.copytree(CONTRACT_ROOT, isolated_root)
            bundle_path = isolated_root / "cabt_contract_bundle.json"
            original = bundle_path.read_bytes()
            bundle_path.write_bytes(
                b" " * (MAX_CONTRACT_BYTES - len(original)) + original
            )
            contracts = load_contract_set(isolated_root)
            self.assertTrue(contracts.is_loader_verified)


if __name__ == "__main__":
    unittest.main()
