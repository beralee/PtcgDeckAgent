class_name NeuralNetInference
extends RefCounted

## 纯 GDScript 前馈网络推理。
## 加载 JSON 权重，执行矩阵-向量乘法。
## 网络结构: Input -> [Linear + Activation] * N -> Output

var _layers: Array[Dictionary] = []
var _loaded: bool = false


func is_loaded() -> bool:
	return _loaded


func load_weights(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[NeuralNetInference] 无法打开权重文件: %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[NeuralNetInference] JSON 解析失败: %s" % json.get_error_message())
		return false
	var data: Variant = json.data
	if not data is Dictionary:
		return false
	return load_weights_from_dict(data as Dictionary)


func load_weights_from_dict(data: Dictionary) -> bool:
	_layers.clear()
	_loaded = false
	var layers_data: Variant = data.get("layers", [])
	if not layers_data is Array:
		return false
	for layer_data: Variant in layers_data:
		if not layer_data is Dictionary:
			return false
		var ld: Dictionary = layer_data as Dictionary
		var weights: Variant = ld.get("weights", [])
		var bias: Variant = ld.get("bias", [])
		var activation: String = str(ld.get("activation", "relu"))
		if not weights is Array or not bias is Array:
			return false
		_layers.append({
			"weights": weights,
			"bias": bias,
			"activation": activation,
		})
	_loaded = not _layers.is_empty()
	return _loaded


func save_weights(path: String) -> bool:
	var layers_out: Array = []
	for layer: Dictionary in _layers:
		layers_out.append({
			"out_features": (layer.get("bias", []) as Array).size(),
			"activation": layer.get("activation", "relu"),
			"weights": layer.get("weights", []),
			"bias": layer.get("bias", []),
		})
	var data := {
		"architecture": "mlp",
		"input_dim": 0,
		"layers": layers_out,
	}
	if not _layers.is_empty():
		var first_weights: Array = _layers[0].get("weights", [])
		if not first_weights.is_empty() and first_weights[0] is Array:
			data["input_dim"] = (first_weights[0] as Array).size()
	var text: String = JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func predict(features: Variant) -> float:
	if not _loaded:
		return 0.5
	var input: Array = []
	if features is Array:
		for f: Variant in features:
			input.append(float(f))
	else:
		return 0.5

	for layer: Dictionary in _layers:
		var weights: Array = layer.get("weights", [])
		var bias: Array = layer.get("bias", [])
		var activation: String = str(layer.get("activation", "relu"))
		var output: Array = []
		for j in weights.size():
			var row: Array = weights[j]
			var sum: float = float(bias[j]) if j < bias.size() else 0.0
			for i in row.size():
				if i < input.size():
					sum += float(row[i]) * float(input[i])
			output.append(sum)
		if activation == "relu":
			for k in output.size():
				if output[k] < 0.0:
					output[k] = 0.0
		elif activation == "sigmoid":
			for k in output.size():
				output[k] = _sigmoid(float(output[k]))
		input = output

	return float(input[0]) if not input.is_empty() else 0.5


static func _sigmoid(x: float) -> float:
	if x > 20.0:
		return 1.0
	if x < -20.0:
		return 0.0
	return 1.0 / (1.0 + exp(-x))
