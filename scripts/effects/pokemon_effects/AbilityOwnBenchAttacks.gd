## Lets this Pokemon use the printed attacks of its owner's Benched Pokemon.
class_name AbilityOwnBenchAttacks
extends BaseEffect

const GRANT_KIND := "own_bench_attack"

var processor: EffectProcessor = null


func _init(effect_processor: EffectProcessor = null) -> void:
	processor = effect_processor


func get_granted_attacks_for_target(
	source: PokemonSlot,
	target: PokemonSlot,
	state: GameState
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if source == null or target == null or state == null or source != target:
		return entries
	var source_top := source.get_top_card()
	if source_top == null:
		return entries
	var owner_index := int(source_top.owner_index)
	if owner_index < 0 or owner_index >= state.players.size():
		return entries

	for bench_slot: PokemonSlot in state.players[owner_index].bench:
		if bench_slot == null or bench_slot == source:
			continue
		var bench_card := bench_slot.get_top_card()
		var bench_data := bench_slot.get_card_data()
		if bench_card == null or bench_data == null or not bench_data.is_pokemon():
			continue
		if processor != null:
			processor.register_pokemon_card(bench_data)
		for attack_index: int in bench_data.attacks.size():
			var attack_variant: Variant = bench_data.attacks[attack_index]
			if not (attack_variant is Dictionary):
				continue
			var attack := (attack_variant as Dictionary).duplicate(true)
			if bool(attack.get("is_vstar_power", false)) and _vstar_power_used(owner_index, state):
				continue
			attack["id"] = "own_bench:%s:%d" % [str(bench_card.instance_id), attack_index]
			attack["source"] = "field_ability"
			attack["grant_kind"] = GRANT_KIND
			attack["source_effect_id"] = source_top.card_data.effect_id
			attack["source_card_instance_id"] = int(source_top.instance_id)
			attack["source_pokemon_name"] = source.get_pokemon_name()
			attack["original_effect_id"] = bench_data.effect_id
			attack["original_card_instance_id"] = int(bench_card.instance_id)
			attack["original_card_name"] = bench_data.name
			attack["original_card_name_en"] = bench_data.name_en
			attack["original_attack_index"] = attack_index
			entries.append(attack)
	return entries


func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if processor == null or pokemon == null or pokemon.get_top_card() == null:
		return []
	var original_effect_id := str(granted_attack.get("original_effect_id", ""))
	var original_attack_index := int(granted_attack.get("original_attack_index", -1))
	if original_effect_id == "" or original_attack_index < 0:
		return []
	return processor.get_attack_interaction_steps_by_id(
		original_effect_id,
		original_attack_index,
		pokemon.get_top_card(),
		granted_attack,
		state
	)


func get_followup_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if processor == null or pokemon == null or pokemon.get_top_card() == null:
		return []
	var original_effect_id := str(granted_attack.get("original_effect_id", ""))
	var original_attack_index := int(granted_attack.get("original_attack_index", -1))
	if original_effect_id == "" or original_attack_index < 0:
		return []
	return processor.get_attack_followup_interaction_steps_by_id(
		original_effect_id,
		original_attack_index,
		pokemon.get_top_card(),
		granted_attack,
		state,
		resolved_context
	)


func execute_granted_attack(
	attacker: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState,
	targets: Array = []
) -> void:
	if processor == null or attacker == null or attacker.get_top_card() == null or state == null:
		return
	var original_effect_id := str(granted_attack.get("original_effect_id", ""))
	var original_attack_index := int(granted_attack.get("original_attack_index", -1))
	if original_effect_id == "" or original_attack_index < 0:
		return
	var owner_index := int(attacker.get_top_card().owner_index)
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var defender: PokemonSlot = state.players[opponent_index].active_pokemon
	processor.execute_attack_effect_by_id(
		original_effect_id,
		original_attack_index,
		attacker,
		defender,
		state,
		targets,
		null,
		{"mode": "granted", "name": str(granted_attack.get("name", ""))}
	)
	if bool(granted_attack.get("is_vstar_power", false)) and owner_index < state.vstar_power_used.size():
		state.vstar_power_used[owner_index] = true


func _vstar_power_used(owner_index: int, state: GameState) -> bool:
	return owner_index >= 0 and owner_index < state.vstar_power_used.size() and state.vstar_power_used[owner_index]


func get_description() -> String:
	return "This Pokémon can use the attacks of any of your Benched Pokémon. You still need the necessary Energy to use each attack."
