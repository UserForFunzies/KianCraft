extends Node3D
## The KianCraft logo, built out of real game blocks, as if someone made it
## in the world. There are a few styles (a meadow, a castle, candy land, the
## woods, a frosty peak, a spooky night, a portal shrine) and a new one is
## picked at random each time the game starts.
##
## build(theme) makes it; play_intro() drops every block into place one after
## another; finish() skips straight to the end.

const Blocks = preload("res://scripts/blocks.gd")
const Mesher = preload("res://scripts/chunk_mesher.gd")

const WORD := "KIANCRAFT"
const SPLIT := 4                 # "KIAN" | "CRAFT" get different blocks
const GLYPHS := {
	"K": ["X...X", "X..X.", "X.X..", "XX...", "X.X..", "X..X.", "X...X"],
	"I": ["XXX", ".X.", ".X.", ".X.", ".X.", ".X.", "XXX"],
	"A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"N": ["X...X", "XX..X", "X.X.X", "X.X.X", "X..XX", "X...X", "X...X"],
	"C": [".XXXX", "X....", "X....", "X....", "X....", "X....", ".XXXX"],
	"R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
	"F": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "X...."],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
}
const ROWS := 7

## Each style: blocks for the two halves of the word, the ground, the sky,
## and a few extras on top. A "block" is [top, side, bottom, front] tiles.
const THEMES := ["meadow", "castle", "candy", "woods", "frost", "spooky", "portal"]

var theme := ""
var width := 0
var sky_top := Color(0.38, 0.6, 0.92)
var sky_bottom := Color(0.75, 0.86, 0.98)
var _pieces: Array = []          # [{"node", "rest": Vector3, "delay"}]
var _t := -1.0                   # intro clock (-1 = not playing)
var _mat: StandardMaterial3D
var _seed := 0


static func random_theme() -> String:
	return THEMES[randi() % THEMES.size()]


var with_ground := true          # false when a real world is shown behind the logo


func build(theme_name := "") -> void:
	for c in get_children():
		c.queue_free()
	_pieces.clear()
	theme = theme_name if theme_name in THEMES else random_theme()
	_seed = hash(theme)
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = Blocks.get_atlas()
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.vertex_color_use_as_albedo = true
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_set_sky()
	# Letters, left to right, 1 block apart.
	var x := 0
	var letter := 0
	var columns := []        # [x, letter index] for every column with a block
	for ch in WORD:
		var g: Array = GLYPHS[ch]
		var w: int = g[0].length()
		for row in ROWS:
			for col in w:
				if g[row][col] != "X":
					continue
				var y := ROWS - 1 - row
				var top_open: bool = row == 0 or g[row - 1][col] != "X"
				var tiles := _letter_tiles(letter >= SPLIT, x + col, y, top_open)
				_add_block(Vector3(x + col, y, 0), tiles, Vector3(1, 1, 2), (x + col) * 0.035 + randf() * 0.12)
				if top_open:
					columns.append([x + col, y + 1, letter])
		x += w + 1
		if letter == SPLIT - 1:
			x += 1   # a little more room between KIAN and CRAFT
		letter += 1
	width = x - 1
	_decorate(columns)
	# The ground they stand on.
	var ground := _ground_tiles()
	for gx in (range(-10, width + 10) if with_ground else []):
		for gz in range(-2, 4):
			_add_block(Vector3(gx, -1, gz - 0.5), ground, Vector3.ONE, -1.0)


## Sets the sky colors for this style (the menu uses them for its background).
func _set_sky() -> void:
	match theme:
		"castle":
			sky_top = Color(0.22, 0.2, 0.42)
			sky_bottom = Color(0.85, 0.55, 0.45)
		"candy":
			sky_top = Color(0.95, 0.6, 0.82)
			sky_bottom = Color(1.0, 0.88, 0.94)
		"woods":
			sky_top = Color(0.45, 0.62, 0.85)
			sky_bottom = Color(0.98, 0.85, 0.62)
		"frost":
			sky_top = Color(0.42, 0.58, 0.82)
			sky_bottom = Color(0.88, 0.94, 1.0)
		"spooky":
			sky_top = Color(0.06, 0.05, 0.14)
			sky_bottom = Color(0.35, 0.18, 0.4)
		"portal":
			sky_top = Color(0.1, 0.06, 0.22)
			sky_bottom = Color(0.55, 0.3, 0.75)
		_:
			sky_top = Color(0.36, 0.6, 0.94)
			sky_bottom = Color(0.78, 0.9, 1.0)


