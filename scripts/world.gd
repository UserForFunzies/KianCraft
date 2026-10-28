extends Node3D
## The voxel world.
##
## - Generates terrain (hills, mountains, water, trees, caves) from a seed.
##   The same seed gives the same world on every computer.
## - Loads chunks around the local player on background threads.
## - Stores every block edit in `_changes`. That's the only world state that has
##   to be saved to disk or sent over the network; everything else is
##   regenerated from the seed.
## - Only the server changes blocks (survival.gd checks the rules first), then
##   tells everyone to apply the change with apply_set_block.

const Blocks = preload("res://scripts/blocks.gd")
const VillagerData = preload("res://scripts/villager_data.gd")
const Mesher = preload("res://scripts/chunk_mesher.gd")
const VoxelShader = preload("res://shaders/voxel.gdshader")
const WaterShader = preload("res://shaders/water.gdshader")

const S := Blocks.CHUNK_SIZE
const H := Blocks.CHUNK_HEIGHT
const L := S * S
const SEA_LEVEL := 28
const TREE_CELL := 6           # at most one tree per 6x6 area
const MAX_TASKS := 6           # background jobs running at once
const MAX_URGENT_TASKS := 10   # extra room so block edits never wait behind loading
const NEIGHBORS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]  # order matches what chunk_mesher.gd expects

signal block_changed(pos: Vector3i, old_block: int, new_block: int)
## A chunk was (re)lit: how much light reaches each door, torch and bed in it.
## {Vector3i world pos: Vector2(sunlight 0-1, lamp light 0-1)}
signal models_lit(key: Vector2i, lights: Dictionary)

var render_distance := 6       # in chunks
var daylight := 1.0            # current sunlight strength (set by the day/night cycle)
var world_seed := 0
## How this world's land is laid out. 1 = worlds made before the big biome
## update (plains, desert, candy from noise); 2 = biome regions with meadows
## around spawn, plus forest, candy, desert and mountains further out.
var gen_version := 1
var depth := 0                 # extra blocks below y = 0 (gen 13+: the deeper underground)
var running := false

var _chunk_data := {}          # Vector2i -> PackedInt32Array
var _chunk_top := {}           # Vector2i -> int (highest non-air y)
var _chunk_nodes := {}         # Vector2i -> StaticBody3D
var _chunk_version := {}       # Vector2i -> int (bumped on edit, drops stale meshes)
var _changes := {}             # Vector2i -> { local_index:int -> block:int }
var _dirty := {}               # chunks that need re-meshing after an edit
var _pending_data := {}
var _pending_mesh := {}
var _tasks: Array[Dictionary] = []
var _offsets: Array[Vector2i] = []
var _center := Vector2i.ZERO
var _focus: Node3D
var _water_queue := {}         # server: blocks whose water might need to change
var _water_timer := 0.0
var _chunk_glow := {}          # chunk key -> lights the world put there itself (cell indexes)
var _door_facing := {}         # Vector3i (door's bottom block) -> true if it runs along X
var _extra_keys := {}          # server: chunks kept loaded (data only) around other players

var _hills := FastNoiseLite.new()
var _mountains := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _cave_a := FastNoiseLite.new()
var _cave_b := FastNoiseLite.new()
var _deep_noise := FastNoiseLite.new()    # the Deep's big caverns (gen 12)
var _lava_noise := FastNoiseLite.new()    # where its lava lakes are
var _heat_noise := FastNoiseLite.new()    # where it runs hot: the lava caverns (gen 14)
var _water_ticks := 0
var _desert_noise := FastNoiseLite.new()
var _candy_noise := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _solid_material: ShaderMaterial
var _water_material: ShaderMaterial


func _ready() -> void:
	var atlas := Blocks.get_atlas()
	_solid_material = ShaderMaterial.new()
	_solid_material.shader = VoxelShader
	_solid_material.set_shader_parameter("atlas", atlas)
	_solid_material.set_shader_parameter("tile_count", float(Blocks.TILE_COUNT))
	_solid_material.set_shader_parameter("materials", Blocks.get_material_texture())
	_water_material = ShaderMaterial.new()
	_water_material.shader = WaterShader
	_water_material.set_shader_parameter("atlas", atlas)


func _exit_tree() -> void:
	clear()


# --- Lifecycle -------------------------------------------------------------------

func start(seed_value: int, changes: Dictionary, door_facing := {}, version := 1) -> void:
	clear()
	world_seed = seed_value
	gen_version = version
	depth = LOWER_DEPTH if version >= 13 else 0
	_changes = changes.duplicate(true)
	_door_facing = door_facing.duplicate()
	for n in [_hills, _mountains, _detail, _forest, _cave_a, _cave_b, _desert_noise, _candy_noise]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.seed = seed_value
	_hills.frequency = 0.005
	_hills.fractal_octaves = 4
	_mountains.seed = seed_value + 1
	_mountains.frequency = 0.0025
	_mountains.fractal_octaves = 3
	_detail.seed = seed_value + 2
	_detail.frequency = 0.03
	_detail.fractal_octaves = 2
	_forest.seed = seed_value + 3
	_forest.frequency = 0.01
	# Caves are where two wavy 3D noise "sheets" cross, which makes long tunnels.
	for n in [_cave_a, _cave_b]:
		n.frequency = 0.022
		n.fractal_octaves = 1
	_cave_a.seed = seed_value + 4
	_cave_b.seed = seed_value + 5
	_deep_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_deep_noise.seed = seed_value + 41
	_deep_noise.frequency = 0.03
	_deep_noise.fractal_octaves = 2
	_lava_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_lava_noise.seed = seed_value + 42
	_lava_noise.frequency = 0.045
	_heat_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_heat_noise.seed = seed_value + 43
	_heat_noise.frequency = 0.0035
	# Biomes: big, slow noise. High "desert" values = sand; high "candy" = candy land.
	_desert_noise.seed = seed_value + 6
	_desert_noise.frequency = 0.0022
	_desert_noise.fractal_octaves = 2
	_candy_noise.seed = seed_value + 7
	_candy_noise.frequency = 0.0019
	_candy_noise.fractal_octaves = 2
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.seed = seed_value + 8
	_warp.frequency = 0.008
	_warp.fractal_octaves = 2
	_build_offsets()
	running = true


## Stops everything and frees all chunks. Safe to call any time.
func clear() -> void:
	for job in _tasks:
		WorkerThreadPool.wait_for_task_completion(job["id"])
	_tasks.clear()
	for node in _chunk_nodes.values():
		node.queue_free()
	_chunk_nodes.clear()
	_chunk_data.clear()
	_chunk_top.clear()
	_chunk_glow.clear()
	_chunk_version.clear()
	_changes.clear()
	_door_facing.clear()
	_water_queue.clear()
	_dirty.clear()
	_pending_data.clear()
	_pending_mesh.clear()
	_extra_keys.clear()
	_focus = null
	running = false


## The node (usually the local player) that chunks are loaded around.
func set_focus(node: Node3D) -> void:
	_focus = node
	if node:
		_center = chunk_key_at(node.global_position)


func set_render_distance(chunks: int) -> void:
	render_distance = chunks
	_build_offsets()


## 0 = darkest night, 1 = full day. Called by the day/night cycle.
func set_daylight(value: float) -> void:
	daylight = value
	_solid_material.set_shader_parameter("daylight", value)
	_water_material.set_shader_parameter("daylight", value)


func get_solid_material() -> ShaderMaterial:
	return _solid_material


func get_water_material() -> ShaderMaterial:
	return _water_material


## Weather and seasons: wet, shiny ground in the rain; snow settling on top of blocks.
func set_weather_look(wetness: float, snow: float, rain: float) -> void:
	_solid_material.set_shader_parameter("wetness", wetness)
	_solid_material.set_shader_parameter("snow_cover", snow)
	_water_material.set_shader_parameter("rain", rain)


## The water reflects this sky color.
func set_sky_color(c: Color) -> void:
	_water_material.set_shader_parameter("sky_color", c)


func get_changes() -> Dictionary:
	return _changes


func loaded_chunk_count() -> int:
	return _chunk_nodes.size()


# --- Terrain generation ----------------------------------------------------------

## Height of the top terrain block at a world column (before trees/caves/edits).
func surface_height(x: int, z: int) -> int:
	if gen_version >= 2:
		return _surface_height_v2(x, z)
	var w := _biome_weights_v1(x, z)
	var hills := _hills.get_noise_2d(x, z) * 12.0
	var m := maxf(_mountains.get_noise_2d(x, z) - 0.1, 0.0)
	var mountains := m * m * 140.0
	var detail := _detail.get_noise_2d(x, z) * 2.0
	# Deserts are flat with gentle dunes; candy land is soft rolling hills.
	var flat := 1.0 - 0.6 * w.x - 0.45 * w.y
	var mountain_share := clampf(1.0 - w.x - w.y, 0.0, 1.0)
	var h := SEA_LEVEL + 2 + hills * flat + mountains * mountain_share + detail * (1.0 + w.x) + 3.0 * w.x + 3.0 * w.y
	return clampi(int(h), 1, H - 12)


# --- Biomes ------------------------------------------------------------------------

const DESERT_LIMIT := 0.24
const CANDY_LIMIT := 0.3
const BLEND := 0.07

## Worlds from before the biome update: x = desert, y = candy (0..1).
func _biome_weights_v1(x: float, z: float) -> Vector2:
	var c := smoothstep(CANDY_LIMIT - BLEND, CANDY_LIMIT + BLEND, _candy_noise.get_noise_2d(x, z))
	var d := smoothstep(DESERT_LIMIT - BLEND, DESERT_LIMIT + BLEND, _desert_noise.get_noise_2d(x, z)) * (1.0 - c)
	return Vector2(d, c)


## "plains" (meadows), "desert", "candy", and in newer worlds "forest" and "mountain".
func biome_at(x: float, z: float) -> String:
	if gen_version >= 2:
		return _nearest_regions(x, z)[0]["biome"]
	var w := _biome_weights_v1(x, z)
	if w.y >= 0.5:
		return "candy"
	if w.x >= 0.5:
		return "desert"
	return "plains"


## Closest spot of a biome, searching outward in rings. Returns Vector3(0, -1, 0) if none.
func find_biome(biome: String, from: Vector2, max_radius := 4000) -> Vector3:
	if biome_at(from.x, from.y) == biome:
		return Vector3(from.x, surface_height(int(from.x), int(from.y)) + 1, from.y)
	for r in range(32, max_radius, 32):
		var steps := maxi(8, int(TAU * r / 32.0))
		for i in steps:
			var a := TAU * i / steps
			var x := from.x + cos(a) * r
			var z := from.y + sin(a) * r
			# Step a little further in, so we land inside the biome, not on its edge.
			if biome_at(x, z) == biome and biome_at(x + cos(a) * 24.0, z + sin(a) * 24.0) == biome:
				x += cos(a) * 24.0
				z += sin(a) * 24.0
				return Vector3(floorf(x) + 0.5, surface_height(int(x), int(z)) + 1, floorf(z) + 0.5)
	return Vector3(0, -1, 0)


## A good place to spawn: dry land near the world origin.
func find_spawn_point() -> Vector3:
	for r in range(0, 200, 4):
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x: int = dir.x * r
			var z: int = dir.y * r
			var h := surface_height(x, z)
			if h > SEA_LEVEL + 1 and not _tree_at_column(x, z) and not _is_cave(x, h, z) \
					and biome_at(x, z) == "plains":
				return Vector3(x + 0.5, h + 1.05, z + 0.5)
	return Vector3(0.5, H - 10, 0.5)


# --- Biome regions (newer worlds) ------------------------------------------------
# The land is split into big regions (about REGION blocks across), each with
# one biome. Region borders wiggle (warp noise) and blend over BORDER blocks.
# Near spawn it's all meadows; easy biomes (forest, candy) start a bit further
# out, and hard ones (desert, mountain) only far away.

const REGION := 200.0
const BORDER := 26.0
const SAFE_RADIUS := 260.0      # all meadows inside this
const HARD_RADIUS := 480.0      # desert and mountains only beyond this
const CHAMBER_Y := 16
const NICE_NAMES := {"plains": "Meadows", "desert": "Desert", "candy": "Candy Land", "forest": "Tall Forest", "mountain": "Snowy Mountains", "fall": "Fall Forest", "spooky": "Spooky Forest", "sky": "Floating Islands", "chess": "Chessboard Kingdom", "fastfood": "Fast Food Land"}

## Which biome a region at this distance from spawn gets (roll 0-99).
const SPOOKY_RADIUS := 1060.0   # spooky regions start here, so even their blurry edges stay 1000+ blocks out

func _pick_biome(d: float, roll: int) -> String:
	if gen_version >= 5 and d >= SPOOKY_RADIUS and roll >= 16 and roll % 8 == 0:
		return "spooky"
	if gen_version >= 6 and d >= SPOOKY_RADIUS and roll >= 16 and roll % 8 == 4:
		return "sky"
	if gen_version >= 9 and d >= HARD_RADIUS and roll >= 16 and roll % 8 == 2:
		return "chess"   # the chessboard kingdom (worlds made after it was added)
	if gen_version >= 10 and d >= HARD_RADIUS and roll >= 16 and roll % 8 == 6:
		return "fastfood"   # fast food land
	if gen_version >= 4:
		# Worlds made after the fall forest was added (older worlds keep their layout).
		if d >= HARD_RADIUS:
			return ["plains", "plains", "forest", "candy", "desert", "mountain", "fall"][roll % 7] if roll >= 16 else "plains"
		elif d >= SAFE_RADIUS:
			return "plains" if roll < 44 else ("forest" if roll < 64 else ("fall" if roll < 84 else "candy"))
		return "plains"
	if d >= HARD_RADIUS:
		return ["plains", "plains", "forest", "candy", "desert", "mountain"][roll % 6] if roll >= 16 else "plains"
	elif d >= SAFE_RADIUS:
		return "plains" if roll < 50 else ("forest" if roll < 75 else "candy")
	return "plains"


## A region's biome and middle. Pure math (no shared cache), because chunks
## are generated on several threads at once.
func _region(c: Vector2i) -> Dictionary:
	var h := _hash(c.x * 92821 + 7, c.y * 68917 + 3)
	var center := (Vector2(c) + Vector2(0.2 + (h % 600) / 1000.0, 0.2 + ((h >> 10) % 600) / 1000.0)) * REGION
	var d := center.length()
	var roll := (h >> 20) % 100
	var biome := _pick_biome(d, roll)
	return {"center": center, "biome": biome, "cell": c, "hash": h}


## Fast version for every block column: just [biome, distance] of the closest
## two regions, without building dictionaries.
func _region_biome(c: Vector2i) -> Array:
	var h := _hash(c.x * 92821 + 7, c.y * 68917 + 3)
	var center := (Vector2(c) + Vector2(0.2 + (h % 600) / 1000.0, 0.2 + ((h >> 10) % 600) / 1000.0)) * REGION
	var d := center.length()
	var roll := (h >> 20) % 100
	var biome := _pick_biome(d, roll)
	return [biome, center]


## The two closest regions to a point: [{"biome", "dist"}, {"biome", "dist"}].
func _nearest_regions(x: float, z: float) -> Array:
	var p := Vector2(x + _warp.get_noise_2d(x, z) * 45.0, z + _warp.get_noise_2d(z + 500.0, x) * 45.0)
	var base := Vector2i(floori(p.x / REGION), floori(p.y / REGION))
	var b1 := ""
	var d1 := INF
	var b2 := ""
	var d2 := INF
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var r := _region_biome(base + Vector2i(dx, dz))
			var d := p.distance_squared_to(r[1])
			if d < d1:
				b2 = b1
				d2 = d1
				b1 = r[0]
				d1 = d
			elif d < d2:
				b2 = r[0]
				d2 = d
	return [{"biome": b1, "dist": sqrt(d1)}, {"biome": b2, "dist": sqrt(d2)}]


## How much of each biome is here, for smooth borders: {biome: weight}.
func biome_weights(x: float, z: float) -> Dictionary:
	if gen_version < 2:
		var w := _biome_weights_v1(x, z)
		return {"desert": w.x, "candy": w.y, "plains": maxf(0.0, 1.0 - w.x - w.y)}
	var n := _nearest_regions(x, z)
	if n[0]["biome"] == n[1]["biome"]:
		return {n[0]["biome"]: 1.0}
	var t := clampf((n[1]["dist"] - n[0]["dist"]) / BORDER, 0.0, 1.0)
	var wa := 0.5 + 0.5 * smoothstep(0.0, 1.0, t)
	return {n[0]["biome"]: wa, n[1]["biome"]: 1.0 - wa}


func _biome_height(biome: String, x: int, z: int) -> float:
	var hills := _hills.get_noise_2d(x, z) * 12.0
	var detail := _detail.get_noise_2d(x, z) * 2.0
	match biome:
		"desert":
			return SEA_LEVEL + 5 + hills * 0.35 + detail * 2.0
		"candy":
			return SEA_LEVEL + 5 + hills * 0.55 + detail
		"forest":
			return SEA_LEVEL + 4 + hills * 1.0 + detail
		"fall":
			return SEA_LEVEL + 4 + hills * 0.75 + detail
		"spooky":
			return SEA_LEVEL + 4 + hills * 0.9 + detail * 1.5
		"sky":
			return SEA_LEVEL + 3 + hills * 0.45 + detail
		"chess":
			return SEA_LEVEL + 5 + hills * 0.18 + detail * 0.25   # nearly flat, like a giant board
		"fastfood":
			return SEA_LEVEL + 5 + hills * 0.5 + detail * 0.5    # soft rolling buns
		"mountain":
			var m := (_mountains.get_noise_2d(x, z) + 1.0) * 0.5
			return SEA_LEVEL + 12 + pow(m, 1.5) * 46.0 + hills * 0.6 + detail * 1.5
	return SEA_LEVEL + 3 + hills * 0.8 + detail


func _surface_height_v2(x: int, z: int) -> int:
	return _column_v2(x, z)[0]


## [surface height, biome] of any column, straight from the seed (no chunk
## needs to be loaded). Maps use this to draw the land.
func column_info(x: int, z: int) -> Array:
	if gen_version >= 2:
		return _column_v2(x, z)
	return [surface_height(x, z), biome_at(x, z)]


## [height, biome] for a column in one go (newer worlds).
func _column_v2(x: int, z: int) -> Array:
	var n := _nearest_regions(x, z)
	var b1: String = n[0]["biome"]
	var b2: String = n[1]["biome"]
	var h := _biome_height(b1, x, z)
	if b1 != b2:
		var t := clampf((n[1]["dist"] - n[0]["dist"]) / BORDER, 0.0, 1.0)
		var wa := 0.5 + 0.5 * smoothstep(0.0, 1.0, t)
		h = h * wa + _biome_height(b2, x, z) * (1.0 - wa)
	return [clampi(int(h), 1, H - 12), b1]


## Mine shafts: in mountain regions that touch another mountain region (the
## bigger mountain ranges), a tunnel leads down from the region's middle into
## a big chamber where the Yeti lives.
func _mine_shaft(c: Vector2i) -> Dictionary:
	if gen_version < 2:
		return {}
	var r := _region(c)
	if r["biome"] != "mountain" or (r["hash"] >> 7) % 100 >= 65:
		return {}
	var big := false
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _region(c + off)["biome"] == "mountain":
			big = true
	if not big:
		return {}
	var ex := int(r["center"].x)
	var ez := int(r["center"].y)
	var top := _surface_height_v2(ex, ez)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var dir: Vector2i = dirs[(r["hash"] >> 3) % 4]
	var length := maxi(top - CHAMBER_Y, 4)
	var chamber := Vector3i(ex + dir.x * (length + 9), CHAMBER_Y, ez + dir.y * (length + 9))
	return {"entrance": Vector3i(ex, top + 1, ez), "dir": dir, "length": length, "chamber": chamber}


