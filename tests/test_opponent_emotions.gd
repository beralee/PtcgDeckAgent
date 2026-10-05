class_name TestOpponentEmotions
extends TestBase
const Mood := preload("res://scripts/commentary/OpponentMood.gd")
const Director := preload("res://scripts/commentary/OpponentTalkDirector.gd")
const Voice := preload("res://scripts/commentary/OpponentTalkVoice.gd")
const Session := preload("res://scripts/commentary/OpponentTalkSession.gd")
const Helper := preload("res://tests/test_opponent_talk.gd")
const Bubble := preload("res://scripts/commentary/OpponentTalkBubble.gd")

func test_every_expression_has_a_canonical_mood_and_portrait() -> String:
	return assert_true(ResourceLoader.exists("res://scripts/commentary/OpponentMood.gd"), "Every opponent utterance needs one canonical mood and matching portrait")

func test_all_twelve_portraits_have_unique_regions_and_safe_alpha_padding() -> String:
	assert_eq(Mood.IDS.size(), 12)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/opponent_emotions/manifest.json"))
	assert_eq(manifest.order, Mood.IDS, "Exportable pack and runtime share atlas order")
	var signatures := {}
	for id: String in Mood.IDS:
		assert_eq(str(manifest.labels[Mood.IDS.find(id)]), str(Mood.entry(id).label), id)
		var texture := Mood.portrait(id)
		assert_true(texture.atlas != null, id)
		var image := texture.get_image()
		assert_eq(image.get_size(), Vector2i(256, 256), id)
		var visible := image.get_used_rect()
		assert_true(visible.position.x >= 8 and visible.position.y >= 8, id + " top/left alpha padding")
		assert_true(visible.end.x <= 248 and visible.end.y <= 248, id + " bottom/right alpha padding")
		signatures[image.get_data().hex_encode().sha256_text()] = true
	assert_eq(signatures.size(), 12, "Distinct expressions, not twelve names for one image")
	return ""

func test_emotion_changes_with_pressure_progress_and_consecutive_stalls() -> String:
	var helper := Helper.new()
	var director := Director.new()
	assert_eq(director.settled(helper._state()).mood_id, "eager")
	assert_eq(director.action(helper._event("TURN_END", 4)).mood_id, "confused")
	assert_eq(director.action(helper._event("TURN_END", 6)).mood_id, "frustrated")
	assert_eq(director.action(helper._event("ATTACK", 8, 1, {"attack_name": "幻影潜袭"})).mood_id, "relieved")
	assert_eq(director.action(helper._event("ATTACK", 10, 1, {"attack_name": "幻影潜袭"})).mood_id, "focused")
	assert_eq(director.action(helper._event("EVOLVE", 12, 1, {"evolution": "多龙巴鲁托ex"})).mood_id, "confident")
	director.settled(helper._state(12, 1, 5))
	assert_eq(director.action(helper._event("ATTACK", 14, 1, {"attack_name": "幻影潜袭"})).mood_id, "anxious")
	assert_eq(director.action(helper._event("TURN_END", 16)).mood_id, "anxious")
	assert_eq(director.action(helper._event("ATTACK", 18, 1, {"attack_name": "幻影潜袭"})).mood_id, "determined")
	return ""

func test_same_prize_gain_is_proud_when_even_and_relief_when_behind() -> String:
	var helper := Helper.new()
	var even := Director.new()
	even.settled(helper._state())
	assert_eq(even.settled(helper._state(6, 6, 4)).mood_id, "proud")
	var behind := Director.new()
	behind.settled(helper._state(4, 2, 6))
	var cue := behind.settled(helper._state(6, 2, 4))
	assert_eq(cue.mood_id, "relieved")
	assert_eq(cue.prizes_taken, 2)
	var text := Voice.render(Voice.local_bank("逗比"), cue, 0)
	assert_true(text.contains("喘口气"), "Wording matches relief instead of smug portrait")
	return ""

