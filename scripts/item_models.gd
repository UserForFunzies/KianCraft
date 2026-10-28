extends RefCounted
## 3D models for things you hold: a little textured cube for blocks, and a flat
## pixel-art cut-out for tools and other items. Used for your own hand (first
## person), other players' hands, and the cracking overlay when mining.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Mesher = preload("res://scripts/chunk_mesher.gd")
const ToolModels = preload("res://scripts/tool_models.gd")


## A unit cube (0..1) with the block's textures. tile_uvs=false gives every face
## plain 0..1 UVs instead (for the crack overlay).
static func cube_mesh(block: int, tile_uvs := true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uw := 1.0 / Blocks.TILE_COUNT
	for f in 6:
		var which := 0 if f == 2 else (2 if f == 3 else 1)
		var tile: int = Blocks.FACE_TILES[block][which] if tile_uvs else 0
		var shade: float = Mesher.FACE_SHADE[f]
		var base := verts.size()
		for k in 4:
			var cuv: Vector2 = Mesher.FACE_UVS[f][k]
			verts.append(Mesher.FACE_CORNERS[f][k])
			norms.append(Mesher.FACE_NORMALS[f])
			uvs.append(Vector2(tile * uw + cuv.x * uw, cuv.y) if tile_uvs else cuv)
			cols.append(Color(shade, shade, shade))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A box of any size made of atlas tiles, with light baked into vertex colors
## the same way chunk_mesher.gd does it (so it works with voxel.gdshader).
## tiles: one tile per face in the order +X, -X, +Y, -Y, +Z, -Z.
static func box_mesh(size: Vector3, offset: Vector3, tiles: Array, sky: float, lamp: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var uw := 1.0 / Blocks.TILE_COUNT
	for f in 6:
		var shade := 1.0   # (the world's shader lights it from the sun)
		var base := verts.size()
		for k in 4:
			var corner: Vector3 = Mesher.FACE_CORNERS[f][k]
			var cuv: Vector2 = Mesher.FACE_UVS[f][k]
			verts.append(offset + corner * size)
			norms.append(Mesher.FACE_NORMALS[f])
			uvs.append(Vector2(tiles[f] * uw + lerpf(0.01, 0.99, cuv.x) * uw, lerpf(0.01, 0.99, cuv.y)))
			cols.append(Color(sky, lamp, shade))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Builds a holdable model of an item, centered on its origin.
## on_top: draw over everything (for your own first-person hand, so it never
## pokes into walls).
static func item_model(id: String, size: float, on_top: bool) -> Node3D:
	var root := Node3D.new()
	var block := Items.block_of(id)
	if block >= 0 and Blocks.MODEL[block] == "":
		var mi := MeshInstance3D.new()
		mi.mesh = cube_mesh(block)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Blocks.get_atlas()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		if on_top:
			mat.no_depth_test = true
			mat.render_priority = 2
		mi.material_override = mat
		mi.scale = Vector3.ONE * size
		mi.position = Vector3.ONE * (-size * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		root.set_meta("material", mat)
	elif Items.get_def(id).has("bow") or Items.get_def(id).has("tool"):
		# Bows, tools and weapons are built as a solid little model from their picture (a flat
		# picture looks paper-thin when you hold it side-on).
		var mi := MeshInstance3D.new()
		mi.mesh = ToolModels.mesh(id, size) if ToolModels.has_model(id) else extruded_mesh(id, size)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if on_top:
			mat.no_depth_test = true
			mat.render_priority = 2
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		root.set_meta("material", mat)
		root.set_meta("gripped", true)
	elif not id.is_empty():
		var icon := Items.icon(id)  # torches, doors and beds are held as flat pictures
		var sprite := Sprite3D.new()
		sprite.texture = icon.atlas
		sprite.region_enabled = true
		sprite.region_rect = icon.region
		sprite.pixel_size = size / 16.0
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.double_sided = true
		sprite.shaded = false
		sprite.no_depth_test = on_top
		sprite.render_priority = 2 if on_top else 0
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Tools and weapons are held by the handle: put the grip pixel on the origin.
		var grip := grip_pixel(id)
		if grip.x >= 0:
			sprite.offset = Vector2(8.0 - grip.x - 0.5, grip.y + 0.5 - 8.0)
			root.set_meta("gripped", true)
		root.add_child(sprite)
		root.set_meta("sprite", sprite)
	return root


## An item's picture made solid: every pixel becomes a little block, BOW_DEPTH
## pixels thick, with darker sides. The grip pixel sits on the origin.
const BOW_DEPTH := 2.5
static var _extruded := {}

static func extruded_mesh(id: String, size: float) -> ArrayMesh:
	var key := "%s@%.3f" % [id, size]
	if _extruded.has(key):
		return _extruded[key]
	var icon := Items.icon(id)
	var img: Image = icon.atlas.get_image().get_region(Rect2i(icon.region))
	if img.is_compressed():
		img.decompress()
	var n := img.get_width()
	var px := size / n
	var grip := Vector2(grip_pixel(id)) * (n / 16.0) + Vector2(0.5, 0.5) * (n / 16.0)
	var depth := BOW_DEPTH * (n / 16.0) * px
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var solid := func(x: int, y: int) -> bool:
		if x < 0 or y < 0 or x >= n or y >= n:
			return false
		var pc := img.get_pixel(x, y)
		return pc.a > 0.5 and pc.get_luminance() > 0.12   # (skip the picture's dark outline)
	for y in n:
		for x in n:
			if not solid.call(x, y):
				continue
			var c := img.get_pixel(x, y)
			var x0 := (x - grip.x) * px
			var y0 := (grip.y - y - 1) * px
			# [normal, neighbour that hides this face, shade]
			for f in [[Vector3(0, 0, 1), Vector2i(-99, 0), 1.0], [Vector3(0, 0, -1), Vector2i(-99, 0), 0.9],
					[Vector3(1, 0, 0), Vector2i(1, 0), 0.7], [Vector3(-1, 0, 0), Vector2i(-1, 0), 0.7],
					[Vector3(0, 1, 0), Vector2i(0, -1), 0.85], [Vector3(0, -1, 0), Vector2i(0, 1), 0.6]]:
				var nb: Vector2i = f[1]
				if nb.x != -99 and solid.call(x + nb.x, y + nb.y):
					continue
				var nrm: Vector3 = f[0]
				var shade: float = f[2]
				var corners := _face_quad(nrm, Vector3(x0, y0, -depth * 0.5), Vector3(px, px, depth))
				var base := verts.size()
				for q in corners:
					verts.append(q)
					cols.append(Color(c.r * shade, c.g * shade, c.b * shade))
				idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_extruded[key] = mesh
	return mesh


## The 4 corners of one face of a box (clockwise from outside, Godot's winding).
static func _face_quad(n: Vector3, o: Vector3, s: Vector3) -> Array:
	var a := o
	var b := o + s
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


## Where your hand holds a tool, in its 16x16 icon (x right, y down). (-1,-1) = not a tool.
## All tool icons lean the same way: handle at the bottom left, head at the top right.
static func grip_pixel(id: String) -> Vector2i:
	var d := Items.get_def(id)
	if d.has("tool"):
		return Vector2i(3, 12)
	if d.has("bow"):
		return Vector2i(10, 4)   # the grip wrap in the middle of the bow
	return Vector2i(-1, -1)


## Darkens a held-item model to match how bright it is where you're standing.
static func set_model_brightness(model: Node3D, b: float) -> void:
	var c := Color(b, b, b)
	if model.has_meta("material"):
		(model.get_meta("material") as StandardMaterial3D).albedo_color = c
	if model.has_meta("sprite"):
		(model.get_meta("sprite") as Sprite3D).modulate = c
