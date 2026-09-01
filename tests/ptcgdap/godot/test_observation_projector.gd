class_name TestObservationProjector
extends TestBase

const ProjectorScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const CursorScript = preload("res://scripts/ai/ptcgdap/public/GodotLogCursor.gd")
const SerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const GameStateScript = preload("res://scripts/data/GameState.gd")
const PlayerStateScript = preload("res://scripts/data/PlayerState.gd")
const PokemonSlotScript = preload("res://scripts/data/PokemonSlot.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const CardDataScript = preload("res://scripts/data/CardData.gd")
const VECTOR_PATH := "res://contracts/ptcgdap/godot_observation_projector_conformance_vectors.json"
const EXPECTED_PROJECTOR_HASH := "C51EA4CF1AEFCBB5B9C6D83825FF3A717CCDCC4105B804210BF6169372619041"


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _vectors() -> Dictionary:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(VECTOR_PATH))
	var value: Variant = parsed.get("value")
	return value if value is Dictionary else {}


func test_default_projector_loads_fixed_contract() -> String:
	var projector: Variant = ProjectorScript.load_default()
	if projector == null or not projector.ok:
		return "projector failed to load: %s stage=%s" % [("null" if projector == null else projector.error_code), ("null" if projector == null else projector.get("_load_stage"))]
	if projector.contract_hash != EXPECTED_PROJECTOR_HASH or not projector.validate_integrity():
		return "projector trust anchor mismatch"
	return ""


func test_shared_w1_through_w7_projection_vectors() -> String:
	var vectors := _vectors()
	var cases: Array = vectors.get("projection_cases", [])
	if cases.size() != 7:
		return "projection vector count differs"
	var windows := {}
	var projector: Variant = ProjectorScript.load_default()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		windows[case.get("window")] = true
		var result: Variant = projector.project_conformance_case(vectors, case)
		if not result.accepted:
			return "%s unexpectedly rejected: %s" % [case.get("case_id"), result.error_code]
		if not result.validate_integrity(projector):
			return "%s result integrity failed" % case.get("case_id")
		if result.to_conformance_summary() != case.get("expected_result"):
			return "%s result differs" % case.get("case_id")
		var cursor: Variant = CursorScript.load_default()
		var log_slice: Variant = cursor.peek(result.firewall_result)
		if log_slice == null or log_slice.status != "slice_ready":
			return "%s logs were not accepted by the unchanged cursor" % case.get("case_id")
		if log_slice.logs != result.observation.get("logs") or not log_slice.validate_integrity(cursor):
			return "%s cursor slice differs or failed integrity" % case.get("case_id")
		if cursor.commit(log_slice).status != "committed":
			return "%s cursor slice did not commit" % case.get("case_id")
		var serialized := JSON.stringify(result.to_public_dict())
		for forbidden: String in ["search_begin_input", "host_pokemon_entity_serial", "instance_id", "object_id", "private_sentinel"]:
			if serialized.contains(forbidden):
				return "%s leaked %s" % [case.get("case_id"), forbidden]
	if windows.keys().size() != 7:
		return "W1-W7 coverage differs"
	return ""


func _card_fixture(path: String, owner: int) -> Dictionary:
	var source_bytes := _read_bytes(path)
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(source_bytes)
	if not bool(parsed.get("ok", false)) or not parsed.get("value") is Dictionary:
		return {"ok": false, "error": "source parse failed: %s" % path}
	var data: Variant = CardDataScript.from_dict(parsed.get("value"))
	var card: Variant = CardInstanceScript.create(data, owner)
	var key := ProjectorScript.source_document_key(data.set_code, data.card_index)
	return {"ok": true, "card": card, "bytes": source_bytes, "key": key}


