class_name AIHeuristics
extends RefCounted

# 卡组家族签名卡名称（用于轻量卡组检测）
const _MIRAIDON_SIGNATURES: Array[String] = ["Miraidon ex"]
const _GARDEVOIR_SIGNATURES: Array[String] = ["Gardevoir ex", "Kirlia"]
const _CHARIZARD_SIGNATURES: Array[String] = ["Charizard ex", "Charmeleon", "Charmander"]


func score_action(action: Dictionary, context: Dictionary) -> float:
	var features: Dictionary = context.get("features", {})
	action["reason_tags"] = []
	var score: float = _base_score(action, features)
	score += _apply_shared_adjustments(action, context, features)
	score += _apply_deck_bias(action, context, features)
	return score


func _base_score(action: Dictionary, features: Dictionary) -> float:
	match str(action.get("kind", "")):
		"attack":
			if bool(action.get("projected_knockout", false)):
				return 1000.0
			return 500.0
		"attach_energy":
			return 240.0 if bool(action.get("is_active_target", false)) else 200.0
		"play_basic_to_bench":
			return 180.0
		"evolve":
			return 170.0
		"use_ability":
			return 160.0
		"play_stadium":
			return 120.0
		"play_trainer":
			return 110.0 if _is_productive_trainer(action, features) else 20.0
		"retreat":
			return 90.0
		"end_turn":
			return 0.0
		_:
			return 10.0


func _apply_shared_adjustments(action: Dictionary, context: Dictionary, features: Dictionary) -> float:
	var score_delta := 0.0
	var kind := str(action.get("kind", ""))

	if _supports_bench_development(kind, features):
		score_delta += 70.0
		_add_reason_tag(action, "bench_development")

	if kind == "evolve" and _advances_stage2_line(action, context):
		score_delta += 140.0
		_add_reason_tag(action, "stage2_progress")

	if kind == "attach_energy" and bool(features.get("improves_attack_readiness", false)):
		score_delta += 80.0
		_add_reason_tag(action, "attack_readiness")

	if kind == "play_trainer" and not _is_productive_trainer(action, features):
		score_delta -= 30.0
		_add_reason_tag(action, "dead_trainer_penalty")

	return score_delta


func _supports_bench_development(kind: String, features: Dictionary) -> bool:
	if bool(features.get("improves_bench_development", false)):
		return true
	return kind == "play_trainer" and int(features.get("remaining_basic_targets", 0)) > 0


func _is_productive_trainer(action: Dictionary, features: Dictionary) -> bool:
	if features.has("productive"):
		return bool(features.get("productive", true))
	return bool(action.get("productive", true))


func _advances_stage2_line(action: Dictionary, context: Dictionary) -> bool:
	var evolution_card: CardInstance = action.get("card")
	if evolution_card == null or evolution_card.card_data == null:
		return false
	if str(evolution_card.card_data.stage) != "Stage 1":
		return false
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	for hand_card: CardInstance in game_state.players[player_index].hand:
		if hand_card == null or hand_card.card_data == null:
			continue
		if str(hand_card.card_data.stage) != "Stage 2":
			continue
		if str(hand_card.card_data.evolves_from) == str(evolution_card.card_data.name):
			return true
	return false


func _add_reason_tag(action: Dictionary, tag: String) -> void:
	var reason_tags: Array = action.get("reason_tags", [])
	if not reason_tags.has(tag):
		reason_tags.append(tag)
	action["reason_tags"] = reason_tags


# -- 轻量卡组偏好 --


func _apply_deck_bias(action: Dictionary, context: Dictionary, features: Dictionary) -> float:
	var deck_family := _detect_deck_family(context)
	if deck_family == "":
		return 0.0
	var score_delta := 0.0
	match deck_family:
		"miraidon":
			score_delta += _miraidon_bias(action, context, features)
		"gardevoir":
			score_delta += _gardevoir_bias(action, context, features)
		"charizard_ex":
			score_delta += _charizard_bias(action, context, features)
	if score_delta != 0.0:
		_add_reason_tag(action, "deck_bias")
	return score_delta


