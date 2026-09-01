## Compatibility note: the resource path keeps its historical Poison suffix so
## existing profile imports remain valid. The production strategy is pure Metal.
class_name DeckStrategyV18ArchaludonMetal
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const DECK_ID := 800017280
const MARNIE_DECK_ID := 800018501

const DURALUDON := "CSV9C_136"
const ARCHALUDON_EX := "CSV9C_138"
const LATIAS_EX := "CSV9C_078"
const FEZANDIPITI_EX := "CSV8C_135"
const SQUAWKABILLY_EX := "CSV2C_105"
const MANAPHY := "CS5bC_052"

const EARTHEN_VESSEL := "CSV6C_115"
const ULTRA_BALL := "CSV1C_112"
const NEST_BALL := "CSVH1C_043"
const SECRET_BOX := "CSV8C_176"
const NIGHT_STRETCHER := "CSV8C_183"
const PAL_PAD := "CSV1C_111"
const PROFESSORS_RESEARCH := "CSV1C_121"
const CARMINE := "CSV8C_199"
const PROFESSOR_TURO := "CSV6C_125"
const BOSS_ORDERS := "CSVH1aC_023"
const IONO := "CSV3C_123"
const POKEGEAR := "CSV2C_113"
const METAL_ENERGY := "CSVE1C_MET"

const MARNIE_IMPIDIMP := "CSV10C_146"
const MARNIE_MORGREM := "CSV10C_147"
const MARNIE_GRIMMSNARL := "CSV10C_148"
const MARNIE_SNORUNT := "CSV6C_051"
const MARNIE_FROSLASS := "CSV7C_059"
const MARNIE_MUNKIDORI := "CSV8C_094"

const ALLOY_BUILD_STEP := "csv9c_metal_discard_assignments"
const ALLOY_BUILD_LEGACY_STEP := "alloy_build_assignments"
const METAL := "M"

const PROFILE := {
	"strategy_id": "v18_archaludon_metal_800017280",
	"signatures": [ARCHALUDON_EX, DURALUDON, MANAPHY],
	"active_priority": [DURALUDON, ARCHALUDON_EX, SQUAWKABILLY_EX, LATIAS_EX, FEZANDIPITI_EX, MANAPHY],
	"bench_priority": [DURALUDON, MANAPHY, SQUAWKABILLY_EX, LATIAS_EX, FEZANDIPITI_EX],
	"search_priority": [ARCHALUDON_EX, DURALUDON, MANAPHY, LATIAS_EX, FEZANDIPITI_EX, SQUAWKABILLY_EX],
	"evolution_priority": [ARCHALUDON_EX],
	"energy_priority": [ARCHALUDON_EX, DURALUDON],
	"ability_priority": [ARCHALUDON_EX, SQUAWKABILLY_EX, FEZANDIPITI_EX, LATIAS_EX],
}

var _deck_id := DECK_ID


func configure_from_deck(deck: DeckData) -> void:
	_deck_id = int(deck.id) if deck != null else DECK_ID


func _profile() -> Dictionary:
	return PROFILE


func get_strategy_id() -> String:
	return "v18_archaludon_metal_%d" % _deck_id


