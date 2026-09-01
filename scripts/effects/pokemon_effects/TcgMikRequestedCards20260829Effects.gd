class_name TcgMikRequestedCards20260829Effects
extends RefCounted

const AbilityIgnoreEffectsScript := preload("res://scripts/effects/pokemon_effects/AbilityIgnoreEffects.gd")
const CSV9CHelpersScript := preload("res://scripts/effects/CSV9CHelpers.gd")


class TapuKokoRevengeImpact extends BaseEffect:
	var bonus_damage: int = 90
	var attack_index_to_match: int = 0

	func _init(bonus: int = 90, match_attack_index: int = 0) -> void:
		bonus_damage = maxi(0, bonus)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		return bonus_damage if _qualifies(attacker, state) else 0

	func execute_attack(
		attacker: PokemonSlot,
		defender: PokemonSlot,
		attack_index: int,
		state: GameState
	) -> void:
		if not applies_to_attack_index(attack_index) or not _qualifies(attacker, state):
			return
		if defender == null or EffectMistEnergy.has_mist_energy(defender):
			return
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
				return
		_apply_special_status(defender, "paralyzed", state)

	func _qualifies(attacker: PokemonSlot, state: GameState) -> bool:
		if attacker == null or attacker.get_top_card() == null or state == null:
			return false
		var owner := attacker.get_top_card().owner_index
		if not state.was_knocked_out_during_opponents_previous_turn(owner):
			return false
		var attack_key := "attack_damage_knockout_names:%d:%d" % [owner, state.turn_number - 1]
		if state.shared_turn_flags.has(attack_key):
			var attack_names: Variant = state.shared_turn_flags.get(attack_key, [])
			return attack_names is Array and not (attack_names as Array).is_empty()
		var any_key := "knockout_names:%d:%d" % [owner, state.turn_number - 1]
		if state.shared_turn_flags.has(any_key):
			return false
		# Authored fixtures and old replays predate attack-damage identity tracking.
		return true

	func get_description() -> String:
		return "If one of your Pokemon was Knocked Out by attack damage during the opponent's last turn, add 90 damage and Paralyze the opponent's Active Pokemon."


