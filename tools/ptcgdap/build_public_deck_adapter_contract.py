from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CONTRACT_ROOT = ROOT / "contracts/ptcgdap"
CONTEXT_VECTORS = CONTRACT_ROOT / "strategic_context_v18_conformance_vectors.json"
PROFILE_ID = "ptcgdap-public-deck-adapter-p4-wp4-v1"
BUNDLE_ID = PROFILE_ID
PARENT_BUNDLE = "69D05747A9F91C19765D448B676C86E1D9DFA1BBAB108ED1374B854B34E48389"
SOURCE_LOCK = "8C9BF1ABFCCF56B5EA433313D7385C60CD7B7E7A693A53E3FD98D91289E3F205"
ADAPTER_PREFIX = b"PTCGDAP\0PUBLIC_DECK_ADAPTER_V1\0"
PROPOSAL_PREFIX = b"PTCGDAP\0PUBLIC_DECK_ADAPTER_PROPOSAL_V1\0"
ARTIFACTS = (
    "public_deck_adapter.schema.json",
    "public_deck_adapter_profile.json",
    "public_deck_adapter_conformance_vectors.json",
)
OPERATORS = ("goal_proposal", "macro_proposal", "tiebreak_score")
REASONS = {
    "goal_proposal": "public_goal_proposal",
    "macro_proposal": "public_macro_proposal",
    "tiebreak_score": "public_tiebreak_proposal",
}
GOAL_STAGES = ("acquire", "deploy", "fund", "ready", "execute", "maintain", "recover")
PREDICATES = (
    "select_type_raw",
    "select_context_raw",
    "option_type_raw",
    "option_card_id",
    "option_player_index",
    "acting_hand_card_id",
    "acting_active_card_id",
)
SAFE_MAX = 9007199254740991


def canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def digest(value: Any) -> str:
    return hashlib.sha256(canonical(value)).hexdigest().upper()


def domain_hash(prefix: bytes, value: Any) -> str:
    return hashlib.sha256(prefix + canonical(value)).hexdigest().upper()


def pretty(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _identifier_schema() -> dict[str, Any]:
    return {"type": "string", "pattern": "^[a-z0-9][a-z0-9._-]{0,127}$", "not": {"pattern": "(?i:private)"}}


def schema() -> dict[str, Any]:
    nullable_safe = {"oneOf": [{"type": "null"}, {"$ref": "#/$defs/safeInteger"}]}
    predicate = {
        "type": "object",
        "additionalProperties": False,
        "required": list(PREDICATES),
        "properties": {key: copy.deepcopy(nullable_safe) for key in PREDICATES},
    }
    rule = {
        "type": "object",
        "additionalProperties": False,
        "required": ["rule_id", "operator", "reason_code", "goal_stage", "priority", "predicate"],
        "properties": {
            "rule_id": {"$ref": "#/$defs/identifier"},
            "operator": {"enum": list(OPERATORS)},
            "reason_code": {"enum": list(REASONS.values())},
            "goal_stage": {"enum": list(GOAL_STAGES)},
            "priority": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]},
            "predicate": predicate,
        },
        "allOf": [
            {"if": {"properties": {"operator": {"const": operator}}}, "then": {"properties": {"reason_code": {"const": reason}}}}
            for operator, reason in REASONS.items()
        ],
    }
    document = {
        "type": "object",
        "additionalProperties": False,
        "required": ["schema_version", "adapter_id", "adapter_version", "rules"],
        "properties": {
            "schema_version": {"const": 1},
            "adapter_id": {"$ref": "#/$defs/identifier"},
            "adapter_version": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 1}]},
            "rules": {"type": "array", "maxItems": 128, "items": {"$ref": "#/$defs/rule"}},
        },
    }
    compiled = copy.deepcopy(document)
    compiled["required"] += ["profile_id", "authoritative", "adapter_hash"]
    compiled["properties"].update(
        {
            "profile_id": {"const": PROFILE_ID},
            "authoritative": {"const": False},
            "adapter_hash": {"$ref": "#/$defs/hash"},
        }
    )
    adapter_proposal = {
        "type": "object",
        "additionalProperties": False,
        "required": ["operator", "indexes", "reason_code"],
        "properties": {
            "operator": {"enum": list(OPERATORS)},
            "indexes": {"$ref": "#/$defs/indexArray"},
            "reason_code": {"enum": list(REASONS.values())},
        },
        "allOf": [
            {"if": {"properties": {"operator": {"const": operator}}}, "then": {"properties": {"reason_code": {"const": reason}}}}
            for operator, reason in REASONS.items()
        ],
    }
    matched_rule = {
        "type": "object",
        "additionalProperties": False,
        "required": ["rule_id", "operator", "goal_stage", "matched_indexes"],
        "properties": {
            "rule_id": {"$ref": "#/$defs/identifier"},
            "operator": {"enum": list(OPERATORS)},
            "goal_stage": {"enum": list(GOAL_STAGES)},
            "matched_indexes": {"$ref": "#/$defs/indexArray"},
        },
    }
    result = {
        "type": "object",
        "additionalProperties": False,
        "required": ["schema_version", "profile_id", "proposal_id", "adapter_id", "source", "adapter_proposals", "matched_rules", "authoritative", "proposal_hash"],
        "properties": {
            "schema_version": {"const": 1},
            "profile_id": {"const": PROFILE_ID},
            "proposal_id": {"$ref": "#/$defs/identifier"},
            "adapter_id": {"$ref": "#/$defs/identifier"},
            "source": {
                "type": "object",
                "additionalProperties": False,
                "required": ["context_hash", "window_id", "adapter_hash"],
                "properties": {key: {"$ref": "#/$defs/hash"} for key in ("context_hash", "window_id", "adapter_hash")},
            },
            "adapter_proposals": {"type": "array", "maxItems": 3, "items": {"$ref": "#/$defs/adapterProposal"}},
            "matched_rules": {"type": "array", "maxItems": 128, "items": {"$ref": "#/$defs/matchedRule"}},
            "authoritative": {"const": False},
            "proposal_hash": {"$ref": "#/$defs/hash"},
        },
    }
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://ptcgdap.local/contracts/public_deck_adapter.schema.json",
        "title": "PTCGDAP P4-WP4 public deck adapter documents and proposal audit values",
        "$defs": {
            "safeInteger": {"type": "integer", "minimum": -SAFE_MAX, "maximum": SAFE_MAX},
            "identifier": _identifier_schema(),
            "hash": {"type": "string", "pattern": "^[0-9A-F]{64}$"},
            "index": {"allOf": [{"$ref": "#/$defs/safeInteger"}, {"minimum": 0}]},
            "indexArray": {"type": "array", "maxItems": 1024, "uniqueItems": True, "items": {"$ref": "#/$defs/index"}},
            "rule": rule,
            "adapterDocument": document,
            "compiledAdapter": compiled,
            "adapterProposal": adapter_proposal,
            "matchedRule": matched_rule,
            "proposalResult": result,
        },
        "oneOf": [
            {"$ref": "#/$defs/adapterDocument"},
            {"$ref": "#/$defs/compiledAdapter"},
            {"$ref": "#/$defs/proposalResult"},
        ],
    }


