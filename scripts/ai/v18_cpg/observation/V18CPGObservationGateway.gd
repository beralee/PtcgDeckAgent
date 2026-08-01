class_name V18CPGObservationGateway
extends RefCounted

const ContractsScript = preload("res://scripts/ai/v18_cpg/schema/V18CPGContracts.gd")
const BenchLimitScript = preload("res://scripts/engine/BenchLimitHelper.gd")
const VISIBLE_SCOPE_OWN_FULL_DECK := "own_full_deck"
const VISIBLE_SCOPE_OPPONENT_HAND_REVEALED := "opponent_hand_revealed"
const DEFAULT_BENCH_CAPACITY := 5

var _observation_version: int = 0
var _last_observation_hash: String = ""
var _decklist_visibility: String = "observed_only"


func configure(decklist_visibility: String = "observed_only") -> void:
	_decklist_visibility = decklist_visibility if decklist_visibility in ["configured_known", "observed_only"] else "observed_only"


func build(
	game_state: GameState,
	player_index: int,
	legal_actions: Array = [],
	interaction_step: Dictionary = {}
) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return _empty_envelope(player_index)
	var opponent_index := 1 - player_index
	var own: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[opponent_index]
	var own_bench_capacity := _bench_capacity(game_state, own)
	var opponent_bench_capacity := _bench_capacity(game_state, opponent)
	var envelope := {
		"schema_version": ContractsScript.OBSERVATION_SCHEMA_VERSION,
		"observation_version": 0,
		"turn": {
			"number": int(game_state.turn_number),
			"current_player": int(game_state.current_player_index),
			"viewer": player_index,
			"phase": int(game_state.phase),
			"first_player": int(game_state.first_player_index),
			# This public bit is deliberately narrower than "an attack is legal now":
			# it answers whether paying the remaining printed cost can lead directly
			# to a deterministic attack this turn.  Cost-completion certificates must
			# not fire through the first-turn restriction or Special Conditions.
			"deterministic_attack_window_open": _deterministic_attack_window_open(
				game_state, own, player_index
			),
			"quotas": {
				"energy_available": not game_state.energy_attached_this_turn,
				"supporter_available": not game_state.supporter_used_this_turn,
				"stadium_available": not game_state.stadium_played_this_turn,
				"retreat_available": not game_state.retreat_used_this_turn,
				"vstar_available": player_index < game_state.vstar_power_used.size() and not bool(game_state.vstar_power_used[player_index]),
			},
		},
		"own": _visible_own_player(
			own,
			game_state.turn_number,
			own_bench_capacity
		),
		"opponent": _visible_opponent(
			opponent,
			game_state.turn_number,
			opponent_bench_capacity
		),
		"stadium": _card_ref(game_state.stadium_card),
		"legal_actions": _legal_action_refs(legal_actions),
		"interaction": _visible_interaction(interaction_step),
		"visibility": {
			"decklist_visibility": _decklist_visibility,
			"own_prize_identities": false,
			"opponent_hand_contents": str(interaction_step.get("visible_scope", "")) == VISIBLE_SCOPE_OPPONENT_HAND_REVEALED,
			"deck_order_visible": false,
		},
	}
	var hash_payload: Dictionary = envelope.duplicate(true)
	hash_payload.erase("observation_version")
	var observation_hash := ContractsScript.stable_hash(hash_payload)
	if observation_hash != _last_observation_hash:
		_observation_version += 1
		_last_observation_hash = observation_hash
	envelope["observation_version"] = _observation_version
	envelope["observation_hash"] = observation_hash
	return envelope


