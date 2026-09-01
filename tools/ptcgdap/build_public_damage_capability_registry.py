from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CARD_ROOT = ROOT / "data" / "bundled_user" / "cards"
OUTPUT = ROOT / "contracts" / "ptcgdap" / "public_damage_capability_registry_v1.json"

CAPABILITY_SPECS: dict[str, dict[str, Any]] = {
    "863479acd128e1e5e2643a3a1e77ce26": {
        "capability_ids": ["attack.fixed_split.v1"],
        "handler_paths": [
            "scripts/engine/CSV10C101To200Registry.gd",
            "scripts/effects/pokemon_effects/AbilityMarniesGrimmsnarlPunkUp.gd",
        ],
        "attack_overrides": {"0": {"active_damage": 180, "bench_damage": 30}},
    },
    "f27a2982c03f5b49a68ec0a77a2d6e48": {
        "capability_ids": ["between_turn.ability_counter.v1"],
        "handler_paths": ["scripts/effects/pokemon_effects/AbilityFroslassFreezingShroud.gd"],
        "parameters": {
            "damage_per_check": 10,
            "requires_target_ability": True,
            "exclude_same_capability": True,
        },
    },
    "66fee12502043db7d92b97b0d62b0f59": {
        "capability_ids": ["ability.move_damage_counters.v1"],
        "handler_paths": ["scripts/effects/pokemon_effects/AbilityMoveDamageCountersToOpponent.gd"],
        "parameters": {"maximum_damage": 30, "required_energy_type": "D"},
    },
    "e242d711feffd98f3fbb5c511d00d667": {
        "capability_ids": ["tool.conditional_active_damage_bonus.v1"],
        "handler_paths": [
            "scripts/engine/EffectRegistry.gd",
            "scripts/effects/tool_effects/EffectToolConditionalDamage.gd",
        ],
        "parameters": {"bonus_damage": 30, "condition": "self_prizes_remaining_gt_opponent"},
    },
    "e228e825c541ce80e2507c557cb506c3": {
        "capability_ids": ["attack.mass_devolution.v1"],
        "handler_paths": [
            "scripts/engine/EffectRegistry.gd",
            "scripts/effects/trainer_effects/EffectTMDevolution.gd",
        ],
        "parameters": {"scope": "all_opponent_evolved", "removed_cards_per_target": 1},
    },
    "930f07ef177d44b0e1084343b66b13af": {
        "capability_ids": ["attack.bench_heal.v1"],
        "handler_paths": [
            "scripts/effects/pokemon_effects/AttackHealOwnBenchPokemon.gd",
        ],
        "parameters": {"bench_heal_amount": 100},
        "attack_overrides": {"1": {"bench_heal_amount": 100}},
    },
}

FIXED_DAMAGE = re.compile(r"^[0-9]+$")


def _canonical(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def _sha_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest().upper()


def _sha_path(path: Path) -> str:
    return _sha_bytes(path.read_bytes())


def _card_uid(card: dict[str, Any]) -> str:
    return f"{card.get('set_code', '')}_{card.get('card_index', '')}"


def _fixed_damage(value: Any) -> int | None:
    text = str(value or "").strip()
    return int(text) if FIXED_DAMAGE.fullmatch(text) else None


def build_registry() -> dict[str, Any]:
    cards: dict[str, dict[str, Any]] = {}
    source_files: list[dict[str, Any]] = []
    for path in sorted(CARD_ROOT.glob("*.json"), key=lambda item: item.name.casefold()):
        try:
            card = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            continue
        if type(card) is not dict:
            continue
        uid = _card_uid(card)
        if not re.fullmatch(r"[A-Za-z0-9.]+_[A-Za-z0-9._]+", uid) or uid in cards:
            continue
        effect_id = str(card.get("effect_id", ""))
        special = CAPABILITY_SPECS.get(effect_id, {})
        attacks: list[dict[str, Any]] = []
        for index, attack_value in enumerate(card.get("attacks", [])):
            if type(attack_value) is not dict:
                continue
            fixed = _fixed_damage(attack_value.get("damage"))
            row: dict[str, Any] = {
                "attack_index": index,
                "active_damage": fixed,
                "bench_damage": 0,
                "cost": str(attack_value.get("cost", "")),
            }
            override = special.get("attack_overrides", {}).get(str(index), {})
            row.update(override)
            attacks.append(row)
        cards[uid] = {
            "effect_id": effect_id,
            "card_type": str(card.get("card_type", "")),
            "stage": str(card.get("stage", "")),
            "max_hp": int(card.get("hp", 0)) if type(card.get("hp")) is int else 0,
            "energy_type": str(card.get("energy_type", "")),
            "has_ability": bool(card.get("abilities", [])),
            "weakness_energy": str(card.get("weakness_energy", "")),
            "weakness_multiplier": 2 if "2" in str(card.get("weakness_value", "")) else 1,
            "resistance_energy": str(card.get("resistance_energy", "")),
            "resistance_reduction": 30 if "30" in str(card.get("resistance_value", "")) else 0,
            "capability_ids": sorted(special.get("capability_ids", [])),
            "attacks": attacks,
        }
        source_files.append({
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": _sha_path(path),
        })

    effects: list[dict[str, Any]] = []
    for effect_id, spec in sorted(CAPABILITY_SPECS.items()):
        handlers: list[dict[str, str]] = []
        for relative in spec["handler_paths"]:
            path = ROOT / relative
            if not path.is_file():
                raise FileNotFoundError(relative)
            handlers.append({"path": relative, "sha256": _sha_path(path)})
        effects.append({
            "effect_id": effect_id,
            "capability_ids": sorted(spec["capability_ids"]),
            "parameters": spec.get("parameters", {}),
            "handlers": handlers,
        })

    payload: dict[str, Any] = {
        "schema_version": 1,
        "profile_id": "ptcgdap-public-damage-capability-registry-v1",
        "card_identity_domain": "godot_local_card_uid_v1",
        "generation": {
            "builder": "tools/ptcgdap/build_public_damage_capability_registry.py",
            "catalog_root": "data/bundled_user/cards",
            "card_count": len(cards),
            "source_root_sha256": _sha_bytes(_canonical(source_files)),
        },
        "capabilities": sorted(
            {capability for spec in CAPABILITY_SPECS.values() for capability in spec["capability_ids"]}
        ),
        "effect_specs": effects,
        "cards": cards,
    }
    payload["registry_sha256"] = _sha_bytes(_canonical(payload))
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    registry = build_registry()
    encoded = json.dumps(registry, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text(encoding="utf-8") != encoded:
            print("public_damage_capability_registry_out_of_date")
            return 1
        print(registry["registry_sha256"])
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(encoded, encoding="utf-8", newline="\n")
    print(registry["registry_sha256"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
