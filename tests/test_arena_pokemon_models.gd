extends TestBase

const EXPANDED := ["ceruledge", "terapagos", "grimmsnarl", "zoroark", "archaludon", "ho_oh", "budew", "garchomp", "raging_bolt", "pikachu_tera"]
const Catalog := preload("res://scenes/arena3d/ArenaPokemonCatalog.gd")

func test_all_species_clips_are_reversible_and_own_their_signature_parts() -> String:
	var checks: Array[String] = []
	for id: String in Catalog.ENTRIES:
		var actor := preload("res://scenes/arena3d/ArenaPokemonActor.gd").new()
		actor.build(id)
		for part: String in Catalog.ENTRIES[id].joints:
			checks.append(assert_true(actor.joints.has(part),id+" owns the visible signature joint "+part))
		actor.pose(.30)
		var first: Transform3D = actor.joints.Body.transform
		actor.pose(.82)
		checks.append(assert_false(first.is_equal_approx(actor.joints.Body.transform),id+" has an action silhouette distinct from anticipation"))
		actor.pose(.30)
		checks.append(assert_true(first.is_equal_approx(actor.joints.Body.transform),id+" can resample without accumulated transforms"))
		actor.pose(1.90)
		checks.append(assert_eq(actor.performance.vertex_count,0,id+" clears transient geometry at the end" ) if id not in ["charizard","pikachu_tera"] else "")
		checks.append(assert_not_null(actor.audio.stream,id+" has a local sound cue"))
		checks.append(assert_true(actor.audio.stream.get_length()<=preload("res://scenes/arena3d/ArenaPokemonDirection.gd").profile(id).duration+.01,"Sound cannot outlive the species presentation window"))
		actor.free()
	return run_checks(checks)

func test_catalog_does_not_confuse_trainers_tera_or_concealed_cards() -> String:
	var checks: Array[String] = []
	for id: String in Catalog.ENTRIES:
		var card := {"empty":false,"concealed":false,"name":Catalog.ENTRIES[id].aliases[0]}
		if id=="pikachu_tera":card.uid="CSV9C_054"
		if id=="gardevoir":card.uid="CSV2C_055"
		checks.append(assert_eq(Catalog.identify(card),id,"Exact public identity routes to "+id))
		card.concealed=true
		checks.append(assert_eq(Catalog.identify(card),"","Hidden identities never instantiate a character"))
	for name: String in ["烈咬陆鲨ex","索罗亚克ex","长毛巨魔ex","皮卡丘ex","皮卡丘","密勒顿ex"]:
		checks.append(assert_eq(Catalog.identify({"empty":false,"concealed":false,"name":name}),"","Keep trainer/form distinctions: "+name))
	return run_checks(checks)

func test_requested_roster_has_importable_models() -> String:
	var checks: Array[String] = []
	for species: String in EXPANDED:
		var path := "res://assets/arena3d/pokemon/%s.glb" % species
		checks.append(assert_true(ResourceLoader.exists(path), "Requested character needs a genuine imported mesh: " + species))
	return run_checks(checks)

func test_three_characters_have_real_volumetric_models() -> String:
	var checks: Array[String] = []
	for species: String in ["dragapult", "charizard", "munkidori"]:
		var path := "res://assets/arena3d/pokemon/%s.glb" % species
		checks.append(assert_true(ResourceLoader.exists(path), "A real 3D model must exist: " + species))
		if not ResourceLoader.exists(path): continue
		var model: Node3D = load(path).instantiate()
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var vertices := 0
		for part: MeshInstance3D in meshes:
			for surface: int in part.mesh.get_surface_count():
				vertices += part.mesh.surface_get_array_len(surface)
		checks.append(assert_true(vertices > 1000, "Character contains authored geometry: " + species))
		checks.append(assert_true(vertices < 120000, "Character remains within the desktop geometry budget"))
		checks.append(assert_true(model.find_children("*", "Sprite3D", true, false).is_empty(), "Character is not a camera-facing sheet"))
		for joint: String in ["Head", "Tail", "Arm_L", "Arm_R"]:
			checks.append(assert_true(model.find_child(joint, true, false) != null, "Articulated " + species + " / " + joint))
		model.free()
	return run_checks(checks)

func test_joint_animation_is_repeatable_and_moves_silhouette() -> String:
	var checks: Array[String] = []
	for species: String in ["dragapult","charizard","munkidori"]:
		var actor: Node3D = load("res://scenes/arena3d/ArenaPokemonActor.gd").new()
		actor.build(species)
		actor.pose(.20)
		var head: Transform3D = actor.joints.Head.transform
		var tail: Transform3D = actor.joints.Tail.transform
		actor.pose(.82)
		checks.append(assert_false(head.is_equal_approx(actor.joints.Head.transform),"Head responds to the attack clock"))
		checks.append(assert_false(tail.is_equal_approx(actor.joints.Tail.transform),"Tail is articulated in three dimensions"))
		if species == "charizard":
			checks.append(assert_false(actor.joints.Wing_L.transform.is_equal_approx(actor.rest.Wing_L),"Wing membrane follows its joint"))
			checks.append(assert_false(actor.joints.Jaw.transform.is_equal_approx(actor.rest.Jaw),"Jaw opens for the real breath"))
			var mouth: Vector3 = actor.mouth_local()
			actor.turn("Jaw",Vector3(.3,0,0))
			checks.append(assert_true(mouth.is_equal_approx(actor.mouth_local()),"Opening the lower jaw cannot drag the breath into the neck"))
			actor.turn("Head",Vector3(0,.2,0))
			checks.append(assert_false(mouth.is_equal_approx(actor.mouth_local()),"Breath follows the posed head"))
		if species == "dragapult":
			checks.append(assert_true(actor.joints.Dreepy_L.position.distance_to(actor.rest.Dreepy_L.origin) > .2,"Dreepy launches independently of its carrier"))
		actor.pose(.20)
		checks.append(assert_true(head.is_equal_approx(actor.joints.Head.transform),"Repeated presentation sampling never accumulates rotation"))
		actor.free()
	return run_checks(checks)
