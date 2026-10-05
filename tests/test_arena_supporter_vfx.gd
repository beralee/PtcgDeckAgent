extends TestBase
const Scenario := preload("res://scripts/tools/ArenaSignatureScenario.gd")
const Catalog := preload("res://scenes/arena3d/ArenaSupporterCatalog.gd")
const Cue := preload("res://scenes/arena3d/ArenaSupporterCue.gd")

func test_every_other_supporter_uses_six_authored_character_poses() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node3D = load("res://scenes/arena3d/ArenaWorld.gd").new()
	tree.root.add_child(world)
	world.sound_enabled = false
	world.supporter_vfx.manual_clock = true
	var checks: Array[String] = []
	for id: String in Catalog.ENTRIES:
		if id == "boss": continue
		var spec: Dictionary = Catalog.ENTRIES[id]
		world.supporter_vfx.play(_public_card(CardDatabase.get_card(spec.printing[0],spec.printing[1])))
		var hero: Node = world.supporter_vfx.active.hero
		checks.append(assert_true(hero is Sprite2D,"Character cut-in replaces the rejected full-card billboard: "+id))
		if hero is Sprite2D:
			checks.append(assert_true(hero.hframes == 3 and hero.vframes == 2,"Six authored poses: "+id))
			world.supporter_vfx.sample(.5)
			var preparation: int = hero.frame
			world.supporter_vfx.sample(1.2)
			checks.append(assert_true(hero.frame != preparation,"Gesture changes at the action beat: "+id))
			checks.append(assert_true(world.supporter_vfx.resolution_time()>1.2,"Gesture precedes rule-result reveal: "+id))
			checks.append(assert_true(world.supporter_vfx.duration()>world.supporter_vfx.resolution_time()+.6,"Outcome has time to resolve: "+id))
		world.supporter_vfx.clear()
		for i: int in 2: await tree.process_frame
	world.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_boss_character_commands_before_the_committed_board_is_released() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node3D = load("res://scenes/arena3d/ArenaWorld.gd").new()
	tree.root.add_child(world)
	world.sound_enabled = false
	world.motion_enabled = true
	var renderer: Node3D = world.supporter_vfx
	renderer.manual_clock = true
	var card := _public_card(CardDatabase.get_card("CSVH1aC","023"))
	renderer.play(card)
	var checks: Array[String] = [assert_not_null(renderer.get("boss_director"),"Boss must use an authored character director, not the generic card-and-rings motif")]
	var director: Node = renderer.get("boss_director")
	if director != null:
		renderer.sample(.55)
		checks.append(assert_eq(director.hero.get_meta("source_artwork"),"res://assets/textures/vfx/trainer_boss_orders/sheet-transparent.png","The high-resolution poses preserve the actual 2D Giovanni artwork"))
		checks.append(assert_true(director.hero.texture.get_width()>=1536,"The cinematic uses high-resolution artwork"))
		checks.append(assert_true(director.hero.hframes == 3 and director.hero.vframes == 2,"All six authored character poses are available"))
		var entrance_frame: int = director.hero.frame
		renderer.sample(1.15)
		checks.append(assert_true(director.hero.frame != entrance_frame,"The hand pose changes at the command beat"))
		checks.append(assert_true(renderer.resolution_time() > 1.15,"The board cannot swap before Giovanni gives the order"))
		checks.append(assert_true(renderer.duration() > renderer.resolution_time()+.55,"Allow the actual card swap to finish before input resumes"))
		checks.append(assert_eq(director.target_slot,"opp_bench_1","Lock the selected bench slot, not an arbitrary central decoration"))
		checks.append(assert_true(renderer.covers_card("my_active"),"Cinematic hides combat labels while the character fills the board"))
		world.motion_enabled = false
		for i: int in 2: await tree.process_frame
		checks.append(assert_true(renderer.active.is_empty(),"Reduced motion cancels the cut-in"))
		checks.append(assert_eq(renderer.get_child_count(),0,"Cancellation removes character, overlay, geometry, light and audio together"))
	world.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_catalog_requires_public_supported_printings_and_exact_identity() -> String:
	var checks: Array[String]=[]
	for id: String in Catalog.ENTRIES:
		var spec: Dictionary=Catalog.ENTRIES[id]
		var data: CardData=CardDatabase.get_card(spec.printing[0],spec.printing[1])
		checks.append(assert_not_null(data,"Bundled printing exists for "+id))
		if data==null:continue
		var public_card:=_public_card(data)
		checks.append(assert_eq(Catalog.identify(public_card),id,"Exact public G/H/I/J printing resolves "+id))
		public_card.concealed=true
		checks.append(assert_eq(Catalog.identify(public_card),"","Concealed identity never triggers "+id))
		public_card.concealed=false; public_card.regulation="F"
		checks.append(assert_eq(Catalog.identify(public_card),"","Out-of-scope printing has ordinary fallback"))
	return run_checks(checks)