## Fairy villages: very rarely, in the middle of a tall forest region.
func _fairy_village(c: Vector2i) -> Dictionary:
	if gen_version < 2:
		return {}
	var r := _region(c)
	if r["biome"] != "forest" or (r["hash"] >> 9) % 100 >= 30:
		return {}
	var houses: int = 2 + (r["hash"] >> 13) % 4   # 2 to 5
	var center := Vector2i(int(r["center"].x), int(r["center"].y))
	var spots: Array[Vector2i] = []
	for i in houses:
		var a: float = TAU * i / houses + ((r["hash"] >> 17) % 100) / 100.0
		var rad: float = 5.0 + houses * 0.6
		spots.append(center + Vector2i(roundi(cos(a) * rad), roundi(sin(a) * rad)))
	return {"id": "v%d_%d" % [c.x, c.y], "center": center, "houses": spots, "radius": 6 + houses * 2}


func _structures_near(ox: int, oz: int) -> Dictionary:
	var shafts := []
	var villages := []
	if gen_version < 2:
		return {"shafts": shafts, "villages": villages}
	var base := Vector2i(floori(ox / REGION), floori(oz / REGION))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := base + Vector2i(dx, dz)
			var ms := _mine_shaft(c)
			if not ms.is_empty():
				shafts.append(ms)
			var fv := _fairy_village(c)
			if not fv.is_empty():
				villages.append(fv)
	return {"shafts": shafts, "villages": villages}


## Chamber centers of mine shafts within `radius` (for the Yeti).
func mine_chambers_near(pos: Vector3, radius: float) -> Array:
	var out := []
	for ms in _structures_near(floori(pos.x), floori(pos.z))["shafts"]:
		if Vector3(ms["chamber"]).distance_to(pos) <= radius:
			out.append(ms["chamber"])
	return out


func fairy_villages_near(pos: Vector3, radius: float) -> Array:
	var out := []
	for v in _structures_near(floori(pos.x), floori(pos.z))["villages"]:
		if Vector2(v["center"]).distance_to(Vector2(pos.x, pos.z)) <= radius:
			out.append(v)
	return out


## Nearest mine shaft entrance or fairy village (for /locate). y = -1 if none.
func find_structure(kind: String, from: Vector2, max_radius := 4000.0) -> Vector3:
	if gen_version < 2:
		return Vector3(0, -1, 0)
	var best := Vector3(0, -1, 0)
	var best_d := max_radius
	var cells := int(max_radius / REGION) + 1
	var base := Vector2i(floori(from.x / REGION), floori(from.y / REGION))
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var c := base + Vector2i(dx, dz)
			var at := Vector3(0, -1, 0)
			if kind == "mineshaft":
				var ms := _mine_shaft(c)
				if not ms.is_empty():
					at = Vector3(ms["entrance"])
			else:
				var fv := _fairy_village(c)
				if not fv.is_empty():
					at = Vector3(fv["center"].x, surface_height(fv["center"].x, fv["center"].y) + 1, fv["center"].y)
			if at.y >= 0 and Vector2(at.x, at.z).distance_to(from) < best_d:
				best_d = Vector2(at.x, at.z).distance_to(from)
				best = at
	return best


func _carve_mine_shaft(data: PackedInt32Array, ox: int, oz: int, ms: Dictionary) -> int:
	var top := 0
	var e: Vector3i = ms["entrance"]
	var dir: Vector2i = ms["dir"]
	var side := Vector2i(-dir.y, dir.x)
	var cx := ox + S * 0.5
	var cz := oz + S * 0.5
	# Quick skip if this chunk is nowhere near the shaft.
	var far := Vector2(Vector2(ms["chamber"].x, ms["chamber"].z) - Vector2(cx, cz)).length()
	if far > ms["length"] + 40 and Vector2(e.x - cx, e.z - cz).length() > ms["length"] + 40:
		return 0
	for i in ms["length"] + 1:
		var fy: int = e.y - 1 - i
		var p: Vector2i = Vector2i(e.x, e.z) + dir * i
		var support: bool = i % 4 == 0
		for w in range(-2, 3):
			var q: Vector2i = p + side * w
			for dy in range(-1, 5):
				var b := -1
				if dy == -1:
					b = Blocks.PLANKS if absi(w) <= 1 else -1
				elif absi(w) <= 1 and dy <= 3:
					b = Blocks.AIR
				elif support and absi(w) == 2 and dy <= 3:
					b = Blocks.LOG
				elif support and dy == 4:
					b = Blocks.PLANKS
				if b >= 0:
					_put(data, ox, oz, q.x, fy + 1 + dy, q.y, b, false)
		# Clear the space above the entrance so it isn't buried.
		if i < 3:
			for w in range(-1, 2):
				for dy in range(4, 9):
					var q2: Vector2i = p + side * w
					_put(data, ox, oz, q2.x, fy + 1 + dy, q2.y, Blocks.AIR, false)
	var ch: Vector3i = ms["chamber"]
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			for dy in range(-1, 9):
				var edge := absi(dx) == 8 or absi(dz) == 8 or dy == -1 or dy == 8
				var pillar := absi(dx) == 4 and absi(dz) == 4
				var b := Blocks.COBBLESTONE if edge else (Blocks.LOG if pillar else Blocks.AIR)
				_put(data, ox, oz, ch.x + dx, ch.y + dy, ch.z + dz, b, false)
	# Join the tunnel's end to the chamber.
	var end: Vector2i = Vector2i(e.x, e.z) + dir * ms["length"]
	for i in 10:
		var p: Vector2i = end + dir * i
		for w in range(-1, 2):
			for dy in range(0, 4):
				var q: Vector2i = p + side * w
				_put(data, ox, oz, q.x, ch.y + dy, q.y, Blocks.AIR, false)
	top = maxi(top, e.y + 8)
	return top


func _build_fairy_village(data: PackedInt32Array, ox: int, oz: int, fv: Dictionary) -> int:
	var c: Vector2i = fv["center"]
	if Vector2(c.x - ox - S * 0.5, c.y - oz - S * 0.5).length() > fv["radius"] + 20:
		return 0
	var top := 0
	for spot in fv["houses"]:
		var h := _surface_height_v2(spot.x, spot.y)
		# A tiny mushroom house: a 2-tall stem with a door, and a round red cap.
		for dy in range(1, 3):
			_put(data, ox, oz, spot.x, h + dy, spot.y, Blocks.MUSHROOM_STEM, false)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				_put(data, ox, oz, spot.x + dx, h + 3, spot.y + dz, Blocks.MUSHROOM_CAP, false)
		_put(data, ox, oz, spot.x, h + 4, spot.y, Blocks.MUSHROOM_CAP, false)
		top = maxi(top, h + 5)
	return top


func _in_village(x: int, z: int, villages = null) -> bool:
	if gen_version < 2:
		return false
	for fv in (villages if villages != null else _structures_near(x, z)["villages"]):
		if Vector2(fv["center"]).distance_to(Vector2(x, z)) < fv["radius"]:
			return true
	return false


# --- The Deep (worlds made with gen 12 or later) ----------------------------------
# The bottom of the world: a 3-block Bedstone crust (a bronze pickaxe or better
# breaks it) with the Deep under it: big dark caverns of Deepstone with gems,
# rich ore veins, stalactites, glowing crystals and lava lakes on the floor.
const DEEP_TOP := 11       # gen 12: the highest air in the Deep
const CRUST_TOP := 14      # gen 12: Bedstone from DEEP_TOP + 1 up to here
# Gen 13+: the world goes LOWER_DEPTH blocks further down. Ordinary stone (with
# caves and rich ore) carries on below y = 0, then a thick Bedstone crust
# that only a titanium pickaxe breaks, then the tall caverns of the Deep.
const LOWER_DEPTH := 64
const LOWER_CRUST := Vector2i(-27, -22)   # Bedstone from .x up to .y
const LOWER_DEEP := Vector2i(-62, -28)    # the Deep's open space
const LOWER_LAVA := -57                   # lava lakes fill the hollows up to here
const LOWER_VEINS := [
	# [block, veins per chunk, blocks per vein, lowest y, highest y]  (world y)
	[Blocks.IRON_ORE, 5, 7, -21, -1],
	[Blocks.SILVER_ORE, 3, 6, -21, -1],
	[Blocks.TITANIUM_ORE, 3, 6, -21, -6],
	[Blocks.GOLD_ORE, 2, 5, -21, -8],
	[Blocks.COPPER_ORE, 3, 6, -12, -1],
]
const DEEP_VEINS := [
	[Blocks.RUBY_ORE, 3, 5, 2, 11],
	[Blocks.SAPPHIRE_ORE, 3, 5, 2, 11],
	[Blocks.AMETHYST_ORE, 3, 5, 2, 11],
	[Blocks.DIAMOND_ORE, 1, 4, 2, 7],
	[Blocks.ONYX_ORE, 1, 4, 2, 7],
	[Blocks.IRON_ORE, 3, 9, 2, 11],
	[Blocks.SILVER_ORE, 2, 7, 2, 11],
	[Blocks.GOLD_ORE, 2, 7, 2, 9],
	[Blocks.TITANIUM_ORE, 2, 7, 2, 9],
]


func has_deep() -> bool:
	return gen_version >= 12


# --- The lava caverns (gen 14) -----------------------------------------------------
# Big parts of the Deep run hot: magma rock walls, a sea of lava on the floor,
# lava falling from the ceiling, fire imps, magma slimes and fire drakes. Deep
# in the hottest parts the Fire Giant waits on a stone island in the lava.
const HEAT_LIMIT := 0.3
const FIRE_CELL := 420         # at most one Fire Giant per FIRE_CELL x FIRE_CELL
const FIRE_FLOOR := -55        # his island's floor
const FIRE_R := 13             # its radius
const HOT_LAVA := -54          # the lava sea's surface in the caverns


func is_lava_cavern(x: int, z: int) -> bool:
	return gen_version >= 14 and _heat_noise.get_noise_2d(x, z) > HEAT_LIMIT


## The Fire Giant's lair in one cell, or {}.
func fire_lair_in_cell(c: Vector2i) -> Dictionary:
	if gen_version < 14:
		return {}
	var hs := _hash(c.x * 6151 + 91, c.y * 3571 - 47)
	for t in 20:
		var hh := _hash(hs % 100000 + t * 197, c.x * 3 - c.y + t)
		var x := c.x * FIRE_CELL + 40 + hh % (FIRE_CELL - 80)
		var z := c.y * FIRE_CELL + 40 + (hh >> 9) % (FIRE_CELL - 80)
		if Vector2(x, z).length() < 350.0:
			continue
		if _heat_noise.get_noise_2d(x, z) > HEAT_LIMIT + 0.12:
			return {"boss": "fire_giant", "pos": Vector3i(x, FIRE_FLOOR + 1, z), "ground": FIRE_FLOOR, "id": "fire%d_%d" % [c.x, c.y], "deep": true}
	return {}


## A spot in the lava caverns near `from` (for /goto lava), or y = -1.
func find_lava_cavern(from: Vector2) -> Vector3:
	if gen_version < 14:
		return Vector3(0, -1, 0)
	for r in range(0, 1500, 12):
		for k in maxi(1, r / 6):
			var a := TAU * k / maxf(1.0, r / 6.0)
			var x := floori(from.x + cos(a) * r)
			var z := floori(from.y + sin(a) * r)
			if not is_lava_cavern(x, z):
				continue
			for y in range(HOT_LAVA + 1, deep_top() - 1):
				if not _is_deep_open(x, y - 1, z) and _is_deep_open(x, y, z) and _is_deep_open(x, y + 1, z):
					return Vector3(x + 0.5, y, z + 0.5)
	return Vector3(0, -1, 0)


## The Deep's open space: lowest and highest y.
func deep_bottom() -> int:
	return LOWER_DEEP.x if gen_version >= 13 else 2


func deep_top() -> int:
	return LOWER_DEEP.y if gen_version >= 13 else DEEP_TOP


## A cavern floor in the Deep near `from` (for /goto deep), or y = -1.
func find_deep(from: Vector2) -> Vector3:
	if not has_deep():
		return Vector3(0, -1, 0)
	for r in range(0, 80, 4):
		for k in maxi(1, r * 2):
			var a := TAU * k / maxf(1.0, r * 2.0)
			var x := floori(from.x + cos(a) * r)
			var z := floori(from.y + sin(a) * r)
			if _lava_noise.get_noise_2d(x, z) > 0.28:
				continue
			for y in range(deep_bottom(), deep_top() - 1):
				if gen_version >= 13 and y <= LOWER_LAVA:
					continue   # (not in a lava hollow)
				if not _is_deep_open(x, y - 1, z) and _is_deep_open(x, y, z) and _is_deep_open(x, y + 1, z):
					return Vector3(x + 0.5, y, z + 0.5)
	return Vector3(0, -1, 0)


## Is this spot one of the Deep's open caverns?
func _is_deep_open(x: int, y: int, z: int) -> bool:
	if gen_version >= 13:
		if y < LOWER_DEEP.x or y > LOWER_DEEP.y:
			return false
		# Tall caverns: widest in the middle, closing in toward the floor and the crust.
		var mid := (LOWER_DEEP.x + LOWER_DEEP.y) * 0.5
		var half := (LOWER_DEEP.y - LOWER_DEEP.x) * 0.5
		var k := (y - mid) / half
		return _deep_noise.get_noise_3d(x, y * 1.2, z) + 0.24 - k * k * 0.42 > 0.0
	if y < 2 or y > DEEP_TOP:
		return false
	# Roomiest in the middle, closing up toward the floor and the crust.
	return _deep_noise.get_noise_3d(x, y * 1.7, z) + 0.16 - absf(y - 6.5) * 0.04 > 0.0


func _is_cave(x: int, y: int, z: int) -> bool:
	# Squash vertically so tunnels run mostly sideways.
	if absf(_cave_a.get_noise_3d(x, y * 1.6, z)) > 0.085:
		return false  # cheap early-out: most blocks fail this first test
	return absf(_cave_b.get_noise_3d(x, y * 1.6, z)) < 0.085


func _generate(key: Vector2i) -> Dictionary:
	var data := PackedInt32Array()
	data.resize(L * H)  # all zeros = air
	var ox := key.x * S
	var oz := key.y * S
	var top := SEA_LEVEL
	# Work out the trees first (each TREE_CELL x TREE_CELL cell may hold one;
	# cells slightly outside the chunk let leaves spill in), then remember which
	# columns have a trunk nearby so caves don't undermine them.
	var structures := _structures_near(ox, oz)
	var trees: Array = []
	var tree_cols := {}
	var cx0 := floori(float(ox - 4) / TREE_CELL)
	var cx1 := floori(float(ox + S + 3) / TREE_CELL)
	var cz0 := floori(float(oz - 4) / TREE_CELL)
	var cz1 := floori(float(oz + S + 3) / TREE_CELL)
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var tree := _tree_in_cell(cx, cz, structures["villages"])
			if tree.is_empty():
				continue
			trees.append(tree)
			var tp: Vector3i = tree["pos"]
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					tree_cols[Vector2i(tp.x + dx, tp.z + dz)] = true
	var col_h := PackedInt32Array()
	col_h.resize(L)
	var col_biome: Array[String] = []
	col_biome.resize(L)
	for z in S:
		for x in S:
			var wx := ox + x
			var wz := oz + z
			var h: int
			var biome: String
			if gen_version >= 2:
				var colinfo := _column_v2(wx, wz)
				h = colinfo[0]
				biome = colinfo[1]
			else:
				h = surface_height(wx, wz)
				biome = biome_at(wx, wz)
			col_h[x + z * S] = h
			col_biome[x + z * S] = biome
			top = maxi(top, h)
			var beach := h <= SEA_LEVEL + 1
			var rocky := h > SEA_LEVEL + 36 and biome == "plains"
			var snowy := biome == "mountain"
			# [top block, the 3 blocks under it, deeper layer above stone]
			var top_b := Blocks.GRASS
			var under_b := Blocks.DIRT
			var deep_b := Blocks.STONE
			if biome == "desert":
				top_b = Blocks.SAND
				under_b = Blocks.SAND
				deep_b = Blocks.SANDSTONE
			elif biome == "fall":
				top_b = Blocks.FALL_GRASS
			elif biome == "spooky":
				top_b = Blocks.DEAD_GRASS
			elif biome == "fastfood":
				top_b = Blocks.SESAME_BUN
			elif biome == "chess":
				# Big 5x5 squares of white marble and black onyx.
				top_b = Blocks.BLACK_ONYX if posmod(floori(wx / float(CHESS_SQUARE)) + floori(wz / float(CHESS_SQUARE)), 2) == 1 else Blocks.WHITE_MARBLE
			elif biome == "candy":
				top_b = Blocks.FROSTING
				under_b = Blocks.CAKE
			elif snowy:
				top_b = Blocks.SNOW if h < SEA_LEVEL + 30 else Blocks.SNOWY_STONE
				under_b = Blocks.DIRT if h < SEA_LEVEL + 30 else Blocks.STONE
			if beach and not snowy:
				top_b = Blocks.SAND
				under_b = Blocks.SAND
			elif rocky:
				top_b = Blocks.STONE
				under_b = Blocks.STONE
			var col := x + z * S
			data[col] = Blocks.BEDROCK if gen_version < 13 else Blocks.STONE   # (gen 13: the world carries on below)
			for y in range(1, maxi(h, SEA_LEVEL) + 1):
				var b: int
				if y < h - 6:
					b = Blocks.STONE
				elif y < h - 3:
					b = deep_b
				elif y < h:
					b = under_b
				elif y == h:
					b = top_b
				else:
					b = Blocks.WATER
				data[col + y * L] = b
			var cave_bottom := 1 if gen_version >= 13 else 3
			if gen_version == 12:
				# The Deep: Deepstone with caverns, under a Bedstone crust.
				cave_bottom = CRUST_TOP + 1
				for y in range(1, mini(CRUST_TOP, h - 1) + 1):
					data[col + y * L] = Blocks.BEDSTONE if y > DEEP_TOP else Blocks.DEEPSTONE
				var lake := _lava_noise.get_noise_2d(wx, wz) > 0.32
				for y in range(2, mini(DEEP_TOP, h - 4) + 1):
					if _is_deep_open(wx, y, wz):
						data[col + y * L] = Blocks.AIR
						if y == 2 and lake:
							data[col + L] = Blocks.LAVA   # a lava lake in the cavern floor
			# Caves. Keep a thick roof under water (no flooding) and under trees
			# (no floating trees); elsewhere tunnels may break the surface.
			var cave_top := h
			if h <= SEA_LEVEL + 4:
				cave_top = h - 5
			elif tree_cols.has(Vector2i(wx, wz)):
				cave_top = h - 2
			for y in range(cave_bottom, cave_top + 1):
				if _is_cave(wx, y, wz):
					data[col + y * L] = Blocks.AIR

	for tree in trees:
		var t: Vector3i = tree["pos"]
		if tree["kind"] == "dead":
			top = maxi(top, _place_dead_tree(data, ox, oz, t, tree["height"], tree["twist"]))
		elif tree["kind"] == "maple":
			top = maxi(top, _place_maple(data, ox, oz, t, tree["height"], tree["golden"]))
		elif tree["kind"] == "palm":
			top = maxi(top, _place_palm(data, ox, oz, t, tree["height"], tree["lean"]))
		elif tree["kind"] == "cactus":
			for ly in range(t.y, t.y + tree["height"]):
				_put(data, ox, oz, t.x, ly, t.z, Blocks.CACTUS, false)
			top = maxi(top, t.y + tree["height"])
		elif tree["kind"] == "pine":
			top = maxi(top, _place_pine(data, ox, oz, t, tree["height"]))
		elif tree["kind"] == "fry_box":
			top = maxi(top, _place_fry_box(data, ox, oz, t, tree["height"]))
		elif tree["kind"] == "chess_piece":
			top = maxi(top, _place_chess_piece(data, ox, oz, t, tree["height"], tree["onyx"]))
		else:
			top = maxi(top, _place_tree(data, ox, oz, t, tree["height"], tree["kind"] == "candy", tree.get("big", false)))
	for ms in structures["shafts"]:
		top = maxi(top, _carve_mine_shaft(data, ox, oz, ms))
	for fv in structures["villages"]:
		top = maxi(top, _build_fairy_village(data, ox, oz, fv))
	if gen_version >= 6:
		top = maxi(top, _place_islands(data, ox, oz))
	var glow := []
	if gen_version >= 8:
		for l in _lairs_touching(ox, oz):
			if not l.get("deep", false):   # (the Fire Giant's island is built with the lower world)
				top = maxi(top, _build_lair(data, ox, oz, l, glow))
	if gen_version >= 11:
		for cp in camps_touching(ox, oz):
			top = maxi(top, _build_camp(data, ox, oz, cp, glow))
	if gen_version >= 7:
		for sh in shrines_touching(ox, oz):
			_build_shrine(data, ox, oz, sh, glow)
		for site in sites_touching(ox, oz):
			top = maxi(top, _build_site(data, ox, oz, site, glow))
	_place_ores(data, key)
	if gen_version == 12:
		glow.append_array(_decorate_deep(data, ox, oz))
	_place_cutie_ore(data, ox, oz, col_h, col_biome)
	var plants := _place_plants(data, ox, oz, col_h, col_biome)
	if not plants.is_empty():
		top = maxi(top, plants[plants.size() - 1] / L)
	for idx in glow:
		plants.append(idx)   # the lights a shrine or dungeon brings (lit like glowing mushrooms)
	if depth > 0:
		# Gen 13+: put the lower world under it (block indexes now count from the very bottom).
		var lower := _generate_lower(key, ox, oz)
		var shift := depth * L
		for i in plants.size():
			plants[i] += shift
		plants.append_array(lower["lights"])
		var full: PackedInt32Array = lower["data"]
		full.append_array(data)
		return {"data": full, "top": mini(top, H - 2) + depth, "plants": plants}
	return {"data": data, "top": mini(top, H - 2), "plants": plants}


