class_name AttackCoinFlipDiscardOpponentActiveEnergy
extends BaseEffect

const ENERGY_STEP_ID := "discard_opponent_active_energy"

var attack_index_to_match: int = -1
var _coin_flipper: CoinFlipper = null
var _pending_flips: Dictionary = {}


func _init(match_attack_index: int = -1, flipper: CoinFlipper = null) -> void:
	attack_index_to_match = match_attack_index
	_coin_flipper = flipper


func applies_to_attack_index(attack_index: int) -> bool:
	return attack_index_to_match == -1 or attack_index == attack_index_to_match


func _flip_key(card: CardInstance, state: GameState) -> String:
	return "%d:%d:%d" % [state.get_instance_id(), state.turn_number, card.instance_id]


func _heads(card: CardInstance, state: GameState) -> bool:
	var key := _flip_key(card, state)
	if not _pending_flips.has(key):
		var flipper := _coin_flipper if _coin_flipper != null else CoinFlipper.new()
		_pending_flips[key] = flipper.flip()
	return bool(_pending_flips[key])


func build_ucis_attack_preview_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	return [{"id": "coin_preview", "title": "投掷1枚硬币，正面时选择对手战斗宝可梦的1个能量弃置", "preview_only": true, "wait_for_coin_animation": true}]


func build_ucis_attack_interaction_steps_spec_steps(card: CardInstance, attack: Dictionary, state: GameState) -> Array[Dictionary]:
	if card == null or state == null or not applies_to_attack_index(_resolve_attack_index(card, attack)):
		return []
	if not _heads(card, state):
		return []
	var opponent: PlayerState = state.players[1 - card.owner_index]
	var active: PokemonSlot = opponent.active_pokemon
	if active == null or active.attached_energy.is_empty():
		return []
	var labels: Array[String] = []
	for energy: CardInstance in active.attached_energy:
		labels.append(energy.card_data.name if energy.card_data != null else "")
	return [{
		"id": ENERGY_STEP_ID,
		"title": "投币结果：正面。选择对手战斗宝可梦身上的1个能量弃置",
		"items": active.attached_energy.duplicate(),
		"labels": labels,
		"card_groups": build_attached_card_groups(opponent, active.attached_energy),
		"transparent_battlefield_dialog": true,
		"min_select": 1,
		"max_select": 1,
		"allow_cancel": false,
		"wait_for_coin_animation": true,
		"ucis_select_type_name": "ATTACHED_CARD",
		"ucis_context_name": "DISCARD_ENERGY_CARD",
	}]


func validate_attack_preflight(attacker: PokemonSlot, attack_index: int, targets: Array, state: GameState) -> Dictionary:
	if not applies_to_attack_index(attack_index):
		return interaction_validation_ok()
	var context := get_interaction_context(targets)
	if not context.has(ENERGY_STEP_ID):
		return interaction_validation_ok()
	var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
	var candidates: Array = defender.attached_energy if defender != null else []
	return validate_context_selection(context, ENERGY_STEP_ID, candidates, 0, 1)


func validate_attack_interaction(attacker: PokemonSlot, attack_index: int, targets: Array, state: GameState) -> Dictionary:
	if not applies_to_attack_index(attack_index):
		return interaction_validation_ok()
	var preflight := validate_attack_preflight(attacker, attack_index, targets, state)
	if not bool(preflight.get("valid", false)):
		return preflight
	var heads := _heads(attacker.get_top_card(), state)
	var defender := state.players[1 - attacker.get_top_card().owner_index].active_pokemon
	if not heads or defender == null or defender.attached_energy.is_empty():
		return interaction_validation_ok()
	return validate_context_selection(get_interaction_context(targets), ENERGY_STEP_ID, defender.attached_energy, 1, 1)


func execute_attack(attacker: PokemonSlot, _defender: PokemonSlot, attack_index: int, state: GameState) -> void:
	if attacker == null or state == null or not applies_to_attack_index(attack_index):
		return
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	if not bool(validate_attack_interaction(attacker, attack_index, [get_attack_interaction_context()], state).get("valid", false)):
		return
	var heads := _heads(top, state)
	_pending_flips.erase(_flip_key(top, state))
	if not heads:
		return

	var opponent: PlayerState = state.players[1 - top.owner_index]
	var active: PokemonSlot = opponent.active_pokemon
	if active == null or active.attached_energy.is_empty():
		return

	var processor: EffectProcessor = state.shared_turn_flags.get("_draw_effect_processor")
	if processor != null and processor.is_attack_effect_prevented_by_defender_ability(attacker, active, state):
		return
	if processor == null and AttackCoinFlipPreventDamageAndEffectsNextTurn.prevents_attack_effects(active, state):
		return
	# Validation binds exactly one current physical card; never substitute the first Energy.
	var energy: CardInstance = get_attack_interaction_context()[ENERGY_STEP_ID][0]
	active.attached_energy.erase(energy)
	opponent.discard_card(energy)


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
	return "Flip a coin. If heads, discard an Energy from the opponent Active Pokemon."
