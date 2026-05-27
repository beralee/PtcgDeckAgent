class_name CSV9CAdvancedEffects
extends RefCounted

const AdvancedHelpers := preload("res://scripts/effects/pokemon_effects/CSV9CAdvancedHelpers.gd")


class IronAntExSuddenShear extends AbilityOnBenchEnter:
	func _init() -> void:
		effect_type = "csv9c_iron_ant_sudden_shear"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		if state.current_player_index != top.owner_index:
			return false
		if pokemon.turn_played != state.turn_number:
			return false
		if not pokemon.entered_bench_from_hand_this_turn(state.turn_number):
			return false
		if not state.players[top.owner_index].bench.has(pokemon):
			return false
		for eff: Dictionary in pokemon.effects:
			if eff.get("type", "") == TRIGGERED_KEY and int(eff.get("turn", -1)) == state.turn_number:
				return false
		return not state.players[1 - top.owner_index].deck.is_empty()

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top: CardInstance = pokemon.get_top_card()
		var opponent: PlayerState = state.players[1 - top.owner_index]
		var milled: CardInstance = opponent.deck.pop_front()
		milled.face_up = true
		opponent.discard_pile.append(milled)
		pokemon.effects.append({"type": TRIGGERED_KEY, "turn": state.turn_number})


class ChienPaoBuryInSnow extends AbilityOnBenchEnter:
	func _init() -> void:
		effect_type = "csv9c_chien_pao_bury_in_snow"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		if state.current_player_index != top.owner_index:
			return false
		if pokemon.turn_played != state.turn_number:
			return false
		if not pokemon.entered_bench_from_hand_this_turn(state.turn_number):
			return false
		if not state.players[top.owner_index].bench.has(pokemon):
			return false
		if state.stadium_card == null:
			return false
		for eff: Dictionary in pokemon.effects:
			if eff.get("type", "") == TRIGGERED_KEY and int(eff.get("turn", -1)) == state.turn_number:
				return false
		return true

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, _targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var owner_index := state.stadium_owner_index
		if owner_index >= 0 and owner_index < state.players.size() and state.stadium_card != null:
			state.players[owner_index].discard_pile.append(state.stadium_card)
		state.stadium_card = null
		state.stadium_owner_index = -1
		pokemon.effects.append({"type": TRIGGERED_KEY, "turn": state.turn_number})


