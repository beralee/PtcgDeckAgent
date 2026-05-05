## 学习装置 - 己方战斗位宝可梦昏厥时，可将其1张基本能量转附到持有此卡的宝可梦
## 被动效果，昏厥时触发由 GameStateMachine 处理
class_name EffectExpShare
extends BaseEffect

const EFFECT_ID := "40d67cc66ad153ee1d54c6213c50b4a1"


## 检查宝可梦是否持有学习装置
static func find_exp_share_slot(player: PlayerState) -> PokemonSlot:
	var slots := find_exp_share_slots(player)
	return slots[0] if not slots.is_empty() else null


static func find_exp_share_slots(player: PlayerState) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.bench:
		if slot.attached_tool != null and slot.attached_tool.card_data.effect_id == EFFECT_ID:
			result.append(slot)
	return result


static func get_transferable_energy(ko_slot: PokemonSlot) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	for energy: CardInstance in ko_slot.attached_energy:
		if energy.card_data != null and energy.card_data.card_type == "Basic Energy":
			result.append(energy)
	return result


## 将昏厥宝可梦的1张基本能量转移到持有学习装置的宝可梦
static func transfer_energy_on_knockout(
	ko_slot: PokemonSlot,
	player: PlayerState,
	target: PokemonSlot = null,
	selected_energy: CardInstance = null
) -> void:
	if target == null:
		target = find_exp_share_slot(player)
	if target == null:
		return
	if not target in find_exp_share_slots(player):
		return
	var energy_to_move: CardInstance = selected_energy
	if energy_to_move == null or not energy_to_move in ko_slot.attached_energy or energy_to_move.card_data == null or energy_to_move.card_data.card_type != "Basic Energy":
		var transferable := get_transferable_energy(ko_slot)
		energy_to_move = transferable[0] if not transferable.is_empty() else null
	if energy_to_move == null:
		return
	ko_slot.attached_energy.erase(energy_to_move)
	target.attached_energy.append(energy_to_move)


func get_description() -> String:
	return "己方战斗位昏厥时，可将其1张基本能量转附于此宝可梦"
