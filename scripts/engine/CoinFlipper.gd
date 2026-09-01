## 投币系统 - 处理所有需要投币判定的游戏操作
class_name CoinFlipper
extends RefCounted

const RandomEventPortScript = preload("res://scripts/engine/RandomEventPort.gd")

## 投币完成信号，result: true=正面, false=反面
signal coin_flipped(result: bool)

var random_event_port: RefCounted
var _rng: RandomNumberGenerator


func _init(port: RefCounted = null) -> void:
	random_event_port = port if port != null else RandomEventPortScript.new()
	# Kept as an alias for existing deterministic benchmark seed controls. All
	# draws still flow through RandomEventPort.
	_rng = random_event_port.call("legacy_rng") as RandomNumberGenerator


## 投一次硬币，返回 true=正面, false=反面
func flip() -> bool:
	return flip_with_metadata({})


func flip_with_metadata(metadata: Dictionary) -> bool:
	var result: bool = bool(random_event_port.call("coin", metadata))
	coin_flipped.emit(result)
	return result


## 投多次硬币，返回结果数组
func flip_multiple(count: int) -> Array[bool]:
	return flip_multiple_with_metadata(count, {})


func flip_multiple_with_metadata(count: int, metadata: Dictionary) -> Array[bool]:
	var results: Array[bool] = []
	for i: int in count:
		var current := metadata.duplicate(true)
		current["event_in_group"] = i
		results.append(flip_with_metadata(current))
	return results


## 统计多次投币中正面的数量
func count_heads(results: Array[bool]) -> int:
	var count := 0
	for r: bool in results:
		if r:
			count += 1
	return count


## 投币直到出现反面，返回正面次数（用于"投币直到反面"类招式）
func flip_until_tails() -> int:
	var heads := 0
	while flip():
		heads += 1
	return heads


func push_context(metadata: Dictionary) -> int:
	return int(random_event_port.call("push_context", metadata))


func pop_context(token: int) -> bool:
	return bool(random_event_port.call("pop_context", token))
