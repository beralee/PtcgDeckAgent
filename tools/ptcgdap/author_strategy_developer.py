from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.author_strategy_match_host import (  # noqa: E402
    AuthorStrategyMatchError,
    AuthorStrategyMatchHandleBuilder,
    AuthorStrategyShadowPrompt,
    PtcgDAPAuthorMatchHost,
)
from scripts.ai.ptcgdap.author_strategy_package import (  # noqa: E402
    AuthorStrategyPackageError,
    AuthorStrategyPackageLoader,
    WINDOWS_LOCAL_DECK_DOMAIN,
)
from scripts.ai.ptcgdap.cabt_envelope import parse_raw_cabt_envelope  # noqa: E402
from scripts.ai.ptcgdap.cabt_selection import CabtSelectionWindow  # noqa: E402
from scripts.ai.ptcgdap.competitive_policy_v2 import CompetitivePolicyV2Compiler  # noqa: E402
from scripts.ai.ptcgdap.public_deck_adapter import (  # noqa: E402
    LOCAL_CARD_ID_DOMAIN,
    OFFICIAL_CARD_ID_DOMAIN,
    PublicDeckAdapterCompiler,
    PublicDeckAdapterProposer,
    is_valid_local_card_uid,
)
from scripts.ai.ptcgdap.public_observation_firewall import PublicObservationFirewall  # noqa: E402
from scripts.ai.ptcgdap.source_lock import (  # noqa: E402
    canonical_json_v1_bytes,
    load_json_bytes_strict,
    load_json_strict,
)
from scripts.ai.ptcgdap.strategic_context_v18 import StrategicContextCompiler  # noqa: E402
from scripts.ai.ptcgdap.strategic_trace_v2 import RestrictedBaseGraphIRCompiler  # noqa: E402
from tools.ptcgdap.build_author_strategy_package import (  # noqa: E402
    FIXED_PAYLOAD_KINDS,
    GENERATED_PATHS,
    OPTIONAL_PAYLOAD_KINDS,
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
    read_source_directory,
)


DEFAULT_TEMPLATE_PACKAGE = (
    ROOT
    / "data/ptcgdap/author_strategy_packages"
    / "ptcgdap-author-strategy-release-candidate.ptcgai"
)
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
FIREWALL_VECTORS = CONTRACT_ROOT / "cabt_public_firewall_conformance_vectors.json"
STRATEGIC_CONTEXT_VECTORS = CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json"
DEVELOPMENT_FIXTURE_PRIVATE_KEY = bytes(range(32))
SCENARIO_DOCUMENT_TYPE = "author_strategy_developer_scenario_v1"
SCENARIO_KEYS = {
    "document_type",
    "schema_version",
    "scenario_id",
    "raw_observation",
    "prompt",
    "local_uid_bindings",
    "expected_selected_indexes",
}
PROMPT_KEYS = {
    "prompt_id",
    "prompt_generation",
    "mandatory_indexes",
    "terminal_indexes",
    "base_hard_tiers",
    "base_vetoed_indexes",
}
BINDING_KEYS = {"options", "acting_hand", "acting_active"}
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$")
MAX_SAFE_INTEGER = 9007199254740991


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


class DeveloperToolError(ValueError):
    def __init__(self, code: str, diagnostic: dict[str, object] | None = None) -> None:
        self.code = code
        self.diagnostic = copy.deepcopy(diagnostic)
        super().__init__(code)


def _raise(code: str, diagnostic: dict[str, object] | None = None) -> None:
    raise DeveloperToolError(code, diagnostic)


def _safe_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAX_SAFE_INTEGER


def _json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _load_template_payloads(package_path: Path) -> tuple[dict[str, bytes], dict[str, Any]]:
    try:
        handle = AuthorStrategyPackageLoader().load_path(package_path)
        metadata = handle.to_dict()
        payloads: dict[str, bytes] = {}
        for path in sorted(
            set(FIXED_PAYLOAD_KINDS) | set(OPTIONAL_PAYLOAD_KINDS),
            key=lambda value: value.encode("ascii"),
        ):
            try:
                payloads[path] = handle.payload_bytes(path)
            except KeyError:
                continue
    except (OSError, AuthorStrategyPackageError):
        _raise("developer_template_invalid")
    if GENERATED_PATHS & set(payloads) or not payloads:
        _raise("developer_template_invalid")
    return payloads, metadata


