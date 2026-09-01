class_name AbilityMarniesGrimmsnarlPunkUp
extends BaseEffect

const ASSIGNMENT_STEP_ID := "marnies_punk_up_assignments"
const USED_KEY := "marnies_grimmsnarl_punk_up_used"
const MAX_COUNT := 5


func is_evolve_triggered_ability() -> bool:
	return true


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	if pokemon == null or state == null:
		return false
	var top: CardInstance = pokemon.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	if state.current_player_index != top.owner_index:
		return false
	if pokemon.turn_evolved != state.turn_number:
		return false
	if _used_this_turn(pokemon, state):
		return false
	var player: PlayerState = state.players[top.owner_index]
	return not _collect_basic_darkness_energy(player.deck).is_empty() and not _collect_marnies_targets(player).is_empty()


func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var energy_items: Array = _collect_basic_darkness_energy(player.deck)
	if energy_items.is_empty():
		return []
	var target_items: Array = _collect_marnies_targets(player)
	if target_items.is_empty():
		return []
	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name if energy_card.card_data != null else "")
	var target_labels: Array[String] = []
	for target: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			target.get_pokemon_name(),
			target.get_remaining_hp(),
			target.get_max_hp(),
		])
	var step := build_full_library_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"Choose up to 5 Basic Darkness Energy and attach them to your Marnie's Pokemon",
		player.deck,
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		0,
		mini(MAX_COUNT, energy_items.size()),
		VISIBLE_SCOPE_OWN_FULL_DECK,
		true,
		{"force_confirm": true}
	)
	# Locked CABT expresses Punk Up as two reobserved CARD windows: choose
	# Energy cards to attach (ATTACH_TO), then choose the Pokemon receiving each
	# card (ATTACH_FROM).  These raw semantics are public operation metadata;
	# identities remain private-UID/local-serial values in this engine.
	step["ucis_context_name"] = "ATTACH_TO"
	step["ucis_target_context_name"] = "ATTACH_FROM"
	return [step]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	if pokemon == null or state == null:
		return
	var top: CardInstance = pokemon.get_top_card()
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return
	var player: PlayerState = state.players[top.owner_index]
	var context: Dictionary = get_interaction_context(targets)
	var assignments: Array[Dictionary] = _resolve_assignments(player, context)
	if assignments.is_empty() and context.has(ASSIGNMENT_STEP_ID):
		player.shuffle_deck()
		_mark_used(pokemon, state)
		return
	if assignments.is_empty():
		return
	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		if energy_card not in player.deck or not _is_basic_darkness_energy(energy_card):
			continue
		if target_slot not in player.get_all_pokemon() or not _is_marnies_slot(target_slot):
			continue
		player.deck.erase(energy_card)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)
	player.shuffle_deck()
	_mark_used(pokemon, state)


func _resolve_assignments(player: PlayerState, context: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_assignments: Array = context.get(ASSIGNMENT_STEP_ID, [])
	var has_explicit_assignments := context.has(ASSIGNMENT_STEP_ID)
	var used_sources: Array[CardInstance] = []
	for entry: Variant in selected_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card: CardInstance = source
		var target_slot: PokemonSlot = target
		if source_card not in player.deck or source_card in used_sources:
			continue
		if not _is_basic_darkness_energy(source_card):
			continue
		if target_slot not in player.get_all_pokemon() or not _is_marnies_slot(target_slot):
			continue
		used_sources.append(source_card)
		result.append({"source": source_card, "target": target_slot})
		if result.size() >= MAX_COUNT:
			break
	if not result.is_empty() or has_explicit_assignments:
		return result

	var fallback_sources: Array[CardInstance] = []
	for deck_card: CardInstance in player.deck:
		if _is_basic_darkness_energy(deck_card):
			fallback_sources.append(deck_card)
			if fallback_sources.size() >= MAX_COUNT:
				break
	var fallback_targets: Array = _collect_marnies_targets(player)
	if fallback_sources.is_empty() or fallback_targets.is_empty():
		return []
	for i: int in fallback_sources.size():
		result.append({
			"source": fallback_sources[i],
			"target": fallback_targets[i % fallback_targets.size()],
		})
	return result


func _collect_basic_darkness_energy(cards: Array[CardInstance]) -> Array:
	var result: Array = []
	for deck_card: CardInstance in cards:
		if _is_basic_darkness_energy(deck_card):
			result.append(deck_card)
	return result


func _is_basic_darkness_energy(card: CardInstance) -> bool:
	if card == null or card.card_data == null:
		return false
	var card_data: CardData = card.card_data
	if card_data.card_type != "Basic Energy":
		return false
	var energy_type := card_data.energy_provides if card_data.energy_provides != "" else card_data.energy_type
	return energy_type in ["D", "Darkness", "Dark"]


func _collect_marnies_targets(player: PlayerState) -> Array:
	var result: Array = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if _is_marnies_slot(slot):
			result.append(slot)
	return result


func _is_marnies_slot(slot: PokemonSlot) -> bool:
	return slot != null and _is_marnies_card_data(slot.get_card_data())


func _is_marnies_card_data(card_data: CardData) -> bool:
	if card_data == null or not card_data.is_pokemon():
		return false
	var names: Array[String] = [card_data.name, card_data.name_en, card_data.name_zh]
	for raw_name: String in names:
		var normalized := raw_name.strip_edges().to_lower()
		if normalized.begins_with("marnie's ") or normalized.begins_with("marnies ") or normalized.begins_with("玛俐的"):
			return true
	return false


func _used_this_turn(pokemon: PokemonSlot, state: GameState) -> bool:
	for effect: Dictionary in pokemon.effects:
		if effect.get("type", "") == USED_KEY and int(effect.get("turn", -1)) == state.turn_number:
			return true
	return false


func _mark_used(pokemon: PokemonSlot, state: GameState) -> void:
	if _used_this_turn(pokemon, state):
		return
	pokemon.effects.append({
		"type": USED_KEY,
		"turn": state.turn_number,
	})


func get_description() -> String:
	return "When evolved this turn, attach up to 5 Basic Darkness Energy from your deck to your Marnie's Pokemon."
