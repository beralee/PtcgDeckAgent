class_name DeckTrainingGoalEvaluator
extends RefCounted


const GOAL_PRIZES := "prizes"
const GOAL_TARGET_KNOCKOUTS := "target_knockouts"
const GOAL_COMPOUND := "compound"

const INVARIANT_NOT_LOST := "not_lost"
const INVARIANT_PRESERVE_ANY := "preserve_any"
const INVARIANT_HANDOFF_ATTACKER := "handoff_attacker"
const INVARIANT_MIN_DECK_CARDS := "min_deck_cards"
const INVARIANT_MIN_OPEN_BENCH_SLOTS := "min_open_bench_slots"
const INVARIANT_OPPONENT_PRIZES_AT_LEAST := "opponent_prizes_at_least"
const INVARIANT_HAND_CONTAINS_ANY := "hand_contains_any"


static func is_supported(goal: Dictionary) -> bool:
	var goal_type := str(goal.get("type", ""))
	if goal_type in [GOAL_PRIZES, GOAL_TARGET_KNOCKOUTS]:
		return true
	if goal_type != GOAL_COMPOUND:
		return false
	var progress_goal := base_goal(goal)
	if progress_goal.is_empty() or not is_supported(progress_goal):
		return false
	var invariants_variant: Variant = goal.get("invariants", [])
	if not (invariants_variant is Array) or (invariants_variant as Array).is_empty():
		return false
	for invariant_variant: Variant in invariants_variant:
		if not (invariant_variant is Dictionary) or not _is_supported_invariant(invariant_variant):
			return false
	return true


static func required(goal: Dictionary) -> int:
	var resolved_goal := base_goal(goal)
	if str(resolved_goal.get("type", "")) == GOAL_TARGET_KNOCKOUTS:
		var targets_variant: Variant = resolved_goal.get("targets", [])
		var target_count := (targets_variant as Array).size() if targets_variant is Array else 0
		return maxi(1, int(resolved_goal.get("required", target_count)))
	if str(resolved_goal.get("type", "")) == GOAL_PRIZES:
		return maxi(1, int(resolved_goal.get("count", 1)))
	return 0


static func base_goal(goal: Dictionary) -> Dictionary:
	if str(goal.get("type", "")) != GOAL_COMPOUND:
		return goal
	var nested_variant: Variant = goal.get("progress_goal", {})
	return nested_variant if nested_variant is Dictionary else {}


