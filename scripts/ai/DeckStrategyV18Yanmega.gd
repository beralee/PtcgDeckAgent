class_name DeckStrategyV18Yanmega
extends "res://scripts/ai/DeckStrategy17InitialRulesBase.gd"


const YANMA: Array[String] = ["Yanma", "蜻蜻蜓"]
const YANMEGA_EX: Array[String] = ["Yanmega ex", "远古巨蜓ex"]
const BUDEW: Array[String] = ["Budew", "含羞苞"]
const DUNSPARCE: Array[String] = ["Dunsparce", "土龙弟弟"]
const DUDUNSPARCE: Array[String] = ["Dudunsparce", "土龙节节"]
const DUDUNSPARCE_EX: Array[String] = ["Dudunsparce ex", "土龙节节ex"]
const CRUSTLE: Array[String] = ["Crustle", "岩殿居蟹"]
const GRASS_ENERGY: Array[String] = ["Grass Energy", "基本草能量"]
const JET_ENERGY: Array[String] = ["Jet Energy", "喷射能量"]
const TM_EVOLUTION: Array[String] = ["Technical Machine: Evolution", "招式学习器 进化"]
const BUDDY_BUDDY_POFFIN: Array[String] = ["Buddy-Buddy Poffin", "友好宝芬"]
const ULTRA_BALL: Array[String] = ["Ultra Ball", "高级球"]
const ARTAZON: Array[String] = ["Artazon", "深钵镇"]

const SWITCH: Array[String] = ["Switch"]

const PROFILE := {
	"strategy_id": "v18_yanmega_route",
	"signatures": ["远古巨蜓ex", "蜻蜻蜓"],
	"active_priority": ["含羞苞", "米立龙", "土龙弟弟", "石居蟹", "蜻蜻蜓"],
	"bench_priority": ["蜻蜻蜓", "土龙弟弟", "石居蟹", "米立龙"],
	"energy_priority": ["远古巨蜓ex", "土龙节节ex", "岩殿居蟹"],
	"evolution_priority": ["远古巨蜓ex", "土龙节节", "土龙节节ex", "岩殿居蟹"],
	"search_priority": ["远古巨蜓ex", "蜻蜻蜓", "土龙节节", "土龙弟弟"],
	"ability_priority": ["远古巨蜓ex", "土龙节节", "土龙节节ex"],
	"trainer_priority": ["友好宝芬", "高级球", "巢穴球", "招式学习器 进化", "派帕"],
}

var _prediction_game_state: GameState = null
var _prediction_player_index := -1


func _profile() -> Dictionary:
	return PROFILE


func get_strategy_id() -> String:
	return "v18_yanmega_route"


func predict_attacker_damage(slot: PokemonSlot, extra_context: int = 0) -> Dictionary:
	if not _matches_any(slot, DUDUNSPARCE_EX):
		return super.predict_attacker_damage(slot, extra_context)
	if _prediction_game_state == null \
			or _prediction_player_index < 0 \
			or _prediction_player_index >= _prediction_game_state.players.size():
		return super.predict_attacker_damage(slot, extra_context)
	var can_attack := slot != null and slot.attached_energy.size() + extra_context >= 1
	var ex_count := _opponent_ex_count(_prediction_game_state, _prediction_player_index)
	return {
		"damage": ex_count * 60 if can_attack else 0,
		"can_attack": can_attack,
		"description": "adversity_tail_%d_ex" % ex_count,
	}


