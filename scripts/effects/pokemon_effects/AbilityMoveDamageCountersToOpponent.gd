## 亢奋脑力 - 愿增猿
## 如果附着了恶能量，每回合1次，将己方宝可梦上最多N个伤害指示物转放到对手宝可梦上。
class_name AbilityMoveDamageCountersToOpponent
extends BaseEffect

const USED_FLAG_TYPE := "ability_move_counters_to_opp_used"
const LUMINOUS_ENERGY_EFFECT_ID := "540ee48bb93584e4bfe3d7f5d0ee0efc"
const LEGACY_ENERGY_EFFECT_ID := "6f31b7241a181631016466e561f148f3"
const TEMPLE_OF_SINNOH_EFFECT_ID := "53864b068a4a1e8dce3c53c884b67efa"

var max_counters: int = 3


func _init(max_count: int = 3) -> void:
	max_counters = max_count


func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return false
	# 检查是否已使用
	for eff: Dictionary in pokemon.effects:
		if eff.get("type") == USED_FLAG_TYPE and eff.get("turn") == state.turn_number:
			return false
	# 必须附着恶能量
	if not _has_dark_energy(pokemon, state):
		return false
	# 己方场上至少有1只宝可梦有伤害指示物
	var player: PlayerState = state.players[top.owner_index]
	var has_source := false
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.damage_counters >= 10:
			has_source = true
			break
	if not has_source:
		return false
	# 对手场上需要有宝可梦
	var opponent: PlayerState = state.players[1 - top.owner_index]
	return not opponent.get_all_pokemon().is_empty()


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var opponent: PlayerState = state.players[1 - card.owner_index]

	# 步骤1：选择己方有伤害的宝可梦
	var source_items: Array = []
	var source_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.damage_counters >= 10:
			source_items.append(slot)
			source_labels.append("%s（%d伤害）" % [slot.get_pokemon_name(), slot.damage_counters])
	if source_items.is_empty():
		return []

	# 步骤2：选择对手宝可梦
	var target_items: Array = []
	var target_labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		target_items.append(slot)
		target_labels.append(slot.get_pokemon_name())
	if target_items.is_empty():
		return []

	# 步骤3：选择转移数量
	var count_items: Array = []
	var count_labels: Array[String] = []
	for i: int in range(1, max_counters + 1):
		count_items.append(i)
		count_labels.append("转移%d个指示物" % i)

	return [
		{
			"id": "source_pokemon",
			"title": "选择己方1只有伤害的宝可梦",
			"items": source_items,
			"labels": source_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "target_pokemon",
			"title": "选择对手1只宝可梦",
			"items": target_items,
			"labels": target_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
		{
			"id": "counter_count",
			"title": "选择转移伤害指示物数量（最多%d个）" % max_counters,
			"items": count_items,
			"labels": count_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		},
	]


func execute_ability(
	pokemon: PokemonSlot,
	_ability_index: int,
	targets: Array,
	state: GameState
) -> void:
	var top: CardInstance = pokemon.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)

	# 获取来源宝可梦
	var source_raw: Array = ctx.get("source_pokemon", [])
	var source: PokemonSlot = null
	if not source_raw.is_empty() and source_raw[0] is PokemonSlot:
		var s: PokemonSlot = source_raw[0]
		if s in player.get_all_pokemon() and s.damage_counters >= 10:
			source = s
	if source == null:
		return

	# 获取目标宝可梦
	var target_raw: Array = ctx.get("target_pokemon", [])
	var target: PokemonSlot = null
	if not target_raw.is_empty() and target_raw[0] is PokemonSlot:
		var t: PokemonSlot = target_raw[0]
		if t in opponent.get_all_pokemon():
			target = t
	if target == null:
		return

	# 获取转移数量
	var count_raw: Array = ctx.get("counter_count", [])
	var count: int = 1
	if not count_raw.is_empty():
		count = int(count_raw[0])
	count = clampi(count, 1, max_counters)

	# 执行转移
	var move_amount: int = mini(count * 10, source.damage_counters)
	if move_amount <= 0:
		return
	source.damage_counters -= move_amount
	target.damage_counters += move_amount

	pokemon.effects.append({"type": USED_FLAG_TYPE, "turn": state.turn_number})


func _has_dark_energy(pokemon: PokemonSlot, state: GameState = null) -> bool:
	for energy: CardInstance in pokemon.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var energy_type: String = _get_attached_energy_type(pokemon, energy, state)
		if energy_type == "D" or energy_type == "ANY":
			return true
	return false


func _get_attached_energy_type(pokemon: PokemonSlot, energy: CardInstance, state: GameState = null) -> String:
	if energy == null or energy.card_data == null:
		return "C"
	if _is_special_energy_suppressed(energy, state):
		return "C"
	match energy.card_data.effect_id:
		LUMINOUS_ENERGY_EFFECT_ID:
			return "C" if _luminous_energy_is_downgraded(pokemon, energy) else "ANY"
		LEGACY_ENERGY_EFFECT_ID:
			return "ANY"
	var provides: String = energy.card_data.energy_provides
	return provides if provides != "" else "C"


func _is_special_energy_suppressed(energy: CardInstance, state: GameState = null) -> bool:
	return (
		energy.card_data.card_type == "Special Energy"
		and state != null
		and state.stadium_card != null
		and state.stadium_card.card_data != null
		and state.stadium_card.card_data.effect_id == TEMPLE_OF_SINNOH_EFFECT_ID
	)


func _luminous_energy_is_downgraded(pokemon: PokemonSlot, luminous_energy: CardInstance) -> bool:
	if pokemon == null:
		return false
	for other: CardInstance in pokemon.attached_energy:
		if other != luminous_energy and other != null and other.card_data != null and other.card_data.card_type == "Special Energy":
			return true
	return false


func get_description() -> String:
	return "特性【亢奋脑力】：附着恶能量时，每回合1次，将己方宝可梦上最多%d个伤害指示物转放到对手宝可梦上。" % max_counters
