extends RefCounted
## Detailed surfaces for creatures, characters and armor: fur, skin, cloth,
## leather, metal, bone, gummy, scales, feathers, wood and straw. Each kind is
## a small tiling picture (painted in code) that the part's own color is
## multiplied with, wrapped around the box from all sides (triplanar), so a
## blocky model looks hand-textured without any UVs.
##
## Settings > "Creature detail": 0 Simple (flat colors, the classic look),
## 1 Detailed (textures), 2 Ultra HD (finer textures with bumps that catch the light).

const Settings = preload("res://scripts/settings.gd")

const KINDS := ["plain", "fur", "hair", "skin", "cloth", "leather", "metal", "bone", "gummy", "scale", "feather", "wood", "straw", "stone"]
## How many times the picture repeats per block (smaller = bigger details).
const SCALE := {"fur": 4.0, "hair": 5.0, "skin": 3.0, "cloth": 6.0, "leather": 3.5, "metal": 3.0, "bone": 3.0,
		"gummy": 2.5, "scale": 4.0, "feather": 4.0, "wood": 2.5, "straw": 3.5, "stone": 2.5}
const ROUGH := {"plain": 1.0, "fur": 1.0, "hair": 0.85, "skin": 0.75, "cloth": 0.95, "leather": 0.7, "metal": 0.32,
		"bone": 0.8, "gummy": 0.25, "scale": 0.45, "feather": 0.9, "wood": 0.9, "straw": 1.0, "stone": 0.95}
## The pictures are a little darker than white on average; colors are brightened to match.
const LIFT := 1.12

static var _tex := {}      # "kind:level" -> [albedo, normal]
static var _mats := {}     # material cache (shared, never changed after it's made)


static func level() -> int:
	return clampi(int(Settings.gfx.get("creature_detail", 1)), 0, 2)


## A shared material for a part. Don't change it: use material_copy() for that.
static func material(color: Color, kind := "plain", glow := false) -> StandardMaterial3D:
	var lv := level()
	var key := "%s|%s|%s|%d" % [color.to_html(), kind, glow, lv]
	if not _mats.has(key):
		_mats[key] = _make(color, kind, glow, lv)
	return _mats[key]


## A fresh material the caller may change (cull mode, metal, emission...).
static func material_copy(color: Color, kind := "plain") -> StandardMaterial3D:
	return _make(color, kind, false, level())


static func _make(color: Color, kind: String, glow: bool, lv: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = ROUGH.get(kind, 1.0) if lv > 0 else 1.0
	if kind == "metal" and lv > 0:
		m.metallic = 0.55
	if lv > 0 and kind != "plain" and not glow:
		var t: Array = _textures(kind, lv)
		m.albedo_texture = t[0]
		m.albedo_color = Color(minf(color.r * LIFT, 1.0), minf(color.g * LIFT, 1.0), minf(color.b * LIFT, 1.0), color.a)
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE * float(SCALE.get(kind, 3.0)) * (0.5 if lv >= 2 else 1.0)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		if lv >= 2:
			m.normal_enabled = true
			m.normal_texture = t[1]
			m.normal_scale = 0.9
		if kind == "gummy":
			m.rim_enabled = true
			m.rim = 0.35
			m.rim_tint = 0.6
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.5
	return m


## [albedo, normal] pictures for a kind (painted once, then kept).
static func _textures(kind: String, lv: int) -> Array:
	var key := "%s:%d" % [kind, lv]
	if _tex.has(key):
		return _tex[key]
	var n := 32 if lv < 2 else 64
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + 77
	var h := PackedFloat32Array()
	h.resize(n * n)
	for i in h.size():
		h[i] = 0.9
	_paint(kind, h, n, rng)
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var nrm := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := clampf(h[x + y * n], 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
			var dx := h[posmod(x + 1, n) + y * n] - h[posmod(x - 1, n) + y * n]
			var dy := h[x + posmod(y + 1, n) * n] - h[x + posmod(y - 1, n) * n]
			var nv := Vector3(-dx * 3.0, dy * 3.0, 1.0).normalized()
			nrm.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5, 1.0))
	img.generate_mipmaps()
	nrm.generate_mipmaps()
	var out := [ImageTexture.create_from_image(img), ImageTexture.create_from_image(nrm)]
	_tex[key] = out
	return out


