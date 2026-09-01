from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any, Mapping
import zipfile

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes, load_json_bytes_strict, load_json_strict


MANIFEST_PATH = Path("data/ptcgdap/marnie_windows_policy_package_v1.json")
SEALED_D051_RELEASE_BUNDLE_CANONICAL = "8C023680073C8CD0B7A423B07B840629812B2043305EA16411765A44F7F4D1EB"
SEALED_D051_ROLLBACK_PROFILE_CANONICAL = "01FCA4ED2B6228732AE91B5934F1A93272F92A2EC0B144E2695616C55BE7BF07"
EXPECTED_TOP_KEYS = frozenset({
    "document_type", "schema_version", "package_id", "package_version", "authority_scope",
    "target", "author_package", "contracts", "executor", "model", "trace", "capabilities",
    "fallback", "parents", "rollback",
})


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _canonical_sha(path: Path) -> str:
    return _sha(canonical_json_v1_bytes(load_json_strict(path)))


def _result(accepted: bool, error_code: str, **values: object) -> dict[str, object]:
    return {"accepted": accepted, "error_code": error_code, **values}


class PolicyPackageVerifier:
    """Fail-closed verifier for the immutable Windows policy manifest.

    This verifier owns build/install-time integrity only. It does not grant
    production trust, device approval, player-live authority, or A5 status.
    """

    __slots__ = ("_root",)

    def __init__(self, root: Path) -> None:
        resolved = root.resolve()
        if not resolved.is_dir():
            raise ValueError("policy package root missing")
        self._root = resolved

    def verify(self, document: Mapping[str, Any] | None = None) -> dict[str, object]:
        try:
            value: Any = load_json_strict(self._root / MANIFEST_PATH) if document is None else document
        except (OSError, UnicodeDecodeError, ValueError):
            return _result(False, "policy_package_document_missing")
        if not self._shape_valid(value):
            return _result(False, "policy_package_schema_invalid")
        manifest = dict(value)

        if not self._identity_valid(manifest):
            return _result(False, "policy_package_identity_mismatch")
        author = manifest["author_package"]
        archive_path = self._root / author["path"]
        try:
            archive_bytes = archive_path.read_bytes()
        except OSError:
            return _result(False, "policy_package_archive_mismatch")
        if _sha(archive_bytes) != author["archive_sha256"]:
            return _result(False, "policy_package_archive_mismatch")

        try:
            with zipfile.ZipFile(archive_path, "r") as archive:
                names = archive.namelist()
                if len(names) != len(set(names)):
                    return _result(False, "policy_package_archive_mismatch")
                members = {name: archive.read(name) for name in names}
        except (OSError, KeyError, zipfile.BadZipFile):
            return _result(False, "policy_package_archive_mismatch")
        if not self._members_valid(author, members):
            return _result(False, "policy_package_member_mismatch")

        try:
            expected_contracts = self._expected_contracts()
        except (OSError, UnicodeDecodeError, ValueError):
            return _result(False, "policy_package_contract_mismatch")
        if manifest["contracts"] != expected_contracts or manifest["trace"] != {
            "profile": "strategic_trace_v2",
            "bundle_canonical_sha256": expected_contracts["strategic_trace_v2_bundle_canonical_sha256"],
        }:
            return _result(False, "policy_package_contract_mismatch")
        try:
            expected_executor = self._expected_executor()
        except (OSError, UnicodeDecodeError, ValueError):
            return _result(False, "policy_package_executor_mismatch")
        if manifest["executor"] != expected_executor:
            return _result(False, "policy_package_executor_mismatch")
        if manifest["model"] != {
            "learned_model": "none",
            "backend": "none",
            "artifact_path": None,
            "artifact_sha256": None,
            "unexpected_fallback_expected": 0,
        }:
            return _result(False, "policy_package_model_mismatch")
        try:
            expected_parents = self._expected_parents()
        except (OSError, UnicodeDecodeError, ValueError):
            return _result(False, "policy_package_parent_mismatch")
        if manifest["parents"] != expected_parents:
            return _result(False, "policy_package_parent_mismatch")
        try:
            expected_rollback = self._expected_rollback()
        except (OSError, UnicodeDecodeError, ValueError):
            return _result(False, "policy_package_rollback_mismatch")
        if manifest["rollback"] != expected_rollback:
            return _result(False, "policy_package_rollback_mismatch")
        if manifest["capabilities"] != self._expected_capabilities() or manifest["fallback"] != {
            "owner": "restricted_base_graph",
            "mode": "deterministic_same_window",
            "remote": False,
            "classic_raw_state": False,
        }:
            return _result(False, "policy_package_integrity_invalid")
        return _result(
            True,
            "",
            package_id=manifest["package_id"],
            package_version=manifest["package_version"],
            archive_sha256=author["archive_sha256"],
            learned_model="none",
            execution_location="device_local",
            manifest_canonical_sha256=_sha(canonical_json_v1_bytes(manifest)),
            production_ready=False,
        )

    @staticmethod
    def _shape_valid(value: Any) -> bool:
        if type(value) is not dict or set(value) != EXPECTED_TOP_KEYS:
            return False
        nested_keys = {
            "target": {"host", "platform", "architecture", "execution_location"},
            "author_package": {"path", "package_id", "package_version", "archive_sha256", "manifest_sha256", "deck_manifest_sha256", "policy_ir_sha256", "adapter_sha256", "config_sha256", "weights"},
            "contracts": {"cabt_contract_canonical_sha256", "card_catalog_bundle_canonical_sha256", "base_executor_bundle_canonical_sha256", "public_deck_adapter_bundle_canonical_sha256", "strategic_trace_v2_bundle_canonical_sha256", "source_lock_canonical_sha256"},
            "executor": {"kind", "portable_baseline", "host_adapter_path", "host_adapter_sha256", "base_executor_path", "base_executor_sha256", "match_owner_path", "match_owner_sha256", "engine_action_executor_path", "engine_action_executor_sha256", "policy_boundary"},
            "model": {"learned_model", "backend", "artifact_path", "artifact_sha256", "unexpected_fallback_expected"},
            "trace": {"profile", "bundle_canonical_sha256"},
            "capabilities": {"cabt_search", "seeded_offline", "card_id_domain", "cabt_exportable", "network_ingress", "network_egress", "system_python", "external_process", "dynamic_model_download", "policy_output"},
            "fallback": {"owner", "mode", "remote", "classic_raw_state"},
            "parents": {"author_package_bundle_canonical_sha256", "author_match_host_bundle_canonical_sha256", "author_live_seam_bundle_canonical_sha256", "author_release_bundle_canonical_sha256", "source_lock_canonical_sha256"},
            "rollback": {"mode", "target_kind", "target_path", "target_canonical_sha256", "current_match_hot_swap", "user_packages_preserved"},
        }
        for key, keys in nested_keys.items():
            if type(value.get(key)) is not dict or set(value[key]) != keys:
                return False
        weights = value["author_package"].get("weights")
        return type(weights) is dict and set(weights) == {"path", "sha256", "status"}

    @staticmethod
    def _identity_valid(value: dict[str, Any]) -> bool:
        return (
            value["document_type"] == "policy_package_v1"
            and value["schema_version"] == 1
            and value["package_id"] == "ptcgdap.marnie.windows-local.policy"
            and value["package_version"] == "0.1.0"
            and value["authority_scope"] == "development_and_device_canary_only"
            and value["target"] == {
                "host": "godot", "platform": "windows", "architecture": "x86_64", "execution_location": "device_local"
            }
            and value["author_package"].get("path") == MANIFEST_PATH.parent.joinpath(
                "author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
            ).as_posix()
            and value["author_package"].get("package_id") == "ptcgdap.marnie.windows-local"
            and value["author_package"].get("package_version") == "0.1.0"
        )

    @staticmethod
    def _members_valid(author: dict[str, Any], members: dict[str, bytes]) -> bool:
        expected = {
            "manifest_sha256": "strategy_package.json",
            "deck_manifest_sha256": "deck/deck_manifest.json",
            "policy_ir_sha256": "policy/policy_ir.json",
            "adapter_sha256": "policy/adapter.json",
            "config_sha256": "policy/config.json",
        }
        try:
            if any(_sha(members[path]) != author[field] for field, path in expected.items()):
                return False
            weights = author["weights"]
            if weights != {
                "path": "policy/weights.bin",
                "sha256": _sha(members["policy/weights.bin"]),
                "status": "unused_non_model_payload",
            }:
                return False
            strategy = load_json_bytes_strict(members["strategy_package.json"])
        except (KeyError, UnicodeDecodeError, ValueError):
            return False
        return type(strategy) is dict and strategy.get("package_id") == author["package_id"] and strategy.get("package_version") == author["package_version"]

    def _expected_contracts(self) -> dict[str, str]:
        return {
            "cabt_contract_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/cabt_contract_bundle.json"),
            "card_catalog_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/card_id_catalog_bundle.json"),
            "base_executor_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/restricted_base_graph_executor_bundle.json"),
            "public_deck_adapter_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/public_deck_adapter_bundle.json"),
            "strategic_trace_v2_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/strategic_trace_v2_bundle.json"),
            "source_lock_canonical_sha256": _canonical_sha(self._root / "docs/ptcgdap/SOURCE_LOCK.json"),
        }

    def _expected_executor(self) -> dict[str, object]:
        host = "scripts/ai/ptcgdap/runtime/local/AuthorStrategyDevelopmentPolicy.gd"
        base = "scripts/ai/ptcgdap/public/RestrictedBaseGraphExecutor.gd"
        owner = "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd"
        action = "scripts/ai/ptcgdap/host/godot/AuthorStrategyEngineActionExecutor.gd"
        return {
            "kind": "gdscript_restricted_ir_v1",
            "portable_baseline": "gdscript",
            "host_adapter_path": host,
            "host_adapter_sha256": _sha((self._root / host).read_bytes()),
            "base_executor_path": base,
            "base_executor_sha256": _sha((self._root / base).read_bytes()),
            "match_owner_path": owner,
            "match_owner_sha256": _sha((self._root / owner).read_bytes()),
            "engine_action_executor_path": action,
            "engine_action_executor_sha256": _sha((self._root / action).read_bytes()),
            "policy_boundary": "agent(raw_observation)->list[int]",
        }

    def _expected_parents(self) -> dict[str, str]:
        return {
            "author_package_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/author_strategy_package_bundle.json"),
            "author_match_host_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/author_strategy_match_host_bundle.json"),
            "author_live_seam_bundle_canonical_sha256": _canonical_sha(self._root / "contracts/ptcgdap/author_strategy_live_seam_bundle.json"),
            "author_release_bundle_canonical_sha256": SEALED_D051_RELEASE_BUNDLE_CANONICAL,
            "source_lock_canonical_sha256": _canonical_sha(self._root / "docs/ptcgdap/SOURCE_LOCK.json"),
        }

    def _expected_rollback(self) -> dict[str, object]:
        path = "contracts/ptcgdap/author_strategy_release_profile.json"
        return {
            "mode": "disable_author_strategy_for_new_matches",
            "target_kind": "author_strategy_disabled_release_profile",
            "target_path": path,
            "target_canonical_sha256": SEALED_D051_ROLLBACK_PROFILE_CANONICAL,
            "current_match_hot_swap": False,
            "user_packages_preserved": True,
        }

    @staticmethod
    def _expected_capabilities() -> dict[str, object]:
        return {
            "cabt_search": "none",
            "seeded_offline": False,
            "card_id_domain": "godot_local_card_uid_v1",
            "cabt_exportable": False,
            "network_ingress": False,
            "network_egress": False,
            "system_python": False,
            "external_process": False,
            "dynamic_model_download": False,
            "policy_output": "current_window_indexes_only",
        }
