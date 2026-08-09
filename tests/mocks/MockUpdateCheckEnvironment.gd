class_name MockUpdateCheckEnvironment
extends RefCounted


class MockRequest:
	extends Node

	signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

	var request_error := OK
	var request_calls: Array[Dictionary] = []
	var cancel_count := 0


	func request(url: String, headers: PackedStringArray, method: int) -> int:
		request_calls.append({
			"url": url,
			"headers": headers.duplicate(),
			"method": method,
		})
		return request_error


	func cancel_request() -> void:
		cancel_count += 1


	func complete_json(data: Dictionary, response_code: int = 200) -> void:
		request_completed.emit(
			HTTPRequest.RESULT_SUCCESS,
			response_code,
			PackedStringArray(),
			JSON.stringify(data).to_utf8_buffer()
		)


	func complete_transport_failure(result: int = HTTPRequest.RESULT_CANT_CONNECT) -> void:
		request_completed.emit(result, 0, PackedStringArray(), PackedByteArray())


var state: Dictionary = {}
var now_unix := 1_000_000
var request_error := OK
var requests: Array[MockRequest] = []
var saved_states: Array[Dictionary] = []


func create_request() -> Node:
	var mock := MockRequest.new()
	mock.request_error = request_error
	requests.append(mock)
	return mock


func load_state() -> Dictionary:
	return state.duplicate(true)


func save_state(next_state: Dictionary) -> void:
	state = next_state.duplicate(true)
	saved_states.append(state.duplicate(true))


func current_unix_time() -> int:
	return now_unix


func latest_request() -> MockRequest:
	return requests.back() if not requests.is_empty() else null
