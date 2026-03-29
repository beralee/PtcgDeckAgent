## 宝可梦联盟总部 - 双方基础宝可梦招式费用+1无色能量
class_name EffectLeagueHQ
extends BaseEffect


func get_attack_colorless_cost_modifier(
	attacker: PokemonSlot,
	_attack: Dictionary,
	_state: GameState
) -> int:
	if attacker == null:
		return 0
	var cd: CardData = attacker.get_card_data()
	if cd == null:
		return 0
	if cd.stage == "Basic":
		return 1
	return 0


func get_description() -> String:
	return "双方基础宝可梦招式费用+1无色能量"