func _engine_fixture() -> Dictionary:
	var specs := {
		"p0_active": ["res://data/bundled_user/cards/LEN_DRI_134.json", 0],
		"p0_energy": ["res://data/bundled_user/cards/CSVE1C_DAR.json", 0],
		"p0_hand": ["res://data/bundled_user/cards/LEN_DRI_135.json", 0],
		"p0_discard": ["res://data/bundled_user/cards/CSV8C_183.json", 0],
		"p0_deck_hidden": ["res://data/bundled_user/cards/CSV8C_173.json", 0],
		"p0_prize_hidden": ["res://data/bundled_user/cards/CSV8C_094.json", 0],
		"p1_active": ["res://data/bundled_user/cards/LEN_DRI_134.json", 1],
		"p1_bench": ["res://data/bundled_user/cards/CSV7C_059.json", 1],
		"p1_hand_hidden": ["res://data/bundled_user/cards/LEN_DRI_169.json", 1],
		"p1_deck_hidden": ["res://data/bundled_user/cards/CSV8C_173.json", 1],
		"p1_prize_hidden": ["res://data/bundled_user/cards/CSV8C_094.json", 1],
	}
	var cards := {}
	var sources := {}
	for label: String in specs:
		var spec: Array = specs[label]
		var created := _card_fixture(spec[0], spec[1])
		if not bool(created.get("ok", false)):
			return created
		cards[label] = created.get("card")
		sources[created.get("key")] = created.get("bytes")

	var p0: Variant = PlayerStateScript.new()
	var p1: Variant = PlayerStateScript.new()
	p0.player_index = 0
	p1.player_index = 1
	var p0_active: Variant = PokemonSlotScript.new()
	var p1_active: Variant = PokemonSlotScript.new()
	var p1_bench: Variant = PokemonSlotScript.new()
	p0_active.pokemon_stack.append(cards["p0_active"])
	p0_active.attached_energy.append(cards["p0_energy"])
	p0_active.turn_played = 1
	p1_active.pokemon_stack.append(cards["p1_active"])
	p1_active.damage_counters = 10
	p1_bench.pokemon_stack.append(cards["p1_bench"])
	p0.active_pokemon = p0_active
	p1.active_pokemon = p1_active
	p1.bench.append(p1_bench)
	p0.hand.append(cards["p0_hand"])
	p0.discard_pile.append(cards["p0_discard"])
	p0.deck.append(cards["p0_deck_hidden"])
	p0.prizes.append(cards["p0_prize_hidden"])
	p1.hand.append(cards["p1_hand_hidden"])
	p1.deck.append(cards["p1_deck_hidden"])
	p1.prizes.append(cards["p1_prize_hidden"])

	var state: Variant = GameStateScript.new()
	state.players.append(p0)
	state.players.append(p1)
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 2
	state.phase = GameStateScript.GamePhase.MAIN
	state.energy_attached_this_turn = true
	state.winner_index = -1

	var registry: Variant = SerialRegistryScript.new()
	var all_cards := []
	for label: String in cards:
		all_cards.append(cards[label])
	for card: Variant in all_cards:
		var registration: Dictionary = registry.register_card(card, card.owner_index)
		if not bool(registration.get("ok", false)):
			return {"ok": false, "error": "registry registration failed: %s" % registration.get("code")}
	var seal: Dictionary = registry.seal_card_inventory([6, 5])
	if not bool(seal.get("ok", false)):
		return {"ok": false, "error": "registry seal failed: %s" % seal.get("code")}
	for pair: Array in [[p0_active, 0], [p1_active, 1], [p1_bench, 1]]:
		var entity: Dictionary = registry.begin_pokemon_entity(pair[0], pair[1])
		if not bool(entity.get("ok", false)):
			return {"ok": false, "error": "entity registration failed: %s" % entity.get("code")}
	return {
		"ok": true,
		"state": state,
		"registry": registry,
		"cards": cards,
		"sources": sources,
	}


func _main_engine_decision() -> Dictionary:
	return {
		"select": {
			"type": 0,
			"context": 0,
			"minCount": 1,
			"maxCount": 1,
			"remainDamageCounter": 0,
			"remainEnergyCost": 0,
			"option": [
				{"type": 7, "index": 0},
				{"type": 13, "local_attack_index": 0},
				{"type": 14},
			],
			"deck": null,
			"contextCard": null,
			"effect": null,
		},
		"deck_cards": null,
		"context_card": null,
		"effect_card": null,
		"option_card_refs": [null, null, null],
		"turn_action_count": 3,
	}


func test_real_engine_shadow_capture_is_source_attested_and_hidden_safe() -> String:
	var fixture := _engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var decision := _main_engine_decision()
	var events := [{"kind": "attack", "card_ref": fixture.get("cards")["p0_active"], "local_attack_index": 0}]
	var result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), decision, events, fixture.get("sources"), 3, 600
	)
	if not result.accepted or result.error_code != "":
		return "engine capture rejected: %s stage=%s" % [result.error_code, projector.get("_capture_stage")]
	if not result.validate_integrity(projector):
		return "engine capture integrity failed"
	var serialized: Dictionary = result.to_public_dict()
	if serialized.get("audit", {}).get("authority") != "engine_attested_shadow":
		return "engine audit authority differs"
	var observation: Dictionary = serialized.get("observation")
	var players: Array = observation.get("current", {}).get("players", [])
	if players.size() != 2 or players[1].get("hand") != null or players[1].get("handCount") != 1:
		return "opponent hand visibility differs"
	if players[0].get("deckCount") != 1 or players[0].get("prize") != [null]:
		return "hidden deck or prize projection differs"
	var registry_card: Dictionary = fixture.get("registry").lookup_card(
		fixture.get("cards")["p0_active"], fixture.get("registry").get_match_generation(), 0
	)
	if players[0].get("active", [])[0].get("serial") != registry_card.get("serial"):
		return "wire Pokemon serial did not use top physical card serial"
	var text := JSON.stringify(serialized)
	for hidden_id: int in [1080, 112, 1259]:
		if text.contains('"id":%d' % hidden_id):
			return "hidden card identity leaked: %d" % hidden_id
	if text.contains("host_pokemon_entity"):
		return "Host-private entity domain leaked"
	return ""


