from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from scripts.ai.ptcgdap.source_lock import canonical_json_v1_bytes
from tools.ptcgdap.build_as_wp4_author_strategy_fixture import build_fixture_payloads
from tools.ptcgdap.build_author_strategy_package import TEST_FIXTURE_KEY_ID, build_package_bytes
from tools.ptcgdap.build_author_strategy_windows_local_deck_contract import (
    build_marnie_deck_csv,
    build_marnie_deck_manifest,
)


OUTPUT = ROOT / "data/ptcgdap/author_strategy_packages/ptcgdap-author-strategy-release-candidate.ptcgai"
TEST_FIXTURE_PRIVATE_KEY = bytes(range(32))


def _sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def build_candidate_payloads() -> dict[str, bytes]:
    payloads = build_fixture_payloads()
    deck_manifest = build_marnie_deck_manifest(ROOT)
    deck_csv = build_marnie_deck_csv(deck_manifest)
    deck_manifest_bytes = canonical_json_v1_bytes(deck_manifest)
    manifest = json.loads(payloads["strategy_package.json"])
    manifest["package_id"] = "ptcgdap.marnie.windows-local"
    manifest["package_version"] = "0.1.0"
    manifest["author"] = {"author_id": "ptcgdap.builtin", "display_name": "PtcgDAP"}
    manifest["strategy"] = {
        "display_name": "Marnie 18.0 长毛巨魔 Windows 本地策略",
        "summary": "Exact local-UID 800018501 deck candidate for Windows package and match-gate validation; test signed and never player-ready.",
    }
    manifest["deck"]["display_name"] = "18.0 玛俐的长毛巨魔"
    manifest["policy"]["weights_path"] = "policy/weights.bin"
    nodes = [
        ("n00", "legality_guard", "base", {"frontier": "current_window"}),
        ("n10", "mandatory_terminal_guard", "base", {"mandatory_precedence": True, "terminal_precedence": True}),
        ("n20", "macro_proposal", "adapter", {"macro_ids": [
            "marnie.poffin.play",
            "marnie.spikemuth.play",
            "marnie.morgrem.evolve",
            "marnie.grimmsnarl.evolve",
            "marnie.punk-up.energy",
            "marnie.shadow-bullet.attack",
            "marnie.night-stretcher.play",
        ]}),
        ("n30", "hard_tier_filter", "base", {"same_tier_only": True}),
        ("n40", "base_veto", "base", {"enabled": True}),
        ("n50", "deterministic_fallback", "base", {"strategy": "same_window_first_min"}),
        ("n60", "emit_decision", "base", {}),
    ]
    policy_ir = {
        "schema_version": 1,
        "profile_id": "ptcgdap-restricted-base-graph-ir-p4-wp2-v1",
        "graph_id": "ptcgdap.marnie.windows-local",
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

    def predicate(**updates: object) -> dict[str, object]:
        value: dict[str, object] = {
            "select_type_raw": None,
            "select_context_raw": None,
            "option_type_raw": None,
            "option_card_id": None,
            "option_player_index": None,
            "acting_hand_card_id": None,
            "acting_active_card_id": None,
        }
        value.update(updates)
        return value

    def macro(rule_id: str, stage: str, rule_predicate: dict[str, object], priority: int = 0) -> dict[str, object]:
        return {
            "rule_id": rule_id,
            "operator": "macro_proposal",
            "reason_code": "public_macro_proposal",
            "goal_stage": stage,
            "priority": priority,
            "predicate": rule_predicate,
        }

    adapter = {
        "schema_version": 1,
        "adapter_id": "ptcgdap.marnie.windows-local",
        "adapter_version": 1,
        "rules": [
            macro("marnie.poffin.play", "acquire", predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, acting_hand_card_id="CSV7C_177")),
            macro("marnie.spikemuth.play", "acquire", predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, acting_hand_card_id="CSV10C_216")),
            macro("marnie.morgrem.evolve", "deploy", predicate(option_type_raw=3, option_card_id="CSV10C_146", acting_hand_card_id="CSV10C_147")),
            macro("marnie.grimmsnarl.evolve", "deploy", predicate(option_type_raw=3, option_card_id="CSV10C_147", acting_hand_card_id="CSV10C_148")),
            macro("marnie.punk-up.energy", "fund", predicate(select_type_raw=1, select_context_raw=22, option_type_raw=3, option_card_id="CSVE1C_DAR", acting_active_card_id="CSV10C_148")),
            macro("marnie.shadow-bullet.attack", "execute", predicate(select_type_raw=0, select_context_raw=0, option_type_raw=13, acting_active_card_id="CSV10C_148")),
            macro("marnie.night-stretcher.play", "recover", predicate(select_type_raw=0, select_context_raw=0, option_type_raw=7, acting_hand_card_id="CSV8C_183")),
        ],
    }
    config = {
        "document_type": "author_policy_config_v1",
        "schema_version": 1,
        "config_profile_id": "ptcgdap-author-policy-config-v1",
        "values": {
            "card_id_domain": "godot_local_card_uid_v1",
            "deck_manifest_sha256": _sha(deck_manifest_bytes),
            "source_deck_id": 800018501,
            "cabt_exportable": False,
            "platform_scope": "windows",
        },
    }
    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["deck/deck_manifest.json"] = deck_manifest_bytes
    payloads["deck/deck.csv"] = deck_csv
    payloads["policy/policy_ir.json"] = canonical_json_v1_bytes(policy_ir)
    payloads["policy/adapter.json"] = canonical_json_v1_bytes(adapter)
    payloads["policy/config.json"] = canonical_json_v1_bytes(config)
    payloads["policy/weights.bin"] = b"PTCGDAP-WEIGHTS-V1\0" + b"".join(
        struct.pack("<f", value) for value in (0.0, 0.25, -0.25, 0.5, -0.5, 1.0, -1.0, 0.125)
    )
    payloads["README.md"] = (
        b"# Marnie 18.0 Windows local-deck candidate\n\n"
        b"Deterministic built-in export fixture using exact Godot local card UIDs. "
        b"It is Windows-only, cabt_exportable=false, test_fixture_only, "
        b"execution_trusted=false, and grants no player or match authority.\n"
    )
    return payloads


