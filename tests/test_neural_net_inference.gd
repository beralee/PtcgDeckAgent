class_name TestNeuralNetInference
extends TestBase

const NeuralNetInferenceScript = preload("res://scripts/ai/NeuralNetInference.gd")


func _make_simple_weights() -> Dictionary:
	return {
		"architecture": "mlp",
		"input_dim": 2,
		"layers": [
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": [[1.0, 1.0]],
				"bias": [0.0],
			}
		]
	}


func _make_two_layer_weights() -> Dictionary:
	return {
		"architecture": "mlp",
		"input_dim": 2,
		"layers": [
			{
				"out_features": 2,
				"activation": "relu",
				"weights": [[1.0, 0.0], [0.0, 1.0]],
				"bias": [0.0, 0.0],
			},
			{
				"out_features": 1,
				"activation": "sigmoid",
				"weights": [[0.5, 0.5]],
				"bias": [0.0],
			}
		]
	}


func _make_full_size_weights() -> Dictionary:
	var layer1_w: Array = []
	for _i in 64:
		var row: Array = []
		row.resize(30)
		row.fill(0.0)
		layer1_w.append(row)
	var layer1_b: Array = []
	layer1_b.resize(64)
	layer1_b.fill(0.0)

	var layer2_w: Array = []
	for _i in 32:
		var row: Array = []
		row.resize(64)
		row.fill(0.0)
		layer2_w.append(row)
	var layer2_b: Array = []
	layer2_b.resize(32)
	layer2_b.fill(0.0)

	var layer3_w: Array = [[]]
	layer3_w[0] = []
	layer3_w[0].resize(32)
	layer3_w[0].fill(0.0)
	var layer3_b: Array = [0.0]

	return {
		"architecture": "mlp",
		"input_dim": 30,
		"layers": [
			{"out_features": 64, "activation": "relu", "weights": layer1_w, "bias": layer1_b},
			{"out_features": 32, "activation": "relu", "weights": layer2_w, "bias": layer2_b},
			{"out_features": 1, "activation": "sigmoid", "weights": layer3_w, "bias": layer3_b},
		]
	}


func test_load_weights_from_dict() -> String:
	var net := NeuralNetInferenceScript.new()
	var ok: bool = net.load_weights_from_dict(_make_simple_weights())
	return run_checks([
		assert_true(ok, "加载简单权重应成功"),
		assert_true(net.is_loaded(), "加载后 is_loaded 应为 true"),
	])


func test_predict_simple_sigmoid() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_simple_weights())
	var result: float = net.predict([1.0, 1.0])
	return run_checks([
		assert_true(absf(result - 0.8808) < 0.01, "sigmoid(2) 应约为 0.8808，实际 %.4f" % result),
	])


func test_predict_two_layer() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var result: float = net.predict([2.0, 3.0])
	return run_checks([
		assert_true(absf(result - 0.924) < 0.01, "两层网络输出应约为 0.924，实际 %.4f" % result),
	])


func test_predict_relu_clips_negative() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var result: float = net.predict([-5.0, -3.0])
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "负输入经 relu 后应得 sigmoid(0)=0.5，实际 %.4f" % result),
	])


func test_predict_full_size_zero_weights() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_full_size_weights())
	var input: Array[float] = []
	input.resize(30)
	input.fill(1.0)
	var result: float = net.predict(input)
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "全零权重应输出 0.5，实际 %.4f" % result),
	])


func test_predict_not_loaded_returns_fallback() -> String:
	var net := NeuralNetInferenceScript.new()
	var result: float = net.predict([1.0, 2.0])
	return run_checks([
		assert_true(absf(result - 0.5) < 0.01, "未加载时应返回 0.5，实际 %.4f" % result),
	])


func test_load_and_save_json_roundtrip() -> String:
	var net := NeuralNetInferenceScript.new()
	net.load_weights_from_dict(_make_two_layer_weights())
	var path := "user://test_nn_weights_roundtrip.json"
	var save_ok: bool = net.save_weights(path)
	var net2 := NeuralNetInferenceScript.new()
	var load_ok: bool = net2.load_weights(path)
	var result1: float = net.predict([2.0, 3.0])
	var result2: float = net2.predict([2.0, 3.0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return run_checks([
		assert_true(save_ok, "保存权重应成功"),
		assert_true(load_ok, "加载权重应成功"),
		assert_true(absf(result1 - result2) < 0.001, "往返后推理结果应一致"),
	])
