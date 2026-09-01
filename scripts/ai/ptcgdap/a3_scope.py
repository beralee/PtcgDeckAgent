from __future__ import annotations

import hashlib
from pathlib import Path
import subprocess
from typing import Any, Iterable, Mapping

from .cabt_tree_hash import jcs_canonical_json_bytes
from .source_lock import load_json_strict


TARGET_DECKS = (
    (800018501, "marnie_grimmsnarl"),
    (800017097, "gardevoir"),
    (800018499, "dragapult"),
    (800018509, "raging_bolt_ogerpon"),
    (800018502, "ns_zoroark"),
)

CORE_RULE_FILES = (
    "scripts/engine/GameStateMachine.gd",
    "scripts/engine/RuleValidator.gd",
    "scripts/engine/DamageCalculator.gd",
    "scripts/engine/EffectProcessor.gd",
    "scripts/engine/EffectRegistry.gd",
    "scripts/engine/RandomEventPort.gd",
    "scripts/engine/CoinFlipper.gd",
)

PROTOCOL_FILES = (
    "contracts/ptcgdap/a3_comparator_conformance_v2.json",
    "contracts/ptcgdap/a3_engine_adapter_v2.json",
    "contracts/ptcgdap/a3_five_deck_capability_profile_v2.json",
    "contracts/ptcgdap/a3_private_semantic_parity_profile_v1.json",
    "contracts/ptcgdap/a3_snapshot_profile_v2.json",
    "scripts/ai/ptcgdap/a3_differential.py",
    "scripts/ai/ptcgdap/a3_entity_relation.py",
    "scripts/ai/ptcgdap/a3_execution.py",
    "scripts/ai/ptcgdap/a3_match_plan.py",
    "scripts/ai/ptcgdap/a3_mutation.py",
    "scripts/ai/ptcgdap/a3_operation_contract.py",
    "scripts/ai/ptcgdap/a3_operation_qualification.py",
    "scripts/ai/ptcgdap/a3_official_deck_compatibility.py",
    "scripts/ai/ptcgdap/a3_qualification.py",
    "scripts/ai/ptcgdap/a3_review.py",
    "scripts/ai/ptcgdap/a3_scenario_coverage.py",
    "scripts/ai/ptcgdap/a3_scope.py",
    "scripts/ai/ptcgdap/a3_self_replay.py",
    "scripts/ai/ptcgdap/a3_snapshot.py",
    "scripts/ai/ptcgdap/private_official_cabt.py",
    "scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd",
    "scripts/ai/ptcgdap/host/godot/A3CheckpointComparator.gd",
    "scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd",
    "scripts/ai/HeadlessMatchBridge.gd",
    "tools/ptcgdap/run_a3_comparator_vectors.gd",
    "tools/ptcgdap/a3_godot_headless_bridge.gd",
    "tools/ptcgdap/godot_a3_jsonline_bridge.py",
    "tools/ptcgdap/build_a3_operation_qualification.py",
)


class A3ScopeError(RuntimeError):
    pass


def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _sha_json(value: Any) -> str:
    return _sha_bytes(jcs_canonical_json_bytes(value))


def _file_record(root: Path, relative: str) -> dict[str, Any]:
    path = root / relative
    data = path.read_bytes()
    return {"path": relative.replace("\\", "/"), "bytes": len(data), "sha256": _sha_bytes(data)}


def _source_card_path(root: Path, entry: dict[str, Any]) -> Path | None:
    candidates = (
        root / "data" / "bundled_user" / "cards" / f"{entry['set_code']}_{entry['card_index']}.json",
        root / "data" / "bundled_user" / "cards" / f"LEN_{entry['source_set_code']}_{entry['source_card_index']}.json",
    )
    return next((path for path in candidates if path.is_file()), None)


def _effect_handler_index(
    root: Path,
    effect_tokens: Mapping[str, Iterable[str]],
) -> dict[str, list[str]]:
    ids = {value for value in effect_tokens if value}
    result = {value: [] for value in ids}
    for parent in (root / "scripts" / "engine", root / "scripts" / "effects"):
        for path in sorted(parent.rglob("*.gd")):
            text = path.read_text(encoding="utf-8")
            for effect_id in ids:
                tokens = {effect_id, *(token for token in effect_tokens[effect_id] if token)}
                if any(token in text for token in tokens):
                    result[effect_id].append(path.relative_to(root).as_posix())
    return result