## Paints a kind's light/dark pattern (0..1, about 0.9 on average) into h.
static func _paint(kind: String, h: PackedFloat32Array, n: int, rng: RandomNumberGenerator) -> void:
	var w := TAU / n
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var mottle := func(x: int, y: int) -> float:
		return sin(x * w * 2.0 + ph[0]) * sin(y * w * 3.0 + ph[1]) * 0.5 + sin(x * w * 5.0 - y * w * 4.0 + ph[2]) * 0.5
	for y in n:
		for x in n:
			h[x + y * n] = 0.9 + rng.randf_range(-0.04, 0.04) + mottle.call(x, y) * 0.03
	match kind:
		"fur", "hair":
			# Strands: short lines running down, some lighter, some darker.
			var count := n * n / (5 if kind == "fur" else 3)
			for k in count:
				var x := rng.randi() % n
				var y := rng.randi() % n
				var d := rng.randf_range(-0.14, 0.12)
				var lean := rng.randi_range(-1, 1) if kind == "fur" else 0
				for j in rng.randi_range(3, 7 if kind == "fur" else 10):
					var i := posmod(x + (lean if j > 2 else 0), n) + posmod(y + j, n) * n
					h[i] = clampf(h[i] + d * (1.0 - j * 0.08), 0.0, 1.0)
		"skin":
			for k in n * n / 18:
				var i := rng.randi() % (n * n)
				h[i] -= rng.randf_range(0.02, 0.06)   # pores and freckle-ish dots
			for y in n:
				for x in n:
					h[x + y * n] += mottle.call(x, y) * 0.03
		"cloth":
			# A woven pattern: threads over and under.
			for y in n:
				for x in n:
					var over := ((x / 2) + (y / 2)) % 2 == 0
					h[x + y * n] += (0.05 if over else -0.05) + (0.03 if (x % 2 == 0) != over else 0.0)
		"leather":
			for y in n:
				for x in n:
					h[x + y * n] += mottle.call(x, y) * 0.05
			for k in 7:
				_walk(h, n, rng, rng.randi() % n, rng.randi() % n, rng.randi_range(5, 12), -0.12)   # creases
		"metal":
			# Brushed lines, a few scratches and dents.
			for y in n:
				var line := rng.randf_range(-0.04, 0.04)
				for x in n:
					h[x + y * n] = 0.88 + line + rng.randf_range(-0.015, 0.015)
			for k in 6:
				_walk(h, n, rng, rng.randi() % n, rng.randi() % n, rng.randi_range(4, 10), 0.1)
			for k in 3:
				_dent(h, n, rng.randi() % n, rng.randi() % n, rng.randf_range(1.5, 3.0), -0.08)
		"bone":
			for k in 6:
				_walk(h, n, rng, rng.randi() % n, rng.randi() % n, rng.randi_range(4, 9), -0.15)   # cracks
			for k in n / 2:
				_dent(h, n, rng.randi() % n, rng.randi() % n, 0.8, -0.1)   # little pits
		"gummy":
			for k in 6:
				_dent(h, n, rng.randi() % n, rng.randi() % n, rng.randf_range(1.0, 2.5), 0.07)   # bubbles
			for i in h.size():
				h[i] = lerpf(h[i], 0.93, 0.6)
		"scale":
			# Rows of overlapping round scales.
			var s := maxi(4, n / 8)
			for y in n:
				for x in n:
					var row := y / s
					var cx := (x + (s / 2 if row % 2 == 1 else 0)) % s
					var d := Vector2(cx - s * 0.5, y % s).length() / s
					h[x + y * n] += 0.08 - d * 0.2
		"feather":
			for y in n:
				for x in n:
					var barb := posmod(x + y / 2, 4) == 0
					h[x + y * n] += -0.08 if barb else 0.02
			for x in range(0, n, 8):
				for y in n:
					h[x + y * n] = 0.97   # the quills
		"wood":
			for y in n:
				for x in n:
					var g := sin(x * w * 3.0 + sin(y * w * 2.0 + ph[0]) * 2.0)
					h[x + y * n] += -0.12 if g > 0.85 else g * 0.02
		"straw":
			for k in n * n / 4:
				var x := rng.randi() % n
				var y := rng.randi() % n
				var d := rng.randf_range(-0.16, 0.12)
				for j in rng.randi_range(4, 9):
					var i := posmod(x + j / 3, n) + posmod(y + j, n) * n
					h[i] = clampf(h[i] + d, 0.0, 1.0)
		"stone":
			for k in 5:
				_walk(h, n, rng, rng.randi() % n, rng.randi() % n, rng.randi_range(6, 14), -0.15)
			for k in n:
				var i := rng.randi() % (n * n)
				h[i] += 0.08


