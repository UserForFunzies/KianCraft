extends Node3D
## Spawns, runs and syncs all mobs. The server decides everything; clients
## only display what they're told.
##
## Spawning (checked every second around each player), by biome:
## - Animals: in daylight under open sky, on grass (plains) or frosting (candy land).
## - Night hunters: on the surface at night where there's no light.
##   Plains: wolf, cougar, bear. Desert: sand bear, sand spider.
## - Cave hunters: underground where there's no light (spider, or sand spider
##   under the desert).
## - Candy land never spawns anything hostile.
## - The King Cougar (boss) sometimes appears near players in the desert.
##   Only one exists at a time.
## - QtMaMe the trader lives in candy land until someone meets her; then she
##   moves near that player's favorite bed.
## When the sun comes up, night hunters run away and vanish once they're out
## of view.

const Mob = preload("res://scripts/mob.gd")
const MobData = preload("res://scripts/mob_data.gd")
const VillagerData = preload("res://scripts/villager_data.gd")
const Blocks = preload("res://scripts/blocks.gd")

const SIM_RATE := 20.0               # brain/physics updates per second
const SYNC_INTERVAL := 0.1
const SPAWN_INTERVAL := 1.0
const ANIMAL_CAP := 10               # per player, within CAP_RADIUS
const HOSTILE_CAP := 8
const CAP_RADIUS := 64.0
const SPAWN_MIN := 24.0
const SPAWN_MAX := 48.0
const SAFE_SPAWN_DISTANCE := 20.0    # never spawn hostiles closer than this
const KING_CHANCE := 0.02            # per second, per player standing in the desert
const KING_COOLDOWN := 600.0         # seconds after a King is defeated before another appears
const KING_LEASH := 160.0            # a boss leaves if nobody is this close
const YETI_RANGE := 34.0             # the Yeti wakes when someone comes this close to his chamber
const YETI_COOLDOWN := 900.0
const GRIM_COOLDOWN := 900.0
const GRIM_RANGE := 40.0
const FAIRY_RANGE := 72.0            # fairies come out when someone is this close to their village
const NPC_HELP_RADIUS := 12.0        # QtMaMe fights hostile mobs this close to her
const NPC_HOME_REFRESH := 5.0
const NPC_GUARD_RADIUS := 28.0       # she chases monsters this far from home

signal mob_killed(type: String, pos: Vector3, yaw: float, killer_peer: int, attackers: Array)

var world: Node
var day_night: Node
var get_players: Callable            # -> Array of {"peer", "pos", "alive"}
var on_attack: Callable              # (peer, damage, mob)
var announce: Callable               # (text) chat message to everyone
var name_of: Callable                # (peer) -> player name, for boss fight news
var bed_for: Callable                # (player name) -> Vector3i of their favorite bed, or y = -1

var _mobs := {}                      # id -> Mob
var _next_id := 1
var _sim_accum := 0.0
var _sync_timer := 0.0
var _spawn_timer := 0.0
var _king_id := 0
var _king_cooldown := 0.0
var _yeti_id := 0
var _yeti_cooldown := 0.0
var _grim_id := 0
var _lair_ids := {}                   # lair id -> boss mob id
var _lair_cooldown := {}              # lair id -> seconds before its boss comes back
const LAIR_COOLDOWN := 900.0
const LAIR_WAKE := 30.0               # how close you get before the boss shows up
var _grim_cooldown := 0.0
var _fairies := {}                   # fairy key -> {"village", "center", "color", "bright", "owner", "state", "home", "id"}
var _dungeons_done := {}              # dungeon id -> true (its guards have woken up)
var _fairy_villages_done := {}       # village id -> true (its fairies have been added to _fairies)
var owner_peer: Callable             # (character key) -> peer id or 0, from survival.gd
var bed_pos_for: Callable            # (character key) -> Vector3i bed or y = -1
var fairy_changed: Callable          # (character key) a fairy joined, left or came back
var _npc_id := 0
var _npc := {}                       # saved QtMaMe state: home, pos, friend
var _npc_refresh := 0.0
var _npc_enemy := 0


func clear() -> void:
	for m in _mobs.values():
		m.queue_free()
	_mobs.clear()
	_king_id = 0
	_yeti_id = 0
	_grim_id = 0
	_npc_id = 0
	_fairies.clear()
	_fairy_villages_done.clear()
	_dungeons_done.clear()
	_lair_ids.clear()
	_lair_cooldown.clear()
	_npc = {}


func get_mob(id: int) -> Node3D:
	return _mobs.get(id)


func all_mobs() -> Array:
	return _mobs.values()


func count() -> int:
	return _mobs.size()


func get_npc() -> Node3D:
	return _mobs.get(_npc_id)


## The boss nearest to you (King Cougar or Yeti), for the health bar.
func get_king() -> Node3D:
	var k: Node3D = _mobs.get(_king_id)
	var y: Node3D = _mobs.get(_yeti_id)
	if k == null:
		return y
	if y == null:
		return k
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return k
	return k if k.position.distance_to(cam.global_position) < y.position.distance_to(cam.global_position) else y


# --- Saving (server) --------------------------------------------------------------------

## Places QtMaMe (from the save, or in the nearest candy land for new worlds).
func server_start(save: Dictionary) -> void:
	_npc = save.get("qtmame", {}).duplicate(true)
	_fairies = save.get("fairies", {}).duplicate(true)
	_fairy_villages_done = save.get("fairy_villages", {}).duplicate(true)
	_dungeons_done = save.get("dungeons", {}).duplicate(true)
	for k in _fairies:
		_fairies[k]["id"] = 0
		if _fairies[k]["state"] == "follow":
			_fairies[k]["state"] = "home"  # wait at the bed until the owner comes back
	_king_cooldown = 0.0
	_yeti_cooldown = 0.0
	if _npc.is_empty():
		var home: Vector3 = world.find_biome("candy", Vector2.ZERO)
		if home.y < 0:
			return
		home = world.safe_ground(home)
		_npc = {"home": home, "pos": home, "friend": ""}
	var m := get_mob(spawn_mob("qtmame", _npc["pos"]))
	if m:
		_npc_id = m.mob_id