class AbilityBouquetMagic extends BaseEffect:
	const ENERGY_STEP_ID := "bouquet_magic_grass_energy"
	const TARGET_STEP_ID := "bouquet_magic_bench_target"

	func can_use_ability(pokemon: PokemonSlot, state: GameState) -> bool:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return false
		var owner := pokemon.get_top_card().owner_index
		return (
			state.current_player_index == owner
			and state.phase == GameState.GamePhase.MAIN
			and not pokemon.has_ability_used(state.turn_number)
			and not _grass_energy(state.players[owner]).is_empty()
			and not state.players[1 - owner].bench.is_empty()
		)

	func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		if card == null or state == null:
			return []
		var energies := _grass_energy(state.players[card.owner_index])
		var targets: Array = state.players[1 - card.owner_index].bench.duplicate()
		if energies.is_empty() or targets.is_empty():
			return []
		var energy_labels: Array[String] = []
		for energy: CardInstance in energies:
			energy_labels.append(energy.card_data.name if energy.card_data != null else "")
		var target_labels: Array[String] = []
		for target: PokemonSlot in targets:
			target_labels.append("%s (HP %d/%d)" % [target.get_pokemon_name(), target.get_remaining_hp(), target.get_max_hp()])
		return [
			{
				"id": ENERGY_STEP_ID,
				"title": "选择要弃置的1张基本草能量",
				"items": energies,
				"labels": energy_labels,
				"min_select": 1,
				"max_select": 1,
				"allow_cancel": true,
			},
			{
				"id": TARGET_STEP_ID,
				"title": "选择对手的1只备战宝可梦，放置3个伤害指示物",
				"items": targets,
				"labels": target_labels,
				"min_select": 1,
				"max_select": 1,
				"allow_cancel": true,
			},
		]

	func validate_ability_interaction(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if not can_use_ability(pokemon, state):
			return interaction_validation_error("Bouquet Magic is not available")
		var owner := pokemon.get_top_card().owner_index
		var context := get_interaction_context(targets)
		var energy_result := validate_context_selection(
			context,
			ENERGY_STEP_ID,
			_grass_energy(state.players[owner]),
			1,
			1
		)
		if not bool(energy_result.get("valid", false)):
			return energy_result
		return validate_context_selection(
			context,
			TARGET_STEP_ID,
			state.players[1 - owner].bench,
			1,
			1
		)

	func execute_ability(
		pokemon: PokemonSlot,
		_ability_index: int,
		targets: Array,
		state: GameState
	) -> void:
		var validation := validate_ability_interaction(pokemon, 0, targets, state)
		if not bool(validation.get("valid", false)):
			return
		var owner := pokemon.get_top_card().owner_index
		var player := state.players[owner]
		var context := get_interaction_context(targets)
		var energy: CardInstance = (context.get(ENERGY_STEP_ID, []) as Array)[0]
		var target: PokemonSlot = (context.get(TARGET_STEP_ID, []) as Array)[0]
		player.hand.erase(energy)
		energy.face_up = true
		player.discard_pile.append(energy)
		target.damage_counters += 30
		pokemon.mark_ability_used(state.turn_number)

	func _grass_energy(player: PlayerState) -> Array[CardInstance]:
		var result: Array[CardInstance] = []
		if player == null:
			return result
		for card: CardInstance in player.hand:
			if CSV9CHelpersScript.is_basic_energy(card, "G"):
				result.append(card)
		return result

	func get_empty_interaction_message(_card: CardInstance, _state: GameState) -> String:
		return "需要1张手牌中的基本草能量和对手的1只备战宝可梦。"

	func get_description() -> String:
		return "Once during your turn, discard a Basic Grass Energy from your hand and put 3 damage counters on 1 of your opponent's Benched Pokemon."


class AttackSetOpponentRemainingHP extends BaseEffect:
	const STEP_ID := "opponent_pokemon_remaining_hp_target"

	var remaining_hp: int = 30
	var attack_index_to_match: int = 0

	func _init(target_remaining_hp: int = 30, match_attack_index: int = 0) -> void:
		remaining_hp = maxi(0, target_remaining_hp)
		attack_index_to_match = match_attack_index

	func applies_to_attack_index(attack_index: int) -> bool:
		return attack_index_to_match < 0 or attack_index == attack_index_to_match

	func get_attack_interaction_steps(
		card: CardInstance,
		attack: Dictionary,
		state: GameState
	) -> Array[Dictionary]:
		if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
			return []
		var items: Array = state.players[1 - card.owner_index].get_all_pokemon()
		if items.is_empty():
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in items:
			labels.append("%s (HP %d/%d)" % [slot.get_pokemon_name(), slot.get_remaining_hp(), slot.get_max_hp()])
		return [{
			"id": STEP_ID,
			"title": "选择对手的1只宝可梦，使其剩余HP变为%d" % remaining_hp,
			"items": items,
			"labels": labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		}]

	func validate_attack_interaction(
		attacker: PokemonSlot,
		attack_index: int,
		targets: Array,
		state: GameState
	) -> Dictionary:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return interaction_validation_error("Icicle Sole is not available")
		var owner := attacker.get_top_card().owner_index
		return validate_context_selection(
			get_interaction_context(targets),
			STEP_ID,
			state.players[1 - owner].get_all_pokemon(),
			1,
			1
		)

	func execute_attack(
		attacker: PokemonSlot,
		_defender: PokemonSlot,
		attack_index: int,
		state: GameState
	) -> void:
		if attacker == null or attacker.get_top_card() == null or state == null or not applies_to_attack_index(attack_index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		var selected: Array = get_attack_interaction_context().get(STEP_ID, [])
		if selected.is_empty() or not (selected[0] is PokemonSlot):
			return
		var target := selected[0] as PokemonSlot
		if target not in opponent.get_all_pokemon() or _is_prevented(attacker, target, opponent, state):
			return
		var max_hp := target.get_max_hp()
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("get_effective_max_hp"):
			max_hp = int(processor.call("get_effective_max_hp", target, state))
		var target_damage := maxi(0, max_hp - remaining_hp)
		if target.damage_counters < target_damage:
			target.damage_counters = target_damage
			_mark_attack_damage_counter_placement(target, state)

	func _is_prevented(
		attacker: PokemonSlot,
		target: PokemonSlot,
		opponent: PlayerState,
		state: GameState
	) -> bool:
		if target == null or AbilityIgnoreEffectsScript.has_ignore_effects(target):
			return true
		if target in opponent.bench and AbilityBenchImmune.prevents_opponent_attack_effect(target, attacker, state):
			return true
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null)
		if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
			if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, target, state)):
				return true
		if processor != null and processor.has_method("has_mist_energy_protection"):
			return bool(processor.call("has_mist_energy_protection", target, state))
		return false

	func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
		if attack.has("_override_attack_index"):
			return int(attack.get("_override_attack_index", -1))
		if card == null or card.card_data == null:
			return -1
		for index: int in card.card_data.attacks.size():
			if card.card_data.attacks[index] == attack:
				return index
		return -1

	func get_description() -> String:
		return "Put damage counters on 1 of your opponent's Pokemon until it has %d HP remaining." % remaining_hp


class AbilityKofuPrepWork extends BaseEffect:
	func execute_ability(
		_pokemon: PokemonSlot,
		_ability_index: int,
		_targets: Array,
		_state: GameState
	) -> void:
		pass

	func is_cost_modifier_ability() -> bool:
		return true

	func get_attack_colorless_cost_modifier(
		pokemon: PokemonSlot,
		attack: Dictionary,
		state: GameState
	) -> int:
		if pokemon == null or pokemon.get_top_card() == null or state == null:
			return 0
		var owner := pokemon.get_top_card().owner_index
		if owner < 0 or owner >= state.players.size():
			return 0
		var colorless_count := 0
		for symbol: String in CardData.normalize_attack_cost(attack.get("cost", "")):
			if symbol == "C":
				colorless_count += 1
		var kofu_count := 0
		for card: CardInstance in state.players[owner].discard_pile:
			if card == null or card.card_data == null:
				continue
			if card.card_data.name == "海岱" or card.card_data.name_en == "Kofu":
				kofu_count += 1
		return -mini(kofu_count, colorless_count)

	func get_description() -> String:
		return "This Pokemon's attacks cost one less Colorless Energy for each Kofu in your discard pile."