def _default_scenario() -> dict[str, object]:
    try:
        vectors = load_json_strict(FIREWALL_VECTORS)
        raw = copy.deepcopy(vectors["base_observations"]["regular"])
    except (OSError, KeyError, TypeError, UnicodeDecodeError, ValueError):
        _raise("developer_contract_invalid")
    raw["select"]["option"] = [
        {"type": 3, "area": 2, "index": 0, "playerIndex": 0},
        {"type": 3, "area": 2, "index": 1, "playerIndex": 0},
    ]
    return {
        "document_type": SCENARIO_DOCUMENT_TYPE,
        "schema_version": 1,
        "scenario_id": "marnie-morgrem-evolve",
        "raw_observation": raw,
        "prompt": {
            "prompt_id": "morgrem-evolve",
            "prompt_generation": 1,
            "mandatory_indexes": [],
            "terminal_indexes": [],
            "base_hard_tiers": [
                {"index": 0, "tier": [0]},
                {"index": 1, "tier": [0]},
            ],
            "base_vetoed_indexes": [],
        },
        "local_uid_bindings": {
            "options": [
                {"index": 0, "local_card_uid": None},
                {"index": 1, "local_card_uid": "CSV10C_146"},
            ],
            "acting_hand": [{"serial": 30, "local_card_uid": "CSV10C_147"}],
            "acting_active": [{"serial": 10, "local_card_uid": "CSV10C_148"}],
        },
        "expected_selected_indexes": [1],
    }


def scaffold_workspace(
    output: Path,
    *,
    template_package: Path = DEFAULT_TEMPLATE_PACKAGE,
) -> dict[str, object]:
    target_input = Path(output)
    if target_input.exists() or target_input.is_symlink():
        _raise("developer_output_exists")
    try:
        parent = target_input.parent.resolve(strict=True)
    except OSError:
        _raise("developer_output_parent_missing")
    if not parent.is_dir() or parent.is_symlink():
        _raise("developer_output_parent_invalid")
    target = parent / target_input.name
    try:
        resolved_template = Path(template_package).resolve(strict=True)
    except OSError:
        _raise("developer_template_invalid")
    payloads, metadata = _load_template_payloads(resolved_template)
    scenario = _default_scenario()
    temporary = Path(tempfile.mkdtemp(prefix=".ptcgdap-author-workspace-", dir=parent))
    try:
        package_root = temporary / "package"
        scenario_root = temporary / "scenarios"
        build_root = temporary / "build"
        package_root.mkdir()
        scenario_root.mkdir()
        build_root.mkdir()
        for relative, value in payloads.items():
            path = package_root / Path(relative)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(value)
        (scenario_root / "morgrem-evolve.json").write_bytes(_json_bytes(scenario))
        os.replace(temporary, target)
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
    return {
        "document_type": "author_strategy_developer_scaffold_report_v1",
        "schema_version": 1,
        "status": "scaffolded",
        "error_code": "",
        "template": {
            "package_id": metadata["package_id"],
            "package_version": metadata["package_version"],
            "archive_sha256": metadata["archive_sha256"],
        },
        "payload_file_count": len(payloads),
        "scenario_count": 1,
        "development_fixture_signature": True,
        "author_key_required": False,
        "production_authority": False,
    }


