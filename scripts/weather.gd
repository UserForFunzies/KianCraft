extends Node3D
## Weather and the feel of each place.
##
## The server picks the weather (clear, cloudy, rain, storm) and tells
## everyone, so friends on the LAN all get rained on together. What you see
## depends on where you are: rain falls as snow in the snowy mountains, as
## colorful sprinkles in candy land, and just clouds in the desert. Storms
## bring lightning and thunder.
##
## It also gives each biome its own sky tint, color grading and mist, adds
## little living touches (falling leaves, fireflies at night), and makes the
## ground wet and shiny when it rains (snow settles on blocks in the mountains).
##
## Seasons: `season` is here for later (spring/summer/fall/winter could change
## the weather odds, leaf colors and snow); for now it's always "summer".

const Settings = preload("res://scripts/settings.gd")
const Sound = preload("res://scripts/sound.gd")
const Graphics = preload("res://scripts/graphics.gd")

const KINDS := ["clear", "cloudy", "rain", "storm"]
## How likely each weather is next (by the biome at the world's spawn it's the same
## everywhere; the place you're in changes how it looks).
const ODDS := {"clear": 5.0, "cloudy": 3.0, "rain": 2.0, "storm": 0.8}
const MIN_SECONDS := 150.0
const MAX_SECONDS := 420.0
const SYNC_SECONDS := 10.0

## Per biome: [sky tint, saturation, mist (extra fog), ambient bits]
const BIOME_LOOK := {
	"plains": [Color(1.0, 1.0, 1.0), 1.12, 0.0, "meadow"],
	"forest": [Color(0.96, 1.0, 0.96), 1.1, 0.15, "forest"],
	"candy": [Color(1.06, 0.93, 1.04), 1.22, 0.05, "candy"],
	"desert": [Color(1.06, 1.0, 0.9), 1.05, 0.1, ""],
	"mountain": [Color(0.95, 0.99, 1.06), 1.0, 0.1, ""],
	"fall": [Color(1.05, 0.97, 0.9), 1.18, 0.1, "fall"],
	"spooky": [Color(0.78, 0.8, 0.95), 0.85, 0.6, "spooky"],
	"sky": [Color(1.0, 1.0, 1.06), 1.12, 0.0, ""],
	"chess": [Color(1.0, 1.0, 1.04), 1.02, 0.08, ""],
	"fastfood": [Color(1.05, 1.0, 0.94), 1.18, 0.04, ""],
}

var main: Node
var season := "summer"

## Synced from the server.
var kind := "clear"
var _remaining := 240.0
var _sync_timer := 0.0

## Smoothly changing values (every computer).
var rain := 0.0                 # 0..1 how hard it's falling
var cover := 0.3                # cloud cover
var dark := 0.0                 # storm darkness
var wetness := 0.0              # ground wetness (slow to dry)
var snow := 0.0                 # snow settled on blocks (mountains)
var flash := 0.0
var precip := "rain"            # what falls where you are: rain, snow, sprinkles, none
var biome := "plains"
var mist := 0.0

var _rain_fx: GPUParticles3D
var _snow_fx: GPUParticles3D
var _sprinkle_fx: GPUParticles3D
var _bits_fx: GPUParticles3D     # leaves, petals, fireflies
var _collider: GPUParticlesCollisionHeightField3D
var _bits_kind := ""
var _look_timer := 0.0
var _bolt_timer := 8.0
var _thunder_at := -1.0
var _outside := true
var _deep := false
var cave := 0.0                 # 0 outside .. 1 deep underground (eased)


func _ready() -> void:
	_rain_fx = _make_rain()
	_snow_fx = _make_snow()
	_sprinkle_fx = _make_sprinkles()
	_bits_fx = _make_bits()
	_collider = GPUParticlesCollisionHeightField3D.new()
	_collider.size = Vector3(80, 64, 80)
	_collider.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_collider.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_ALWAYS   # (so new roofs stop the rain right away)
	_collider.follow_camera_enabled = true
	add_child(_collider)
	if OS.has_environment("KC_NOCOLLIDE"):
		_collider.visible = false