static func invariants(goal: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if str(goal.get("type", "")) != GOAL_COMPOUND:
		return result
	var invariants_variant: Variant = goal.get("invariants", [])
	if not (invariants_variant is Array):
		return result
	for invariant_variant: Variant in invariants_variant:
		if invariant_variant is Dictionary:
			result.append(invariant_variant)
	return result


static func _legacy_required(goal: Dictionary) -> int:
	if str(goal.get("type", "")) == GOAL_TARGET_KNOCKOUTS:
		return maxi(1, int(goal.get("required", (goal.get("targets", []) as Array).size())))
	return maxi(1, int(goal.get("count", 1)))


static func progress(goal: Dictionary, state: GameState, context: Dictionary = {}) -> int:
	if state == null:
		return 0
	var resolved_goal := base_goal(goal)
	match str(resolved_goal.get("type", "")):
		GOAL_PRIZES:
			var initial_counts: Array = context.get("initial_prize_counts", [])
			if initial_counts.is_empty() or state.players.is_empty():
				return 0
			return maxi(0, int(initial_counts[0]) - state.players[0].prizes.size())
		GOAL_TARGET_KNOCKOUTS:
			return int(context.get("target_knockouts", 0))
	return 0


static func is_satisfied(goal: Dictionary, state: GameState, context: Dictionary = {}) -> bool:
	if not is_supported(goal) or state == null or progress(goal, state, context) < required(goal):
		return false
	for invariant: Dictionary in invariants(goal):
		if not _invariant_satisfied(invariant, state):
			return false
	return true


static func grade(goal: Dictionary, state: GameState, context: Dictionary = {}) -> String:
	var achieved := progress(goal, state, context)
	var target := required(goal)
	if str(goal.get("type", "")) == GOAL_COMPOUND \
			and achieved >= target \
			and not is_satisfied(goal, state, context):
		return "B"
	if achieved >= target + 1:
		return "S"
	if achieved >= target:
		return "A"
	if achieved == target - 1:
		return "B"
	return "C"


static func progress_text(goal: Dictionary, state: GameState, context: Dictionary = {}) -> String:
	var achieved := progress(goal, state, context)
	var target := required(goal)
	var resolved_goal := base_goal(goal)
	var base_text := "指定击倒 %d / %d" % [achieved, target] \
		if str(resolved_goal.get("type", "")) == GOAL_TARGET_KNOCKOUTS \
		else "已拿奖赏 %d / %d" % [achieved, target]
	if str(goal.get("type", "")) != GOAL_COMPOUND:
		return base_text
	var passed := 0
	var all_invariants := invariants(goal)
	for invariant: Dictionary in all_invariants:
		if _invariant_satisfied(invariant, state):
			passed += 1
	return "%s · 局面条件 %d / %d" % [base_text, passed, all_invariants.size()]


static func failure_reasons(goal: Dictionary, state: GameState, context: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	if state == null:
		return ["missing_game_state"]
	if progress(goal, state, context) < required(goal):
		result.append("progress_goal_not_met")
	for invariant: Dictionary in invariants(goal):
		if not _invariant_satisfied(invariant, state):
			result.append(str(invariant.get("failure_reason", invariant.get("type", "invariant_failed"))))
	return result


static func _is_supported_invariant(invariant: Dictionary) -> bool:
	return str(invariant.get("type", "")) in [
		INVARIANT_NOT_LOST,
		INVARIANT_PRESERVE_ANY,
		INVARIANT_HANDOFF_ATTACKER,
		INVARIANT_MIN_DECK_CARDS,
		INVARIANT_MIN_OPEN_BENCH_SLOTS,
		INVARIANT_OPPONENT_PRIZES_AT_LEAST,
		INVARIANT_HAND_CONTAINS_ANY,
	]


static func _invariant_satisfied(invariant: Dictionary, state: GameState) -> bool:
	if state == null:
		return false
	var player_index := int(invariant.get("player", 0))
	if player_index < 0 or player_index >= state.players.size():
		return false
	var player: PlayerState = state.players[player_index]
	match str(invariant.get("type", "")):
		INVARIANT_NOT_LOST:
			return not state.is_game_over() or state.winner_index == player_index
		INVARIANT_PRESERVE_ANY:
			return _matching_live_slots(player, invariant).size() >= maxi(1, int(invariant.get("count", 1)))
		INVARIANT_HANDOFF_ATTACKER:
			var minimum_energy := maxi(0, int(invariant.get("min_energy", 1)))
			var require_bench := bool(invariant.get("require_bench", false))
			for slot: PokemonSlot in _matching_live_slots(player, invariant):
				if slot.attached_energy.size() < minimum_energy:
					continue
				if require_bench and slot == player.active_pokemon:
					continue
				# Presence in Active/Bench is the engine's authoritative live
				# signal. Raw PokemonSlot HP does not include effective-HP tools
				# such as Bravery Charm, so only enforce a raw threshold when
				# the invariant explicitly authors one.
				if not invariant.has("min_remaining_hp") \
						or slot.get_remaining_hp() >= int(invariant.get("min_remaining_hp", 1)):
					return true
			return false
		INVARIANT_MIN_DECK_CARDS:
			return player.deck.size() >= maxi(0, int(invariant.get("count", 1)))
		INVARIANT_MIN_OPEN_BENCH_SLOTS:
			return maxi(0, int(invariant.get("bench_limit", 5)) - player.bench.size()) \
				>= maxi(0, int(invariant.get("count", 1)))
		INVARIANT_OPPONENT_PRIZES_AT_LEAST:
			var opponent_index := int(invariant.get("opponent", 1 - player_index))
			return opponent_index >= 0 \
				and opponent_index < state.players.size() \
				and state.players[opponent_index].prizes.size() >= maxi(0, int(invariant.get("count", 1)))
		INVARIANT_HAND_CONTAINS_ANY:
			var wanted := _wanted_card_refs(invariant)
			for card: CardInstance in player.hand:
				if _card_matches(card, wanted):
					return true
			return false
	return false


static func _matching_live_slots(player: PlayerState, invariant: Dictionary) -> Array[PokemonSlot]:
	var result: Array[PokemonSlot] = []
	var wanted := _wanted_card_refs(invariant)
	if wanted.is_empty():
		return result
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot == null:
			continue
		var top := slot.get_top_card()
		if _card_matches(top, wanted):
			result.append(slot)
	return result


static func _wanted_card_refs(invariant: Dictionary) -> Dictionary:
	var wanted: Dictionary = {}
	for key: String in ["card_uids", "card_names"]:
		var values_variant: Variant = invariant.get(key, [])
		if not (values_variant is Array):
			continue
		for value: Variant in values_variant:
			var normalized := str(value).strip_edges().to_lower()
			if normalized != "":
				wanted[normalized] = true
	return wanted


static func _card_matches(card: CardInstance, wanted: Dictionary) -> bool:
	if card == null or card.card_data == null or wanted.is_empty():
		return false
	var refs := [
		card.card_data.get_uid().strip_edges().to_lower(),
		card.card_data.name.strip_edges().to_lower(),
		card.card_data.name_en.strip_edges().to_lower(),
	]
	for ref: String in refs:
		if ref != "" and wanted.has(ref):
			return true
	return false
