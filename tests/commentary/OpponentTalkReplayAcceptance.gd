extends Node
## Explicit replay check against the previous real 18.5 match. Reads only its
## public projection, never its private engine replay. No simulation pool/API.
const Director := preload("res://scripts/commentary/OpponentTalkDirector.gd")
const Session := preload("res://scripts/commentary/OpponentTalkSession.gd")
const Knowledge := preload("res://scripts/commentary/CommentaryKnowledge.gd")
const Voice := preload("res://scripts/commentary/OpponentTalkVoice.gd")
class OfflineModel extends RefCounted:
	var calls := 0
	func cancel_pending_requests() -> void: pass
	func request_json(_owner: Node, _url: String, _key: String, _payload: Dictionary, callback: Callable) -> int:
		calls += 1
		var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/opponent_emotion_bank_simulation.json"))
		callback.call({"ok": true, "content": bank, "tokens": 0})
		return OK

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://.tmp/commentary_match_20260929/public_match.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--public-replay="): path = argument.trim_prefix("--public-replay=")
	if not FileAccess.file_exists(path):
		push_error("Supply --public-replay=<public projection JSON>")
		get_tree().quit(2)
		return
	var replay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var director := Director.new()
	var knowledge := Knowledge.new()
	var session := Session.new()
	var model := OfflineModel.new()
	session.start(self, {"api_key": "OFFLINE_ONLY", "ai_personality": "逗比臭牌篓子"}, model)
	var cues: Array = []
	var failures: Array = []
	var previous_prizes: Array = []
	for frame: Dictionary in replay.frames:
		var now := float(frame.step) * 6.0
		for event: Dictionary in frame.events:
			session.new_action()
			var cue := director.action(event)
			if not cue.is_empty():
				cue["step"] = int(frame.step)
				cues.append(cue)
				session.offer(cue, now)
		var state: Dictionary = frame.state
		if bool(frame.pending) or str(state.phase) not in ["MAIN", "GAME_OVER"] or int(state.turn) <= 0: continue
		var cue := director.settled(state)
		if not cue.is_empty():
			cue["step"] = int(frame.step)
			cues.append(cue)
			if cue.trigger == "prize_burst" and (previous_prizes.is_empty() or int(previous_prizes[1]) - int(state.players[1].prizes_remaining) != int(cue.prizes_taken)):
				failures.append("Prize reaction not supported by actual transfer at %s" % frame.step)
			if cue.trigger == "victory" and int(state.winner) != 1: failures.append("Premature victory")
			session.offer(cue, now + 0.5)
		previous_prizes = [int(state.players[0].prizes_remaining), int(state.players[1].prizes_remaining)]
		session.prepare(knowledge.observe(state), now)
		session.tick(now + 3.0)
	for cue: Dictionary in cues:
		if str(cue.subject).contains("长毛巨魔") or str(cue.subject).contains("喷火龙"):
			failures.append("Spoke for the wrong seat or an absent Pokemon")
	var endings := cues.filter(func(c: Dictionary): return c.trigger == "victory")
	var bursts := cues.filter(func(c: Dictionary): return c.trigger == "prize_burst")
	var arrivals := cues.filter(func(c: Dictionary): return c.trigger == "ace_arrival")
	if endings.size() != 1 or int(endings[0].step) != 117: failures.append("Expected exactly one confirmed ending at 117")
	if bursts.is_empty(): failures.append("Real multi-prize transfer never celebrated")
	if arrivals.size() != 1 or not str(arrivals[0].subject).contains("多龙"): failures.append("Expected actual Dragapult arrival")
	if model.calls > Session.MAX_CALLS: failures.append("Request budget exceeded")
	var output := "res://.tmp/opponent_talk_20260929/public_replay_report.json"
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify({"passed": failures.is_empty(), "frames": replay.frames.size(), "cues": cues, "spoken": session.history, "mock_calls": model.calls, "paid_calls": 0, "failures": failures}, "\t"))
	print("OPPONENT_REPLAY ", JSON.stringify({"passed": failures.is_empty(), "frames": replay.frames.size(), "cues": cues.size(), "spoken": session.history.size(), "mock_calls": model.calls, "paid_calls": 0, "failures": failures}))
	session.stop()
	get_tree().quit(0 if failures.is_empty() else 1)