func build_turn_plan(game_state: GameState, player_index: int, context: Dictionary = {}) -> Dictionary:
	_remember_prediction_context(game_state, player_index)
	var plan := super.build_turn_plan(game_state, player_index, context)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return plan
	var player: PlayerState = game_state.players[player_index]
	if not _bench_has_yanmega(player):
		return plan
	plan["id"] = "v18_yanmega_route:buzzing_rush_handoff"
	plan["intent"] = "trigger_buzzing_rush_handoff"
	var flags: Dictionary = plan.get("flags", {}) if plan.get("flags", {}) is Dictionary else {}
	flags["allow_resource_paid_owner_retreat"] = true
	plan["flags"] = flags
	return plan


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	_remember_prediction_context(game_state, player_index)
	var score := super.score_action_absolute(action, game_state, player_index)
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return score
	var player: PlayerState = game_state.players[player_index]
	var kind := str(action.get("kind", ""))
	match kind:
		"play_basic_to_bench":
			var card: CardInstance = action.get("card", null)
			if _matches_any(card, YANMA):
				score += 850.0 if not _has_slot(player, YANMA) else 280.0
				if _tm_route_can_add_second_seed(player, game_state):
					score += 6500.0
			elif _matches_any(card, DUNSPARCE):
				if _extra_dunsparce_padding_blocks_yanmega(player):
					return minf(score, -3000.0)
				score += 360.0
		"play_trainer":
			var trainer: CardInstance = action.get("card", null)
			if _matches_any(trainer, BUDDY_BUDDY_POFFIN) and _tm_route_can_add_second_seed(player, game_state):
				score += 6500.0
			elif _matches_any(trainer, ULTRA_BALL) and _yanmega_access_broken(player):
				score += 5200.0
			elif _matches_any(trainer, SWITCH) and _yanmega_handoff_blocked(player):
				return maxf(score, 5600.0)
		"play_stadium":
			var stadium: CardInstance = action.get("card", null)
			if _matches_any(stadium, ARTAZON) and game_state.stadium_card == null \
					and player.bench.size() >= 5:
				return -3000.0
		"evolve":
			var evolution: CardInstance = action.get("card", null)
			var target: PokemonSlot = action.get("target_slot", null)
			if _matches_any(evolution, YANMEGA_EX):
				score += 1150.0
				score += 900.0 if target != player.active_pokemon else -250.0
				if target == player.active_pokemon and _should_harden_active_tm_carrier(player):
					score += 9200.0
				if target != player.active_pokemon and _count_slots(player, YANMEGA_EX) == 1:
					score += 2600.0
			elif _matches_any(evolution, DUDUNSPARCE) or _matches_any(evolution, DUDUNSPARCE_EX):
				score += 380.0
		"attach_energy":
			var target: PokemonSlot = action.get("target_slot", null)
			score += _yanmega_attach_bonus(action.get("card", null), target, player)
			score += _conversion_attach_bonus(action.get("card", null), target, game_state, player_index)
			score += _tm_evolution_energy_bonus(target, player)
		"attach_tool":
			var tool: CardInstance = action.get("card", null)
			var target: PokemonSlot = action.get("target_slot", action.get("target", null))
			if _matches_any(tool, TM_EVOLUTION):
				score += _tm_evolution_attach_bonus(target, player, game_state)
		"retreat":
			if _tm_route_retreat_forbidden(player, game_state):
				return minf(score, -3000.0)
			var target: PokemonSlot = action.get("bench_target", null)
			score += _conversion_handoff_priority(target, game_state, player_index)
			if _matches_any(target, YANMEGA_EX):
				score += 1450.0
		"attack", "granted_attack":
			var source: PokemonSlot = action.get("source_slot", player.active_pokemon)
			if kind == "granted_attack" and _is_tm_evolution_attack(action):
				var target_count := _tm_evolution_target_count(player)
				score += 7200.0 + float(target_count) * 900.0 if target_count > 0 else -3000.0
				if target_count == 1 and _tm_route_can_add_second_seed(player, game_state):
					score -= 5000.0
			elif _matches_any(source, YANMEGA_EX):
				score += 950.0 + float(int(action.get("projected_damage", 0))) * 2.0
		"use_ability":
			var source: PokemonSlot = action.get("source_slot", null)
			if _matches_any(source, DUDUNSPARCE) or _matches_any(source, DUDUNSPARCE_EX):
				score += 260.0 if player.deck.size() > 8 else -600.0
		"end_turn":
			if _bench_has_yanmega(player):
				score -= 1100.0
	return score


