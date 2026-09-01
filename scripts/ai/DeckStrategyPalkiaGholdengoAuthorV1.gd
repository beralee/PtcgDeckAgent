class_name DeckStrategyPalkiaGholdengoAuthorV1
extends "res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd"


const STRATEGY_ID := "palkia_gholdengo_author_v1"


func _profile() -> Dictionary:
	var profile: Dictionary = super._profile()
	profile["strategy_id"] = STRATEGY_ID
	return profile


func get_strategy_id() -> String:
	return STRATEGY_ID


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var plan: Dictionary = super.build_turn_plan(game_state, player_index, context)
	plan["id"] = STRATEGY_ID
	return plan
