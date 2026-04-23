class_name LLMTurnPlanPromptBuilder
extends RefCounted

const SCHEMA_VERSION := "llm_turn_plan_v1"

const VALID_INTENTS: Array[String] = [
	"setup_board", "fuel_discard", "charge_bolt",
	"pressure_expand", "convert_attack", "emergency_retreat",
]


func build_request_payload(game_state: GameState, player_index: int) -> Dictionary:
	if game_state == null or player_index < 0 or player_index >= game_state.players.size():
		return {}
	var player: PlayerState = game_state.players[player_index]
	var opponent_index: int = 1 - player_index
	var opponent: PlayerState = game_state.players[opponent_index] if opponent_index >= 0 and opponent_index < game_state.players.size() else null
	return {
		"system_prompt_version": SCHEMA_VERSION,
		"response_format": response_schema(),
		"instructions": instructions(),
		"game_state": _serialize_game_state(game_state, player, opponent, player_index),
	}


func parse_llm_response_to_turn_plan(response: Dictionary) -> Dictionary:
	var intent: String = str(response.get("intent", "")).strip_edges()
	if intent not in VALID_INTENTS:
		return {}
	var primary_target: String = str(response.get("primary_target", "")).strip_edges()
	var suppress_supporters: Array = response.get("suppress_supporters", []) if response.get("suppress_supporters", []) is Array else []
	var flags := {
		"llm_driven": true,
		"hand_has_sada": false,
		"hand_has_earthen_vessel": false,
		"hand_has_energy_retrieval": false,
		"discard_has_fuel": false,
		"active_is_stuck": intent == "emergency_retreat",
		"suppress_supporters": suppress_supporters,
	}
	return {
		"intent": intent,
		"phase": "",
		"flags": flags,
		"targets": {
			"primary_attacker_name": primary_target,
			"bridge_target_name": primary_target if intent in ["charge_bolt", "fuel_discard"] else "",
			"pivot_target_name": "",
		},
		"constraints": _constraints_for_intent(intent),
		"context": {"source": "llm"},
	}


func instructions() -> PackedStringArray:
	return PackedStringArray([
		"你是猛雷鼓(Raging Bolt)卡组的策略AI。",
		"猛雷鼓卡组的核心链路：大地容器弃基础能量填弃牌堆 → 奥琳博士(Sada)从弃牌堆贴能量到猛雷鼓 → 猛雷鼓攻击。",
		"每回合只能使用一张支援者卡。如果手上有奥琳博士且弃牌堆有≥2基础能量，绝不能浪费支援者位给抽牌支援者。",
		"分析提供的场面状态，返回本回合最佳意图(intent)。",
		"可用intent: setup_board（无攻击手在场）, fuel_discard（弃牌堆能量不足需要填充）, charge_bolt（弃牌堆就绪+手有Sada可充能）, pressure_expand（一只就绪需要展开后备）, convert_attack（多只就绪应集中攻击）, emergency_retreat（前场被困需要换人）",
		"primary_target应为场上能量缺口最小的猛雷鼓ex的名字。",
		"suppress_supporters列出本回合不应使用的支援者卡名。",
		"priority_actions列出3-5步具体操作顺序。",
		"reasoning用一句话解释为什么选这个intent。",
	])


func response_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": false,
		"required": ["intent", "primary_target", "priority_actions", "suppress_supporters", "reasoning"],
		"properties": {
			"intent": {
				"type": "string",
				"enum": VALID_INTENTS,
			},
			"primary_target": {"type": "string", "maxLength": 60},
			"priority_actions": {
				"type": "array",
				"maxItems": 5,
				"items": {"type": "string", "maxLength": 120},
			},
			"suppress_supporters": {
				"type": "array",
				"maxItems": 4,
				"items": {"type": "string", "maxLength": 40},
			},
			"reasoning": {"type": "string", "maxLength": 200},
		},
	}


func _serialize_game_state(game_state: GameState, player: PlayerState, opponent: PlayerState, player_index: int) -> Dictionary:
	var data := {
		"turn_number": int(game_state.turn_number),
		"player_index": player_index,
		"my_field": _serialize_player_field(player, true),
	}
	if opponent != null:
		data["opponent_field"] = _serialize_player_field(opponent, false)
	return data


func _serialize_player_field(player: PlayerState, include_hand: bool) -> Dictionary:
	var field := {
		"prize_count": player.prizes.size(),
		"deck_count": player.deck.size(),
		"active": _serialize_slot(player.active_pokemon),
		"bench": _serialize_slot_array(player.bench),
		"discard_pile": _serialize_card_names(player.discard_pile),
	}
	if include_hand:
		field["hand"] = _serialize_hand(player)
	return field


func _serialize_hand(player: PlayerState) -> Array[Dictionary]:
	var hand: Array[Dictionary] = []
	for card: CardInstance in player.hand:
		if card == null or card.card_data == null:
			continue
		var entry := {"name": str(card.card_data.name), "type": str(card.card_data.card_type)}
		if card.card_data.card_type == "Pokemon":
			entry["stage"] = str(card.card_data.stage)
		hand.append(entry)
	return hand


func _serialize_slot(slot: PokemonSlot) -> Dictionary:
	if slot == null or slot.get_top_card() == null:
		return {}
	var data := {
		"name": str(slot.get_pokemon_name()),
		"hp": slot.get_remaining_hp(),
		"max_hp": int(slot.get_card_data().hp) if slot.get_card_data() != null else 0,
		"attached_energy": _serialize_energy_counts(slot),
		"retreat_cost": int(slot.get_card_data().retreat_cost) if slot.get_card_data() != null else 0,
	}
	if slot.get_card_data() != null and not slot.get_card_data().attacks.is_empty():
		var attacks: Array[Dictionary] = []
		for attack: Dictionary in slot.get_card_data().attacks:
			attacks.append({
				"name": str(attack.get("name", "")),
				"damage": str(attack.get("damage", "0")),
				"cost": str(attack.get("cost", "")),
			})
		data["attacks"] = attacks
	return data


func _serialize_energy_counts(slot: PokemonSlot) -> Dictionary:
	var counts := {}
	for card: CardInstance in slot.attached_energy:
		if card == null or card.card_data == null:
			continue
		var energy_type: String = str(card.card_data.energy_provides)
		counts[energy_type] = int(counts.get(energy_type, 0)) + 1
	return counts


func _serialize_slot_array(slots: Array[PokemonSlot]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: PokemonSlot in slots:
		var serialized := _serialize_slot(slot)
		if not serialized.is_empty():
			result.append(serialized)
	return result


func _serialize_card_names(cards: Array[CardInstance]) -> Array[String]:
	var names: Array[String] = []
	for card: CardInstance in cards:
		if card != null and card.card_data != null:
			names.append(str(card.card_data.name))
	return names


func _constraints_for_intent(intent: String) -> Dictionary:
	match intent:
		"charge_bolt":
			return {"forbid_draw_supporter_waste": true}
		"convert_attack":
			return {"forbid_engine_churn": true}
	return {}
