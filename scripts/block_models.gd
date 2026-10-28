extends Node3D
## Draws blocks that aren't plain cubes: torches, doors and beds.
## They only ever come from players, so we find them in the world's edit list
## and keep one small model per block, updated whenever a block changes.
## (Their collision boxes come from chunk_mesher.gd.)

const Blocks = preload("res://scripts/blocks.gd")
const Survival = preload("res://scripts/survival.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const Avatar = preload("res://scripts/avatar.gd")
const MapView = preload("res://scripts/map_view.gd")
const Items = preload("res://scripts/items.gd")

var survival: Node   # for what's in item frames and on armor stands

const DOOR_THICK := 0.1875

var world: Node
var _nodes := {}          # Vector3i -> Node3D
var _light := {}          # Vector3i -> Vector2(sun, lamp), from the chunk mesher
var _flames: Array[Node3D] = []
var _halos: Array[Sprite3D] = []
var _time := 0.0

static var _halo_tex: ImageTexture


## Drawn here (doors, torches, beds, and the glow around lamps). Plants
## ("cross") and the lamp block itself are part of the chunk mesh.
static func is_ours(b: int) -> bool:
	return (Blocks.MODEL[b] != "" and not Blocks.MODEL[b] in ["cross", "shape"]) or b == Blocks.LAMP or b == Blocks.PORTAL_LIT


func rebuild_all() -> void:
	clear()
	var types := []
	for b in Blocks.COUNT:
		if is_ours(b):
			types.append(b)
	for entry in world.find_edited(types):
		_make(entry[0], entry[1])


func clear() -> void:
	for n in _nodes.values():
		n.queue_free()
	_nodes.clear()
	_light.clear()
	_flames.clear()
	_halos.clear()


## The block here. Our blocks only ever come from players, so the edit list
## knows about them even before (or after) their chunk is loaded.
func _block(p: Vector3i) -> int:
	var b: int = world.get_edited_block(p)
	return b if b >= 0 else world.get_block(p)


func _remove(p: Vector3i) -> void:
	if _nodes.has(p):
		_nodes[p].queue_free()
		if _nodes[p].has_meta("flame"):
			_flames.erase(_nodes[p].get_meta("flame"))
		if _nodes[p].has_meta("halo"):
			_halos.erase(_nodes[p].get_meta("halo"))
		_nodes.erase(p)


## Redraw one model (its frame item or stand armor changed).
func refresh(pos: Vector3i) -> void:
	_remove(pos)
	var b: int = _block(pos)
	if is_ours(b):
		_make(pos, b)


func on_block_changed(pos: Vector3i, _old: int, _new: int) -> void:
	# Doors look at their neighbors (walls, the other half), so refresh those too.
	for off in [Vector3i.ZERO, Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		var p: Vector3i = pos + off
		_remove(p)
		var b: int = _block(p)
		if is_ours(b):
			_make(p, b)


## A chunk finished lighting: redo its models with the real light, and with
## the walls around them now loaded (old doors decide their direction from walls).
func on_models_lit(_key: Vector2i, lights: Dictionary) -> void:
	for p in lights:
		_light[p] = lights[p]
		var b: int = _block(p)
		_remove(p)
		if is_ours(b):
			_make(p, b)


func _process(delta: float) -> void:
	_time += delta
	for f in _flames:
		if is_instance_valid(f):
			var k := 1.0 + sin(_time * 17.0 + f.position.x * 3.0) * 0.08 + sin(_time * 7.0) * 0.05
			f.scale = Vector3(k, k * 1.1, k)
	# Glows are soft by day and bright at night (and gently breathe).
	var night := 1.0 - clampf(world.daylight if world else 1.0, 0.0, 1.0)
	for h in _halos:
		if is_instance_valid(h):
			var flicker := 1.0 + sin(_time * (9.0 if h.get_meta("torch", false) else 1.6) + h.global_position.x) * 0.06
			var a: float = h.get_meta("strength", 1.0) * lerpf(0.28, 0.85, night) * flicker
			h.modulate = Color(h.get_meta("tint", Color.WHITE), a)


## A round, soft spot of light (brightest in the middle, fading to nothing).
static func halo_texture() -> ImageTexture:
	if _halo_tex == null:
		var n := 64
		var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n / 2.0, n / 2.0)) / (n / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = a * a * (3.0 - 2.0 * a)  # smooth
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_halo_tex = ImageTexture.create_from_image(img)
	return _halo_tex


## A glowing halo that always faces the camera. Added on top (no shadows, no depth write).
func _add_halo(root: Node3D, at: Vector3, size: float, tint: Color, strength: float, torch := false) -> Sprite3D:
	var h := Sprite3D.new()
	h.texture = halo_texture()
	h.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	h.shaded = false
	h.double_sided = true
	h.transparent = true
	h.no_depth_test = false
	h.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	h.pixel_size = size / 64.0
	h.position = at
	h.render_priority = 2
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = h.texture
	mat.vertex_color_use_as_albedo = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	h.material_override = mat
	h.set_meta("tint", tint)
	h.set_meta("strength", strength)
	h.set_meta("torch", torch)
	root.add_child(h)
	_halos.append(h)
	root.set_meta("halo", h)
	return h


func _make(pos: Vector3i, b: int) -> void:
	var sky: float
	var lamp: float
	if _light.has(pos):
		# Real light from the chunk mesher, so a door in a wall under a roof
		# is as bright as the wall next to it.
		var l: Vector2 = _light[pos]
		sky = l.x
		lamp = l.y
	else:
		# Not lit yet (its chunk is still loading): a rough guess until it is.
		sky = 1.0 if world.sees_sky(pos) else 0.8
		lamp = clampf(world.lamp_light_at(pos) / 15.0, 0.0, 1.0)
	var root := Node3D.new()
	root.position = Vector3(pos)
	if b == Blocks.PORTAL_LIT:
		_add_halo(root, Vector3(0.5, 0.5, 0.5), 2.4, Color(0.8, 0.45, 1.0), 0.55)
		add_child(root)
		_nodes[pos] = root
		return
	if b == Blocks.LAMP:
		_add_halo(root, Vector3(0.5, 0.5, 0.5), 3.4, Color(1.0, 0.82, 0.5), 1.0)
		add_child(root)
		_nodes[pos] = root
		return
	match Blocks.MODEL[b]:
		"torch":
			_add_box(root, Vector3(0.125, 0.6, 0.125), Vector3(0.4375, 0, 0.4375),
					Blocks.T_LOG_SIDE, sky, maxf(lamp, 0.8))
			var flame := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.2, 0.22, 0.2)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(1.0, 0.75, 0.25)
			fm.material = mat
			flame.mesh = fm
			flame.position = Vector3(0.5, 0.7, 0.5)
			root.add_child(flame)
			var core := MeshInstance3D.new()
			var cm := BoxMesh.new()
			cm.size = Vector3(0.1, 0.12, 0.1)
			var cmat := StandardMaterial3D.new()
			cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cmat.albedo_color = Color(1.0, 0.98, 0.7)
			cm.material = cmat
			core.mesh = cm
			core.position = Vector3(0, -0.02, 0)
			flame.add_child(core)
			_flames.append(flame)
			root.set_meta("flame", flame)
			_add_halo(root, Vector3(0.5, 0.72, 0.5), 1.6, Color(1.0, 0.7, 0.35), 0.8, true)
		"bed":
			_make_bed(root, pos, b, sky, lamp)
		"door":
			_make_door(root, pos, b, sky, lamp)
		"frame":
			_make_frame(root, pos, sky, lamp)
		"stand":
			_make_stand(root, pos, sky, lamp)
		"statue":
			_make_statue(root, pos, sky, lamp)
		"campfire":
			_make_campfire(root, pos, sky, lamp)
		"bedroll":
			_make_bedroll(root, pos, sky, lamp)
	add_child(root)
	_nodes[pos] = root


