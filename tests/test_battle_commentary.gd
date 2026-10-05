class_name TestBattleCommentary
extends TestBase
const Projector := preload("res://scripts/commentary/CommentaryPublicProjector.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const Session := preload("res://scripts/commentary/BattleCommentarySession.gd")
const Prompt := preload("res://scripts/commentary/CommentaryPrompt.gd")
const Client := preload("res://scripts/commentary/CommentaryDeepSeekClient.gd")
const Preferences := preload("res://scripts/commentary/CommentaryPreferences.gd")
const Controller := preload("res://scripts/commentary/BattleCommentaryController.gd")
const PanelScript := preload("res://scripts/commentary/CommentaryPanel.gd")

class ModelDouble extends RefCounted:
	var requests: Array = []
	var callbacks: Array[Callable] = []
	var canceled := false
	func request_json(_owner: Node, _endpoint: String, _key: String, payload: Dictionary, callback: Callable) -> int:
		requests.append(payload.duplicate(true))
		callbacks.append(callback)
		return OK
	func cancel_pending_requests() -> void:
		canceled = true
	func reply(index: int, content: Dictionary, tokens: int = 400) -> void:
		callbacks[index].call({"ok": true, "content": content, "tokens": tokens})

class LoopbackClient extends Client:
	var loopback := ""
	func is_official_deepseek_endpoint(endpoint: String) -> bool:
		return endpoint == loopback or super.is_official_deepseek_endpoint(endpoint)

func _card(label: String, uid: String = "PUBLIC") -> CardInstance:
	var cd := CardData.new()
	cd.name = label
	cd.set_code = uid
	cd.card_index = "001"
	cd.hp = 200
	return CardInstance.create(cd, 0)

func _state() -> GameState:
	var state := GameState.new()
	state.turn_number = 1
	state.phase = GameState.GamePhase.MAIN
	for seat in range(2):
		var player := PlayerState.new()
		player.player_index = seat
		player.hand.append(_card("SECRET_HAND_%d" % seat))
		player.deck.append(_card("SECRET_DECK_%d" % seat))
		player.prizes.append(_card("SECRET_PRIZE_%d" % seat))
		var slot := PokemonSlot.new()
		slot.pokemon_stack.append(_card("公开宝可梦%d" % seat, "PUBLIC%d" % seat))
		slot.damage_counters = 30
		player.active_pokemon = slot
		state.players.append(player)
	return state

func _packet(id: int = 1) -> Dictionary:
	var state := Projector.snapshot(_state())
	return {"snapshot_id": id, "state": state, "before": {}, "events": [{"id": id, "type": "ATTACK", "player": 0, "turn": 1}], "knowledge": Knowledge.new().observe(state)}

func _plans(id: int) -> Dictionary:
	return {"snapshot_id": id, "plans": [{"seat": 0, "opening": "先观察公开进化组件。", "prize_plan": "按已知攻击费用判断接力。", "risk": "完整变体尚未确定。"}, {"seat": 1, "opening": "保护场上攻击手。", "prize_plan": "观察单奖与双奖交换。", "risk": "附能路线尚待公开。"}]}

func _comment(id: int) -> Dictionary:
	return {"snapshot_id": id, "text": "这一轮需要关注后续攻击手的接力，场上能量分配会影响下一回合的进攻节奏。", "kind": "analysis", "evidence_ids": [id]}

func _session(model: RefCounted, parent: Node) -> RefCounted:
	var session := Session.new()
	session.start(parent, {"api_key": "TEST_ONLY_NOT_A_REAL_KEY", "endpoint": "https://api.deepseek.com", "model": "deepseek-v4-flash"}, model)
	return session

func test_text_commentary_has_an_independent_public_owner() -> String:
	return assert_true(ResourceLoader.exists("res://scripts/commentary/BattleCommentarySession.gd"), "Text commentary needs an independent, display-only session")

func test_public_projection_excludes_both_hands_decks_prizes_and_private_flags() -> String:
	var state := _state()
	state.shared_turn_flags["secret_rng"] = "PRIVATE_RNG"
	var public := Projector.snapshot(state)
	var serialized := JSON.stringify(public)
	return run_checks([
		assert_false(serialized.contains("SECRET"), "No hidden card identity from either seat"),
		assert_false(serialized.contains("PRIVATE_RNG"), "No mutable flags or RNG"),
		assert_eq(public.players[0].hand_count, 1),
		assert_eq(public.players[0].active.hp, 170),
		assert_true(serialized.contains("公开宝可梦")),
	])

func test_setup_cards_stay_concealed_even_with_face_up_flag() -> String:
	var state := _state()
	state.phase = GameState.GamePhase.SETUP_PLACE
	state.players[0].active_pokemon.get_top_card().face_up = true
	return assert_false(JSON.stringify(Projector.snapshot(state)).contains("公开宝可梦"), "Setup is concealed by phase, not mutable flags")

func test_draw_and_prize_action_payloads_are_not_public() -> String:
	for kind in [GameAction.ActionType.DRAW_CARD, GameAction.ActionType.TAKE_PRIZE, GameAction.ActionType.PUBLIC_REVEAL]:
		var action := GameAction.create(kind, 0, {"card_names": ["SECRET"], "count": 1, "nested": {"search_begin_input": "SECRET"}}, 3, "SECRET")
		assert_false(JSON.stringify(Projector.event(action, 4)).contains("SECRET"))
	return ""

func test_every_actual_bundled_deck_has_authored_mechanism_briefs() -> String:
	var library := Knowledge.new()
	var actual := 0
	for file: String in DirAccess.get_files_at("res://data/bundled_user/decks"):
		if not file.ends_with(".json"): continue
		actual += 1
		var deck: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bundled_user/decks/" + file))
		var ids: Array = library.catalog.deck_coverage.get(str(int(deck.id)), [])
		assert_false(ids.is_empty(), "Missing prepared deck: " + file)
		for id: String in ids:
			var profile: Dictionary = library.catalog.profiles[id]
			for key: String in ["opening", "engine", "prizes", "sustain", "risks"]:
				assert_true(str(profile.get(key, "")).length() >= 10, file + " " + key)
			var anchored := false
			for entry: Dictionary in deck.cards:
				if "%s_%s" % [entry.set_code, entry.card_index] in profile.printings: anchored = true
			assert_true(anchored, "Printing must exist in actual deck: " + file + "/" + id)
	assert_eq(actual, library.catalog.deck_coverage.size(), "No stale coverage records")
	return ""

func test_knowledge_uses_public_printings_not_selected_deck_or_names_alone() -> String:
	var state := Projector.snapshot(_state())
	state.players[0].active.evolution = ["CSV10C_148"]
	var knowledge := Knowledge.new()
	var brief: Dictionary = knowledge.observe(state)
	assert_true(JSON.stringify(brief.seats[0]).contains("marnie"))
	assert_false(JSON.stringify(brief.seats[1]).contains("marnie"))
	state.players[0].active.evolution = ["UNKNOWN_SAME_NAME"]
	var unknown: Dictionary = Knowledge.new().observe(state)
	assert_true(unknown.seats[0].profiles.is_empty(), "Unknown printing must be prepared from its own card text")
	return ""

func test_disabled_2d_review_and_headless_are_ineligible() -> String:
	return run_checks([
		assert_false(Preferences.eligible(false, true, false, false)),
		assert_false(Preferences.eligible(true, false, false, false)),
		assert_false(Preferences.eligible(true, true, true, false)),
		assert_false(Preferences.eligible(true, true, false, true)),
		assert_true(Preferences.eligible(true, true, false, false)),
	])

func test_preparation_must_complete_before_commentary_single_flight() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	session.offer(_packet())
	session.tick(100)
	session.tick(101)
	assert_eq(model.requests.size(), 1, "One in-flight request")
	assert_true(model.requests[0].messages[1].content.contains('"mode":"prepare"'))
	model.reply(0, _plans(1))
	assert_eq(session.prepared_signature, "[[],[]]")
	session.tick(110)
	assert_eq(model.requests.size(), 2)
	assert_true(model.requests[1].messages[1].content.contains('"mode":"commentary"'))
	model.reply(1, _comment(1))
	assert_eq(session.history.back().source, "AI 解说")
	assert_eq(session.charged_tokens, 800)
	session.stop()
	parent.free()
	return ""

func test_new_evidence_requires_fresh_deck_preparation() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	session.offer(_packet())
	session.tick(100)
	model.reply(0, _plans(1))
	var next := _packet(2)
	next.knowledge.seats[0].profiles = [{"id": "dragapult"}]
	session.offer(next)
	session.tick(110)
	assert_true(model.requests.back().messages[1].content.contains('"mode":"prepare"'))
	session.stop()
	parent.free()
	return ""

func test_stale_cancel_and_budget_prevent_publication_or_new_requests() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	session.offer(_packet())
	session.tick(100)
	model.reply(0, _plans(1))
	session.tick(110)
	session.offer(_packet(2))
	var count: int = session.history.size()
	model.reply(1, _comment(1))
	assert_eq(session.history.size(), count, "Old board result dropped")
	session.stop()
	model.reply(1, _comment(1))
	assert_true(model.canceled)
	assert_eq(session.history.size(), count, "Late callback cannot resurrect closed commentary")
	session.tick(120)
	assert_eq(model.requests.size(), 2)
	var limited := _session(ModelDouble.new(), parent)
	limited.calls = Session.MAX_CALLS
	limited.offer(_packet())
	limited.tick(200)
	assert_eq(limited.client.requests.size(), 0)
	limited.stop()
	parent.free()
	return ""

func test_unknown_usage_remains_charged_and_failure_breaker_stops() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	for i in range(3):
		session.offer(_packet(i + 1))
		session.tick(100 + i * 10)
		model.callbacks[i].call({"ok": false})
	assert_true(session.charged_tokens > 0)
	session.offer(_packet(4))
	session.tick(150)
	assert_eq(model.requests.size(), 3)
	session.stop()
	parent.free()
	return ""

func test_response_format_evidence_and_private_claim_guards() -> String:
	var packet := _packet()
	assert_true(Prompt.valid_comment(_comment(1), packet))
	var content := _comment(2)
	assert_false(Prompt.valid_comment(content, packet))
	content = _comment(1)
	content.evidence_ids = [999]
	assert_false(Prompt.valid_comment(content, packet))
	content.evidence_ids = [1]
	content.text = "对手手里有老板的指令，所以接下来这一回合一定能够击倒这只宝可梦。"
	assert_false(Prompt.valid_comment(content, packet))
	assert_false(Prompt.valid_plans({"snapshot_id": 1, "plans": []}, 1))
	return ""

func test_transport_usage_is_outside_model_content_and_no_unsafe_fallback() -> String:
	var client := Client.new()
	var response := {"choices": [{"finish_reason": "stop", "message": {"content": JSON.stringify({"tokens": 0, "status": "ok", "text": "test"})}}], "usage": {"prompt_tokens": 450, "completion_tokens": 90}}
	var parsed: Dictionary = client._parse_chat_response(200, JSON.stringify(response))
	assert_eq(parsed.tokens, 540)
	assert_eq(parsed.content.tokens, 0)
	assert_false(client._allow_unsafe_tls)
	assert_false(client._allow_python_fallback)
	response.choices[0].finish_reason = "length"
	assert_false(client._parse_chat_response(200, JSON.stringify(response)).ok)
	assert_false(client._parse_chat_response(200, "{broken").ok)
	assert_false(client.is_official_deepseek_endpoint("https://example.com"))
	return ""

func test_requests_do_not_consume_gameplay_rng() -> String:
	seed(44123)
	var expected := randi()
	seed(44123)
	var parent := Node.new()
	var session := _session(ModelDouble.new(), parent)
	session.offer(_packet())
	session.tick(100)
	var actual := randi()
	session.stop()
	parent.free()
	return assert_eq(actual, expected, "Commentary assembly and dispatch must not advance game RNG")

func test_new_action_rejects_old_result_before_next_stable_snapshot() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	session.offer(_packet())
	session.tick(100)
	model.reply(0, _plans(1))
	session.tick(110)
	var history_count: int = session.history.size()
	session.mark_unsettled()
	model.reply(1, _comment(1))
	assert_eq(session.history.size(), history_count)
	session.tick(120)
	assert_eq(model.requests.size(), 2, "Never request commentary on an unresolved action")
	session.stop()
	parent.free()
	return ""

func test_merged_events_keep_earliest_before_and_disabled_service_keeps_public_updates() -> String:
	var parent := Node.new()
	var model := ModelDouble.new()
	var session := _session(model, parent)
	var first := _packet()
	first.before = {"turn": 0}
	session.offer(first)
	session.mark_unsettled()
	var second := _packet(2)
	second.before = {"turn": 1}
	second.state.turn = 2
	session.offer(second)
	assert_eq(session.pending.before.turn, 0)
	assert_eq(session.pending.events.size(), 2)
	session.failures = 3
	session.tick(100)
	assert_true(session.history.back().text.contains("第 2 回合"))
	var third := _packet(3)
	third.state.turn = 3
	session.offer(third)
	assert_true(session.history.back().text.contains("第 3 回合"))
	assert_eq(model.requests.size(), 0)
	session.stop()
	parent.free()
	return ""

func test_damage_units_and_unsuccessful_trainer_attempt_are_explicit() -> String:
	var state := Projector.snapshot(_state())
	assert_eq(state.players[0].active.damage_points, 30)
	assert_eq(state.players[0].active.damage_counter_count, 3)
	var action := GameAction.create(GameAction.ActionType.PLAY_TRAINER, 0, {"card_name": "高级球", "not_played": true}, 1)
	assert_eq(Projector.event(action, 1).type, "TRAINER_NOT_PLAYED")
	return ""

func test_same_name_different_mechanisms_do_not_share_profiles() -> String:
	var library := Knowledge.new()
	assert_false("CSVH4C_024" in library.catalog.profiles.miraidon.printings, "Dragon Miraidon lacks Tandem Unit")
	assert_false("30thC_095" in library.catalog.profiles.snorlax.printings, "Non-Block Snorlax is not a retreat lock")
	assert_false("CS6bC_113" in library.catalog.profiles.snorlax.printings)
	return ""

func test_sub_agent_model_fixtures_pass_and_mechanical_errors_are_rejected() -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/commentary_model_simulation.json"))
	assert_true(Prompt.valid_plans(fixture.preparation, int(fixture.preparation.snapshot_id)))
	var exercised := 0
	for item: Dictionary in fixture.cases:
		var context: Dictionary = item.public_context
		var validation := str(context.get("validation", ""))
		# Semantic adversarial samples are explicitly MANUAL quality review.
		# No test claims JSON/evidence validation proves all card reasoning.
		if validation == "semantic_review": continue
		if context.has("raw_response"):
			var envelope := {"choices": [{"finish_reason": "stop", "message": {"content": context.raw_response}}]}
			assert_false(Client.new()._parse_chat_response(200, JSON.stringify(envelope)).ok, item.id)
		else:
			var packet := _packet(int(context.get("current_snapshot_id", context.get("snapshot_id", 0))))
			packet.events.clear()
			for id: int in context.get("evidence_ids", []): packet.events.append({"id": id})
			assert_eq(Prompt.valid_comment(item.response, packet), bool(item.should_accept), item.id)
		exercised += 1
	assert_true(exercised >= 14, "Exercise positives and mechanical adversarial cases")
	return ""

func test_real_http_transport_with_local_model_double_only() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var parent := Node.new()
	tree.root.add_child(parent)
	var server := TCPServer.new()
	var port := 18739
	while port < 18749 and server.listen(port, "127.0.0.1") != OK: port += 1
	if port == 18749:
		parent.free()
		return assert_true(false, "No loopback port available for offline transport test")
	var client := LoopbackClient.new()
	client.loopback = "http://127.0.0.1:%d" % port
	client.clear_proxy()
	var replies: Array = []
	var payload := Prompt.payload(_packet(), "commentary", [], "offline-commentator")
	var error: int = client.request_json(parent, client.loopback, "OFFLINE_TEST_KEY", payload, func(reply: Dictionary): replies.append(reply))
	assert_eq(error, OK)
	var peer: StreamPeerTCP
	var request := ""
	var replied := false
	var deadline := Time.get_ticks_msec() + 5000
	while replies.is_empty() and Time.get_ticks_msec() < deadline:
		if peer == null and server.is_connection_available(): peer = server.take_connection()
		if peer != null:
			peer.poll()
			if peer.get_available_bytes() > 0: request += peer.get_utf8_string(peer.get_available_bytes())
			var split := request.find("\r\n\r\n")
			if split >= 0 and not replied:
				var length := 0
				for header: String in request.left(split).split("\r\n"):
					if header.to_lower().begins_with("content-length:"): length = int(header.get_slice(":", 1).strip_edges())
				if request.substr(split + 4).to_utf8_buffer().size() >= length:
					var body := JSON.stringify({"choices": [{"finish_reason": "stop", "message": {"content": JSON.stringify(_comment(1))}}], "usage": {"prompt_tokens": 100, "completion_tokens": 50}})
					var wire := "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.to_utf8_buffer().size(), body]
					peer.put_data(wire.to_utf8_buffer())
					replied = true
		await tree.process_frame
	assert_false(replies.is_empty(), "Real HTTPRequest should receive local fixture")
	if not replies.is_empty():
		assert_true(bool(replies[0].get("ok", false)))
		assert_eq(replies[0].tokens, 150)
		assert_true(Prompt.valid_comment(replies[0].content, _packet()))
	assert_true(request.begins_with("POST /chat/completions "))
	assert_false(request.contains("SECRET"), "Actual wire excludes private cards")
	assert_true(request.contains('"json_object"'))
	assert_true(request.contains('"disabled"'))
	client.cancel_pending_requests()
	if peer != null: peer.disconnect_from_host()
	server.stop()
	parent.queue_free()
	await tree.process_frame
	return ""
