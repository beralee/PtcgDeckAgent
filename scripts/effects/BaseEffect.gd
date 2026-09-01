class_name BaseEffect
extends RefCounted

const DiscardPileRestriction := preload("res://scripts/effects/DiscardPileRestrictionHelper.gd")
const FieldTransition := preload("res://scripts/engine/BattleFieldTransitionService.gd")
const UcisCompiler := preload("res://scripts/engine/ucis/UcisInteractionCompiler.gd")

var _attack_interaction_context: Dictionary = {}
var _default_attack_index_to_match: int = -1
var _ucis_last_error := ""
var _ucis_last_diagnostic: Dictionary = {}
var _ucis_registration_ids: Array[String] = []

const ATTACK_DAMAGE_COUNTER_PLACEMENT_FLAG := "_attack_damage_counter_effect_slot_ids"
const EMPTY_SEARCH_CONTINUE := "continue"
const EMPTY_SEARCH_VIEW_DECK := "view_deck"
const VISIBLE_SCOPE_OWN_FULL_DECK := "own_full_deck"
const DEFAULT_FULL_LIBRARY_DISABLED_BADGE := "不可选"
const DEFAULT_FULL_LIBRARY_SELECTABLE_LABEL := "可选"
const INTERACTION_SOURCE_KEY := "__interaction_source"
const INTERACTION_INTENTS_KEY := "__interaction_intents"
const INTERACTION_SOURCE_BATTLE_UI := "battle_ui"
const INTERACTION_INTENT_SELECT := "select"
const INTERACTION_INTENT_DECLINE := "decline"
const DELEGATED_ATTACK_CONTEXT_KEY := "__delegated_attack"


enum TargetType {
	NONE,
	OWN_ACTIVE,
	OPP_ACTIVE,
	OWN_BENCH,
	OPP_BENCH,
	OWN_ANY_POKEMON,
	OPP_ANY_POKEMON,
	ANY_POKEMON,
	HAND_CARD,
	DISCARD_CARD,
	ENERGY_ON_POKEMON,
	COIN_FLIP,
	PLAYER_CHOICE,
}


func get_target_type() -> TargetType:
	return TargetType.NONE


func build_ucis_interaction_steps_spec_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_interaction_steps_spec_steps(card, state),
		"interaction"
	)


func build_ucis_preview_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return build_ucis_interaction_steps_spec_steps(card, state)


func get_preview_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_preview_interaction_steps_spec_steps(card, state),
		"preview_interaction"
	)


func get_empty_interaction_message(_card: CardInstance, _state: GameState) -> String:
	return ""


func build_ucis_attack_interaction_steps_spec_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_attack_interaction_steps_spec_steps(card, attack, state),
		"attack_interaction"
	)


func build_ucis_attack_preview_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	return build_ucis_attack_interaction_steps_spec_steps(card, attack, state)


func get_attack_preview_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_attack_preview_interaction_steps_spec_steps(card, attack, state),
		"attack_preview_interaction"
	)


func build_ucis_followup_attack_interaction_steps_spec_steps(
	_card: CardInstance,
	_attack: Dictionary,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_followup_attack_interaction_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_followup_attack_interaction_steps_spec_steps(card, attack, state, resolved_context),
		"followup_attack_interaction"
	)


func build_ucis_followup_granted_attack_interaction_steps_spec_steps(
	_pokemon: PokemonSlot,
	_granted_attack: Dictionary,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_followup_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_followup_granted_attack_interaction_steps_spec_steps(
			pokemon, granted_attack, state, resolved_context
		),
		"followup_granted_attack_interaction"
	)


func build_ucis_followup_interaction_steps_spec_steps(
	_card: CardInstance,
	_state: GameState,
	_resolved_context: Dictionary
) -> Array[Dictionary]:
	return []


func get_followup_interaction_steps(
	card: CardInstance,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_followup_interaction_steps_spec_steps(card, state, resolved_context),
		"followup_interaction"
	)


