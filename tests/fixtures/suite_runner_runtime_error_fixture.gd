extends RefCounted


func test_runtime_error_must_not_pass() -> String:
	var owner: Variant = RefCounted.new()
	owner.method_that_does_not_exist()
	return ""