def build_product_candidate_payloads() -> dict[str, bytes]:
    """Return the exact built-in candidate with truthful release-stage copy.

    Deck, policy, weights, and every executable input stay byte-identical to
    the exported test fixture. Only the human-facing manifest summary and
    README stop claiming a test-fixture signature. Signature authority still
    comes exclusively from ``signature.json`` and the fixed release gates.
    """

    payloads = dict(build_candidate_payloads())
    manifest = json.loads(payloads["strategy_package.json"])
    manifest["strategy"]["summary"] = (
        "Exact local-UID 800018501 Windows product-signed release candidate. "
        "Player start remains disabled until exact W0-W7 conformance, device "
        "canary, rollback, package release, and A5 approvals are all active."
    )
    payloads["strategy_package.json"] = canonical_json_v1_bytes(manifest)
    payloads["README.md"] = (
        b"# Marnie 18.0 Windows product-signed release candidate\n\n"
        b"The deck and policy payloads are byte-identical to the validated "
        b"built-in candidate. Product signing establishes package identity "
        b"only; player start remains denied until every fixed product approval "
        b"gate accepts this exact archive.\n"
    )
    return payloads


def build_candidate_bytes() -> bytes:
    payloads = build_candidate_payloads()
    return build_package_bytes(payloads, TEST_FIXTURE_PRIVATE_KEY, key_id=TEST_FIXTURE_KEY_ID)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write == args.check:
        raise SystemExit("choose exactly one of --write or --check")
    value = build_candidate_bytes()
    if args.write:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_bytes(value)
    elif not OUTPUT.is_file() or OUTPUT.read_bytes() != value:
        raise SystemExit("AS-WP6 built-in candidate drift")
    print(f"archive_bytes={len(value)}")
    print(f"archive_sha256={_sha(value)}")
    print("execution_trusted=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
