extends Node3D
## Behind the main menu: real places from a KianCraft world, made by the
## game's own world generator. The camera slowly circles one spot (a boss in
## its lair, the floating castle, candy land...), then fades to the next.
##
## start() begins (or resumes) the show; stop() frees the world while you play.

const World = preload("res://scripts/world.gd")
const MobData = preload("res://scripts/mob_data.gd")
const Graphics = preload("res://scripts/graphics.gd")
const Settings = preload("res://scripts/settings.gd")
const DayNight = preload("res://scripts/day_night.gd")

const SEED := 4242               # a world with every kind of place in reach
const GEN := 11
const SCENE_SECONDS := 15.0
const FADE := 1.2
const LOAD_WAIT := 8.0           # give up waiting for a place to load after this
const VIEW_CHUNKS := 5

## [caption, how to find it, decorations, night?]
const PLACES := [
	["Old Oakheart's hollow tree", "lair:oakheart", [["oakheart", 0, 0]], false, [48.0, 26.0]],
	["Candy land", "biome:candy", [["gummy_bear", 3, 2], ["gummy_bear", -4, 3], ["marshmallow", 1, -4], ["peppermint_pig", -2, -2]], false],
	["King Cougar's temple", "lair:king_cougar", [["king_cougar", 0, 0]], false],
	["Grimskull's castle in the clouds", "castle", [["grimskull", 0, -5], ["skeleton", 3, 2], ["skeleton_archer", -3, 2]], false],
	["The fall forest", "biome:fall", [["fox", 2, 2], ["squirrel", -3, 1], ["deer", 4, -3]], false],
	["The Gummy Giant's fort", "lair:gummy_giant", [["gummy_giant", 0, 0]], false],
	["The snowy mountains", "biome:mountain", [["mountain_goat", 2, 1], ["mountain_goat", -3, 3]], false, [34.0, 16.0]],
	["The Scarecrow King's maze", "lair:scarecrow_king", [["scarecrow_king", 0, 0], ["crow", 3, 3]], false],
	["The Lantern Witch's crypt", "lair:lantern_witch", [["lantern_witch", 0, -9], ["ghost", 4, 2], ["ghost", -4, -3]], true],
	["The Boar King's standing stones", "lair:boar_king", [["boar_king", 0, 0], ["boar", 3, 3], ["boar", -3, 2]], false],
]

## Extra places shown with the HD graphics (Block textures Detailed or better),
## with a slower, film-like camera and a soft blur far away. Simple textures
## keep the classic list and camera.
const PLACES_NEW := [
	["The King & Queen's castle", "lair:chess_royals", [["white_king", -3, 3], ["white_queen", 3, 3]], false, [46.0, 22.0]],
	["Chuckles the Clown's circus", "lair:clown", [["clown", 0, 0], ["fry_minion", 4, 3], ["fry_minion", -4, 2]], false, [42.0, 20.0]],
	["A villager camp", "camp", [["@villager", 3, 2], ["@villager", -3, 4], ["@villager", 1, -4]], false, [36.0, 15.0]],
	["The Chessboard Kingdom", "biome:chess", [["white_pawn", 2, 2], ["black_pawn", -3, 1], ["black_pawn", 4, -3]], false],
	["Fast Food Land", "biome:fastfood", [["nugget_buddy", 2, 1], ["happy_box", -3, 2], ["nugget_buddy", 1, -3]], false],
	["The spooky forest at night", "biome:spooky", [["ghost", 3, 2], ["black_cat", -2, 2], ["crow", 1, -3]], true],
]

signal place_changed(caption: String)

var world: Node3D
var camera: Camera3D
var _env: Environment
var _sky: ShaderMaterial
var _night := false
var _sun_dir := Vector3.UP
var _sun: DirectionalLight3D
var _focus: Node3D
var _decor: Node3D
var _fade: ColorRect                     # the menu gives us a black rectangle to fade with
var _order: Array = []
var _index := -1
var _found := {}                          # place index -> Vector3 (ground spot), or null if not found
var _target := Vector3.ZERO
var _t := 0.0
var _state := "off"                       # off, loading, showing, leaving
var _angle := 0.0
var _radius := 26.0
var _height := 14.0
var caption := ""
var _lift := 0.0
var _camp_biome := "plains"
var _hd := false
var _cam_attr: CameraAttributesPractical


## The places for the current graphics.
func places() -> Array:
	return PLACES + PLACES_NEW if _hd else PLACES


static func hd_wanted() -> bool:
	return int(Settings.gfx.get("detail_textures", 1)) >= 1


