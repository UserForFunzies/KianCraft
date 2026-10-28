extends CharacterBody3D
## A player. The same script is used for you and for other people:
## - The *local* player (the one this computer controls) reads input, moves with
##   physics, mines/places/attacks (by asking the server via survival.gd) and
##   sends its position to everyone else.
## - *Remote* players are just puppets that smoothly follow received positions.
## Which one it is depends on the node's multiplayer authority (set by main.gd).

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Inv = preload("res://scripts/inventory.gd")
const Survival = preload("res://scripts/survival.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const CrackShader = preload("res://shaders/crack.gdshader")
const MobData = preload("res://scripts/mob_data.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Settings = preload("res://scripts/settings.gd")
const Sound = preload("res://scripts/sound.gd")
const SKIN := Color(0.95, 0.8, 0.65)

signal hotbar_changed(index: int)
signal interact_block(block: int, pos: Vector3i)   # right-clicked a workbench/furnace/shop
signal interact_loot(id: int)                      # right-clicked a corpse or bag
signal interact_npc                                # right-clicked QtMaMe
signal interact_villager(mob_id: int)              # right-clicked a villager
signal interact_player(peer: int)                  # right-clicked another player (trade)
signal interact_fairy(mob_id: int)                 # right-clicked a fairy
signal open_map(slot: int)                         # right-clicked while holding a map

var drawing := false        # pulling a bow back
var draw_charge := 0.0      # 0..1, how far it's pulled
var _draw_time := 0.0
var _base_fov := -1.0

const WALK_SPEED := 4.3
const SPRINT_SPEED := 6.0
const SNEAK_SPEED := 1.6
const JUMP_VELOCITY := 8.4     # ~1.25 blocks high
const GRAVITY := 28.0
const MAX_FALL_SPEED := 50.0
const REACH := 5.5
const ATTACK_REACH := 3.5
const MOUSE_SENSITIVITY := 0.0025
const EYE_HEIGHT := 1.62
const PLACE_REPEAT := 0.25     # seconds between places while holding the mouse
const ATTACK_COOLDOWN := 0.45
const SAFE_FALL := 3.5         # blocks you can fall without getting hurt
const SYNC_INTERVAL := 0.05    # send position 20x per second
const INFO_INTERVAL := 1.0     # resend name every second (late joiners get it too)

var world: Node              # set by main.gd before the player is added
var survival: Node           # set by main.gd
var mobs: Node               # set by main.gd
var display_name := "Player"
var hotbar_index := 0
var input_enabled := true    # main.gd turns this off while menus are open
var alive := true
var spawn_point := Vector3.ZERO
var break_progress := 0.0    # 0..1 while mining (shown as cracks on the block)
var look_info := {}          # what's under the crosshair, for the HUD's hint text
var held_id := ""            # item in your hand (for remote players: what they hold)
var sleeping := false
var fly_mode := false        # (host command) fly around
var noclip_mode := false     # (host command) fly through walls
var frozen := false          # (host command) can't move
var shirt_color := Color.WHITE
var skin_color := SKIN
var look := {}               # how this character looks (see avatar.gd); set before adding
var _armor_ids := ["", "", "", "", "", "", ""]

var _head: Node3D
var _camera: Camera3D
var _highlight: MeshInstance3D
var _name_label: Label3D
var _place_cooldown := 0.0
var _attack_cooldown := 0.0
const NAME_RANGE := 40.0      # how far away you can read someone's name (party: 200)
var test_input := false       # headless tests can't capture the mouse; this stands in for it
var _break_was_down := false
var _wheel := 0.0             # scroll built up toward the next hotbar slot
var _wheel_time := 0
const WHEEL_GAP_MS := 45
var _step_smooth := 0.0       # the camera eases up after stepping onto a stair
var _fov_kick := 0.0          # 0..1: the view widens a little while sprinting
var _land_dip := 0.0          # 0..1: the camera dips when you land from a fall
var _mining_pos := Vector3i(0, -1, 0)
var _mining_time := 0.0
var _fall_start := 0.0
var _was_on_floor := true
var _sync_timer := 0.0
var _info_timer := 0.0
var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0

# First-person hand (local player) and third-person arm (everyone else).
var _view_root: Node3D
var _hand: MeshInstance3D
var _hand_mat: StandardMaterial3D
var _sleeve_mat: StandardMaterial3D
var _view_item: Node3D
var _crack: MeshInstance3D
var _crack_mat: ShaderMaterial
var _arm_pivot: Node3D
var _arm_item: Node3D
var _av: Dictionary          # avatar parts (see avatar.gd)
var _walk_time := 0.0
var _swing_t := -1.0         # 0..1 while swinging
var _equip_t := 0.0          # 1 -> 0 while bringing a new item up
var _bob := 0.0
var _light_timer := 0.0
var _brightness := 1.0
var _shown_id := "<none>"
var _step_dist := 0.0         # distance walked since the last footstep sound
var _was_in_water := false


func _ready() -> void:
	# Players live on physics layer 2 and only collide with the terrain (layer 1),
	# so they walk through each other instead of stacking up.
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	shape.shape = box
	shape.position.y = 0.9  # the node's origin is at the player's feet
	add_child(shape)

	_head = Node3D.new()
	_head.position.y = EYE_HEIGHT
	add_child(_head)

	_build_avatar()

	if is_multiplayer_authority():
		_camera = Camera3D.new()
		_camera.fov = 75.0
		_camera.near = 0.05
		_camera.far = 1000.0
		_head.add_child(_camera)
		_camera.current = true
		_highlight = _make_highlight()
		add_child(_highlight)
		_build_view_model()
		_build_crack()
		spawn_point = global_position
	_target_position = global_position
	_target_yaw = rotation.y
	_fall_start = global_position.y


## A blocky body so other players can see you (hidden for yourself).
func _build_avatar() -> void:
	if look.is_empty():
		look = Avatar.default_look(posmod(get_multiplayer_authority(), Avatar.COLORS.size()))
	look = Avatar.clean_look(look)
	shirt_color = Avatar.shirt_color(look)
	skin_color = Avatar.skin_color(look)
	_av = Avatar.build(look, _head)
	add_child(_av["root"])
	_arm_pivot = _av["arm_r"]
	if _name_label:
		return  # rebuilding after a look change: the name tag is already there

	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.pixel_size = 0.006
	_name_label.font_size = 48
	_name_label.outline_size = 12
	_name_label.position.y = 2.15
	_name_label.visibility_range_end = NAME_RANGE
	add_child(_name_label)

	if is_multiplayer_authority():
		_av["root"].visible = false
		_av["face"].visible = false
		_name_label.visible = false


## Changes how this player looks (new character, or a friend's look arriving).
func set_look(new_look: Dictionary) -> void:
	new_look = Avatar.clean_look(new_look)
	if new_look == look and _av.has("root"):
		return
	look = new_look
	if _av.has("root"):
		_av["root"].queue_free()
		_av["face"].queue_free()
	_build_avatar()
	if is_multiplayer_authority():
		_av["root"].visible = false
		_av["face"].visible = false
		if _sleeve_mat:
			_sleeve_mat.albedo_color = shirt_color
	_arm_item = null
	_shown_id = "<none>"
	set_armor(_armor_ids)


## Shows armor on this player's body: ids for [head, chest, legs, feet].
func set_armor(ids: Array) -> void:
	_armor_ids = ids.duplicate()
	Avatar.set_armor(_av, ids)
	if is_multiplayer_authority():
		for slot in ["head", "chest", "legs", "feet", "back", "neck"]:
			for n in _av.get("armor_" + slot, []):
				n.visible = false  # you don't see your own helmet from inside it


## Your own hand, in the bottom-right of the screen. Drawn on top of
## everything so it never pokes into walls.
func _build_view_model() -> void:
	_view_root = Node3D.new()
	_camera.add_child(_view_root)
	# Sleeve, then forearm and hand, pointing into the screen.
	_hand_mat = StandardMaterial3D.new()
	_hand_mat.albedo_color = skin_color
	_hand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hand_mat.no_depth_test = true
	_hand_mat.render_priority = 1
	_sleeve_mat = _hand_mat.duplicate()
	_sleeve_mat.albedo_color = shirt_color
	_hand = _view_box(Vector3(0.1, 0.1, 0.24), Vector3(0, 0, -0.02), _hand_mat)
	_view_box(Vector3(0.12, 0.12, 0.22), Vector3(0, 0, 0.2), _sleeve_mat)
	_view_box(Vector3(0.124, 0.124, 0.03), Vector3(0, 0, 0.09), _sleeve_mat).set_meta("cuff", true)


func _view_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view_root.add_child(mi)
	return mi


func _build_crack() -> void:
	_crack = MeshInstance3D.new()
	_crack.mesh = ItemModels.cube_mesh(Blocks.STONE, false)
	_crack_mat = ShaderMaterial.new()
	_crack_mat.shader = CrackShader
	_crack_mat.set_shader_parameter("cracks", Items.crack_texture())
	_crack.material_override = _crack_mat
	_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack.top_level = true
	_crack.visible = false
	add_child(_crack)


## Swaps the model in your hand (first person) or this player's arm (third person).
func _show_held(id: String) -> void:
	if id == _shown_id:
		return
	_shown_id = id
	if _view_root:
		if _view_item:
			_view_item.queue_free()
		_view_item = ItemModels.item_model(id, 0.2 if Items.block_of(id) >= 0 else (0.3 if Items.get_def(id).has("tool") else 0.42), true)
		if Items.block_of(id) >= 0:
			_view_item.position = Vector3(-0.02, 0.08, -0.16)
			_view_item.rotation = Vector3(0.25, 0.75, 0.0)
		elif Items.get_def(id).has("bow"):
			# A bow stands up in your fist: string straight up and down toward you,
			# the curved limb bowing out forward (and a little right, so you can see its shape).
			_view_item.position = Vector3(-0.03, 0.05, -0.1)
			_view_item.rotation = Vector3(deg_to_rad(-5), deg_to_rad(5), deg_to_rad(-30))   # turned toward you so you see its curve
		elif _view_item.has_meta("gripped"):
			# Held by the handle, right in the fist, head up and a little forward.
			_view_item.position = Vector3(-0.005, 0.02, -0.12)
			_view_item.rotation = Vector3(0.0, deg_to_rad(-80), deg_to_rad(20))
		else:
			_view_item.position = Vector3(-0.04, 0.14, -0.14)
			_view_item.rotation = Vector3(0.0, deg_to_rad(-80), deg_to_rad(30))
		_view_root.add_child(_view_item)
		_equip_t = 1.0
		ItemModels.set_model_brightness(_view_item, _brightness)
	if _arm_pivot:
		if _arm_item:
			_arm_item.queue_free()
		_arm_item = ItemModels.item_model(id, 0.25 if Items.block_of(id) >= 0 else 0.5, false)
		_arm_item.position = Vector3(0, -0.66, -0.14 if Items.block_of(id) >= 0 else (-0.04 if _arm_item.has_meta("gripped") else -0.22))
		_arm_item.rotation = Vector3(deg_to_rad(-90), 0, 0) if Items.block_of(id) < 0 else Vector3.ZERO
		if Items.get_def(id).has("bow"):
			_arm_item.rotation = Vector3(0.0, deg_to_rad(90), deg_to_rad(-45))   # upright, limb pointing forward
		_arm_pivot.add_child(_arm_item)


## Start a swing (mining hit, attack, placing, eating). Others see it too.
func swing() -> void:
	if _swing_t < 0.0 or _swing_t > 0.6:
		_swing_t = 0.0
		if is_multiplayer_authority():
			Sound.play("swing", -12.0, randf_range(0.9, 1.1))
	if is_multiplayer_authority() and not multiplayer.get_peers().is_empty():
		_receive_swing.rpc()


func _animate(delta: float, moving: bool) -> void:
	var swing_amount := 0.0
	if _swing_t >= 0.0:
		_swing_t += delta / 0.28
		swing_amount = sin(clampf(_swing_t, 0.0, 1.0) * PI)
		if _swing_t >= 1.0:
			_swing_t = -1.0
	_equip_t = maxf(0.0, _equip_t - delta / 0.18)
	if _view_root:
		if moving:
			_bob += delta * 9.0
		else:
			_bob += delta * 1.6  # a slow breathing sway when standing still
		var bob := Vector3(sin(_bob) * 0.012, -absf(cos(_bob)) * 0.016, 0.0) if moving \
				else Vector3(0.0, sin(_bob) * 0.004, 0.0)
		# A chop: a quick wind-up (raise and lean back), then a strike forward
		# and down toward the crosshair, then an easy return.
		var t := clampf(_swing_t, 0.0, 1.0) if _swing_t >= 0.0 else 0.0
		var wind := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.18, 0.38, t))
		var strike := smoothstep(0.18, 0.45, t) * (1.0 - smoothstep(0.55, 1.0, t))
		_view_root.position = Vector3(0.36, -0.32 - _equip_t * 0.35, -0.5) + bob \
				+ Vector3(0.02, 0.05, 0.04) * wind + Vector3(-0.15, -0.06, -0.14) * strike
		_view_root.rotation = Vector3(-0.15 + wind * 0.45 - strike * 1.05, 0.12 + strike * 0.5, -strike * 0.25)
		if drawing:
			# Bow raised to the middle of the screen, pulled back (with a shake at full pull).
			var shake := sin(Time.get_ticks_msec() * 0.05) * 0.003 * draw_charge * draw_charge
			_view_root.position = Vector3(0.2, -0.24 + shake, -0.45 + 0.12 * draw_charge)
			_view_root.rotation = Vector3(0.05, 0.3, 0.35)
	if moving:
		_walk_time += delta
	if not is_multiplayer_authority():
		Avatar.animate(_av, _walk_time, moving, swing_amount, _shown_id != "")


