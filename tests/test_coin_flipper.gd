## 投币系统测试
class_name TestCoinFlipper
extends TestBase


func test_flip_returns_bool() -> String:
	var flipper := CoinFlipper.new()
	var result: Variant = flipper.flip()
	return run_checks([
		assert_eq(result is bool, true, "flip() should return a bool"),
	])


func test_flip_multiple_count() -> String:
	var flipper := CoinFlipper.new()
	var results: Array[bool] = flipper.flip_multiple(5)
	return run_checks([
		assert_eq(results.size(), 5, "flip_multiple(5) should return 5 results"),
	])


func test_count_heads() -> String:
	var flipper := CoinFlipper.new()
	var results: Array[bool] = [true, false, true, true, false]
	return run_checks([
		assert_eq(flipper.count_heads(results), 3, "count_heads should count 3 heads"),
	])


func test_flip_until_tails_returns_non_negative() -> String:
	var flipper := CoinFlipper.new()
	var heads: int = flipper.flip_until_tails()
	return run_checks([
		assert_eq(heads >= 0, true, "flip_until_tails should return a non-negative value"),
	])


func test_coin_flipped_signal() -> String:
	var flipper := CoinFlipper.new()
	var signal_fired: Array[bool] = [false]
	flipper.coin_flipped.connect(func(_result: bool) -> void:
		signal_fired[0] = true
	)
	flipper.flip()
	return run_checks([
		assert_eq(signal_fired[0], true, "flip() should emit coin_flipped"),
	])