func score_interaction_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	_remember_prediction_context(context.get("game_state", null), int(context.get("player_index", -1)))
	var step_id := str(step.get("id", "")).to_lower()
	var player: PlayerState = null
	var context_state: GameState = context.get("game_state", null)
	var context_player_index := int(context.get("player_index", -1))
	if context_state != null and context_player_index >= 0 \
			and context_player_index < context_state.players.size():
		player = context_state.players[context_player_index]
	if item is PokemonSlot:
		if step_id == "scoop_up_cyclone_target" and player != null and _bench_has_yanmega(player):
			return 5600.0 if item == player.active_pokemon else -1400.0
		if step_id == "evolution_bench":
			if _matches_any(item, YANMA):
				return 2800.0
			if _matches_any(item, DUNSPARCE):
				return 600.0
			return -500.0
		if step_id == "move_energy_target":
			if _matches_any(item, YANMEGA_EX):
				return 2800.0
			if _matches_any(item, YANMA):
				return 1600.0
			return -500.0
		if step_id.contains("switch") or step_id.contains("active") or step_id.contains("send") or step_id.contains("handoff"):
			return score_handoff_target(item, step, context)
	if item is CardInstance:
		if step_id == "search_item" and _matches_any(item, SWITCH) \
				and _yanmega_handoff_blocked(player):
			return 5600.0
		if _matches_any(item, YANMEGA_EX):
			return 1200.0
		if _matches_any(item, YANMA):
			return 1080.0
		if _matches_any(item, DUDUNSPARCE) or _matches_any(item, DUDUNSPARCE_EX):
			return 720.0
		if _matches_any(item, GRASS_ENERGY):
			return 620.0
	return super.score_interaction_target(item, step, context)


func score_handoff_target(item: Variant, step: Dictionary, context: Dictionary = {}) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	_remember_prediction_context(game_state, player_index)
	if item is PokemonSlot:
		var conversion_priority := _conversion_handoff_priority(item as PokemonSlot, game_state, player_index)
		if conversion_priority > 0.0:
			return conversion_priority
	if item is PokemonSlot and _slot_has_tm_evolution(item):
		return 4200.0
	if item is PokemonSlot and _matches_any(item, YANMEGA_EX):
		var slot := item as PokemonSlot
		var score := 1800.0 + float(slot.attached_energy.size()) * 80.0
		var prediction := predict_attacker_damage(slot)
		var opponent_active := _opponent_active(game_state, player_index)
		if _is_pokemon_ex(opponent_active) \
				and bool(prediction.get("can_attack", false)) \
				and _would_knock_out(opponent_active, int(prediction.get("damage", 0))):
			score += 3600.0
		return score
	if item is PokemonSlot and (_matches_any(item, DUDUNSPARCE) or _matches_any(item, DUDUNSPARCE_EX)):
		return 180.0
	return super.score_handoff_target(item, step, context)


func get_search_priority(card: CardInstance) -> int:
	if _matches_any(card, YANMEGA_EX):
		return 1200
	if _matches_any(card, YANMA):
		return 1100
	if _matches_any(card, DUDUNSPARCE) or _matches_any(card, DUDUNSPARCE_EX):
		return 740
	return super.get_search_priority(card)


func get_discard_priority(card: CardInstance) -> int:
	if _matches_any(card, TM_EVOLUTION):
		return 1
	if _matches_any(card, YANMA) or _matches_any(card, YANMEGA_EX):
		return 5
	if _matches_any(card, GRASS_ENERGY) or _matches_any(card, JET_ENERGY):
		return 20
	return super.get_discard_priority(card)


func _yanmega_attach_bonus(energy: CardInstance, target: PokemonSlot, player: PlayerState) -> float:
	if target == null:
		return 0.0
	if _matches_any(target, YANMEGA_EX):
		if _matches_any(energy, JET_ENERGY) and target != player.active_pokemon:
			return 1700.0
		if _matches_any(energy, GRASS_ENERGY):
			var count := target.attached_energy.size()
			if count < 4:
				return 1050.0 - float(count) * 80.0
			return -500.0
	if _matches_any(target, YANMA) and _matches_any(energy, GRASS_ENERGY):
		return 300.0
	return -180.0


