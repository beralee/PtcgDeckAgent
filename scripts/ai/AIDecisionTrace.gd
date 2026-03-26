class_name AIDecisionTrace
extends RefCounted

var turn_number: int = -1
var player_index: int = -1
var legal_actions: Array = []
var scored_actions: Array = []
var chosen_action: Dictionary = {}
var reason_tags: Array = []


func clone():
	var copy: Object = get_script().new()
	copy.turn_number = turn_number
	copy.player_index = player_index
	copy.legal_actions = legal_actions.duplicate(true)
	copy.scored_actions = scored_actions.duplicate(true)
	copy.chosen_action = chosen_action.duplicate(true)
	copy.reason_tags = reason_tags.duplicate(true)
	return copy


func to_dictionary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"player_index": player_index,
		"legal_actions": legal_actions.duplicate(true),
		"scored_actions": scored_actions.duplicate(true),
		"chosen_action": chosen_action.duplicate(true),
		"reason_tags": reason_tags.duplicate(true),
	}
