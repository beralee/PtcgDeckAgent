class_name BattleReadyVfxEvaluator
extends RefCounted


const RULE_BUDEW_OPENING_ITEM_LOCK := "budew_opening_item_lock_ready"
const RULE_DRAGAPULT_PHANTOM_DIVE := "dragapult_phantom_dive_ready"
const RULE_LUGIA_DOUBLE_ARCHEOPS := "lugia_double_archeops_ready"
const RULE_IRON_HANDS_AMP := "iron_hands_amp_ready"
const RULE_TERAPAGOS_CAVERN_BOARD := "terapagos_cavern_board_ready"
const RULE_PALKIA_VSTAR_ACCELERATION := "palkia_vstar_acceleration_ready"
const RULE_GHOLDENGO_BIG_SWING := "gholdengo_big_swing_ready"
const RULE_CHARIZARD_INFERNAL_REIGN := "charizard_infernal_reign_ready"
const RULE_MIRAIDON_GENERATOR_LINE := "miraidon_generator_line_ready"
const RULE_REGIGIGAS_ANCIENT_WISDOM := "regigigas_ancient_wisdom_ready"
const RULE_RADIANT_GRENINJA_CONCEALED_CARDS := "radiant_greninja_concealed_cards_ready"
const RULE_CERULEDGE_DISCARD_ENERGY := "ceruledge_discard_energy_ready"
const RULE_ROARING_MOON_FRENZIED := "roaring_moon_frenzied_ready"
const RULE_ARCHALUDON_METAL_BRIDGE := "archaludon_metal_bridge_ready"

const BUDEW_UID := "CSV9.5C_004"
const DRAGAPULT_EX_UID := "CSV8C_159"
const LUGIA_VSTAR_UID := "CS6aC_103"
const ARCHEOPS_UID := "CS6aC_113"
const IRON_HANDS_EX_UID := "CSV6C_051"
const TERAPAGOS_EX_UID := "CSV9C_175"
const AREA_ZERO_UID := "CSV9C_207"
const AREA_ZERO_EFFECT_IDS := {
	"701eb0ccb34fe3d319ea1307bc36c1ef": true,
	"cf3124da3d7bf217f7969b6ae4e60e38": true,
}
const PALKIA_VSTAR_UID := "CS5bC_051"
const GHOLDENGO_EX_UID := "CSV4C_089"
const CHARIZARD_EX_UID := "CSV5C_075"
const MIRAIDON_EX_UID := "CSV1C_050"
const REGIGIGAS_ANCIENT_UID := "CS5.5C_056"
const RADIANT_GRENINJA_UID := "CS6.5C_020"
const CERULEDGE_EX_UID := "CSV9C_034"
const ROARING_MOON_EX_UID := "CSV6C_096"
const ARCHALUDON_EX_UID := "CSV9C_138"
const TANDEM_UNIT_USED_EFFECT_TYPE := "ability_search_pokemon_to_bench_used"
const TANDEM_UNIT_SUMMONED_EFFECT_TYPE := "ability_search_pokemon_to_bench_summoned"

const ENERGY_SYMBOLS := {
	"G": true,
	"R": true,
	"W": true,
	"L": true,
	"P": true,
	"F": true,
	"D": true,
	"M": true,
	"N": true,
	"C": true,
}

const REGI_NAMES := [
	"regirock",
	"regice",
	"registeel",
	"regieleki",
	"regidrago",
]


func find_ready_triggers(game_state: GameState) -> Array:
	var triggers: Array = []
	if game_state == null:
		return triggers
	if game_state.phase != GameState.GamePhase.MAIN:
		return triggers
	if game_state.current_player_index < 0 or game_state.current_player_index >= game_state.players.size():
		return triggers
	var player_index := game_state.current_player_index
	var player: PlayerState = game_state.players[player_index]
	if player == null:
		return triggers
	_append_budew_opening_trigger(game_state, player, player_index, triggers)
	_append_dragapult_phantom_dive_trigger(game_state, player, player_index, triggers)
	_append_lugia_double_archeops_trigger(game_state, player, player_index, triggers)
	_append_iron_hands_amp_trigger(game_state, player, player_index, triggers)
	_append_terapagos_cavern_board_trigger(game_state, player, player_index, triggers)
	_append_palkia_vstar_acceleration_trigger(game_state, player, player_index, triggers)
	_append_gholdengo_big_swing_trigger(game_state, player, player_index, triggers)
	_append_charizard_infernal_reign_trigger(game_state, player, player_index, triggers)
	_append_miraidon_generator_line_trigger(game_state, player, player_index, triggers)
	_append_regigigas_ancient_wisdom_trigger(game_state, player, player_index, triggers)
	_append_radiant_greninja_trigger(game_state, player, player_index, triggers)
	_append_ceruledge_discard_energy_trigger(game_state, player, player_index, triggers)
	_append_roaring_moon_frenzied_trigger(game_state, player, player_index, triggers)
	_append_archaludon_metal_bridge_trigger(game_state, player, player_index, triggers)
	return triggers


