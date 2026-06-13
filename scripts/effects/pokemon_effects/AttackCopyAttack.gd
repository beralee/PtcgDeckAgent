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
		if copied_attack.get("is_vstar_power", false) and _is_vstar_power_used_for_player(card.owner_index, state):
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
	if _has_resolved_copied_followup(resolved_context):
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
	if _is_selected_vstar_power_used(option, _attacker, _state):
		return 0
	var attack: Dictionary = option.get("attack", {})
	var total: int = DamageCalculator.new().parse_damage(str(attack.get("damage", "")))
	if _processor != null:
		total += _processor.get_attack_damage_bonus_by_id(
			str(option.get("source_effect_id", "")),
			int(option.get("attack_index", -1)),
			_attacker,
			_state,
			[get_attack_interaction_context()],
			AttackCopyAttack
		)
	return total


func ignores_weakness_and_resistance(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	var option: Dictionary = _get_selected_option()
	if option.is_empty() or _processor == null:
		return false
	return _processor.attack_effect_id_ignores_weakness_and_resistance(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


func ignores_weakness(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	var option: Dictionary = _get_selected_option()
	if option.is_empty() or _processor == null:
		return false
	return _processor.attack_effect_id_ignores_weakness(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


func ignores_resistance(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	var option: Dictionary = _get_selected_option()
	if option.is_empty() or _processor == null:
		return false
	return _processor.attack_effect_id_ignores_resistance(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


func ignores_defender_effects(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	var option: Dictionary = _get_selected_option()
	if option.is_empty() or _processor == null:
		return false
	return _processor.attack_effect_id_ignores_defender_effects(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


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
	if _is_selected_vstar_power_used(option, attacker, state):
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
	_mark_selected_vstar_power_used(option, attacker, state)


func _get_selected_option() -> Dictionary:
	return _get_selected_option_from_context(get_attack_interaction_context())


func _get_selected_option_from_context(context: Dictionary) -> Dictionary:
	var selected_raw: Array = context.get(STEP_ID, [])
	if selected_raw.is_empty() or not (selected_raw[0] is Dictionary):
		return {}
	return selected_raw[0]


func _has_resolved_copied_followup(context: Dictionary) -> bool:
	for key: Variant in context.keys():
		if str(key) != STEP_ID:
			return true
	return false


func _is_selected_vstar_power_used(option: Dictionary, attacker: PokemonSlot, state: GameState) -> bool:
	if not _is_selected_vstar_power(option):
		return false
	var player_index := _get_attacker_owner_index(attacker)
	return _is_vstar_power_used_for_player(player_index, state)


func _mark_selected_vstar_power_used(option: Dictionary, attacker: PokemonSlot, state: GameState) -> void:
	if not _is_selected_vstar_power(option):
		return
	var player_index := _get_attacker_owner_index(attacker)
	if player_index < 0 or player_index >= state.vstar_power_used.size():
		return
	state.vstar_power_used[player_index] = true


func _is_selected_vstar_power(option: Dictionary) -> bool:
	var attack: Dictionary = option.get("attack", {})
	return bool(attack.get("is_vstar_power", false))


func _get_attacker_owner_index(attacker: PokemonSlot) -> int:
	if attacker == null:
		return -1
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return -1
	return top_card.owner_index


func _is_vstar_power_used_for_player(player_index: int, state: GameState) -> bool:
	if state == null:
		return true
	if player_index < 0 or player_index >= state.vstar_power_used.size():
		return true
	return bool(state.vstar_power_used[player_index])


func get_description() -> String:
	return "基因侵入：选择对手战斗宝可梦的1个招式，作为这个招式使用。"
