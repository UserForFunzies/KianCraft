extends RefCounted
## Turns one chunk's block data into a lit render mesh plus collision triangles.
##
## How it works:
## 1. Copy this chunk plus an 8-block border from its 8 neighbors into one
##    "padded" array, so lighting can flow in from next door.
## 2. Sunlight: shine straight down each column until something blocks it,
##    then spread sideways/down into shadows (losing 1 level per block).
## 3. Lamp light: spread out from every lamp the same way.
## 4. Emit only the faces that touch a see-through block. Each corner gets
##    "smooth lighting" (average of the 4 nearby cells) and ambient occlusion
##    (darker where blocks meet), stored in the vertex color:
##    r = sunlight, g = lamp light, b = face shade * occlusion.
##    The shader (shaders/voxel.gdshader) turns that into the final brightness,
##    using the time of day for sunlight.
##
## This runs on background threads: it only reads the arrays it's given.

const Blocks = preload("res://scripts/blocks.gd")

const S := Blocks.CHUNK_SIZE
const H := Blocks.CHUNK_HEIGHT
const L := S * S            # blocks per layer in normal chunk data
const P := 8                # border taken from neighbors (light spreads this far)
const PW := S + 2 * P       # padded width
const PL := PW * PW         # blocks per layer in the padded array
const OPAQUE := 15

# Face order: +X, -X, +Y (top), -Y (bottom), +Z, -Z.
# Corners are listed clockwise as seen from outside (Godot's front-face winding).
const FACE_DIRS := [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]
const FACE_NORMALS := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0),
	Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
]
const FACE_CORNERS := [
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
]
const FACE_UVS := [
	[Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)],
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	[Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	[Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	[Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)],
]
## Fixed brightness per face direction (top brightest, bottom darkest).
## (Held items use it; the world itself is lit by the real sun now.)
const FACE_SHADE := [0.8, 0.8, 1.0, 0.55, 0.65, 0.65]
## How much leaves and plants sway in the wind (stored in vertex alpha).
const SWAY_NONE := 1.0
const SWAY_LEAVES := 0.7
const SWAY_PLANT := 0.3
static var SWAYS := {6: true, 45: true, 80: true, 150: true, 151: true, 178: true}
## Brightness for 0..3 solid blocks touching a corner.
const AO_CURVE := [1.0, 0.75, 0.6, 0.45]
const UV_EPS := 0.01

var _pb := PackedInt32Array()   # padded blocks (ints, so there can be more than 256 kinds)
var _sky := PackedByteArray()   # padded sunlight levels
var _blk := PackedByteArray()   # padded lamp light levels
var _ymax := 0                  # layers stored in the padded arrays
var _face_off := PackedInt32Array()
var _corner_off: Array = []     # [face][corner] -> [tangent1, tangent2] index offsets

var _s_verts := PackedVector3Array()
var _s_norms := PackedVector3Array()
var _s_uvs := PackedVector2Array()
var _s_cols := PackedColorArray()
var _s_idx := PackedInt32Array()
var _w_verts := PackedVector3Array()
var _w_norms := PackedVector3Array()
var _w_uvs := PackedVector2Array()
var _w_cols := PackedColorArray()
var _w_idx := PackedInt32Array()
var _collision := PackedVector3Array()
var _model_light := {}          # local Vector3i -> Vector2(sky, lamp) for doors/torches/beds


## chunks: 9 PackedInt32Arrays, index (dz + 1) * 3 + (dx + 1), center = 4.
## top_all: highest non-air y in any of the 9. center_top: same for the center.
## lamps: lamp positions relative to the center chunk's corner (may be outside it).
var _turns := {}                 # local Vector3i -> how a shaped block is turned


func build(chunks: Array, top_all: int, center_top: int, lamps: Array, turns := {}) -> Dictionary:
	_turns = turns
	_ymax = mini((chunks[4] as PackedInt32Array).size() / L, top_all + 2)   # (taller in worlds with the deeper Deep)
	_init_offsets()
	_copy_padded(chunks)
	_light_sky()
	_light_lamps(lamps)
	_mesh(mini(center_top + 1, _ymax - 1))
	return _result()


func _init_offsets() -> void:
	for f in 6:
		var d: Vector3i = FACE_DIRS[f]
		_face_off.append(d.x + d.z * PW + d.y * PL)
		var per_corner := []
		for k in 4:
			var c: Vector3 = FACE_CORNERS[f][k]
			var t := []
			if d.x == 0:
				t.append(1 if c.x > 0.5 else -1)
			if d.y == 0:
				t.append(PL if c.y > 0.5 else -PL)
			if d.z == 0:
				t.append(PW if c.z > 0.5 else -PW)
			per_corner.append(t)
		_corner_off.append(per_corner)