## Server: pick weather now (or a named one, for /weather).
func choose(next := "") -> void:
	if next == "":
		var total := 0.0
		for k in ODDS:
			total += ODDS[k]
		var roll := randf() * total
		next = "clear"
		for k in ODDS:
			roll -= ODDS[k]
			if roll <= 0.0:
				next = k
				break
	kind = next
	_remaining = randf_range(MIN_SECONDS, MAX_SECONDS)
	if main and main.multiplayer.has_multiplayer_peer() and not main.multiplayer.get_peers().is_empty():
		_sync.rpc(kind, _remaining)


@rpc("authority", "call_remote", "reliable")
func _sync(k: String, remaining: float) -> void:
	kind = k
	_remaining = remaining


## A new world (or joining one): start fresh.
func reset(k := "clear") -> void:
	kind = k
	_remaining = randf_range(MIN_SECONDS, MAX_SECONDS)
	rain = 0.0
	wetness = 0.0
	snow = 0.0
	flash = 0.0
	cover = 0.3
	dark = 0.0


func _process(delta: float) -> void:
	if main == null:
		return
	var in_game: bool = main.in_game
	if in_game and main.multiplayer.is_server():
		_remaining -= delta
		if _remaining <= 0.0:
			choose()
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = SYNC_SECONDS
			if not main.multiplayer.get_peers().is_empty():
				_sync.rpc(kind, _remaining)
	if not in_game or main.dedicated:
		_show_fx(0.0, 0.0, 0.0)
		_bits_fx.emitting = false
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := cam.global_position
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = 0.5
		biome = main.world.biome_at(at.x, at.z)
		_outside = main.world.sees_sky(Vector3i(floori(at.x), floori(at.y), floori(at.z)))
		# Deep under the ground (or a big roof): the world goes dark and the
		# far distance fades to black instead of to the sky.
		_deep = not _outside and at.y < main.world.surface_height(floori(at.x), floori(at.z)) - 2
		precip = "rain"
		if biome == "mountain" or at.y > 92.0:
			precip = "snow"
		elif biome == "candy":
			precip = "sprinkles"
		elif biome == "desert":
			precip = "none"
		_update_bits(at)

	# Ease everything toward the weather's targets.
	var want_rain: float = {"clear": 0.0, "cloudy": 0.0, "rain": 0.65, "storm": 1.0}[kind]
	var want_cover: float = {"clear": 0.25, "cloudy": 0.7, "rain": 0.9, "storm": 1.0}[kind]
	var want_dark: float = {"clear": 0.0, "cloudy": 0.2, "rain": 0.55, "storm": 0.85}[kind]
	if precip == "none":
		want_rain = 0.0
		want_dark *= 0.4
	if biome == "spooky":
		want_cover = maxf(want_cover, 0.55)
		want_dark = maxf(want_dark, 0.3)
	var k := 1.0 - exp(-delta * 0.15)
	rain = lerpf(rain, want_rain, k * 2.0)
	cover = lerpf(cover, want_cover, k)
	dark = lerpf(dark, want_dark, k)
	if rain > 0.1 and precip == "rain" or precip == "sprinkles" and rain > 0.1:
		wetness = minf(1.0, wetness + delta * 0.02 * rain)
	else:
		wetness = maxf(0.0, wetness - delta * 0.006)
	if precip == "snow" and rain > 0.1:
		snow = minf(1.0, snow + delta * 0.015 * rain)
	elif precip != "snow":
		snow = maxf(0.0, snow - delta * 0.05)   # (a different biome: no snow there)
	mist = lerpf(mist, float(BIOME_LOOK.get(biome, BIOME_LOOK["plains"])[2]), k)

	cave = move_toward(cave, 1.0 if _deep else 0.0, delta * 0.8)
	_lightning(delta)
	_apply_look(at)
	var amount := float(Settings.gfx["weather"])
	if _deep:
		amount = 0.0   # deep underground: no rain to see at all
	# Otherwise the rain keeps falling all around you; the height-field collider
	# stops each drop on whatever is above it (a roof, a glass ceiling, leaves),
	# so under a roof you see it pouring just outside, like in Minecraft.
	_show_fx(rain * amount if precip == "rain" else 0.0, rain * amount if precip == "snow" else 0.0,
			rain * amount if precip == "sprinkles" else 0.0)
	for fx in [_rain_fx, _snow_fx, _sprinkle_fx, _bits_fx]:
		fx.global_position = at


