class_name BattleReplayStateRestorer
extends RefCounted


func restore(raw_snapshot: Dictionary) -> GameState:
	var snapshot_state_variant: Variant = raw_snapshot.get("state", raw_snapshot)
	var snapshot_state: Dictionary = snapshot_state_variant if snapshot_state_variant is Dictionary else {}
	var state := GameState.new()
	state.turn_number = int(snapshot_state.get("turn_number", raw_snapshot.get("turn_number", 0)))
	state.current_player_index = int(snapshot_state.get("current_player_index", raw_snapshot.get("player_index", 0)))
	state.first_player_index = int(snapshot_state.get("first_player_index", 0))
	state.phase = _restore_phase(snapshot_state.get("phase", raw_snapshot.get("phase", GameState.GamePhase.SETUP)))
	state.winner_index = int(snapshot_state.get("winner_index", -1))
	state.win_reason = str(snapshot_state.get("win_reason", ""))
	state.energy_attached_this_turn = bool(snapshot_state.get("energy_attached_this_turn", false))
	state.supporter_used_this_turn = bool(snapshot_state.get("supporter_used_this_turn", false))
	state.stadium_played_this_turn = bool(snapshot_state.get("stadium_played_this_turn", false))
	state.retreat_used_this_turn = bool(snapshot_state.get("retreat_used_this_turn", false))
	state.stadium_owner_index = int(snapshot_state.get("stadium_owner_index", -1))
	state.stadium_card = _restore_card_instance(snapshot_state.get("stadium_card", {}), state.stadium_owner_index)
	state.stadium_effect_used_turn = int(snapshot_state.get("stadium_effect_used_turn", -1))
	state.stadium_effect_used_player = int(snapshot_state.get("stadium_effect_used_player", -1))
	state.stadium_effect_used_effect_id = str(snapshot_state.get("stadium_effect_used_effect_id", ""))
	var vstar_variant: Variant = snapshot_state.get("vstar_power_used", [false, false])
	if vstar_variant is Array and (vstar_variant as Array).size() >= 2:
		state.vstar_power_used = [bool(vstar_variant[0]), bool(vstar_variant[1])]
	var knockout_variant: Variant = snapshot_state.get("last_knockout_turn_against", [-999, -999])
	if knockout_variant is Array and (knockout_variant as Array).size() >= 2:
		state.last_knockout_turn_against = [int(knockout_variant[0]), int(knockout_variant[1])]
	var flags_variant: Variant = snapshot_state.get("shared_turn_flags", {})
	if flags_variant is Dictionary:
		state.shared_turn_flags = (flags_variant as Dictionary).duplicate(true)

	var players_variant: Variant = snapshot_state.get("players", [])
	if players_variant is Array:
		for player_variant: Variant in players_variant:
			if player_variant is Dictionary:
				state.players.append(_restore_player_state(player_variant as Dictionary))
	return state


func _restore_phase(value: Variant) -> GameState.GamePhase:
	if value is int:
		return int(value)
	var text := str(value).strip_edges().to_lower()
	if text.is_valid_int():
		return int(text)
	match text:
		"setup":
			return GameState.GamePhase.SETUP
		"mulligan":
			return GameState.GamePhase.MULLIGAN
		"setup_place":
			return GameState.GamePhase.SETUP_PLACE
		"draw":
			return GameState.GamePhase.DRAW
		"main":
			return GameState.GamePhase.MAIN
		"attack":
			return GameState.GamePhase.ATTACK
		"pokemon_check":
			return GameState.GamePhase.POKEMON_CHECK
		"between_turns":
			return GameState.GamePhase.BETWEEN_TURNS
		"knockout_replace":
			return GameState.GamePhase.KNOCKOUT_REPLACE
		"game_over":
			return GameState.GamePhase.GAME_OVER
	return GameState.GamePhase.SETUP


func _restore_player_state(snapshot: Dictionary) -> PlayerState:
	var player := PlayerState.new()
	player.player_index = int(snapshot.get("player_index", 0))
	player.hand = _restore_card_list(snapshot.get("hand", []), player.player_index)
	player.deck = _restore_card_list(snapshot.get("deck", []), player.player_index)
	player.prizes = _restore_card_list(snapshot.get("prizes", []), player.player_index)
	player.reset_prize_layout()
	player.discard_pile = _restore_card_list(snapshot.get("discard_pile", []), player.player_index)
	player.lost_zone = _restore_card_list(snapshot.get("lost_zone", []), player.player_index)
	player.active_pokemon = _restore_slot(snapshot.get("active", {}), player.player_index)
	var bench_variant: Variant = snapshot.get("bench", [])
	if bench_variant is Array:
		for slot_variant: Variant in bench_variant:
			var slot: PokemonSlot = _restore_slot(slot_variant, player.player_index)
			if slot != null:
				player.bench.append(slot)
	return player


