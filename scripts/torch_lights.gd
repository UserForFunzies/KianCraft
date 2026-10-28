extends Node3D
## Real lights for torches, lamps, lanterns and portals near you. The world's
## own block light (in the terrain shader) already makes them glow; these add
## proper light on players, mobs and items, and soft flickering shadows on
## the best setting. Only the nearest few get a light (the "Torch lights"
## graphics option), so a big castle full of torches stays fast.

const Blocks = preload("res://scripts/blocks.gd")
const Settings = preload("res://scripts/settings.gd")

const SEARCH_CHUNKS := 2         # look this many chunks around you
const REFRESH := 0.35            # seconds between re-picking the nearest lights
const SHADOWED := 4              # how many of the nearest cast shadows (Ultra)

var world: Node
var budget := 0
var shadows := false

var _pool: Array[OmniLight3D] = []
var _used := 0
var _timer := 0.0
var _flicker: Array = []          # per light: [base energy, flickers?, seed]


func apply_settings() -> void:
	budget = int(Settings.gfx["lights"])
	shadows = Settings.gfx["torch_shadows"] and Settings.modern()
	_timer = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH
		_refresh()
	var t := Time.get_ticks_msec() / 1000.0
	for i in _used:
		var f: Array = _flicker[i]
		if f[1]:
			var s: float = f[2]
			var n := sin(t * 11.0 + s) * 0.5 + sin(t * 17.3 + s * 2.1) * 0.3 + sin(t * 5.1 + s * 0.7) * 0.2
			_pool[i].light_energy = f[0] * (1.0 + n * 0.12)


## Every light-giving block near the camera, nearest first.
func _refresh() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if budget <= 0 or world == null or cam == null or not world.running:
		_set_used(0)
		return
	var c: Vector3 = cam.global_position
	var S: int = Blocks.CHUNK_SIZE
	var L: int = S * S
	var center := Vector2i(floori(c.x) >> 4, floori(c.z) >> 4)
	var found: Array = []        # [dist², pos, block]
	var max_d2 := float((SEARCH_CHUNKS * S) * (SEARCH_CHUNKS * S))
	for dz in range(-SEARCH_CHUNKS, SEARCH_CHUNKS + 1):
		for dx in range(-SEARCH_CHUNKS, SEARCH_CHUNKS + 1):
			var key := center + Vector2i(dx, dz)
			var edits: Dictionary = world._changes.get(key, {})
			for idx in edits:
				var b: int = edits[idx]
				if Blocks.LIGHT_EMISSION[b] >= 6:
					_add(found, key, idx, b, c, S, L, max_d2)
			var data: PackedInt32Array = world._chunk_data.get(key, PackedInt32Array())
			if data.is_empty():
				continue
			for idx in world._chunk_glow.get(key, PackedInt32Array()):
				if not edits.has(idx) and Blocks.LIGHT_EMISSION[data[idx]] >= 6:
					_add(found, key, idx, data[idx], c, S, L, max_d2)
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n := mini(found.size(), budget)
	_set_used(n)
	for i in n:
		var l := _pool[i]
		var b: int = found[i][2]
		var p: Vector3 = found[i][1]
		var style := _style(b)
		l.position = p + style[2]
		l.light_color = style[0]
		l.omni_range = Blocks.LIGHT_EMISSION[b] * 0.6
		l.light_energy = style[1]
		l.shadow_enabled = shadows and i < SHADOWED and style[3]
		_flicker[i] = [style[1], style[4], float(p.x * 3.1 + p.z * 1.7)]


func _add(found: Array, key: Vector2i, idx: int, b: int, c: Vector3, S: int, L: int, max_d2: float) -> void:
	var p := Vector3(key.x * S + idx % S, idx / L - world.depth, key.y * S + (idx / S) % S)
	var d2 := (p + Vector3(0.5, 0.5, 0.5)).distance_squared_to(c)
	if d2 <= max_d2:
		found.append([d2, p, b])


## [color, energy, offset in the block, may cast shadows, flickers]
func _style(b: int) -> Array:
	match b:
		Blocks.TORCH:
			return [Color(1.0, 0.68, 0.35), 1.3, Vector3(0.5, 0.75, 0.5), true, true]
		Blocks.CAMPFIRE:
			return [Color(1.0, 0.6, 0.28), 1.6, Vector3(0.5, 0.5, 0.5), true, true]
		Blocks.LAMP:
			return [Color(1.0, 0.86, 0.62), 1.2, Vector3(0.5, 0.5, 0.5), false, false]
		Blocks.JACK_O_LANTERN:
			return [Color(1.0, 0.55, 0.2), 1.1, Vector3(0.5, 0.5, 0.5), false, true]
		Blocks.GHOST_LANTERN:
			return [Color(0.5, 1.0, 0.9), 1.1, Vector3(0.5, 0.5, 0.5), false, true]
		Blocks.GLOWSHROOM:
			return [Color(0.45, 0.85, 1.0), 0.7, Vector3(0.5, 0.4, 0.5), false, false]
	if b == Blocks.PORTAL_LIT:
		return [Color(0.75, 0.45, 1.0), 1.2, Vector3(0.5, 0.5, 0.5), false, false]
	return [Color(1.0, 0.8, 0.55), 1.0, Vector3(0.5, 0.5, 0.5), false, false]


func _set_used(n: int) -> void:
	while _pool.size() < n:
		var l := OmniLight3D.new()
		l.omni_attenuation = 1.6
		l.light_specular = 0.3
		l.shadow_bias = 0.08
		l.shadow_normal_bias = 1.5
		l.light_size = 0.08
		l.distance_fade_enabled = true
		l.distance_fade_begin = 28.0
		l.distance_fade_length = 6.0
		add_child(l)
		_pool.append(l)
		_flicker.append([1.0, false, 0.0])
	for i in _pool.size():
		_pool[i].visible = i < n
	_used = n