func _update_brightness() -> void:
	# Roughly how bright it is where your head is (sunlight * time of day, or lamps).
	var head := Vector3i(floori(_camera.global_position.x), floori(_camera.global_position.y), floori(_camera.global_position.z))
	var sky: float = world.daylight if world.sees_sky(head) else 0.0
	var lamp: float = world.lamp_light_at(head) / 15.0
	_brightness = clampf(maxf(maxf(sky, lamp), 0.18), 0.0, 1.0)
	_hand_mat.albedo_color = Color(skin_color * _brightness, 1.0)
	_sleeve_mat.albedo_color = Color(shirt_color * _brightness, 1.0)
	if _view_item:
		ItemModels.set_model_brightness(_view_item, _brightness)


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	return mi


## Black outline drawn around the block you're looking at.
func _make_highlight() -> MeshInstance3D:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0, 0, 0)
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var a := -0.002
	var b := 1.002
	var corners := [
		Vector3(a, a, a), Vector3(b, a, a), Vector3(b, a, b), Vector3(a, a, b),
		Vector3(a, b, a), Vector3(b, b, a), Vector3(b, b, b), Vector3(a, b, b),
	]
	for e in [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4],
			[0, 4], [1, 5], [2, 6], [3, 7]]:
		im.surface_add_vertex(corners[e[0]])
		im.surface_add_vertex(corners[e[1]])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.top_level = true  # positioned in world space, not relative to the player
	mi.visible = false
	return mi


