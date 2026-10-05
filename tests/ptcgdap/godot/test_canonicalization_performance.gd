extends TestBase

const JsonTree = preload("res://scripts/ai/ptcgdap/cabt/CabtJsonTree.gd")

func test_large_repeated_public_vocabulary_stays_within_one_second() -> String:
	# Policy files repeat the same field names/threat vocabulary thousands of times.
	# Keep this CPU regression separate from rendered device/frame acceptance.
	var rows: Array = []
	for index: int in 10000:
		rows.append({"option.kind": "attach_energy", "target_uid": "CSV10C_147",
			"goal_stage": "maintain", "priority": index, "source_uid": "CSV8C_094"})
	var started := Time.get_ticks_usec()
	var result := JsonTree.canonicalize(rows)
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var decoded: Variant = JSON.parse_string(result.get("text", ""))
	var intact: bool = decoded is Array and decoded.size() == rows.size()
	if intact:
		for index: int in rows.size():
			var row: Dictionary = decoded[index]
			intact = intact and row.size() == 5 and int(row.get("priority", -1)) == index \
				and row.get("target_uid") == "CSV10C_147" and row.get("source_uid") == "CSV8C_094" \
				and row.get("option.kind") == "attach_energy" and row.get("goal_stage") == "maintain"
	return run_checks([
		assert_true(result.get("ok", false), "Canonicalization must succeed"),
		assert_true(intact, "All rows and values must survive"),
		assert_true(elapsed_ms < 1000.0, "Repeated-vocabulary canonicalization took %.1f ms" % elapsed_ms),
	])

func test_repeated_unicode_keys_keep_jcs_and_artifact_ordering() -> String:
	var astral := String.chr(0x10000)
	var bmp := String.chr(0xe000)
	var leaf := {astral: "玛俐\n\t\"\\", bmp: "玛俐\n\t\"\\"}
	var jcs := JsonTree.canonicalize([leaf, leaf])
	var artifact := JsonTree.canonicalize_artifact([leaf, leaf])
	var encoded := '"玛俐\\n\\t\\\"\\\\"'
	var first := '{"%s":%s,"%s":%s}' % [astral, encoded, bmp, encoded]
	var second := '{"%s":%s,"%s":%s}' % [bmp, encoded, astral, encoded]
	return run_checks([
		assert_eq(jcs.get("text"), "[%s,%s]" % [first, first]),
		assert_eq(artifact.get("text"), "[%s,%s]" % [second, second]),
		assert_eq(JsonTree.canonicalize([leaf, leaf], {"max_output_bytes": 10}).get("error_code"), "output_size_limit"),
		assert_eq(JsonTree.canonicalize({StringName("same"): 1}).get("error_code"), "non_string_key"),
		assert_eq(JsonTree.canonicalize(String.chr(0xffff)).get("error_code"), "invalid_unicode"),
	])

func test_literal_memo_preserves_duplicate_escape_and_resource_rejections() -> String:
	return run_checks([
		assert_eq(JsonTree.canonicalize_json_bytes('{"a":1,"\\u0061":2}'.to_utf8_buffer()).get("error_code"), "duplicate_key"),
		assert_eq(JsonTree.canonicalize_json_bytes('["same","same","bad\nvalue"]'.to_utf8_buffer()).get("error_code"), "invalid_json"),
		assert_eq(JsonTree.canonicalize_json_bytes('["same","same"]'.to_utf8_buffer(), {"max_output_bytes": 8}).get("error_code"), "output_size_limit"),
		assert_eq(JsonTree.canonicalize_artifact_json_bytes('["same","same",1.5]'.to_utf8_buffer()).get("ok"), false),
	])
