extends TestBase


func test_discarded_assertion() -> String:
	assert_eq(1, 2, "deliberately discarded assertion")
	return ""
