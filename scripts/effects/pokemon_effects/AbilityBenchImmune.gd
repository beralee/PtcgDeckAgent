## 备战区免疫特性效果 - 大牙狸（毫不在意）
## 当此宝可梦在备战区时，不受对手招式伤害影响
## 被动特性，由 EffectProcessor 在计算对备战区造成伤害时调用 has_bench_immune()
class_name AbilityBenchImmune
extends BaseEffect

const AbilityPreventTeraAttackDamageAndEffectsScript = preload("res://scripts/effects/pokemon_effects/AbilityPreventTeraAttackDamageAndEffects.gd")
const AbilityNonRuleBoxBenchDamageShieldScript = preload("res://scripts/effects/pokemon_effects/AbilityNonRuleBoxBenchDamageShield.gd")

## 匹配的特性名称（用于在 abilities 列表中识别）
const ABILITY_NAME: String = "毫不在意"
const DAMAGE_AND_EFFECT_ABILITY_NAME: String = "深度下潜"
const DAMAGE_AND_EFFECT_ABILITY_NAMES := [DAMAGE_AND_EFFECT_ABILITY_NAME, "藏隐"]


## 被动特性无需主动执行
func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	# 被动特性，无需执行动作
	pass


## 检查指定 PokemonSlot 是否拥有"毫不在意"特性
## EffectProcessor 应在对备战区宝可梦施加招式伤害前调用此方法
## 若返回 true，且该宝可梦当前在备战区，则跳过招式伤害
static func has_bench_immune(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card()
	if top == null:
		return false
	var cd: CardData = top.card_data
	if cd == null:
		return false
	# 遍历卡牌的 abilities 列表，查找"毫不在意"特性
	var abilities: Variant = cd.abilities
	if abilities == null:
		return false
	for ability: Variant in abilities:
		if ability is Dictionary:
			var ab_name: Variant = ability.get("name", "")
			if ab_name == ABILITY_NAME or str(ab_name) in DAMAGE_AND_EFFECT_ABILITY_NAMES:
				return true
	return false


static func has_bench_damage_and_effect_immunity(slot: PokemonSlot) -> bool:
	var top: CardInstance = slot.get_top_card() if slot != null else null
	if top == null or top.card_data == null:
		return false
	for ability: Variant in top.card_data.abilities:
		if ability is Dictionary and str(ability.get("name", "")) in DAMAGE_AND_EFFECT_ABILITY_NAMES:
			return true
	return false


static func prevents_opponent_attack_damage(
	target: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState
) -> bool:
	if target == null:
		return false
	if _is_tera_bench_rule_active(target, state):
		return true
	if _is_benched(target, state) and has_bench_immune(target) and not _is_bench_immunity_disabled(target, state):
		return true
	if AbilityPreventTeraAttackDamageAndEffectsScript.prevents_target_effect_from_tera_attack(attacker, target, state):
		return true
	if AbilityBenchProtect.protects_bench_target(target, attacker, state):
		return true
	if AbilityNonRuleBoxBenchDamageShieldScript.protects_bench_target(target, attacker, state):
		return true
	return AbilityTeamBenchShield.protects_bench_target(target, attacker, state)


static func prevents_opponent_attack_effect(
	target: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState
) -> bool:
	if target != null and _is_benched(target, state) and has_bench_damage_and_effect_immunity(target) and not _is_bench_immunity_disabled(target, state):
		return true
	if AbilityPreventTeraAttackDamageAndEffectsScript.prevents_target_effect_from_tera_attack(attacker, target, state):
		return true
	return AbilityTeamBenchShield.protects_bench_target(target, attacker, state)


static func prevents_opponent_attack_damage_or_effect(
	target: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState
) -> bool:
	return prevents_opponent_attack_damage(target, attacker, state)


static func _is_bench_immunity_disabled(target: PokemonSlot, state: GameState) -> bool:
	if target == null or state == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("is_ability_disabled"):
		return bool(processor.call("is_ability_disabled", target, state))
	return EffectCancelCologne.is_slot_directly_ability_disabled(target, state)


static func _is_benched(target: PokemonSlot, state: GameState) -> bool:
	if target == null or state == null:
		return false
	for player: PlayerState in state.players:
		if target in player.bench:
			return true
	return false


static func _is_tera_bench_rule_active(target: PokemonSlot, state: GameState) -> bool:
	if target == null or state == null or target.get_card_data() == null:
		return false
	if not target.get_card_data().is_tera_pokemon():
		return false
	for player: PlayerState in state.players:
		if target in player.bench:
			return true
	return false


func get_description() -> String:
	return "特性【毫不在意】：此宝可梦在备战区时，不受对手招式伤害。"