static func _walk(h: PackedFloat32Array, n: int, rng: RandomNumberGenerator, x: int, y: int, length: int, d: float) -> void:
	var p := Vector2(x, y)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	for j in length:
		var i := posmod(int(p.x), n) + posmod(int(p.y), n) * n
		h[i] = clampf(h[i] + d, 0.0, 1.0)
		dir = dir.rotated(rng.randf_range(-0.7, 0.7))
		p += dir


static func _dent(h: PackedFloat32Array, n: int, cx: int, cy: int, r: float, d: float) -> void:
	var ri := ceili(r)
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var k := 1.0 - Vector2(dx, dy).length() / r
			if k > 0.0:
				var i := posmod(cx + dx, n) + posmod(cy + dy, n) * n
				h[i] = clampf(h[i] + d * k, 0.0, 1.0)


# --- Which surface each mob is made of -------------------------------------------------

const MOB_KIND := {
	"bunny": "fur", "deer": "fur", "boar": "fur", "ram": "fur", "wolf": "fur", "cougar": "fur", "bear": "fur",
	"sand_bear": "fur", "king_cougar": "fur", "snow_hare": "fur", "mountain_goat": "fur", "polar_bear": "fur",
	"dire_wolf": "fur", "yeti": "fur", "squirrel": "fur", "hedgehog": "fur", "fox": "fur", "black_cat": "fur",
	"boar_king": "fur", "chicken": "feather", "crow": "feather", "spider": "scale", "sand_spider": "scale",
	"gummy_bear": "gummy", "marshmallow": "gummy", "peppermint_pig": "gummy", "gummy_giant": "gummy",
	"qtmame": "skin", "zombie": "skin", "gremlin": "skin", "cave_troll": "stone", "witch": "cloth", "lantern_witch": "cloth",
	"skeleton": "bone", "skeleton_archer": "bone", "skeleton_knight": "bone", "bone_hound": "bone", "grimskull": "bone",
	"scarecrow": "straw", "scarecrow_king": "straw", "oakheart": "wood", "ghost": "plain", "fairy": "plain",
	"white_pawn": "stone", "black_pawn": "stone", "white_king": "stone", "white_queen": "stone", "black_king": "stone", "black_queen": "stone",
	"heart_soldier": "plain", "spade_soldier": "plain", "card_guard": "plain",
	"nugget_buddy": "gummy", "spicy_nugget": "gummy", "happy_box": "plain", "chomp_box": "plain",
	"angry_fries": "plain", "fry_minion": "plain", "clown": "cloth",
	"fire_imp": "plain", "imp_minion": "plain", "magma_slime": "gummy", "fire_drake": "plain", "fire_giant": "plain",
}


## The surface for one part of a mob: small bits (eyes, noses, buttons) and
## glowing bits stay flat; horns and tusks are bone; armor plates metal.
static func part_kind(type: String, part: Dictionary) -> String:
	if part.has("mat"):
		return part["mat"]
	var size: Vector3 = part["size"]
	var c: Color = part["color"]
	if part.get("glow", false) or minf(size.x, minf(size.y, size.z)) < 0.045 or c.v < 0.12:
		return "plain"
	var base: String = MOB_KIND.get(type, "skin")
	if base == "plain":
		return "plain"
	if c.s < 0.12 and c.v > 0.82 and base != "bone" and base != "gummy" and maxf(size.x, maxf(size.y, size.z)) < 0.5 \
			and minf(size.x, size.z) < 0.12:
		return "bone"   # horns, tusks, antlers, claws
	if base == "bone" and c.s > 0.08 and c.v < 0.7:
		return "metal" if c.s < 0.3 else "cloth"   # a skeleton knight's armor, a skeleton's rags
	return base
