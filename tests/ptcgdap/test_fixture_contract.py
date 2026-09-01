from __future__ import annotations

import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.fixture_contract import (
    FixtureContractError,
    MAX_FIXTURE_FILE_BYTES,
    canonical_sha256,
    load_public_fixture,
    verify_fixture_catalog,
)


FIXTURE_MANIFEST = ROOT / "tests" / "ptcgdap" / "fixtures" / "fixtures_manifest.json"
ORACLE_ROOT = Path(os.environ.get("PTCGABC_ORACLE_ROOT", ROOT.parent / "ptcgabc"))
FIXTURE_CATALOG_CANONICAL_SHA256 = "A210E518F5D045F718F66A1FD92925D43B5C567C307EBBC1DF795F993CD1A658"
SOURCE_LOCK = ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json"
SOURCE_LOCK_CANONICAL_SHA256 = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"


class FixtureContractTests(unittest.TestCase):
    def _write_public_catalog(self, root: Path, payload: object) -> Path:
        public_dir = root / "public"
        public_dir.mkdir()
        fixture_path = public_dir / "observation.json"
        fixture_bytes = (json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
        fixture_path.write_bytes(fixture_bytes)
        manifest = {
            "schema_version": 1,
            "fixtures": [
                {
                    "id": "observation",
                    "path": "public/observation.json",
                    "classification": "public_agent_observation",
                    "runtime_agent_callback_input": True,
                    "runtime_policy_input": False,
                    "byte_sha256": hashlib.sha256(fixture_bytes).hexdigest().upper(),
                    "canonical_sha256": canonical_sha256(payload),
                    "covers": ["privacy_negative_control"],
                    "provenance": {
                        "source_kind": "synthetic",
                        "derivation": "exact_copy",
                        "sanitization": "none",
                    },
                    "expected": {},
                }
            ],
        }
        manifest_path = root / "fixtures_manifest.json"
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        return manifest_path

    def test_repository_golden_catalog_is_self_consistent(self) -> None:
        report = verify_fixture_catalog(FIXTURE_MANIFEST)

        self.assertTrue(report.ok, report.to_dict())
        self.assertGreaterEqual(report.public_fixture_count, 6)
        self.assertGreaterEqual(report.private_fixture_count, 1)

    def test_repository_golden_catalog_reproduces_locked_oracle_sources(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        report = verify_fixture_catalog(
            FIXTURE_MANIFEST,
            verify_sources=True,
            root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
            trusted_source_lock_path=SOURCE_LOCK,
            expected_source_lock_sha256=SOURCE_LOCK_CANONICAL_SHA256,
        )

        self.assertTrue(report.ok, report.to_dict())

    def test_private_negative_control_cannot_be_loaded_as_agent_callback_fixture(self) -> None:
        with self.assertRaises(FixtureContractError):
            load_public_fixture(
                FIXTURE_MANIFEST,
                "private_replay_negative_control",
                expected_catalog_canonical_sha256=FIXTURE_CATALOG_CANONICAL_SHA256,
            )

    def test_public_loader_requires_an_external_catalog_trust_anchor(self) -> None:
        with self.assertRaises(FixtureContractError):
            load_public_fixture(
                FIXTURE_MANIFEST,
                "initial_callback",
                expected_catalog_canonical_sha256="0" * 64,
            )

    def test_misclassified_replay_container_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_dir = root / "public"
            public_dir.mkdir()
            payload = {
                "steps": [],
                "visualize": {"private_deck_order": [1, 2, 3]},
            }
            fixture_path = public_dir / "bad.json"
            fixture_bytes = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
            fixture_path.write_bytes(fixture_bytes)
            manifest = {
                "schema_version": 1,
                "fixtures": [
                    {
                        "id": "bad",
                        "path": "public/bad.json",
                        "classification": "public_agent_observation",
                        "runtime_agent_callback_input": True,
                        "runtime_policy_input": False,
                        "byte_sha256": hashlib.sha256(fixture_bytes).hexdigest().upper(),
                        "canonical_sha256": canonical_sha256(payload),
                        "covers": ["private_replay_rejection"],
                        "provenance": {
                            "source_kind": "synthetic_negative_control",
                            "derivation": "exact_copy",
                            "sanitization": "none",
                        },
                        "expected": {},
                    }
                ],
            }
            manifest_path = root / "fixtures_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(manifest_path)

            self.assertFalse(report.ok)
            self.assertIn("not_raw_agent_observation", {issue.code for issue in report.issues})

    def test_fixture_byte_drift_is_detected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_dir = root / "public"
            public_dir.mkdir()
            observation = {
                "select": None,
                "logs": [],
                "current": None,
                "search_begin_input": None,
            }
            fixture_path = public_dir / "initial.json"
            expected_bytes = (json.dumps(observation, sort_keys=True) + "\n").encode("utf-8")
            fixture_path.write_bytes(expected_bytes + b" ")
            manifest = {
                "schema_version": 1,
                "fixtures": [
                    {
                        "id": "initial",
                        "path": "public/initial.json",
                        "classification": "public_agent_observation",
                        "runtime_agent_callback_input": True,
                        "runtime_policy_input": False,
                        "byte_sha256": hashlib.sha256(expected_bytes).hexdigest().upper(),
                        "canonical_sha256": canonical_sha256(observation),
                        "covers": ["initial_callback"],
                        "provenance": {
                            "source_kind": "synthetic",
                            "derivation": "declared_mutation",
                            "sanitization": "none",
                        },
                        "expected": {},
                    }
                ],
            }
            manifest_path = root / "fixtures_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(manifest_path)

            self.assertFalse(report.ok)
            self.assertIn("fixture_byte_hash_mismatch", {issue.code for issue in report.issues})

    def test_declared_private_shapes_are_rejected_across_nested_fields(self) -> None:
        base = json.loads(
            (FIXTURE_MANIFEST.parent / "public" / "normal_single_select.json").read_text(encoding="utf-8")
        )

        cases = {
            "non_null_search": (
                lambda value: value.__setitem__("search_begin_input", "must-not-persist"),
                "unredacted_search_token",
            ),
            "invalid_seat_context": (
                lambda value: value["current"].__setitem__("yourIndex", "0"),
                "invalid_your_index",
            ),
            "invalid_players": (
                lambda value: value["current"].__setitem__("players", {}),
                "invalid_players_shape",
            ),
            "opponent_hand": (
                lambda value: value["current"]["players"][1].__setitem__("hand", [{"id": 1, "serial": 2}]),
                "opponent_hand_identity",
            ),
            "stadium_name": (
                lambda value: value["current"].__setitem__("stadium", [{"id": 1, "name": "private"}]),
                "visualizer_card_name",
            ),
            "case_variant_name": (
                lambda value: value["select"]["option"][0].__setitem__("Name", "private"),
                "visualizer_card_name",
            ),
            "nested_rng": (
                lambda value: value.__setitem__("futureHostField", {"private_rng_state": 123}),
                "private_replay_container_field",
            ),
            "nested_search": (
                lambda value: value["select"].__setitem__("search_begin_input", "copy"),
                "nested_search_capability",
            ),
            "root_search_case_alias": (
                lambda value: value.__setitem__("SearchBeginInput", "secret"),
                "nested_search_capability",
            ),
            "player_deck_order": (
                lambda value: value["current"]["players"][0].__setitem__("deck", [{"id": 1}]),
                "private_deck_order",
            ),
            "nested_deck_case_alias": (
                lambda value: value.__setitem__("futureHostField", {"Deck": [{"id": 1}]}),
                "private_deck_order",
            ),
            "reverse_log_identity": (
                lambda value: value.__setitem__("logs", [{"type": 5, "playerIndex": 1, "cardId": 1, "serial": 2}]),
                "reverse_log_identity",
            ),
            "string_reverse_log": (
                lambda value: value.__setitem__("logs", [{"type": "5", "playerIndex": 1, "cardId": 1, "serial": 2}]),
                "invalid_log_type",
            ),
            "opponent_select_deck": (
                lambda value: value["select"].__setitem__(
                    "deck", [{"id": 1, "playerIndex": 1, "serial": 2}]
                ),
                "unauthorized_select_deck_identity",
            ),
        }
        for name, (mutate, expected_code) in cases.items():
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                payload = json.loads(json.dumps(base))
                mutate(payload)
                manifest_path = self._write_public_catalog(Path(directory), payload)

                report = verify_fixture_catalog(manifest_path)

                self.assertFalse(report.ok)
                self.assertIn(expected_code, {issue.code for issue in report.issues})

    def test_deep_fixture_tree_returns_a_bounded_parse_issue(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_dir = root / "public"
            public_dir.mkdir()
            nested: object = "leaf"
            for _ in range(140):
                nested = {"next": nested}
            payload = {
                "select": None,
                "logs": [],
                "current": None,
                "search_begin_input": None,
                "future": nested,
            }
            fixture_path = public_dir / "deep.json"
            fixture_bytes = json.dumps(payload).encode("utf-8")
            fixture_path.write_bytes(fixture_bytes)
            manifest = {
                "schema_version": 1,
                "catalog_id": "deep-negative-control",
                "source_lock_id": "ptcgdap-test-lock",
                "source_lock_canonical_sha256": "0" * 64,
                "source_lock_locator_hint": "unused",
                "search_token_persistence_policy": (
                    "Real search_begin_input values are never persisted. Persisted payloads always use null; "
                    "provenance records only whether the source value was null or non-null."
                ),
                "fixtures": [
                    {
                        "id": "deep",
                        "path": "public/deep.json",
                        "classification": "public_agent_observation",
                        "runtime_agent_callback_input": True,
                        "runtime_policy_input": False,
                        "byte_sha256": hashlib.sha256(fixture_bytes).hexdigest().upper(),
                        "canonical_sha256": "0" * 64,
                        "covers": ["bounded_json"],
                        "provenance": {
                            "source_kind": "synthetic",
                            "derivation": "exact_copy",
                            "sanitization": "none",
                        },
                    }
                ],
            }
            manifest_path = root / "fixtures_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(manifest_path)

            self.assertFalse(report.ok)
            self.assertIn("fixture_parse_error", {issue.code for issue in report.issues})
            self.assertIn("128-level", report.issues[-1].detail)

    def test_oversized_fixture_is_rejected_before_json_loading(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_dir = root / "public"
            public_dir.mkdir()
            fixture_path = public_dir / "oversized.json"
            with fixture_path.open("wb") as stream:
                stream.truncate(MAX_FIXTURE_FILE_BYTES + 1)
            manifest = {
                "schema_version": 1,
                "catalog_id": "oversized-negative-control",
                "source_lock_id": "ptcgdap-test-lock",
                "source_lock_canonical_sha256": "0" * 64,
                "source_lock_locator_hint": "unused",
                "search_token_persistence_policy": (
                    "Real search_begin_input values are never persisted. Persisted payloads always use null; "
                    "provenance records only whether the source value was null or non-null."
                ),
                "fixtures": [
                    {
                        "id": "oversized",
                        "path": "public/oversized.json",
                        "classification": "public_agent_observation",
                        "runtime_agent_callback_input": True,
                        "runtime_policy_input": False,
                        "byte_sha256": "0" * 64,
                        "canonical_sha256": "0" * 64,
                        "covers": ["bounded_json"],
                        "provenance": {
                            "source_kind": "synthetic",
                            "derivation": "exact_copy",
                            "sanitization": "none",
                        },
                    }
                ],
            }
            manifest_path = root / "fixtures_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(manifest_path)

            issue = next(item for item in report.issues if item.code == "fixture_parse_error")
            self.assertIn(f"{MAX_FIXTURE_FILE_BYTES}-byte", issue.detail)

    def test_fixture_path_resolution_error_returns_an_issue(self) -> None:
        with mock.patch(
            "scripts.ai.ptcgdap.fixture_contract.Path.resolve",
            side_effect=OSError("synthetic path failure"),
        ):
            report = verify_fixture_catalog(FIXTURE_MANIFEST)

        self.assertFalse(report.ok)
        self.assertIn("unsafe_fixture_path", {issue.code for issue in report.issues})

    def test_public_provenance_cannot_select_visualizer_private_state(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        with tempfile.TemporaryDirectory() as directory:
            copied_root = Path(directory) / "fixtures"
            shutil.copytree(FIXTURE_MANIFEST.parent, copied_root)
            manifest_path = copied_root / "fixtures_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["fixtures"][0]["provenance"]["source_selector"] = "/steps/0/0/visualize"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(
                manifest_path,
                verify_sources=True,
                root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
                trusted_source_lock_path=SOURCE_LOCK,
                expected_source_lock_sha256=SOURCE_LOCK_CANONICAL_SHA256,
            )

            self.assertFalse(report.ok)
            self.assertIn("fixture_source_verification_error", {issue.code for issue in report.issues})

    def test_source_verification_requires_locked_extraction_for_public_observations(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        with tempfile.TemporaryDirectory() as directory:
            copied_root = Path(directory) / "fixtures"
            shutil.copytree(FIXTURE_MANIFEST.parent, copied_root)
            manifest_path = copied_root / "fixtures_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["fixtures"][0]["provenance"]["derivation"] = "exact_copy"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(
                manifest_path,
                verify_sources=True,
                root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
                trusted_source_lock_path=SOURCE_LOCK,
                expected_source_lock_sha256=SOURCE_LOCK_CANONICAL_SHA256,
            )

            self.assertFalse(report.ok)
            self.assertIn("fixture_source_verification_error", {issue.code for issue in report.issues})

    def test_source_verification_rejects_a_substitute_lock_with_the_same_id(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            copied_root = root / "fixtures"
            shutil.copytree(FIXTURE_MANIFEST.parent, copied_root)
            fake_lock_path = root / "SOURCE_LOCK.json"
            fake_lock = json.loads(
                (ROOT / "docs" / "ptcgdap" / "SOURCE_LOCK.json").read_text(encoding="utf-8")
            )
            fake_lock["status"] = "substituted_without_new_lock_id"
            fake_lock_path.write_text(json.dumps(fake_lock), encoding="utf-8")
            manifest_path = copied_root / "fixtures_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["source_lock_locator_hint"] = str(fake_lock_path)
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(
                manifest_path,
                verify_sources=True,
                root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
                trusted_source_lock_path=fake_lock_path,
                expected_source_lock_sha256=SOURCE_LOCK_CANONICAL_SHA256,
            )

            self.assertFalse(report.ok)
            self.assertIn("fixture_source_verification_error", {issue.code for issue in report.issues})

    def test_non_string_mutation_pointer_returns_a_report_instead_of_crashing(self) -> None:
        if not ORACLE_ROOT.is_dir():
            self.skipTest("official oracle integration requires PTCGABC_ORACLE_ROOT")
        with tempfile.TemporaryDirectory() as directory:
            copied_root = Path(directory) / "fixtures"
            shutil.copytree(FIXTURE_MANIFEST.parent, copied_root)
            manifest_path = copied_root / "fixtures_manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            unknown = next(item for item in manifest["fixtures"] if item["id"] == "unknown_additive_and_enum")
            unknown["provenance"]["mutations"][0]["path"] = ["not", "a", "pointer"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(
                manifest_path,
                verify_sources=True,
                root_overrides={"ptcgabc": ORACLE_ROOT, "ptcgdap": ROOT},
                trusted_source_lock_path=SOURCE_LOCK,
                expected_source_lock_sha256=SOURCE_LOCK_CANONICAL_SHA256,
            )

            self.assertFalse(report.ok)
            self.assertIn("fixture_source_verification_error", {issue.code for issue in report.issues})

    def test_nonstandard_nan_fixture_returns_a_parse_issue(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            public_dir = root / "public"
            public_dir.mkdir()
            fixture_path = public_dir / "bad.json"
            fixture_bytes = (
                b'{"select":null,"logs":[],"current":null,'
                b'"search_begin_input":null,"future":NaN}\n'
            )
            fixture_path.write_bytes(fixture_bytes)
            manifest = {
                "schema_version": 1,
                "catalog_id": "nan-negative-control",
                "source_lock_id": "ptcgdap-source-lock-2026-08-09-p1wp1",
                "source_lock_canonical_sha256": SOURCE_LOCK_CANONICAL_SHA256,
                "source_lock_path": "unused",
                "search_token_persistence_policy": (
                    "Real search_begin_input values are never persisted. Persisted payloads always use null; "
                    "provenance records only whether the source value was null or non-null."
                ),
                "fixtures": [
                    {
                        "id": "bad",
                        "path": "public/bad.json",
                        "classification": "public_agent_observation",
                        "runtime_agent_callback_input": True,
                        "runtime_policy_input": False,
                        "byte_sha256": hashlib.sha256(fixture_bytes).hexdigest().upper(),
                        "canonical_sha256": "0" * 64,
                        "covers": ["malformed_json"],
                        "provenance": {
                            "source_kind": "synthetic",
                            "derivation": "exact_copy",
                            "sanitization": "none",
                        },
                        "expected": {},
                    }
                ],
            }
            manifest_path = root / "fixtures_manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            report = verify_fixture_catalog(manifest_path)

            self.assertFalse(report.ok)
            self.assertIn("fixture_parse_error", {issue.code for issue in report.issues})


if __name__ == "__main__":
    unittest.main()