## How loud the rain sound is (0..1) where you are.
func rain_sound() -> float:
	if precip != "rain" and precip != "sprinkles":
		return 0.0
	return rain * (0.8 if _outside else 0.3)


func _lightning(delta: float) -> void:
	flash = maxf(0.0, flash - delta * 3.5)
	if _thunder_at >= 0.0:
		_thunder_at -= delta
		if _thunder_at < 0.0:
			Sound.play("thunder", -2.0 + randf_range(-3.0, 0.0), randf_range(0.85, 1.1), "Ambience")
	if kind != "storm" or precip == "none" or rain < 0.6:
		return
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = randf_range(7.0, 22.0)
		flash = randf_range(0.6, 1.0)
		_thunder_at = randf_range(0.4, 2.5)


func _apply_look(at: Vector3) -> void:
	var dn: Node = main.day_night
	var look: Array = BIOME_LOOK.get(biome, BIOME_LOOK["plains"])
	dn.tint_target = look[0]
	dn.cloud_cover = cover
	dn.overcast = dark
	dn.flash = flash if _outside else flash * 0.15
	dn.cave = cave
	main.world.set_weather_look(wetness, snow, rain if precip == "rain" else 0.0)
	var env: Environment = main._env
	if env == null:
		return
	env.adjustment_saturation = lerpf(env.adjustment_saturation, float(look[1]) - dark * 0.2, 0.05)
	# Fog: the edge of the world, closer in rain and in misty biomes.
	var far := float(main.world.render_distance * 16)
	var thick := clampf(rain * 0.55 + mist * 0.5, 0.0, 0.85)
	if precip == "snow":
		thick = clampf(thick + rain * 0.2, 0.0, 0.9)
	env.fog_depth_begin = far * lerpf(0.45, 0.04, thick)
	env.fog_depth_end = far * lerpf(0.97, 0.6, thick)
	env.fog_depth_begin = lerpf(env.fog_depth_begin, 8.0, cave)
	env.fog_depth_end = lerpf(env.fog_depth_end, 46.0, cave)
	var base := Graphics.mist_density()
	env.volumetric_fog_density = base * (1.0 + rain * 1.5 + mist * 3.0) if base > 0.0 else 0.0


func _show_fx(r: float, s: float, sp: float) -> void:
	_set_fx(_rain_fx, r, 4000)
	_set_fx(_snow_fx, s, 2400)
	_set_fx(_sprinkle_fx, sp, 1400)


func _set_fx(fx: GPUParticles3D, strength: float, most: int) -> void:
	var n := int(most * clampf(strength, 0.0, 1.5))
	if n < 40:
		fx.emitting = false
		return
	# Changing `amount` restarts the particles, so only change it in big steps.
	var step := int(roundf(n / 200.0)) * 200 + 40
	if fx.amount != step:
		fx.amount = step
	fx.emitting = true


# --- The particles ------------------------------------------------------------------

func _base_fx(lifetime: float, box: Vector3) -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.lifetime = lifetime
	fx.amount = 40
	fx.emitting = false
	fx.local_coords = false
	fx.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.preprocess = lifetime
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	fx.process_material = pm
	add_child(fx)
	return fx


