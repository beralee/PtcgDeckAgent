## 夜光能量 - 提供所有属性能量；如果宝可梦身上有其他特殊能量则只提供1个无色
class_name EffectLuminousEnergy
extends BaseEffect

const EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"


func provides_any_type() -> bool:
	return true


## 检查该能量是否应退化为无色（宝可梦身上有其他特殊能量时）
## 由 EffectProcessor.get_energy_type 在 provides_any_type 判定后调用
func should_downgrade_to_colorless(energy: CardInstance, state: GameState) -> bool:
	if energy == null or state == null:
		return false
	for player: PlayerState in state.players:
		for slot: PokemonSlot in player.get_all_pokemon():
			if energy in slot.attached_energy:
				for other: CardInstance in slot.attached_energy:
					if other != energy and other.card_data.card_type == "Special Energy":
						return true
				return false
	return false


func get_energy_count() -> int:
	return 1


func get_description() -> String:
	return "提供所有属性能量；宝可梦身上有其他特殊能量时只提供1个无色"
