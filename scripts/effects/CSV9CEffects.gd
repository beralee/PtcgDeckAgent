class_name CSV9CEffects
extends RefCounted

const H = preload("res://scripts/effects/CSV9CHelpers.gd")
const BenchLimit = preload("res://scripts/engine/BenchLimitHelper.gd")
const AbilityBenchImmuneEffect = preload("res://scripts/effects/pokemon_effects/AbilityBenchImmune.gd")
const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const AttackCoinFlipPreventDamageAndEffectsNextTurnEffect = preload("res://scripts/effects/pokemon_effects/AttackCoinFlipPreventDamageAndEffectsNextTurn.gd")

const PREVENT_DAMAGE_EFFECT_TYPE := "csv9c_prevent_attack_damage"
const NO_WEAKNESS_EFFECT_TYPE := "csv9c_no_weakness_next_turn"
const OUTGOING_DAMAGE_REDUCTION_EFFECT_TYPE := "csv9c_outgoing_damage_reduction"
const ANGELITE_USED_PREFIX := "csv9c_angelite_used_p"
const BRIAR_USED_PREFIX := "csv9c_briar_used_p"
const FAN_CALL_USED_PREFIX := "csv9c_fan_call_used_p"
const LAST_ATTACK_TURN_PREFIX := "csv9c_last_attack_turn_p"
const LAST_ATTACK_SLOT_PREFIX := "csv9c_last_attack_slot_p"
const LAST_ATTACK_ANCIENT_PREFIX := "csv9c_last_attack_ancient_p"

const KNOWN_TERA_EFFECT_IDS := {
	"a533d02d029bd799e8c425beecd3ffaa": true,
	"cd845155473716c29f29efa29da0a869": true,
	"cfe54f4650db054ec2eec6dfcaaff88a": true,
	"317cdd81106733967d562ad538a7983a": true,
	"fa9e235782bba9bdb62005106bbdd6d9": true,
	"0f9c649bb3f59a7a342b53cdc78952a4": true,
	"1e48ba6c2140461745fc407bf34f5598": true,
	"92770a887520f6c4528cf57ae82392b3": true,
	"689549e631f4f93ecf618a215c628bd1": true,
	"27d1eb5f7abc237f462328c2ff00fdf3": true,
	"61fb0755be18f5fcdc6a30781d5fc05e": true,
	"62619a01b9dd1e1dec71d6f6557c9cb8": true,
	"c09bd406f26faeab1683244e53bab0b4": true,
	"5de19cbd4b2d1ff80ba14d6d89246ae9": true,
}

const KNOWN_ANCIENT_EFFECT_IDS := {
	"41dd160743c1707676c4faa6759c718b": true,
	"66377923675b93ec93a30c3411292d47": true,
}

const MILOTIC_CALMING_SHORE_EFFECT_ID := "88b2885578a73494f1eed7c2b53e67c7"
const MILOTIC_CALMING_SHORE_REMOTE_EFFECT_ID := "57aa4d41e927a2f1cdf846f73509b907"


static func owner_index_for_slot(slot: PokemonSlot, state: GameState) -> int:
	if slot == null or state == null:
		return -1
	for pi: int in state.players.size():
		if slot in state.players[pi].get_all_pokemon():
			return pi
	return -1


static func card_label(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	return card.card_data.name


static func slot_label(slot: PokemonSlot, state: GameState = null) -> String:
	return H.slot_label(slot, state)


static func is_basic_energy(card: CardInstance, energy_type: String = "") -> bool:
	if card == null or card.card_data == null:
		return false
	var cd: CardData = card.card_data
	if cd.card_type != "Basic Energy":
		return false
	return energy_type == "" or cd.energy_provides == energy_type or cd.energy_type == energy_type


static func basic_energy_type(card: CardInstance) -> String:
	if card == null or card.card_data == null:
		return ""
	if card.card_data.energy_provides != "":
		return card.card_data.energy_provides
	return card.card_data.energy_type


static func is_tera_card_data(cd: CardData) -> bool:
	if cd == null or not cd.is_pokemon():
		return false
	if cd.is_tera_pokemon():
		return true
	if KNOWN_TERA_EFFECT_IDS.has(cd.effect_id):
		return true
	for tag: String in cd.is_tags:
		var normalized := tag.to_lower()
		if normalized == "tera" or normalized == "terastal" or tag == "太晶":
			return true
	for attack: Dictionary in cd.attacks:
		var seen_types: Dictionary = {}
		for symbol: String in CardData.normalize_attack_cost(str(attack.get("cost", ""))):
			if symbol != "C":
				seen_types[symbol] = true
		if seen_types.size() >= 3:
			return true
	return false


static func is_tera_slot(slot: PokemonSlot) -> bool:
	return slot != null and is_tera_card_data(slot.get_card_data())


static func player_has_tera(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.get_all_pokemon():
		if is_tera_slot(slot):
			return true
	return false


static func has_tera_on_bench(player: PlayerState) -> bool:
	if player == null:
		return false
	for slot: PokemonSlot in player.bench:
		if is_tera_slot(slot):
			return true
	return false


static func is_ancient_card_data(cd: CardData) -> bool:
	if cd == null:
		return false
	return cd.is_ancient_pokemon() or KNOWN_ANCIENT_EFFECT_IDS.has(cd.effect_id)


static func is_basic_colorless_pokemon(slot: PokemonSlot) -> bool:
	if slot == null or slot.get_card_data() == null:
		return false
	var cd := slot.get_card_data()
	return cd.is_basic_pokemon() and cd.energy_type == "C"


static func player_field_return_to_hand_blocked(player_index: int, state: GameState) -> bool:
	return H.player_field_return_to_hand_blocked(player_index, state)


static func find_owner_slot(card: CardInstance, player: PlayerState) -> PokemonSlot:
	if card == null or player == null:
		return null
	for slot: PokemonSlot in player.get_all_pokemon():
		if slot != null and slot.get_top_card() == card:
			return slot
	return null


static func return_cards_to_deck(player: PlayerState, cards: Array[CardInstance], shuffle_after: bool = true) -> void:
	for card: CardInstance in cards:
		if card == null:
			continue
		card.face_up = false
		player.deck.append(card)
	if shuffle_after:
		player.shuffle_deck()


static func prevents_damage_from_attack_effect(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
	if attacker == null or defender == null or state == null:
		return false
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") != PREVENT_DAMAGE_EFFECT_TYPE:
			continue
		if int(effect.get("turn", -999)) != state.turn_number - 1:
			continue
		var mode := str(effect.get("mode", "basic"))
		var attacker_cd := attacker.get_card_data()
		if attacker_cd == null:
			continue
		match mode:
			"basic":
				if attacker_cd.is_basic_pokemon():
					return true
			"basic_non_colorless":
				if attacker_cd.is_basic_pokemon() and attacker_cd.energy_type != "C":
					return true
	return false


static func defender_has_no_weakness(defender: PokemonSlot, state: GameState) -> bool:
	if defender == null or state == null:
		return false
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") == NO_WEAKNESS_EFFECT_TYPE and int(effect.get("turn", -999)) == state.turn_number - 1:
			return true
	return false


static func record_attack_completed(attacker: PokemonSlot, state: GameState) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	var pi := attacker.get_top_card().owner_index
	var cd := attacker.get_card_data()
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_TURN_PREFIX, pi]] = state.turn_number
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_SLOT_PREFIX, pi]] = int(attacker.get_instance_id())
	state.shared_turn_flags["%s%d" % [LAST_ATTACK_ANCIENT_PREFIX, pi]] = is_ancient_card_data(cd)


static func previous_own_turn_different_ancient_attacked(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	if int(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_TURN_PREFIX, pi], -999)) != state.turn_number - 2:
		return false
	if not bool(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_ANCIENT_PREFIX, pi], false)):
		return false
	return int(state.shared_turn_flags.get("%s%d" % [LAST_ATTACK_SLOT_PREFIX, pi], -1)) != int(attacker.get_instance_id())


