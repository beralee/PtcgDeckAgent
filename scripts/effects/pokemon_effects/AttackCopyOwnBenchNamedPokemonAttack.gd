class_name AttackCopyOwnBenchNamedPokemonAttack
extends BaseEffect

const STEP_ID := "copied_attack"
const SOURCE_ZONE := "bench"
const SOURCE_ZONE_LABEL := "备战区"

var _processor: EffectProcessor = null
var required_name_prefix: String = ""
var blocked_attack_names: PackedStringArray = []


func _init(processor: EffectProcessor = null, name_prefix: String = "", blocked_names: PackedStringArray = PackedStringArray()) -> void:
	_processor = processor
	required_name_prefix = name_prefix
	blocked_attack_names = blocked_names


func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or card.owner_index < 0 or card.owner_index >= state.players.size():
		return []
	var player: PlayerState = state.players[card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	var action_items: Array[Dictionary] = []
	var copied_cost := str(attack.get("cost", ""))
	for bench_slot: PokemonSlot in player.bench:
		var source_data := _get_copy_source_data(bench_slot)
		if source_data == null:
			continue
		if _processor != null:
			_processor.register_pokemon_card(source_data)
		var source_card := bench_slot.get_top_card()
		if source_card == null:
			continue
		for attack_index: int in bench_slot.get_attacks().size():
			var copied_attack: Dictionary = bench_slot.get_attacks()[attack_index]
			if not _can_copy_attack(copied_attack):
				continue
			items.append(_build_copied_attack_option(source_card, bench_slot, source_data, copied_attack, attack_index))
			labels.append("%s - %s" % [
				source_data.display_name(),
				CardData.dictionary_display_name(copied_attack),
			])
			action_items.append(_build_copied_attack_action_item(source_data, copied_attack, copied_cost))
	if items.is_empty():
		return []
	return [{
		"id": STEP_ID,
		"title": _copy_prompt_title(),
		"items": items,
		"labels": labels,
		"presentation": "action_hud",
		"action_items": action_items,
		"source_zone": SOURCE_ZONE,
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
	if _processor == null or _has_resolved_copied_followup(resolved_context):
		return []
	var option := _get_selected_option_from_context(resolved_context)
	if option.is_empty():
		return []
	var source_effect_id := _get_selected_source_effect_id(option)
	var copied_attack_index := int(option.get("attack_index", -1))
	if source_effect_id == "" or copied_attack_index < 0:
		return []
	return _processor.get_attack_interaction_steps_by_id(
		source_effect_id,
		copied_attack_index,
		card,
		option.get("attack", {}),
		state,
		get_script()
	)


func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
	var option := _get_selected_option()
	if option.is_empty():
		return 0
	var copied_attack: Dictionary = option.get("attack", {})
	var total := DamageCalculator.new().parse_damage(str(copied_attack.get("damage", "")))
	var source_effect_id := _get_selected_source_effect_id(option)
	var copied_attack_index := int(option.get("attack_index", -1))
	if _processor != null and source_effect_id != "" and copied_attack_index >= 0:
		total += _processor.get_attack_damage_bonus_by_id(
			source_effect_id,
			copied_attack_index,
			attacker,
			state,
			[get_attack_interaction_context()],
			get_script()
		)
	return total


func ignores_weakness_and_resistance(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	return _copied_attack_has_flag("attack_effect_id_ignores_weakness_and_resistance", attacker, state)


func ignores_weakness(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	return _copied_attack_has_flag("attack_effect_id_ignores_weakness", attacker, state)


func ignores_resistance(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	return _copied_attack_has_flag("attack_effect_id_ignores_resistance", attacker, state)


func ignores_defender_effects(attacker: PokemonSlot, state: GameState, _attack_index: int = -1) -> bool:
	return _copied_attack_has_flag("attack_effect_id_ignores_defender_effects", attacker, state)


func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	if _processor == null:
		return
	var option := _get_selected_option()
	if option.is_empty():
		return
	var source_effect_id := _get_selected_source_effect_id(option)
	var copied_attack_index := int(option.get("attack_index", -1))
	if source_effect_id == "" or copied_attack_index < 0:
		return
	_processor.execute_attack_effect_by_id(
		source_effect_id,
		copied_attack_index,
		attacker,
		defender,
		state,
		[get_attack_interaction_context()],
		get_script()
	)


func _copied_attack_has_flag(method_name: String, attacker: PokemonSlot, state: GameState) -> bool:
	var option := _get_selected_option()
	if option.is_empty() or _processor == null or not _processor.has_method(method_name):
		return false
	var source_effect_id := _get_selected_source_effect_id(option)
	var copied_attack_index := int(option.get("attack_index", -1))
	if source_effect_id == "" or copied_attack_index < 0:
		return false
	return bool(_processor.call(
		method_name,
		source_effect_id,
		copied_attack_index,
		attacker,
		state,
		[get_attack_interaction_context()],
		get_script()
	))


func _get_selected_option() -> Dictionary:
	return _get_selected_option_from_context(get_attack_interaction_context())


func _get_selected_option_from_context(context: Dictionary) -> Dictionary:
	var selected_raw: Array = context.get(STEP_ID, [])
	if selected_raw.is_empty() or not (selected_raw[0] is Dictionary):
		return {}
	return selected_raw[0]


func _get_selected_source_effect_id(option: Dictionary) -> String:
	var source_card: Variant = option.get("source_card", null)
	if source_card is CardInstance:
		var source_instance := source_card as CardInstance
		if source_instance.card_data != null:
			return str(source_instance.card_data.effect_id)
	return str(option.get("source_effect_id", ""))


func _has_resolved_copied_followup(context: Dictionary) -> bool:
	for key: Variant in context.keys():
		if str(key) != STEP_ID:
			return true
	return false


func _get_copy_source_data(slot: PokemonSlot) -> CardData:
	if slot == null or slot.get_card_data() == null:
		return null
	var card_data := slot.get_card_data()
	if not card_data.is_pokemon():
		return null
	if not _matches_required_name_prefix(card_data):
		return null
	return card_data


func _matches_required_name_prefix(card_data: CardData) -> bool:
	if required_name_prefix == "":
		return true
	var normalized_prefix := _normalize_apostrophe(required_name_prefix)
	for raw_name: Variant in [card_data.name_en, card_data.name, card_data.name_zh]:
		var card_name := str(raw_name)
		if card_name.begins_with(required_name_prefix):
			return true
		if _normalize_apostrophe(card_name).begins_with(normalized_prefix):
			return true
	if required_name_prefix == "N's ":
		for raw_name: Variant in [card_data.name_en, card_data.name, card_data.name_zh]:
			if _is_n_pokemon_name(str(raw_name)):
				return true
		return str(card_data.name_zh).begins_with("N的") or str(card_data.name).begins_with("N的")
	return false


func _normalize_apostrophe(value: String) -> String:
	return value.replace(char(0x2019), "'").replace(char(0x2018), "'")


func _is_n_pokemon_name(value: String) -> bool:
	var normalized := _normalize_apostrophe(value.strip_edges())
	if normalized.begins_with("N's "):
		return true
	if normalized.begins_with("N" + char(0x7684)):
		return true
	return false


func _can_copy_attack(copied_attack: Dictionary) -> bool:
	var attack_name := str(copied_attack.get("name", ""))
	if attack_name in blocked_attack_names:
		return false
	if bool(copied_attack.get("is_vstar_power", false)):
		return false
	return true


func _build_copied_attack_option(
	source_card: CardInstance,
	source_slot: PokemonSlot,
	source_data: CardData,
	copied_attack: Dictionary,
	attack_index: int
) -> Dictionary:
	return {
		"source_card": source_card,
		"source_effect_id": source_data.effect_id,
		"source_zone": SOURCE_ZONE,
		"attack_index": attack_index,
		"attack": copied_attack,
		"source_slot": source_slot,
	}


func _build_copied_attack_action_item(source_data: CardData, copied_attack: Dictionary, copied_cost: String) -> Dictionary:
	var attack_name := CardData.dictionary_display_name(copied_attack)
	var damage_text := str(copied_attack.get("damage", "")).strip_edges()
	var meta := source_data.display_name()
	if damage_text != "":
		meta = "%s  %s" % [source_data.display_name(), damage_text]
	var body := CardData.dictionary_display_text(copied_attack).strip_edges()
	if body == "":
		body = "使用这只%sN的宝可梦的这个招式。" % SOURCE_ZONE_LABEL
	return {
		"type": "attack",
		"kind": "招式",
		"title": attack_name,
		"meta": meta,
		"body": body,
		"cost": copied_cost,
		"enabled": true,
		"reason": "",
	}


func _copy_prompt_title() -> String:
	if required_name_prefix == "N's ":
		return "选择%sN的宝可梦的1个招式" % SOURCE_ZONE_LABEL
	return "选择%s宝可梦的1个招式" % SOURCE_ZONE_LABEL


func get_description() -> String:
	if required_name_prefix == "N's ":
		return "选择自己%sN的宝可梦的1个招式，作为这个招式使用。" % SOURCE_ZONE_LABEL
	return "选择自己%s宝可梦的1个招式，作为这个招式使用。" % SOURCE_ZONE_LABEL
