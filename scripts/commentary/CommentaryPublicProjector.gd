extends RefCounted
## An observer allow-list, deliberately independent of private replay/advice DTOs.
## Hidden zones are counted, never iterated. Setup faces stay hidden for BOTH seats.
static func card(cd: CardData) -> Dictionary:
	if cd == null: return {}
	var attacks: Array = []
	for move: Dictionary in cd.attacks:
		attacks.append({"name": str(move.get("name", "")).left(80), "text": str(move.get("text", "")).left(900), "cost": str(move.get("cost", "")).left(80), "damage": str(move.get("damage", "")).left(30)})
	var abilities: Array = []
	for ability: Dictionary in cd.abilities:
		abilities.append({"name": str(ability.get("name", "")).left(80), "text": str(ability.get("text", "")).left(900)})
	return {"uid": cd.get_uid(), "name": cd.display_name(), "type": cd.card_type, "stage": cd.stage, "hp": cd.hp, "mechanic": cd.mechanic, "evolves_from": cd.evolves_from, "text": cd.description.left(900), "attacks": attacks, "abilities": abilities, "weakness": cd.weakness_energy, "resistance": cd.resistance_energy, "energy_provides": cd.energy_provides}

static func snapshot(gs: GameState) -> Dictionary:
	if gs == null or gs.players.size() != 2: return {}
	var public_field := gs.turn_number > 0 and gs.phase not in [GameState.GamePhase.SETUP, GameState.GamePhase.MULLIGAN, GameState.GamePhase.SETUP_PLACE]
	var result := {"turn": gs.turn_number, "current": gs.current_player_index, "phase": GameState.GamePhase.keys()[gs.phase], "players": [], "cards": {}, "stadium": "", "winner": gs.winner_index if gs.phase == GameState.GamePhase.GAME_OVER else -1}
	for player: PlayerState in gs.players:
		var bench: Array = []
		for slot: PokemonSlot in player.bench: bench.append(_slot(slot, public_field, result.cards))
		result.players.append({"hand_count": player.hand.size(), "deck_count": player.deck.size(), "prizes_remaining": player.prizes.size(), "active": _slot(player.active_pokemon, public_field, result.cards), "bench": bench, "discard": _zone(player.discard_pile, result.cards), "lost_zone": _zone(player.lost_zone, result.cards)})
	if gs.stadium_card != null and gs.stadium_card.card_data != null:
		result.stadium = _remember(gs.stadium_card, result.cards)
	result["turn_resources"] = {"energy_attached": gs.energy_attached_this_turn, "supporter_used": gs.supporter_used_this_turn, "retreat_used": gs.retreat_used_this_turn, "vstar_used": gs.vstar_power_used.duplicate()}
	return result

static func _remember(instance: CardInstance, catalog: Dictionary) -> String:
	if instance == null or instance.card_data == null: return ""
	var uid := instance.card_data.get_uid()
	catalog[uid] = card(instance.card_data)
	return uid

static func _zone(zone: Array, catalog: Dictionary) -> Dictionary:
	var counts := {}
	for instance: CardInstance in zone:
		var uid := _remember(instance, catalog)
		if not uid.is_empty(): counts[uid] = int(counts.get(uid, 0)) + 1
	return counts

static func _slot(slot: PokemonSlot, public_field: bool, catalog: Dictionary) -> Dictionary:
	if slot == null or slot.get_top_card() == null: return {}
	if not public_field: return {"concealed": true}
	var stack: Array = []
	for instance: CardInstance in slot.pokemon_stack: stack.append(_remember(instance, catalog))
	var energy: Array = []
	for instance: CardInstance in slot.attached_energy: energy.append(_remember(instance, catalog))
	var statuses: Array = []
	for key: String in ["poisoned", "burned", "asleep", "paralyzed", "confused"]:
		if bool(slot.status_conditions.get(key, false)): statuses.append(key)
	return {"uid": _remember(slot.get_top_card(), catalog), "evolution": stack, "hp": slot.get_remaining_hp(), "max_hp": slot.get_max_hp(), "damage_points": slot.damage_counters, "damage_counter_count": slot.damage_counters / 10, "energy": energy, "tool": _remember(slot.attached_tool, catalog), "statuses": statuses}

static func event(action: GameAction, sequence: int) -> Dictionary:
	var result := {"id": sequence, "type": GameAction.ActionType.keys()[action.action_type], "player": action.player_index, "turn": action.turn_number}
	# Never forward arbitrary data, descriptions, draw identities, prizes, RNG,
	# public_reveal payloads or target dictionaries (their provenance varies).
	var fields: Array = []
	match action.action_type:
		GameAction.ActionType.ATTACK: fields = ["attack_name"]
		GameAction.ActionType.USE_ABILITY: fields = ["pokemon_name", "ability_name"]
		GameAction.ActionType.PLAY_TRAINER, GameAction.ActionType.PLAY_TOOL, GameAction.ActionType.PLAY_STADIUM: fields = ["card_name"]
		GameAction.ActionType.EVOLVE: fields = ["base", "evolution"]
		GameAction.ActionType.PLAY_POKEMON, GameAction.ActionType.SEND_OUT, GameAction.ActionType.KNOCKOUT: fields = ["pokemon_name"]
		GameAction.ActionType.ATTACH_ENERGY: fields = ["energy", "target", "pokemon_name"]
		GameAction.ActionType.DAMAGE_DEALT, GameAction.ActionType.HEAL: fields = ["target"]
	if action.action_type == GameAction.ActionType.PLAY_TRAINER and action.data.get("not_played", false) == true:
		result.type = "TRAINER_NOT_PLAYED"
	if action.action_type in [GameAction.ActionType.DRAW_CARD, GameAction.ActionType.TAKE_PRIZE]:
		if action.data.get("count") is int: result.count = action.data.count
	for key: String in fields:
		if action.data.get(key) is String: result[key] = action.data[key].left(80)
	return result

static func public_names(state: Dictionary, seat: int) -> Array[String]:
	var names: Array[String] = []
	if state.get("players", []).size() != 2: return names
	var player: Dictionary = state.players[seat]
	var ids: Array = player.get("discard", {}).keys() + player.get("lost_zone", {}).keys()
	for slot: Dictionary in [player.active] + player.bench:
		ids.append_array(slot.get("evolution", []))
	for uid: String in ids:
		var value := str(state.cards.get(uid, {}).get("name", ""))
		if not value.is_empty() and value not in names: names.append(value)
	return names
