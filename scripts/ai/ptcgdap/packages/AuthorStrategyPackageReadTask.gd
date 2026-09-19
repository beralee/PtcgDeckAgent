class_name AuthorStrategyPackageReadTask
extends RefCounted

signal completed(result: Dictionary)

const ReaderScript = preload("res://scripts/ai/ptcgdap/packages/AuthorStrategyPackageSourceReader.gd")

var _task_id := -1
var _mutex := Mutex.new()
var _canceled := false
var _result: Dictionary = {}


func start(source: String) -> Error:
	if _task_id != -1:
		return ERR_BUSY
	_task_id = WorkerThreadPool.add_task(_capture.bind(source), false, "Read selected strategy package")
	return OK if _task_id >= 0 else ERR_CANT_CREATE


func cancel() -> void:
	_mutex.lock()
	_canceled = true
	_mutex.unlock()


func _is_canceled() -> bool:
	_mutex.lock()
	var value := _canceled
	_mutex.unlock()
	return value


func _capture(source: String) -> void:
	var result := ReaderScript.read_source(source, _is_canceled)
	_mutex.lock()
	_result = result
	_mutex.unlock()
	# The deferred argument owns this RefCounted until completion is collected.
	# The scene can exit without waiting for a document provider or retaining its
	# URI. No catalog, card database, scene, or installer is accessed by the task.
	call_deferred("_deliver", self)


func _deliver(_keep_alive: RefCounted) -> void:
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	_mutex.lock()
	var result := _result
	_result = {}
	if _canceled:
		result = {"ok": false, "error_code": "package_import_canceled"}
	_mutex.unlock()
	completed.emit(result)