# --- Input ---------------------------------------------------------------------

func _can_act() -> bool:
	return input_enabled and alive and not frozen and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_input)


## Can I hit other players right now? (The world's PvP rule.)
func _pvp() -> bool:
	return survival != null and survival.main != null and survival.main.pvp_active()


## A quick red flash when someone hits this player (PvP).
func flash_hit() -> void:
	if not _av.has("root"):
		return
	var t := create_tween()
	_av["root"].scale = Vector3.ONE * 1.04
	t.tween_property(_av["root"], "scale", Vector3.ONE, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or not _can_act():
		return
	if event is InputEventMouseMotion:
		var sens := MOUSE_SENSITIVITY * Settings.mouse_sensitivity
		rotate_y(-event.relative.x * sens)
		_head.rotation.x = clampf(_head.rotation.x - event.relative.y * sens, -1.55, 1.55)
	elif event is InputEventMouseButton and event.pressed:
		# One slot per wheel "click": smooth wheels and touchpads send lots of
		# tiny scrolls, so add them up, and don't skip more than one at a time.
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var amount: float = event.factor if event.factor > 0.0 else 1.0
			_wheel += amount * (-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)
			var now := Time.get_ticks_msec()
			if absf(_wheel) >= 1.0 and now - _wheel_time >= WHEEL_GAP_MS:
				_wheel_time = now
				select_slot(posmod(hotbar_index + (1 if _wheel > 0.0 else -1), Inv.HOTBAR_SIZE))
				_wheel = 0.0
	elif event.is_action_pressed("drop"):
		# Q drops one, Ctrl+Q drops the whole stack.
		if not held_item().is_empty():
			swing()
			var all: bool = event is InputEventKey and event.ctrl_pressed
			survival.req_drop.rpc_id(1, "inv", hotbar_index, 0 if all else 1, -_camera.global_basis.z)
	else:
		for i in Inv.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				select_slot(i)


func select_slot(i: int) -> void:
	hotbar_index = i
	_mining_time = 0.0
	hotbar_changed.emit(i)


func held_item() -> Dictionary:
	return survival.my_slot(hotbar_index) if survival else {}


func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		# Remote player: glide toward the latest received position.
		var k := minf(1.0, delta * 15.0)
		global_position = global_position.lerp(_target_position, k)
		var before := global_position
		var moved := global_position.distance_to(_target_position) > 0.02
		rotation.y = lerp_angle(rotation.y, _target_yaw, k)
		_head.rotation.x = lerp_angle(_head.rotation.x, _target_pitch, k)
		_show_held(held_id)
		_animate(delta, moved)
		var step := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_footsteps(step, absf(global_position.y - before.y) < 0.05 and moved)
		return
	if world == null or not world.running:
		return
	_place_cooldown -= delta
	_attack_cooldown -= delta
	var now_held: String = held_item().get("id", "")
	if now_held != held_id:
		held_id = now_held
		if not multiplayer.get_peers().is_empty():
			_receive_held.rpc(held_id)
	_show_held(held_id)
	_animate(delta, is_on_floor() and Vector2(velocity.x, velocity.z).length() > 1.0)
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.25
		_update_brightness()

	var origin := _camera.global_position
	var dir := -_camera.global_basis.z
	var hit: Dictionary = world.raycast(origin, dir, REACH)
	var block_dist: float = (Vector3(hit["position"]) + Vector3(0.5, 0.5, 0.5)).distance_to(origin) if hit.get("hit", false) else INF
	var mob := _pick_mob(origin, dir, minf(REACH, block_dist))
	var loot_id := _pick_loot(origin, dir, minf(REACH, block_dist))
	var other := _pick_player(origin, dir, minf(REACH, block_dist))
	if mob != null and not mob.is_friendly_npc() and origin.distance_to(mob.position) > ATTACK_REACH + mob.half_width():
		mob = null  # too far to hit (but you can still talk to QtMaMe or a fairy from a bit further)

	_highlight.visible = hit.get("hit", false) and mob == null and loot_id < 0 and other == null
	if _highlight.visible:
		_highlight.global_position = Vector3(hit["position"])
	_update_look_info(hit, mob, loot_id, other)

	if not _can_act():
		_reset_mining()
		_crack.visible = false
		_stop_drawing()
		return

	# Left mouse: attack a mob, or mine the block you're looking at.
	if Input.is_action_pressed("break"):
		if mob != null and not mob.is_friendly_npc():
			_reset_mining()
			if _attack_cooldown <= 0.0:
				_attack_cooldown = ATTACK_COOLDOWN / (1.0 + _buff("haste"))
				swing()
				survival.req_attack.rpc_id(1, mob.mob_id, hotbar_index)
		elif other != null and _pvp() and origin.distance_to(other.global_position + Vector3(0, 1.0, 0)) <= ATTACK_REACH + 0.6:
			_reset_mining()
			if _attack_cooldown <= 0.0:
				_attack_cooldown = ATTACK_COOLDOWN / (1.0 + _buff("haste"))
				swing()
				survival.req_attack_player.rpc_id(1, int(str(other.name)), hotbar_index)
		elif _highlight.visible:
			_mine(hit, delta)
		else:
			_reset_mining()
			# Nothing in reach: still swing (it just whooshes through the air).
			if not _break_was_down and _attack_cooldown <= 0.0 and not Items.get_def(held_item().get("id", "")).has("bow"):
				_attack_cooldown = ATTACK_COOLDOWN / (1.0 + _buff("haste"))
				swing()
	else:
		_reset_mining()
	_break_was_down = Input.is_action_pressed("break")

	# Right mouse: open loot/workbench/furnace/shop, eat, or place a block.
	if Input.is_action_just_pressed("place") or (Input.is_action_pressed("place") and _place_cooldown <= 0.0):
		var first := Input.is_action_just_pressed("place")
		_place_cooldown = PLACE_REPEAT
		var sneaking := Input.is_action_pressed("descend")
		var held := held_item()
		if first and loot_id >= 0:
			interact_loot.emit(loot_id)
		elif first and mob != null and mob.is_fairy():
			interact_fairy.emit(mob.mob_id)
		elif first and mob != null and mob.def["kind"] == "villager":
			interact_villager.emit(mob.mob_id)
		elif first and mob != null and mob.def["kind"] == "npc":
			interact_npc.emit()
		elif first and other != null:
			interact_player.emit(int(str(other.name)))
		elif first and _highlight.visible and Blocks.is_interactive(hit["block"]) and not sneaking:
			interact_block.emit(hit["block"], hit["position"])
		elif first and Items.get_def(held.get("id", "")).has("bow"):
			drawing = true
			_draw_time = 0.0
		elif first and Items.get_def(held.get("id", "")).has("food"):
			swing()
			Sound.play("eat", -6.0, randf_range(0.9, 1.1))
			survival.req_use.rpc_id(1, hotbar_index)
		elif first and Items.is_map(held.get("id", "")):
			open_map.emit(hotbar_index)
		elif first and held.get("id", "") in ["glass_bottle", "bucket"]:
			var wpos: Vector3i = world.raycast_water(origin, dir, REACH)
			if wpos.y >= 0:
				swing()
				Sound.play_at("splash", Vector3(wpos), -8.0)
				survival.req_fill.rpc_id(1, wpos, hotbar_index)
		elif first and held.get("id", "") in ["water_bucket", "lava_bucket"] and hit.get("hit", false):
			var wt: Vector3i = hit["position"] + hit["normal"]
			if Blocks.REPLACE[hit["block"]]:
				wt = hit["position"]
			swing()
			Sound.play_at("splash", Vector3(wt), -6.0)
			survival.req_pour.rpc_id(1, wt, hotbar_index)
		elif hit.get("hit", false) and Items.block_of(held.get("id", "")) >= 0:
			var target: Vector3i = hit["position"] + hit["normal"]
			if Blocks.REPLACE[hit["block"]]:
				target = hit["position"]  # building on tall grass just squashes it
			var placing := Items.block_of(held.get("id", ""))
			if Blocks.is_replaceable(world.get_block(target)) and (not Blocks.is_solid(placing) or not _overlaps_any_player(target)):
				swing()
				var n: Vector3i = hit["normal"]
				var axis := "x" if n.x != 0 else ("z" if n.z != 0 else "y")
				if Blocks.SHAPE[placing] != "":
					axis = "top" if _aim_high(hit, origin, dir) else "bottom"
				if placing == Blocks.ITEM_FRAME:
					var dirs := [Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)]
					axis = "n%d" % dirs.find(n) if n.y == 0 else "floor"
				survival.req_place.rpc_id(1, target, hotbar_index, axis)

	_update_bow(delta)

	# Cracks on the block being mined.
	_crack.visible = break_progress > 0.0 and _highlight.visible
	if _crack.visible:
		_crack.global_position = Vector3(_mining_pos) - Vector3.ONE * 0.003
		_crack.scale = Vector3.ONE * 1.006
		_crack_mat.set_shader_parameter("progress", break_progress)

	# Middle mouse: pick the hotbar slot holding the block you're looking at.
	if Input.is_action_just_pressed("pick") and hit.get("hit", false):
		var want: String = Blocks.DROP[hit["block"]]
		for i in Inv.HOTBAR_SIZE:
			if survival.my_slot(i).get("id", "") == want:
				select_slot(i)
				break