def _policy_preflight(package: Any, handle: Any) -> dict[str, object]:
    diagnostic: dict[str, object] = {
        "accepted": False,
        "owning_layer": "PtcgDAPAuthorMatchHost.create",
        "stage": "compile_policy",
        "error_code": "",
        "invalid_local_card_uids": [],
    }
    try:
        pins = handle.to_public_dict()
        if pins.get("deck_card_id_domain") == WINDOWS_LOCAL_DECK_DOMAIN:
            allowed = {
                row.get("local_card_uid")
                for row in handle.local_deck_snapshot()
                if type(row.get("local_card_uid")) is str
            }
            invalid = {uid for uid in allowed if not is_valid_local_card_uid(uid)}
            adapter = load_json_bytes_strict(package.payload_bytes("policy/adapter.json"))
            policy_ir = load_json_bytes_strict(package.payload_bytes("policy/policy_ir.json"))
            if type(adapter) is dict and type(adapter.get("rules")) is list:
                for rule in adapter["rules"]:
                    predicate = rule.get("predicate") if type(rule) is dict else None
                    if type(predicate) is not dict:
                        continue
                    for field in ("option_card_id", "acting_hand_card_id", "acting_active_card_id"):
                        uid = predicate.get(field)
                        if type(uid) is str and (not is_valid_local_card_uid(uid) or uid not in allowed):
                            invalid.add(uid)
            diagnostic["invalid_local_card_uids"] = sorted(invalid, key=str.encode)
            if type(adapter) is dict and adapter.get("schema_version") == 2:
                diagnostic["owning_layer"] = "RestrictedBaseGraphIRCompiler.compile"
                ir_outcome = RestrictedBaseGraphIRCompiler.compile(
                    policy_ir,
                    contract_root=CONTRACT_ROOT,
                )
                if not ir_outcome.accepted or ir_outcome.ir is None:
                    diagnostic["error_code"] = ir_outcome.error_code or "package_policy_unsupported"
                    _raise("package_policy_unsupported", diagnostic)
                diagnostic["owning_layer"] = "CompetitivePolicyV2Compiler.compile_local_uid"
                outcome = CompetitivePolicyV2Compiler.compile_local_uid(
                    adapter,
                    allowed_card_uids=allowed,
                )
                if not outcome.accepted or outcome.policy is None:
                    diagnostic["error_code"] = outcome.error_code or "package_policy_unsupported"
                    _raise("package_policy_unsupported", diagnostic)
                diagnostic["accepted"] = True
                return diagnostic
        PtcgDAPAuthorMatchHost.create(handle, f"dev.validate.{package.archive_sha256[:12].lower()}")
    except AuthorStrategyMatchError as exc:
        diagnostic["error_code"] = exc.code
        _raise(exc.code, diagnostic)
    except (KeyError, UnicodeDecodeError, ValueError, TypeError):
        diagnostic["error_code"] = "package_policy_unsupported"
        _raise("package_policy_unsupported", diagnostic)
    diagnostic["accepted"] = True
    return diagnostic


def _package_report(package_path: Path, *, status: str) -> dict[str, object]:
    try:
        package = AuthorStrategyPackageLoader().load_path(package_path)
        handle = AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)
        policy_preflight = _policy_preflight(package, handle)
        pins = handle.to_public_dict()
        metadata = package.to_dict()
        adapter_document = load_json_bytes_strict(package.payload_bytes("policy/adapter.json"))
    except DeveloperToolError:
        raise
    except AuthorStrategyPackageError as exc:
        _raise(exc.code)
    except AuthorStrategyMatchError as exc:
        _raise(exc.code)
    except OSError:
        _raise("package_file_missing")
    return {
        "document_type": "author_strategy_developer_package_report_v1",
        "schema_version": 1,
        "status": status,
        "error_code": "",
        "package_id": package.package_id,
        "package_version": package.package_version,
        "archive_sha256": package.archive_sha256,
        "archive_bytes": package_path.stat().st_size,
        "author_display_name": metadata["author"]["display_name"],
        "strategy_display_name": metadata["strategy"]["display_name"],
        "deck_display_name": metadata["deck"]["display_name"],
        "card_id_domain": pins["deck_card_id_domain"],
        "deck_card_count": pins["local_deck_card_count"],
        "deck_unique_printing_count": pins["local_deck_unique_printing_count"],
        "signature_status": package.signature_status,
        "signature_scope": package.signature_scope,
        "execution_trusted": package.execution_trusted,
        "development_shadow_ready": pins["development_shadow_ready"],
        "production_ready": False,
        "cabt_exportable": pins["cabt_exportable"],
        "adapter_schema_version": adapter_document.get("schema_version"),
        "policy_runtime_kind": (
            "competitive_policy_v2"
            if adapter_document.get("schema_version") == 2
            else "restricted_adapter_v1"
        ),
        "policy_preflight": policy_preflight,
    }


