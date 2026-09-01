class_name TestAuthorStrategyLiveSeam
extends TestBase

const SEAM_PATH := "res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd"
const PROFILE_PATH := "res://contracts/ptcgdap/author_strategy_live_seam_profile.json"
const SeamScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorLiveSeam.gd")
const PromptSourceScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategyLivePromptSource.gd")
const SourceDocumentsScript = preload("res://scripts/ai/ptcgdap/host/godot/AuthorStrategySourceDocuments.gd")
const LoaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageLoader.gd")
const DeckGateScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyDeckGate.gd")
const HandleScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const HostScript = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorMatchHost.gd")
const FirewallScript = preload("res://scripts/ai/ptcgdap/public/PublicObservationFirewall.gd")
const SerialRegistryScript = preload("res://scripts/ai/ptcgdap/host/godot/GodotSerialRegistry.gd")
const GameStateMachineScript = preload("res://scripts/engine/GameStateMachine.gd")
const GameStateScript = preload("res://scripts/data/GameState.gd")
const PlayerStateScript = preload("res://scripts/data/PlayerState.gd")
const CardDataScript = preload("res://scripts/data/CardData.gd")
const CardInstanceScript = preload("res://scripts/data/CardInstance.gd")
const FIXTURE_PATH := "res://tests/ptcgdap/fixtures/author_strategy_packages/as_wp4/00-exact-mapped-shadow.ptcgai"
const MARNIE_PACKAGE_PATH := (
	"res://data/ptcgdap/author_strategy_packages/"
	+ "ptcgdap-author-strategy-release-candidate.ptcgai"
)
const CARD_PATH := "res://data/bundled_user/cards/LEN_DRI_134.json"
const MARNIE_CARD_PATH := "res://data/bundled_user/cards/CSV8C_094.json"

var _handle_templates := {}


func test_w1_live_seam_module_and_contract_are_loadable() -> String:
	var script: GDScript = load(SEAM_PATH)
	if script == null:
		return "AS-WP5 live seam module is missing"
	var seam: Variant = script.new()
	if seam == null or not seam.has_method("validate_integrity") or not seam.validate_integrity():
		return "AS-WP5 live seam contract failed to load"
	return ""


func test_w1_canary_exposes_no_player_package_authority() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if not parsed is Dictionary:
		return "AS-WP5 profile is missing"
	if parsed.get("enabled_prompt_families") != ["W1"]:
		return "AS-WP5 enabled more than W1"
	if bool(parsed.get("trust_scope", {}).get("player_package_execution", true)):
		return "development canary granted player package authority"
	return ""


