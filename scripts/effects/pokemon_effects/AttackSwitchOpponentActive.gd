## Attack effect: switch the opponent's Active Pokemon with one of their Benched Pokemon.
class_name AttackSwitchOpponentActive
extends BaseEffect

const STEP_ID := "opponent_switch_target"

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index == attack_index_to_match


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var owner_index := card.owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return []
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return []
	var opponent: PlayerState = state.players[opponent_index]
	if opponent.active_pokemon == null or opponent.bench.is_empty():
		return []

	var items := opponent.bench.duplicate()
	var labels: Array[String] = []
	for slot: PokemonSlot in items:
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	return [{
		"id": STEP_ID,
		"title": "对手选择1只备战宝可梦换到战斗场",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"opponent_chooses": true,
	}]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var owner_index := top.owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return
	var opponent_index := 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return
	var opponent: PlayerState = state.players[opponent_index]
	if opponent.active_pokemon == null or opponent.bench.is_empty():
		return

	var target := _resolve_selected_target(opponent)
	if target == null:
		return
	_switch_to_active(opponent, target, state.turn_number)


func _resolve_selected_target(opponent: PlayerState) -> PokemonSlot:
	var ctx := get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected in opponent.bench:
			return selected
	return opponent.bench[0] if not opponent.bench.is_empty() else null


func _switch_to_active(player: PlayerState, new_active: PokemonSlot, turn_number: int) -> void:
	var old_active: PokemonSlot = player.active_pokemon
	var bench_idx := player.bench.find(new_active)
	if old_active == null or bench_idx < 0:
		return
	player.bench.remove_at(bench_idx)
	old_active.clear_on_leave_active()
	player.bench.append(old_active)
	player.active_pokemon = new_active
	new_active.mark_entered_active_from_bench(turn_number)


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "Switch the opponent's Active Pokemon with 1 of their Benched Pokemon. The opponent chooses the new Active Pokemon."
