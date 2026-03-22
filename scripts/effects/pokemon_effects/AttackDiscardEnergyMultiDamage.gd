## 弃指定能量×倍伤害效果 - 强劲电光（雷丘V）
## 弃置攻击者身上所有指定类型的能量，每弃1张追加额外伤害
## 参数:
##   energy_type       要弃置的能量类型（默认"L"=雷能量）
##   damage_per_energy 每弃1张追加的伤害值（默认60）
class_name AttackDiscardEnergyMultiDamage
extends BaseEffect

const STEP_ID := "discard_energy"

## 要弃置的能量类型
var energy_type: String = "L"
## 每弃1张追加的伤害值
var damage_per_energy: int = 60


func _init(e_type: String = "L", per_energy: int = 60) -> void:
	energy_type = e_type
	damage_per_energy = per_energy


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		for energy_card: CardInstance in slot.attached_energy:
			if not _matches_energy_type(energy_card):
				continue
			items.append(energy_card)
			labels.append("%s on %s" % [energy_card.card_data.name, slot.get_pokemon_name()])
	return [{
		"id": STEP_ID,
		"title": "选择要弃置的能量",
		"items": items,
		"labels": labels,
		"min_select": 0,
		"max_select": items.size(),
		"allow_cancel": true,
	}]


func get_damage_bonus(_attacker: PokemonSlot, _state: GameState) -> int:
	var selected_count: int = _get_selected_energy().size()
	return (selected_count - 1) * damage_per_energy


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	var to_discard: Array[CardInstance] = _get_selected_energy()
	if to_discard.is_empty():
		return

	var selected_ids: Dictionary = {}
	for energy_card: CardInstance in to_discard:
		selected_ids[energy_card.instance_id] = true
	for slot: PokemonSlot in player.get_all_pokemon():
		var kept: Array[CardInstance] = []
		for attached: CardInstance in slot.attached_energy:
			if selected_ids.has(attached.instance_id):
				player.discard_pile.append(attached)
			else:
				kept.append(attached)
		slot.attached_energy = kept


## 判断能量卡是否符合指定类型
func _matches_energy_type(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null:
		return false
	if not cd.is_energy():
		return false
	if energy_type == "":
		return true
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func _get_selected_energy() -> Array[CardInstance]:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(STEP_ID, [])
	var result: Array[CardInstance] = []
	for entry: Variant in selected_raw:
		if entry is CardInstance and _matches_energy_type(entry) and not result.has(entry):
			result.append(entry)
	return result


func get_description() -> String:
	return "强劲电光：弃置己方场上任意数量的%s能量，每弃1张追加%d伤害。" % [energy_type, damage_per_energy]
