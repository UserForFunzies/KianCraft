extends Node3D
## Day/night cycle: moves the sun and moon across the shader sky, lights the
## world with them (with shadows), and keeps fog and ambient light matching.
## The weather (weather.gd) sets how cloudy and dark it is.
##
## Time is stored as `world_time` in seconds. One full day lasts DAY_LENGTH.
## time_of_day(): 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
## The server owns the clock and main.gd sends it to clients now and then.

const Graphics = preload("res://scripts/graphics.gd")
const Settings = preload("res://scripts/settings.gd")

const DAY_LENGTH := 1200.0      # 20 real minutes per in-game day
const NEW_WORLD_TIME := 0.3     # new worlds start in the morning
const DAY_SKY := Color(0.55, 0.75, 0.98)
const NIGHT_SKY := Color(0.02, 0.03, 0.08)
const SUNSET_SKY := Color(0.95, 0.55, 0.32)
const NIGHT_DAYLIGHT := 0.16    # how bright moonlight is compared to the sun

var world_time := NEW_WORLD_TIME * DAY_LENGTH
var running := false
var night_eyes := false          # the Lantern Witch's power: nights look much brighter

## Set by the weather: 0..1 how cloudy, how dark the clouds are, lightning flash.
var cloud_cover := 0.3
var overcast := 0.0
var flash := 0.0
var cave := 0.0                  # 0 outside .. 1 deep underground (weather.gd sets it)
## The biome's own sky color (candy land is pink...), eased toward smoothly.
var tint := Color.WHITE
var tint_target := Color.WHITE

var _env: Environment
var _world: Node
var _sun_light: DirectionalLight3D
var _sky: ShaderMaterial


func setup(env: Environment, world: Node) -> void:
	_env = env
	_world = world
	_sky = Graphics.sky_material(env)
	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "Sun"
	_sun_light.shadow_enabled = false
	add_child(_sun_light)
	_apply()


## Sun shadows and the rest of the graphics options.
func apply_graphics() -> void:
	Graphics.apply_sun(_sun_light)


func sun_light() -> DirectionalLight3D:
	return _sun_light


func _process(delta: float) -> void:
	if running:
		world_time += delta
	var k := 1.0 - exp(-delta * 0.6)
	tint = tint.lerp(tint_target, k)
	_apply()


func time_of_day() -> float:
	return fposmod(world_time / DAY_LENGTH, 1.0)


func day_number() -> int:
	return int(world_time / DAY_LENGTH) + 1


## Jump to a time of day (0..1) on the current day.
func set_time_of_day(t: float) -> void:
	world_time = floorf(world_time / DAY_LENGTH) * DAY_LENGTH + t * DAY_LENGTH


## "Day 3, 14:05" style text for the HUD.
func clock_text() -> String:
	var minutes := int(time_of_day() * 24.0 * 60.0)
	return "Day %d, %02d:%02d" % [day_number(), minutes / 60, minutes % 60]


func is_night() -> bool:
	return _sun_height() < -0.05


func _sun_height() -> float:
	return sin((time_of_day() - 0.25) * TAU)


func _apply() -> void:
	if _env == null:
		return
	var angle := (time_of_day() - 0.25) * TAU
	var sun_dir := Vector3(cos(angle), sin(angle), 0.25).normalized()
	var e := sun_dir.y
	var day := smoothstep(-0.15, 0.25, e)
	var seen := maxf(day, 0.75) if night_eyes else day
	if _world:
		_world.set_daylight(lerpf(NIGHT_DAYLIGHT, 1.0, seen))
	light_scene(_env, _sky, _sun_light, sun_dir, seen, tint, cloud_cover, overcast, flash, cave)
	if _world and _world.has_method("set_sky_color"):
		_world.set_sky_color(Graphics.horizon_color(e, tint).lerp(Graphics.top_color(e, tint), 0.4).darkened(overcast * 0.4))


## Lights a scene for a sun direction: the sky shader, sun or moon light,
## fog and ambient colors. `seen` is how bright it looks (1 day, 0 night;
## the Lantern Witch's power raises it). Shared with the menu's backdrop.
static func light_scene(env: Environment, sky: ShaderMaterial, sun: DirectionalLight3D, sun_dir: Vector3,
		seen: float, tint := Color.WHITE, cover := 0.3, dark := 0.0, flash_amount := 0.0, cave := 0.0) -> void:
	var e := sun_dir.y
	var twilight := 1.0 - smoothstep(0.0, 0.3, absf(e))
	if sky:
		sky.set_shader_parameter("sun_dir", sun_dir)
		sky.set_shader_parameter("moon_dir", -sun_dir)
		sky.set_shader_parameter("tint", tint)
		sky.set_shader_parameter("cloud_cover", cover)
		sky.set_shader_parameter("cloud_dark", dark)
		sky.set_shader_parameter("flash", flash_amount)
	var hor := Graphics.horizon_color(e, tint)
	var grey := Color(0.5, 0.53, 0.58) * lerpf(0.15, 1.0, smoothstep(-0.15, 0.25, e))
	hor = hor.lerp(grey, dark * 0.7)
	env.fog_light_color = hor
	# Ambient: mostly the sky itself; this part keeps nights from going pitch black.
	var amb := Graphics.top_color(e, tint).lerp(hor, 0.5).lerp(Color.WHITE, 0.25)
	env.ambient_light_color = amb.lerp(Color(0.55, 0.62, 0.85), 1.0 - seen)
	env.ambient_light_energy = lerpf(0.5, 0.8, seen) * (1.0 - dark * 0.25) + flash_amount * 2.0
	env.background_energy_multiplier = 1.0
	# Underground: no sky light at all, and the dark swallows the distance.
	env.ambient_light_energy *= lerpf(1.0, 0.04, cave)
	env.ambient_light_sky_contribution = lerpf(0.6, 0.0, cave)
	env.fog_light_color = hor.lerp(Color(0.004, 0.004, 0.006), cave)
	env.fog_aerial_perspective = lerpf(0.35, 0.0, cave)
	env.sdfgi_energy = lerpf(0.9, 0.25, cave)
	env.ssil_intensity = lerpf(0.9, 0.5, cave)
	# The sun by day, the moon by night (one light, so shadows always work).
	var up := Vector3.UP if absf(e) < 0.99 else Vector3.FORWARD
	if e > -0.08:
		sun.look_at_from_position(Vector3.ZERO, -sun_dir, up)
		sun.light_energy = clampf(e * 5.0, 0.0, 1.0) * 1.4 * (1.0 - dark * 0.7)
		sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.36), twilight * 0.7)
	else:
		sun.look_at_from_position(Vector3.ZERO, sun_dir, up)
		sun.light_energy = clampf(-e * 4.0, 0.0, 1.0) * lerpf(0.35, 0.9, seen) * (1.0 - dark * 0.6)
		sun.light_color = Color(0.62, 0.7, 1.0)
	sun.light_energy += flash_amount * 3.0
