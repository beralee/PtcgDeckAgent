## Energy Sticker - flip a coin; on heads attach 1 Basic Energy from discard to a Benched Pokemon.
class_name EffectEnergySticker
extends BaseEffect

const ASSIGNMENT_ID := "energy_sticker_assignment"

var coin_flipper: CoinFlipper
var _pending_heads: bool = false
var _has_pending_flip: bool = false


func _init(flipper: CoinFlipper = null) -> void:
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func can_execute(card: CardInstance, state: GameState) -> bool:
	var player: PlayerState = state.players[card.owner_index]
	return not _get_basic_energy(player).is_empty() and not player.bench.is_empty()


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": "coin_flip_preview",
		"title": "投掷1枚硬币",
		"wait_for_coin_animation": true,
		"preview_only": true,
	}]


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	_pending_heads = coin_flipper.flip()
	_has_pending_flip = true
	if not _pending_heads:
		return []

	var player: PlayerState = state.players[card.owner_index]
	var source_items: Array = _get_basic_energy(player)
	var source_labels: Array[String] = []
	for energy_card: CardInstance in source_items:
		source_labels.append(energy_card.card_data.name)

	var target_items: Array = player.bench.duplicate()
	var target_labels: Array[String] = []
	for slot: PokemonSlot in target_items:
		target_labels.append("%s (HP %d/%d)" % [
			slot.get_pokemon_name(),
			slot.get_remaining_hp(),
			slot.get_max_hp(),
		])

	return [build_card_assignment_step(
		ASSIGNMENT_ID,
		"选择弃牌区1张基本能量附着给备战宝可梦",
		source_items,
		source_labels,
		target_items,
		target_labels,
		1,
		1,
		true
	)]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_pending_flip:
		_pending_heads = coin_flipper.flip()
		_has_pending_flip = true
	if not _pending_heads:
		_has_pending_flip = false
		return

	var player: PlayerState = state.players[card.owner_index]
	var assignment: Dictionary = _resolve_assignment(player, get_interaction_context(targets))
	_has_pending_flip = false
	if assignment.is_empty():
		return

	var energy_card: CardInstance = assignment.get("source", null)
	var target_slot: PokemonSlot = assignment.get("target", null)
	if energy_card == null or target_slot == null:
		return

	player.discard_pile.erase(energy_card)
	energy_card.face_up = true
	target_slot.attached_energy.append(energy_card)


func _resolve_assignment(player: PlayerState, ctx: Dictionary) -> Dictionary:
	var selected_raw: Array = ctx.get(ASSIGNMENT_ID, [])
	for entry: Variant in selected_raw:
		if not (entry is Dictionary):
			continue
		var assignment: Dictionary = entry
		var source: Variant = assignment.get("source", null)
		var target: Variant = assignment.get("target", null)
		if not (source is CardInstance) or not (target is PokemonSlot):
			continue
		var source_card: CardInstance = source
		var target_slot: PokemonSlot = target
		if source_card in _get_basic_energy(player) and target_slot in player.bench:
			return {
				"source": source_card,
				"target": target_slot,
			}

	var fallback_energy: Array = _get_basic_energy(player)
	if fallback_energy.is_empty() or player.bench.is_empty():
		return {}
	return {
		"source": fallback_energy[0],
		"target": player.bench[0],
	}


func _get_basic_energy(player: PlayerState) -> Array:
	var result: Array = []
	for discard_card: CardInstance in player.discard_pile:
		if discard_card.card_data == null:
			continue
		if discard_card.card_data.card_type == "Basic Energy":
			result.append(discard_card)
	return result


func get_description() -> String:
	return "Flip a coin. If heads, attach 1 Basic Energy from your discard pile to 1 of your Benched Pokemon."