func _pick(options: Array, x: int, y: int) -> int:
	return options[absi(hash(Vector3i(x, y, _seed))) % options.size()]


## [top, side, bottom, front] tiles for one letter block.
func _letter_tiles(second: bool, x: int, y: int, top_open: bool) -> Array:
	match theme:
		"castle":
			if second:
				var t := _pick([Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS, Blocks.T_CHISELED, Blocks.T_GOLD_INLAY], x, y)
				return [Blocks.T_PILLAR_TOP if top_open else t, t, t, t]
			return [Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_BLOCK, _pick([Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_INLAY], x, y)]
		"candy":
			if second:
				return [Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE, Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE]
			if top_open:
				return [Blocks.T_FROSTING_TOP, Blocks.T_FROSTING_SIDE, Blocks.T_CAKE, Blocks.T_FROSTING_SIDE]
			return [Blocks.T_COTTON_CANDY, Blocks.T_COTTON_CANDY, Blocks.T_COTTON_CANDY, _pick([Blocks.T_COTTON_CANDY, Blocks.T_CAKE], x, y)]
		"woods":
			if second:
				var p := _pick([Blocks.T_PLANKS, Blocks.T_REDWOOD_PLANKS, Blocks.T_MAPLE_PLANKS, Blocks.T_PINE_PLANKS], x / 6, 0)
				return [p, p, p, p]
			return [Blocks.T_LOG_TOP, Blocks.T_LOG_SIDE, Blocks.T_LOG_TOP, Blocks.T_LOG_SIDE]
		"frost":
			if second:
				var m := _pick([Blocks.T_SILVER_BLOCK, Blocks.T_TITANIUM_BLOCK], x / 6, 1)
				return [Blocks.T_SNOW if top_open else m, m, m, m]
			if top_open:
				return [Blocks.T_SNOW, Blocks.T_SNOWY_STONE_SIDE, Blocks.T_STONE, Blocks.T_SNOWY_STONE_SIDE]
			return [Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE, _pick([Blocks.T_STONE, Blocks.T_STONE, Blocks.T_TITANIUM_ORE], x, y)]
		"spooky":
			if second:
				return [Blocks.T_PUMPKIN_TOP, Blocks.T_PUMPKIN_SIDE, Blocks.T_PUMPKIN_TOP, _pick([Blocks.T_JACK_FACE, Blocks.T_PUMPKIN_SIDE, Blocks.T_PUMPKIN_SIDE], x, y)]
			if top_open:
				return [Blocks.T_DEAD_GRASS_TOP, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE]
			return [Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE]
		"portal":
			if second:
				return [Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_BLOCK, _pick([Blocks.T_GOLD_BLOCK, Blocks.T_GOLD_INLAY], x, y)]
			return [Blocks.T_PORTALSTONE, Blocks.T_PORTALSTONE, Blocks.T_PORTALSTONE, _pick([Blocks.T_PORTALSTONE, Blocks.T_PORTAL_LIT], x, y)]
		_:
			if second:
				var s := _pick([Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE, Blocks.T_IRON_ORE, Blocks.T_GOLD_ORE, Blocks.T_COPPER_ORE, Blocks.T_CUTIE_ORE], x, y)
				return [Blocks.T_STONE if not top_open else Blocks.T_GRASS_TOP, Blocks.T_GRASS_SIDE if top_open else s, Blocks.T_STONE, Blocks.T_GRASS_SIDE if top_open else s]
			if top_open:
				return [Blocks.T_GRASS_TOP, Blocks.T_GRASS_SIDE, Blocks.T_DIRT, Blocks.T_GRASS_SIDE]
			return [Blocks.T_DIRT, Blocks.T_DIRT, Blocks.T_DIRT, Blocks.T_DIRT]


