extends SceneTree

const CardCatalogIndexScript := preload("res://scripts/card_catalog/CardCatalogIndex.gd")


func _initialize() -> void:
	var catalog := CardCatalogIndexScript.new()
	if not catalog.is_ready():
		print("Card catalog validation failed: catalog is not ready")
		quit(1)
		return
	print("Card catalog validation passed: version=%s cards=%d" % [catalog.get_catalog_version(), catalog.card_count()])
	quit(0)