func export_save() -> Dictionary:
	var npc := get_npc()
	if npc:
		_npc["pos"] = npc.sim_pos
	var fairies := {}
	for k in _fairies:
		var f: Dictionary = _fairies[k].duplicate()
		f.erase("id")
		fairies[k] = f
	return {"qtmame": _npc, "fairies": fairies, "fairy_villages": _fairy_villages_done, "dungeons": _dungeons_done}


## Someone said hello to QtMaMe: from now on she lives near their favorite bed.
func npc_set_friend(player_name: String) -> void:
	if _npc.is_empty():
		return
	_npc["friend"] = player_name
	_npc_refresh = 0.0


func npc_home() -> Vector3:
	return _npc.get("home", Vector3(0, -1, 0))


# --- Server loop ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or world == null or not world.running:
		return
	var players: Array = get_players.call()
	var is_day: bool = not day_night.is_night()
	_king_cooldown = maxf(0.0, _king_cooldown - delta)
	_yeti_cooldown = maxf(0.0, _yeti_cooldown - delta)
	_grim_cooldown = maxf(0.0, _grim_cooldown - delta)
	_update_npc_home(delta)
	_sim_accum += delta
	var dt := 1.0 / SIM_RATE
	while _sim_accum >= dt:
		_sim_accum -= dt
		for m in _mobs.values():
			if m.is_fairy():
				_tick_fairy(m, dt, players)
			elif m.is_npc():
				_tick_npc(m, dt, players)
			elif m.is_villager():
				_tick_villager(m, dt)
			else:
				m.server_tick(dt, world, players, on_attack, is_day)
			m.set_remote_state(m.sim_pos, m.yaw, m.moving, m.hp_ratio)  # the host sees them too
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_despawn(players, is_day)
		for p in players:
			if p["alive"]:
				_try_spawn_near(p["pos"], players)
				_try_spawn_king(p["pos"], players)
				_try_spawn_yeti(p["pos"])
				_try_spawn_grimskull(p["pos"])
				_wake_dungeon(p["pos"])
				_try_spawn_lair_boss(p["pos"], players)
				_wake_fairies(p["pos"])
				_wake_camp(p["pos"])
		_boss_summons(players)
		for k in _lair_cooldown.keys():
			_lair_cooldown[k] -= SPAWN_INTERVAL
			if _lair_cooldown[k] <= 0.0:
				_lair_cooldown.erase(k)
	_sync_timer -= delta
	if _sync_timer <= 0.0 and not multiplayer.get_peers().is_empty() and not _mobs.is_empty():
		_sync_timer = SYNC_INTERVAL
		var data := PackedFloat32Array()
		for m in _mobs.values():
			data.append_array([m.mob_id, m.sim_pos.x, m.sim_pos.y, m.sim_pos.z, m.yaw, 1.0 if m.moving else 0.0, m.hp_ratio])
		_receive_states.rpc(data)


func _biome(p: Vector3) -> String:
	return world.biome_at(p.x, p.z)


func _try_spawn_near(center: Vector3, players: Array) -> void:
	var animals := 0
	var hostiles := 0
	for m in _mobs.values():
		if m.sim_pos.distance_to(center) < CAP_RADIUS:
			if m.def["kind"] == "hostile":
				hostiles += 1
			elif m.def["kind"] in ["passive", "neutral"]:
				animals += 1
	var night: bool = day_night.is_night()
	var a := randf() * TAU
	var r := randf_range(SPAWN_MIN, SPAWN_MAX)
	var x := floori(center.x + cos(a) * r)
	var z := floori(center.z + sin(a) * r)
	var top: int = world.surface_y(x, z)
	if top <= 0:
		return  # not loaded
	var biome: String = world.biome_at(x, z)

	# Surface spawn
	var surface := Vector3i(x, top + 1, z)
	var ground: int = world.get_block(Vector3i(x, top, z))
	if _has_room(surface, 2):
		if biome == "sky" and not night and hostiles < HOSTILE_CAP and world.sees_sky(surface) \
				and _far_from_players(Vector3(surface), players) and randf() < 0.5:
			_spawn_random("day", surface, biome)   # skeleton knights and bone hounds guard the ruins by day
			return
		var animal_ground := ground in [Blocks.GRASS, Blocks.FROSTING, Blocks.SNOW, Blocks.FALL_GRASS, Blocks.DEAD_GRASS, Blocks.WHITE_MARBLE, Blocks.BLACK_ONYX, Blocks.SESAME_BUN]
		if animal_ground and not night and animals < ANIMAL_CAP and world.sees_sky(surface):
			_spawn_random("animal", surface, biome)
			return
		if night and biome != "candy" and hostiles < HOSTILE_CAP and not Blocks.is_water(ground) \
				and world.lamp_light_at(surface) == 0 and _far_from_players(Vector3(surface), players):
			_spawn_random("night", surface, biome)
			return

	# Cave spawn: look for a dark pocket of air under the surface.
	# (Worlds with the Deep look down there a lot of the time: it's big and dark.)
	var deep_try: bool = world.has_deep() and randf() < 0.4
	if hostiles >= HOSTILE_CAP or biome == "candy":   # (candy land is always safe, even deep down)
		return
	var low: int = 4 if world.depth == 0 else world.LOWER_CRUST.y + 2   # (gen 13: caves go on below y = 0)
	var y := randi_range(low, maxi(low + 1, top - 4))
	if deep_try:
		y = randi_range(world.deep_bottom() + 1, world.deep_top())
	for i in 12:
		var p := Vector3i(x, y - i, z)
		if p.y < world.floor_y() + 2:
			break
		if Blocks.is_solid(world.get_block(p + Vector3i.DOWN)) and _has_room(p, 2) \
				and not world.sees_sky(p) and world.lamp_light_at(p) == 0 \
				and _far_from_players(Vector3(p), players):
			_spawn_random("cave", p, biome)
			return


