extends SceneTree
## Explicit layout fixture; this does not claim natural game play.
var battle: Control
var measurements: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gm = root.get_node("GameManager")
	gm.current_mode = gm.GameMode.TWO_PLAYER
	gm.selected_deck_ids.assign([575720,575720])
	gm.first_player_choice = 0
	battle = load("res://scenes/battle/BattleScene.tscn").instantiate()
	root.add_child(battle)
	current_scene = battle
	await create_timer(1).timeout
	var gs: GameState = battle.get("_gsm").game_state
	gs.phase = GameState.GamePhase.MAIN
	gs.turn_number = 4
	gs.current_player_index = 0
	battle.set("_pending_choice", "")
	battle.get("_dialog_overlay").hide()
	var samples: Array[CardData] = []
	for card: CardInstance in gs.players[0].deck + gs.players[0].hand:
		if card.card_data.is_basic_pokemon(): samples.append(card.card_data)
	for pi in range(2):
		gs.players[pi].bench.clear()
		for i in range(9):
			var slot := PokemonSlot.new()
			var ci := CardInstance.create(samples[i % samples.size()],pi)
			ci.face_up = true
			slot.pokemon_stack.append(ci)
			if i == 0: gs.players[pi].active_pokemon = slot
			else: gs.players[pi].bench.append(slot)
	var presenter = battle.get_node("Arena3DPresenter")
	for id in ["grove"]:
		presenter.theme_id = id
		presenter.world.set_theme(id)
		presenter._apply_theme()
		for resolution in [Vector2i(1280,720),Vector2i(1440,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
			root.size = resolution
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_size = resolution
			for count in [1,7,12,20,30]:
				gs.players[0].hand.clear()
				for i in range(count): gs.players[0].hand.append(CardInstance.create(samples[i%samples.size()],0))
				battle.call("_refresh_ui")
				await create_timer(.25).timeout
				presenter._refresh()
				await process_frame
				assert(presenter.world.cards.has("my_bench_7"))
				for slot_id in ["my_active","opp_active","my_bench_7","opp_bench_7"]:
					var point: Vector2 = presenter.world.camera.unproject_position(presenter.world.cards[slot_id].node.position)
					assert(presenter.world.hit_slot(point)==slot_id,"Visible expanded bench must pick correctly")
				var hand_container: Control = battle.get("_hand_container")
				assert(hand_container.get_child_count() >= count, "All hand cards retained")
				if count == 30:
					var scroll: ScrollContainer = battle.get("_hand_scroll")
					var point := scroll.get_global_rect().get_center()
					for tick in range(24):
						var wheel := InputEventMouseButton.new()
						wheel.position = point
						wheel.global_position = point
						wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
						wheel.pressed = true
						root.push_input(wheel,true)
						await process_frame
					assert(scroll.scroll_horizontal > 0,"Actual mouse wheel reaches large hand")
				if count in [12,20]:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("user://ac-%s-%dx%d-hand%d.png" % [id,resolution.x,resolution.y,count])
			print("ARENA_LAYOUT_PASS ",id," ",resolution," hand=1,7,12,20,30 bench=8")
			var samples_us: Array[int] = []
			var previous := Time.get_ticks_usec()
			for frame in range(120):
				await process_frame
				var now := Time.get_ticks_usec()
				samples_us.append(now-previous)
				previous = now
			measurements.append({"theme":id,"resolution":[resolution.x,resolution.y],"frame_us":samples_us,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"fixture":true,"hand":30,"bench_per_side":8})
	var report := FileAccess.open("user://ac-render-samples.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(measurements,"  "))
	report.close()
	print("ARENA_AC_LAYOUT_FIXTURE_PASS")
	battle.call("_release_battle_runtime_resources")
	battle.queue_free()
	await process_frame
	quit()
