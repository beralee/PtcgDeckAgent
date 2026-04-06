## 铁荆棘ex - 初始化：战斗场上时，压制双方规则宝可梦（非未来）的特性
class_name AbilityIronThornsInit
extends BaseEffect


## 检查指定宝可梦的特性是否被铁荆棘初始化压制
static func is_locked_by_init(slot: PokemonSlot, state: GameState) -> bool:
	if slot == null or state == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	if not cd.is_rule_box_pokemon():
		return false
	if _is_future(cd):
		return false
	# 检查双方战斗场上是否有未被压制的铁荆棘初始化特性
	for pi: int in 2:
		var active: PokemonSlot = state.players[pi].active_pokemon
		if active == null or active == slot:
			continue
		var active_cd: CardData = active.get_card_data()
		if active_cd == null:
			continue
		if not _has_init_ability(active_cd):
			continue
		# 检查该铁荆棘的特性是否被其他效果压制（排除初始化自身的递归）
		if _is_init_suppressed(active, state):
			continue
		return true
	return false


## 检查铁荆棘的初始化特性是否被其他效果压制（不递归检查初始化自身）
static func _is_init_suppressed(slot: PokemonSlot, state: GameState) -> bool:
	if AbilityBasicLock.is_locked_by_basic_lock(slot, state):
		return true
	if AbilityDisableOpponentAbility.is_locked_by_dark_wing(slot, state):
		return true
	return false


static func _has_init_ability(cd: CardData) -> bool:
	for ability: Dictionary in cd.abilities:
		if ability.get("name", "") == "初始化":
			return true
	return false


static func _is_future(cd: CardData) -> bool:
	for tag: Variant in cd.is_tags:
		if str(tag) == "Future":
			return true
	return false


func get_description() -> String:
	return "战斗场上时，双方规则宝可梦（非未来）的特性全部消除"