def build_development_package(source: Path, output: Path) -> dict[str, object]:
    output_input = Path(output)
    if output_input.exists() or output_input.is_symlink():
        _raise("developer_output_exists")
    try:
        parent = output_input.parent.resolve(strict=True)
    except OSError:
        _raise("developer_output_parent_missing")
    if not parent.is_dir() or parent.is_symlink():
        _raise("developer_output_parent_invalid")
    target = parent / output_input.name
    try:
        payloads = read_source_directory(Path(source).resolve(strict=True))
        archive = build_package_bytes(
            payloads,
            DEVELOPMENT_FIXTURE_PRIVATE_KEY,
            key_id=TEST_FIXTURE_KEY_ID,
        )
        package = AuthorStrategyPackageLoader().load_bytes(archive)
        handle = AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)
        _policy_preflight(package, handle)
    except DeveloperToolError:
        raise
    except AuthorStrategyPackageError as exc:
        _raise(exc.code)
    except AuthorStrategyMatchError as exc:
        _raise(exc.code)
    except (OSError, TypeError, ValueError):
        _raise("developer_source_invalid")
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=".ptcgdap-author-package-",
            suffix=".tmp",
            dir=parent,
            delete=False,
        ) as file:
            file.write(archive)
            temporary = Path(file.name)
        os.replace(temporary, target)
    except Exception:
        if temporary is not None and temporary.exists():
            temporary.unlink()
        raise
    return _package_report(target, status="built")


def validate_development_package(package: Path) -> dict[str, object]:
    return _package_report(Path(package).resolve(strict=False), status="valid")


def _fixed_godot_user_catalog_root(appdata_root: Path | None) -> Path:
    if appdata_root is None:
        raw_appdata = os.environ.get("APPDATA", "")
        if not raw_appdata:
            _raise("developer_user_data_unavailable")
        base = Path(raw_appdata)
    else:
        base = Path(appdata_root)
    try:
        base.mkdir(parents=True, exist_ok=True)
        resolved_base = base.resolve(strict=True)
        if base.is_symlink() or not resolved_base.is_dir():
            _raise("developer_user_data_invalid")
        target = (
            resolved_base
            / "Godot/app_userdata/PtcgDeckAgent/ptcgdap/author_strategy_packages"
        )
        target.mkdir(parents=True, exist_ok=True)
        resolved_target = target.resolve(strict=True)
    except DeveloperToolError:
        raise
    except OSError:
        _raise("developer_user_data_unavailable")
    if target.is_symlink() or not resolved_target.is_relative_to(resolved_base):
        _raise("developer_user_data_invalid")
    return resolved_target