## An item frame flat against the wall behind it, with its item (or a map
## picture) in front, and the item's written name underneath.
func _make_frame(root: Node3D, pos: Vector3i, sky: float, lamp: float) -> void:
	var turn = world.door_facing(pos)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.5, 0.5, 0.5)
	pivot.rotation.y = (int(turn) if turn != null else 0) * PI / 2.0
	root.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.box_mesh(Vector3(0.84, 0.84, 0.06), Vector3(-0.42, -0.42, 0.44), [Blocks.T_FRAME, Blocks.T_FRAME, Blocks.T_FRAME, Blocks.T_FRAME, Blocks.T_FRAME, Blocks.T_FRAME], sky, lamp)
	mi.material_override = world.get_solid_material()
	pivot.add_child(mi)
	var state: Dictionary = survival.frame_items.get(pos, {}) if survival else {}
	if state.is_empty():
		return
	var slot: Dictionary = state["slot"]
	var light := clampf(maxf(sky * (world.daylight if world else 1.0), lamp) + 0.15, 0.2, 1.0)
	if Items.is_map(slot["id"]) and state.has("mini"):
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.72, 0.72)
		q.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = MapView.mini_texture(world, state["mini"], state["c"])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_color = Color(light, light, light)
		q.material_override = mat
		q.position = Vector3(0, 0.02, 0.43)
		q.rotation.y = PI   # face out of the wall
		pivot.add_child(q)
	else:
		var model := ItemModels.item_model(slot["id"], 0.5 if Items.block_of(slot["id"]) < 0 else 0.3, false)
		model.position = Vector3(0, 0, 0.36)
		ItemModels.set_model_brightness(model, light)
		pivot.add_child(model)
	if slot.has("label"):
		var lab := Label3D.new()
		lab.text = slot["label"] + ("\nby " + str(slot["scribe"]) if slot.has("scribe") else "")
		lab.pixel_size = 0.0035
		lab.font_size = 36
		lab.outline_size = 10
		lab.modulate = Color(Items.get_def(str(slot.get("label_ink", "black_ink"))).get("liquid", Color.WHITE)).lightened(0.35)
		lab.position = Vector3(0, -0.36, 0.4)
		lab.rotation.y = PI
		pivot.add_child(lab)