## Slabs and stairs go upside down (in the top half) when you click the
## underside of a block, or the top half of a block's side.
func _aim_high(hit: Dictionary, origin: Vector3, dir: Vector3) -> bool:
	var n: Vector3i = hit["normal"]
	if n.y < 0:
		return true
	if n.y > 0:
		return false
	var p: Vector3i = hit["position"]
	var axis := 0 if n.x != 0 else 2
	var plane: float = float(p[axis]) + (1.0 if n[axis] > 0 else 0.0)
	if absf(dir[axis]) < 0.0001:
		return false
	var t: float = (plane - origin[axis]) / dir[axis]
	var at := origin + dir * t
	return at.y - floorf(at.y) > 0.5


## Hold right-click with a bow to pull it back, let go to shoot.
func _update_bow(delta: float) -> void:
	if not drawing:
		return
	var bow := Items.get_def(held_item().get("id", ""))
	if not bow.has("bow"):
		_stop_drawing()
		return
	if Input.is_action_pressed("place"):
		_draw_time += delta
		draw_charge = clampf(_draw_time / float(bow["draw"]), 0.0, 1.0)
		if _base_fov < 0.0:
			_base_fov = _camera.fov
		_camera.fov = _base_fov - 9.0 * draw_charge   # a little zoom while aiming
		return
	if draw_charge >= 0.15:
		survival.req_shoot.rpc_id(1, hotbar_index, _camera.global_position, -_camera.global_basis.z, draw_charge)
		Sound.play("swing", -8.0, 1.4)
	_stop_drawing()


