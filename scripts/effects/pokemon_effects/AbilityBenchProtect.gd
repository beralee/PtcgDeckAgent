## 备战区保护特性效果 - 浪花水帘（玛纳霏）
## 只要此宝可梦在场上，己方备战宝可梦不受对手招式伤害
## 被动特性，由 EffectProcessor 查询 has_bench_protect()
## 特性激活时在游戏状态的效果列表中存储标记（或直接由引擎轮询）
class_name AbilityBenchProtect
extends BaseEffect

const MANAPHY_EFFECT_ID := "04653d073ffc3ca2202746e4f9aebabd"
const WAVE_VEIL_ABILITY_NAMES := ["浪花水帘", "浪花水幕", "Wave Veil"]


## 被动特性，无需执行任何动作
## 引擎应在每次对备战区宝可梦施加招式伤害前调用此类的 is_active() 检查
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需主动执行
	pass


## 返回此特性是否阻止对备战区宝可梦的招式伤害
## EffectProcessor 应调用此方法判断备战区保护是否有效
func blocks_bench_damage() -> bool:
	return true


static func protects_bench_target(target: PokemonSlot, attacker: PokemonSlot, state: GameState) -> bool:
	if target == null or attacker == null or state == null:
		return false
	var target_top: CardInstance = target.get_top_card()
	var attacker_top: CardInstance = attacker.get_top_card()
	if target_top == null or attacker_top == null:
		return false
	var target_owner := target_top.owner_index
	if target_owner < 0 or target_owner >= state.players.size():
		return false
	if target_owner == attacker_top.owner_index:
		return false
	if target not in state.players[target_owner].bench:
		return false
	for source: PokemonSlot in state.players[target_owner].get_all_pokemon():
		if _is_wave_veil_source(source) and not _is_source_ability_disabled(source, state):
			return true
	return false


static func _is_wave_veil_source(source: PokemonSlot) -> bool:
	if source == null:
		return false
	var card_data: CardData = source.get_card_data()
	if card_data == null:
		return false
	if card_data.effect_id == MANAPHY_EFFECT_ID:
		return true
	for ability: Variant in card_data.abilities:
		if ability is Dictionary and str(ability.get("name", "")) in WAVE_VEIL_ABILITY_NAMES:
			return true
	return false


static func _is_source_ability_disabled(source: PokemonSlot, state: GameState) -> bool:
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("is_ability_disabled"):
		return bool(processor.call("is_ability_disabled", source, state))
	return EffectCancelCologne.is_slot_directly_ability_disabled(source, state) if state != null else false


func get_description() -> String:
	return "特性【浪花水帘】：只要此宝可梦在场上，己方备战宝可梦不受对手招式伤害。"
