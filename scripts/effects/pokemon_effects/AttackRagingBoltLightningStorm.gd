class_name AttackRagingBoltLightningStorm
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")

const STEP_ID := "raging_bolt_lightning_storm_target"

var damage_per_energy: int = 30
var attack_index_to_match: int = -1


func _init(per_energy: int = 30, match_attack_index: int = 0) -> void:
	damage_per_energy = max(0, per_energy)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


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
	var items := state.players[opponent_index].get_all_pokemon()
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append(_slot_label(state.players[opponent_index], slot))
	return [{
		"id": STEP_ID,
		"title": "Choose 1 of your opponent's Pokemon",
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
	if target == null:
		return
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return
	if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage_or_effect(target, attacker, state):
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
		return
	var damage := target.attached_energy.size() * damage_per_energy
	if damage <= 0:
		return
	var final_damage := _calculate_attack_target_damage(attacker, target, damage, state)
	target.damage_counters += final_damage
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("record_effect_damage"):
		processor.call("record_effect_damage", top.owner_index, target, final_damage, state, "raging_bolt_lightning_storm")


func _resolve_target(opponent: PlayerState, fallback: PokemonSlot) -> PokemonSlot:
	var all_targets := opponent.get_all_pokemon()
	var selected_raw: Array = get_attack_interaction_context().get(STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected := selected_raw[0] as PokemonSlot
		if selected in all_targets:
			return selected
	if fallback != null and fallback in all_targets:
		return fallback
	return all_targets[0] if not all_targets.is_empty() else null


func _slot_label(player: PlayerState, slot: PokemonSlot) -> String:
	if slot == null:
		return ""
	var position := "Active" if player.active_pokemon == slot else "Bench %d" % (player.bench.find(slot) + 1)
	return "%s (%s, %d Energy)" % [slot.get_pokemon_name(), position, slot.attached_energy.size()]


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
	return "Deal damage to 1 opponent Pokemon equal to its attached Energy count."
