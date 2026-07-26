extends SceneTree

const NoctowlSearchScript = preload("res://scripts/ai/v18_cpg/modules/V18CPGTeraNoctowlSearch.gd")
const ProfileCatalogScript = preload("res://scripts/ai/v18_cpg/V18CPGProfileCatalog.gd")

const DECK_ID := 800015934
const BOSS_UID := "CSVH1AC_023"
const FAN_ROTOM_UID := "CSV9C_161"
const AREA_ZERO_UID := "CSV9C_207"

var _failures: Array[String] = []


func _initialize() -> void:
	var module = NoctowlSearchScript.new()
	var profile := ProfileCatalogScript.get_profile_for_deck(DECK_ID)
	var fixture := _fixture()
	var frontier: Array[Dictionary] = module.annotate_frontier_v2(
		fixture.frontier,
		fixture.observation,
		fixture.facts,
		profile,
		{}
	)
	var annotation: Dictionary = frontier[1].get(
		"module_annotations", {}
	).get("tera_noctowl_search", {})
	_check(
		bool(annotation.get("verified_advantage", false)) \
			and str(annotation.get("verified_advantage_kind", "")) \
				== "fan_rotom_gust_closeout",
		"Boss must certify the exact public Fan Rotom attach-and-attack closeout"
	)
	_check(
		str(annotation.get("gust_closeout_target_slot_id", "")) == "slot:301",
		"closeout certificate must bind the exact damaged opponent Bench slot"
	)
	var advantage: Dictionary = module.verify_route_advantage(
		frontier[1],
		frontier[0],
		fixture.facts,
		profile
	)
	_check(
		bool(advantage.get("verified", false)) \
			and str(advantage.get("certificate_kind", "")) \
				== "public_fan_rotom_gust_attach_attack_closeout",
		"gust line must expose a deterministic public win certificate"
	)

	var damaged_target := _slot("151C_151", "Mew ex", 301)
	var healthy_target := _slot("CSV8C_172", "Bloodmoon Ursaluna ex", 302)
	var damaged_score: Variant = module.verified_fan_rotom_gust_target_score(
		damaged_target,
		{"id": "opponent_bench_target"},
		fixture.observation,
		profile,
		"fan_rotom_gust_closeout"
	)
	var healthy_score: Variant = module.verified_fan_rotom_gust_target_score(
		healthy_target,
		{"id": "opponent_bench_target"},
		fixture.observation,
		profile,
		"fan_rotom_gust_closeout"
	)
	_check(
		damaged_score != null and healthy_score != null \
			and float(damaged_score) > float(healthy_score),
		"Boss interaction must select the certificate-bound 30 HP target"
	)

	var no_energy: Dictionary = fixture.observation.duplicate(true)
	no_energy.own.hand = no_energy.own.hand.filter(
		func(card: Dictionary) -> bool:
			return str(card.get("type", "")) != "Basic Energy"
	)
	var no_energy_frontier: Array[Dictionary] = module.annotate_frontier_v2(
		fixture.frontier,
		no_energy,
		fixture.facts,
		profile,
		{}
	)
	_check(
		not bool(no_energy_frontier[1].get(
			"module_annotations", {}
		).get("tera_noctowl_search", {}).get("verified_advantage", false)),
		"closeout must fail closed without a visible manual attachment"
	)

	var too_healthy: Dictionary = fixture.observation.duplicate(true)
	too_healthy.opponent.bench[0].remaining_hp = 80
	var too_healthy_frontier: Array[Dictionary] = module.annotate_frontier_v2(
		fixture.frontier,
		too_healthy,
		fixture.facts,
		profile,
		{}
	)
	_check(
		not bool(too_healthy_frontier[1].get(
			"module_annotations", {}
		).get("tera_noctowl_search", {}).get("verified_advantage", false)),
		"closeout must fail closed when Fan Rotom cannot take the final prize"
	)

	if _failures.is_empty():
		print("V18CPG 800015934 round22 Fan Rotom gust closeout: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("V18CPG 800015934 round22 Fan Rotom gust closeout: FAIL (%d)" % _failures.size())
	quit(1)


func _fixture() -> Dictionary:
	var observation := {
		"own": {
			"deck_count": 21,
			"prizes_remaining": 1,
			"active": {
				"slot_id": "slot:101",
				"pokemon": {"uid": FAN_ROTOM_UID, "name": "Fan Rotom"},
				"energy_count": 0,
				"energy": [],
				"remaining_hp": 70,
			},
			"bench": [],
			"hand": [{
				"uid": BOSS_UID,
				"name": "Boss's Orders",
				"type": "Supporter",
			}, {
				"uid": "CSVE1C_LIG",
				"name": "Lightning Energy",
				"type": "Basic Energy",
				"energy_provides": "L",
			}],
		},
		"opponent": {
			"active": {
				"slot_id": "slot:201",
				"pokemon": {"uid": "CS6AC_057", "name": "Zapdos"},
				"remaining_hp": 120,
				"prize_count": 1,
			},
			"bench": [{
				"slot_id": "slot:301",
				"pokemon": {"uid": "151C_151", "name": "Mew ex"},
				"remaining_hp": 30,
				"prize_count": 2,
				"energy_count": 0,
			}, {
				"slot_id": "slot:302",
				"pokemon": {"uid": "CSV8C_172", "name": "Bloodmoon Ursaluna ex"},
				"remaining_hp": 260,
				"prize_count": 2,
				"energy_count": 0,
			}],
		},
		"stadium": {"uid": AREA_ZERO_UID, "name": "Area Zero Underdepths"},
		"turn": {
			"quotas": {
				"energy_available": true,
				"supporter_available": true,
			},
		},
		"legal_actions": [{
			"id": "action:ultra_ball",
			"kind": "play_trainer",
			"card": {"uid": "CSV1C_112", "name": "Ultra Ball", "type": "Item"},
		}, {
			"id": "action:boss",
			"kind": "play_trainer",
			"card": {"uid": BOSS_UID, "name": "Boss's Orders", "type": "Supporter"},
		}],
	}
	var facts := {
		"attack": {"ready": false, "ko_available": false},
		"resources": {
			"energy_on_board": 0,
			"prizes_remaining": 1,
		},
		"turn": {
			"energy_available": true,
			"supporter_available": true,
		},
	}
	var frontier: Array[Dictionary] = [{
		"candidate_id": "candidate:ultra_ball",
		"route_id": "route:information",
		"safe_prefix_action_id": "action:ultra_ball",
		"action_kind": "play_trainer",
		"action_ref": {
			"card": {"uid": "CSV1C_112", "name": "Ultra Ball", "type": "Item"},
		},
		"action_semantic_roles": ["item", "pokemon_search"],
		"checkpoint_after": "information_revealed",
		"base_score": 1029.2,
		"outcome": {"terminal": false},
	}, {
		"candidate_id": "candidate:boss",
		"route_id": "route:gust",
		"safe_prefix_action_id": "action:boss",
		"action_kind": "play_trainer",
		"action_ref": {
			"card": {"uid": BOSS_UID, "name": "Boss's Orders", "type": "Supporter"},
		},
		"action_semantic_roles": ["supporter", "gust"],
		"checkpoint_after": "action_resolved",
		"base_score": 334.8,
		"outcome": {"terminal": false},
	}]
	return {
		"observation": observation,
		"facts": facts,
		"frontier": frontier,
	}


func _slot(uid: String, name_en: String, instance_id: int) -> PokemonSlot:
	var data := CardData.new()
	data.name = name_en
	data.name_en = name_en
	data.card_type = "Pokemon"
	data.stage = "Basic"
	var parts := uid.split("_", false, 1)
	data.set_code = parts[0]
	data.card_index = parts[1]
	var card := CardInstance.create(data, 1)
	card.instance_id = instance_id
	var slot := PokemonSlot.new()
	slot.pokemon_stack.append(card)
	return slot


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