func _restore_card_list(cards_variant: Variant, fallback_owner_index: int) -> Array[CardInstance]:
	var restored: Array[CardInstance] = []
	if not (cards_variant is Array):
		return restored
	for card_variant: Variant in cards_variant:
		var card: CardInstance = _restore_card_instance(card_variant, fallback_owner_index)
		if card != null:
			restored.append(card)
	return restored


func _restore_slot(slot_variant: Variant, fallback_owner_index: int) -> PokemonSlot:
	if not (slot_variant is Dictionary):
		return null
	var slot_snapshot: Dictionary = slot_variant
	if slot_snapshot.is_empty():
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = _restore_card_list(slot_snapshot.get("pokemon_stack", []), fallback_owner_index)
	slot.attached_energy = _restore_card_list(slot_snapshot.get("attached_energy", []), fallback_owner_index)
	slot.attached_tool = _restore_card_instance(slot_snapshot.get("attached_tool", {}), fallback_owner_index)
	slot.damage_counters = int(slot_snapshot.get("damage_counters", 0))
	slot.turn_played = int(slot_snapshot.get("turn_played", -1))
	slot.turn_evolved = int(slot_snapshot.get("turn_evolved", -1))
	var status_variant: Variant = slot_snapshot.get("status_conditions", {})
	slot.status_conditions = status_variant.duplicate(true) if status_variant is Dictionary else slot.status_conditions
	var effects_variant: Variant = slot_snapshot.get("effects", [])
	slot.effects = _restore_dictionary_array(effects_variant)
	var top_card := slot.get_top_card()
	if top_card != null and top_card.card_data != null:
		top_card.card_data.retreat_cost = int(slot_snapshot.get("retreat_cost", top_card.card_data.retreat_cost))
	return slot


func _restore_card_instance(card_variant: Variant, fallback_owner_index: int) -> CardInstance:
	if not (card_variant is Dictionary):
		return null
	var card_snapshot: Dictionary = card_variant
	if card_snapshot.is_empty():
		return null
	var owner_index: int = int(card_snapshot.get("owner_index", fallback_owner_index))
	var card_data := _restore_card_data(card_snapshot)
	var card := CardInstance.create(card_data, owner_index)
	var instance_id: int = int(card_snapshot.get("instance_id", card.instance_id))
	card.instance_id = instance_id
	card.face_up = bool(card_snapshot.get("face_up", false))
	if instance_id >= CardInstance._next_id:
		CardInstance._next_id = instance_id + 1
	return card


func _restore_card_data(card_snapshot: Dictionary) -> CardData:
	var card_data := CardData.new()
	card_data.name = str(card_snapshot.get("card_name", ""))
	card_data.card_type = str(card_snapshot.get("card_type", ""))
	card_data.mechanic = str(card_snapshot.get("mechanic", ""))
	card_data.description = str(card_snapshot.get("description", ""))
	card_data.stage = str(card_snapshot.get("stage", ""))
	card_data.hp = int(card_snapshot.get("hp", 0))
	card_data.energy_type = str(card_snapshot.get("energy_type", ""))
	card_data.effect_id = str(card_snapshot.get("effect_id", ""))
	card_data.energy_provides = str(card_snapshot.get("energy_provides", ""))
	card_data.set_code = str(card_snapshot.get("set_code", ""))
	card_data.card_index = str(card_snapshot.get("card_index", ""))
	card_data.evolves_from = str(card_snapshot.get("evolves_from", ""))
	card_data.weakness_energy = str(card_snapshot.get("weakness_energy", ""))
	card_data.weakness_value = str(card_snapshot.get("weakness_value", ""))
	card_data.resistance_energy = str(card_snapshot.get("resistance_energy", ""))
	card_data.resistance_value = str(card_snapshot.get("resistance_value", ""))
	card_data.retreat_cost = int(card_snapshot.get("retreat_cost", 0))
	card_data.attacks = _restore_dictionary_array(card_snapshot.get("attacks", []))
	card_data.abilities = _restore_dictionary_array(card_snapshot.get("abilities", []))
	card_data.ensure_image_metadata()
	return card_data


func _restore_dictionary_array(value: Variant) -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	if not (value is Array):
		return restored
	for entry: Variant in value:
		if entry is Dictionary:
			restored.append((entry as Dictionary).duplicate(true))
	return restored
