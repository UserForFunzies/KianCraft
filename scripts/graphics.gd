extends RefCounted
## The look of the 3D world: the sky, sunlight and shadows, glow, fog, soft
## corner shadows, bounced light... and how the graphics settings turn each
## of them up or down. Used by the game (main.gd + day_night.gd) and by the
## menu's backdrop, so both look the same.
##
## Nothing here is an asset: the sky is a shader (shaders/sky.gdshader).

const Settings = preload("res://scripts/settings.gd")
const SkyShader = preload("res://shaders/sky.gdshader")

## Colors of the sky through the day (the sky shader blends the same ones).
const DAY_TOP := Color(0.24, 0.47, 0.92)
const DAY_HORIZON := Color(0.68, 0.82, 0.98)
const SUNSET := Color(1.0, 0.5, 0.25)
const NIGHT_TOP := Color(0.01, 0.015, 0.05)
const NIGHT_HORIZON := Color(0.04, 0.06, 0.14)


## A new environment with the shader sky, filmic colors and fog that hides
## the edge of the world. Call apply() afterwards for the quality options.
static func make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ShaderMaterial.new()
	mat.shader = SkyShader
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME   # it moves (clouds, stars)
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6     # the rest comes from ambient_light_color (day_night sets it)
	env.ambient_light_color = Color(0.6, 0.7, 0.9)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.94
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12              # kid-friendly: colorful, not washed out
	env.adjustment_contrast = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env.fog_depth_curve = 1.6
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	return env


static func sky_material(env: Environment) -> ShaderMaterial:
	if env == null or env.sky == null:
		return null
	return env.sky.sky_material as ShaderMaterial


## Turns the environment's effects on or off for the current settings.
static func apply(env: Environment, g: Dictionary = Settings.gfx) -> void:
	var modern := Settings.modern()
	env.glow_enabled = g["glow"]
	var shadows: int = g["shadows"]
	env.ssao_enabled = modern and g["ssao"]
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssao_light_affect = 0.15
	env.ssao_ao_channel_affect = 0.0
	env.ssil_enabled = modern and g["ssil"]
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = modern and g["sdfgi"]
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.sdfgi_energy = 0.9
	env.sdfgi_bounce_feedback = 0.4
	# God rays only look right with sun shadows (otherwise caves fill with sunlit mist).
	# Mist (how hazy the air is) and god rays (how bright the sunbeams in it
	# are) are separate: rays need a little mist to show up in, and the sun's
	# shadows to cut them into beams.
	var rays: int = int(g.get("god_rays", 0)) if shadows > 0 else 0
	env.volumetric_fog_enabled = modern and (rays > 0 or int(g.get("mist", 0)) > 0)
	env.volumetric_fog_density = mist_density(g)
	env.volumetric_fog_albedo = Color(0.92, 0.94, 1.0)
	env.volumetric_fog_anisotropy = 0.65
	env.volumetric_fog_length = 48.0 if shadows <= 1 else 80.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.ssr_enabled = modern and g["ssr"]
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	var mat := sky_material(env)
	if mat:
		mat.set_shader_parameter("cloud_quality", float(g["clouds"]))
	if modern:
		var q := RenderingServer.ENV_SSAO_QUALITY_HIGH if g["sdfgi"] else RenderingServer.ENV_SSAO_QUALITY_MEDIUM
		RenderingServer.environment_set_ssao_quality(q, true, 0.5, 2, 50.0, 300.0)


## Sun shadows for the current settings.
static func apply_sun(light: DirectionalLight3D, g: Dictionary = Settings.gfx) -> void:
	if light == null:
		return
	var s: int = g["shadows"]
	light.shadow_enabled = s > 0
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.2
	light.shadow_blur = 1.2
	light.light_angular_distance = 0.6 if s >= 3 else 0.0   # soft-edged sun (PCSS) on the best setting
	match s:
		1:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			light.directional_shadow_max_distance = 48.0
		2:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			light.directional_shadow_max_distance = 96.0
		_:
			light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			light.directional_shadow_max_distance = 160.0
	light.directional_shadow_fade_start = 0.85
	light.light_volumetric_fog_energy = ray_energy(g)
	if s > 0:
		RenderingServer.directional_shadow_atlas_set_size(2048 if s == 1 else 4096, true)
		var soft := RenderingServer.SHADOW_QUALITY_SOFT_LOW
		if s == 2:
			soft = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
		elif s == 3:
			soft = RenderingServer.SHADOW_QUALITY_SOFT_HIGH
		RenderingServer.directional_soft_shadow_filter_set_quality(soft)
		RenderingServer.positional_soft_shadow_filter_set_quality(soft)


## How thick the mist is for the settings (weather and biomes add to it).
static func mist_density(g: Dictionary = Settings.gfx) -> float:
	var base: float = [0.0, 0.0035, 0.007, 0.014][clampi(int(g.get("mist", 0)), 0, 3)]
	if int(g.get("god_rays", 0)) > 0:
		base = maxf(base, 0.0025)   # god rays need a little haze to shine through
	return base


## How brightly the sun lights the mist (god rays): 0 = not at all.
static func ray_energy(g: Dictionary = Settings.gfx) -> float:
	return [0.15, 0.45, 0.9, 1.5][clampi(int(g.get("god_rays", 0)), 0, 3)]


## The terrain and water shaders' options (swaying, waves, see-through water).
static func apply_world(world: Node, g: Dictionary = Settings.gfx) -> void:
	if world == null or not world.has_method("get_solid_material"):
		return
	var solid: ShaderMaterial = world.get_solid_material()
	var water: ShaderMaterial = world.get_water_material()
	solid.set_shader_parameter("wind", 1.0 if g["wind"] else 0.0)
	# With real torch lights on, the baked-in glow is turned down so it isn't doubled.
	solid.set_shader_parameter("lamp_glow", 0.55 if int(g["lights"]) > 0 else 1.0)
	solid.set_shader_parameter("surface", 1.0 if g.get("surface", false) else 0.0)
	solid.set_shader_parameter("variety", 1.0 if g.get("variety", false) else 0.0)
	solid.set_shader_parameter("materials", preload("res://scripts/blocks.gd").get_material_texture())
	water.set_shader_parameter("waves", 1.0 if int(g["water"]) >= 1 else 0.0)
	water.set_shader_parameter("fancy", 1.0 if int(g["water"]) >= 2 else 0.0)


## The sky's color near the horizon, for the fog (so the edge of the world melts into the sky).
static func horizon_color(sun_height: float, tint := Color.WHITE) -> Color:
	var day := smoothstep(-0.18, 0.2, sun_height)
	var twilight := 1.0 - smoothstep(0.0, 0.35, absf(sun_height))
	var c := NIGHT_HORIZON.lerp(DAY_HORIZON, day).lerp(SUNSET, twilight * 0.55)
	return c * tint


static func top_color(sun_height: float, tint := Color.WHITE) -> Color:
	var day := smoothstep(-0.18, 0.2, sun_height)
	return NIGHT_TOP.lerp(DAY_TOP, day) * tint
