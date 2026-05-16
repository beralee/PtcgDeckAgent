class_name BattleDiscussionContextBuilder
extends RefCounted


func current_signature(selected_deck_ids: Array, mode: Variant, view_player: int) -> String:
	var deck_ids: PackedStringArray = []
	for deck_id: Variant in selected_deck_ids:
		deck_ids.append(str(deck_id))
	return "%s:%d:%s" % [str(mode), int(view_player), ",".join(deck_ids)]


func session_id(selected_deck_ids: Array, view_player: int) -> int:
	var deck_a := int(selected_deck_ids[0]) if selected_deck_ids.size() > 0 else 0
	var deck_b := int(selected_deck_ids[1]) if selected_deck_ids.size() > 1 else 0
	return 730000000 + int(view_player) * 100000000 + (abs(deck_a) % 10000) * 10000 + (abs(deck_b) % 10000)


func build_context(snapshot: Dictionary, view_player: int, my_deck: DeckData, opp_deck: DeckData) -> Dictionary:
	var opponent_index := 1 - int(view_player)
	var players: Array = snapshot.get("players", [])
	var my_player: Dictionary = players[view_player] if view_player >= 0 and view_player < players.size() and players[view_player] is Dictionary else {}
	var opp_player: Dictionary = players[opponent_index] if opponent_index >= 0 and opponent_index < players.size() and players[opponent_index] is Dictionary else {}
	var my_prize_remaining := int(my_player.get("prize_count", 0))
	var opponent_prize_remaining := int(opp_player.get("prize_count", 0))
	var my_prizes_taken := prizes_taken_from_remaining(my_prize_remaining)
	var opponent_prizes_taken := prizes_taken_from_remaining(opponent_prize_remaining)
	var current_player_index := int(snapshot.get("current_player_index", -1))
	return {
		"context_type": "live_battle_visible_state",
		"perspective_player_index": view_player,
		"perspective_label": "玩家%d / %s" % [view_player + 1, my_deck.deck_name if my_deck != null else "未知卡组"],
		"score_explanation": {
			"prize_remaining_score": "my_prize_remaining-opponent_prize_remaining; lower remaining prize count is better",
			"prizes_taken_score": "my_prizes_taken-opponent_prizes_taken; higher taken prize count is better",
			"do_not_treat_remaining_prizes_as_prizes_taken": true,
		},
		"hidden_information_policy": {
			"allowed": [
				"己方手牌完整内容",
				"己方公开场面、弃牌区、放逐区、卡组构筑列表",
				"双方场上公开宝可梦、能量、道具、HP、异常状态",
				"双方奖赏剩余数量、手牌数量、牌库剩余数量",
				"对手公开弃牌区和放逐区",
			],
			"forbidden": [
				"对手手牌内容",
				"对手牌库内容或顺序",
				"双方奖赏卡具体身份",
				"任何当前视角不可见的隐藏信息",
			],
		},
		"state": {
			"turn_number": int(snapshot.get("turn_number", 0)),
			"phase": str(snapshot.get("phase", "")),
			"current_player_index": current_player_index,
			"is_perspective_players_turn": current_player_index == view_player,
			"acting_side_from_perspective": "me" if current_player_index == view_player else "opponent",
			"first_player_index": int(snapshot.get("first_player_index", -1)),
			"energy_attached_this_turn": bool(snapshot.get("energy_attached_this_turn", false)),
			"supporter_used_this_turn": bool(snapshot.get("supporter_used_this_turn", false)),
			"stadium_played_this_turn": bool(snapshot.get("stadium_played_this_turn", false)),
			"retreat_used_this_turn": bool(snapshot.get("retreat_used_this_turn", false)),
			"stadium_card": public_card_detail(snapshot.get("stadium_card", {})),
			"stadium_owner_index": int(snapshot.get("stadium_owner_index", -1)),
			"vstar_power_used": snapshot.get("vstar_power_used", []),
		},
		"public_counts": {
			"my_hand_count": int(my_player.get("hand_count", 0)),
			"my_deck_count": int(my_player.get("deck_count", 0)),
			"my_prize_count": my_prize_remaining,
			"my_prize_remaining": my_prize_remaining,
			"my_prizes_taken": my_prizes_taken,
			"opponent_hand_count": int(opp_player.get("hand_count", 0)),
			"opponent_deck_count": int(opp_player.get("deck_count", 0)),
			"opponent_prize_count": opponent_prize_remaining,
			"opponent_prize_remaining": opponent_prize_remaining,
			"opponent_prizes_taken": opponent_prizes_taken,
			"prize_remaining_score": "%d-%d" % [my_prize_remaining, opponent_prize_remaining],
			"prizes_taken_score": "%d-%d" % [my_prizes_taken, opponent_prizes_taken],
			"perspective_is_ahead_by_remaining_prizes": my_prize_remaining < opponent_prize_remaining,
			"perspective_is_ahead_by_prizes_taken": my_prizes_taken > opponent_prizes_taken,
		},
		"knockout_projection": knockout_projection_from_visible_state(my_player, opp_player),
		"my_visible_state": visible_player_context(my_player, true),
		"opponent_public_state": visible_player_context(opp_player, false),
		"my_decklist": decklist_context(my_deck),
		"opponent_deck_name": opp_deck.deck_name if opp_deck != null else "",
	}