def profile() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "source_authority": "exact_current_p4_wp1_strategic_context_owner",
        "hash_contract": {
            "canonicalization": "RFC8785_JCS_IJSON_SAFE_SUBSET",
            "adapter_prefix_utf8_hex": ADAPTER_PREFIX.hex().upper(),
            "proposal_prefix_utf8_hex": PROPOSAL_PREFIX.hex().upper(),
        },
        "adapter_contract": {
            "goal_stages": list(GOAL_STAGES),
            "operators": list(OPERATORS),
            "operator_reason_codes": REASONS,
            "predicate_fields": list(PREDICATES),
            "predicate_combination": "all_non_null_fields_must_match",
            "ordering": "minimum_priority_then_rule_order_then_current_option_index",
            "proposal_authority": "same_base_tier_ordering_hint_only",
            "missing_option_field": "predicate_does_not_match",
        },
        "result_contract": {
            "serialized_result_is_execution_authority": False,
            "owner_revalidation_required": True,
            "future_executor_must_revalidate_exact_context_and_ir": True,
            "proposal_may_not_filter_legality_or_forced_indexes": True,
        },
        "stable_error_codes": [
            "contract_error",
            "invalid_adapter_document",
            "unsupported_adapter_operator",
            "unsupported_goal_stage",
            "invalid_public_predicate",
            "private_adapter_input",
            "adapter_integrity_invalid",
            "invalid_context",
            "invalid_adapter",
            "invalid_proposal_id",
            "proposal_integrity_invalid",
        ],
        "forbidden_fields": ["callable", "module", "class", "code", "script", "path", "url", "import", "private_state", "display_name", "localized_name", "image"],
        "private_keys_denied": ["raw_private_hash", "token_free_callback_hash", "search_begin_input", "session", "callback", "binding", "ticket", "command", "object_ref", "pokemon_entity_serial"],
        "scope": {"public_deck_adapter_proposal": True, "deck_specific_rules": False, "policy": False, "trace_issuer": False, "live_owner": False},
    }


def empty_predicate(**changes: int | None) -> dict[str, int | None]:
    value: dict[str, int | None] = {key: None for key in PREDICATES}
    value.update(changes)
    return value


