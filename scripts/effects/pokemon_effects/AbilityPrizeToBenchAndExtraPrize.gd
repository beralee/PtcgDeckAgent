class_name AbilityPrizeToBenchAndExtraPrize
extends BaseEffect

var coin_flipper: CoinFlipper = null


func _init(flipper: CoinFlipper = null) -> void:
	coin_flipper = flipper


func resolve_prize_take(card: CardInstance, player: PlayerState, state: GameState) -> Dictionary:
	if card == null or card.card_data == null:
		return {"used": false, "extra_prizes": 0}
	if card not in player.hand:
		return {"used": false, "extra_prizes": 0}
	if not card.is_basic_pokemon() or player.is_bench_full():
		return {"used": false, "extra_prizes": 0}

	player.hand.erase(card)
	var slot: PokemonSlot = PokemonSlot.new()
	slot.pokemon_stack.append(card)
	slot.turn_played = state.turn_number
	player.bench.append(slot)

	var extra_prizes: int = 0
	if coin_flipper != null and coin_flipper.flip():
		extra_prizes = 1

	return {
		"used": true,
		"extra_prizes": extra_prizes,
	}
