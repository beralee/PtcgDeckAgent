class_name EffectBlackBeltsTraining
extends BaseEffect

const DAMAGE_FLAG_PREFIX := "black_belts_training_attack_bonus_turn_"
const DAMAGE_VALUE_PREFIX := "black_belts_training_attack_bonus_value_"


func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
	if card == null or state == null:
		return
	state.shared_turn_flags[DAMAGE_FLAG_PREFIX + str(card.owner_index)] = state.turn_number
	state.shared_turn_flags[DAMAGE_VALUE_PREFIX + str(card.owner_index)] = 40


static func get_turn_damage_bonus(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState,
	attack: Dictionary = {},
	current_attack_damage_modifier: int = 0
) -> int:
	if attacker == null or defender == null or state == null:
		return 0
	if not _attack_can_deal_damage(attack, current_attack_damage_modifier):
		return 0
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return 0
	var player_index := top.owner_index
	if player_index < 0 or player_index >= state.players.size():
		return 0
	if int(state.shared_turn_flags.get(DAMAGE_FLAG_PREFIX + str(player_index), -999)) != state.turn_number:
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return 0
	if defender != state.players[opponent_index].active_pokemon:
		return 0
	var defender_data := defender.get_card_data()
	if defender_data == null or defender_data.mechanic != "ex":
		return 0
	return int(state.shared_turn_flags.get(DAMAGE_VALUE_PREFIX + str(player_index), 40))


static func _attack_can_deal_damage(attack: Dictionary, current_attack_damage_modifier: int) -> bool:
	if current_attack_damage_modifier > 0:
		return true
	var damage_text := str(attack.get("damage", "")).strip_edges()
	return damage_text != ""


func get_description() -> String:
	return "本回合己方宝可梦的招式对对手战斗场上的宝可梦 ex 造成的伤害 +40。"
