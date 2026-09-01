from __future__ import annotations

import csv
import hashlib
import io
from pathlib import Path
import unicodedata
from typing import Any, Iterable, Mapping, Protocol

from scripts.ai.ptcgdap.a3_entity_relation import SemanticEntityRelation
from scripts.ai.ptcgdap.a3_scope import TARGET_DECKS
from scripts.ai.ptcgdap.cabt_tree_hash import jcs_canonical_json_bytes
from scripts.ai.ptcgdap.source_lock import load_json_strict
class A3DeckCompatibilityError(RuntimeError):
    pass


class RightsDecision(Protocol):
    accepted: bool
    claims: Mapping[str, bool]


class CompetitionRightsGate(Protocol):
    """Dependency-inverted boundary implemented by the private workspace."""

    private_bundle_root: Path | None

    def authorize(
        self,
        *,
        operation: str,
        requested_capabilities: Iterable[str] = (),
    ) -> RightsDecision: ...


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def _sha_json(value: Any) -> str:
    return _sha256(jcs_canonical_json_bytes(value))


def _normalize_name(value: Any) -> str:
    if type(value) is not str:
        return ""
    translated = value.translate(str.maketrans({"’": "'", "‘": "'", "‐": "-", "‑": "-"}))
    return " ".join(unicodedata.normalize("NFKC", translated).casefold().split())


def _catalog_indexes(data: bytes) -> tuple[dict[tuple[str, str], set[int]], dict[str, set[int]]]:
    try:
        rows = csv.DictReader(io.StringIO(data.decode("utf-8-sig", errors="strict")))
    except UnicodeError as error:
        raise A3DeckCompatibilityError("a3_official_catalog_invalid") from error
    required = {"Card ID", "Card Name", "Expansion", "Collection No."}
    if rows.fieldnames is None or not required.issubset(rows.fieldnames):
        raise A3DeckCompatibilityError("a3_official_catalog_invalid")
    by_print: dict[tuple[str, str], set[int]] = {}
    by_name: dict[str, set[int]] = {}
    try:
        for row in rows:
            card_id = int(row["Card ID"])
            if card_id <= 0:
                raise ValueError
            printing = (
                str(row["Expansion"]).strip().upper(),
                str(row["Collection No."]).strip(),
            )
            by_print.setdefault(printing, set()).add(card_id)
            normalized_name = _normalize_name(row["Card Name"])
            if normalized_name:
                by_name.setdefault(normalized_name, set()).add(card_id)
    except (TypeError, ValueError) as error:
        raise A3DeckCompatibilityError("a3_official_catalog_invalid") from error
    return by_print, by_name


def _master_index(repository: Path) -> dict[tuple[str, str], list[dict[str, Any]]]:
    path = repository / "data/ptcgdap/card_id_catalog/official_card_attack_master_v1.json"
    if not path.is_file() or path.is_symlink():
        raise A3DeckCompatibilityError("a3_official_identity_master_missing")
    master = load_json_strict(path)
    if type(master) is not dict or type(master.get("cards")) is not list:
        raise A3DeckCompatibilityError("a3_official_identity_master_invalid")
    result: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for value in master["cards"]:
        printing = value.get("exact_english_printing_or_null") if type(value) is dict else None
        if type(printing) is not dict:
            continue
        key = (
            str(printing.get("expansion", "")).strip().upper(),
            str(printing.get("collection_no", "")).strip(),
        )
        result.setdefault(key, []).append(value)
    return result


def _deck_source(root: Path, relative: Any) -> Path:
    if type(relative) is not str or not relative or "\\" in relative:
        raise A3DeckCompatibilityError("a3_local_deck_source_invalid")
    path = (root / relative).resolve()
    if not path.is_relative_to(root) or path.is_symlink() or not path.is_file():
        raise A3DeckCompatibilityError("a3_local_deck_source_invalid")
    return path


def _scoped_entries(scoped_deck: Mapping[str, Any], source: Mapping[str, Any]) -> list[dict[str, Any]]:
    values = scoped_deck.get("entries")
    if type(values) is list and len(values) == len(source["cards"]):
        return [dict(value) for value in values]
    result: list[dict[str, Any]] = []
    for ordinal, entry in enumerate(source["cards"]):
        if (
            type(entry) is not dict
            or type(entry.get("set_code")) is not str
            or type(entry.get("card_index")) is not str
        ):
            raise A3DeckCompatibilityError("a3_private_identity_scope_missing")
        private_uid = f"{entry['set_code']}_{entry['card_index']}"
        result.append({
            "deck_entry_ordinal": ordinal,
            "private_card_uid": private_uid,
            "semantic_card_id": f"private-card:{private_uid}",
            "private_attack_ids": list(entry.get("private_attack_ids", [])),
        })
    return result


def build_official_deck_compatibility_report(
    repository_root: str | Path,
    scope: Mapping[str, Any],
    private_bundle_root: str | Path,
    rights_gate: CompetitionRightsGate,
    private_inventory: Mapping[str, Any],
) -> dict[str, Any]:
    """Build a private-ID correspondence report for the oracle overlap."""
    repository = Path(repository_root).resolve()
    private_root = Path(private_bundle_root).resolve()
    if type(scope) is not dict or type(scope.get("decks")) is not list:
        raise A3DeckCompatibilityError("a3_scope_invalid")
    decision = rights_gate.authorize(
        operation="local_private_oracle",
        requested_capabilities=("read_private_bundle",),
    )
    if (
        not decision.accepted
        or decision.claims.get("read_private_bundle") is not True
        or rights_gate.private_bundle_root != private_root
    ):
        raise A3DeckCompatibilityError("rights_operation_not_authorized")
    catalog_path = private_root / "EN_Card_Data.csv"
    if catalog_path.is_symlink() or not catalog_path.is_file():
        raise A3DeckCompatibilityError("a3_official_catalog_missing")
    catalog_data = catalog_path.read_bytes()
    catalog_sha = _sha256(catalog_data)
    expected_catalog = private_inventory.get("critical_identities", {}).get("official_catalog", {})
    if expected_catalog.get("sha256") != catalog_sha:
        raise A3DeckCompatibilityError("a3_official_catalog_inventory_mismatch")
    by_print, by_name = _catalog_indexes(catalog_data)
    master = _master_index(repository)

    expected_ids = {deck_id for deck_id, _ in TARGET_DECKS}
    actual_ids = {deck.get("deck_id") for deck in scope["decks"] if type(deck) is dict}
    if actual_ids != expected_ids or len(scope["decks"]) != len(TARGET_DECKS):
        raise A3DeckCompatibilityError("a3_target_deck_set_mismatch")

    deck_reports: list[dict[str, Any]] = []
    common_open_count = 0
    for scoped_deck in scope["decks"]:
        if type(scoped_deck) is not dict or type(scoped_deck.get("deck_id")) is not int:
            raise A3DeckCompatibilityError("a3_scope_invalid")
        source_path = _deck_source(repository, scoped_deck.get("local_source_path"))
        source = load_json_strict(source_path)
        if type(source) is not dict or source.get("total_cards") != 60 or type(source.get("cards")) is not list:
            raise A3DeckCompatibilityError("a3_local_deck_source_invalid")
        scoped_entries = _scoped_entries(scoped_deck, source)
        entries: list[dict[str, Any]] = []
        overlap_entries = 0
        overlap_copies = 0
        private_only_entries = 0
        private_only_copies = 0
        for ordinal, source_entry in enumerate(source["cards"]):
            scoped_entry = scoped_entries[ordinal]
            if type(source_entry) is not dict or type(source_entry.get("count")) is not int or source_entry["count"] <= 0:
                raise A3DeckCompatibilityError("a3_local_deck_source_invalid")
            printing = (
                str(source_entry.get("source_set_code", "")).strip().upper(),
                str(source_entry.get("source_card_index", "")).strip(),
            )
            exact_ids = sorted(by_print.get(printing, set()))
            name_candidates = sorted(by_name.get(_normalize_name(source_entry.get("source_name")), set()))
            master_rows = master.get(printing, [])
            private_attack_ids = scoped_entry.get("private_attack_ids", [])
            resolved_id: int | None = None
            official_attack_ids: list[int] = []
            bridge_hash: str | None = None
            if len(exact_ids) == 1 and len(master_rows) == 1:
                master_id = master_rows[0].get("official_card_id")
                official_attack_ids = list(master_rows[0].get("ordered_official_attack_ids", []))
                if (
                    master_id == exact_ids[0]
                    and type(private_attack_ids) is list
                    and len(private_attack_ids) == len(official_attack_ids)
                ):
                    status = "exact_corresponding_printing"
                    resolved_id = exact_ids[0]
                    bridge_record = {
                        "semantic_card_id": scoped_entry.get("semantic_card_id"),
                        "private_card_uid": scoped_entry.get("private_card_uid"),
                        "private_attack_ids": list(private_attack_ids),
                        "official_card_ids": [resolved_id],
                        "official_attack_ids": official_attack_ids,
                        "evidence_kind": "exact_corresponding_printing",
                        "source_printing": {
                            "expansion": printing[0], "collection_no": printing[1],
                        },
                    }
                    bridge_hash = _sha_json(bridge_record)
                    overlap_entries += 1
                    overlap_copies += source_entry["count"]
                else:
                    status = "common_printing_attack_surface_open"
                    common_open_count += 1
            elif exact_ids:
                status = "common_printing_identity_ambiguous"
                common_open_count += 1
            elif name_candidates:
                status = "name_only_candidate_not_bound"
                private_only_entries += 1
                private_only_copies += source_entry["count"]
            else:
                status = "private_only_not_in_locked_oracle_catalog"
                private_only_entries += 1
                private_only_copies += source_entry["count"]
            entries.append({
                "deck_entry_ordinal": ordinal,
                "count": source_entry["count"],
                "private_card_uid": scoped_entry.get("private_card_uid"),
                "semantic_card_id": scoped_entry.get("semantic_card_id"),
                "private_attack_ids": list(private_attack_ids),
                "source_printing": {
                    "expansion": printing[0], "collection_no": printing[1],
                },
                "status": status,
                "official_card_ids": [] if resolved_id is None else [resolved_id],
                "official_attack_ids": official_attack_ids if resolved_id is not None else [],
                "name_only_candidate_official_card_ids": (
                    name_candidates if status == "name_only_candidate_not_bound" else []
                ),
                "bridge_record_sha256": bridge_hash,
            })
        deck_reports.append({
            "deck_id": scoped_deck["deck_id"],
            "deck_name": scoped_deck.get("deck_name"),
            "local_source_sha256": _sha256(source_path.read_bytes()),
            "private_ordered_deck_sha256": scoped_deck.get("ordered_private_deck_sha256"),
            "oracle_overlap_entry_count": overlap_entries,
            "oracle_overlap_card_copy_count": overlap_copies,
            "private_only_entry_count": private_only_entries,
            "private_only_card_copy_count": private_only_copies,
            "entries": entries,
        })

    report: dict[str, Any] = {
        "document_type": "ptcgdap_a3_private_semantic_correspondence_v2",
        "schema_version": 2,
        "scope_sha256": scope.get("scope_sha256"),
        "private_source_locator_persisted": False,
        "private_inventory_sha256": private_inventory.get("inventory_sha256"),
        "official_catalog_sha256": catalog_sha,
        "identity_equality_required": False,
        "official_deck_identity_required": False,
        "decks": deck_reports,
        "all_corresponding_cards_mapped": common_open_count == 0,
        "common_mapping_open_count": common_open_count,
        "mapping_policy": "exact printing plus locked attack ordinal surface; name-only never binds",
        "evidence_classification": "trusted-private",
        "publishable": False,
        "correspondence_gate": "passed" if common_open_count == 0 else "blocked",
        "known_gaps": [] if common_open_count == 0 else [
            "common_card_identity_or_attack_surface_open",
        ],
        "maximum_claim": "private_correspondence_registry_input_only",
    }
    report["evidence_sha256"] = _sha_json(report)
    return report