func test_full_collection_has_animated_geometry_sound_and_bounded_cleanup() -> String:
	var tree:=Engine.get_main_loop() as SceneTree
	var world: Node3D=load("res://scenes/arena3d/ArenaWorld.gd").new()
	tree.root.add_child(world)
	world.sound_enabled=false
	var renderer: Node3D=world.supporter_vfx
	renderer.manual_clock=true
	var checks: Array[String]=[]
	for id: String in Catalog.ENTRIES:
		var spec: Dictionary=Catalog.ENTRIES[id]
		var data: CardData=CardDatabase.get_card(spec.printing[0],spec.printing[1])
		checks.append(assert_true(renderer.play(_public_card(data),1.8),"Collection plays "+id))
		renderer.sample(.8)
		checks.append(assert_true(renderer.vertex_count>100,"Volumetric geometry renders for "+id))
		checks.append(assert_not_null(renderer.active.hero.texture,"Real local artwork resolves for "+id))
		checks.append(assert_not_null(renderer.active.audio.stream,"Original audio exists for "+id))
		checks.append(assert_false(renderer.active.audio.playing,"Muted board suppresses "+id))
		renderer.sample(1.3)
		checks.append(assert_true(world.supporter_focus>0,"Camera responds during the effect"))
		renderer.clear()
		for i: int in 2:await tree.process_frame
		checks.append(assert_eq(renderer.get_child_count(),0,"No leftover geometry, sprite, light, sound: "+id))
		checks.append(assert_eq(world.supporter_focus,0.0,"Camera resets after "+id))
	world.queue_free()
	await tree.process_frame
	return run_checks(checks)

