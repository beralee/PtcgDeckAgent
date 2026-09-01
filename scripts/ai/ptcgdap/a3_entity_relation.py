from __future__ import annotations

import copy
import hashlib
from dataclasses import dataclass
from typing import Any, Mapping, Sequence

from .cabt_tree_hash import jcs_canonical_json_bytes


class EntityRelationError(RuntimeError):
    pass


_SERIAL_FIELDS = frozenset({"serial", "cardSerial", "srcSerial", "pokemonSerial"})
_CARD_ID_FIELDS = frozenset({"cardId", "srcCardId", "contextCardId"})
_ATTACK_ID_FIELDS = frozenset({"attackId", "srcAttackId"})
_FORBIDDEN_INTENT_KEYS = frozenset({"name", "cardName", "displayName", "slotName", "zone"})
_CARD_EVIDENCE_KINDS = frozenset({
    "exact_corresponding_printing",
    "reviewed_equivalent_print",
    "legacy_exact_official_id",
})


def _hash(value: Any) -> str:
    return hashlib.sha256(jcs_canonical_json_bytes(value)).hexdigest().upper()


@dataclass(frozen=True, slots=True)
class EntityBinding:
    semantic_id: str
    semantic_card_id: str | int
    left_card_id: str | int
    official_card_id: int
    deck_occurrence: int
    left_serial: int
    right_serial: int
    evidence_kind: str
    evidence_hash: str


@dataclass(frozen=True, slots=True)
class CardIdentityBinding:
    semantic_card_id: str
    left_card_id: str | int
    right_card_ids: tuple[int, ...]
    evidence_kind: str
    evidence_hash: str


@dataclass(frozen=True, slots=True)
class AttackIdentityBinding:
    semantic_attack_id: str
    left_attack_id: str | int
    right_attack_ids: tuple[int, ...]
    owner_semantic_card_id: str
    evidence_hash: str


