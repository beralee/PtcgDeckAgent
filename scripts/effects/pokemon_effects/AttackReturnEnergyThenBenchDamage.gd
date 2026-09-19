class_name AttackReturnEnergyThenBenchDamage
extends BaseEffect

const AbilityPreventDamageFromBasicExEffect = preload("res://scripts/effects/pokemon_effects/AbilityPreventDamageFromBasicEx.gd")
const RETURN_STEP := "return_energy_to_deck"

var damage_amount: int = 120
var energy_return_count: int = 3
var attack_index_to_match: int = -1
var processor: EffectProcessor = null


func _init(amount: int = 120, match_attack_index: int = -1, return_count: int = 3, p_processor: EffectProcessor = null) -> void:
	damage_amount = amount
	attack_index_to_match = match_attack_index
	energy_return_count = return_count
	processor = p_processor


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	if attacker == null:
		return []
	var required_return_count := _required_units(attacker, state)
	if required_return_count <= 0:
		return []
	if state.players[1 - card.owner_index].bench.is_empty():
		return []
	return [_energy_step(attacker, state, [], RETURN_STEP)]


func _energy_step(attacker: PokemonSlot, state: GameState, chosen: Array[CardInstance], step_id: String) -> Dictionary:
	var player := state.players[attacker.get_top_card().owner_index]
	var energy_items: Array = []
	var has_multi_energy := false
	for energy: CardInstance in attacker.attached_energy:
		if _units(energy, state) > 1:
			has_multi_energy = true
		if energy not in chosen and _units(energy, state) > 0:
			energy_items.append(energy)
	var remaining := _required_units(attacker, state) - _sum_units(chosen, state)
	# Ordinary Energy keeps the existing single selection. Multi-Energy cards
	# use fresh one-card windows so each choice updates the remaining units.
	var count := 1 if has_multi_energy else remaining
	var energy_labels: Array[String] = []
	for energy: CardInstance in energy_items:
		energy_labels.append(energy.card_data.name if energy.card_data != null else "")
	return {
		"id": step_id,
		"title": "选择能量洗回牌库（还需%d个能量）" % remaining,
		"items": energy_items,
		"labels": energy_labels,
		"card_groups": build_attached_card_groups(player, energy_items),
		"transparent_battlefield_dialog": true,
		"min_select": count,
		"max_select": count,
		"allow_cancel": chosen.is_empty(),
		"utility_actions": [build_empty_dialog_utility_action("不洗回能量", INTERACTION_INTENT_DECLINE)] if chosen.is_empty() else [],
	}


func build_ucis_followup_attack_interaction_steps_spec_steps(
	card: CardInstance,
	attack: Dictionary,
	state: GameState,
	resolved_context: Dictionary
) -> Array[Dictionary]:
	if not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	var player: PlayerState = state.players[card.owner_index]
	var attacker: PokemonSlot = player.active_pokemon
	var selected := _selected_energy(attacker, resolved_context)
	if not bool(selected.ok) or selected.cards.is_empty():
		return []
	if _sum_units(selected.cards, state) < _required_units(attacker, state):
		# Only a completed one-card window may open another one-card window.
		if not _has_multi_energy(attacker, state):
			return []
		return [_energy_step(attacker, state, selected.cards, "%s_%d" % [RETURN_STEP, selected.cards.size() + 1])]
	if not _valid_return(attacker, selected.cards, state):
		return []
	if resolved_context.has("bench_target"):
		return []
	var bench_items: Array = state.players[1 - card.owner_index].bench.duplicate()
	if bench_items.is_empty():
		return []
	var bench_labels: Array[String] = []
	for slot: PokemonSlot in bench_items:
		bench_labels.append(slot.get_pokemon_name())
	return [
		{
			"id": "bench_target",
			"title": "选择对手的1只备战宝可梦",
			"items": bench_items,
			"labels": bench_labels,
			"min_select": 1,
			"max_select": 1,
			"allow_cancel": false,
		},
	]


