extends TestBase

const Overlay = preload("res://scripts/ui/SceneLoadingOverlay.gd")
const Baseline = preload("res://scripts/ui/SceneLoadingBaseline.gd")

func test_event_estimates_preserve_platform_and_first_repeat_baselines() -> String:
	return run_checks([
		assert_gt(Baseline.expected_ms("navigation.battle_setup", false, "Windows", false), 1000.0, "First entry uses the dedicated cold-entry bench"),
		assert_true(Baseline.expected_ms("navigation.battle_setup", true, "Windows", false) < 150.0, "Repeat entry uses warm bench samples"),
		assert_gt(Baseline.expected_ms("battle.author_start", false, "Android", false), Baseline.expected_ms("battle.author_start", false, "Windows", false), "Android keeps its separate emulator reference"),
		assert_eq(Baseline.expected_ms("navigation.unknown", false, "Windows", false), 0.0, "Unmeasured events must not borrow a different page's duration"),
		assert_eq(Baseline.expected_ms("navigation.settings", false, "macOS", false), 0.0, "Unmeasured platforms use a marquee"),
	])

func test_estimate_scales_with_bench_duration_and_never_claims_completion() -> String:
	var previous := 0.0
	var checks: Array[String] = []
	for elapsed: float in [0.0, 250.0, 1000.0, 2000.0, 10000.0, 600000.0]:
		var value := Baseline.estimated_fraction(elapsed, 1000.0)
		checks.append(assert_gte(value, previous, "Estimated progress must never move backwards"))
		checks.append(assert_true(value < 1.0, "Elapsed time cannot prove readiness"))
		previous = value
	checks.append(assert_gt(Baseline.estimated_fraction(500.0, 600.0), Baseline.estimated_fraction(500.0, 3000.0), "Different bench events must produce different progress"))
	return run_checks(checks)

func test_progress_survives_stages_and_new_request_resets_it() -> String:
	var overlay := Overlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.begin("正在准备对战", "battle.author_start")
	overlay.started_usec -= int(overlay._expected_ms * 500.0)
	overlay._process(0.0)
	var started: int = overlay.started_usec
	var value: float = overlay._progress.value
	var checks: Array[String] = [assert_gt(value, 0.0, "Bench time should visibly advance the bar")]
	overlay.begin("正在校验策略")
	checks.append(assert_eq(overlay.started_usec, started, "A stage must retain the operation clock"))
	checks.append(assert_gte(overlay._progress.value, value, "A stage must not reset progress"))
	overlay.begin("正在打开", "navigation.settings")
	checks.append(assert_gt(overlay.started_usec, started, "A replacement operation starts a new clock"))
	checks.append(assert_true(overlay._progress.value < value, "A new page must not inherit the old operation's progress"))
	overlay.finish()
	checks.append(assert_eq(overlay._progress.value, 1.0, "Only readiness fills the bar"))
	overlay.queue_free()
	return run_checks(checks)

func test_success_uses_warm_baseline_but_failed_retry_remains_first_entry() -> String:
	var overlay := Overlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.begin("正在准备对战", "battle.author_start")
	var first_duration: float = overlay._expected_ms
	overlay.fail("准备失败")
	var checks: Array[String] = [assert_false(overlay._progress.visible, "Failure must stop the loading animation")]
	overlay.begin("正在准备对战", "battle.author_start")
	checks.append(assert_eq(overlay._expected_ms, first_duration, "Failed attempts cannot mark a case warm"))
	checks.append(assert_true(overlay._progress.visible and not overlay._back.visible, "Retry restores the loading state"))
	overlay.finish()
	overlay.begin("正在准备对战", "battle.author_start")
	checks.append(assert_eq(overlay._expected_ms, Baseline.expected_ms("battle.author_start", true), "A completed operation selects the repeat baseline"))
	overlay.finish()
	overlay.queue_free()
	return run_checks(checks)

func test_unmeasured_event_uses_a_marquee_without_a_percentage() -> String:
	var overlay := Overlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.begin("正在打开", "navigation.unmeasured")
	var checks: Array[String] = [
		assert_true(overlay._progress.indeterminate, "Missing bench evidence uses a rolling bar"),
		assert_false(overlay._progress.show_percentage, "Estimated or unknown progress must not display an exact percentage"),
	]
	overlay.finish()
	overlay.queue_free()
	return run_checks(checks)

func test_loading_uses_a_bar_instead_of_elapsed_seconds() -> String:
	var overlay := Overlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.begin("正在打开")
	var bars := overlay.find_children("*", "ProgressBar", true, false)
	var checks: Array[String] = [
		assert_eq(bars.size(), 1, "Loading must show a progress bar"),
		assert_false(overlay._detail.text.contains("秒"), "Loading must not expose the elapsed-second counter"),
	]
	overlay.finish()
	overlay.queue_free()
	return run_checks(checks)

func test_loading_feedback_survives_scene_work_and_failures_have_an_exit() -> String:
	var overlay := Overlay.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(overlay)
	overlay.begin("正在校验策略")
	var started: int = overlay.started_usec
	await tree.process_frame
	overlay.begin("正在准备对战")
	var same_request: bool = overlay.started_usec == started and overlay.visible
	overlay.fail("准备失败")
	var can_exit: bool = overlay._back.visible and overlay._detail.text.contains("返回")
	overlay.finish()
	var finished: bool = not overlay.visible
	overlay.queue_free()
	return run_checks([
		assert_true(same_request, "Stages must retain the same feedback clock"),
		assert_true(can_exit, "Failure must offer an exit"),
		assert_true(finished, "Completion must release the input shield"),
	])