func setup(fade: ColorRect) -> void:
	_fade = fade
	# The same sky, sun, shadows and effects as the game (graphics.gd).
	_env = Graphics.make_environment()
	_sky = Graphics.sky_material(_env)
	_env.fog_depth_begin = VIEW_CHUNKS * 16.0 * 0.62
	_env.fog_depth_end = VIEW_CHUNKS * 16.0 * 0.95
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	add_child(_sun)
	_apply_graphics()
	Settings.on_changed(_apply_graphics)
	camera = Camera3D.new()
	camera.fov = 60
	camera.far = 400.0
	add_child(camera)
	_focus = Node3D.new()
	add_child(_focus)
	_decor = Node3D.new()
	add_child(_decor)
	_cam_attr = CameraAttributesPractical.new()
	_order = range(PLACES.size())
	_order.shuffle()


func start() -> void:
	if _state != "off":
		return
	_hd = hd_wanted()
	_order = range(places().size())
	_order.shuffle()
	_index = -1
	world = World.new()
	world.name = "MenuWorld"
	add_child(world)
	world.start(SEED, {}, {}, GEN)
	Graphics.apply_world(world)
	# HD sees one chunk further (and the fog moves back with it), so it's crisp.
	world.set_render_distance(VIEW_CHUNKS + (1 if _hd else 0))
	world.set_focus(_focus)
	_next_place()


func stop() -> void:
	_state = "off"
	for c in _decor.get_children():
		c.queue_free()
	if world:
		world.clear()
		world.queue_free()
		world = null


func is_running() -> bool:
	return _state != "off"


## Where a place is (the ground in the middle of it), or null if this world doesn't have one near.
func find_place(i: int) -> Variant:
	if _found.has(i):
		return _found[i]
	var how: String = places()[i][1]
	var at: Variant = null
	if how.begins_with("lair:"):
		var l: Dictionary = world.find_lair(how.substr(5), Vector2.ZERO, 2500.0)
		if not l.is_empty():
			at = Vector3(l["pos"].x + 0.5, l["ground"] + 1, l["pos"].z + 0.5)
	elif how.begins_with("biome:"):
		var b: Vector3 = world.find_biome(how.substr(6), Vector2.ZERO, 2500)
		if b.y >= 0:
			at = Vector3(b.x + 0.5, world.surface_height(floori(b.x), floori(b.z)) + 1, b.z + 0.5)
	elif how == "camp":
		var cp: Dictionary = world.find_camp(Vector2.ZERO, 2500.0)
		if not cp.is_empty():
			_camp_biome = cp["biome"]
			at = Vector3(cp["center"].x + 0.5, cp["ground"] + 1, cp["center"].y + 0.5)
	elif how == "castle":
		var c: Vector3 = world.find_castle(Vector2.ZERO, 3000.0)
		if c.y >= 0:
			at = c
	_found[i] = at
	return at


func _next_place() -> void:
	for tries in places().size():
		_index = (_index + 1) % _order.size()
		var at: Variant = find_place(_order[_index])
		if at != null:
			_go_to(_order[_index], at)
			return
	_state = "off"   # nothing found (shouldn't happen with this seed)


func _go_to(i: int, at: Vector3) -> void:
	_target = at
	_focus.global_position = at
	world.set_focus(_focus)
	_state = "loading"
	_t = 0.0
	_angle = randf() * TAU
	var place: Array = places()[i]
	var big: bool = String(place[1]).begins_with("lair") or place[1] == "castle"
	_radius = 30.0 if big else 24.0
	_height = 13.0 if big else 9.0
	if place.size() > 4:
		_radius = place[4][0]
		_height = place[4][1]
	caption = place[0]
	var night: bool = place[3]
	_night = night
	world.set_daylight(0.32 if night else 1.0)
	# A low sun for long shadows and warm light (or the moon, for spooky places).
	var t := randf_range(0.86, 0.92) if night else randf_range(0.31, 0.36)
	if randf() < 0.3 and not night:
		t = randf_range(0.66, 0.69)   # sometimes a golden evening
	var a := (t - 0.25) * TAU
	_sun_dir = Vector3(cos(a), sin(a), 0.25).rotated(Vector3.UP, randf() * TAU).normalized()
	DayNight.light_scene(_env, _sky, _sun, _sun_dir, 0.0 if night else 1.0, Color.WHITE, randf_range(0.2, 0.45))
	world.set_sky_color(Graphics.horizon_color(_sun_dir.y).lerp(Graphics.top_color(_sun_dir.y), 0.4))
	for c in _decor.get_children():
		c.queue_free()
	# HD: a soft blur in the far distance, like a camera lens.
	_cam_attr.dof_blur_far_enabled = _hd and Settings.modern()
	_cam_attr.dof_blur_far_distance = _radius + 55.0
	_cam_attr.dof_blur_far_transition = 60.0
	_cam_attr.dof_blur_amount = 0.018
	camera.attributes = _cam_attr if _hd else null
	# (HD: clear air a bit further out, so the big places aren't lost in the haze)
	var view := VIEW_CHUNKS + (1 if _hd else 0)
	_env.fog_depth_begin = view * 16.0 * (0.8 if _hd else 0.62)
	_env.fog_depth_end = view * 16.0 * (1.05 if _hd else 0.95)
	_place_camera(0.0)