func get_interaction_context(targets: Array) -> Dictionary:
	if targets.is_empty():
		return {}
	var ctx: Variant = targets[0]
	return ctx.duplicate(false) if ctx is Dictionary else {}


## Effects with mandatory costs or player choices override these validators.
## The processor calls validation before any zone mutation or attack resolution.
func validate_card_interaction(
	_card: CardInstance,
	_targets: Array,
	_state: GameState
) -> Dictionary:
	return interaction_validation_ok()


func validate_attack_interaction(
	_attacker: PokemonSlot,
	_attack_index: int,
	_targets: Array,
	_state: GameState
) -> Dictionary:
	return interaction_validation_ok()


func interaction_validation_ok() -> Dictionary:
	return {"valid": true, "reason": ""}


func interaction_validation_error(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}


func interaction_context_selection(context: Dictionary, step_id: String) -> Array:
	var raw: Variant = context.get(step_id, [])
	return raw if raw is Array else []


func interaction_context_has_explicit_empty_intent(context: Dictionary, step_id: String) -> bool:
	if not context.has(step_id):
		return false
	if str(context.get(INTERACTION_SOURCE_KEY, "")) != INTERACTION_SOURCE_BATTLE_UI:
		# Direct engine/AI callers express an intentional whiff by including the
		# step key with an empty array. Missing and empty remain distinct.
		return true
	var intents_raw: Variant = context.get(INTERACTION_INTENTS_KEY, {})
	if not (intents_raw is Dictionary):
		return false
	return str((intents_raw as Dictionary).get(step_id, "")) == INTERACTION_INTENT_DECLINE


func validate_context_selection(
	context: Dictionary,
	step_id: String,
	legal_items: Array,
	min_select: int,
	max_select: int,
	require_explicit_empty: bool = false,
	ignore_non_legal_items: bool = false
) -> Dictionary:
	if not context.has(step_id):
		return interaction_validation_error("missing interaction step: %s" % step_id)
	var raw: Variant = context.get(step_id)
	if not (raw is Array):
		return interaction_validation_error("interaction step is not an array: %s" % step_id)
	var selected: Array = raw
	var seen: Dictionary = {}
	var legal_selection_count := 0
	for item: Variant in selected:
		if item == null or item not in legal_items:
			if ignore_non_legal_items:
				continue
			return interaction_validation_error("interaction step %s contains a stale or illegal selection" % step_id)
		var identity: Variant = item
		if item is CardInstance:
			identity = "card:%d" % (item as CardInstance).instance_id
		elif item is PokemonSlot:
			identity = "slot:%d" % (item as PokemonSlot).get_instance_id()
		if seen.has(identity):
			return interaction_validation_error("interaction step %s contains a duplicate selection" % step_id)
		seen[identity] = true
		legal_selection_count += 1
	if legal_selection_count < min_select:
		return interaction_validation_error("interaction step %s requires at least %d selection(s)" % [step_id, min_select])
	if max_select >= 0 and legal_selection_count > max_select:
		return interaction_validation_error("interaction step %s allows at most %d selection(s)" % [step_id, max_select])
	if legal_selection_count == 0 and require_explicit_empty and not interaction_context_has_explicit_empty_intent(context, step_id):
		return interaction_validation_error("interaction step %s requires an explicit decline" % step_id)
	return interaction_validation_ok()