func _make_rain() -> GPUParticles3D:
	var fx := _base_fx(1.1, Vector3(13, 2, 13))
	var pm: ParticleProcessMaterial = fx.process_material
	pm.emission_shape_offset = Vector3(0, 14, 0)
	pm.direction = Vector3(0.08, -1, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3(0, -6, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.82, 0.95, 0.38)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	fx.draw_pass_1 = q
	return fx


func _make_snow() -> GPUParticles3D:
	var fx := _base_fx(6.0, Vector3(14, 2, 14))
	var pm: ParticleProcessMaterial = fx.process_material
	pm.emission_shape_offset = Vector3(0, 14, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 20.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0.3, -1.2, 0.1)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.12
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _dot_texture()
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	fx.draw_pass_1 = q
	return fx


## Candy land's rain: little colorful sprinkles tumbling down.
func _make_sprinkles() -> GPUParticles3D:
	var fx := _base_fx(2.6, Vector3(20, 2, 20))
	var pm: ParticleProcessMaterial = fx.process_material
	pm.emission_shape_offset = Vector3(0, 14, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -3, 0)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.particle_flag_rotate_y = true
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.4, 0.6), Color(1, 0.4, 0.6), Color(0.5, 0.85, 1.0), Color(1.0, 0.9, 0.4), Color(0.6, 1.0, 0.6), Color(0.85, 0.6, 1.0)])
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_initial_ramp = gt
	var b := BoxMesh.new()
	b.size = Vector3(0.04, 0.16, 0.04)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material = m
	fx.draw_pass_1 = b
	return fx


## Little living things in the air: falling leaves, petals, fireflies, wisps.
func _make_bits() -> GPUParticles3D:
	var fx := _base_fx(7.0, Vector3(14, 6, 14))
	fx.amount = 60
	var pm: ParticleProcessMaterial = fx.process_material
	pm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_noise_scale = 4.0
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.15, 1.0))
	fade.add_point(Vector2(0.85, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = fade
	pm.scale_curve = ct
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot_texture()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	fx.draw_pass_1 = q
	return fx


func _update_bits(at: Vector3) -> void:
	var night: bool = main.day_night.is_night()
	var want := ""
	var look: String = BIOME_LOOK.get(biome, BIOME_LOOK["plains"])[3]
	if _outside and float(Settings.gfx["particles"]) >= 1.0:
		if night and look in ["meadow", "forest", "fall"] and rain < 0.3:
			want = "fireflies"
		elif night and look == "spooky":
			want = "wisps"
		elif not night and look in ["forest", "fall", "candy"]:
			want = look
	if want == _bits_kind:
		return
	_bits_kind = want
	if want == "":
		_bits_fx.emitting = false
		return
	var pm: ParticleProcessMaterial = _bits_fx.process_material
	var mat: StandardMaterial3D = (_bits_fx.draw_pass_1 as QuadMesh).material
	var glowing := want in ["fireflies", "wisps"]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glowing else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.emission_enabled = glowing
	var colors: Array = {
		"fireflies": [Color(1.0, 0.95, 0.4), Color(0.8, 1.0, 0.4)],
		"wisps": [Color(0.5, 1.0, 0.9), Color(0.7, 0.6, 1.0)],
		"forest": [Color(0.35, 0.6, 0.2), Color(0.5, 0.7, 0.25)],
		"fall": [Color(0.95, 0.45, 0.12), Color(0.95, 0.75, 0.2)],
		"candy": [Color(1.0, 0.7, 0.85), Color(1.0, 0.95, 1.0)],
	}[want]
	var g := Gradient.new()
	g.colors = PackedColorArray(colors)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	if glowing:
		mat.emission = colors[0]
		mat.emission_energy_multiplier = 3.0
		pm.gravity = Vector3.ZERO
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.4
		pm.emission_shape_offset = Vector3(0, 1, 0)
		pm.emission_box_extents = Vector3(14, 2.5, 14)
		pm.turbulence_influence_min = 0.1
		pm.turbulence_influence_max = 0.2
		(_bits_fx.draw_pass_1 as QuadMesh).size = Vector2(0.08, 0.08)
	else:
		pm.gravity = Vector3(0.3, -0.5, 0.2)
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.3
		pm.emission_shape_offset = Vector3(0, 7, 0)
		pm.emission_box_extents = Vector3(14, 4, 14)
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.12
		(_bits_fx.draw_pass_1 as QuadMesh).size = Vector2(0.15, 0.15)
	_bits_fx.amount = int(40 * float(Settings.gfx["particles"]))
	_bits_fx.emitting = true


static var _dot: ImageTexture

## A soft round dot (snowflakes, fireflies) or, scaled, a little leaf.
static func _dot_texture() -> ImageTexture:
	if _dot == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 2.0, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot
