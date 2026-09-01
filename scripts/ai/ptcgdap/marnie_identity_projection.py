"""Offline-only Marnie serial/catalog/projector integration audit.

Serialized dictionaries from this module are conformance evidence only.  They
never grant selection, binding, ticket, Host, projector, or execution authority.
"""

from __future__ import annotations

from copy import deepcopy
import hashlib
from pathlib import Path
import re
import struct
from types import MappingProxyType
from typing import Any, Iterable, Mapping

from .card_id_catalog import CardIdCatalog
from .marnie_vertical_slice import MarnieVerticalSlice
from .source_lock import canonical_json_v1_bytes, load_json_bytes_strict


_EXPECTED_BUNDLE_CANONICAL_SHA256 = "1EB530AB7DFACBE6AB098A6C67D6AAE0BC1871FF3E2F48C9284E8539EE6ACDC4"
_EXPECTED_RUNTIME_INTEGRITY_SHA256 = "CADBD5A469D93575DCF757BA701C9315A545B17271E758167C1D2C82E8F3595E"
_EXPECTED_RELATION_CACHE_SHA256 = "C16EE05C42083C55C555AC1C1DBB9A1C625F8DB06ADB4ECC5D5A9D6B1626C166"
_EXPECTED_PARENT_FIXTURE_SHA256 = "7E0CF80D7B2872C29F69BA15548857F1F32407943371D3C12A266A0E471EC425"
_EXPECTED_PARENT_POLICY_SHA256 = "F4E88E5DB4E480BA8441BE7B3A7C81CE3DB40ED1917EB37BCDCAC1C32B1ABD6C"
_EXPECTED_CATALOG_SHA256 = "AB8CF10465F492A98DA8247A84572AECEE281D0726F7BB7B8E5DBC03A6AC70D4"
_EXPECTED_PROJECTOR_SHA256 = "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"
_MAX_JSON_BYTES = 2 * 1024 * 1024
_MAX_SAFE_INTEGER = 9007199254740991
_SHA256_RE = re.compile(r"^[0-9A-F]{64}$")
_FRAME_IDS = (
    "w0_initial", "w1_setup_active", "w2_setup_bench", "w3_main",
    "w4_spikemuth_deck", "w5_punk_up_sources", "w5_punk_up_target_1",
    "w5_punk_up_target_2", "w6_shadow_bullet_attack", "w6_shadow_bullet_target",
    "w7_take_prize", "w7_forced_send_out", "w7_terminal",
)
_MUTATIONS = frozenset((
    "card_unknown", "serial_relation_conflict", "player_index_invalid",
    "attack_unknown", "attack_owner_mismatch", "hidden_private_key",
    "host_entity_key",
))
_EXPECTED_ARTIFACTS = (
    ("marnie_identity_projection_schema_v1", "contracts/ptcgdap/marnie_identity_projection.schema.json", "schema"),
    ("marnie_identity_projection_profile_v1", "contracts/ptcgdap/marnie_identity_projection_profile.json", "profile"),
    ("marnie_identity_projection_audit_v1", "data/ptcgdap/marnie_vertical_slice/marnie_identity_projection_v1.json", "audit"),
    ("marnie_identity_projection_vectors_v1", "contracts/ptcgdap/marnie_identity_projection_conformance_vectors.json", "vectors"),
)
_FORBIDDEN_KEYS = frozenset((
    "search_begin_input", "raw_private_hash", "token_free_callback_hash",
    "host_pokemon_entity", "host_pokemon_entity_serial", "instance_id",
    "object_id", "private_sentinel",
))


class MarnieIdentityProjectionError(RuntimeError):
    def __init__(self, code: str) -> None:
        self.code = code
        super().__init__(code)


def _sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _freeze(value: Any) -> Any:
    if type(value) is dict:
        return MappingProxyType({key: _freeze(child) for key, child in value.items()})
    if type(value) is list:
        return tuple(_freeze(child) for child in value)
    return value


