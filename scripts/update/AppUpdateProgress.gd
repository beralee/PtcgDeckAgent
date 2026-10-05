extends RefCounted
## Update progress formatting shared by the home entry and dialog.

static func percent(data: Dictionary) -> int:
	var completed := int(data.get("verified", 0)) if data.get("state") == "verifying" else int(data.get("downloaded", 0))
	return clampi(int(100.0 * completed / maxi(1, int(data.get("total", 0)))), 0, 100)

static func bytes_text(value: int) -> String:
	return "%.1f MB" % (value / 1048576.0) if value >= 1048576 else "%d KB" % (value / 1024)