def public_compatibility_summary(private_report: Mapping[str, Any]) -> dict[str, Any]:
    if (
        type(private_report) is not dict
        or private_report.get("document_type")
        != "ptcgdap_a3_private_semantic_correspondence_v2"
        or type(private_report.get("decks")) is not list
    ):
        raise A3DeckCompatibilityError("semantic_correspondence_report_invalid")
    rows: list[dict[str, Any]] = []
    for deck in private_report["decks"]:
        if type(deck) is not dict:
            raise A3DeckCompatibilityError("semantic_correspondence_report_invalid")
        rows.append({
            "deck_id": deck.get("deck_id"),
            "deck_name": deck.get("deck_name"),
            "local_source_sha256": deck.get("local_source_sha256"),
            "private_ordered_deck_sha256": deck.get("private_ordered_deck_sha256"),
            "oracle_overlap_entry_count": deck.get("oracle_overlap_entry_count"),
            "oracle_overlap_card_copy_count": deck.get("oracle_overlap_card_copy_count"),
            "private_only_entry_count": deck.get("private_only_entry_count"),
            "private_only_card_copy_count": deck.get("private_only_card_copy_count"),
        })
    summary = {
        "document_type": "ptcgdap_a3_private_semantic_correspondence_public_summary_v2",
        "schema_version": 2,
        "scope_sha256": private_report.get("scope_sha256"),
        "official_catalog_sha256": private_report.get("official_catalog_sha256"),
        "private_inventory_sha256": private_report.get("private_inventory_sha256"),
        "private_detail_sha256": private_report.get("evidence_sha256"),
        "identity_equality_required": False,
        "official_deck_identity_required": False,
        "decks": rows,
        "all_corresponding_cards_mapped": private_report.get("all_corresponding_cards_mapped"),
        "common_mapping_open_count": private_report.get("common_mapping_open_count"),
        "correspondence_gate": private_report.get("correspondence_gate"),
        "known_gaps": list(private_report.get("known_gaps", [])),
        "official_card_ids_published": False,
        "official_attack_ids_published": False,
        "official_card_rows_published": False,
        "private_source_locator_persisted": False,
        "maximum_claim": "public_private_id_correspondence_hash_and_count_summary_only",
    }
    summary["evidence_sha256"] = _sha_json(summary)
    return summary


