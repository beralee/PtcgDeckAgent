class_name TestCardImplementationStatus
extends TestBase

const CardImplementationStatusScript := preload("res://scripts/engine/CardImplementationStatus.gd")


func _make_card(card_type: String, effect_id: String = "", description: String = "") -> CardData:
	var card := CardData.new()
	card.name = "Status Probe"
	card.name_en = "Status Probe"
	card.set_code = "UTEST"
	card.card_index = "999"
	card.card_type = card_type
	card.effect_id = effect_id
	card.description = description
	return card


func test_missing_trainer_effect_is_marked_unimplemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var card := _make_card("Item", "missing-effect-id", "Search your deck for a card.")

	return run_checks([
		assert_true(CardImplementationStatusScript.is_unimplemented(card), "Trainer cards with text and missing effect registration should be marked unimplemented"),
		assert_true(CardImplementationStatusScript.get_reason(card) != "", "Unimplemented status should expose a diagnostic reason"),
	])


func test_registered_trainer_effect_is_not_marked_unimplemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var card := _make_card("Item", "1af63a7e2cb7a79215474ad8db8fd8fd", "Search your deck for a Basic Pokemon and put it onto your Bench.")

	return run_checks([
		assert_false(CardImplementationStatusScript.is_unimplemented(card), "Registered trainer effects should not show the unimplemented badge"),
	])


func test_basic_energy_and_vanilla_pokemon_are_not_marked_unimplemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var energy := _make_card("Basic Energy")
	var pokemon := _make_card("Pokemon")
	pokemon.hp = 70
	pokemon.attacks = [{"name": "Tackle", "cost": "C", "damage": "20", "text": ""}]

	return run_checks([
		assert_false(CardImplementationStatusScript.is_unimplemented(energy), "Basic Energy should not be considered an unimplemented effect card"),
		assert_false(CardImplementationStatusScript.is_unimplemented(pokemon), "Pure vanilla Pokemon attacks should not require an effect implementation"),
	])


func test_missing_pokemon_ability_or_attack_effect_is_marked_unimplemented() -> String:
	CardImplementationStatusScript.clear_cache()
	var ability_card := _make_card("Pokemon", "missing-ability-effect")
	ability_card.abilities = [{"name": "Custom Ability", "text": "Draw 1 card."}]
	var attack_card := _make_card("Pokemon", "missing-attack-effect")
	attack_card.attacks = [{"name": "Custom Attack", "cost": "C", "damage": "30+", "text": "This attack does 30 more damage."}]

	return run_checks([
		assert_true(CardImplementationStatusScript.is_unimplemented(ability_card), "Pokemon abilities without registered effects should be marked unimplemented"),
		assert_true(CardImplementationStatusScript.is_unimplemented(attack_card), "Pokemon attacks with rule text or dynamic damage should require an effect implementation"),
	])