func _stop_drawing() -> void:
	drawing = false
	draw_charge = 0.0
	_draw_time = 0.0
	if _base_fov > 0.0:
		_camera.fov = _base_fov
		_base_fov = -1.0


func _mine(hit: Dictionary, delta: float) -> void:
	var pos: Vector3i = hit["position"]
	if pos != _mining_pos:
		_mining_pos = pos
		_mining_time = 0.0
	var tool := Items.get_def(held_item().get("id", ""))
	var needed := Survival.break_time(hit["block"], tool) / (1.0 + _buff("haste")) / Survival.cute_bonus(held_item()) / Survival.quality(held_item())
	if needed == INF:
		break_progress = 0.0
		if _swing_t < 0.0 and _mining_time == 0.0:
			swing()
		if _mining_time == 0.0:
			_mining_time = -1.0  # tell the server once so it explains why
			survival.req_break.rpc_id(1, pos, hotbar_index)
		return
	_mining_time = maxf(_mining_time, 0.0) + delta
	break_progress = clampf(_mining_time / maxf(needed, 0.001), 0.0, 1.0)
	if _swing_t < 0.0:
		swing()  # keep chopping while you hold the button
		Sound.play_at("dig_" + Sound.material_of(hit["block"]), Vector3(pos) + Vector3(0.5, 0.5, 0.5), -6.0)
	if _mining_time >= needed:
		survival.req_break.rpc_id(1, pos, hotbar_index)
		_mining_time = 0.0
		_mining_pos = Vector3i(0, -1, 0)
		break_progress = 0.0