func _try_spawn_king(center: Vector3, players: Array) -> void:
	if world.gen_version >= 8:
		return   # newer worlds: the King lives in his temple (see _try_spawn_lair_boss)
	if _king_id != 0 or _king_cooldown > 0.0 or _biome(center) != "desert" or randf() > KING_CHANCE:
		return
	for attempt in 6:
		var a := randf() * TAU
		var x := floori(center.x + cos(a) * randf_range(30.0, 45.0))
		var z := floori(center.z + sin(a) * randf_range(30.0, 45.0))
		var top: int = world.surface_y(x, z)
		if top <= 0 or world.biome_at(x, z) != "desert":
			continue
		var p := Vector3i(x, top + 1, z)
		# Out in the open, not in a cave or under a tree.
		if _has_room(p, 3) and world.sees_sky(p) and _far_from_players(Vector3(p), players):
			spawn_king(Vector3(p) + Vector3(0.5, 0, 0.5))
			return


func spawn_king(pos: Vector3) -> int:
	if _king_id != 0 and _mobs.has(_king_id):
		return _king_id
	_king_id = spawn_mob("king_cougar", pos)
	if announce.is_valid():
		announce.call("The ground shakes... the KING COUGAR has appeared in the desert!")
	return _king_id


## The Yeti waits in the big chamber at the bottom of a mine shaft and wakes
## up when someone comes near. One at a time.
func _try_spawn_yeti(center: Vector3) -> void:
	if _yeti_id != 0 or _yeti_cooldown > 0.0:
		return
	for ch in world.mine_chambers_near(center, YETI_RANGE):
		if world.is_data_loaded(Vector3(ch)):
			spawn_boss("yeti", Vector3(ch) + Vector3(0.5, 0.0, 0.5))
			return


## Walk into a castle's courtyard and Grimskull rises from his throne.
## Get near a lair and its boss is there waiting (one per lair; it comes
## back a while after it's beaten).
func _try_spawn_lair_boss(center: Vector3, _players: Array) -> void:
	for l in world.lairs_near(center, LAIR_WAKE + 10.0):
		var id: String = l["id"]
		if _lair_cooldown.has(id) or (_lair_ids.has(id) and _mobs.has(_lair_ids[id])):
			continue
		if l["boss"] == "king_cougar" and world.gen_version < 8:
			continue   # older worlds: the King still roams the desert like before
		var spot := Vector3(l["pos"]) + Vector3(0.5, 0.05, 0.5)
		if Vector2(spot.x - center.x, spot.z - center.z).length() > LAIR_WAKE or not world.is_data_loaded(spot):
			continue
		var mid := 0
		if l["boss"] == "king_cougar":
			if _king_id != 0:
				continue
			mid = spawn_king(spot)
		elif l["boss"] == "chess_royals":
			mid = _spawn_royals(spot, id)
		else:
			mid = spawn_mob(l["boss"], spot)
			if announce.is_valid():
				var b := preload("res://scripts/boss_data.gd").get_boss(l["boss"])
				announce.call("The %s awakens in %s!" % [b.get("name", "boss").to_upper(), b.get("lair", "its lair")])
		if mid != 0:
			_lair_ids[id] = mid
			get_mob(mid).set_meta("lair", id)


## Bosses that call for help (boars, wolves, crows, ghosts) while fighting.
func _boss_summons(players: Array) -> void:
	for m in _mobs.values():
		var s: Dictionary = m.def.get("summon", {})
		if s.is_empty() or m.target_peer == 0:
			continue
		var t: float = m.get_meta("summon_t", s["every"] * 0.5) - SPAWN_INTERVAL
		if t > 0.0:
			m.set_meta("summon_t", t)
			continue
		m.set_meta("summon_t", s["every"])
		var helpers: Array = m.get_meta("helpers", []).filter(func(h: int) -> bool: return _mobs.has(h))
		for k in mini(s["count"], s["max"] - helpers.size()):
			var a := randf() * TAU
			var at: Vector3 = m.sim_pos + Vector3(cos(a) * 3.0, 0.3, sin(a) * 3.0)
			var hid := spawn_mob(s["type"], at)
			if hid != 0:
				helpers.append(hid)
				var h: Node3D = get_mob(hid)
				h.target_peer = m.target_peer   # they join the fight straight away
		m.set_meta("helpers", helpers)


## Walk into a dungeon for the first time and its guards are waiting.
func _wake_dungeon(center: Vector3) -> void:
	if world.gen_version < 7:
		return
	for s in world.sites_near(center, 40.0):
		if s["kind"] != "dungeon" or _dungeons_done.has(s["id"]):
			continue
		var room := Vector3(s["room"]) + Vector3(0.5, 0.05, 0.5)
		if room.distance_to(center) > 16.0 or not world.is_data_loaded(room):
			continue
		_dungeons_done[s["id"]] = true
		var guards := ["zombie", "skeleton", "skeleton_archer", "zombie"]
		for i in guards.size():
			var a := TAU * i / guards.size() + randf() * 0.5
			var gid := spawn_mob(guards[i], room + Vector3(cos(a) * 2.2, 0, sin(a) * 2.2))
			var g: Node3D = get_mob(gid)
			if g:
				g.set_meta("home", room)   # they guard the room: fight you there, but don't follow you out