func _append_budew_opening_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	if game_state.turn_number > 2:
		return
	var active := player.active_pokemon
	if not _slot_matches_uid(active, BUDEW_UID):
		return
	triggers.append(_make_trigger(
		RULE_BUDEW_OPENING_ITEM_LOCK,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"opening_active_item_lock"
	))


func _append_dragapult_phantom_dive_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	var active := player.active_pokemon
	if not _slot_matches_uid(active, DRAGAPULT_EX_UID):
		return
	if not _slot_can_pay_cost(active, _attack_cost(active, 1, "RP")):
		return
	if not _opponent_has_bench_target(game_state, player_index):
		return
	triggers.append(_make_trigger(
		RULE_DRAGAPULT_PHANTOM_DIVE,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"phantom_dive_spread_ready"
	))


func _append_lugia_double_archeops_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	if _vstar_used(game_state, player_index):
		return
	if _count_cards_in_zone_by_uid(player.discard_pile, ARCHEOPS_UID) < 2:
		return
	if _bench_limit_for_player(game_state, player) - player.bench.size() < 2:
		return
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, LUGIA_VSTAR_UID):
			continue
		if slot.has_ability_used(game_state.turn_number):
			continue
		triggers.append(_make_trigger(
			RULE_LUGIA_DOUBLE_ARCHEOPS,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"double_archeops_vstar_ready"
		))
		return


func _append_iron_hands_amp_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, IRON_HANDS_EX_UID):
			continue
		if slot.get_total_energy_count() < 4:
			continue
		if not _slot_can_pay_cost(slot, _attack_cost(slot, 1, "LCCC")):
			continue
		triggers.append(_make_trigger(
			RULE_IRON_HANDS_AMP,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"amp_you_very_much_ready"
		))
		return


func _append_terapagos_cavern_board_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	var active := player.active_pokemon
	if not _slot_matches_uid(active, TERAPAGOS_EX_UID):
		return
	if not _is_area_zero_active(game_state):
		return
	if player.bench.size() < 6:
		return
	if not _slot_can_pay_cost(active, _attack_cost(active, 0, "CC")):
		return
	triggers.append(_make_trigger(
		RULE_TERAPAGOS_CAVERN_BOARD,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"area_zero_bench_damage_shell"
	))


func _append_palkia_vstar_acceleration_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	if _vstar_used(game_state, player_index):
		return
	if _count_energy_in_zone(player.discard_pile, "W") <= 0:
		return
	if not _player_has_energy_target(player, "W"):
		return
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, PALKIA_VSTAR_UID):
			continue
		if slot.has_ability_used(game_state.turn_number):
			continue
		triggers.append(_make_trigger(
			RULE_PALKIA_VSTAR_ACCELERATION,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"star_portal_water_ready"
		))
		return


func _append_gholdengo_big_swing_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	var active := player.active_pokemon
	if not _slot_matches_uid(active, GHOLDENGO_EX_UID):
		return
	if not _slot_can_pay_cost(active, _attack_cost(active, 0, "M")):
		return
	var opponent_active := _opponent_active(game_state, player_index)
	if opponent_active == null:
		return
	var needed := maxi(1, int(ceil(float(opponent_active.get_remaining_hp()) / 50.0)))
	if _count_energy_in_zone(player.hand, "") < needed:
		return
	triggers.append(_make_trigger(
		RULE_GHOLDENGO_BIG_SWING,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"make_it_rain_hand_energy_ready"
	))


func _append_charizard_infernal_reign_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, CHARIZARD_EX_UID):
			continue
		if slot.turn_evolved != game_state.turn_number:
			continue
		if not slot.rare_candy_evolved_this_turn(game_state.turn_number):
			continue
		if slot.get_total_energy_count() < 2:
			continue
		triggers.append(_make_trigger(
			RULE_CHARIZARD_INFERNAL_REIGN,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"rare_candy_two_energy_ready"
		))
		return


