extends RefCounted
## Trusted scene adapter: only the committed, public discarded Supporter and
## already-visible board coordinates cross into the renderer. Never hands/decks.
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const Frame := preload("res://scenes/arena3d/ArenaFrame.gd")

static func capture(action: GameAction, state: GameState, view: int, before: Dictionary) -> Dictionary:
	if action == null or state == null or state.players.size() != 2 or view not in [0,1]: return {}
	if action.action_type != GameAction.ActionType.PLAY_TRAINER or action.data.get("not_played",false): return {}
	if action.player_index not in [0,1]: return {}
	var discard: Array[CardInstance] = state.players[action.player_index].discard_pile
	if discard.is_empty(): return {}
	# play_trainer appends its successfully resolved card last, before action_logged.
	# Never search hidden zones or infer identity from a pre-commit hand index.
	var card: CardInstance = discard.back()
	if card == null or card.card_data == null: return {}
	var data: CardData = card.card_data
	if data.name != str(action.data.get("card_name","")): return {}
	var cue := {"public":true,"concealed":false,"card_type":data.card_type,
		"regulation":data.regulation_mark,"name":data.display_name(),"identities":data.rule_identity_names(),
		"uid":data.get_uid(),"image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(data.set_code,data.card_index,data.image_local_path)),
		"mine":action.player_index==view,"source_slot":"","target_slot":"","energy_slots":[]}
	var id := Catalog.identify(cue)
	if id.is_empty(): return {}
	var after := Frame.capture(state,view)
	var prefix := "my" if cue.mine else "opp"
	var surviving_public_ids: Dictionary={}
	for slot: String in after.slots:
		var visible: Dictionary=after.slots[slot]
		if slot.begins_with(prefix) and not visible.get("concealed",true) and visible.get("visual_id","")!="":
			surviving_public_ids[visible.visual_id]=true
	if id == "boss":
		var target := ("opp" if cue.mine else "my")+"_active"
		var now: Dictionary = after.slots.get(target,{})
		for slot: String in before.get("slots",{}):
			var old: Dictionary = before.slots[slot]
			if not old.get("concealed",true) and old.get("visual_id","") != "" and old.get("visual_id") == now.get("visual_id") and slot != target:
				cue.source_slot=slot; cue.target_slot=target
	for slot: String in before.get("slots",{}):
		if not slot.begins_with(prefix): continue
		var old: Dictionary = before.slots[slot]
		var now: Dictionary = after.slots.get(slot,{})
		if old.get("concealed",true) or old.get("empty",true): continue
		# Bench arrays compact after a return. Follow the removed public identity,
		# never mistake every shifted occupant for a second returned Pokemon.
		if id in ["turo","penny"] and old.get("visual_id","")!="" and not surviving_public_ids.has(old.visual_id):
			cue.source_slot=slot
		if not now.get("concealed",true) and old.get("visual_id","") == now.get("visual_id","") and now.get("energy",[]).size()>old.get("energy",[]).size():
			cue.energy_slots.append(slot)
	return cue
