class_name AttackCrobatCriticalBite
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const STEP_ID := "cs5ac_068_critical_bite_target"
const EXTRA_PRIZE_SOURCE := "cs5ac_068_critical_bite"

var damage_amount: int = 30
var extra_prizes: int = 2
var attack_index_to_match: int = 1


func _init(amount: int = 30, extra: int = 2, match_attack_index: int = 1) -> void:
	damage_amount = amount
	extra_prizes = extra
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var opponent_index := 1 - card.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return []
	var opponent := state.players[opponent_index]
	var items: Array = opponent.get_all_pokemon()
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		var zone := "Active" if slot == opponent.active_pokemon else "Bench"
		labels.append("%s: %s" % [zone, slot.get_pokemon_name()])
	return [{
		"id": STEP_ID,
		"title": "Choose 1 opponent Pokemon",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var opponent_index := 1 - top.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var opponent := state.players[opponent_index]
	var target := _resolve_target(opponent, defender)
	if target == null or _damage_is_prevented(attacker, target, opponent, state):
		return
	var damage := _calculate_attack_target_damage(attacker, target, damage_amount, state)
	if damage <= 0:
		return
	var previous_damage := target.damage_counters
	var was_knocked_out := _is_effectively_knocked_out(target, state)
	DamageCalculator.new().apply_damage_to_slot(target, damage)
	_record_damage(attacker, target, damage, state)
	if was_knocked_out or not _is_effectively_knocked_out(target, state):
		return
	if _try_prevent_attack_damage_knockout(target, attacker, state, previous_damage):
		return
	_add_extra_prize_once(target)


func _resolve_target(opponent: PlayerState, fallback: PokemonSlot) -> PokemonSlot:
	var selected_raw: Array = get_attack_interaction_context().get(STEP_ID, [])
	for entry: Variant in selected_raw:
		if entry is PokemonSlot and entry in opponent.get_all_pokemon():
			return entry
	if fallback != null and fallback in opponent.get_all_pokemon():
		return fallback
	var all_targets := opponent.get_all_pokemon()
	return all_targets[0] if not all_targets.is_empty() else null


func _damage_is_prevented(
	attacker: PokemonSlot,
	target: PokemonSlot,
	opponent: PlayerState,
	state: GameState
) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if target == opponent.active_pokemon:
		if processor != null and processor.has_method("is_damage_prevented_by_defender_ability"):
			if bool(processor.call("is_damage_prevented_by_defender_ability", attacker, target, state)):
				return true
		return AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state)
	if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return true
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return true
	return AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state)


func _is_effectively_knocked_out(target: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_effectively_knocked_out"):
		return bool(processor.call("is_effectively_knocked_out", target, state))
	return target.is_knocked_out()


func _try_prevent_attack_damage_knockout(
	target: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	previous_damage: int
) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor == null or not processor.has_method("apply_attack_damage_survival_tool"):
		return false
	return bool(processor.call("apply_attack_damage_survival_tool", target, attacker, state, previous_damage))


func _add_extra_prize_once(target: PokemonSlot) -> void:
	if target == null or extra_prizes <= 0:
		return
	for effect: Dictionary in target.effects:
		if effect.get("type", "") == "extra_prize" and effect.get("source", "") == EXTRA_PRIZE_SOURCE:
			return
	target.effects.append({
		"type": "extra_prize",
		"count": extra_prizes,
		"source": EXTRA_PRIZE_SOURCE,
	})


func _record_damage(attacker: PokemonSlot, target: PokemonSlot, damage: int, state: GameState) -> void:
	var top := attacker.get_top_card() if attacker != null else null
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if top != null and processor != null and processor.has_method("record_effect_damage"):
		processor.call("record_effect_damage", top.owner_index, target, damage, state, "attack")


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Deal %d damage to 1 opponent Pokemon. If that Pokemon is Knocked Out by this attack's damage, take %d extra Prize cards." % [damage_amount, extra_prizes]