def adapter_document(adapter_id: str, rules: list[dict[str, Any]]) -> dict[str, Any]:
    return {"schema_version": 1, "adapter_id": adapter_id, "adapter_version": 1, "rules": rules}


def rule(rule_id: str, operator: str, stage: str, priority: int, predicate: dict[str, Any]) -> dict[str, Any]:
    return {"rule_id": rule_id, "operator": operator, "reason_code": REASONS[operator], "goal_stage": stage, "priority": priority, "predicate": predicate}


def expected_adapter(document: dict[str, Any]) -> dict[str, Any]:
    payload = {"schema_version": 1, "profile_id": PROFILE_ID, "adapter_id": document["adapter_id"], "adapter_version": document["adapter_version"], "rules": copy.deepcopy(document["rules"]), "authoritative": False}
    return {**payload, "adapter_hash": domain_hash(ADAPTER_PREFIX, payload)}


def _card_ids(cards: Any) -> set[int]:
    if not isinstance(cards, list):
        return set()
    return {card["id"] for card in cards if isinstance(card, dict) and type(card.get("id")) is int}


def _matches(predicate: dict[str, Any], context: dict[str, Any], option: dict[str, Any]) -> bool:
    raw = option["raw"]
    actual = {
        "select_type_raw": context["select_semantics"]["select_type_raw"],
        "select_context_raw": context["select_semantics"]["select_context_raw"],
        "option_type_raw": raw.get("type"),
        "option_card_id": raw.get("cardId"),
        "option_player_index": raw.get("playerIndex"),
    }
    for key in ("select_type_raw", "select_context_raw", "option_type_raw", "option_card_id", "option_player_index"):
        if predicate[key] is not None and actual[key] != predicate[key]:
            return False
    acting = context["public_state"]["acting_player"]
    if predicate["acting_hand_card_id"] is not None and predicate["acting_hand_card_id"] not in _card_ids(acting["hand"]):
        return False
    if predicate["acting_active_card_id"] is not None and predicate["acting_active_card_id"] not in _card_ids(acting["active"]):
        return False
    return True


def expected_result(proposal_id: str, context: dict[str, Any], adapter: dict[str, Any]) -> dict[str, Any]:
    options = context["select_semantics"]["options"]
    proposals = []
    matches = []
    for operator in OPERATORS:
        best: dict[int, tuple[int, int]] = {}
        for order, item in enumerate(adapter["rules"]):
            if item["operator"] != operator:
                continue
            indexes = [option["index"] for option in options if _matches(item["predicate"], context, option)]
            if indexes:
                matches.append({"rule_id": item["rule_id"], "operator": operator, "goal_stage": item["goal_stage"], "matched_indexes": indexes})
            for index in indexes:
                key = (item["priority"], order)
                if index not in best or key < best[index]:
                    best[index] = key
        if best:
            proposals.append({"operator": operator, "indexes": sorted(best, key=lambda index: (*best[index], index)), "reason_code": REASONS[operator]})
    payload = {
        "schema_version": 1,
        "profile_id": PROFILE_ID,
        "proposal_id": proposal_id,
        "adapter_id": adapter["adapter_id"],
        "source": {"context_hash": context["context_hash"], "window_id": context["source"]["window_id"], "adapter_hash": adapter["adapter_hash"]},
        "adapter_proposals": proposals,
        "matched_rules": matches,
        "authoritative": False,
    }
    return {**payload, "proposal_hash": domain_hash(PROPOSAL_PREFIX, payload)}