def _thaw(value: Any) -> Any:
    if isinstance(value, Mapping):
        return {key: _thaw(child) for key, child in value.items()}
    if type(value) is tuple:
        return [_thaw(child) for child in value]
    return value


def _contained(root: Path, relative: str) -> Path:
    if type(relative) is not str or not relative or "\\" in relative or "\0" in relative:
        raise MarnieIdentityProjectionError("identity_bundle_invalid")
    path = Path(relative)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        raise MarnieIdentityProjectionError("identity_bundle_invalid")
    try:
        resolved = (root / path).resolve()
        resolved.relative_to(root)
    except (OSError, RuntimeError, ValueError) as exc:
        raise MarnieIdentityProjectionError("identity_bundle_invalid") from exc
    return resolved


def _read_json_once(path: Path) -> tuple[Any, bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise MarnieIdentityProjectionError("identity_file_missing") from exc
    if len(raw) > _MAX_JSON_BYTES:
        raise MarnieIdentityProjectionError("identity_file_too_large")
    try:
        return load_json_bytes_strict(raw), raw
    except (UnicodeError, ValueError) as exc:
        raise MarnieIdentityProjectionError("identity_json_invalid") from exc


def _canonical_file_hash(path: Path) -> str:
    value, _ = _read_json_once(path)
    try:
        return _sha256(canonical_json_v1_bytes(value))
    except ValueError as exc:
        raise MarnieIdentityProjectionError("identity_artifact_invalid") from exc


def _decode_node(node: Any) -> Any:
    if type(node) is not dict or type(node.get("kind")) is not str:
        raise MarnieIdentityProjectionError("frame_identity_invalid")
    kind = node["kind"]
    if kind == "null":
        return None
    if kind in {"boolean", "integer", "string"}:
        return deepcopy(node.get("value"))
    if kind == "binary64":
        raw = node.get("ieee754_hex")
        if type(raw) is not str or len(raw) != 16:
            raise MarnieIdentityProjectionError("frame_identity_invalid")
        try:
            return struct.unpack(">d", bytes.fromhex(raw))[0]
        except (ValueError, struct.error) as exc:
            raise MarnieIdentityProjectionError("frame_identity_invalid") from exc
    if kind == "array":
        if type(node.get("items")) is not list:
            raise MarnieIdentityProjectionError("frame_identity_invalid")
        return [_decode_node(child) for child in node["items"]]
    if kind == "object":
        if type(node.get("entries")) is not list:
            raise MarnieIdentityProjectionError("frame_identity_invalid")
        result: dict[str, Any] = {}
        for entry in node["entries"]:
            if type(entry) is not dict or set(entry) != {"key", "value"} or type(entry["key"]) is not str or entry["key"] in result:
                raise MarnieIdentityProjectionError("frame_identity_invalid")
            result[entry["key"]] = _decode_node(entry["value"])
        return result
    raise MarnieIdentityProjectionError("frame_identity_invalid")


def _walk(value: Any) -> Iterable[dict[str, Any]]:
    if type(value) is dict:
        yield value
        for child in value.values():
            yield from _walk(child)
    elif type(value) is list:
        for child in value:
            yield from _walk(child)


def _is_positive_safe_int(value: Any) -> bool:
    return type(value) is int and 0 < value <= _MAX_SAFE_INTEGER


def _identity(item: dict[str, Any]) -> tuple[int, int, int] | None:
    if not all(key in item for key in ("serial", "playerIndex")):
        return None
    if "id" in item:
        official_id = item["id"]
    elif "cardId" in item:
        official_id = item["cardId"]
    else:
        return None
    serial = item["serial"]
    player = item["playerIndex"]
    if not _is_positive_safe_int(official_id) or not _is_positive_safe_int(serial) or type(player) is not int or player not in (0, 1):
        raise MarnieIdentityProjectionError("frame_identity_invalid")
    return official_id, serial, player


def _runtime_digest(documents: Mapping[str, Any]) -> str:
    return _sha256(canonical_json_v1_bytes({key: _thaw(documents[key]) for key in ("bundle", "schema", "profile", "audit", "vectors")}))


def _relation_cache_digest(known_cards: Any, mapped_cards: Any, attack_owners: Any) -> str:
    return _sha256(canonical_json_v1_bytes({
        "known_cards": sorted(known_cards),
        "mapped_cards": sorted(mapped_cards),
        "attack_owners": {str(key): attack_owners[key] for key in sorted(attack_owners)},
    }))


def _success(value: Any) -> dict[str, Any]:
    return {"ok": True, "error_code": "", "value": deepcopy(value)}


def _failure(code: str) -> dict[str, Any]:
    return {"ok": False, "error_code": code, "value": None}


class MarnieIdentityProjection:
    __slots__ = (
        "_bundle", "_schema", "_profile", "_audit", "_vectors",
        "_parent", "_catalog", "_known_cards", "_mapped_cards", "_attack_owners",
        "_runtime_integrity_sha256",
    )

    def __init__(self, *_: Any, **__: Any) -> None:
        raise MarnieIdentityProjectionError("direct_construction_forbidden")

    @classmethod
    def load_default(cls) -> "MarnieIdentityProjection":
        return cls.load_trusted_bundle(Path(__file__).resolve().parents[3])

    @classmethod
    def load_trusted_bundle(cls, repository_root: Path) -> "MarnieIdentityProjection":
        root = Path(repository_root).resolve()
        bundle_path = _contained(root, "contracts/ptcgdap/marnie_identity_projection_bundle.json")
        bundle, _ = _read_json_once(bundle_path)
        if type(bundle) is not dict:
            raise MarnieIdentityProjectionError("identity_bundle_invalid")
        try:
            bundle_hash = _sha256(canonical_json_v1_bytes(bundle))
        except ValueError as exc:
            raise MarnieIdentityProjectionError("identity_bundle_invalid") from exc
        if bundle_hash != _EXPECTED_BUNDLE_CANONICAL_SHA256:
            raise MarnieIdentityProjectionError("identity_bundle_trust_anchor_mismatch")
        if (
            bundle.get("bundle_id") != "ptcgdap-marnie-identity-projection-p5-wp4-v1"
            or bundle.get("status") != "offline_shadow_identity_projection_gate"
            or type(bundle.get("artifacts")) is not list
            or len(bundle["artifacts"]) != len(_EXPECTED_ARTIFACTS)
        ):
            raise MarnieIdentityProjectionError("identity_bundle_invalid")

        documents: dict[str, Any] = {"bundle": bundle}
        seen: set[str] = set()
        for index, (artifact_id, relative, key) in enumerate(_EXPECTED_ARTIFACTS):
            entry = bundle["artifacts"][index]
            if type(entry) is not dict or set(entry) != {"id", "path", "canonical_sha256"}:
                raise MarnieIdentityProjectionError("identity_bundle_invalid")
            if (entry.get("id"), entry.get("path")) != (artifact_id, relative) or relative in seen:
                raise MarnieIdentityProjectionError("identity_bundle_invalid")
            seen.add(relative)
            expected_hash = entry.get("canonical_sha256")
            if type(expected_hash) is not str or _SHA256_RE.fullmatch(expected_hash) is None:
                raise MarnieIdentityProjectionError("identity_bundle_invalid")
            document, _ = _read_json_once(_contained(root, relative))
            try:
                actual_hash = _sha256(canonical_json_v1_bytes(document))
            except ValueError as exc:
                raise MarnieIdentityProjectionError("identity_artifact_invalid") from exc
            if actual_hash != expected_hash:
                raise MarnieIdentityProjectionError("identity_artifact_hash_mismatch")
            documents[key] = document

        parent_refs = (
            ("parent_fixture_bundle", "contracts/ptcgdap/marnie_vertical_slice_bundle.json", _EXPECTED_PARENT_FIXTURE_SHA256),
            ("parent_capability_policy_bundle", "contracts/ptcgdap/marnie_capability_policy_bundle.json", _EXPECTED_PARENT_POLICY_SHA256),
            ("card_catalog_bundle", "contracts/ptcgdap/card_id_catalog_bundle.json", _EXPECTED_CATALOG_SHA256),
            ("projector_bundle", "contracts/ptcgdap/godot_observation_projector_bundle.json", _EXPECTED_PROJECTOR_SHA256),
        )
        for field, relative, expected_hash in parent_refs:
            if bundle.get(field) != {"path": relative, "canonical_sha256": expected_hash}:
                raise MarnieIdentityProjectionError("identity_bundle_invalid")
            if _canonical_file_hash(_contained(root, relative)) != expected_hash:
                raise MarnieIdentityProjectionError("identity_parent_hash_mismatch")

        try:
            parent = MarnieVerticalSlice.load_trusted_bundle(root)
            catalog = CardIdCatalog.load_trusted_bundle(root)
        except Exception as exc:
            raise MarnieIdentityProjectionError("identity_parent_invalid") from exc
        if parent.bundle_hash() != _EXPECTED_PARENT_FIXTURE_SHA256 or catalog.catalog_hash() != _EXPECTED_CATALOG_SHA256:
            raise MarnieIdentityProjectionError("identity_parent_invalid")

        audit = documents["audit"]
        if type(audit) is not dict or type(audit.get("summary")) is not dict:
            raise MarnieIdentityProjectionError("identity_artifact_invalid")
        known_cards = frozenset(audit["summary"].get("distinct_official_card_ids", []))
        mapped_cards = frozenset(audit["summary"].get("mapped_official_card_ids", []))
        attack_ids = audit["summary"].get("official_attack_ids", [])
        if len(known_cards) != 34 or len(mapped_cards) != 9 or attack_ids != [937, 1240]:
            raise MarnieIdentityProjectionError("identity_artifact_invalid")
        for official_id in sorted(known_cards):
            card_result = catalog.lookup_official_card(official_id)
            bridge_result = catalog.lookup_local_printing_for_official_card(official_id)
            if not card_result["ok"]:
                raise MarnieIdentityProjectionError("identity_catalog_relation_invalid")
            if official_id in mapped_cards:
                if not bridge_result["ok"]:
                    raise MarnieIdentityProjectionError("identity_catalog_relation_invalid")
            elif bridge_result != {"ok": False, "error_code": "official_card_unmapped", "value": None}:
                raise MarnieIdentityProjectionError("identity_catalog_relation_invalid")
        attack_owners: dict[int, int] = {}
        for attack_id in attack_ids:
            attack_result = catalog.lookup_official_attack(attack_id)
            if not attack_result["ok"]:
                raise MarnieIdentityProjectionError("identity_catalog_relation_invalid")
            attack_owners[attack_id] = attack_result["value"]["owner_official_card_id"]

        frozen = {key: _freeze(value) for key, value in documents.items()}
        digest = _runtime_digest(frozen)
        if digest != _EXPECTED_RUNTIME_INTEGRITY_SHA256:
            raise MarnieIdentityProjectionError("identity_integrity_invalid")
        instance = object.__new__(cls)
        for key, value in frozen.items():
            object.__setattr__(instance, f"_{key}", value)
        object.__setattr__(instance, "_parent", parent)
        object.__setattr__(instance, "_catalog", catalog)
        object.__setattr__(instance, "_known_cards", known_cards)
        object.__setattr__(instance, "_mapped_cards", mapped_cards)
        object.__setattr__(instance, "_attack_owners", MappingProxyType(attack_owners))
        object.__setattr__(instance, "_runtime_integrity_sha256", digest)
        if _relation_cache_digest(instance._known_cards, instance._mapped_cards, instance._attack_owners) != _EXPECTED_RELATION_CACHE_SHA256:
            raise MarnieIdentityProjectionError("identity_catalog_relation_invalid")
        if instance._derived_audit() != _thaw(instance._audit):
            raise MarnieIdentityProjectionError("identity_source_relation_invalid")
        return instance

    def _documents(self) -> dict[str, Any]:
        return {key: getattr(self, f"_{key}") for key in ("bundle", "schema", "profile", "audit", "vectors")}

    def validate_integrity(self) -> bool:
        try:
            return (
                type(self._runtime_integrity_sha256) is str
                and self._runtime_integrity_sha256 == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and _runtime_digest(self._documents()) == _EXPECTED_RUNTIME_INTEGRITY_SHA256
                and type(self._parent) is MarnieVerticalSlice
                and type(self._catalog) is CardIdCatalog
                and _relation_cache_digest(self._known_cards, self._mapped_cards, self._attack_owners) == _EXPECTED_RELATION_CACHE_SHA256
            )
        except Exception:
            return False

    def bundle_hash(self) -> str:
        if not self.validate_integrity():
            raise MarnieIdentityProjectionError("identity_integrity_invalid")
        return _EXPECTED_BUNDLE_CANONICAL_SHA256

    def _audit_tree(self, tree: dict[str, Any], visibility: dict[str, Any]) -> tuple[dict[str, Any], dict[int, tuple[int, int]]]:
        keys = {key for item in _walk(tree) for key in item}
        if keys & {"host_pokemon_entity", "host_pokemon_entity_serial"}:
            raise MarnieIdentityProjectionError("host_entity_present")
        if keys & _FORBIDDEN_KEYS:
            raise MarnieIdentityProjectionError("hidden_identity_present")
        if (
            type(visibility) is not dict
            or visibility.get("opponent_hand_hidden") is not True
            or visibility.get("prizes_concealed") is not True
            or visibility.get("opponent_draw_identity_absent") is not True
        ):
            raise MarnieIdentityProjectionError("hidden_identity_present")
        relations: dict[int, tuple[int, int]] = {}
        ids: set[int] = set()
        attack_ids: set[int] = set()
        attack_pairs: set[tuple[int, int]] = set()
        occurrences = evolved = pre_count = 0
        for item in _walk(tree):
            identity = _identity(item)
            if identity is not None:
                official_id, serial, player = identity
                if official_id not in self._known_cards:
                    raise MarnieIdentityProjectionError("official_card_unknown")
                previous = relations.get(serial)
                if previous is not None and previous != (official_id, player):
                    raise MarnieIdentityProjectionError("serial_relation_conflict")
                relations[serial] = (official_id, player)
                ids.add(official_id)
                occurrences += 1
            if "attackId" in item:
                attack_id = item["attackId"]
                if not _is_positive_safe_int(attack_id) or attack_id not in self._attack_owners:
                    raise MarnieIdentityProjectionError("official_attack_unknown")
                owner = self._attack_owners[attack_id]
                if "cardId" in item and item["cardId"] != owner:
                    raise MarnieIdentityProjectionError("attack_owner_mismatch")
                attack_ids.add(attack_id)
                attack_pairs.add((attack_id, owner))
            pre = item.get("preEvolution")
            if type(pre) is list and pre:
                identity = _identity(item)
                if identity is None:
                    raise MarnieIdentityProjectionError("frame_identity_invalid")
                evolved += 1
                pre_count += len(pre)
                for child in pre:
                    if type(child) is not dict:
                        raise MarnieIdentityProjectionError("frame_identity_invalid")
                    child_identity = _identity(child)
                    if child_identity is None or child_identity[1] == identity[1] or child_identity[2] != identity[2]:
                        raise MarnieIdentityProjectionError("frame_identity_invalid")
        return ({
            "identity_occurrence_count": occurrences,
            "unique_serial_count": len(relations),
            "distinct_official_card_ids": sorted(ids),
            "mapped_official_card_ids": sorted(ids & self._mapped_cards),
            "known_unmapped_official_card_ids": sorted(ids - self._mapped_cards),
            "official_attack_ids": sorted(attack_ids),
            "attack_owner_pairs": [{"official_attack_id": attack_id, "owner_official_card_id": owner} for attack_id, owner in sorted(attack_pairs)],
            "evolved_pokemon_count": evolved, "pre_evolution_card_count": pre_count,
            "serial_relation_consistent": True, "top_serial_distinct_from_pre_evolution": True,
            "hidden_identity_absent": True, "host_entity_absent": True,
        }, relations)

    def _derived_audit(self) -> dict[str, Any]:
        frames = []
        cross: dict[int, tuple[int, int]] = {}
        all_ids: set[int] = set()
        all_attacks: set[int] = set()
        total = 0
        for ordinal, frame_id in enumerate(_FRAME_IDS):
            source = self._parent.frame(frame_id)
            if source["public_tree"] is None:
                detail = {
                    "identity_occurrence_count": 0, "unique_serial_count": 0,
                    "distinct_official_card_ids": [], "mapped_official_card_ids": [],
                    "known_unmapped_official_card_ids": [], "official_attack_ids": [],
                    "attack_owner_pairs": [], "evolved_pokemon_count": 0,
                    "pre_evolution_card_count": 0, "serial_relation_consistent": True,
                    "top_serial_distinct_from_pre_evolution": True,
                    "hidden_identity_absent": True, "host_entity_absent": True,
                }
                relations = {}
                status = "terminal_no_observation"
            else:
                tree = _decode_node(source["public_tree"])
                if type(tree) is not dict:
                    raise MarnieIdentityProjectionError("frame_identity_invalid")
                detail, relations = self._audit_tree(tree, source["visibility"])
                status = "verified_public_identity"
            for serial, relation in relations.items():
                if serial in cross and cross[serial] != relation:
                    raise MarnieIdentityProjectionError("serial_relation_conflict")
                cross[serial] = relation
            total += detail["identity_occurrence_count"]
            all_ids.update(detail["distinct_official_card_ids"])
            all_attacks.update(detail["official_attack_ids"])
            frames.append({
                "ordinal": ordinal, "frame_id": frame_id, "status": status,
                "public_observation_hash": source["public_observation_hash"], **detail,
            })
        expected = _thaw(self._audit)
        summary = deepcopy(expected["summary"])
        if (
            summary["identity_occurrence_count"] != total
            or summary["cross_frame_unique_serial_count"] != len(cross)
            or summary["distinct_official_card_ids"] != sorted(all_ids)
            or summary["official_attack_ids"] != sorted(all_attacks)
        ):
            raise MarnieIdentityProjectionError("identity_source_relation_invalid")
        return {
            "schema_version": 1, "artifact_kind": "frame_audit", "audit_id": expected["audit_id"],
            "profile_id": expected["profile_id"],
            "source_trajectory_artifact_id": expected["source_trajectory_artifact_id"],
            "source_trajectory_canonical_sha256": expected["source_trajectory_canonical_sha256"],
            "official_deck_artifact_id": expected["official_deck_artifact_id"],
            "official_deck_canonical_sha256": expected["official_deck_canonical_sha256"],
            "frames": frames, "summary": summary,
            "production_actions_used": False, "execution_authority": False,
        }

    def _result_value(self, frames: list[dict[str, Any]], operation: str) -> dict[str, Any]:
        return {
            "accepted": True, "operation": operation, "frame_count": len(frames),
            "frames": deepcopy(frames),
            "summary": deepcopy(_thaw(self._audit)["summary"]) if operation == "audit_all" else None,
            "production_actions_used": False, "execution_authority": False,
        }

    def audit_all(self) -> dict[str, Any]:
        if not self.validate_integrity():
            return _failure("identity_integrity_invalid")
        return _success(self._result_value(_thaw(self._audit)["frames"], "audit_all"))

    def audit_frame(self, frame_id: Any) -> dict[str, Any]:
        if not self.validate_integrity():
            return _failure("identity_integrity_invalid")
        if type(frame_id) is not str:
            return _failure("input_type_invalid")
        for frame in _thaw(self._audit)["frames"]:
            if frame["frame_id"] == frame_id:
                return _success(self._result_value([frame], "audit_frame"))
        return _failure("frame_unknown")

    @staticmethod
    def _mutate(tree: dict[str, Any], mutation: str) -> None:
        items = list(_walk(tree))
        identities = [(item, _identity(item)) for item in items]
        identities = [(item, identity) for item, identity in identities if identity is not None]
        if mutation == "card_unknown":
            item = identities[0][0]
            item["id" if "id" in item else "cardId"] = 9999
        elif mutation == "player_index_invalid":
            identities[0][0]["playerIndex"] = 2
        elif mutation == "serial_relation_conflict":
            seen: dict[int, dict[str, Any]] = {}
            for item, identity in identities:
                assert identity is not None
                if identity[1] in seen:
                    item["id" if "id" in item else "cardId"] = 7 if identity[0] != 7 else 112
                    return
                seen[identity[1]] = item
            raise MarnieIdentityProjectionError("frame_identity_invalid")
        elif mutation == "attack_unknown":
            next(item for item in items if "attackId" in item)["attackId"] = 9999
        elif mutation == "attack_owner_mismatch":
            item = next(item for item in items if "attackId" in item and "cardId" in item)
            item["cardId"] = 7
            item["serial"] = _MAX_SAFE_INTEGER
        elif mutation == "hidden_private_key":
            tree["private_sentinel"] = "SECRET"
        elif mutation == "host_entity_key":
            tree["host_pokemon_entity_serial"] = 1
        else:
            raise MarnieIdentityProjectionError("input_type_invalid")

    def probe_frame_mutation(self, frame_id: Any, mutation: Any) -> dict[str, Any]:
        if not self.validate_integrity():
            return _failure("identity_integrity_invalid")
        try:
            if self._parent.bundle_hash() != _EXPECTED_PARENT_FIXTURE_SHA256:
                return _failure("identity_integrity_invalid")
        except Exception:
            return _failure("identity_integrity_invalid")
        if type(frame_id) is not str or type(mutation) is not str or mutation not in _MUTATIONS:
            return _failure("input_type_invalid")
        if frame_id not in _FRAME_IDS:
            return _failure("frame_unknown")
        source = self._parent.frame(frame_id)
        if source["public_tree"] is None:
            return _failure("frame_identity_invalid")
        tree = _decode_node(source["public_tree"])
        try:
            self._mutate(tree, mutation)
            self._audit_tree(tree, source["visibility"])
        except MarnieIdentityProjectionError as exc:
            return _failure(exc.code)
        return _failure("frame_identity_invalid")

    def run(self, operation: Any, value: Any) -> dict[str, Any]:
        if not self.validate_integrity():
            return _failure("identity_integrity_invalid")
        if type(operation) is not str or type(value) is not dict:
            return _failure("input_type_invalid")
        if operation == "audit_all" and value == {}:
            return self.audit_all()
        if operation == "audit_frame" and set(value) == {"frame_id"}:
            return self.audit_frame(value["frame_id"])
        if operation == "probe_frame_mutation" and set(value) == {"frame_id", "mutation"}:
            return self.probe_frame_mutation(value["frame_id"], value["mutation"])
        return _failure("operation_unknown")

    def audit_snapshot(self) -> dict[str, Any]:
        if not self.validate_integrity():
            raise MarnieIdentityProjectionError("identity_integrity_invalid")
        summary = _thaw(self._audit)["summary"]
        return {
            "bundle_canonical_sha256": _EXPECTED_BUNDLE_CANONICAL_SHA256,
            "runtime_integrity_sha256": _EXPECTED_RUNTIME_INTEGRITY_SHA256,
            "frame_count": summary["frame_count"],
            "distinct_official_card_id_count": len(summary["distinct_official_card_ids"]),
            "cross_frame_unique_serial_count": summary["cross_frame_unique_serial_count"],
            "mapped_official_card_id_count": len(summary["mapped_official_card_ids"]),
            "known_unmapped_official_card_id_count": len(summary["known_unmapped_official_card_ids"]),
            "production_actions_used": False, "execution_authority": False,
        }