## What's under the crosshair, in words, so the HUD can show a friendly hint.
func _update_look_info(hit: Dictionary, mob: Node3D, loot_id: int, other: Node3D) -> void:
	var held := held_item()
	var hurt: bool = survival.me.get("health", 20.0) < 20.0
	if loot_id >= 0:
		look_info = {"title": "Loot", "hint": "Right-click to look inside"}
	elif other != null:
		look_info = {"title": other.display_name, "hint": "Left-click to attack  ·  Right-click to trade" if _pvp() else "Right-click to trade", "danger": _pvp()}
	elif mob != null and mob.is_fairy():
		var c: int = mob.variant.get("color", 0)
		var b: float = mob.variant.get("bright", 0.7)
		look_info = {"title": "%s %s Fairy" % [MobData.brightness_name(b), MobData.FAIRY_COLORS[c][0]],
				"hint": "%s. Right-click to make friends!" % MobData.fairy_text(c, b)}
	elif mob != null and mob.def["kind"] == "villager":
		look_info = {"title": MobData.display_name(mob.type), "hint": "Right-click to trade"}
	elif mob != null and mob.def["kind"] == "npc":
		look_info = {"title": "QtMaMe", "hint": "Right-click to sell things for DOUBLE toots!"}
	elif mob != null:
		var kind: String = mob.def["kind"]
		look_info = {"title": mob.toughness_name() + MobData.display_name(mob.type), "hint": "Left-click to attack",
				"danger": kind == "hostile"}
	elif hit.get("hit", false):
		var b: int = hit["block"]
		var info := {"title": Blocks.NAMES[b]}
		if Blocks.WORKBENCH_TIER.has(b) or Blocks.BUILD_BENCH.has(b):
			info["hint"] = "Right-click to craft"
		elif b == Blocks.CUTE_CRAFTER:
			info["hint"] = "Right-click to make things cute!"
		elif b == Blocks.SCRIBE:
			info["hint"] = "Right-click to write names on your things"
		elif b == Blocks.RESEARCH_TABLE:
			info["hint"] = "Right-click to learn new recipes"
		elif b == Blocks.ITEM_FRAME:
			var fr: Dictionary = survival.frame_items.get(hit["position"], {}) if survival else {}
			if fr.is_empty():
				info["hint"] = "Right-click with something to put it in"
			else:
				var fs: Dictionary = fr["slot"]
				info["title"] = fs.get("label", Items.display_name(fs["id"]))
				info["hint"] = ("by %s  -  " % fs["scribe"] if fs.has("scribe") else "") + "Right-click to take it"
		elif b == Blocks.ARMOR_STAND:
			info["hint"] = "Right-click to dress it up"
		elif b == Blocks.BOSS_STATUE and survival:
			var si: int = survival.statue_index(hit["position"])
			var bosses: Array = preload("res://scripts/boss_data.gd").BOSSES
			if si >= 0 and si < bosses.size():
				var boss: Dictionary = bosses[si]
				info["title"] = "%s Statue" % boss["name"]
				if survival.trophies.has(boss["id"]):
					info["hint"] = "%s: %s. Right-click to pick it, F to use" % [boss["power"], boss["text"]]
				else:
					info["hint"] = "Bring its trophy from %s" % boss["lair"]
			else:
				info["title"] = "An Empty Statue"
				info["hint"] = "For a boss nobody has found yet"
		elif b == Blocks.PORTAL or b == Blocks.PORTAL_LIT:
			var pid: int = survival.client_portal_at(hit["position"]) if survival else 0
			var pd: Dictionary = survival.portals.get(pid, {}) if survival else {}
			var pname: String = pd.get("name", "")
			info["title"] = "Portal \"%s\"" % pname if pname != "" else "Portal (no name yet)"
			info["hint"] = "Linked! Walk in to travel" if pd.get("linked", false) else "Right-click to name it"
		elif b == Blocks.SHOP:
			info["hint"] = "Right-click to sell for toots"
		elif b == Blocks.FURNACE:
			info["hint"] = "Right-click to smelt"
		elif b == Blocks.SUPER_CHEST:
			info["hint"] = "Right-click to open your own Super Chest"
		elif b == Blocks.CAMPFIRE:
			info["hint"] = "Right-click at night to rest by the fire"
		elif b == Blocks.ARENA_BUTTON:
			var locked: bool = survival.arena_states.get(hit["position"], false) if survival else false
			info["hint"] = "Right-click to open the gates" if locked else "Right-click to lock the gates and start the battle!"
		elif b == Blocks.ARENA_BOX:
			info["hint"] = "Right-click: a whole battle arena appears!"
		elif b == Blocks.BEDROLL:
			info["hint"] = "Right-click at night to sleep (your respawn stays put)"
		elif Blocks.is_sapling(b):
			info["hint"] = "Growing into a tree..."
		elif b == Blocks.CHEST or b == Blocks.SHRINE_CHEST:
			info["hint"] = "Right-click to open"
			if survival and survival.chest_names.has(hit["position"]):
				info["title"] = survival.chest_names[hit["position"]]
		elif b == Blocks.BED or b == Blocks.BED_FOOT:
			info["hint"] = "Right-click to sleep"
		elif Blocks.is_door(b):
			info["hint"] = "Right-click to close" if Blocks.is_open_door(b) else "Right-click to open"
		elif b == Blocks.TORCH:
			info["hint"] = "Burns out after a few minutes"
		elif Blocks.HARDNESS[b] < 0.0:
			info["hint"] = "Too tough to break"
		elif not Survival.can_harvest(b, Items.get_def(held.get("id", ""))):
			info["hint"] = "You need %s" % Survival.needed_tool_text(b)
			info["danger"] = true
		look_info = info
	else:
		look_info = {}
	if Items.get_def(held.get("id", "")).has("food") and hurt and not look_info.has("hint"):
		look_info["hint"] = "Right-click to eat"


## How strong this fairy power is for you right now (0 = no such fairy).
func _buff(type: String) -> float:
	var b: Dictionary = survival.me.get("buff", {}) if survival else {}
	var c: Dictionary = survival.me.get("cape", {}) if survival else {}
	var pw: Dictionary = survival.active_power() if survival else {}
	var g: Dictionary = survival.me.get("gear", {}) if survival else {}
	var total: float = (b.get("power", 0.0) if b.get("type", "") == type else 0.0) \
			+ (c.get("power", 0.0) if c.get("type", "") == type else 0.0) \
			+ (float(pw.get("amount", 0.0)) if pw.get("buff", "") == type else 0.0) \
			+ float(g.get(type, 0.0))
	return minf(total, float(MobData.BUFF_CAP.get(type, 99.0)))


## Yeti boots: faster on snow.
func _snow_speed() -> float:
	var feet: Dictionary = survival.my_slot(Inv.ARMOR_START + 3) if survival else {}
	var boost: float = Items.get_def(feet.get("id", "")).get("snow_speed", 1.0)
	if boost == 1.0:
		return 1.0
	var below: int = world.get_block(Vector3i(floori(global_position.x), floori(global_position.y - 0.1), floori(global_position.z)))
	return boost if below in [Blocks.SNOW, Blocks.SNOWY_STONE] else 1.0


func _reset_mining() -> void:
	_mining_time = 0.0
	_mining_pos = Vector3i(0, -1, 0)
	break_progress = 0.0


## Closest mob under the crosshair (or null).
func _pick_mob(origin: Vector3, dir: Vector3, max_dist: float) -> Node3D:
	if mobs == null:
		return null
	var best: Node3D = null
	var best_d := max_dist
	for m in mobs.all_mobs():
		var d := _ray_aabb(origin, dir, m.get_aabb_world())
		if d >= 0.0 and d < best_d:
			best_d = d
			best = m
	return best


