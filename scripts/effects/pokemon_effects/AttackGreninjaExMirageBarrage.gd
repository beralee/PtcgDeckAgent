class_name AttackGreninjaExMirageBarrage
extends BaseEffect

var attack_index_to_match: int = -1
var damage_amount: int = 120
var discard_count: int = 2
const ATTACK_EFFECT_TARGET_RESULTS_FLAG := "_attack_effect_target_results"


func _init(match_attack_index: int = -1, damage: int = 120, energy_to_discard: int = 2) -> void:
	attack_index_to_match = match_attack_index
	damage_amount = damage
	discard_count = energy_to_discard


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	if attacker != null:
		energy_items = attacker.attached_energy.duplicate()
		for energy: CardInstance in energy_items:
			energy_labels.append(energy.card_data.name)

	var target_items: Array = state.players[1 - card.owner_index].get_all_pokemon()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())

	return [{
		"id": "greninja_ex_discard_energy",
		"title": "选择2个附着的能量放入弃牌区",
		"items": energy_items,
		"labels": energy_labels,
		"min_select": mini(discard_count, energy_items.size()),
		"max_select": mini(discard_count, energy_items.size()),
		"allow_cancel": false,
	}, {
		"id": "greninja_ex_targets",
		"title": "选择对手最多2只宝可梦",
		"items": target_items,
		"labels": target_labels,
		"min_select": mini(2, target_items.size()),
		"max_select": mini(2, target_items.size()),
		"allow_cancel": false,
	}]


func validate_attack_interaction(
	attacker: PokemonSlot,
	attack_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return interaction_validation_error("Mirage Barrage attacker or attack index is invalid")
	var top := attacker.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return interaction_validation_error("Mirage Barrage attacker owner is invalid")
	var context := get_interaction_context(targets)
	var energy_items: Array = attacker.attached_energy.duplicate()
	var energy_result := validate_context_selection(
		context,
		"greninja_ex_discard_energy",
		energy_items,
		discard_count,
		discard_count
	)
	if not bool(energy_result.get("valid", false)):
		return energy_result
	var target_items: Array = state.players[1 - top.owner_index].get_all_pokemon()
	var expected_targets := mini(2, target_items.size())
	return validate_context_selection(
		context,
		"greninja_ex_targets",
		target_items,
		expected_targets,
		expected_targets
	)


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	if attacker == null or not applies_to_attack_index(_attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	if not bool(validate_attack_interaction(attacker, _attack_index, [ctx], state).get("valid", false)):
		return

	var selected_energy_ids: Dictionary = {}
	for entry: Variant in ctx.get("greninja_ex_discard_energy", []):
		if entry is CardInstance:
			selected_energy_ids[(entry as CardInstance).instance_id] = true

	var selected_targets: Dictionary = {}
	for entry: Variant in ctx.get("greninja_ex_targets", []):
		if not (entry is PokemonSlot):
			continue
		var target := entry as PokemonSlot
		if target in opponent.get_all_pokemon():
			selected_targets[target.get_instance_id()] = target

	var discarded: Array[CardInstance] = []
	var kept_energy: Array[CardInstance] = []
	for energy: CardInstance in attacker.attached_energy:
		if discarded.size() < discard_count and selected_energy_ids.has(energy.instance_id):
			discarded.append(energy)
		else:
			kept_energy.append(energy)
	attacker.attached_energy = kept_energy
	for energy: CardInstance in discarded:
		energy.face_up = true
		player.discard_pile.append(energy)
		_record_attack_effect_discarded_attached_energy(attacker, energy, state)

	var target_results: Array = []
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	for target: PokemonSlot in selected_targets.values():
		var prevention_source := ""
		if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
			prevention_source = "bench_damage_immunity"
		elif AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			prevention_source = "attack_damage_and_effects_prevention"
		var final_damage := 0 if prevention_source != "" else _calculate_attack_target_damage(attacker, target, damage_amount, state)
		if final_damage > 0:
			target.damage_counters += final_damage
			if processor != null and processor.has_method("record_effect_damage"):
				processor.call("record_effect_damage", top.owner_index, target, final_damage, state, "Mirage Barrage")
		target_results.append({
			"target_name": target.get_pokemon_name(),
			"target_slot_id": int(target.get_instance_id()),
			"target_zone": "bench" if target in opponent.bench else "active",
			"base_damage": damage_amount,
			"final_damage": final_damage,
			"prevention_source": prevention_source,
		})
	state.shared_turn_flags[ATTACK_EFFECT_TARGET_RESULTS_FLAG] = target_results


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return int(attack.get("_override_attack_index", -1))


func get_description() -> String:
	return "Discard 2 Energy from this Pokemon and deal damage to 2 opponent Pokemon."