func _append_miraidon_generator_line_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	for ready_entry: Dictionary in _player_slot_entries(player):
		var ready_slot: PokemonSlot = ready_entry.get("slot", null)
		if not _slot_matches_uid(ready_slot, MIRAIDON_EX_UID):
			continue
		var source_instance_id := _tandem_unit_source_instance_id(ready_slot, game_state.turn_number)
		if source_instance_id < 0:
			continue
		if _count_tandem_unit_summoned_lightning_basics(player, game_state.turn_number, source_instance_id) < 2:
			continue
		triggers.append(_make_trigger(
			RULE_MIRAIDON_GENERATOR_LINE,
			player_index,
			str(ready_entry.get("slot_kind", "active")),
			int(ready_entry.get("slot_index", 0)),
			ready_slot,
			game_state.turn_number,
			"tandem_unit_two_lightning_basics_summoned"
		))
		return
	return
	if player.bench.size() >= _bench_limit_for_player(game_state, player):
		return
	var has_generator_line := _has_lightning_basic_in_deck(player) or (_player_has_trainer_named(player.hand, ["Electric Generator", "电气发生器"]) and _count_basic_energy_in_zone(player.deck, "L") >= 2)
	if not has_generator_line:
		return
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, MIRAIDON_EX_UID):
			continue
		if slot.has_ability_used(game_state.turn_number):
			continue
		triggers.append(_make_trigger(
			RULE_MIRAIDON_GENERATOR_LINE,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"tandem_unit_generator_route_ready"
		))
		return


func _append_regigigas_ancient_wisdom_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	if _count_energy_in_zone(player.discard_pile, "") <= 0:
		return
	if not _player_has_all_regi_parts(player):
		return
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, REGIGIGAS_ANCIENT_UID):
			continue
		if slot.has_ability_used(game_state.turn_number):
			continue
		triggers.append(_make_trigger(
			RULE_REGIGIGAS_ANCIENT_WISDOM,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"ancient_wisdom_regi_board_ready"
		))
		return


func _append_radiant_greninja_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, RADIANT_GRENINJA_UID):
			continue
		if not _slot_can_pay_cost(slot, _attack_cost(slot, 0, "WWC")):
			continue
		triggers.append(_make_trigger(
			RULE_RADIANT_GRENINJA_CONCEALED_CARDS,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"moonlight_shuriken_attack_ready"
		))
		return


func _append_ceruledge_discard_energy_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	var active := player.active_pokemon
	if not _slot_matches_uid(active, CERULEDGE_EX_UID):
		return
	if not _slot_can_pay_cost(active, _attack_cost(active, 0, "R")):
		return
	if _count_energy_in_zone(player.discard_pile, "") < 5:
		return
	triggers.append(_make_trigger(
		RULE_CERULEDGE_DISCARD_ENERGY,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"discard_energy_damage_ready"
	))


func _append_roaring_moon_frenzied_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	var active := player.active_pokemon
	if not _slot_matches_uid(active, ROARING_MOON_EX_UID):
		return
	if not _slot_can_pay_cost(active, _attack_cost(active, 0, "DDC")):
		return
	if _opponent_active(game_state, player_index) == null:
		return
	triggers.append(_make_trigger(
		RULE_ROARING_MOON_FRENZIED,
		player_index,
		"active",
		0,
		active,
		game_state.turn_number,
		"frenzied_gouging_ready"
	))


func _append_archaludon_metal_bridge_trigger(game_state: GameState, player: PlayerState, player_index: int, triggers: Array) -> void:
	for entry: Dictionary in _player_slot_entries(player):
		var slot: PokemonSlot = entry.get("slot", null)
		if not _slot_matches_uid(slot, ARCHALUDON_EX_UID):
			continue
		if slot.turn_evolved != game_state.turn_number:
			continue
		if not _slot_can_pay_cost(slot, _attack_cost(slot, 0, "MMM")):
			continue
		triggers.append(_make_trigger(
			RULE_ARCHALUDON_METAL_BRIDGE,
			player_index,
			str(entry.get("slot_kind", "active")),
			int(entry.get("slot_index", 0)),
			slot,
			game_state.turn_number,
			"evolved_this_turn_220_attack_ready"
		))
		return


