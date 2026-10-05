extends Node
## Real loopback HTTP, streaming the bundled APK through the production downloader.
const INVALID := "This is deliberately not an APK."
var server := TCPServer.new()
var port := 18761
var clients: Array[Dictionary] = []
var package_path := "res://payload/release.apk"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for candidate: int in range(18761, 18771):
		if server.listen(candidate, "127.0.0.1") == OK:
			port = candidate
			return
	push_error("Lab HTTP server could not start")

func _process(_delta: float) -> void:
	while server.is_connection_available():
		clients.append({"peer": server.take_connection(), "request": "", "sent": 0, "buffer": PackedByteArray(), "next": 0})
	for client: Dictionary in clients.duplicate():
		var peer: StreamPeerTCP = client.peer
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_close(client)
			continue
		if not client.has("mode"):
			if peer.get_available_bytes() > 0:
				client.request += peer.get_utf8_string(mini(peer.get_available_bytes(), 4096))
			if client.request.length() > 4096:
				_close(client)
			elif "\r\n\r\n" in client.request:
				_begin_response(client)
			continue
		if client.mode == "stall" or Time.get_ticks_msec() < client.next:
			continue
		if client.sent >= client.limit:
			_close(client)
			continue
		if client.buffer.is_empty():
			var count := mini(65536 if client.mode != "slow" else 8192, client.limit - client.sent)
			if client.mode == "invalid":
				client.buffer = INVALID.to_utf8_buffer().slice(client.sent, client.sent + count)
			else:
				client.buffer = client.file.get_buffer(count)
				if client.mode == "corrupt" and client.sent == 0:
					client.buffer[0] = client.buffer[0] ^ 1
			if client.buffer.is_empty():
				_close(client)
				continue
		var result := peer.put_partial_data(client.buffer)
		if result[0] != OK:
			_close(client)
			continue
		client.sent += result[1]
		client.buffer = client.buffer.slice(result[1])
		client.next = Time.get_ticks_msec() + (60 if client.mode == "slow" else 0)

func _begin_response(client: Dictionary) -> void:
	var words: PackedStringArray = client.request.split("\r\n")[0].split(" ")
	var mode := str(words[1]).trim_prefix("/") if words.size() >= 2 else "missing"
	if mode not in ["good", "slow", "drop", "truncated", "corrupt", "invalid", "stall"] or not FileAccess.file_exists(package_path):
		client.peer.put_data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".to_utf8_buffer())
		_close(client)
		return
	client.mode = mode
	client.file = FileAccess.open(package_path, FileAccess.READ)
	client.total = INVALID.to_utf8_buffer().size() if mode == "invalid" else client.file.get_length()
	client.limit = int(client.total / 2) if mode in ["drop", "truncated"] else client.total
	var length: int = client.limit if mode == "truncated" else client.total
	client.peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/vnd.android.package-archive\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % length).to_utf8_buffer())

func _close(client: Dictionary) -> void:
	client.peer.disconnect_from_host()
	client.erase("file")
	clients.erase(client)

func _exit_tree() -> void:
	for client: Dictionary in clients.duplicate():
		_close(client)
	server.stop()
