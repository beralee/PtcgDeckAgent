extends TestBase

func test_signature_direction_has_species_specific_paths_and_recovery() -> String:
	var path := "res://scenes/arena3d/ArenaPokemonDirection.gd"
	if not ResourceLoader.exists(path): return assert_true(false,"Pokemon need distinct travel, disappearance, impact and aftermath choreography")
	var director = load(path)
	var checks: Array[String] = []
	var a := Vector3(0,0,-3)
	var b := Vector3(0,0,3)
	var flight: Array[Vector3] = []
	for t: float in [.70,1.20,1.70,2.20]: flight.append(director.sample("garchomp",t,a,b).position)
	checks.append(assert_true(flight[0].x*flight[1].x < 0,"Garchomp crosses opposite flanks at speed"))
	checks.append(assert_true(flight[1].distance_to(flight[2])>4.0,"Garchomp's second flyby crosses the board, not a short in-place lunge"))
	checks.append(assert_true(director.sample("zoroark",.90,a,b).visibility<.05,"Zoroark disappears into darkness before the ambush"))
	checks.append(assert_true(director.sample("zoroark",1.65,a,b).position.distance_to(b)<3.0,"Zoroark materializes at the committed victim"))
	var quake: Dictionary=director.sample("raging_bolt",2.35,a,b)
	checks.append(assert_true(quake.quake>.1,"Thunder leaves a visible ground-shaking aftermath after impact"))
	for id: String in preload("res://scenes/arena3d/ArenaPokemonCatalog.gd").ENTRIES:
		var profile: Dictionary=director.profile(id)
		checks.append(assert_true(profile.hit<profile.settle and profile.settle<profile.duration,"Outcome pacing has a valid impact and recovery: "+id))
		var ended: Dictionary=director.sample(id,profile.duration+.1,a,b)
		checks.append(assert_true(ended.quake==0 and ended.darkness==0 and ended.visibility==0,"Every signature restores the board: "+id))
	return run_checks(checks)

func test_gardevoir_has_a_real_character_and_ability_entry_point() -> String:
	var catalog = preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")
	if not catalog.ENTRIES.has("gardevoir"): return assert_true(false,"Requested Gardevoir needs a model and committed Psychic Embrace animation")
	var motion: Node=load("res://scenes/arena3d/ArenaMotionDirector.gd").new()
	var checks: Array[String]=[assert_true(ResourceLoader.exists("res://assets/arena3d/pokemon/gardevoir.glb"),"Gardevoir is volumetric"),assert_true(motion.has_method("start_psychic_embrace"),"Ability integrates with the production visual owner")]
	motion.free()
	return run_checks(checks)

func test_embrace_projection_rejects_hidden_replacement_and_noncommitted_effects() -> String:
	var cue=preload("res://scenes/arena3d/ArenaPokemonAbilityCue.gd")
	var caster: Dictionary={"empty":false,"concealed":false,"name":"沙奈朵ex","uid":"CSV2C_055","visual_id":"caster","energy":[],"damage":0}
	var target: Dictionary={"empty":false,"concealed":false,"name":"愿增猿","visual_id":"recipient","energy":["D"],"damage":0}
	var before: Dictionary={"slots":{"opp_active":caster,"opp_bench_0":target}}
	var after: Dictionary=before.duplicate(true)
	after.slots.opp_bench_0.energy.append("P")
	after.slots.opp_bench_0.damage=20
	var checks: Array[String]=[assert_eq(cue.project("opp_active",before,after).get("target"),"opp_bench_0","Committed public energy and damage choose the real ally")]
	after.slots.opp_bench_0.visual_id="replacement"
	checks.append(assert_true(cue.project("opp_active",before,after).is_empty(),"A replacement cannot inherit another Pokemon's cue"))
	after.slots.opp_bench_0.visual_id="recipient"
	before.slots.opp_active.concealed=true
	checks.append(assert_true(cue.project("opp_active",before,after).is_empty(),"A concealed caster cannot be revealed by character animation"))
	before.slots.opp_active.concealed=false
	after.slots.opp_bench_0.damage=0
	checks.append(assert_true(cue.project("opp_active",before,after).is_empty(),"An ordinary attachment cannot counterfeit Psychic Embrace"))
	return run_checks(checks)