## Gen 13+: the depth blocks under y = 0 (index 0 = the bedrock floor). Stone
## with caves and rich ore, a thick Bedstone crust, then the Deep's tall caverns
## with gems, lava lakes, stalactites and glowing crystals.
func _generate_lower(key: Vector2i, ox: int, oz: int) -> Dictionary:
	var data := PackedInt32Array()
	data.resize(L * depth)
	var lights := []
	for z in S:
		for x in S:
			var wx := ox + x
			var wz := oz + z
			var col := x + z * S
			var hot := is_lava_cavern(wx, wz)
			var lake := hot or _lava_noise.get_noise_2d(wx, wz) > 0.2
			var lava_top := HOT_LAVA if hot else LOWER_LAVA
			data[col] = Blocks.BEDROCK
			for y in range(-depth + 1, 0):
				var i := col + (y + depth) * L
				var b := Blocks.STONE
				if y <= LOWER_CRUST.y and y >= LOWER_CRUST.x:
					b = Blocks.BEDSTONE
				elif y < LOWER_CRUST.x:
					b = Blocks.MAGMA_ROCK if hot else Blocks.DEEPSTONE
					if _is_deep_open(wx, y, wz):
						b = Blocks.LAVA if lake and y <= lava_top else Blocks.AIR
						# The lava's surface glows (every other block is plenty; light spreads).
						if b == Blocks.LAVA and (y == lava_top or not _is_deep_open(wx, y + 1, wz)) and (wx + wz) % 2 == 0:
							lights.append(i)
				elif y >= LOWER_CRUST.y + 3 and _is_cave(wx, y, wz):
					b = Blocks.AIR   # the caves above keep going down
				data[i] = b
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(key.x * 29 - 13, key.y * 31 + 57)
	var table := []
	for v in LOWER_VEINS:
		table.append([v[0], v[1], v[2], v[3] + depth, v[4] + depth])
	_veins(data, rng, table)
	var gems := []
	for v in DEEP_VEINS:
		# Same gems as gen 12, spread over the taller Deep (a bit more of them).
		var lo := LOWER_DEEP.x + depth
		var hi := (LOWER_DEEP.x + 12 if v[4] <= 7 else LOWER_DEEP.y) + depth
		gems.append([v[0], v[1] * 2, v[2], lo, hi])
	_veins(data, rng, gems, Blocks.DEEPSTONE)
	# Stalactites, stalagmites and glow crystals.
	for z in S:
		for x in S:
			var col := x + z * S
			for y in range(LOWER_DEEP.x, LOWER_DEEP.y + 1):
				var i := col + (y + depth) * L
				if data[i] != Blocks.AIR:
					continue
				var hs := _hash((ox + x) * 31 + y * 7, (oz + z) * 17 - y * 3) % 1000
				var above: int = data[i + L]
				var below: int = data[i - L]
				if above == Blocks.MAGMA_ROCK:
					above = Blocks.DEEPSTONE   # (hanging from magma rock looks the same)
				if below == Blocks.MAGMA_ROCK:
					below = Blocks.DEEPSTONE
				if above == Blocks.DEEPSTONE and hs < 70:
					data[i] = Blocks.STALACTITE
					for k in range(1, 1 + hs % 4):   # some hang down a few blocks
						if data[i - k * L] != Blocks.AIR:
							break
						data[i - k * L] = Blocks.STALACTITE
				elif below == Blocks.DEEPSTONE and hs >= 880 and hs < 930:
					data[i] = Blocks.STALACTITE   # a stalagmite
					if hs < 895 and data[i + L] == Blocks.AIR:
						data[i + L] = Blocks.STALACTITE
				elif below == Blocks.DEEPSTONE and hs >= 930 and not is_lava_cavern(ox + x, oz + z):
					data[i] = Blocks.GLOW_CRYSTAL
					lights.append(i)
	if gen_version >= 14:
		_lava_falls(data, ox, oz, lights)
		for l in _fire_lairs_touching(ox, oz):
			_build_fire_lair(data, ox, oz, l, lights)
	return {"data": data, "lights": lights}


## Lava pouring down from the lava caverns' ceilings into the lava sea.
func _lava_falls(data: PackedInt32Array, ox: int, oz: int, lights: Array) -> void:
	for z in S:
		for x in S:
			if not is_lava_cavern(ox + x, oz + z) or _hash((ox + x) * 13 + 5, (oz + z) * 29 - 7) % 1000 >= 4:
				continue
			var col := x + z * S
			var y := LOWER_DEEP.y
			while y > HOT_LAVA and data[col + (y + depth) * L] != Blocks.AIR:
				y -= 1   # find the ceiling
			if y <= HOT_LAVA + 3 or data[col + (y + 1 + depth) * L] == Blocks.AIR:
				continue
			data[col + (y + depth) * L] = Blocks.LAVA
			lights.append(col + (y + depth) * L)
			y -= 1
			while y > HOT_LAVA and data[col + (y + depth) * L] == Blocks.AIR:
				data[col + (y + depth) * L] = Blocks.LAVA_FALL
				if y % 4 == 0:
					lights.append(col + (y + depth) * L)   # it lights the walls all the way down
				y -= 1


func _fire_lairs_touching(ox: int, oz: int) -> Array:
	var out := []
	var c0 := Vector2i(floori(float(ox - FIRE_R - 6) / FIRE_CELL), floori(float(oz - FIRE_R - 6) / FIRE_CELL))
	var c1 := Vector2i(floori(float(ox + S + FIRE_R + 6) / FIRE_CELL), floori(float(oz + S + FIRE_R + 6) / FIRE_CELL))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var l := fire_lair_in_cell(Vector2i(cx, cz))
			if l.is_empty():
				continue
			var p: Vector3i = l["pos"]
			var reach := FIRE_R + 6
			if p.x + reach >= ox and p.x - reach < ox + S and p.z + reach >= oz and p.z - reach < oz + S:
				out.append(l)
	return out


## A block in the lower world (world y below 0), from lower generation.
func _lput(data: PackedInt32Array, ox: int, oz: int, x: int, y: int, z: int, b: int) -> void:
	var lx := x - ox
	var lz := z - oz
	if lx < 0 or lx >= S or lz < 0 or lz >= S or y <= -depth or y >= LOWER_CRUST.x:
		return
	data[lx + lz * S + (y + depth) * L] = b


## The Fire Giant's arena: a round island of Cinderstone in the lava sea, with
## a ring of lava, four bridges, burning braziers and a big throne.
func _build_fire_lair(data: PackedInt32Array, ox: int, oz: int, l: Dictionary, lights: Array) -> void:
	var c: Vector3i = l["pos"]
	var f := FIRE_FLOOR
	for dz in range(-FIRE_R - 5, FIRE_R + 6):
		for dx in range(-FIRE_R - 5, FIRE_R + 6):
			var d := Vector2(dx, dz).length()
			var x := c.x + dx
			var z := c.z + dz
			if d > FIRE_R + 5.5:
				continue
			var bridge := (absi(dx) <= 1 or absi(dz) <= 1)
			if d <= FIRE_R + 0.5:
				for y in range(LOWER_DEEP.x - 2, f):
					_lput(data, ox, oz, x, y, z, Blocks.CINDERSTONE)   # the island goes down to the bottom
				_lput(data, ox, oz, x, f, z, Blocks.MAGMA_ROCK if int(d) % 4 == 3 else Blocks.CINDERSTONE)   # glowing rings in the floor
			elif bridge:
				_lput(data, ox, oz, x, f, z, Blocks.CINDERSTONE)
			elif d <= FIRE_R + 3.5:
				_lput(data, ox, oz, x, f, z, Blocks.LAVA)   # the lava moat
				if (dx + dz) % 3 == 0 and x - ox >= 0 and x - ox < S and z - oz >= 0 and z - oz < S:
					lights.append((x - ox) + (z - oz) * S + (f + depth) * L)
			# Clear the air above (a big open arena).
			if d <= FIRE_R + 5.5:
				for y in range(f + 1, f + 16):
					_lput(data, ox, oz, x, y, z, Blocks.AIR)
	# Burning braziers around the edge: magma pillars with lava on top.
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		var px := c.x + roundi(cos(a) * (FIRE_R - 2))
		var pz := c.z + roundi(sin(a) * (FIRE_R - 2))
		for y in range(f + 1, f + 5):
			_lput(data, ox, oz, px, y, pz, Blocks.MAGMA_ROCK)
		_lput(data, ox, oz, px, f + 5, pz, Blocks.LAVA)
		if px - ox >= 0 and px - ox < S and pz - oz >= 0 and pz - oz < S:
			lights.append((px - ox) + (pz - oz) * S + (f + 5 + depth) * L)
	# The throne, at the north side.
	for dx in range(-2, 3):
		for dy in range(1, 4):
			_lput(data, ox, oz, c.x + dx, f + dy, c.z - FIRE_R + 3, Blocks.CINDERSTONE if dy < 3 or absi(dx) == 2 else Blocks.AIR)
		_lput(data, ox, oz, c.x + dx, f + 1, c.z - FIRE_R + 4, Blocks.MAGMA_ROCK)
	_lput(data, ox, oz, c.x - 2, f + 4, c.z - FIRE_R + 3, Blocks.LAVA)
	_lput(data, ox, oz, c.x + 2, f + 4, c.z - FIRE_R + 3, Blocks.LAVA)



# --- Cave shrines and treasure sites (worlds made with gen 7 or later) ---------------
# Shrines: deep in some caves, a little stone room with lamps and a Stone Chest.
# The chest holds a treasure map with an X on it. The X is at one of the
# treasure sites below, a fairy village, the floating castle or the Yeti's mine.
# Sites: a dungeon (stairs down to a guarded room with a chest) or a grotto
# (a sloping cave whose walls glitter with ore).

const SHRINE_CELL := 112
const SITE_CELL := 176
const SHRINE_R := 3
const SITE_REACH := 34   # how far a site's stairs and room can reach from its entrance


## The shrine in one grid cell: {"pos": the air spot in the middle of its floor, "id"} or {}.
func shrine_in_cell(c: Vector2i) -> Dictionary:
	if gen_version < 7:
		return {}
	var hs := _hash(c.x * 5011 + 17, c.y * 7919 - 29)
	if hs % 100 >= 80:
		return {}
	for t in 16:
		var hh := _hash(hs % 100000 + t * 131, c.x - c.y * 3 + t)
		var x := c.x * SHRINE_CELL + 12 + hh % (SHRINE_CELL - 24)
		var z := c.y * SHRINE_CELL + 12 + (hh >> 8) % (SHRINE_CELL - 24)
		var col := _column_v2(x, z)
		var h: int = col[0]
		if h <= SEA_LEVEL + 4 or col[1] == "sky":
			continue
		for y in range(8, h - 10):
			if _is_cave(x, y, z) and _is_cave(x, y + 1, z) and _is_cave(x, y + 2, z) and not _is_cave(x, y - 1, z):
				return {"pos": Vector3i(x, y, z), "id": "s%d_%d" % [c.x, c.y]}
	return {}


