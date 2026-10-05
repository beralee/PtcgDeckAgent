extends RefCounted
## One process owns one immutable content snapshot. No networking in engine/AI.

static func snapshot() -> Dictionary:
	return Engine.get_meta("ptcg_card_content_snapshot", {}).duplicate(true)

static func card(uid: String) -> Dictionary:
	return Engine.get_meta("ptcg_card_content_snapshot", {}).get("manifest", {}).get("cards", {}).get(uid, {}).duplicate(true)

static func card_uids() -> Array:
	return Engine.get_meta("ptcg_card_content_snapshot", {}).get("manifest", {}).get("cards", {}).keys()

static func release_id() -> String:
	var id := str(Engine.get_meta("ptcg_card_content_snapshot", {}).get("release_id", ""))
	return "bundled" if id == "" else id

static func image_path(uid: String) -> String:
	var item: Dictionary = card(uid)
	if item.get("image") is Dictionary:
		return "user://card_content/objects/%s.img" % item.image.sha256
	return ""

static func image_url(uid: String) -> String:
	var item: Dictionary = card(uid)
	if item.get("image") is Dictionary:
		return origin() + "/v1/card-content/objects/" + str(item.image.sha256)
	return ""

static func origin() -> String:
	return str(ProjectSettings.get_setting("ptcgdap/card_content/base_url", "https://api.ptcg.skillserver.cn")).trim_suffix("/")

static func trusted_url(url: String) -> bool:
	var base := origin()
	if not base.begins_with("https://"): return false
	return url.begins_with(base + "/v1/card-content/objects/") and preload("res://scripts/card_content/ContentManifest.gd").matches("^[0-9a-f]{64}$", url.trim_prefix(base + "/v1/card-content/objects/"))
