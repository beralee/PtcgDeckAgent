extends SceneTree
## A staged legal board; Boss's Orders goes through the real rule owner.
## --reference records the unmodified 2D VFX; --stills records the 3D timing beats.
const OUT := "res://.tmp/boss-director-20260929"
var rig: Node
var presenter: Control
var elapsed := 0.0
var capturing := false
var fired := false
var reference := false
var fast := false
var replayed := false
var actor: CardInstance
var target: PokemonSlot

class Ticker extends Node:
	var owner_tree: SceneTree
	func _process(delta: float) -> void:owner_tree.tick(delta)

func _initialize() -> void:
	root.set_meta("performance_bench_offline",true)
	ProjectSettings.set_setting("editor/movie_writer/mjpeg_quality",.83)
	call_deferred("launch")

func launch() -> void:
	root.size=Vector2i(1600,900)
	root.content_scale_size=Vector2i(1600,900)
	reference="--reference" in OS.get_cmdline_user_args()
	fast="--fast" in OS.get_cmdline_user_args()
	rig=load("res://scripts/tools/ArenaSignatureScenario.gd").new()
	root.add_child(rig)
	await rig.mount("dragapult",0,not reference)
	presenter=rig.battle.get_node_or_null("Arena3DPresenter")
	if not reference:
		presenter.world.configure_quality(false)
		presenter.viewport.msaa_3d=Viewport.MSAA_4X
		presenter.motion.fast_enabled=fast
	_prepare_card()
	var ticker:=Ticker.new()
	ticker.owner_tree=self
	ticker.process_priority=1000
	root.add_child(ticker)
	for i: int in 6:await process_frame
	if "--stills" in OS.get_cmdline_user_args():
		_play()
		presenter.world.supporter_vfx.manual_clock=true
		presenter.motion.set_process(false)
		for mark: float in [.0,.26,.70,1.08,1.56,2.10,2.78,3.10]:
			presenter.world.supporter_vfx.sample(mark)
			if mark>=1.78:presenter.motion.hold=0
			if mark>=3.05:presenter.world.supporter_vfx.clear()
			for i: int in 4:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"/beat-%03d.png" % roundi(mark*100))
		print("BOSS_STILLS_COMPLETE")
		quit()
	else:
		print("BOSS_RECORDING_READY")
		capturing=true

func _prepare_card() -> void:
	var player: PlayerState=rig.gsm.game_state.players[0]
	actor=CardInstance.create(root.get_node("CardDatabase").get_card("CSVH1aC","023"),0)
	player.deck.pop_back()
	player.hand.append(actor)
	target=rig.gsm.game_state.players[1].bench[1]
	rig.battle.call("_refresh_ui")
	if not reference:
		presenter.motion.clear()
		presenter.motion.shown={}
		presenter._refresh()

func _play() -> void:
	var played: bool=rig.gsm.play_trainer(0,actor,[{"opponent_bench_target":[target]}])
	assert(played,"Boss must successfully resolve through GameStateMachine")
	assert(rig.gsm.game_state.players[1].active_pokemon==target,"The actual selected bench target is now active")
	if not reference:
		assert(presenter.world.supporter_vfx.last_outcome.get("id")=="boss")
	print("BOSS_COMMITTED ",elapsed)

func tick(delta: float) -> void:
	if not capturing:return
	if elapsed>=.70 and not fired:
		fired=true
		_play()
	if elapsed>=5.1:
		capturing=false
		print("BOSS_RECORDING_COMPLETE")
		quit()
	elapsed+=delta