def vectors() -> dict[str, Any]:
    context = load(CONTEXT_VECTORS)["fixture"]["expected_context"]
    complete = adapter_document(
        "public.complete",
        [
            rule("goal.type2", "goal_proposal", "acquire", 0, empty_predicate(option_type_raw=2)),
            rule("goal.type1", "goal_proposal", "deploy", 1, empty_predicate(option_type_raw=1)),
            rule("macro.hand7", "macro_proposal", "fund", 0, empty_predicate(acting_hand_card_id=7)),
            rule("macro.type1", "macro_proposal", "ready", 1, empty_predicate(option_type_raw=1)),
            rule("tie.active100", "tiebreak_score", "execute", 0, empty_predicate(acting_active_card_id=100)),
            rule("tie.type2", "tiebreak_score", "maintain", 1, empty_predicate(option_type_raw=2)),
            rule("goal.unmapped999", "goal_proposal", "recover", 0, empty_predicate(option_card_id=999)),
        ],
    )
    no_match = adapter_document("public.no-match", [rule("none", "goal_proposal", "recover", 0, empty_predicate(option_card_id=999))])
    stable = adapter_document(
        "public.stable",
        [
            rule("all.second", "goal_proposal", "ready", 2, empty_predicate()),
            rule("type2.first", "goal_proposal", "execute", 0, empty_predicate(option_type_raw=2)),
            rule("type1.first", "goal_proposal", "maintain", 0, empty_predicate(option_type_raw=1)),
        ],
    )
    docs = []
    compiled = {}
    for case_id, document in (("complete", complete), ("no-match", no_match), ("stable", stable)):
        value = expected_adapter(document)
        docs.append({"id": case_id, "document": document, "expected_adapter": value})
        compiled[case_id] = value
    proposal_cases = []
    for case_id, adapter_case in (("complete-proposal", "complete"), ("empty-proposal", "no-match"), ("stable-proposal", "stable")):
        proposal_cases.append({"id": case_id, "adapter_case_id": adapter_case, "proposal_id": case_id, "expected_result": expected_result(case_id, context, compiled[adapter_case])})
    rejections = [
        {"id": "extra-document-key", "mutation": {"target": "document", "field": "private_state", "value": True}, "expected_error_code": "private_adapter_input"},
        {"id": "bad-adapter-id", "mutation": {"target": "document", "field": "adapter_id", "value": "PRIVATE.adapter"}, "expected_error_code": "private_adapter_input"},
        {"id": "unknown-operator", "mutation": {"target": "rule", "field": "operator", "value": "python_callable"}, "expected_error_code": "unsupported_adapter_operator"},
        {"id": "unknown-stage", "mutation": {"target": "rule", "field": "goal_stage", "value": "cheat"}, "expected_error_code": "unsupported_goal_stage"},
        {"id": "wrong-reason", "mutation": {"target": "rule", "field": "reason_code", "value": "public_macro_proposal"}, "expected_error_code": "invalid_adapter_document"},
        {"id": "priority-bool", "mutation": {"target": "rule", "field": "priority", "value": True}, "expected_error_code": "invalid_adapter_document"},
        {"id": "predicate-extra", "mutation": {"target": "rule", "field": "predicate", "value": {**empty_predicate(), "display_name": "secret"}}, "expected_error_code": "invalid_public_predicate"},
        {"id": "predicate-string", "mutation": {"target": "rule", "field": "predicate", "value": {**empty_predicate(), "option_type_raw": "1"}}, "expected_error_code": "invalid_public_predicate"},
        {"id": "predicate-private", "mutation": {"target": "rule", "field": "predicate", "value": {**empty_predicate(), "option_type_raw": "PRIVATE_HAND_SENTINEL"}}, "expected_error_code": "private_adapter_input"},
        {"id": "duplicate-rule", "mutation": {"target": "document", "field": "rules", "value": [complete["rules"][0], complete["rules"][0]]}, "expected_error_code": "invalid_adapter_document"},
    ]
    return {
        "schema_version": 1,
        "vector_set_id": PROFILE_ID,
        "profile_id": PROFILE_ID,
        "context_fixture": {"context_hash": context["context_hash"], "window_id": context["source"]["window_id"], "option_count": len(context["select_semantics"]["options"])},
        "adapter_documents": docs,
        "proposal_cases": proposal_cases,
        "adapter_rejections": rejections,
        "private_sentinels": ["PRIVATE", "PRIVATE_HAND_SENTINEL", "PRIVATE_SEARCH_SENTINEL", "PRIVATE_SESSION_SENTINEL"],
        "consumer_rule": "Serialized adapter and proposal values are public audit only. The restricted executor may consume proposal indexes only as same-tier ordering hints and must retain all Base authority.",
    }


def artifacts() -> dict[str, Any]:
    docs = {ARTIFACTS[0]: schema(), ARTIFACTS[1]: profile(), ARTIFACTS[2]: vectors()}
    bundle = {
        "schema_version": 1,
        "bundle_id": BUNDLE_ID,
        "parent_bundle_canonical_sha256": PARENT_BUNDLE,
        "source_lock_canonical_sha256": SOURCE_LOCK,
        "artifacts": [
            {"id": name.removesuffix(".json"), "path": f"contracts/ptcgdap/{name}", "canonical_sha256": digest(docs[name])}
            for name in ARTIFACTS
        ],
    }
    return {**docs, "public_deck_adapter_bundle.json": bundle}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated = artifacts()
    if args.check:
        bad = [name for name, value in generated.items() if not (CONTRACT_ROOT / name).is_file() or (CONTRACT_ROOT / name).read_bytes() != pretty(value)]
        if bad:
            print("artifact drift: " + ", ".join(bad), file=sys.stderr)
            return 1
        return 0
    for name, value in generated.items():
        (CONTRACT_ROOT / name).write_bytes(pretty(value))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