func _detect_deck_family(context: Dictionary) -> String:
	var game_state: GameState = context.get("game_state")
	var player_index: int = int(context.get("player_index", -1))
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return ""
	var player: PlayerState = game_state.players[player_index]
	var names: Array[String] = _collect_visible_card_names(player)
	if _has_any_signature(names, _MIRAIDON_SIGNATURES):
		return "miraidon"
	if _has_any_signature(names, _GARDEVOIR_SIGNATURES):
		return "gardevoir"
	if _has_any_signature(names, _CHARIZARD_SIGNATURES):
		return "charizard_ex"
	return ""


func _collect_visible_card_names(player: PlayerState) -> Array[String]:
	## 收集玩家所有可见卡牌的名称（手牌、场上、牌库）
	var names: Array[String] = []
	# 手牌
	for card: CardInstance in player.hand:
		if card != null and card.card_data != null:
			names.append(str(card.card_data.name))
	# 场上宝可梦（前场 + 后备）
	if player.active_pokemon != null:
		var active_cd: CardData = player.active_pokemon.get_card_data()
		if active_cd != null:
			names.append(str(active_cd.name))
	for slot: PokemonSlot in player.bench:
		if slot != null:
			var bench_cd: CardData = slot.get_card_data()
			if bench_cd != null:
				names.append(str(bench_cd.name))
	# 牌库
	for card: CardInstance in player.deck:
		if card != null and card.card_data != null:
			names.append(str(card.card_data.name))
	return names


func _has_any_signature(names: Array[String], signatures: Array[String]) -> bool:
	for sig: String in signatures:
		if sig in names:
			return true
	return false


func _miraidon_bias(action: Dictionary, _context: Dictionary, _features: Dictionary) -> float:
	## Miraidon 卡组：Electric Generator 加分、电属性基础上板加分
	var kind := str(action.get("kind", ""))
	var card: CardInstance = action.get("card")
	if kind == "play_trainer" and card != null and card.card_data != null:
		if str(card.card_data.name) == "Electric Generator":
			return 25.0
	if kind == "play_basic_to_bench" and card != null and card.card_data != null:
		if str(card.card_data.energy_type) == "L":
			return 15.0
	return 0.0


func _gardevoir_bias(action: Dictionary, _context: Dictionary, _features: Dictionary) -> float:
	## Gardevoir 卡组：超能进化线加分、Psychic Embrace 特性加分
	var kind := str(action.get("kind", ""))
	var card: CardInstance = action.get("card")
	if kind == "evolve" and card != null and card.card_data != null:
		var evo_name := str(card.card_data.name)
		if evo_name == "Gardevoir ex" or evo_name == "Kirlia":
			return 30.0
	if kind == "use_ability":
		var source_slot: PokemonSlot = action.get("source_slot")
		if source_slot != null:
			var slot_cd: CardData = source_slot.get_card_data()
			if slot_cd != null and _has_ability_named(slot_cd, "Psychic Embrace"):
				return 25.0
	return 0.0


func _charizard_bias(action: Dictionary, _context: Dictionary, _features: Dictionary) -> float:
	## Charizard 卡组：Rare Candy 加分、火属性进化线加分
	var kind := str(action.get("kind", ""))
	var card: CardInstance = action.get("card")
	if kind == "play_trainer" and card != null and card.card_data != null:
		if str(card.card_data.name) == "Rare Candy":
			return 25.0
	if kind == "evolve" and card != null and card.card_data != null:
		var evo_name := str(card.card_data.name)
		if evo_name == "Charmeleon" or evo_name == "Charizard ex":
			return 30.0
	return 0.0


func _has_ability_named(card_data: CardData, ability_name: String) -> bool:
	if card_data == null:
		return false
	for ability: Dictionary in card_data.abilities:
		if str(ability.get("name", "")) == ability_name:
			return true
	return false
