class_name CSV10CEffects
extends RefCounted

const HOP_PREFIXES := ["赫普的", "hop's "]
const ETHAN_PREFIXES := ["阿响的", "ethan's "]
const LILLIE_PREFIXES := ["莉莉艾的", "lillie's "]
const TEAM_ROCKET_PREFIXES := ["火箭队的", "team rocket's "]
const STEVEN_PREFIXES := ["大吾的", "steven's "]
const N_PREFIXES := ["N的", "n's "]


static func matches_named_pokemon(slot: PokemonSlot, prefixes: Array) -> bool:
	if slot == null:
		return false
	var data := slot.get_card_data()
	if data == null or not data.is_pokemon():
		return false
	for identity_name: String in data.rule_identity_names():
		var normalized := identity_name.strip_edges().to_lower()
		for raw_prefix: String in prefixes:
			var prefix := raw_prefix.strip_edges().to_lower()
			if prefix != "" and normalized.begins_with(prefix):
				return true
	return false


static func matches_named_card(data: CardData, prefixes: Array) -> bool:
	if data == null:
		return false
	for identity_name: String in data.rule_identity_names():
		var normalized := identity_name.strip_edges().to_lower()
		for raw_prefix: String in prefixes:
			var prefix := raw_prefix.strip_edges().to_lower()
			if prefix != "" and normalized.begins_with(prefix):
				return true
	return false


class HopsChoiceBand:
	extends BaseEffect

	func get_attack_colorless_cost_modifier(attacker: PokemonSlot, _attack: Dictionary, _state: GameState) -> int:
		return -1 if CSV10CEffects.matches_named_pokemon(attacker, HOP_PREFIXES) else 0

	func get_attack_modifier(attacker: PokemonSlot, _state: GameState) -> int:
		return 30 if CSV10CEffects.matches_named_pokemon(attacker, HOP_PREFIXES) else 0

	func get_description() -> String:
		return "The attached Hop's Pokemon's attacks cost 1 less Colorless Energy and do 30 more damage."


class LilliesPearl:
	extends BaseEffect

	func get_knockout_prize_modifier(slot: PokemonSlot, _state: GameState) -> int:
		return -1 if CSV10CEffects.matches_named_pokemon(slot, LILLIE_PREFIXES) else 0

	func get_description() -> String:
		return "When the attached Lillie's Pokemon is Knocked Out by damage from an opponent's attack, the opponent takes 1 fewer Prize card."