func snapshot_public_state(game_state: GameState, player_index: int) -> Dictionary:
	# Runtime event snapshots deliberately do not consume an observation version:
	# they detect engine progress between a selected action and the next decision
	# window. They expose the same public zones as `build`, but no legal actions,
	# interaction candidates, hidden deck identities, or Prize identities.
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return {}
	var own: PlayerState = game_state.players[player_index]
	var opponent: PlayerState = game_state.players[opponent_index]
	var snapshot := {
		"turn": {
			"number": int(game_state.turn_number),
			"current_player": int(game_state.current_player_index),
			"viewer": player_index,
			"phase": int(game_state.phase),
			"first_player": int(game_state.first_player_index),
			"quotas": {
				"energy_available": not game_state.energy_attached_this_turn,
				"supporter_available": not game_state.supporter_used_this_turn,
				"stadium_available": not game_state.stadium_played_this_turn,
				"retreat_available": not game_state.retreat_used_this_turn,
				"vstar_available": player_index < game_state.vstar_power_used.size() \
					and not bool(game_state.vstar_power_used[player_index]),
			},
		},
		"own": _visible_own_player(
			own,
			game_state.turn_number,
			_bench_capacity(game_state, own)
		),
		"opponent": _visible_opponent(
			opponent,
			game_state.turn_number,
			_bench_capacity(game_state, opponent)
		),
		"stadium": _card_ref(game_state.stadium_card),
	}
	snapshot["public_state_hash"] = ContractsScript.stable_hash(snapshot)
	return snapshot


func _deterministic_attack_window_open(
	game_state: GameState,
	player: PlayerState,
	player_index: int
) -> bool:
	if game_state == null or player == null or player.active_pokemon == null:
		return false
	if game_state.current_player_index != player_index \
			or game_state.phase != GameState.GamePhase.MAIN:
		return false
	if game_state.turn_number == 1 and game_state.first_player_index == player_index:
		return false
	var status: Dictionary = player.active_pokemon.status_conditions
	# Confusion permits an attempted attack, but its payoff is not deterministic;
	# keep it model-owned rather than minting a monotonic local certificate.
	if bool(status.get("asleep", false)) \
			or bool(status.get("paralyzed", false)) \
			or bool(status.get("confused", false)):
		return false
	# Printed-cost completion cannot prove a follow-up through public attack-lock
	# effects.  Some locks name only one attack, but the generic profile does not
	# bind an attack index/name, so fail closed and leave those positions to the
	# model or Rule implementation.
	for effect_data: Dictionary in player.active_pokemon.effects:
		var effect_type := str(effect_data.get("type", ""))
		if effect_type == "attack_lock_until_leave_active":
			return false
		if effect_type in ["attack_lock", "attack_lock_all"] \
				and int(effect_data.get("turn", -999)) == game_state.turn_number - 2:
			return false
		if effect_type == "defender_attack_lock" \
				and int(effect_data.get("turn", -999)) == game_state.turn_number - 1:
			return false
	return true


func _empty_envelope(player_index: int) -> Dictionary:
	return {
		"schema_version": ContractsScript.OBSERVATION_SCHEMA_VERSION,
		"observation_version": _observation_version,
		"turn": {"viewer": player_index},
		"own": {},
		"opponent": {},
		"legal_actions": [],
		"interaction": {},
		"visibility": {},
		"observation_hash": "",
	}


func _visible_own_player(
	player: PlayerState,
	turn_number: int,
	bench_capacity: int = DEFAULT_BENCH_CAPACITY
) -> Dictionary:
	if player == null:
		return {}
	var result := {
		"hand": _card_refs(player.hand),
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"prizes_remaining": player.prizes.size(),
		"discard": _card_refs(player.discard_pile),
		"lost_zone": _card_refs(player.lost_zone),
		"active": _slot_ref(player.active_pokemon, turn_number),
		"bench": _slot_refs(player.bench, turn_number),
	}
	result.merge(_bench_state(player, bench_capacity))
	return result


func _visible_opponent(
	player: PlayerState,
	turn_number: int,
	bench_capacity: int = DEFAULT_BENCH_CAPACITY
) -> Dictionary:
	if player == null:
		return {}
	var result := {
		"hand_count": player.hand.size(),
		"deck_count": player.deck.size(),
		"prizes_remaining": player.prizes.size(),
		"discard": _card_refs(player.discard_pile),
		"lost_zone": _card_refs(player.lost_zone),
		"active": _slot_ref(player.active_pokemon, turn_number),
		"bench": _slot_refs(player.bench, turn_number),
	}
	result.merge(_bench_state(player, bench_capacity))
	return result


