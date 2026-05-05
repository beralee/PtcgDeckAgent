## Optional Stadium discard after an attack.
## Used by attacks such as Lugia V's Aero Dive and Lugia VSTAR's Storm Dive.
class_name AttackOptionalDiscardStadium
extends BaseEffect

const STEP_ID := "discard_stadium"

var discard_stadium: bool = true


func _init(do_discard: bool = true) -> void:
	discard_stadium = do_discard


func get_attack_interaction_steps(
	_card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	var attack_index: int = int(attack.get("_override_attack_index", attack.get("index", -1)))
	if attack_index >= 0 and not applies_to_attack_index(attack_index):
		return []
	if not discard_stadium or state.stadium_card == null:
		return []
	return [{
		"id": STEP_ID,
		"title": "是否弃置场上的竞技场？",
		"items": ["keep", "discard"],
		"labels": ["保留竞技场", "弃置竞技场"],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if not applies_to_attack_index(attack_index) or not discard_stadium:
		return
	if state.stadium_card == null:
		return

	var ctx: Dictionary = get_attack_interaction_context()
	if ctx.has(STEP_ID):
		var selected_raw: Array = ctx.get(STEP_ID, [])
		if selected_raw.is_empty() or str(selected_raw[0]) != "discard":
			return

	var owner_idx: int = state.stadium_owner_index
	if owner_idx >= 0 and owner_idx < state.players.size():
		var owner_player: PlayerState = state.players[owner_idx]
		owner_player.discard_pile.append(state.stadium_card)

	state.stadium_card = null
	state.stadium_owner_index = -1


func get_description() -> String:
	return "可以选择弃置场上的竞技场。"
