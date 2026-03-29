## 学习装置 - 己方战斗位宝可梦昏厥时，可将其1张基本能量转附到持有此卡的宝可梦
## 被动效果，昏厥时触发由 GameStateMachine 处理
class_name EffectExpShare
extends BaseEffect


## 检查宝可梦是否持有学习装置
static func find_exp_share_slot(player: PlayerState) -> PokemonSlot:
	for slot: PokemonSlot in player.bench:
		if slot.attached_tool != null and slot.attached_tool.card_data.effect_id == "40d67cc66ad153ee1d54c6213c50b4a1":
			return slot
	return null


## 将昏厥宝可梦的1张基本能量转移到持有学习装置的宝可梦
static func transfer_energy_on_knockout(ko_slot: PokemonSlot, player: PlayerState) -> void:
	var target: PokemonSlot = find_exp_share_slot(player)
	if target == null:
		return
	for energy: CardInstance in ko_slot.attached_energy:
		if energy.card_data.card_type == "Basic Energy":
			ko_slot.attached_energy.erase(energy)
			target.attached_energy.append(energy)
			return


func get_description() -> String:
	return "己方战斗位昏厥时，可将其1张基本能量转附于此宝可梦"
