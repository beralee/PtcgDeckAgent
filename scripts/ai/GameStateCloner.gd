class_name GameStateCloner
extends RefCounted

## 深拷贝 GameStateMachine，克隆体可独立运行完整对局。
## CardData 共享引用（静态数据），CardInstance 独立拷贝。
## EffectProcessor / RuleValidator / DamageCalculator 共享引用（无状态或仅静态注册表）。


func clone_gsm(original: GameStateMachine) -> GameStateMachine:
	if original == null:
		return null
	var cloned := GameStateMachine.new()
	cloned.rule_validator = original.rule_validator
	cloned.damage_calculator = original.damage_calculator
	cloned.effect_processor = original.effect_processor
	cloned.coin_flipper = CoinFlipper.new()
	cloned.game_state = _clone_game_state(original.game_state)
	var empty_log: Array[GameAction] = []
	cloned.action_log = empty_log
	return cloned


func _clone_game_state(original: GameState) -> GameState:
	if original == null:
		return GameState.new()
	var cloned := GameState.new()
	cloned.current_player_index = original.current_player_index
	cloned.turn_number = original.turn_number
	cloned.first_player_index = original.first_player_index
	cloned.phase = original.phase
	cloned.energy_attached_this_turn = original.energy_attached_this_turn
	cloned.supporter_used_this_turn = original.supporter_used_this_turn
	cloned.stadium_played_this_turn = original.stadium_played_this_turn
	cloned.retreat_used_this_turn = original.retreat_used_this_turn
	cloned.stadium_effect_used_turn = original.stadium_effect_used_turn
	cloned.stadium_effect_used_player = original.stadium_effect_used_player
	cloned.stadium_effect_used_effect_id = original.stadium_effect_used_effect_id
	cloned.vstar_power_used = original.vstar_power_used.duplicate()
	cloned.last_knockout_turn_against = original.last_knockout_turn_against.duplicate()
	cloned.shared_turn_flags = original.shared_turn_flags.duplicate(true)
	cloned.winner_index = original.winner_index
	cloned.win_reason = original.win_reason
	cloned.stadium_card = _clone_card_instance(original.stadium_card)
	cloned.stadium_owner_index = original.stadium_owner_index
	cloned.players.clear()
	for player: PlayerState in original.players:
		cloned.players.append(_clone_player_state(player))
	return cloned


func _clone_player_state(original: PlayerState) -> PlayerState:
	if original == null:
		return PlayerState.new()
	var cloned := PlayerState.new()
	cloned.player_index = original.player_index
	cloned.deck = _clone_card_array(original.deck)
	cloned.hand = _clone_card_array(original.hand)
	cloned.prizes = _clone_card_array(original.prizes)
	cloned.discard_pile = _clone_card_array(original.discard_pile)
	cloned.lost_zone = _clone_card_array(original.lost_zone)
	cloned.active_pokemon = _clone_pokemon_slot(original.active_pokemon)
	cloned.bench.clear()
	for slot: PokemonSlot in original.bench:
		cloned.bench.append(_clone_pokemon_slot(slot))
	cloned.prize_layout.clear()
	for i: int in original.prize_layout.size():
		var prize_variant: Variant = original.prize_layout[i]
		if prize_variant is CardInstance:
			var original_card: CardInstance = prize_variant
			var found: CardInstance = _find_cloned_card_in_array(cloned.prizes, original_card)
			cloned.prize_layout.append(found)
		else:
			cloned.prize_layout.append(null)
	return cloned


func _clone_pokemon_slot(original: PokemonSlot) -> PokemonSlot:
	if original == null:
		return null
	var cloned := PokemonSlot.new()
	cloned.pokemon_stack = _clone_card_array(original.pokemon_stack)
	cloned.attached_energy = _clone_card_array(original.attached_energy)
	cloned.attached_tool = _clone_card_instance(original.attached_tool)
	cloned.damage_counters = original.damage_counters
	cloned.status_conditions = original.status_conditions.duplicate(true)
	cloned.turn_played = original.turn_played
	cloned.turn_evolved = original.turn_evolved
	cloned.effects = original.effects.duplicate(true)
	return cloned


func _clone_card_instance(original: CardInstance) -> CardInstance:
	if original == null:
		return null
	var cloned := CardInstance.new()
	cloned.instance_id = original.instance_id
	cloned.card_data = original.card_data
	cloned.owner_index = original.owner_index
	cloned.face_up = original.face_up
	return cloned


func _clone_card_array(original: Array[CardInstance]) -> Array[CardInstance]:
	var cloned: Array[CardInstance] = []
	for card: CardInstance in original:
		cloned.append(_clone_card_instance(card))
	return cloned


func _clone_card_array_untyped(original: Array) -> Array:
	var cloned: Array = []
	for item: Variant in original:
		if item is CardInstance:
			cloned.append(_clone_card_instance(item))
		else:
			cloned.append(item)
	return cloned


func _find_cloned_card_in_array(cloned_array: Array[CardInstance], original_card: CardInstance) -> CardInstance:
	if original_card == null:
		return null
	for card: CardInstance in cloned_array:
		if card != null and card.instance_id == original_card.instance_id:
			return card
	return null