def register_private_semantic_bridge(
    relation: SemanticEntityRelation,
    private_report: Mapping[str, Any],
) -> int:
    """Load only sealed exact correspondences into a comparator relation."""
    if (
        type(private_report) is not dict
        or private_report.get("document_type")
        != "ptcgdap_a3_private_semantic_correspondence_v2"
        or private_report.get("evidence_classification") != "trusted-private"
        or private_report.get("publishable") is not False
    ):
        raise A3DeckCompatibilityError("semantic_correspondence_report_invalid")
    projected = dict(private_report)
    expected = projected.pop("evidence_sha256", None)
    if type(expected) is not str or expected != _sha_json(projected):
        raise A3DeckCompatibilityError("semantic_correspondence_report_unsealed")
    loaded: set[str] = set()
    for deck in private_report.get("decks", []):
        for entry in deck.get("entries", []):
            if type(entry) is not dict or entry.get("status") != "exact_corresponding_printing":
                continue
            semantic_card_id = entry.get("semantic_card_id")
            private_uid = entry.get("private_card_uid")
            official_ids = entry.get("official_card_ids")
            private_attacks = entry.get("private_attack_ids")
            official_attacks = entry.get("official_attack_ids")
            bridge_hash = entry.get("bridge_record_sha256")
            if (
                type(semantic_card_id) is not str or not semantic_card_id
                or type(private_uid) is not str or not private_uid
                or type(official_ids) is not list or len(official_ids) != 1
                or type(private_attacks) is not list
                or type(official_attacks) is not list
                or len(private_attacks) != len(official_attacks)
                or type(bridge_hash) is not str or len(bridge_hash) != 64
            ):
                raise A3DeckCompatibilityError("semantic_correspondence_entry_invalid")
            relation.bind_card_identity(
                semantic_card_id=semantic_card_id,
                left_card_id=private_uid,
                right_card_ids=tuple(official_ids),
                evidence_kind="exact_corresponding_printing",
                evidence_hash=bridge_hash,
            )
            for ordinal, (private_attack, official_attack) in enumerate(
                zip(private_attacks, official_attacks, strict=True)
            ):
                relation.bind_attack_identity(
                    semantic_attack_id=f"{semantic_card_id}:attack:{ordinal}",
                    left_attack_id=private_attack,
                    right_attack_ids=(official_attack,),
                    owner_semantic_card_id=semantic_card_id,
                    evidence_hash=bridge_hash,
                )
            loaded.add(semantic_card_id)
    if not loaded:
        raise A3DeckCompatibilityError("semantic_correspondence_empty")
    return len(loaded)


__all__ = [
    "A3DeckCompatibilityError", "build_official_deck_compatibility_report",
    "public_compatibility_summary", "register_private_semantic_bridge",
]
