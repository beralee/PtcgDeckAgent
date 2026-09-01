from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_author_strategy_package import (
    TEST_FIXTURE_KEY_ID,
    build_package_bytes,
    build_synthetic_fixture_payloads,
)


OUTPUT = ROOT / "tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
TEST_FIXTURE_PRIVATE_KEY = bytes(range(32))
DECK_ROWS = (
    (7, 28),
    (104, 4),
    (112, 4),
    (646, 4),
    (647, 4),
    (648, 4),
    (1080, 4),
    (1097, 4),
    (1259, 4),
)


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _json(value: object) -> bytes:
    return canonical_json_v1_bytes(value)


def _ordered_json(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def build_fixture_payloads() -> dict[str, bytes]:
    payloads = build_synthetic_fixture_payloads()
    deck_csv = ("card_id,count\n" + "".join(f"{card_id},{count}\n" for card_id, count in DECK_ROWS)).encode("ascii")
    deck_manifest = json.loads(payloads["deck/deck_manifest.json"])
    deck_manifest.update(
        {
            "deck_id": "test.fixture.mapped-shadow",
            "deck_csv_sha256": _sha(deck_csv),
            "cabt_exportable": False,
        }
    )
    manifest = json.loads(payloads["strategy_package.json"])
    manifest.update({"package_id": "test.fixture.mapped-shadow", "package_version": "1.0.0"})
    manifest["author"] = {"author_id": "test.fixture.author", "display_name": "Fixture Author"}
    manifest["strategy"] = {
        "display_name": "Mapped Shadow Tiebreak",
        "summary": "Exact-mapped development fixture for AS-WP4 shadow conformance; never player-ready.",
    }
    manifest["deck"]["display_name"] = "Exact Mapped Shadow Fixture"
    nodes = [
        ("n00", "legality_guard", "base", {"frontier": "current_window"}),
        ("n10", "mandatory_terminal_guard", "base", {"mandatory_precedence": True, "terminal_precedence": True}),
        ("n20", "hard_tier_filter", "base", {"same_tier_only": True}),
        ("n30", "tiebreak_score", "adapter", {"feature_ids": ["fixture.tiebreak"], "weight_scale": 1000000}),
        ("n40", "base_veto", "base", {"enabled": True}),
        ("n50", "deterministic_fallback", "base", {"strategy": "same_window_first_min"}),
        ("n60", "emit_decision", "base", {}),
    ]
    policy_ir = {
        "schema_version": 1,
        "profile_id": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
        "graph_id": "test.fixture.mapped-shadow",
        "entry_node_id": "n00",
        "required_capabilities": ["public_context", "current_window", "deterministic_fallback", "strategic_trace_v2"],
        "nodes": [
            {
                "node_id": node_id,
                "operator": operator,
                "owner": owner,
                "config": config,
                "next_node_ids": [] if index + 1 == len(nodes) else [nodes[index + 1][0]],
            }
            for index, (node_id, operator, owner, config) in enumerate(nodes)
        ],
    }
    adapter = {
        "schema_version": 1,
        "adapter_id": "test.fixture.mapped-shadow",
        "adapter_version": 1,
        "rules": [
            {
                "rule_id": "prefer-option-type-two",
                "operator": "tiebreak_score",
                "reason_code": "public_tiebreak_proposal",
                "goal_stage": "execute",
                "priority": 0,
                "predicate": {
                    "select_type_raw": 9,
                    "select_context_raw": 41,
                    "option_type_raw": 2,
                    "option_card_id": None,
                    "option_player_index": None,
                    "acting_hand_card_id": None,
                    "acting_active_card_id": None,
                },
            }
        ],
    }
    payloads["strategy_package.json"] = _json(manifest)
    payloads["deck/deck_manifest.json"] = _json(deck_manifest)
    payloads["deck/deck.csv"] = deck_csv
    payloads["policy/policy_ir.json"] = _json(policy_ir)
    # The already-sealed P4-WP4 adapter contract preserves the declared
    # predicate-field order. Keep this one payload in that exact order.
    payloads["policy/adapter.json"] = _ordered_json(adapter)
    payloads["README.md"] = b"# AS-WP4 exact-mapped shadow fixture\n\nDevelopment conformance only; execution trust is false.\n"
    payloads["LICENSE"] = b"Test fixture only. No production grant.\n"
    return payloads


def build_fixture_bytes() -> bytes:
    return build_package_bytes(build_fixture_payloads(), TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the deterministic AS-WP4 exact-mapped shadow package")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    value = build_fixture_bytes()
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_bytes() != value:
            raise SystemExit("AS-WP4 fixture drift")
        print(f"fixture verified sha256={_sha(value)}")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(value)
    print(f"fixture written sha256={_sha(value)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