func test_loss_size_and_confirmed_endings_have_appropriate_moods() -> String:
	var helper := Helper.new()
	var director := Director.new()
	director.settled(helper._state())
	assert_eq(director.settled(helper._state(5, 4, 6)).mood_id, "surprised")
	assert_eq(director.settled(helper._state(7, 3, 6)).mood_id, "determined")
	assert_eq(director.settled(helper._state(9, 0, 6, 0)).mood_id, "respectful")
	assert_eq(Director.new().settled(helper._state(9, 6, 0, 1)).mood_id, "joyful")
	return ""

func test_schema_pairs_mood_with_trigger_and_local_or_mock_wording() -> String:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_emotion_bank_simulation.json"))
	assert_true(Voice.valid_bank(fixture))
	for personality: String in ["逗比", "冷静", "中二"]:
		var bank := Voice.local_bank(personality)
		assert_true(Voice.valid_bank({"lines": bank}), personality)
		for key: String in Mood.LINE_KEYS:
			var cue := Mood.bind({"trigger": key.get_slice("/", 0), "mood_id": key.get_slice("/", 1), "subject": "幻影潜袭", "prizes_taken": 2})
			assert_eq(Mood.line_key(cue), key)
			assert_false(Voice.render(bank, cue, 0).is_empty(), key)
			assert_false(Voice.render(fixture.lines, cue, 0).is_empty(), key)
	fixture.lines["attack_call/proud"] = fixture.lines["attack_call/focused"]
	fixture.lines.erase("attack_call/focused")
	assert_false(Voice.valid_bank(fixture), "Models cannot invent an event/emotion pairing")
	var canonical := Mood.bind({"trigger": "defeat", "mood_id": "proud", "mood": "我超得意"})
	assert_eq(canonical.mood_id, "respectful")
	assert_eq(canonical.mood, "服气", "Never render an arbitrary untrusted mood label")
	return ""

func test_visible_label_portrait_and_history_share_the_cue_mood() -> String:
	var parent := Node.new()
	var model := preload("res://tests/test_battle_commentary.gd").ModelDouble.new()
	var session := Session.new()
	session.start(parent, {}, model)
	var bubble := Bubble.new()
	assert_false(bubble.visible, "Silent opponents do not occupy the board")
	session.line_ready.connect(bubble.present)
	session.offer({"trigger": "attack_call", "turn": 8, "subject": "幻影潜袭", "mood_id": "anxious", "priority": 40}, 100)
	assert_eq(session.history.back().mood_id, "anxious")
	assert_eq(bubble.current_mood_id, "anxious")
	assert_true(bubble.identity.text.contains("紧张"))
	assert_true(bubble.body.text.contains("冒汗"))
	assert_eq(bubble.emote.texture.region, Mood.portrait("anxious").region)
	bubble._process(9.0)
	assert_false(bubble.visible, "Finished speech disappears instead of leaving an idle panel")
	assert_eq(bubble.current_mood_id, "focused", "Idle cannot keep a stale victory or shocked face")
	session.stop()
	bubble.free()
	parent.free()
	return ""

func test_even_terminal_speech_expires() -> String:
	var bubble := Bubble.new()
	bubble.present("这局我输了，打得漂亮。", {"trigger": "defeat", "priority": 100})
	bubble._process(9.0)
	assert_false(bubble.visible, "End-of-match speech is also transient")
	bubble.free()
	return ""

func test_floating_placement_avoids_bench_and_hides_when_no_pocket_exists() -> String:
	var placement := preload("res://scripts/commentary/OpponentTalkPlacement.gd")
	var bounds := Rect2(800, 60, 700, 350)
	var obstacles: Array[Rect2] = [Rect2(800, 100, 300, 140), Rect2(1260, 260, 240, 150)]
	var result := placement.find_slot(bounds, Vector2(320, 104), Vector2(1000, 150), obstacles)
	assert_true(result.has_area() and bounds.encloses(result))
	for obstacle: Rect2 in obstacles: assert_false(result.intersects(obstacle))
	obstacles.append(bounds)
	assert_false(placement.find_slot(bounds, Vector2(320, 104), Vector2(1000, 150), obstacles).has_area())
	return ""