def build_five_deck_scope(repository_root: str | Path) -> dict[str, Any]:
    root = Path(repository_root).resolve()
    semantic_profile_path = (
        root / "contracts" / "ptcgdap" / "a3_private_semantic_parity_profile_v1.json"
    )
    semantic_profile = load_json_strict(semantic_profile_path)
    if (
        type(semantic_profile) is not dict
        or semantic_profile.get("document_type")
        != "ptcgdap_a3_private_semantic_parity_profile_v1"
        or semantic_profile.get("schema_version") != 1
        or semantic_profile.get("project_scope_decision", {}).get(
            "local_private_oracle_research_allowed"
        ) is not True
        or semantic_profile.get("identity_domains", {}).get(
            "official_numeric_identity_equality_required"
        ) is not False
    ):
        raise A3ScopeError("a3_private_semantic_profile_invalid")
    capability_profile_path = root / "contracts" / "ptcgdap" / "a3_five_deck_capability_profile_v2.json"
    capability_profile = load_json_strict(capability_profile_path)
    if (
        type(capability_profile) is not dict
        or type(capability_profile.get("capabilities")) is not list
        or not capability_profile["capabilities"]
        or any(
            type(item) is not dict or type(item.get("capability_id")) is not str
            for item in capability_profile["capabilities"]
        )
    ):
        raise A3ScopeError("a3_capability_profile_invalid")
    required_capability_ids = [
        item["capability_id"] for item in capability_profile["capabilities"]
    ]
    if len(required_capability_ids) != len(set(required_capability_ids)):
        raise A3ScopeError("a3_capability_profile_invalid")
    master_path = root / "data" / "ptcgdap" / "card_id_catalog" / "official_card_attack_master_v1.json"
    master = load_json_strict(master_path)
    if type(master) is not dict or type(master.get("cards")) is not list:
        raise A3ScopeError("a3_official_identity_master_invalid")
    printing_map: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for card in master["cards"]:
        printing = card.get("exact_english_printing_or_null") if type(card) is dict else None
        if type(printing) is not dict:
            continue
        key = (str(printing.get("expansion", "")).upper(), str(printing.get("collection_no", "")))
        printing_map.setdefault(key, []).append(card)

    deck_sources: list[tuple[int, str, Path, dict[str, Any]]] = []
    effect_tokens: dict[str, set[str]] = {}
    for deck_id, name in TARGET_DECKS:
        path = root / "data" / "bundled_user" / "decks" / f"{deck_id}.json"
        deck = load_json_strict(path)
        if type(deck) is not dict or deck.get("total_cards") != 60 or type(deck.get("cards")) is not list:
            raise A3ScopeError(f"a3_deck_source_invalid:{deck_id}")
        deck_sources.append((deck_id, name, path, deck))
        for entry in deck["cards"]:
            if type(entry) is not dict:
                continue
            effect_id = str(entry.get("effect_id", ""))
            if not effect_id:
                continue
            tokens = effect_tokens.setdefault(effect_id, set())
            source_path = _source_card_path(root, entry)
            source_card = load_json_strict(source_path) if source_path is not None else None
            if type(source_card) is dict:
                for ability in source_card.get("abilities", []):
                    if type(ability) is dict and type(ability.get("name")) is str:
                        tokens.add(ability["name"])
                for attack in source_card.get("attacks", []):
                    if type(attack) is dict and type(attack.get("name")) is str:
                        tokens.add(attack["name"])
    handler_index = _effect_handler_index(root, effect_tokens)

    decks: list[dict[str, Any]] = []
    all_private_card_uids: set[str] = set()
    all_private_attack_ids: set[str] = set()
    oracle_overlap_private_uids: set[str] = set()
    oracle_overlap_entry_count = 0
    oracle_overlap_copy_count = 0
    oracle_excluded_entry_count = 0
    all_handler_paths: set[str] = set(CORE_RULE_FILES)
    for deck_id, name, path, deck in deck_sources:
        ordered_private_uids: list[str] = []
        entries: list[dict[str, Any]] = []
        unresolved: list[dict[str, Any]] = []
        for ordinal, raw_entry in enumerate(deck["cards"]):
            entry = dict(raw_entry)
            count = int(entry.get("count", 0))
            private_uid = f"{entry.get('set_code', '')}_{entry.get('card_index', '')}"
            if (
                count <= 0
                or type(entry.get("set_code")) is not str
                or not entry["set_code"]
                or type(entry.get("card_index")) is not str
                or not entry["card_index"]
            ):
                raise A3ScopeError(f"a3_private_card_identity_invalid:{deck_id}:{ordinal}")
            semantic_card_id = f"private-card:{private_uid}"
            ordered_private_uids.extend([private_uid] * count)
            all_private_card_uids.add(private_uid)
            key = (str(entry.get("source_set_code", "")).upper(), str(entry.get("source_card_index", "")))
            candidates = printing_map.get(key, [])
            source_path = _source_card_path(root, entry)
            source_card = load_json_strict(source_path) if source_path is not None else None
            source_identity_status = "closed" if type(source_card) is dict else "open"
            official_card_id = int(candidates[0]["official_card_id"]) if len(candidates) == 1 else None
            official_attacks = list(candidates[0].get("ordered_official_attack_ids", [])) if len(candidates) == 1 else []
            local_attack_count = len(source_card.get("attacks", [])) if type(source_card) is dict and type(source_card.get("attacks")) is list else 0
            private_attack_ids = [
                f"{private_uid}:attack:{attack_ordinal}"
                for attack_ordinal in range(local_attack_count)
            ]
            all_private_attack_ids.update(private_attack_ids)
            handlers = handler_index.get(str(entry.get("effect_id", "")), [])
            has_semantic_text = bool(
                type(source_card) is dict
                and (source_card.get("abilities") or any(str(attack.get("text", "")) for attack in source_card.get("attacks", []) if type(attack) is dict))
            )
            handler_status = "mapped" if handlers or not has_semantic_text else "unresolved"
            if len(candidates) == 1 and len(official_attacks) == local_attack_count:
                correspondence_status = "exact_corresponding_printing"
            elif len(candidates) == 0:
                correspondence_status = "not_in_locked_oracle_catalog"
            elif len(candidates) > 1:
                correspondence_status = "ambiguous_oracle_printing"
            else:
                correspondence_status = "attack_surface_mismatch"
            bridge_hash = None
            if correspondence_status == "exact_corresponding_printing":
                # The public scope commits to the private adapter record without
                # publishing either official Card ID or Attack IDs.
                bridge_hash = _sha_json({
                    "semantic_card_id": semantic_card_id,
                    "private_card_uid": private_uid,
                    "source_printing": {"expansion": key[0], "collection_no": key[1]},
                    "official_card_id": official_card_id,
                    "ordered_official_attack_ids": official_attacks,
                    "source_card_sha256": (
                        _sha_bytes(source_path.read_bytes()) if source_path is not None else None
                    ),
                })
                oracle_overlap_entry_count += 1
                oracle_overlap_copy_count += count
                oracle_overlap_private_uids.add(private_uid)
            else:
                oracle_excluded_entry_count += 1
            all_handler_paths.update(handlers)
            record = {
                "deck_entry_ordinal": ordinal,
                "count": count,
                "private_card_uid": private_uid,
                "semantic_card_id": semantic_card_id,
                "private_attack_ids": private_attack_ids,
                "local_printing": {"set_code": entry.get("set_code"), "card_index": entry.get("card_index")},
                "source_printing": {"expansion": key[0], "collection_no": key[1]},
                "effect_id": entry.get("effect_id"),
                "source_identity_status": source_identity_status,
                "source_card_sha256": (
                    _sha_bytes(source_path.read_bytes()) if source_path is not None else None
                ),
                "handler_status": handler_status,
                "handler_paths": handlers,
                "source_card_path": source_path.relative_to(root).as_posix() if source_path is not None else None,
                "oracle_correspondence": {
                    "status": correspondence_status,
                    "evidence_kind": (
                        "exact_corresponding_printing"
                        if correspondence_status == "exact_corresponding_printing"
                        else None
                    ),
                    "bridge_record_sha256": bridge_hash,
                    "official_numeric_ids_published": False,
                },
            }
            entries.append(record)
            if source_identity_status != "closed" or handler_status != "mapped":
                unresolved.append({
                    "deck_entry_ordinal": ordinal,
                    "source_identity": source_identity_status,
                    "handler": handler_status,
                })
        private_identity_closed = len(ordered_private_uids) == 60 and all(
            entry["source_identity_status"] == "closed" for entry in entries
        )
        private_effect_closed = all(entry["handler_status"] == "mapped" for entry in entries)
        decks.append(
            {
                "deck_id": deck_id,
                "deck_name": name,
                "local_source_path": path.relative_to(root).as_posix(),
                "local_source_sha256": _sha_bytes(path.read_bytes()),
                "local_source_canonical_sha256": _sha_json(deck),
                "ordered_private_card_uids": ordered_private_uids,
                "ordered_private_deck_sha256": _sha_json(ordered_private_uids),
                "ordered_card_count": len(ordered_private_uids),
                "unique_printing_count": len(entries),
                "entries": entries,
                "unresolved": unresolved,
                "private_identity_closure_status": "closed" if private_identity_closed else "open",
                "private_effect_closure_status": "closed" if private_effect_closed else "open",
                "identity_effect_closure_status": (
                    "closed" if private_identity_closed and private_effect_closed else "open"
                ),
            }
        )

    handler_files = [_file_record(root, path) for path in sorted(all_handler_paths) if (root / path).is_file()]
    protocol_files = [_file_record(root, path) for path in PROTOCOL_FILES]
    try:
        godot_commit = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=root, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=5,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        godot_commit = "unavailable"
    a1_scope = load_json_strict(root / "evidence/ptcgdap/a1/scope_v2.json")
    private_inventory_path = root / "evidence/ptcgdap/w0/private_oracle_inventory_v1.json"
    private_inventory = (
        load_json_strict(private_inventory_path) if private_inventory_path.is_file() else None
    )
    private_smoke_path = root / "evidence/ptcgdap/w0/private_official_adapter_smoke_v1.json"
    private_smoke = load_json_strict(private_smoke_path) if private_smoke_path.is_file() else None
    private_identities = (
        private_inventory.get("critical_identities", {})
        if type(private_inventory) is dict
        else {}
    )
    def private_sha(identity: str) -> str | None:
        value = private_identities.get(identity, {})
        candidate = value.get("sha256") if type(value) is dict else None
        return candidate if type(candidate) is str and len(candidate) == 64 else None
    rng_scan_roots = (root / "scripts" / "engine", root / "scripts" / "data", root / "scripts" / "effects")
    rng_violations: list[dict[str, Any]] = []
    forbidden = (".randomize(", "randi_range(", ".shuffle(", "RandomNumberGenerator.new(")
    for parent in rng_scan_roots:
        for source in sorted(parent.rglob("*.gd")):
            relative = source.relative_to(root).as_posix()
            if relative == "scripts/engine/RandomEventPort.gd":
                continue
            for line_number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), start=1):
                if any(token in line for token in forbidden):
                    rng_violations.append({"path": relative, "line": line_number, "source": line.strip()})
    random_port_text = (root / "scripts/engine/RandomEventPort.gd").read_text(encoding="utf-8")
    effect_processor_text = (root / "scripts/engine/EffectProcessor.gd").read_text(encoding="utf-8")
    game_state_text = (root / "scripts/engine/GameStateMachine.gd").read_text(encoding="utf-8")
    required_random_metadata = (
        '"source_card_uid"', '"source_attack_ordinal"', '"source_ability_ordinal"',
        '"target_identity"', '"status_condition"', '"event_in_group"', '"effect_id"',
        '"effect_phase"', '"effect_implementation"',
        '"source_context_fingerprint"', '"pre_state_hash"',
    )
    random_metadata_closed = (
        all(token in random_port_text for token in required_random_metadata)
        and "_random_card_effect_context" in effect_processor_text
        and "_random_attack_effect_context" in effect_processor_text
        and "_random_ability_effect_context" in effect_processor_text
        and "_pokemon_check_coin_context" in effect_processor_text
        and "_flip_with_random_context" in game_state_text
    )
    godot_adapter_paths = (
        root / "scripts/ai/ptcgdap/host/godot/A3ExternalDecisionPort.gd",
        root / "tools/ptcgdap/a3_godot_headless_bridge.gd",
        root / "tools/ptcgdap/godot_a3_jsonline_bridge.py",
    )
    godot_adapter_closed = all(path.is_file() for path in godot_adapter_paths)

    manifest: dict[str, Any] = {
        "document_type": "ptcgdap_a3_five_deck_scope_v2",
        "schema_version": 2,
        "contract_generation": 2,
        "oracle_provenance": {
            "class": (
                "user_supplied_private_source_locked_material"
                if private_inventory is not None
                else "existing_source_locked_private_development_material"
            ),
            "official_runtime_authorized": False,
            "project_owner_scope_attested": True,
            "local_private_oracle_research_allowed": True,
            "public_distribution_authorized": False,
            "maximum_claim": semantic_profile["certification"]["maximum_claim"],
            "w0_status": "project_owner_open_research_scope_attested",
            "private_inventory_sha256": (
                private_inventory.get("inventory_sha256")
                if private_inventory is not None
                else None
            ),
            "official_module_sha256": (
                private_sha("official_module")
                or a1_scope["source_hashes"]["enum"]["sha256"]
            ),
            "official_engine_sha256": private_sha("official_engine"),
            "official_catalog_sha256": private_sha("official_catalog"),
            "private_adapter_smoke_evidence_sha256": (
                private_smoke.get("evidence_sha256") if type(private_smoke) is dict else None
            ),
            "live_official_adapter_smoke": (
                type(private_smoke) is dict
                and private_smoke.get("live_official_engine_started") is True
                and private_smoke.get("official_engine_sha256") == private_sha("official_engine")
                and private_smoke.get("official_catalog_sha256") == private_sha("official_catalog")
                and private_smoke.get("source_locator_persisted") is False
            ),
        },
        "godot_candidate": {
            "git_commit": godot_commit,
            "dirty_scope_content_manifest_sha256": _sha_json(handler_files + protocol_files),
            "content_manifest_scope": "reachable_rule_and_differential_protocol_files",
        },
        "godot_contracts": {
            "cabt_a1_scope_sha256": a1_scope["scope_sha256"],
            "card_catalog_bundle_sha256": _sha_json(
                load_json_strict(root / "contracts/ptcgdap/card_id_catalog_bundle.json")
            ),
        },
        "private_semantic_parity_profile": _file_record(
            root, semantic_profile_path.relative_to(root).as_posix()
        ),
        "official_identity_master": _file_record(root, master_path.relative_to(root).as_posix()),
        "capability_profile": _file_record(
            root, capability_profile_path.relative_to(root).as_posix()
        ),
        "required_capability_ids": required_capability_ids,
        "decks": decks,
        "candidate_private_card_uids": sorted(all_private_card_uids),
        "candidate_private_attack_ids": sorted(all_private_attack_ids),
        "oracle_correspondence_scope": {
            "identity_equality_required": False,
            "official_deck_identity_required": False,
            "mapping_policy": "exact_corresponding_printing_or_separately_reviewed_equivalent; never_name_only",
            "mapped_unique_private_card_count": len(oracle_overlap_private_uids),
            "mapped_deck_entry_count": oracle_overlap_entry_count,
            "mapped_card_copy_count": oracle_overlap_copy_count,
            "excluded_deck_entry_count": oracle_excluded_entry_count,
            "official_numeric_ids_published": False,
            "status": "closed" if oracle_overlap_entry_count > 0 else "open",
        },
        "effect_rule_handler_files": handler_files,
        "adapter_snapshot_comparator_action_protocol_files": protocol_files,
        "prompt_scope": list(range(49)),
        "random_capability": {
            "owner": "scripts/engine/RandomEventPort.gd",
            "levels_implemented": ["R0", "R2A"],
            "same_seed_claim": False,
            "rng_callsite_violations": rng_violations,
            "event_metadata_status": (
                "closed_source_card_attack_ability_target_status_group_phase_and_public_pre_state_context"
                if random_metadata_closed
                else "open_source_identity_context"
            ),
            "conditioned_tape_context_bound": random_metadata_closed,
            "status": (
                "single_owner_context_closed"
                if not rng_violations and random_metadata_closed
                else "rng-owner-not-aligned"
            ),
        },
        "engine_adapter_capability": {
            "godot_event_driven_jsonline": godot_adapter_closed,
            "godot_private_state_injection": False,
            "official_native_event_driven_jsonline": True,
            "search_analysis_capability": "none",
        },
        "known_differences": [],
        "non_claims": [
            "official_numeric_card_id_equality",
            "official_exact_deck_identity",
            "official_search_analysis_api",
            "same_seed_official_rng",
            "official_certification_or_universal_engine_equivalence",
        ],
        "unsupported": (
            []
            if godot_adapter_closed and random_metadata_closed and not rng_violations
            else [
                *([] if godot_adapter_closed else ["godot_headless_event_driven_jsonline_adapter"]),
                *([] if random_metadata_closed else ["rng_source_identity_context_not_closed"]),
                *([] if not rng_violations else ["rng_owner_not_aligned"]),
            ]
        ),
    }
    manifest["identity_effect_closure_status"] = (
        "closed" if all(deck["identity_effect_closure_status"] == "closed" for deck in decks) else "open"
    )
    manifest["a3_promotion_status"] = "needs_differential"
    manifest["scope_sha256"] = _sha_json(manifest)
    return manifest


__all__ = ["A3ScopeError", "TARGET_DECKS", "build_five_deck_scope"]