func _try_spawn_grimskull(center: Vector3) -> void:
	if _grim_id != 0 or _grim_cooldown > 0.0:
		return
	var c: Vector3 = world.castle_near(center, GRIM_RANGE)
	if c.y < 0 or absf(center.y - c.y) > 14.0 or not world.is_data_loaded(c):
		return
	spawn_boss("grimskull", c + Vector3(0, 0, -5))


func spawn_boss(type: String, pos: Vector3) -> int:
	if type == "king_cougar":
		return spawn_king(pos)
	if type == "grimskull":
		if _grim_id != 0 and _mobs.has(_grim_id):
			return _grim_id
		_grim_id = spawn_mob("grimskull", pos)
		if announce.is_valid():
			announce.call("Two skulls laugh at once... GRIMSKULL has risen from his throne! (Fire on the left, ice on the right!)")
		return _grim_id
	if type == "yeti":
		if _yeti_id != 0 and _mobs.has(_yeti_id):
			return _yeti_id
		_yeti_id = spawn_mob("yeti", pos)
		if announce.is_valid():
			announce.call("A terrible roar echoes from deep in the mine... the YETI is awake!")
		return _yeti_id
	return spawn_mob(type, pos)


## (Host) /hunt: send mobs after a player. 1 = cats and dogs, 2 = bears,
## 3 = cave trolls and gremlins, 4 = a boss. Returns how many came.
const HUNTS := [
	["wolf", "wolf", "dire_wolf", "cougar", "fox", "black_cat", "bone_hound"],
	["bear", "bear", "sand_bear", "polar_bear"],
	["cave_troll", "cave_troll", "gremlin", "gremlin", "gremlin", "gremlin"],
	[],
]
const HUNT_BOSSES := ["boar_king", "oakheart", "gummy_giant", "scarecrow_king", "yeti", "lantern_witch", "king_cougar", "clown", "fire_giant"]


func send_hunt(peer: int, tier: int, at: Vector3) -> int:
	var kinds: Array = HUNTS[clampi(tier, 1, 4) - 1]
	if tier >= 4:
		kinds = [HUNT_BOSSES[randi() % HUNT_BOSSES.size()]]
	var n := 0
	for i in kinds.size():
		var spot := _hunt_spot(at, 10.0 + randf() * 5.0 if tier < 4 else 14.0)
		if spot.y < 0:
			continue
		var id := spawn_boss(kinds[i], spot) if tier >= 4 else spawn_mob(kinds[i], spot)
		var m: Node3D = get_mob(id)
		if m == null:
			continue
		m.hunt_peer = peer
		m.target_peer = peer
		m._mode = "chase"
		m._anger_timer = 600.0   # angry for a long time (and not scared of the sun)
		n += 1
	return n


func _hunt_spot(at: Vector3, r: float) -> Vector3:
	for attempt in 10:
		var a := randf() * TAU
		var x := floori(at.x + cos(a) * r)
		var z := floori(at.z + sin(a) * r)
		var top: int = world.surface_y(x, z)
		if top > 0 and _has_room(Vector3i(x, top + 1, z), 2):
			return Vector3(x + 0.5, top + 1.05, z + 0.5)
	return Vector3(0, -1, 0)


# --- Villagers ----------------------------------------------------------------------
var _camp_ids := {}            # camp id -> [mob ids]
const CAMP_WAKE := 56.0        # villagers come out when someone is this close
const VILLAGER_LEASH := 9.0    # they wander this far from their house


func _wake_camp(center: Vector3) -> void:
	for cp in world.camps_near(center, CAMP_WAKE):
		var id: String = cp["id"]
		var alive: Array = _camp_ids.get(id, []).filter(func(i: int) -> bool: return _mobs.has(i))
		if not alive.is_empty():
			_camp_ids[id] = alive
			continue
		var c: Vector2i = cp["center"]
		if not world.is_data_loaded(Vector3(c.x, 0, c.y)):
			continue
		var made := []
		var houses: Array = cp["houses"]
		for i in mini(houses.size(), 4):
			var hs: Dictionary = houses[i]
			var door: Vector2i = hs["door"]
			var spot := Vector2(c + hs["at"]) + Vector2(door) * (maxf(hs["w"], hs["d"]) + 2.0) + Vector2(0.5, 0.5)
			var y := float(cp["ground"]) + 1.05
			var mid := spawn_mob(VillagerData.mob_type(cp["biome"]), Vector3(spot.x, y, spot.y))
			var m: Node3D = get_mob(mid)
			if m:
				m.set_meta("home", Vector3(spot.x, y, spot.y))
				m.set_meta("camp", id)
				m.set_meta("index", i)
				made.append(mid)
		_camp_ids[id] = made


## A villager potters around in front of their house.
func _tick_villager(m: Node3D, dt: float) -> void:
	m.server_tick(dt, world, [], on_attack, true)
	var home: Vector3 = m.get_meta("home", m.sim_pos)
	var off: Vector3 = home - m.sim_pos
	off.y = 0
	if off.length() > VILLAGER_LEASH:
		m._mode = "wander"
		m._mode_timer = 1.0
		m._wander_dir = off.normalized()


func _has_room(p: Vector3i, h: int) -> bool:
	for i in h:
		if not Blocks.is_open(world.get_block(p + Vector3i(0, i, 0))):
			return false
	return true


func _far_from_players(p: Vector3, players: Array) -> bool:
	for pl in players:
		if pl["pos"].distance_to(p) < SAFE_SPAWN_DISTANCE:
			return false
	return true


