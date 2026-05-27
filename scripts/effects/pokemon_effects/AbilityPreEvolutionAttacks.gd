class_name AbilityPreEvolutionAttacks
extends BaseEffect

const GRANT_KIND := "pre_evolution_attack"

var processor: EffectProcessor = null


func _init(effect_processor: EffectProcessor = null) -> void:
	processor = effect_processor


func get_granted_attacks_for_target(
	source: PokemonSlot,
	target: PokemonSlot,
	state: GameState
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if source == null or target == null or state == null:
		return entries
	var source_top := source.get_top_card()
	var target_top := target.get_top_card()
	if source_top == null or target_top == null:
		return entries
	if source_top.owner_index != target_top.owner_index:
		return entries
	if target.pokemon_stack.size() < 2:
		return entries
	var target_data := target.get_card_data()
	if target_data == null or not target_data.is_evolution_pokemon():
		return entries

	for stack_index: int in target.pokemon_stack.size() - 1:
		var card: CardInstance = target.pokemon_stack[stack_index]
		if card == null or card.card_data == null:
			continue
		for attack_index: int in card.card_data.attacks.size():
			var attack: Dictionary = (card.card_data.attacks[attack_index] as Dictionary).duplicate(true)
			attack["id"] = "pre_evolution:%s:%d" % [str(card.instance_id), attack_index]
			attack["source"] = "field_ability"
			attack["grant_kind"] = GRANT_KIND
			attack["source_effect_id"] = source_top.card_data.effect_id
			attack["source_card_instance_id"] = int(source_top.instance_id)
			attack["source_pokemon_name"] = source.get_pokemon_name()
			attack["original_effect_id"] = card.card_data.effect_id
			attack["original_card_instance_id"] = int(card.instance_id)
			attack["original_card_name"] = card.card_data.name
			attack["original_card_name_en"] = card.card_data.name_en
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
	var opponent_index := 1 - int(attacker.get_top_card().owner_index)
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var defender: PokemonSlot = state.players[opponent_index].active_pokemon
	processor.execute_attack_effect_by_id(
		original_effect_id,
		original_attack_index,
		attacker,
		defender,
		state,
		targets
	)


func get_description() -> String:
	return "Your evolved Pokemon can use the attacks from their previous Evolutions while this Pokemon is in play."