class IrissFightingSpirit:
	extends BaseEffect

	const STEP_ID := "discard_cards"

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var items: Array = []
		var labels: Array[String] = []
		for hand_card: CardInstance in state.players[card.owner_index].hand:
			if hand_card == card:
				continue
			items.append(hand_card)
			labels.append(hand_card.card_data.name if hand_card.card_data != null else "")
		return [{
			"id": STEP_ID,
			"title": "选择1张手牌放入弃牌区",
			"items": items,
			"labels": labels,
			"presentation": "cards",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		for hand_card: CardInstance in state.players[card.owner_index].hand:
			if hand_card != card:
				return true
		return false

	func get_unusable_reason(_card: CardInstance, _state: GameState) -> String:
		return "艾莉丝的斗志需要将另外1张手牌放入弃牌区。"

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var player: PlayerState = state.players[card.owner_index]
		var context := get_interaction_context(targets)
		var chosen: CardInstance = null
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw != card and raw in player.hand:
				chosen = raw
				break
		if chosen == null:
			for hand_card: CardInstance in player.hand:
				if hand_card != card:
					chosen = hand_card
					break
		if chosen == null:
			return
		_discard_cards_from_hand_with_log(state, card.owner_index, [chosen], card, "trainer")
		_draw_cards_with_log(state, card.owner_index, maxi(0, 6 - player.hand.size()), card, "trainer")

	func get_description() -> String:
		return "Discard 1 other card from your hand. Draw until you have 6 cards in hand."


class MCExcitement:
	extends BaseEffect

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		var opponent_index := 1 - card.owner_index
		var count := 4 if state.players[opponent_index].prizes.size() <= 3 else 2
		_draw_cards_with_log(state, card.owner_index, count, card, "trainer")

	func get_description() -> String:
		return "Draw 2 cards, or 4 cards if the opponent has 3 or fewer Prize cards remaining."


class ScaryBigBrother:
	extends BaseEffect

	const TARGET_STEP_ID := "opponent_pokemon"
	const ENERGY_STEP_ID := "special_energy"

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var targets := _eligible_targets(card, state)
		var labels: Array[String] = []
		for slot: PokemonSlot in targets:
			labels.append(slot.get_pokemon_name())
		return [{
			"id": TARGET_STEP_ID,
			"title": "选择对手的1只宝可梦",
			"items": targets,
			"labels": labels,
			"presentation": "pokemon_slots",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		var target := _selected_target(card, state, resolved_context)
		if target == null:
			return []
		var energy := _special_energy(target)
		if energy.is_empty():
			return []
		var labels: Array[String] = []
		for attached: CardInstance in energy:
			labels.append(attached.card_data.name if attached.card_data != null else "")
		var steps: Array[Dictionary] = [{
			"id": ENERGY_STEP_ID,
			"title": "选择要放入弃牌区的1张特殊能量",
			"items": energy,
			"labels": labels,
			"presentation": "cards",
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]
		return steps

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not _eligible_targets(card, state).is_empty()

	func get_unusable_reason(_card: CardInstance, _state: GameState) -> String:
		return "对手场上没有附着宝可梦道具或特殊能量的宝可梦。"

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var context := get_interaction_context(targets)
		var target := _selected_target(card, state, context)
		if target == null:
			return
		var opponent := state.players[1 - card.owner_index]
		if target.attached_tool != null:
			var tool := target.attached_tool
			target.attached_tool = null
			opponent.discard_card(tool)
		var available := _special_energy(target)
		var chosen: CardInstance = null
		for raw: Variant in context.get(ENERGY_STEP_ID, []):
			if raw is CardInstance and raw in available:
				chosen = raw
				break
		if chosen == null and not available.is_empty():
			chosen = available[0]
		if chosen != null:
			target.attached_energy.erase(chosen)
			opponent.discard_card(chosen)

	func _eligible_targets(card: CardInstance, state: GameState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		if card == null or state == null:
			return result
		for slot: PokemonSlot in state.players[1 - card.owner_index].get_all_pokemon():
			if slot == null or (slot.attached_tool == null and _special_energy(slot).is_empty()):
				continue
			var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
			if processor != null and processor.has_method("is_protected_from_opponent_hand_trainer_effect"):
				if bool(processor.call("is_protected_from_opponent_hand_trainer_effect", slot, card, state)):
					continue
			if slot not in result:
				result.append(slot)
		return result

	func _selected_target(card: CardInstance, state: GameState, context: Dictionary) -> PokemonSlot:
		var eligible := _eligible_targets(card, state)
		for raw: Variant in context.get(TARGET_STEP_ID, []):
			if raw is PokemonSlot and raw in eligible:
				return raw
		return eligible[0] if not context.has(TARGET_STEP_ID) and not eligible.is_empty() else null

	func _special_energy(slot: PokemonSlot) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if slot == null:
			return result
		for energy: CardInstance in slot.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Special Energy":
				result.append(energy)
		return result

	func get_description() -> String:
		return "Choose 1 opposing Pokemon. Discard 1 Pokemon Tool and 1 Special Energy from it."


class EthansAdventure:
	extends BaseEffect

	const STEP_ID := "search_cards"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not state.players[card.owner_index].deck.is_empty()

	func can_headless_execute(card: CardInstance, state: GameState) -> bool:
		return can_execute(card, state) and not _legal_cards(state.players[card.owner_index]).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var legal := _legal_cards(player)
		if legal.is_empty():
			return [build_empty_search_resolution_step("阿响的冒险：牌库中没有可加入手牌的卡牌。")]
		return [build_full_library_search_step(
			STEP_ID,
			"选择合计最多3张阿响的宝可梦或基本火能量",
			player.deck,
			legal,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(3, legal.size()),
			{"allow_cancel": true, "force_confirm": true}
		)]

	func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if should_preview_empty_search_deck(resolved_context):
			return [build_readonly_deck_preview_step("阿响的冒险：查看牌库", state.players[card.owner_index].deck)]
		return []

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var player := state.players[card.owner_index]
		var context := get_interaction_context(targets)
		var legal := _legal_cards(player)
		var selected: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in selected:
				selected.append(raw)
				if selected.size() >= 3:
					break
		if not context.has(STEP_ID):
			for candidate: CardInstance in legal:
				selected.append(candidate)
				if selected.size() >= 3:
					break
		_move_public_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer", "search_to_hand", ["阿响的宝可梦或基本火能量"])
		player.shuffle_deck()

	func _legal_cards(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for candidate: CardInstance in player.deck:
			if candidate == null or candidate.card_data == null:
				continue
			var data := candidate.card_data
			if data.is_pokemon() and CSV10CEffects.matches_named_card(data, ETHAN_PREFIXES):
				result.append(candidate)
			elif data.card_type == "Basic Energy" and (data.energy_provides == "R" or data.energy_type == "R"):
				result.append(candidate)
		return result

	func get_description() -> String:
		return "Search your deck for up to 3 total Hop's Pokemon and Basic Fire Energy, reveal them, put them into your hand, then shuffle."


class TeamRocketsAriana:
	extends BaseEffect

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var player := state.players[card.owner_index]
		return player.hand.size() < _target_size(player) and not player.deck.is_empty()

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		var player := state.players[card.owner_index]
		_draw_cards_with_log(state, card.owner_index, maxi(0, _target_size(player) - player.hand.size()), card, "trainer")

	func _target_size(player: PlayerState) -> int:
		var slots := player.get_all_pokemon()
		if slots.is_empty():
			return 5
		for slot: PokemonSlot in slots:
			if not CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
				return 5
		return 8

	func get_description() -> String:
		return "Draw until you have 5 cards, or 8 cards if every Pokemon you have in play is a Team Rocket's Pokemon."


class TeamRocketsArcher:
	extends BaseEffect

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var owner := card.owner_index
		if owner < 0 or owner >= state.last_knockout_turn_against.size() or state.last_knockout_turn_against[owner] != state.turn_number - 1:
			return false
		var key := "knockout_names:%d:%d" % [owner, state.turn_number - 1]
		var names: Variant = state.shared_turn_flags.get(key, [])
		if names is Array and (names as Array).is_empty():
			# Older replays only recorded attack-damage knockout identities.
			names = state.shared_turn_flags.get("attack_damage_knockout_names:%d:%d" % [owner, state.turn_number - 1], [])
		if not (names is Array):
			return false
		for raw_name: Variant in names:
			var normalized := str(raw_name).strip_edges().to_lower()
			for raw_prefix: String in TEAM_ROCKET_PREFIXES:
				if normalized.begins_with(raw_prefix.strip_edges().to_lower()):
					return true
		return false

	func get_unusable_reason(_card: CardInstance, _state: GameState) -> String:
		return "上一个对手回合没有自己的火箭队的宝可梦因招式伤害而昏厥。"

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		_shuffle_draw(state.players[card.owner_index], 5, state, card.owner_index, card)
		_shuffle_draw(state.players[1 - card.owner_index], 3, state, 1 - card.owner_index, card)

	func _shuffle_draw(player: PlayerState, count: int, state: GameState, player_index: int, source: CardInstance) -> void:
		var hand_copy: Array[CardInstance] = player.hand.duplicate()
		for hand_card: CardInstance in hand_copy:
			player.hand.erase(hand_card)
			hand_card.face_up = false
			player.deck.append(hand_card)
		player.shuffle_deck()
		_draw_cards_with_log(state, player_index, count, source, "trainer")

	func get_description() -> String:
		return "Play only if a Team Rocket's Pokemon was Knocked Out during the opponent's last turn. Both players shuffle their hands into their decks; you draw 5 and your opponent draws 3."


class TeamRocketsGiovanni:
	extends BaseEffect

	const OWN_STEP_ID := "own_rocket_bench"
	const OPPONENT_STEP_ID := "opponent_bench"

	func can_execute(card: CardInstance, state: GameState) -> bool:
		if card == null or state == null:
			return false
		var player := state.players[card.owner_index]
		return CSV10CEffects.matches_named_pokemon(player.active_pokemon, TEAM_ROCKET_PREFIXES) and not _own_targets(player).is_empty() and not _opponent_targets(card, state).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var own := _own_targets(state.players[card.owner_index])
		var opponent: Array = _opponent_targets(card, state)
		return [
			_choice_step(OWN_STEP_ID, "选择自己的1只备战区火箭队的宝可梦", own),
			_choice_step(OPPONENT_STEP_ID, "选择对手的1只备战宝可梦", opponent),
		]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var context := get_interaction_context(targets)
		var player := state.players[card.owner_index]
		var opponent := state.players[1 - card.owner_index]
		var own_targets := _own_targets(player)
		var own_target := _selected_slot(context.get(OWN_STEP_ID, []), own_targets)
		var opponent_target := _selected_slot(context.get(OPPONENT_STEP_ID, []), _opponent_targets(card, state))
		if own_target == null or opponent_target == null:
			return
		_switch_active(player, own_target)
		_switch_active(opponent, opponent_target)

	func _own_targets(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.bench:
			if CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
				result.append(slot)
		return result

	func _opponent_targets(card: CardInstance, state: GameState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		if card == null or state == null:
			return result
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		for slot: PokemonSlot in state.players[1 - card.owner_index].bench:
			if slot == null:
				continue
			if processor != null and processor.has_method("is_protected_from_opponent_hand_trainer_effect"):
				if bool(processor.call("is_protected_from_opponent_hand_trainer_effect", slot, card, state)):
					continue
			result.append(slot)
		return result

	func _choice_step(step_id: String, title: String, items: Array) -> Dictionary:
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(slot.get_pokemon_name())
		return {"id": step_id, "title": title, "items": items, "labels": labels, "presentation": "pokemon_slots", "min_select": 1, "max_select": 1, "allow_cancel": true}

	func _selected_slot(raw_items: Array, legal: Array) -> PokemonSlot:
		for raw: Variant in raw_items:
			if raw is PokemonSlot and raw in legal:
				return raw
		return legal[0] if not legal.is_empty() else null

	func _switch_active(player: PlayerState, target: PokemonSlot) -> void:
		if player.active_pokemon == null or target == null or target not in player.bench:
			return
		var old_active := player.active_pokemon
		player.bench.erase(target)
		old_active.clear_on_leave_active()
		player.bench.append(old_active)
		player.active_pokemon = target

	func get_description() -> String:
		return "Switch your Active Team Rocket's Pokemon with a Benched Team Rocket's Pokemon, then switch in 1 opposing Benched Pokemon."


class TeamRocketsLance:
	extends BaseEffect

	const STEP_ID := "search_basic_rocket"

	func allows_first_player_first_turn() -> bool:
		return true

	func can_execute(card: CardInstance, state: GameState) -> bool:
		return card != null and state != null and not state.players[card.owner_index].deck.is_empty()

	func can_headless_execute(card: CardInstance, state: GameState) -> bool:
		return can_execute(card, state) and not _legal(state.players[card.owner_index]).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var legal := _legal(player)
		if legal.is_empty():
			return [build_empty_search_resolution_step("火箭队的兰斯：牌库中没有基础火箭队的宝可梦。")]
		return [build_full_library_search_step(STEP_ID, "选择最多3只基础火箭队的宝可梦", player.deck, legal, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(3, legal.size()), {"allow_cancel": true, "force_confirm": true})]

	func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if should_preview_empty_search_deck(resolved_context):
			return [build_readonly_deck_preview_step("火箭队的兰斯：查看牌库", state.players[card.owner_index].deck)]
		return []

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var player := state.players[card.owner_index]
		var context := get_interaction_context(targets)
		var legal := _legal(player)
		var selected: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in selected:
				selected.append(raw)
				if selected.size() >= 3:
					break
		if not context.has(STEP_ID):
			selected.assign(legal.slice(0, mini(3, legal.size())))
		_move_public_cards_to_hand_with_log(state, card.owner_index, selected, card, "trainer", "search_to_hand", ["基础火箭队的宝可梦"])
		player.shuffle_deck()

	func _legal(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for candidate: CardInstance in player.deck:
			if candidate != null and candidate.card_data != null and candidate.card_data.is_basic_pokemon() and CSV10CEffects.matches_named_card(candidate.card_data, TEAM_ROCKET_PREFIXES):
				result.append(candidate)
		return result

	func get_description() -> String:
		return "You may play this during the first player's first turn. Search your deck for up to 3 Basic Team Rocket's Pokemon, reveal them, put them into your hand, then shuffle."


class StonesCave:
	extends BaseEffect

	func get_defense_modifier(defender: PokemonSlot, _state: GameState) -> int:
		return -30 if CSV10CEffects.matches_named_pokemon(defender, STEVEN_PREFIXES) else 0

	func get_description() -> String:
		return "Steven's Pokemon take 30 less damage from attacks."


class NsCastle:
	extends BaseEffect

	func get_retreat_cost_modifier(slot: PokemonSlot, _state: GameState) -> int:
		return -99 if CSV10CEffects.matches_named_pokemon(slot, N_PREFIXES) else 0

	func get_description() -> String:
		return "N's Pokemon in play have no Retreat Cost."


class Levincia:
	extends BaseEffect

	const STEP_ID := "levincia_basic_lightning"

	func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
		return true

	func can_execute(_card: CardInstance, state: GameState) -> bool:
		return state != null and not _eligible(state.players[state.current_player_index]).is_empty()

	func get_interaction_steps(_card: CardInstance, state: GameState) -> Array[Dictionary]:
		var eligible := _eligible(state.players[state.current_player_index])
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{
			"id": STEP_ID,
			"title": "选择最多2张基本雷能量加入手牌",
			"items": eligible,
			"labels": labels,
			"min_select": 0,
			"max_select": mini(2, eligible.size()),
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		var player_index := state.current_player_index
		var eligible := _eligible(state.players[player_index])
		var context := get_interaction_context(targets)
		var selected: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in eligible and raw not in selected:
				selected.append(raw)
				if selected.size() >= 2:
					break
		if not context.has(STEP_ID):
			selected.assign(eligible.slice(0, mini(2, eligible.size())))
		_move_discard_cards_to_hand_with_log(state, player_index, selected, card, "stadium")

	func _eligible(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for energy: CardInstance in player.discard_pile:
			if energy.card_data != null and energy.card_data.card_type == "Basic Energy" and (energy.card_data.energy_provides == "L" or energy.card_data.energy_type == "L"):
				result.append(energy)
		return result

	func get_description() -> String:
		return "Once during each player's turn, that player may put up to 2 Basic Lightning Energy from their discard pile into their hand."


class Postwick:
	extends BaseEffect

	func get_attack_modifier(attacker: PokemonSlot, _state: GameState) -> int:
		return 30 if CSV10CEffects.matches_named_pokemon(attacker, HOP_PREFIXES) else 0

	func get_description() -> String:
		return "Attacks used by Hop's Pokemon do 30 more damage to the opponent's Active Pokemon."


class TeamRocketsWatchtower:
	extends BaseEffect

	func suppresses_ability(slot: PokemonSlot, _state: GameState) -> bool:
		var data := slot.get_card_data() if slot != null else null
		return data != null and data.card_type == "Pokemon" and data.energy_type == "C"

	func get_description() -> String:
		return "All Colorless Pokemon in play have no Abilities."


class TeamRocketsFactory:
	extends BaseEffect

	const FLAG_PREFIX := "rocket_supporter_played_turn:"

	func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool:
		return true

	func can_execute(_card: CardInstance, state: GameState) -> bool:
		if state == null or state.current_player_index < 0 or state.current_player_index >= state.players.size():
			return false
		var player_index := state.current_player_index
		return int(state.shared_turn_flags.get("%s%d" % [FLAG_PREFIX, player_index], -1)) == state.turn_number and not state.players[player_index].deck.is_empty()

	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		if can_execute(card, state):
			_draw_cards_with_log(state, state.current_player_index, 2, card, "stadium")

	func get_description() -> String:
		return "Once during your turn, if you played a Team Rocket Supporter from your hand this turn, draw 2 cards."


class SpikemuthEnergy:
	extends BaseEffect

	func get_energy_type_for(_energy: CardInstance, _state: GameState) -> String:
		return "C"

	func get_energy_count_for(_energy: CardInstance, _state: GameState) -> int:
		return 1

	func on_attached_pokemon_damaged_by_opponent_attack(
		_energy: CardInstance,
		_defender: PokemonSlot,
		attacker: PokemonSlot,
		_damage: int,
		_state: GameState
	) -> void:
		if attacker != null:
			attacker.damage_counters += 20

	func get_description() -> String:
		return "Provides 1 Colorless Energy. If the attached Active Pokemon is damaged by an opponent's attack, put 2 damage counters on the attacker."


class TeamRocketEnergy:
	extends BaseEffect

	func can_execute(_card: CardInstance, _state: GameState) -> bool:
		return true

	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if card == null or state == null:
			return
		var slot := _attached_slot(card, state)
		if not targets.is_empty() and targets[0] is PokemonSlot and card in (targets[0] as PokemonSlot).attached_energy:
			slot = targets[0]
		if slot == null or CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
			return
		slot.attached_energy.erase(card)
		var owner := card.owner_index
		if owner >= 0 and owner < state.players.size():
			state.players[owner].discard_pile.append(card)

	func get_energy_types_for(_energy: CardInstance, _state: GameState) -> PackedStringArray:
		return PackedStringArray(["P", "D"])

	func get_energy_type_for(_energy: CardInstance, _state: GameState) -> String:
		return "P"

	func get_energy_count_for(_energy: CardInstance, _state: GameState) -> int:
		return 2

	func _attached_slot(energy: CardInstance, state: GameState) -> PokemonSlot:
		for player: PlayerState in state.players:
			for slot: PokemonSlot in player.get_all_pokemon():
				if energy in slot.attached_energy:
					return slot
		return null

	func get_description() -> String:
		return "Attach only to a Team Rocket's Pokemon; otherwise discard it. Provides 2 Energy in any combination of Psychic and Darkness."


class MistysPsyduckStrollJump:
	extends BaseEffect

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon in state.players[owner].bench and not pokemon.has_ability_used(state.turn_number) and not state.players[owner].deck.is_empty()

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var pokemon_card := pokemon.get_top_card()
		var owner := pokemon_card.owner_index
		var player := state.players[owner]
		var bottom: CardInstance = player.deck.pop_back()
		bottom.face_up = true
		player.discard_pile.append(bottom)
		for stack_card: CardInstance in pokemon.pokemon_stack:
			if stack_card != pokemon_card:
				stack_card.face_up = true
				player.discard_pile.append(stack_card)
		for energy: CardInstance in pokemon.attached_energy:
			energy.face_up = true
			player.discard_pile.append(energy)
		if pokemon.attached_tool != null:
			pokemon.attached_tool.face_up = true
			player.discard_pile.append(pokemon.attached_tool)
		player.bench.erase(pokemon)
		pokemon.pokemon_stack.clear()
		pokemon.attached_energy.clear()
		pokemon.attached_tool = null
		pokemon.effects.clear()
		pokemon.clear_all_status()
		pokemon.damage_counters = 0
		pokemon_card.face_up = false
		player.deck.push_front(pokemon_card)

	func get_description() -> String:
		return "Once during your turn while this Pokemon is on your Bench, discard the bottom card of your deck, discard all cards attached to this Pokemon, then put this Pokemon on top of your deck."


class ZamazentaPowerSlam:
	extends BaseEffect

	const EFFECT_TYPE := "csv10c_zamazenta_power_slam_reflect"
	var attack_index_to_match := 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func is_attack_damage_reactive_effect() -> bool:
		return true

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or state == null or not applies_to_attack_index(attack_index):
			return
		attacker.effects = attacker.effects.filter(func(entry: Dictionary) -> bool: return entry.get("type", "") != EFFECT_TYPE)
		attacker.effects.append({"type": EFFECT_TYPE, "turn": state.turn_number})

	func on_damaged_by_attack(defender: PokemonSlot, attacker: PokemonSlot, damage: int, state: GameState) -> void:
		if defender == null or attacker == null or damage <= 0 or state == null:
			return
		for entry: Dictionary in defender.effects:
			if entry.get("type", "") == EFFECT_TYPE and int(entry.get("turn", -999)) == state.turn_number - 1:
				var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
				if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
					if bool(processor.call("is_attack_effect_prevented_by_defender_ability", defender, attacker, state)):
						return
				attacker.damage_counters += damage
				return

	func get_description() -> String:
		return "During your opponent's next turn, if this Pokemon is damaged by an attack, put that many damage counters on the attacker."


class CetitanSnowedIn:
	extends BaseEffect

	func prevents_opponent_hand_trainer_effect(target: PokemonSlot, trainer: CardInstance, _state: GameState) -> bool:
		if target == null or trainer == null or trainer.card_data == null or target.get_top_card() == null:
			return false
		return trainer.owner_index != target.get_top_card().owner_index and trainer.card_data.card_type in ["Item", "Supporter"]

	func get_description() -> String:
		return "Prevent all effects of Item and Supporter cards played from your opponent's hand done to this Pokemon."


class ElectivireDoubleVolt:
	extends BaseEffect

	const STEP_ID := "electivire_two_targets"
	var attack_index_to_match := 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var items := state.players[1 - card.owner_index].get_all_pokemon()
		var labels: Array[String] = []
		for target: PokemonSlot in items:
			labels.append(target.get_pokemon_name())
		return [{"id": STEP_ID, "title": "选择对手的2只宝可梦，各造成50伤害", "items": items, "labels": labels, "presentation": "pokemon_slots", "min_select": mini(2, items.size()), "max_select": mini(2, items.size()), "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var legal := opponent.get_all_pokemon()
		var chosen: Array[PokemonSlot] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is PokemonSlot and raw in legal and raw not in chosen:
				chosen.append(raw)
				if chosen.size() >= 2:
					break
		var required := mini(2, legal.size())
		var context := get_attack_interaction_context()
		if chosen.size() != required and context.has(STEP_ID):
			return
		if chosen.is_empty():
			chosen.assign(legal.slice(0, mini(2, legal.size())))
		for target: PokemonSlot in chosen:
			if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
				continue
			if AbilityPreventDamageFromBasicEx.prevents_target_damage(attacker, target, state):
				continue
			target.damage_counters += _calculate_attack_target_damage(attacker, target, 50, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackExcessAttachedEnergyBonus:
	extends BaseEffect

	var required_energy_count := 5
	var bonus_damage := 100
	var attack_index_to_match := 1

	func _init(required_count: int = 5, bonus: int = 100, match_attack_index: int = 1) -> void:
		required_energy_count = required_count
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null:
			return 0
		var total := 0
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
		for energy: CardInstance in attacker.attached_energy:
			total += int(processor.call("get_energy_colorless_count", energy, state)) if processor != null and processor.has_method("get_energy_colorless_count") else 1
		return bonus_damage if total >= required_energy_count else 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class IonosBelliboltElectricStream:
	extends BaseEffect

	const ASSIGNMENT_STEP_ID := "iono_lightning_assignment"
	const ENERGY_STEP_ID := "iono_lightning_energy"
	const TARGET_STEP_ID := "iono_energy_target"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon in state.players[owner].get_all_pokemon() and not _energy(state.players[owner]).is_empty() and not _targets(state.players[owner]).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var energy := _energy(player)
		var targets := _targets(player)
		var energy_labels: Array[String] = []
		var target_labels: Array[String] = []
		for item: CardInstance in energy:
			energy_labels.append(item.card_data.name)
		for target: PokemonSlot in targets:
			target_labels.append(target.get_pokemon_name())
		var step := build_card_assignment_step(
			ASSIGNMENT_STEP_ID,
			"选择1张基本雷能量附着于1只奇树的宝可梦",
			energy,
			energy_labels,
			targets,
			target_labels,
			1,
			1,
			true
		)
		step["single_target_only"] = true
		return [step]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var context := get_interaction_context(targets)
		var legal_energy := _energy(player)
		var legal_targets := _targets(player)
		var energy: CardInstance = null
		var target: PokemonSlot = null
		for raw: Variant in context.get(ASSIGNMENT_STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var source: Variant = raw.get("source", null)
			var assigned_target: Variant = raw.get("target", null)
			if source is CardInstance and source in legal_energy and assigned_target is PokemonSlot and assigned_target in legal_targets:
				energy = source
				target = assigned_target
				break
		# Keep old two-step contexts valid for replays and headless callers.
		if energy == null:
			energy = _selected_energy(context.get(ENERGY_STEP_ID, []), legal_energy)
		if target == null:
			target = _selected_target(context.get(TARGET_STEP_ID, []), legal_targets)
		if energy == null or target == null:
			return
		player.hand.erase(energy)
		target.attached_energy.append(energy)

	func _energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.hand:
			if card.card_data != null and card.card_data.card_type == "Basic Energy" and (card.card_data.energy_provides == "L" or card.card_data.energy_type == "L"):
				result.append(card)
		return result

	func _targets(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot == null or slot.get_card_data() == null:
				continue
			for identity: String in slot.get_card_data().rule_identity_names():
				var normalized := identity.strip_edges().to_lower()
				if normalized.begins_with("奇树的") or normalized.begins_with("iono's "):
					result.append(slot)
					break
		return result

	func _selected_energy(raw: Array, legal: Array[CardInstance]) -> CardInstance:
		for value: Variant in raw:
			if value is CardInstance and value in legal:
				return value
		return legal[0] if not legal.is_empty() else null

	func _selected_target(raw: Array, legal: Array[PokemonSlot]) -> PokemonSlot:
		for value: Variant in raw:
			if value is PokemonSlot and value in legal:
				return value
		return legal[0] if not legal.is_empty() else null


class TeamRocketsMewtwoPowerSuppressor:
	extends BaseEffect

	func get_attack_unusable_reason(pokemon: PokemonSlot, _attack_index: int, state: GameState) -> String:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return "This Pokemon cannot attack."
		var player := state.players[pokemon.get_top_card().owner_index]
		var count := 0
		for slot: PokemonSlot in player.get_all_pokemon():
			if CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
				count += 1
		return "At least 4 Team Rocket's Pokemon must be in play to attack." if count < 4 else ""


class TeamRocketsMewtwoEraseBall:
	extends BaseEffect

	const STEP_ID := "mewtwo_discard_bench_energy"
	var attack_index_to_match := 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or attack != card.card_data.attacks[attack_index_to_match]:
			return []
		var energy := _bench_energy(state.players[card.owner_index])
		var labels: Array[String] = []
		for slot: PokemonSlot in state.players[card.owner_index].bench:
			for item: CardInstance in slot.attached_energy:
				labels.append("%s — %s" % [item.card_data.name, slot.get_pokemon_name()])
		return [{"id": STEP_ID, "title": "选择最多2张备战宝可梦身上的能量放入弃牌区", "items": energy, "labels": labels, "min_select": 0, "max_select": mini(2, energy.size()), "allow_cancel": true, "force_confirm": true}]

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return _selected(attacker, state).size() * 60

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		for energy: CardInstance in _selected(attacker, state):
			for slot: PokemonSlot in player.bench:
				if energy in slot.attached_energy:
					slot.attached_energy.erase(energy)
					player.discard_pile.append(energy)
					break

	func _bench_energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for slot: PokemonSlot in player.bench:
			result.append_array(slot.attached_energy)
		return result

	func _selected(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
		var legal := _bench_energy(state.players[attacker.get_top_card().owner_index])
		var result: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in result:
				result.append(raw)
				if result.size() >= 2:
					break
		return result


class AttackOpponentPokemonExCountDamage:
	extends BaseEffect

	var damage_per_pokemon := 60
	var attack_index_to_match := 0

	func _init(damage: int = 60, match_attack_index: int = 0) -> void:
		damage_per_pokemon = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -damage_per_pokemon
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var count := 0
		for slot: PokemonSlot in opponent.get_all_pokemon():
			var data := slot.get_card_data()
			if data != null and (data.mechanic == "ex" or data.has_tag("ex")):
				count += 1
		return count * damage_per_pokemon - damage_per_pokemon

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackLookAtOpponentPrize extends BaseEffect:
	const STEP_ID := "opponent_prize_index"
	const REVEAL_STEP_ID := "opponent_prize_reveal"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var prizes := state.players[1 - card.owner_index].prizes
		var items: Array[int] = []
		var labels: Array[String] = []
		for index: int in prizes.size():
			var prize: CardInstance = prizes[index]
			if prize == null or prize.face_up:
				continue
			items.append(index)
			labels.append("奖赏卡%d" % (index + 1))
		if items.is_empty():
			return []
		return [{
			"id": STEP_ID,
			"title": "选择对手1张反面朝上的奖赏卡查看",
			"items": items,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func get_followup_attack_interaction_steps(
		card: CardInstance,
		_attack: Dictionary,
		state: GameState,
		context: Dictionary
	) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var prizes := state.players[1 - card.owner_index].prizes
		var selected: Array = context.get(STEP_ID, [])
		if selected.is_empty() or not (selected[0] is int):
			return []
		var selected_index := int(selected[0])
		if selected_index < 0 or selected_index >= prizes.size():
			return []
		var prize: CardInstance = prizes[selected_index]
		if prize == null or prize.face_up:
			return []
		return [{
			"id": REVEAL_STEP_ID,
			"title": "查看对手的奖赏卡%d" % (selected_index + 1),
			"items": [],
			"labels": [],
			"presentation": "cards",
			"card_items": [prize],
			"card_indices": [-1],
			"choice_labels": [prize.card_data.display_name() if prize.card_data != null else "奖赏卡%d" % (selected_index + 1)],
			"min_select": 0,
			"max_select": 0,
			"allow_cancel": false,
			"force_confirm": true,
			"card_click_selectable": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var owner := attacker.get_top_card().owner_index
		var prizes := state.players[1 - owner].prizes
		if prizes.is_empty():
			return
		var facedown_indices: Array[int] = []
		for index: int in prizes.size():
			if prizes[index] != null and not prizes[index].face_up:
				facedown_indices.append(index)
		if facedown_indices.is_empty():
			return
		var selected_index := facedown_indices[0]
		var selected: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not selected.is_empty() and selected[0] is int and int(selected[0]) in facedown_indices:
			selected_index = int(selected[0])
		var prize: CardInstance = prizes[selected_index]
		state.shared_turn_flags["csv10c_revealed_opponent_prize:%d" % owner] = {
			"index": selected_index,
			"card_uid": prize.card_data.get_uid() if prize != null and prize.card_data != null else "",
			"card_name": prize.card_data.name if prize != null and prize.card_data != null else "",
		}

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackDiscardSixBasicEnergyKnockout extends BaseEffect:
	const STEP_ID := "discard_basic_energy_for_knockout"
	var energy_type: String = "G"
	var required_count: int = 6
	var attack_index_to_match: int = -1

	func _init(type: String = "G", count: int = 6, match_attack_index: int = -1) -> void:
		energy_type = type
		required_count = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var eligible := _eligible(state.players[card.owner_index].hand)
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{
			"id": STEP_ID,
			"title": "选择%d张基本能量放入弃牌区" % required_count,
			"items": eligible,
			"labels": labels,
			"min_select": mini(required_count, eligible.size()),
			"max_select": mini(required_count, eligible.size()),
			"allow_cancel": eligible.size() < required_count,
		}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var eligible := _eligible(player.hand)
		if eligible.size() < required_count:
			return
		var chosen: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in eligible and raw not in chosen:
				chosen.append(raw)
		if chosen.is_empty():
			chosen.assign(eligible.slice(0, required_count))
		if chosen.size() != required_count:
			return
		for energy: CardInstance in chosen:
			player.hand.erase(energy)
			player.discard_pile.append(energy)
		defender.damage_counters = maxi(defender.damage_counters, defender.get_max_hp())

	func _eligible(cards: Array[CardInstance]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in cards:
			if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy" and (card.card_data.energy_provides == energy_type or card.card_data.energy_type == energy_type):
				result.append(card)
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackOwnFieldToolCountDamage extends BaseEffect:
	var damage_per_tool: int = 30
	var attack_index_to_match: int = -1

	func _init(per_tool: int = 30, match_attack_index: int = -1) -> void:
		damage_per_tool = per_tool
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var player := state.players[attacker.get_top_card().owner_index]
		var tool_count := 0
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.attached_tool != null:
				tool_count += 1
		# The printed damage already contributes one `damage_per_tool` through
		# DamageCalculator (for example, "30x" parses as 30). Offset that
		# baseline so zero attached Tools correctly deals zero damage.
		return damage_per_tool * (tool_count - 1)

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AbilityPreventDamageFromMechanic extends BaseEffect:
	var blocked_mechanics: PackedStringArray = PackedStringArray()

	func _init(mechanics: PackedStringArray = PackedStringArray()) -> void:
		blocked_mechanics = mechanics.duplicate()

	func prevents_damage_from(attacker: PokemonSlot, _defender: PokemonSlot, _state: GameState) -> bool:
		var card_data := attacker.get_card_data() if attacker != null else null
		return card_data != null and card_data.mechanic in blocked_mechanics

	func get_description() -> String:
		return "Prevent attack damage from Pokemon with the configured mechanics."


class AttackCoinFlipBonusAndHeal extends BaseEffect:
	var bonus_damage: int = 30
	var heal_amount: int = 30
	var attack_index_to_match: int = -1
	var coin_flipper: CoinFlipper = CoinFlipper.new()

	func _init(bonus: int = 30, heal: int = 30, match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
		bonus_damage = bonus
		heal_amount = heal
		attack_index_to_match = match_attack_index
		if flipper != null:
			coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, _state: GameState) -> void:
		if attacker == null or defender == null or not applies_to_attack_index(attack_index):
			return
		if coin_flipper.flip():
			defender.damage_counters += bonus_damage
			attacker.damage_counters = maxi(0, attacker.damage_counters - heal_amount)


class AbilitySwitchSelfFromBench extends BaseEffect:
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon in state.players[owner].bench and state.players[owner].active_pokemon != null and not pokemon.has_ability_used(state.turn_number)

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var bench_index := player.bench.find(pokemon)
		var old_active := player.active_pokemon
		player.bench[bench_index] = old_active
		old_active.clear_on_leave_active()
		player.active_pokemon = pokemon
		pokemon.mark_entered_active_from_bench(state.turn_number)
		pokemon.mark_ability_used(state.turn_number)


class AbilityAttachBasicEnergyFromDiscardToSelf extends BaseEffect:
	const STEP_ID := "discard_basic_energy_to_self"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and not pokemon.has_ability_used(state.turn_number) and not _eligible(state.players[owner].discard_pile).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var eligible := _eligible(state.players[card.owner_index].discard_pile)
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{"id": STEP_ID, "title": "选择弃牌区1张基本能量附着于这只宝可梦", "items": eligible, "labels": labels, "min_select": 1, "max_select": 1, "allow_cancel": true}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var eligible := _eligible(player.discard_pile)
		var chosen: CardInstance = null
		for raw: Variant in get_interaction_context(targets).get(STEP_ID, []):
			if raw is CardInstance and raw in eligible:
				chosen = raw
				break
		if chosen == null:
			chosen = eligible[0]
		player.discard_pile.erase(chosen)
		pokemon.attached_energy.append(chosen)
		pokemon.mark_ability_used(state.turn_number)

	func _eligible(cards: Array[CardInstance]) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in cards:
			if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy":
				result.append(card)
		return result


class AttackOwnFieldNamedPokemonCountDamage extends BaseEffect:
	var damage_per_pokemon: int = 30
	var name_prefixes: PackedStringArray = PackedStringArray()
	var attack_index_to_match: int = -1

	func _init(per_pokemon: int = 30, prefixes: PackedStringArray = PackedStringArray(), match_attack_index: int = -1) -> void:
		damage_per_pokemon = per_pokemon
		name_prefixes = prefixes.duplicate()
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var count := 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			if _matches(slot):
				count += 1
		# DamageCalculator already parses the printed "30x" as one unit.
		# Offset that unit so copied attacks can still deal zero when the
		# attacking field contains no matching Pokemon.
		return damage_per_pokemon * (count - 1)

	func _matches(slot: PokemonSlot) -> bool:
		var card_data := slot.get_card_data() if slot != null else null
		if card_data == null:
			return false
		for identity: String in card_data.rule_identity_names():
			for prefix: String in name_prefixes:
				if prefix != "" and identity.begins_with(prefix):
					return true
		return false

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackRepeatedTargetDamage extends BaseEffect:
	const STEP_ID := "repeated_target_damage"
	var selection_count: int = 6
	var damage_per_selection: int = 20
	var attack_index_to_match: int = -1

	func _init(count: int = 6, damage: int = 20, match_attack_index: int = -1) -> void:
		selection_count = count
		damage_per_selection = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var targets := state.players[1 - card.owner_index].get_all_pokemon()
		var labels: Array[String] = []
		for slot: PokemonSlot in targets:
			labels.append(slot.get_pokemon_name())
		return [{"id": STEP_ID, "title": "分配%d次伤害" % selection_count, "ui_mode": "counter_distribution", "total_counters": selection_count, "target_items": targets, "target_labels": labels, "min_select": selection_count, "max_select": selection_count, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var legal := opponent.get_all_pokemon()
		var context := get_attack_interaction_context()
		var distribution: Dictionary = {}
		var selected_count := 0
		for raw: Variant in context.get(STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var target: Variant = raw.get("target", null)
			var amount := maxi(0, int(raw.get("amount", 0)))
			if target is PokemonSlot and target in legal and selected_count + amount <= selection_count:
				distribution[target] = int(distribution.get(target, 0)) + amount
				selected_count += amount
		if selected_count == 0 and not context.has(STEP_ID) and defender in legal:
			distribution[defender] = selection_count
			selected_count = selection_count
		if selected_count != selection_count:
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		for target_variant: Variant in distribution:
			var target := target_variant as PokemonSlot
			if target == null:
				continue
			if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
				continue
			if processor != null and processor.has_method("is_damage_prevented_by_defender_ability"):
				if bool(processor.call("is_damage_prevented_by_defender_ability", attacker, target, state)):
					continue
			CSV9CHelpers.apply_attack_damage_to_slot(attacker, target, state, int(distribution[target]) * damage_per_selection)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityDrawCardsOncePerTurn extends BaseEffect:
	var draw_count: int = 1

	func _init(count: int = 1) -> void:
		draw_count = count

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon in state.players[owner].get_all_pokemon() and not pokemon.has_ability_used(state.turn_number) and not state.players[owner].deck.is_empty()

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top := pokemon.get_top_card()
		_draw_cards_with_log(state, top.owner_index, draw_count, top, "ability")
		pokemon.mark_ability_used(state.turn_number)


class AbilityBurnDamageBonus extends BaseEffect:
	var bonus_damage: int = 30

	func _init(bonus: int = 30) -> void:
		bonus_damage = bonus

	func get_burn_damage_bonus_for_target(source: PokemonSlot, target: PokemonSlot, _state: GameState) -> int:
		if source == null or target == null or source.get_top_card() == null or target.get_top_card() == null:
			return 0
		return bonus_damage if source.get_top_card().owner_index != target.get_top_card().owner_index else 0

	func get_description() -> String:
		return "The opponent's Burn places %d additional damage." % bonus_damage


class AttackDiscardTeamRocketEnergyAndOpponentActive extends BaseEffect:
	const STEP_ID := "discard_team_rocket_energy"
	var attack_index_to_match: int = 1

	func _init(match_attack_index: int = 1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var attacker := state.players[card.owner_index].active_pokemon
		var eligible := _eligible_energy(attacker)
		if eligible.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{
			"id": STEP_ID,
			"title": "选择1张附着的火箭队能量放入弃牌区",
			"items": eligible,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var eligible := _eligible_energy(attacker)
		if eligible.is_empty():
			return
		var chosen: CardInstance = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in eligible:
				chosen = raw
				break
		if chosen == null:
			chosen = eligible[0]
		var owner := attacker.get_top_card().owner_index
		attacker.attached_energy.erase(chosen)
		state.players[owner].discard_pile.append(chosen)
		_record_attack_effect_discarded_attached_energy(attacker, chosen, state)
		# The Energy discard affects the attacker and still resolves when the
		# Defending Pokemon is protected from effects of attacks. Protection
		# only prevents the subsequent discard of the Defending Pokemon.
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		var defender_owner := defender.get_top_card().owner_index
		var defender_player := state.players[defender_owner]
		for attached: CardInstance in defender.collect_all_cards():
			attached.face_up = true
			defender_player.discard_pile.append(attached)
		defender.pokemon_stack.clear()
		defender.attached_energy.clear()
		defender.attached_tool = null
		defender.damage_counters = 0
		defender.clear_all_status()
		if defender_player.active_pokemon == defender:
			defender_player.active_pokemon = null
		else:
			defender_player.bench.erase(defender)

	func _eligible_energy(slot: PokemonSlot) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if slot == null:
			return result
		for energy: CardInstance in slot.attached_energy:
			if _is_team_rocket_energy(energy):
				result.append(energy)
		return result

	func _is_team_rocket_energy(card: CardInstance) -> bool:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			return false
		for identity: String in card.card_data.rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			if normalized in ["火箭队能量", "team rocket energy", "team rocket's energy"]:
				return true
		return false

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilitySearchNamedCard extends BaseEffect:
	const STEP_ID := "search_named_card"
	var aliases: Array[String] = []

	func _init(card_aliases: Array = []) -> void:
		for alias: Variant in card_aliases:
			aliases.append(str(alias))

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and not pokemon.has_ability_used(state.turn_number) and not state.players[owner].deck.is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var matching := _matching_cards(state.players[card.owner_index])
		if matching.is_empty():
			return [build_empty_search_resolution_step("牌库中没有指定卡牌。")]
		var labels: Array[String] = []
		for candidate: CardInstance in matching:
			labels.append(candidate.card_data.name)
		return [build_full_library_search_step(
			STEP_ID,
			"选择1张指定卡牌加入手牌",
			state.players[card.owner_index].deck,
			matching,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			1,
			1,
			{"allow_cancel": false}
		)]

	func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if not should_preview_empty_search_deck(resolved_context):
			return []
		return [build_readonly_deck_preview_step("查看剩余牌库", state.players[card.owner_index].deck)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top := pokemon.get_top_card()
		var player := state.players[top.owner_index]
		var matching := _matching_cards(player)
		var chosen: CardInstance = null
		for raw: Variant in get_interaction_context(targets).get(STEP_ID, []):
			if raw is CardInstance and raw in matching:
				chosen = raw
				break
		if chosen == null and not matching.is_empty():
			chosen = matching[0]
		if chosen != null:
			_move_public_cards_to_hand_with_log(state, top.owner_index, [chosen], top, "ability", "search_to_hand", aliases)
		player.shuffle_deck()
		pokemon.mark_ability_used(state.turn_number)

	func _matching_cards(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for candidate: CardInstance in player.deck:
			if _matches(candidate):
				result.append(candidate)
		return result

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null:
			return false
		for identity: String in card.card_data.rule_identity_names():
			for alias: String in aliases:
				if identity.strip_edges().to_lower() == alias.strip_edges().to_lower():
					return true
		return false


class AttackDiscardPileNamedCardCountDamage extends BaseEffect:
	var damage_per_card: int = 60
	var aliases: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(per_card: int = 60, card_aliases: Array = [], match_attack_index: int = 0) -> void:
		damage_per_card = per_card
		for alias: Variant in card_aliases:
			aliases.append(str(alias))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var count := 0
		for card: CardInstance in state.players[attacker.get_top_card().owner_index].discard_pile:
			if _matches(card):
				count += 1
		return count * damage_per_card

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null:
			return false
		for identity: String in card.card_data.rule_identity_names():
			for alias: String in aliases:
				if identity.strip_edges().to_lower() == alias.strip_edges().to_lower():
					return true
		return false

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackDiscardFireEnergyFromSelfMultiplier extends BaseEffect:
	const STEP_ID := "discard_fire_energy_from_self"
	var damage_per_energy: int = 70
	var max_discard: int = 5
	var attack_index_to_match: int = 0

	func _init(per_energy: int = 70, maximum: int = 5, match_attack_index: int = 0) -> void:
		damage_per_energy = per_energy
		max_discard = maximum
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var eligible := _eligible(state.players[card.owner_index].active_pokemon, state)
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{
			"id": STEP_ID,
			"title": "选择最多%d张附着的火能量放入弃牌区" % max_discard,
			"items": eligible,
			"labels": labels,
			"min_select": 0,
			"max_select": mini(max_discard, eligible.size()),
			"allow_cancel": true,
		}]

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return (_selected(attacker, state).size() - 1) * damage_per_energy

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or state == null or not applies_to_attack_index(attack_index):
			return
		var selected := _selected(attacker, state)
		if selected.is_empty() and not get_attack_interaction_context().has(STEP_ID):
			selected = _eligible(attacker, state).slice(0, max_discard)
		var player := state.players[attacker.get_top_card().owner_index]
		for energy: CardInstance in selected:
			attacker.attached_energy.erase(energy)
			player.discard_pile.append(energy)
			_record_attack_effect_discarded_attached_energy(attacker, energy, state)

	func _selected(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
		var eligible := _eligible(attacker, state)
		var result: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in eligible and raw not in result:
				result.append(raw)
				if result.size() >= max_discard:
					break
		return result

	func _eligible(attacker: PokemonSlot, state: GameState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if attacker == null:
			return result
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
		for energy: CardInstance in attacker.attached_energy:
			if energy == null or energy.card_data == null or not energy.card_data.is_energy():
				continue
			var provided := str(energy.card_data.energy_provides if energy.card_data.energy_provides != "" else energy.card_data.energy_type)
			if processor != null and processor.has_method("get_energy_type"):
				provided = str(processor.call("get_energy_type", energy, state))
			if provided == "R" or provided == "ANY":
				result.append(energy)
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityAttachFireToBenchedEthansPokemon extends BaseEffect:
	const STEP_ID := "attach_fire_to_benched_ethan"
	var max_energy: int = 2

	func _init(maximum: int = 2) -> void:
		max_energy = maximum

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		return state.current_player_index == owner and not pokemon.has_ability_used(state.turn_number) and not _energy(player).is_empty() and not _targets(player).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var sources := _energy(player)
		var targets := _targets(player)
		var source_labels: Array[String] = []
		var target_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(energy.card_data.name)
		for slot: PokemonSlot in targets:
			target_labels.append(slot.get_pokemon_name())
		var step := build_card_assignment_step(STEP_ID, "选择最多2张基本火能量附着于1只备战区的阿响的宝可梦", sources, source_labels, targets, target_labels, 0, mini(max_energy, sources.size()), true)
		step["single_target_only"] = true
		return [step]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var sources := _energy(player)
		var legal_targets := _targets(player)
		var selected: Array[CardInstance] = []
		var chosen_target: PokemonSlot = null
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var source: Variant = raw.get("source", null)
			var target: Variant = raw.get("target", null)
			if source is CardInstance and target is PokemonSlot and source in sources and target in legal_targets and source not in selected:
				if chosen_target == null:
					chosen_target = target
				if target == chosen_target:
					selected.append(source)
					if selected.size() >= max_energy:
						break
		if selected.is_empty() and not context.has(STEP_ID):
			chosen_target = legal_targets[0]
			selected = sources.slice(0, max_energy)
		if chosen_target == null or selected.is_empty():
			return
		for energy: CardInstance in selected:
			player.hand.erase(energy)
			chosen_target.attached_energy.append(energy)
		pokemon.mark_ability_used(state.turn_number)

	func _energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.hand:
			if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy" and (card.card_data.energy_provides == "R" or card.card_data.energy_type == "R"):
				result.append(card)
		return result

	func _targets(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.bench:
			if _is_ethans_pokemon(slot):
				result.append(slot)
		return result

	func _is_ethans_pokemon(slot: PokemonSlot) -> bool:
		if slot == null or slot.get_card_data() == null:
			return false
		for identity: String in slot.get_card_data().rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			if normalized.begins_with("阿响的") or normalized.begins_with("ethan's "):
				return true
		return false


class AttackHealAllOwnPokemon extends BaseEffect:
	var heal_amount: int = 50
	var attack_index_to_match: int = 0

	func _init(amount: int = 50, match_attack_index: int = 0) -> void:
		heal_amount = amount
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			slot.damage_counters = maxi(0, slot.damage_counters - heal_amount)


class AttackDiscardTwoEnergyThenBenchDamage extends BaseEffect:
	const ENERGY_STEP_ID := "discard_two_energy_for_bench_damage"
	const TARGET_STEP_ID := "bench_damage_target"
	var damage_amount: int = 120
	var attack_index_to_match: int = 1

	func _init(damage: int = 120, match_attack_index: int = 1) -> void:
		damage_amount = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var attacker := state.players[card.owner_index].active_pokemon
		var energy: Array = attacker.attached_energy.duplicate() if attacker != null else []
		var energy_labels: Array[String] = []
		for attached: CardInstance in energy:
			energy_labels.append(attached.card_data.name)
		var bench: Array = state.players[1 - card.owner_index].bench.duplicate()
		var bench_labels: Array[String] = []
		for slot: PokemonSlot in bench:
			bench_labels.append(slot.get_pokemon_name())
		var steps: Array[Dictionary] = [{
			"id": ENERGY_STEP_ID,
			"title": "选择2个附着的能量放入弃牌区",
			"items": energy,
			"labels": energy_labels,
			"min_select": mini(2, energy.size()),
			"max_select": mini(2, energy.size()),
			"allow_cancel": false,
		}]
		if not bench.is_empty():
			steps.append({
			"id": TARGET_STEP_ID,
			"title": "选择对手的1只备战宝可梦",
			"items": bench,
			"labels": bench_labels,
			"min_select": mini(1, bench.size()),
			"max_select": mini(1, bench.size()),
			"allow_cancel": false,
			})
		return steps

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var context := get_attack_interaction_context()
		var selected_energy: Array[CardInstance] = []
		for raw: Variant in context.get(ENERGY_STEP_ID, []):
			if raw is CardInstance and raw in attacker.attached_energy and raw not in selected_energy:
				selected_energy.append(raw)
				if selected_energy.size() >= 2:
					break
		if selected_energy.size() < 2 and not context.has(ENERGY_STEP_ID):
			selected_energy = attacker.attached_energy.slice(0, 2)
		if selected_energy.size() < 2:
			return
		for energy: CardInstance in selected_energy:
			attacker.attached_energy.erase(energy)
			player.discard_pile.append(energy)
			_record_attack_effect_discarded_attached_energy(attacker, energy, state)
		var target: PokemonSlot = null
		for raw: Variant in context.get(TARGET_STEP_ID, []):
			if raw is PokemonSlot and raw in opponent.bench:
				target = raw
				break
		if target == null and not context.has(TARGET_STEP_ID) and not opponent.bench.is_empty():
			target = opponent.bench[0]
		if target == null:
			return
		if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
			return
		target.damage_counters += _calculate_attack_target_damage(attacker, target, damage_amount, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityBurnOpponentActiveOncePerTurn extends BaseEffect:
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and state.players[owner].active_pokemon == pokemon and not pokemon.has_ability_used(state.turn_number) and state.players[1 - owner].active_pokemon != null

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		_apply_special_status(state.players[1 - owner].active_pokemon, "burned", state)
		pokemon.mark_ability_used(state.turn_number)


class AbilityDamp extends BaseEffect:
	func blocks_self_knockout_abilities(_source: PokemonSlot, _state: GameState) -> bool:
		return true

	func get_description() -> String:
		return "While this Pokemon is in play, Abilities that Knock Out their user have no effect."


class AbilityMistysPsyduckSkipJump extends BaseEffect:
	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and pokemon in state.players[owner].bench and not state.players[owner].deck.is_empty()

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top := pokemon.get_top_card()
		var player := state.players[top.owner_index]
		var bottom: CardInstance = player.deck.pop_back()
		bottom.face_up = true
		player.discard_pile.append(bottom)
		for energy: CardInstance in pokemon.attached_energy:
			energy.face_up = true
			player.discard_pile.append(energy)
		if pokemon.attached_tool != null:
			pokemon.attached_tool.face_up = true
			player.discard_pile.append(pokemon.attached_tool)
		pokemon.attached_energy.clear()
		pokemon.attached_tool = null
		pokemon.pokemon_stack.clear()
		pokemon.damage_counters = 0
		pokemon.clear_all_status()
		player.bench.erase(pokemon)
		top.face_up = false
		player.deck.push_front(top)


class AttackEvolvedFromNamedPokemonBonus extends BaseEffect:
	var bonus_damage: int = 80
	var name_prefixes: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(bonus: int = 80, prefixes: Array = [], match_attack_index: int = 0) -> void:
		bonus_damage = bonus
		for prefix: Variant in prefixes:
			name_prefixes.append(str(prefix))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or state == null or attacker.turn_evolved != state.turn_number or attacker.pokemon_stack.size() < 2:
			return 0
		var previous: CardInstance = attacker.pokemon_stack[attacker.pokemon_stack.size() - 2]
		if previous == null or previous.card_data == null:
			return 0
		for identity: String in previous.card_data.rule_identity_names():
			for prefix: String in name_prefixes:
				if identity.strip_edges().to_lower().begins_with(prefix.strip_edges().to_lower()):
					return bonus_damage
		return 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackMillTopAndCountNamedPokemon extends BaseEffect:
	var mill_count: int = 7
	var damage_per_match: int = 70
	var name_prefixes: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(count: int = 7, per_match: int = 70, prefixes: Array = [], match_attack_index: int = 0) -> void:
		mill_count = count
		damage_per_match = per_match
		for prefix: Variant in prefixes:
			name_prefixes.append(str(prefix))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -damage_per_match
		var player := state.players[attacker.get_top_card().owner_index]
		var matches := 0
		for index: int in mini(mill_count, player.deck.size()):
			if _matches(player.deck[index]):
				matches += 1
		return (matches - 1) * damage_per_match

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		for _index: int in mini(mill_count, player.deck.size()):
			var card: CardInstance = player.deck.pop_front()
			card.face_up = true
			player.discard_pile.append(card)

	func _matches(card: CardInstance) -> bool:
		if card == null or card.card_data == null or not card.card_data.is_pokemon():
			return false
		for identity: String in card.card_data.rule_identity_names():
			for prefix: String in name_prefixes:
				if identity.strip_edges().to_lower().begins_with(prefix.strip_edges().to_lower()):
					return true
		return false


class AttackSearchNamedPokemonToHand extends BaseEffect:
	const STEP_ID := "search_mistys_pokemon"
	var search_count: int = 3
	var name_prefixes: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(count: int = 3, prefixes: Array = [], match_attack_index: int = 0) -> void:
		search_count = count
		for prefix: Variant in prefixes:
			name_prefixes.append(str(prefix))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var matching := _matching(player)
		if matching.is_empty():
			return [build_empty_search_resolution_step("牌库中没有符合条件的宝可梦。")]
		return [build_full_library_search_step(STEP_ID, "选择最多%d张指定宝可梦加入手牌" % search_count, player.deck, matching, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(search_count, matching.size()), {"allow_cancel": true})]

	func get_followup_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if not should_preview_empty_search_deck(resolved_context):
			return []
		return [build_readonly_deck_preview_step("查看剩余牌库", state.players[card.owner_index].deck)]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var matching := _matching(player)
		var selected: Array[CardInstance] = []
		var context := get_attack_interaction_context()
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in matching and raw not in selected:
				selected.append(raw)
				if selected.size() >= search_count:
					break
		if selected.is_empty() and not context.has(STEP_ID):
			selected = matching.slice(0, search_count)
		var reveal_labels: Array[String] = ["named Pokemon"]
		_move_public_cards_to_hand_with_log(state, attacker.get_top_card().owner_index, selected, attacker.get_top_card(), "attack", "search_to_hand", reveal_labels)
		player.shuffle_deck()

	func _matching(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card != null and card.card_data != null and card.card_data.is_pokemon():
				for identity: String in card.card_data.rule_identity_names():
					for prefix: String in name_prefixes:
						if identity.strip_edges().to_lower().begins_with(prefix.strip_edges().to_lower()):
							result.append(card)
							break
					if card in result:
						break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityBasicTeamRocketAttackEffectShield extends BaseEffect:
	func prevents_attack_effects_to_target(source: PokemonSlot, target: PokemonSlot, _attacker: PokemonSlot, _state: GameState) -> bool:
		if source == null or target == null or source.get_top_card() == null or target.get_top_card() == null:
			return false
		if source.get_top_card().owner_index != target.get_top_card().owner_index:
			return false
		var card_data := target.get_card_data()
		if card_data == null or card_data.stage != "Basic":
			return false
		for identity: String in card_data.rule_identity_names():
			var normalized := identity.strip_edges().to_lower()
			if normalized.begins_with("火箭队的") or normalized.begins_with("team rocket's "):
				return true
		return false


class AttackBonusIfAttachedNamedEnergy extends BaseEffect:
	var bonus_damage: int = 60
	var energy_aliases: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(bonus: int = 60, aliases: Array = [], match_attack_index: int = 0) -> void:
		bonus_damage = bonus
		for alias: Variant in aliases:
			energy_aliases.append(str(alias))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
		if attacker == null:
			return 0
		for energy: CardInstance in attacker.attached_energy:
			if energy == null or energy.card_data == null:
				continue
			for identity: String in energy.card_data.rule_identity_names():
				for alias: String in energy_aliases:
					if identity.strip_edges().to_lower() == alias.strip_edges().to_lower():
						return bonus_damage
		return 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AbilityReturnBasicWaterOnAttackKnockout extends BaseEffect:
	func knockout_attached_cards_to_hand(_source: PokemonSlot, knocked_out: PokemonSlot, _state: GameState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if knocked_out == null or knocked_out.get_card_data() == null or knocked_out.get_card_data().energy_type != "W":
			return result
		for energy: CardInstance in knocked_out.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy" and (energy.card_data.energy_provides == "W" or energy.card_data.energy_type == "W"):
				result.append(energy)
		return result


class AttackAttachWaterFromHandMultiplier extends BaseEffect:
	const STEP_ID := "attach_water_from_hand_before_damage"
	var damage_per_energy: int = 30
	var attack_index_to_match: int = 0

	func _init(per_energy: int = 30, match_attack_index: int = 0) -> void:
		damage_per_energy = per_energy
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var eligible := _eligible(state.players[card.owner_index])
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{"id": STEP_ID, "title": "选择任意数量的基本水能量附着于这只宝可梦", "items": eligible, "labels": labels, "min_select": 0, "max_select": eligible.size(), "allow_cancel": true}]

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -damage_per_energy
		var player := state.players[attacker.get_top_card().owner_index]
		var count := attacker.count_energy_of_type("W") + _selected(player).size()
		return (count - 1) * damage_per_energy

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		for energy: CardInstance in _selected(player):
			player.hand.erase(energy)
			attacker.attached_energy.append(energy)

	func _selected(player: PlayerState) -> Array[CardInstance]:
		var eligible := _eligible(player)
		var result: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in eligible and raw not in result:
				result.append(raw)
		return result

	func _eligible(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.hand:
			if card != null and card.card_data != null and card.card_data.card_type == "Basic Energy" and (card.card_data.energy_provides == "W" or card.card_data.energy_type == "W"):
				result.append(card)
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackNamedFieldEnergyCountBonus extends BaseEffect:
	var energy_type: String = "L"
	var damage_per_energy: int = 20
	var name_prefixes: Array[String] = []
	var attack_index_to_match: int = 0

	func _init(required_energy: String = "L", per_energy: int = 20, prefixes: Array = [], match_attack_index: int = 0) -> void:
		energy_type = required_energy
		damage_per_energy = per_energy
		for prefix: Variant in prefixes:
			name_prefixes.append(str(prefix))
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		var count := 0
		for slot: PokemonSlot in state.players[attacker.get_top_card().owner_index].get_all_pokemon():
			if _matches(slot):
				for energy: CardInstance in slot.attached_energy:
					if _energy_matches(energy, state):
						count += 1
		return count * damage_per_energy

	func _energy_matches(energy: CardInstance, state: GameState) -> bool:
		if energy == null or energy.card_data == null:
			return false
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("get_energy_types"):
			var types := PackedStringArray(processor.call("get_energy_types", energy, state))
			return energy_type in types or "ANY" in types
		return energy.card_data.energy_provides in [energy_type, "ANY"] or energy.card_data.energy_type == energy_type

	func _matches(slot: PokemonSlot) -> bool:
		if slot == null or slot.get_card_data() == null:
			return false
		for identity: String in slot.get_card_data().rule_identity_names():
			for prefix: String in name_prefixes:
				if identity.strip_edges().to_lower().begins_with(prefix.strip_edges().to_lower()):
					return true
		return false

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackSelfDamageThenCoinKnockout extends BaseEffect:
	var self_damage: int = 100
	var attack_index_to_match: int = 0
	var coin_flipper: CoinFlipper = CoinFlipper.new()

	func _init(recoil: int = 100, match_attack_index: int = 0, flipper: CoinFlipper = null) -> void:
		self_damage = recoil
		attack_index_to_match = match_attack_index
		if flipper != null:
			coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		attacker.damage_counters += self_damage
		if not coin_flipper.flip():
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		defender.damage_counters = maxi(defender.damage_counters, defender.get_max_hp())


class AttackTwoOpponentPokemonDamage extends BaseEffect:
	const STEP_ID := "opponent_two_targets"
	var damage_amount: int = 50
	var target_count: int = 2
	var attack_index_to_match: int = 0

	func _init(damage: int = 50, count: int = 2, match_attack_index: int = 0) -> void:
		damage_amount = damage
		target_count = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var targets := state.players[1 - card.owner_index].get_all_pokemon()
		var labels: Array[String] = []
		for slot: PokemonSlot in targets:
			labels.append(slot.get_pokemon_name())
		var count := mini(target_count, targets.size())
		return [{"id": STEP_ID, "title": "选择对手的%d只宝可梦" % count, "items": targets, "labels": labels, "min_select": count, "max_select": count, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var chosen: Array[PokemonSlot] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is PokemonSlot and raw in opponent.get_all_pokemon() and raw not in chosen:
				chosen.append(raw)
				if chosen.size() >= target_count:
					break
		if chosen.is_empty():
			chosen = opponent.get_all_pokemon().slice(0, target_count)
		for target: PokemonSlot in chosen:
			if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
				continue
			target.damage_counters += _calculate_attack_target_damage(attacker, target, damage_amount, state)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AttackBonusIfExcessEnergy extends BaseEffect:
	var excess_required: int = 2
	var bonus_damage: int = 100
	var attack_index_to_match: int = 1

	func _init(excess: int = 2, bonus: int = 100, match_attack_index: int = 1) -> void:
		excess_required = excess
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, _state: GameState) -> int:
		if attacker == null or attacker.get_card_data() == null or attack_index_to_match < 0 or attack_index_to_match >= attacker.get_card_data().attacks.size():
			return 0
		var required := str(attacker.get_card_data().attacks[attack_index_to_match].get("cost", "")).length()
		return bonus_damage if attacker.get_total_energy_count() >= required + excess_required else 0

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackMoveOpponentActiveEnergyToBench extends BaseEffect:
	const ASSIGNMENT_STEP_ID := "move_opponent_active_energy_assignment"
	const ENERGY_STEP_ID := "move_opponent_active_energy"
	const TARGET_STEP_ID := "move_opponent_energy_target"
	var attack_index_to_match: int = 0

	func _init(match_attack_index: int = 0) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.active_pokemon == null or opponent.active_pokemon.attached_energy.is_empty() or opponent.bench.is_empty():
			return []
		var energy: Array = opponent.active_pokemon.attached_energy.duplicate()
		var energy_labels: Array[String] = []
		var target_labels: Array[String] = []
		for attached: CardInstance in energy:
			energy_labels.append(attached.card_data.name)
		for slot: PokemonSlot in opponent.bench:
			target_labels.append(slot.get_pokemon_name())
		var step := build_card_assignment_step(
			ASSIGNMENT_STEP_ID,
			"若希望，选择对手战斗宝可梦的1个能量并转附于其备战宝可梦",
			energy,
			energy_labels,
			opponent.bench.duplicate(),
			target_labels,
			0,
			1,
			true
		)
		step["single_target_only"] = true
		return [step]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[defender.get_top_card().owner_index]
		var chosen_energy: CardInstance = null
		var chosen_target: PokemonSlot = null
		for raw: Variant in get_attack_interaction_context().get(ASSIGNMENT_STEP_ID, []):
			if not (raw is Dictionary):
				continue
			var source: Variant = raw.get("source", null)
			var target: Variant = raw.get("target", null)
			if source is CardInstance and source in defender.attached_energy and target is PokemonSlot and target in opponent.bench:
				chosen_energy = source
				chosen_target = target
				break
		# Keep old two-step contexts valid for replays and headless callers.
		for raw: Variant in get_attack_interaction_context().get(ENERGY_STEP_ID, []):
			if chosen_energy != null:
				break
			if raw is CardInstance and raw in defender.attached_energy:
				chosen_energy = raw
				break
		for raw: Variant in get_attack_interaction_context().get(TARGET_STEP_ID, []):
			if chosen_target != null:
				break
			if raw is PokemonSlot and raw in opponent.bench:
				chosen_target = raw
				break
		if chosen_energy == null or chosen_target == null:
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		defender.attached_energy.erase(chosen_energy)
		chosen_target.attached_energy.append(chosen_energy)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityDamageOpponentEvolutionFromHand extends BaseEffect:
	var counter_count: int = 4

	func _init(count: int = 4) -> void:
		counter_count = count

	func on_opponent_evolved_from_hand(source: PokemonSlot, evolved_slot: PokemonSlot, evolved_player_index: int, _state: GameState) -> void:
		if source == null or source.get_top_card() == null or evolved_slot == null or evolved_slot.get_top_card() == null:
			return
		if source.get_top_card().owner_index == evolved_player_index:
			return
		evolved_slot.damage_counters += counter_count * 10


class AttackDiscardOpponentToolThenParalyze extends BaseEffect:
	var attack_index_to_match: int = 0

	func _init(match_attack_index: int = 0) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or defender == null or defender.get_top_card() == null or state == null or not applies_to_attack_index(attack_index) or defender.attached_tool == null:
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		var tool := defender.attached_tool
		defender.attached_tool = null
		tool.face_up = true
		state.players[defender.get_top_card().owner_index].discard_pile.append(tool)
		_apply_special_status(defender, "paralyzed", state)


class AttackDiscardAllEnergyDamageBenchedEx extends BaseEffect:
	const STEP_ID := "bench_ex_target"
	var damage_amount: int = 210
	var attack_index_to_match: int = 1

	func _init(damage: int = 210, match_attack_index: int = 1) -> void:
		damage_amount = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var targets := _targets(state.players[1 - card.owner_index])
		var labels: Array[String] = []
		for slot: PokemonSlot in targets:
			labels.append(slot.get_pokemon_name())
		return [{"id": STEP_ID, "title": "选择对手备战区的1只宝可梦ex", "items": targets, "labels": labels, "min_select": mini(1, targets.size()), "max_select": mini(1, targets.size()), "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var discarded := attacker.attached_energy.duplicate()
		attacker.attached_energy.clear()
		for energy: CardInstance in discarded:
			player.discard_pile.append(energy)
			_record_attack_effect_discarded_attached_energy(attacker, energy, state)
		var legal := _targets(opponent)
		var target: PokemonSlot = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is PokemonSlot and raw in legal:
				target = raw
				break
		if target == null and not legal.is_empty():
			target = legal[0]
		if target == null or AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
			return
		target.damage_counters += _calculate_attack_target_damage(attacker, target, damage_amount, state)

	func _targets(opponent: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in opponent.bench:
			if slot != null and slot.get_card_data() != null and slot.get_card_data().mechanic == "ex":
				result.append(slot)
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1


class AbilityDiscardAttachedLightningDrawToSix extends BaseEffect:
	const STEP_ID := "discard_attached_basic_lightning"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return state.current_player_index == owner and not pokemon.has_ability_used(state.turn_number) and not _eligible(pokemon).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var slot: PokemonSlot = null
		for candidate: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
			if candidate.get_top_card() == card:
				slot = candidate
				break
		var eligible := _eligible(slot)
		var labels: Array[String] = []
		for energy: CardInstance in eligible:
			labels.append(energy.card_data.name)
		return [{"id": STEP_ID, "title": "选择1个附着的基本雷能量放入弃牌区", "items": eligible, "labels": labels, "min_select": 1, "max_select": 1, "allow_cancel": true}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var eligible := _eligible(pokemon)
		var chosen: CardInstance = null
		for raw: Variant in get_interaction_context(targets).get(STEP_ID, []):
			if raw is CardInstance and raw in eligible:
				chosen = raw
				break
		if chosen == null:
			chosen = eligible[0]
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		pokemon.attached_energy.erase(chosen)
		chosen.face_up = true
		player.discard_pile.append(chosen)
		_draw_cards_with_log(state, owner, maxi(0, 6 - player.hand.size()), pokemon.get_top_card(), "ability")
		pokemon.mark_ability_used(state.turn_number)

	func _eligible(pokemon: PokemonSlot) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if pokemon == null:
			return result
		for energy: CardInstance in pokemon.attached_energy:
			if energy != null and energy.card_data != null and energy.card_data.card_type == "Basic Energy" and (energy.card_data.energy_provides == "L" or energy.card_data.energy_type == "L"):
				result.append(energy)
		return result


class AttackOpponentBenchTailsMultiplier extends BaseEffect:
	var damage_per_tails: int = 80
	var printed_base_damage: int = 80
	var attack_index_to_match: int = 1
	var coin_flipper: CoinFlipper = CoinFlipper.new()

	func _init(per_tails: int = 80, printed_base: int = 80, match_attack_index: int = 1, flipper: CoinFlipper = null) -> void:
		damage_per_tails = per_tails
		printed_base_damage = printed_base
		attack_index_to_match = match_attack_index
		if flipper != null:
			coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return -printed_base_damage
		var tails := 0
		for _flip: int in state.players[1 - attacker.get_top_card().owner_index].bench.size():
			if not coin_flipper.flip():
				tails += 1
		return tails * damage_per_tails - printed_base_damage

	func ignores_weakness_and_resistance(_attacker: PokemonSlot, _state: GameState, attack_index: int) -> bool:
		return applies_to_attack_index(attack_index)

	func execute_attack(_attacker: PokemonSlot, _defender: PokemonSlot, _attack_index: int, _state: GameState) -> void:
		pass


class AttackRocketMirror extends BaseEffect:
	const STEP_ID := "rocket_mirror_source"
	var attack_index_to_match: int = 0

	func _init(match_attack_index: int = 0) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var legal := _legal_sources(state.players[card.owner_index])
		var labels: Array[String] = []
		for slot: PokemonSlot in legal:
			labels.append("%s (%d damage)" % [slot.get_pokemon_name(), slot.damage_counters])
		return [{"id": STEP_ID, "title": "Choose 1 damaged Benched Team Rocket's Pokemon", "items": legal, "labels": labels, "min_select": mini(1, legal.size()), "max_select": mini(1, legal.size()), "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var legal := _legal_sources(player)
		var source: PokemonSlot = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is PokemonSlot and raw in legal:
				source = raw
				break
		if source == null and not legal.is_empty():
			source = legal[0]
		if source == null:
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		var amount := source.damage_counters
		source.damage_counters = 0
		defender.damage_counters += amount
		if amount > 0:
			_mark_attack_damage_counter_placement(defender, state)

	func _legal_sources(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.bench:
			if slot.damage_counters > 0 and CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
				result.append(slot)
		return result


class AttackSearchBasicStevensPokemonToBench extends BaseEffect:
	const STEP_ID := "search_basic_steven_to_bench"
	var search_count: int = 2
	var attack_index_to_match: int = 0

	func _init(count: int = 2, match_attack_index: int = 0) -> void:
		search_count = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var legal := _legal_cards(player)
		var available := mini(search_count, BenchLimitHelper.get_available_bench_space(state, player))
		if legal.is_empty() or available <= 0:
			return []
		return [build_full_library_search_step(STEP_ID, "Choose up to 2 Basic Steven's Pokemon to put on your Bench", player.deck, legal, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(available, legal.size()), {"allow_cancel": true})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var legal := _legal_cards(player)
		var available := mini(search_count, BenchLimitHelper.get_available_bench_space(state, player))
		var chosen: Array[CardInstance] = []
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in chosen:
				chosen.append(raw)
				if chosen.size() >= available:
					break
		if not get_attack_interaction_context().has(STEP_ID):
			chosen.assign(legal.slice(0, mini(available, legal.size())))
		for pokemon: CardInstance in chosen:
			if pokemon not in player.deck or BenchLimitHelper.is_bench_full(state, player):
				continue
			player.deck.erase(pokemon)
			pokemon.face_up = true
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(pokemon)
			slot.turn_played = state.turn_number
			player.bench.append(slot)
		player.shuffle_deck()

	func _legal_cards(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card != null and card.card_data != null and card.card_data.is_basic_pokemon() and CSV10CEffects.matches_named_card(card.card_data, STEVEN_PREFIXES):
				result.append(card)
		return result


class AttackVictorySymbol extends BaseEffect:
	var attack_index_to_match: int = 1

	func _init(match_attack_index: int = 1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var owner := attacker.get_top_card().owner_index
		if state.players[owner].prizes.size() == 1:
			state.set_game_over(owner, "victory_symbol")


class AbilityBenchStevensPokemonDamageReduction extends BaseEffect:
	var reduction_amount: int = 30

	func _init(amount: int = 30) -> void:
		reduction_amount = maxi(0, amount)

	func get_team_defense_modifier(source: PokemonSlot, defender: PokemonSlot, attacker: PokemonSlot, state: GameState) -> int:
		if source == null or source.get_top_card() == null or defender == null or defender.get_top_card() == null or state == null:
			return 0
		var owner := source.get_top_card().owner_index
		if owner < 0 or owner >= state.players.size() or source not in state.players[owner].bench:
			return 0
		if defender.get_top_card().owner_index != owner or not CSV10CEffects.matches_named_pokemon(defender, STEVEN_PREFIXES):
			return 0
		if attacker != null and attacker.get_top_card() != null and attacker.get_top_card().owner_index == owner:
			return 0
		var effect_id := source.get_card_data().effect_id
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		for candidate: PokemonSlot in state.players[owner].bench:
			if candidate == null or candidate.get_card_data() == null or candidate.get_card_data().effect_id != effect_id:
				continue
			if processor != null and processor.has_method("is_ability_disabled") and bool(processor.call("is_ability_disabled", candidate, state)):
				continue
			return -reduction_amount if candidate == source else 0
		return 0


class AbilityLuringWink extends BaseEffect:
	const STEP_ID := "opponent_basic_to_bench"
	const PREVIEW_STEP_ID := "opponent_hand_preview"

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		return CSV9CHelpers.evolved_from_hand_this_turn(pokemon, state) and not pokemon.has_ability_used(state.turn_number)

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.hand.is_empty():
			return []
		var labels: Array[String] = []
		for hand_card: CardInstance in opponent.hand:
			labels.append(hand_card.card_data.display_name() if hand_card.card_data != null else "Unknown")
		return [{
			"id": PREVIEW_STEP_ID,
			"title": "Look at the opponent's hand",
			"items": opponent.hand.duplicate(),
			"labels": labels,
			"presentation": "cards",
			"visible_scope": "opponent_hand_revealed",
			"min_select": 0,
			"max_select": 0,
			"allow_cancel": false,
			"force_confirm": true,
		}]

	func get_followup_interaction_steps(card: CardInstance, state: GameState, resolved_context: Dictionary) -> Array[Dictionary]:
		if card == null or state == null or not resolved_context.has(PREVIEW_STEP_ID):
			return []
		var opponent := state.players[1 - card.owner_index]
		var legal := _legal_basic_cards(opponent)
		var legal_count := mini(legal.size(), BenchLimitHelper.get_available_bench_space(state, opponent))
		if legal_count <= 0:
			return []
		var labels: Array[String] = []
		for basic: CardInstance in legal:
			labels.append(basic.card_data.display_name())
		return [{
			"id": STEP_ID,
			"title": "Choose any number of Basic Pokemon to put on the opponent's Bench",
			"items": legal,
			"labels": labels,
			"presentation": "cards",
			"visible_scope": "opponent_hand_revealed",
			"min_select": 0,
			"max_select": legal_count,
			"allow_cancel": true,
			"force_confirm": true,
		}]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner := pokemon.get_top_card().owner_index
		var opponent := state.players[1 - owner]
		var legal := _legal_basic_cards(opponent)
		var selected: Array[CardInstance] = []
		var context := get_interaction_context(targets)
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in selected and not BenchLimitHelper.is_bench_full(state, opponent):
				selected.append(raw)
		for card: CardInstance in selected:
			if card not in opponent.hand or BenchLimitHelper.is_bench_full(state, opponent):
				continue
			opponent.hand.erase(card)
			card.face_up = true
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(card)
			slot.turn_played = state.turn_number
			opponent.bench.append(slot)
		pokemon.mark_ability_used(state.turn_number)

	func _legal_basic_cards(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.hand:
			if card != null and card.card_data != null and card.card_data.is_basic_pokemon():
				result.append(card)
		return result


class AttackSearchBasicLilliesPokemonToBench extends BaseEffect:
	const STEP_ID := "search_basic_lillie_to_bench"
	var attack_index_to_match: int = 0

	func _init(match_attack_index: int = 0) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var legal := _legal_cards(player)
		var available := BenchLimitHelper.get_available_bench_space(state, player)
		if legal.is_empty() or available <= 0:
			return []
		return [build_full_library_search_step(STEP_ID, "Choose any number of Basic Lillie's Pokemon to put on your Bench", player.deck, legal, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(available, legal.size()), {"allow_cancel": true})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var legal := _legal_cards(player)
		var available := BenchLimitHelper.get_available_bench_space(state, player)
		var context := get_attack_interaction_context()
		var chosen: Array[CardInstance] = []
		for raw: Variant in context.get(STEP_ID, []):
			if raw is CardInstance and raw in legal and raw not in chosen:
				chosen.append(raw)
				if chosen.size() >= available:
					break
		if not context.has(STEP_ID):
			chosen.assign(legal.slice(0, mini(available, legal.size())))
		for card: CardInstance in chosen:
			if card not in player.deck or BenchLimitHelper.is_bench_full(state, player):
				continue
			player.deck.erase(card)
			card.face_up = true
			var slot := PokemonSlot.new()
			slot.pokemon_stack.append(card)
			slot.turn_played = state.turn_number
			player.bench.append(slot)
		player.shuffle_deck()

	func _legal_cards(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card != null and card.card_data != null and card.card_data.is_basic_pokemon() and CSV10CEffects.matches_named_card(card.card_data, LILLIE_PREFIXES):
				result.append(card)
		return result


class AttackReturnSelfAllCardsToHandAtIndex extends AttackReturnSelfAllCardsToHand:
	var attack_index_to_match: int = 1

	func _init(match_attack_index: int = 1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match


class AttackCopyOpponentTeraAttack extends AttackCopyAttack:
	func _init(processor: EffectProcessor = null) -> void:
		super(processor)

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.active_pokemon == null or opponent.active_pokemon.get_card_data() == null or not opponent.active_pokemon.get_card_data().is_tera_pokemon():
			return []
		return super.get_attack_interaction_steps(card, attack, state)


class AttackReorderOpponentTopCards extends BaseEffect:
	const STEP_ID := "opponent_top5_order"
	var look_count: int = 5
	var attack_index_to_match: int = 0

	func _init(count: int = 5, match_attack_index: int = 0) -> void:
		look_count = maxi(0, count)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var opponent := state.players[1 - card.owner_index]
		var top_cards := opponent.deck.slice(0, mini(look_count, opponent.deck.size()))
		if top_cards.is_empty():
			return []
		var labels: Array[String] = []
		for top_card: CardInstance in top_cards:
			labels.append(top_card.card_data.display_name() if top_card.card_data != null else "Unknown")
		return [{
			"id": STEP_ID,
			"title": "Arrange the top cards of the opponent's deck in any order (first selected is the top card)",
			"items": top_cards,
			"labels": labels,
			"presentation": "cards",
			"visible_scope": "opponent_top_cards_revealed",
			"min_select": top_cards.size(),
			"max_select": top_cards.size(),
			"selection_order_matters": true,
			"allow_cancel": false,
			"force_confirm": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var count := mini(look_count, opponent.deck.size())
		if count <= 0:
			return
		var original := opponent.deck.slice(0, count)
		var selected_raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var ordered: Array[CardInstance] = []
		for raw: Variant in selected_raw:
			if raw is CardInstance and raw in original and raw not in ordered:
				ordered.append(raw)
		if ordered.size() != original.size():
			ordered.assign(original)
		var remainder := opponent.deck.slice(count)
		opponent.deck.clear()
		opponent.deck.append_array(ordered)
		opponent.deck.append_array(remainder)


class AbilityRocketBrain extends BaseEffect:
	const SOURCE_STEP_ID := "rocket_damage_source"
	const TARGET_STEP_ID := "rocket_damage_target"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var player := state.players[pokemon.get_top_card().owner_index]
		return not _sources(player).is_empty() and player.get_all_pokemon().size() >= 2

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var player := state.players[card.owner_index]
		var sources := _sources(player)
		var targets := player.get_all_pokemon()
		var source_labels: Array[String] = []
		var target_labels: Array[String] = []
		for slot: PokemonSlot in sources:
			source_labels.append("%s (%d damage)" % [slot.get_pokemon_name(), slot.damage_counters])
		for slot: PokemonSlot in targets:
			target_labels.append(slot.get_pokemon_name())
		return [
			{"id": SOURCE_STEP_ID, "title": "Choose a damaged Team Rocket's Pokemon", "items": sources, "labels": source_labels, "min_select": 1, "max_select": 1, "allow_cancel": true},
			{"id": TARGET_STEP_ID, "title": "Choose another one of your Pokemon", "items": targets, "labels": target_labels, "exclude_selected_from_step_ids": [SOURCE_STEP_ID], "min_select": 1, "max_select": 1, "allow_cancel": true},
		]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var context := get_interaction_context(targets)
		var source := _selected_slot(context.get(SOURCE_STEP_ID, []), _sources(player))
		var target := _selected_slot(context.get(TARGET_STEP_ID, []), player.get_all_pokemon())
		if source == null or target == null or source == target or source.damage_counters < 10:
			return
		source.damage_counters -= 10
		target.damage_counters += 10

	func _sources(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.damage_counters >= 10 and CSV10CEffects.matches_named_pokemon(slot, TEAM_ROCKET_PREFIXES):
				result.append(slot)
		return result

	func _selected_slot(raw_items: Array, legal: Array) -> PokemonSlot:
		for raw: Variant in raw_items:
			if raw is PokemonSlot and raw in legal:
				return raw
		return null


class AttackForceOutThenDamage extends BaseEffect:
	const STEP_ID := "force_out_target"
	var damage_amount: int = 30
	var attack_index_to_match: int = 0

	func _init(damage: int = 30, match_attack_index: int = 0) -> void:
		damage_amount = maxi(0, damage)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, _attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var opponent := state.players[1 - card.owner_index]
		var labels: Array[String] = []
		for slot: PokemonSlot in opponent.bench:
			labels.append(slot.get_pokemon_name())
		return [{"id": STEP_ID, "title": "Choose 1 opposing Benched Pokemon to switch into the Active Spot", "items": opponent.bench.duplicate(), "labels": labels, "min_select": mini(1, opponent.bench.size()), "max_select": mini(1, opponent.bench.size()), "allow_cancel": false, "opponent_chooses": false}]

	func validate_attack_interaction(attacker: PokemonSlot, attack_index: int, targets: Array, state: GameState) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_ok()
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		if opponent.active_pokemon == null or opponent.bench.is_empty():
			return interaction_validation_ok()
		return validate_context_selection(get_interaction_context(targets), STEP_ID, opponent.bench, 1, 1)

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		if opponent.active_pokemon == null or opponent.bench.is_empty():
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, opponent.active_pokemon, state)):
				return
		var target: PokemonSlot = null
		for raw: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if raw is PokemonSlot and raw in opponent.bench:
				target = raw
				break
		if target == null:
			target = opponent.bench[0]
		var old_active := opponent.active_pokemon
		opponent.bench.erase(target)
		old_active.clear_on_leave_active()
		opponent.bench.append(old_active)
		opponent.active_pokemon = target
		target.mark_entered_active_from_bench(state.turn_number)
		var resolved_damage := _calculate_attack_target_damage(attacker, target, damage_amount, state)
		if resolved_damage <= 0:
			return
		DamageCalculator.new().apply_damage_to_slot(target, resolved_damage)
		if processor != null and processor.has_method("process_after_attack_damage"):
			processor.call("process_after_attack_damage", target, attacker, resolved_damage, state, [get_attack_interaction_context()])
		if processor != null and processor.has_method("record_effect_damage"):
			processor.call("record_effect_damage", attacker.get_top_card().owner_index, target, resolved_damage, state, "attack")


class AbilityRagePointDamageBoost extends BaseEffect:
	var required_damage: int = 20
	var bonus_damage: int = 120

	func _init(required: int = 20, bonus: int = 120) -> void:
		required_damage = maxi(0, required)
		bonus_damage = maxi(0, bonus)

	func get_attack_modifier_for_attacker(source: PokemonSlot, attacker: PokemonSlot, _state: GameState, _defender: PokemonSlot = null) -> int:
		return bonus_damage if source == attacker and attacker != null and attacker.damage_counters >= required_damage else 0
