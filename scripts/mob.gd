extends Node3D
## One mob. The server runs its brain and physics (server_tick); every computer
## (including the server) shows a model that glides toward the latest position.
##
## Physics is simple Minecraft-style box collision against the block grid,
## so it works on a dedicated server without any 3D physics or meshes.

const MobData = preload("res://scripts/mob_data.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Sound = preload("res://scripts/sound.gd")

const GRAVITY := 28.0
const JUMP_VELOCITY := 8.4
const ATTACK_COOLDOWN := 1.2

var mob_id := 0
var type := ""
var def := {}
var variant := {}             # per-mob extras (a fairy's color and brightness, ...)

# --- Server simulation state ---
var hp := 1.0
var sim_pos := Vector3.ZERO
var velocity := Vector3.ZERO
var yaw := 0.0
var on_ground := false
var moving := false
var target_peer := 0          # player being chased (0 = none)
var hunt_peer := 0            # (a host's hunt) always goes after this player
var flee_from := Vector3.ZERO
var _mode := "idle"           # idle, wander, flee, chase
var _mode_timer := 0.0
var _wander_dir := Vector3.ZERO
var _attack_timer := 0.0
var _anger_timer := 0.0
const HOME_LEASH := 12.0   # guards (meta "home") stay this close to their room
var age := 0.0
var fleeing_sun_time := 0.0   # how long a night hunter has been running from daylight
var attackers := {}           # peer id -> true (everyone who hit it; used for boss loot)
var hp_ratio := 1.0           # health left 0..1 (sent to clients for the boss bar)
var fly_height := 0.0         # flying mobs: the height they're heading for
var stuck_time := 0.0         # QtMaMe: how long she hasn't got closer to home
var _last_home_dist := INF

# --- Display state (all computers) ---
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _anim_time := 0.0
var _remote_moving := false
var _model: Dictionary
var _flash := 0.0
var _voice_timer := randf_range(4.0, 14.0)


var max_hp := 10.0
var dmg_mult := 1.0            # tougher mobs far from spawn hit harder


## "Tough Zombie", "Fierce Zombie"... for the look-at name.
func toughness_name() -> String:
	var d: float = float(variant.get("danger", 0.0))
	if d >= 3.5:
		return "Fierce "
	if d >= 2.0:
		return "Tough "
	return ""


func setup(id: int, mob_type: String, pos: Vector3, start_yaw: float, extra := {}) -> void:
	mob_id = id
	type = mob_type
	variant = extra
	def = MobData.get_def(mob_type)
	var danger: float = float(extra.get("danger", 0.0))
	max_hp = def.get("hp", 10.0) * (1.0 + 0.6 * danger)
	dmg_mult = 1.0 + 0.45 * danger
	hp = max_hp
	sim_pos = pos
	yaw = start_yaw
	position = pos
	rotation.y = start_yaw
	_target_pos = pos
	_target_yaw = start_yaw
	if is_fairy():
		_model = MobData.build_fairy(variant.get("color", 0), variant.get("bright", 0.7))
	else:
		_model = MobData.build_model(mob_type)
	add_child(_model["root"])
	if def.has("label"):
		var label := Label3D.new()
		label.text = def["label"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.006
		label.font_size = 52
		label.outline_size = 14
		label.modulate = def.get("label_color", Color.WHITE)
		label.position.y = def["size"].y + 0.35
		add_child(label)


## How far in front of its middle this mob's head sticks out (for biting range).
func front_reach() -> float:
	var front := half_width()
	for part in def.get("parts", []):
		if part.get("head", false):
			front = maxf(front, -part["pos"].z + part["size"].z * 0.5)
	return front


func is_boss() -> bool:
	return def.get("boss", false)


func is_npc() -> bool:
	return def["kind"] == "npc"


func is_fairy() -> bool:
	return def["kind"] == "fairy"


## Mobs that can't be hurt and don't fight (QtMaMe and fairies).
func is_friendly_npc() -> bool:
	return is_npc() or is_fairy() or is_villager()


func is_villager() -> bool:
	return def["kind"] == "villager"


## Collision box half-width and height.
## Frost arrows slow a mob down for a few seconds.
var slow_until := 0.0
var stun_until := 0.0      # (the White Throne's blade) frozen in place till then
## Ranged mobs call this to shoot at a player: (mob, target_peer).
var on_shoot: Callable
var _shoot_timer := 1.5


func slow_factor() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	if t < stun_until:
		return 0.05
	return 0.5 if t < slow_until else 1.0


func half_width() -> float:
	return def["size"].x * 0.5


func height() -> float:
	return def["size"].y


## The box used for clicking on the mob.
func get_aabb_world() -> AABB:
	var w := half_width()
	return AABB(position - Vector3(w, 0, w), Vector3(w * 2.0, height(), w * 2.0))


# --- Display -------------------------------------------------------------------------

func set_remote_state(pos: Vector3, new_yaw: float, is_moving: bool, health := 1.0) -> void:
	_target_pos = pos
	_target_yaw = new_yaw
	_remote_moving = is_moving
	hp_ratio = health


func flash() -> void:
	_flash = 0.25
	Sound.play_at("hit", position + Vector3(0, height() * 0.5, 0), -4.0)
	voice(1.15)


## Says something (pitch: higher for small mobs, deeper for big ones).
func voice(pitch_mul := 1.0) -> void:
	var v: String = Sound.VOICES.get(type, "")
	if v == "":
		return
	var size_pitch := clampf(1.2 - height() * 0.12, 0.7, 1.4)
	Sound.play_at(v, position + Vector3(0, height() * 0.7, 0), 0.0 if is_boss() else -6.0, size_pitch * pitch_mul)


func _process(delta: float) -> void:
	_voice_timer -= delta
	if _voice_timer <= 0.0:
		_voice_timer = randf_range(6.0, 18.0) if def.get("kind", "") != "hostile" else randf_range(4.0, 10.0)
		voice()
	var k := minf(1.0, delta * 12.0)
	position = position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	# Walk animation: legs swing in opposite pairs.
	if _remote_moving:
		_anim_time += delta * 9.0
	else:
		_anim_time = lerpf(_anim_time, roundf(_anim_time / PI) * PI, k)
	var legs: Array = _model["legs"]
	if is_fairy():
		# Wings flutter fast, and the fairy bobs gently.
		var beat := sin(Time.get_ticks_msec() / 28.0) * 0.7
		for i in legs.size():
			legs[i].rotation.y = beat * (1.0 if i == 0 else -1.0)
		_model["root"].position.y = sin(Time.get_ticks_msec() / 400.0 + mob_id) * 0.08
	for i in (legs.size() if not is_fairy() else 0):
		var phase := 0.0 if (i % 2 == 0) == (i / 2 % 2 == 0) else PI
		legs[i].rotation.x = sin(_anim_time + phase) * 0.6
	# Red flash when hurt.
	if _flash > 0.0:
		_flash -= delta
		var red := _flash > 0.0
		for c in _all_meshes(_model["root"]):
			c.material_overlay = _hurt_material() if red else null


static var _hurt_mat: StandardMaterial3D


static func _hurt_material() -> StandardMaterial3D:
	if _hurt_mat == null:
		_hurt_mat = StandardMaterial3D.new()
		_hurt_mat.albedo_color = Color(1, 0, 0, 0.45)
		_hurt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hurt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _hurt_mat


func _all_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_all_meshes(c))
	return out


# --- Server: brain ---------------------------------------------------------------------

## players: Array of {"peer": int, "pos": Vector3, "alive": bool}.
## on_attack(peer, damage, mob) is called when this mob hits someone.
func server_tick(delta: float, world: Node, players: Array, on_attack: Callable, is_day := false) -> void:
	age += delta
	_mode_timer -= delta
	_attack_timer -= delta
	_anger_timer -= delta
	var kind: String = def["kind"]
	var speed: float = def["speed"] * slow_factor()
	hp_ratio = clampf(hp / max_hp, 0.0, 1.0)

	# Night hunters run away from the nearest player once the sun is up (but
	# only out where the sun can reach them: in caves and dungeons they fight).
	var home: Variant = get_meta("home") if has_meta("home") else null
	var in_sun: bool = is_day and home == null and world.sees_sky(Vector3i(floori(sim_pos.x), floori(sim_pos.y + 1.5), floori(sim_pos.z)))
	if in_sun and kind == "hostile" and MobData.spawns_in(type, "night") and not is_boss() and _anger_timer <= 0.0 and hunt_peer == 0:
		var nearest := Vector3.ZERO
		var best := INF
		for p in players:
			var d2: float = (p["pos"] - sim_pos).length_squared()
			if d2 < best:
				best = d2
				nearest = p["pos"]
		target_peer = 0
		_mode = "flee"
		_mode_timer = 1.0
		flee_from = nearest
		fleeing_sun_time += delta
	elif kind == "hostile":
		var sight: float = def.get("sight", 16.0)
		var best := sight * sight
		var found := 0
		for p in players:
			if not p["alive"]:
				continue
			var seen: float = float(p.get("sight", 1.0))   # Night Eyes: noticed from half as far
			var d2: float = (p["pos"] - sim_pos).length_squared() / (seen * seen)
			var keep: bool = p["peer"] == target_peer and d2 < best * 2.25
			if home != null and (p["pos"] as Vector3).distance_to(home) > HOME_LEASH:
				continue   # guards don't chase you out of their room
			if d2 < best or keep:
				best = d2
				found = p["peer"]
		if hunt_peer != 0 and players.any(func(p): return p["peer"] == hunt_peer and p["alive"]):
			found = hunt_peer   # sent on a hunt: nothing else matters
		target_peer = found
		fleeing_sun_time = 0.0
		_mode = "chase" if found != 0 else _mode
		if found == 0 and home != null and sim_pos.distance_to(home) > HOME_LEASH * 0.5 and _mode != "flee":
			# Wander back into the room.
			_mode = "wander"
			_mode_timer = 1.0
			var back: Vector3 = home - sim_pos
			back.y = 0
			_wander_dir = back.normalized()
	elif kind == "neutral" and target_peer != 0 and _anger_timer <= 0.0:
		target_peer = 0  # calmed down

	var target_pos := Vector3.ZERO
	var target_alive := false
	if target_peer != 0:
		for p in players:
			if p["peer"] == target_peer:
				target_pos = p["pos"]
				target_alive = p["alive"]
		if not target_alive:
			target_peer = 0
	if target_peer == 0 and _mode == "chase":
		_mode = "idle"

	var wish := Vector3.ZERO
	var move_speed := 0.0
	if def.get("fly", false):
		if _mode == "chase":
			fly_height = target_pos.y + 1.6
		elif fly_height == 0.0 or absf(fly_height - sim_pos.y) > 6.0:
			fly_height = sim_pos.y
	match _mode:
		"chase":
			var to := target_pos - sim_pos
			to.y = 0
			var reach := front_reach() * 0.85 + 0.9
			var ranged: Dictionary = def.get("ranged", {})
			_shoot_timer -= delta
			if not ranged.is_empty() and to.length() < ranged["range"] and (to.length() > 4.0 or ranged.get("chase", false)):
				# Archers keep their distance and shoot.
				if _shoot_timer <= 0.0 and on_shoot.is_valid():
					_shoot_timer = ranged["every"] * randf_range(0.85, 1.15)
					on_shoot.call(self, target_peer)
				if ranged.get("chase", false):
					# A boss stomps toward you while it shoots, and still hits hard up close.
					if to.length() > reach * 0.8:
						wish = to.normalized()
						move_speed = speed
					if to.length() < reach and absf(target_pos.y - sim_pos.y) < 2.5 and _attack_timer <= 0.0:
						_attack_timer = ATTACK_COOLDOWN
						on_attack.call(target_peer, def.get("damage", 1.0) * dmg_mult, self)
				elif to.length() < 7.0:
					wish = -to.normalized()
					move_speed = speed * 0.6
			elif to.length() > reach * 0.8:
				wish = to.normalized()
				move_speed = speed
			yaw = atan2(-to.x, -to.z) if to.length() > 0.01 else yaw
			if to.length() < reach and absf(target_pos.y - sim_pos.y) < 1.8 and _attack_timer <= 0.0:
				_attack_timer = ATTACK_COOLDOWN
				on_attack.call(target_peer, def.get("damage", 1.0) * dmg_mult, self)
		"flee":
			var away := sim_pos - flee_from
			away.y = 0
			wish = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
			if not _dry_ahead(world, wish):
				# Don't run into the lake: veer to whichever side is dry.
				var left := Vector3(-wish.z, 0, wish.x)
				wish = left if _dry_ahead(world, left) else -left
			move_speed = speed * 1.3
			if _mode_timer <= 0.0:
				_mode = "idle"
		"wander":
			wish = _wander_dir
			move_speed = speed * 0.35
			if _mode_timer <= 0.0:
				_mode = "idle"
				_mode_timer = randf_range(2.0, 6.0)
			elif not _good_direction(world, _wander_dir):
				_mode = "idle"  # water or the edge of home ahead: stop and pick again
				_mode_timer = randf_range(0.5, 1.5)
				wish = Vector3.ZERO
		_:  # idle
			if _mode_timer <= 0.0:
				_mode = "wander"
				_mode_timer = randf_range(1.5, 4.0)
				_wander_dir = _pick_wander_direction(world)

	# Don't wander off cliffs (chasing/fleeing mobs don't care).
	if _mode == "wander" and wish != Vector3.ZERO:
		var ahead := sim_pos + wish * (half_width() + 0.6)
		var drop := 0
		for i in range(1, 5):
			if Blocks.is_solid(world.get_block(Vector3i(floori(ahead.x), floori(sim_pos.y) - i, floori(ahead.z)))):
				break
			drop = i
		if drop >= 3:
			wish = Vector3.ZERO
			_mode = "idle"
			_mode_timer = 1.0

	if wish != Vector3.ZERO and _mode != "chase":
		yaw = lerp_angle(yaw, atan2(-wish.x, -wish.z), minf(1.0, delta * 8.0))

	_physics(delta, world, wish * move_speed)


## QtMaMe's brain: fight nearby hostile mobs, otherwise stay near home.
## enemy: closest hostile mob (or null). on_hit(enemy) is called when she bonks it.
func npc_tick(delta: float, world: Node, home: Vector3, enemy: Node3D, on_hit: Callable) -> void:
	age += delta
	_mode_timer -= delta
	_attack_timer -= delta
	var speed: float = def["speed"] * slow_factor()
	var wish := Vector3.ZERO
	var move_speed := 0.0
	if world.is_data_loaded(sim_pos) and _collides(world, sim_pos):
		sim_pos.y += 1.0  # spawned inside the ground: pop up
		return
	var to_home := home - sim_pos
	to_home.y = 0
	if enemy != null:
		var to: Vector3 = enemy.sim_pos - sim_pos
		to.y = 0
		var reach: float = half_width() + enemy.half_width() + 0.7
		if to.length() > reach * 0.8:
			wish = to.normalized()
			move_speed = speed * 1.2
		yaw = atan2(-to.x, -to.z)
		if to.length() < reach and _attack_timer <= 0.0:
			_attack_timer = 1.1
			on_hit.call(enemy)
	elif to_home.length() > 20.0:
		wish = to_home.normalized()
		move_speed = speed
		yaw = lerp_angle(yaw, atan2(-wish.x, -wish.z), minf(1.0, delta * 6.0))
	else:
		if _mode_timer <= 0.0:
			_mode = "wander" if _mode != "wander" else "idle"
			_mode_timer = randf_range(2.0, 5.0)
			var a := randf() * TAU
			_wander_dir = Vector3(sin(a), 0, cos(a))
		if _mode == "wander":
			if _drop_ahead(world, _wander_dir) >= 2 or not _dry_ahead(world, _wander_dir):
				_mode = "idle"  # don't wander into a hole or a lake
				_mode_timer = 1.0
			else:
				wish = _wander_dir
				move_speed = speed * 0.35
				yaw = lerp_angle(yaw, atan2(-wish.x, -wish.z), minf(1.0, delta * 6.0))
	# Notice when she's stuck on the way home (mobs.gd may help her along).
	var d := to_home.length()
	if d > 20.0 and d > _last_home_dist - 0.05 * delta:
		stuck_time += delta
	else:
		stuck_time = 0.0
	_last_home_dist = d
	_physics(delta, world, wish * move_speed)


## Called by the server when a player hits this mob.
func on_hurt(attacker_peer: int, attacker_pos: Vector3, knockback: float) -> void:
	var kind: String = def["kind"]
	if attacker_peer != 0:
		attackers[attacker_peer] = true
	if is_boss():
		knockback = knockback * 0.15  # too big to push around much
	var away := sim_pos - attacker_pos
	away.y = 0
	if away.length() > 0.01:
		velocity += away.normalized() * knockback
	velocity.y = maxf(velocity.y, 4.0 if not is_boss() else 0.0)
	if kind == "npc":
		return
	if kind == "passive":
		_mode = "flee"
		_mode_timer = 5.0
		flee_from = attacker_pos
	elif attacker_peer != 0:
		target_peer = attacker_peer
		_mode = "chase"
		_anger_timer = 20.0


# --- Server: where to go -------------------------------------------------------------
# Land animals keep out of water, and every mob likes its own biome: when it
# wanders it picks a direction that keeps it (or brings it back) home.
# Chasing and running from the sun ignore this.

func _is_home(world: Node, p: Vector3) -> bool:
	return MobData.lives_in(type, world.biome_at(p.x, p.z))


func _dry_ahead(world: Node, dir: Vector3) -> bool:
	var ahead := sim_pos + dir * (half_width() + 1.0)
	for dy in [0, -1, 1]:
		var b: int = world.get_block(Vector3i(floori(ahead.x), floori(sim_pos.y) + dy, floori(ahead.z)))
		if Blocks.is_water(b) or (Blocks.is_lava(b) and not def.get("fireproof", false)):
			return false   # (fire creatures don't mind lava)
	return true


func _good_direction(world: Node, dir: Vector3) -> bool:
	if not _dry_ahead(world, dir):
		return false
	var ahead := sim_pos + dir * (half_width() + 3.0)
	return _is_home(world, ahead) or not _is_home(world, sim_pos)


func _pick_wander_direction(world: Node) -> Vector3:
	var best := Vector3.ZERO
	var best_score := -INF
	var start := randf() * TAU
	for i in 8:
		var a := start + i * TAU / 8.0
		var dir := Vector3(sin(a), 0, cos(a))
		var ahead := sim_pos + dir * 6.0
		var score := randf()
		if not _dry_ahead(world, dir):
			score -= 10.0
		if _is_home(world, ahead):
			score += 3.0
		if _drop_ahead(world, dir) >= 3:
			score -= 6.0
		if score > best_score:
			best_score = score
			best = dir
	return best


## How far the ground falls away just ahead (0 = flat).
func _drop_ahead(world: Node, dir: Vector3) -> int:
	var ahead := sim_pos + dir * (half_width() + 0.6)
	for i in range(1, 6):
		if Blocks.is_solid(world.get_block(Vector3i(floori(ahead.x), floori(sim_pos.y) - i, floori(ahead.z)))):
			return i - 1
	return 5


## Fairies fly: no gravity, just glide toward a spot and hover there.
func fly_tick(delta: float, target: Vector3, face: Vector3) -> void:
	var to := target - sim_pos
	var speed: float = def.get("speed", 6.0) * slow_factor() * (1.0 + clampf(to.length() / 6.0, 0.0, 2.0))
	if to.length() > 0.05:
		sim_pos += to.normalized() * minf(to.length(), speed * delta)
	if to.length() > 40.0:
		sim_pos = target  # fell far behind (teleported owner): pop over
	var look := face - sim_pos
	if Vector2(look.x, look.z).length() > 0.1:
		yaw = lerp_angle(yaw, atan2(-look.x, -look.z), minf(1.0, delta * 6.0))
	moving = to.length() > 0.3


# --- Server: physics -----------------------------------------------------------------

func _physics(delta: float, world: Node, wish_velocity: Vector3) -> void:
	if not world.is_data_loaded(sim_pos):
		return  # the ground here isn't loaded: freeze instead of falling forever
	if _collides(world, sim_pos):
		# Stuck inside the ground (big mobs on hills, or a block placed on it): climb out.
		sim_pos.y = floorf(sim_pos.y) + 1.0
		velocity.y = 0.0
		return
	var in_water: bool = Blocks.is_fluid(world.get_block(Vector3i(floori(sim_pos.x), floori(sim_pos.y + 0.3), floori(sim_pos.z))))
	var flying: bool = def.get("fly", false)
	var accel := 30.0 if on_ground or flying else 8.0
	if in_water and not flying:
		wish_velocity *= 0.5
	velocity.x = move_toward(velocity.x, wish_velocity.x, accel * delta)
	velocity.z = move_toward(velocity.z, wish_velocity.z, accel * delta)
	if flying:
		# Drakes fly: they glide toward a height a little above whatever they're after.
		velocity.y = clampf((fly_height - sim_pos.y) * 2.0, -4.0, 4.0)
	elif in_water:
		velocity.y = minf(velocity.y + 18.0 * delta, 2.5)  # bob up to the surface
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -40.0)

	var blocked := false
	var step := velocity * delta
	var steps := maxi(1, ceili(step.length() / 0.25))
	var sub := step / steps
	on_ground = false
	for i in steps:
		if not _try_move(world, Vector3(sub.x, 0, 0)):
			blocked = true
			velocity.x = 0
		if not _try_move(world, Vector3(0, 0, sub.z)):
			blocked = true
			velocity.z = 0
		if not _try_move(world, Vector3(0, sub.y, 0)):
			if sub.y < 0:
				on_ground = true
				sim_pos.y = floorf(sim_pos.y + 0.001)  # rest exactly on the block
			velocity.y = 0
			sub.y = 0
	if blocked and wish_velocity.length() > 0.1 and (on_ground or in_water):
		velocity.y = JUMP_VELOCITY  # hop up a step
	moving = Vector2(velocity.x, velocity.z).length() > 0.3


func _try_move(world: Node, d: Vector3) -> bool:
	var next := sim_pos + d
	if _collides(world, next):
		return false
	sim_pos = next
	return true


func _collides(world: Node, p: Vector3) -> bool:
	var w := half_width() - 0.001
	var h := height() - 0.001
	for y in range(floori(p.y), floori(p.y + h) + 1):
		for z in range(floori(p.z - w), floori(p.z + w) + 1):
			for x in range(floori(p.x - w), floori(p.x + w) + 1):
				if Blocks.is_solid(world.get_block(Vector3i(x, y, z))):
					return true
	return false