func _bench_capacity(game_state: GameState, player: PlayerState) -> int:
	return maxi(
		0,
		int(BenchLimitScript.get_bench_limit_for_player(game_state, player))
	)


func _bench_state(player: PlayerState, bench_capacity: int) -> Dictionary:
	var capacity := maxi(0, bench_capacity)
	var bench_count := player.bench.size() if player != null else 0
	return {
		"bench_count": bench_count,
		"bench_capacity": capacity,
		"bench_slots_free": maxi(0, capacity - bench_count),
		"bench_full": bench_count >= capacity,
		"bench_overflow_count": maxi(0, bench_count - capacity),
		"default_bench_capacity": DEFAULT_BENCH_CAPACITY,
		"overflow_if_default_capacity": maxi(
			0,
			bench_count - DEFAULT_BENCH_CAPACITY
		),
		"capacity_above_default": capacity > DEFAULT_BENCH_CAPACITY,
		"capacity_below_default": capacity < DEFAULT_BENCH_CAPACITY,
	}


func _visible_interaction(step: Dictionary) -> Dictionary:
	if step.is_empty():
		return {}
	var scope := str(step.get("visible_scope", ""))
	var visible_items: Array = []
	if scope in [VISIBLE_SCOPE_OWN_FULL_DECK, VISIBLE_SCOPE_OPPONENT_HAND_REVEALED]:
		var source_items: Variant = step.get("card_items", step.get("items", []))
		if source_items is Array:
			visible_items = _variant_card_refs(source_items as Array)
	return {
		"id": str(step.get("id", "")),
		"type": str(step.get("type", "")),
		"ui_mode": str(step.get("ui_mode", "")),
		"visible_scope": scope,
		"min_select": int(step.get("min_select", 0)),
		"max_select": int(step.get("max_select", 0)),
		"items": visible_items,
	}


func _legal_action_refs(actions: Array) -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	for raw_action: Variant in actions:
		if raw_action is Dictionary:
			refs.append(action_ref(raw_action as Dictionary))
	return refs


func action_ref(action: Dictionary) -> Dictionary:
	var ref := {
		"id": stable_action_id(action),
		"kind": str(action.get("kind", "")),
		"requires_interaction": bool(action.get("requires_interaction", false)),
	}
	if str(action.get("kind", "")) == "retreat":
		# The legal-action builder has already asked EffectProcessor for the
		# effective retreat cost. Preserve its exact payment instead of forcing
		# planners to reason from the printed card cost. Empty payment is a safe,
		# engine-authoritative zero-retreat proof; provider visibility alone is not.
		var raw_payment: Variant = action.get("energy_to_discard", null)
		if raw_payment is Array:
			ref["retreat_payment_energy_count"] = (raw_payment as Array).size()
			ref["zero_energy_retreat"] = (raw_payment as Array).is_empty()
			ref["engine_legal_retreat_proof"] = true
	var card: Variant = action.get("card", null)
	if card is CardInstance:
		ref["card"] = _card_ref(card as CardInstance)
	var source: Variant = action.get("source_slot", null)
	if source is PokemonSlot:
		ref["source"] = _slot_identity(source as PokemonSlot)
		ref["source_card"] = _card_ref((source as PokemonSlot).get_top_card())
	var target: Variant = action.get("target_slot", action.get("bench_target", null))
	if target is PokemonSlot:
		ref["target"] = _slot_identity(target as PokemonSlot)
	for key: String in ["attack_index", "attack_name", "ability_index", "ability_name", "projected_damage", "projected_knockout"]:
		if action.has(key):
			ref[key] = action.get(key)
	var local_certificates: Variant = action.get("v18cpg_local_certificates", {})
	if local_certificates is Dictionary and not (local_certificates as Dictionary).is_empty():
		ref["local_certificates"] = (local_certificates as Dictionary).duplicate(true)
	return ref


