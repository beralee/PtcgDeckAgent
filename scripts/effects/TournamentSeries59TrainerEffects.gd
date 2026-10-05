extends RefCounted


class HealTargets extends BaseEffect:
	const STEP_ID := "series59_heal_targets"
	var amount: int
	var maximum: int
	var full: bool
	var cure_status: bool
	var low_hp: bool
	var processor_ref: WeakRef
	func _init(heal_amount: int, max_targets: int = 1, heal_all: bool = false, cure: bool = false, require_low_hp: bool = false, processor: EffectProcessor = null) -> void:
		amount = heal_amount
		maximum = max_targets
		full = heal_all
		cure_status = cure
		low_hp = require_low_hp
		if processor != null: processor_ref = weakref(processor)
	func _targets(card: CardInstance, state: GameState) -> Array:
		var result: Array = []
		if card == null or state == null: return result
		var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor")
		if not processor is EffectProcessor and processor_ref != null: processor = processor_ref.get_ref()
		for slot: PokemonSlot in state.players[card.owner_index].get_all_pokemon():
			var remaining: int = processor.get_effective_remaining_hp(slot, state) if processor is EffectProcessor else slot.get_remaining_hp()
			var can_heal: bool = slot.damage_counters > 0 and (not processor is EffectProcessor or processor.can_heal_pokemon(slot, state))
			if low_hp and (remaining <= 0 or remaining > 30): continue
			if can_heal or (cure_status and slot.has_any_status()): result.append(slot)
		return result
	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not _targets(card, state).is_empty()
	func build_ucis_interaction_steps_spec_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
		var items := _targets(card, state)
		if items.is_empty(): return []
		var labels: Array[String] = []
		for slot: PokemonSlot in items: labels.append(slot.get_pokemon_name())
		return [{"id": STEP_ID, "title": "选择要回复的自己的宝可梦", "items": items, "labels": labels, "min_select": 0 if maximum > 1 else 1, "max_select": mini(maximum, items.size()), "allow_cancel": true, "requires_explicit_empty_selection": maximum > 1}]
	func validate_card_interaction(card: CardInstance, targets: Array, state: GameState) -> Dictionary:
		var candidates := _targets(card, state)
		return validate_context_selection(get_interaction_context(targets), STEP_ID, candidates, 0 if maximum > 1 else 1, mini(maximum, candidates.size()), maximum > 1)
	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if not bool(validate_card_interaction(card, targets, state).get("valid", false)): return
		for slot: PokemonSlot in get_interaction_context(targets).get(STEP_ID, []):
			slot.heal(slot.damage_counters if full else amount, state)
			if cure_status: slot.clear_all_status()


class PracticeStudio extends EffectStadiumDamageModifier:
	func _init() -> void:
		super(10, "attack", "Stage 1", false)
	func matches_pokemon(slot: PokemonSlot) -> bool:
		return slot != null and slot.get_card_data() != null and slot.get_card_data().stage == "Stage 1"


class MedicalEnergy extends BaseEffect:
	func get_energy_type_provides() -> String: return "C"
	func get_energy_count() -> int: return 1
	func execute(card: CardInstance, targets: Array, state: GameState) -> void:
		if targets.size() != 1 or not targets[0] is PokemonSlot: return
		var slot: PokemonSlot = targets[0]
		if card in slot.attached_energy and slot in state.players[card.owner_index].get_all_pokemon():
			slot.heal(30, state)


class DangerousLaser extends BaseEffect:
	func can_execute(card: CardInstance, state: GameState) -> bool:
		var target := state.players[1 - card.owner_index].active_pokemon
		return target != null and (not bool(target.status_conditions.get("burned", false)) or not bool(target.status_conditions.get("confused", false)))
	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		var target := state.players[1 - card.owner_index].active_pokemon
		_apply_special_status(target, "burned", state)
		_apply_special_status(target, "confused", state)


class CommunityCenter extends BaseEffect:
	func can_use_as_stadium_action(_card: CardInstance, _state: GameState) -> bool: return true
	func can_execute(_card: CardInstance, state: GameState) -> bool:
		if not state.supporter_used_this_turn: return false
		for slot: PokemonSlot in state.players[state.current_player_index].get_all_pokemon():
			if slot.damage_counters > 0: return true
		return false
	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		if not can_execute(card, state): return
		for slot: PokemonSlot in state.players[state.current_player_index].get_all_pokemon(): slot.heal(10, state)


class HandTrimmer extends BaseEffect:
	func can_execute(card: CardInstance, state: GameState) -> bool:
		return not state.players[1 - card.owner_index].hand.is_empty()
	func execute(card: CardInstance, _targets: Array, state: GameState) -> void:
		var opponent: PlayerState = state.players[1 - card.owner_index]
		var cards: Array[CardInstance] = opponent.hand.duplicate()
		opponent.shuffle_cards(cards, "series59_hand_to_bottom")
		for item: CardInstance in cards:
			opponent.remove_from_hand(item)
			item.face_up = false
			opponent.deck.append(item)
		_draw_cards_with_log(state, 1 - card.owner_index, cards.size(), card, "trainer")
