class_name EffectHealAllPokemon
extends BaseEffect

var heal_amount: int = 30


func _init(amount: int = 30) -> void:
	heal_amount = max(0, amount)


func execute(_card: CardInstance, _targets: Array, state: GameState) -> void:
	if state == null or heal_amount <= 0:
		return
	for player: PlayerState in state.players:
		_heal_slot(player.active_pokemon, state)
		for slot: PokemonSlot in player.bench:
			_heal_slot(slot, state)


func _heal_slot(slot: PokemonSlot, state: GameState) -> void:
	if slot == null:
		return
	slot.heal(heal_amount, state)


func get_description() -> String:
	return "Heal %d damage from each Pokemon in play." % heal_amount
