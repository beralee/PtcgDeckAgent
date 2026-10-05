extends Node
## Opt-in diagnostic only: explicitly excluded from performance acceptance.
## Time actual owners in tree order; do not instrument production battles.
var entries: Array[Dictionary] = []

func install(root: Node) -> void:
	process_priority = 100
	for node: Node in [root]+root.find_children("*","",true,false):
		if not node.is_processing() or not node.has_method("_process"): continue
		entries.append({"node":node,"path":str(root.get_path_to(node)),"script":node.get_script().resource_path,"ms":[]})
		node.set_process(false)

func _process(delta: float) -> void:
	for entry: Dictionary in entries:
		if not is_instance_valid(entry.node): continue
		var start := Time.get_ticks_usec()
		entry.node.call("_process",delta)
		entry.ms.append(float(Time.get_ticks_usec()-start)/1000.0)

func finish() -> Array:
	var result: Array = []
	for entry: Dictionary in entries:
		if is_instance_valid(entry.node): entry.node.set_process(true)
		result.append({"path":entry.path,"script":entry.script,"timing":preload("res://scripts/performance/PerformanceStatistics.gd").summarize(entry.ms)})
	return result