func _copy_padded(chunks: Array) -> void:
	# Rows along X are contiguous in both layouts, so copy them as slices.
	for y in _ymax:
		var yo := y * L
		for pz in PW:
			var lz := pz - P
			var cz := -1 if lz < 0 else (1 if lz >= S else 0)
			var row := (cz + 1) * 3
			var base := (lz - cz * S) * S + yo
			var left: PackedInt32Array = chunks[row]
			var center: PackedInt32Array = chunks[row + 1]
			var right: PackedInt32Array = chunks[row + 2]
			_pb.append_array(left.slice(base + S - P, base + S))
			_pb.append_array(center.slice(base, base + S))
			_pb.append_array(right.slice(base, base + P))
	_sky.resize(_pb.size())
	_blk.resize(_pb.size())


func _light_sky() -> void:
	var atten: Array = Blocks.LIGHT_ATTENUATION
	var stop := PackedInt32Array()
	stop.resize(PL)
	var seeds := PackedInt32Array()
	# 1. Straight down each column.
	for col in PL:
		var y := _ymax - 1
		var i := col + y * PL
		while y >= 0 and _pb[i] == Blocks.AIR:
			_sky[i] = 15
			y -= 1
			i -= PL
		stop[col] = y  # first non-air block from the top
		var light := 15
		while y >= 0:
			var a: int = atten[_pb[i]]
			if a >= OPAQUE:
				break
			light -= a
			if light <= 0:
				break
			_sky[i] = light
			seeds.append(i)  # under leaves / in water: spreads from here too
			y -= 1
			i -= PL
	# 2. Open-sky cells beside a shadowed column start the sideways spread.
	for z in PW:
		for x in PW:
			var col := x + z * PW
			var my_stop := stop[col]
			var highest := my_stop
			if x > 0: highest = maxi(highest, stop[col - 1])
			if x < PW - 1: highest = maxi(highest, stop[col + 1])
			if z > 0: highest = maxi(highest, stop[col - PW])
			if z < PW - 1: highest = maxi(highest, stop[col + PW])
			for y in range(my_stop + 1, highest + 1):
				seeds.append(col + y * PL)
	_flood(_sky, seeds)


func _light_lamps(lamps: Array) -> void:
	var seeds := PackedInt32Array()
	for lp in lamps:
		var p: Vector3i = lp
		var x := p.x + P
		var z := p.z + P
		if x < 0 or x >= PW or z < 0 or z >= PW or p.y < 0 or p.y >= _ymax:
			continue
		var i := x + z * PW + p.y * PL
		var e: int = Blocks.LIGHT_EMISSION[_pb[i]]
		if e > _blk[i]:
			_blk[i] = e
			seeds.append(i)
	if not seeds.is_empty():
		_flood(_blk, seeds)


## Breadth-first light spread: each step into a see-through block loses 1+ levels.
func _flood(light: PackedByteArray, queue: PackedInt32Array) -> void:
	var atten: Array = Blocks.LIGHT_ATTENUATION
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var l: int = light[i]
		if l <= 1:
			continue
		var x := i % PW
		var z := (i / PW) % PW
		var y := i / PL
		for d in 6:
			var n: int
			if d == 0:
				if x == PW - 1: continue
				n = i + 1
			elif d == 1:
				if x == 0: continue
				n = i - 1
			elif d == 2:
				if z == PW - 1: continue
				n = i + PW
			elif d == 3:
				if z == 0: continue
				n = i - PW
			elif d == 4:
				if y == _ymax - 1: continue
				n = i + PL
			else:
				if y == 0: continue
				n = i - PL
			var a: int = atten[_pb[n]]
			if a >= OPAQUE:
				continue
			var nl := l - 1 - a
			if nl > light[n]:
				light[n] = nl
				queue.append(n)


