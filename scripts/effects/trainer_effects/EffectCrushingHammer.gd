## 粉碎之锤 - 投币正面→弃掉对手场上宝可梦身上附着的1个能量
class_name EffectCrushingHammer
extends BaseEffect

var _coin_flipper: CoinFlipper = null
var _pending_heads: bool = false
var _has_pending_flip: bool = false


func _init(flipper: CoinFlipper = null) -> void:
	_coin_flipper = flipper


func can_execute(_card: CardInstance, state: GameState) -> bool:
	var opp: PlayerState = state.players[1 - state.current_player_index]
	for slot: PokemonSlot in opp.get_all_pokemon():
		if not slot.attached_energy.is_empty():
			return true
	return false


func get_preview_interaction_steps(_card: CardInstance, _state: GameState) -> Array[Dictionary]:
	return [{
		"id": "coin_flip_preview",
		"title": "投掷1枚硬币",
		"wait_for_coin_animation": true,
		"preview_only": true,
	}]


func get_interaction_steps(card: CardInstance, state: GameState) -> Array[Dictionary]:
	var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
	_pending_heads = flipper.flip()
	_has_pending_flip = true
	if not _pending_heads:
		return []
	var opp: PlayerState = state.players[1 - card.owner_index]
	var energy_items: Array = []
	var energy_labels: Array[String] = []
	for slot: PokemonSlot in opp.get_all_pokemon():
		for energy: CardInstance in slot.attached_energy:
			energy_items.append(energy)
			energy_labels.append("%s - %s" % [slot.get_pokemon_name(), energy.card_data.name])
	if energy_items.is_empty():
		return []
	return [{
		"id": "target_pokemon",
		"title": "选择对手要弃掉的能量",
		"items": energy_items,
		"labels": energy_labels,
		"card_groups": build_attached_card_groups(opp, energy_items),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"wait_for_coin_animation": true,
	}]


func execute(card: CardInstance, targets: Array, state: GameState) -> void:
	if not _has_pending_flip:
		var flipper: CoinFlipper = _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_heads = flipper.flip()
		_has_pending_flip = true
	if not _pending_heads:
		_has_pending_flip = false
		return

	var opp: PlayerState = state.players[1 - card.owner_index]
	var ctx: Dictionary = get_interaction_context(targets)
	var target_slot: PokemonSlot = null
	var target_energy: CardInstance = null

	var raw: Array = ctx.get("target_pokemon", [])
	if not raw.is_empty():
		if raw[0] is CardInstance:
			var selected_energy := raw[0] as CardInstance
			for slot: PokemonSlot in opp.get_all_pokemon():
				if selected_energy in slot.attached_energy:
					target_slot = slot
					target_energy = selected_energy
					break
		elif raw[0] is PokemonSlot:
			var selected: PokemonSlot = raw[0]
			if selected in opp.get_all_pokemon() and not selected.attached_energy.is_empty():
				target_slot = selected

	if target_slot == null:
		for slot: PokemonSlot in opp.get_all_pokemon():
			if not slot.attached_energy.is_empty():
				target_slot = slot
				break

	if target_slot == null or target_slot.attached_energy.is_empty():
		_has_pending_flip = false
		return

	var energy: CardInstance = target_energy if target_energy != null else target_slot.attached_energy.back()
	target_slot.attached_energy.erase(energy)
	opp.discard_card(energy)
	_has_pending_flip = false


func get_description() -> String:
	return "投币正面：弃掉对手场上宝可梦身上附着的1个能量"
