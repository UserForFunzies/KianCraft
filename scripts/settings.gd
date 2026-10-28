extends RefCounted
## Player settings: screen, graphics, mouse and tips. Saved on this computer
## in user://settings.cfg (next to the worlds folder), so each PC has its own.
##
## Settings.apply(tree) pushes everything to the window and the game;
## anything that cares about a change registers with Settings.on_changed(callable).

const PATH := "user://settings.cfg"

const RESOLUTIONS := [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2048, 1152), Vector2i(2560, 1440)]
const RESOLUTION_NAMES := ["1920 x 1080  (1080p)", "1920 x 1200", "2048 x 1152", "2560 x 1440  (1440p)"]
const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless fullscreen"]
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const RENDERERS := ["Modern (best looking)", "Classic (for old or laptop PCs)"]
const OVERRIDE_PATH := "user://override.cfg"   # the engine reads this at start (see project.godot)

## What each graphics level turns on. Picking a level sets all of these; each
## can then be changed on its own under "Advanced" (that makes it "Custom").
##   view        how far you can see, in chunks (16 blocks each)      CPU + GPU
##   shadows     sun shadows: 0 off, 1 near, 2 medium, 3 far and sharp GPU
##   lights      how many torches and lamps cast real light (0 = glow only) GPU
##   torch_shadows  the nearest torches cast shadows too                GPU
##   ssao        soft shadows in corners and under things               GPU
##   ssil        light bouncing off nearby colored blocks               GPU
##   sdfgi       sunlight bouncing around the world (global light)      GPU (heavy)
##   glow        bright things glow (torches, lava, sunsets)            GPU
##   god_rays    sunbeams through trees and windows: 0 off .. 3 strong  GPU
##   mist        hazy air you can see light in: 0 off .. 3 thick        GPU
##   ssr         shiny reflections on wet ground                        GPU
##   clouds      0 none, 1 simple, 2 detailed                           GPU
##   water       0 simple, 1 waves, 2 see-through with foam             GPU
##   wind        leaves and grass sway                                  GPU (light)
##   aa          smooth edges: 0 off, 1 FXAA, 2 TAA, 3 MSAA 2x, 4 MSAA 4x  GPU
##   scale       3D drawn at this fraction of the screen (FSR upscaling) GPU
##   particles   how many sparks, splashes and bits                     CPU
##   weather     how many rain drops and snowflakes                     CPU + GPU
##   detail_textures  block pictures: 0 simple, 1 detailed, 2 Ultra HD     GPU (light)
##   surface     blocks look bumpy and shiny in the light (stone, ore, bark) GPU
##   variety     natural blocks change color a little across the world   GPU (light)
const QUALITY := [
	{"view": 6, "shadows": 0, "lights": 0, "torch_shadows": false, "ssao": false, "ssil": false, "sdfgi": false,
		"glow": false, "god_rays": 0, "mist": 0, "ssr": false, "clouds": 1, "water": 0, "wind": false, "aa": 0, "scale": 1.0,
		"particles": 0.5, "weather": 0.4, "detail_textures": 0, "surface": false, "variety": false, "creature_detail": 0},
	{"view": 8, "shadows": 1, "lights": 12, "torch_shadows": false, "ssao": false, "ssil": false, "sdfgi": false,
		"glow": true, "god_rays": 0, "mist": 0, "ssr": false, "clouds": 1, "water": 1, "wind": true, "aa": 1, "scale": 1.0,
		"particles": 1.0, "weather": 0.7, "detail_textures": 1, "surface": false, "variety": true, "creature_detail": 1},
	{"view": 12, "shadows": 2, "lights": 32, "torch_shadows": false, "ssao": true, "ssil": false, "sdfgi": false,
		"glow": true, "god_rays": 1, "mist": 1, "ssr": false, "clouds": 2, "water": 2, "wind": true, "aa": 2, "scale": 1.0,
		"particles": 1.0, "weather": 1.0, "detail_textures": 1, "surface": true, "variety": true, "creature_detail": 2},
	{"view": 16, "shadows": 3, "lights": 64, "torch_shadows": true, "ssao": true, "ssil": true, "sdfgi": true,
		"glow": true, "god_rays": 2, "mist": 1, "ssr": true, "clouds": 2, "water": 2, "wind": true, "aa": 2, "scale": 1.0,
		"particles": 1.5, "weather": 1.5, "detail_textures": 2, "surface": true, "variety": true, "creature_detail": 2},
]
## The "Advanced" list in Settings: [key, label, kind, options/range, what it costs].
const GFX_OPTIONS := [
	["view", "View distance", "choice", [[4, "4 chunks"], [6, "6 chunks"], [8, "8 chunks"], [10, "10 chunks"], [12, "12 chunks"], [16, "16 chunks"], [20, "20 chunks"]], "CPU + GPU"],
	["shadows", "Sun shadows", "choice", [[0, "Off"], [1, "Near"], [2, "Medium"], [3, "Far and sharp"]], "GPU"],
	["lights", "Torch lights", "choice", [[0, "Glow only"], [12, "12 nearby"], [32, "32 nearby"], [64, "64 nearby"]], "GPU"],
	["torch_shadows", "Torch shadows", "bool", null, "GPU heavy"],
	["ssao", "Corner shadows (SSAO)", "bool", null, "GPU"],
	["ssil", "Bounced color (SSIL)", "bool", null, "GPU"],
	["sdfgi", "Global light (SDFGI)", "bool", null, "GPU heavy"],
	["glow", "Glow", "bool", null, "GPU light"],
	["god_rays", "God rays", "choice", [[0, "Off"], [1, "Soft"], [2, "Medium"], [3, "Strong"]], "GPU"],
	["mist", "Mist in the air", "choice", [[0, "Off"], [1, "Light"], [2, "Medium"], [3, "Thick"]], "GPU"],
	["ssr", "Wet reflections", "bool", null, "GPU"],
	["clouds", "Clouds", "choice", [[0, "Off"], [1, "Simple"], [2, "Detailed"]], "GPU"],
	["water", "Water", "choice", [[0, "Simple"], [1, "Waves"], [2, "Clear with foam"]], "GPU"],
	["wind", "Swaying leaves and grass", "bool", null, "GPU light"],
	["aa", "Smooth edges", "choice", [[0, "Off"], [1, "FXAA"], [2, "TAA"], [3, "MSAA 2x"], [4, "MSAA 4x"]], "GPU"],
	["scale", "3D resolution", "choice", [[1.0, "100%"], [0.85, "85% (FSR)"], [0.75, "75% (FSR)"], [0.67, "67% (FSR)"], [0.5, "50% (FSR)"]], "GPU"],
	["particles", "Particles", "choice", [[0.5, "Few"], [1.0, "Normal"], [1.5, "Lots"]], "CPU"],
	["weather", "Rain and snow", "choice", [[0.4, "Light"], [0.7, "Normal"], [1.0, "Heavy"], [1.5, "Downpour"]], "CPU + GPU"],
	["detail_textures", "Block textures", "choice", [[0, "Simple"], [1, "Detailed"], [2, "Ultra HD"]], "GPU light"],
	["surface", "Bumpy, shiny surfaces", "bool", null, "GPU"],
	["creature_detail", "Creature & character detail", "choice", [[0, "Simple (classic)"], [1, "Detailed"], [2, "Ultra HD"]], "GPU light"],
	["variety", "Natural color variety", "bool", null, "GPU light"],
]
## Things the Classic renderer can't do (they're hidden there).
const MODERN_ONLY := ["ssao", "ssil", "sdfgi", "god_rays", "mist", "ssr", "torch_shadows"]