func _spawn_random(rule: String, p: Vector3i, biome: String) -> void:
	var choices: Array[String] = []
	var total := 0
	for t in MobData.MOBS:
		var d: Dictionary = MobData.MOBS[t]
		if MobData.spawns_in(t, rule) and MobData.lives_in(t, biome) and d.get("weight", 0) > 0 \
				and Vector2(p.x, p.z).length() >= d.get("min_dist", 0.0) \
				and bool(d.get("deep", false)) == (rule == "cave" and world.has_deep() and p.y <= world.deep_top()) \
				and bool(d.get("hot", false)) == (rule == "cave" and p.y <= world.deep_top() and world.is_lava_cavern(p.x, p.z)):
			choices.append(t)
			total += d["weight"]
	if choices.is_empty():
		return
	var roll := randi() % total
	for t in choices:
		roll -= MobData.MOBS[t]["weight"]
		if roll < 0:
			# Animals come in small groups.
			var group := randi_range(1, 3) if rule == "animal" and MobData.MOBS[t]["kind"] == "passive" else 1
			for g in group:
				var off := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)) if g > 0 else Vector3.ZERO
				spawn_mob(t, Vector3(p) + Vector3(0.5, 0.0, 0.5) + off)
			return


## Mobs vanish once nobody can see them (beyond the server's view distance).
func _despawn(players: Array, is_day: bool) -> void:
	var view: float = maxf(64.0, world.render_distance * 16.0)
	for m in _mobs.values():
		if m.is_friendly_npc() and not m.is_villager():
			continue
		var nearest := INF
		for p in players:
			nearest = minf(nearest, m.sim_pos.distance_to(p["pos"]))
		var gone := nearest > view
		if m.is_boss():
			gone = nearest > KING_LEASH
		elif is_day and m.fleeing_sun_time > 0.0:
			# Running from the sun: gone once out of view, or after a while if it got stuck far off.
			gone = gone or (m.fleeing_sun_time > 60.0 and nearest > 24.0)
		if gone:
			if m.mob_id == _king_id:
				_king_id = 0
			if m.mob_id == _yeti_id:
				_yeti_id = 0
			if m.mob_id == _grim_id:
				_grim_id = 0
			remove_mob(m.mob_id)


# --- QtMaMe -------------------------------------------------------------------------

## Where QtMaMe is, for the music that helps you find her. Once a friend has
## brought her home to their bed she's "settled", and the music stops for good.
var npc_beacon := {"pos": Vector3.ZERO, "active": false}
var _beacon_timer := 0.0
const NPC_SETTLED_RADIUS := 16.0


func _tick_beacon(delta: float) -> void:
	_beacon_timer -= delta
	if _beacon_timer > 0.0:
		return
	_beacon_timer = 1.0
	var npc := get_npc()
	if npc == null or _npc.is_empty():
		return
	if not _npc.get("settled", false) and _npc.get("friend", "") != "":
		var home: Vector3 = _npc.get("home", Vector3(0, -1, 0))
		if home.y >= 0.0 and Vector2(home.x - npc.sim_pos.x, home.z - npc.sim_pos.z).length() < NPC_SETTLED_RADIUS:
			_npc["settled"] = true
			if announce.is_valid():
				announce.call("QtMaMe has moved in! Her music goes quiet now that everyone knows where she lives.")
	var active: bool = not _npc.get("settled", false)
	if multiplayer.has_multiplayer_peer() and not multiplayer.get_peers().is_empty():
		_receive_beacon.rpc(npc.sim_pos, active)
	else:
		_receive_beacon(npc.sim_pos, active)


@rpc("authority", "call_local", "unreliable")
func _receive_beacon(pos: Vector3, active: bool) -> void:
	npc_beacon = {"pos": pos, "active": active}


func _update_npc_home(delta: float) -> void:
	_tick_beacon(delta)
	_npc_refresh -= delta
	if _npc_refresh > 0.0 or _npc.is_empty() or _npc.get("friend", "") == "" or not bed_for.is_valid():
		return
	_npc_refresh = NPC_HOME_REFRESH
	var bed: Vector3i = bed_for.call(_npc["friend"])
	if bed.y >= 0:
		_npc["home"] = Vector3(bed) + Vector3(0.5, 1.0, 0.5)


func _tick_npc(m: Node3D, dt: float, players: Array) -> void:
	var home: Vector3 = _npc.get("home", m.sim_pos)
	# Keep after the monster she's already fighting while it's still near home.
	var enemy: Node3D = _mobs.get(_npc_enemy)
	if enemy == null or enemy.sim_pos.distance_to(home) > NPC_GUARD_RADIUS:
		enemy = null
		var best := NPC_HELP_RADIUS
		for other in _mobs.values():
			if other.def["kind"] == "hostile" and not other.is_boss():
				var d: float = other.sim_pos.distance_to(m.sim_pos)
				if d < best:
					best = d
					enemy = other
	_npc_enemy = enemy.mob_id if enemy else 0
	m.npc_tick(dt, world, home, enemy, func(target: Node3D) -> void:
		damage_mob(target.mob_id, m.def.get("damage", 1.5), 0, m.sim_pos))
	# Far from home and stuck (or her path isn't loaded)? Hop there when nobody's watching.
	var far: bool = Vector2(home.x - m.sim_pos.x, home.z - m.sim_pos.z).length() > 48.0
	if far or m.stuck_time > 8.0:
		var watched := false
		for p in players:
			if p["pos"].distance_to(m.sim_pos) < 32.0:
				watched = true
		if not watched:
			m.sim_pos = world.safe_ground(home)  # on open ground, never in a hole or a cave
			m.velocity = Vector3.ZERO
			m.stuck_time = 0.0


# --- Spawning / damage --------------------------------------------------------------

# --- Fairies ------------------------------------------------------------------------
# Each fairy village has 2-5 fairies (one per tiny house). Their colors and
# brightness come from the world seed, so a village always has the same ones.
# A fairy belongs to nobody until a player befriends it (one per player); then
# it follows them. When they die it flies home to their bed and waits.

