extends SceneTree

class LocalUpdater extends "res://scripts/update/AppUpdater.gd":
	func _restore_pending() -> void: pass
	func _save_pending() -> void: pass
	func _validated_artifact(info: Dictionary) -> Dictionary: return info.artifact.duplicate(true)
	func _stall_timeout_ms() -> int: return 250
	func _package_path() -> String: return "user://app_updates/stalled-test.zip"

var server := TCPServer.new()
var peers: Array[Dictionary] = []
var updater: Node
var started := 0
var stage := 0
var frames := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var port := 18791
	while port < 18811 and server.listen(port, "127.0.0.1") != OK:
		port += 1
	if not server.is_listening():
		quit(1)
		return
	updater = LocalUpdater.new()
	root.add_child(updater)
	updater.offer({"latest_version": "99.0.0", "artifact": {"url": "http://127.0.0.1:%d/stall" % port, "size": 128, "sha256": "a".repeat(64), "format": "windows_zip", "entry": "Game.exe", "arch": "x86_64"}})
	started = Time.get_ticks_msec()
	updater.start_download()
	stage = 1

func _process(_delta: float) -> bool:
	if stage == 0:
		return false
	while server.is_connection_available():
		peers.append({"peer": server.take_connection(), "answered": false})
	for client: Dictionary in peers:
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if not client.answered and peer.get_available_bytes() > 0:
			peer.get_data(peer.get_available_bytes())
			peer.put_data("HTTP/1.1 200 OK\r\nContent-Length: 128\r\n\r\n".to_utf8_buffer())
			client.answered = true # Deliberately keep socket open forever, with no body.
	if Time.get_ticks_msec() - started > 3000:
		push_error("Stalled transport did not remain responsive")
		quit(1)
	if stage == 1 and updater.snapshot().state == "failed":
		updater.start_download()
		stage = 2
	elif stage == 2:
		frames += 1
		if frames >= 3:
			updater.cancel_download()
			if updater.snapshot().state != "cancelled":
				quit(1)
				return false
			for client: Dictionary in peers:
				client.peer.disconnect_from_host()
			server.stop()
			print("STALLED_TRANSPORT_PASS: real TCP timeout and cancellation returned without freezing")
			quit(0)
	return false