func validate_attack_interaction(attacker: PokemonSlot, index: int, targets: Array, state: GameState) -> Dictionary:
	if not applies_to_attack_index(index):
		return interaction_validation_ok()
	var context := get_interaction_context(targets)
	var selected := _selected_energy(attacker, context)
	if not bool(selected.ok):
		return interaction_validation_error("Energy return contains a duplicate or stale card")
	if selected.cards.is_empty():
		if context.has("bench_target") and context["bench_target"] != []:
			return interaction_validation_error("Bench damage requires returning some Energy")
		return interaction_validation_ok()
	if not _valid_return(attacker, selected.cards, state):
		return interaction_validation_error("Return three Energy, or all available Energy if fewer remain")
	var opponent := state.players[1 - attacker.get_top_card().owner_index]
	if _resolve_bench_target(context.get("bench_target", []), opponent) == null:
		return interaction_validation_error("Choose a current opposing Bench Pokemon")
	return interaction_validation_ok()


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	var player: PlayerState = state.players[top.owner_index]
	var opponent: PlayerState = state.players[1 - top.owner_index]
	var ctx: Dictionary = get_attack_interaction_context()
	var selected := _selected_energy(attacker, ctx)
	if not bool(selected.ok) or not _valid_return(attacker, selected.cards, state):
		return
	var target: PokemonSlot = _resolve_bench_target(ctx.get("bench_target", []), opponent)
	if target == null:
		return

	# Energy modifiers (notably Double Turbo's -20) still apply to this
	# attack's Bench damage even though those Energy cards are shuffled back.
	var current_processor := _processor(state)
	var damage := damage_amount
	if current_processor != null:
		damage = DamageCalculator.new().calculate_damage(attacker, target, {"damage": str(damage_amount)}, state, 0,
			current_processor.get_attacker_modifier(attacker, state, target),
			current_processor.get_defender_modifier(target, state, attacker), true, true)
	for energy: CardInstance in selected.cards:
		attacker.attached_energy.erase(energy)
		energy.face_up = false
		player.deck.append(energy)

	player.shuffle_deck()
	if AbilityBenchImmune.prevents_opponent_attack_damage(target, attacker, state):
		return
	if AbilityPreventDamageFromBasicExEffect.prevents_target_damage(attacker, target, state):
		return
	if AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_damage(target, state):
		return
	DamageCalculator.new().apply_damage_to_slot(target, damage)


func _resolve_attached_energy(attacker: PokemonSlot, selected: Variant) -> CardInstance:
	var selected_card: CardInstance = null
	if selected is CardInstance:
		selected_card = selected
	elif selected is Dictionary:
		var selected_dict := selected as Dictionary
		for key: String in ["card", "source", "energy"]:
			var value: Variant = selected_dict.get(key, null)
			if value is CardInstance:
				selected_card = value
				break
	if selected_card == null:
		return null
	for attached: CardInstance in attacker.attached_energy:
		if attached == selected_card or attached.instance_id == selected_card.instance_id:
			return attached
	return null


func _resolve_bench_target(target_raw: Variant, opponent: PlayerState) -> PokemonSlot:
	if not (target_raw is Array):
		return null
	var target_items: Array = target_raw
	if target_items.size() != 1 or not (target_items[0] is PokemonSlot):
		return null
	var target: PokemonSlot = target_items[0]
	if target == null or target == opponent.active_pokemon or target not in opponent.bench:
		return null
	return target


func _processor(state: GameState) -> EffectProcessor:
	return processor if processor != null else state.shared_turn_flags.get("_draw_effect_processor", null)


func _units(energy: CardInstance, state: GameState) -> int:
	var current_processor := _processor(state)
	return current_processor.get_energy_colorless_count(energy, state) if current_processor != null else 1


func _sum_units(cards: Array[CardInstance], state: GameState) -> int:
	var total := 0
	for energy: CardInstance in cards:
		total += _units(energy, state)
	return total


func _required_units(attacker: PokemonSlot, state: GameState) -> int:
	return mini(energy_return_count, _sum_units(attacker.attached_energy, state))


func _has_multi_energy(attacker: PokemonSlot, state: GameState) -> bool:
	for energy: CardInstance in attacker.attached_energy:
		if _units(energy, state) > 1:
			return true
	return false


func _valid_return(attacker: PokemonSlot, cards: Array[CardInstance], state: GameState) -> bool:
	var required := _required_units(attacker, state)
	return required > 0 and not cards.is_empty() and cards.size() <= required and _sum_units(cards, state) >= required


func _selected_energy(attacker: PokemonSlot, context: Dictionary) -> Dictionary:
	var cards: Array[CardInstance] = []
	for i: int in range(1, energy_return_count + 1):
		var key := RETURN_STEP if i == 1 else "%s_%d" % [RETURN_STEP, i]
		var raw: Variant = context.get(key, [])
		if not (raw is Array):
			return {"ok": false, "cards": cards}
		for entry: Variant in raw:
			var energy := _resolve_attached_energy(attacker, entry)
			if energy == null or energy in cards:
				return {"ok": false, "cards": cards}
			cards.append(energy)
	return {"ok": true, "cards": cards}


func _resolve_attack_index(card: CardInstance, attack: Dictionary) -> int:
	if attack.has("_override_attack_index"):
		return int(attack.get("_override_attack_index", -1))
	if card == null or card.card_data == null:
		return -1
	for i: int in card.card_data.attacks.size():
		if card.card_data.attacks[i] == attack:
			return i
	return -1


func get_description() -> String:
	return "You may shuffle %d Energy into your deck. If you do, deal %d damage to 1 opponent Benched Pokemon." % [energy_return_count, damage_amount]