def install_development_package(
    package: Path,
    *,
    appdata_root: Path | None = None,
) -> dict[str, object]:
    source_input = Path(package)
    if source_input.is_symlink():
        _raise("package_integrity_invalid")
    validated = validate_development_package(source_input)
    if (
        validated.get("signature_scope") != "test_fixture_only"
        or validated.get("execution_trusted") is not False
        or validated.get("production_ready") is not False
    ):
        _raise("developer_install_package_not_development")
    try:
        source = source_input.resolve(strict=True)
        archive = source.read_bytes()
    except OSError:
        _raise("package_file_missing")
    if _sha(archive) != validated["archive_sha256"]:
        _raise("package_integrity_invalid")

    catalog_root = _fixed_godot_user_catalog_root(appdata_root)
    loader = AuthorStrategyPackageLoader()
    package_id = str(validated["package_id"])
    package_version = str(validated["package_version"])
    archive_sha256 = str(validated["archive_sha256"])
    for existing in sorted(catalog_root.glob("*.ptcgai"), key=lambda path: path.name.encode("utf-8")):
        try:
            installed = loader.load_path(existing)
        except (AuthorStrategyPackageError, OSError):
            continue
        if installed.package_id != package_id or installed.package_version != package_version:
            continue
        if installed.archive_sha256 != archive_sha256:
            _raise(
                "developer_install_identity_conflict",
                {
                    "package_id": package_id,
                    "package_version": package_version,
                    "requested_archive_sha256": archive_sha256,
                    "installed_archive_sha256": installed.archive_sha256,
                },
            )
        return _install_report(validated, existing, already_installed=True)

    filename = "%s-%s-%s.ptcgai" % (
        package_id,
        package_version,
        archive_sha256[:12].lower(),
    )
    destination = catalog_root / filename
    if destination.exists() or destination.is_symlink():
        _raise("developer_install_destination_conflict")
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=".ptcgdap-author-install-",
            suffix=".tmp",
            dir=catalog_root,
            delete=False,
        ) as file:
            file.write(archive)
            temporary = Path(file.name)
        os.replace(temporary, destination)
        installed = loader.load_path(destination)
        if installed.archive_sha256 != archive_sha256:
            _raise("package_integrity_invalid")
    except DeveloperToolError:
        if temporary is not None and temporary.exists():
            temporary.unlink()
        if destination.exists() and _sha(destination.read_bytes()) != archive_sha256:
            destination.unlink()
        raise
    except (AuthorStrategyPackageError, OSError):
        if temporary is not None and temporary.exists():
            temporary.unlink()
        _raise("developer_install_failed")
    return _install_report(validated, destination, already_installed=False)


def _install_report(
    validated: dict[str, object],
    destination: Path,
    *,
    already_installed: bool,
) -> dict[str, object]:
    report = copy.deepcopy(validated)
    report.update(
        {
            "document_type": "author_strategy_developer_install_report_v1",
            "status": "installed",
            "installed_path": str(destination.resolve()),
            "install_source": "user",
            "already_installed": already_installed,
            "catalog_discoverable": True,
            "catalog_status": "metadata_only",
            "catalog_reload_required": True,
            "player_start_allowed": False,
            "match_authority": False,
            "production_authority": False,
        }
    )
    return report


def _index_list(value: object) -> bool:
    return (
        type(value) is list
        and all(_safe_int(index) for index in value)
        and len(value) == len(set(value))
    )


def _scenario_document(path: Path) -> dict[str, Any]:
    try:
        document = load_json_strict(path)
        canonical_json_v1_bytes(document)
    except (OSError, UnicodeDecodeError, ValueError, TypeError):
        _raise("developer_scenario_invalid")
    if (
        type(document) is not dict
        or set(document) != SCENARIO_KEYS
        or document.get("document_type") != SCENARIO_DOCUMENT_TYPE
        or document.get("schema_version") != 1
        or type(document.get("scenario_id")) is not str
        or IDENTIFIER.fullmatch(document["scenario_id"]) is None
        or type(document.get("raw_observation")) is not dict
        or not _index_list(document.get("expected_selected_indexes"))
    ):
        _raise("developer_scenario_invalid")
    prompt = document.get("prompt")
    if (
        type(prompt) is not dict
        or set(prompt) != PROMPT_KEYS
        or type(prompt.get("prompt_id")) is not str
        or IDENTIFIER.fullmatch(prompt["prompt_id"]) is None
        or not _safe_int(prompt.get("prompt_generation"))
        or prompt["prompt_generation"] < 1
        or not _index_list(prompt.get("mandatory_indexes"))
        or not _index_list(prompt.get("terminal_indexes"))
        or not _index_list(prompt.get("base_vetoed_indexes"))
        or type(prompt.get("base_hard_tiers")) is not list
    ):
        _raise("developer_scenario_invalid")
    bindings = document.get("local_uid_bindings")
    if bindings is not None and (type(bindings) is not dict or set(bindings) != BINDING_KEYS):
        _raise("developer_scenario_invalid")
    return document


def _local_context(
    bindings: dict[str, Any] | None,
    *,
    context_hash: str,
    window_id: str,
) -> dict[str, object] | None:
    if bindings is None:
        return None
    return {
        "schema_version": 1,
        "card_id_domain": LOCAL_CARD_ID_DOMAIN,
        "source": {"context_hash": context_hash, "window_id": window_id},
        "options": copy.deepcopy(bindings["options"]),
        "acting_hand": copy.deepcopy(bindings["acting_hand"]),
        "acting_active": copy.deepcopy(bindings["acting_active"]),
    }