func _make_trigger(
	rule_id: String,
	player_index: int,
	slot_kind: String,
	slot_index: int,
	slot: PokemonSlot,
	turn_number: int,
	reason: String
) -> Dictionary:
	var card := slot.get_top_card() if slot != null else null
	var card_data := card.card_data if card != null else null
	var card_uid := _card_uid(card_data)
	var card_instance_id := int(card.instance_id) if card != null else -1
	var key := "%s:p%d:%s%d:c%d:t%d" % [rule_id, player_index, slot_kind, slot_index, card_instance_id, turn_number]
	return {
		"rule_id": rule_id,
		"player_index": player_index,
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"card_uid": card_uid,
		"card_instance_id": card_instance_id,
		"turn_number": turn_number,
		"reason": reason,
		"ready_key": key,
	}


func _player_slot_entries(player: PlayerState) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if player == null:
		return entries
	if player.active_pokemon != null:
		entries.append({"slot": player.active_pokemon, "slot_kind": "active", "slot_index": 0})
	for bench_index: int in player.bench.size():
		entries.append({"slot": player.bench[bench_index], "slot_kind": "bench", "slot_index": bench_index})
	return entries


func _slot_matches_uid(slot: PokemonSlot, uid: String) -> bool:
	if slot == null:
		return false
	return _card_uid(slot.get_card_data()) == uid


func _card_uid(card_data: CardData) -> String:
	if card_data == null:
		return ""
	var set_code := String(card_data.set_code).strip_edges()
	var card_index := String(card_data.card_index).strip_edges()
	if set_code == "" or card_index == "":
		return ""
	return "%s_%s" % [set_code, card_index]


func _count_energy_in_zone(cards: Array, energy_type: String) -> int:
	var count := 0
	for card: CardInstance in cards:
		if card == null or card.card_data == null or not card.card_data.is_energy():
			continue
		if energy_type == "" or _card_provides_energy_type(card, energy_type):
			count += 1
	return count


func _count_basic_energy_in_zone(cards: Array, energy_type: String) -> int:
	var count := 0
	for card: CardInstance in cards:
		if card == null or card.card_data == null:
			continue
		if card.card_data.card_type != "Basic Energy":
			continue
		if energy_type == "" or _card_provides_energy_type(card, energy_type):
			count += 1
	return count


func _count_cards_in_zone_by_uid(cards: Array, uid: String) -> int:
	var count := 0
	for card: CardInstance in cards:
		if card != null and _card_uid(card.card_data) == uid:
			count += 1
	return count


func _card_provides_energy_type(card: CardInstance, energy_type: String) -> bool:
	if card == null or card.card_data == null:
		return false
	var provides := String(card.card_data.energy_provides).strip_edges().to_upper()
	if provides == "":
		provides = String(card.card_data.energy_type).strip_edges().to_upper()
	return energy_type == "" or provides == energy_type or energy_type in provides


func _attack_cost(slot: PokemonSlot, attack_index: int, fallback: String) -> String:
	if slot == null:
		return fallback
	var attacks := slot.get_attacks()
	if attack_index >= 0 and attack_index < attacks.size():
		var cost := str((attacks[attack_index] as Dictionary).get("cost", "")).strip_edges().to_upper()
		if cost != "":
			return cost
	return fallback


func _slot_can_pay_cost(slot: PokemonSlot, cost: String) -> bool:
	if slot == null:
		return false
	var available: Array[String] = []
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var provides := String(energy.card_data.energy_provides).strip_edges().to_upper()
		if provides == "":
			provides = String(energy.card_data.energy_type).strip_edges().to_upper()
		if provides == "":
			provides = "C"
		available.append(provides.substr(0, 1))
	var symbols := _cost_symbols(cost)
	for symbol: String in symbols:
		if symbol == "C":
			continue
		var found := available.find(symbol)
		if found < 0:
			return false
		available.remove_at(found)
	for symbol: String in symbols:
		if symbol != "C":
			continue
		if available.is_empty():
			return false
		available.pop_back()
	return true


func _cost_symbols(cost: String) -> Array[String]:
	var symbols: Array[String] = []
	var normalized := cost.strip_edges().to_upper()
	for index: int in normalized.length():
		var symbol := normalized.substr(index, 1)
		if ENERGY_SYMBOLS.has(symbol):
			symbols.append(symbol)
	return symbols


func _opponent_has_bench_target(game_state: GameState, player_index: int) -> bool:
	if game_state == null:
		return false
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return false
	return not game_state.players[opponent_index].bench.is_empty()


func _opponent_active(game_state: GameState, player_index: int) -> PokemonSlot:
	if game_state == null:
		return null
	var opponent_index := 1 - player_index
	if opponent_index < 0 or opponent_index >= game_state.players.size():
		return null
	return game_state.players[opponent_index].active_pokemon


