extends "res://scripts/ai/DeckStrategy17LLMBase.gd"

const PALKIA_LLM_GIMMIGHOUL_BASIC_NAMES: Array[String] = ["Gimmighoul", "索财灵", "CSV9C_096"]
const PALKIA_LLM_GIMMIGHOUL_DAMAGE_ATTACK_NAMES: Array[String] = ["Tackle", "撞击", "鎾炲嚮"]
const PALKIA_LLM_GIMMIGHOUL_SETUP_ATTACK_NAMES: Array[String] = ["Little Messenger", "小使者"]
const PALKIA_LLM_GIMMIGHOUL_EFFECT_IDS: Array[String] = ["6c6c611ae3397c524ea28fec85c1f8b8"]
const PALKIA_LLM_GHOLDENGO_EX_NAMES: Array[String] = ["Gholdengo ex", "赛富豪ex"]

const PALKIA_LLM_PALKIA_V_NAMES: Array[String] = ["Origin Forme Palkia V", "起源帕路奇亚V"]
const PALKIA_LLM_GHOLDENGO_LINE_NAMES: Array[String] = ["Gimmighoul", "索财灵", "CSV9C_096", "Gholdengo ex", "赛富豪ex"]
const PALKIA_LLM_LIGHTNING_PRESSURE_NAMES: Array[String] = [
	"Miraidon ex",
	"密勒顿ex",
	"Raikou V",
	"雷公V",
	"Iron Hands ex",
	"铁臂膀ex",
	"Iron Thorns ex",
	"铁荆棘ex",
	"Raichu V",
	"雷丘V",
]


func _llm_strategy_id() -> String:
	return "v17_palkia_gholdengo_llm"


func _rules_strategy_path() -> String:
	return "res://scripts/ai/DeckStrategy17PalkiaGholdengo.gd"


func _deck_display_name() -> String:
	return "17.0 水龙赛富豪"


func plan_opening_setup(player: PlayerState) -> Dictionary:
	var plan: Dictionary = super.plan_opening_setup(player)
	return _palkia_llm_filter_opening_palkia_v_liability(plan, player)


func score_action_absolute(action: Dictionary, game_state: GameState, player_index: int) -> float:
	if _palkia_llm_is_early_palkia_v_bench_liability(action, game_state, player_index):
		return -10000.0
	if _palkia_llm_should_block_low_value_gimmighoul_attack(action, game_state, player_index):
		return -10000.0
	return super.score_action_absolute(action, game_state, player_index)


func score_action(action: Dictionary, context: Dictionary) -> float:
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	if _palkia_llm_is_early_palkia_v_bench_liability(action, game_state, player_index):
		return -10000.0
	if _palkia_llm_should_block_low_value_gimmighoul_attack(action, game_state, player_index):
		return -10000.0
	return super.score_action(action, context)


