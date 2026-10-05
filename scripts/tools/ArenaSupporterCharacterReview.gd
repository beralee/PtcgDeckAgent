extends SceneTree
## Staged legal boards, real committed trainer plays, shipping Windows presentation.
## This is an authored showcase, not a recorded competitive match.
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const OUT := "res://.tmp/supporter-characters-20260929"
const CHAPTER := 6.0
var rig: Node
var presenter: Control
var elapsed := 0.0
var chapter := -1
var fired := false
var capturing := false
var actor: CardInstance
var context: Dictionary
var current_id := ""
var database: Node
var item_data: CardData
var tool_data: CardData
var roster: Array = Catalog.ENTRIES.keys()

class Ticker extends Node:
	var owner_tree: SceneTree
	func _process(delta: float) -> void:owner_tree.tick(delta)

func _initialize() -> void:
	root.set_meta("performance_bench_offline",true)
	ProjectSettings.set_setting("editor/movie_writer/mjpeg_quality",.80)
	call_deferred("launch")

func launch() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):roster=[argument.trim_prefix("--only=")]
	root.size = Vector2i(1600,900)
	root.content_scale_size = Vector2i(1600,900)
	database = root.get_node("CardDatabase")
	for data: CardData in database.get_all_cards():
		if item_data==null and data.card_type=="Item":item_data=data
		if tool_data==null and data.card_type=="Tool":tool_data=data
		if item_data!=null and tool_data!=null:break
	rig = load("res://scripts/tools/ArenaSignatureScenario.gd").new()
	root.add_child(rig)
	await rig.mount("dragapult",0)
	presenter = rig.battle.get_node("Arena3DPresenter")
	presenter.world.configure_quality(false)
	presenter.viewport.msaa_3d = Viewport.MSAA_4X
	var ticker := Ticker.new()
	ticker.owner_tree = self
	ticker.process_priority = 1000
	root.add_child(ticker)
	for i: int in 6:await process_frame
	if "--verify" in OS.get_cmdline_user_args() or "--stills" in OS.get_cmdline_user_args():
		presenter.world.sound_enabled = false
		for id: String in roster:
			_prepare(id)
			await process_frame
			if not _play():quit(1);return
			if "--stills" in OS.get_cmdline_user_args():
				presenter.world.supporter_vfx.manual_clock = true
				presenter.motion.set_process(false)
				presenter.world.supporter_vfx.sample(1.18)
				for i: int in 3:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OUT+"/live-"+id+".png")
			await process_frame
		print("SUPPORTER_VERIFICATION_COMPLETE count=",roster.size())
		quit()
	else:
		print("SUPPORTER_RECORDING_READY frame=",Engine.get_process_frames())
		capturing = true

func _card(set_code: String,index: String,owner: int=0) -> CardInstance:
	return CardInstance.create(database.get_card(set_code,index),owner)

func _prepare(id: String) -> void:
	current_id = id
	presenter.motion.clear()
	rig.gsm.game_state = GameState.new()
	var state: GameState = rig.gsm.game_state
	state.current_player_index=0;state.first_player_index=0;state.turn_number=5;state.phase=GameState.GamePhase.MAIN
	for pi: int in 2:
		var player := PlayerState.new()
		player.player_index=pi
		state.players.append(player)
		player.active_pokemon=rig._slot(database.get_card("CSV8C","159") if pi==0 else database.get_card("CSV5C","075"),pi)
		for printing: Array in [["CSV8C","094"],["CSV7C","154"],["CSV9C","175"]]:
			player.bench.append(rig._slot(database.get_card(printing[0],printing[1]),pi))
		for energy: String in ["R","P"]:player.active_pokemon.attached_energy.append(CardInstance.create(rig._energy(energy),pi))
		player.bench[0].attached_energy.append(CardInstance.create(rig._energy("D"),pi))
		var prizes: Array[CardInstance]=[]
		for i: int in (2 if pi==1 and id=="briar" else 6):prizes.append(CardInstance.create(rig._energy("R"),pi))
		player.set_prizes(prizes)
		for energy: String in ["R","P","D","L"]:player.hand.append(CardInstance.create(rig._energy(energy),pi))
		for energy: String in ["R","P","L"]:player.discard_pile.append(CardInstance.create(rig._energy(energy),pi))
		player.deck.append(CardInstance.create(item_data,pi))
		player.deck.append(CardInstance.create(tool_data,pi))
		for printing: Array in [["CSV7C","154"],["CSV9C","175"],["CSV8C","159"]]:player.deck.append(_card(printing[0],printing[1],pi))
		player.deck.append(CardInstance.create(rig._energy("P"),pi))
		while rig.gsm.count_player_total_cards(pi)<60:player.deck.append(CardInstance.create(rig._energy("R"),pi))
	var player: PlayerState=state.players[0]
	var spec: Dictionary=Catalog.ENTRIES[id]
	actor=_card(spec.printing[0],spec.printing[1])
	player.deck.pop_back();player.hand.append(actor)
	context={}
	match id:
		"boss":context={"opponent_bench_target":[state.players[1].bench[1]]}
		"arven":context={"search_item":[player.deck[0]],"search_tool":[player.deck[1]]}
		"turo":context={"prof_turo_target":[player.bench[0]]}
		"penny":context={"penny_target":[player.bench[0]]}
		"cipher":context={"top_cards":[player.deck[0],player.deck[1]]}
		"crispin":context={"csv9c196_energy_to_hand":[player.deck[6]],"csv9c196_energy_attachment":[{"source":player.deck[5],"target":player.bench[1]}]}
		"sada":context={"sada_assignments":[{"source":player.discard_pile[0],"target":player.bench[1]}]}
		"cilan":context={"csv9c198_pokemon_ex":[player.deck[2],player.deck[3],player.deck[4]]}
		"kieran":context={"kieran_mode":[false]}
		"lana":context={"lanas_aid_cards":player.discard_pile.duplicate()}
		"brock":context={"brocks_scouting_mode":[true],"brocks_scouting_basic":[player.deck[2],player.deck[3]]}
	rig.battle.call("_refresh_ui")
	presenter.motion.shown={}
	presenter._refresh()

func _play() -> bool:
	var success: bool = rig.gsm.play_trainer(0,actor,[context])
	var routed: bool = presenter.world.supporter_vfx.last_outcome.get("id")==current_id
	if not success or not routed:
		push_error("Supporter showcase failed to commit: "+current_id)
		return false
	print("SUPPORTER_COMMITTED ",current_id," at=",elapsed)
	return true

func tick(delta: float) -> void:
	if not capturing:return
	var next := int(elapsed/CHAPTER)
	if next>=roster.size():
		print("SUPPORTER_RECORDING_COMPLETE")
		capturing=false
		quit()
		return
	if next!=chapter:
		if chapter>=0 and presenter.motion.is_busy():push_error("Previous supporter did not finish before next chapter: "+current_id)
		chapter=next
		_prepare(roster[chapter])
		fired=false
	if fmod(elapsed,CHAPTER)>=.55 and not fired:
		fired=true
		if not _play():quit(1);return
	elapsed+=delta