func _conversion_attach_bonus(
	energy: CardInstance,
	target: PokemonSlot,
	game_state: GameState,
	player_index: int
) -> float:
	if not _matches_any(target, DUDUNSPARCE_EX) or _opponent_ex_count(game_state, player_index) < 4:
		return 0.0
	if not (_matches_any(energy, GRASS_ENERGY) or _matches_any(energy, JET_ENERGY)):
		return 0.0
	return 2700.0 if target.attached_energy.is_empty() else -1400.0


func _conversion_handoff_priority(slot: PokemonSlot, game_state: GameState, player_index: int) -> float:
	if slot == null:
		return 0.0
	var prediction := predict_attacker_damage(slot)
	if not bool(prediction.get("can_attack", false)):
		return 0.0
	var damage := int(prediction.get("damage", 0))
	var opponent_active := _opponent_active(game_state, player_index)
	if _matches_any(slot, DUDUNSPARCE_EX) and _opponent_ex_count(game_state, player_index) >= 4:
		return 3200.0 + float(damage) * 4.0 + (1800.0 if _would_knock_out(opponent_active, damage) else 0.0)
	if _matches_any(slot, CRUSTLE) and _is_pokemon_ex(opponent_active):
		return 4600.0 + (1800.0 if _would_knock_out(opponent_active, damage) else 0.0)
	return 0.0


func _tm_evolution_attach_bonus(target: PokemonSlot, player: PlayerState, game_state: GameState) -> float:
	if target == null or player == null:
		return -4000.0
	var attack_locked := _first_player_attack_locked(game_state, player)
	if attack_locked:
		return -4000.0
	if target != player.active_pokemon:
		return -4000.0
	var target_count := _tm_evolution_target_count(player)
	if target_count <= 0:
		return 1000.0 if _matches_any(target, BUDEW) else -800.0
	if not _can_fund_tm_evolution_attack(target, player, game_state):
		return 900.0
	return 4200.0 + float(target_count) * 600.0


func _tm_evolution_energy_bonus(target: PokemonSlot, player: PlayerState) -> float:
	if player == null or player.active_pokemon == null:
		return 0.0
	var carrier := _tm_route_carrier(player)
	if carrier == null or _tm_evolution_target_count(player) <= 0:
		return 0.0
	if not carrier.attached_energy.is_empty():
		return 0.0
	return 5000.0 if target == carrier else -3000.0


func _can_fund_tm_evolution_attack(target: PokemonSlot, player: PlayerState, game_state: GameState) -> bool:
	if target != null and not target.attached_energy.is_empty():
		return true
	if game_state != null and game_state.energy_attached_this_turn:
		return false
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null and card.card_data.is_energy():
			return true
	return false


func _tm_evolution_target_count(player: PlayerState) -> int:
	if player == null:
		return 0
	var yanma_count := 0
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, YANMA):
			yanma_count += 1
	var yanmega_in_deck := 0
	for card: CardInstance in player.deck:
		if _matches_any(card, YANMEGA_EX):
			yanmega_in_deck += 1
	return mini(2, mini(yanma_count, yanmega_in_deck))


func _should_harden_active_tm_carrier(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null:
		return false
	var active := player.active_pokemon
	if not _matches_any(active, YANMA) \
			or not _slot_has_tm_evolution(active) \
			or active.attached_energy.is_empty():
		return false
	var bench_yanma_count := 0
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, YANMA):
			bench_yanma_count += 1
	if bench_yanma_count < 2 or _tm_evolution_target_count(player) != 2:
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, YANMEGA_EX):
			return true
	return false


func _tm_route_can_add_second_seed(player: PlayerState, game_state: GameState) -> bool:
	if player == null or _tm_evolution_target_count(player) >= 2:
		return false
	if BenchLimitHelper.get_available_bench_space(game_state, player) <= 0:
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, YANMA):
			return true
	var has_poffin := false
	for card: CardInstance in player.hand:
		if _matches_any(card, BUDDY_BUDDY_POFFIN):
			has_poffin = true
			break
	if not has_poffin:
		return false
	for card: CardInstance in player.deck:
		if _matches_any(card, YANMA):
			return true
	return false


