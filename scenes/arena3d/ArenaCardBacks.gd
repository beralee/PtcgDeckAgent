extends RefCounted
## Viewer-relative presentation. Never reads a card identity or hidden state.
const OWN := preload("res://assets/ui/card_backs/official-international.jpg")
const GOLD_SOURCE := preload("res://assets/ui/card_backs/japanese-gold-source.png")
static var gold: Texture2D

static func for_side(mine: bool) -> Texture2D:
	if mine: return OWN
	if gold == null:
		# Sample only the card rectangle in the unchanged reference atlas. Its
		# surrounding layout and drop shadow must never be stretched onto a card.
		var source := GOLD_SOURCE.get_image()
		if source.is_compressed(): source.decompress()
		gold = ImageTexture.create_from_image(source.get_region(Rect2i(78,99,474,663)))
		gold.resource_name = "JapaneseGoldBack"
	return gold

static func bind_view(scene: Object, view: int) -> void:
	# The legacy reveal owner stores seat textures; the 3D layout stores roles.
	scene.set("_player_card_back_texture",for_side(view == 0))
	scene.set("_opponent_card_back_texture",for_side(view == 1))