static var resolution := 0          # index into RESOLUTIONS
static var window_mode := 0         # index into WINDOW_MODES
static var quality := 2             # index into QUALITY (High) - the last level picked
static var gfx: Dictionary = QUALITY[2].duplicate()   # the graphics actually in use
static var renderer := 0            # index into RENDERERS (takes effect on restart)
static var mouse_sensitivity := 1.0 # 0.25 .. 3.0
static var show_tips := true
static var master_volume := 0.8     # 0 .. 1
static var sfx_volume := 1.0
static var ambience_volume := 0.7
static var ui_volume := 0.8
static var first_run := true        # true until the player answers the "tips?" question
## Party members' name tags (seen from far away, through hills).
const TAG_COLORS := [["Green", Color(0.55, 1.0, 0.6)], ["Gold", Color(1.0, 0.85, 0.35)], ["Sky blue", Color(0.55, 0.82, 1.0)],
		["Pink", Color(1.0, 0.6, 0.85)], ["Purple", Color(0.78, 0.62, 1.0)], ["White", Color(1, 1, 1)]]
static var chat_size := 0           # 0 Small, 1 Medium, 2 Large
static var party_tags := true       # show party members' names from far away
static var tag_size := 1.0          # 0.5 .. 2.0
static var tag_color := 0           # index into TAG_COLORS
static var tag_alpha := 1.0         # 0.2 (very see-through) .. 1.0

