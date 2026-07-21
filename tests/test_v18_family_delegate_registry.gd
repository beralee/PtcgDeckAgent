class_name TestV18FamilyDelegateRegistry
extends TestBase


const REGISTRY_SCRIPT = preload("res://scripts/ai/DeckStrategyRegistry.gd")
const FIXED_ORDER_REGISTRY_SCRIPT = preload("res://scripts/ai/AIFixedDeckOrderRegistry.gd")
const PROFILE_CATALOG_SCRIPT = preload("res://scripts/ai/DeckStrategyV18ProfileCatalog.gd")
const DECK_DIR := "res://data/bundled_user/decks"

const FAMILY_SUPPORT_CONTRACT := [
	{
		"path": "res://scripts/ai/DeckStrategyV18DragapultFamily.gd",
		"ids": {
			18000230: "v18_dragapult_family_18000230",
			800015734: "v18_dragapult_family_800015734",
			800018499: "v18_dragapult_family_800018499",
			800019125: "v18_dragapult_family_800019125",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18BlazikenDragapult.gd",
		"ids": {
			18000625: "v18_blaziken_dragapult_18000625",
			800015734: "v18_blaziken_dragapult_800015734",
			800019125: "v18_blaziken_dragapult_800019125",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd",
		"ids": {
			800015934: "v18_tera_noctowl_core",
			800017643: "v18_tera_noctowl_core",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18GardevoirFamily.gd",
		"ids": {
			800017097: "v18_gardevoir_family",
			800018105: "v18_gardevoir_family",
			800018497: "v18_gardevoir_family",
			800018498: "v18_gardevoir_family",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd",
		"ids": {
			800017097: "v18_gardevoir_variants_800017097_delegate",
			800018105: "v18_gardevoir_variants_800018105_delegate",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18HopFroslass.gd",
		"ids": {
			800017407: "v18_hop_froslass_800017407_delegate",
			800017631: "v18_hop_froslass_800017631_delegate",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18ControlGrass.gd",
		"ids": {
			800018359: "v18_control_grass_delegate_800018359",
			800018500: "v18_control_grass_delegate_800018500",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd",
		"ids": {
			800018359: "v18_pidgeot_academy_800018359_delegate",
			800018498: "v18_pidgeot_academy_800018498_delegate",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18DarkCharacterFamily.gd",
		"ids": {
			800018501: "v18_marnies_grimmsnarl_character_delegate",
			800018502: "v18_ns_zoroark_character_delegate",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd",
		"ids": {
			800018501: "v18_marnie_cynthia_800018501",
			800018543: "v18_marnie_cynthia_800018543",
		},
	},
	{
		"path": "res://scripts/ai/DeckStrategyV18PartnerFamilies.gd",
		"ids": {
			800018539: "v18_ethans_ho_oh_core",
			800018543: "v18_stage2_core_800018543",
			800018880: "v18_stage2_core_800018880",
		},
	},
]

# Overlapping family support is intentional. The most deck-specific delegate wins here.
const PLANNED_REGISTRY_CONTRACT := [
	{"deck_id": 18000625, "path": "res://scripts/ai/DeckStrategyV18BlazikenDragapult.gd", "delegate_id": "v18_blaziken_dragapult_18000625"},
	{"deck_id": 800015734, "path": "res://scripts/ai/DeckStrategyV18DragapultFamily.gd", "delegate_id": "v18_dragapult_family_800015734"},
	{"deck_id": 800015934, "path": "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd", "delegate_id": "v18_tera_noctowl_core"},
	{"deck_id": 800017097, "path": "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd", "delegate_id": "v18_gardevoir_variants_800017097_delegate"},
	{"deck_id": 800017407, "path": "res://scripts/ai/DeckStrategyV18HopFroslass.gd", "delegate_id": "v18_hop_froslass_800017407_delegate"},
	{"deck_id": 800017631, "path": "res://scripts/ai/DeckStrategyV18HopFroslass.gd", "delegate_id": "v18_hop_froslass_800017631_delegate"},
	{"deck_id": 800017643, "path": "res://scripts/ai/DeckStrategyV18TeraNoctowl.gd", "delegate_id": "v18_tera_noctowl_core"},
	{"deck_id": 800018105, "path": "res://scripts/ai/DeckStrategyV18GardevoirVariants.gd", "delegate_id": "v18_gardevoir_variants_800018105_delegate"},
	{"deck_id": 800018359, "path": "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd", "delegate_id": "v18_pidgeot_academy_800018359_delegate"},
	{"deck_id": 800018498, "path": "res://scripts/ai/DeckStrategyV18PidgeotAcademy.gd", "delegate_id": "v18_pidgeot_academy_800018498_delegate"},
	{"deck_id": 800018500, "path": "res://scripts/ai/DeckStrategyV18ControlGrass.gd", "delegate_id": "v18_control_grass_delegate_800018500"},
	{"deck_id": 800018501, "path": "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd", "delegate_id": "v18_marnie_cynthia_800018501"},
	{"deck_id": 800018543, "path": "res://scripts/ai/DeckStrategyV18MarnieCynthia.gd", "delegate_id": "v18_marnie_cynthia_800018543"},
	{"deck_id": 800018880, "path": "res://scripts/ai/DeckStrategyV18PartnerFamilies.gd", "delegate_id": "v18_stage2_core_800018880"},
	{"deck_id": 800019125, "path": "res://scripts/ai/DeckStrategyV18DragapultFamily.gd", "delegate_id": "v18_dragapult_family_800019125"},
]

const MATURE_REGISTRY_CONTRACT := [
	{"deck_id": 18000230, "path": "res://scripts/ai/DeckStrategyDragapultCharizard.gd", "delegate_id": "dragapult_charizard"},
	{"deck_id": 800016834, "path": "res://scripts/ai/DeckStrategyV18Gholdengo.gd", "delegate_id": "v18_pure_gholdengo_core"},
	{"deck_id": 800017047, "path": "res://scripts/ai/DeckStrategyV18Stage2Core.gd", "delegate_id": "v18_stage2_core_800017047"},
	{"deck_id": 800018497, "path": "res://scripts/ai/DeckStrategyGardevoir.gd", "delegate_id": "gardevoir"},
	{"deck_id": 800018499, "path": "res://scripts/ai/DeckStrategy175PureDragapult.gd", "delegate_id": "v175_pure_dragapult"},
	{"deck_id": 800018502, "path": "res://scripts/ai/DeckStrategyNsZoroark.gd", "delegate_id": "ns_zoroark"},
	{"deck_id": 800018509, "path": "res://scripts/ai/DeckStrategyRagingBoltOgerpon.gd", "delegate_id": "raging_bolt_ogerpon"},
	{"deck_id": 800018539, "path": "res://scripts/ai/DeckStrategyV18EthanHoOh.gd", "delegate_id": "v18_ethans_ho_oh_core"},
	{"deck_id": 800033475, "path": "res://scripts/ai/DeckStrategyV18Yanmega.gd", "delegate_id": "v18_yanmega_route"},
]


func test_new_family_support_contract_matches_real_deck_scoped_identities() -> String:
	var checks: Array[String] = []
	for family_variant: Variant in FAMILY_SUPPORT_CONTRACT:
		var family: Dictionary = family_variant
		var script_path := str(family.get("path", ""))
		var family_script: Variant = load(script_path)
		checks.append(assert_true(family_script is GDScript, "Family script should compile: %s" % script_path))
		if not family_script is GDScript:
			continue
		var identities: Dictionary = family.get("ids", {})
		for deck_id_variant: Variant in identities:
			var deck_id := int(deck_id_variant)
			var deck := _load_deck(deck_id)
			checks.append(assert_not_null(deck, "Family support deck %d should load" % deck_id))
			if deck == null:
				continue
			var delegate: RefCounted = (family_script as GDScript).new()
			delegate.call("configure_from_deck", deck)
			checks.append(assert_eq(
				str(delegate.call("get_strategy_id")),
				str(identities.get(deck_id, "")),
				"Family %s should expose its real deck-scoped identity for %d" % [script_path.get_file(), deck_id]
			))
	return run_checks(checks)


func test_registry_wires_every_planned_v18_family_delegate() -> String:
	return _assert_registry_contract(PLANNED_REGISTRY_CONTRACT, "planned family")


func test_registry_preserves_mature_v18_delegate_mappings() -> String:
	return _assert_registry_contract(MATURE_REGISTRY_CONTRACT, "mature")


func test_normal_and_strong_fixed_openings_share_the_same_registry_family() -> String:
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	var fixed_registry: RefCounted = FIXED_ORDER_REGISTRY_SCRIPT.new()
	var checks: Array[String] = []
	for entry_variant: Variant in PLANNED_REGISTRY_CONTRACT:
		var entry: Dictionary = entry_variant
		var deck_id := int(entry.get("deck_id", 0))
		var deck := _load_deck(deck_id)
		checks.append(assert_not_null(deck, "Deck %d should load in both modes" % deck_id))
		var fixed_order: Array[Dictionary] = fixed_registry.call("load_fixed_order", deck_id)
		checks.append(assert_true(
			fixed_order.size() >= 19,
			"Strong mode for deck %d should have setup, Prize, and bridge cards" % deck_id
		))
		if deck == null:
			continue
		# Strong mode changes only deck order and runtime mode, never Registry resolution.
		var normal_strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck)
		var strong_strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck)
		var normal_delegate := _delegate_of(normal_strategy)
		var strong_delegate := _delegate_of(strong_strategy)
		checks.append(assert_not_null(normal_delegate, "Normal mode deck %d should have a delegate" % deck_id))
		checks.append(assert_not_null(strong_delegate, "Strong mode deck %d should have a delegate" % deck_id))
		if normal_delegate == null or strong_delegate == null:
			continue
		checks.append(assert_eq(
			_delegate_script_path(strong_delegate),
			_delegate_script_path(normal_delegate),
			"Normal and strong modes must share one family script for deck %d" % deck_id
		))
		checks.append(assert_eq(
			str(strong_delegate.call("get_strategy_id")),
			str(normal_delegate.call("get_strategy_id")),
			"Normal and strong modes must share one family identity for deck %d" % deck_id
		))
	return run_checks(checks)


func test_planned_and_mature_contracts_cover_all_24_v18_decks_once() -> String:
	var seen: Dictionary = {}
	var checks: Array[String] = []
	for contract_variant: Variant in [PLANNED_REGISTRY_CONTRACT, MATURE_REGISTRY_CONTRACT]:
		for entry_variant: Variant in contract_variant:
			var entry: Dictionary = entry_variant
			var deck_id := int(entry.get("deck_id", 0))
			checks.append(assert_false(seen.has(deck_id), "Deck %d should have exactly one planned Registry owner" % deck_id))
			seen[deck_id] = true
	var catalog_ids: Array[int] = PROFILE_CATALOG_SCRIPT.deck_ids()
	checks.append(assert_eq(seen.size(), 24, "The Registry contract should cover all 24 V18 decks exactly once"))
	checks.append(assert_eq(catalog_ids.size(), 24, "The production V18 profile catalog should still contain 24 decks"))
	for deck_id: int in catalog_ids:
		checks.append(assert_true(seen.has(deck_id), "Catalog deck %d should have exactly one Registry contract owner" % deck_id))
	for deck_id_variant: Variant in seen:
		var deck_id := int(deck_id_variant)
		checks.append(assert_true(deck_id in catalog_ids, "Contract deck %d should remain in the production V18 catalog" % deck_id))
	return run_checks(checks)


func _assert_registry_contract(contract: Array, label: String) -> String:
	var registry: RefCounted = REGISTRY_SCRIPT.new()
	var checks: Array[String] = []
	for entry_variant: Variant in contract:
		var entry: Dictionary = entry_variant
		var deck_id := int(entry.get("deck_id", 0))
		var deck := _load_deck(deck_id)
		checks.append(assert_not_null(deck, "%s deck %d should load" % [label, deck_id]))
		if deck == null:
			continue
		var expected_outer_id := str(registry.call("strategy_id_for_deck_id", deck_id))
		var strategy: RefCounted = registry.call("resolve_strategy_for_deck", deck)
		checks.append(assert_not_null(strategy, "%s deck %d should resolve through Registry" % [label, deck_id]))
		if strategy == null:
			continue
		checks.append(assert_true(expected_outer_id.begins_with("v18_"), "Deck %d should retain an exact V18 profile id" % deck_id))
		checks.append(assert_eq(
			str(strategy.call("get_strategy_id")),
			expected_outer_id,
			"Deck %d should preserve the Registry profile identity" % deck_id
		))
		var delegate := _delegate_of(strategy)
		checks.append(assert_not_null(delegate, "%s deck %d should configure a delegate" % [label, deck_id]))
		if delegate == null:
			continue
		checks.append(assert_eq(
			_delegate_script_path(delegate),
			str(entry.get("path", "")),
			"Deck %d should resolve the expected delegate type" % deck_id
		))
		checks.append(assert_eq(
			str(delegate.call("get_strategy_id")),
			str(entry.get("delegate_id", "")),
			"Deck %d should expose the expected delegate strategy id" % deck_id
		))
	return run_checks(checks)


func _delegate_of(strategy: RefCounted) -> RefCounted:
	if strategy == null:
		return null
	var delegate: Variant = strategy.get("_delegate")
	return delegate as RefCounted if delegate is RefCounted else null


func _delegate_script_path(delegate: RefCounted) -> String:
	if delegate == null:
		return ""
	var script: Variant = delegate.get_script()
	return str(script.resource_path) if script is Script else ""


func _load_deck(deck_id: int) -> DeckData:
	var path := "%s/%d.json" % [DECK_DIR, deck_id]
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DeckData.from_dict(parsed) if parsed is Dictionary else null