static func angelite_locked(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	return int(state.shared_turn_flags.get("%s%d" % [ANGELITE_USED_PREFIX, pi], -999)) == state.turn_number - 2


static func mark_angelite_used(attacker: PokemonSlot, state: GameState) -> void:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return
	state.shared_turn_flags["%s%d" % [ANGELITE_USED_PREFIX, attacker.get_top_card().owner_index]] = state.turn_number


static func briar_bonus_applies(attacker: PokemonSlot, state: GameState) -> bool:
	if attacker == null or attacker.get_top_card() == null or state == null:
		return false
	var pi := attacker.get_top_card().owner_index
	return int(state.shared_turn_flags.get("%s%d" % [BRIAR_USED_PREFIX, pi], -999)) == state.turn_number and is_tera_slot(attacker)


static func mark_briar_used(player_index: int, state: GameState) -> void:
	state.shared_turn_flags["%s%d" % [BRIAR_USED_PREFIX, player_index]] = state.turn_number


static func add_extra_prize_once(defender: PokemonSlot, source: String, count: int = 1) -> void:
	if defender == null or count <= 0:
		return
	for effect: Dictionary in defender.effects:
		if effect.get("type", "") == "extra_prize" and effect.get("source", "") == source:
			return
	defender.effects.append({
		"type": "extra_prize",
		"count": count,
		"source": source,
	})


class AttackEvolveFromDeck:
	extends BaseEffect

	const STEP_ID := "csv9c_evolution_card"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var attacker := H.find_owner_slot(card, player)
		if attacker == null:
			return []
		var items := _candidates(player, attacker)
		if items.is_empty():
			return []
		return [build_full_library_search_step(STEP_ID, "Choose an evolution card", player.deck, items, VISIBLE_SCOPE_OWN_FULL_DECK, 1, 1, {"allow_cancel": true})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if not applies_to_attack_index(attack_index) or attacker == null or attacker.get_top_card() == null:
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var items := _candidates(player, attacker)
		var chosen: CardInstance = null
		var ctx := get_attack_interaction_context()
		var selected: Array = ctx.get(STEP_ID, [])
		for entry: Variant in selected:
			if entry is CardInstance and entry in items:
				chosen = entry
				break
		if chosen == null and not items.is_empty() and not ctx.has(STEP_ID):
			chosen = items[0]
		if chosen == null:
			player.shuffle_deck()
			return
		player.deck.erase(chosen)
		chosen.face_up = true
		attacker.pokemon_stack.append(chosen)
		attacker.turn_evolved = state.turn_number
		attacker.clear_all_status()
		player.shuffle_deck()

	func _candidates(player: PlayerState, attacker: PokemonSlot) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		var top_name := attacker.get_pokemon_name()
		for card: CardInstance in player.deck:
			if card.card_data != null and card.card_data.is_pokemon() and card.card_data.evolves_from == top_name:
				result.append(card)
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackPreventDamageNextTurn:
	extends BaseEffect

	var mode: String = "basic"
	var attack_index_to_match: int = -1

	func _init(p_mode: String = "basic", match_attack_index: int = -1) -> void:
		mode = p_mode
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		attacker.effects.append({
			"type": H.PREVENT_DAMAGE_EFFECT_TYPE,
			"turn": state.turn_number,
			"mode": mode,
		})


class AttackTeraBenchBonusDamage:
	extends BaseEffect

	var bonus_damage: int = 100
	var attack_index_to_match: int = -1

	func _init(bonus: int = 100, match_attack_index: int = -1) -> void:
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null:
			return 0
		if not H.has_tera_on_bench(state.players[attacker.get_top_card().owner_index]):
			return 0
		return bonus_damage


class AttackDiscardPileEnergyBonus:
	extends BaseEffect

	var damage_per_energy: int = 20
	var attack_index_to_match: int = -1

	func _init(per_energy: int = 20, match_attack_index: int = -1) -> void:
		damage_per_energy = per_energy
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null:
			return 0
		var player := state.players[attacker.get_top_card().owner_index]
		var count := 0
		for card: CardInstance in player.discard_pile:
			if card != null and card.card_data != null and card.card_data.is_energy():
				count += 1
		return count * damage_per_energy


class AttackJoltikCharge:
	extends BaseEffect

	const STEP_ID := "csv9c_joltik_energy_assignments"
	const GRASS_STEP_ID := "csv9c_joltik_grass_assignments"
	const LIGHTNING_STEP_ID := "csv9c_joltik_lightning_assignments"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var targets := player.get_all_pokemon()
		var target_labels: Array[String] = []
		for slot: PokemonSlot in targets:
			target_labels.append(H.slot_label(slot, state))
		var steps: Array[Dictionary] = []
		var grass_sources := _candidate_energy(player, "G")
		if not grass_sources.is_empty():
			steps.append(build_full_library_card_assignment_step(
				GRASS_STEP_ID,
				"Attach Grass Energy",
				player.deck,
				grass_sources,
				_card_labels(grass_sources),
				targets,
				target_labels,
				0,
				mini(2, grass_sources.size()),
				VISIBLE_SCOPE_OWN_FULL_DECK,
				true
			))
		var lightning_sources := _candidate_energy(player, "L")
		if not lightning_sources.is_empty():
			steps.append(build_full_library_card_assignment_step(
				LIGHTNING_STEP_ID,
				"Attach Lightning Energy",
				player.deck,
				lightning_sources,
				_card_labels(lightning_sources),
				targets,
				target_labels,
				0,
				mini(2, lightning_sources.size()),
				VISIBLE_SCOPE_OWN_FULL_DECK,
				true
			))
		return steps

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var assignments := _resolve_assignments(player, attacker)
		for entry: Dictionary in assignments:
			var source: CardInstance = entry.get("source")
			var target: PokemonSlot = entry.get("target")
			if source == null or target == null or not (source in player.deck):
				continue
			player.deck.erase(source)
			source.face_up = true
			target.attached_energy.append(source)
		player.shuffle_deck()

	func _candidate_energy(player: PlayerState, only_type: String = "") -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if only_type == "":
				if H.is_basic_energy(card, "G") or H.is_basic_energy(card, "L"):
					result.append(card)
			elif H.is_basic_energy(card, only_type):
				result.append(card)
		return result

	func _card_labels(cards: Array[CardInstance]) -> Array[String]:
		var labels: Array[String] = []
		for card: CardInstance in cards:
			labels.append(H.card_label(card))
		return labels

	func _resolve_assignments(player: PlayerState, attacker: PokemonSlot) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var used_sources: Dictionary = {}
		var type_counts := {"G": 0, "L": 0}
		var targets := player.get_all_pokemon()
		var ctx := get_attack_interaction_context()
		var has_explicit := ctx.has(STEP_ID) or ctx.has(GRASS_STEP_ID) or ctx.has(LIGHTNING_STEP_ID)
		for step_id: String in [STEP_ID, GRASS_STEP_ID, LIGHTNING_STEP_ID]:
			for entry: Variant in ctx.get(step_id, []):
				if not (entry is Dictionary):
					continue
				var source: CardInstance = entry.get("source")
				var target: PokemonSlot = entry.get("target")
				var e_type := H.basic_energy_type(source)
				if source == null or target == null or used_sources.has(source.instance_id) or target not in targets:
					continue
				if not (e_type in type_counts) or int(type_counts[e_type]) >= 2:
					continue
				used_sources[source.instance_id] = true
				type_counts[e_type] = int(type_counts[e_type]) + 1
				result.append({"source": source, "target": target})
				if result.size() >= 4:
					break
		if not result.is_empty() or has_explicit:
			return result
		for source: CardInstance in _candidate_energy(player):
			var e_type := H.basic_energy_type(source)
			if int(type_counts.get(e_type, 0)) >= 2:
				continue
			type_counts[e_type] = int(type_counts.get(e_type, 0)) + 1
			result.append({"source": source, "target": attacker})
			if result.size() >= 4:
				break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackRecoverPokemonFromDiscard:
	extends BaseEffect

	const STEP_ID := "csv9c_recover_pokemon"
	var max_count: int = 1
	var attack_index_to_match: int = -1

	func _init(count: int = 1, match_attack_index: int = -1) -> void:
		max_count = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var items := _candidates(player)
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for c: CardInstance in items:
			labels.append(H.card_label(c))
		return [{"id": STEP_ID, "title": "Recover Pokemon from discard", "items": items, "labels": labels, "min_select": 0, "max_select": mini(max_count, items.size()), "allow_cancel": true}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var selected := _resolve_selected(player)
		for card: CardInstance in selected:
			player.discard_pile.erase(card)
			card.face_up = true
			player.hand.append(card)

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if card.card_data != null and card.card_data.is_pokemon():
				result.append(card)
		return result

	func _resolve_selected(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if entry is CardInstance and entry in player.discard_pile and entry.card_data.is_pokemon() and entry not in result:
				result.append(entry)
				if result.size() >= max_count:
					break
		if not result.is_empty() or has_explicit:
			return result
		var candidates := _candidates(player)
		if not candidates.is_empty():
			result.append(candidates[0])
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackSearchBasicEnergyToHand:
	extends BaseEffect

	const STEP_ID := "csv9c_basic_energy_to_hand"
	var max_count: int = 2
	var attack_index_to_match: int = -1

	func _init(count: int = 2, match_attack_index: int = -1) -> void:
		max_count = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var items := _candidates(player)
		if items.is_empty():
			return []
		return [build_full_library_search_step(STEP_ID, "Choose up to %d Basic Energy cards" % max_count, player.deck, items, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(max_count, items.size()), {"allow_cancel": true})]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var selected := _resolve_selected(player)
		for card: CardInstance in selected:
			player.deck.erase(card)
			card.face_up = true
			player.hand.append(card)
		player.shuffle_deck()

	func _candidates(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if H.is_basic_energy(card):
				result.append(card)
		return result

	func _resolve_selected(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if entry is CardInstance and entry in player.deck and H.is_basic_energy(entry) and entry not in result:
				result.append(entry)
				if result.size() >= max_count:
					break
		if not result.is_empty() or has_explicit:
			return result
		for card: CardInstance in _candidates(player):
			result.append(card)
			if result.size() >= max_count:
				break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackHealSelf:
	extends BaseEffect

	var heal_amount: int = 30
	var attack_index_to_match: int = -1

	func _init(amount: int = 30, match_attack_index: int = -1) -> void:
		heal_amount = amount
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, _state: GameState) -> void:
		if attacker != null and applies_to_attack_index(attack_index):
			attacker.damage_counters = maxi(0, attacker.damage_counters - heal_amount)


class AttackHealOwnPokemon:
	extends BaseEffect

	const STEP_ID := "csv9c_heal_target"
	var heal_amount: int = 30
	var attack_index_to_match: int = -1

	func _init(amount: int = 30, match_attack_index: int = -1) -> void:
		heal_amount = amount
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var items: Array = []
		var labels: Array[String] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.damage_counters > 0:
				items.append(slot)
				labels.append(H.slot_label(slot, state))
		if items.is_empty():
			return []
		return [{"id": STEP_ID, "title": "Choose a Pokemon to heal", "items": items, "labels": labels, "min_select": 0, "max_select": 1, "allow_cancel": true}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var target: PokemonSlot = null
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and raw[0] is PokemonSlot and raw[0] in player.get_all_pokemon():
			target = raw[0]
		if target == null:
			for slot: PokemonSlot in player.get_all_pokemon():
				if slot.damage_counters > 0:
					target = slot
					break
		if target != null:
			target.damage_counters = maxi(0, target.damage_counters - heal_amount)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackOpponentFieldSpecialEnergyDamage:
	extends BaseEffect

	var damage_per_energy: int = 40
	var printed_unit_damage: int = 40
	var attack_index_to_match: int = -1

	func _init(per_energy: int = 40, match_attack_index: int = -1) -> void:
		damage_per_energy = per_energy
		printed_unit_damage = per_energy
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null:
			return 0
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var count := 0
		for slot: PokemonSlot in opponent.get_all_pokemon():
			for energy: CardInstance in slot.attached_energy:
				if energy.card_data != null and energy.card_data.card_type == "Special Energy":
					count += 1
		return count * damage_per_energy - printed_unit_damage


class AttackPreviousAncientBonus:
	extends BaseEffect

	var bonus_damage: int = 150
	var attack_index_to_match: int = -1

	func _init(bonus: int = 150, match_attack_index: int = -1) -> void:
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return bonus_damage if H.previous_own_turn_different_ancient_attacked(attacker, state) else 0


class AttackBothActiveKnockout:
	extends BaseEffect

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if not applies_to_attack_index(attack_index):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if attacker != null:
			var attacker_max := attacker.get_max_hp()
			if processor != null and processor.has_method("get_effective_max_hp"):
				attacker_max = int(processor.call("get_effective_max_hp", attacker, state))
			attacker.damage_counters = maxi(attacker.damage_counters, attacker_max)
		if defender != null and not AttackCoinFlipPreventDamageAndEffectsNextTurnEffect.prevents_attack_effects(defender, state):
			var defender_max := defender.get_max_hp()
			if processor != null and processor.has_method("get_effective_max_hp"):
				defender_max = int(processor.call("get_effective_max_hp", defender, state))
			defender.damage_counters = maxi(defender.damage_counters, defender_max)


class AttackRuleBoxBonusDamage:
	extends BaseEffect

	var bonus_damage: int = 110
	var attack_index_to_match: int = -1

	func _init(bonus: int = 110, match_attack_index: int = -1) -> void:
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or state == null:
			return 0
		var pi := H.owner_index_for_slot(attacker, state)
		if pi < 0:
			return 0
		var defender := state.players[1 - pi].active_pokemon
		if defender == null or defender.get_card_data() == null:
			return 0
		var cd := defender.get_card_data()
		return bonus_damage if cd.mechanic in ["ex", "V", "VSTAR", "VMAX"] or cd.has_tag("V") else 0


class AttackBenchMultiDamage:
	extends BaseEffect

	const STEP_ID := "csv9c_bench_damage_targets"
	var damage_amount: int = 130
	var max_targets: int = 2
	var attack_index_to_match: int = -1

	func _init(amount: int = 130, count: int = 2, match_attack_index: int = -1) -> void:
		damage_amount = amount
		max_targets = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.bench.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in opponent.bench:
			labels.append(H.slot_label(slot, state))
		var count := mini(max_targets, opponent.bench.size())
		return [{"id": STEP_ID, "title": "Choose Benched targets", "items": opponent.bench.duplicate(), "labels": labels, "min_select": count, "max_select": count, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var selected := _selected_targets(opponent)
		for target: PokemonSlot in selected:
			if target == null:
				continue
			if AbilityBenchImmuneEffect.prevents_opponent_attack_damage(target, attacker, state):
				continue
			if AttackCoinFlipPreventDamageAndEffectsNextTurnEffect.prevents_attack_damage(target, state):
				continue
			if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
				continue
			H.apply_attack_damage_to_slot(attacker, target, state, damage_amount)

	func _selected_targets(opponent: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if entry is PokemonSlot and entry in opponent.bench and entry not in result:
				result.append(entry)
				if result.size() >= max_targets:
					break
		if not result.is_empty() or has_explicit:
			return result
		for slot: PokemonSlot in opponent.bench:
			result.append(slot)
			if result.size() >= max_targets:
				break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackPoisonAndRetreatLock:
	extends BaseEffect

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(_attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or not applies_to_attack_index(attack_index):
			return
		if H.prevents_attack_effects(defender, state):
			return
		_apply_special_status(defender, "poisoned", state)
		defender.effects.append({"type": "retreat_lock", "turn": state.turn_number})


class AttackReturnEnergyToHand:
	extends BaseEffect

	const STEP_ID := "csv9c_return_energy"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var attacker := H.find_owner_slot(card, player)
		if attacker == null or attacker.attached_energy.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in attacker.attached_energy:
			labels.append(H.card_label(energy))
		return [{"id": STEP_ID, "title": "Choose Energy to return", "items": attacker.attached_energy.duplicate(), "labels": labels, "min_select": 1, "max_select": 1, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		if attacker.attached_energy.is_empty():
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var chosen: CardInstance = null
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and raw[0] is CardInstance and raw[0] in attacker.attached_energy:
			chosen = raw[0]
		if chosen == null:
			chosen = attacker.attached_energy[0]
		attacker.attached_energy.erase(chosen)
		chosen.face_up = true
		player.hand.append(chosen)

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackNoWeaknessNextTurn:
	extends BaseEffect

	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker != null and applies_to_attack_index(attack_index):
			attacker.effects.append({"type": H.NO_WEAKNESS_EFFECT_TYPE, "turn": state.turn_number})


class AttackReduceDefenderOutgoingDamage:
	extends BaseEffect

	var reduce_amount: int = 100
	var attack_index_to_match: int = -1

	func _init(amount: int = 100, match_attack_index: int = -1) -> void:
		reduce_amount = amount
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func execute_attack(_attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or not applies_to_attack_index(attack_index):
			return
		if H.prevents_attack_effects(defender, state):
			return
		defender.effects.append({
			"type": H.OUTGOING_DAMAGE_REDUCTION_EFFECT_TYPE,
			"turn": state.turn_number,
			"amount": reduce_amount,
		})


class AttackStadiumRequired:
	extends BaseEffect

	var printed_damage: int = 70
	var attack_index_to_match: int = -1

	func _init(damage: int = 70, match_attack_index: int = -1) -> void:
		printed_damage = damage
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(_attacker: PokemonSlot, state: GameState) -> int:
		return 0 if state != null and state.stadium_card != null else -printed_damage


class AttackGholdengoEvolvedBonus:
	extends BaseEffect

	var bonus_damage: int = 90
	var attack_index_to_match: int = -1

	func _init(bonus: int = 90, match_attack_index: int = -1) -> void:
		bonus_damage = bonus
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or state == null:
			return 0
		if attacker.turn_evolved != state.turn_number or attacker.pokemon_stack.size() < 2:
			return 0
		var previous: CardInstance = attacker.pokemon_stack[attacker.pokemon_stack.size() - 2]
		if previous == null or previous.card_data == null:
			return 0
		var name := previous.card_data.name.to_lower()
		var name_en := previous.card_data.name_en.to_lower()
		return bonus_damage if previous.card_data.effect_id == "6c6c611ae3397c524ea28fec85c1f8b8" or name.contains("索财灵") or name_en.contains("gimmighoul") else 0


class AttackReturnSelfToDeck:
	extends BaseEffect

	const STEP_ID := "csv9c_return_self_replacement"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var attacker := H.find_owner_slot(card, player)
		if attacker == null or player.active_pokemon != attacker or player.bench.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in player.bench:
			labels.append(H.slot_label(slot, state))
		return [{"id": STEP_ID, "title": "Choose a new Active Pokemon", "items": player.bench.duplicate(), "labels": labels, "min_select": 1, "max_select": 1, "allow_cancel": true}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var replacement: PokemonSlot = null
		if player.active_pokemon == attacker:
			replacement = _resolve_replacement(player)
			if replacement == null:
				return
		var cards := attacker.collect_all_cards()
		attacker.pokemon_stack.clear()
		attacker.attached_energy.clear()
		attacker.attached_tool = null
		attacker.damage_counters = 0
		attacker.clear_all_status()
		if player.active_pokemon == attacker:
			player.active_pokemon = replacement
			player.bench.erase(replacement)
		else:
			player.bench.erase(attacker)
		H.return_cards_to_deck(player, cards, true)

	func _resolve_replacement(player: PlayerState) -> PokemonSlot:
		if get_attack_interaction_context().has(STEP_ID):
			var raw_explicit: Array = get_attack_interaction_context().get(STEP_ID, [])
			if raw_explicit.is_empty():
				return null
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and raw[0] is PokemonSlot and raw[0] in player.bench:
			return raw[0]
		return player.bench[0] if not player.bench.is_empty() else null

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackHandBasicEnergyAttach:
	extends BaseEffect

	const STEP_ID := "csv9c_hand_energy_assignments"
	var attack_index_to_match: int = -1

	func _init(match_attack_index: int = -1) -> void:
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var sources := _basic_energy_in_hand(player)
		if sources.is_empty():
			return []
		var source_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(H.card_label(energy))
		var targets := player.get_all_pokemon()
		var target_labels: Array[String] = []
		for slot: PokemonSlot in targets:
			target_labels.append(H.slot_label(slot, state))
		return [build_card_assignment_step(STEP_ID, "Attach Basic Energy from hand", sources, source_labels, targets, target_labels, 0, sources.size(), true)]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var assignments := _resolve_assignments(player, attacker)
		for entry: Dictionary in assignments:
			var source: CardInstance = entry.get("source")
			var target: PokemonSlot = entry.get("target")
			if source == null or target == null or not (source in player.hand):
				continue
			player.hand.erase(source)
			source.face_up = true
			target.attached_energy.append(source)

	func _basic_energy_in_hand(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.hand:
			if H.is_basic_energy(card):
				result.append(card)
		return result

	func _resolve_assignments(player: PlayerState, attacker: PokemonSlot) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var used: Dictionary = {}
		var targets := player.get_all_pokemon()
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if not (entry is Dictionary):
				continue
			var source: CardInstance = entry.get("source")
			var target: PokemonSlot = entry.get("target")
			if source == null or target == null or used.has(source.instance_id) or not H.is_basic_energy(source) or target not in targets:
				continue
			used[source.instance_id] = true
			result.append({"source": source, "target": target})
		if not result.is_empty() or has_explicit:
			return result
		for source: CardInstance in _basic_energy_in_hand(player):
			result.append({"source": source, "target": attacker})
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackBasicPokemonKnockoutCoin:
	extends BaseEffect

	const STEP_ID := "csv9c_basic_bench_ko_target"
	const RESULT_STEP_ID := "csv9c_basic_ko_coin_result"
	var attack_index_to_match: int = -1
	var coin_flipper: CoinFlipper = null
	var _pending_flip_heads: bool = false
	var _has_pending_flip: bool = false

	func _init(match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
		attack_index_to_match = match_attack_index
		coin_flipper = flipper

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_preview_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.active_pokemon != null and opponent.active_pokemon.get_card_data() != null and opponent.active_pokemon.get_card_data().is_basic_pokemon():
			return [_build_coin_result_step("投掷1次硬币，然后结算嗡嗡屑石。", "preview")]
		if not _basic_bench_targets(opponent).is_empty():
			return [_build_coin_result_step("投掷1次硬币。若为反面，选择对手备战区的1只基础宝可梦【昏厥】。", "preview")]
		return [_build_coin_result_step("投掷1次硬币。若为反面且对手备战区没有基础宝可梦，嗡嗡屑石会发动失败。", "preview")]

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
		_pending_flip_heads = flipper.flip()
		_has_pending_flip = true
		var opponent := state.players[1 - card.owner_index]
		if _pending_flip_heads:
			if opponent.active_pokemon != null and opponent.active_pokemon.get_card_data() != null and opponent.active_pokemon.get_card_data().is_basic_pokemon():
				return [_build_coin_result_step("投币结果：正面。对手战斗场的基础宝可梦将【昏厥】。", "heads")]
			return [_build_coin_result_step("投币结果：正面。对手战斗宝可梦不是基础宝可梦，嗡嗡屑石发动失败。", "heads")]
		var items := _basic_bench_targets(opponent)
		if items.is_empty():
			return [_build_coin_result_step("投币结果：反面。对手备战区没有基础宝可梦，嗡嗡屑石发动失败。", "tails")]
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(H.slot_label(slot, state))
		return [{
			"id": STEP_ID,
			"title": "投币结果：反面。选择对手备战区的1只基础宝可梦【昏厥】。",
			"items": items,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"wait_for_coin_animation": true,
		}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
		var context_result := _coin_result_from_context()
		var heads := context_result == "heads" if context_result != "" else _pending_flip_heads
		if context_result == "" and not _has_pending_flip:
			heads = flipper.flip()
		_has_pending_flip = false
		var target: PokemonSlot = null
		if heads:
			if defender != null and defender.get_card_data() != null and defender.get_card_data().is_basic_pokemon():
				target = defender
		else:
			target = _selected_basic_bench(state.players[1 - attacker.get_top_card().owner_index])
		if target == null:
			return
		if H.prevents_attack_effects(target, state):
			return
		if target != state.players[1 - attacker.get_top_card().owner_index].active_pokemon:
			if AbilityBenchImmuneEffect.prevents_opponent_attack_effect(target, attacker, state):
				return
		var max_hp := target.get_max_hp()
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("get_effective_max_hp"):
			max_hp = int(processor.call("get_effective_max_hp", target, state))
		target.damage_counters = maxi(target.damage_counters, max_hp)

	func _build_coin_result_step(title: String, result: String) -> Dictionary:
		return {
			"id": RESULT_STEP_ID,
			"title": title,
			"items": [result],
			"labels": ["继续"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"wait_for_coin_animation": true,
			"force_dialog": true,
		}

	func _basic_bench_targets(opponent: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in opponent.bench:
			if slot.get_card_data() != null and slot.get_card_data().is_basic_pokemon():
				result.append(slot)
		return result

	func _selected_basic_bench(opponent: PlayerState) -> PokemonSlot:
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty() and raw[0] is PokemonSlot and raw[0] in opponent.bench:
			var selected: PokemonSlot = raw[0]
			if selected.get_card_data() != null and selected.get_card_data().is_basic_pokemon():
				return selected
		var candidates := _basic_bench_targets(opponent)
		if not candidates.is_empty():
			return candidates[0]
		return null

	func _coin_result_from_context() -> String:
		var ctx := get_attack_interaction_context()
		var raw: Array = ctx.get(RESULT_STEP_ID, [])
		if not raw.is_empty():
			var result := str(raw[0])
			if result == "heads" or result == "tails":
				return result
		if ctx.has(STEP_ID):
			return "tails"
		return ""

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackReturnOpponentBenchToDeck:
	extends BaseEffect

	const STEP_ID := "csv9c_return_bench_to_deck"
	var max_targets: int = 2
	var attack_index_to_match: int = -1

	func _init(count: int = 2, match_attack_index: int = -1) -> void:
		max_targets = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if opponent.bench.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in opponent.bench:
			labels.append(H.slot_label(slot, state))
		var count := mini(max_targets, opponent.bench.size())
		return [{"id": STEP_ID, "title": "Choose Benched Pokemon to shuffle into deck", "items": opponent.bench.duplicate(), "labels": labels, "min_select": count, "max_select": count, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var selected := _selected_targets(opponent)
		var returned_count := 0
		for slot: PokemonSlot in selected:
			if slot == null or slot not in opponent.bench:
				continue
			if H.prevents_attack_effects(slot, state):
				continue
			if AbilityBenchImmuneEffect.prevents_opponent_attack_effect(slot, attacker, state):
				continue
			opponent.bench.erase(slot)
			H.return_cards_to_deck(opponent, slot.collect_all_cards(), false)
			returned_count += 1
		if returned_count > 0:
			opponent.shuffle_deck()
			H.mark_angelite_used(attacker, state)

	func _selected_targets(opponent: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if entry is PokemonSlot and entry in opponent.bench and entry not in result:
				result.append(entry)
				if result.size() >= max_targets:
					break
		if not result.is_empty() or has_explicit:
			return result
		for slot: PokemonSlot in opponent.bench:
			result.append(slot)
			if result.size() >= max_targets:
				break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackTriFrost:
	extends BaseEffect

	const STEP_ID := "csv9c_tri_frost_targets"
	var damage_amount: int = 110
	var max_targets: int = 3
	var attack_index_to_match: int = -1

	func _init(amount: int = 110, count: int = 3, match_attack_index: int = -1) -> void:
		damage_amount = amount
		max_targets = count
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		var items: Array = opponent.get_all_pokemon()
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(H.slot_label(slot, state))
		var count := mini(max_targets, items.size())
		return [{"id": STEP_ID, "title": "Choose up to 3 opposing Pokemon", "items": items, "labels": labels, "min_select": count, "max_select": count, "allow_cancel": false}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		var discarded := attacker.attached_energy.duplicate()
		attacker.attached_energy.clear()
		for energy: CardInstance in discarded:
			player.discard_pile.append(energy)
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		for target: PokemonSlot in _selected_targets(opponent):
			if target == null:
				continue
			if target != opponent.active_pokemon:
				if AbilityBenchImmuneEffect.prevents_opponent_attack_damage(target, attacker, state):
					continue
				if AttackCoinFlipPreventDamageAndEffectsNextTurnEffect.prevents_attack_damage(target, state):
					continue
				if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
					continue
				H.apply_attack_damage_to_slot(attacker, target, state, damage_amount)
			else:
				if AttackCoinFlipPreventDamageAndEffectsNextTurnEffect.prevents_attack_damage(target, state):
					continue
				if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
					continue
				DamageCalculator.new().apply_damage_to_slot(target, _calculate_attack_target_damage(attacker, target, damage_amount, state))

	func _selected_targets(opponent: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		var has_explicit := get_attack_interaction_context().has(STEP_ID)
		for entry: Variant in raw:
			if entry is PokemonSlot and entry in opponent.get_all_pokemon() and entry not in result:
				result.append(entry)
				if result.size() >= max_targets:
					break
		if not result.is_empty() or has_explicit:
			return result
		for slot: PokemonSlot in opponent.get_all_pokemon():
			result.append(slot)
			if result.size() >= max_targets:
				break
		return result

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AttackSlowkingInspiration:
	extends BaseEffect

	const STEP_ID := "csv9c_slowking_copied_attack"
	var attack_index_to_match: int = -1
	var processor: EffectProcessor = null

	func _init(match_attack_index: int = -1, p_processor: EffectProcessor = null) -> void:
		attack_index_to_match = match_attack_index
		processor = p_processor

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match == -1 or attack_index_to_match == attack_index

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		if player.deck.is_empty():
			return []
		var top_card: CardInstance = player.deck[0]
		if top_card == null or top_card.card_data == null or not top_card.card_data.is_pokemon() or top_card.card_data.is_rule_box_pokemon() or top_card.card_data.attacks.is_empty():
			return []
		var items: Array = []
		var labels: Array[String] = []
		var action_items: Array[Dictionary] = []
		for i: int in top_card.card_data.attacks.size():
			var copied_attack: Dictionary = top_card.card_data.attacks[i]
			if bool(copied_attack.get("is_vstar_power", false)):
				continue
			items.append({
				"source_card": top_card,
				"attack_index": i,
				"attack": copied_attack,
			})
			labels.append("%s - %s" % [top_card.card_data.name, str(copied_attack.get("name", "Attack %d" % [i + 1]))])
			action_items.append(_build_copied_attack_action_item(top_card.card_data, copied_attack, str(attack.get("cost", ""))))
		if items.is_empty():
			return []
		return [{
			"id": STEP_ID,
			"title": "选择翻开的宝可梦的1个招式",
			"items": items,
			"labels": labels,
			"presentation": "action_hud",
			"action_items": action_items,
			"pokemon_card": top_card,
			"pokemon_card_data": top_card.card_data,
			"card_items": [top_card],
			"card_click_selectable": false,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func get_followup_attack_interaction_steps(
		card: CardInstance,
		attack: Dictionary,
		state: GameState,
		resolved_context: Dictionary
	) -> Array[Dictionary]:
		if processor == null:
			return []
		if _has_resolved_copied_followup(resolved_context):
			return []
		var option := _get_selected_option_from_context(resolved_context)
		if option.is_empty():
			return []
		var source_card: Variant = option.get("source_card", null)
		if not (source_card is CardInstance):
			return []
		var source_instance: CardInstance = source_card
		if source_instance.card_data == null:
			return []
		var copied_index: int = int(option.get("attack_index", -1))
		if copied_index < 0 or copied_index >= source_instance.card_data.attacks.size():
			return []
		var copied_attack: Dictionary = option.get("attack", {})
		if copied_attack.is_empty():
			copied_attack = source_instance.card_data.attacks[copied_index]
		return processor.get_attack_interaction_steps_by_id(
			source_instance.card_data.effect_id,
			copied_index,
			card,
			copied_attack,
			state,
			AttackSlowkingInspiration
		)

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or attacker.get_top_card() == null or defender == null or not applies_to_attack_index(attack_index):
			return
		var player := state.players[attacker.get_top_card().owner_index]
		if player.deck.is_empty():
			return
		var top_card: CardInstance = player.deck.pop_front()
		top_card.face_up = true
		player.discard_pile.append(top_card)
		if top_card.card_data == null or not top_card.card_data.is_pokemon() or top_card.card_data.is_rule_box_pokemon() or top_card.card_data.attacks.is_empty():
			return
		var copied_index := _resolve_copied_attack_index(top_card.card_data)
		if copied_index < 0 or copied_index >= top_card.card_data.attacks.size():
			return
		var copied_attack: Dictionary = top_card.card_data.attacks[copied_index]
		var copied_damage := DamageCalculator.new().parse_damage(str(copied_attack.get("damage", "")))
		var proc: Variant = processor if processor != null else state.shared_turn_flags.get("_draw_effect_processor", null)
		var copied_targets: Array = [get_attack_interaction_context()]
		if proc != null and proc.has_method("get_attack_damage_bonus_by_id"):
			copied_damage += int(proc.call("get_attack_damage_bonus_by_id", top_card.card_data.effect_id, copied_index, attacker, state, copied_targets, AttackSlowkingInspiration))
		if copied_damage > 0:
			var ignore_weakness := false
			var ignore_resistance := false
			var ignore_defender_effects := false
			if proc != null:
				if proc.has_method("attack_effect_id_ignores_weakness"):
					ignore_weakness = bool(proc.call("attack_effect_id_ignores_weakness", top_card.card_data.effect_id, copied_index, attacker, state, copied_targets, AttackSlowkingInspiration))
				if proc.has_method("attack_effect_id_ignores_resistance"):
					ignore_resistance = bool(proc.call("attack_effect_id_ignores_resistance", top_card.card_data.effect_id, copied_index, attacker, state, copied_targets, AttackSlowkingInspiration))
				if proc.has_method("attack_effect_id_ignores_defender_effects"):
					ignore_defender_effects = bool(proc.call("attack_effect_id_ignores_defender_effects", top_card.card_data.effect_id, copied_index, attacker, state, copied_targets, AttackSlowkingInspiration))
			if not ignore_defender_effects and proc != null and proc.has_method("is_damage_prevented_by_defender_ability") and bool(proc.call("is_damage_prevented_by_defender_ability", attacker, defender, state)):
				return
			var attacker_modifier := 0
			var defender_modifier := 0
			var weakness_override := ""
			if proc != null:
				if proc.has_method("get_attacker_modifier"):
					attacker_modifier = int(proc.call("get_attacker_modifier", attacker, state, defender))
				if not ignore_defender_effects and proc.has_method("get_defender_modifier"):
					defender_modifier = int(proc.call("get_defender_modifier", defender, state, attacker))
				if proc.has_method("get_weakness_value_override"):
					weakness_override = str(proc.call("get_weakness_value_override", attacker, defender, state))
			var damage := DamageCalculator.new().calculate_damage(attacker, defender, {"damage": str(copied_damage)}, state, 0, attacker_modifier, defender_modifier, ignore_weakness, ignore_resistance, weakness_override)
			DamageCalculator.new().apply_damage_to_slot(defender, damage)
		if proc != null and proc.has_method("execute_attack_effect_by_id"):
			proc.call("execute_attack_effect_by_id", top_card.card_data.effect_id, copied_index, attacker, defender, state, copied_targets, AttackSlowkingInspiration)

	func _resolve_copied_attack_index(cd: CardData) -> int:
		var raw: Array = get_attack_interaction_context().get(STEP_ID, [])
		if not raw.is_empty():
			var entry: Variant = raw[0]
			if entry is Dictionary:
				var chosen_from_option := int((entry as Dictionary).get("attack_index", -1))
				if chosen_from_option >= 0 and chosen_from_option < cd.attacks.size():
					return chosen_from_option
			elif entry is int:
				var chosen: int = entry
				if chosen >= 0 and chosen < cd.attacks.size():
					return chosen
		return _best_attack_index(cd)

	func _get_selected_option_from_context(context: Dictionary) -> Dictionary:
		var raw: Array = context.get(STEP_ID, [])
		if raw.is_empty() or not (raw[0] is Dictionary):
			return {}
		return raw[0]

	func _has_resolved_copied_followup(context: Dictionary) -> bool:
		for key: Variant in context.keys():
			if str(key) != STEP_ID:
				return true
		return false

	func _build_copied_attack_action_item(source_data: CardData, copied_attack: Dictionary, attack_cost: String) -> Dictionary:
		var attack_name := str(copied_attack.get("name", ""))
		var damage_text := str(copied_attack.get("damage", "")).strip_edges()
		var meta := source_data.name
		if damage_text != "":
			meta = "%s  %s" % [source_data.name, damage_text]
		var body := str(copied_attack.get("text", "")).strip_edges()
		if body == "":
			body = "使用翻开的宝可梦所拥有的这个招式。"
		return {
			"type": "attack",
			"kind": "招式",
			"title": attack_name,
			"meta": meta,
			"body": body,
			"cost": attack_cost,
			"enabled": true,
			"reason": "",
		}

	func _best_attack_index(cd: CardData) -> int:
		var best_index := 0
		var best_damage := -1
		for i: int in cd.attacks.size():
			var damage := DamageCalculator.new().parse_damage(str(cd.attacks[i].get("damage", "")))
			if damage > best_damage:
				best_damage = damage
				best_index = i
		return best_index

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		for i: int in card.card_data.attacks.size():
			if card.card_data.attacks[i] == attack:
				return i
		return -1


class AbilityBenchMillOnPlay:
	extends BaseEffect

	const USED_KEY := "csv9c_bench_mill_used"

	func is_bench_enter_ability() -> bool:
		return true

	func is_optional_bench_enter_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var pi := pokemon.get_top_card().owner_index
		return state.current_player_index == pi and pokemon in state.players[pi].bench and pokemon.turn_played == state.turn_number and pokemon.entered_bench_from_hand_this_turn(state.turn_number) and not pokemon.has_ability_used(state.turn_number) and not state.players[1 - pi].deck.is_empty()

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var opponent := state.players[1 - pokemon.get_top_card().owner_index]
		if not opponent.deck.is_empty():
			var card: CardInstance = opponent.deck.pop_front()
			card.face_up = true
			opponent.discard_pile.append(card)
		pokemon.mark_ability_used(state.turn_number)


class AbilityBenchDiscardStadiumOnPlay:
	extends BaseEffect

	func is_bench_enter_ability() -> bool:
		return true

	func is_optional_bench_enter_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null or state.stadium_card == null:
			return false
		var pi := pokemon.get_top_card().owner_index
		return state.current_player_index == pi and pokemon in state.players[pi].bench and pokemon.turn_played == state.turn_number and pokemon.entered_bench_from_hand_this_turn(state.turn_number) and not pokemon.has_ability_used(state.turn_number)

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var stadium_owner := state.stadium_owner_index
		if stadium_owner >= 0 and stadium_owner < state.players.size():
			state.players[stadium_owner].discard_pile.append(state.stadium_card)
		state.stadium_card = null
		state.stadium_owner_index = -1
		pokemon.mark_ability_used(state.turn_number)


class AbilityAttachEnergyFromHandHeal:
	extends BaseEffect

	const STEP_ID := "csv9c_hand_energy_heal_assignment"
	var energy_type: String = "G"
	var heal_amount: int = 30

	func _init(e_type: String = "G", heal: int = 30) -> void:
		energy_type = e_type
		heal_amount = heal

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var pi := pokemon.get_top_card().owner_index
		if state.current_player_index != pi or pokemon.has_ability_used(state.turn_number):
			return false
		for card: CardInstance in state.players[pi].hand:
			if H.is_basic_energy(card, energy_type):
				return true
		return false

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var sources: Array = []
		var source_labels: Array[String] = []
		for hand_card: CardInstance in player.hand:
			if H.is_basic_energy(hand_card, energy_type):
				sources.append(hand_card)
				source_labels.append(H.card_label(hand_card))
		if sources.is_empty():
			return []
		var targets := player.get_all_pokemon()
		var target_labels: Array[String] = []
		for slot: PokemonSlot in targets:
			target_labels.append(H.slot_label(slot, state))
		return [build_card_assignment_step(STEP_ID, "Attach Energy and heal", sources, source_labels, targets, target_labels, 1, 1, true)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var pi := pokemon.get_top_card().owner_index
		var player := state.players[pi]
		var assignment := _resolve_assignment(player, pokemon, get_interaction_context(targets))
		var source: CardInstance = assignment.get("source")
		var target: PokemonSlot = assignment.get("target")
		if source == null or target == null:
			return
		player.hand.erase(source)
		source.face_up = true
		target.attached_energy.append(source)
		target.damage_counters = maxi(0, target.damage_counters - heal_amount)
		pokemon.mark_ability_used(state.turn_number)

	func _resolve_assignment(player: PlayerState, pokemon: PokemonSlot, ctx: Dictionary) -> Dictionary:
		var valid_targets := player.get_all_pokemon()
		for entry: Variant in ctx.get(STEP_ID, []):
			if not (entry is Dictionary):
				continue
			var source: CardInstance = entry.get("source")
			var target: PokemonSlot = entry.get("target")
			if source in player.hand and H.is_basic_energy(source, energy_type) and target in valid_targets:
				return {"source": source, "target": target}
		for hand_card: CardInstance in player.hand:
			if H.is_basic_energy(hand_card, energy_type):
				return {"source": hand_card, "target": pokemon}
		return {}


class AbilityFireEvolutionBoost:
	extends BaseEffect

	var bonus_damage: int = 10

	func _init(bonus: int = 10) -> void:
		bonus_damage = bonus

	func get_attack_modifier_for_attacker(source: PokemonSlot, attacker: PokemonSlot, _state: GameState, defender: PokemonSlot) -> int:
		if source == null or attacker == null or defender == null or attacker.get_card_data() == null:
			return 0
		if H.owner_index_for_slot(source, _state) != H.owner_index_for_slot(attacker, _state):
			return 0
		var cd := attacker.get_card_data()
		return bonus_damage if cd.energy_type == "R" and cd.is_evolution_pokemon() else 0


class AbilityPreventOpponentReturnToHand:
	extends BaseEffect

	func prevents_player_return_to_hand(source: PokemonSlot, player_index: int, _target: PokemonSlot, state: GameState) -> bool:
		return source != null and H.owner_index_for_slot(source, state) == 1 - player_index


class AbilitySurviveAtFullHP:
	extends BaseEffect

	func try_prevent_attack_knockout(defender: PokemonSlot, _attacker: PokemonSlot, state: GameState, previous_damage: int, processor: EffectProcessor) -> bool:
		if defender == null or state == null or processor == null:
			return false
		if previous_damage != 0:
			return false
		var max_hp := processor.get_effective_max_hp(defender, state)
		if defender.damage_counters < max_hp:
			return false
		defender.damage_counters = maxi(0, max_hp - 10)
		return true


class AbilityTogekissExtraPrize:
	extends BaseEffect

	var coin_flipper: CoinFlipper = null

	func _init(flipper: CoinFlipper = null) -> void:
		coin_flipper = flipper

	func try_add_attack_knockout_extra_prize(source: PokemonSlot, attacker: PokemonSlot, knocked_out: PokemonSlot, state: GameState) -> bool:
		if source == null or attacker == null or knocked_out == null or state == null:
			return false
		var source_owner := H.owner_index_for_slot(source, state)
		if source_owner < 0 or source_owner != H.owner_index_for_slot(attacker, state):
			return false
		if state.players[1 - source_owner].active_pokemon != knocked_out:
			return false
		var ko_key := "csv9c_togekiss_prize_flip_%d_%d_%d" % [state.turn_number, source_owner, int(knocked_out.get_instance_id())]
		if bool(state.shared_turn_flags.get(ko_key, false)):
			return false
		state.shared_turn_flags[ko_key] = true
		var flipper := coin_flipper if coin_flipper != null else CoinFlipper.new()
		if flipper.flip():
			H.add_extra_prize_once(knocked_out, "csv9c_togekiss", 1)
		return true


class AbilityBasicFreeRetreat:
	extends BaseEffect

	func get_retreat_cost_modifier_for_slot(source: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
		if source == null or target == null or state == null:
			return 0
		if H.owner_index_for_slot(source, state) != H.owner_index_for_slot(target, state):
			return 0
		return -99 if target.get_card_data() != null and target.get_card_data().is_basic_pokemon() else 0


class AbilityPoisonDamageBoostActive:
	extends BaseEffect

	var bonus_damage: int = 50

	func _init(bonus: int = 50) -> void:
		bonus_damage = bonus

	func get_poison_damage_bonus_for_target(source: PokemonSlot, _target: PokemonSlot, state: GameState) -> int:
		if source == null or source.get_top_card() == null:
			return 0
		var owner := source.get_top_card().owner_index
		return bonus_damage if state.players[owner].active_pokemon == source else 0


class AbilityBlockAceSpecIfTooled:
	extends BaseEffect

	func blocks_opponent_ace_spec(source: PokemonSlot, player_index: int, card: CardInstance, state: GameState) -> bool:
		if source == null or source.attached_tool == null or card == null or card.card_data == null:
			return false
		if not card.card_data.is_ace_spec():
			return false
		return H.owner_index_for_slot(source, state) == 1 - player_index


class AbilityEvolveAttachMetalFromDiscard:
	extends BaseEffect

	const STEP_ID := "csv9c_metal_discard_assignments"

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		if not H.evolved_from_hand_this_turn(pokemon, state) or pokemon.has_ability_used(state.turn_number):
			return false
		var player := state.players[pokemon.get_top_card().owner_index]
		return not _metal_energy(player).is_empty() and not _metal_targets(player).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var sources := _metal_energy(player)
		var targets := _metal_targets(player)
		if sources.is_empty() or targets.is_empty():
			return []
		var source_labels: Array[String] = []
		for energy: CardInstance in sources:
			source_labels.append(H.card_label(energy))
		var target_labels: Array[String] = []
		for slot: PokemonSlot in targets:
			target_labels.append(H.slot_label(slot, state))
		return [build_card_assignment_step(STEP_ID, "Attach Metal Energy from discard", sources, source_labels, targets, target_labels, 0, mini(2, sources.size()), true)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		for assignment: Dictionary in _resolve_assignments(player, pokemon, get_interaction_context(targets)):
			var source: CardInstance = assignment.get("source")
			var target: PokemonSlot = assignment.get("target")
			if source == null or target == null or source not in player.discard_pile:
				continue
			player.discard_pile.erase(source)
			source.face_up = true
			target.attached_energy.append(source)
		pokemon.mark_ability_used(state.turn_number)

	func _metal_energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.discard_pile:
			if H.is_basic_energy(card, "M"):
				result.append(card)
		return result

	func _metal_targets(player: PlayerState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.get_card_data() != null and slot.get_card_data().energy_type == "M":
				result.append(slot)
		return result

	func _resolve_assignments(player: PlayerState, pokemon: PokemonSlot, ctx: Dictionary) -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		var targets := _metal_targets(player)
		var used: Dictionary = {}
		var has_explicit := ctx.has(STEP_ID)
		for entry: Variant in ctx.get(STEP_ID, []):
			if not (entry is Dictionary):
				continue
			var source: CardInstance = entry.get("source")
			var target: PokemonSlot = entry.get("target")
			if source == null or target == null or used.has(source.instance_id) or target not in targets or not H.is_basic_energy(source, "M"):
				continue
			used[source.instance_id] = true
			result.append({"source": source, "target": target})
			if result.size() >= 2:
				break
		if not result.is_empty() or has_explicit:
			return result
		for source: CardInstance in _metal_energy(player):
			result.append({"source": source, "target": pokemon})
			if result.size() >= 2:
				break
		return result


class AbilityKyuremCostReduction:
	extends BaseEffect

	func is_cost_modifier_ability() -> bool:
		return true

	func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		if _resolve_attack_index(attacker, attack) != 0:
			return 0
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		for card: CardInstance in opponent.discard_pile:
			var name := H.card_label(card)
			if name.contains("阿克罗玛") or name.to_lower().contains("colress"):
				return -4
		return 0

	func _resolve_attack_index(attacker: PokemonSlot, attack: Dictionary) -> int:
		for i: int in attacker.get_card_data().attacks.size():
			if attacker.get_card_data().attacks[i] == attack:
				return i
		return -1


class AbilityEeveeEarlyEvolution:
	extends BaseEffect

	func allows_early_evolution(pokemon: PokemonSlot, player_index: int, state: GameState) -> bool:
		return pokemon != null and pokemon.get_top_card() != null and pokemon.get_top_card().owner_index == player_index and state.players[player_index].active_pokemon == pokemon


class AbilityNoctowlTeraTrainerSearch:
	extends BaseEffect

	const STEP_ID := "csv9c_noctowl_trainers"

	func is_evolve_triggered_ability() -> bool:
		return true

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		if not H.evolved_from_hand_this_turn(pokemon, state) or pokemon.has_ability_used(state.turn_number):
			return false
		var player := state.players[pokemon.get_top_card().owner_index]
		return H.player_has_tera(player) and not _trainers(player).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var items := _trainers(player)
		if items.is_empty():
			return []
		return [build_full_library_search_step(STEP_ID, "Choose up to 2 Trainer cards", player.deck, items, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(2, items.size()), {"allow_cancel": true})]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var selected := _resolve_selected(player, get_interaction_context(targets))
		_move_public_cards_to_hand_with_log(state, pokemon.get_top_card().owner_index, selected, pokemon.get_top_card(), "ability", "search_to_hand", ["Trainer"])
		player.shuffle_deck()
		pokemon.mark_ability_used(state.turn_number)

	func _trainers(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card.card_data != null and card.card_data.is_trainer():
				result.append(card)
		return result

	func _resolve_selected(player: PlayerState, ctx: Dictionary) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		var has_explicit := ctx.has(STEP_ID)
		for entry: Variant in ctx.get(STEP_ID, []):
			if entry is CardInstance and entry in player.deck and entry.card_data.is_trainer() and entry not in result:
				result.append(entry)
				if result.size() >= 2:
					break
		if not result.is_empty() or has_explicit:
			return result
		for card: CardInstance in _trainers(player):
			result.append(card)
			if result.size() >= 2:
				break
		return result


class AbilityFanCall:
	extends BaseEffect

	const STEP_ID := "csv9c_fan_call_cards"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var pi := pokemon.get_top_card().owner_index
		if state.current_player_index != pi or not state.is_first_turn_for_player(pi):
			return false
		if int(state.shared_turn_flags.get("%s%d" % [H.FAN_CALL_USED_PREFIX, pi], -999)) == state.turn_number:
			return false
		return not _targets(state.players[pi]).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var items := _targets(player)
		if items.is_empty():
			return []
		return [build_full_library_search_step(STEP_ID, "Choose up to 3 Colorless Pokemon", player.deck, items, VISIBLE_SCOPE_OWN_FULL_DECK, 0, mini(3, items.size()), {"allow_cancel": true})]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var pi := pokemon.get_top_card().owner_index
		var player := state.players[pi]
		var selected := _resolve_selected(player, get_interaction_context(targets))
		_move_public_cards_to_hand_with_log(state, pi, selected, pokemon.get_top_card(), "ability", "search_to_hand", ["Colorless Pokemon"])
		player.shuffle_deck()
		state.shared_turn_flags["%s%d" % [H.FAN_CALL_USED_PREFIX, pi]] = state.turn_number
		pokemon.mark_ability_used(state.turn_number)

	func _targets(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		for card: CardInstance in player.deck:
			if card.card_data != null and card.card_data.is_pokemon() and card.card_data.energy_type == "C" and card.card_data.hp <= 100:
				result.append(card)
		return result

	func _resolve_selected(player: PlayerState, ctx: Dictionary) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		var has_explicit := ctx.has(STEP_ID)
		for entry: Variant in ctx.get(STEP_ID, []):
			if entry is CardInstance and entry in player.deck and entry.card_data.energy_type == "C" and entry.card_data.hp <= 100 and entry not in result:
				result.append(entry)
				if result.size() >= 3:
					break
		if not result.is_empty() or has_explicit:
			return result
		for card: CardInstance in _targets(player):
			result.append(card)
			if result.size() >= 3:
				break
		return result


class AbilityBouffalantDefense:
	extends BaseEffect

	var reduction: int = -60

	func get_defense_modifier_for_defender(source: PokemonSlot, defender: PokemonSlot, state: GameState) -> int:
		if source == null or defender == null or state == null:
			return 0
		var pi := H.owner_index_for_slot(source, state)
		if pi < 0 or pi != H.owner_index_for_slot(defender, state):
			return 0
		if not H.is_basic_colorless_pokemon(defender):
			return 0
		var count := 0
		var first_source: PokemonSlot = null
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		for slot: PokemonSlot in state.players[pi].get_all_pokemon():
			if slot != null and slot.get_card_data() != null and slot.get_card_data().effect_id == source.get_card_data().effect_id:
				if processor != null and processor.has_method("is_ability_disabled") and bool(processor.call("is_ability_disabled", slot, state)):
					continue
				if first_source == null:
					first_source = slot
				count += 1
		return reduction if count >= 2 and first_source == source else 0