func test_engine_capture_rejects_self_reported_identity_legacy_events_and_source_drift() -> String:
	var fixture := _engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var self_reported := _main_engine_decision()
	self_reported["select"]["type"] = 5
	self_reported["select"]["context"] = 34
	self_reported["select"]["option"] = [{"type": 15, "cardId": 7, "serial": 999}]
	self_reported["option_card_refs"] = [fixture.get("cards")["p0_energy"]]
	var self_result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), self_reported, [], fixture.get("sources")
	)
	if self_result.accepted or self_result.error_code != "invalid_decision":
		return "self-reported skill identity was not rejected: %s stage=%s" % [self_result.error_code, projector.get("_capture_stage")]
	var legacy_event := [{"kind": "play", "card": {"id": 646, "serial": 1, "playerIndex": 0}}]
	var legacy_result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), _main_engine_decision(), legacy_event, fixture.get("sources")
	)
	if legacy_result.accepted or legacy_result.error_code != "invalid_public_event":
		return "legacy serialized event gained authority"
	var changed_sources: Dictionary = fixture.get("sources").duplicate(true)
	var active_card: Variant = fixture.get("cards")["p0_active"]
	var active_key := ProjectorScript.source_document_key(active_card.card_data.set_code, active_card.card_data.card_index)
	var changed: PackedByteArray = changed_sources[active_key].duplicate()
	changed[changed.size() - 1] = 32
	changed_sources[active_key] = changed
	var source_result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), _main_engine_decision(), [], changed_sources
	)
	if source_result.accepted or source_result.error_code != "card_catalog_unmapped":
		return "changed source bytes retained authority"
	return ""


func test_engine_capture_accepts_official_skill_zero_zero_sentinel() -> String:
	var fixture := _engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var decision := _main_engine_decision()
	decision["select"]["type"] = 5
	decision["select"]["context"] = 34
	decision["select"]["option"] = [{"type": 15, "cardId": 0, "serial": 0}]
	decision["option_card_refs"] = [null]
	var result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), decision, [], fixture.get("sources")
	)
	if not result.accepted:
		return "official SKILL(0,0) rejected: %s stage=%s" % [result.error_code, projector.get("_capture_stage")]
	var options: Array = result.observation.get("select", {}).get("option", [])
	if options != [{"type": 15, "cardId": 0, "serial": 0}]:
		return "official SKILL(0,0) sparse wire changed"
	return ""


func test_engine_result_rebinds_live_state_and_registry() -> String:
	var fixture := _engine_fixture()
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var projector: Variant = ProjectorScript.load_default()
	var result: Variant = projector.capture_engine(
		fixture.get("state"), fixture.get("registry"), _main_engine_decision(), [], fixture.get("sources")
	)
	if not result.accepted or not result.validate_integrity(projector):
		return "baseline engine result failed: %s stage=%s" % [result.error_code, projector.get("_capture_stage")]
	fixture.get("state").supporter_used_this_turn = true
	if result.validate_integrity(projector) or not result.to_public_dict().is_empty():
		return "mutated engine state retained result authority"
	fixture.get("state").supporter_used_this_turn = false
	fixture.get("registry").close_match()
	if result.validate_integrity(projector):
		return "closed registry retained result authority"
	return ""


func test_shared_rejections_are_closed_and_non_echoing() -> String:
	var vectors := _vectors()
	var cases: Array = vectors.get("rejection_cases", [])
	if cases.size() != 8:
		return "rejection vector count differs"
	var projector: Variant = ProjectorScript.load_default()
	for case_value: Variant in cases:
		var case: Dictionary = case_value
		var result: Variant = projector.project_conformance_case(vectors, case)
		if not result.validate_integrity(projector):
			return "%s rejection integrity failed" % case.get("case_id")
		if result.to_conformance_summary() != case.get("expected_result"):
			return "%s rejection differs" % case.get("case_id")
		if JSON.stringify(result.to_public_dict()).contains("private_sentinel"):
			return "%s rejection echoed private value" % case.get("case_id")
	return ""


func test_copied_and_mutated_results_never_grant_authority() -> String:
	var vectors := _vectors()
	var projector: Variant = ProjectorScript.load_default()
	var result: Variant = projector.project_conformance_case(vectors, vectors.get("projection_cases", [])[0])
	if projector.accept_projector_result(result.to_public_dict()):
		return "copied result granted owner authority"
	result.set("_public_observation_hash", "F".repeat(64))
	if result.validate_integrity(projector):
		return "mutated result retained integrity"
	if not result.to_public_dict().is_empty():
		return "mutated result serialized authority"
	return ""


func test_runtime_has_no_live_consumer_or_legacy_log_authority() -> String:
	var source := FileAccess.get_file_as_string("res://scripts/ai/ptcgdap/host/godot/GodotObservationProjector.gd")
	for forbidden: String in ["AIOpponent", "BattleScene", "HeadlessMatchBridge", "GameAction.data", "description", "instance_id", "get_instance_id", "HTTPRequest", "HTTPClient", "FileAccess.WRITE"]:
		if source.contains(forbidden):
			return "projector contains forbidden runtime marker %s" % forbidden
	return ""
