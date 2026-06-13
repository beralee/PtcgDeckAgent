class_name AttackMoveOwnDamageCountersToOpponent
extends BaseEffect

const SOURCE_STEP_ID := "cresselia_damage_sources"
const TARGET_STEP_ID := "cresselia_damage_target"

var damage_per_pokemon: int = 20
var attack_index_to_match: int = -1


func _init(amount: int = 20, match_attack_index: int = -1) -> void:
	damage_per_pokemon = amount
	attack_index_to_match = match_attack_index


func applies_to_attack_index(index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == index


func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = []
	var source_labels: Array[String] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.damage_counters <= 0:
			continue
		source_items.append(slot)
		source_labels.append("%s (%d个伤害指示物)" % [slot.get_pokemon_name(), slot.damage_counters / 10])
	if source_items.is_empty():
		return []
	return [{
		"id": SOURCE_STEP_ID,
		"title": "选择要转移伤害指示物的己方宝可梦",
		"items": source_items,
		"labels": source_labels,
		"min_select": source_items.size(),
		"max_select": source_items.size(),
		"requires_followup_interaction": true,
		"allow_cancel": true,
	}]


func get_followup_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	var player: PlayerState = state.players[card.owner_index]
	var selected_sources: Array[PokemonSlot] = _resolve_sources(player, resolved_context)
	if selected_sources.is_empty():
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var items: Array = []
	var labels: Array[String] = []
	for slot: PokemonSlot in opponent.get_all_pokemon():
		items.append(slot)
		labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
	if items.is_empty():
		return []
	return [{
		"id": TARGET_STEP_ID,
		"title": "选择放置伤害指示物的对手宝可梦",
		"items": items,
		"labels": labels,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": true,
	}]


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, state: GameState) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_sources: Array[PokemonSlot] = _resolve_sources(player, ctx)
	if selected_sources.is_empty():
		return
	var target: PokemonSlot = _resolve_target(opponent)
	if target == null:
		return
	if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
		return
	var moved_total: int = 0
	for slot: PokemonSlot in selected_sources:
		var moved: int = mini(damage_per_pokemon, (slot.damage_counters / 10) * 10)
		if moved <= 0:
			continue
		slot.damage_counters -= moved
		moved_total += moved
	target.damage_counters += moved_total
	if moved_total > 0:
		_mark_attack_damage_counter_placement(target, state)


func _resolve_target(opponent: PlayerState) -> PokemonSlot:
	var ctx: Dictionary = get_attack_interaction_context()
	var selected_raw: Array = ctx.get(TARGET_STEP_ID, [])
	if not selected_raw.is_empty() and selected_raw[0] is PokemonSlot:
		var selected: PokemonSlot = selected_raw[0]
		if selected in opponent.get_all_pokemon():
			return selected
	var all_targets: Array[PokemonSlot] = opponent.get_all_pokemon()
	return all_targets[0] if not all_targets.is_empty() else null


func _resolve_sources(player: PlayerState, ctx: Dictionary) -> Array[PokemonSlot]:
	var legal_sources: Array[PokemonSlot] = []
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot.damage_counters > 0:
			legal_sources.append(slot)
	if not ctx.has(SOURCE_STEP_ID):
		return legal_sources
	var selected_raw: Array = ctx.get(SOURCE_STEP_ID, [])
	var selected_sources: Array[PokemonSlot] = []
	for raw: Variant in selected_raw:
		if raw is PokemonSlot:
			var slot: PokemonSlot = raw
			if slot in legal_sources and not (slot in selected_sources):
				selected_sources.append(slot)
	return selected_sources
