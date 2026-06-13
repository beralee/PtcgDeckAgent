## Search basic Energy from the deck or top cards and attach to matching Pokemon.
class_name AttackSearchAndAttach
extends BaseEffect

const ASSIGNMENT_STEP_ID := "energy_assignments"

var energy_type: String = ""
var attach_count: int = 3
var search_mode: String = "deck_search"
var top_n_count: int = 5
var attach_to: String = "any"
var target_tag: String = ""
var attack_index_to_match: int = -1
var max_assignments_per_target: int = 0
var single_target_only: bool = false


func _init(
	e_type: String = "",
	count: int = 3,
	mode: String = "deck_search",
	top_n: int = 5,
	a_to: String = "any",
	required_tag: String = "",
	per_target_limit: int = 0
) -> void:
	energy_type = e_type
	attach_count = count
	search_mode = mode
	top_n_count = top_n
	attach_to = a_to
	target_tag = required_tag
	max_assignments_per_target = per_target_limit


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match < 0 or attack_index_to_match == attack_index


func get_attack_interaction_steps(
	card: CardInstance,
	_attack: Dictionary,
	state: GameState
) -> Array[Dictionary]:
	if card == null:
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = _find_owner_slot(card, player)
	if attacker == null:
		return []

	var energy_items: Array[CardInstance] = _collect_candidate_energy_cards(player)
	if energy_items.is_empty():
		return []

	var target_items: Array = _collect_attach_targets(attacker, player, false)
	if target_items.is_empty():
		return []

	var energy_labels: Array[String] = []
	for energy_card: CardInstance in energy_items:
		energy_labels.append(energy_card.card_data.name)

	var target_labels: Array[String] = []
	for target_slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			target_slot.get_pokemon_name(),
			target_slot.get_remaining_hp(),
			target_slot.get_max_hp(),
		])

	var max_assignments: int = _get_max_assignment_count(energy_items.size(), target_items.size())
	if search_mode == "deck_search":
		var deck_step := build_full_library_card_assignment_step(
			ASSIGNMENT_STEP_ID,
			"选择要附着的能量并分配给目标宝可梦",
			player.deck,
			energy_items,
			energy_labels,
			target_items,
			target_labels,
			0,
			max_assignments,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			true
		)
		_apply_assignment_limits(deck_step)
		return [deck_step]

	var step := build_card_assignment_step(
		ASSIGNMENT_STEP_ID,
		"选择要附着的能量并分配给目标宝可梦",
		energy_items,
		energy_labels,
		target_items,
		target_labels,
		0,
		max_assignments,
		true
	)
	_apply_assignment_limits(step)
	return [step]


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top_card: CardInstance = attacker.get_top_card()
	if top_card == null:
		return
	var pi: int = top_card.owner_index
	var player: PlayerState = state.players[pi]

	var candidates: Array[CardInstance] = _collect_candidate_energy_cards(player)
	if candidates.is_empty():
		player.shuffle_deck()
		return

	var ctx: Dictionary = get_attack_interaction_context()
	var assignments: Array[Dictionary] = _resolve_assignments(attacker, player, candidates, ctx)
	if assignments.is_empty() and ctx.has(ASSIGNMENT_STEP_ID):
		player.shuffle_deck()
		return
	if assignments.is_empty():
		assignments = _build_fallback_assignments(attacker, player, candidates)
	if assignments.is_empty():
		player.shuffle_deck()
		return

	for assignment: Dictionary in assignments:
		var energy_card: CardInstance = assignment.get("source")
		var target_slot: PokemonSlot = assignment.get("target")
		if energy_card == null or target_slot == null:
			continue
		var deck_idx: int = player.deck.find(energy_card)
		if deck_idx >= 0:
			player.deck.remove_at(deck_idx)
		energy_card.face_up = true
		target_slot.attached_energy.append(energy_card)

	player.shuffle_deck()


func _is_matching_basic_energy(card: CardInstance) -> bool:
	var cd: CardData = card.card_data
	if cd == null or cd.card_type != "Basic Energy":
		return false
	if energy_type == "":
		return true
	return cd.energy_provides == energy_type or cd.energy_type == energy_type


func _collect_candidate_energy_cards(player: PlayerState) -> Array[CardInstance]:
	var candidates: Array[CardInstance] = []
	if player == null:
		return candidates
	if search_mode == "top_n":
		var look_count: int = mini(top_n_count, player.deck.size())
		for idx: int in look_count:
			var card: CardInstance = player.deck[idx]
			if _is_matching_basic_energy(card):
				candidates.append(card)
	else:
		for card: CardInstance in player.deck:
			if _is_matching_basic_energy(card):
				candidates.append(card)
	return candidates


