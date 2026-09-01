from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
from typing import Any, Mapping

from .source_lock import canonical_json_v1_bytes


LEGACY_ENTRYPOINTS = (
    "get_interaction_steps",
    "get_preview_interaction_steps",
    "get_on_play_interaction_steps",
    "get_attack_interaction_steps",
    "get_attack_preview_interaction_steps",
    "get_followup_interaction_steps",
    "get_followup_attack_interaction_steps",
    "get_granted_attack_interaction_steps",
    "get_followup_granted_attack_interaction_steps",
    "get_knockout_interaction_steps",
    "get_end_turn_interaction_steps",
    "get_reactive_interaction_steps",
    "get_trigger_interaction_steps",
)
UCIS_BUILDERS = tuple(f"build_ucis_{name[4:]}_spec_steps" for name in LEGACY_ENTRYPOINTS)
FORBIDDEN_AUTHORITY = (
    "BattleScene",
    "DecisionPort",
    "A3ExternalDecisionPort",
    "AIStepResolver",
    "_pending_choice",
    "ActionTicket",
)
LEGACY_AUTHOR_TOKENS = ("cabt_",)


def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _load_card(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    value = json.loads(raw.decode("utf-8"))
    if type(value) is not dict:
        raise ValueError("ucis_catalog_card_document_invalid")
    return value


def build_ucis_catalog(repository_root: str | Path) -> dict[str, Any]:
    from .ucis import UcisRegistry

    root = Path(repository_root).resolve()
    registry = UcisRegistry.load(root)
    effect_root = root / "scripts/effects"
    source_files = sorted(effect_root.rglob("*.gd"))
    legacy_overrides: list[str] = []
    authority_violations: list[str] = []
    builder_occurrences: list[dict[str, Any]] = []
    source_manifest: list[dict[str, Any]] = []
    for path in source_files:
        relative = path.relative_to(root).as_posix()
        raw = path.read_bytes()
        source = raw.decode("utf-8-sig")
        source_manifest.append({"path": relative, "raw_sha256": _sha_bytes(raw)})
        if path.name != "BaseEffect.gd":
            for method in LEGACY_ENTRYPOINTS:
                if re.search(rf"\b{re.escape(method)}\s*\(", source):
                    legacy_overrides.append(f"{relative}:{method}")
            for token in FORBIDDEN_AUTHORITY:
                if token in source:
                    authority_violations.append(f"{relative}:{token}")
            for token in LEGACY_AUTHOR_TOKENS:
                if token in source:
                    legacy_overrides.append(f"{relative}:{token}")
        for method in UCIS_BUILDERS:
            count = len(re.findall(rf"(?m)^\s*func\s+{re.escape(method)}\s*\(", source))
            if count:
                builder_occurrences.append(
                    {"path": relative, "builder": method, "occurrences": count}
                )

    card_files = sorted((root / "data/bundled_user/cards").glob("*.json"))
    cards: list[dict[str, Any]] = []
    card_documents: dict[str, tuple[Path, dict[str, Any]]] = {}
    for path in card_files:
        document = _load_card(path)
        set_code = str(document.get("set_code", "")).strip()
        card_index = str(document.get("card_index", "")).strip()
        effect_id = str(document.get("effect_id", "")).strip()
        if not set_code or not card_index or not effect_id:
            raise ValueError("ucis_catalog_card_identity_invalid")
        uid = f"{set_code}_{card_index}"
        raw_hash = _sha_bytes(path.read_bytes())
        cards.append(
            {
                "card_uid": uid,
                "effect_id": effect_id,
                "source_path": path.relative_to(root).as_posix(),
                "source_sha256": raw_hash,
                "status": "pending_runtime_attestation",
            }
        )
        card_documents[uid] = (path, document)

    attestation_path = root / "contracts/ptcgdap/ucis_runtime_attestation_v1.json"
    if not attestation_path.is_file():
        raise ValueError("ucis_runtime_attestation_missing")
    attestation = json.loads(attestation_path.read_text(encoding="utf-8-sig"))
    if (
        type(attestation) is not dict
        or attestation.get("document_type") != "ptcgdap_ucis_runtime_attestation_v1"
        or attestation.get("schema_version") != 1
        or attestation.get("ucis_generation") != 1
        or attestation.get("contract_generation") != 2
    ):
        raise ValueError("ucis_runtime_attestation_invalid")
    runtime_cards = attestation.get("cards")
    runtime_effects = attestation.get("effects")
    runtime_closure = attestation.get("closure")
    if type(runtime_cards) is not list or type(runtime_effects) is not list or type(runtime_closure) is not dict:
        raise ValueError("ucis_runtime_attestation_shape_invalid")
    runtime_card_map = {str(row.get("card_uid", "")): row for row in runtime_cards if type(row) is dict}
    if set(runtime_card_map) != set(card_documents) or len(runtime_card_map) != len(runtime_cards):
        raise ValueError("ucis_runtime_attestation_card_scope_drift")
    manifest_map = {
        str(row.get("path", "")): str(row.get("sha256", ""))
        for row in attestation.get("card_source_manifest", [])
        if type(row) is dict
    }
    expected_manifest = {
        path.relative_to(root).as_posix(): _sha_bytes(path.read_bytes())
        for path, _document in card_documents.values()
    }
    if manifest_map != expected_manifest:
        raise ValueError("ucis_runtime_attestation_source_drift")
    for card in cards:
        runtime_row = runtime_card_map[card["card_uid"]]
        if runtime_row.get("effect_id") != card["effect_id"]:
            raise ValueError("ucis_runtime_attestation_effect_drift")
        card["status"] = runtime_row.get("status")
        card["capability_ids"] = list(runtime_row.get("capability_ids", []))
        card["effect_refs"] = list(runtime_row.get("effect_refs", []))
        card["source_hashes"] = list(runtime_row.get("source_hashes", []))
        card["program_templates"] = list(runtime_row.get("program_templates", []))
        if runtime_row.get("status") == "unsupported":
            card["unsupported_reason"] = str(runtime_row.get("unsupported_reason", ""))

    effects: dict[str, dict[str, Any]] = {}
    for runtime_row in runtime_effects:
        if type(runtime_row) is not dict:
            raise ValueError("ucis_runtime_attestation_effect_invalid")
        effect_id = str(runtime_row.get("effect_id", ""))
        if not effect_id or effect_id in effects:
            raise ValueError("ucis_runtime_attestation_effect_invalid")
        effects[effect_id] = {
            "effect_id": effect_id,
            "status": runtime_row.get("status"),
            "resolution_owner": "BaseEffect.CardEffectSpec",
            "runtime_program_owner": "UcisInteractionCompiler",
            "card_uids": list(runtime_row.get("card_uids", [])),
            "effect_refs": list(runtime_row.get("effect_refs", [])),
            "capability_ids": list(runtime_row.get("capability_ids", [])),
            "source_hashes": list(runtime_row.get("source_hashes", [])),
            "program_templates": list(runtime_row.get("program_templates", [])),
            "unsupported_reasons": list(runtime_row.get("unsupported_reasons", [])),
        }
    if set(effects) != {card["effect_id"] for card in cards}:
        raise ValueError("ucis_runtime_attestation_effect_scope_drift")

    total_builders = sum(int(entry["occurrences"]) for entry in builder_occurrences)
    closure = {
        "total_cards": len(cards),
        "total_effects": len(effects),
        "interactive_builder_entries": total_builders,
        "compiled": int(runtime_closure.get("compiled", -1)),
        "automatic": int(runtime_closure.get("automatic", -1)),
        "unsupported": int(runtime_closure.get("unsupported", -1)),
        "unregistered": 0,
        "legacy_author_visible": len(legacy_overrides),
        "custom_prompt_builder": len(authority_violations),
        "silent_fallback": 0,
    }
    primitive_coverage = attestation.get("primitive_coverage")
    if type(primitive_coverage) is not dict or set(primitive_coverage) != set(registry.primitives):
        raise ValueError("ucis_runtime_primitive_coverage_invalid")
    return {
        "document_type": "ptcgdap_ucis_card_catalog_v1",
        "schema_version": 1,
        "ucis_generation": 1,
        "identity_domain": "godot_local_card_uid_v1",
        "catalog_root": "data/bundled_user/cards",
        "effect_source_root": "scripts/effects",
        "cards": cards,
        "effects": [effects[key] for key in sorted(effects)],
        "builder_occurrences": builder_occurrences,
        "source_manifest": source_manifest,
        "primitive_coverage": primitive_coverage,
        "compatibility_translation": {
            "owner": "scripts/engine/ucis/UcisInteractionCompiler.gd",
            "author_visible_legacy_fields": 0,
            "modes": [
                "semantic_name",
                "structural_spec",
                "engine_private_compatibility",
            ],
            "silent_mode": None,
        },
        "runtime_attestation_path": attestation_path.relative_to(root).as_posix(),
        "runtime_attestation_sha256": _sha_bytes(attestation_path.read_bytes()),
        "violations": {
            "legacy_overrides": legacy_overrides,
            "authority": authority_violations,
        },
        "closure": closure,
    }


def validate_ucis_catalog(catalog: Mapping[str, Any]) -> None:
    from .ucis import UcisRegistry

    if catalog.get("document_type") != "ptcgdap_ucis_card_catalog_v1":
        raise ValueError("ucis_catalog_document_type_invalid")
    if catalog.get("schema_version") != 1 or catalog.get("ucis_generation") != 1:
        raise ValueError("ucis_catalog_generation_invalid")
    cards = catalog.get("cards")
    effects = catalog.get("effects")
    closure = catalog.get("closure")
    violations = catalog.get("violations")
    primitive_coverage = catalog.get("primitive_coverage")
    if type(cards) is not list or type(effects) is not list or type(closure) is not dict:
        raise ValueError("ucis_catalog_shape_invalid")
    if type(violations) is not dict:
        raise ValueError("ucis_catalog_violation_shape_invalid")
    if type(primitive_coverage) is not dict:
        raise ValueError("ucis_catalog_primitive_coverage_invalid")
    if len(cards) != len({entry["card_uid"] for entry in cards}):
        raise ValueError("ucis_catalog_card_uid_duplicate")
    if len(effects) != len({entry["effect_id"] for entry in effects}):
        raise ValueError("ucis_catalog_effect_id_duplicate")
    effect_ids = {entry["effect_id"] for entry in effects}
    if any(entry.get("effect_id") not in effect_ids for entry in cards):
        raise ValueError("ucis_catalog_unregistered_card_effect")
    expected_total = int(closure.get("compiled", -1)) + int(closure.get("automatic", -1)) + int(
        closure.get("unsupported", -1)
    )
    if expected_total != len(effects) or closure.get("total_effects") != len(effects):
        raise ValueError("ucis_catalog_effect_partition_invalid")
    if closure.get("total_cards") != len(cards):
        raise ValueError("ucis_catalog_card_count_invalid")
    allowed_statuses = {"compiled", "automatic", "unsupported"}
    if any(entry.get("status") not in allowed_statuses for entry in cards + effects):
        raise ValueError("ucis_catalog_status_invalid")
    if any(
        entry.get("status") == "unsupported" and not entry.get("unsupported_reason")
        for entry in cards
    ):
        raise ValueError("ucis_catalog_unsupported_reason_missing")
    registered = set(UcisRegistry.load(Path(__file__).resolve().parents[3]).primitives)
    if set(primitive_coverage) != registered or any(
        type(value) is not int or value < 0 for value in primitive_coverage.values()
    ):
        raise ValueError("ucis_catalog_primitive_coverage_invalid")
    for entry in cards + effects:
        capabilities = entry.get("capability_ids")
        source_hashes = entry.get("source_hashes")
        programs = entry.get("program_templates")
        if type(capabilities) is not list or type(source_hashes) is not list or type(programs) is not list:
            raise ValueError("ucis_catalog_effect_program_shape_invalid")
        if entry.get("status") == "compiled":
            if not capabilities or not programs:
                raise ValueError("ucis_catalog_compiled_program_missing")
            if any(capability not in registered for capability in capabilities):
                raise ValueError("ucis_catalog_capability_unregistered")
        if entry.get("status") == "automatic" and (capabilities or programs):
            raise ValueError("ucis_catalog_automatic_program_forbidden")
        if entry.get("status") == "unsupported" and not capabilities:
            raise ValueError("ucis_catalog_unsupported_capability_missing")
        if any(
            type(value) is not str
            or len(value) != 64
            or value != value.upper()
            or any(character not in "0123456789ABCDEF" for character in value)
            for value in source_hashes
        ):
            raise ValueError("ucis_catalog_effect_source_hash_invalid")
    if not catalog.get("runtime_attestation_sha256") or len(catalog["runtime_attestation_sha256"]) != 64:
        raise ValueError("ucis_catalog_runtime_attestation_hash_invalid")
    for key in ("unregistered", "legacy_author_visible", "custom_prompt_builder", "silent_fallback"):
        if closure.get(key) != 0:
            raise ValueError(f"ucis_catalog_closure_failed:{key}")
    if violations.get("legacy_overrides") or violations.get("authority"):
        raise ValueError("ucis_catalog_static_boundary_failed")
    canonical_json_v1_bytes(catalog)


__all__ = [
    "FORBIDDEN_AUTHORITY",
    "LEGACY_ENTRYPOINTS",
    "LEGACY_AUTHOR_TOKENS",
    "UCIS_BUILDERS",
    "build_ucis_catalog",
    "validate_ucis_catalog",
]
