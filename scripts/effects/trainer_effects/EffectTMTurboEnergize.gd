class_name EffectTMTurboEnergize
extends BaseEffect

const GRANTED_ATTACK_ID := "tm_turbo_energize"
const STEP_ID := "tm_turbo_energize"
const MAX_ATTACH := 2


func get_granted_attacks(_pokemon: PokemonSlot, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": GRANTED_ATTACK_ID,
		"name": "Turbo Energize",
		"cost": "C",
		"damage": "",
		"text": "Search your deck for up to 2 Basic Energy cards and attach them to your Benched Pokemon in any way. Then shuffle your deck.",
	}]


func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	_attack_data: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return []
	var player: PlayerState = state.players[top.owner_index]
	if player.bench.is_empty():
		return []

	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for deck_card: CardInstance in player.deck:
		if deck_card.card_data != null and deck_card.card_data.card_type == "Basic Energy":
			energy_items.append(deck_card)
			energy_labels.append(deck_card.card_data.name)
	if energy_items.is_empty():
		return []

	var target_items: Array = player.bench.duplicate()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append(slot.get_pokemon_name())

	return [build_card_assignment_step(
		STEP_ID,
		"Choose up to 2 Basic Energy cards from your deck and assign them to your Benched Pokemon",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		0,
		mini(MAX_ATTACH, energy_items.size()),
		true
	)]


func execute_granted_attack(
	attacker: PokemonSlot,
	attack_data: Dictionary,
	state: GameState,
	targets: Array = []
) -> void:
	if str(attack_data.get("id", "")) != GRANTED_ATTACK_ID:
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var assignments_raw: Array = ctx.get(STEP_ID, [])
	var used_sources: Array[CardInstance] = []
	var attached_count: int = 0

	for entry: Variant in assignments_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var energy_card: CardInstance = source as CardInstance
		var target_slot: PokemonSlot = target as PokemonSlot
		if energy_card in used_sources:
			continue
		if energy_card not in player.deck or target_slot not in player.bench:
			continue
		if energy_card.card_data == null or energy_card.card_data.card_type != "Basic Energy":
			continue
		used_sources.append(energy_card)
		player.deck.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)
		attached_count += 1
		if attached_count >= MAX_ATTACH:
			break

	player.shuffle_deck()


func discard_at_end_of_turn(_slot: PokemonSlot, _state: GameState) -> bool:
	return true