## The treasure site in one grid cell, or {}.
## {"kind": "dungeon"/"grotto", "entrance": top of the stairs, "dir", "depth", "room": air spot in the middle of the room's floor, "id"}
func site_in_cell(c: Vector2i) -> Dictionary:
	if gen_version < 7:
		return {}
	var hs := _hash(c.x * 3307 - 11, c.y * 4421 + 53)
	if hs % 100 >= 60:
		return {}
	var x := c.x * SITE_CELL + 40 + (hs >> 3) % (SITE_CELL - 80)
	var z := c.y * SITE_CELL + 40 + (hs >> 11) % (SITE_CELL - 80)
	var col := _column_v2(x, z)
	var h: int = col[0]
	if h <= SEA_LEVEL + 3 or h > SEA_LEVEL + 60 or col[1] == "sky" or _in_village(x, z):
		return {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var dir: Vector2i = dirs[(hs >> 19) % 4]
	var kind := "dungeon" if (hs >> 22) % 2 == 0 else "grotto"
	var depth := 14 if kind == "dungeon" else 9
	var room := Vector3i(x + dir.x * (depth + 5), h - depth + 1, z + dir.y * (depth + 5))
	return {"kind": kind, "entrance": Vector3i(x, h + 1, z), "dir": dir, "depth": depth, "room": room, "h": h, "id": "d%d_%d" % [c.x, c.y]}


func shrines_touching(ox: int, oz: int) -> Array:
	var out := []
	for cz in range(floori(float(oz - SHRINE_R - 1) / SHRINE_CELL), floori(float(oz + S + SHRINE_R) / SHRINE_CELL) + 1):
		for cx in range(floori(float(ox - SHRINE_R - 1) / SHRINE_CELL), floori(float(ox + S + SHRINE_R) / SHRINE_CELL) + 1):
			var sh := shrine_in_cell(Vector2i(cx, cz))
			if sh.is_empty():
				continue
			var p: Vector3i = sh["pos"]
			if p.x + SHRINE_R >= ox and p.x - SHRINE_R < ox + S and p.z + SHRINE_R >= oz and p.z - SHRINE_R < oz + S:
				out.append(sh)
	return out


func sites_touching(ox: int, oz: int) -> Array:
	var out := []
	for cz in range(floori(float(oz - SITE_REACH) / SITE_CELL), floori(float(oz + S + SITE_REACH) / SITE_CELL) + 1):
		for cx in range(floori(float(ox - SITE_REACH) / SITE_CELL), floori(float(ox + S + SITE_REACH) / SITE_CELL) + 1):
			var s := site_in_cell(Vector2i(cx, cz))
			if s.is_empty():
				continue
			var e: Vector3i = s["entrance"]
			if e.x + SITE_REACH >= ox and e.x - SITE_REACH < ox + S and e.z + SITE_REACH >= oz and e.z - SITE_REACH < oz + S:
				out.append(s)
	return out


## Treasure sites within `radius` of a spot (by entrance).
func sites_near(pos: Vector3, radius: float) -> Array:
	var out := []
	if gen_version < 7:
		return out
	var n := int(radius / SITE_CELL) + 1
	var base := Vector2i(floori(pos.x / SITE_CELL), floori(pos.z / SITE_CELL))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var s := site_in_cell(base + Vector2i(dx, dz))
			if not s.is_empty() and Vector2(s["room"].x - pos.x, s["room"].z - pos.z).length() <= radius:
				out.append(s)
	return out


## The nearest treasure site of a kind ("" = any), or {}.
func find_site(kind: String, from: Vector2, max_radius := 3000.0) -> Dictionary:
	var best := {}
	var best_d := max_radius
	for s in sites_near(Vector3(from.x, 0, from.y), max_radius):
		if kind != "" and s["kind"] != kind:
			continue
		var d := Vector2(s["entrance"].x, s["entrance"].z).distance_to(from)
		if d < best_d:
			best_d = d
			best = s
	return best


## The nearest cave shrine (the air spot over its floor), y = -1 if none.
func find_shrine(from: Vector2, max_radius := 800.0) -> Vector3:
	if gen_version < 7:
		return Vector3(0, -1, 0)
	var best := Vector3(0, -1, 0)
	var best_d := max_radius
	var n := int(max_radius / SHRINE_CELL) + 1
	var base := Vector2i(floori(from.x / SHRINE_CELL), floori(from.y / SHRINE_CELL))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var sh := shrine_in_cell(base + Vector2i(dx, dz))
			if sh.is_empty():
				continue
			var d := Vector2(sh["pos"].x, sh["pos"].z).distance_to(from)
			if d < best_d:
				best_d = d
				best = Vector3(sh["pos"])
	return best


# --- Boss lairs ------------------------------------------------------------------
# Some regions of each biome hold its boss's lair (like the Yeti's mine and
# Grimskull's castle). Worlds made with gen 8 or later get the buildings; in
# older worlds the boss still turns up at the same spot, just out in the open.

const LAIR_BOSSES := {"plains": "boar_king", "forest": "oakheart", "desert": "king_cougar", "candy": "gummy_giant",
		"fall": "scarecrow_king", "spooky": "lantern_witch", "chess": "chess_royals", "fastfood": "clown"}
const LAIR_REACH := 16      # how far a lair's building spreads from its middle


## The lair in a region ({} = none): {"boss", "pos" (where the boss stands), "ground", "id"}.
func lair_in_region(c: Vector2i) -> Dictionary:
	if gen_version < 2:
		return {}
	var r := _region(c)
	var boss: String = LAIR_BOSSES.get(r["biome"], "")
	if boss == "" or (not boss in ["chess_royals", "clown"] and (r["hash"] >> 23) % 100 >= 45):
		return {}   # (every chessboard kingdom has its castle, and fast food land its circus)
	var center: Vector2 = r["center"]
	if center.length() < 300.0:
		return {}   # never right next to spawn
	# A bit away from the middle (fairy villages sit right in the middle of forests).
	var a: float = ((r["hash"] >> 5) % 360) * PI / 180.0
	var x := int(center.x + cos(a) * 45.0)
	var z := int(center.y + sin(a) * 45.0)
	if biome_at(x, z) != r["biome"]:
		return {}
	var h := _surface_height_v2(x, z)
	if h <= SEA_LEVEL + 1:
		return {}
	var stand := h + 1
	if boss == "lantern_witch" and gen_version >= 8:
		stand = h - 8   # down in the crypt
	return {"boss": boss, "pos": Vector3i(x, stand, z), "ground": h, "id": "lair%d_%d" % [c.x, c.y]}


func lairs_near(pos: Vector3, radius: float) -> Array:
	var out := []
	var n := int(radius / REGION) + 2
	var base := Vector2i(floori(pos.x / REGION), floori(pos.z / REGION))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var l := lair_in_region(base + Vector2i(dx, dz))
			if not l.is_empty() and Vector2(l["pos"].x - pos.x, l["pos"].z - pos.z).length() <= radius:
				out.append(l)
	if gen_version >= 14:
		var fn := int(radius / FIRE_CELL) + 1
		var fb := Vector2i(floori(pos.x / FIRE_CELL), floori(pos.z / FIRE_CELL))
		for dz in range(-fn, fn + 1):
			for dx in range(-fn, fn + 1):
				var fl := fire_lair_in_cell(fb + Vector2i(dx, dz))
				if not fl.is_empty() and Vector2(fl["pos"].x - pos.x, fl["pos"].z - pos.z).length() <= radius:
					out.append(fl)
	return out


## The nearest lair of a boss ("" = any), or {}.
func find_lair(boss: String, from: Vector2, max_radius := 3000.0) -> Dictionary:
	var best := {}
	var best_d := max_radius
	for l in lairs_near(Vector3(from.x, 0, from.y), max_radius):
		if boss != "" and l["boss"] != boss:
			continue
		var d := Vector2(l["pos"].x, l["pos"].z).distance_to(from)
		if d < best_d:
			best_d = d
			best = l
	return best


# --- Villager camps (worlds made with gen 11 or later) ------------------------------
# Most regions have a camp of their biome's folk, a little way from the middle
# (on the other side from any boss lair). Each camp picks one of three
# layouts (a ring of huts round a lamp, a street, or a walled yard) and its
# own number, sizes and heights of houses, all built from the biome's blocks.

const CAMP_REACH := 24       # how far a camp spreads from its middle
const CAMP_CHANCE := 60      # % of regions with a camp
const CAMP_GROUND := {"fall": Blocks.FALL_GRASS, "spooky": Blocks.DEAD_GRASS, "desert": Blocks.SAND, "candy": Blocks.FROSTING,
		"mountain": Blocks.SNOW, "fastfood": Blocks.SESAME_BUN, "chess": Blocks.WHITE_MARBLE}


## The camp in a region ({} = none): {"id", "biome", "center", "ground", "layout", "houses"}.
func camp_in_region(c: Vector2i) -> Dictionary:
	if gen_version < 11:
		return {}
	var r := _region(c)
	var biome: String = r["biome"]
	if not VillagerData.TRIBES.has(biome):
		return {}
	var hsh := absi(_hash(c.x * 7919 + 13, c.y * 104729 + 7))
	if hsh % 100 >= CAMP_CHANCE:
		return {}
	var center: Vector2 = r["center"]
	if center.length() < 160.0:
		return {}   # (spawn has its shrine and QtMaMe)
	var a: float = ((r["hash"] >> 5) % 360) * PI / 180.0 + PI + ((hsh >> 20) % 60 - 30) * PI / 180.0
	var x := int(center.x + cos(a) * 62.0)
	var z := int(center.y + sin(a) * 62.0)
	if biome_at(x, z) != biome:
		return {}
	var g := _surface_height_v2(x, z)
	if g <= SEA_LEVEL + 1 or g > SEA_LEVEL + 40:
		return {}
	var layout: String = ["ring", "street", "walled"][(hsh >> 8) % 3]
	var count := 3 + (hsh >> 12) % 4
	var houses := []
	for i in count:
		var hh := absi(_hash(x + i * 31, z - i * 17))
		var hw := 2 + hh % 2          # half width (5 or 7 wide)
		var hd := 2 + (hh >> 3) % 2
		var tall := 3 + (hh >> 6) % 2
		var at := Vector2i.ZERO
		match layout:
			"ring":
				var ang := TAU * i / count + (hsh % 100) * 0.01
				var rad := 9.0 + count * 1.2
				at = Vector2i(roundi(cos(ang) * rad), roundi(sin(ang) * rad))
			"street":
				var along := (i / 2) * 9 - (count / 2) * 4
				var side := 6 if i % 2 == 0 else -6
				at = Vector2i(along, side) if (hsh >> 16) % 2 == 0 else Vector2i(side, along)
			_:
				var corners := [Vector2i(-9, -9), Vector2i(9, -9), Vector2i(-9, 9), Vector2i(9, 9), Vector2i(0, -10), Vector2i(0, 10)]
				at = corners[i % corners.size()]
		# The door faces the middle of the camp.
		var door := Vector2i(0, -signi(at.y)) if absi(at.y) >= absi(at.x) else Vector2i(-signi(at.x), 0)
		if door == Vector2i.ZERO:
			door = Vector2i(0, 1)
		houses.append({"at": at, "w": hw, "d": hd, "h": tall, "door": door})
	return {"id": "camp%d_%d" % [c.x, c.y], "biome": biome, "center": Vector2i(x, z), "ground": g, "layout": layout, "houses": houses}


func camps_near(pos: Vector3, radius: float) -> Array:
	var out := []
	var n := int(radius / REGION) + 1
	var base := Vector2i(floori(pos.x / REGION), floori(pos.z / REGION))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var cp := camp_in_region(base + Vector2i(dx, dz))
			if not cp.is_empty() and Vector2(cp["center"]).distance_to(Vector2(pos.x, pos.z)) <= radius:
				out.append(cp)
	return out


func find_camp(from: Vector2, max_radius := 3000.0) -> Dictionary:
	var best := {}
	var best_d := max_radius
	for cp in camps_near(Vector3(from.x, 0, from.y), max_radius):
		var d := Vector2(cp["center"]).distance_to(from)
		if d < best_d:
			best_d = d
			best = cp
	return best


func camps_touching(ox: int, oz: int) -> Array:
	var out := []
	var base := Vector2i(floori((ox + S * 0.5) / REGION), floori((oz + S * 0.5) / REGION))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cp := camp_in_region(base + Vector2i(dx, dz))
			if cp.is_empty():
				continue
			var p: Vector2i = cp["center"]
			if p.x + CAMP_REACH >= ox and p.x - CAMP_REACH < ox + S and p.y + CAMP_REACH >= oz and p.y - CAMP_REACH < oz + S:
				out.append(cp)
	return out


func _fence_of(family: String) -> int:
	for i in Blocks.FAMILIES.size():
		if Blocks.FAMILIES[i][0] == family:
			return Blocks.fence_block(i)
	return Blocks.fence_block(0)


## Builds the part of a camp that's inside this chunk.
func _build_camp(data: PackedInt32Array, ox: int, oz: int, cp: Dictionary, glow: Array) -> int:
	var t := VillagerData.tribe(cp["biome"])
	var m: Dictionary = t["mats"]
	var c: Vector2i = cp["center"]
	var g: int = cp["ground"]
	var top := g
	# Level the ground: the camp sits flat at the middle's height.
	for dz in range(-CAMP_REACH, CAMP_REACH + 1):
		for dx in range(-CAMP_REACH, CAMP_REACH + 1):
			var d2 := dx * dx + dz * dz
			if d2 > CAMP_REACH * CAMP_REACH:
				continue
			var x := c.x + dx
			var z := c.y + dz
			if x < ox or x >= ox + S or z < oz or z >= oz + S:
				continue
			var col_h := _surface_height_v2(x, z)
			var edge: float = sqrt(float(d2)) / float(CAMP_REACH)
			var lvl := g if edge < 0.8 else roundi(lerpf(g, col_h, (edge - 0.8) / 0.2))
			var ground_b := _read(data, ox, oz, x, col_h, z)
			if ground_b < 0 or ground_b == Blocks.DIRT or not Blocks.is_solid(ground_b) or Blocks.is_leaves(ground_b) or Blocks.is_log(ground_b):
				ground_b = CAMP_GROUND.get(cp["biome"], Blocks.GRASS)   # (dirt is where a tree stood)
			for y in range(lvl + 1, maxi(lvl + 14, col_h + 12)):
				_put(data, ox, oz, x, y, z, Blocks.AIR, false)
			for y in range(mini(lvl, col_h) - 3, lvl):
				_put(data, ox, oz, x, y, z, Blocks.DIRT, false)
			_put(data, ox, oz, x, lvl, z, ground_b, false)
	# A path or a yard of the camp's floor in the middle, and a lamp post.
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			if absi(dx) + absi(dz) <= 4:
				_put(data, ox, oz, c.x + dx, g, c.y + dz, m["floor"], false)
	for dy in range(1, 4):
		_put(data, ox, oz, c.x, g + dy, c.y, m["trim"], false)
	_put(data, ox, oz, c.x, g + 4, c.y, m["light"], false)
	_glow_at(glow, ox, oz, c.x, g + 4, c.y)
	if cp["layout"] == "walled":
		var fence := _fence_of(m["fence"])
		for i in range(-15, 16):
			for side in [Vector2i(i, -15), Vector2i(i, 15), Vector2i(-15, i), Vector2i(15, i)]:
				var gate: bool = absi(i) <= 1 and (side.y == 15 or side.y == -15)
				if not gate:
					_put(data, ox, oz, c.x + side.x, g + 1, c.y + side.y, fence, false)
		for q in [Vector2i(-15, -15), Vector2i(15, -15), Vector2i(-15, 15), Vector2i(15, 15)]:
			_put(data, ox, oz, c.x + q.x, g + 2, c.y + q.y, m["light"], false)
			_glow_at(glow, ox, oz, c.x + q.x, g + 2, c.y + q.y)
	elif cp["layout"] == "street":
		var along_x: bool = absi(int(cp["houses"][0]["at"].y)) == 6
		for i in range(-16, 17):
			for wdt in range(-1, 2):
				var p := Vector2i(i, wdt) if along_x else Vector2i(wdt, i)
				_put(data, ox, oz, c.x + p.x, g, c.y + p.y, m["floor"], false)
	for hs in cp["houses"]:
		top = maxi(top, _build_house(data, ox, oz, c + hs["at"], g, hs, m, glow))
	return top + 2


func _build_house(data: PackedInt32Array, ox: int, oz: int, at: Vector2i, g: int, hs: Dictionary, m: Dictionary, glow: Array) -> int:
	var hw: int = hs["w"]
	var hd: int = hs["d"]
	var tall: int = hs["h"]
	var door: Vector2i = hs["door"]
	for dz in range(-hd, hd + 1):
		for dx in range(-hw, hw + 1):
			var x := at.x + dx
			var z := at.y + dz
			var wall := absi(dx) == hw or absi(dz) == hd
			var corner := absi(dx) == hw and absi(dz) == hd
			_put(data, ox, oz, x, g, z, m["floor"], false)
			for dy in range(1, tall + 1):
				var b := Blocks.AIR
				if corner:
					b = m["trim"]
				elif wall:
					b = m["wall"]
					var in_door: bool = (door.x != 0 and dx == door.x * hw and dz == 0) or (door.y != 0 and dz == door.y * hd and dx == 0)
					if in_door and dy <= 2:
						b = Blocks.AIR
					elif dy == 2 and ((absi(dx) == hw and absi(dz) == 1) or (absi(dz) == hd and absi(dx) == 1)) and not in_door:
						b = Blocks.GLASS          # little windows
				_put(data, ox, oz, x, g + dy, z, b, false)
	# A peaked roof: each layer a step smaller.
	var layers := mini(hw, hd) + 1
	for k in layers:
		for dz in range(-hd - 1 + k, hd + 2 - k):
			for dx in range(-hw - 1 + k, hw + 2 - k):
				_put(data, ox, oz, at.x + dx, g + tall + 1 + k, at.y + dz, m["roof"], false)
	# A light inside, and one by the door.
	_put(data, ox, oz, at.x, g + tall, at.y, m["light"], false)
	_glow_at(glow, ox, oz, at.x, g + tall, at.y)
	var out_door := at + Vector2i(door.x * (hw + 1), door.y * (hd + 1))
	_put(data, ox, oz, out_door.x + door.y, g + 1, out_door.y + door.x, m["light"], false)
	_glow_at(glow, ox, oz, out_door.x + door.y, g + 1, out_door.y + door.x)
	return g + tall + 1 + layers


## A block inside the chunk being built (-1 = outside it).
func _read(data: PackedInt32Array, ox: int, oz: int, x: int, y: int, z: int) -> int:
	if x < ox or x >= ox + S or z < oz or z >= oz + S or y < 0 or y >= H:
		return -1
	return data[(x - ox) + (z - oz) * S + y * L]


func _lairs_touching(ox: int, oz: int) -> Array:
	var out := []
	for l in lairs_near(Vector3(ox + S * 0.5, 0, oz + S * 0.5), S + LAIR_REACH + REGION):
		var p: Vector3i = l["pos"]
		if p.x + LAIR_REACH >= ox and p.x - LAIR_REACH < ox + S and p.z + LAIR_REACH >= oz and p.z - LAIR_REACH < oz + S:
			out.append(l)
	return out


func _build_lair(data: PackedInt32Array, ox: int, oz: int, l: Dictionary, glow: Array) -> int:
	var p: Vector3i = l["pos"]
	var g: int = l["ground"]
	var hs := _hash(p.x, p.z)
	match l["boss"]:
		"boar_king":
			# A ring of tall standing stones around a trampled dirt clearing.
			for dz in range(-10, 11):
				for dx in range(-10, 11):
					if dx * dx + dz * dz <= 81:
						_put(data, ox, oz, p.x + dx, g, p.z + dz, Blocks.DIRT, false)
						for dy in range(1, 5):
							_put(data, ox, oz, p.x + dx, g + dy, p.z + dz, Blocks.AIR, false)
			for i in 10:
				var a := TAU * i / 10.0
				var sx := p.x + roundi(cos(a) * 9.0)
				var sz := p.z + roundi(sin(a) * 9.0)
				var tall := 3 + _hash(sx, sz) % 3
				for dy in tall:
					_put(data, ox, oz, sx, g + 1 + dy, sz, Blocks.STONE_PILLAR if dy < tall - 1 else Blocks.CHISELED_BRICKS, false)
			return g + 7
		"oakheart":
			# A giant hollow oak: a ring of trunk, a doorway, and a huge leafy top.
			for dz in range(-6, 7):
				for dx in range(-6, 7):
					var r := sqrt(float(dx * dx + dz * dz))
					for dy in range(0, 16):
						var y := g + 1 + dy
						if r < 4.6:
							_put(data, ox, oz, p.x + dx, y, p.z + dz, Blocks.AIR if dy < 14 else Blocks.LOG, false)
						elif r < 6.0:
							var door := dz < -3 and absi(dx) <= 1 and dy < 4
							_put(data, ox, oz, p.x + dx, y, p.z + dz, Blocks.AIR if door else Blocks.LOG, false)
					_put(data, ox, oz, p.x + dx, g, p.z + dz, Blocks.DIRT if r < 6.0 else Blocks.GRASS, false)
			for dz in range(-11, 12):
				for dx in range(-11, 12):
					for dy in range(0, 6):
						var e := Vector3(dx, (dy - 2) * 1.6, dz).length()
						if e < 11.0 and _hash(p.x + dx * 3 + dy, p.z + dz) % 7 != 0:
							_put(data, ox, oz, p.x + dx, g + 15 + dy, p.z + dz, Blocks.LEAVES, true)
			for spot in [Vector2i(2, 2), Vector2i(-2, 3), Vector2i(3, -1)]:
				_put(data, ox, oz, p.x + spot.x, g + 1, p.z + spot.y, Blocks.GLOWSHROOM, false)
				_glow_at(glow, ox, oz, p.x + spot.x, g + 1, p.z + spot.y)
			return g + 22
		"king_cougar":
			# A sandstone temple: a raised floor, carved walls, columns, open to the sky.
			for dz in range(-8, 9):
				for dx in range(-8, 9):
					var edge := maxi(absi(dx), absi(dz))
					_put(data, ox, oz, p.x + dx, g, p.z + dz, Blocks.SANDSTONE, false)
					for dy in range(1, 8):
						var y := g + dy
						var b := Blocks.AIR
						if edge == 8 and dy <= 5:
							var gate := (dz == -8 and absi(dx) <= 1 and dy <= 3)
							b = Blocks.AIR if gate else (Blocks.CARVED_SANDSTONE if dy % 2 == 0 else Blocks.SANDSTONE)
						elif absi(dx) == 4 and absi(dz) == 4 and dy <= 5:
							b = Blocks.SANDSTONE_COLUMN
						elif edge == 8 and dy == 6 and (dx + dz) % 2 == 0:
							b = Blocks.SANDSTONE
						_put(data, ox, oz, p.x + dx, y, p.z + dz, b, false)
			_put(data, ox, oz, p.x, g, p.z, Blocks.GOLD_BLOCK, false)
			return g + 8
		"gummy_giant":
			# A gingerbread fort: cake walls topped with frosting, candy cane towers.
			for dz in range(-8, 9):
				for dx in range(-8, 9):
					var edge := maxi(absi(dx), absi(dz))
					_put(data, ox, oz, p.x + dx, g, p.z + dz, Blocks.FROSTING, false)
					for dy in range(1, 10):
						var b := Blocks.AIR
						var corner := absi(dx) == 8 and absi(dz) == 8
						if corner and dy <= 8:
							b = Blocks.CANDY_CANE
						elif edge == 8 and dy <= 4:
							var gate := dz == -8 and absi(dx) <= 1 and dy <= 3
							b = Blocks.AIR if gate else (Blocks.FROSTING if dy == 4 else Blocks.CAKE)
						_put(data, ox, oz, p.x + dx, g + dy, p.z + dz, b, false)
			return g + 10
		"chess_royals":
			return _build_chess_castle(data, ox, oz, p, g, glow)
		"clown":
			return _build_circus_tent(data, ox, oz, p, g, glow)
		"scarecrow_king":
			# A maze of hay bales in a field, with pumpkins, and an open middle.
			var cells := 8
			for dz in range(-cells, cells + 1):
				for dx in range(-cells, cells + 1):
					_put(data, ox, oz, p.x + dx, g, p.z + dz, Blocks.FALL_GRASS, false)
					var wall := false
					if absi(dx) == cells or absi(dz) == cells:
						wall = not (dz == -cells and absi(dx) <= 0)   # the way in
					elif dx % 2 == 0 and dz % 2 == 0 and maxi(absi(dx), absi(dz)) > 2:
						wall = true
					elif (dx % 2 == 0) != (dz % 2 == 0) and maxi(absi(dx), absi(dz)) > 2:
						wall = _hash(p.x + dx * 7, p.z + dz * 11) % 3 == 0
					for dy in range(1, 4):
						_put(data, ox, oz, p.x + dx, g + dy, p.z + dz, Blocks.HAY_BALE if wall and dy <= 2 else Blocks.AIR, false)
					if not wall and maxi(absi(dx), absi(dz)) <= 2 and (dx + dz + hs) % 5 == 0:
						_put(data, ox, oz, p.x + dx, g + 1, p.z + dz, Blocks.JACK_O_LANTERN, false)
						_glow_at(glow, ox, oz, p.x + dx, g + 1, p.z + dz)
			return g + 4
		"lantern_witch":
			# A crypt: gravestones on top, stairs down, a stone room with ghost lanterns.
			var floor_y: int = p.y - 1
			for dz in range(-6, 7):
				for dx in range(-6, 7):
					for dy in range(-1, 6):
						var edge := absi(dx) == 6 or absi(dz) == 6 or dy == -1 or dy == 5
						var y := floor_y + 1 + dy
						var b := Blocks.STONE_BRICKS if edge else Blocks.AIR
						if edge and _hash(p.x + dx, y + dz) % 4 == 0:
							b = Blocks.COBBLESTONE
						_put(data, ox, oz, p.x + dx, y, p.z + dz, b, false)
			for c in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
				_put(data, ox, oz, p.x + c.x, floor_y + 4, p.z + c.y, Blocks.GHOST_LANTERN, false)
				_glow_at(glow, ox, oz, p.x + c.x, floor_y + 4, p.z + c.y)
			for c in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, 3)]:
				_put(data, ox, oz, p.x + c.x, floor_y + 1, p.z + c.y, Blocks.GRAVESTONE, false)
			# Stairs down from the surface, coming in from the north.
			for i in range(0, g - floor_y + 1):
				var sz := p.z - 6 - (g - floor_y) + i
				var fy := g - i
				for w in [0, 1]:
					_put(data, ox, oz, p.x + w, fy, sz, Blocks.STONE_BRICKS, false)
					for dy in range(1, 4):
						_put(data, ox, oz, p.x + w, fy + dy, sz, Blocks.AIR, false)
			for i in 8:
				var a := TAU * i / 8.0
				_put(data, ox, oz, p.x + roundi(cos(a) * 9.0), g + 1, p.z + roundi(sin(a) * 9.0), Blocks.GRAVESTONE, false)
			return g + 3
	return 0