class SemanticEntityRelation:
    """Evidence-only identity correspondence plus match-local serial renaming.

    Public/private card IDs and official Card IDs are different domains.  They
    become comparable only through an explicit printing/effect witness.  Card
    names, slot names and current zones are deliberately absent from the API.
    Entity serials additionally require an exact deck occurrence or later
    event-lineage witness.
    """

    def __init__(self) -> None:
        self._bindings: dict[str, EntityBinding] = {}
        self._by_side: dict[str, dict[int, str]] = {"left": {}, "right": {}}
        self._card_identity_bindings: dict[str, CardIdentityBinding] = {}
        self._card_ids_by_side: dict[str, dict[tuple[str, str], str | int]] = {
            "left": {}, "right": {},
        }
        self._attack_identity_bindings: dict[str, AttackIdentityBinding] = {}
        self._attack_ids_by_side: dict[str, dict[tuple[str, str], str]] = {
            "left": {}, "right": {},
        }
        self._movement: list[dict[str, Any]] = []

    @staticmethod
    def _identity_key(value: str | int) -> tuple[str, str]:
        if type(value) is int and value > 0:
            return ("int", str(value))
        if type(value) is str and value:
            return ("str", value)
        raise EntityRelationError("parity_identity_value_invalid")

    def bind_card_identity(
        self,
        *,
        semantic_card_id: str,
        left_card_id: str | int,
        right_card_ids: Sequence[int],
        evidence_kind: str,
        evidence_hash: str,
    ) -> None:
        if (
            type(semantic_card_id) is not str or not semantic_card_id
            or evidence_kind not in _CARD_EVIDENCE_KINDS
            or type(evidence_hash) is not str or len(evidence_hash) != 64
            or type(right_card_ids) not in (list, tuple)
            or not right_card_ids
            or any(type(value) is not int or value <= 0 for value in right_card_ids)
            or len(right_card_ids) != len(set(right_card_ids))
        ):
            raise EntityRelationError("parity_card_identity_bridge_invalid")
        left_key = self._identity_key(left_card_id)
        right_values = tuple(right_card_ids)
        binding = CardIdentityBinding(
            semantic_card_id, left_card_id, right_values, evidence_kind, evidence_hash,
        )
        existing = self._card_identity_bindings.get(semantic_card_id)
        if existing is not None:
            if existing != binding:
                raise EntityRelationError("parity_card_identity_bridge_conflict")
            return
        if left_key in self._card_ids_by_side["left"]:
            raise EntityRelationError("parity_card_identity_bridge_conflict")
        right_keys = [self._identity_key(value) for value in right_values]
        if any(key in self._card_ids_by_side["right"] for key in right_keys):
            raise EntityRelationError("parity_card_identity_bridge_conflict")
        self._card_ids_by_side["left"][left_key] = semantic_card_id
        for key in right_keys:
            self._card_ids_by_side["right"][key] = semantic_card_id
        self._card_identity_bindings[semantic_card_id] = binding

    def bind_attack_identity(
        self,
        *,
        semantic_attack_id: str,
        left_attack_id: str | int,
        right_attack_ids: Sequence[int],
        owner_semantic_card_id: str,
        evidence_hash: str,
    ) -> None:
        if (
            type(semantic_attack_id) is not str or not semantic_attack_id
            or type(owner_semantic_card_id) is not str or not owner_semantic_card_id
            or type(evidence_hash) is not str or len(evidence_hash) != 64
            or type(right_attack_ids) not in (list, tuple)
            or not right_attack_ids
            or any(type(value) is not int or value <= 0 for value in right_attack_ids)
            or len(right_attack_ids) != len(set(right_attack_ids))
        ):
            raise EntityRelationError("parity_attack_identity_bridge_invalid")
        binding = AttackIdentityBinding(
            semantic_attack_id, left_attack_id, tuple(right_attack_ids),
            owner_semantic_card_id, evidence_hash,
        )
        existing = self._attack_identity_bindings.get(semantic_attack_id)
        if existing is not None:
            if existing != binding:
                raise EntityRelationError("parity_attack_identity_bridge_conflict")
            return
        left_key = self._identity_key(left_attack_id)
        right_keys = [self._identity_key(value) for value in right_attack_ids]
        if (
            left_key in self._attack_ids_by_side["left"]
            or any(key in self._attack_ids_by_side["right"] for key in right_keys)
        ):
            raise EntityRelationError("parity_attack_identity_bridge_conflict")
        self._attack_ids_by_side["left"][left_key] = semantic_attack_id
        for key in right_keys:
            self._attack_ids_by_side["right"][key] = semantic_attack_id
        self._attack_identity_bindings[semantic_attack_id] = binding

    def bind_deck_occurrence(
        self,
        *,
        official_card_id: int,
        semantic_card_id: str | None = None,
        left_card_id: str | int | None = None,
        deck_occurrence: int,
        left_serial: int,
        right_serial: int,
        source_deck_hash: str,
    ) -> str:
        if (
            type(official_card_id) is not int or official_card_id <= 0
            or type(deck_occurrence) is not int or deck_occurrence < 0
            or type(left_serial) is not int or left_serial <= 0
            or type(right_serial) is not int or right_serial <= 0
            or type(source_deck_hash) is not str or len(source_deck_hash) != 64
        ):
            raise EntityRelationError("parity_entity_anchor_invalid")
        if semantic_card_id is None:
            semantic_card_value: str | int = official_card_id
            semantic_id = f"card:{official_card_id}:occurrence:{deck_occurrence}"
            legacy_key = f"legacy-official-card:{official_card_id}"
            if legacy_key not in self._card_identity_bindings:
                self.bind_card_identity(
                    semantic_card_id=legacy_key,
                    left_card_id=official_card_id,
                    right_card_ids=(official_card_id,),
                    evidence_kind="legacy_exact_official_id",
                    evidence_hash=_hash({
                        "kind": "legacy_exact_official_id",
                        "official_card_id": official_card_id,
                    }),
                )
            # Preserve the historical exact-ID semantic value for callers that
            # already express intents with the official numeric ID.
            self._card_ids_by_side["left"][self._identity_key(official_card_id)] = official_card_id
            self._card_ids_by_side["right"][self._identity_key(official_card_id)] = official_card_id
            left_card_value: str | int = official_card_id
        else:
            if type(semantic_card_id) is not str or not semantic_card_id or left_card_id is None:
                raise EntityRelationError("parity_entity_anchor_invalid")
            identity = self._card_identity_bindings.get(semantic_card_id)
            if (
                identity is None
                or identity.left_card_id != left_card_id
                or official_card_id not in identity.right_card_ids
            ):
                raise EntityRelationError("parity_card_identity_bridge_missing")
            semantic_card_value = semantic_card_id
            left_card_value = left_card_id
            semantic_id = f"entity:{semantic_card_id}:occurrence:{deck_occurrence}"
        evidence = _hash({
            "kind": "exact_deck_occurrence",
            "semantic_card_id": semantic_card_value,
            "left_card_id": left_card_value,
            "official_card_id": official_card_id,
            "deck_occurrence": deck_occurrence,
            "source_deck_hash": source_deck_hash,
        })
        self._bind(EntityBinding(
            semantic_id, semantic_card_value, left_card_value,
            official_card_id, deck_occurrence, left_serial,
            right_serial, "exact_deck_occurrence", evidence,
        ))
        return semantic_id

    def bind_lineage_successor(
        self,
        *,
        semantic_id: str,
        left_serial: int,
        right_serial: int,
        event_ordinal: int,
        event_fingerprint: str,
    ) -> None:
        binding = self._bindings.get(semantic_id)
        if (
            binding is None
            or type(left_serial) is not int or left_serial <= 0
            or type(right_serial) is not int or right_serial <= 0
            or type(event_ordinal) is not int or event_ordinal < 0
            or type(event_fingerprint) is not str or len(event_fingerprint) != 64
        ):
            raise EntityRelationError("parity_entity_lineage_invalid")
        self._preflight_serial("left", left_serial, semantic_id)
        self._preflight_serial("right", right_serial, semantic_id)
        self._by_side["left"][left_serial] = semantic_id
        self._by_side["right"][right_serial] = semantic_id
        self._movement.append({
            "semantic_id": semantic_id,
            "event_ordinal": event_ordinal,
            "event_fingerprint": event_fingerprint,
            "kind": "event_lineage_successor",
        })

    def bind_current_window_entity(
        self,
        *,
        semantic_card_id: str,
        left_card_id: str | int,
        official_card_id: int,
        left_serial: int,
        right_serial: int,
        window_evidence_hash: str,
    ) -> str:
        """Bind one publicly co-present operation entity across ID domains.

        This is deliberately not a deck-order claim.  It may be used only
        after the current ordered semantic frontier has matched without
        serials, and it binds the two physical instances for that window.
        """
        identity = self._card_identity_bindings.get(semantic_card_id)
        if (
            identity is None
            or identity.left_card_id != left_card_id
            or official_card_id not in identity.right_card_ids
            or type(left_serial) is not int or left_serial <= 0
            or type(right_serial) is not int or right_serial <= 0
            or type(window_evidence_hash) is not str or len(window_evidence_hash) != 64
        ):
            raise EntityRelationError("parity_current_window_entity_invalid")
        existing_left = self._by_side["left"].get(left_serial)
        existing_right = self._by_side["right"].get(right_serial)
        if existing_left is not None or existing_right is not None:
            if existing_left is None or existing_left != existing_right:
                raise EntityRelationError("parity_current_window_entity_conflict")
            return existing_left
        semantic_id = f"entity:{semantic_card_id}:window:{window_evidence_hash[:24]}"
        suffix = 0
        candidate = semantic_id
        while candidate in self._bindings:
            suffix += 1
            candidate = f"{semantic_id}:{suffix}"
        evidence = _hash({
            "kind": "current_window_correspondence",
            "semantic_card_id": semantic_card_id,
            "left_card_id": left_card_id,
            "official_card_id": official_card_id,
            "window_evidence_hash": window_evidence_hash,
        })
        self._bind(EntityBinding(
            candidate, semantic_card_id, left_card_id, official_card_id, suffix,
            left_serial, right_serial, "current_window_correspondence", evidence,
        ))
        return candidate

    def record_zone_movement(
        self,
        *,
        semantic_id: str,
        event_ordinal: int,
        from_zone: str,
        to_zone: str,
        event_fingerprint: str,
    ) -> None:
        if (
            semantic_id not in self._bindings
            or type(event_ordinal) is not int or event_ordinal < 0
            or not from_zone or not to_zone
            or type(event_fingerprint) is not str or len(event_fingerprint) != 64
        ):
            raise EntityRelationError("parity_entity_movement_invalid")
        self._movement.append({
            "semantic_id": semantic_id,
            "event_ordinal": event_ordinal,
            "from_zone": from_zone,
            "to_zone": to_zone,
            "event_fingerprint": event_fingerprint,
            "kind": "zone_movement_lineage",
        })

    def semantic_id(self, side: str, serial: int) -> str:
        if side not in self._by_side or type(serial) is not int or serial <= 0:
            raise EntityRelationError("parity_entity_serial_invalid")
        try:
            return self._by_side[side][serial]
        except KeyError as error:
            raise EntityRelationError("parity_entity_unbound") from error

    def semantic_card_id(self, side: str, card_id: str | int) -> str | int:
        if card_id == 0:
            return 0
        if side not in self._card_ids_by_side:
            raise EntityRelationError("parity_card_identity_side_invalid")
        try:
            return self._card_ids_by_side[side][self._identity_key(card_id)]
        except KeyError as error:
            raise EntityRelationError("parity_card_identity_unbound") from error

    def semantic_attack_id(self, side: str, attack_id: str | int) -> str | int:
        if attack_id == 0:
            return 0
        if side not in self._attack_ids_by_side:
            raise EntityRelationError("parity_attack_identity_side_invalid")
        try:
            return self._attack_ids_by_side[side][self._identity_key(attack_id)]
        except KeyError as error:
            raise EntityRelationError("parity_attack_identity_unbound") from error

    def semantic_tree(self, side: str, value: Any) -> Any:
        if side not in self._by_side:
            raise EntityRelationError("parity_tree_semanticization_invalid")

        def visit(current: Any, key: str | None = None) -> Any:
            if key in _SERIAL_FIELDS:
                if current == 0 and key == "serial":
                    return 0
                return self.semantic_id(side, current)
            if key in _CARD_ID_FIELDS:
                return self.semantic_card_id(side, current)
            if key in _ATTACK_ID_FIELDS:
                return self.semantic_attack_id(side, current)
            if type(current) is dict:
                return {
                    str(child_key): visit(child, str(child_key))
                    for child_key, child in current.items()
                }
            if type(current) is list:
                return [visit(child) for child in current]
            if type(current) is tuple:
                return tuple(visit(child) for child in current)
            return copy.deepcopy(current)

        return visit(value)

    def semantic_option(self, side: str, option: Mapping[str, Any]) -> dict[str, Any]:
        if side not in self._by_side or type(option) is not dict:
            raise EntityRelationError("parity_option_semanticization_invalid")
        return self.semantic_tree(side, option)

    def semantic_frontier(self, side: str, options: Sequence[Mapping[str, Any]]) -> tuple[str, ...]:
        return tuple(_hash(self.semantic_option(side, option)) for option in options)

    @property
    def relation_hash(self) -> str:
        return _hash({
            "bindings": [
                {
                    "semantic_id": binding.semantic_id,
                    "semantic_card_id": binding.semantic_card_id,
                    "left_card_id": binding.left_card_id,
                    "official_card_id": binding.official_card_id,
                    "deck_occurrence": binding.deck_occurrence,
                    "evidence_kind": binding.evidence_kind,
                    "evidence_hash": binding.evidence_hash,
                }
                for binding in sorted(self._bindings.values(), key=lambda item: item.semantic_id)
            ],
            "card_identity_bindings": [
                {
                    "semantic_card_id": binding.semantic_card_id,
                    "left_card_id": binding.left_card_id,
                    "right_card_ids": list(binding.right_card_ids),
                    "evidence_kind": binding.evidence_kind,
                    "evidence_hash": binding.evidence_hash,
                }
                for binding in sorted(
                    self._card_identity_bindings.values(),
                    key=lambda item: item.semantic_card_id,
                )
            ],
            "attack_identity_bindings": [
                {
                    "semantic_attack_id": binding.semantic_attack_id,
                    "left_attack_id": binding.left_attack_id,
                    "right_attack_ids": list(binding.right_attack_ids),
                    "owner_semantic_card_id": binding.owner_semantic_card_id,
                    "evidence_hash": binding.evidence_hash,
                }
                for binding in sorted(
                    self._attack_identity_bindings.values(),
                    key=lambda item: item.semantic_attack_id,
                )
            ],
            "movement": sorted(
                self._movement,
                key=lambda item: (item["event_ordinal"], item["semantic_id"], item["kind"]),
            ),
        })

    def _bind(self, binding: EntityBinding) -> None:
        if binding.semantic_id in self._bindings:
            raise EntityRelationError("parity_entity_duplicate_anchor")
        self._preflight_serial("left", binding.left_serial, binding.semantic_id)
        self._preflight_serial("right", binding.right_serial, binding.semantic_id)
        self._by_side["left"][binding.left_serial] = binding.semantic_id
        self._by_side["right"][binding.right_serial] = binding.semantic_id
        self._bindings[binding.semantic_id] = binding

    def _preflight_serial(self, side: str, serial: int, semantic_id: str) -> None:
        existing = self._by_side[side].get(serial)
        if existing is not None and existing != semantic_id:
            raise EntityRelationError("parity_entity_bijection_conflict")


class SemanticActionBinder:
    """Resolve one explicit semantic intent independently in each frontier."""

    @staticmethod
    def resolve(
        intent: Mapping[str, Any],
        *,
        side: str,
        options: Sequence[Mapping[str, Any]],
        relation: SemanticEntityRelation,
    ) -> list[int]:
        if type(intent) is not dict or any(key in intent for key in _FORBIDDEN_INTENT_KEYS):
            raise EntityRelationError("parity_semantic_intent_forbidden_identity")
        count = intent.get("count", 1)
        predicates = intent.get("match")
        if type(count) is not int or count < 0 or type(predicates) is not dict:
            raise EntityRelationError("parity_semantic_intent_invalid")
        matches: list[int] = []
        for index, raw_option in enumerate(options):
            semantic = relation.semantic_option(side, raw_option)
            if all(semantic.get(key) == value for key, value in predicates.items()):
                matches.append(index)
        if len(matches) != count:
            raise EntityRelationError("parity_semantic_intent_not_unique")
        return matches


__all__ = [
    "AttackIdentityBinding", "CardIdentityBinding", "EntityBinding",
    "EntityRelationError", "SemanticActionBinder",
    "SemanticEntityRelation",
]
