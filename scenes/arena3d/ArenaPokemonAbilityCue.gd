extends RefCounted
## Trusted public-scene adapter. Renderer receives values and slot coordinates only.
const Frame := preload("res://scenes/arena3d/ArenaFrame.gd")
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")

static func capture(action: GameAction,state: GameState,view: int,before: Dictionary,after: Dictionary) -> Dictionary:
	if action==null or state==null or state.players.size()!=2 or view not in [0,1]:return {}
	if action.action_type!=GameAction.ActionType.USE_ABILITY or action.player_index not in [0,1]:return {}
	var player: PlayerState=state.players[action.player_index]
	var runtime_id:=int(action.data.get("source_slot_runtime_id",0))
	var prefix: String="my" if action.player_index==view else "opp"
	var caster: String=""
	for slot: PokemonSlot in player.get_all_pokemon():
		if int(slot.get_instance_id())!=runtime_id:continue
		caster=prefix+"_active" if slot==player.active_pokemon else prefix+"_bench_%d" % player.bench.find(slot)
	if caster=="":return {}
	var card: Dictionary=after.get("slots",{}).get(caster,{})
	if Catalog.identify(card)!="gardevoir":return {}
	var old_caster: Dictionary=before.get("slots",{}).get(caster,{})
	if old_caster.get("concealed",true) or old_caster.get("visual_id","")!=card.get("visual_id",""):return {}
	var resolved:=project(caster,before,after)
	if not resolved.is_empty():
		resolved.title=str(action.data.get("ability_name","精神拥抱"))
		resolved.turn=state.turn_number
	return resolved

static func project(caster: String,before: Dictionary,after: Dictionary) -> Dictionary:
	var card: Dictionary=after.get("slots",{}).get(caster,{})
	if Catalog.identify(card)!="gardevoir":return {}
	var old_caster: Dictionary=before.get("slots",{}).get(caster,{})
	if old_caster.get("concealed",true) or old_caster.get("visual_id","")=="" or old_caster.get("visual_id")!=card.get("visual_id"):return {}
	var side: String="my_" if caster.begins_with("my_") else "opp_"
	var recipient: String=""
	for id: String in before.get("slots",{}):
		if not id.begins_with(side):continue
		var old: Dictionary=before.slots[id]
		var now: Dictionary=after.get("slots",{}).get(id,{})
		if old.get("concealed",true) or now.get("concealed",true):continue
		if old.get("visual_id","")=="" or old.get("visual_id")!=now.get("visual_id"):continue
		var energy_gain: int=now.get("energy",[]).count("P")-old.get("energy",[]).count("P")
		var damage_gain:=int(now.get("damage",0))-int(old.get("damage",0))
		if energy_gain==1 and damage_gain==20:
			if recipient!="":return {}
			recipient=id
	if recipient=="":return {}
	return {"public":true,"species":"gardevoir","card":card.duplicate(true),"caster":caster,"target":recipient,"energy_count":1,"damage":20}