## A shrine statue: a small stone copy of its boss, facing the middle of the
## shrine, with its name. Once its trophy is on it, it's in full color and glows.
func _make_statue(root: Node3D, pos: Vector3i, sky: float, lamp: float) -> void:
	var i: int = survival.statue_index(pos) if survival else -1
	var bosses: Array = preload("res://scripts/boss_data.gd").BOSSES
	var boss: Dictionary = bosses[i] if i >= 0 and i < bosses.size() else {}
	var placed: bool = not boss.is_empty() and survival.trophies.has(boss["id"])
	var light := clampf(maxf(sky * (world.daylight if world else 1.0), lamp) + 0.2, 0.25, 1.0)
	var base := MeshInstance3D.new()
	base.mesh = ItemModels.box_mesh(Vector3(0.9, 0.12, 0.9), Vector3(-0.45, 0, -0.45), [Blocks.T_CHISELED, Blocks.T_CHISELED, Blocks.T_CHISELED, Blocks.T_CHISELED, Blocks.T_CHISELED, Blocks.T_CHISELED], sky, lamp)
	base.material_override = world.get_solid_material()
	base.position = Vector3(0.5, 0, 0.5)
	root.add_child(base)
	var holder := Node3D.new()
	holder.position = Vector3(0.5, 0.12, 0.5)
	if survival and survival.shrine_center != Survival.NO_POS:
		var to_mid := Vector3(survival.shrine_center - pos)
		holder.rotation.y = atan2(-to_mid.x, -to_mid.z) + PI
	root.add_child(holder)
	var mdef: Dictionary = preload("res://scripts/mob_data.gd").get_def(boss.get("mob", ""))
	if mdef.has("parts"):
		var model: Node3D = preload("res://scripts/mob_data.gd").build_model(boss["mob"])["root"]
		var h: float = maxf(0.5, mdef.get("size", Vector2(1, 1)).y)
		var k := 1.1 / h
		model.scale = Vector3.ONE * k
		holder.add_child(model)
		if boss.has("mob2"):
			# A pair (the King & Queen) stand side by side.
			model.scale *= 0.8
			model.position.x = -0.2
			var second: Node3D = preload("res://scripts/mob_data.gd").build_model(boss["mob2"])["root"]
			second.scale = Vector3.ONE * k * 0.8
			second.position.x = 0.2
			holder.add_child(second)
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color(0.62, 0.62, 0.65) * Color(light, light, light)
		for mi in holder.find_children("*", "MeshInstance3D", true, false):
			if placed:
				var m := StandardMaterial3D.new()
				var src: Material = (mi as MeshInstance3D).get_active_material(0)
				m.albedo_color = (src as BaseMaterial3D).albedo_color if src is BaseMaterial3D else Color.WHITE
				m.emission_enabled = true
				m.emission = m.albedo_color * 0.25
				mi.material_override = m
			else:
				mi.material_override = stone
	else:
		# A boss that hasn't been found yet: a rough stone block with a question mark.
		var q := MeshInstance3D.new()
		q.mesh = ItemModels.box_mesh(Vector3(0.6, 0.8, 0.6), Vector3(-0.3, 0, -0.3), [Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE, Blocks.T_COBBLE], sky, lamp)
		q.material_override = world.get_solid_material()
		holder.add_child(q)
	if placed:
		_add_halo(root, Vector3(0.5, 0.7, 0.5), 1.4, boss["color"].lightened(0.3), 0.7, false)