## Puts the place's creatures on the ground once the ground has loaded.
func _decorate(i: int) -> void:
	for d in places()[i][2]:
		var type: String = d[0]
		if type == "@villager":
			type = "villager_" + _camp_biome
		if not MobData.MOBS.has(type):
			continue
		var x := floori(_target.x) + int(d[1])
		var z := floori(_target.z) + int(d[2])
		var y: int = _ground_y(x, z, int(_target.y))
		var model: Node3D = MobData.build_model(type)["root"]
		model.position = Vector3(x + 0.5, y, z + 0.5)
		model.rotation.y = randf() * TAU
		model.set_meta("bob", randf() * TAU)
		model.set_meta("flies", type in ["crow", "ghost"])
		if type in ["crow", "ghost"]:
			model.position.y += 2.5
		_decor.add_child(model)


## The top of the ground near a height (so bosses stand on their lair's floor,
## not on its roof or in a cave below).
func _ground_y(x: int, z: int, near: int) -> int:
	for dy in range(4, -8, -1):
		var y := near + dy
		var below: int = world.get_block(Vector3i(x, y - 1, z))
		if preload("res://scripts/blocks.gd").is_solid(below) and not preload("res://scripts/blocks.gd").is_solid(world.get_block(Vector3i(x, y, z))) \
				and not preload("res://scripts/blocks.gd").is_solid(world.get_block(Vector3i(x, y + 1, z))):
			return y
	return near


func _place_camera(delta: float) -> void:
	_angle += delta * (0.035 if _hd else 0.05)
	var bob := sin(_t * 0.3) * 1.0
	var r := _radius
	var h := _height + bob
	if _hd and _state != "loading":
		# A slow film-like move: drift in a little closer and lower over the scene.
		var k := clampf(_t / (SCENE_SECONDS + FADE), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		r = lerpf(_radius * 1.08, _radius * 0.86, k)
		h = lerpf(_height * 1.1, _height * 0.8, k) + bob * 0.5
	camera.position = _target + Vector3(cos(_angle) * r, h, sin(_angle) * r)
	# Never inside a hill (and never inside the tops of trees right under it).
	var ground: float = world.surface_height(floori(camera.position.x), floori(camera.position.z)) + 9.0 if world else -INF
	_lift = lerpf(_lift, maxf(0.0, ground - camera.position.y), minf(1.0, delta * 2.0) if delta > 0.0 else 1.0)
	camera.position.y += _lift
	camera.look_at(_target + Vector3(0, 3.0, 0), Vector3.UP)


func _process(delta: float) -> void:
	if _state == "off" or world == null:
		return
	_t += delta
	_place_camera(delta)
	for m in _decor.get_children():
		var ph: float = m.get_meta("bob", 0.0)
		m.rotation.y += delta * (0.6 if m.get_meta("flies", false) else 0.08) * (1.0 if int(ph * 10) % 2 == 0 else -1.0)
		if m.get_meta("flies", false):
			m.position.y += sin(_t * 1.5 + ph) * delta * 0.4
	match _state:
		"loading":
			_set_fade(1.0)
			if world.is_ready_at(_target) and world.is_ready_at(camera.position) or _t > LOAD_WAIT:
				_decorate(_order[_index])
				_state = "showing"
				_t = 0.0
				place_changed.emit(caption)
		"showing":
			_set_fade(1.0 - clampf(_t / FADE, 0.0, 1.0))
			if _t > SCENE_SECONDS:
				_state = "leaving"
				_t = 0.0
		"leaving":
			_set_fade(clampf(_t / FADE, 0.0, 1.0))
			if _t >= FADE:
				_next_place()


func _apply_graphics() -> void:
	if _env == null or not is_instance_valid(self):
		return
	Graphics.apply(_env)
	Graphics.apply_sun(_sun)
	if world:
		Graphics.apply_world(world)


func _set_fade(a: float) -> void:
	if _fade:
		_fade.color.a = a
