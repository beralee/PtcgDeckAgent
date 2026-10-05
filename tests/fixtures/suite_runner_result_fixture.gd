extends TestBase


func test_explicit_skip() -> String:
	return "SKIP: fixture is intentionally unavailable"


func test_skip_cannot_hide_assertion() -> String:
	assert_true(false, "SKIP: this is a failed assertion, not an unavailable fixture")
	return "SKIP: fixture is intentionally unavailable"


func test_invalid_return() -> int:
	return 0


func test_required_argument(_required: String) -> String:
	return ""
