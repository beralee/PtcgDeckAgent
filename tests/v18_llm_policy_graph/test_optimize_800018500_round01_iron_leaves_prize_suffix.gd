extends SceneTree

## Regression fixture extracted from optimization21 round00, seed 800018507.
##
## The public position has two movable Grass Energy on separate Pokemon, a
## Grass Energy in hand, an unused manual-attachment quota, and a 70 HP / two-
## prize opposing Active.  Iron Leaves ex can therefore move both public
## Energy when it enters, receive the hand Energy, and use Prism Edge for a
## deterministic two-prize knockout.  The Rule strategy currently selects no
## Energy because each one-Energy Bench source is independently penalized.

const AbilityScript = preload("res://scripts/effects/pokemon_effects/AbilityBenchEnterSwitchAndMoveEnergy.gd")
const CapabilityRegistryScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGCapabilityRegistry.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")
const RuleStrategyScript = preload("res://scripts/ai/DeckStrategyV18ControlGrass.gd")
const StrategyScript = preload("res://scripts/ai/v18_cpg/V18ConditionalPolicyStrategy.gd")

const DECK_ID := 800018500
const IRON_LEAVES_UID := "CSV7C_033"
const IRON_HANDS_UID := "CSV6C_051"
const STEP_ID := "iron_leaves_energy_to_move"
const CERTIFICATE_KIND := "profiled_iron_leaves_same_turn_prize_suffix"

var _failures: Array[String] = []


