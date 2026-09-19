extends TestBase


func test_current_boolean_empty_search_choices_validate_for_all_ball_effects() -> String:
	var effects: Array = [
		preload("res://scripts/effects/trainer_effects/EffectNestBall.gd").new(),
		preload("res://scripts/effects/trainer_effects/EffectBuddyPoffin.gd").new(),
		preload("res://scripts/effects/trainer_effects/EffectUltraBall.gd").new(),
	]
	var state := GameState.new()
	state.players = [PlayerState.new(), PlayerState.new()]
	var source := _item("Search")
	var discard := [_item("Cost A"), _item("Cost B")]
	state.players[0].hand.assign([source, discard[0], discard[1]])
	state.players[0].deck.assign([_item("No Pokemon")])
	for effect: BaseEffect in effects:
		for choice: bool in [true, false]:
			var context := {"discard_cards": discard, "empty_search_resolution": [choice]}
			var result := effect.validate_card_interaction(source, [context], state)
			if not bool(result.get("valid", false)):
				return "%s rejects its current boolean choice %s: %s" % [effect.get_script().resource_path, choice, result]
		var invalid := effect.validate_card_interaction(source, [{"discard_cards": discard, "empty_search_resolution": ["unknown"]}], state)
		if bool(invalid.get("valid", false)):
			return "Unknown empty-search choice must remain invalid"
	return ""


func _item(card_name: String) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.card_type = "Item"
	return CardInstance.create(data, 0)