## An armor stand: a stone base, a wooden pole and a wooden dummy wearing
## whatever armor (and cape) it was given.
func _make_stand(root: Node3D, pos: Vector3i, sky: float, lamp: float) -> void:
	var turn = world.door_facing(pos)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.5, 0, 0.5)
	pivot.rotation.y = (int(turn) if turn != null else 0) * PI / 2.0
	root.add_child(pivot)
	var base := MeshInstance3D.new()
	base.mesh = ItemModels.box_mesh(Vector3(0.8, 0.1, 0.8), Vector3(-0.4, 0, -0.4), [Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE, Blocks.T_STONE], sky, lamp)
	base.material_override = world.get_solid_material()
	pivot.add_child(base)
	var parts := Avatar.build(Avatar.default_look())
	var dummy: Node3D = parts["root"]
	var wood := Color(0.68, 0.52, 0.32) * clampf(maxf(sky, lamp) + 0.2, 0.3, 1.0)
	for m in _meshes(dummy):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(wood, 1.0)
		m.material_override = mat
	if parts.has("face"):
		parts["face"].visible = false
	var ids: Array = survival.stand_items.get(pos, []) if survival else []
	if not ids.is_empty():
		Avatar.set_armor(parts, ids)
	dummy.position = Vector3(0, 0.1, 0)
	pivot.add_child(dummy)


static func _meshes(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


## Half of a two-block bed: a wooden frame with legs, a solid mattress and
## blanket, and (on the pillow end) a headboard and pillow. Turned to face the
## way it was placed: the pillow end is "forward" (-Z before turning).
## A ring of stones, crossed logs and a flickering fire (with sparks).
func _make_campfire(root: Node3D, pos: Vector3i, sky: float, lamp: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.5, 0, 0.5)
	var f = world.door_facing(pos)
	pivot.rotation.y = (int(f) if f != null else 0) * PI / 2.0 + PI / 4.0
	root.add_child(pivot)
	for i in 8:
		var a := TAU * i / 8.0
		_add_box(pivot, Vector3(0.16, 0.12, 0.16), Vector3(cos(a) * 0.36 - 0.08, 0, sin(a) * 0.36 - 0.08),
				Blocks.T_COBBLE, sky, maxf(lamp, 0.6))
	for i in 3:
		var holder := Node3D.new()
		holder.rotation.y = i * PI / 3.0
		holder.position.y = 0.06 + i * 0.03
		pivot.add_child(holder)
		_add_box(holder, Vector3(0.7, 0.11, 0.11), Vector3(-0.35, 0, -0.055), Blocks.T_LOG_SIDE, sky, maxf(lamp, 0.7))
	var flames := Node3D.new()
	flames.position = Vector3(0.5, 0.18, 0.5)
	root.add_child(flames)
	for k in 3:
		var flame := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.3, 0.34, 0.3) * (1.0 - k * 0.25)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = [Color(1.0, 0.45, 0.12), Color(1.0, 0.72, 0.25), Color(1.0, 0.95, 0.65)][k]
		fm.material = mat
		flame.mesh = fm
		flame.position = Vector3(0, 0.12 + k * 0.06, 0)
		flame.rotation.y = k * 0.6
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.add_child(flame)
		_flames.append(flame)
	var sparks := CPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 1.4
	sparks.position = Vector3(0.5, 0.4, 0.5)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.15
	sparks.direction = Vector3.UP
	sparks.spread = 18.0
	sparks.gravity = Vector3(0, 0.6, 0)
	sparks.initial_velocity_min = 0.6
	sparks.initial_velocity_max = 1.2
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var sm := BoxMesh.new()
	sm.size = Vector3.ONE * 0.035
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(1.0, 0.7, 0.3)
	sm.material = smat
	sparks.mesh = sm
	root.add_child(sparks)
	_add_halo(root, Vector3(0.5, 0.45, 0.5), 2.8, Color(1.0, 0.62, 0.3), 1.0, true)


## A blanket rolled out on the ground, with a pillow at the head end.
func _make_bedroll(root: Node3D, pos: Vector3i, sky: float, lamp: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.5, 0, 0.5)
	var f = world.door_facing(pos)
	pivot.rotation.y = (int(f) if f != null else 0) * PI / 2.0
	root.add_child(pivot)
	_add_box(pivot, Vector3(0.7, 0.08, 0.96), Vector3(-0.35, 0, -0.48), Blocks.T_BEDROLL, sky, lamp)
	_add_box(pivot, Vector3(0.74, 0.16, 0.18), Vector3(-0.37, 0, 0.3), Blocks.T_BEDROLL, sky, lamp)   # the rolled-up end
	_add_box(pivot, Vector3(0.46, 0.1, 0.2), Vector3(-0.23, 0.08, -0.44), Blocks.T_BED_TOP, sky, lamp)   # pillow