func _wake_fairies(center: Vector3) -> void:
	for v in world.fairy_villages_near(center, FAIRY_RANGE):
		if not _fairy_villages_done.has(v["id"]):
			_fairy_villages_done[v["id"]] = true
			for i in v["houses"].size():
				var h: int = world._hash(v["center"].x * 31 + i * 7, v["center"].y * 17 + i * 13)
				_fairies["%s_%d" % [v["id"], i]] = {"village": v["id"], "center": Vector3(v["center"].x, 0, v["center"].y),
						"color": h % MobData.FAIRY_COLORS.size(), "bright": 0.4 + ((h >> 8) % 61) / 100.0,
						"owner": "", "state": "village", "home": Vector3(0, -1, 0), "id": 0}
	# Make sure every fairy that should be out right now exists.
	for k in _fairies:
		var f: Dictionary = _fairies[k]
		if f["id"] != 0 and _mobs.has(f["id"]):
			continue
		var owner_online: bool = f["owner"] != "" and owner_peer.is_valid() and owner_peer.call(f["owner"]) != 0
		var at := _fairy_target(f, _players_by_peer())
		if at.y < 0:
			continue
		var show := false
		if f["owner"] == "":
			show = center.distance_to(at) < FAIRY_RANGE
		else:
			show = owner_online and (f["state"] == "follow" or center.distance_to(at) < FAIRY_RANGE)
		if show:
			f["id"] = spawn_mob("fairy", at, {"color": f["color"], "bright": f["bright"], "key": k})


func _players_by_peer() -> Dictionary:
	var out := {}
	for p in get_players.call():
		out[p["peer"]] = p
	return out


func _fairy_key_of(mob_id: int) -> String:
	for k in _fairies:
		if _fairies[k]["id"] == mob_id:
			return k
	return ""


## Where a fairy wants to be right now (y = -1 if it shouldn't be out).
func _fairy_target(f: Dictionary, players_by_peer: Dictionary) -> Vector3:
	var t := Time.get_ticks_msec() / 1000.0
	match f["state"]:
		"follow":
			var peer: int = owner_peer.call(f["owner"]) if owner_peer.is_valid() else 0
			if not players_by_peer.has(peer):
				return Vector3(0, -1, 0)
			var p: Vector3 = players_by_peer[peer]["pos"]
			return p + Vector3(cos(t * 1.3) * 0.9, 1.9 + sin(t * 2.1) * 0.15, sin(t * 1.3) * 0.9)
		"home":
			var h: Vector3 = f["home"]
			if h.y < 0:
				return Vector3(0, -1, 0)
			return h + Vector3(cos(t) * 0.6, 1.4 + sin(t * 1.7) * 0.1, sin(t) * 0.6)
	var c: Vector3 = f["center"]
	var ground: float = world.surface_height(int(c.x), int(c.z)) + 1.0
	var phase: float = float(hash(f["village"]) % 100) + f["color"] * 1.7
	return Vector3(c.x + cos(t * 0.5 + phase) * 4.0, ground + 2.0 + sin(t + phase) * 0.6, c.z + sin(t * 0.5 + phase) * 4.0)


func _tick_fairy(m: Node3D, dt: float, players: Array) -> void:
	var key: String = m.variant.get("key", "")
	if not _fairies.has(key):
		remove_mob(m.mob_id)
		return
	var f: Dictionary = _fairies[key]
	var by_peer := {}
	for p in players:
		by_peer[p["peer"]] = p
	var peer: int = owner_peer.call(f["owner"]) if f["owner"] != "" and owner_peer.is_valid() else 0
	if f["owner"] == "":
		var anyone := false
		for p in players:
			if p["pos"].distance_to(f["center"] + Vector3(0, p["pos"].y, 0)) < FAIRY_RANGE * 1.5:
				anyone = true
		if not anyone:
			remove_mob(m.mob_id)  # nobody near the village: hide until someone comes back
			f["id"] = 0
			return
	var before: String = f["state"]
	if f["owner"] != "" and peer == 0:
		# The owner left the game: wait at their bed, out of sight.
		f["state"] = "home"
		f["home"] = _bed_or_spawn(f["owner"])
		remove_mob(m.mob_id)
		f["id"] = 0
		return
	if f["state"] == "follow" and by_peer.has(peer) and not by_peer[peer]["alive"]:
		f["state"] = "home"  # the owner died: fly home to their bed
		f["home"] = _bed_or_spawn(f["owner"])
	elif f["state"] == "home" and by_peer.has(peer) and by_peer[peer]["alive"] \
			and by_peer[peer]["pos"].distance_to(f["home"]) < 7.0:
		f["state"] = "follow"  # back together!
	if f["state"] != before and fairy_changed.is_valid():
		fairy_changed.call(f["owner"])
	var target := _fairy_target(f, by_peer)
	if target.y < 0:
		return
	var face: Vector3 = target + Vector3(0, 0, -1)
	if f["state"] == "follow" and by_peer.has(peer):
		face = by_peer[peer]["pos"] + Vector3(0, 1.6, 0)
	m.fly_tick(dt, target, face)


func _bed_or_spawn(owner_key: String) -> Vector3:
	var bed: Vector3i = bed_pos_for.call(owner_key) if bed_pos_for.is_valid() else Vector3i(0, -1, 0)
	if bed.y >= 0:
		return Vector3(bed) + Vector3(0.5, 0.0, 0.5)
	return world.find_spawn_point()