func plan_opening_setup(player: PlayerState) -> Dictionary:
	if player == null:
		return {"active_hand_index": -1, "bench_hand_indices": []}
	var candidates: Array[Dictionary] = []
	for index: int in player.hand.size():
		var card: CardInstance = player.hand[index]
		if card == null or not card.is_basic_pokemon():
			continue
		candidates.append({
			"index": index,
			"active": _opening_active_score(card),
			"bench": _opening_bench_score(card),
			"identity": _opening_identity(card),
		})
	if candidates.is_empty():
		return {"active_hand_index": -1, "bench_hand_indices": []}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("active", 0.0)) > float(b.get("active", 0.0))
	)
	var active_index := int(candidates[0].get("index", -1))
	var bench_candidates := candidates.duplicate(true)
	bench_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("bench", 0.0)) > float(b.get("bench", 0.0))
	)
	var bench_indices: Array[int] = []
	var identity_counts: Dictionary = {}
	for entry: Dictionary in bench_candidates:
		var index := int(entry.get("index", -1))
		if index == active_index or float(entry.get("bench", 0.0)) <= 0.0:
			continue
		var identity := str(entry.get("identity", ""))
		var cap := 1
		if identity == DURALUDON:
			cap = 1 if _matches_key(player.hand[active_index], DURALUDON) else 2
		if int(identity_counts.get(identity, 0)) >= cap:
			continue
		bench_indices.append(index)
		identity_counts[identity] = int(identity_counts.get(identity, 0)) + 1
		if bench_indices.size() >= 4:
			break
	return {"active_hand_index": active_index, "bench_hand_indices": bench_indices}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	var player := _valid_player(game_state, player_index)
	if player == null:
		return {}
	var ready := _ready_archaludon(player)
	var debt := _setup_debt(player)
	var phase := "setup"
	if int(debt.get("missing_duraludon", 0)) > 0:
		phase = "rebuild"
	elif int(debt.get("missing_archaludon", 0)) > 0 or int(debt.get("missing_attack_energy", 0)) > 0:
		phase = "launch"
	elif player.prizes.size() > 0 and player.prizes.size() <= 2:
		phase = "close"
	else:
		phase = "convert"
	var owner_name := ARCHALUDON_EX if ready != null else DURALUDON
	var bridge_name := ARCHALUDON_EX if _has_slot(player, DURALUDON) else DURALUDON
	var low_deck := player.deck.size() <= 8
	return {
		"id": "v18_archaludon_metal_800017280:%s" % phase,
		"intent": _phase_intent(phase, ready != null),
		"phase": phase,
		"flags": {
			"archaludon_metal_route": true,
			"ready_attackers": 1 if ready != null else 0,
			"setup_debt": debt,
			"low_deck": low_deck,
			"marnie_matchup": _is_marnie_matchup(game_state, player_index),
		},
		"owner": {
			"turn_owner_name": owner_name,
			"bridge_target_name": bridge_name,
			"pivot_target_name": owner_name,
		},
		"targets": {
			"primary_attacker_name": ARCHALUDON_EX,
			"bridge_target_name": bridge_name,
		},
		"priorities": {
			"attach": [ARCHALUDON_EX, DURALUDON],
			"handoff": [ARCHALUDON_EX, DURALUDON],
			"search": [ARCHALUDON_EX, DURALUDON, MANAPHY, LATIAS_EX, FEZANDIPITI_EX],
			"evolve": [ARCHALUDON_EX],
			"ability": [ARCHALUDON_EX, FEZANDIPITI_EX, SQUAWKABILLY_EX],
			"trainer": [ULTRA_BALL, EARTHEN_VESSEL, NEST_BALL, NIGHT_STRETCHER, BOSS_ORDERS, SECRET_BOX],
		},
		"constraints": {
			"forbid_engine_churn": low_deck and ready != null,
			"forbid_extra_bench_padding": player.bench.size() >= 4 and int(debt.get("total", 0)) <= 0,
		},
		"context": context.duplicate(true),
	}


func build_continuity_contract(
	game_state: GameState,
	player_index: int,
	_turn_contract: Dictionary = {}
) -> Dictionary:
	var player := _valid_player(game_state, player_index)
	if player == null:
		return {}
	var debt := _setup_debt(player)
	var ready := _ready_archaludon(player) != null
	return {
		"enabled": true,
		"safe_setup_before_attack": ready and int(debt.get("missing_backup_route", 0)) > 0,
		"setup_debt": debt,
		"action_bonuses": [
			{"kind": "play_basic_to_bench", "card_names": [DURALUDON], "bonus": 780.0},
			{"kind": "evolve", "card_names": [ARCHALUDON_EX], "bonus": 920.0},
			{"kind": "attach_energy", "target_names": [ARCHALUDON_EX, DURALUDON], "bonus": 720.0},
			{"kind": "use_ability", "target_names": [ARCHALUDON_EX], "bonus": 520.0},
		],
		"attack_penalty": 880.0 if ready and int(debt.get("missing_backup_route", 0)) > 0 else 0.0,
	}


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	var base_score := super.score_action_absolute(action, game_state, player_index)
	var player := _valid_player(game_state, player_index)
	if player == null:
		return base_score
	match str(action.get("kind", "")):
		"attack", "granted_attack":
			return _score_attack(action, player, game_state, player_index, base_score)
		"attach_energy":
			return _score_energy_attachment(action, player, base_score)
		"evolve":
			return _score_evolution(action, player, base_score)
		"play_basic_to_bench":
			return _score_basic(action, player, game_state, base_score)
		"play_trainer", "play_stadium":
			return _score_trainer(action, player, game_state, player_index, base_score)
		"use_ability", "use_stadium_effect":
			return _score_ability(action, player, game_state, player_index, base_score)
		"retreat":
			return _score_retreat(action, player, base_score)
		"end_turn":
			if _ready_archaludon(player) == null and int(_setup_debt(player).get("total", 0)) > 0:
				return minf(base_score, -2600.0)
	return base_score


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var step_id := str(step.get("id", "")).to_lower()
	var player := _player_from_context(context)
	if item is Dictionary and step_id.contains("assignment"):
		var assignment := item as Dictionary
		var target: Variant = assignment.get("target", null)
		if target is PokemonSlot:
			return _metal_target_score(target as PokemonSlot, player, _pending_count(target as PokemonSlot, context) + 1)
	if item is PokemonSlot:
		var slot := item as PokemonSlot
		if step_id in [ALLOY_BUILD_STEP, ALLOY_BUILD_LEGACY_STEP] or step_id.contains("metal_discard"):
			return _metal_target_score(slot, player, _pending_count(slot, context) + 1)
		if step_id == "prof_turo_target":
			return _turo_target_score(slot, player)
		if _is_opponent_slot(slot, context) and _is_gust_or_damage_step(step_id):
			return _opponent_target_score(slot, player)
		if _is_handoff_step(step_id):
			return _handoff_score(slot, player)
	if item is CardInstance:
		var card := item as CardInstance
		if _is_recovery_step(step_id):
			return _recovery_score(
				card,
				player,
				context.get("game_state", null),
				int(context.get("player_index", -1))
			)
		if step_id.contains("discard"):
			return float(_discard_priority(card, player))
		return _search_score(
			card,
			player,
			step_id,
			context.get("game_state", null),
			int(context.get("player_index", -1))
		)
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	if item is PokemonSlot:
		return _handoff_score(item as PokemonSlot, _player_from_context(context))
	return score_interaction_target(item, step, context)


