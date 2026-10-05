extends RefCounted
## Trusted scene-owner adapter. Private snapshots stay here, never in ArenaWorld,
## presentation DTOs or logs. Reuse exact movement detection, then allow-list ONLY
## role/count/direction. Even the local player's moving cards use anonymous backs.
const Snapshot := preload("res://scripts/ui/battle/visuals/BattleVisualSnapshot.gd")
const Builder := preload("res://scripts/ui/battle/visuals/BattleVisualEventBuilder.gd")
var _baseline: Dictionary = {}
var _view := -1

func prime(state: GameState, view: int) -> void:
	_baseline = Snapshot.capture(state)
	_view = view

func capture(action: GameAction, state: GameState, view: int) -> Array[Dictionary]:
	if _baseline.is_empty() or view != _view:
		prime(state,view)
		return []
	var after: Dictionary = Snapshot.capture(state)
	var events: Array[Dictionary] = Builder.build(_baseline,after,action,view)
	_baseline = Snapshot.retain_temporarily_missing_cards(_baseline,after)
	if state.turn_number <= 0 or state.phase in [GameState.GamePhase.SETUP,GameState.GamePhase.SETUP_PLACE,GameState.GamePhase.MULLIGAN]: return []
	return project(events,view)

static func project(events: Array[Dictionary], view: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.get("kind","") != "zone_transfer": continue
		var semantic: String = event.get("semantic","")
		var source: String = event.get("source_zone","")
		var target: String = event.get("target_zone","")
		var count := int(event.get("count",0))
		var owner := int(event.get("owner_index",-1))
		if owner not in [0,1] or count <= 0: continue
		var direction := ""
		if source.ends_with(".hand") and target.ends_with(".deck"): direction = "return"
		elif source.ends_with(".deck") and target.ends_with(".hand"): direction = "draw"
		elif source.ends_with(".hand") and target.ends_with(".discard") and semantic != "trainer_play" and count > 1: direction = "discard"
		if direction != "": result.append({"mine":owner == view,"count":count,"direction":direction})
	return result