func _ground_tiles() -> Array:
	match theme:
		"candy":
			return [Blocks.T_FROSTING_TOP, Blocks.T_FROSTING_SIDE, Blocks.T_CAKE, Blocks.T_FROSTING_SIDE]
		"frost":
			return [Blocks.T_SNOW, Blocks.T_SNOW_SIDE, Blocks.T_DIRT, Blocks.T_SNOW_SIDE]
		"spooky":
			return [Blocks.T_DEAD_GRASS_TOP, Blocks.T_DEAD_GRASS_SIDE, Blocks.T_DIRT, Blocks.T_DEAD_GRASS_SIDE]
		"castle":
			return [Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS]
		"portal":
			return [Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE]
		"woods":
			return [Blocks.T_FALL_GRASS_TOP, Blocks.T_FALL_GRASS_SIDE, Blocks.T_DIRT, Blocks.T_FALL_GRASS_SIDE]
	return [Blocks.T_GRASS_TOP, Blocks.T_GRASS_SIDE, Blocks.T_DIRT, Blocks.T_GRASS_SIDE]


## A few things on top of the letters and around them, like a real build.
func _decorate(columns: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	match theme:
		"meadow", "woods":
			var leaf := Blocks.T_LEAVES if theme == "meadow" else Blocks.T_MAPLE_LEAVES
			_tree(Vector3(-4, 0, 0.5), leaf, 4)
			_tree(Vector3(width + 3, 0, 0.5), leaf if theme == "meadow" else Blocks.T_GOLDEN_LEAVES, 5)
			for c in columns:
				if theme == "woods" and rng.randf() < 0.3:
					_add_block(Vector3(c[0], c[1], 0.25), [leaf, leaf, leaf, leaf], Vector3(1, 1, 1.5), c[0] * 0.035 + 0.6)
		"castle":
			for c in columns:
				if c[2] >= SPLIT and int(c[0]) % 2 == 0:
					_add_block(Vector3(c[0], c[1], 0.5), [Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS, Blocks.T_STONE_BRICKS], Vector3(1, 1, 1), c[0] * 0.035 + 0.6)
			for lx in [-2, width + 1]:
				for y in 5:
					_add_block(Vector3(lx, y, 0.5), [Blocks.T_PILLAR_TOP, Blocks.T_PILLAR_SIDE, Blocks.T_PILLAR_TOP, Blocks.T_PILLAR_SIDE], Vector3.ONE, 0.2 + y * 0.05)
				_add_block(Vector3(lx, 5, 0.5), [Blocks.T_LAMP, Blocks.T_LAMP, Blocks.T_LAMP, Blocks.T_LAMP], Vector3.ONE, 0.6)
		"candy":
			for lx in [-3, width + 2]:
				for y in 6:
					_add_block(Vector3(lx, y, 0.5), [Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE, Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE], Vector3.ONE, 0.2 + y * 0.05)
				_add_block(Vector3(lx - 1, 5, 0.5), [Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE, Blocks.T_CANDY_CANE_TOP, Blocks.T_CANDY_CANE], Vector3.ONE, 0.6)
		"frost":
			for c in columns:
				if rng.randf() < 0.25:
					_add_block(Vector3(c[0], c[1], 0.5), [Blocks.T_SNOW, Blocks.T_SNOW, Blocks.T_SNOW, Blocks.T_SNOW], Vector3(1, 0.4, 1), c[0] * 0.035 + 0.6)
			_pine(Vector3(-4, 0, 0.5))
			_pine(Vector3(width + 3, 0, 0.5))
		"spooky":
			for lx in [-3, width + 2]:
				_add_block(Vector3(lx, 0, 0.5), [Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE, Blocks.T_GRAVESTONE], Vector3(1, 1.2, 0.4), 0.3)
				_add_block(Vector3(lx, 2.6, 0.5), [Blocks.T_GHOST_LANTERN, Blocks.T_GHOST_LANTERN, Blocks.T_GHOST_LANTERN, Blocks.T_GHOST_LANTERN], Vector3(0.7, 0.7, 0.7), 0.7)
		"portal":
			# A little portal frame on each side, glowing.
			for lx in [-5, width + 2]:
				for y in 5:
					for dx in 4:
						var edge: bool = y == 0 or y == 4 or dx == 0 or dx == 3
						var t := Blocks.T_PORTALSTONE if edge else Blocks.T_PORTAL_LIT
						_add_block(Vector3(lx + dx, y, 0.5), [t, t, t, t], Vector3(1, 1, 0.5 if not edge else 1.0), 0.2 + y * 0.06)


func _tree(base: Vector3, leaf: int, h: int) -> void:
	for y in h:
		_add_block(base + Vector3(0, y, 0), [Blocks.T_LOG_TOP, Blocks.T_LOG_SIDE, Blocks.T_LOG_TOP, Blocks.T_LOG_SIDE], Vector3.ONE, 0.1 + y * 0.05)
	for dy in range(h - 1, h + 2):
		var r := 2 if dy < h + 1 else 1
		for dx in range(-r, r + 1):
			for dz in range(-1, 2):
				if absi(dx) == r and dz != 0:
					continue
				_add_block(base + Vector3(dx, dy, dz), [leaf, leaf, leaf, leaf], Vector3.ONE, 0.4 + dy * 0.03)


func _pine(base: Vector3) -> void:
	for y in 6:
		_add_block(base + Vector3(0, y, 0), [Blocks.T_PINE_TOP, Blocks.T_PINE_SIDE, Blocks.T_PINE_TOP, Blocks.T_PINE_SIDE], Vector3.ONE, 0.1 + y * 0.05)
	for k in 3:
		var r := 2 - k
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				_add_block(base + Vector3(dx, 2 + k * 2, dz), [Blocks.T_PINE_LEAVES, Blocks.T_PINE_LEAVES, Blocks.T_PINE_LEAVES, Blocks.T_PINE_LEAVES], Vector3.ONE, 0.4 + k * 0.08)


## One block (or a stretched block) with its own faces. delay < 0 = always there.
func _add_block(pos: Vector3, tiles: Array, size: Vector3, delay: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cube(size, tiles)
	mi.material_override = _mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if delay >= 0.0:
		_pieces.append({"node": mi, "rest": pos, "delay": delay})


func _cube(size: Vector3, tiles: Array) -> ArrayMesh:
	# Face order: +X, -X, +Y, -Y, +Z (front, toward the camera), -Z.
	var face_tiles := [tiles[1], tiles[1], tiles[0], tiles[2], tiles[3], tiles[1]]
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uw := 1.0 / Blocks.TILE_COUNT
	var off := Vector3(0, 0, -size.z * 0.5)
	for f in 6:
		var shade: float = [0.82, 0.82, 1.0, 0.55, 0.95, 0.6][f]
		var base := verts.size()
		for k in 4:
			var corner: Vector3 = Mesher.FACE_CORNERS[f][k]
			var cuv: Vector2 = Mesher.FACE_UVS[f][k]
			verts.append(off + corner * size)
			uvs.append(Vector2(face_tiles[f] * uw + lerpf(0.01, 0.99, cuv.x) * uw, lerpf(0.01, 0.99, cuv.y)))
			cols.append(Color(shade, shade, shade))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The middle of the letters (for pointing a camera at).
func center() -> Vector3:
	return Vector3(width * 0.5, ROWS * 0.5, 0)


# --- The intro: blocks fall into place ---------------------------------------------

const DROP := 14.0
const FALL_TIME := 0.55
const INTRO_LENGTH := 2.6


func play_intro() -> void:
	_t = 0.0
	for p in _pieces:
		p["node"].position = p["rest"] + Vector3(0, DROP, 0)
		p["node"].visible = false


func finish() -> void:
	_t = -1.0
	for p in _pieces:
		p["node"].position = p["rest"]
		p["node"].visible = true


func is_playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var done := true
	for p in _pieces:
		var k: float = (_t - p["delay"]) / FALL_TIME
		var n: Node3D = p["node"]
		if k <= 0.0:
			done = false
			continue
		n.visible = true
		if k >= 1.0:
			n.position = p["rest"]
			continue
		done = false
		# Fall, then a small bounce as it lands.
		var drop := (1.0 - k) * (1.0 - k) * DROP if k < 0.8 else absf(sin((k - 0.8) / 0.2 * PI)) * 0.25
		n.position = p["rest"] + Vector3(0, drop, 0)
	if done:
		_t = -1.0
