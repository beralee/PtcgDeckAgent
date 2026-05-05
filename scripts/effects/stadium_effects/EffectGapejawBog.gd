class_name EffectGapejawBog
extends BaseEffect

var damage_counters: int = 20


func on_basic_pokemon_played_to_bench_from_hand(slot: PokemonSlot, _player_index: int, _state: GameState) -> void:
	if slot == null or slot.get_top_card() == null:
		return
	var card_data: CardData = slot.get_card_data()
	if card_data == null or not card_data.is_basic_pokemon():
		return
	slot.damage_counters += damage_counters


func get_description() -> String:
	return "Whenever either player plays a Basic Pokemon from hand to their Bench, put 2 damage counters on that Pokemon."
