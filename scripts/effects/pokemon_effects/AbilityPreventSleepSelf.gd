class_name AbilityPreventSleepSelf
extends BaseEffect


func prevents_special_status(_slot: PokemonSlot, _state: GameState = null, status_name: String = "") -> bool:
	return status_name == "asleep"


func get_description() -> String:
	return "This Pokemon cannot be Asleep."