## Is this the treasure chest at the back of a dungeon?
func is_dungeon_chest(p: Vector3i) -> bool:
	for s in sites_near(Vector3(p), 24.0):
		if s["kind"] == "dungeon" and _dungeon_chest(s) == p:
			return true
	return false


static func _dungeon_chest(s: Dictionary) -> Vector3i:
	var d: Vector2i = s["dir"]
	return s["room"] + Vector3i(d.x * 3, 0, d.y * 3)


func _glow_at(glow: Array, ox: int, oz: int, x: int, y: int, z: int) -> void:
	var lx := x - ox
	var lz := z - oz
	if lx >= 0 and lx < S and lz >= 0 and lz < S and y >= 1 and y < H:
		glow.append(lx + lz * S + y * L)


## A little shrine: a brick floor, four pillars with lamps on top, and a
## Stone Chest on a carved block in the middle.
func _build_shrine(data: PackedInt32Array, ox: int, oz: int, sh: Dictionary, glow: Array) -> void:
	var p: Vector3i = sh["pos"]
	for dz in range(-SHRINE_R, SHRINE_R + 1):
		for dx in range(-SHRINE_R, SHRINE_R + 1):
			var x := p.x + dx
			var z := p.z + dz
			var mid := absi(dx) <= 1 and absi(dz) <= 1
			_put(data, ox, oz, x, p.y - 1, z, Blocks.CHISELED_BRICKS if mid else _ruin_block(x, p.y - 1, z), false)
			for dy in range(0, 5):
				_put(data, ox, oz, x, p.y + dy, z, Blocks.AIR, false)
			if absi(dx) == SHRINE_R and absi(dz) == SHRINE_R:
				for dy in 3:
					_put(data, ox, oz, x, p.y + dy, z, Blocks.STONE_PILLAR, false)
				_put(data, ox, oz, x, p.y + 3, z, Blocks.LAMP, false)
				_glow_at(glow, ox, oz, x, p.y + 3, z)
	_put(data, ox, oz, p.x, p.y, p.z, Blocks.CHISELED_BRICKS, false)
	_put(data, ox, oz, p.x, p.y + 1, p.z, Blocks.SHRINE_CHEST, false)
	_put(data, ox, oz, p.x - SHRINE_R + 1, p.y + 4, p.z + SHRINE_R - 1, Blocks.COBWEB, false)


## A dungeon or a grotto: stairs down from the surface, then the room.
func _build_site(data: PackedInt32Array, ox: int, oz: int, s: Dictionary, glow: Array) -> int:
	var e: Vector3i = s["entrance"]
	var dir: Vector2i = s["dir"]
	var side := Vector2i(-dir.y, dir.x)
	var room: Vector3i = s["room"]
	var h: int = s["h"]
	var dungeon: bool = s["kind"] == "dungeon"
	if dungeon:
		for dz in range(-4, 5):
			for dx in range(-4, 5):
				for dy in range(-1, 5):
					var edge := absi(dx) == 4 or absi(dz) == 4 or dy == -1 or dy == 4
					var x := room.x + dx
					var z := room.z + dz
					var b := Blocks.AIR
					if edge:
						b = Blocks.COBBLESTONE if _hash(x * 3 + dy, z - dy * 7) % 3 == 0 else Blocks.STONE_BRICKS
					_put(data, ox, oz, x, room.y + dy, z, b, false)
		for corner in [Vector2i(-3, -3), Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3)]:
			_put(data, ox, oz, room.x + corner.x, room.y + 3, room.z + corner.y, Blocks.COBWEB, false)
		for corner in [Vector2i(-3, 3), Vector2i(3, -3)]:
			_put(data, ox, oz, room.x + corner.x, room.y, room.z + corner.y, Blocks.GLOWSHROOM, false)
			_glow_at(glow, ox, oz, room.x + corner.x, room.y, room.z + corner.y)
		var ch := _dungeon_chest(s)
		_put(data, ox, oz, ch.x, ch.y, ch.z, Blocks.CHEST, false)
		# Two worn posts mark the way in.
		for w in [-1, 2]:
			var q: Vector2i = Vector2i(e.x, e.z) + side * w
			for dy in 2:
				_put(data, ox, oz, q.x, h + 1 + dy, q.y, Blocks.STONE_PILLAR, false)
	else:
		var d := Vector2(room.x, room.z).length()
		var ores := [Blocks.IRON_ORE, Blocks.COPPER_ORE, Blocks.TIN_ORE, Blocks.SILVER_ORE]
		if d > 1200.0:
			ores = [Blocks.GOLD_ORE, Blocks.TITANIUM_ORE, Blocks.SILVER_ORE, Blocks.IRON_ORE]
		elif d > 500.0:
			ores = [Blocks.IRON_ORE, Blocks.SILVER_ORE, Blocks.GOLD_ORE, Blocks.IRON_ORE]
		if biome_at(room.x, room.z) == "candy":
			ores[3] = Blocks.CUTIE_ORE
		for dz in range(-6, 7):
			for dx in range(-6, 7):
				for dy in range(-2, 6):
					var x := room.x + dx
					var y := room.y + dy
					var z := room.z + dz
					var hv := _hash(x * 5 + y * 77, z * 3 - y * 11)
					var r := Vector3(dx, (dy - 1.5) * 1.4, dz).length() + (hv % 100) / 140.0
					if r < 4.2 and dy >= 0:
						_put(data, ox, oz, x, y, z, Blocks.AIR, false)
					elif r < 5.8 and hv % 5 < 3:
						_put(data, ox, oz, x, y, z, ores[(hv >> 4) % ores.size()], false)
					elif r < 5.8:
						_put(data, ox, oz, x, y, z, Blocks.STONE, false)
		for spot in [Vector2i(2, 1), Vector2i(-2, -1), Vector2i(0, 3)]:
			_put(data, ox, oz, room.x + spot.x, room.y, room.z + spot.y, Blocks.GLOWSHROOM, false)
			_glow_at(glow, ox, oz, room.x + spot.x, room.y, room.z + spot.y)
	# The stairs: down one block each step (with a solid step under you).
	for i in s["depth"] + 2:
		var p: Vector2i = Vector2i(e.x, e.z) + dir * i
		var fy := maxi(h - i, room.y - 1)
		for w in [0, 1]:
			var q: Vector2i = p + side * w
			_put(data, ox, oz, q.x, fy, q.y, Blocks.STONE_BRICKS if dungeon else Blocks.COBBLESTONE, false)
			for dy in range(1, 4):
				_put(data, ox, oz, q.x, fy + dy, q.y, Blocks.AIR, false)
	return h + 3


## Cutie ore: little gem-sprinkled pockets in candy land's cake layer, just
## under the frosting. They come in small clumps, so finding one often finds a few.
func _place_cutie_ore(data: PackedInt32Array, ox: int, oz: int, col_h: PackedInt32Array, col_biome: Array[String]) -> void:
	for z in S:
		for x in S:
			if col_biome[x + z * S] != "candy":
				continue
			var h: int = col_h[x + z * S]
			for y in range(maxi(1, h - 3), h):
				var i := x + z * S + y * L
				if data[i] != Blocks.CAKE:
					continue
				var wx := ox + x
				var wz := oz + z
				if _hash(floori(wx / 3.0) * 7 + 401, floori(wz / 3.0) * 13 + y / 3 * 977) % 30 != 0:
					continue  # not a clump here
				if _hash(wx + 55, wz * 3 + y) % 3 == 0:
					continue  # clumps have a few gaps
				data[i] = Blocks.CUTIE_ORE


# --- Ground plants -------------------------------------------------------------------
# Flowers, grass tufts and other little things on top of the ground, to match
# each biome. Like everything else they come from the seed, so every computer
# grows the same ones. Flowers grow in patches, mostly of one kind.

## Puts plants on the natural ground of a chunk. Returns their cell indexes.
func _place_plants(data: PackedInt32Array, ox: int, oz: int, col_h: PackedInt32Array, col_biome: Array[String]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for z in S:
		for x in S:
			var h: int = col_h[x + z * S]
			if h < 1 or h >= H - 3:
				continue
			var i := x + z * S + h * L
			var ground: int = data[i]
			if data[i + L] != Blocks.AIR:
				continue  # a tree trunk, a cave hole, water, a building...
			var plant := plant_at(ox + x, oz + z, col_biome[x + z * S], ground)
			if plant > 0:
				data[i + L] = plant
				out.append(i + L)
	out.sort()
	return out


## Which plant (if any) grows on this spot of ground. 0 = nothing.
func plant_at(x: int, z: int, biome: String, ground: int) -> int:
	var hsh := _hash(x * 3 + 11, z * 5 - 7)
	var roll := hsh % 1000
	var pick := (hsh >> 10) & 1023
	var patch := _hash(floori(x / 6.0) + 999, floori(z / 6.0) - 333)
	var in_patch := patch % 5 == 0
	match ground:
		Blocks.GRASS:
			if biome == "forest":
				if roll < 100:
					return Blocks.FERN
				if roll < 170:
					return Blocks.TALL_GRASS
				if roll < 182:
					return Blocks.TOADSTOOL
				if roll < (380 if in_patch else 192):
					return Blocks.BLUEBELL
				return 0
			if roll < 140:
				return Blocks.TALL_GRASS
			if roll < (390 if in_patch else 155):
				var flowers := [Blocks.POPPY, Blocks.DANDELION, Blocks.CORNFLOWER, Blocks.DAISY]
				if in_patch and pick % 5 != 0:
					return flowers[(patch >> 4) % flowers.size()]  # most of a patch is one kind
				return flowers[pick % flowers.size()]
		Blocks.DEAD_GRASS:
			# Gravestones, jack-o'-lanterns, glowing mushrooms and cobwebs.
			if roll < 40:
				return Blocks.GLOWSHROOM
			if roll < 70:
				return Blocks.COBWEB
			if roll < 110:
				return Blocks.TALL_GRASS
			if roll < (150 if in_patch else 116):
				return Blocks.GRAVESTONE
			if roll < 124:
				return Blocks.JACK_O_LANTERN
			if roll < 130:
				return Blocks.PUMPKIN
		Blocks.FALL_GRASS:
			# Leaf piles everywhere, pumpkin patches, the odd hay bale and mushroom.
			if roll < 120:
				return Blocks.LEAF_PILE
			if roll < 190:
				return Blocks.GOLD_LEAF_PILE
			if roll < 230:
				return Blocks.TALL_GRASS
			if roll < (300 if in_patch else 238):
				return Blocks.PUMPKIN
			if roll < 246:
				return Blocks.TOADSTOOL
			if roll < 249:
				return Blocks.HAY_BALE
		Blocks.SNOW:
			if roll < 60:
				return Blocks.FROST_GRASS
			if roll < (160 if in_patch else 68):
				return Blocks.EDELWEISS
		Blocks.SAND:
			if biome == "desert":
				if roll < 15:
					return Blocks.DRY_SHRUB
				if roll < 21:
					return Blocks.CACTUS_FLOWER
		Blocks.FROSTING:
			if roll < 25:
				return Blocks.LOLLIPOP
			if roll < (225 if in_patch else 45):
				return Blocks.CANDY_TULIP
	return 0


## After player edits are put on a fresh chunk: wild plants that have nothing
## under them any more (dug out), or sit right next to something a player built,
## go away. (Old builds from before plants existed don't fill up with flowers.)
## Plants the player put down themselves are edits, so they always stay.
func _tidy_plants(key: Vector2i, data: PackedInt32Array, plants: PackedInt32Array) -> void:
	var edits: Dictionary = _changes.get(key, {})
	for idx in plants:
		if edits.has(idx) or not (Blocks.is_plant(data[idx]) or data[idx] in [Blocks.PUMPKIN, Blocks.HAY_BALE, Blocks.JACK_O_LANTERN, Blocks.GRAVESTONE]):
			continue
		if not Blocks.plant_can_sit_on(data[idx - L]) or (not edits.is_empty() and _built_near(edits, idx)):
			data[idx] = Blocks.AIR


## Building clears the wild plants right around it (the same rule as
## _tidy_plants, so a chunk looks the same whether it was just built in or
## loaded later). Runs on every computer, so nothing needs sending.
func _clear_wild_plants_near(p: Vector3i) -> void:
	var touched := {}
	for dy in range(-3, 2):
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var c := p + Vector3i(dx, dy, dz)
				if c.y < 1 - depth or c.y >= H:
					continue
				var key := Vector2i(c.x >> 4, c.z >> 4)
				if (c.x >> 4) != (p.x >> 4) or (c.z >> 4) != (p.z >> 4):
					continue  # the load-time rule only looks inside the same chunk
				var data = _chunk_data.get(key)
				if data == null:
					continue
				var idx := (c.x & 15) + (c.z & 15) * S + (c.y + depth) * L
				if Blocks.is_plant(data[idx]) and not _changes.get(key, {}).has(idx):
					data[idx] = Blocks.AIR
					_chunk_data[key] = data
					touched[key] = true
	for key in touched:
		_chunk_version[key] = _chunk_version.get(key, 0) + 1
		_dirty[key] = true


## Has a player put a solid block within 2 blocks of this cell (same chunk)?
func _built_near(edits: Dictionary, idx: int) -> bool:
	var lx := idx % S
	var lz := (idx / S) % S
	var y := idx / L
	for dy in range(-1, 4):
		var yy := y + dy
		if yy < 0 or yy >= H + depth:
			continue
		for dz in range(-2, 3):
			var zz := lz + dz
			if zz < 0 or zz >= S:
				continue
			for dx in range(-2, 3):
				var xx := lx + dx
				if xx < 0 or xx >= S:
					continue
				var e: int = edits.get(xx + zz * S + yy * L, -1)
				if e > 0 and Blocks.is_solid(e):
					return true
	return false


## Extra copper and tin around spawn (meadows), so bronze gear comes quicker:
## [block, extra veins per chunk, blocks per vein, lowest y, highest y].
## Mostly in the first ~25 blocks under the surface, where caves cut through.
const EARLY_VEINS := [
	[Blocks.COPPER_ORE, 7, 8, 12, 44],
	[Blocks.TIN_ORE, 7, 8, 12, 44],
]
const EARLY_RADIUS := 600.0   # extra ore fades out by this far from spawn


## [block, veins per chunk, blocks per vein, lowest y, highest y]
## Two ores per workbench tier; deeper ores are rarer.
const ORE_VEINS := [
	[Blocks.COPPER_ORE, 6, 6, 4, 60],
	[Blocks.TIN_ORE, 5, 6, 4, 60],
	[Blocks.IRON_ORE, 4, 5, 3, 40],
	[Blocks.SILVER_ORE, 2, 4, 3, 32],
	[Blocks.TITANIUM_ORE, 2, 4, 2, 20],
	[Blocks.GOLD_ORE, 1, 4, 2, 16],
]


func _place_ores(data: PackedInt32Array, key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash(key.x * 7 + 3, key.y * 13 + 5)
	_veins(data, rng, ORE_VEINS)
	# Near spawn: a few more copper and tin veins (their own dice, so the
	# ores that were already there stay put). Fewer the further out you go.
	var dist := Vector2(key.x * S + S * 0.5, key.y * S + S * 0.5).length()
	var near := 1.0 - clampf(dist / EARLY_RADIUS, 0.0, 1.0)
	if near > 0.0:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = _hash(key.x * 11 - 9, key.y * 17 + 21)
		var extra := []
		for ore in EARLY_VEINS:
			extra.append([ore[0], int(round(ore[1] * near)), ore[2], ore[3], ore[4]])
		_veins(data, rng2, extra)
	if gen_version == 12:
		# Gems and big, rich veins in the Deep (their own dice too).
		var rng3 := RandomNumberGenerator.new()
		rng3.seed = _hash(key.x * 19 + 77, key.y * 23 - 41)
		_veins(data, rng3, DEEP_VEINS, Blocks.DEEPSTONE)


## Stalactites hanging from the Deep's ceilings, stalagmites and glowing
## crystals on its floors. Returns everything that glows (crystals and lava).
func _decorate_deep(data: PackedInt32Array, ox: int, oz: int) -> Array:
	var lights := []
	for z in S:
		for x in S:
			var col := x + z * S
			if data[col + L] == Blocks.LAVA:
				lights.append(col + L)
			for y in range(2, DEEP_TOP + 1):
				if data[col + y * L] != Blocks.AIR:
					continue
				var hs := _hash((ox + x) * 31 + y * 7, (oz + z) * 17 - y * 3) % 1000
				var above: int = data[col + (y + 1) * L]
				var below: int = data[col + (y - 1) * L]
				if above == Blocks.DEEPSTONE and hs < 60:
					data[col + y * L] = Blocks.STALACTITE
					if hs < 22 and y > 3 and data[col + (y - 1) * L] == Blocks.AIR:
						data[col + (y - 1) * L] = Blocks.STALACTITE
				elif below == Blocks.DEEPSTONE and hs >= 900 and hs < 940:
					data[col + y * L] = Blocks.STALACTITE   # a stalagmite
				elif below == Blocks.DEEPSTONE and hs >= 940:
					data[col + y * L] = Blocks.GLOW_CRYSTAL
					lights.append(col + y * L)
	return lights


func _veins(data: PackedInt32Array, rng: RandomNumberGenerator, table: Array, only := Blocks.STONE) -> void:
	for ore in table:
		for v in ore[1]:
			var x := rng.randi_range(0, S - 1)
			var y := rng.randi_range(ore[3], ore[4])
			var z := rng.randi_range(0, S - 1)
			for n in ore[2]:  # wander a few steps, replacing only stone
				if x >= 0 and x < S and z >= 0 and z < S and y >= 1 and x + z * S + y * L < data.size():
					var i := x + z * S + y * L
					if data[i] == only:
						data[i] = ore[0]
				match rng.randi() % 6:
					0: x += 1
					1: x -= 1
					2: y += 1
					3: y -= 1
					4: z += 1
					_: z -= 1


## Returns {} or {"pos": Vector3i(base), "height": int} for the tree in a cell.
func _tree_in_cell(cx: int, cz: int, villages = null) -> Dictionary:
	var hsh := _hash(cx, cz)
	var tx := cx * TREE_CELL + 1 + hsh % 4
	var tz := cz * TREE_CELL + 1 + (hsh >> 3) % 4
	var biome := biome_at(tx, tz)
	var forest := clampf(_forest.get_noise_2d(tx, tz), 0.0, 1.0)
	var chance := 0.12 + forest * 1.3
	if gen_version >= 2 and biome == "plains":
		chance = 0.05 + forest * 0.6   # meadows: open grass with scattered trees
	if biome == "desert":
		chance = 0.12  # a few cacti
	elif biome == "candy":
		chance = 0.35
	elif biome == "forest":
		chance = 0.92
	elif biome == "fall":
		chance = 0.55
	elif biome == "spooky":
		chance = 0.32
	elif biome == "sky":
		chance = 0.06
	elif biome == "chess":
		chance = 0.1   # now and then a stone chess piece
	elif biome == "fastfood":
		chance = 0.12  # giant fry boxes
	elif biome == "mountain":
		chance = 0.3
	if _in_village(tx, tz, villages):
		return {}  # keep the fairy village clear
	if float((hsh >> 6) % 1000) / 1000.0 >= chance:
		return {}
	var h := surface_height(tx, tz)
	if h <= SEA_LEVEL + 1 or (h > SEA_LEVEL + 36 and biome == "plains") or (biome == "mountain" and h >= SEA_LEVEL + 30):
		return {}  # no trees on beaches, rocky peaks or snowy summits
	if biome == "desert":
		if gen_version >= 3 and (hsh >> 20) % 4 == 0:
			# Now and then a palm tree (new worlds only, so old deserts don't sprout them).
			return {"pos": Vector3i(tx, h + 1, tz), "height": 6 + (hsh >> 16) % 3, "kind": "palm",
					"lean": Vector2i([1, -1, 0, 0][(hsh >> 12) % 4], [0, 0, 1, -1][(hsh >> 12) % 4])}
		return {"pos": Vector3i(tx, h + 1, tz), "height": 2 + (hsh >> 16) % 3, "kind": "cactus"}
	if biome == "mountain":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 5 + (hsh >> 16) % 4, "kind": "pine"}
	if biome == "forest":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 9 + (hsh >> 16) % 5, "kind": "tree", "big": true}
	if biome == "fall":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 5 + (hsh >> 16) % 3, "kind": "maple", "golden": (hsh >> 22) % 3 == 0}
	if biome == "spooky":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 5 + (hsh >> 16) % 4, "kind": "dead", "twist": (hsh >> 12) % 4}
	if biome == "chess":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 2 + (hsh >> 16) % 3, "kind": "chess_piece", "onyx": (hsh >> 22) % 2 == 0}
	if biome == "fastfood":
		return {"pos": Vector3i(tx, h + 1, tz), "height": 2 + (hsh >> 16) % 2, "kind": "fry_box"}
	return {"pos": Vector3i(tx, h + 1, tz), "height": 4 + (hsh >> 16) % 3,
			"kind": "candy" if biome == "candy" else "tree"}


