## 复制对手招式效果 - 基因侵入（梦幻ex）
## 复制对手主战宝可梦的招式并执行
class_name AttackCopyAttack
extends BaseEffect

const STEP_ID := "copied_attack"

var _processor: EffectProcessor = null


func _init(processor: EffectProcessor = null) -> void:
	_processor = processor


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null:
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var opp_active: PokemonSlot = opponent.active_pokemon
	if opp_active == null:
		return []
	var items: Array = []
	var labels: Array[String] = []
	for attack_index: int in opp_active.get_attacks().size():
		var copied_attack: Dictionary = opp_active.get_attacks()[attack_index]
		if copied_attack.get("is_vstar_power", false):
			continue
		items.append({
			"source_effect_id": opp_active.get_card_data().effect_id,
			"attack_index": attack_index,
			"attack": copied_attack,
		})
		labels.append("%s - %s" % [
			opp_active.get_pokemon_name(),
			str(copied_attack.get("name", "")),
		])
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": "选择对手战斗宝可梦的1个招式",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if _processor == null:
		return []
	var option: Dictionary = _get_selected_option_from_context(resolved_context)
	if option.is_empty():
		return []
	return _processor.get_attack_interaction_steps_by_id(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		card,
		option.get("attack", {}),
		state,
		AttackCopyAttack
	)


func get_damage_bonus(_attacker: PokemonSlot, _state: GameState) -> int:
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		return 0
	var attack: Dictionary = option.get("attack", {})
	return DamageCalculator.new().parse_damage(str(attack.get("damage", "")))


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	if _processor == null:
		return
	var option: Dictionary = _get_selected_option()
	if option.is_empty():
		return
	var source_effect_id: String = str(option.get("source_effect_id", ""))
	var copied_attack_index: int = int(option.get("attack_index", -1))
	if source_effect_id == "" or copied_attack_index < 0:
		return
	_processor.execute_attack_effect_by_id(
		source_effect_id,
		copied_attack_index,
		attacker,
		defender,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


func _get_selected_option() -> Dictionary:
	return _get_selected_option_from_context(get_attack_interaction_context())


func _get_selected_option_from_context(context: Dictionary) -> Dictionary:
	var selected_raw: Array = context.get(STEP_ID, [])
	if selected_raw.is_empty() or not (selected_raw[0] is Dictionary):
		return {}
	return selected_raw[0]


func get_description() -> String:
	return "基因侵入：选择对手战斗宝可梦的1个招式，作为这个招式使用。"
