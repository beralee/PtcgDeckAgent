class_name AttackItemLockNextTurn
extends BaseEffect

const ITEM_LOCK_PREFIX := "item_lock_"

var require_heads: bool = false
var coin_flipper: CoinFlipper


func _init(needs_heads: bool = false, flipper: CoinFlipper = null) -> void:
	require_heads = needs_heads
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func execute_attack(
	attacker: PokemonSlot,
	_defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	var top: CardInstance = attacker.get_top_card()
	if top == null:
		return
	if require_heads and not coin_flipper.flip():
		return

	var opponent_index: int = 1 - top.owner_index
	state.shared_turn_flags["%s%d" % [ITEM_LOCK_PREFIX, opponent_index]] = state.turn_number + 1


func get_description() -> String:
	if require_heads:
		return "Flip a coin. If heads, your opponent cannot play Item cards from hand during their next turn."
	return "Your opponent cannot play Item cards from hand during their next turn."
