extends RefCounted
## Solid 3D models for tools and weapons you hold, built from little boxes.
## Every tier has its own shape (and gets bigger and fancier as it goes up),
## legendary weapons have their own look, and cute ones get hearts and bows.
##
## Models are built standing up (grip at the origin, the tool pointing up +Y,
## its flat side facing +Z), then leaned 45 degrees so they point up and to the
## right, just like the item pictures. Sizes are in "s" (the model's size).

const Items = preload("res://scripts/items.gd")

const WOOD := Color(0.6, 0.42, 0.24)
const DARK_WOOD := Color(0.36, 0.24, 0.15)
const LEATHER := Color(0.42, 0.26, 0.16)
const GOLD := Color(1.0, 0.8, 0.3)
const PINK := Color(1.0, 0.55, 0.78)

## Face shading (this is drawn without lighting, like the old pixel models).
const FACES := [[Vector3(0, 0, 1), 1.0], [Vector3(0, 0, -1), 0.88], [Vector3(1, 0, 0), 0.74],
		[Vector3(-1, 0, 0), 0.7], [Vector3(0, 1, 0), 0.92], [Vector3(0, -1, 0), 0.6]]

static var _cache := {}


class Builder:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var s := 1.0

	## A box: center and size in s units, turned rot (radians) around Z.
	func box(center: Vector2, size: Vector3, c: Color, rot := 0.0, z := 0.0) -> void:
		var b := Basis(Vector3(0, 0, 1), rot)
		var h := size * 0.5
		var o := Vector3(center.x, center.y, z)
		for f in FACES:
			var n: Vector3 = f[0]
			var shade: float = f[1]
			var base := verts.size()
			for q in _quad(n, -h, size):
				verts.append((o + b * q) * s)
				cols.append(Color(c.r * shade, c.g * shade, c.b * shade))
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	## A little heart (for cute things), w wide.
	func heart(center: Vector2, w: float, c: Color, z := 0.0) -> void:
		box(center + Vector2(-w * 0.22, w * 0.12), Vector3(w * 0.48, w * 0.42, w * 0.3), c, 0.0, z)
		box(center + Vector2(w * 0.22, w * 0.12), Vector3(w * 0.48, w * 0.42, w * 0.3), c, 0.0, z)
		box(center + Vector2(0, -w * 0.12), Vector3(w * 0.42, w * 0.42, w * 0.3), c, PI / 4.0, z)

	static func _quad(n: Vector3, a: Vector3, sz: Vector3) -> Array:
		var b := a + sz
		if n.z > 0:
			return [Vector3(a.x, a.y, b.z), Vector3(a.x, b.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, a.y, b.z)]
		if n.z < 0:
			return [Vector3(b.x, a.y, a.z), Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, a.y, a.z)]
		if n.x > 0:
			return [Vector3(b.x, a.y, b.z), Vector3(b.x, b.y, b.z), Vector3(b.x, b.y, a.z), Vector3(b.x, a.y, a.z)]
		if n.x < 0:
			return [Vector3(a.x, a.y, a.z), Vector3(a.x, b.y, a.z), Vector3(a.x, b.y, b.z), Vector3(a.x, a.y, b.z)]
		if n.y > 0:
			return [Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
		return [Vector3(a.x, a.y, a.z), Vector3(a.x, a.y, b.z), Vector3(b.x, a.y, b.z), Vector3(b.x, a.y, a.z)]

	func mesh() -> ArrayMesh:
		# Lean it 45 degrees so it points up and to the right.
		var lean := Basis(Vector3(0, 0, 1), -PI / 4.0)
		for i in verts.size():
			verts[i] = lean * verts[i]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		if not verts.is_empty():
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return m


## Can this item be shown with a built model? (Tools and weapons.)
static func has_model(id: String) -> bool:
	return Items.get_def(id).has("tool")


## How long a tool's model is (in s), for tests and for placing it.
static func length_of(id: String) -> float:
	var d := Items.get_def(id)
	var tier := clampi(int(d.get("tier", 1)), 1, 5)
	if d.get("tool", "") == "sword":
		return 1.95 if d.get("rarity", "") == "legendary" and d.get("icon", "") == "sword" else [0.0, 1.05, 1.2, 1.36, 1.54, 1.75][tier]
	return [0.0, 1.0, 1.06, 1.12, 1.2, 1.3][tier]


static func mesh(id: String, size: float) -> ArrayMesh:
	var key := "%s@%.3f" % [id, size]
	if _cache.has(key):
		return _cache[key]
	var d := Items.get_def(id)
	var bld := Builder.new()
	bld.s = size
	var tier := clampi(int(d.get("tier", 1)), 1, 5)
	var c: Color = d.get("color", Color(0.8, 0.8, 0.8))
	var cute: bool = d.get("cute", false)
	var legend: bool = d.get("rarity", "") == "legendary"
	if d.get("icon", "") == "hammer":
		_hammer(bld, c)
	else:
		match d.get("tool", ""):
			"sword":
				_sword(bld, id, tier, c, cute, legend)
			"pickaxe":
				_pickaxe(bld, tier, c, cute)
			"axe":
				_axe(bld, tier, c, cute)
			"shovel":
				_shovel(bld, tier, c, cute)
	var m := bld.mesh()
	_cache[key] = m
	return m


## The handle every tool has: from the bottom (y0) up to y1, w wide, getting
## fancier wraps and bands as the tier goes up.
static func _handle(b: Builder, y0: float, y1: float, w: float, tier: int, cute: bool) -> void:
	var col: Color = WOOD if tier <= 2 else (DARK_WOOD if tier >= 4 else WOOD.darkened(0.1))
	if cute:
		col = Color(1.0, 0.92, 0.95)
	b.box(Vector2(0, (y0 + y1) * 0.5), Vector3(w, y1 - y0, w), col)
	var bands := 0 if tier <= 1 else (2 if tier <= 3 else 3)
	var band_c: Color = LEATHER if tier == 3 else (Color(0.7, 0.7, 0.74) if tier == 4 else GOLD)
	if cute:
		bands = 4
		band_c = PINK
	for i in bands:
		var y := y0 + 0.04 + i * 0.06
		b.box(Vector2(0, y), Vector3(w * 1.3, 0.03, w * 1.3), band_c)
	if tier >= 2:
		b.box(Vector2(0, y0 - 0.02), Vector3(w * 1.4, 0.04, w * 1.4), band_c if tier >= 4 else col.darkened(0.2))   # an end cap


static func _sword(b: Builder, id: String, tier: int, c: Color, cute: bool, legend: bool) -> void:
	var length := length_of(id)
	var bw: float = [0.0, 0.11, 0.14, 0.135, 0.14, 0.165][tier]
	var gw: float = [0.0, 0.17, 0.22, 0.27, 0.32, 0.38][tier]
	var edge := c.lightened(0.35)
	var fuller := c.darkened(0.18)
	var guard_c: Color = WOOD.darkened(0.15) if tier <= 2 else (c.darkened(0.25) if tier == 3 else GOLD)
	var pommel_c: Color = guard_c
	var gem := Color(0.5, 0.85, 1.0)
	if legend:
		bw = 0.175
		gw = 0.4
		gem = d_gem(id, Color(0.55, 0.85, 1.0))
		if id == "black_throne_blade":
			edge = gem.lightened(0.2)
			fuller = gem.darkened(0.2)
			guard_c = Color(0.75, 0.76, 0.82)
		else:
			edge = GOLD.lightened(0.15)
			fuller = gem
			guard_c = GOLD
		pommel_c = guard_c
	if cute:
		guard_c = PINK
		pommel_c = PINK
		edge = Color(1.0, 0.95, 0.98)
	# Grip and pommel.
	var wrap: Color = WOOD if tier == 1 else (LEATHER if tier <= 3 else Color(0.18, 0.14, 0.2))
	if cute:
		wrap = Color(1.0, 0.92, 0.95)
	b.box(Vector2(0, -0.09), Vector3(0.05, 0.18, 0.055), wrap)
	for i in (0 if tier == 1 else 3):
		b.box(Vector2(0, -0.035 - i * 0.05), Vector3(0.06, 0.018, 0.065), wrap.lightened(0.25) if not cute else PINK)
	if cute:
		b.heart(Vector2(0, -0.22), 0.11, PINK)
	elif tier == 1:
		b.box(Vector2(0, -0.2), Vector3(0.07, 0.05, 0.07), WOOD.darkened(0.2))
	else:
		b.box(Vector2(0, -0.21), Vector3(0.08 + tier * 0.006, 0.07, 0.08), pommel_c)
		if tier >= 5 or legend:
			b.box(Vector2(0, -0.21), Vector3(0.05, 0.05, 0.095), gem)
	# The crossguard.
	if cute:
		b.heart(Vector2(0, 0.03), 0.2, PINK, 0.0)
		b.box(Vector2(-0.12, 0.05), Vector3(0.08, 0.06, 0.04), Color(1.0, 0.4, 0.65), 0.5)   # a little bow
		b.box(Vector2(0.12, 0.05), Vector3(0.08, 0.06, 0.04), Color(1.0, 0.4, 0.65), -0.5)
	else:
		b.box(Vector2(0, 0.02), Vector3(gw, 0.04, 0.075), guard_c)
		match tier:
			3:   # curved up at the ends
				for sx in [-1.0, 1.0]:
					b.box(Vector2(sx * gw * 0.5, 0.05), Vector3(0.04, 0.07, 0.075), guard_c, -sx * 0.4)
			4:   # square caps hanging down
				for sx in [-1.0, 1.0]:
					b.box(Vector2(sx * gw * 0.5, 0.0), Vector3(0.05, 0.08, 0.085), guard_c.lightened(0.15))
			5:   # swept-up wings and a gem
				for sx in [-1.0, 1.0]:
					b.box(Vector2(sx * gw * 0.42, 0.07), Vector3(0.13, 0.04, 0.07), guard_c, sx * 0.55)
				b.box(Vector2(0, 0.02), Vector3(0.06, 0.06, 0.09), gem)
		if legend:
			if id == "white_throne_blade":
				for sx in [-0.12, 0.0, 0.12]:   # a crown for a guard
					b.box(Vector2(sx, 0.08), Vector3(0.035, 0.06 if sx != 0.0 else 0.09, 0.07), GOLD)
			else:
				for sx in [-1.0, 1.0]:   # cruel spikes
					b.box(Vector2(sx * 0.2, 0.08), Vector3(0.03, 0.14, 0.06), guard_c, sx * 0.35)
	# The blade: a stack of slices, shaped by tier.
	var y0 := 0.045
	var n := 12
	var seg := (length - y0) / n
	for i in n:
		var t := (i + 0.5) / n
		var w := bw
		match tier:
			1:
				w = bw * (1.0 - 0.25 * pow(t, 4.0))
			2:
				w = bw * (1.0 + (0.08 if i % 2 == 0 else -0.04))   # chipped stone edge
			3:
				w = bw * (0.82 + 0.45 * sin(PI * t * 0.85))         # leaf-shaped
			_:
				w = bw
		if legend:
			w = bw * (1.0 + 0.15 * sin(PI * t))
		var point := 0.72 if tier >= 4 or legend else 0.8
		if t > point:
			w *= 1.0 - (t - point) / (1.0 - point) * 0.82
		var y := y0 + (i + 0.5) * seg
		b.box(Vector2(0, y), Vector3(w, seg * 1.04, 0.04), c)
		if tier >= 3 or legend or cute:
			b.box(Vector2(-w * 0.5 + 0.006, y), Vector3(0.014, seg * 1.04, 0.036), edge)   # bright edges
			b.box(Vector2(w * 0.5 - 0.006, y), Vector3(0.014, seg * 1.04, 0.036), edge)
		if (tier >= 4 or legend) and t < point:
			b.box(Vector2(0, y), Vector3(w * 0.22, seg * 1.04, 0.038), fuller)   # the groove down the middle
	if cute:
		b.heart(Vector2(0, length * 0.55), 0.1, Color(1.0, 0.45, 0.7), 0.02)
		b.box(Vector2(0.03, length * 0.75), Vector3(0.02, 0.02, 0.04), Color.WHITE)   # sparkles
		b.box(Vector2(-0.03, length * 0.35), Vector3(0.02, 0.02, 0.04), Color.WHITE)


static func d_gem(id: String, fallback: Color) -> Color:
	return Items.get_def(id).get("gem", fallback)


static func _pickaxe(b: Builder, tier: int, c: Color, cute: bool) -> void:
	var h: float = [0.0, 0.95, 1.0, 1.05, 1.1, 1.18][tier]
	_handle(b, -0.15, h - 0.04, 0.055, tier, cute)
	var hw: float = [0.0, 0.26, 0.3, 0.34, 0.38, 0.44][tier]
	var thick: float = [0.0, 0.095, 0.12, 0.1, 0.11, 0.12][tier]
	var n := 10
	for i in n:
		var t := (i + 0.5) / n * 2.0 - 1.0         # -1..1 across the head
		var x := t * hw
		var y := h - absf(t) * absf(t) * 0.12       # curving down to the points
		var slope := -2.0 * t * 0.12 / hw
		var th := thick * (1.0 - absf(t) * 0.55)
		var col := c.lightened(0.3) if absf(t) > 0.8 and tier >= 3 else c
		b.box(Vector2(x, y), Vector3(hw * 2.0 / n * 1.1, th, 0.06), col, atan(slope))
	b.box(Vector2(0, h - 0.01), Vector3(0.09, 0.1, 0.075), c.darkened(0.25) if tier < 5 else GOLD)   # where it meets the handle
	if tier >= 5:
		b.box(Vector2(0, h - 0.01), Vector3(0.05, 0.05, 0.085), Color(0.5, 0.85, 1.0))
	if cute:
		b.heart(Vector2(0, h + 0.03), 0.09, PINK, 0.0)


static func _axe(b: Builder, tier: int, c: Color, cute: bool) -> void:
	var h: float = [0.0, 0.95, 1.0, 1.06, 1.12, 1.2][tier]
	_handle(b, -0.15, h + 0.02, 0.055, tier, cute)
	var reach: float = [0.0, 0.2, 0.23, 0.27, 0.3, 0.33][tier]
	var sides := [-1.0, 1.0] if tier >= 5 else [-1.0]
	for side in sides:
		var n := 7
		for i in n:
			var t := (i + 0.5) / n
			var x: float = side * (0.03 + t * reach)
			var tall := 0.1 + t * (0.12 + tier * 0.025)   # the blade flares out toward the edge
			var col := c.lightened(0.38) if i == n - 1 else c
			b.box(Vector2(x, h - 0.08), Vector3(reach / n * 1.1, tall, 0.05), col)
	if tier == 4:
		b.box(Vector2(0.08, h - 0.08), Vector3(0.1, 0.05, 0.05), c.darkened(0.1))   # a spike on the back
	b.box(Vector2(0, h - 0.08), Vector3(0.08, 0.16, 0.07), c.darkened(0.25) if tier < 5 else GOLD)
	if cute:
		b.heart(Vector2(-reach * 0.5, h - 0.08), 0.08, PINK, 0.03)


static func _shovel(b: Builder, tier: int, c: Color, cute: bool) -> void:
	var h: float = [0.0, 0.8, 0.85, 0.9, 0.95, 1.0][tier]
	_handle(b, -0.1, h, 0.05, tier, cute)
	# A D-grip at the bottom.
	var grip_c: Color = WOOD.darkened(0.2) if not cute else PINK
	b.box(Vector2(0, -0.2), Vector3(0.16, 0.035, 0.05), grip_c)
	for sx in [-0.065, 0.065]:
		b.box(Vector2(sx, -0.15), Vector3(0.035, 0.1, 0.05), grip_c)
	b.box(Vector2(0, h), Vector3(0.08, 0.07, 0.07), c.darkened(0.3))   # the collar
	var bw: float = [0.0, 0.16, 0.18, 0.2, 0.22, 0.25][tier]
	var bl: float = [0.0, 0.24, 0.26, 0.28, 0.31, 0.34][tier]
	var n := 8
	for i in n:
		var t := (i + 0.5) / n
		var w := bw if t < 0.55 else bw * (1.0 - (t - 0.55) / 0.45 * 0.85)
		if tier >= 5 and i % 2 == 1 and t > 0.3:
			w *= 0.9   # a toothed edge
		b.box(Vector2(0, h + 0.035 + (i + 0.5) * bl / n), Vector3(w, bl / n * 1.05, 0.03), c.lightened(0.2) if i == n - 1 else c)
	if cute:
		b.heart(Vector2(0, h + bl * 0.45), 0.08, PINK, 0.02)


## Chuckles' circus hammer: a long handle and a huge striped head.
static func _hammer(b: Builder, c: Color) -> void:
	_handle(b, -0.18, 1.3, 0.06, 4, false)
	b.box(Vector2(0, 1.42), Vector3(0.5, 0.26, 0.26), c)
	for sx in [-0.17, 0.0, 0.17]:
		b.box(Vector2(sx, 1.42), Vector3(0.06, 0.27, 0.27), Color(0.97, 0.95, 0.92))
	for sx in [-0.26, 0.26]:
		b.box(Vector2(sx, 1.42), Vector3(0.04, 0.3, 0.3), GOLD)