func _tree_at_column(x: int, z: int) -> bool:
	var tree := _tree_in_cell(floori(float(x) / TREE_CELL), floori(float(z) / TREE_CELL))
	if tree.is_empty():
		return false
	var p: Vector3i = tree["pos"]
	return absi(p.x - x) <= 2 and absi(p.z - z) <= 2


# --- Floating islands --------------------------------------------------------------
# In the "sky" biome (far out), islands float high above a quiet grassy plain.
# Each 48x48 cell may hold one island. Some have ruins, a broken watchtower or a
# tiny abandoned village (with chests to find). A few hang low, with vines you
# can climb all the way up from the ground. Far, far out they get much bigger.

const ISLAND_CELL := 48
const BIG_SKY_RADIUS := 1500.0


## The island in this cell, or {} (pure math, safe on any thread).
func island_in_cell(ci: Vector2i) -> Dictionary:
	var h := _hash(ci.x * 311 + 17, ci.y * 577 + 29)
	var cx := ci.x * ISLAND_CELL + 10 + h % 28
	var cz := ci.y * ISLAND_CELL + 10 + (h >> 5) % 28
	if biome_at(cx, cz) != "sky" or (h >> 10) % 10 >= 7:
		return {}
	var big: bool = Vector2(cx, cz).length() >= BIG_SKY_RADIUS
	if big and (h >> 2) % 17 == 0:
		# A rare huge island with a castle on it (and the two-headed skeleton boss inside).
		var mid := Vector2(ci.x * ISLAND_CELL + ISLAND_CELL / 2.0, ci.y * ISLAND_CELL + ISLAND_CELL / 2.0)
		return {"c": mid, "r": 26, "top": 60, "low": false, "kind": -1, "h": h, "castle": true}
	var r := 7 + (h >> 13) % 8
	if big:
		r += 4 + (h >> 17) % 7
	var low := (h >> 21) % 7 == 0
	var top := (46 + (h >> 24) % 5) if low else (60 + (h >> 24) % 18)
	if top + 12 > H - 3:
		top = H - 15
	return {"c": Vector2(cx + 0.5, cz + 0.5), "r": r, "top": top, "low": low, "kind": (h >> 4) % 6, "h": h}


## The castle island nearest this spot within `radius`, as the courtyard
## middle (y < 0 = none).
func castle_near(pos: Vector3, radius: float) -> Vector3:
	if gen_version < 6:
		return Vector3(0, -1, 0)
	var best := Vector3(0, -1, 0)
	var best_d := radius
	for isl in islands_near(int(pos.x - radius), int(pos.z - radius), int(pos.x + radius), int(pos.z + radius)):
		if isl.get("castle", false):
			var c: Vector2 = isl["c"]
			var d := c.distance_to(Vector2(pos.x, pos.z))
			if d < best_d:
				best_d = d
				best = Vector3(floorf(c.x) + 0.5, isl["top"] + 1, floorf(c.y) + 0.5)
	return best


## Search outward for the nearest castle (for /locate castle).
func find_castle(from: Vector2, max_radius := 5000.0) -> Vector3:
	var step := 400.0
	var r := step
	while r <= max_radius:
		var found := castle_near(Vector3(from.x, 0, from.y), r)
		if found.y >= 0:
			return found
		r += step
	return Vector3(0, -1, 0)


## Islands that reach into this area.
func islands_near(x0: int, z0: int, x1: int, z1: int) -> Array:
	var out := []
	var reach := 26
	for cz in range(floori(float(z0 - reach) / ISLAND_CELL), floori(float(z1 + reach) / ISLAND_CELL) + 1):
		for cx in range(floori(float(x0 - reach) / ISLAND_CELL), floori(float(x1 + reach) / ISLAND_CELL) + 1):
			var isl := island_in_cell(Vector2i(cx, cz))
			if not isl.is_empty():
				out.append(isl)
	return out


## The top and bottom of an island's ground at a column, or [] if it's not there.
static func island_column(isl: Dictionary, x: int, z: int) -> Array:
	var c: Vector2 = isl["c"]
	var p := Vector2(x + 0.5, z + 0.5) - c
	var r: float = isl["r"]
	var wobble := 0.85 + 0.15 * sin(atan2(p.y, p.x) * 3.0 + float(isl["h"] % 97))
	var re := r * wobble
	var d := p.length()
	if d >= re:
		return []
	var t := d / re
	var top: int = isl["top"] + int((1.0 - t) * 1.5)
	var depth := int(lerpf(r * 0.9, 1.0, pow(t, 0.6)))
	return [top, top - maxi(depth, 1)]


## The highest island ground at a column (-1 = no island). For maps.
func island_top(x: int, z: int) -> int:
	if gen_version < 6 or biome_at(x, z) != "sky":
		return -1
	for isl in islands_near(x, z, x, z):
		var col := island_column(isl, x, z)
		if not col.is_empty():
			return col[0]
	return -1


func _place_islands(data: PackedInt32Array, ox: int, oz: int) -> int:
	var top := 0
	for isl in islands_near(ox, oz, ox + S - 1, oz + S - 1):
		var c: Vector2 = isl["c"]
		var hsh: int = isl["h"]
		# The body: grass on top, a little dirt, then stone tapering down to a point.
		for z in S:
			for x in S:
				var col := island_column(isl, ox + x, oz + z)
				if col.is_empty():
					continue
				var t: int = col[0]
				for y in range(col[1], t + 1):
					var b := Blocks.STONE
					if y == t:
						b = Blocks.GRASS
					elif y >= t - 2:
						b = Blocks.DIRT
					_put(data, ox, oz, ox + x, y, oz + z, b, false)
				top = maxi(top, t)
				# Flowers and grass on top.
				var fh := _hash(ox + x + 77, oz + z - 31)
				if fh % 9 == 0:
					_put(data, ox, oz, ox + x, t + 1, oz + z, [Blocks.TALL_GRASS, Blocks.DAISY, Blocks.POPPY, Blocks.CORNFLOWER][fh % 4], true)
		var cx := floori(c.x)
		var cz := floori(c.y)
		var ct: int = isl["top"] + 1
		var r: int = isl["r"]
		# Vines hanging under low islands, nearly to the ground.
		if isl["low"]:
			for k in 6:
				var a := TAU * k / 6.0 + float(hsh % 11)
				var vx := cx + int(cos(a) * r * 0.55)
				var vz := cz + int(sin(a) * r * 0.55)
				var col := island_column(isl, vx, vz)
				if col.is_empty():
					continue
				var ground := surface_height(vx, vz)
				for y in range(ground + 2, col[1]):
					_put(data, ox, oz, vx, y, vz, Blocks.VINE, true)
		# What's built on it.
		if isl.get("castle", false):
			top = maxi(top, _place_castle(data, ox, oz, Vector3i(cx, ct, cz)))
			continue
		match int(isl["kind"]):
			0, 1:
				if r >= 7:
					top = maxi(top, _place_tree(data, ox, oz, Vector3i(cx + 2, ct, cz - 1), 4 + hsh % 2))
			2, 3:
				top = maxi(top, _place_ruin(data, ox, oz, Vector3i(cx, ct, cz), r, hsh, int(isl["kind"]) == 3))
			4:
				if r >= 8:
					top = maxi(top, _place_sky_village(data, ox, oz, Vector3i(cx, ct, cz), r, hsh))
				else:
					top = maxi(top, _place_ruin(data, ox, oz, Vector3i(cx, ct, cz), r, hsh, true))
			5:
				top = maxi(top, _place_watchtower(data, ox, oz, Vector3i(cx, ct, cz), hsh))
	return top


## Is this bit of an old building still there? (Ruins are missing ~30% of their blocks.)
func _standing(x: int, y: int, z: int, decay: int) -> bool:
	return _hash(x * 7 + y * 131, z * 13 - y * 17) % 10 >= decay


func _ruin_block(x: int, y: int, z: int) -> int:
	return Blocks.STONE_BRICKS if _hash(x + y * 3, z - y) % 3 != 0 else Blocks.COBBLESTONE


## A broken ring of stone wall with a couple of pillars (and maybe a chest).
func _place_ruin(data: PackedInt32Array, ox: int, oz: int, at: Vector3i, r: int, hsh: int, chest: bool) -> int:
	var rr := maxi(2, int(r * 0.45))
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var edge := maxi(absi(dx), absi(dz)) == rr
			if not edge:
				continue
			var hgt := 1 + _hash(at.x + dx, at.z + dz + hsh % 13) % 3
			for y in hgt:
				var p := at + Vector3i(dx, y, dz)
				if _standing(p.x, p.y, p.z, 3):
					_put(data, ox, oz, p.x, p.y, p.z, _ruin_block(p.x, p.y, p.z), false)
	for corner in [Vector2i(-rr, -rr), Vector2i(rr, rr)]:
		for y in 4:
			if _standing(at.x + corner.x, at.y + y, at.z + corner.y, 2):
				_put(data, ox, oz, at.x + corner.x, at.y + y, at.z + corner.y, Blocks.STONE_PILLAR, false)
	if chest:
		_put(data, ox, oz, at.x, at.y, at.z, Blocks.CHEST, false)
	return at.y + 5


## A few small, half-fallen stone huts with plank roofs and a path between them.
func _place_sky_village(data: PackedInt32Array, ox: int, oz: int, at: Vector3i, r: int, hsh: int) -> int:
	var spots := [Vector2i(-3, -3), Vector2i(3, 2), Vector2i(-2, 4)]
	var count := 2 + hsh % 2
	for k in count:
		var s: Vector2i = spots[k]
		var hc := Vector3i(at.x + s.x, at.y, at.z + s.y)
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var wall := absi(dx) == 2 or absi(dz) == 2
				var door := dz == 2 and dx == 0
				for y in range(0, 3):
					var p := hc + Vector3i(dx, y, dz)
					if wall and not (door and y < 2) and _standing(p.x, p.y, p.z, 2):
						_put(data, ox, oz, p.x, p.y, p.z, _ruin_block(p.x, p.y, p.z), false)
				var roof := hc + Vector3i(dx, 3, dz)
				if _standing(roof.x, roof.y, roof.z, 4):
					_put(data, ox, oz, roof.x, roof.y, roof.z, Blocks.PLANKS, false)
		if (hsh >> (k + 3)) % 2 == 0:
			_put(data, ox, oz, hc.x, hc.y, hc.z, Blocks.CHEST, false)
		# a cobble path toward the middle
		for i in 4:
			var pp := Vector3i(hc.x - int(sign(s.x)) * i, at.y - 1, hc.z - int(sign(s.y)) * i)
			_put(data, ox, oz, pp.x, pp.y, pp.z, Blocks.COBBLESTONE, false)
	return at.y + 5


## The castle: high stone walls with battlements, a gate, four corner towers
## and a great hall at the back with a throne. Mostly still standing.
func _place_castle(data: PackedInt32Array, ox: int, oz: int, at: Vector3i) -> int:
	var half := 10
	var dark := Blocks.STONE_BRICKS
	for dz in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var floor_p := at + Vector3i(dx, -1, dz)
			_put(data, ox, oz, floor_p.x, floor_p.y, floor_p.z, Blocks.COBBLESTONE if (dx + dz) % 5 != 0 else Blocks.STONE_BRICKS, false)
			for y in range(0, 12):
				_put(data, ox, oz, at.x + dx, at.y + y, at.z + dz, Blocks.AIR, false)   # clear the courtyard
			var wall := absi(dx) == half or absi(dz) == half
			var tower := absi(dx) >= half - 2 and absi(dz) >= half - 2
			var gate := dz == half and absi(dx) <= 1
			if tower:
				var shell := absi(dx) == half or absi(dz) == half or absi(dx) == half - 2 or absi(dz) == half - 2
				for y in 11:
					if shell and _standing(at.x + dx, at.y + y, at.z + dz, 1):
						_put(data, ox, oz, at.x + dx, at.y + y, at.z + dz, dark, false)
				if shell and (dx + dz) % 2 == 0:
					_put(data, ox, oz, at.x + dx, at.y + 11, at.z + dz, dark, false)   # battlements
			elif wall:
				for y in 7:
					if gate and y < 4:
						continue
					if _standing(at.x + dx, at.y + y, at.z + dz, 1):
						_put(data, ox, oz, at.x + dx, at.y + y, at.z + dz, Blocks.CHISELED_BRICKS if y == 3 else dark, false)
				if (dx + dz) % 2 == 0:
					_put(data, ox, oz, at.x + dx, at.y + 7, at.z + dz, dark, false)
	# The great hall at the back, open toward the gate.
	for dz in range(-half + 1, -half + 8):
		for dx in range(-5, 6):
			var side := absi(dx) == 5 or dz == -half + 1
			for y in 6:
				if side and _standing(at.x + dx, at.y + y, at.z + dz, 1):
					_put(data, ox, oz, at.x + dx, at.y + y, at.z + dz, dark, false)
			_put(data, ox, oz, at.x + dx, at.y + 6, at.z + dz, Blocks.STONE_BRICK_SLAB, false)   # roof
	for dx in [-3, 3]:
		for y in 6:
			_put(data, ox, oz, at.x + dx, at.y + y, at.z - half + 6, Blocks.STONE_PILLAR, false)
	_put(data, ox, oz, at.x, at.y, at.z - half + 2, Blocks.GOLD_BLOCK, false)            # the throne
	_put(data, ox, oz, at.x, at.y + 1, at.z - half + 2, Blocks.CHISELED_BRICKS, false)
	return at.y + 13


## A crumbling watchtower: a hollow column of stone with a lookout on top.
func _place_watchtower(data: PackedInt32Array, ox: int, oz: int, at: Vector3i, hsh: int) -> int:
	var hgt := 6 + hsh % 4
	for y in hgt:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				if dz == 1 and dx == 0 and y < 2:
					continue  # doorway
				var p := at + Vector3i(dx, y, dz)
				if _standing(p.x, p.y, p.z, 1 + y / 3):
					_put(data, ox, oz, p.x, p.y, p.z, _ruin_block(p.x, p.y, p.z), false)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var p := at + Vector3i(dx, hgt, dz)
			if _standing(p.x, p.y, p.z, 4):
				_put(data, ox, oz, p.x, p.y, p.z, Blocks.STONE_BRICK_SLAB, false)
	for y in hgt:
		_put(data, ox, oz, at.x, at.y + y, at.z, Blocks.VINE, true)   # climb up the inside
	_put(data, ox, oz, at.x + 1, at.y + hgt + 1, at.z + 1, Blocks.CHEST, false)
	return at.y + hgt + 2


## A dead, twisted tree: a bare trunk with crooked branches, lying logs that
## stick out sideways and bend up at the end, and the odd cobweb.
func _place_dead_tree(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int, twist: int) -> int:
	var top := base.y + height
	for ly in range(base.y, top):
		_put(data, ox, oz, base.x, ly, base.z, Blocks.DEAD_LOG, false)
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	for k in 3:
		var d: Vector2i = dirs[(twist + k) % 4]
		var y := top - 1 - k * 2
		if y <= base.y + 1:
			break
		var lying: int = Blocks.DEAD_LOG_X if d.x != 0 else Blocks.DEAD_LOG_Z
		var reach := 2 + (k + twist) % 2
		for i in range(1, reach + 1):
			_put(data, ox, oz, base.x + d.x * i, y, base.z + d.y * i, lying, true)
		_put(data, ox, oz, base.x + d.x * reach, y + 1, base.z + d.y * reach, Blocks.DEAD_LOG, true)   # bends up
		if (twist + k) % 3 == 0:
			_put(data, ox, oz, base.x + d.x * (reach - 1), y - 1, base.z + d.y * (reach - 1), Blocks.COBWEB, true)
	_put(data, ox, oz, base.x, top, base.z, Blocks.DEAD_LOG_X if twist % 2 == 0 else Blocks.DEAD_LOG_Z, true)
	_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.DIRT, false)
	return top + 2


## A maple: a round, full crown of red (or golden) leaves, like a fall postcard.
func _place_maple(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int, golden: bool) -> int:
	var leaves := Blocks.GOLDEN_LEAVES if golden else Blocks.MAPLE_LEAVES
	var crown := base.y + height
	for ly in range(crown - 3, crown + 2):
		var r := 2.6 - absf(ly - (crown - 1)) * 0.55
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if dx * dx + dz * dz <= r * r and (_hash(base.x + dx * 13 + ly, base.z + dz * 7) % 9 != 0 or absi(dx) + absi(dz) < 2):
					_put(data, ox, oz, base.x + dx, ly, base.z + dz, leaves, true)
	for ly in range(base.y, crown):
		_put(data, ox, oz, base.x, ly, base.z, Blocks.MAPLE_LOG, false)
	_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.DIRT, false)
	return crown + 2


## A palm: a gently bending trunk with a star of drooping fronds on top.
func _place_palm(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int, lean: Vector2i) -> int:
	var p := base
	for ly in height:
		_put(data, ox, oz, p.x, p.y, p.z, Blocks.PALM_LOG, false)
		if ly == height / 2 or ly == height - 2:
			p += Vector3i(lean.x, 0, lean.y)   # the bend
		p.y += 1
	var top := p
	_put(data, ox, oz, top.x, top.y, top.z, Blocks.PALM_LEAVES, true)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var long := 3 if d.x == 0 or d.y == 0 else 2
		for k in range(1, long + 1):
			var droop := 1 if k >= long else 0
			_put(data, ox, oz, top.x + d.x * k, top.y - droop, top.z + d.y * k, Blocks.PALM_LEAVES, true)
	_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.SAND, false)
	return top.y + 2


## A cone of pine needles on a straight trunk, for the mountains.
func _place_pine(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int) -> int:
	var top := base.y + height
	for ly in range(base.y + 2, top + 1):
		var r := clampi(int((top - ly) * 0.45) + (1 if (top - ly) % 2 == 0 else 0), 0, 3)
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) + absi(dz) <= r + (1 if r >= 2 else 0):
					_put(data, ox, oz, base.x + dx, ly, base.z + dz, Blocks.PINE_LEAVES, true)
	_put(data, ox, oz, base.x, top + 1, base.z, Blocks.PINE_LEAVES, true)
	for ly in range(base.y, top):
		_put(data, ox, oz, base.x, ly, base.z, Blocks.PINE_LOG, false)
	_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.DIRT, false)
	return top + 2