func _draw_cards_with_log(
	state: GameState,
	player_index: int,
	count: int,
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null:
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("draw_cards_with_log"):
		return draw_processor.call("draw_cards_with_log", player_index, count, state, source_card, source_kind)
	if count <= 0:
		return []
	return state.players[player_index].draw_cards(count)


func _discard_cards_from_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("discard_cards_from_hand_with_log"):
		return draw_processor.call("discard_cards_from_hand_with_log", player_index, cards, state, source_card, source_kind)
	var player: PlayerState = state.players[player_index]
	var discarded: Array[CardInstance] = []
	for card: CardInstance in cards:
		if card == null or not (card in player.hand):
			continue
		player.remove_from_hand(card)
		player.discard_card(card)
		discarded.append(card)
	return discarded


func _record_attack_effect_discarded_attached_energy(attacker: PokemonSlot, energy: CardInstance, state: GameState) -> void:
	if state == null:
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("record_attack_effect_discarded_attached_energy"):
		processor.call("record_attack_effect_discarded_attached_energy", attacker, energy, state)


func _move_public_cards_to_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = "",
	public_result_kind: String = "search_to_hand",
	public_result_labels: Array[String] = []
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	var draw_processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if draw_processor != null and draw_processor.has_method("move_public_cards_to_hand_with_log"):
		return draw_processor.call(
			"move_public_cards_to_hand_with_log",
			player_index,
			cards,
			state,
			source_card,
			source_kind,
			public_result_kind,
			public_result_labels
		)
	var player: PlayerState = state.players[player_index]
	var moved: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for card: CardInstance in cards:
		if card == null or seen_ids.has(card.instance_id) or not (card in player.deck):
			continue
		seen_ids[card.instance_id] = true
		player.deck.erase(card)
		card.face_up = true
		player.hand.append(card)
		moved.append(card)
	return moved


func _move_discard_cards_to_hand_with_log(
	state: GameState,
	player_index: int,
	cards: Array[CardInstance],
	source_card: CardInstance = null,
	source_kind: String = ""
) -> Array[CardInstance]:
	if state == null or cards.is_empty():
		return []
	if DiscardToHandBlockHelper.is_discard_to_hand_blocked(player_index, state, source_kind):
		return []
	var player: PlayerState = state.players[player_index]
	var moved: Array[CardInstance] = []
	var seen_ids: Dictionary = {}
	for card: CardInstance in cards:
		if (
			card == null
			or seen_ids.has(card.instance_id)
			or not (card in player.discard_pile)
			or not DiscardPileRestriction.can_move_to_hand_or_deck(card)
		):
			continue
		seen_ids[card.instance_id] = true
		player.discard_pile.erase(card)
		card.face_up = true
		player.hand.append(card)
		moved.append(card)
	return moved


func _switch_active_with_bench(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String,
	preserve_incoming_bench_index: bool = false
) -> bool:
	var placement := (
		FieldTransition.BENCH_PLACEMENT_REPLACE_INCOMING
		if preserve_incoming_bench_index
		else FieldTransition.BENCH_PLACEMENT_APPEND
	)
	return FieldTransition.switch_active_with_bench(
		state,
		player_index,
		incoming,
		reason,
		placement
	)


func _promote_from_bench(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	return FieldTransition.promote_from_bench(state, player_index, incoming, reason)


func _replace_active_with_newcomer(
	state: GameState,
	player_index: int,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	return FieldTransition.replace_active_with_newcomer(state, player_index, incoming, reason)


func _remove_active(
	state: GameState,
	player_index: int,
	outgoing: PokemonSlot,
	reason: String
) -> bool:
	return FieldTransition.remove_active(state, player_index, outgoing, reason)


func _remove_active_and_promote(
	state: GameState,
	player_index: int,
	outgoing: PokemonSlot,
	incoming: PokemonSlot,
	reason: String
) -> bool:
	return FieldTransition.remove_active_and_promote(
		state,
		player_index,
		outgoing,
		incoming,
		reason
	)


func set_attack_interaction_context(targets: Array) -> void:
	_attack_interaction_context = get_interaction_context(targets)


func get_attack_interaction_context() -> Dictionary:
	return _attack_interaction_context


func clear_attack_interaction_context() -> void:
	_attack_interaction_context.clear()


func _apply_special_status(slot: PokemonSlot, status_name: String, state: GameState) -> bool:
	if slot == null or status_name.strip_edges() == "":
		return false
	if _special_status_prevented(slot, state):
		slot.clear_all_status()
		return false
	if _special_status_prevented(slot, state, status_name):
		slot.set_status(status_name, false)
		return false
	slot.set_status(status_name, true)
	return true


func _special_status_prevented(slot: PokemonSlot, state: GameState, status_name: String = "") -> bool:
	if slot == null or state == null:
		return false
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor != null and processor.has_method("prevents_special_status"):
		return bool(processor.call("prevents_special_status", slot, state, status_name))
	return EffectFestivalGrounds.prevents_special_status(slot, state) or EffectToolAncientBoosterEnergyCapsule.protects(slot, state)


func _calculate_attack_target_damage(
	attacker: PokemonSlot,
	target: PokemonSlot,
	damage_amount: int,
	state: GameState
) -> int:
	if attacker == null or target == null or state == null or damage_amount <= 0:
		return 0
	if not _is_opponent_active_target(attacker, target, state):
		return damage_amount
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
	if processor == null or not processor.has_method("get_attacker_modifier"):
		return damage_amount
	var pseudo_attack := {"damage": str(damage_amount)}
	var attacker_modifier: int = int(processor.call("get_attacker_modifier", attacker, state, target))
	var defender_modifier: int = 0
	if processor.has_method("get_defender_modifier"):
		defender_modifier = int(processor.call("get_defender_modifier", target, state, attacker))
	return DamageCalculator.new().calculate_damage(
		attacker,
		target,
		pseudo_attack,
		state,
		0,
		attacker_modifier,
		defender_modifier
	)


func _mark_attack_damage_counter_placement(target: PokemonSlot, state: GameState) -> void:
	if target == null or state == null:
		return
	var raw_marker: Variant = state.shared_turn_flags.get(ATTACK_DAMAGE_COUNTER_PLACEMENT_FLAG, {})
	var marker: Dictionary = raw_marker if raw_marker is Dictionary else {}
	marker[int(target.get_instance_id())] = true
	state.shared_turn_flags[ATTACK_DAMAGE_COUNTER_PLACEMENT_FLAG] = marker


func _is_opponent_active_target(attacker: PokemonSlot, target: PokemonSlot, state: GameState) -> bool:
	var top: CardInstance = attacker.get_top_card() if attacker != null else null
	if top == null or top.owner_index < 0 or top.owner_index >= state.players.size():
		return false
	var opponent_index: int = 1 - top.owner_index
	if opponent_index < 0 or opponent_index >= state.players.size():
		return false
	return target == state.players[opponent_index].active_pokemon


func bind_default_attack_index(attack_index: int) -> void:
	_default_attack_index_to_match = attack_index


func applies_to_attack_index(attack_index: int) -> bool:
	return _default_attack_index_to_match < 0 or _default_attack_index_to_match == attack_index


func build_full_library_search_step(
	step_id: String,
	title: String,
	visible_cards: Array,
	legal_items: Array,
	visible_scope: String,
	min_select: int = 1,
	max_select: int = 1,
	options: Dictionary = {}
) -> Dictionary:
	var resolved_scope := visible_scope.strip_edges()
	if resolved_scope == "":
		push_error("build_full_library_search_step requires an explicit visible_scope")

	var card_indices: Array[int] = []
	for card: Variant in visible_cards:
		card_indices.append(legal_items.find(card))

	var legal_labels: Array[String] = []
	for item: Variant in legal_items:
		legal_labels.append(_full_library_search_label_for_item(item))

	var disabled_badge := str(options.get("card_disabled_badge", DEFAULT_FULL_LIBRARY_DISABLED_BADGE))
	var selectable_label := str(options.get("selectable_label", DEFAULT_FULL_LIBRARY_SELECTABLE_LABEL))
	var disabled_label := str(options.get("disabled_label", disabled_badge))
	var choice_labels: Array[String] = []
	if options.has("choice_labels"):
		for label: Variant in options.get("choice_labels", []):
			choice_labels.append(str(label))
	else:
		for i: int in visible_cards.size():
			var label := _full_library_search_label_for_item(visible_cards[i])
			var suffix := selectable_label if card_indices[i] >= 0 else disabled_label
			choice_labels.append("%s - %s" % [label, suffix])

	var can_whiff_hidden_search: bool = \
		resolved_scope == VISIBLE_SCOPE_OWN_FULL_DECK \
		and bool(options.get("allow_hidden_search_whiff", true))
	var resolved_min_select: int = 0 if can_whiff_hidden_search else min_select
	var resolved_force_confirm: bool = bool(options.get("force_confirm", false))
	if can_whiff_hidden_search and max_select <= 1:
		resolved_force_confirm = true

	var step := {
		"id": step_id,
		"title": title,
		"items": legal_items.duplicate(),
		"labels": legal_labels,
		"presentation": "cards",
		"card_items": visible_cards.duplicate(),
		"card_indices": card_indices,
		"choice_labels": choice_labels,
		"visible_scope": resolved_scope,
		"card_disabled_badge": disabled_badge,
		"card_selectable_hint": str(options.get("card_selectable_hint", selectable_label)),
		"min_select": resolved_min_select,
		"max_select": max_select,
		"allow_cancel": bool(options.get("allow_cancel", true)),
		"visible_count": visible_cards.size(),
		"selectable_count": legal_items.size(),
	}
	if can_whiff_hidden_search:
		step["hidden_search_can_whiff"] = true
	if options.has("show_selectable_hints"):
		step["show_selectable_hints"] = bool(options.get("show_selectable_hints", false))
	if options.has("card_click_selectable"):
		step["card_click_selectable"] = bool(options.get("card_click_selectable", true))
	if options.has("utility_actions"):
		step["utility_actions"] = (options.get("utility_actions", []) as Array).duplicate(true)
	if options.has("prompt_type"):
		step["prompt_type"] = str(options.get("prompt_type", ""))
	if options.has("force_confirm") or resolved_force_confirm:
		step["force_confirm"] = resolved_force_confirm
	# Card code names the semantic destination; the UCIS registry exclusively
	# owns the corresponding raw SelectType/Context/OptionType values.
	step["ucis_context_name"] = str(options.get("ucis_context_name", "TO_HAND"))
	step["ucis_option_type_name"] = str(options.get("ucis_option_type_name", "CARD"))
	return step


func _full_library_search_label_for_item(item: Variant) -> String:
	if item is CardInstance:
		var card: CardInstance = item
		return card.card_data.name if card.card_data != null else ""
	if item is CardData:
		return (item as CardData).name
	if item is PokemonSlot:
		return (item as PokemonSlot).get_pokemon_name()
	if item is Dictionary:
		var entry: Dictionary = item
		for key: String in ["card_name", "pokemon_name", "name", "title"]:
			var text := str(entry.get(key, "")).strip_edges()
			if text != "":
				return text
	return str(item).strip_edges()


func build_card_assignment_step(
	step_id: String,
	title: String,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	allow_cancel: bool = true
) -> Dictionary:
	return {
		"id": step_id,
		"title": title,
		"ui_mode": "card_assignment",
		"source_items": source_items,
		"source_labels": source_labels,
		"target_items": target_items,
		"target_labels": target_labels,
		"min_select": min_assignments,
		"max_select": max_assignments,
		"allow_cancel": allow_cancel,
	}


func build_full_library_card_assignment_step(
	step_id: String,
	title: String,
	visible_source_cards: Array,
	source_items: Array,
	source_labels: Array[String],
	target_items: Array,
	target_labels: Array[String],
	min_assignments: int,
	max_assignments: int,
	visible_scope: String,
	allow_cancel: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	var step := build_card_assignment_step(
		step_id,
		title,
		source_items,
		source_labels,
		target_items,
		target_labels,
		min_assignments,
		max_assignments,
		allow_cancel
	)
	return add_full_library_source_metadata_to_assignment_step(
		step,
		visible_source_cards,
		source_items,
		visible_scope,
		options
	)


func add_full_library_source_metadata_to_assignment_step(
	step: Dictionary,
	visible_source_cards: Array,
	source_items: Array,
	visible_scope: String,
	options: Dictionary = {}
) -> Dictionary:
	var source_step := build_full_library_search_step(
		str(step.get("id", "")),
		str(step.get("title", "")),
		visible_source_cards,
		source_items,
		visible_scope,
		int(step.get("min_select", 0)),
		int(step.get("max_select", source_items.size())),
		options
	)
	step["source_card_items"] = (source_step.get("card_items", []) as Array).duplicate()
	step["source_card_indices"] = (source_step.get("card_indices", []) as Array).duplicate()
	step["source_choice_labels"] = (source_step.get("choice_labels", []) as Array).duplicate()
	step["source_visible_scope"] = str(source_step.get("visible_scope", ""))
	step["source_card_disabled_badge"] = str(source_step.get("card_disabled_badge", ""))
	step["source_card_selectable_hint"] = str(source_step.get("card_selectable_hint", ""))
	step["source_visible_count"] = int(source_step.get("visible_count", visible_source_cards.size()))
	step["source_selectable_count"] = int(source_step.get("selectable_count", source_items.size()))
	if not step.has("visible_scope"):
		step["visible_scope"] = str(source_step.get("visible_scope", ""))
	return step


func get_ucis_effect_spec() -> Dictionary:
	var script: Script = get_script()
	var script_path := _ucis_effect_ref(script)
	var source := str(script.source_code) if script != null else ""
	var builder_names := UcisCompiler.builder_entrypoints_for_source(source)
	var capability_ids := UcisCompiler.declared_capabilities_for_source(source, builder_names)
	var source_context := HashingContext.new()
	source_context.start(HashingContext.HASH_SHA256)
	# HashingContext rejects an empty byte sequence. Built-in automatic effects
	# use their stable effect reference as the source identity.
	var source_identity := source if not source.is_empty() else script_path
	source_context.update(source_identity.to_utf8_buffer())
	var source_hash := source_context.finish().hex_encode().to_upper()
	return {
		"schema_version": 1,
		"effect_ref": script_path,
		"resolution_kind": "interactive" if not builder_names.is_empty() else "automatic_resolution",
		"program_kind": capability_ids[0] if not capability_ids.is_empty() else "automatic_resolution",
		"capability_ids": capability_ids,
		"builder_entrypoints": builder_names,
		"programs": UcisCompiler.declared_program_templates(
			script_path,
			source_hash,
			builder_names,
			capability_ids
		),
		"chooser_rule": "engine_current_chooser",
		"visibility_rule": "acting_seat_public_only",
		"lifecycle_anchor": "effect_runtime_checkpoint",
		"continuation_rule": "ordered_steps",
		"stop_rule": "program_complete",
		"information_checkpoints": ["fresh_reobserve"],
		"contract_generation": 2,
		"compiler_generation": 1,
		"source_hash": source_hash,
	}


func bind_ucis_registration_id(effect_id: String) -> void:
	var normalized := effect_id.strip_edges()
	if not normalized.is_empty() and normalized not in _ucis_registration_ids:
		_ucis_registration_ids.append(normalized)
		_ucis_registration_ids.sort()


func get_ucis_registration_ids() -> Array[String]:
	return _ucis_registration_ids.duplicate()


func _ucis_effect_ref(script: Script) -> String:
	if not _ucis_registration_ids.is_empty():
		return "effect_id:%s" % ",".join(_ucis_registration_ids)
	if script == null:
		return "builtin:BaseEffect"
	var resource_path := str(script.resource_path).strip_edges()
	if not resource_path.is_empty():
		return resource_path
	# Inner GDScript classes have no resource_path of their own. Bind them to a
	# deterministic source digest rather than an Object ID or display name.
	var source := str(script.source_code)
	if source.is_empty():
		return "inline:BaseEffect"
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(source.to_utf8_buffer())
	return "inline_script_sha256:%s" % context.finish().hex_encode().to_upper()


func get_ucis_last_error() -> String:
	return _ucis_last_error


func get_ucis_last_diagnostic() -> Dictionary:
	return _ucis_last_diagnostic.duplicate(true)


func _compile_ucis_steps(raw_steps: Array, entrypoint: String) -> Array[Dictionary]:
	_ucis_last_error = ""
	_ucis_last_diagnostic = {}
	if raw_steps.is_empty():
		return []
	var compiled: Dictionary = UcisCompiler.compile_steps(raw_steps, entrypoint, self)
	if bool(compiled.get("ok", false)):
		var result: Array[Dictionary] = []
		for step_value: Variant in compiled.get("steps", []):
			if not step_value is Dictionary:
				_ucis_last_error = "ucis_compiler_return_shape_invalid"
				break
			result.append(step_value as Dictionary)
		if _ucis_last_error.is_empty() and result.size() == raw_steps.size():
			return result
	elif _ucis_last_error.is_empty():
		_ucis_last_error = str(compiled.get("error_code", "unsupported_interaction_shape"))
	_ucis_last_diagnostic = {
		"effect_ref": _ucis_effect_ref(get_script()),
		"entrypoint": entrypoint,
		"error_code": _ucis_last_error,
	}
	push_error("UCIS rejected %s effect=%s: %s" % [
		entrypoint,
		_ucis_last_diagnostic.effect_ref,
		_ucis_last_error,
	])
	# A rejected interactive shape must not be mistaken for an automatic effect.
	# This mandatory empty sentinel prevents any engine mutation and makes both
	# live and headless owners surface the stable unsupported error.
	return [{
		"id": "ucis_unsupported_interaction",
		"items": [],
		"labels": [],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"ucis_unsupported_error": _ucis_last_error,
		"ucis_unsupported_diagnostic": _ucis_last_diagnostic.duplicate(true),
		"__ucis": {
			"ucis_generation": 1,
			"step_id": "ucis_unsupported_interaction",
			"primitive": "ChooseCardSet",
			"select_type_raw": 1,
			"context_raw": 25,
			"option_type_raw": 3,
			"quantity_encoding": "result_list_length",
			"next_checkpoint_rule": "fresh_reobserve",
			"unsupported_if": [_ucis_last_error],
		},
	}]


func can_execute(_card: CardInstance, _state: GameState) -> bool:
	return true


func get_unusable_reason(_card: CardInstance, _state: GameState) -> String:
	return ""


func can_headless_execute(card: CardInstance, state: GameState) -> bool:
	return can_execute(card, state)


func execute(_card: CardInstance, _targets: Array, _state: GameState) -> void:
	pass


func build_ucis_on_play_interaction_steps_spec_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return []


func get_on_play_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_on_play_interaction_steps_spec_steps(card, state),
		"on_play_interaction"
	)


func build_ucis_granted_attack_interaction_steps_spec_steps(
	_pokemon: PokemonSlot,
	_granted_attack: Dictionary,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_granted_attack_interaction_steps(
	pokemon: PokemonSlot,
	granted_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_granted_attack_interaction_steps_spec_steps(pokemon, granted_attack, state),
		"granted_attack_interaction"
	)


func build_ucis_knockout_interaction_steps_spec_steps(
	_holder: PokemonSlot,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_knockout_interaction_steps(holder: PokemonSlot, state: GameState) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_knockout_interaction_steps_spec_steps(holder, state),
		"knockout_interaction"
	)


func build_ucis_end_turn_interaction_steps_spec_steps(
	_slot: PokemonSlot,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_end_turn_interaction_steps(slot: PokemonSlot, state: GameState) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_end_turn_interaction_steps_spec_steps(slot, state),
		"end_turn_interaction"
	)


func build_ucis_reactive_interaction_steps_spec_steps(
	_source: PokemonSlot,
	_attacker: PokemonSlot,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_reactive_interaction_steps(
	source: PokemonSlot,
	attacker: PokemonSlot,
	state: GameState
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_reactive_interaction_steps_spec_steps(source, attacker, state),
		"reactive_interaction"
	)


func build_ucis_trigger_interaction_steps_spec_steps(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_state: GameState
) -> Array[Dictionary]:
	return []


func get_trigger_interaction_steps(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	state: GameState
) -> Array[Dictionary]:
	return _compile_ucis_steps(
		build_ucis_trigger_interaction_steps_spec_steps(attacker, defender, state),
		"trigger_interaction"
	)


func execute_on_play(_card: CardInstance, _state: GameState, _targets: Array = []) -> void:
	pass


func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
	return false


func get_stadium_action_unusable_reason(_card: CardInstance, _state: GameState) -> String:
	return ""


func get_ability_unusable_reason(_pokemon: PokemonSlot, _state: GameState) -> String:
	return ""


func execute_attack(
	_attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	_state: GameState
) -> void:
	pass


func execute_ability(
	_pokemon: PokemonSlot,
	_ability_index: int,
	_targets: Array,
	_state: GameState
) -> void:
	pass


func get_description() -> String:
	return ""


func build_empty_search_resolution_step(title: String) -> Dictionary:
	return build_empty_search_resolution_step_with_view_label(title, "查看牌库")


func build_empty_search_resolution_step_with_view_label(title: String, view_label: String) -> Dictionary:
	return {
		"id": "empty_search_resolution",
		"title": title,
		"items": [true, false],
		"labels": ["继续消耗", view_label],
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"ucis_context_name": "ACTIVATE",
	}


func should_preview_empty_search_deck(resolved_context: Dictionary) -> bool:
	var selected_raw: Array = resolved_context.get("empty_search_resolution", [])
	if selected_raw.is_empty():
		return false
	var selected: Variant = selected_raw[0]
	if typeof(selected) == TYPE_BOOL:
		return not bool(selected)
	return str(selected) == EMPTY_SEARCH_VIEW_DECK


func has_resolved_non_internal_interaction_step(
	context: Dictionary,
	ignored_step_ids: Array = []
) -> bool:
	for key: Variant in context.keys():
		var key_name := str(key)
		if key_name.begins_with("__") or key_name in ignored_step_ids:
			continue
		return true
	return false


func build_empty_dialog_utility_action(
	label: String,
	intent: String = INTERACTION_INTENT_SELECT
) -> Dictionary:
	return {
		"label": label,
		"selected_indices": [],
		"intent": intent,
	}


func build_readonly_card_preview_step(
	title: String,
	cards: Array[CardInstance],
	close_label: String = "关闭并继续"
) -> Dictionary:
	var labels: Array[String] = []
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			labels.append("")
			continue
		if card.card_data.is_pokemon():
			labels.append("%s (HP %d)" % [card.card_data.name, card.card_data.hp])
		else:
			labels.append(card.card_data.name)
	return {
		"id": "empty_search_view_deck",
		"title": title,
		"items": cards.duplicate(),
		"labels": labels,
		"min_select": 0,
		"max_select": 0,
		"allow_cancel": false,
		"presentation": "cards",
		"utility_actions": [build_empty_dialog_utility_action(close_label)],
	}


func build_readonly_deck_preview_step(title: String, deck_cards: Array[CardInstance]) -> Dictionary:
	return build_readonly_card_preview_step(title, deck_cards)


func build_attached_card_groups(player: PlayerState, card_items: Array) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if player == null:
		return groups
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		var group_indices: Array[int] = []
		for i: int in card_items.size():
			var item: Variant = card_items[i]
			if not (item is CardInstance):
				continue
			var card_item := item as CardInstance
			if card_item in slot.attached_energy or slot.attached_tool == card_item:
				group_indices.append(i)
		if not group_indices.is_empty():
			groups.append({
				"slot": slot,
				"card_indices": group_indices,
				"energy_indices": group_indices,
			})
	return groups