func _read_bytes(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_buffer(file.get_length()) if file != null else PackedByteArray()


func _host(match_id: String) -> Dictionary:
	var requested: Dictionary = _fresh_handle(FIXTURE_PATH)
	if not bool(requested.get("ok", false)):
		return {"ok": false, "error": "fixture handle rejected: %s" % requested.get("error_code")}
	var built: Dictionary = HostScript.create(requested.get("handle"), match_id)
	return {"ok": true, "host": built.get("host")} if bool(built.get("ok", false)) else {"ok": false, "error": "host rejected: %s" % built.get("error_code")}


func _marnie_host(match_id: String) -> Dictionary:
	var requested: Dictionary = _fresh_handle(MARNIE_PACKAGE_PATH)
	if not bool(requested.get("ok", false)):
		return {"ok": false, "error": "Marnie handle rejected: %s" % requested.get("error_code")}
	var built: Dictionary = HostScript.create(requested.get("handle"), match_id)
	return {"ok": true, "host": built.get("host")} if bool(built.get("ok", false)) else {"ok": false, "error": "Marnie host rejected: %s" % built.get("error_code")}


func _fresh_handle(path: String) -> Dictionary:
	if not _handle_templates.has(path):
		var captured := _read_bytes(path)
		if captured.is_empty():
			return {"ok": false, "error_code": "package_file_missing"}
		var loader := LoaderScript.new()
		var inspected: Dictionary = loader.inspect_match_bytes(captured, _sha(captured))
		if not bool(inspected.get("ok", false)):
			return inspected
		var gated: Dictionary = DeckGateScript.build(inspected.get("payloads", {}))
		if not bool(gated.get("ok", false)):
			return gated
		_handle_templates[path] = {
			"metadata": inspected.get("metadata", {}).duplicate(true),
			"payloads": inspected.get("payloads", {}).duplicate(true),
			"local_deck": gated.get("local_deck", []).duplicate(true),
		}
	var template: Dictionary = _handle_templates[path]
	return HandleScript.create(
		template.get("metadata", {}).duplicate(true),
		template.get("payloads", {}).duplicate(true),
		template.get("local_deck", []).duplicate(true),
	)


static func _sha(source: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(source) != OK:
		return ""
	return context.finish().hex_encode().to_upper()


func _card(owner: int) -> Variant:
	return _card_from_path(CARD_PATH, owner)


func _card_from_path(path: String, owner: int) -> Variant:
	var parsed: Dictionary = FirewallScript._parse_contract_json_bytes(_read_bytes(path))
	if not bool(parsed.get("ok", false)):
		return null
	var data: Variant = CardDataScript.from_dict(parsed.get("value"))
	return CardInstanceScript.create(data, owner)


func _local_marnie_fixture(match_id: String) -> Dictionary:
	var p0 := PlayerStateScript.new()
	var p1 := PlayerStateScript.new()
	p0.player_index = 0
	p1.player_index = 1
	var hidden: Variant = _card_from_path(MARNIE_CARD_PATH, 0)
	var first: Variant = _card_from_path(MARNIE_CARD_PATH, 1)
	var second: Variant = _card_from_path(MARNIE_CARD_PATH, 1)
	if hidden == null or first == null or second == null:
		return {"ok": false, "error": "Marnie card fixture failed"}
	p0.hand.append(hidden)
	p1.hand.append(first)
	p1.hand.append(second)
	var state := GameStateScript.new()
	state.players = [p0, p1]
	state.phase = GameStateScript.GamePhase.SETUP
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 0
	var gsm := GameStateMachineScript.new()
	gsm.game_state = state
	var registry := SerialRegistryScript.new()
	for card: Variant in [hidden, first, second]:
		var registered: Dictionary = registry.register_card(card, card.owner_index)
		if not bool(registered.get("ok", false)):
			return {"ok": false, "error": "Marnie registry failed: %s" % registered.get("code")}
	var sealed: Dictionary = registry.seal_card_inventory([1, 2])
	if not bool(sealed.get("ok", false)):
		return {"ok": false, "error": "Marnie seal failed: %s" % sealed.get("code")}
	var documents: Dictionary = SourceDocumentsScript.load_for_cards([first, second])
	if not bool(documents.get("ok", false)):
		return {"ok": false, "error": "Marnie documents failed: %s" % documents.get("error_code")}
	var source: Dictionary = PromptSourceScript.create_setup_active(
		gsm, registry, documents.get("source_documents"), 1,
		p1.get_basic_pokemon_in_hand(), 1, [], true
	)
	if not bool(source.get("ok", false)):
		return {"ok": false, "error": "Marnie local source failed: %s" % source.get("error_code")}
	var host_result := _marnie_host(match_id)
	if not bool(host_result.get("ok", false)):
		return host_result
	var seam: Dictionary = SeamScript.create(host_result.get("host"), registry.get_match_generation(), "session:%s" % match_id)
	if not bool(seam.get("ok", false)):
		return {"ok": false, "error": "Marnie seam failed: %s" % seam.get("error_code")}
	return {
		"ok": true, "gsm": gsm, "registry": registry, "player": p1,
		"first": first, "second": second, "source": source.get("source"),
		"seam": seam.get("seam"),
	}


func _fixture(match_id: String) -> Dictionary:
	var p0 := PlayerStateScript.new()
	var p1 := PlayerStateScript.new()
	p0.player_index = 0
	p1.player_index = 1
	var hidden: Variant = _card(0)
	var first: Variant = _card(1)
	var second: Variant = _card(1)
	if hidden == null or first == null or second == null:
		return {"ok": false, "error": "card fixture failed"}
	p0.hand.append(hidden)
	p1.hand.append(first)
	p1.hand.append(second)
	var state := GameStateScript.new()
	state.players = [p0, p1]
	state.phase = GameStateScript.GamePhase.SETUP
	state.current_player_index = 0
	state.first_player_index = 0
	state.turn_number = 0
	var gsm := GameStateMachineScript.new()
	gsm.game_state = state
	var registry := SerialRegistryScript.new()
	for card: Variant in [hidden, first, second]:
		var registered: Dictionary = registry.register_card(card, card.owner_index)
		if not bool(registered.get("ok", false)):
			return {"ok": false, "error": "registry failed: %s" % registered.get("code")}
	var sealed: Dictionary = registry.seal_card_inventory([1, 2])
	if not bool(sealed.get("ok", false)):
		return {"ok": false, "error": "seal failed: %s" % sealed.get("code")}
	var documents: Dictionary = SourceDocumentsScript.load_for_cards([first, second])
	if not bool(documents.get("ok", false)):
		return {"ok": false, "error": "documents failed: %s" % documents.get("error_code")}
	var source: Dictionary = PromptSourceScript.create_setup_active(
		gsm, registry, documents.get("source_documents"), 1,
		p1.get_basic_pokemon_in_hand(), 1, []
	)
	if not bool(source.get("ok", false)):
		return {"ok": false, "error": "source failed: %s" % source.get("error_code")}
	var host_result := _host(match_id)
	if not bool(host_result.get("ok", false)):
		return host_result
	var seam: Dictionary = SeamScript.create(host_result.get("host"), registry.get_match_generation(), "session:%s" % match_id)
	if not bool(seam.get("ok", false)):
		return {"ok": false, "error": "seam failed: %s" % seam.get("error_code")}
	return {
		"ok": true, "gsm": gsm, "registry": registry, "player": p1,
		"first": first, "second": second, "source": source.get("source"),
		"seam": seam.get("seam"),
	}


func test_w1_current_window_executes_once_reobserves_and_hides_private_state() -> String:
	var fixture := _fixture("aswp5-live-success")
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var result: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if not bool(result.get("ok", false)):
		return "live seam rejected: %s %s" % [result.get("error_code"), str(fixture.seam.last_development_diagnostic())]
	var witness: Dictionary = result.get("witness")
	if not witness.get("engine_applied") or not witness.get("reobserved") or not witness.get("old_authority_invalidated"):
		return "lifecycle witness incomplete: %s" % str(witness)
	if witness.get("player_package_authority") or witness.get("classic_fallback_used") or not witness.get("development_canary"):
		return "canary trust scope drifted"
	if fixture.player.active_pokemon == null or fixture.player.active_pokemon.get_top_card() not in [fixture.first, fixture.second]:
		return "selected basic was not placed"
	var serialized := JSON.stringify(witness)
	for forbidden: String in ["instance_id", "object_id", "card_name", "private_engine_command", "Marnie's Impidimp"]:
		if serialized.contains(forbidden):
			return "witness leaked %s" % forbidden
	var replay: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if replay.get("ok") or replay.get("error_code") != "replay_rejected":
		return "one-use source replayed: %s" % str(replay)
	return ""


func test_w1_local_uid_marnie_candidate_binds_exact_public_view_and_executes_once() -> String:
	var fixture := _local_marnie_fixture("aswp5-marnie-local")
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	if not fixture.seam.uses_local_uid_domain():
		return "Marnie seam did not expose local UID domain"
	var prompt: Variant = fixture.source.host_prompt_owner()
	var local_view: Variant = prompt.local_uid_public_context() if prompt != null else null
	if not local_view is Dictionary or local_view.get("card_id_domain") != "godot_local_card_uid_v1":
		return "Marnie W1 source omitted local UID public view"
	if local_view.get("options", [])[0].get("local_card_uid") != "CSV8C_094":
		return "Marnie W1 option did not use stable game UID"
	var result: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if not bool(result.get("ok", false)):
		return "Marnie local W1 seam rejected: %s %s" % [result.get("error_code"), str(fixture.seam.last_development_diagnostic())]
	var witness: Dictionary = result.get("witness")
	if not witness.get("engine_applied") or witness.get("player_package_authority") or witness.get("classic_fallback_used"):
		return "Marnie local W1 authority witness drifted: %s" % str(witness)
	if fixture.player.active_pokemon == null or fixture.player.active_pokemon.get_top_card() not in [fixture.first, fixture.second]:
		return "Marnie local W1 did not apply exact selected card"
	return ""


func test_w1_policy_faults_use_same_window_deterministic_fallback() -> String:
	for fault: String in ["policy_exception", "illegal_output"]:
		var fixture := _fixture("aswp5-%s" % fault)
		if not bool(fixture.get("ok", false)):
			return "%s: %s" % [fault, fixture.get("error")]
		var result: Dictionary = fixture.seam.run_setup_active(fixture.source, fault)
		var witness_value: Variant = result.get("witness")
		var witness: Dictionary = witness_value if witness_value is Dictionary else {}
		if not bool(result.get("ok", false)) or witness.get("selection_source") != "deterministic_fallback":
			return "%s did not use bounded fallback: %s %s" % [fault, str(result), str(fixture.seam.last_development_diagnostic())]
		if witness.get("selected_indexes") != [0] or witness.get("classic_fallback_used"):
			return "%s fallback selection drifted" % fault
	return ""


func test_w1_candidate_reorder_fails_before_engine_mutation() -> String:
	var fixture := _fixture("aswp5-reorder")
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	fixture.player.hand.reverse()
	var result: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if result.get("ok") or result.get("error_code") != "prompt_changed":
		return "reordered prompt retained authority: %s" % str(result)
	if fixture.player.active_pokemon != null or fixture.player.hand.size() != 2:
		return "reorder rejection mutated engine state"
	fixture.player.hand.reverse()
	fixture.player.hand.remove_at(1)
	var removed: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if removed.get("ok") or removed.get("error_code") != "prompt_changed":
		return "removed candidate retained authority: %s" % str(removed)
	if fixture.player.active_pokemon != null or fixture.player.hand.size() != 1:
		return "removal rejection applied an engine action"
	var unsupported: Dictionary = fixture.seam.run_setup_active(RefCounted.new())
	if unsupported.get("ok") or unsupported.get("error_code") != "unsupported_prompt_family":
		return "unsupported family entered W1 seam"
	return ""


func test_w1_post_commit_engine_precondition_fault_never_falls_back() -> String:
	var fixture := _fixture("aswp5-engine-precondition")
	if not bool(fixture.get("ok", false)):
		return str(fixture.get("error"))
	var result: Dictionary = fixture.seam.run_setup_active(fixture.source, "active_already_present")
	if result.get("ok") or result.get("error_code") != "engine_apply_rejected":
		return "post-commit precondition did not fail closed: %s" % str(result)
	if fixture.player.active_pokemon != null or fixture.player.hand.size() != 2:
		return "engine-precondition injection mutated state"
	var replay: Dictionary = fixture.seam.run_setup_active(fixture.source)
	if replay.get("ok") or replay.get("error_code") != "replay_rejected":
		return "failed committed prompt was replayable: %s" % str(replay)
	return ""