func visible_player_context(player: Dictionary, include_hand: bool) -> Dictionary:
	var context := {
		"player_index": int(player.get("player_index", -1)),
		"hand_count": int(player.get("hand_count", 0)),
		"deck_count": int(player.get("deck_count", 0)),
		"discard_count": int(player.get("discard_count", 0)),
		"prize_count": int(player.get("prize_count", 0)),
		"prize_remaining": int(player.get("prize_count", 0)),
		"prizes_taken": prizes_taken_from_remaining(int(player.get("prize_count", 0))),
		"active": public_slot_detail(player.get("active", {})),
		"bench": public_slot_array(player.get("bench", [])),
		"discard_pile": public_card_array(player.get("discard_pile", [])),
		"lost_zone": public_card_array(player.get("lost_zone", [])),
	}
	if include_hand:
		context["hand"] = public_card_array(player.get("hand", []))
	else:
		context["hand"] = "[hidden: opponent hand contents are not visible]"
		context["deck"] = "[hidden: opponent deck contents/order are not visible]"
		context["prizes"] = "[hidden: prize identities are not visible]"
	return context


func prizes_taken_from_remaining(prize_remaining: int) -> int:
	return clampi(6 - prize_remaining, 0, 6)


func knockout_projection_from_visible_state(my_player: Dictionary, opponent_player: Dictionary) -> Dictionary:
	var my_remaining := int(my_player.get("prize_count", 0))
	var opponent_remaining := int(opponent_player.get("prize_count", 0))
	var opponent_active := public_slot_detail(opponent_player.get("active", {}))
	var prize_gain := 0
	if not opponent_active.is_empty():
		prize_gain = maxi(0, int(opponent_active.get("prize_count_if_knocked_out", 1)))
	var my_remaining_after := maxi(0, my_remaining - prize_gain)
	var my_taken_after := prizes_taken_from_remaining(my_remaining_after)
	var opponent_taken_after := prizes_taken_from_remaining(opponent_remaining)
	return {
		"if_perspective_player_knocks_out_opponent_active_now": {
			"prizes_to_take": prize_gain,
			"my_prize_remaining_after": my_remaining_after,
			"opponent_prize_remaining_after": opponent_remaining,
			"prize_remaining_score_after": "%d-%d" % [my_remaining_after, opponent_remaining],
			"my_prizes_taken_after": my_taken_after,
			"opponent_prizes_taken_after": opponent_taken_after,
			"prizes_taken_score_after": "%d-%d" % [my_taken_after, opponent_taken_after],
		},
	}


func public_slot_array(slots_variant: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (slots_variant is Array):
		return result
	for slot_variant: Variant in slots_variant:
		var slot := public_slot_detail(slot_variant)
		if not slot.is_empty():
			result.append(slot)
	return result


func public_slot_detail(slot_variant: Variant) -> Dictionary:
	if not (slot_variant is Dictionary):
		return {}
	var slot := slot_variant as Dictionary
	if str(slot.get("pokemon_name", "")).strip_edges() == "":
		return {}
	return {
		"pokemon_name": str(slot.get("pokemon_name", "")),
		"prize_count_if_knocked_out": int(slot.get("prize_count", 1)),
		"remaining_hp": int(slot.get("remaining_hp", 0)),
		"max_hp": int(slot.get("max_hp", 0)),
		"damage_counters": int(slot.get("damage_counters", 0)),
		"retreat_cost": int(slot.get("retreat_cost", 0)),
		"attached_energy": public_card_array(slot.get("attached_energy", [])),
		"attached_tool": public_card_detail(slot.get("attached_tool", {})),
		"status_conditions": slot.get("status_conditions", {}),
		"effects": slot.get("effects", []),
		"turn_played": int(slot.get("turn_played", -1)),
		"turn_evolved": int(slot.get("turn_evolved", -1)),
		"pokemon_stack": public_card_array(slot.get("pokemon_stack", [])),
	}


func public_card_array(cards_variant: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (cards_variant is Array):
		return result
	for card_variant: Variant in cards_variant:
		var card := public_card_detail(card_variant)
		if not card.is_empty():
			result.append(card)
	return result


func public_card_detail(card_variant: Variant) -> Dictionary:
	if not (card_variant is Dictionary):
		return {}
	var card := (card_variant as Dictionary).duplicate(true)
	card.erase("instance_id")
	card.erase("owner_index")
	card.erase("face_up")
	return card


func decklist_context(deck: DeckData) -> Dictionary:
	if deck == null:
		return {}
	var entries: Array[Dictionary] = []
	for entry_variant: Variant in deck.cards:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var card := CardDatabase.get_card(str(entry.get("set_code", "")), str(entry.get("card_index", "")))
		var row := {
			"name": str(entry.get("name", card.name if card != null else "")),
			"count": int(entry.get("count", 0)),
			"card_type": str(entry.get("card_type", card.card_type if card != null else "")),
			"set_code": str(entry.get("set_code", "")),
			"card_index": str(entry.get("card_index", "")),
		}
		if card != null:
			row["detail"] = card_data_detail(card)
		entries.append(row)
	return {
		"deck_id": deck.id,
		"deck_name": deck.deck_name,
		"total_cards": deck.total_cards,
		"strategy": deck.strategy,
		"cards": entries,
	}


func card_data_detail(card: CardData) -> Dictionary:
	if card == null:
		return {}
	return {
		"card_name": card.name,
		"name_en": card.name_en,
		"card_type": card.card_type,
		"mechanic": card.mechanic,
		"description": card.description,
		"stage": card.stage,
		"hp": card.hp,
		"energy_type": card.energy_type,
		"energy_provides": card.energy_provides,
		"evolves_from": card.evolves_from,
		"weakness": {"energy": card.weakness_energy, "value": card.weakness_value},
		"resistance": {"energy": card.resistance_energy, "value": card.resistance_value},
		"retreat_cost": card.retreat_cost,
		"attacks": card.attacks.duplicate(true),
		"abilities": card.abilities.duplicate(true),
		"effect_id": card.effect_id,
	}