func _is_tm_evolution_attack(action: Dictionary) -> bool:
	var granted_raw: Variant = action.get("granted_attack_data", {})
	if not (granted_raw is Dictionary):
		return false
	var granted: Dictionary = granted_raw
	return str(granted.get("id", "")) == "tm_evolution" or str(granted.get("name", "")) in ["Evolution", "进化"]


func _tm_route_retreat_forbidden(player: PlayerState, game_state: GameState) -> bool:
	if player == null or _tm_evolution_target_count(player) <= 0:
		return false
	if _bench_has_yanmega(player):
		return false
	var carrier := _tm_route_carrier(player)
	if carrier == null:
		return false
	return carrier == player.active_pokemon or _first_player_attack_locked(game_state, player)


func _tm_route_carrier(player: PlayerState) -> PokemonSlot:
	if player == null:
		return null
	if _slot_has_tm_evolution(player.active_pokemon):
		return player.active_pokemon
	for slot: PokemonSlot in player.bench:
		if _slot_has_tm_evolution(slot):
			return slot
	return null


func _first_player_attack_locked(game_state: GameState, player: PlayerState) -> bool:
	return game_state != null \
		and player != null \
		and int(game_state.turn_number) == 1 \
		and int(game_state.first_player_index) == int(player.player_index)


func _slot_has_tm_evolution(slot: PokemonSlot) -> bool:
	return slot != null and _matches_any(slot.attached_tool, TM_EVOLUTION)


func _bench_has_yanmega(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, YANMEGA_EX):
			return true
	return false


func _yanmega_handoff_blocked(player: PlayerState) -> bool:
	if player == null or player.active_pokemon == null or _matches_any(player.active_pokemon, YANMEGA_EX):
		return false
	for slot: PokemonSlot in player.bench:
		if _matches_any(slot, YANMEGA_EX) and bool(predict_attacker_damage(slot).get("can_attack", false)):
			return true
	return false


func _extra_dunsparce_padding_blocks_yanmega(player: PlayerState) -> bool:
	return player != null \
		and _has_slot(player, YANMA) \
		and not _has_slot(player, YANMEGA_EX) \
		and _count_slots(player, DUNSPARCE) >= 1


func _yanmega_access_broken(player: PlayerState) -> bool:
	if player == null or not _has_slot(player, YANMA) or _has_slot(player, YANMEGA_EX):
		return false
	for card: CardInstance in player.hand:
		if _matches_any(card, YANMEGA_EX):
			return false
	for card: CardInstance in player.deck:
		if _matches_any(card, YANMEGA_EX):
			return true
	return false


func _has_slot(player: PlayerState, names: Array[String]) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches_any(slot, names):
			return true
	return false


func _count_slots(player: PlayerState, names: Array[String]) -> int:
	if player == null:
		return 0
	var count := 0
	for slot: PokemonSlot in player.get_all_pokemon():
		if _matches_any(slot, names):
			count += 1
	return count


func _remember_prediction_context(game_state: GameState, player_index: int) -> void:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return
	_prediction_game_state = game_state
	_prediction_player_index = player_index


func _opponent_active(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index].active_pokemon


func _opponent_ex_count(game_state: GameState, player_index: int) -> int:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return 0
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return 0
	var count := 0
	for slot: PokemonSlot in game_state.players[opponent_index].get_all_pokemon():
		if _is_pokemon_ex(slot):
			count += 1
	return count


func _is_pokemon_ex(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var card_data: CardData = slot.get_card_data()
	return card_data.mechanic == "ex" or card_data.has_tag("ex")


func _would_knock_out(defender: PokemonSlot, damage: int) -> bool:
	return defender != null and damage > 0 and damage >= defender.get_remaining_hp()


func _matches_any(item: Variant, names: Array[String]) -> bool:
	for name: String in names:
		if _matches_key(item, name):
			return true
	return false