func _mesh(y_end: int) -> void:
	var transparent: Array = Blocks.TRANSPARENT
	var models: Array = Blocks.MODEL
	var lava: Array = Blocks.IS_LAVA
	for y in range(1, y_end + 1):
		for z in range(P, P + S):
			for x in range(P, P + S):
				var i := x + z * PW + y * PL
				var b: int = _pb[i]
				if b == Blocks.AIR:
					continue
				if models[b] == "cross":
					_add_cross(i, Vector3(x - P, y, z - P), b)
					continue
				if models[b] == "shape":
					_add_shape(i, Vector3(x - P, y, z - P), b, int(_turns.get(Vector3i(x - P, y, z - P), 0)))
					continue
				if models[b] != "":
					# Drawn by block_models.gd; we only add its collision box,
					# and note how much light reaches it so the model is lit
					# just like the blocks around it.
					var h: float = Blocks.COLLIDE[b]
					if h > 0.0:
						_add_collision_box(Vector3(x - P, y, z - P), h)
					_model_light[Vector3i(x - P, y, z - P)] = Vector2(_sky[i] / 15.0, _blk[i] / 15.0)
					continue
				var is_water: bool = Blocks.IS_WATER[b]
				for f in 6:
					var n: int = _pb[i + _face_off[f]]
					if is_water:
						if f == 2:
							if Blocks.IS_WATER[n]:
								continue   # (the top shows unless more water is above)
						elif n != Blocks.AIR:
							continue
					elif n == b or transparent[n] == 0 or (lava[b] and lava[n]):
						continue
					_add_face(f, i, Vector3(x - P, y, z - P), b, is_water)
	# The bedrock floor (y = 0) only ever shows its top face.
	for z in range(P, P + S):
		for x in range(P, P + S):
			var i := x + z * PW
			if _pb[i] != Blocks.AIR and transparent[_pb[i + PL]] == 1:
				_add_face(2, i, Vector3(x - P, 0, z - P), _pb[i], false)


func _add_face(f: int, i: int, pos: Vector3, b: int, is_water: bool) -> void:
	var tile: int = Blocks.FACE6[b][f]
	var turn: bool = Blocks.UV_TURN[b][f]
	var uw := 1.0 / Blocks.TILE_COUNT
	var u0 := tile * uw
	var sway: float = SWAY_LEAVES if SWAYS.has(b) else SWAY_NONE
	var normal: Vector3 = FACE_NORMALS[f]
	var corners: Array = FACE_CORNERS[f]
	var uvs: Array = FACE_UVS[f]
	var offs: Array = _corner_off[f]
	var atten: Array = Blocks.LIGHT_ATTENUATION
	var front := i + _face_off[f]

	# Per-corner smooth light + ambient occlusion.
	var cols: Array[Color] = []
	var bright := PackedFloat32Array()
	for k in 4:
		var t: Array = offs[k]
		var a: int = front + t[0]
		var c: int = front + t[1]
		var d: int = front + t[0] + t[1]
		var side1: bool = atten[_pb[a]] >= OPAQUE
		var side2: bool = atten[_pb[c]] >= OPAQUE
		var corner: bool = atten[_pb[d]] >= OPAQUE
		var ao := 3 if side1 and side2 else int(side1) + int(side2) + int(corner)
		var sky: int = _sky[front]
		var blk: int = _blk[front]
		var count := 1
		if not side1:
			sky += _sky[a]; blk += _blk[a]; count += 1
		if not side2:
			sky += _sky[c]; blk += _blk[c]; count += 1
		if not corner and not (side1 and side2):
			sky += _sky[d]; blk += _blk[d]; count += 1
		var sv := sky / (15.0 * count)
		var bv := blk / (15.0 * count)
		var sh: float = AO_CURVE[ao]
		cols.append(Color(sv, bv, sh, sway))
		bright.append(maxf(sv, bv) * sh)

	# Split the quad along the diagonal that avoids ugly lighting creases.
	var order := [0, 1, 2, 0, 2, 3]
	if bright[0] + bright[2] < bright[1] + bright[3]:
		order = [1, 2, 3, 1, 3, 0]

	if is_water:
		var base := _w_verts.size()
		for k in 4:
			var cuv: Vector2 = uvs[k]
			var corner: Vector3 = corners[k]
			if corner.y > 0.5:
				corner.y = _water_corner(i, int(corner.x), int(corner.z))   # lower toward the edges of a flow
			_w_verts.append(pos + corner)
			_w_norms.append(normal)
			_w_uvs.append(Vector2(u0 + lerpf(UV_EPS, 1.0 - UV_EPS, cuv.x) * uw,
					lerpf(UV_EPS, 1.0 - UV_EPS, cuv.y)))
			_w_cols.append(cols[k])
		for o in order:
			_w_idx.append(base + o)
	else:
		var base := _s_verts.size()
		for k in 4:
			var cuv: Vector2 = uvs[k]
			if turn:
				cuv = Vector2(cuv.y, cuv.x)
			_s_verts.append(pos + corners[k])
			_s_norms.append(normal)
			_s_uvs.append(Vector2(u0 + lerpf(UV_EPS, 1.0 - UV_EPS, cuv.x) * uw,
					lerpf(UV_EPS, 1.0 - UV_EPS, cuv.y)))
			_s_cols.append(cols[k])
		for o in order:
			_s_idx.append(base + o)
		if Blocks.COLLIDE[b] > 0.0:  # portals and the like are drawn but you walk through them
			var c0: Vector3 = pos + corners[0]
			var c2: Vector3 = pos + corners[2]
			_collision.append_array([c0, pos + corners[1], c2, c0, c2, pos + corners[3]])


