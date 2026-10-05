extends RefCounted
const Mood := preload("res://scripts/commentary/OpponentMood.gd")
## Public, immutable facts in; optional display cues out. Never owns a decision.
var seat := 1
var own_turn := -1
var attacked := false
var developed := false
var stalled := false
var opened := false
var ended := false
var previous_prizes: Array = []
var last_attack := ""
var own_remaining := 6
var other_remaining := 6
var stalled_turns := 0
var serial := 0
var announced_aces: Dictionary = {}

func _cue(trigger: String, turn: int, subject: String = "", prizes: int = 0, priority: int = 40, mood_id: String = "") -> Dictionary:
	serial += 1
	var cue := {"id": serial, "trigger": trigger, "turn": turn, "subject": subject.left(80), "prizes_taken": prizes, "priority": priority}
	if not mood_id.is_empty(): cue.mood_id = mood_id
	return Mood.bind(cue)

func _under_pressure() -> bool:
	return other_remaining <= 2 and own_remaining > other_remaining

func action(event: Dictionary) -> Dictionary:
	if ended or int(event.get("player", -1)) != seat: return {}
	var turn := int(event.get("turn", 0))
	if turn <= 0: return {}
	if own_turn != turn:
		own_turn = turn
		attacked = false
		developed = false
	match str(event.get("type", "")):
		"PLAY_POKEMON", "ATTACH_ENERGY":
			developed = true
			stalled_turns = 0
		"EVOLVE":
			developed = true
			stalled_turns = 0
			var subject := str(event.get("evolution", ""))
			var lower := subject.to_lower()
			if not subject.is_empty() and not announced_aces.has(subject) and (lower.contains("ex") or lower.contains("vstar") or lower.contains("vmax")):
				announced_aces[subject] = true
				return _cue("ace_arrival", turn, subject, 0, 45)
		"ATTACK":
			attacked = true
			last_attack = str(event.get("attack_name", ""))
			if last_attack.is_empty(): return {}
			var trigger := "recovery" if stalled else "attack_call"
			var emotion := ("determined" if _under_pressure() else "relieved") if stalled else ("anxious" if _under_pressure() else "focused")
			stalled = false
			stalled_turns = 0
			return _cue(trigger, turn, last_attack, 0, 40, emotion)
		"TURN_END":
			# A quiet public turn is frustration, not a claim about hidden cards or
			# the legal action frontier. Exclude the two opening turns.
			if turn >= 3 and not attacked and not developed:
				stalled = true
				stalled_turns += 1
				var emotion := "anxious" if _under_pressure() else ("frustrated" if stalled_turns >= 2 else "confused")
				return _cue("stalled", turn, "", 0, 30, emotion)
	return {}

func settled(state: Dictionary) -> Dictionary:
	if ended or state.get("players", []).size() != 2 or int(state.get("turn", 0)) <= 0: return {}
	if str(state.get("phase", "")) not in ["MAIN", "GAME_OVER"]: return {}
	var prizes := [int(state.players[0].prizes_remaining), int(state.players[1].prizes_remaining)]
	var won := 0
	var lost := 0
	var was_behind := false
	if previous_prizes.size() == 2:
		was_behind = int(previous_prizes[seat]) > int(previous_prizes[1 - seat])
		won = maxi(0, int(previous_prizes[seat]) - int(prizes[seat]))
		lost = maxi(0, int(previous_prizes[1 - seat]) - int(prizes[1 - seat]))
	previous_prizes = prizes
	own_remaining = int(prizes[seat])
	other_remaining = int(prizes[1 - seat])
	var turn := int(state.turn)
	var winner := int(state.get("winner", -1))
	if winner in [0, 1]:
		ended = true
		return _cue("victory" if winner == seat else "defeat", turn, "", won, 100)
	if won >= 2:
		return _cue("prize_burst", turn, last_attack, won, 80, "relieved" if was_behind else "proud")
	if lost > 0:
		return _cue("setback", turn, "", 0, 60, "surprised" if lost >= 2 else "determined")
	if not opened:
		opened = true
		return _cue("opening", turn, "", 0, 20)
	return {}