class ChienPaoIcicleLoop extends BaseEffect:
	const STEP_ID := "icicle_loop_attached_energy"
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var source := _find_source_slot(player, card)
		if source == null or source.attached_energy.is_empty():
			return []
		var labels: Array[String] = []
		for energy: CardInstance in source.attached_energy:
			labels.append(AdvancedHelpers.card_name(energy))
		return [{
			"id": STEP_ID,
			"title": "Choose 1 attached Energy to return to hand",
			"items": source.attached_energy.duplicate(),
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		if top == null or attacker.attached_energy.is_empty():
			return
		var energy := _selected_energy(attacker)
		if energy == null:
			return
		attacker.attached_energy.erase(energy)
		state.players[top.owner_index].hand.append(energy)

	func _selected_energy(attacker: PokemonSlot) -> CardInstance:
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if entry is CardInstance and entry in attacker.attached_energy:
				return entry
		return attacker.attached_energy[0] if not attacker.attached_energy.is_empty() else null

	func _find_source_slot(player: PlayerState, card: CardInstance) -> PokemonSlot:
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.get_top_card() == card:
				return slot
		return null


class HydrappleExRipeningCharge extends BaseEffect:
	const STEP_ID := "ripening_charge_assignments"
	const USED_FLAG := "csv9c_ripening_charge_used"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		if state.current_player_index != top.owner_index:
			return false
		for eff: Dictionary in pokemon.effects:
			if eff.get("type", "") == USED_FLAG and int(eff.get("turn", -1)) == state.turn_number:
				return false
		var player: PlayerState = state.players[top.owner_index]
		return not _grass_energy_from_hand(player).is_empty() and not player.get_all_pokemon().is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player: PlayerState = state.players[card.owner_index]
		var source_items: Array = _grass_energy_from_hand(player)
		var source_labels: Array[String] = []
		for energy: CardInstance in source_items:
			source_labels.append(AdvancedHelpers.card_name(energy))
		var target_items: Array = player.get_all_pokemon()
		var target_labels: Array[String] = []
		for slot: PokemonSlot in target_items:
			target_labels.append(AdvancedHelpers.slot_label(slot))
		if source_items.is_empty() or target_items.is_empty():
			return []
		return [build_card_assignment_step(
			STEP_ID,
			"选择1张手牌基本草能量并附着给己方宝可梦",
			source_items,
			source_labels,
			target_items,
			target_labels,
			1,
			1,
			true
		)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if not can_use_ability(pokemon, state):
			return
		var top: CardInstance = pokemon.get_top_card()
		var player: PlayerState = state.players[top.owner_index]
		var assignment := _resolve_first_assignment(player, get_interaction_context(targets))
		if assignment.is_empty():
			return
		var energy: CardInstance = assignment.get("source", null)
		var target: PokemonSlot = assignment.get("target", null)
		if energy == null or target == null:
			return
		player.hand.erase(energy)
		target.attached_energy.append(energy)
		target.damage_counters = maxi(0, target.damage_counters - 30)
		pokemon.effects.append({"type": USED_FLAG, "turn": state.turn_number})

	func _resolve_first_assignment(player: PlayerState, ctx: Dictionary) -> Dictionary:
		for entry: Variant in ctx.get(STEP_ID, []):
			if not (entry is Dictionary):
				continue
			var assignment: Dictionary = entry
			var source: Variant = assignment.get("source", null)
			var target: Variant = assignment.get("target", null)
			if source is CardInstance and target is PokemonSlot:
				var energy: CardInstance = source
				var slot: PokemonSlot = target
				if energy in _grass_energy_from_hand(player) and slot in player.get_all_pokemon():
					return {"source": energy, "target": slot}
		var energies := _grass_energy_from_hand(player)
		var slots := player.get_all_pokemon()
		if energies.is_empty() or slots.is_empty():
			return {}
		return {"source": energies[0], "target": slots[0]}

	func _grass_energy_from_hand(player: PlayerState) -> Array:
		var result: Array = []
		for card: CardInstance in player.hand:
			if AdvancedHelpers.is_basic_energy(card, "G"):
				result.append(card)
		return result


class ConditionalFireEvolutionDamageBoost extends BaseEffect:
	func get_attack_modifier_for_source(source: PokemonSlot, attacker: PokemonSlot, _state: GameState) -> int:
		if source == null or attacker == null or source.get_top_card() == null or attacker.get_card_data() == null:
			return 0
		if source.get_top_card().owner_index != attacker.get_top_card().owner_index:
			return 0
		var cd: CardData = attacker.get_card_data()
		return 10 if cd.energy_type == "R" and cd.is_evolution_pokemon() else 0


class MiloticCalmingShore extends BaseEffect:
	func prevents_opponent_field_cards_return_to_hand(source: PokemonSlot, acting_player_index: int, state: GameState) -> bool:
		if source == null or source.get_top_card() == null or state == null:
			return false
		var owner := source.get_top_card().owner_index
		return acting_player_index == 1 - owner


class PikachuExTenaciousHeart extends BaseEffect:
	func try_prevent_attack_knockout(
		defender: PokemonSlot,
		_attacker: PokemonSlot,
		state: GameState,
		previous_damage: int,
		processor = null
	) -> bool:
		if defender == null or state == null:
			return false
		var max_hp := AdvancedHelpers.effective_max_hp(defender, state, processor)
		if max_hp <= 0 or previous_damage != 0:
			return false
		if defender.damage_counters < max_hp:
			return false
		defender.damage_counters = maxi(0, max_hp - 10)
		return true


class LatiasExSkyline extends BaseEffect:
	func get_retreat_cost_modifier_for_slot(source: PokemonSlot, slot: PokemonSlot, _state: GameState) -> int:
		if source == null or slot == null or source.get_top_card() == null or slot.get_card_data() == null:
			return 0
		if source.get_top_card().owner_index != slot.get_top_card().owner_index:
			return 0
		return -999 if slot.get_card_data().stage == "Basic" else 0


class TogekissMiracleKiss extends BaseEffect:
	var coin_flipper: CoinFlipper

	func _init(flipper: CoinFlipper = null) -> void:
		coin_flipper = flipper if flipper != null else CoinFlipper.new()

	func get_extra_prize_for_active_knockout(source: PokemonSlot, knocked_out: PokemonSlot, state: GameState) -> int:
		if source == null or knocked_out == null or state == null or source.get_top_card() == null:
			return 0
		var owner := source.get_top_card().owner_index
		if knocked_out != state.players[1 - owner].active_pokemon:
			return 0
		return 1 if coin_flipper.flip() else 0


class SylveonExMagicalCharm extends BaseEffect:
	const EFFECT_TYPE := "csv9c_magical_charm_outgoing_reduction"
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func execute_attack(_attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if defender == null or not applies_to_attack_index(attack_index):
			return
		defender.effects.append({
			"type": EFFECT_TYPE,
			"amount": -100,
			"turn": state.turn_number,
		})

	static func get_outgoing_damage_modifier(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or state == null:
			return 0
		var total := 0
		for eff: Dictionary in attacker.effects:
			if eff.get("type", "") == EFFECT_TYPE and int(eff.get("turn", -999)) == state.turn_number - 1:
				total += int(eff.get("amount", 0))
		return total


class SylveonExAngelite extends BaseEffect:
	const STEP_ID := "angelite_bench_targets"
	const USED_FLAG_PREFIX := "csv9c_angelite_used_by_player_"
	var attack_index_to_match: int = 1

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func can_use_angelite(player_index: int, state: GameState) -> bool:
		return int(state.shared_turn_flags.get("%s%d" % [USED_FLAG_PREFIX, player_index], -999)) != state.turn_number - 2

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		var opponent: PlayerState = state.players[1 - card.owner_index]
		if opponent.bench.is_empty():
			return []
		var items: Array = opponent.bench.duplicate()
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(AdvancedHelpers.slot_label(slot))
		var count := mini(2, items.size())
		return [{
			"id": STEP_ID,
			"title": "选择对手的%d只备战宝可梦洗回牌库" % count,
			"items": items,
			"labels": labels,
			"min_select": count,
			"max_select": count,
			"allow_cancel": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var top: CardInstance = attacker.get_top_card()
		if top == null:
			return
		var opponent: PlayerState = state.players[1 - top.owner_index]
		var chosen := _selected_slots(opponent, 2)
		for slot: PokemonSlot in chosen:
			AdvancedHelpers.return_slot_to_deck(slot, opponent)
		if not chosen.is_empty():
			opponent.shuffle_deck()
		state.shared_turn_flags["%s%d" % [USED_FLAG_PREFIX, top.owner_index]] = state.turn_number

	func _selected_slots(opponent: PlayerState, limit: int) -> Array:
		var result: Array = []
		var ctx := get_attack_interaction_context()
		for entry: Variant in ctx.get(STEP_ID, []):
			if entry is PokemonSlot and entry in opponent.bench and entry not in result:
				result.append(entry)
				if result.size() >= limit:
					return result
		for slot: PokemonSlot in opponent.bench:
			if slot not in result:
				result.append(slot)
				if result.size() >= limit:
					break
		return result


class AnnihilapeDestinedFight extends BaseEffect:
	var attack_index_to_match: int = 1

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if not applies_to_attack_index(attack_index):
			return
		AdvancedHelpers.knock_out_slot(attacker, state)
		AdvancedHelpers.knock_out_slot(defender, state)


class PecharuntToxicSubjugation extends BaseEffect:
	const POISON_BONUS := 50

	func get_poison_damage_bonus_for_target(source: PokemonSlot, target: PokemonSlot, state: GameState) -> int:
		if source == null or target == null or state == null or source.get_top_card() == null:
			return 0
		var owner := source.get_top_card().owner_index
		if state.players[owner].active_pokemon != source:
			return 0
		return POISON_BONUS if state.players[1 - owner].active_pokemon == target else 0


class GenesectAceCanceller extends BaseEffect:
	func blocks_card_from_hand(source: PokemonSlot, card: CardInstance, player_index: int, state: GameState) -> bool:
		if source == null or card == null or card.card_data == null or state == null:
			return false
		var top := source.get_top_card()
		if top == null or source.attached_tool == null:
			return false
		if player_index != 1 - top.owner_index:
			return false
		return card.card_data.is_ace_spec()


class ArchaludonExAlloyBuild extends BaseEffect:
	const STEP_ID := "alloy_build_assignments"
	const USED_FLAG := "csv9c_alloy_build_used"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top: CardInstance = pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		if state.current_player_index != top.owner_index:
			return false
		if pokemon.turn_evolved != state.turn_number:
			return false
		for eff: Dictionary in pokemon.effects:
			if eff.get("type", "") == USED_FLAG and int(eff.get("turn", -1)) == state.turn_number:
				return false
		var player := state.players[top.owner_index]
		return not _metal_energy_from_discard(player).is_empty() and not _metal_targets(player).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var source_items := _metal_energy_from_discard(player)
		var target_items := _metal_targets(player)
		if source_items.is_empty() or target_items.is_empty():
			return []
		var source_labels: Array[String] = []
		for energy: CardInstance in source_items:
			source_labels.append(AdvancedHelpers.card_name(energy))
		var target_labels: Array[String] = []
		for slot: PokemonSlot in target_items:
			target_labels.append(AdvancedHelpers.slot_label(slot))
		var max_count := mini(2, source_items.size())
		return [build_card_assignment_step(
			STEP_ID,
			"选择最多2张弃牌区基本钢能量并分配给己方钢宝可梦",
			source_items,
			source_labels,
			target_items,
			target_labels,
			0,
			max_count,
			true
		)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if pokemon == null or pokemon.get_top_card() == null:
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var assignments := _resolve_assignments(player, get_interaction_context(targets), 2)
		if assignments.is_empty() and not get_interaction_context(targets).has(STEP_ID):
			return
		for assignment: Dictionary in assignments:
			var energy: CardInstance = assignment.get("source", null)
			var target: PokemonSlot = assignment.get("target", null)
			if energy == null or target == null:
				continue
			player.discard_pile.erase(energy)
			target.attached_energy.append(energy)
		pokemon.effects.append({"type": USED_FLAG, "turn": state.turn_number})

	func _resolve_assignments(player: PlayerState, ctx: Dictionary, limit: int) -> Array:
		var result: Array = []
		var used: Array = []
		for entry: Variant in ctx.get(STEP_ID, []):
			if result.size() >= limit or not (entry is Dictionary):
				continue
			var source: Variant = entry.get("source", null)
			var target: Variant = entry.get("target", null)
			if source is CardInstance and target is PokemonSlot:
				var energy: CardInstance = source
				var slot: PokemonSlot = target
				if energy in _metal_energy_from_discard(player) and slot in _metal_targets(player) and energy not in used:
					result.append({"source": energy, "target": slot})
					used.append(energy)
		return result

	func _metal_energy_from_discard(player: PlayerState) -> Array:
		var result: Array = []
		for card: CardInstance in player.discard_pile:
			if AdvancedHelpers.is_basic_energy(card, "M"):
				result.append(card)
		return result

	func _metal_targets(player: PlayerState) -> Array:
		var result: Array = []
		for slot: PokemonSlot in player.get_all_pokemon():
			if slot.get_card_data() != null and slot.get_card_data().energy_type == "M":
				result.append(slot)
		return result


class ArchaludonExMetalDefender extends BaseEffect:
	const EFFECT_TYPE := "csv9c_metal_defender_no_weakness"
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		attacker.effects.append({"type": EFFECT_TYPE, "turn": state.turn_number})

	func ignores_weakness_when_defending(defender: PokemonSlot, state: GameState) -> bool:
		if defender == null or state == null:
			return false
		for eff: Dictionary in defender.effects:
			if eff.get("type", "") == EFFECT_TYPE and int(eff.get("turn", -999)) == state.turn_number - 1:
				return true
		return false


class GholdengoRichStrike extends BaseEffect:
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		if attacker == null or state == null or attacker.turn_evolved != state.turn_number:
			return 0
		if attacker.pokemon_stack.size() < 2:
			return 0
		var previous: CardInstance = attacker.pokemon_stack[attacker.pokemon_stack.size() - 2]
		if previous == null or previous.card_data == null:
			return 0
		var previous_name := previous.card_data.name
		var previous_en := previous.card_data.name_en
		return 90 if previous_name == "索财灵" or previous_en == "Gimmighoul" else 0


class GholdengoSurfingTurn extends BaseEffect:
	const STEP_ID := "surfing_turn_choice"
	var attack_index_to_match: int = 1

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, _state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		return [{
			"id": STEP_ID,
			"title": "是否将这只宝可梦和附属卡洗回自己的牌库",
			"items": ["no", "yes"],
			"labels": ["不放回", "放回牌库"],
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var ctx := get_attack_interaction_context()
		var selected: Array = ctx.get(STEP_ID, [])
		if selected.is_empty() or str(selected[0]) != "yes":
			return
		var top := attacker.get_top_card()
		if top == null:
			return
		var player := state.players[top.owner_index]
		AdvancedHelpers.return_slot_to_deck(attacker, player)
		player.shuffle_deck()


class AlolanExeggutorExTropicalFrenzy extends BaseEffect:
	const STEP_ID := "tropical_frenzy_assignments"
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		var player := state.players[card.owner_index]
		var source_items := _basic_energy_from_hand(player)
		if source_items.is_empty():
			return []
		var target_items := player.get_all_pokemon()
		var source_labels: Array[String] = []
		for energy: CardInstance in source_items:
			source_labels.append(AdvancedHelpers.card_name(energy))
		var target_labels: Array[String] = []
		for slot: PokemonSlot in target_items:
			target_labels.append(AdvancedHelpers.slot_label(slot))
		return [build_card_assignment_step(
			STEP_ID,
			"选择任意数量手牌基本能量并分配给己方宝可梦",
			source_items,
			source_labels,
			target_items,
			target_labels,
			0,
			source_items.size(),
			true
		)]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		if top == null:
			return
		var player := state.players[top.owner_index]
		var used: Array = []
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if not (entry is Dictionary):
				continue
			var source: Variant = entry.get("source", null)
			var target: Variant = entry.get("target", null)
			if source is CardInstance and target is PokemonSlot:
				var energy: CardInstance = source
				var slot: PokemonSlot = target
				if energy in _basic_energy_from_hand(player) and slot in player.get_all_pokemon() and energy not in used:
					player.hand.erase(energy)
					slot.attached_energy.append(energy)
					used.append(energy)

	func _basic_energy_from_hand(player: PlayerState) -> Array:
		var result: Array = []
		for card: CardInstance in player.hand:
			if card.card_data != null and card.card_data.card_type == "Basic Energy":
				result.append(card)
		return result


class AlolanExeggutorExSwingingSphene extends BaseEffect:
	const STEP_ID := "swinging_sphene_bench_basic"
	const RESULT_STEP_ID := "swinging_sphene_coin_result"
	var attack_index_to_match: int = 1
	var coin_flipper: CoinFlipper
	var _pending_flip_heads: bool = false
	var _has_pending_flip: bool = false

	func _init(flipper: CoinFlipper = null) -> void:
		coin_flipper = flipper if flipper != null else CoinFlipper.new()

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_preview_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		if AdvancedHelpers.is_basic_pokemon_slot(opponent.active_pokemon):
			return [_build_coin_result_step("投掷1次硬币，然后结算嗡嗡屑石。", "preview")]
		if not _basic_bench_targets(opponent).is_empty():
			return [_build_coin_result_step("投掷1次硬币。若为反面，选择对手备战区的1只基础宝可梦【昏厥】。", "preview")]
		return [_build_coin_result_step("投掷1次硬币。若为反面且对手备战区没有基础宝可梦，嗡嗡屑石会发动失败。", "preview")]

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		_pending_flip_heads = coin_flipper.flip()
		_has_pending_flip = true
		var resolved_opponent := state.players[1 - card.owner_index]
		if _pending_flip_heads:
			if AdvancedHelpers.is_basic_pokemon_slot(resolved_opponent.active_pokemon):
				return [_build_coin_result_step("投币结果：正面。对手战斗场的基础宝可梦将【昏厥】。", "heads")]
			return [_build_coin_result_step("投币结果：正面。对手战斗宝可梦不是基础宝可梦，嗡嗡屑石发动失败。", "heads")]
		var resolved_items := _basic_bench_targets(resolved_opponent)
		if resolved_items.is_empty():
			return [_build_coin_result_step("投币结果：反面。对手备战区没有基础宝可梦，嗡嗡屑石发动失败。", "tails")]
		var resolved_labels: Array[String] = []
		for resolved_slot: PokemonSlot in resolved_items:
			resolved_labels.append(AdvancedHelpers.slot_label(resolved_slot))
		return [{
			"id": STEP_ID,
			"title": "投币结果：反面。选择对手备战区的1只基础宝可梦【昏厥】。",
			"items": resolved_items,
			"labels": resolved_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
			"wait_for_coin_animation": true,
		}]
		var opponent := state.players[1 - card.owner_index]
		var items: Array = []
		var labels: Array[String] = []
		for slot: PokemonSlot in opponent.bench:
			if AdvancedHelpers.is_basic_pokemon_slot(slot):
				items.append(slot)
				labels.append(AdvancedHelpers.slot_label(slot))
		if items.is_empty():
			return []
		return [{
			"id": STEP_ID,
			"title": "若投币为反面，选择对手备战区1只基础宝可梦昏厥",
			"items": items,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": true,
		}]

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		if top == null:
			return
		var opponent := state.players[1 - top.owner_index]
		var context_result := _coin_result_from_context()
		var heads := context_result == "heads" if context_result != "" else _pending_flip_heads
		if context_result == "" and not _has_pending_flip:
			heads = coin_flipper.flip()
		_has_pending_flip = false
		if heads:
			if AdvancedHelpers.is_basic_pokemon_slot(defender):
				AdvancedHelpers.knock_out_slot(defender, state)
			return
		var target := _selected_basic_bench(opponent)
		if target != null:
			AdvancedHelpers.knock_out_slot(target, state)

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
			if AdvancedHelpers.is_basic_pokemon_slot(slot):
				result.append(slot)
		return result

	func _selected_basic_bench(opponent: PlayerState) -> PokemonSlot:
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if entry is PokemonSlot and entry in opponent.bench and AdvancedHelpers.is_basic_pokemon_slot(entry):
				return entry
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


class KyuremAntiPlasma extends BaseEffect:
	func get_attack_any_cost_modifier(attacker: PokemonSlot, attack: Dictionary, state: GameState) -> int:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return 0
		if str(attack.get("name", "")) not in ["三重冰霜", "Trifrost"]:
			return 0
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		for card: CardInstance in opponent.discard_pile:
			if card.card_data == null:
				continue
			if card.card_data.name.contains("阿克罗玛") or card.card_data.name_en.contains("Colress"):
				return -4
		return 0


class KyuremTrifrost extends BaseEffect:
	const STEP_ID := "trifrost_targets"
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_attack_interaction_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if not applies_to_attack_index(AdvancedHelpers.resolve_attack_index(card, attack)):
			return []
		var opponent := state.players[1 - card.owner_index]
		var items := opponent.get_all_pokemon()
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append(AdvancedHelpers.slot_label(slot))
		var count := mini(3, items.size())
		if count <= 0:
			return []
		return [{
			"id": STEP_ID,
			"title": "选择对手的%d只宝可梦各造成110伤害" % count,
			"items": items,
			"labels": labels,
			"min_select": count,
			"max_select": count,
			"allow_cancel": true,
		}]

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		if top == null:
			return
		var player := state.players[top.owner_index]
		var opponent := state.players[1 - top.owner_index]
		var discarded := attacker.attached_energy.duplicate()
		attacker.attached_energy.clear()
		for energy: CardInstance in discarded:
			player.discard_pile.append(energy)
		var targets := _selected_targets(opponent, 3)
		for target: PokemonSlot in targets:
			if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
				continue
			if target != opponent.active_pokemon and AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
				continue
			if AbilityPreventDamageFromBasicEx.prevents_target_damage(attacker, target, state):
				continue
			target.damage_counters += _calculate_attack_target_damage(attacker, target, 110, state)

	func _selected_targets(opponent: PlayerState, limit: int) -> Array:
		var result: Array = []
		for entry: Variant in get_attack_interaction_context().get(STEP_ID, []):
			if entry is PokemonSlot and entry in opponent.get_all_pokemon() and entry not in result:
				result.append(entry)
				if result.size() >= limit:
					return result
		for slot: PokemonSlot in opponent.get_all_pokemon():
			if slot not in result:
				result.append(slot)
				if result.size() >= limit:
					break
		return result


class EeveeBoostedEvolution extends BaseEffect:
	func allows_fast_evolution(source: PokemonSlot, state: GameState) -> bool:
		if source == null or state == null or source.get_top_card() == null:
			return false
		var owner := source.get_top_card().owner_index
		return state.players[owner].active_pokemon == source


class NoctowlJewelSeeker extends BaseEffect:
	const STEP_ID := "jewel_seeker_trainers"
	const USED_FLAG := "csv9c_jewel_seeker_used"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top := pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		if state.current_player_index != top.owner_index:
			return false
		if pokemon.turn_evolved != state.turn_number:
			return false
		for eff: Dictionary in pokemon.effects:
			if eff.get("type", "") == USED_FLAG and int(eff.get("turn", -1)) == state.turn_number:
				return false
		var player := state.players[top.owner_index]
		return _has_tera_pokemon(player) and not _trainer_cards(player.deck).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var items := _trainer_cards(player.deck)
		if items.is_empty():
			return []
		return [build_full_library_search_step(
			STEP_ID,
			"从牌库中选择最多2张训练家加入手牌",
			player.deck,
			items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(2, items.size()),
			{"allow_cancel": true}
		)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if pokemon == null or pokemon.get_top_card() == null:
			return
		var player := state.players[pokemon.get_top_card().owner_index]
		var selected := AdvancedHelpers.selected_cards(player.deck, _trainer_cards(player.deck), get_interaction_context(targets).get(STEP_ID, []), 2)
		for card: CardInstance in selected:
			player.deck.erase(card)
			card.face_up = true
			player.hand.append(card)
		player.shuffle_deck()
		pokemon.effects.append({"type": USED_FLAG, "turn": state.turn_number})

	func _has_tera_pokemon(player: PlayerState) -> bool:
		for slot: PokemonSlot in player.get_all_pokemon():
			var cd := slot.get_card_data()
			if cd != null and (cd.ancient_trait == "Tera" or cd.has_tag("Tera") or cd.label.contains("太晶") or cd.name.contains("太乐巴戈斯")):
				return true
		return false

	func _trainer_cards(cards: Array[CardInstance]) -> Array:
		var result: Array = []
		for card: CardInstance in cards:
			if card.card_data != null and card.card_data.is_trainer():
				result.append(card)
		return result


class RotomFanCall extends BaseEffect:
	const STEP_ID := "fan_call_targets"
	const USED_FLAG := "csv9c_fan_call_used"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		var top := pokemon.get_top_card() if pokemon != null else null
		if top == null or state == null:
			return false
		var owner := top.owner_index
		if state.current_player_index != owner:
			return false
		if not state.is_first_turn_for_player(owner):
			return false
		if int(state.shared_turn_flags.get("%s%d" % [USED_FLAG, owner], -999)) == state.turn_number:
			return false
		return not _fan_call_targets(state.players[owner].deck).is_empty()

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var player := state.players[card.owner_index]
		var items := _fan_call_targets(player.deck)
		if items.is_empty():
			return []
		return [build_full_library_search_step(
			STEP_ID,
			"从牌库中选择最多3张HP100及以下的无色宝可梦加入手牌",
			player.deck,
			items,
			VISIBLE_SCOPE_OWN_FULL_DECK,
			0,
			mini(3, items.size()),
			{"allow_cancel": true}
		)]

	func execute_ability(pokemon: PokemonSlot, _ability_index: int, targets: Array, state: GameState) -> void:
		if pokemon == null or pokemon.get_top_card() == null:
			return
		var top := pokemon.get_top_card()
		var player := state.players[top.owner_index]
		var selected := AdvancedHelpers.selected_cards(player.deck, _fan_call_targets(player.deck), get_interaction_context(targets).get(STEP_ID, []), 3)
		for card: CardInstance in selected:
			player.deck.erase(card)
			card.face_up = true
			player.hand.append(card)
		player.shuffle_deck()
		state.shared_turn_flags["%s%d" % [USED_FLAG, top.owner_index]] = state.turn_number
		pokemon.mark_ability_used(state.turn_number)

	func _fan_call_targets(cards: Array[CardInstance]) -> Array:
		var result: Array = []
		for card: CardInstance in cards:
			var cd := card.card_data
			if cd != null and cd.is_pokemon() and cd.energy_type == "C" and cd.hp <= 100:
				result.append(card)
		return result


class RotomAssaultLanding extends BaseEffect:
	var attack_index_to_match: int = 0

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func get_damage_bonus(_attacker: PokemonSlot, state: GameState) -> int:
		return 0 if state != null and state.stadium_card != null else -70


class BouffalantCurlyWall extends BaseEffect:
	func get_team_defense_modifier(source: PokemonSlot, defender: PokemonSlot, _attacker: PokemonSlot, state: GameState) -> int:
		if source == null or defender == null or state == null or source.get_top_card() == null or defender.get_top_card() == null:
			return 0
		var owner := source.get_top_card().owner_index
		if defender.get_top_card().owner_index != owner:
			return 0
		var cd := defender.get_card_data()
		if cd == null or cd.stage != "Basic" or cd.energy_type != "C":
			return 0
		var count := 0
		for slot: PokemonSlot in state.players[owner].get_all_pokemon():
			if slot.get_card_data() != null and slot.get_card_data().name == "爆炸头水牛":
				count += 1
		return -60 if count >= 2 else 0


class TerapagosExCrownOpalMarker extends BaseEffect:
	const EFFECT_TYPE := "csv9c_crown_opal_prevent_basic_non_colorless"
	var attack_index_to_match: int = 1

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or not applies_to_attack_index(attack_index):
			return
		attacker.effects.append({"type": EFFECT_TYPE, "turn": state.turn_number})


class TerapagosExCrownOpalGuard extends BaseEffect:
	const EFFECT_TYPE := "csv9c_crown_opal_prevent_basic_non_colorless"

	func prevents_damage_from(attacker: PokemonSlot, defender: PokemonSlot, state: GameState) -> bool:
		if attacker == null or defender == null or state == null or attacker.get_card_data() == null:
			return false
		var attacker_cd := attacker.get_card_data()
		if attacker_cd.stage != "Basic" or attacker_cd.energy_type == "C":
			return false
		for eff: Dictionary in defender.effects:
			if eff.get("type", "") == EFFECT_TYPE and int(eff.get("turn", -999)) == state.turn_number - 1:
				return true
		return false


class TerapagosExUnifiedBeatGate extends BaseEffect:
	func blocks_second_player_first_turn_use(attacker: PokemonSlot, state: GameState) -> bool:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return false
		var owner := attacker.get_top_card().owner_index
		return state.is_first_turn_for_player(owner) and owner != state.first_player_index


class SlowkingInspirationChallenge extends BaseEffect:
	const OPTION_STEP_ID := "inspiration_attack"
	var attack_index_to_match: int = 0
	var processor

	func _init(effect_processor = null) -> void:
		processor = effect_processor

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index == attack_index_to_match

	func execute_attack(attacker: PokemonSlot, defender: PokemonSlot, attack_index: int, state: GameState) -> void:
		if attacker == null or defender == null or state == null or not applies_to_attack_index(attack_index):
			return
		var top := attacker.get_top_card()
		if top == null:
			return
		var player := state.players[top.owner_index]
		if player.deck.is_empty():
			return
		var milled: CardInstance = player.deck.pop_front()
		milled.face_up = true
		player.discard_pile.append(milled)
		if milled.card_data == null or not milled.card_data.is_pokemon() or milled.card_data.is_rule_box_pokemon():
			return
		var copied_index := _selected_attack_index(milled)
		if copied_index < 0 or copied_index >= milled.card_data.attacks.size():
			return
		var copied_attack: Dictionary = milled.card_data.attacks[copied_index]
		var damage := DamageCalculator.new().parse_damage(str(copied_attack.get("damage", "")))
		var attack_bonus := 0
		var attacker_mod := 0
		var defender_mod := 0
		var ignore_weakness := false
		var ignore_resistance := false
		var ignore_effects := false
		if processor != null:
			attack_bonus = processor.get_attack_damage_bonus_by_id(milled.card_data.effect_id, copied_index, attacker, state, [get_attack_interaction_context()], SlowkingInspirationChallenge)
			attacker_mod = processor.get_attacker_modifier(attacker, state, defender)
			ignore_weakness = processor.attack_effect_id_ignores_weakness(milled.card_data.effect_id, copied_index, attacker, state, [get_attack_interaction_context()], SlowkingInspirationChallenge)
			ignore_resistance = processor.attack_effect_id_ignores_resistance(milled.card_data.effect_id, copied_index, attacker, state, [get_attack_interaction_context()], SlowkingInspirationChallenge)
			ignore_effects = processor.attack_effect_id_ignores_defender_effects(milled.card_data.effect_id, copied_index, attacker, state, [get_attack_interaction_context()], SlowkingInspirationChallenge)
			if not ignore_effects:
				defender_mod = processor.get_defender_modifier(defender, state, attacker)
		var resolved_damage := DamageCalculator.new().calculate_damage(
			attacker,
			defender,
			{"damage": str(damage + attack_bonus)},
			state,
			0,
			attacker_mod,
			defender_mod,
			ignore_weakness,
			ignore_resistance
		)
		if resolved_damage > 0:
			DamageCalculator.new().apply_damage_to_slot(defender, resolved_damage)
		if processor != null:
			processor.execute_attack_effect_by_id(
				milled.card_data.effect_id,
				copied_index,
				attacker,
				defender,
				state,
				[get_attack_interaction_context()],
				SlowkingInspirationChallenge
			)

	func _selected_attack_index(card: CardInstance) -> int:
		var ctx := get_attack_interaction_context()
		for entry: Variant in ctx.get(OPTION_STEP_ID, []):
			if entry is Dictionary:
				return int(entry.get("attack_index", -1))
			if entry is int:
				return int(entry)
		for i: int in card.card_data.attacks.size():
			if not bool(card.card_data.attacks[i].get("is_vstar_power", false)):
				return i
		return -1
