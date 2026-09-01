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
	var source_effect_id := str(option.get("source_effect_id", ""))
	var copied_attack_index := int(option.get("attack_index", -1))
	var copied_attack: Dictionary = option.get("attack", {})
	if not _has_resolved_copied_followup(resolved_context):
		return _processor.get_attack_interaction_steps_by_id(
			source_effect_id,
			copied_attack_index,
			card,
			copied_attack,
			state,
			AttackCopyAttack
		)
	return _processor.get_attack_followup_interaction_steps_by_id(
		source_effect_id,
		copied_attack_index,
		card,
		copied_attack,
		state,
		resolved_context,
		AttackCopyAttack
	)


func validate_attack_interaction(
	attacker: PokemonSlot,
	_attack_index: int,
	targets: Array,
	state: GameState
) -> Dictionary:
	if _processor == null:
		return interaction_validation_ok()
	var option := _get_selected_option_from_context(get_interaction_context(targets))
	if option.is_empty():
		return interaction_validation_ok()
	var source_effect_id := str(option.get("source_effect_id", ""))
	var copied_attack_index := int(option.get("attack_index", -1))
	if not _is_legal_selected_option(option, attacker, state):
		return interaction_validation_error("copied attack source is invalid")
	var defender := _get_opponent_active(attacker, state)
	if _processor.validate_attack_effect_context_by_id(
		source_effect_id,
		copied_attack_index,
		attacker,
		defender,
		state,
		targets,
		AttackCopyAttack
	):
		return interaction_validation_ok()
	return interaction_validation_error(_processor.get_last_interaction_validation_error(state))


func before_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var option := _get_selected_option()
	if option.is_empty() or _processor == null:
		return
	_processor.execute_before_attack_damage_effects_by_id(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		defender,
		state,
		[get_attack_interaction_context()],
		AttackCopyAttack
	)


func cancels_attack_damage(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> bool:
	var option := _get_selected_option()
	if option.is_empty() or _processor == null:
		return false
	return _processor.attack_damage_cancelled_by_id(
		str(option.get("source_effect_id", "")),
		int(option.get("attack_index", -1)),
		attacker,
		defender,
		state,
		[get_attack_interaction_context()],
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
		AttackCopyAttack,
		{"mode": "copy", "name": str((option.get("attack", {}) as Dictionary).get("name", ""))}
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
	return has_resolved_non_internal_interaction_step(context, [STEP_ID])


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


func _get_opponent_active(attacker: PokemonSlot, state: GameState) -> PokemonSlot:
	var owner_index := _get_attacker_owner_index(attacker)
	if state == null or owner_index < 0 or owner_index >= state.players.size():
		return null
	return state.players[1 - owner_index].active_pokemon


func _is_legal_selected_option(option: Dictionary, attacker: PokemonSlot, state: GameState) -> bool:
	var source := _get_opponent_active(attacker, state)
	if source == null or source.get_card_data() == null:
		return false
	if str(option.get("source_effect_id", "")) != str(source.get_card_data().effect_id):
		return false
	var copied_attack_index := int(option.get("attack_index", -1))
	var attacks := source.get_attacks()
	if copied_attack_index < 0 or copied_attack_index >= attacks.size():
		return false
	var copied_attack: Dictionary = attacks[copied_attack_index]
	if option.get("attack", {}) != copied_attack:
		return false
	return not (bool(copied_attack.get("is_vstar_power", false)) and _is_vstar_power_used_for_player(_get_attacker_owner_index(attacker), state))


func _is_vstar_power_used_for_player(player_index: int, state: GameState) -> bool:
	if state == null:
		return true
	if player_index < 0 or player_index >= state.vstar_power_used.size():
		return true
	return bool(state.vstar_power_used[player_index])


func get_description() -> String:
	return "基因侵入：选择对手战斗宝可梦的1个招式，作为这个招式使用。"
