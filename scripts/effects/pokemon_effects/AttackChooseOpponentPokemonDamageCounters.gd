class_name AttackChooseOpponentPokemonDamageCounters
extends BaseEffect

const STEP_ID := "opponent_pokemon_damage_counter_target"
const AbilityIgnoreEffectsScript := preload("res://scripts/effects/pokemon_effects/AbilityIgnoreEffects.gd")

var counter_count: int = 1
var attack_index_to_match: int = -1


func _init(count: int = 1, match_attack_index: int = -1) -> void:
	counter_count = maxi(0, count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = opponent.get_all_pokemon()
	if items.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": STEP_ID,
		"title": "选择对手的1只宝可梦，放置%d个伤害指示物" % counter_count,
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
	}]


func validate_attack_interaction(
	attacker: PokemonSlot,
	attack_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return interaction_validation_error("damage-counter target attacker or attack index is invalid")
	var top := attacker.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return interaction_validation_error("damage-counter target attacker owner is invalid")
	var legal_targets: Array = state.players[1 - top.owner_index].get_all_pokemon()
	return validate_context_selection(
		get_interaction_context(targets),
		STEP_ID,
		legal_targets,
		1,
		1,
	)


func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var legal_targets: Array = opponent.get_all_pokemon()
	if legal_targets.is_empty():
		return
	var context := get_attack_interaction_context()
	var selected: Array = context.get(STEP_ID, []) if context.get(STEP_ID, []) is Array else []
	var target: PokemonSlot = null
	if not selected.is_empty() and selected[0] is PokemonSlot and selected[0] in legal_targets:
		target = selected[0] as PokemonSlot
	elif defender != null and defender in legal_targets:
		target = defender
	else:
		target = legal_targets[0] as PokemonSlot
	if _effect_is_prevented(attacker, target, opponent, state):
		return
	target.damage_counters += counter_count * 10
	_mark_attack_damage_counter_placement(target, state)


func _effect_is_prevented(attacker: PokemonSlot, target: PokemonSlot, opponent: PlayerState, state: GameState) -> bool:
	if target == null or AbilityIgnoreEffectsScript.has_ignore_effects(target):
		return true
	if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
		return true
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state)):
			return true
	if processor != null and processor.has_method("has_mist_energy_protection"):
		if bool(processor.call("has_mist_energy_protection", target, state)):
			return true
	return false


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for index: int in card.card_data.attacks.size():
		if card.card_data.attacks[index] == attack:
			return index
	return -1


func get_description() -> String:
	return "Put %d damage counters on 1 of your opponent's Pokemon." % counter_count