func stable_action_id(action: Dictionary) -> String:
	var parts: Array[String] = [str(action.get("kind", ""))]
	var card: Variant = action.get("card", null)
	parts.append(str((card as CardInstance).instance_id) if card is CardInstance else "-")
	var source: Variant = action.get("source_slot", null)
	parts.append(str(_slot_instance_id(source as PokemonSlot)) if source is PokemonSlot else "-")
	var target: Variant = action.get("target_slot", action.get("bench_target", null))
	parts.append(str(_slot_instance_id(target as PokemonSlot)) if target is PokemonSlot else "-")
	parts.append(str(action.get("attack_index", -1)))
	parts.append(str(action.get("ability_index", -1)))
	return "action:" + ":".join(parts)


func _slot_refs(slots: Array, turn_number: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_slot: Variant in slots:
		if raw_slot is PokemonSlot:
			result.append(_slot_ref(raw_slot as PokemonSlot, turn_number))
	return result


func _slot_ref(slot: PokemonSlot, turn_number: int) -> Dictionary:
	if slot == null:
		return {}
	var data := slot.get_card_data()
	var printed_retreat_cost := int(slot.get_retreat_cost())
	return {
		"slot_id": _slot_identity(slot),
		"pokemon": _card_ref(slot.get_top_card()),
		"stack": _card_refs(slot.pokemon_stack),
		"energy": _card_refs(slot.attached_energy),
		"energy_count": slot.attached_energy.size(),
		"tool": _card_ref(slot.attached_tool),
		"damage": int(slot.damage_counters),
		"remaining_hp": int(slot.get_remaining_hp()),
		"max_hp": int(slot.get_max_hp()),
		"prize_count": int(slot.get_prize_count()),
		# Compatibility field retained for consumers created before the effective
		# mobility contract. It is the printed cost, not the current engine cost.
		"retreat_cost": printed_retreat_cost,
		"printed_retreat_cost": printed_retreat_cost,
		"stage": str(data.stage) if data != null else "",
		"ability_used": slot.has_ability_used(turn_number),
		"tera": _is_tera(data),
	}


func _slot_identity(slot: PokemonSlot) -> String:
	return "slot:%d" % _slot_instance_id(slot)


func _slot_instance_id(slot: PokemonSlot) -> int:
	if slot == null or slot.get_top_card() == null:
		return -1
	return int(slot.get_top_card().instance_id)


func _card_refs(cards: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_card: Variant in cards:
		if raw_card is CardInstance:
			result.append(_card_ref(raw_card as CardInstance))
	return result


func _variant_card_refs(items: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Variant in items:
		if item is CardInstance:
			result.append(_card_ref(item as CardInstance))
		elif item is CardData:
			result.append(_card_data_ref(item as CardData, -1))
		elif item is Dictionary:
			var card: Variant = (item as Dictionary).get("card", null)
			if card is CardInstance:
				result.append(_card_ref(card as CardInstance))
	return result


func _card_ref(card: CardInstance) -> Dictionary:
	if card == null or card.card_data == null:
		return {}
	return _card_data_ref(card.card_data, card.instance_id)


func _card_data_ref(data: CardData, instance_id: int) -> Dictionary:
	if data == null:
		return {}
	return {
		"instance_id": instance_id,
		"uid": data.get_uid(),
		"effect_id": str(data.effect_id),
		"name": _display_name(data),
		"type": str(data.card_type),
		"mechanic": str(data.mechanic),
		"stage": str(data.stage),
		"energy_type": str(data.energy_type),
		"energy_provides": str(data.energy_provides),
		"hp": int(data.hp),
	}


func _display_name(data: CardData) -> String:
	if data == null:
		return ""
	if str(data.name_en).strip_edges() != "":
		return str(data.name_en)
	return str(data.name)


func _is_tera(data: CardData) -> bool:
	if data == null:
		return false
	# Tera is card identity, not a word that happens to occur in rules text.
	# Reading `description` made Noctowl look like a Tera Pokemon because Jewel
	# Seeker mentions the condition, while Teal Mask Ogerpon's actual Tera marker
	# lives in `ancient_trait` and was missed.
	var joined := "%s %s %s %s" % [
		data.ancient_trait,
		data.mechanic,
		data.label,
		" ".join(data.is_tags),
	]
	var lowered := joined.to_lower()
	return lowered.contains("tera") or joined.contains("太晶")