func _place_tree(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int, candy := false, big := false) -> int:
	var trunk := Blocks.CANDY_CANE if candy else (Blocks.REDWOOD_LOG if big else Blocks.LOG)
	var leaves := Blocks.COTTON_CANDY if candy else Blocks.LEAVES
	var crown := base.y + height
	if big:
		# Tall forest trees: a big round crown up high.
		for ly in range(crown - 4, crown + 2):
			var r := 3 if ly < crown - 1 and ly > crown - 4 else 2
			for dz in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dz * dz > r * r + 1:
						continue
					_put(data, ox, oz, base.x + dx, ly, base.z + dz, leaves, true)
		for ly in range(base.y, crown):
			_put(data, ox, oz, base.x, ly, base.z, trunk, false)
		_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.DIRT, false)
		return crown + 2
	for ly in range(crown - 2, crown + 2):
		var r := 2 if ly < crown else 1
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if r == 2 and absi(dx) == 2 and absi(dz) == 2 and (_hash(base.x + dx * 31 + ly, base.z + dz * 17) & 1) == 0:
					continue  # randomly trim corners so trees look less boxy
				if ly == crown + 1 and absi(dx) + absi(dz) > 1:
					continue  # plus-shaped top
				_put(data, ox, oz, base.x + dx, ly, base.z + dz, leaves, true)
	for ly in range(base.y, crown):
		_put(data, ox, oz, base.x, ly, base.z, trunk, false)
	_put(data, ox, oz, base.x, base.y - 1, base.z, Blocks.CAKE if candy else Blocks.DIRT, false)
	return crown + 1


const CHESS_SQUARE := 5     # the chessboard kingdom's squares are this many blocks wide


## A giant box of fries: a 3x3 red box with fries sticking up out of it.
func _place_fry_box(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int) -> int:
	var top := base.y
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for dy in height:
				_put(data, ox, oz, base.x + dx, base.y + dy, base.z + dz, Blocks.FRY_BOX, false)
			var tall := 1 + _hash(base.x + dx * 7, base.z + dz * 13) % 3
			for dy in tall:
				_put(data, ox, oz, base.x + dx, base.y + height + dy, base.z + dz, Blocks.FRIES_BLOCK, false)
			top = maxi(top, base.y + height + tall)
	return top


## Chuckles' circus: a round red and white tent with a pointy roof, a door to
## the north, a sawdust ring inside with a gold edge, and lamps.
func _build_circus_tent(data: PackedInt32Array, ox: int, oz: int, p: Vector3i, g: int, glow: Array) -> int:
	const RAD := 12.5
	for dz in range(-14, 15):
		for dx in range(-14, 15):
			var r := sqrt(float(dx * dx + dz * dz))
			if r > RAD + 0.8:
				continue
			var x := p.x + dx
			var z := p.z + dz
			for dy in range(-3, 0):
				_put(data, ox, oz, x, g + dy, z, Blocks.DIRT, false)
			# The floor: a sawdust ring with a gold edge, bun all around.
			var floor_b := Blocks.SESAME_BUN
			if r < 7.5:
				floor_b = Blocks.SAND
			elif r < 8.5:
				floor_b = Blocks.GOLD_BLOCK if (dx + dz) % 2 == 0 else Blocks.CIRCUS_STRIPES
			_put(data, ox, oz, x, g, z, floor_b, false)
			# The tent: straight walls, then a cone roof up to a point.
			var wall_top := 7
			var roof := wall_top + int((RAD - r) * 0.85)
			for dy in range(1, 21):
				var y := g + dy
				var b := Blocks.AIR
				var door := dz < 0 and absi(dx) <= 1 and dy <= 4
				if r >= RAD - 0.7 and dy <= wall_top and not door:
					b = Blocks.CIRCUS_STRIPES
				elif dy > wall_top and dy == roof:
					b = Blocks.CIRCUS_STRIPES
				_put(data, ox, oz, x, y, z, b, false)
	# A flag on top, and lamps on poles around the ring.
	var peak := g + 7 + int(RAD * 0.85)
	for dy in range(1, 4):
		_put(data, ox, oz, p.x, peak + dy, p.z, Blocks.CIRCUS_STRIPES if dy < 3 else Blocks.GOLD_BLOCK, false)
	for i in 6:
		var a := TAU * i / 6.0 + 0.5
		var lx := p.x + roundi(cos(a) * 10.0)
		var lz := p.z + roundi(sin(a) * 10.0)
		for dy in range(1, 4):
			_put(data, ox, oz, lx, g + dy, lz, Blocks.FRY_BOX if dy < 3 else Blocks.LAMP, false)
		_glow_at(glow, ox, oz, lx, g + 3, lz)
	return peak + 4


## A stone chess piece standing on the board: a pawn, rook or bishop shape.
func _place_chess_piece(data: PackedInt32Array, ox: int, oz: int, base: Vector3i, height: int, onyx: bool) -> int:
	var bricks := Blocks.ONYX_BRICKS if onyx else Blocks.MARBLE_BRICKS
	var column := Blocks.ONYX_COLUMN if onyx else Blocks.MARBLE_COLUMN
	var stone := Blocks.BLACK_ONYX if onyx else Blocks.WHITE_MARBLE
	_put(data, ox, oz, base.x, base.y, base.z, bricks, false)
	for dy in range(1, height):
		_put(data, ox, oz, base.x, base.y + dy, base.z, column, false)
	_put(data, ox, oz, base.x, base.y + height, base.z, stone, false)
	if height >= 4:
		_put(data, ox, oz, base.x, base.y + height + 1, base.z, Blocks.MARBLE_SLAB if not onyx else Blocks.ONYX_SLAB, false)
	return base.y + height + 2


## The King and Queen's castle: black and white walls around a giant
## chessboard (each square 2x2), corner towers, columns with lamps and two
## thrones at the back. The gate faces north.
func _build_chess_castle(data: PackedInt32Array, ox: int, oz: int, p: Vector3i, g: int, glow: Array) -> int:
	const W := 12            # the walls
	const T := 14            # the outer edge of the corner towers
	for dz in range(-T, T + 1):
		for dx in range(-T, T + 1):
			var ax := absi(dx)
			var az := absi(dz)
			var edge := maxi(ax, az)
			var tower := ax >= W - 1 and az >= W - 1
			if edge > W and not tower:
				continue
			var x := p.x + dx
			var z := p.z + dz
			for dy in range(-4, 0):
				_put(data, ox, oz, x, g + dy, z, Blocks.STONE, false)   # solid ground under it all
			# The floor: the big board in the middle, polished bricks around it.
			var floor_b := Blocks.MARBLE_BRICKS
			if dx >= -8 and dx < 8 and dz >= -8 and dz < 8:
				floor_b = Blocks.BLACK_ONYX if posmod(((dx + 8) >> 1) + ((dz + 8) >> 1), 2) == 1 else Blocks.WHITE_MARBLE
			elif edge == 9 or edge == 10:
				floor_b = Blocks.ONYX_BRICKS
			_put(data, ox, oz, x, g, z, floor_b, false)
			var checker := posmod((dx + dz) >> 1, 2) == 0
			for dy in range(1, 16):
				var y := g + dy
				var b := Blocks.AIR
				if tower:
					var hollow := ax > W - 1 and ax < T and az > W - 1 and az < T and dy < 11
					if dy <= 11 and not hollow:
						b = Blocks.ONYX_BRICKS if (dy / 2) % 2 == 0 else Blocks.MARBLE_BRICKS
					elif dy == 12 and (ax == T or az == T or ax == W - 1 or az == W - 1) and (dx + dz) % 2 == 0:
						b = Blocks.ONYX_BRICKS   # battlements
					elif dy == 12 and not (ax == T or az == T or ax == W - 1 or az == W - 1):
						b = Blocks.LAMP if ax == W + 1 and az == W + 1 else Blocks.MARBLE_SLAB
				elif edge == W:
					var gate := dz == -W and ax <= 1 and dy <= 4
					if dy <= 7 and not gate:
						b = (Blocks.MARBLE_BRICKS if checker else Blocks.ONYX_BRICKS) if (dy - 1) / 2 % 2 == 0 \
								else (Blocks.ONYX_BRICKS if checker else Blocks.MARBLE_BRICKS)
					elif dy == 8 and (dx + dz) % 2 == 0:
						b = Blocks.MARBLE_BRICKS   # battlements
					elif gate and dy == 4:
						b = Blocks.AIR
				elif ax == 10 and az == 10 and dy <= 6:
					b = (Blocks.MARBLE_COLUMN if (dx > 0) == (dz > 0) else Blocks.ONYX_COLUMN) if dy < 6 else Blocks.LAMP
				_put(data, ox, oz, x, y, z, b, false)
	# The lamps light the courtyard.
	for c in [Vector2i(10, 10), Vector2i(-10, 10), Vector2i(10, -10), Vector2i(-10, -10)]:
		_glow_at(glow, ox, oz, p.x + c.x, g + 6, p.z + c.y)
	for c in [Vector2i(13, 13), Vector2i(-13, 13), Vector2i(13, -13), Vector2i(-13, -13)]:
		_glow_at(glow, ox, oz, p.x + c.x, g + 12, p.z + c.y)
	# Two thrones at the back (south), white and black, on a checker dais.
	for dx in range(-4, 5):
		for dz in range(9, 12):
			_put(data, ox, oz, p.x + dx, g + 1, p.z + dz, Blocks.CHECKER_TILE, false)
	for t in [[-2, Blocks.MARBLE_BRICKS, Blocks.WHITE_MARBLE], [2, Blocks.ONYX_BRICKS, Blocks.BLACK_ONYX]]:
		var tx: int = p.x + t[0]
		_put(data, ox, oz, tx, g + 2, p.z + 10, Blocks.GOLD_BLOCK, false)        # the seat
		for dy in range(2, 5):
			_put(data, ox, oz, tx, g + dy, p.z + 11, t[1], false)               # the tall back
		_put(data, ox, oz, tx, g + 5, p.z + 11, t[2], false)
	return g + 16


func _put(data: PackedInt32Array, ox: int, oz: int, x: int, y: int, z: int, b: int, only_air: bool) -> void:
	if data.is_empty():
		# Growing a tree in the live world (grow_tree): only into open space,
		# never over anything solid that's already there.
		var p := Vector3i(x, y, z)
		var cur := get_block(p)
		if y >= 1 and y < H - 2 and cur != b and Blocks.is_open(cur):
			server_set_block(p, b)
		return
	var lx := x - ox
	var lz := z - oz
	if lx < 0 or lx >= S or lz < 0 or lz >= S or y < 1 or y >= H:
		return
	var i := lx + lz * S + y * L
	if only_air and data[i] != Blocks.AIR:
		return
	data[i] = b


## Deterministic pseudo-random number (always >= 0) from two ints and the seed.
## A sapling grows up: puts the same kind of tree the world makes there
## (server only). Returns false if there's no room for its trunk yet.
func grow_tree(base: Vector3i, sapling: int) -> bool:
	if not multiplayer.is_server() or not Blocks.is_sapling(sapling):
		return false
	var kind: String = Blocks.SAPLINGS[sapling - Blocks.OAK_SAPLING][0]
	var hsh := _hash(base.x * 7 + base.y, base.z * 13)
	var height: int = {"oak": 4 + hsh % 3, "redwood": 9 + hsh % 4, "pine": 5 + hsh % 4, "palm": 6 + hsh % 3,
			"maple": 5 + hsh % 3, "golden": 5 + hsh % 3, "candy": 4 + hsh % 3}[kind]
	for y in range(1, height + 1):
		if not Blocks.is_open(get_block(base + Vector3i(0, y, 0))):
			return false
	server_set_block(base, Blocks.AIR)
	var live := PackedInt32Array()
	match kind:
		"oak":
			_place_tree(live, 0, 0, base, height)
		"redwood":
			_place_tree(live, 0, 0, base, height, false, true)
		"candy":
			_place_tree(live, 0, 0, base, height, true)
		"pine":
			_place_pine(live, 0, 0, base, height)
		"palm":
			var lean := Vector2i([1, -1, 0, 0][(hsh >> 4) % 4], [0, 0, 1, -1][(hsh >> 4) % 4])
			_place_palm(live, 0, 0, base, height, lean)
		"maple", "golden":
			_place_maple(live, 0, 0, base, height, kind == "golden")
	return true


## The world-made tree a leaf at `p` most likely belongs to: {"pos", "big"}
## (empty if it isn't one, like a tree someone grew).
func tree_of_leaf(p: Vector3i) -> Dictionary:
	var cx := floori(p.x / float(TREE_CELL))
	var cz := floori(p.z / float(TREE_CELL))
	var best := {}
	var best_d := 4.6
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var t := _tree_in_cell(cx + dx, cz + dz)
			if t.is_empty() or t["kind"] in ["cactus", "dead"]:
				continue
			var base: Vector3i = t["pos"]
			var d := Vector2(base.x - p.x, base.z - p.z).length()
			if d < best_d and p.y >= base.y and p.y <= base.y + int(t["height"]) + 3:
				best_d = d
				best = {"pos": base, "big": t.get("big", false)}
	return best


func _hash(a: int, b: int) -> int:
	var h := a * 374761393 + b * 668265263 + world_seed * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff


# --- Chunk streaming (runs every frame) ------------------------------------------
# Block data is kept 2 chunks further out than meshes, because meshing a chunk
# (and lighting it) needs all 8 of its neighbors.

func _process(delta: float) -> void:
	if not running:
		return
	if not _water_queue.is_empty() and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_water_timer -= delta
		if _water_timer <= 0.0:
			_water_timer = WATER_TICK
			_tick_water()
	_collect_finished_tasks()
	var has_focus := _focus != null and is_instance_valid(_focus)
	if not has_focus and _extra_keys.is_empty():
		return
	if has_focus:
		var c := chunk_key_at(_focus.global_position)
		if c != _center:
			_center = c
			_unload_far_chunks()
	elif not _offsets.is_empty():
		_offsets.clear()  # dedicated server: nothing to draw, only data around players
	_schedule_work()


func _build_offsets() -> void:
	_offsets.clear()
	var r := render_distance + 2
	for z in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + z * z <= r * r:
				_offsets.append(Vector2i(x, z))
	_offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())


## Server only: keep block data (no meshes) loaded around other players, so
## mobs can walk there and block edits can be checked.
func set_extra_focus(points: Array) -> void:
	_extra_keys.clear()
	for p in points:
		var c := chunk_key_at(p)
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				_extra_keys[c + Vector2i(dx, dz)] = true
	# Drop block data that neither we nor any other player needs any more.
	var has_focus := _focus != null and is_instance_valid(_focus)
	for key in _chunk_data.keys():
		if not _extra_keys.has(key) and not (has_focus and _within(key, render_distance + 3)):
			_chunk_data.erase(key)
			_chunk_top.erase(key)
			_chunk_glow.erase(key)


func _schedule_work() -> void:
	# Edited chunks first, so placing/breaking blocks feels instant.
	for key in _dirty.keys():
		if _tasks.size() >= MAX_URGENT_TASKS:
			break
		if _pending_mesh.has(key):
			continue  # wait for the in-flight (now outdated) job to finish
		if not _chunk_nodes.has(key) or not _neighbors_loaded(key):
			_dirty.erase(key)
			continue
		_dirty.erase(key)
		_start_mesh_task(key)

	var mesh_r2 := render_distance * render_distance
	for off in _offsets:
		if _tasks.size() >= MAX_TASKS:
			return
		var key := _center + off
		if not _chunk_data.has(key):
			if not _pending_data.has(key):
				_start_data_task(key)
		elif off.length_squared() <= mesh_r2 and not _chunk_nodes.has(key) \
				and not _pending_mesh.has(key) and _neighbors_loaded(key):
			_start_mesh_task(key)
	for key in _extra_keys:
		if _tasks.size() >= MAX_TASKS:
			return
		if not _chunk_data.has(key) and not _pending_data.has(key):
			_start_data_task(key)


func _start_data_task(key: Vector2i) -> void:
	var holder := [null]
	var id := WorkerThreadPool.add_task(func() -> void: holder[0] = _generate(key))
	_tasks.append({"id": id, "type": "data", "key": key, "holder": holder})
	_pending_data[key] = true


func _start_mesh_task(key: Vector2i) -> void:
	var holder := [null]
	var chunks := []
	var top_all := 0
	var lamps := []
	for off in NEIGHBORS:
		var k: Vector2i = key + off
		chunks.append(_chunk_data[k])
		top_all = maxi(top_all, _chunk_top[k])
		# Lights come from player edits, plus the few the world makes itself
		# (jack-o'-lanterns, glowing mushrooms), which are remembered per chunk.
		var edits: Dictionary = _changes.get(k, {})
		for idx in edits:
			if Blocks.LIGHT_EMISSION[edits[idx]] > 0:
				lamps.append(Vector3i(idx % S + off.x * S, idx / L, (idx / S) % S + off.y * S))
		var cd: PackedInt32Array = _chunk_data[k]
		for idx in _chunk_glow.get(k, PackedInt32Array()):
			if not edits.has(idx) and Blocks.LIGHT_EMISSION[cd[idx]] > 0:
				lamps.append(Vector3i(idx % S + off.x * S, idx / L, (idx / S) % S + off.y * S))
	var center_top: int = _chunk_top[key]
	# How each stair, slab, chair... in this chunk is turned (they only come from players).
	var turns := {}
	var center_edits: Dictionary = _changes.get(key, {})
	for idx in center_edits:
		if Blocks.SHAPE[center_edits[idx]] != "":
			var lp := Vector3i(idx % S, idx / L, (idx / S) % S)
			turns[lp] = int(_door_facing.get(Vector3i(key.x * S + lp.x, lp.y - depth, key.y * S + lp.z), 0))
	var id := WorkerThreadPool.add_task(func() -> void:
		holder[0] = Mesher.new().build(chunks, top_all, center_top, lamps, turns))
	_tasks.append({"id": id, "type": "mesh", "key": key, "holder": holder,
			"version": _chunk_version.get(key, 0)})
	_pending_mesh[key] = true


func _collect_finished_tasks() -> void:
	var i := 0
	while i < _tasks.size():
		var job: Dictionary = _tasks[i]
		if not WorkerThreadPool.is_task_completed(job["id"]):
			i += 1
			continue
		WorkerThreadPool.wait_for_task_completion(job["id"])
		_tasks.remove_at(i)
		var key: Vector2i = job["key"]
		var result: Dictionary = job["holder"][0]
		if job["type"] == "data":
			_pending_data.erase(key)
			if _within(key, render_distance + 3) or _extra_keys.has(key):
				_store_chunk_data(key, result["data"], result["top"], result.get("plants", PackedInt32Array()))
		else:
			_pending_mesh.erase(key)
			if _within(key, render_distance + 1):
				# Show it even if an edit happened meanwhile (a fresher mesh is queued).
				_apply_mesh(key, result)


func _store_chunk_data(key: Vector2i, data: PackedInt32Array, top: int, plants := PackedInt32Array()) -> void:
	# Re-apply player edits on top of freshly generated terrain.
	var edits: Dictionary = _changes.get(key, {})
	for idx in edits:
		var b: int = edits[idx]
		data[idx] = b
		if b != Blocks.AIR:
			top = maxi(top, idx / L)
	_tidy_plants(key, data, plants)
	var glow := PackedInt32Array()
	for idx in plants:
		if Blocks.LIGHT_EMISSION[data[idx]] > 0:
			glow.append(idx)
	if glow.is_empty():
		_chunk_glow.erase(key)
	else:
		_chunk_glow[key] = glow
	_chunk_data[key] = data
	_chunk_top[key] = top
	_wake_fluids(key, data)


func _apply_mesh(key: Vector2i, result: Dictionary) -> void:
	var body: StaticBody3D = _chunk_nodes.get(key)
	if body == null:
		body = StaticBody3D.new()
		body.position = Vector3(key.x * S, -depth, key.y * S)   # (meshes count from the bottom of the world)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		body.add_child(mi)
		var wi := MeshInstance3D.new()
		wi.name = "Water"
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # the sun shines into water
		wi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		body.add_child(wi)
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		body.add_child(cs)
		add_child(body)
		_chunk_nodes[key] = body

	var mesh: ArrayMesh = null
	if result["solid"] != null:
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result["solid"])
		mesh.surface_set_material(0, _solid_material)
	(body.get_node("Mesh") as MeshInstance3D).mesh = mesh
	var wmesh: ArrayMesh = null
	if result["water"] != null:
		wmesh = ArrayMesh.new()
		wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result["water"])
		wmesh.surface_set_material(0, _water_material)
	(body.get_node("Water") as MeshInstance3D).mesh = wmesh

	var lights: Dictionary = result.get("models", {})
	if not lights.is_empty():
		var world_lights := {}
		for lp in lights:
			world_lights[Vector3i(key.x * S + lp.x, lp.y - depth, key.y * S + lp.z)] = lights[lp]
		models_lit.emit(key, world_lights)

	var faces: PackedVector3Array = result["collision"]
	var cs: CollisionShape3D = body.get_node("Shape")
	if faces.is_empty():
		cs.shape = null
	else:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		cs.shape = shape