static var _listeners: Array[Callable] = []


static func _static_init() -> void:
	load_settings()


## Call `callback` (no arguments) whenever settings change.
static func on_changed(callback: Callable) -> void:
	_listeners.append(callback)


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	resolution = clampi(cfg.get_value("display", "resolution", resolution), 0, RESOLUTIONS.size() - 1)
	window_mode = clampi(cfg.get_value("display", "window_mode", window_mode), 0, WINDOW_MODES.size() - 1)
	quality = clampi(cfg.get_value("graphics", "quality", quality), 0, QUALITY.size() - 1)
	gfx = QUALITY[quality].duplicate()
	var saved = cfg.get_value("graphics", "options", {})
	if saved is Dictionary:
		for k in saved:
			if gfx.has(k) and typeof(saved[k]) == typeof(gfx[k]):
				gfx[k] = saved[k]
	renderer = clampi(cfg.get_value("graphics", "renderer", renderer), 0, RENDERERS.size() - 1)
	mouse_sensitivity = clampf(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity), 0.25, 3.0)
	show_tips = cfg.get_value("help", "show_tips", show_tips)
	master_volume = clampf(cfg.get_value("sound", "master", master_volume), 0.0, 1.0)
	sfx_volume = clampf(cfg.get_value("sound", "effects", sfx_volume), 0.0, 1.0)
	ambience_volume = clampf(cfg.get_value("sound", "ambience", ambience_volume), 0.0, 1.0)
	ui_volume = clampf(cfg.get_value("sound", "interface", ui_volume), 0.0, 1.0)
	first_run = cfg.get_value("help", "first_run", first_run)
	party_tags = cfg.get_value("party", "show_tags", party_tags)
	chat_size = clampi(cfg.get_value("help", "chat_size", chat_size), 0, 2)
	tag_size = clampf(cfg.get_value("party", "tag_size", tag_size), 0.5, 2.0)
	tag_color = clampi(cfg.get_value("party", "tag_color", tag_color), 0, TAG_COLORS.size() - 1)
	tag_alpha = clampf(cfg.get_value("party", "tag_alpha", tag_alpha), 0.2, 1.0)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "options", gfx)
	cfg.set_value("graphics", "renderer", renderer)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("help", "show_tips", show_tips)
	cfg.set_value("sound", "master", master_volume)
	cfg.set_value("sound", "effects", sfx_volume)
	cfg.set_value("sound", "ambience", ambience_volume)
	cfg.set_value("sound", "interface", ui_volume)
	cfg.set_value("help", "first_run", first_run)
	cfg.set_value("party", "show_tags", party_tags)
	cfg.set_value("help", "chat_size", chat_size)
	cfg.set_value("party", "tag_size", tag_size)
	cfg.set_value("party", "tag_color", tag_color)
	cfg.set_value("party", "tag_alpha", tag_alpha)
	cfg.save(PATH)


