## 放逐市 - 宝可梦昏厥时，宝可梦卡放入放逐区，其余附属卡放入弃牌区。
class_name EffectLostCity
extends BaseEffect


func redirects_knocked_out_pokemon_to_lost_zone() -> bool:
	return true


func get_description() -> String:
	return "双方的宝可梦昏厥时，宝可梦卡放入放逐区，其余卡牌放入弃牌区。"