func _make_bed(root: Node3D, pos: Vector3i, b: int, sky: float, lamp: float) -> void:
	var turn = world.door_facing(pos)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.5, 0, 0.5)
	pivot.rotation.y = (int(turn) if turn != null else 0) * PI / 2.0
	root.add_child(pivot)
	var head := b == Blocks.BED
	var wood := Blocks.T_PLANKS
	var parts := [
		[Vector3(1.0, 0.18, 1.0), Vector3(-0.5, 0.12, -0.5), wood],          # frame
		[Vector3(0.96, 0.26, 0.96), Vector3(-0.48, 0.3, -0.48), Blocks.T_BED_PILLOW if head else Blocks.T_BED_BLANKET],
	]
	for corner in [Vector2(-0.5, -0.5), Vector2(0.38, -0.5), Vector2(-0.5, 0.38), Vector2(0.38, 0.38)]:
		parts.append([Vector3(0.12, 0.14, 0.12), Vector3(corner.x, 0.0, corner.y), wood])   # legs
	if head:
		parts.append([Vector3(1.0, 0.85, 0.1), Vector3(-0.5, 0.0, -0.5), wood])            # headboard
	else:
		parts.append([Vector3(1.0, 0.5, 0.08), Vector3(-0.5, 0.0, 0.42), wood])            # footboard
	for prt in parts:
		var mi := MeshInstance3D.new()
		var t: int = prt[2]
		mi.mesh = ItemModels.box_mesh(prt[0], prt[1], [t, t, t, wood, t, t], sky, lamp)
		mi.material_override = world.get_solid_material()
		pivot.add_child(mi)


func _add_box(root: Node3D, size: Vector3, offset: Vector3, tile: int, sky: float, lamp: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.box_mesh(size, offset, [tile, tile, tile, tile, tile, tile], sky, lamp)
	mi.material_override = world.get_solid_material()
	root.add_child(mi)
	return mi


## Which way a closed door runs: along the wall it's set into. Both halves
## use the bottom block's surroundings (and the block above the top half), so
## the two halves always agree.
func door_along_x(bottom: Vector3i) -> bool:
	var stored = world.door_facing(bottom)
	if stored != null:
		return stored  # set when it was placed: it faces the player who placed it
	var x_walls := 0
	var z_walls := 0
	for y in [0, 1]:
		var p := bottom + Vector3i(0, y, 0)
		for off in [Vector3i.LEFT, Vector3i.RIGHT]:
			if _is_wall(_block(p + off)):
				x_walls += 1
		for off in [Vector3i.FORWARD, Vector3i.BACK]:
			if _is_wall(_block(p + off)):
				z_walls += 1
	return x_walls >= z_walls


func _is_wall(b: int) -> bool:
	return Blocks.is_solid(b) and not Blocks.is_door(b)


## A thin panel. It runs along whichever direction has walls beside it, and
## swings 90 degrees around its hinge when opened.
func _make_door(root: Node3D, pos: Vector3i, b: int, sky: float, lamp: float) -> void:
	# Which half is this? Ask the edit list, so it's right even while the
	# chunk is still loading (that used to make both halves think they
	# were the bottom, and draw out of step until the door was used).
	var is_top := Blocks.same_door(_block(pos + Vector3i.DOWN), b)
	var bottom := pos + (Vector3i.DOWN if is_top else Vector3i.ZERO)
	var tile: int = Blocks.FACE_TILES[b][1] + (1 if is_top else 0)
	var along_x := door_along_x(bottom)
	root.set_meta("along_x", along_x)
	root.set_meta("top", is_top)
	root.set_meta("open", Blocks.is_open_door(b))
	if Blocks.is_open_door(b):
		along_x = not along_x  # swung open, it now sits along the other edge
	var hinge := Node3D.new()
	root.add_child(hinge)
	var mi := MeshInstance3D.new()
	var t := DOOR_THICK
	var face := [tile, tile, tile, tile, tile, tile]
	if along_x:
		var z := 0.5 - t * 0.5 if not Blocks.is_open_door(b) else 0.0
		mi.mesh = ItemModels.box_mesh(Vector3(1, 1, t), Vector3(0, 0, z), face, sky, lamp)
	else:
		var x := 0.5 - t * 0.5 if not Blocks.is_open_door(b) else 0.0
		mi.mesh = ItemModels.box_mesh(Vector3(t, 1, 1), Vector3(x, 0, 0), face, sky, lamp)
	mi.material_override = world.get_solid_material()
	hinge.add_child(mi)