## How high the water surface is at one top corner of cell i: the average of
## the water cells around that corner (full height if water falls in there).
func _water_corner(i: int, cx: int, cz: int) -> float:
	var total := 0.0
	var n := 0
	for dz in ([-1, 0] if cz == 0 else [0, 1]):
		for dx in ([-1, 0] if cx == 0 else [0, 1]):
			var j: int = i + dx + dz * PW
			var b: int = _pb[j]
			if not Blocks.IS_WATER[b]:
				continue
			if Blocks.IS_WATER[_pb[j + PL]]:
				return 1.0
			total += Blocks.fluid_height(b)
			n += 1
	return total / n if n > 0 else 0.89


## A ground plant: two see-through pictures crossed in an X (both sides drawn),
## nudged a little off-center so a field of them doesn't look like a grid.
func _add_cross(i: int, pos: Vector3, b: int) -> void:
	var tile: int = Blocks.FACE_TILES[b][1]
	var uw := 1.0 / Blocks.TILE_COUNT
	var u0 := tile * uw + UV_EPS * uw
	var u1 := (tile + 1) * uw - UV_EPS * uw
	var hsh := (int(pos.x) * 73856093) ^ (int(pos.z) * 19349663) ^ (int(pos.y) * 83492791)
	var nudge := Vector3(((hsh & 7) - 3.5) * 0.03, 0.0, (((hsh >> 3) & 7) - 3.5) * 0.03)
	var col := Color(_sky[i] / 15.0, _blk[i] / 15.0, 1.0, 0.95)   # (alpha below 1: a plant)
	var top := Color(col.r, col.g, col.b, SWAY_PLANT)
	var lo := 0.15
	var hi := 0.85
	for diag in [[Vector3(lo, 0, lo), Vector3(hi, 0, hi)], [Vector3(hi, 0, lo), Vector3(lo, 0, hi)]]:
		var a: Vector3 = pos + nudge + diag[0]
		var d: Vector3 = pos + nudge + diag[1]
		var quad := [a, a + Vector3.UP, d + Vector3.UP, d]
		var quv := [Vector2(u0, 1.0 - UV_EPS), Vector2(u0, UV_EPS), Vector2(u1, UV_EPS), Vector2(u1, 1.0 - UV_EPS)]
		var base := _s_verts.size()
		for k in 4:
			_s_verts.append(quad[k])
			_s_norms.append(Vector3.UP)
			_s_uvs.append(quv[k])
			_s_cols.append(top if k == 1 or k == 2 else col)
		_s_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])  # front
		_s_idx.append_array([base, base + 2, base + 1, base, base + 3, base + 2])  # back


## A shaped block (stairs, slab, column, table, chair): a few boxes, every face
## drawn, the texture cut to fit each face so the wood grain stays the same size.
## Each box also gets its own collision, so you can stand on a slab's top.
func _add_shape(i: int, pos: Vector3, b: int, turn: int) -> void:
	var tiles: Array = Blocks.FACE6[b]
	var uw := 1.0 / Blocks.TILE_COUNT
	var sky := _sky[i] / 15.0
	var blk := _blk[i] / 15.0
	var shape: String = Blocks.SHAPE[b]
	if shape == "wedge":
		_add_wedge(pos, tiles[2], turn, sky, blk)
		return
	var boxes: Array
	if shape == "fence" or shape == "wall":
		var sides := []
		for f in [0, 1, 4, 5]:   # +X, -X, +Z, -Z
			sides.append(Blocks.fence_joins(_pb[i + _face_off[f]]))
		boxes = Blocks.fence_boxes(b, sides)
		if shape == "fence":
			# Fences are a bit taller than they look (like Minecraft), so you
			# and the animals can't just hop over them.
			for box in boxes:
				var lo: Vector3 = box[0]
				var hi: Vector3 = box[1]
				if hi.y >= 0.9:
					_add_collision_aabb(pos + Vector3(lo.x, 1.0, lo.z), pos + Vector3(hi.x, 1.5, hi.z))
	else:
		boxes = Blocks.shape_boxes(b, turn)
	for box in boxes:
		var a: Vector3 = box[0]
		var c: Vector3 = box[1]
		for f in 6:
			var u0: float = tiles[f] * uw
			var base := _s_verts.size()
			for k in 4:
				var corner: Vector3 = FACE_CORNERS[f][k]
				var p := a + corner * (c - a)
				var uv := _box_uv(f, p)
				_s_verts.append(pos + p)
				_s_norms.append(FACE_NORMALS[f])
				_s_uvs.append(Vector2(u0 + lerpf(UV_EPS, 1.0 - UV_EPS, uv.x) * uw, lerpf(UV_EPS, 1.0 - UV_EPS, uv.y)))
				_s_cols.append(Color(sky, blk, 1.0))
			_s_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			var v0: Vector3 = _s_verts[base]
			var v2: Vector3 = _s_verts[base + 2]
			_collision.append_array([v0, _s_verts[base + 1], v2, v0, v2, _s_verts[base + 3]])


