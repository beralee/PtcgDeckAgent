class_name TestPointerSequence
extends TestBase

const PointerSequenceScript := preload("res://scripts/ui/input/PointerSequence.gd")


func test_pointer_sequence_allows_only_one_owner_and_one_intent() -> String:
	var sequence: PointerSequence = PointerSequenceScript.new(11, 3, PointerSequenceScript.SOURCE_TOUCH, Vector2(40, 60), 1000)
	var first := sequence.consume("button_pressed", "modal", 1010)
	var duplicate := sequence.consume("slot_pressed", "board", 1015)
	return run_checks([
		assert_true(first, "The owning modal should consume the sequence"),
		assert_false(duplicate, "The same physical sequence must not submit a second intent"),
		assert_eq(sequence.owner, "modal", "The first owner must remain stable"),
		assert_eq(sequence.consumed_intent, "button_pressed", "The first intent must remain authoritative"),
	])


func test_pointer_cancel_never_completes_or_accepts_late_intent() -> String:
	var sequence: PointerSequence = PointerSequenceScript.new(12, 0, PointerSequenceScript.SOURCE_TOUCH, Vector2(12, 18), 2000)
	var cancelled := sequence.cancel("touchcancel", 2010)
	return run_checks([
		assert_true(cancelled, "An active touch should accept cancellation"),
		assert_eq(sequence.state, PointerSequenceScript.STATE_CANCELLED, "Cancelled pointer must reach a terminal state"),
		assert_false(sequence.consume("button_pressed", "page", 2020), "A late release must not submit an intent"),
		assert_false(sequence.complete(2030), "A cancelled sequence must not complete again"),
		assert_eq(sequence.consumed_intent, "", "Cancellation must not synthesize a click"),
	])


func test_touch_sequence_recognizes_nearby_synthetic_mouse_echo() -> String:
	var sequence: PointerSequence = PointerSequenceScript.new(13, 2, PointerSequenceScript.SOURCE_TOUCH, Vector2(100, 100), 3000)
	sequence.update_position(Vector2(104, 98), 3020)
	return run_checks([
		assert_true(sequence.is_possible_synthetic_echo(Vector2(106, 101), 3040), "Nearby mouse event in the same time range should be treated as a touch echo"),
		assert_false(sequence.is_possible_synthetic_echo(Vector2(180, 180), 3040), "A distant mouse event should remain independent"),
		assert_false(sequence.is_possible_synthetic_echo(Vector2(106, 101), 4000), "A much later mouse event should remain independent"),
	])


func test_completed_sequence_is_idempotent() -> String:
	var sequence: PointerSequence = PointerSequenceScript.new(14, 0, PointerSequenceScript.SOURCE_MOUSE, Vector2.ZERO, 4000)
	var first := sequence.complete(4010)
	var second := sequence.complete(4020)
	var cancel_after_complete := sequence.cancel("late_blur", 4030)
	return run_checks([
		assert_true(first, "The first completion should succeed"),
		assert_false(second, "A sequence must finish exactly once"),
		assert_false(cancel_after_complete, "A completed sequence must ignore late cancellation"),
		assert_eq(sequence.finished_at_msec, 4010, "Late callbacks must not rewrite the terminal timestamp"),
	])
