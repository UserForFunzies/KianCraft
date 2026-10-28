extends Node3D
## Little visual effects: blocks bursting into bits when broken, and a puff
## when a block is placed. Runs on every computer (it reacts to block changes
## arriving from the server), so everyone sees everyone's mining.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Sound = preload("res://scripts/sound.gd")

var _colors := {}
var particle_scale := 1.0      # from the graphics setting
var world: Node


func _world_block(p: Vector3i) -> int:
	return world.get_block(p) if world else 0


func on_block_changed(pos: Vector3i, old_block: int, new_block: int) -> void:
	var center := Vector3(pos) + Vector3(0.5, 0.5, 0.5)
	if Blocks.same_door(old_block, new_block):
		# A door opening or closing isn't breaking anything. Only the bottom half plays a sound.
		if not Blocks.same_door(_world_block(pos + Vector3i.DOWN), new_block):
			Sound.play_at("door_open" if Blocks.is_open_door(new_block) else "door_close", center, -4.0,
					0.75 if Sound.material_of(new_block) == "metal" else 1.0)
		return
	if Blocks.is_targetable(old_block) and not Blocks.is_targetable(new_block):
		Sound.play_at("break_" + Sound.material_of(old_block), center, -3.0)
	elif Blocks.is_targetable(new_block) and not Blocks.is_targetable(old_block):
		Sound.play_at("place_" + Sound.material_of(new_block), center, -5.0)
	if Blocks.is_targetable(old_block) and not Blocks.is_targetable(new_block):
		_burst(Vector3(pos) + Vector3(0.5, 0.5, 0.5), _color(old_block), 18, 4.0)
	elif Blocks.is_targetable(new_block) and not Blocks.is_targetable(old_block):
		_burst(Vector3(pos) + Vector3(0.5, 0.5, 0.5), _color(new_block).lightened(0.2), 6, 1.5)


func _color(block: int) -> Color:
	if not _colors.has(block):
		_colors[block] = Items.average_color(block)
	return _colors[block]


func _burst(at: Vector3, color: Color, amount: int, speed: float) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	p.amount = maxi(2, int(amount * particle_scale))
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3.ONE * 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -20, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, color.lightened(0.15))
	grad.set_color(1, color.darkened(0.25))
	p.color_initial_ramp = grad
	p.position = at
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