## Where on its picture a point of a face is (the same layout as full cubes).
static func _box_uv(f: int, p: Vector3) -> Vector2:
	match f:
		0, 1:
			return Vector2(p.z, 1.0 - p.y)
		2, 3:
			return Vector2(p.x, p.z)
	return Vector2(p.x, 1.0 - p.y)


func _add_collision_aabb(a: Vector3, b: Vector3) -> void:
	for f in 6:
		var c: Array = FACE_CORNERS[f]
		var v := []
		for k in 4:
			var corner: Vector3 = c[k]
			v.append(a + corner * (b - a))
		_collision.append_array([v[0], v[1], v[2], v[0], v[2], v[3]])


## A wedge: a smooth slope from the back top edge down to the front bottom
## edge (turned like stairs, and flipped upside down for the bottom of a roof).
func _add_wedge(pos: Vector3, tile: int, turn: int, sky: float, blk: float) -> void:
	var uw := 1.0 / Blocks.TILE_COUNT
	var turns := turn & 3
	var flip := (turn & 4) != 0
	var tf := func(p: Vector3) -> Vector3:
		var q := p
		for t in turns:
			q = Vector3(1.0 - q.z, q.y, q.x)
		if flip:
			q.y = 1.0 - q.y
		return q
	# [points (before turning), uv face, shade]
	var faces := [
		[[Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], 2, 0.95],   # the slope
		[[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)], 3, 0.55],   # bottom
		[[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)], 5, 0.65],   # back
		[[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], 1, 0.8],                      # sides
		[[Vector3(1, 0, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)], 0, 0.8],
	]
	for face in faces:
		var pts: Array = face[0]
		var base := _s_verts.size()
		var world_pts := []
		for p in pts:
			var q: Vector3 = tf.call(p)
			world_pts.append(pos + q)
			var uv := _box_uv(face[1], p)
			_s_verts.append(pos + q)
			_s_uvs.append(Vector2(tile * uw + lerpf(UV_EPS, 1.0 - UV_EPS, uv.x) * uw, lerpf(UV_EPS, 1.0 - UV_EPS, uv.y)))
			_s_cols.append(Color(sky, blk, 1.0))
		var nrm: Vector3 = (world_pts[1] - world_pts[0]).cross(world_pts[2] - world_pts[0]).normalized()
		for k in pts.size():
			_s_norms.append(-nrm)
		var tri: Array = [base, base + 1, base + 2]
		if pts.size() == 4:
			tri.append_array([base, base + 2, base + 3])
		# Both windings: turning and flipping change which side faces out, so draw both.
		for k in range(0, tri.size(), 3):
			_s_idx.append_array([tri[k], tri[k + 1], tri[k + 2], tri[k], tri[k + 2], tri[k + 1]])
			_collision.append_array([_s_verts[tri[k]], _s_verts[tri[k + 1]], _s_verts[tri[k + 2]]])


func _add_collision_box(pos: Vector3, h: float) -> void:
	for f in 6:
		var c: Array = FACE_CORNERS[f]
		var v := []
		for k in 4:
			var corner: Vector3 = c[k]
			v.append(pos + Vector3(corner.x, corner.y * h, corner.z))
		_collision.append_array([v[0], v[1], v[2], v[0], v[2], v[3]])


func _result() -> Dictionary:
	var out := {"solid": null, "water": null, "collision": _collision, "models": _model_light}
	if not _s_verts.is_empty():
		out["solid"] = _pack(_s_verts, _s_norms, _s_uvs, _s_cols, _s_idx)
	if not _w_verts.is_empty():
		out["water"] = _pack(_w_verts, _w_norms, _w_uvs, _w_cols, _w_idx)
	return out


static func _pack(v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array,
		c: PackedColorArray, idx: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays
