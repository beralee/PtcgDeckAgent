class_name TestOpponentTalk
extends TestBase
const Director := preload("res://scripts/commentary/OpponentTalkDirector.gd")
const Voice := preload("res://scripts/commentary/OpponentTalkVoice.gd")
const Session := preload("res://scripts/commentary/OpponentTalkSession.gd")
const OldTests := preload("res://tests/test_battle_commentary.gd")

func _event(type: String, turn: int = 4, player: int = 1, extra: Dictionary = {}) -> Dictionary:
	var event := {"type": type, "turn": turn, "player": player}
	event.merge(extra)
	return event

func _state(turn: int = 4, p0: int = 6, p1: int = 6, winner: int = -1) -> Dictionary:
	return {"turn": turn, "phase": "MAIN" if winner == -1 else "GAME_OVER", "players": [{"prizes_remaining": p0}, {"prizes_remaining": p1}], "winner": winner}

func _session(model: RefCounted, parent: Node, personality: String = "逗比臭牌篓子") -> RefCounted:
	var session := Session.new()
	session.start(parent, {"api_key": "OFFLINE_ONLY", "ai_personality": personality}, model)
	return session

func test_opponent_has_a_display_only_personality_director() -> String:
	return assert_true(ResourceLoader.exists("res://scripts/commentary/OpponentTalkDirector.gd"), "Opponent reactions need a grounded, display-only personality director")

func test_only_committed_own_moves_get_shouts_not_player_or_setup_moves() -> String:
	var director := Director.new()
	assert_true(director.action(_event("EVOLVE", 4, 0, {"evolution": "玛俐的长毛巨魔ex"})).is_empty())
	assert_true(director.action(_event("PLAY_POKEMON", 0, 1)).is_empty())
	var cue := director.action(_event("EVOLVE", 4, 1, {"evolution": "多龙巴鲁托ex"}))
	assert_eq(cue.trigger, "ace_arrival")
	assert_eq(cue.subject, "多龙巴鲁托ex")
	assert_true(director.action(_event("EVOLVE", 6, 1, {"evolution": "多龙巴鲁托ex"})).is_empty(), "Same ace does not keep re-introducing itself")
	cue = director.action(_event("ATTACK", 6, 1, {"attack_name": "幻影潜袭"}))
	assert_eq(cue.trigger, "attack_call")
	assert_eq(cue.prizes_taken, 0, "Declaration is not a prize result")
	return ""

func test_stall_excludes_opening_and_public_development_then_recovers() -> String:
	var director := Director.new()
	assert_true(director.action(_event("TURN_END", 2)).is_empty())
	director.action(_event("EVOLVE", 4, 1, {"evolution": "多龙奇"}))
	assert_true(director.action(_event("TURN_END", 4)).is_empty(), "Developing is not stalled")
	assert_eq(director.action(_event("TURN_END", 6)).trigger, "stalled")
	assert_eq(director.action(_event("ATTACK", 8, 1, {"attack_name": "幻影潜袭"})).trigger, "recovery")
	assert_true(director.action(_event("TURN_END", 8)).is_empty())
	return ""

func test_actual_prizes_and_terminal_override_and_no_duplicate_victory() -> String:
	var director := Director.new()
	director.settled(_state())
	director.action(_event("ATTACK", 4, 1, {"attack_name": "幻影潜袭"}))
	assert_true(director.settled(_state()).is_empty(), "No celebrating before actual prize transfer")
	var cue := director.settled(_state(4, 6, 4))
	assert_eq(cue.trigger, "prize_burst")
	assert_eq(cue.prizes_taken, 2)
	assert_true(director.settled(_state(4, 6, 4)).is_empty())
	assert_eq(director.settled(_state(5, 5, 4)).trigger, "setback")
	assert_eq(director.settled(_state(8, 5, 0, 1)).trigger, "victory", "One ending instead of both prize boast and ending")
	assert_true(director.settled(_state(8, 5, 0, 1)).is_empty())
	assert_true(director.action(_event("ATTACK", 8, 1, {"attack_name": "幻影潜袭"})).is_empty())
	assert_eq(Director.new().settled(_state(8, 0, 5, 0)).trigger, "defeat")
	return ""

func test_personalities_share_fact_slots_but_change_style_and_do_not_use_rng() -> String:
	seed(59217)
	var expected := randi()
	seed(59217)
	var cue := {"trigger": "ace_arrival", "subject": "喷火龙ex", "prizes_taken": 0}
	var calm := Voice.render(Voice.local_bank("冷静克制"), cue, 0)
	var fiery := Voice.render(Voice.local_bank("中二热血"), cue, 0)
	assert_true(calm.contains("喷火龙ex") and fiery.contains("喷火龙ex"))
	assert_true(fiery.contains("就决定是你了"))
	assert_true(calm != fiery)
	assert_eq(randi(), expected, "Personality selection must never advance gameplay RNG")
	for personality: String in ["冷静", "中二", "逗比"]:
		assert_true(Voice.valid_bank({"lines": Voice.local_bank(personality)}), personality)
	return ""

func test_agent_roleplay_samples_and_mechanical_rejections() -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_talk_model_simulation.json"))
	for item: Dictionary in fixture.cases:
		var accepted: bool = Voice.safe_text(item.text) and (item.trigger != "prize_burst" or int(item.prizes_taken) >= 2)
		assert_eq(accepted, bool(item.expected_valid), item.id)
	# This is a format/privacy check, not proof of semantic correctness.
	var bank := {"lines": Voice.local_bank("逗比")}
	bank.lines["attack_call/focused"][0] = "我先收两张奖赏，{subject}，直接赢了！"
	assert_false(Voice.valid_bank(bank))
	bank = {"lines": Voice.local_bank("逗比")}
	bank.lines["ace_arrival/confident"][0] = "我的{hidden_hand}和{subject}都已经就位。"
	assert_false(Voice.valid_bank(bank))
	bank = {"lines": Voice.local_bank("逗比")}
	bank.lines.unknown = ["多余字段", "多余字段"]
	assert_false(Voice.valid_bank(bank))
	assert_eq(Voice.render(Voice.local_bank("逗比"), {"trigger": "prize_burst", "prizes_taken": 0}, 0), "")
	return ""

func test_model_prepares_bank_only_public_knowledge_and_reply_never_speaks_stale_actions() -> String:
	var parent := Node.new()
	var model := OldTests.ModelDouble.new()
	var session := _session(model, parent, "自定义的冷静侦探")
	var packet := OldTests.new()._packet()
	session.prepare(packet.knowledge, 100)
	assert_eq(model.requests.size(), 1)
	assert_true(model.requests[0].messages[1].content.contains("自定义的冷静侦探"))
	assert_false(JSON.stringify(model.requests).contains("SECRET"))
	assert_false(JSON.stringify(model.requests).contains("hand_count"))
	session.prepare(packet.knowledge, 110)
	assert_eq(model.requests.size(), 1, "Single flight")
	var roleplay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_emotion_bank_simulation.json"))
	assert_true(Voice.valid_bank(roleplay), "Sub-agent plays DeepSeek without a paid request")
	model.reply(0, roleplay)
	assert_true(session.model_ready)
	assert_eq(session.history.size(), 0, "Reply only prepares future lines")
	session.prepare(packet.knowledge, 140)
	assert_eq(model.requests.size(), 1, "Same public knowledge reuses bank")
	var cue := Director.new().action(_event("ATTACK", 6, 1, {"attack_name": "幻影潜袭"}))
	session.offer(cue, 150)
	assert_true(session.history.back().text.contains("幻影潜袭"))
	assert_eq(session.history.back().source, "model_bank")
	session.stop()
	model.reply(0, {"lines": Voice.local_bank("逗比")})
	assert_eq(session.history.size(), 1, "Late response cannot reopen a muted session")
	assert_true(model.canceled)
	parent.free()
	return ""

func test_throttling_expires_result_queue_and_terminal_wins() -> String:
	var parent := Node.new()
	var session := _session(OldTests.ModelDouble.new(), parent)
	var director := Director.new()
	session.offer(director.settled(_state()), 100)
	session.offer(director.action(_event("ATTACK", 4, 1, {"attack_name": "幻影潜袭"})), 101)
	assert_eq(session.history.size(), 1, "Do not babble every action")
	session.offer(director.settled(_state(4, 6, 4)), 101.5)
	assert_false(session.pending.is_empty())
	session.new_action()
	session.tick(103)
	assert_eq(session.history.size(), 1, "New action invalidates queued reaction")
	session.offer(director.settled(_state(6, 6, 2)), 104)
	assert_eq(session.history.size(), 2)
	session.offer(director.settled(_state(8, 6, 0, 1)), 104.2)
	assert_eq(session.history.back().trigger, "victory")
	assert_true(session.terminal)
	assert_true(session.client.canceled)
	session.stop()
	parent.free()
	return ""

func test_no_key_no_network_but_local_personality_and_failure_budget() -> String:
	var parent := Node.new()
	var model := OldTests.ModelDouble.new()
	var session := Session.new()
	session.start(parent, {"ai_personality": "中二热血"}, model)
	session.prepare({}, 100)
	session.offer(Director.new().settled(_state()), 100)
	assert_eq(model.requests.size(), 0)
	assert_true(session.history.back().text.contains("斗志"))
	session.stop()
	session = _session(model, parent)
	for i in 2:
		session.prepare({}, 100 + i * 40)
		model.callbacks[i].call({"ok": false})
	assert_true(session.charged_tokens > 0, "Unknown usage remains reserved")
	session.prepare({}, 200)
	assert_eq(model.requests.size(), 2, "Repeated errors stop further requests")
	session.calls = Session.MAX_CALLS
	session.failures = 0
	session.prepare({}, 250)
	assert_eq(model.requests.size(), 2)
	session.stop()
	parent.free()
	return ""