## Another (living) player under the crosshair, or null.
func _pick_player(origin: Vector3, dir: Vector3, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for p in get_parent().get_children():
		if p == self or not p.visible or not (p is CharacterBody3D):
			continue
		var d := _ray_aabb(origin, dir, AABB(p.global_position - Vector3(0.3, 0, 0.3), Vector3(0.6, 1.9, 0.6)))
		if d >= 0.0 and d < best_d:
			best_d = d
			best = p
	return best


func _pick_loot(origin: Vector3, dir: Vector3, max_dist: float) -> int:
	if survival == null:
		return -1
	var best := -1
	var best_d := max_dist
	for t in survival.loot_targets():
		var d := _ray_aabb(origin, dir, t["aabb"])
		if d >= 0.0 and d < best_d:
			best_d = d
			best = t["id"]
	return best


## Distance along the ray to the box, or -1 if it misses.
static func _ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var hit = box.intersects_ray(origin, dir)
	if hit == null:
		return 0.0 if box.has_point(origin) else -1.0
	return origin.distance_to(hit)


## Stops you from placing a block inside yourself or another player.
func _overlaps_any_player(block_pos: Vector3i) -> bool:
	var block_box := AABB(Vector3(block_pos), Vector3.ONE)
	for p in get_parent().get_children():
		if p is CharacterBody3D:
			var player_box := AABB(p.global_position - Vector3(0.29, 0.0, 0.29), Vector3(0.58, 1.79, 0.58))
			if player_box.intersects(block_box):
				return true
	return false


# --- Movement --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if sleeping or frozen:
		velocity = Vector3.ZERO
		_fall_start = global_position.y
		_send_state(delta)
		return
	if world == null or not world.is_ready_at(global_position):
		velocity = Vector3.ZERO  # wait until the ground under us has loaded
		_fall_start = global_position.y
		return

	var act := _can_act()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if act else Vector2.ZERO
	var wish := transform.basis * Vector3(input.x, 0.0, input.y)
	var jump := act and Input.is_action_pressed("jump")
	var sprint := act and Input.is_action_pressed("sprint")
	var sneak := act and Input.is_action_pressed("descend")
	var in_water := _is_in_water()

	if fly_mode or noclip_mode:
		# Flying: Space up, Shift down, Ctrl fast. No-clip goes through anything.
		var fs := SPRINT_SPEED * 2.6 if sprint else WALK_SPEED * 1.8
		var v := wish * fs
		v.y = (fs if jump else 0.0) - (fs if sneak else 0.0)
		velocity = velocity.lerp(v, minf(1.0, delta * 10.0))
		collision_mask = 0 if noclip_mode else 1
		if noclip_mode:
			global_position += velocity * delta
		else:
			move_and_slide()
		_fall_start = global_position.y
		_was_on_floor = true
		_send_state(delta)
		return
	collision_mask = 1

	if in_water:
		var speed := (SPRINT_SPEED if sprint else WALK_SPEED) * 0.55
		var current: Vector3 = world.fluid_push(global_position + Vector3(0, 0.4, 0)) * 2.6
		velocity.x = move_toward(velocity.x, wish.x * speed + current.x, 30.0 * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed + current.z, 30.0 * delta)
		velocity.y = maxf(velocity.y - GRAVITY * 0.25 * delta, -3.0)
		if jump:
			# Swim up; if pushing against a ledge, hop out of the water.
			velocity.y = 6.5 if is_on_wall() else minf(velocity.y + 30.0 * delta, 3.5)
		_fall_start = global_position.y
	else:
		if _on_vine():
			# Climbing: jump or walk forward to go up, sneak to hold still, otherwise slide down slowly.
			velocity.y = 3.4 if (jump or input.y < -0.1) else (0.0 if sneak else maxf(velocity.y - GRAVITY * delta, -2.0))
			velocity.x = move_toward(velocity.x, wish.x * WALK_SPEED * 0.6, 30.0 * delta)
			velocity.z = move_toward(velocity.z, wish.z * WALK_SPEED * 0.6, 30.0 * delta)
			_fall_start = global_position.y
			jump = false
		var speed := SNEAK_SPEED if sneak else (SPRINT_SPEED if sprint else WALK_SPEED)
		speed *= (1.0 + _buff("speed")) * _snow_speed() * (0.6 if survival and survival.me.get("chilled", false) else 1.0)
		var accel := 60.0 if is_on_floor() else 20.0
		velocity.x = move_toward(velocity.x, wish.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, accel * delta)
		if _on_vine():
			pass  # handled above
		elif is_on_floor():
			if jump:
				velocity.y = JUMP_VELOCITY * (1.0 + _buff("jump"))
		else:
			velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

	var before := global_position
	var was_floor := is_on_floor()
	move_and_slide()
	_step_up(wish, was_floor)
	_footsteps(Vector2(global_position.x - before.x, global_position.z - before.z).length(), is_on_floor() and was_floor)
	if in_water and not _was_in_water and velocity.y < -4.0:
		Sound.play_at("splash", global_position, -4.0)
	_was_in_water = in_water

	# Fall damage: measured from the highest point since leaving the ground.
	if is_on_floor():
		if not _was_on_floor:
			var fallen := _fall_start - global_position.y
			if fallen > 1.5:
				_land_dip = clampf(fallen / 8.0, 0.25, 1.0)
				var land: int = world.get_block(Vector3i(floori(global_position.x), floori(global_position.y - 0.1), floori(global_position.z)))
				if Blocks.is_targetable(land):
					Sound.play_at("step_" + Sound.material_of(land), global_position, -2.0, 0.8)
			if fallen > SAFE_FALL and alive and survival:
				survival.req_fall_damage.rpc_id(1, floorf(fallen - SAFE_FALL + 0.5))
		_fall_start = global_position.y
	else:
		_fall_start = maxf(_fall_start, global_position.y)
	_was_on_floor = is_on_floor()

	if global_position.y < world.floor_y() - 30.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
		_fall_start = global_position.y
		if survival:
			survival.req_fall_damage.rpc_id(1, 10.0)
	_send_state(delta)
	if _camera:
		_step_smooth = maxf(0.0, _step_smooth - delta * 4.0)
		_land_dip = maxf(0.0, _land_dip - delta * 3.0)
		_camera.position.y = -_step_smooth - _land_dip * _land_dip * 0.2
		var fast := Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 0.5
		_fov_kick = move_toward(_fov_kick, 1.0 if sprint and fast and not sneak else 0.0, delta * 3.0)
		if not drawing:
			_camera.fov = 75.0 + 7.0 * smoothstep(0.0, 1.0, _fov_kick)


## Party members' names show from far off, through hills, in green with how
## far away they are; everyone else's are normal and only up close.
func set_party_tag(in_party: bool, dist: float) -> void:
	if _name_label == null:
		return
	if in_party and dist <= 200.0 and Settings.party_tags:
		# (Size, color and see-through-ness are in Settings > Party name tags.)
		_name_label.visibility_range_end = 0.0      # (0 = no limit)
		_name_label.no_depth_test = true
		_name_label.fixed_size = dist > 12.0         # far away: stays readable
		_name_label.pixel_size = (0.0018 if _name_label.fixed_size else 0.006) * Settings.tag_size
		var c: Color = Settings.TAG_COLORS[Settings.tag_color][1]
		_name_label.modulate = Color(c, Settings.tag_alpha)
		_name_label.outline_modulate = Color(0, 0, 0, Settings.tag_alpha)
		_name_label.text = "%s  %dm" % [display_name, roundi(dist)] if dist > 12.0 else display_name
	else:
		_name_label.visibility_range_end = NAME_RANGE
		_name_label.no_depth_test = false
		_name_label.fixed_size = false
		_name_label.pixel_size = 0.006
		_name_label.modulate = Color.WHITE
		_name_label.outline_modulate = Color.BLACK
		_name_label.text = display_name


## Walking into a slab or stair? Hop up the half step (like Minecraft), as
## long as there's room for your head.
func _step_up(wish: Vector3, was_floor: bool) -> void:
	if not (was_floor or is_on_floor()) or not is_on_wall() or wish.length() < 0.1:
		return
	# Something ankle-high in the way (a stair's step, a slab)? If there's room
	# a little higher up and further on, hop up onto it, Minecraft-style. Full
	# blocks are too tall for this, so you still jump onto those.
	var fwd := Vector3(wish.x, 0, wish.z).normalized() * 0.3
	var t := global_transform
	for h in [0.3, 0.55]:
		if test_move(t, Vector3(0, h, 0)):
			return  # bumping your head
		var up := t
		up.origin.y += h
		if not test_move(up, fwd):
			global_position.y += h + 0.01
			global_position += fwd * 0.25
			velocity.y = maxf(velocity.y, 0.0)
			_step_smooth = minf(0.6, _step_smooth + h)
			return


## Touching a vine (at your feet or chest)?
func _on_vine() -> bool:
	var p := global_position
	for dy in [0.2, 1.0]:
		if world.get_block(Vector3i(floori(p.x), floori(p.y + dy), floori(p.z))) == Blocks.VINE:
			return true
	return false


func _is_in_water() -> bool:
	var p := global_position + Vector3(0, 0.4, 0)
	return Blocks.is_fluid(world.get_block(Vector3i(floori(p.x), floori(p.y), floori(p.z))))


func apply_knockback(v: Vector3) -> void:
	velocity += v


func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_fall_start = global_position.y


## Lie down in a bed (the camera drops to pillow height).
func sleep_in(bed: Vector3i) -> void:
	sleeping = true
	global_position = Vector3(bed) + Vector3(0.5, 0.6, 0.5)
	_head.position.y = 0.25
	velocity = Vector3.ZERO


func wake_up() -> void:
	if not sleeping:
		return
	sleeping = false
	_head.position.y = EYE_HEIGHT
	global_position += Vector3(0, 0.1, 0)
	_fall_start = global_position.y


func is_swimming() -> bool:
	return world != null and _is_in_water()


## What gets written to the world save for this player (position only;
## inventory and health are saved by survival.gd).
func get_save_state() -> Dictionary:
	return {"position": global_position, "yaw": rotation.y, "pitch": _head.rotation.x, "hotbar": hotbar_index}


## Puts a remote player's last known position in their save (they move themselves).
func get_remote_save_state() -> Dictionary:
	return {"position": _target_position, "yaw": _target_yaw, "pitch": _target_pitch, "hotbar": 0}


func apply_save_state(state: Dictionary) -> void:
	global_position = state.get("position", global_position)
	rotation.y = state.get("yaw", 0.0)
	_head.rotation.x = state.get("pitch", 0.0)
	_fall_start = global_position.y
	select_slot(clampi(state.get("hotbar", 0), 0, Inv.HOTBAR_SIZE - 1))


# --- Networking ------------------------------------------------------------------

func _send_state(delta: float) -> void:
	if multiplayer.get_peers().is_empty():
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_INTERVAL
		_receive_state.rpc(global_position, rotation.y, _head.rotation.x)
	_info_timer -= delta
	if _info_timer <= 0.0:
		_info_timer = INFO_INTERVAL
		_receive_info.rpc(display_name, held_id, look)


@rpc("authority", "unreliable_ordered")
func _receive_state(pos: Vector3, yaw: float, pitch: float) -> void:
	_target_position = pos
	_target_yaw = yaw
	_target_pitch = pitch


@rpc("authority", "reliable")
func _receive_info(player_name: String, holding := "", their_look := {}) -> void:
	display_name = player_name.left(24)
	_name_label.text = display_name
	held_id = holding
	if not their_look.is_empty():
		set_look(their_look)


@rpc("authority", "reliable")
func _receive_held(id: String) -> void:
	held_id = id


@rpc("authority", "unreliable")
func _receive_swing() -> void:
	_swing_t = 0.0
	Sound.play_at("swing", global_position + Vector3(0, 1.3, 0), -10.0)


## Footsteps for anyone walking (you and other players).
func _footsteps(delta_dist: float, on_ground: bool) -> void:
	if not on_ground or world == null:
		_step_dist = 0.0
		return
	_step_dist += delta_dist
	if _step_dist >= 1.9:
		_step_dist = 0.0
		var below := Vector3i(floori(global_position.x), floori(global_position.y - 0.1), floori(global_position.z))
		var b: int = world.get_block(below)
		if Blocks.is_targetable(b):
			Sound.play_at("step_" + Sound.material_of(b), global_position, -8.0 if is_multiplayer_authority() else -10.0)
