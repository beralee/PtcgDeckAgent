class_name AIHeuristics
extends RefCounted


func score_action(action: Dictionary, _context: Dictionary) -> float:
	match str(action.get("kind", "")):
		"attack":
			if bool(action.get("projected_knockout", false)):
				return 1000.0
			return 500.0
		"attach_energy":
			return 240.0 if bool(action.get("is_active_target", false)) else 200.0
		"play_basic_to_bench":
			return 180.0
		"evolve":
			return 170.0
		"use_ability":
			return 160.0
		"play_stadium":
			return 120.0
		"play_trainer":
			return 110.0 if bool(action.get("productive", true)) else 20.0
		"retreat":
			return 90.0
		"end_turn":
			return 0.0
		_:
			return 10.0
