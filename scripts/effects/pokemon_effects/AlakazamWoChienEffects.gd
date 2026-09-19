extends RefCounted


## CSV9.5C 064 / CSV8C 075: Strange Hacking and Psychic.
class StrangeHacking extends BaseEffect:
	const STEP_ID := "alakazam_counter_redistribution"
	var processor: EffectProcessor

	func _init(p_processor: EffectProcessor) -> void:
		processor = p_processor
		bind_default_attack_index(0)

	func cancels_attack_damage(_attacker: PokemonSlot, _defender: PokemonSlot, index: int, _state: GameState) -> bool:
		# Moving counters is an effect, so damage bonuses cannot create a hit.
		return applies_to_attack_index(index)

	func _targets(card: CardInstance, state: GameState) -> Array[PokemonSlot]:
		var result: Array[PokemonSlot] = []
		var attacker: PokemonSlot = null
		for slot: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
			if card in slot.pokemon_stack:
				attacker = slot
				break
		# A delegated attack carries the actual attacking Pokemon, not the source card.
		for slot: PokemonSlot in state.players[1 - card.owner_index].get_all_pokemon():
			if AbilityBenchImmune.prevents_opponent_attack_effect(slot, attacker, state):
				continue
			if processor.is_attack_effect_prevented_by_defender_ability(attacker, slot, state):
				continue
			result.append(slot)
		return result

	func _total(targets: Array[PokemonSlot]) -> int:
		var result := 0
		for slot: PokemonSlot in targets:
			result += slot.damage_counters
		return result

	func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
		if int(attack.get("_override_attack_index", card.card_data.attacks.find(attack))) != 0:
			return []
		var targets := _targets(card, state)
		var count := int(_total(targets) / 10)
		if count == 0 or targets.size() < 2:
			return []
		var labels: Array[String] = []
		for slot: PokemonSlot in targets:
			labels.append("%s（原有%d个）" % [slot.get_pokemon_name(), slot.damage_counters / 10])
		# Redistributing the whole pool also expresses moving any subset: leave
		# the unchosen counters on their original Pokemon. No counters are added.
		return [{
			"id": STEP_ID,
			"title": "重新分配现有的%d个伤害指示物（保留原分布即不移动）" % count,
			"ui_mode": "counter_distribution", "total_counters": count,
			"target_items": targets, "target_labels": labels,
			"min_select": count, "max_select": count, "allow_cancel": false,
		}]

	func validate_attack_interaction(attacker: PokemonSlot, index: int, targets: Array, state: GameState) -> Dictionary:
		if not applies_to_attack_index(index):
			return interaction_validation_ok()
		var context := get_interaction_context(targets)
		if not context.has(STEP_ID):
			return interaction_validation_ok() # Optional movement: legacy no-selection leaves counters in place.
		var raw: Variant = context[STEP_ID]
		if not (raw is Array):
			return interaction_validation_error("counter redistribution is invalid")
		var legal := _targets(attacker.get_top_card(), state)
		var total := 0
		for entry: Variant in raw:
			if not (entry is Dictionary) or not entry.get("target") in legal:
				return interaction_validation_error("counter redistribution target is no longer legal")
			var amount: Variant = entry.get("amount")
			if not (amount is int) or amount <= 0 or amount % 10 != 0:
				return interaction_validation_error("counter redistribution must use whole damage counters")
			total += amount
		if total != _total(legal):
			return interaction_validation_error("counter redistribution must preserve the existing total")
		return interaction_validation_ok()

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var context := get_attack_interaction_context()
		if not context.has(STEP_ID):
			return
		var legal := _targets(attacker.get_top_card(), state)
		var allocation: Dictionary = {}
		for entry: Dictionary in context[STEP_ID]:
			var target: PokemonSlot = entry.target
			allocation[target] = int(allocation.get(target, 0)) + int(entry.amount)
		# Apply final totals together; the engine checks Knock Outs after the attack.
		for slot: PokemonSlot in legal:
			var final_amount := int(allocation.get(slot, 0))
			if final_amount > slot.damage_counters:
				_mark_attack_damage_counter_placement(slot, state)
			slot.damage_counters = final_amount


class Psychic extends BaseEffect:
	var processor: EffectProcessor

	func _init(p_processor: EffectProcessor) -> void:
		processor = p_processor
		bind_default_attack_index(1)

	func get_damage_bonus(attacker: PokemonSlot, state: GameState) -> int:
		var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
		var units := 0
		if defender != null:
			for energy: CardInstance in defender.attached_energy:
				units += processor.get_energy_colorless_count(energy, state)
		return units * 50


## CSVL2C 013 / CSV3C 015: Covetous Ivy. Forest Burn is printed 220 damage.
class CovetousIvy extends AttackTargetOpponentBenchDamage:
	func _init() -> void:
		super(0, 0)

	func cancels_attack_damage(_attacker: PokemonSlot, _defender: PokemonSlot, index: int, _state: GameState) -> bool:
		# The separate, selected Bench target owns all damage from this attack.
		return applies_to_attack_index(index)

	func validate_attack_interaction(attacker: PokemonSlot, index: int, targets: Array, state: GameState) -> Dictionary:
		var context := get_interaction_context(targets)
		if not applies_to_attack_index(index) or not context.has(STEP_ID):
			return interaction_validation_ok()
		var selected: Variant = context[STEP_ID]
		var bench := state.players[1 - attacker.get_top_card().owner_index].bench
		if not (selected is Array) or selected.size() != 1 or not selected[0] in bench:
			return interaction_validation_error("Covetous Ivy requires a current opposing Bench Pokemon")
		return interaction_validation_ok()

	func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, index: int, state: GameState) -> void:
		if not applies_to_attack_index(index):
			return
		var opponent := state.players[1 - attacker.get_top_card().owner_index]
		if opponent.bench.is_empty():
			return
		var selected: Array = get_attack_interaction_context().get(STEP_ID, [])
		var target: PokemonSlot = selected[0] if not selected.is_empty() else opponent.bench[0]
		if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
			return
		if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
			return
		if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
			return
		var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
		var base_damage := maxi(0, 6 - opponent.prizes.size()) * 60
		var calculator := DamageCalculator.new()
		var damage := calculator.calculate_damage(
			attacker, target, {"damage": str(base_damage)}, state, 0,
			processor.get_attacker_modifier(attacker, state, target),
			processor.get_defender_modifier(target, state, attacker), true, true
		)
		calculator.apply_damage_to_slot(target, damage)
