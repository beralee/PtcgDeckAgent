class_name CS5bC040SlowbroEffects
extends BaseEffect


var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	if attack_index_to_match >= 0:
		return attack_index == attack_index_to_match
	return attack_index == 0 or attack_index == 1


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	if attack_index == 0:
		_apply_special_status(attacker, "asleep", state)
		if defender != null and not _defender_prevents_attack_effect(attacker, defender, state):
			_apply_special_status(defender, "asleep", state)
		return
	if not _can_use_twilight_inspiration(attacker, state):
		return
	var top_card: CardInstance = attacker.get_top_card()
	var owner_index: int = top_card.owner_index if top_card != null else -1
	if owner_index < 0 or owner_index >= state.players.size():
		return
	var player: PlayerState = state.players[owner_index]
	for _i: int in mini(2, player.prizes.size()):
		player.take_prize(0)


static func can_use_twilight_inspiration(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or state == null:
		return false
	var top_card: CardInstance = attacker.get_top_card()
	var owner_index: int = top_card.owner_index if top_card != null else -1
	if owner_index < 0 or owner_index >= state.players.size():
		return false
	var opponent_index: int = 1 - owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	return state.players[opponent_index].prizes.size() == 1


func _can_use_twilight_inspiration(attacker: PokemonSlot, state: GameState) -> bool:
	return can_use_twilight_inspiration(attacker, state)


func _defender_prevents_attack_effect(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		return bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state))
	return false


func get_description() -> String:
	return "Tumbling Tackle makes both Active Pokemon Asleep. Twilight Inspiration can be used only when the opponent has exactly 1 Prize remaining and takes 2 of your Prize cards."