func _initialize() -> void:
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	_check(int(profile.get("deck_id", 0)) == DECK_ID, "the fixture must load deck 800018500's isolated profile")
	_check(int(profile.get("profile_version", 0)) >= 3, "the seed507 certificate requires profile version 3 or newer")
	_check("grass_spread" in profile.get("modules", []), "the profile must compose the grass_spread capability module")
	_test_rule_floor_exposes_exact_gap()
	_test_verified_interaction_contract(profile)
	_test_local_gate_uses_verified_interaction(profile)
	_test_real_effect_and_deterministic_prize_suffix()
	_test_strict_negative_boundaries(profile)
	_test_profile_isolation()
	if _failures.is_empty():
		print("V18CPG 800018500 round01 Iron Leaves prize suffix: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_rule_floor_exposes_exact_gap() -> void:
	var fixture := _engine_fixture()
	var deck := DeckData.new()
	deck.id = DECK_ID
	var rules := RuleStrategyScript.new()
	rules.configure_from_deck(deck)
	var picks := rules.pick_interaction_items(
		fixture.get("items", []),
		_interaction_step(2),
		{
			"game_state": fixture.get("state"),
			"player_index": 0,
			"player": fixture.get("player"),
			"source_slot": fixture.get("iron_leaves"),
		}
	)
	_check(picks.is_empty(), "the current Rule floor must reproduce seed507's zero-Energy interaction gap")


func _test_verified_interaction_contract(profile: Dictionary) -> void:
	var fixture := _engine_fixture()
	var items: Array = fixture.get("items", [])
	var override := _pick_override(items, _interaction_step(items.size()), _public_observation(), _facts(), profile)
	_check(bool(override.get("handled", false)), "grass_spread must certify the public Iron Leaves two-Energy interaction suffix")
	if not bool(override.get("handled", false)):
		# Keep today's expected-red result focused on the missing interface. Once
		# the module handles the position, the detailed certificate contract below
		# becomes active and reports any incomplete evidence field independently.
		return
	var selected: Array = override.get("items", [])
	_check(selected.size() == 2, "the verified override must select exactly two movable Grass Energy")
	_check(items.all(func(item: Variant) -> bool: return item in selected), "the override must select both real Energy instances, not merely two abstract copies")
	_check(str(override.get("certificate_kind", "")) == CERTIFICATE_KIND, "the override must expose the dedicated audited certificate kind")

	var evidence: Dictionary = override.get("evidence", {}) if override.get("evidence", {}) is Dictionary else {}
	_check(str(evidence.get("source_action_kind", "")) == "play_basic_to_bench", "certificate evidence must bind the Rule-owned Iron Leaves bench action")
	_check(str(evidence.get("source_pokemon_uid", "")).to_upper() == IRON_LEAVES_UID, "certificate evidence must bind Iron Leaves ex")
	_check(str(evidence.get("step_id", "")) == STEP_ID, "certificate evidence must bind the exact interaction step")
	_check(int(evidence.get("movable_grass_count", 0)) == 2, "certificate evidence must prove two public movable Grass Energy")
	_check(int(evidence.get("selected_energy_count", 0)) == 2, "certificate evidence must record the exact transfer count")
	_check(str(evidence.get("manual_attach_symbol", "")) == "G", "certificate evidence must reserve the visible Grass attachment")
	_check(int(evidence.get("post_attach_energy_count", 0)) == 3, "certificate evidence must prove the three-Energy post-attachment state")
	_check(int(evidence.get("attack_index", -1)) == 0, "certificate evidence must bind Prism Edge's attack index")
	_check(str(evidence.get("attack_cost", "")) == "GGC", "certificate evidence must bind Prism Edge's printed cost")
	_check(int(evidence.get("projected_damage", 0)) == 180, "certificate evidence must prove Prism Edge's deterministic damage")
	_check(str(evidence.get("target_pokemon_uid", "")).to_upper() == IRON_HANDS_UID, "certificate evidence must bind the current opposing Active")
	_check(int(evidence.get("target_remaining_hp", 0)) == 70, "certificate evidence must bind the 70 HP seed507 target")
	_check(int(evidence.get("prizes_now", 0)) == 2, "certificate evidence must prove the immediate two-prize swing")
	_check(bool(evidence.get("attack_window_open", false)), "certificate evidence must prove the deterministic attack window is open")
	_check(bool(evidence.get("target_stable", false)), "certificate evidence must state that the interaction does not change the opponent target")
	_check(not bool(evidence.get("hidden_info", true)), "certificate evidence must not depend on hidden information")
	_check(not bool(evidence.get("random", true)), "certificate evidence must not depend on randomness")


func _test_local_gate_uses_verified_interaction(profile: Dictionary) -> void:
	var fixture := _engine_fixture()
	var strategy := StrategyScript.new()
	strategy.configure_profile(profile)
	strategy.configure_verified_local_only_for_benchmark()
	var observation := _public_observation()
	observation["observation_hash"] = "round01-action-bound-observation"
	strategy.set("_current_action_owner", "local_gate")
	strategy.set("_current_turn", 11)
	strategy.set("_current_route_id", "route:develop")
	strategy.set("_preferred_candidate_id", "candidate:round01-iron-leaves")
	strategy.set("_preferred_action_id", "action:round01-iron-leaves")
	strategy.set("_last_observation", observation)
	strategy.set("_last_facts", _facts())
	strategy.set("_pending_interaction_certificate_context", {
		"action_id": "action:round01-iron-leaves",
		"action_kind": "play_basic_to_bench",
		"action_card_uid": IRON_LEAVES_UID,
		"candidate_id": "candidate:round01-iron-leaves",
		"route_id": "route:develop",
		"owner": "local_gate",
		"turn": 11,
		"observation_hash": "round01-action-bound-observation",
		"observation": observation,
		"facts": _facts(),
	})
	var selected := strategy.pick_interaction_items(
		fixture.get("items", []),
		_interaction_step(2),
		{
			"pending_effect_card": (fixture.get("iron_leaves") as PokemonSlot).get_top_card(),
			"pending_effect_slot": fixture.get("iron_leaves"),
		}
	)
	_check(selected.size() == 2, "a Rule-owned local_gate action must retain access to the verified two-Energy suffix")
	_check((fixture.get("items", []) as Array).all(func(item: Variant) -> bool: return item in selected), "the local_gate bridge must return both movable Energy instances")
	var audit: Variant = strategy.get("_audit")
	var records: Array[Dictionary] = audit.records() if audit != null and audit.has_method("records") else []
	_check(records.any(func(record: Dictionary) -> bool:
		return str(record.get("event_type", "")) == "module_verified_interaction_override" \
			and str(record.get("certificate_kind", "")) == CERTIFICATE_KIND
	), "the production local_gate path must audit module ownership of the interaction override")


func _test_real_effect_and_deterministic_prize_suffix() -> void:
	var fixture := _engine_fixture()
	var state: GameState = fixture.get("state")
	var player: PlayerState = fixture.get("player")
	var old_active: PokemonSlot = fixture.get("fezandipiti")
	var toedscruel: PokemonSlot = fixture.get("toedscruel")
	var ogerpon: PokemonSlot = fixture.get("ogerpon")
	var iron_leaves: PokemonSlot = fixture.get("iron_leaves")
	var target: PokemonSlot = fixture.get("target")
	var items: Array = fixture.get("items", [])
	var hand_grass: CardInstance = fixture.get("hand_grass")
	var ability := AbilityScript.new()
	var steps := ability.get_interaction_steps(iron_leaves.get_top_card(), state)
	_check(steps.size() == 1 and int(steps[0].get("max_select", -1)) == 2, "the real effect must expose both attached Energy as selectable public items")

	ability.execute_ability(iron_leaves, 0, [{STEP_ID: items}], state)
	_check(player.active_pokemon == iron_leaves, "Iron Leaves' real Ability must switch it into the Active Spot")
	_check(old_active in player.bench, "the previous Active must move to the Bench")
	_check(iron_leaves.attached_energy.size() == 2, "the real Ability must move both selected Energy onto Iron Leaves")
	_check(toedscruel.attached_energy.is_empty() and ogerpon.attached_energy.is_empty(), "both source slots must surrender their selected Energy")

	# This is the normal deterministic manual-attachment state transition.  The
	# certificate is allowed only while the public quota and this exact hand card
	# exist; the negative tests below close both boundaries.
	player.hand.erase(hand_grass)
	iron_leaves.attached_energy.append(hand_grass)
	state.energy_attached_this_turn = true
	_check(_slot_can_pay_cost(iron_leaves, "GGC"), "two moved Grass plus the visible hand Grass must pay Prism Edge's GGC cost")
	var damage := 180
	var target_hp_before := target.get_remaining_hp()
	target.damage_counters += damage
	_check(target_hp_before == 70 and target.is_knocked_out(), "Prism Edge's deterministic 180 damage must knock out the 70 HP opposing Active")
	_check(target.get_prize_count() == 2, "the knocked-out Iron Hands ex must be worth exactly two prizes")
	var prizes_before := player.prizes.size()
	player.prizes.resize(maxi(0, prizes_before - target.get_prize_count()))
	_check(prizes_before == 4 and player.prizes.size() == 2, "the deterministic suffix must reduce own remaining prizes from four to two")


func _test_strict_negative_boundaries(profile: Dictionary) -> void:
	var base_fixture := _engine_fixture()
	var base_items: Array = base_fixture.get("items", [])
	var cases: Array[Dictionary] = []

	var no_hand_grass := _public_observation()
	no_hand_grass["own"]["hand"] = (no_hand_grass["own"]["hand"] as Array).filter(
		func(card: Dictionary) -> bool: return str(card.get("uid", "")) != "CSVE1C_GRA"
	)
	cases.append({"label": "visible hand Grass is missing", "items": base_items, "step": _interaction_step(2), "observation": no_hand_grass, "facts": _facts()})

	var quota_spent := _facts()
	quota_spent["turn"]["energy_available"] = false
	var quota_observation := _public_observation()
	quota_observation["turn"]["quotas"]["energy_available"] = false
	cases.append({"label": "manual attachment quota is spent", "items": base_items, "step": _interaction_step(2), "observation": quota_observation, "facts": quota_spent})

	cases.append({"label": "only one movable Grass exists", "items": [base_items[0]], "step": _interaction_step(1), "observation": _observation_with_one_board_grass(), "facts": _facts()})

	var too_healthy := _public_observation()
	too_healthy["opponent"]["active"]["remaining_hp"] = 181
	too_healthy["opponent"]["active"]["damage"] = 49
	cases.append({"label": "Prism Edge cannot knock out the target", "items": base_items, "step": _interaction_step(2), "observation": too_healthy, "facts": _facts()})

	var one_prize := _public_observation()
	one_prize["opponent"]["active"]["prize_count"] = 1
	cases.append({"label": "target is not a two-prize Pokemon", "items": base_items, "step": _interaction_step(2), "observation": one_prize, "facts": _facts()})

	var closed_window := _public_observation()
	closed_window["turn"]["deterministic_attack_window_open"] = false
	cases.append({"label": "deterministic attack window is closed", "items": base_items, "step": _interaction_step(2), "observation": closed_window, "facts": _facts()})

	var wrong_source := _public_observation()
	wrong_source["own"]["bench"][0]["pokemon"]["uid"] = "CSV5C_010"
	cases.append({"label": "the exact two public Energy sources are not present", "items": base_items, "step": _interaction_step(2), "observation": wrong_source, "facts": _facts()})

	var extra_board_energy := _public_observation()
	extra_board_energy["own"]["active"]["energy"] = [_card_ref("CSVE1C_GRA", "Basic Energy", "G")]
	extra_board_energy["own"]["active"]["energy_count"] = 1
	cases.append({"label": "an unbound third board Energy changes the transfer state", "items": base_items, "step": _interaction_step(2), "observation": extra_board_energy, "facts": _facts()})

	var wrong_prize_race := _public_observation()
	wrong_prize_race["own"]["prizes_remaining"] = 3
	cases.append({"label": "the public prize race differs from seed507", "items": base_items, "step": _interaction_step(2), "observation": wrong_prize_race, "facts": _facts()})

	var iron_already_active := _public_observation()
	iron_already_active["own"]["active"] = _slot_ref("slot:iron", IRON_LEAVES_UID, [], 220, 2)
	iron_already_active["own"]["hand"] = (iron_already_active["own"]["hand"] as Array).filter(
		func(card: Dictionary) -> bool: return str(card.get("uid", "")) != IRON_LEAVES_UID
	)
	cases.append({"label": "Iron Leaves is not entering from the visible hand", "items": base_items, "step": _interaction_step(2), "observation": iron_already_active, "facts": _facts()})

	cases.append({"label": "interaction step is unrelated", "items": base_items, "step": {"id": "energy_assignment", "min_select": 0, "max_select": 2}, "observation": _public_observation(), "facts": _facts()})

	for invalid: Dictionary in cases:
		var result := _pick_override(
			invalid.get("items", []),
			invalid.get("step", {}),
			invalid.get("observation", {}),
			invalid.get("facts", {}),
			profile
		)
		_check(not bool(result.get("handled", false)), "%s must fail closed" % str(invalid.get("label", "invalid state")))
	var mismatched_owner := _pick_override(
		base_items,
		_interaction_step(2),
		_public_observation(),
		_facts(),
		profile,
		"unrelated_module_certificate"
	)
	_check(not bool(mismatched_owner.get("handled", false)), "an unrelated active module certificate must not inherit the Rule-owned suffix")


func _test_profile_isolation() -> void:
	var fixture := _engine_fixture()
	var gardevoir_profile := ProfileCatalogScript.get_profile_for_deck(800018497)
	var override := _pick_override(
		fixture.get("items", []),
		_interaction_step(2),
		_public_observation(),
		_facts(),
		gardevoir_profile
	)
	_check(not bool(override.get("handled", false)), "another deck profile must not inherit the Iron Leaves interaction certificate")


func _pick_override(
	items: Array,
	step: Dictionary,
	observation: Dictionary,
	facts: Dictionary,
	profile: Dictionary,
	certificate_kind: String = ""
) -> Dictionary:
	return CapabilityRegistryScript.new().pick_verified_interaction_override(
		items,
		step,
		[],
		{
			"v18cpg_observation": observation,
			"v18cpg_facts": facts,
			"v18cpg_action_binding": {
				"evidence_kind": "selected_action_filtered_snapshot",
				"action_id": "action:round01-iron-leaves",
				"action_kind": "play_basic_to_bench",
				"action_card_uid": IRON_LEAVES_UID,
				"candidate_id": "candidate:round01-iron-leaves",
				"owner": "local_gate",
				"observation_hash": "round01-action-bound-observation",
			},
		},
		profile,
		certificate_kind
	)


func _engine_fixture() -> Dictionary:
	CardInstance.reset_id_counter()
	var state := GameState.new()
	state.turn_number = 11
	state.current_player_index = 0
	state.first_player_index = 1
	state.phase = GameState.GamePhase.MAIN
	state.energy_attached_this_turn = false

	var player := PlayerState.new()
	player.player_index = 0
	var opponent := PlayerState.new()
	opponent.player_index = 1
	state.players = [player, opponent]

	var toedscruel := _pokemon_slot("Toedscruel", "CSV5C", "009", 120, "", 0)
	var fezandipiti := _pokemon_slot("Fezandipiti ex", "CSV8C", "135", 210, "ex", 0)
	var ogerpon := _pokemon_slot("Teal Mask Ogerpon ex", "CSV8C", "028", 210, "ex", 0)
	var iron_leaves := _pokemon_slot("Iron Leaves ex", "CSV7C", "033", 220, "ex", 0)
	iron_leaves.get_card_data().abilities = [{"name": "Rapid Vernier", "text": ""}]
	iron_leaves.get_card_data().attacks = [{"name": "Prism Edge", "cost": "GGC", "damage": "180", "text": "", "is_vstar_power": false}]
	iron_leaves.turn_played = state.turn_number
	iron_leaves.mark_entered_bench_from_hand(state.turn_number)

	var grass_from_toedscruel := _energy_instance("Grass from Toedscruel", "G", 0)
	var grass_from_ogerpon := _energy_instance("Grass from Ogerpon", "G", 0)
	var hand_grass := _energy_instance("Grass in hand", "G", 0)
	toedscruel.attached_energy.append(grass_from_toedscruel)
	ogerpon.attached_energy.append(grass_from_ogerpon)
	player.active_pokemon = fezandipiti
	player.bench = [toedscruel, ogerpon, iron_leaves]
	player.hand = [hand_grass]
	for i: int in 4:
		player.prizes.append(_dummy_card("Own Prize %d" % i, 0))

	var target := _pokemon_slot("Iron Hands ex", "CSV6C", "051", 230, "ex", 1)
	target.damage_counters = 160
	opponent.active_pokemon = target
	for i: int in 4:
		opponent.prizes.append(_dummy_card("Opponent Prize %d" % i, 1))

	return {
		"state": state,
		"player": player,
		"toedscruel": toedscruel,
		"fezandipiti": fezandipiti,
		"ogerpon": ogerpon,
		"iron_leaves": iron_leaves,
		"target": target,
		"hand_grass": hand_grass,
		"items": [grass_from_toedscruel, grass_from_ogerpon],
	}


func _public_observation() -> Dictionary:
	return {
		"schema_version": "v18cpg-2",
		"observation_version": 32,
		"turn": {
			"number": 11,
			"current_player": 0,
			"first_player": 1,
			"phase": int(GameState.GamePhase.MAIN),
			"deterministic_attack_window_open": true,
			"quotas": {
				"energy_available": true,
				"supporter_available": false,
				"retreat_available": true,
			},
		},
		"own": {
			"prizes_remaining": 4,
			"hand_count": 4,
			"hand": [
				_card_ref(IRON_LEAVES_UID, "Pokemon", "G"),
				_card_ref("CSVE1C_GRA", "Basic Energy", "G"),
				_card_ref("CSV7C_180", "Item"),
				_card_ref("CSV8C_182", "Item"),
			],
			"active": _slot_ref("slot:fezandipiti", "CSV8C_135", [], 210, 2),
			"bench": [
				_slot_ref("slot:toedscruel", "CSV5C_009", [_card_ref("CSVE1C_GRA", "Basic Energy", "G")], 120, 1),
				_slot_ref("slot:ogerpon", "CSV8C_028", [_card_ref("CSVE1C_GRA", "Basic Energy", "G")], 210, 2),
			],
		},
		"opponent": {
			"prizes_remaining": 4,
			"active": _opponent_active_ref(),
			"bench": [],
		},
		"visibility": {
			"deck_order_visible": false,
			"opponent_hand_contents": false,
			"own_prize_identities": false,
		},
	}


func _observation_with_one_board_grass() -> Dictionary:
	var observation := _public_observation()
	observation["own"]["bench"][1]["energy"] = []
	observation["own"]["bench"][1]["energy_count"] = 0
	return observation


func _facts() -> Dictionary:
	return {
		"attack": {"ready": false, "ko_available": false, "max_damage": 0},
		"board": {"opponent_active_remaining_hp": 70, "own_active_remaining_hp": 210},
		"prize": {"current_swing": 0, "win_now": false},
		"resources": {
			"energy_on_board": 2,
			"prizes_remaining": 4,
			"hand_size": 4,
			"deck_low": false,
		},
		"turn": {"energy_available": true, "supporter_available": false},
	}


func _interaction_step(max_select: int) -> Dictionary:
	return {
		"id": STEP_ID,
		"min_select": 0,
		"max_select": max_select,
		"allow_cancel": true,
	}


func _opponent_active_ref() -> Dictionary:
	var slot := _slot_ref("slot:opponent_active", IRON_HANDS_UID, [], 230, 2)
	slot["damage"] = 160
	slot["remaining_hp"] = 70
	return slot


func _slot_ref(
	slot_id: String,
	uid: String,
	energy: Array,
	max_hp: int,
	prize_count: int
) -> Dictionary:
	return {
		"slot_id": slot_id,
		"pokemon": _card_ref(uid, "Pokemon"),
		"energy": energy,
		"energy_count": energy.size(),
		"damage": 0,
		"remaining_hp": max_hp,
		"max_hp": max_hp,
		"prize_count": prize_count,
		"ability_used": false,
	}


func _card_ref(uid: String, type_name: String, symbol: String = "") -> Dictionary:
	var card := {"uid": uid, "type": type_name}
	if symbol != "":
		if type_name.contains("Energy"):
			card["energy_provides"] = symbol
		else:
			card["energy_type"] = symbol
	return card


func _pokemon_slot(
	name: String,
	set_code: String,
	card_index: String,
	hp: int,
	mechanic: String,
	owner_index: int
) -> PokemonSlot:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Pokemon"
	data.stage = "Basic"
	data.energy_type = "G"
	data.hp = hp
	data.mechanic = mechanic
	data.set_code = set_code
	data.card_index = card_index
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(CardInstance.create(data, owner_index))
	return slot


func _energy_instance(name: String, symbol: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Basic Energy"
	data.energy_type = symbol
	data.energy_provides = symbol
	data.set_code = "CSVE1C"
	data.card_index = "GRA"
	return CardInstance.create(data, owner_index)


func _dummy_card(name: String, owner_index: int) -> CardInstance:
	var data := CardData.new()
	data.name = name
	data.name_en = name
	data.card_type = "Item"
	return CardInstance.create(data, owner_index)


func _slot_can_pay_cost(slot: PokemonSlot, cost: String) -> bool:
	if slot == null:
		return false
	var typed: Dictionary = {}
	var total := 0
	for energy: CardInstance in slot.attached_energy:
		if energy == null or energy.card_data == null:
			continue
		var provides := str(energy.card_data.energy_provides)
		if provides == "":
			provides = str(energy.card_data.energy_type)
		total += 1
		if provides != "ANY":
			typed[provides] = int(typed.get(provides, 0)) + 1
	var colorless_required := 0
	var typed_required := 0
	for index: int in cost.length():
		var symbol := cost.substr(index, 1)
		if symbol == "C":
			colorless_required += 1
		else:
			typed_required += 1
			if int(typed.get(symbol, 0)) <= 0:
				return false
			typed[symbol] = int(typed.get(symbol, 0)) - 1
	return total - typed_required >= colorless_required


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
