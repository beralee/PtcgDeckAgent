class_name AttackKnockOutOpponentWithExactDamageCounters
extends BaseEffect

const AbilityIgnoreEffectsScript := preload("res://scripts/effects/pokemon_effects/AbilityIgnoreEffects.gd")
const AbilityBenchImmuneScript := preload("res://scripts/effects/pokemon_effects/AbilityBenchImmune.gd")
const AttackProtectionScript := preload("res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd")
const STEP_ID := "opponent_exact_damage_counter_ko_target"

var required_counter_count: int = 6
var attack_index_to_match: int = -1


func _init(counter_count: int = 6, match_attack_index: int = -1) -> void:
	required_counter_count = maxi(0, counter_count)
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var targets := _legal_targets(state.players[1 - card.owner_index])
	if targets.is_empty():
		return []
	var labels: Array[String] = []
	for slot: PokemonSlot in targets:
		labels.append("%s（%d个伤害指示物）" % [slot.get_pokemon_name(), required_counter_count])
	return [{
		"id": STEP_ID,
		"title": "选择对手的1只放置有%d个伤害指示物的宝可梦，将其昏厥" % required_counter_count,
		"items": targets,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"force_confirm": true,
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
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var legal_targets := _legal_targets(opponent)
	if legal_targets.is_empty():
		return
	var target: PokemonSlot = null
	var raw: Variant = get_attack_interaction_context().get(STEP_ID, [])
	if raw is Array and not (raw as Array).is_empty() and (raw as Array)[0] is PokemonSlot:
		var selected := (raw as Array)[0] as PokemonSlot
		if selected in legal_targets:
			target = selected
	if target == null and defender in legal_targets:
		target = defender
	if target == null:
		target = legal_targets[0]
	if _effect_is_prevented(attacker, target, opponent, state):
		return
	var maximum_hp := target.get_max_hp()
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("get_effective_max_hp"):
		maximum_hp = int(processor.call("get_effective_max_hp", target, state))
	target.damage_counters = maxi(target.damage_counters, maximum_hp)


func _legal_targets(opponent: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	if opponent == null:
		return result
	var required_damage := required_counter_count * 10
	for slot: PokemonSlot in opponent.get_all_pokemon():
		if slot != null and slot.damage_counters == required_damage:
			result.append(slot)
	return result


func _effect_is_prevented(
	attacker: PokemonSlot,
	target: PokemonSlot,
	opponent: PlayerState,
	state: GameState
) -> bool:
	if target == null or AbilityIgnoreEffectsScript.has_ignore_effects(target):
		return true
	if AttackProtectionScript.prevents_attack_effects(target, state):
		return true
	if target in opponent.bench and AbilityBenchImmuneScript.prevents_opponent_attack_effect(target, attacker, state):
		return true
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		return bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state))
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
	return "Knock Out 1 of your opponent's Pokemon that has exactly %d damage counters on it." % required_counter_count
