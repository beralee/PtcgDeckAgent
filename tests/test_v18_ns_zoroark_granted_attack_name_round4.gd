class_name TestV18NsZoroarkGrantedAttackNameRound4
extends TestBase

const NS_ZOROARK_SCRIPT := preload("res://scripts/ai/DeckStrategyNsZoroark.gd")
const DARK_FAMILY_SCRIPT := preload("res://scripts/ai/DeckStrategyV18DarkCharacterFamily.gd")


func test_ordinary_attack_name_still_recognizes_night_joker() -> String:
	var strategy := NS_ZOROARK_SCRIPT.new()
	var score: float = strategy.call("_score_attack", {
		"kind": "attack",
		"attack_name": "Night Joker",
		"projected_damage": 0,
	}, null, -1)
	return assert_eq(score, -3000.0, "A source-less ordinary Night Joker must be hard-rejected")


func test_granted_attack_name_fallback_recognizes_night_joker() -> String:
	var strategy := NS_ZOROARK_SCRIPT.new()
	var ordinary: float = strategy.call("_score_attack", {
		"kind": "attack",
		"attack_name": "Night Joker",
		"projected_damage": 0,
	}, null, -1)
	var fallback: float = strategy.call("_score_attack", {
		"kind": "granted_attack",
		"attack_name": "",
		"granted_attack_data": {"name": "Night Joker", "damage": "999"},
		"projected_damage": 0,
	}, null, -1)
	return assert_eq(fallback, ordinary, "An empty attack_name should fall back to granted_attack_data.name")


func test_granted_damage_is_not_used_as_copied_damage() -> String:
	var strategy := NS_ZOROARK_SCRIPT.new()
	var score: float = strategy.call("_score_attack", {
		"kind": "granted_attack",
		"attack_name": "",
		"granted_attack_data": {"name": "Night Joker", "damage": "999"},
	}, null, -1)
	return assert_eq(score, -3000.0, "granted_attack_data.damage must not make a source-less Night Joker legal")


func test_night_joker_fallback_does_not_cross_into_sibling_route() -> String:
	var strategy := DARK_FAMILY_SCRIPT.new()
	var state := GameState.new()
	state.players.append(PlayerState.new())
	var score: float = strategy.call("_score_ns_attack", {
		"kind": "granted_attack",
		"attack_name": "",
		"granted_attack_data": {"name": "Night Joker", "damage": "999"},
	}, state, 0, state.players[0], 37.0)
	return assert_eq(score, 37.0, "Night Joker fallback should require an N's Zoroark source slot")