func _is_area_zero_active(game_state: GameState) -> bool:
	if game_state == null or game_state.stadium_card == null or game_state.stadium_card.card_data == null:
		return false
	var uid := _card_uid(game_state.stadium_card.card_data)
	var effect_id := str(game_state.stadium_card.card_data.effect_id)
	return uid == AREA_ZERO_UID or AREA_ZERO_EFFECT_IDS.has(effect_id)


func _bench_limit_for_player(game_state: GameState, player: PlayerState) -> int:
	if not _is_area_zero_active(game_state):
		return 5
	return 8 if _player_has_tera(player) else 5


func _player_has_tera(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		var cd := slot.get_card_data()
		if cd == null:
			continue
		if cd.is_tera_pokemon() or cd.ancient_trait == "Tera" or cd.has_tag("Tera") or _slot_matches_uid(slot, TERAPAGOS_EX_UID):
			return true
	return false


func _vstar_used(game_state: GameState, player_index: int) -> bool:
	if game_state == null or player_index < 0 or player_index >= game_state.vstar_power_used.size():
		return true
	return bool(game_state.vstar_power_used[player_index])


func _player_has_energy_target(player: PlayerState, energy_type: String) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		var cd := slot.get_card_data()
		if cd == null:
			continue
		if energy_type == "" or cd.energy_type == energy_type or _attack_costs_include_type(cd, energy_type):
			return true
	return false


func _attack_costs_include_type(card_data: CardData, energy_type: String) -> bool:
	if card_data == null:
		return false
	for attack: Dictionary in card_data.attacks:
		if energy_type in _cost_symbols(str(attack.get("cost", ""))):
			return true
	return false


func _has_lightning_basic_in_deck(player: PlayerState) -> bool:
	if player == null:
		return false
	for card: CardInstance in player.deck:
		var cd := card.card_data if card != null else null
		if cd != null and cd.is_basic_pokemon() and cd.energy_type == "L":
			return true
	return false


func _tandem_unit_source_instance_id(slot: PokemonSlot, turn_number: int) -> int:
	if slot == null:
		return -1
	var top := slot.get_top_card()
	var fallback_id := int(top.instance_id) if top != null else -1
	for eff: Dictionary in slot.effects:
		if str(eff.get("type", "")) != TANDEM_UNIT_USED_EFFECT_TYPE:
			continue
		if int(eff.get("turn", -999)) != turn_number:
			continue
		return int(eff.get("source_instance_id", fallback_id))
	return -1


func _count_tandem_unit_summoned_lightning_basics(player: PlayerState, turn_number: int, source_instance_id: int) -> int:
	if player == null or source_instance_id < 0:
		return 0
	var count := 0
	for slot: PokemonSlot in player.bench:
		if slot == null or slot.turn_played != turn_number:
			continue
		if not _slot_has_source_effect(slot, TANDEM_UNIT_SUMMONED_EFFECT_TYPE, turn_number, source_instance_id):
			continue
		var cd := slot.get_card_data()
		if cd == null or not cd.is_basic_pokemon() or cd.energy_type != "L":
			continue
		count += 1
	return count


func _slot_has_source_effect(slot: PokemonSlot, effect_type: String, turn_number: int, source_instance_id: int) -> bool:
	if slot == null:
		return false
	for eff: Dictionary in slot.effects:
		if str(eff.get("type", "")) != effect_type:
			continue
		if int(eff.get("turn", -999)) != turn_number:
			continue
		if int(eff.get("source_instance_id", -1)) == source_instance_id:
			return true
	return false


func _player_has_trainer_named(cards: Array, names: Array[String]) -> bool:
	for card: CardInstance in cards:
		var cd := card.card_data if card != null else null
		if cd == null or not cd.is_trainer():
			continue
		var card_name := _normalized_card_name(cd)
		for wanted: String in names:
			if wanted.strip_edges().to_lower() in card_name:
				return true
	return false


func _player_has_all_regi_parts(player: PlayerState) -> bool:
	if player == null:
		return false
	var seen: Dictionary = {}
	for slot: PokemonSlot in player.get_all_pokemon():
		var name := _normalized_card_name(slot.get_card_data())
		for regi_name: String in REGI_NAMES:
			if regi_name in name:
				seen[regi_name] = true
	for regi_name: String in REGI_NAMES:
		if not seen.has(regi_name):
			return false
	return true


func _normalized_card_name(card_data: CardData) -> String:
	if card_data == null:
		return ""
	var names := [
		String(card_data.name),
		String(card_data.name_en),
		String(card_data.label),
	]
	return " ".join(names).strip_edges().to_lower()