func get_discard_priority(card: CardInstance) -> int:
	return _discard_priority(card, null)


func get_discard_priority_contextual(card: CardInstance, game_state: GameState, player_index: int) -> int:
	return _discard_priority(card, _valid_player(game_state, player_index))


func get_search_priority(card: CardInstance) -> int:
	return int(_search_score(card, null, "generic_search"))


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if slot == null or slot.get_card_data() == null:
		return {"damage": 0, "can_attack": false, "description": ""}
	var metal_units := _metal_units(slot) + maxi(0, extra_context)
	if _matches_key(slot, ARCHALUDON_EX):
		return {"damage": 220, "can_attack": metal_units >= 3, "description": "archaludon_metal_defender"}
	if _matches_key(slot, DURALUDON):
		return {
			"damage": 130 if metal_units >= 3 else (50 if metal_units >= 2 else 0),
			"can_attack": metal_units >= 2,
			"description": "duraludon_bridge",
		}
	return super.predict_attacker_damage(slot, extra_context)


func _score_attack(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
	if source == null:
		return base_score
	var projected_ko := bool(action.get("projected_knockout", false))
	var defender := _opponent_active(game_state, player_index)
	if _matches_key(source, ARCHALUDON_EX):
		var score := 5700.0
		if projected_ko:
			score += 2600.0 + float(defender.get_prize_count() if defender != null else 1) * 500.0
		elif defender != null and defender.get_remaining_hp() <= 260 and _archaludon_damage(source) >= defender.get_remaining_hp():
			score += 2200.0
		return maxf(base_score, score)
	if _matches_key(source, DURALUDON):
		var damage := int(action.get("projected_damage", 0))
		if projected_ko:
			return maxf(base_score, 4600.0 + float(damage) * 4.0)
		return maxf(base_score, 2100.0 if damage >= 130 else 1250.0)
	if _matches_key(source, SQUAWKABILLY_EX):
		if _ready_archaludon(player) != null:
			return minf(base_score, -4200.0)
		var discard_metal := _metal_in_discard(player)
		var bench_route := _best_unready_metal_target(player, source)
		if discard_metal > 0 and bench_route != null:
			return maxf(base_score, 2400.0 + float(mini(2, discard_metal)) * 520.0)
		return minf(base_score, 80.0)
	if _matches_key(source, FEZANDIPITI_EX) and projected_ko:
		return maxf(base_score, 5000.0)
	return minf(base_score, -900.0) if _ready_archaludon(player) != null else base_score


func _score_energy_attachment(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if target == null:
		return base_score
	if card != null and card.card_data != null and card.card_data.is_energy() and not _is_metal_energy(card):
		return minf(base_score, -4000.0)
	var route_score := _metal_target_score(target, player, 1)
	if not _is_metal_body(target):
		return minf(base_score, -4200.0) if _has_any_metal_route(player) else maxf(base_score, 120.0)
	return maxf(base_score, route_score)


func _score_evolution(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var card: CardInstance = action.get("card", null)
	var target: PokemonSlot = action.get("target_slot", null)
	if not _matches_key(card, ARCHALUDON_EX) or target == null:
		return base_score
	var score := 5000.0
	score += float(mini(2, _metal_in_discard(player))) * 900.0
	if target == player.active_pokemon:
		score += 450.0
	if _metal_units(target) > 0:
		score += 300.0
	return maxf(base_score, score)


func _score_basic(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	base_score: float
) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null:
		return base_score
	if _matches_key(card, DURALUDON):
		var count := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
		return maxf(base_score, 5200.0 if count == 0 else (3900.0 if count == 1 else 900.0))
	if _matches_key(card, MANAPHY):
		if _is_marnie_matchup(game_state, player.player_index) and not _has_slot(player, MANAPHY):
			var metal_bodies := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
			return maxf(base_score, 6200.0) if metal_bodies >= 2 else minf(base_score, 1800.0)
		return maxf(base_score, 1000.0 if not _has_slot(player, MANAPHY) else 100.0)
	if _matches_key(card, SQUAWKABILLY_EX):
		var first_turn := game_state != null and int(game_state.turn_number) <= 2
		return maxf(base_score, 3400.0) if first_turn and _count_slots(player, SQUAWKABILLY_EX) == 0 else minf(base_score, 80.0)
	if _matches_key(card, LATIAS_EX):
		return maxf(base_score, 2200.0 if _count_slots(player, LATIAS_EX) == 0 and _needs_basic_mobility(player) else 600.0)
	if _matches_key(card, FEZANDIPITI_EX):
		return maxf(base_score, 1850.0 if _count_slots(player, FEZANDIPITI_EX) == 0 else 200.0)
	return base_score


func _score_trainer(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var card: CardInstance = action.get("card", null)
	if card == null:
		return base_score
	var ready := _ready_archaludon(player) != null
	var low_deck := player.deck.size() <= 8
	if (_matches_key(card, PROFESSORS_RESEARCH) or _matches_key(card, CARMINE) or _matches_key(card, IONO)) and low_deck and ready:
		return minf(base_score, -3000.0)
	if _matches_key(card, EARTHEN_VESSEL):
		var score := 2050.0
		if _metal_in_discard(player) < 2:
			score += 750.0
		if _metal_in_hand(player) == 0:
			score += 650.0
		return maxf(base_score, score)
	if _matches_key(card, ULTRA_BALL):
		return maxf(base_score, 3100.0 if _has_slot(player, DURALUDON) and not _has_slot(player, ARCHALUDON_EX) else 1750.0)
	if _matches_key(card, NEST_BALL):
		return maxf(base_score, 3000.0 if _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX) < 2 else 1300.0)
	if _matches_key(card, SECRET_BOX):
		return maxf(base_score, 3300.0 if not ready else 1300.0)
	if _matches_key(card, NIGHT_STRETCHER):
		return maxf(base_score, 2800.0 if _has_recoverable_core(player) else 150.0)
	if _matches_key(card, BOSS_ORDERS):
		if not ready:
			return minf(base_score, -2600.0)
		return maxf(base_score, 4300.0) if _opponent_has_one_hit_target(game_state, player_index) else maxf(base_score, 900.0)
	if _matches_key(card, CARMINE):
		return maxf(base_score, 3600.0) if not ready else base_score
	if _matches_key(card, PROFESSORS_RESEARCH):
		return maxf(base_score, 3400.0) if not ready else base_score
	if _matches_key(card, IONO):
		return maxf(base_score, 2500.0) if not ready else base_score
	if _matches_key(card, PROFESSOR_TURO):
		if _is_marnie_matchup(game_state, player_index) and _has_turo_rescue_target(player):
			return maxf(base_score, 5200.0)
		return maxf(base_score, 1500.0) if _has_damaged_liability(player) else minf(base_score, 120.0)
	return base_score


func _score_ability(
	action: Dictionary,
	player: PlayerState,
	game_state: GameState,
	player_index: int,
	base_score: float
) -> float:
	var source: PokemonSlot = action.get("source_slot", null)
	if source == null:
		return base_score
	if _matches_key(source, ARCHALUDON_EX):
		return maxf(base_score, 4800.0 + float(mini(2, _metal_in_discard(player))) * 900.0)
	if _matches_key(source, SQUAWKABILLY_EX):
		return maxf(base_score, 3500.0) if game_state != null and int(game_state.turn_number) <= 2 and not _ready_archaludon(player) else minf(base_score, -400.0)
	if _matches_key(source, FEZANDIPITI_EX):
		if player.deck.size() <= 8 and _ready_archaludon(player) != null:
			return minf(base_score, -2200.0)
	return base_score


func _score_retreat(action: Dictionary, player: PlayerState, base_score: float) -> float:
	var target: PokemonSlot = action.get("bench_target", null)
	if target == null:
		return base_score
	var target_score := _handoff_score(target, player)
	var active_score := _handoff_score(player.active_pokemon, player)
	if _matches_key(target, ARCHALUDON_EX) and _metal_units(target) >= 3:
		return maxf(base_score, 5200.0)
	return maxf(base_score, 2600.0) if target_score > active_score + 700.0 else minf(base_score, -900.0)


func _metal_target_score(slot: PokemonSlot, player: PlayerState, incoming: int) -> float:
	if slot == null:
		return -5000.0
	if not _is_metal_body(slot):
		return -5000.0
	var current := _metal_units(slot)
	var after := current + maxi(0, incoming)
	var score := 2100.0
	if _matches_key(slot, ARCHALUDON_EX):
		score = 3500.0
	elif _matches_key(slot, DURALUDON):
		score = 2850.0
	if current < 3:
		score += float(3 - current) * 520.0
	if current < 3 and after >= 3:
		score += 1500.0
	if player != null and slot == player.active_pokemon:
		score += 500.0
	if current >= 3:
		var backup_ready := _count_ready_metal_attackers(player)
		score = 1150.0 if backup_ready <= 1 else 320.0
	return score


func _handoff_score(slot: PokemonSlot, player: PlayerState) -> float:
	if slot == null:
		return -5000.0
	var prediction := predict_attacker_damage(slot)
	if _matches_key(slot, ARCHALUDON_EX) and bool(prediction.get("can_attack", false)):
		return 6200.0 + float(prediction.get("damage", 0)) * 2.0
	if _matches_key(slot, DURALUDON) and bool(prediction.get("can_attack", false)):
		return 3600.0 + float(prediction.get("damage", 0)) * 2.0
	if _matches_key(slot, ARCHALUDON_EX):
		return 2400.0 + float(_metal_units(slot)) * 450.0
	if _matches_key(slot, DURALUDON):
		return 1800.0 + float(_metal_units(slot)) * 350.0
	if _matches_key(slot, SQUAWKABILLY_EX) and _metal_in_discard(player) > 0 and _ready_archaludon(player) == null:
		return 780.0
	return 100.0


func _search_score(
	card: CardInstance,
	player: PlayerState,
	step_id: String,
	game_state: GameState = null,
	player_index: int = -1
) -> float:
	if card == null:
		return 0.0
	if _matches_key(card, ARCHALUDON_EX):
		return 5200.0 if player == null or (_has_slot(player, DURALUDON) and not _has_slot(player, ARCHALUDON_EX)) else 2600.0
	if _matches_key(card, DURALUDON):
		var count := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
		return 5000.0 if count == 0 else (3800.0 if count == 1 else 800.0)
	if _matches_key(card, EARTHEN_VESSEL):
		return 3500.0 if player == null or _metal_in_discard(player) < 2 else 1800.0
	if _matches_key(card, ULTRA_BALL): return 3200.0
	if _matches_key(card, NEST_BALL):
		var metal_bodies := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
		return 3200.0 if player != null and metal_bodies < 2 else 2850.0
	if _matches_key(card, NIGHT_STRETCHER): return 2700.0 if player == null or _has_recoverable_core(player) else 500.0
	if _matches_key(card, CARMINE): return 1900.0 if player != null and _ready_archaludon(player) == null else 750.0
	if _matches_key(card, PROFESSORS_RESEARCH): return 1700.0 if player != null and _ready_archaludon(player) == null else 650.0
	if _matches_key(card, IONO): return 1500.0 if player != null and _ready_archaludon(player) == null else 900.0
	if _matches_key(card, BOSS_ORDERS):
		if player != null and _ready_archaludon(player) != null and _opponent_has_one_hit_target(game_state, player_index):
			return 5600.0
		return 2600.0 if player != null and _ready_archaludon(player) != null else 500.0
	if _matches_key(card, PROFESSOR_TURO):
		var metal_bodies := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
		if player != null and metal_bodies >= 2 and _has_turo_rescue_target(player) and _is_marnie_matchup(game_state, player_index):
			return 4300.0
		return 1800.0 if player != null and _has_damaged_liability(player) else 300.0
	if _matches_key(card, MANAPHY):
		if player != null and not _has_slot(player, MANAPHY) and _is_marnie_matchup(game_state, player_index):
			var metal_bodies := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
			return 5200.0 if metal_bodies >= 2 else 2400.0
		return 1100.0 if player == null or not _has_slot(player, MANAPHY) else 200.0
	if _matches_key(card, LATIAS_EX): return 1500.0
	if _matches_key(card, FEZANDIPITI_EX): return 1300.0
	return float(super.get_search_priority(card))


func _recovery_score(
	card: CardInstance,
	player: PlayerState,
	game_state: GameState = null,
	player_index: int = -1
) -> float:
	if _matches_key(card, ARCHALUDON_EX): return 5200.0
	if _matches_key(card, DURALUDON): return 4800.0
	if _is_metal_energy(card): return 3600.0 if player == null or _metal_in_hand(player) == 0 else 1600.0
	if _matches_key(card, BOSS_ORDERS):
		return 5000.0 if _is_marnie_matchup(game_state, player_index) else 1600.0
	if _matches_key(card, PROFESSOR_TURO):
		return 3200.0 if player != null and _has_turo_rescue_target(player) else 700.0
	if _matches_key(card, MANAPHY): return 3000.0 if player == null or not _has_slot(player, MANAPHY) else 300.0
	if _matches_key(card, FEZANDIPITI_EX): return 900.0
	return 100.0


func _discard_priority(card: CardInstance, player: PlayerState) -> int:
	if card == null or card.card_data == null:
		return 0
	if _is_metal_energy(card):
		return 210 if player == null or _metal_in_discard(player) < 2 else 105
	if _matches_key(card, ARCHALUDON_EX): return 5 if player == null or _has_slot(player, DURALUDON) else 35
	if _matches_key(card, DURALUDON): return 4 if player == null or not _has_any_metal_route(player) else 45
	if _matches_key(card, MANAPHY): return 16 if player == null or not _has_slot(player, MANAPHY) else 92
	if _matches_key(card, PROFESSOR_TURO): return 12 if player != null and _has_support_liability(player) else 82
	if _matches_key(card, BOSS_ORDERS): return 22
	if _matches_key(card, NIGHT_STRETCHER): return 28
	if _matches_key(card, LATIAS_EX): return 105
	if _matches_key(card, SQUAWKABILLY_EX) or _matches_key(card, FEZANDIPITI_EX): return 85
	return super.get_discard_priority(card)


func _opponent_target_score(slot: PokemonSlot, player: PlayerState) -> float:
	if slot == null:
		return 0.0
	var damage := _active_attack_damage(player)
	var remaining := slot.get_remaining_hp()
	var score := float(slot.get_prize_count()) * 650.0
	if damage > 0 and remaining <= damage:
		score += 4300.0
	if _matches_key(slot, MARNIE_FROSLASS): score += 1600.0
	elif _matches_key(slot, MARNIE_MORGREM): score += 1450.0
	elif _matches_key(slot, MARNIE_IMPIDIMP): score += 1200.0
	elif _matches_key(slot, MARNIE_MUNKIDORI): score += 900.0
	elif _matches_key(slot, MARNIE_SNORUNT): score += 700.0
	elif _matches_key(slot, MARNIE_GRIMMSNARL): score += 350.0
	score -= float(remaining) * 0.35
	return score


func _turo_target_score(slot: PokemonSlot, player: PlayerState) -> float:
	if slot == null:
		return -5000.0
	if _is_metal_body(slot):
		return -5200.0 if _metal_units(slot) > 0 or (player != null and slot == player.active_pokemon) else -2600.0
	if slot.get_prize_count() >= 2:
		return 4300.0 + float(slot.damage_counters) * 12.0
	if slot.damage_counters >= 90:
		return 1400.0 + float(slot.damage_counters) * 5.0
	return 100.0


func _setup_debt(player: PlayerState) -> Dictionary:
	var metal_bodies := _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX)
	var missing_duraludon := 1 if metal_bodies == 0 else 0
	var missing_backup := 1 if metal_bodies < 2 else 0
	var missing_archaludon := 1 if not _has_slot(player, ARCHALUDON_EX) else 0
	var ready := _ready_archaludon(player)
	var best_energy := 0
	for slot: PokemonSlot in _all_slots(player):
		if _is_metal_body(slot):
			best_energy = maxi(best_energy, _metal_units(slot))
	var missing_energy := maxi(0, 3 - best_energy) if ready == null else 0
	return {
		"missing_duraludon": missing_duraludon,
		"missing_backup_route": missing_backup,
		"missing_archaludon": missing_archaludon,
		"missing_attack_energy": missing_energy,
		"total": missing_duraludon + missing_backup + missing_archaludon + missing_energy,
	}


func _phase_intent(phase: String, ready: bool) -> String:
	match phase:
		"rebuild": return "recover_archaludon_route"
		"launch": return "complete_alloy_build_and_mmm"
		"convert", "close": return "convert_metal_defender_and_gust_prizes" if ready else "fund_archaludon"
		_: return "establish_two_duraludon_routes"


func _opening_active_score(card: CardInstance) -> float:
	if _matches_key(card, DURALUDON): return 10000.0
	if _matches_key(card, SQUAWKABILLY_EX): return 2200.0
	if _matches_key(card, LATIAS_EX): return 1800.0
	if _matches_key(card, FEZANDIPITI_EX): return 1200.0
	if _matches_key(card, MANAPHY): return 1000.0
	return 100.0


func _opening_bench_score(card: CardInstance) -> float:
	if _matches_key(card, DURALUDON): return 10000.0
	if _matches_key(card, SQUAWKABILLY_EX): return 8500.0
	if _matches_key(card, LATIAS_EX): return 7600.0
	if _matches_key(card, MANAPHY): return 9600.0
	if _matches_key(card, FEZANDIPITI_EX): return 4100.0
	return -100.0


func _opening_identity(card: CardInstance) -> String:
	for identity: String in [DURALUDON, MANAPHY, SQUAWKABILLY_EX, LATIAS_EX, FEZANDIPITI_EX]:
		if _matches_key(card, identity):
			return identity
	return _primary_name(card)


func _ready_archaludon(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if _matches_key(slot, ARCHALUDON_EX) and _metal_units(slot) >= 3:
			return slot
	return null


func _best_unready_metal_target(player: PlayerState, excluded: PokemonSlot = null) -> PokemonSlot:
	var best: PokemonSlot = null
	var best_score := -INF
	if player == null:
		return null
	for slot: PokemonSlot in _all_slots(player):
		if slot == excluded or not _is_metal_body(slot) or _metal_units(slot) >= 3:
			continue
		var score := _metal_target_score(slot, player, 0)
		if score > best_score:
			best_score = score
			best = slot
	return best


func _count_ready_metal_attackers(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if _is_metal_body(slot) and bool(predict_attacker_damage(slot).get("can_attack", false)):
				count += 1
	return count


func _metal_units(slot: PokemonSlot) -> int:
	var count := 0
	if slot != null:
		for energy: CardInstance in slot.attached_energy:
			if _is_metal_energy(energy):
				count += 1
	return count


func _is_metal_energy(item: Variant) -> bool:
	var data := _card_data_from_item(item)
	if data == null or not data.is_energy():
		return false
	var provides := str(data.energy_provides if data.energy_provides != "" else data.energy_type).to_upper()
	return provides == METAL or provides == "ANY" or METAL in provides


func _metal_in_discard(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.discard_pile:
			if _is_metal_energy(card): count += 1
	return count


func _metal_in_hand(player: PlayerState) -> int:
	var count := 0
	if player != null:
		for card: CardInstance in player.hand:
			if _is_metal_energy(card): count += 1
	return count


func _is_metal_body(slot: PokemonSlot) -> bool:
	return _matches_key(slot, DURALUDON) or _matches_key(slot, ARCHALUDON_EX)


func _has_any_metal_route(player: PlayerState) -> bool:
	return _count_slots(player, DURALUDON) + _count_slots(player, ARCHALUDON_EX) > 0


func _needs_basic_mobility(player: PlayerState) -> bool:
	return player != null and player.active_pokemon != null and not _is_metal_body(player.active_pokemon) and player.active_pokemon.get_card_data().is_basic_pokemon()


func _has_recoverable_core(player: PlayerState) -> bool:
	if player != null:
		for card: CardInstance in player.discard_pile:
			if _matches_key(card, DURALUDON) or _matches_key(card, ARCHALUDON_EX) or _is_metal_energy(card):
				return true
	return false


func _has_damaged_liability(player: PlayerState) -> bool:
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if slot.damage_counters >= 100 and not _matches_key(slot, ARCHALUDON_EX):
				return true
	return false


func _has_support_liability(player: PlayerState) -> bool:
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if not _is_metal_body(slot) and slot.get_prize_count() >= 2:
				return true
	return false


func _has_turo_rescue_target(player: PlayerState) -> bool:
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if not _is_metal_body(slot) and slot.get_prize_count() >= 2 and slot.damage_counters >= 60:
				return true
	return false


func _is_marnie_matchup(game_state: GameState, player_index: int) -> bool:
	var resolved := resolve_opponent_deck(game_state, player_index)
	if bool(resolved.get("is_unique", false)) and int(resolved.get("deck_id", 0)) == MARNIE_DECK_ID:
		return true
	var candidates: Variant = resolved.get("candidate_deck_ids", [])
	if candidates is Array and MARNIE_DECK_ID in (candidates as Array):
		return true
	var opponent := _opponent_player(game_state, player_index)
	if opponent == null:
		return false
	for slot: PokemonSlot in _all_slots(opponent):
		if _matches_key(slot, MARNIE_IMPIDIMP) or _matches_key(slot, MARNIE_MORGREM) or _matches_key(slot, MARNIE_GRIMMSNARL):
			return true
	for card: CardInstance in opponent.discard_pile:
		if _matches_key(card, MARNIE_IMPIDIMP) or _matches_key(card, MARNIE_MORGREM) or _matches_key(card, MARNIE_GRIMMSNARL):
			return true
	return false


func _opponent_has_one_hit_target(game_state: GameState, player_index: int) -> bool:
	var player := _valid_player(game_state, player_index)
	var opponent := _opponent_player(game_state, player_index)
	var damage := _active_attack_damage(player)
	if opponent == null or damage <= 0:
		return false
	for slot: PokemonSlot in opponent.bench:
		if slot != null and slot.get_remaining_hp() <= damage:
			return true
	return false


func _active_attack_damage(player: PlayerState) -> int:
	if player == null or player.active_pokemon == null:
		return 0
	var prediction := predict_attacker_damage(player.active_pokemon)
	return int(prediction.get("damage", 0)) if bool(prediction.get("can_attack", false)) else 0


func _archaludon_damage(slot: PokemonSlot) -> int:
	return int(predict_attacker_damage(slot).get("damage", 220))


func _opponent_active(game_state: GameState, player_index: int) -> PokemonSlot:
	var opponent := _opponent_player(game_state, player_index)
	return opponent.active_pokemon if opponent != null else null


func _opponent_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state == null or game_state.players.size() < 2:
		return null
	var opponent_index := 1 - player_index
	return _valid_player(game_state, opponent_index)


func _valid_player(game_state: GameState, player_index: int) -> PlayerState:
	if game_state != null and player_index >= 0 and player_index < game_state.players.size():
		return game_state.players[player_index]
	return null


func _player_from_context(context: Dictionary) -> PlayerState:
	if context.get("player", null) is PlayerState:
		return context.get("player") as PlayerState
	return _valid_player(context.get("game_state", null), int(context.get("player_index", -1)))


func _pending_count(slot: PokemonSlot, context: Dictionary) -> int:
	var pending: Variant = context.get("pending_assignment_counts", {})
	if not pending is Dictionary or slot == null:
		return 0
	if (pending as Dictionary).has(slot.get_instance_id()):
		return int((pending as Dictionary).get(slot.get_instance_id(), 0))
	if (pending as Dictionary).has(slot):
		return int((pending as Dictionary).get(slot, 0))
	return 0


func _is_opponent_slot(slot: PokemonSlot, context: Dictionary) -> bool:
	var top := slot.get_top_card() if slot != null else null
	return top != null and int(top.owner_index) != int(context.get("player_index", -1))


func _is_gust_or_damage_step(step_id: String) -> bool:
	return step_id.contains("opponent") or step_id.contains("gust") or step_id.contains("boss") or step_id.contains("damage_target")


func _is_handoff_step(step_id: String) -> bool:
	return step_id.contains("switch") or step_id.contains("send") or step_id.contains("active") or step_id.contains("handoff")


func _is_recovery_step(step_id: String) -> bool:
	return step_id.contains("recover") or step_id.contains("stretcher") or step_id.contains("rod")


func _count_slots(player: PlayerState, key: String) -> int:
	var count := 0
	if player != null:
		for slot: PokemonSlot in _all_slots(player):
			if _matches_key(slot, key): count += 1
	return count


func _has_slot(player: PlayerState, key: String) -> bool:
	return _count_slots(player, key) > 0
