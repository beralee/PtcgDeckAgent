class_name TestV18TordContractBridgeRound2
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")

const DECK_ID := 800015934
const RULES_PATH := "res://scripts/ai/DeckStrategyV18Rules.gd"
const DELEGATE_PATH := "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd"
const NOCTOWL_ID := "CSV9C_155"


func test_post_jewel_active_noctowl_routes_all_contract_targets_to_ready_terapagos() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var noctowl := _evolved_noctowl()
	var terapagos := _slot("CSV9C", "175")
	if strategy == null or noctowl == null or terapagos == null:
		return assert_true(false, "Tord production wrapper and post-Jewel fixtures should load")
	terapagos.attached_energy = [_basic_energy("Grass Energy", "G"), _basic_energy("Water Energy", "W")]
	state.players[0].active_pokemon = noctowl
	state.players[0].bench = [terapagos]

	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var owner: Dictionary = plan.get("owner", {})
	var targets: Dictionary = plan.get("targets", {})
	var terapagos_name := _primary_name(terapagos)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Deck 800015934 must resolve through the production V18Rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "The production wrapper must use the TeraNoctowl delegate"),
		assert_false(bool((plan.get("flags", {}) as Dictionary).get("noctowl_jewel_search_live", true)), "Post-Jewel state must clear Jewel Search debt"),
		assert_eq(str(owner.get("turn_owner_name", "")), terapagos_name, "Ready Terapagos must own the post-Jewel turn"),
		assert_eq(str(owner.get("bridge_target_name", "")), terapagos_name, "Post-Jewel owner bridge must leave Active Noctowl for ready Terapagos"),
		assert_eq(str(owner.get("pivot_target_name", "")), terapagos_name, "Post-Jewel pivot must promote ready Terapagos"),
		assert_eq(str(targets.get("primary_attacker_name", "")), terapagos_name, "Merged primary target must match the real attack owner"),
		assert_eq(str(targets.get("bridge_target_name", "")), terapagos_name, "Merged bridge target must not retain the spent Noctowl bridge"),
		assert_eq(str(targets.get("pivot_target_name", "")), terapagos_name, "Merged pivot target must promote ready Terapagos"),
	])


func test_jewel_live_keeps_noctowl_bridge_while_terapagos_owns_the_attack_route() -> String:
	var strategy := _production_strategy()
	var state := _state()
	var hoothoot := _slot("CSV9C", "154")
	var terapagos := _slot("CSV9C", "175")
	var noctowl := _card("CSV9C", "155")
	if strategy == null or hoothoot == null or terapagos == null or noctowl == null:
		return assert_true(false, "Tord production wrapper and live Jewel Search fixtures should load")
	hoothoot.turn_played = 1
	terapagos.attached_energy = [_basic_energy("Grass Energy", "G"), _basic_energy("Water Energy", "W")]
	state.players[0].active_pokemon = hoothoot
	state.players[0].bench = [terapagos]
	state.players[0].hand = [noctowl]

	var plan: Dictionary = strategy.call("build_turn_plan", state, 0, {})
	var owner: Dictionary = plan.get("owner", {})
	var targets: Dictionary = plan.get("targets", {})
	var terapagos_name := _primary_name(terapagos)
	return run_checks([
		assert_eq(strategy.get_script().resource_path, RULES_PATH, "Jewel-live contract must run through the production V18Rules wrapper"),
		assert_eq(_delegate_path(strategy), DELEGATE_PATH, "Jewel-live contract must run through the TeraNoctowl delegate"),
		assert_true(bool((plan.get("flags", {}) as Dictionary).get("noctowl_jewel_search_live", false)), "A Tera board plus mature Hoothoot and hand Noctowl must keep Jewel Search live"),
		assert_eq(str(owner.get("turn_owner_name", "")), terapagos_name, "Ready Terapagos remains the real attack owner during Jewel Search"),
		assert_eq(str(owner.get("bridge_target_name", "")), NOCTOWL_ID, "Live Jewel Search must keep Noctowl as the owner bridge"),
		assert_eq(str(owner.get("pivot_target_name", "")), terapagos_name, "Live Jewel Search must still pivot toward the ready attacker"),
		assert_eq(str(targets.get("primary_attacker_name", "")), terapagos_name, "Merged primary target must remain the real attack owner"),
		assert_eq(str(targets.get("bridge_target_name", "")), NOCTOWL_ID, "Merged bridge target must retain Noctowl while Jewel Search is live"),
		assert_eq(str(targets.get("pivot_target_name", "")), terapagos_name, "Merged pivot target must remain the real attack owner"),
	])


func _production_strategy() -> RefCounted:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/bundled_user/decks/%d.json" % DECK_ID
	))
	if not parsed is Dictionary:
		return null
	return REGISTRY_SCRIPT.new().call("resolve_strategy_for_deck", DeckData.from_dict(parsed))


func _state() -> GameState:
	var state := GameState.new()
	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 3
	state.phase = GameState.GamePhase.MAIN
	return state


func _card(set_code: String, card_index: String) -> CardInstance:
	var data := CardDatabase.get_card(set_code, card_index)
	return CardInstance.create(data, 0) if data != null else null


func _slot(set_code: String, card_index: String) -> PokemonSlot:
	var card := _card(set_code, card_index)
	if card == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _evolved_noctowl() -> PokemonSlot:
	var hoothoot := _card("CSV9C", "154")
	var noctowl := _card("CSV9C", "155")
	if hoothoot == null or noctowl == null:
		return null
	var slot := PokemonSlot.new()
	slot.pokemon_stack = [hoothoot, noctowl]
	return slot


func _basic_energy(card_name: String, symbol: String) -> CardInstance:
	var data := CardData.new()
	data.name = card_name
	data.name_en = card_name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	return CardInstance.create(data, 0)


func _primary_name(slot: PokemonSlot) -> String:
	var data := slot.get_card_data()
	return str(data.name_en) if str(data.name_en) != "" else str(data.name)


func _delegate_path(strategy: RefCounted) -> String:
	var delegate: RefCounted = strategy.get("_delegate") if strategy != null else null
	return delegate.get_script().resource_path if delegate != null else ""
