class_name CSV8CGalvantulaEffects
extends BaseEffect

const ABILITY_DAMAGE_BONUS := 50
const LIGHTNING_DAMAGE_BONUS := 80
const LIGHTNING_TYPE := "L"

var attack_index_to_match: int = 0


func _init(match_attack_index: int = 0) -> void:
	attack_index_to_match = match_attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func get_attack_modifier_for_attacker(
	source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState,
	defender: PokemonSlot = null
) -> int:
	if source == null or attacker == null or defender == null or state == null:
		return 0
	if source != attacker:
		return 0
	var top := source.get_top_card()
	if top == null:
		return 0
	var opponent_index := 1 - int(top.owner_index)
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	if defender != state.players[opponent_index].active_pokemon:
		return 0
	var defender_data := defender.get_card_data()
	if defender_data == null or defender_data.abilities.is_empty():
		return 0
	return ABILITY_DAMAGE_BONUS


func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
	if attacker == null:
		return 0
	return LIGHTNING_DAMAGE_BONUS if _has_attached_lightning_energy(attacker) else 0


func _has_attached_lightning_energy(attacker: PokemonSlot) -> bool:
	for energy: CardInstance in attacker.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		if _card_provides_lightning(energy.card_data):
			return true
	return false


func _card_provides_lightning(card: CardData) -> bool:
	return card.energy_provides == LIGHTNING_TYPE or card.energy_type == LIGHTNING_TYPE


func get_description() -> String:
	return "Its attacks do 50 more damage to the opponent Active Pokemon with an Ability. Its first attack does 80 more damage if this Pokemon has Lightning Energy attached."
