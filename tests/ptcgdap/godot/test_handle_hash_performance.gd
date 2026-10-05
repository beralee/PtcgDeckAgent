extends TestBase

const Handle = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageHandle.gd")
const JsonTree = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

func test_handle_hash_keeps_artifact_bytes_and_rechecks_mutations() -> String:
	var value := {"pins": {"count": 60, "nullable": null, "scope": ["windows"]},
		"name": "玛俐\n\\\"", String.chr(0x10000): 7, String.chr(0xe000): true}
	var old_bytes: PackedByteArray = JsonTree.canonicalize_artifact_json_bytes(JSON.stringify(value).to_utf8_buffer()).get("bytes")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(old_bytes)
	var expected := ctx.finish().hex_encode().to_upper()
	var actual := Handle._canonical_hash(value)
	value.pins.count = 59
	return run_checks([
		assert_eq(actual, expected, "Hash identity must not change"),
		assert_true(Handle._canonical_hash(value) != actual, "Mutated data must be rehashed"),
		assert_eq(Handle._canonical_hash({"value": 1.000001}), "", "Non-integral artifacts must fail"),
		assert_eq(Handle._canonical_hash({"value": 60.0}), "", "Integral floats must also fail"),
	])

func test_small_handle_snapshots_leave_time_for_the_next_frame() -> String:
	var rows: Array = []
	for index: int in 30:
		rows.append({"local_card_uid": "CSV10C_%03d" % index, "count": 2, "mapping_status": "exact"})
	var started := Time.get_ticks_usec()
	for index: int in 20:
		if Handle._canonical_hash(rows).is_empty(): return "Unexpected hash failure"
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	return assert_true(elapsed < 100.0, "20 small snapshots took %.1f ms" % elapsed)
