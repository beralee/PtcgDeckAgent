extends RefCounted
static var backdrop_resolver: RefCounted
## Presentation-only positive projection. Never serialize a private snapshot.
## No policy, action indexes, engine references or hidden card identities leave here.

static func capture(gs: GameState, view_player: int, display_owner: Object = null) -> Dictionary:
	if gs == null or gs.players.size() != 2:
		return {}
	var result := {"turn": gs.turn_number, "current": gs.current_player_index, "view": view_player, "slots": {}, "players": [], "stadium": "", "stadium_card": {}}
	# The engine's card face_up flag may stay false after search-to-bench effects.
	# Once setup is over, occupied field zones are public (existing visual policy).
	var public_field := gs.turn_number > 0 and gs.phase not in [GameState.GamePhase.SETUP,GameState.GamePhase.MULLIGAN,GameState.GamePhase.SETUP_PLACE]
	for pi in range(2):
		var player: PlayerState = gs.players[pi]
		var visible_discard: Array = player.discard_pile
		if display_owner != null and display_owner.get("_battle_display_controller") != null:
			visible_discard = display_owner.get("_battle_display_controller").call("_visible_discard_pile",display_owner,pi,player.discard_pile)
		var prize_slots: Array[bool] = []
		for i in range(6): prize_slots.append(player.get_prize_at_slot(i) != null)
		result.players.append({"deck_count": player.deck.size(), "hand_count": player.hand.size(), "prizes": player.prizes.size(), "prize_slots": prize_slots, "discard_count": visible_discard.size(), "discard_top":_public_top(visible_discard)})
		var prefix := "my" if pi == view_player else "opp"
		result.slots[prefix + "_active"] = _slot(player.active_pokemon,public_field,display_owner)
		var capacity := BenchLimitHelper.get_bench_limit_for_player(gs,player) if public_field else 5
		for i in range(maxi(capacity, player.bench.size())):
			result.slots[prefix + "_bench_%d" % i] = _slot(player.bench[i] if i < player.bench.size() else null,public_field,display_owner)
	if gs.stadium_card != null and gs.stadium_card.card_data != null:
		var cd: CardData = gs.stadium_card.card_data
		result.stadium = cd.display_name()
		result.stadium_card = {"empty":false,"concealed":false,"uid":cd.get_uid(),"name":cd.display_name(),"hp":0,"max_hp":0,"energy":[],"tool":false,"status":[],"evolution":1,"type":"C","image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(cd.set_code,cd.card_index,cd.image_local_path))}
		result.stadium_card.visual_id = str(gs.stadium_card.instance_id)
	# The shared resolver also contains UI methods that reference autoloads.
	# Load it at capture time so pure projection scripts can still be preloaded.
	if backdrop_resolver == null:
		backdrop_resolver = load("res://scripts/ui/battle/display/BattleStadiumBackdropCoordinator.gd").new()
	result.stadium_background = backdrop_resolver.resolve_stadium_backdrop_path(gs.stadium_card,"")
	return result

static func _slot(slot: PokemonSlot, public_field: bool = false, display_owner: Object = null) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {"empty": true}
	var card: CardInstance = slot.get_top_card()
	if (not card.face_up and not public_field) or card.card_data == null:
		return {"empty": false, "concealed": true}
	var cd: CardData = card.card_data
	var energies: Array[String] = []
	for energy in slot.attached_energy:
		if energy.card_data != null:
			energies.append(energy.card_data.energy_provides)
	var statuses: Array[String] = []
	var status: Dictionary = display_owner.call("_build_battle_status",slot) if display_owner != null else {}
	for key in slot.status_conditions:
		if slot.status_conditions[key]:
			statuses.append(key)
	return {"empty": false, "concealed": false, "uid": cd.get_uid(), "visual_id":str(card.instance_id), "name": cd.display_name(),
		"is_tera":cd.is_tera_pokemon(),
		"image": CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(cd.set_code, cd.card_index, cd.image_local_path)),
		"hp": int(status.get("hp_current",slot.get_remaining_hp())), "max_hp": int(status.get("hp_max",slot.get_max_hp())), "damage":slot.damage_counters, "type": cd.energy_type,
		"energy": energies, "status": statuses, "tool": slot.attached_tool != null,
		"energy_icons": status.get("energy_icons",energies).duplicate(), "ability_used":bool(status.get("ability_used_this_turn",false)),
		"tool_name": slot.attached_tool.card_data.display_name() if slot.attached_tool != null and slot.attached_tool.card_data != null else "",
		"tool_image": _tool_image(slot),
		"evolution": slot.pokemon_stack.size()}

static func _tool_image(slot: PokemonSlot) -> String:
	if slot.attached_tool == null or slot.attached_tool.card_data == null: return ""
	var cd: CardData = slot.attached_tool.card_data
	return CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(cd.set_code,cd.card_index,cd.image_local_path))

static func _public_top(zone: Array) -> Dictionary:
	# The discard pile is public in the existing viewer. Never call for
	# a deck, prize or opponent hand; no hidden pile identity enters this DTO.
	if zone.is_empty(): return {}
	var card: CardInstance = zone.back()
	if card == null or card.card_data == null: return {}
	var cd: CardData = card.card_data
	return {"uid":cd.get_uid(),"name":cd.display_name(),"image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(cd.set_code,cd.card_index,cd.image_local_path))}
