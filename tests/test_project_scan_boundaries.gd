class_name TestProjectScanBoundaries
extends TestBase

const GENERATED_RESOURCE_ROOT_MARKERS := [
	"res://tmp/.gdignore",
	"res://Godot/.gdignore",
	"res://artifacts/deck_training/.gdignore",
	"res://native/ptcgai_ort_actor/.gdignore",
]
const REQUIRED_AUTHOR_PACKAGE_FIXTURE := \
	"res://artifacts/ptcgdap/as_wp1/fixtures/valid_minimal.ptcgai"


func test_generated_resource_roots_stay_out_of_the_godot_scanner() -> String:
	var missing: Array[String] = []
	for marker: String in GENERATED_RESOURCE_ROOT_MARKERS:
		if not FileAccess.file_exists(marker):
			missing.append(marker)
	return assert_true(
		missing.is_empty(),
		"Generated data roots must retain their .gdignore boundaries; missing=%s" % [missing]
	)


func test_gitignore_keeps_generated_scan_markers_versionable() -> String:
	var source := FileAccess.get_file_as_string("res://.gitignore")
	return run_checks([
		assert_str_contains(source, "!tmp/.gdignore", "The tmp scanner boundary must remain versionable"),
		assert_str_contains(source, "!/Godot/.gdignore", "The Godot user-mirror boundary must remain versionable"),
		assert_str_contains(source, "!artifacts/deck_training/.gdignore", "The training-artifact boundary must remain versionable"),
	])


func test_author_package_fixtures_remain_visible_outside_training_artifacts() -> String:
	return assert_true(
		FileAccess.file_exists(REQUIRED_AUTHOR_PACKAGE_FIXTURE),
		"Scanner cleanup must not hide the author-package fixtures used by conformance tests"
	)