## Server: a player wants to befriend this fairy. Returns a message for them.
func befriend_fairy(mob_id: int, owner_key: String) -> String:
	var key := _fairy_key_of(mob_id)
	if key.is_empty():
		return ""
	var f: Dictionary = _fairies[key]
	if f["owner"] == owner_key:
		return "This fairy is already your friend."
	if f["owner"] != "":
		return "This fairy already has a friend."
	for k in _fairies:
		if _fairies[k]["owner"] == owner_key:
			return "You already have a fairy friend. A fairy stays with you forever!"
	f["owner"] = owner_key
	f["state"] = "follow"
	if fairy_changed.is_valid():
		fairy_changed.call(owner_key)
	var color_name: String = MobData.FAIRY_COLORS[f["color"]][0]
	return "A %s %s fairy is now your friend! %s." % [MobData.brightness_name(f["bright"]).to_lower(),
			color_name.to_lower(), MobData.fairy_text(f["color"], f["bright"])]


## The fairy power a character has right now (only while their fairy is with them).
func fairy_buff(owner_key: String) -> Dictionary:
	for k in _fairies:
		var f: Dictionary = _fairies[k]
		if f["owner"] == owner_key:
			if f["state"] != "follow":
				return {}
			return {"type": MobData.FAIRY_COLORS[f["color"]][2], "power": MobData.buff_power(f["color"], f["bright"]),
					"color": f["color"], "bright": f["bright"], "text": MobData.fairy_text(f["color"], f["bright"]),
					"name": "%s %s Fairy" % [MobData.brightness_name(f["bright"]), MobData.FAIRY_COLORS[f["color"]][0]]}
	return {}


func fairy_info(mob_id: int) -> Dictionary:
	return _fairies.get(_fairy_key_of(mob_id), {})


## Server: create a mob for everyone.
## Set by main: ranged mobs shoot through this (survival.mob_shoot).
var on_shoot: Callable


## How tough the monsters are here: by biome (the gentle starting lands are 0,
## the floating islands are 3) plus up to 2 more the further you are from
## spawn. Hostile and grumpy mobs get more health and hit harder.
const BIOME_DANGER := {"plains": 0.0, "forest": 0.0, "candy": 0.0, "desert": 1.0, "fall": 1.0,
		"mountain": 2.0, "spooky": 2.0, "sky": 3.0, "chess": 1.5, "fastfood": 1.5}

func danger_at(pos: Vector3) -> float:
	var d: float = BIOME_DANGER.get(world.biome_at(pos.x, pos.z), 1.0) if world else 0.0
	var far := Vector2(pos.x, pos.z).length()
	return snappedf(d + clampf((far - 300.0) / 700.0, 0.0, 2.0), 0.1)


func spawn_mob(type: String, pos: Vector3, extra := {}) -> int:
	if not multiplayer.is_server() or not MobData.MOBS.has(type):
		return 0
	var mdef: Dictionary = MobData.MOBS[type]
	if not extra.has("danger") and not mdef.get("boss", false) and mdef.get("kind", "") in ["hostile", "neutral"]:
		extra = extra.duplicate()
		extra["danger"] = danger_at(pos)
	var id := _next_id
	_next_id += 1
	var yaw := randf() * TAU
	_spawn_local(id, type, pos, yaw, extra)
	_receive_spawn.rpc(id, type, pos, yaw, extra)
	var made: Node3D = _mobs.get(id)
	if made and on_shoot.is_valid():
		made.on_shoot = on_shoot

	if type == "king_cougar":
		_king_id = id
	return id


func remove_mob(id: int) -> void:
	if _mobs.has(id):
		_despawn_local(id)
		_receive_despawn.rpc(id)


## Server: something hits a mob. attacker_peer 0 = not a player (QtMaMe).
## Returns true if it died.
func damage_mob(id: int, amount: float, attacker_peer: int, attacker_pos: Vector3) -> bool:
	var m: Node3D = _mobs.get(id)
	if m == null:
		return false
	if m.is_friendly_npc():
		return false  # QtMaMe and fairies can't be hurt
	if m.is_boss() and attacker_peer > 0:
		var dmg: Dictionary = m.get_meta("boss_damage", {})
		var partner: Node3D = _mobs.get(int(m.get_meta("pair", 0))) if m.has_meta("pair") else null
		var fresh: bool = dmg.is_empty() and (partner == null or partner.get_meta("boss_damage", {}).is_empty())
		if fresh and announce.is_valid():
			announce.call("%s is fighting the %s!" % [_who(attacker_peer), str(MobData.get_def(m.type).get("pair_name", MobData.display_name(m.type))).to_upper()])
			m.set_meta("boss_start", Time.get_ticks_msec())
		dmg[attacker_peer] = dmg.get(attacker_peer, 0.0) + minf(amount, maxf(m.hp, 0.0))
		m.set_meta("boss_damage", dmg)
	m.hp -= amount
	m.on_hurt(attacker_peer, attacker_pos, 6.0)
	_receive_hurt.rpc(id)
	var mdef: Dictionary = MobData.get_def(m.type)
	if mdef.get("enrage", false) and m.hp > 0.0 and m.hp < float(m.max_hp) * 0.5 and not m.has_meta("enraged"):
		# Half beaten: he gets angry. Hits harder, throws fire faster, moves quicker.
		m.set_meta("enraged", true)
		m.dmg_mult *= 1.3
		m.def = m.def.duplicate(true)
		m.def["speed"] = float(m.def["speed"]) * 1.25
		if m.def.has("ranged"):
			m.def["ranged"]["every"] = float(m.def["ranged"]["every"]) * 0.6
		if announce.is_valid():
			announce.call("The %s is ENRAGED! The cavern shakes!" % MobData.display_name(m.type).to_upper())
	if m.hp <= 0.0:
		var attackers: Array = m.attackers.keys()
		if m.mob_id == _king_id:
			_king_id = 0
			_king_cooldown = KING_COOLDOWN
		if m.mob_id == _yeti_id:
			_yeti_id = 0
			_yeti_cooldown = YETI_COOLDOWN
		if m.mob_id == _grim_id:
			_grim_id = 0
			_grim_cooldown = GRIM_COOLDOWN
		if m.has_meta("pair") and _hand_over_royal(m):
			remove_mob(id)
			return true
		if m.is_boss() and announce.is_valid():
			announce.call(_boss_report(m, attacker_peer))
		if m.has_meta("lair"):
			_lair_cooldown[m.get_meta("lair")] = LAIR_COOLDOWN
			_lair_ids.erase(m.get_meta("lair"))
		mob_killed.emit(m.type, m.sim_pos, m.yaw, attacker_peer, attackers)
		remove_mob(id)
		return true
	return false