func _collect_attach_targets(
	attacker: PokemonSlot,
	player: PlayerState,
	limit_to_attach_count: bool
) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	match attach_to:
		"self":
			if _matches_target_tag(attacker):
				result.append(attacker)
		"v_only":
			for slot: PokemonSlot in player.bench:
				if limit_to_attach_count and result.size() >= attach_count:
					break
				if _is_v_pokemon_target(slot) and _matches_target_tag(slot):
					result.append(slot)
			if not limit_to_attach_count or result.size() < attach_count:
				if _is_v_pokemon_target(attacker) and _matches_target_tag(attacker):
					result.append(attacker)
		"bench":
			for slot: PokemonSlot in player.bench:
				if limit_to_attach_count and result.size() >= attach_count:
					break
				if _matches_target_tag(slot):
					result.append(slot)
		_:
			for slot: PokemonSlot in player.bench:
				if limit_to_attach_count and result.size() >= attach_count:
					break
				if _matches_target_tag(slot):
					result.append(slot)
			if (not limit_to_attach_count or result.size() < attach_count) and _matches_target_tag(attacker):
				result.append(attacker)
	return result


func _resolve_assignments(
	attacker: PokemonSlot,
	player: PlayerState,
	candidates: Array[CardInstance],
	ctx: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var selected_assignments: Array = ctx.get(ASSIGNMENT_STEP_ID, [])
	var has_explicit_assignments: bool = ctx.has(ASSIGNMENT_STEP_ID)
	var used_sources: Array[CardInstance] = []
	var target_assignment_counts: Dictionary = {}
	var valid_targets: Array[PokemonSlot] = _collect_attach_targets(attacker, player, false)
	var max_assignments: int = _get_max_assignment_count(candidates.size(), valid_targets.size())
	var locked_target: PokemonSlot = null

	for entry: Variant in selected_assignments:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source")
		var target: Variant = assignment.get("target")
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue

		var source_card: CardInstance = source as CardInstance
		var target_slot: PokemonSlot = target as PokemonSlot
		if source_card not in candidates:
			continue
		if target_slot not in valid_targets:
			continue
		if source_card in used_sources:
			continue
		if single_target_only and locked_target != null and target_slot != locked_target:
			continue
		var target_key: int = target_slot.get_instance_id()
		var target_count: int = int(target_assignment_counts.get(target_key, 0))
		if max_assignments_per_target > 0 and target_count >= max_assignments_per_target:
			continue

		used_sources.append(source_card)
		if single_target_only and locked_target == null:
			locked_target = target_slot
		if max_assignments_per_target > 0:
			target_assignment_counts[target_key] = target_count + 1
		result.append({
			"source": source_card,
			"target": target_slot,
		})
		if result.size() >= max_assignments:
			break

	if not result.is_empty() or has_explicit_assignments:
		return result
	return []


func _build_fallback_assignments(
	attacker: PokemonSlot,
	player: PlayerState,
	candidates: Array[CardInstance]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var fallback_targets: Array[PokemonSlot] = _collect_attach_targets(attacker, player, true)
	if fallback_targets.is_empty():
		return result

	var max_assignments: int = _get_max_assignment_count(candidates.size(), fallback_targets.size())
	for idx: int in max_assignments:
		var target_index: int = mini(idx, fallback_targets.size() - 1)
		if single_target_only:
			target_index = 0
		elif max_assignments_per_target > 0:
			target_index = int(idx / max_assignments_per_target)
		result.append({
			"source": candidates[idx],
			"target": fallback_targets[target_index],
		})
	return result


func _get_max_assignment_count(source_count: int, target_count: int) -> int:
	var result: int = mini(attach_count, source_count)
	if target_count <= 0:
		return 0
	if single_target_only and max_assignments_per_target > 0:
		result = mini(result, max_assignments_per_target)
	elif max_assignments_per_target > 0:
		result = mini(result, target_count * max_assignments_per_target)
	return result


func _apply_assignment_limits(step: Dictionary) -> void:
	if max_assignments_per_target > 0:
		step["max_assignments_per_target"] = max_assignments_per_target
	if single_target_only:
		step["single_target_only"] = true


func _find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	if card == null or player == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


func _matches_target_tag(slot: PokemonSlot) -> bool:
	if target_tag == "":
		return true
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.has_tag(target_tag)


func _is_v_pokemon_target(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd: CardData = slot.get_card_data()
	if cd == null:
		return false
	return cd.mechanic in ["V", "VSTAR", "VMAX"]


func get_description() -> String:
	var type_str := energy_type if energy_type != "" else "basic"
	var mode_str := "from the top %d cards" % top_n_count if search_mode == "top_n" else "from the deck"
	var target_str := "your Pokemon"
	match attach_to:
		"self":
			target_str = "this Pokemon"
		"v_only":
			target_str = "your V Pokemon"
		"bench":
			target_str = "your Benched Pokemon"
	if target_tag != "":
		target_str = "%s with %s" % [target_str, target_tag]
	return "Attach up to %d %s Energy %s to %s." % [attach_count, type_str, mode_str, target_str]
