extends TestBase

const F = preload("res://tests/test_30thdc_cards.gd")
const Cards = preload("res://tests/test_tournament_series59_special_trainers.gd")
const Projector = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const Recorder = preload("res://scripts/ui/battle/BattleRecordingController.gd")
const Restorer = preload("res://scripts/engine/BattleReplayStateRestorer.gd")
var f := F.new()
var c := Cards.new()

func _battle() -> GameStateMachine:
	var gsm:=c._battle()
	var slot:=c._slot("CSV4C_088")
	gsm.game_state.players[0].active_pokemon=slot
	for uid: String in ["CSV3C_120","CSV3C_120","CSV3C_120","CSV4C_120"]:
		slot.attached_tools.append(c._card(uid))
	for _i: int in 3: slot.attached_energy.append(f._energy())
	gsm.effect_processor.register_pokemon_card(slot.get_card_data())
	return gsm


func test_real_four_tool_host_attests_all_tools_and_binds_tm_fourth_printing() -> String:
	var gsm:=_battle()
	var slot:=gsm.game_state.players[0].active_pokemon
	var host: Dictionary=f._host(gsm,0)
	if not bool(host.get("ok",false)):
		gsm.prepare_for_disposal()
		return "4-tool Host creation failed: %s" % str(host)
	var checks: Array[String]=[]
	var handles: Array=[]
	var bridge:=HeadlessMatchBridge.new()
	bridge.bind(gsm)
	host.owner.run_single_step(bridge,gsm)
	var checkpoint: Dictionary=host.port.pending_checkpoint()
	f._check_frame(checkpoint,checks,handles)
	var found:=false
	if bool(checkpoint.get("ok",false)):
		for option: Dictionary in checkpoint.frame.options:
			if str(option.kind)=="granted_attack":
				found=true
				checks.append(assert_eq(option.get("source_uid"),"CSV4C_120","Fourth Tool owns granted attack identity"))
	checks.append(assert_true(found,"Fourth Tool's attack reaches Host main frontier"))
	for tool: CardInstance in slot.attached_tools:
		checks.append(assert_eq(host.owner.call("_find_attached_card_owner_slot",tool),slot,"All four attached cards have public ownership"))
	var serials: Variant=host.owner.get("_serial_registry")
	var last:=slot.attached_tools[-1]
	last.owner_index=1
	checks.append(assert_false(bool(serials.lookup_pokemon_entity(slot,serials.get_match_generation(),0).get("ok",false)),"Owner drift in fourth Tool is rejected"))
	last.owner_index=0
	bridge.bind(null)
	bridge.free()
	host.owner.close_match()
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_wire_projection_preserves_all_tools_and_old_fixture_compatibility() -> String:
	var projector: Variant=Projector.load_default()
	var top: Dictionary={"official_card_id":646,"serial":1,"player_index":0}
	var tools: Array=[]
	for i: int in 4: tools.append({"official_card_id":104,"serial":i+2,"player_index":0})
	var source: Dictionary={"stack":[top],"attached_energy":[],"tool":tools[0],"tools":tools,"appear_this_turn":false,"hp":100,"max_hp":100}
	var wire: Dictionary=projector.call("_wire_pokemon",source)
	var checks: Array[String]=[assert_eq(wire.tools.size(),4,"Official tools array contains every Tool")]
	if wire.tools.size()==4:
		for i: int in 4: checks.append(assert_eq(wire.tools[i].serial,i+2))
	source.erase("tools")
	checks.append(assert_eq(projector.call("_wire_pokemon",source).tools.size(),1,"Old fixture's singular tool still works"))
	return run_checks(checks)


func test_multi_tool_display_snapshot_and_recording_round_trip() -> String:
	var gsm:=_battle()
	var slot:=gsm.game_state.players[0].active_pokemon
	var snapshot:=BattleVisualSnapshot.capture(gsm.game_state)
	var captured: Dictionary=snapshot.slots["p0.active"]
	var checks: Array[String]=[assert_eq(snapshot.zones["p0.active.tool"].size(),4,"Visual layer sees all attached Tools")]
	checks.append(assert_eq(BattleVisualEventBuilder._slot_card_ids(captured).size(),slot.collect_all_cards().size(),"Switch/KO animation moves every attachment"))
	var detail:=BattleCardDetailCoordinator.new()
	var lines:=detail.pokemon_slot_resource_detail_lines(slot)
	checks.append(assert_true("、" in "\n".join(lines),"Card detail enumerates multiple Tools"))
	checks.append(assert_true("暗中奇袭" in "\n".join(lines),"Fourth Tool visible in card detail"))
	var recorder:=Recorder.new()
	var serialized:=recorder.serialize_pokemon_slot(slot)
	checks.append(assert_eq(serialized.get("attached_tools",[]).size(),4))
	var restorer:=Restorer.new()
	var restored: PokemonSlot=restorer.call("_restore_slot",serialized,0)
	checks.append(assert_eq(restored.get_attached_tools().size(),4,"Recorder and restorer retain four physical Tools"))
	if restored.get_attached_tools().size()==4:
		for i: int in 4: checks.append(assert_eq(restored.get_attached_tools()[i].instance_id,slot.attached_tools[i].instance_id))
	serialized.erase("attached_tools")
	var legacy: PokemonSlot=restorer.call("_restore_slot",serialized,0)
	checks.append(assert_eq(legacy.get_attached_tools().size(),1,"Old recordings remain readable"))
	gsm.prepare_for_disposal()
	return run_checks(checks)


func test_scenario_snapshot_restores_all_tools_and_accepts_legacy_single_tool() -> String:
	var gsm:=_battle()
	var snapshot:=ScenarioStateSnapshot.capture(gsm.game_state)
	var checks: Array[String]=[assert_eq(snapshot.players[0].active.get("attached_tools",[]).size(),4)]
	var restored: Dictionary=ScenarioStateRestorer.restore(snapshot)
	checks.append(assert_eq(restored.errors,[]))
	if restored.gsm!=null:
		checks.append(assert_eq(restored.gsm.game_state.players[0].active_pokemon.get_attached_tools().size(),4))
		restored.gsm.prepare_for_disposal()
	snapshot.players[0].active.erase("attached_tools")
	restored=ScenarioStateRestorer.restore(snapshot)
	checks.append(assert_eq(restored.errors,[]))
	if restored.gsm!=null:
		checks.append(assert_eq(restored.gsm.game_state.players[0].active_pokemon.get_attached_tools().size(),1))
		restored.gsm.prepare_for_disposal()
	gsm.prepare_for_disposal()
	return run_checks(checks)