func _is_low_value_runtime_attack_action(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if _palkia_llm_is_low_value_gimmighoul_damage_attack(action, game_state, player_index):
		return true
	if _palkia_llm_is_premature_gimmighoul_setup_attack(action, game_state, player_index):
		return true
	return super._is_low_value_runtime_attack_action(action, game_state, player_index)


func pick_interaction_items(items: Array, step: Dictionary, context: Dictionary = {}) -> Array:
	var step_id := str(step.get("id", "")).to_lower()
	if step_id.contains("discard_basic_energy"):
		var forced := _palkia_llm_pick_make_it_rain_energy(items, step, context)
		if not forced.is_empty():
			return forced
	return super.pick_interaction_items(items, step, context)


func _deck_primary_attackers() -> Array[String]:
	return ["Gholdengo ex", "赛富豪ex", "Gimmighoul", "索财灵", "CSV9C_096", "Origin Forme Palkia VSTAR", "Origin Forme Palkia V", "起源帕路奇亚VSTAR", "起源帕路奇亚V"]


func _deck_secondary_attackers() -> Array[String]:
	return ["Radiant Greninja", "Iron Bundle"]


func _deck_support_pokemon() -> Array[String]:
	return ["Radiant Greninja", "Fezandipiti ex", "Manaphy", "Iron Bundle"]


func _deck_energy_banks() -> Array[String]:
	return ["Gholdengo ex", "Origin Forme Palkia VSTAR"]


func _deck_primary_attacks() -> Array:
	return [
		{"pokemon": "Gholdengo ex", "attack": "Make It Rain"},
		{"pokemon": "赛富豪ex", "attack": "淘金潮"},
		{"pokemon": "Origin Forme Palkia VSTAR", "attack": "Subspace Swell"},
		{"pokemon": "起源帕路奇亚VSTAR", "attack": "亚空潮漩"},
	]


func _deck_low_value_attacks() -> Array:
	return [
		{"pokemon": "索财灵", "attack": "撞击"},
		{"pokemon": "Gimmighoul", "attack": "Tackle"},
	]


func _deck_evolution_lines() -> Array:
	return [
		{"basic": "Gimmighoul", "stages": ["Gholdengo ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"M": 1}},
		{"basic": "索财灵", "stages": ["赛富豪ex"], "role": "primary_attacker", "desired_count": 2, "energy": {"M": 1}},
		{"basic": "Origin Forme Palkia V", "stages": ["Origin Forme Palkia VSTAR"], "role": "secondary_attacker", "desired_count": 1, "energy": {"W": 2}},
	]


func _deck_energy_needs() -> Dictionary:
	return {
		"Gholdengo ex": {"M": 1},
		"Origin Forme Palkia V": {"W": 2},
		"Origin Forme Palkia VSTAR": {"W": 2},
	}


func _deck_route_terms() -> Array[String]:
	return ["淘金潮", "嘉奖硬币", "能量搜索PRO", "高级能量回收", "能量回收", "大地容器", "亚空潮漩", "星耀空扉", "基本钢能量", "基本水能量"]


func _deck_core_plan() -> PackedStringArray:
	return PackedStringArray([
		"【核心计划】前期铺 Gimmighoul 与 Palkia V，T2 优先完成 Gholdengo ex 或 Palkia VSTAR 的有效攻击路线。",
		"【赛富豪路线】Gholdengo ex 的 Make It Rain 需要手牌基础能量作为伤害资源。Energy Search Pro、Superior Energy Retrieval、Energy Retrieval 和 Earthen Vessel 都应服务于本回合斩杀或下回合连续进攻。",
		"【水龙路线】Palkia VSTAR 是稳定副打手和能量压力点。若 Gholdengo 缺能量或进化件，Palkia 可以承担 T2/T3 进攻。",
		"【强模式对电】对手已展示 Miraidon/雷系高压时，不要把 2 奖且弱电的 Palkia V 暴露在备战区；先用 Gimmighoul/Gholdengo 单奖线承压，只有没有雷系奖赏压力时再启用 Palkia。",
		"STRONG-MODE VS LIGHTNING: do not spend a tempo turn on Gimmighoul's 50 damage Tackle unless it takes a KO; pivot, evolve, recover energy, and attack with Gholdengo ex / Make It Rain instead.",
		"【资源原则】Make It Rain 只丢达到击倒或高压所需的最少能量；低牌库时不要为了额外抽滤牺牲已经成立的攻击路线。",
	])


func _palkia_llm_filter_opening_palkia_v_liability(plan: Dictionary, player: PlayerState) -> Dictionary:
	if player == null or plan.is_empty():
		return plan
	var filtered := plan.duplicate(true)
	var active_index := int(filtered.get("active_hand_index", -1))
	if active_index >= 0 and active_index < player.hand.size() and _palkia_llm_is_palkia_v_card(player.hand[active_index]):
		var safer_active := _palkia_llm_best_single_prize_basic_index(player, active_index)
		if safer_active >= 0:
			filtered["active_hand_index"] = safer_active
			active_index = safer_active
	var raw_bench: Array = filtered.get("bench_hand_indices", []) if filtered.get("bench_hand_indices", []) is Array else []
	var bench_indices: Array[int] = []
	for raw_index: Variant in raw_bench:
		var hand_index := int(raw_index)
		if hand_index < 0 or hand_index >= player.hand.size() or hand_index == active_index:
			continue
		if _palkia_llm_is_palkia_v_card(player.hand[hand_index]):
			continue
		bench_indices.append(hand_index)
	filtered["bench_hand_indices"] = bench_indices
	return filtered


func _palkia_llm_best_single_prize_basic_index(player: PlayerState, excluded_index: int) -> int:
	var best_index := -1
	var best_score := -1
	for hand_index: int in player.hand.size():
		if hand_index == excluded_index:
			continue
		var card: CardInstance = player.hand[hand_index]
		if card == null or not card.is_basic_pokemon() or _palkia_llm_is_multi_prize_card(card):
			continue
		var name := _palkia_llm_card_name(card)
		var score := 10
		if _palkia_llm_exact_name_in(name, ["Gimmighoul", "索财灵", "CSV9C_096"]):
			score = 100
		elif _palkia_llm_exact_name_in(name, ["Manaphy", "玛纳霏"]):
			score = 60
		if score > best_score:
			best_score = score
			best_index = hand_index
	return best_index


func _palkia_llm_is_early_palkia_v_bench_liability(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	if str(action.get("kind", action.get("type", ""))) != "play_basic_to_bench":
		return false
	if not _palkia_llm_is_palkia_v_card(action.get("card", null)):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	if player == null or _count_field_names(player, PALKIA_LLM_GHOLDENGO_LINE_NAMES) <= 0:
		return false
	return _palkia_llm_opponent_has_lightning_pressure(game_state, player_index)


func _palkia_llm_should_block_low_value_gimmighoul_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	return (_palkia_llm_is_low_value_gimmighoul_damage_attack(action, game_state, player_index) \
			or _palkia_llm_is_premature_gimmighoul_setup_attack(action, game_state, player_index)) \
			and _should_block_low_value_runtime_attack_context(game_state, player_index)


func _palkia_llm_is_low_value_gimmighoul_damage_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attack", "granted_attack"]:
		return false
	if bool(action.get("projected_knockout", false)):
		return false
	var source := _palkia_llm_action_source_slot(action, game_state, player_index)
	if source == null or not _palkia_llm_is_gimmighoul_basic_slot(source):
		return false
	var attack_name := str(action.get("attack_name", action.get("attack", ""))).strip_edges()
	if _matches_any(attack_name, PALKIA_LLM_GIMMIGHOUL_DAMAGE_ATTACK_NAMES):
		return true
	var attack_index := int(action.get("attack_index", -1))
	var projected_damage := int(action.get("projected_damage", 0))
	return attack_index >= 1 and projected_damage > 0 and projected_damage <= 90


func _palkia_llm_is_premature_gimmighoul_setup_attack(action: Dictionary, game_state: GameState, player_index: int) -> bool:
	var kind := str(action.get("kind", action.get("type", "")))
	if kind not in ["attack", "granted_attack"]:
		return false
	if bool(action.get("projected_knockout", false)):
		return false
	var source := _palkia_llm_action_source_slot(action, game_state, player_index)
	if source == null or not _palkia_llm_is_gimmighoul_basic_slot(source):
		return false
	if source.turn_played >= 0 and game_state != null and source.turn_played >= int(game_state.turn_number):
		return false
	var attack_name := str(action.get("attack_name", action.get("attack", ""))).strip_edges()
	var attack_index := int(action.get("attack_index", -1))
	if attack_index != 0 and not _matches_any(attack_name, PALKIA_LLM_GIMMIGHOUL_SETUP_ATTACK_NAMES):
		return false
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return false
	var player: PlayerState = game_state.players[player_index]
	return bool(self.call("_palkia_llm_player_hand_has_name", player, PALKIA_LLM_GHOLDENGO_EX_NAMES)) \
			and bool(self.call("_palkia_llm_opponent_has_lightning_pressure", game_state, player_index))


func _palkia_llm_is_gimmighoul_basic_slot(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd := slot.get_card_data()
	if cd == null:
		return false
	if PALKIA_LLM_GIMMIGHOUL_EFFECT_IDS.has(str(cd.effect_id)):
		return true
	return _matches_any(_best_card_name(cd), PALKIA_LLM_GIMMIGHOUL_BASIC_NAMES)


func _palkia_llm_action_source_slot(action: Dictionary, game_state: GameState, player_index: int) -> PokemonSlot:
	var raw_source: Variant = action.get("source_slot", null)
	if raw_source is PokemonSlot:
		return raw_source as PokemonSlot
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return null
	var player: PlayerState = game_state.players[player_index]
	return player.active_pokemon if player != null else null


func _palkia_llm_pick_make_it_rain_energy(items: Array, step: Dictionary, context: Dictionary) -> Array:
	var max_select := int(step.get("max_select", 1))
	if max_select <= 0:
		max_select = 1
	var energies: Array = []
	for item: Variant in items:
		if item is CardInstance and _palkia_llm_is_basic_energy(item as CardInstance):
			energies.append(item)
	if energies.is_empty():
		return []
	energies.sort_custom(func(a: Variant, b: Variant) -> bool:
		return _palkia_llm_make_it_rain_energy_discard_score(a as CardInstance) > _palkia_llm_make_it_rain_energy_discard_score(b as CardInstance)
	)
	var pick_count := mini(max_select, energies.size())
	var game_state: GameState = context.get("game_state", null)
	var player_index := int(context.get("player_index", -1))
	var remaining_hp := _palkia_llm_opponent_active_remaining_hp(game_state, player_index)
	if remaining_hp > 0 and remaining_hp < 999:
		var required_count := maxi(1, int(ceil(float(remaining_hp) / 50.0)))
		pick_count = mini(pick_count, required_count) if energies.size() >= required_count else pick_count
	return energies.slice(0, pick_count)


func _palkia_llm_make_it_rain_energy_discard_score(card: CardInstance) -> float:
	if card == null or card.card_data == null:
		return 0.0
	var provides := str(card.card_data.energy_provides).to_upper()
	var energy_type := str(card.card_data.energy_type).to_upper()
	var score := 100.0
	if not (provides.contains("M") or energy_type == "M"):
		score += 10.0
	return score


func _palkia_llm_is_basic_energy(card: CardInstance) -> bool:
	return card != null and card.card_data != null and str(card.card_data.card_type) == "Basic Energy"


func _palkia_llm_player_hand_has_name(player: PlayerState, candidates: Array[String]) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		if _palkia_llm_exact_name_in(_best_card_name(card.card_data), candidates):
			return true
	return false


func _palkia_llm_opponent_active_remaining_hp(game_state: GameState, player_index: int) -> int:
	var opponent_index := 1 - player_index
	if game_state == null or opponent_index < 0 or opponent_index >= game_state.players.size():
		return -1
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null or opponent.active_pokemon == null:
		return -1
	return opponent.active_pokemon.get_remaining_hp()


func _palkia_llm_opponent_has_lightning_pressure(game_state: GameState, player_index: int) -> bool:
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	var opponent: PlayerState = game_state.players[opponent_index]
	if opponent == null:
		return false
	if _palkia_llm_slot_is_lightning_pressure(opponent.active_pokemon):
		return true
	for slot: PokemonSlot in opponent.bench:
		if _palkia_llm_slot_is_lightning_pressure(slot):
			return true
	return false


func _palkia_llm_slot_is_lightning_pressure(slot: PokemonSlot) -> bool:
	if slot == null:
		return false
	var cd := slot.get_card_data()
	if cd != null:
		if str(cd.energy_type).to_upper() == "L":
			return true
		if _palkia_llm_exact_name_in(_best_card_name(cd), PALKIA_LLM_LIGHTNING_PRESSURE_NAMES):
			return true
	for energy: CardInstance in slot.attached_energy:
		if energy != null and energy.card_data != null:
			var provides := str(energy.card_data.energy_provides)
			var energy_type := str(energy.card_data.energy_type)
			if provides.to_upper().contains("L") or energy_type.to_upper() == "L":
				return true
	return false


func _palkia_llm_is_palkia_v_card(card: Variant) -> bool:
	return _palkia_llm_exact_name_in(_palkia_llm_card_name(card), PALKIA_LLM_PALKIA_V_NAMES)


func _palkia_llm_is_multi_prize_card(card: Variant) -> bool:
	var cd: CardData = null
	if card is CardInstance:
		cd = (card as CardInstance).card_data
	elif card is CardData:
		cd = card as CardData
	if cd == null:
		return false
	var mechanic := str(cd.mechanic).to_upper()
	return mechanic in ["EX", "V", "VMAX", "VSTAR"]


func _palkia_llm_card_name(card: Variant) -> String:
	var cd: CardData = null
	if card is CardInstance:
		cd = (card as CardInstance).card_data
	elif card is CardData:
		cd = card as CardData
	elif card is Dictionary:
		var dict: Dictionary = card
		for key: String in ["name_en", "card", "card_name", "name"]:
			var value := str(dict.get(key, ""))
			if value != "":
				return value
	if cd == null:
		return str(card)
	return _best_card_name(cd)


func _palkia_llm_exact_name_in(name: String, candidates: Array[String]) -> bool:
	var normalized := name.strip_edges().to_lower()
	for candidate: String in candidates:
		if normalized == candidate.strip_edges().to_lower():
			return true
	return false