def _adapter_report(
    package: Any,
    handle: Any,
    context: Any,
    local_context: dict[str, object] | None,
    scenario_id: str,
) -> dict[str, object]:
    try:
        document = load_json_bytes_strict(package.payload_bytes("policy/adapter.json"))
        pins = handle.to_public_dict()
        if pins["deck_card_id_domain"] == WINDOWS_LOCAL_DECK_DOMAIN:
            allowed = {
                row["local_card_uid"]
                for row in handle.local_deck_snapshot()
                if type(row.get("local_card_uid")) is str
            }
            outcome = PublicDeckAdapterCompiler.compile_local_uid(
                document,
                allowed_card_uids=allowed,
                deck_manifest_sha256=pins["deck_manifest_sha256"],
            )
            if not outcome.accepted or outcome.adapter is None or local_context is None:
                _raise("invalid_local_uid_public_context")
            outcome = PublicDeckAdapterCompiler.bind_local_context(
                outcome.adapter,
                context,
                local_context,
            )
        elif pins["deck_card_id_domain"] == OFFICIAL_CARD_ID_DOMAIN:
            if local_context is not None:
                _raise("invalid_local_uid_public_context")
            outcome = PublicDeckAdapterCompiler.compile(document)
        else:
            _raise("package_policy_unsupported")
        if not outcome.accepted or outcome.adapter is None:
            _raise(outcome.error_code or "package_policy_unsupported")
        proposed = PublicDeckAdapterProposer.propose(
            context,
            outcome.adapter,
            f"dev.sim.{scenario_id}.proposal",
        )
        if not proposed.accepted or proposed.result is None:
            _raise(proposed.error_code or "package_policy_unsupported")
        public = proposed.result.to_public_dict()
        return {
            "adapter_id": public["adapter_id"],
            "matched_rules": public["matched_rules"],
            "proposals": public["adapter_proposals"],
            "proposal_hash": public["proposal_hash"],
        }
    except DeveloperToolError:
        raise
    except (KeyError, UnicodeDecodeError, ValueError, TypeError):
        _raise("package_policy_unsupported")


def _adjudication_report(
    prompt: dict[str, Any],
    *,
    option_count: int,
    proposals: list[dict[str, Any]],
    selected_indexes: list[int],
) -> dict[str, object]:
    terminal = list(prompt["terminal_indexes"])
    mandatory = list(prompt["mandatory_indexes"])
    vetoed = set(prompt["base_vetoed_indexes"])
    tiers = {row["index"]: list(row["tier"]) for row in prompt["base_hard_tiers"]}
    if terminal:
        forced_owner = "terminal"
        surviving = set(terminal)
        minimum_tier: list[int] | None = None
    elif mandatory:
        forced_owner = "mandatory"
        surviving = set(mandatory)
        minimum_tier = None
    else:
        forced_owner = "none"
        minimum_tier = (
            min((tiers[index] for index in range(option_count)), key=tuple)
            if option_count > 0
            else None
        )
        surviving = (
            {
                index
                for index in range(option_count)
                if tiers[index] == minimum_tier and index not in vetoed
            }
            if minimum_tier is not None
            else set()
        )
    proposal_order: list[int] = []
    for proposal in proposals:
        for index in proposal.get("indexes", []):
            if type(index) is int and index in surviving and index not in proposal_order:
                proposal_order.append(index)
    adapter_applied = bool(
        forced_owner == "none"
        and proposal_order
        and selected_indexes
        and selected_indexes[0] == proposal_order[0]
    )
    if option_count == 0 and not selected_indexes:
        selected_source = "optional_zero"
    elif forced_owner != "none":
        selected_source = forced_owner
    elif adapter_applied:
        selected_source = "adapter_proposal"
    else:
        selected_source = "deterministic_fallback"
    candidates: list[dict[str, object]] = []
    for index in range(option_count):
        reasons: list[str] = []
        if terminal and index not in surviving:
            reasons.append("excluded_by_terminal")
        elif not terminal and mandatory and index not in surviving:
            reasons.append("excluded_by_mandatory")
        elif forced_owner == "none":
            if tiers[index] != minimum_tier:
                reasons.append("excluded_by_hard_tier")
            elif index in vetoed:
                reasons.append("excluded_by_base_veto")
        if index in surviving and index not in selected_indexes:
            reasons.append(
                "lower_adapter_preference"
                if adapter_applied and index in proposal_order
                else "not_selected_by_base_cardinality"
            )
        candidates.append(
            {
                "index": index,
                "hard_tier": tiers[index],
                "proposal_rank": proposal_order.index(index) if index in proposal_order else None,
                "selected": index in selected_indexes,
                "elimination_reasons": reasons,
            }
        )
    return {
        "forced_owner": forced_owner,
        "terminal_indexes": terminal,
        "mandatory_indexes": mandatory,
        "minimum_hard_tier": minimum_tier,
        "base_vetoed_indexes": sorted(vetoed),
        "adapter_preference_applied": adapter_applied,
        "deterministic_fallback_used": selected_source == "deterministic_fallback",
        "selected_source": selected_source,
        "candidates": candidates,
    }


