class_name AttackDiscardAllEnergyTakePrize
extends BaseEffect

var attack_index_to_match: int = -1


func _init(match_attack_index: int = -1) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	attack_index: int,
	state: GameState
) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top := attacker.get_top_card()
	if top == null:
		return
	var owner_index := top.owner_index
	if owner_index < 0 or owner_index >= state.players.size():
		return
	var player: PlayerState = state.players[owner_index]
	var discarded := attacker.attached_energy.duplicate()
	attacker.attached_energy.clear()
	for energy: CardInstance in discarded:
		if energy == null:
			continue
		energy.face_up = true
		player.discard_pile.append(energy)
	player.take_prize(0)


func get_description() -> String:
	return "Discard all Energy from this Pokemon, then take 1 Prize card."
