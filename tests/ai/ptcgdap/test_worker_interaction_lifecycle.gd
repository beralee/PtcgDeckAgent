extends TestBase

const Owner = preload("res://scripts/ai/ptcgdap/host/godot/PtcgDAPAuthorDevelopmentBattleOwner.gd")
const Reviewed = preload("res://scripts/ai/ptcgdap/host/godot/ReviewedAuthorStrategyDevelopmentBattleOwner.gd")
const Cynthia = preload("res://scripts/ai/ptcgdap/host/godot/CynthiaAuthorStrategyDevelopmentBattleOwner.gd")

class WaitingOwner extends Owner:
	var waiting := true
	var source_calls := 0
	var context_seen: Dictionary = {}
	func has_pending_external_decision() -> bool: return waiting
	func _pick_interaction_items(items: Array, _step: Dictionary, context: Dictionary = {}) -> Array:
		source_calls += 1
		context_seen = context.duplicate(true)
		return [] if waiting else [items[-1]]
	func _pick_interaction_target_index(_items: Array, _excluded: Array, _step: Dictionary, _context: Dictionary = {}) -> int:
		return -1 if waiting else 0

func test_all_author_adapters_preserve_pending_search_and_target() -> String:
	var owner := WaitingOwner.new()
	var checks: Array[String] = []
	for adapter: RefCounted in [Owner.PublicInteractionAdapter.new(owner), Reviewed.ReviewedPublicInteractionAdapter.new(owner), Cynthia.CynthiaPublicInteractionAdapter.new(owner)]:
		var resolver := AIStepResolver.new()
		resolver.deck_strategy = adapter
		var plan: Dictionary = resolver._pick_explicit_interaction_items_with_empty_support(["A"], {}, 1, {"source": "search"})
		checks.append(assert_true(plan.get("decision_pending", false), "pending search must not become generic selection"))
		checks.append(assert_eq(resolver._best_legal_target_index(["A"], [], {}), -2, "pending target must wait"))
		checks.append(assert_eq(owner.context_seen, {"source":"search"}, "all adapters must forward interaction context"))
		adapter.set("owner", null)
	return run_checks(checks)

func test_worker_assignment_retains_source_identity_and_rebinds_current_indices() -> String:
	var owner := WaitingOwner.new()
	owner.waiting = false
	var resolver := AIStepResolver.new()
	var adapter := Reviewed.ReviewedPublicInteractionAdapter.new(owner)
	resolver.deck_strategy = adapter
	var first: Dictionary = resolver._build_assignment_source_plan(["A", "B"], 1, 1, {}, {}, [], "window")
	owner.waiting = true # Target worker is outstanding; never reselect source.
	var second: Dictionary = resolver._build_assignment_source_plan(["B", "A"], 1, 1, {}, {}, [], "window")
	var stale: Dictionary = resolver._build_assignment_source_plan(["C", "A"], 1, 1, {}, {}, [], "window")
	adapter.owner = null
	return run_checks([
		assert_eq(first.get("selected_source_indices"), [1]),
		assert_eq(second.get("selected_source_indices"), [0], "semantic source must bind to its new current index"),
		assert_eq(owner.source_calls, 1, "waiting target must not restart source policy"),
		assert_true(stale.get("unresolvable", false), "removed source must fail closed"),
	])

func test_close_releases_all_author_adapter_cycles_and_revokes_old_adapter() -> String:
	var checks: Array[String] = []
	for spec: Array in [[Owner, Owner.PublicInteractionAdapter], [Reviewed, Reviewed.ReviewedPublicInteractionAdapter], [Cynthia, Cynthia.CynthiaPublicInteractionAdapter]]:
		var owner: Variant = spec[0].new()
		var adapter: Variant = spec[1].new(owner)
		owner._interaction_adapter = adapter
		owner._step_resolver = AIStepResolver.new()
		owner._step_resolver.set_deck_strategy(adapter)
		var observed: WeakRef = weakref(owner)
		owner.close_match()
		checks.append(assert_null(adapter.owner, "closed match must revoke retained interaction adapters"))
		owner = null
		checks.append(assert_null(observed.get_ref(), "closed author owner must be released without test-only cycle cleanup"))
		# Release the deliberately failing baseline fixture too.
		adapter.owner = null
	return run_checks(checks)