def simulate_public_window(package_path: Path, scenario_path: Path) -> dict[str, object]:
    scenario = _scenario_document(Path(scenario_path))
    try:
        parsed = parse_raw_cabt_envelope(
            copy.deepcopy(scenario["raw_observation"]),
            contract_root=CONTRACT_ROOT,
        )
        firewall = PublicObservationFirewall.load_default().project(parsed)
        if not firewall.accepted:
            _raise("developer_observation_rejected")
        public = firewall.public_observation
        if type(public) is not dict or type(public.get("select")) is not dict or type(public.get("current")) is not dict:
            _raise("developer_current_window_missing")
        vectors = load_json_strict(STRATEGIC_CONTEXT_VECTORS)
        built = CabtSelectionWindow.build(
            copy.deepcopy(public["select"]),
            public_observation_hash=firewall.public_observation_hash,
            public_hash_authority=vectors["fixture"]["public_hash_authority"],
            chooser_player_index=public["current"]["yourIndex"],
        )
        if built.window is None:
            _raise("developer_current_window_invalid")
        if not built.policy_allowed:
            _raise("developer_current_window_fallback_only")
        compiled = StrategicContextCompiler.build(firewall, built.window)
        if not compiled.accepted or compiled.context is None:
            _raise(compiled.error_code or "developer_context_invalid")
        context_public = compiled.context.to_public_dict()
        local_context = _local_context(
            scenario["local_uid_bindings"],
            context_hash=context_public["context_hash"],
            window_id=built.window.window_id,
        )
        package = AuthorStrategyPackageLoader().load_path(Path(package_path))
        handle = AuthorStrategyMatchHandleBuilder.build(package, root=ROOT)
        adapter = _adapter_report(
            package,
            handle,
            compiled.context,
            local_context,
            scenario["scenario_id"],
        )
        prompt = scenario["prompt"]
        source = AuthorStrategyShadowPrompt.create(
            compiled.context,
            built.window,
            prompt_id=prompt["prompt_id"],
            prompt_generation=prompt["prompt_generation"],
            mandatory_indexes=copy.deepcopy(prompt["mandatory_indexes"]),
            terminal_indexes=copy.deepcopy(prompt["terminal_indexes"]),
            base_hard_tiers=copy.deepcopy(prompt["base_hard_tiers"]),
            base_vetoed_indexes=copy.deepcopy(prompt["base_vetoed_indexes"]),
            local_uid_public_context=local_context,
        )
        host = PtcgDAPAuthorMatchHost.create(handle, f"dev.sim.{scenario['scenario_id']}")
        host.open_current_prompt(source)
        result = host.request_current_selection()
        audit = result.to_public_dict()
    except DeveloperToolError:
        raise
    except AuthorStrategyPackageError as exc:
        _raise(exc.code)
    except AuthorStrategyMatchError as exc:
        _raise(exc.code)
    except (OSError, KeyError, TypeError, UnicodeDecodeError, ValueError):
        _raise("developer_simulation_failed")
    expected = scenario["expected_selected_indexes"]
    passed = result.indexes == expected
    return {
        "document_type": "author_strategy_developer_simulation_report_v1",
        "schema_version": 1,
        "status": "passed" if passed else "failed",
        "error_code": "" if passed else "simulation_expectation_failed",
        "scenario_id": scenario["scenario_id"],
        "package": {
            "package_id": package.package_id,
            "package_version": package.package_version,
            "archive_sha256": package.archive_sha256,
            "signature_status": package.signature_status,
            "execution_trusted": package.execution_trusted,
        },
        "frontier": {
            "public_observation_hash": built.window.public_observation_hash,
            "window_id": built.window.window_id,
            "decision_state": built.decision_state,
            "option_count": built.window.option_count,
        },
        "adapter": adapter,
        "decision": {
            "selected_indexes": result.indexes,
            "audit_hash": audit["audit_hash"],
            "decision_audit_id": audit["source"]["decision_audit_id"],
            "trace_hash": audit["source"]["trace_hash"],
        },
        "adjudication": _adjudication_report(
            prompt,
            option_count=built.window.option_count,
            proposals=adapter["proposals"],
            selected_indexes=result.indexes,
        ),
        "expectation": {"selected_indexes": copy.deepcopy(expected), "matched": passed},
        "claims": {
            "public_only": True,
            "current_window_indexes_only": True,
            "authoritative": False,
            "engine_execution": False,
            "production_authority": False,
            "classic_fallback_used": False,
        },
    }