func test_iono_real_play_queues_anonymous_hands_then_fast_mode_releases_them() -> String:
	var tree:=Engine.get_main_loop() as SceneTree
	var old: Array=[GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig:=Scenario.new()
	tree.root.add_child(rig)
	await rig.mount("dragapult",0)
	var presenter:=rig.battle.get_node("Arena3DPresenter")
	presenter.world.sound_enabled=false
	presenter.motion.fast_enabled=true
	var player: PlayerState=rig.gsm.game_state.players[0]
	var trainer:=CardInstance.create(CardDatabase.get_card("CSV3C","123"),0)
	player.deck.pop_back(); player.hand.append(trainer)
	rig.battle.call("_refresh_ui")
	var success:=rig.gsm.play_trainer(0,trainer,[])
	await tree.process_frame
	var checks: Array[String]=[
		assert_true(success,"Iono resolves through the real rule owner"),
		assert_eq(presenter.world.supporter_vfx.last_outcome.get("id"),"iono","Local trainer routes to Iono"),
		assert_true(presenter.motion.busy_time<=3.08/1.8,"Fast mode scales the authored Iono pacing"),
		assert_false(presenter.motion.hand_transfer.active,"Real hand reset waits behind the motif"),
		assert_false(presenter.motion.hand_transfer.pending.is_empty(),"Real hand movements remain queued"),
		assert_eq(player.hand.size(),6,"The true rule result is unchanged"),
	]
	var limit:=Time.get_ticks_msec()+6500
	while presenter.motion.is_busy() and Time.get_ticks_msec()<limit:await tree.process_frame
	checks.append(assert_false(presenter.motion.is_busy(),"Fast cue and hand return/draw finish without a deadlock"))
	checks.append(assert_true(presenter.world.supporter_vfx.active.is_empty(),"The renderer releases its public cue"))
	checks.append(assert_eq(presenter.world.supporter_focus,0.0,"Fast play resets camera"))
	await rig.close(); rig.free()
	GameManager.battle_3d_enabled=old[0]; GameManager.current_mode=old[1]
	GameManager.battle_effects_enabled=old[2]; GameManager.battle_layout_mode=old[3]
	return run_checks(checks)

func test_adapter_never_uses_hidden_or_unplayed_supporters() -> String:
	var state:=GameState.new()
	for pi: int in 2:
		var player:=PlayerState.new(); player.player_index=pi; state.players.append(player)
	var card:=CardInstance.create(CardDatabase.get_card("CSV3C","123"),1)
	state.players[1].hand.append(card)
	var action:=GameAction.create(GameAction.ActionType.PLAY_TRAINER,1,{"card_name":card.card_data.name},5,"")
	var checks: Array[String]=[assert_true(Cue.capture(action,state,0,{}).is_empty(),"A named card in a hidden hand is not authority to render it")]
	state.players[1].hand.clear(); state.players[1].discard_pile.append(card)
	action.data.not_played=true
	checks.append(assert_true(Cue.capture(action,state,0,{}).is_empty(),"Disrupted trainer attempts do not announce a successful effect"))
	action.data.erase("not_played")
	var public_cue:=Cue.capture(action,state,0,{})
	checks.append(assert_eq(Catalog.identify(public_cue),"iono","A committed public discarded trainer is allowed"))
	var allowed: Array=["public","concealed","card_type","regulation","name","identities","uid","image","mine","source_slot","target_slot","energy_slots"]
	for key: String in public_cue:checks.append(assert_true(key in allowed,"Only display allow-list keys leave the trusted adapter: "+key))
	return run_checks(checks)

func test_committed_character_effects_keep_real_targets_and_release_on_cancel() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var checks: Array[String] = []
	for id: String in ["turo","penny","crispin","arven"]:
		var rig := Scenario.new()
		tree.root.add_child(rig)
		await rig.mount("dragapult",0)
		var presenter := rig.battle.get_node("Arena3DPresenter")
		presenter.world.sound_enabled = false
		var player: PlayerState = rig.gsm.game_state.players[0]
		var spec: Dictionary = Catalog.ENTRIES[id]
		var trainer := CardInstance.create(CardDatabase.get_card(spec.printing[0],spec.printing[1]),0)
		player.deck.pop_back(); player.hand.append(trainer)
		var context: Dictionary = {}
		var selected: CardInstance
		var slot: PokemonSlot = player.bench[0]
		var energies_before := slot.attached_energy.size()
		if id in ["turo","penny"]:
			selected = slot.pokemon_stack.back()
			context["prof_turo_target" if id=="turo" else "penny_target"] = [slot]
		elif id == "crispin":
			var energy := CardInstance.create(rig._energy("P"),0)
			player.deck.pop_back(); player.deck.append(energy)
			context = {"csv9c196_energy_to_hand":[player.deck[0]],"csv9c196_energy_attachment":[{"source":energy,"target":slot}]}
		else:
			for data: CardData in CardDatabase.get_all_cards():
				if data.card_type=="Item":
					selected = CardInstance.create(data,0)
					player.deck.pop_back(); player.deck.append(selected)
					context = {"search_item":[selected],"search_tool":[]}
					break
		rig.battle.call("_refresh_ui")
		presenter.motion.clear(); presenter.motion.shown={}; presenter._refresh()
		var committed := rig.gsm.play_trainer(0,trainer,[context])
		await tree.process_frame
		checks.append(assert_true(committed,"Actual rule owner commits "+id))
		checks.append(assert_eq(presenter.world.supporter_vfx.last_outcome.get("id"),id,"The live presentation routes "+id))
		var director: Node = presenter.world.supporter_vfx.character_director
		checks.append(assert_not_null(director,"Character director exists for "+id))
		if director != null:
			var overlay: Control = director.cut_in
			checks.append(assert_true(overlay.get_parent()==presenter.motion,"Portrait renders above real HUD: "+id))
			if id in ["turo","penny"]:
				checks.append(assert_true(selected in player.hand,"The chosen public Pokemon returns: "+id))
				checks.append(assert_eq(director.anchors,["my_bench_0"],"Return light follows the removed card, not shifted neighbors"))
			elif id == "crispin":
				checks.append(assert_eq(slot.attached_energy.size(),energies_before+1,"The real chosen energy attaches"))
				checks.append(assert_eq(director.anchors,["my_bench_0"],"Energy light follows the actual recipient"))
			else:
				checks.append(assert_true(selected in player.hand,"Actual search result remains unchanged"))
				checks.append(assert_true(director.anchors.is_empty(),"A search never invents a selected board target"))
			presenter.world.motion_enabled = false
			for i: int in 3:await tree.process_frame
			checks.append(assert_false(is_instance_valid(overlay),"Cancellation frees the externally parented character: "+id))
			checks.append(assert_false(presenter.motion.is_busy(),"Cancellation releases input: "+id))
		await rig.close(); rig.free()
	GameManager.battle_3d_enabled=old[0]; GameManager.current_mode=old[1]
	GameManager.battle_effects_enabled=old[2]; GameManager.battle_layout_mode=old[3]
	return run_checks(checks)

func _public_card(data: CardData) -> Dictionary:
	return {"public":true,"concealed":false,"card_type":data.card_type,"regulation":data.regulation_mark,"name":data.display_name(),"identities":data.rule_identity_names(),"uid":data.get_uid(),"mine":true,"source_slot":"opp_bench_1","target_slot":"opp_active","energy_slots":[],"image":CardData.resolve_existing_image_path(CardData.get_image_candidate_paths(data.set_code,data.card_index,data.image_local_path))}

func test_return_path_tracks_the_removed_card_when_later_bench_slots_shift() -> String:
	var state:=GameState.new()
	state.turn_number=5; state.phase=GameState.GamePhase.MAIN
	for pi: int in 2:
		var player:=PlayerState.new(); player.player_index=pi
		state.players.append(player)
		for i: int in 3:
			var slot:=PokemonSlot.new()
			var pokemon:=CardInstance.create(CardDatabase.get_card("CSV1C","050"),pi)
			pokemon.face_up=true; slot.pokemon_stack.append(pokemon); player.bench.append(slot)
	var before:=preload("res://scenes/arena3d/ArenaFrame.gd").capture(state,0)
	state.players[0].bench.remove_at(0)
	var trainer:=CardInstance.create(CardDatabase.get_card("CSV6C","125"),0)
	state.players[0].discard_pile.append(trainer)
	var action:=GameAction.create(GameAction.ActionType.PLAY_TRAINER,0,{"card_name":trainer.card_data.name},5,"")
	var cue:=Cue.capture(action,state,0,before)
	return assert_eq(cue.get("source_slot"),"my_bench_0","Returning the first bench card must not aim at the last shifted slot")

func test_fast_boss_preserves_the_hold_then_releases_the_external_cut_in() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig := Scenario.new()
	tree.root.add_child(rig)
	await rig.mount("dragapult",0)
	var presenter := rig.battle.get_node("Arena3DPresenter")
	presenter.world.sound_enabled=false
	presenter.motion.fast_enabled=true
	var player: PlayerState=rig.gsm.game_state.players[0]
	var target: PokemonSlot=rig.gsm.game_state.players[1].bench[1]
	var previous_name: String=rig.gsm.game_state.players[1].active_pokemon.get_pokemon_name()
	var trainer := CardInstance.create(CardDatabase.get_card("CSVH1aC","023"),0)
	player.deck.pop_back();player.hand.append(trainer)
	rig.battle.call("_refresh_ui")
	presenter._refresh()
	var committed := rig.gsm.play_trainer(0,trainer,[{"opponent_bench_target":[target]}])
	await tree.process_frame
	var cut_in: Control=presenter.world.supporter_vfx.boss_director.cut_in
	var checks: Array[String]=[
		assert_true(committed,"The real fast Boss action commits"),
		assert_eq(presenter.motion.shown.slots.opp_active.name,previous_name,"The pre-effect board remains visible until the command resolves"),
		assert_true(cut_in.get_parent()==presenter.motion,"The character must render above board labels, in the owned presentation layer"),
		assert_true(presenter.motion.hold>.65,"Fast mode still preserves a readable character command"),
		assert_true(presenter.motion.busy_time<=3.05/1.8,"Fast mode scales the authored total duration"),
	]
	var limit:=Time.get_ticks_msec()+4000
	while presenter.motion.is_busy() and Time.get_ticks_msec()<limit:await tree.process_frame
	for i: int in 3:await tree.process_frame
	checks.append(assert_false(presenter.motion.is_busy(),"The cinematic releases the live input gate"))
	checks.append(assert_eq(presenter.motion.shown.slots.opp_active.name,target.get_pokemon_name(),"The final presented target agrees with the true rule result"))
	checks.append(assert_false(is_instance_valid(cut_in),"The externally parented cut-in is also freed"))
	checks.append(assert_eq(presenter.world.supporter_camera_offset,Vector2.ZERO,"The camera's temporary pan and shake reset"))
	await rig.close();rig.free()
	GameManager.battle_3d_enabled=old[0];GameManager.current_mode=old[1]
	GameManager.battle_effects_enabled=old[2];GameManager.battle_layout_mode=old[3]
	return run_checks(checks)

func test_committed_boss_orders_gets_a_3d_cue_and_preserves_the_real_switch() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var old := [GameManager.battle_3d_enabled,GameManager.current_mode,GameManager.battle_effects_enabled,GameManager.battle_layout_mode]
	var rig := Scenario.new()
	tree.root.add_child(rig)
	await rig.mount("dragapult",1)
	var presenter := rig.battle.get_node("Arena3DPresenter")
	presenter.world.sound_enabled = false
	var player: PlayerState = rig.gsm.game_state.players[1]
	var target: PokemonSlot = rig.gsm.game_state.players[0].bench[1]
	var card := CardInstance.create(CardDatabase.get_card("CSVH1aC","023"),1)
	player.deck.pop_back()
	player.hand.append(card)
	rig.battle.call("_refresh_ui")
	presenter._refresh()
	var played := rig.gsm.play_trainer(1,card,[{"opponent_bench_target":[target]}])
	await tree.process_frame
	var cue: Node = presenter.world.get_node_or_null("SupporterVfx")
	var checks: Array[String] = [assert_true(played,"A real successful Boss play commits"),assert_eq(rig.gsm.game_state.players[0].active_pokemon,target,"Rules perform the selected switch"),assert_not_null(cue,"The committed supporter must produce a dedicated 3D presentation")]
	if cue != null:
		presenter._refresh()
		checks.append(assert_false(presenter.stadium_button.visible,"The empty-stadium button cannot cover the public supporter card"))
		if "--capture-live-supporter" in OS.get_cmdline_user_args():
			await tree.create_timer(.7).timeout
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png("res://.tmp/arena-supporters-20260929/live-boss.png")
		checks.append(assert_eq(cue.last_outcome.get("id"),"boss","Real Boss action reaches the new renderer"))
		checks.append(assert_eq(cue.last_outcome.get("source_slot"),"my_bench_1","The pull starts at the actual previous public bench slot"))
		checks.append(assert_eq(cue.last_outcome.get("target_slot"),"my_active","The pull ends at the committed active slot"))
		checks.append(assert_true(presenter.motion.is_busy(),"Input waits for the visual outcome"))
		presenter.world.motion_enabled = false
		for i: int in 3: await tree.process_frame
		checks.append(assert_eq(cue.get_child_count(),0,"Reduced motion removes every temporary effect"))
		checks.append(assert_false(presenter.motion.is_busy(),"Reduced motion releases the input gate"))
		presenter._refresh()
		checks.append(assert_true(presenter.stadium_button.visible,"Cancelling restores the normal stadium entry"))
	await rig.close()
	rig.free()
	GameManager.battle_3d_enabled=old[0]; GameManager.current_mode=old[1]
	GameManager.battle_effects_enabled=old[2]; GameManager.battle_layout_mode=old[3]
	return run_checks(checks)