func _who(peer: int) -> String:
	return str(name_of.call(peer)) if name_of.is_valid() else "Someone"


## The King & Queen: both white or both black (a new pick each time they
## wake, so beat them again for the other color's sword). Returns the King.
func _spawn_royals(spot: Vector3, lair_id: String) -> int:
	var col := "white" if randi() % 2 == 0 else "black"
	var king := spawn_mob(col + "_king", spot + Vector3(-2.5, 0, 3.0))
	var queen := spawn_mob(col + "_queen", spot + Vector3(2.5, 0, 3.0))
	if king == 0 or queen == 0:
		return king
	get_mob(king).set_meta("pair", queen)
	get_mob(queen).set_meta("pair", king)
	get_mob(queen).set_meta("lair", lair_id)
	if announce.is_valid():
		announce.call("The %s awaken in the black and white castle!" % MobData.get_def(col + "_king")["pair_name"].to_upper())
	return king


## A King or Queen fell while the other still stands: the survivor takes over
## everyone's damage (so the treasure goes to all who fought) and gets angry.
func _hand_over_royal(m: Node3D) -> bool:
	var other: Node3D = _mobs.get(int(m.get_meta("pair", 0)))
	if other == null or other.hp <= 0.0:
		return false
	for a in m.attackers:
		other.attackers[a] = m.attackers[a]
	var od: Dictionary = other.get_meta("boss_damage", {})
	var md: Dictionary = m.get_meta("boss_damage", {})
	for k in md:
		od[k] = od.get(k, 0.0) + md[k]
	other.set_meta("boss_damage", od)
	if m.has_meta("boss_start"):
		other.set_meta("boss_start", mini(int(other.get_meta("boss_start", m.get_meta("boss_start"))), int(m.get_meta("boss_start"))))
	other.remove_meta("pair")
	other.dmg_mult *= 1.35
	if m.has_meta("lair"):
		other.set_meta("lair", m.get_meta("lair"))
		_lair_ids[m.get_meta("lair")] = other.mob_id
	if announce.is_valid():
		announce.call("The %s has fallen! The %s is furious!" % [MobData.display_name(m.type).to_upper(), MobData.display_name(other.type).to_upper()])
	return true


## "Kian beat the YETI in 2:14! Damage: Kian 310, Dad 190"
func _boss_report(m: Node3D, killer: int) -> String:
	var dmg: Dictionary = m.get_meta("boss_damage", {})
	var secs := int((Time.get_ticks_msec() - int(m.get_meta("boss_start", Time.get_ticks_msec()))) / 1000.0)
	var order := dmg.keys()
	order.sort_custom(func(a, b) -> bool: return dmg[a] > dmg[b])
	var parts := PackedStringArray()
	for p in order:
		parts.append("%s %d" % [_who(p), roundi(dmg[p])])
	var who := _who(killer) if killer > 0 else "Someone"
	var team := ""
	if order.size() > 1:
		team = " with help from %s" % ", ".join(PackedStringArray(order.filter(func(p) -> bool: return p != killer).map(func(p) -> String: return _who(p))))
	var boss_name: String = MobData.get_def(m.type).get("pair_name", MobData.display_name(m.type))
	return "%s beat the %s%s in %d:%02d!  Damage: %s" % [who, boss_name.to_upper(), team, secs / 60, secs % 60,
			", ".join(parts) if not parts.is_empty() else "-"]


## Server -> one new player: every mob that already exists.
func send_snapshot(peer: int) -> void:
	for m in _mobs.values():
		_receive_spawn.rpc_id(peer, m.mob_id, m.type, m.sim_pos, m.yaw, m.variant)   # (variant carries its danger)


func _spawn_local(id: int, type: String, pos: Vector3, yaw: float, extra := {}) -> void:
	if _mobs.has(id):
		return
	var m := Mob.new()
	m.setup(id, type, pos, yaw, extra)
	m.name = "Mob%d" % id
	add_child(m)
	_mobs[id] = m
	if type == "king_cougar" or type == "yeti":
		m.voice()  # announce himself with a roar


func _despawn_local(id: int) -> void:
	var m: Node3D = _mobs.get(id)
	if m:
		_mobs.erase(id)
		m.queue_free()


# --- Network -------------------------------------------------------------------------

@rpc("authority", "reliable")
func _receive_spawn(id: int, type: String, pos: Vector3, yaw: float, extra := {}) -> void:
	_spawn_local(id, type, pos, yaw, extra)
	if type == "qtmame":
		_npc_id = id
	elif type == "king_cougar":
		_king_id = id
	elif type == "yeti":
		_yeti_id = id


@rpc("authority", "reliable")
func _receive_despawn(id: int) -> void:
	_despawn_local(id)


@rpc("authority", "call_local", "unreliable")
func _receive_hurt(id: int) -> void:
	var m: Node3D = _mobs.get(id)
	if m:
		m.flash()


@rpc("authority", "unreliable_ordered")
func _receive_states(data: PackedFloat32Array) -> void:
	for i in range(0, data.size(), 7):
		var m: Node3D = _mobs.get(int(data[i]))
		if m:
			m.set_remote_state(Vector3(data[i + 1], data[i + 2], data[i + 3]), data[i + 4], data[i + 5] > 0.5, data[i + 6])
