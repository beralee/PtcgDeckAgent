class_name AttackCoinFlipApplyStatus
extends BaseEffect

var status_name: String = "confused"
var coin_flipper: CoinFlipper


func _init(status: String = "confused", flipper: CoinFlipper = null) -> void:
	status_name = status
	coin_flipper = flipper if flipper != null else CoinFlipper.new()


func execute_attack(
	attacker: PokemonSlot,
	defender: PokemonSlot,
	_attack_index: int,
	state: GameState
) -> void:
	# 薄雾能量免疫对手招式效果
	if defender != null and EffectMistEnergy.has_mist_energy(defender):
		return
	var processor: Variant = state.shared_turn_flags.get("_draw_effect_processor", null) if state != null else null
	if processor != null and processor.has_method("is_attack_effect_prevented_by_defender_ability"):
		if bool(processor.call("is_attack_effect_prevented_by_defender_ability", attacker, defender, state)):
			return
	if coin_flipper.flip():
		_apply_special_status(defender, status_name, state)


func get_description() -> String:
	return "Flip a coin. If heads, apply %s." % status_name