func _unload_far_chunks() -> void:
	for key in _chunk_nodes.keys():
		if not _within(key, render_distance + 1):
			_chunk_nodes[key].queue_free()
			_chunk_nodes.erase(key)
	for key in _chunk_data.keys():
		if not _within(key, render_distance + 3) and not _extra_keys.has(key):
			_chunk_data.erase(key)
			_chunk_top.erase(key)
			_chunk_glow.erase(key)


func _within(key: Vector2i, radius: int) -> bool:
	return (key - _center).length_squared() <= radius * radius


func _neighbors_loaded(key: Vector2i) -> bool:
	for off in NEIGHBORS:
		if not _chunk_data.has(key + off):
			return false
	return true


# --- Block access ----------------------------------------------------------------

static func chunk_key_at(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / S), floori(pos.z / S))


## Block at a world position. Unloaded areas read as air.
func get_block(p: Vector3i) -> int:
	if p.y < -depth or p.y >= H:
		return Blocks.AIR
	var data = _chunk_data.get(Vector2i(p.x >> 4, p.z >> 4))  # >> 4 == floor(/16)
	if data == null:
		return Blocks.AIR
	return data[(p.x & 15) + (p.z & 15) * S + (p.y + depth) * L]


## Where a chunk's block index is in the world (indexes count from the very
## bottom, which is `depth` blocks below y = 0 in worlds with the deeper Deep).
func _pos_of(key: Vector2i, idx: int) -> Vector3i:
	return Vector3i(key.x * S + idx % S, idx / L - depth, key.y * S + (idx / S) % S)


## The lowest y in this world (the bedrock floor).
func floor_y() -> int:
	return -depth


## True once the chunk under `pos` has a mesh (and therefore collision).
func is_ready_at(pos: Vector3) -> bool:
	return _chunk_nodes.has(chunk_key_at(pos))


## True if block data (not necessarily a mesh) is loaded at `pos`.
func is_data_loaded(pos: Vector3) -> bool:
	return _chunk_data.has(chunk_key_at(pos))


## Nothing but air/leaves/glass between this block and the sky?
func sees_sky(p: Vector3i) -> bool:
	for y in range(p.y + 1, H):
		if Blocks.LIGHT_ATTENUATION[get_block(Vector3i(p.x, y, p.z))] >= Blocks.MAX_LIGHT:
			return false
	return true


## Rough lamp light at a spot (ignores walls). Used for mob spawning rules.
func lamp_light_at(p: Vector3i) -> int:
	var best := 0
	var c := Vector2i(p.x >> 4, p.z >> 4)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := c + Vector2i(dx, dz)
			var edits: Dictionary = _changes.get(key, {})
			for idx in edits:
				var e: int = Blocks.LIGHT_EMISSION[edits[idx]]
				if e <= 0:
					continue
				var lp := _pos_of(key, idx)
				var d := absi(lp.x - p.x) + absi(lp.y - p.y) + absi(lp.z - p.z)
				best = maxi(best, e - d)
	return best


## The block a player put at this spot, or -1 if nobody changed it.
## (Works even where the chunk isn't loaded. Doors, beds, torches and chests
## only ever come from players, so this finds them anywhere.)
func get_edited_block(p: Vector3i) -> int:
	if p.y < -depth or p.y >= H:
		return -1
	var edits: Dictionary = _changes.get(Vector2i(p.x >> 4, p.z >> 4), {})
	return edits.get((p.x & 15) + (p.z & 15) * S + (p.y + depth) * L, -1)


## Every player-made block of these types: [[pos, block], ...].
func find_edited(types: Array) -> Array:
	var out := []
	for key in _changes:
		var edits: Dictionary = _changes[key]
		for idx in edits:
			if edits[idx] in types:
				out.append([_pos_of(key, idx), edits[idx]])
	return out


## A safe place to stand at (pos.x, pos.z): on top of real ground (not on
## leaves, not in water, not in a cave), with room for a person above.
func safe_ground(pos: Vector3) -> Vector3:
	var x := floori(pos.x)
	var z := floori(pos.z)
	if not is_data_loaded(Vector3(x, 0, z)):
		return Vector3(x + 0.5, surface_height(x, z) + 1.05, z + 0.5)
	for y in range(H - 3, 1, -1):
		var b := get_block(Vector3i(x, y, z))
		if Blocks.is_open(b):
			continue
		if Blocks.is_water(b) or b in [Blocks.LEAVES, Blocks.PINE_LEAVES, Blocks.COTTON_CANDY, Blocks.PALM_LEAVES, Blocks.MAPLE_LEAVES, Blocks.GOLDEN_LEAVES]:
			continue
		if Blocks.is_solid(b) and Blocks.is_open(get_block(Vector3i(x, y + 1, z))) and Blocks.is_open(get_block(Vector3i(x, y + 2, z))):
			return Vector3(x + 0.5, y + 1.05, z + 0.5)
	return Vector3(x + 0.5, surface_height(x, z) + 1.05, z + 0.5)


## Highest solid block in a column, or -1 if the column isn't loaded.
func surface_y(x: int, z: int) -> int:
	var key := Vector2i(x >> 4, z >> 4)
	if not _chunk_data.has(key):
		return -1
	for y in range(mini(_chunk_top[key] - depth + 1, H - 1), -depth, -1):
		if Blocks.is_solid(get_block(Vector3i(x, y, z))):
			return y
	return -depth


## Changes a block on this computer only. Gameplay goes through survival.gd,
## which calls server_set_block.
func set_block_local(p: Vector3i, block: int) -> void:
	if p.y < -depth or p.y >= H:
		return
	var key := Vector2i(p.x >> 4, p.z >> 4)
	var lx := p.x & 15
	var lz := p.z & 15
	var idx := lx + lz * S + (p.y + depth) * L
	var old := get_block(p)
	if not _changes.has(key):
		_changes[key] = {}
	_changes[key][idx] = block
	if not _chunk_data.has(key):
		return  # not loaded here; the edit is applied when it loads
	var data: PackedInt32Array = _chunk_data[key]
	data[idx] = block
	_chunk_data[key] = data  # packed arrays are copied on write, so store it back
	if block != Blocks.AIR and p.y + depth > _chunk_top[key]:
		_chunk_top[key] = p.y + depth
	if Blocks.is_solid(block):
		_clear_wild_plants_near(p)
	# Announce it only now that the new block is in place, so anything that
	# looks at the world (torch/door models) sees the new block, not the old one.
	block_changed.emit(p, old, block)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_queue_water(p)
	# Light can change up to Mesher.P blocks away, which may reach into neighbors.
	var dx_range := [0]
	var dz_range := [0]
	if lx < Mesher.P: dx_range.append(-1)
	if lx >= S - Mesher.P: dx_range.append(1)
	if lz < Mesher.P: dz_range.append(-1)
	if lz >= S - Mesher.P: dz_range.append(1)
	for dz in dz_range:
		for dx in dx_range:
			var k: Vector2i = key + Vector2i(dx, dz)
			_chunk_version[k] = _chunk_version.get(k, 0) + 1
			_dirty[k] = true


## The first water block along a ray, before anything solid (or NO water: y < 0).
func raycast_water(origin: Vector3, direction: Vector3, max_distance: float) -> Vector3i:
	var d := direction.normalized()
	var t := 0.0
	while t <= max_distance:
		var p := origin + d * t
		var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		var b := get_block(c)
		if Blocks.is_fluid(b):
			return c
		if Blocks.is_targetable(b) and not Blocks.is_plant(b):
			break
		t += 0.1
	return Vector3i(0, -1, 0)


## Steps through the block grid along a ray and returns the first solid block hit:
## {"hit": true, "position": Vector3i, "normal": Vector3i, "block": int}
func raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	var dir := direction.normalized()
	var p := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(int(signf(dir.x)), int(signf(dir.y)), int(signf(dir.z)))
	var t_delta := Vector3(
		absf(1.0 / dir.x) if dir.x != 0.0 else INF,
		absf(1.0 / dir.y) if dir.y != 0.0 else INF,
		absf(1.0 / dir.z) if dir.z != 0.0 else INF)
	var t_max := Vector3(
		((p.x + (1 if step.x > 0 else 0)) - origin.x) / dir.x if dir.x != 0.0 else INF,
		((p.y + (1 if step.y > 0 else 0)) - origin.y) / dir.y if dir.y != 0.0 else INF,
		((p.z + (1 if step.z > 0 else 0)) - origin.z) / dir.z if dir.z != 0.0 else INF)
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_distance:
		var b := get_block(p)
		if Blocks.is_targetable(b):
			return {"hit": true, "position": p, "normal": normal, "block": b}
		if t_max.x < t_max.y and t_max.x < t_max.z:
			p.x += step.x
			t = t_max.x
			t_max.x += t_delta.x
			normal = Vector3i(-step.x, 0, 0)
		elif t_max.y < t_max.z:
			p.y += step.y
			t = t_max.y
			t_max.y += t_delta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			p.z += step.z
			t = t_max.z
			t_max.z += t_delta.z
			normal = Vector3i(0, 0, -step.z)
	return {"hit": false}


# --- Fluids (water now; lava and slime later) ------------------------------------
# Minecraft-style rules, run by the server a few times a second:
# - Sources (lakes, the sea, a poured bucket) stay until someone scoops them.
# - A fluid falls straight down into anything open under it (falling blocks).
# - Resting on something, it spreads sideways one level weaker per block, up
#   to its reach (water: 7). Flowing blocks with nothing feeding them dry up.
# - It heads for the nearest drop: if there's a way down within 4 blocks, it
#   only spreads that way (so water runs off ledges instead of pooling).
# - Water between two sources, resting on something, becomes a source too
#   (so digging at a lake's edge just makes the lake bigger).
# Changes go out to everyone in one batch per tick.

const WATER_TICK := 0.25
const LAVA_EVERY := 4          # lava moves once every this many water ticks (once a second)
const WATER_STEPS := 400       # most blocks changed per tick
const DROP_SEARCH := 4         # how far a fluid looks for a way down
const SIDES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]

var _fluid_asleep := {}        # chunk key -> {Vector3i: true}: queued cells that weren't loaded yet
var _drop_cache := {}          # (one tick) cell -> directions it wants to flow


func _queue_water(p: Vector3i) -> void:
	_water_queue[p] = true
	for off in [Vector3i.UP, Vector3i.DOWN, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		_water_queue[p + off] = true


## Can a fluid move into this cell? (Empty, a plant, or a weaker flowing block of the same fluid.)
func _fluid_open(q: Vector3i, kind: String) -> bool:
	var b := get_block(q)
	if Blocks.is_open(b):
		return true
	return Blocks.fluid_kind(b) == kind and Blocks.fluid_level(b) != 0


## Which directions the fluid in cell n wants to spread: toward the nearest
## drop within DROP_SEARCH blocks, or every open way if there's none.
func _flow_dirs(n: Vector3i, kind: String) -> Array:
	if _drop_cache.has(n):
		return _drop_cache[n]
	var best := DROP_SEARCH + 1
	var dist := {}
	for d in SIDES:
		var q: Vector3i = n + d
		if not _fluid_open(q, kind):
			continue
		var found := _drop_distance(q, d, kind)
		dist[d] = found
		best = mini(best, found)
	var out := []
	for d in dist:
		if best > DROP_SEARCH or dist[d] == best:
			out.append(d)
	_drop_cache[n] = out
	return out


## Steps from q (reached going `came`) to the nearest cell with a drop under it
## (DROP_SEARCH + 1 = none in reach). A little breadth-first search.
func _drop_distance(q: Vector3i, came: Vector3i, kind: String) -> int:
	var frontier := [q]
	var seen := {q: true}
	for step in range(1, DROP_SEARCH + 1):
		var next := []
		for c in frontier:
			if _fluid_open(c + Vector3i.DOWN, kind):
				return step
			for d in SIDES:
				var nb: Vector3i = c + d
				if d == -came and c == q:
					continue
				if not seen.has(nb) and _fluid_open(nb, kind):
					seen[nb] = true
					next.append(nb)
		frontier = next
		if frontier.is_empty():
			break
	return DROP_SEARCH + 1


## What a cell should become because of the fluids around it (-1 = leave it).
func _water_target(p: Vector3i) -> int:
	if not is_data_loaded(Vector3(p)) or p.y <= -depth or p.y >= H - 2:
		return -1
	var b := get_block(p)
	var lv := Blocks.fluid_level(b)
	if Blocks.is_lava(b):
		# Water touching lava cools it: still lava turns to Cinderstone, flowing lava to cobblestone.
		for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i.UP]:
			if Blocks.is_water(get_block(p + off)):
				return Blocks.CINDERSTONE if lv == 0 else Blocks.COBBLESTONE
	if lv == 0:
		return -1                     # sources stay until someone scoops them
	if lv < 0 and not Blocks.is_open(b):
		return -1                     # solid blocks aren't touched
	var kind := Blocks.fluid_kind(b)
	var target := Blocks.AIR
	for k in ([kind] if kind != "" else Blocks.FLUIDS.keys()):
		var t := _fluid_target_for(p, k)
		if t != Blocks.AIR:
			target = t
			break
	if Blocks.is_plant(b) and target == Blocks.AIR:
		return -1                     # a plant never turns into "dry air"
	return target


func _fluid_target_for(p: Vector3i, kind: String) -> int:
	var fd: Dictionary = Blocks.FLUIDS[kind]
	var source: int = fd["source"]
	var below := get_block(p + Vector3i.DOWN)
	# Between two sources, resting on something: a new source.
	var sources := 0
	for off in SIDES:
		if get_block(p + off) == source:
			sources += 1
	if sources >= 2 and (Blocks.is_solid(below) or below == source):
		return source
	# Fluid above falls in.
	if Blocks.fluid_kind(get_block(p + Vector3i.UP)) == kind:
		return fd["fall"]
	# Otherwise the strongest neighbour that's spreading this way.
	var best := 99
	for off in SIDES:
		var n: Vector3i = p + off
		var nb := get_block(n)
		if Blocks.fluid_kind(nb) != kind:
			continue
		var nl := Blocks.fluid_level(nb)
		if nl != 0:
			# Flowing and falling water only spreads once it's resting on something solid.
			var under := get_block(n + Vector3i.DOWN)
			if Blocks.is_open(under) or Blocks.is_fluid(under):
				continue
		var strength := 0 if nl == 0 or nl == Blocks.FALLING else nl
		if strength + 1 > int(fd["reach"]):
			continue
		if not (-off in _flow_dirs(n, kind)):
			continue
		best = mini(best, strength + 1)
	if best <= int(fd["reach"]):
		return Blocks.fluid_flow(kind, best)
	return Blocks.AIR


func _tick_water() -> void:
	var cells := _water_queue.keys()
	_water_queue.clear()
	_drop_cache.clear()
	_water_ticks += 1
	var lava_turn := _water_ticks % LAVA_EVERY == 0
	var changes := []
	var seen := {}
	for p in cells:
		if changes.size() >= WATER_STEPS:
			_water_queue[p] = true    # do the rest next time
			continue
		if not is_data_loaded(Vector3(p)):
			var key := Vector2i(p.x >> 4, p.z >> 4)
			if not _fluid_asleep.has(key):
				_fluid_asleep[key] = {}
			_fluid_asleep[key][p] = true   # picked up again when that chunk loads
			continue
		var target := _water_target(p)
		if target < 0 or target == get_block(p) or seen.has(p):
			continue
		if not lava_turn and (Blocks.is_lava(target) or Blocks.is_lava(get_block(p))) and target != Blocks.CINDERSTONE and target != Blocks.COBBLESTONE:
			_water_queue[p] = true    # lava is slow: it only moves every LAVA_EVERY ticks
			continue
		seen[p] = true
		changes.append([p, target, -1])
	if not changes.is_empty():
		server_set_blocks(changes)    # (each change queues its neighbours again)


## Server: a chunk just loaded. Wake up any fluid waiting there, and give
## flowing water that was saved mid-flow a nudge so it carries on.
func _wake_fluids(key: Vector2i, data: PackedInt32Array) -> void:
	if not (multiplayer.has_multiplayer_peer() and multiplayer.is_server()):
		return
	for p in _fluid_asleep.get(key, {}):
		_water_queue[p] = true
	_fluid_asleep.erase(key)
	for idx in _changes.get(key, {}):
		var lv := Blocks.fluid_level(data[idx])
		if lv > 0:
			_water_queue[_pos_of(key, idx)] = true


## Which way flowing water pushes you at p (zero in still water).
func fluid_push(p: Vector3) -> Vector3:
	var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
	var b := get_block(c)
	if not Blocks.is_fluid(b) or Blocks.fluid_level(b) == 0:
		return Vector3.ZERO
	var h := Blocks.fluid_height(b)
	var push := Vector3.ZERO
	for off in SIDES:
		var nb := get_block(c + off)
		if Blocks.fluid_kind(nb) == Blocks.fluid_kind(b):
			push += Vector3(off) * (h - Blocks.fluid_height(nb))
		elif Blocks.is_open(nb):
			push += Vector3(off) * h * 0.5
	if Blocks.fluid_level(b) == Blocks.FALLING:
		push.y -= 1.0
	return push.normalized() if push.length() > 0.01 else Vector3.ZERO


# --- Networking ------------------------------------------------------------------

## Server only: change a block for everyone. Game rules (tools, inventory)
## are checked in survival.gd before this is called.
func get_door_facing() -> Dictionary:
	return _door_facing


## Which way the door at this bottom block runs (null if it was never set).
func door_facing(bottom: Vector3i):
	return _door_facing.get(bottom)


## Lots of blocks at once (one message to everyone instead of thousands).
## cells: [[Vector3i, block, facing], ...].
func server_set_blocks(cells: Array) -> void:
	if not multiplayer.is_server():
		return
	var batch := PackedInt32Array()
	for c in cells:
		var p: Vector3i = c[0]
		if p.y <= -depth or p.y >= H - 2 or int(c[1]) < 0 or int(c[1]) >= Blocks.COUNT:
			continue
		batch.append_array([p.x, p.y, p.z, int(c[1]), int(c[2]) if c.size() > 2 else -1])
		if batch.size() >= 5 * 4000:
			apply_set_blocks.rpc(batch)
			batch = PackedInt32Array()
	if not batch.is_empty():
		apply_set_blocks.rpc(batch)


@rpc("authority", "call_local", "reliable")
func apply_set_blocks(batch: PackedInt32Array) -> void:
	for i in range(0, batch.size(), 5):
		apply_set_block(Vector3i(batch[i], batch[i + 1], batch[i + 2]), batch[i + 3], batch[i + 4])


func server_set_block(p: Vector3i, block: int, facing := -1) -> bool:
	if not multiplayer.is_server():
		return false
	if block < 0 or block >= Blocks.COUNT:
		return false
	if p.y <= -depth or p.y >= H - 2:
		return false  # the very bottom is the unbreakable bedrock floor; keep headroom at the top
	apply_set_block.rpc(p, block, facing)
	return true


@rpc("authority", "call_local", "reliable")
func apply_set_block(p: Vector3i, block: int, facing := -1) -> void:
	if facing >= 0:
		# Doors: true = runs along X. Shaped blocks (stairs, slabs...): how they're turned (0-7).
		_door_facing[p] = (facing == 1) if Blocks.is_door(block) else facing
	elif not Blocks.is_door(block):
		_door_facing.erase(p)
	set_block_local(p, block)