static func get_volume(key: String) -> float:
	match key:
		"master_volume": return master_volume
		"sfx_volume": return sfx_volume
		"ambience_volume": return ambience_volume
		"ui_volume": return ui_volume
	return 0.0


static func set_volume(key: String, v: float) -> void:
	match key:
		"master_volume": master_volume = v
		"sfx_volume": sfx_volume = v
		"ambience_volume": ambience_volume = v
		"ui_volume": ui_volume = v


static func q() -> Dictionary:
	return gfx


static func view_distance() -> int:
	return gfx["view"]


## Picks a graphics level (sets every option to that level's values).
static func set_quality(i: int) -> void:
	quality = clampi(i, 0, QUALITY.size() - 1)
	gfx = QUALITY[quality].duplicate()


## True when some option was changed away from the picked level.
static func is_custom() -> bool:
	var preset: Dictionary = QUALITY[quality]
	for k in preset:
		if gfx.get(k) != preset[k]:
			return true
	return false


static func set_option(key: String, value) -> void:
	gfx[key] = value


static func msaa() -> int:
	var aa := int(gfx["aa"])
	if (aa == 1 or aa == 2) and not modern():
		return Viewport.MSAA_2X   # (Classic has no FXAA or TAA)
	match aa:
		3: return Viewport.MSAA_2X
		4: return Viewport.MSAA_4X
	return Viewport.MSAA_DISABLED


## True when the game is running on the Modern (Forward+) renderer.
static func modern() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


## The renderer takes effect the next time the game starts: the engine reads
## user://override.cfg before anything else (project.godot points at it).
static func write_renderer_override() -> void:
	if renderer == 1:
		var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
		if f:
			f.store_string("[rendering]\n\nrenderer/rendering_method=\"gl_compatibility\"\nrenderer/rendering_method.mobile=\"gl_compatibility\"\n")
	elif FileAccess.file_exists(OVERRIDE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE_PATH))


## The renderer this run is using (0 Modern, 1 Classic).
static func running_renderer() -> int:
	return 0 if modern() else 1


## Pushes the screen settings to the window. 3D is drawn at the chosen
## resolution; menus and text are always drawn sharp at the window's real size.
static func apply_display(tree: SceneTree) -> void:
	var vp := tree.root
	var res: Vector2i = RESOLUTIONS[resolution]
	vp.msaa_3d = msaa()
	var aa := int(gfx["aa"])
	if modern():
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == 2 and modern()
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var size := Vector2i(mini(res.x, usable.size.x), mini(res.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
			_set_scale(vp, 1.0)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_set_scale(vp, clampf(float(res.y) / maxf(screen_size.y, 1.0), 0.5, 1.0))
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_set_scale(vp, clampf(float(res.y) / maxf(screen_size.y, 1.0), 0.5, 1.0))


## 3D resolution: the screen size times the "3D resolution" option. Below 100%
## the Modern renderer sharpens it back up with AMD FSR.
static func _set_scale(vp: Viewport, base: float) -> void:
	var s := clampf(base * float(gfx["scale"]), 0.25, 1.0)
	vp.scaling_3d_scale = s
	if s < 0.999 and modern():
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.fsr_sharpness = 0.3
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


static func apply(tree: SceneTree) -> void:
	apply_display(tree)
	save_settings()
	write_renderer_override()
	for cb in _listeners.duplicate():
		if cb.is_valid():
			cb.call()
		else:
			_listeners.erase(cb)


## F11: flip between windowed and fullscreen.
static func toggle_fullscreen(tree: SceneTree) -> void:
	window_mode = 0 if window_mode != 0 else 1
	apply(tree)