def _write_report(path: Path, report: dict[str, object]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + ".tmp")
    temporary.write_bytes(_json_bytes(report))
    os.replace(temporary, target)


def _emit(report: dict[str, object], report_path: Path | None) -> None:
    if report_path is not None:
        _write_report(report_path, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build, validate, install, and simulate data-only PtcgDAP author strategy packages.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    scaffold = subparsers.add_parser("scaffold", help="Create an editable package workspace and scenario.")
    scaffold.add_argument("--output", type=Path, required=True)
    scaffold.add_argument("--template-package", type=Path, default=DEFAULT_TEMPLATE_PACKAGE)
    scaffold.add_argument("--report", type=Path)

    build = subparsers.add_parser("build", help="Create a deterministic test-fixture-signed .ptcgai.")
    build.add_argument("--source", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    build.add_argument("--report", type=Path)

    validate = subparsers.add_parser("validate", help="Run the strict package and exact-deck gates.")
    validate.add_argument("--package", type=Path, required=True)
    validate.add_argument("--report", type=Path)

    install = subparsers.add_parser(
        "install",
        help="Validate and install a development package into the fixed Godot user catalog.",
    )
    install.add_argument("--package", type=Path, required=True)
    install.add_argument("--report", type=Path)

    simulate = subparsers.add_parser("simulate", help="Run one public current-window policy scenario.")
    simulate.add_argument("--package", type=Path, required=True)
    simulate.add_argument("--scenario", type=Path, required=True)
    simulate.add_argument("--report", type=Path)

    args = parser.parse_args()
    try:
        if args.command == "scaffold":
            report = scaffold_workspace(args.output, template_package=args.template_package)
        elif args.command == "build":
            report = build_development_package(args.source, args.output)
        elif args.command == "validate":
            report = validate_development_package(args.package)
        elif args.command == "install":
            report = install_development_package(args.package)
        else:
            report = simulate_public_window(args.package, args.scenario)
        _emit(report, args.report)
        return 0 if report.get("status") != "failed" else 2
    except DeveloperToolError as exc:
        report = {
            "document_type": "author_strategy_developer_error_v1",
            "schema_version": 1,
            "status": "error",
            "error_code": exc.code,
            "production_authority": False,
        }
        if exc.diagnostic is not None:
            report["diagnostic"] = exc.diagnostic
        _emit(report, getattr(args, "report", None))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
