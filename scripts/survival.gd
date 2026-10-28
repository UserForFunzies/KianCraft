extends Node
## Survival rules: inventories, armor, health, toots, crafting, smelting, the
## Block Shop and QtMaMe, chests, dropped items, trading, doors, beds, torches,
## death and loot.
##
## The server is the referee. Clients send requests ("break this block",
## "move 5 dirt into the chest") with the req_* functions; the server checks the
## rules, changes its copy of the state, and sends players their updated state.
## The host uses exactly the same path, so there's one set of rules.
##
## Per-character state (saved in the world file by character id, see characters.gd):
##   inventory (40 slots: 0-8 hotbar, 9-35 backpack, 36-39 armor),
##   toots, unlocked recipes, health, bed (respawn point) and how often each bed was used.
##
## Moving items around ("areas"):
##   "inv"  = your inventory          "open" = whatever container you have open
##   (chest, furnace, loot bag/corpse, or your side of a trade).

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Inv = preload("res://scripts/inventory.gd")
const Blocks = preload("res://scripts/blocks.gd")
const MobData = preload("res://scripts/mob_data.gd")
const VillagerData = preload("res://scripts/villager_data.gd")
const BossData = preload("res://scripts/boss_data.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const Sound = preload("res://scripts/sound.gd")

const MAX_HEALTH := 20.0
const REACH := 8.0              # how far away (server check) you can use blocks
const STATION_REACH := 6.0      # how close you must be to a workbench/shop/trader
const ATTACK_REACH := 5.0
const ATTACK_COOLDOWN := 0.4
const REGEN_DELAY := 8.0        # seconds without damage before healing starts
const REGEN_INTERVAL := 4.0     # then +1 health this often
const CORPSE_SECONDS := 300.0   # mob corpses vanish after 5 minutes
const DROP_SECONDS := 300.0     # items on the ground vanish after 5 minutes
const DROP_PICKUP_DELAY := 1.2  # seconds before a thrown item can be picked up
const TORCH_SECONDS := 300.0    # torches burn out after 5 minutes
const CHEST_SIZE := 27
const TRADE_SIZE := 9
const TRADER_BONUS := 2.0       # QtMaMe pays double
const ARMOR_PER_POINT := 0.04   # (old: 4% per point; now see protection())
const ARMOR_HALF := 18.0         # this many armor points block half the damage
const ARMOR_MAX_BLOCK := 0.85    # nothing blocks more than this
const SLEEP_SECONDS := 2.5      # everyone in bed this long = skip the night
const MAX_AIR := 10.0           # seconds you can hold your breath
const AIR_REFILL := 4.0         # air per second back in the open
const DROWN_DAMAGE := 2.0       # per second once you're out of air
const COLD_INTERVAL := 4.0      # seconds between cold damage in the snowy mountains
const COLD_DAMAGE := 1.0
const NO_POS := Vector3i(0, -1, 0)
const TOOL_NAMES := ["", "wooden pickaxe", "stone pickaxe", "bronze pickaxe", "iron pickaxe", "titanium pickaxe"]

signal self_changed             # this computer's player state changed
signal container_changed        # the open container changed (or closed)
signal notice(text: String)     # short message for the HUD
signal died(cause: String)
signal respawned(pos: Vector3)
signal hurt
signal sleep_changed(sleeping: bool, bed: Vector3i)
signal trade_invited(from_peer: int, from_name: String)
signal party_invited(from_peer: int, from_name: String, party_name: String)
signal party_changed
signal legendary_found(item: String)
signal map_received             # the map you opened arrived (see map_view)
signal arena_countdown           # 3, 2, 1, FIGHT!
signal map_updated(regions: Array)  # more of it filled in, or its marks changed ([] = marks)

var main: Node                  # main.gd (players, world, mobs, chat)

# --- Server ---
var _states := {}               # peer id -> state
var _saved := {}                # character id -> state (saved / offline players)
var _furnaces := {}             # Vector3i -> {"slots": [in, fuel, out], "burn", "burn_max", "progress"}
var _chests := {}               # Vector3i -> slots
var _loot := {}                 # id -> {"kind", "mob", "pos", "yaw", "slots", "age", "owner", "locked"}
var _next_loot := 1
var _drops := {}                # id -> {"id", "count", "pos", "vel", "age", "delay", "resting"}
var _next_drop := 1
var _torches := {}              # Vector3i -> seconds left
var _saplings := {}             # Vector3i -> world time when it grows into a tree
var _decay := {}                # Vector3i -> seconds until these leaves fall (their tree was chopped)
var _sapling_given := {}        # tree (its base) -> saplings it has dropped so far
var _sapling_timer := 0.0
var _maps := {}                 # map id -> {"maker", "regions": {Vector2i: PackedByteArray bits}, "marks": [...]}
var _next_map := 1
var _map_viewers := {}          # peer -> id of the map they're looking at
var _map_dirty := {}            # map id -> {region key: true} filled in since we last told viewers
var _map_timer := 0.0
var _trades := {}               # id -> {"a", "b", "offer": {peer: slots}, "toots": {peer: float}, "ready": {peer: bool}}
var _next_trade := 1
var _invites := {}              # target peer -> {"from": peer, "time": float}
var _viewers := {}              # peer id -> {"kind": "furnace"/"chest"/"loot"/"trade", "key"}
var _attack_times := {}
var _armor_sent := {}           # peer -> last armor list sent to everyone
var _container_sync := 0.0
var _drop_sync := 0.0
var _sleep_timer := 0.0

# --- Client (this computer's player) ---
var me := {}                    # {"inventory", "toots", "unlocked", "health", "alive", "armor"}
var open_kind := ""             # "furnace", "chest", "loot", "trade" or ""
var map_view := {}              # the map you're looking at: {"id", "maker", "regions", "marks"}
var open_key = null
var open_slots: Array = []
var open_extra := {}
var _loot_nodes := {}           # loot id -> Node3D (corpses and bags, on every computer)
var _arrow_nodes := {}          # arrow id -> {"node", "vel", "stuck", "age"} (drawn on every computer)
var _drop_nodes := {}           # drop id -> Node3D
var _drop_targets := {}         # drop id -> Vector3 (smooth movement)
var _clock := 0.0


static func new_state(player_name: String) -> Dictionary:
	return {"name": player_name, "inventory": Inv.make(Inv.PLAYER_SIZE), "toots": 0.0,
			"unlocked": {}, "health": MAX_HEALTH, "alive": true, "hurt_time": -1000.0, "regen": 0.0,
			"bed": NO_POS, "beds": {}, "sleeping": false, "air": MAX_AIR, "drown": 0.0, "cold": 0.0,
			"seen": {}, "known": {}, "ender": Inv.make(CHEST_SIZE)}


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## How long breaking a block takes with the given tool (INF = you can't).
static func break_time(block: int, tool: Dictionary) -> float:
	var hardness: float = Blocks.HARDNESS[block]
	if hardness < 0.0 or not can_harvest(block, tool):
		return INF
	var speed: float = tool.get("speed", 1.0) if tool.get("tool", "") == Blocks.TOOL[block] else 1.0
	return hardness / speed


static func can_harvest(block: int, tool: Dictionary) -> bool:
	var tier: int = Blocks.MIN_TIER[block]
	if tier == 0:
		return true
	return tool.get("tool", "") == Blocks.TOOL[block] and tool.get("tier", 0) >= tier


static func needed_tool_text(block: int) -> String:
	var tier: int = Blocks.MIN_TIER[block]
	return "a %s or better" % TOOL_NAMES[clampi(tier, 0, TOOL_NAMES.size() - 1)]


## Total armor points worn (each shield on the HUD = 2 points).
static func armor_points(inv: Array) -> int:
	var total := 0
	for i in range(Inv.ARMOR_START, mini(Inv.PLAYER_SIZE, inv.size())):
		if inv[i] != null:
			total += roundi(float(Items.get_def(inv[i]["id"]).get("armor", 0)) * quality(inv[i]))
	return total


# --- Legendary rolls ---------------------------------------------------------------
# Every legendary a boss drops rolls how good it came out (85-100%). Its
# damage, armor, digging speed and powers scale with it. A 100% roll is
# "Perfect" (it says so in front of its name).

const LEGEND_ROLL := Vector2(0.85, 1.0)
const PERFECT_CHANCE := 0.08     # on top of rolling 100% the normal way
const PERFECT := 0.995


## How good this exact item came out (1.0 for things that don't roll).
static func quality(slot) -> float:
	if slot == null or not (slot is Dictionary):
		return 1.0
	if Items.get_def(slot.get("id", "")).get("rarity", "") != "legendary" or not slot.has("roll"):
		return 1.0
	return clampf(float(slot["roll"]), 0.5, 1.0)


static func is_perfect(slot) -> bool:
	return slot is Dictionary and slot.has("roll") and float(slot["roll"]) >= PERFECT


static func roll_legendary() -> float:
	if randf() < PERFECT_CHANCE:
		return 1.0
	return snappedf(randf_range(LEGEND_ROLL.x, LEGEND_ROLL.y), 0.01)


## How much of each hit your armor blocks (0..0.85). More armor always helps,
## but each extra point helps a little less: leather ~28%, bronze ~42%,
## iron ~55%, titanium ~65%, and legendary pieces on top.
static func protection(points: float) -> float:
	return minf(points / (points + ARMOR_HALF), ARMOR_MAX_BLOCK)


static func protection_of(inv: Array) -> float:
	return protection(armor_points(inv) + cute_armor(inv))


static func armor_ids(inv: Array) -> Array:
	var out := []
	for i in range(Inv.ARMOR_START, Inv.PLAYER_SIZE):
		out.append(inv[i]["id"] if i < inv.size() and inv[i] != null else "")
	return out


# --- Setup / saving (server) -------------------------------------------------------------

func server_start(save: Dictionary) -> void:
	_states.clear()
	_viewers.clear()
	_trades.clear()
	_invites.clear()
	_armor_sent.clear()
	_saved = save.get("players", {}).duplicate(true)
	for key in _saved:
		_saved[key] = _upgrade_state(_saved[key], _saved[key].get("name", key))
		_saved[key]["key"] = key
	_furnaces = save.get("furnaces", {}).duplicate(true)
	for pos in _furnaces:
		if _furnaces[pos]["slots"].size() < 4:
			_furnaces[pos]["slots"].resize(4)
		_fix_slots(_furnaces[pos]["slots"])
	_chests = save.get("chests", {}).duplicate(true)
	for pos in _chests:
		_fix_slots(_chests[pos])
	_torches = save.get("torches", {}).duplicate(true)
	_saplings = save.get("saplings", {}).duplicate(true)
	_sapling_given = save.get("sapling_given", {}).duplicate(true)
	_decay.clear()
	_loot.clear()
	_next_loot = 1
	for bag in save.get("bags", []):
		_fix_slots(bag["slots"])
		_create_loot(bag.get("kind", "bag"), "", bag["pos"], 0.0, bag["slots"], bag.get("owner", ""), bag.get("locked", ""))
	_drops.clear()
	_next_drop = 1
	for d in save.get("drops", []):
		var id := Items.resolve_alias(d["id"])
		if Items.exists(id):
			_spawn_drop(id, d["count"], d["pos"], Vector3.ZERO, 0.0, d.get("data", {}))
	_maps = save.get("maps", {}).duplicate(true)
	_portals = save.get("portals", {}).duplicate(true)
	_frames = save.get("frames", {}).duplicate(true)
	_stands = save.get("stands", {}).duplicate(true)
	_chest_names = save.get("chest_names", {}).duplicate(true)
	_arenas = save.get("arenas", {}).duplicate(true)
	_parties = save.get("parties", {}).duplicate(true)
	_trophies = save.get("trophies", {}).duplicate(true)
	shrine_center = save.get("shrine_center", NO_POS)
	_shrine_timer = 0.0
	_next_party = save.get("next_party", 1)
	_party_invites.clear()
	chest_names = _chest_names.duplicate()
	_refresh_chest_labels()
	_next_portal = save.get("next_portal", 1)
	_portal_cooldown.clear()
	_next_map = save.get("next_map", 1)
	_map_viewers.clear()
	_map_dirty.clear()


## Brings saves from older versions up to date (bigger inventory, new armor slots).
func _upgrade_state(st: Dictionary, player_name: String) -> Dictionary:
	var fresh := new_state(player_name)
	var older := not st.has("seen")
	for k in fresh:
		if not st.has(k):
			st[k] = fresh[k]
	if older:
		# From before research: count what they carry and what they've learned
		# as found, and don't pop up a list of everything they already knew.
		for id in st["unlocked"]:
			st["seen"][id] = true
			var r := Recipes.get_recipe(id)
			for input in r.get("in", {}):
				for c in Recipes.choices(r, input):
					st["seen"][c] = true
		for s in st["inventory"]:
			if s != null:
				st["seen"][s["id"]] = true
		for r in Recipes.RECIPES:
			if Recipes.needs_research(r) and Recipes.discovered(r, st["seen"]):
				st["known"][r["out"]] = true
	if st["ender"].size() < CHEST_SIZE:
		st["ender"].resize(CHEST_SIZE)
	_fix_slots(st["ender"])
	var inv: Array = st["inventory"]
	var old_armor = null
	if inv.size() == 37:
		old_armor = inv[36]
		inv.resize(36)
	inv.resize(Inv.PLAYER_SIZE)
	_fix_slots(inv)
	if old_armor != null:
		old_armor["id"] = Items.resolve_alias(old_armor["id"])
		var slot := Inv.armor_slot_for(old_armor["id"])
		if slot >= 0 and inv[slot] == null:
			inv[slot] = old_armor
		else:
			Inv.add(inv, old_armor["id"], old_armor["count"], Inv.PLAYER_SLOTS)
	st["sleeping"] = false
	return st


func _fix_slots(slots: Array) -> void:
	for i in slots.size():
		var s = slots[i]
		if s == null:
			continue
		s["id"] = Items.resolve_alias(s["id"])
		if not Items.exists(s["id"]):
			slots[i] = null


func export_save() -> Dictionary:
	var players := _saved.duplicate(true)
	for st in _states.values():
		players[st["key"]] = st.duplicate(true)
	# Items sitting in an open trade go back to their owners in the save.
	for t in _trades.values():
		for peer in [t["a"], t["b"]]:
			if _states.has(peer):
				var inv: Array = players[_states[peer]["key"]]["inventory"]
				for s in t["offer"][peer]:
					if s != null:
						Inv.add_slot(inv, s, Inv.PLAYER_SLOTS)
	var bags := []
	for l in _loot.values():
		if l["kind"] != "corpse":
			bags.append({"kind": l["kind"], "pos": l["pos"], "slots": l["slots"], "owner": l["owner"], "locked": l["locked"]})
	var drops := []
	for d in _drops.values():
		drops.append({"id": d["id"], "count": d["count"], "pos": d["pos"], "data": d.get("data", {})})
	return {"players": players, "furnaces": _furnaces, "chests": _chests, "bags": bags,
			"drops": drops, "torches": _torches, "saplings": _saplings.duplicate(), "sapling_given": _sapling_given.duplicate(), "maps": _maps.duplicate(true), "next_map": _next_map,
			"portals": _portals.duplicate(true), "next_portal": _next_portal,
			"frames": _frames.duplicate(true), "stands": _stands.duplicate(true),
			"chest_names": _chest_names.duplicate(true),
			"parties": _parties.duplicate(true), "next_party": _next_party,
			"trophies": _trophies.duplicate(true), "shrine_center": shrine_center, "arenas": _arenas.duplicate(true)}


## key: the character's id. Worlds from before characters existed saved
## players by name, so a character with the same name takes that over once.
func server_add_player(peer: int, player_name: String, key := "") -> void:
	if key.is_empty():
		key = player_name
	var saved: Dictionary = _saved.get(key, {})
	if saved.is_empty() and _saved.has(player_name) and not _saved[player_name].has("char_id"):
		saved = _saved[player_name]
		_saved.erase(player_name)
	var st: Dictionary = _upgrade_state((saved if not saved.is_empty() else new_state(player_name)).duplicate(true), player_name)
	st["name"] = player_name
	st["key"] = key
	st["char_id"] = key
	st["hurt_time"] = -1000.0
	_states[peer] = st
	_sync_self(peer)
	if not st["alive"]:
		_you_died.rpc_id(peer, "died while you were away")
	for id in _loot:
		var l: Dictionary = _loot[id]
		_loot_spawn.rpc_id(peer, id, l["kind"], l["mob"], l["pos"], l["yaw"], l["owner"])
	for id in _drops:
		var d: Dictionary = _drops[id]
		_drop_spawn.rpc_id(peer, id, d["id"], d["pos"])
	_send_portals(peer)
	_send_displays(peer)
	_send_party_info()
	_receive_shrine.rpc_id(peer, shrine_center, _trophies)
	_portal_cooldown[peer] = PORTAL_COOLDOWN  # don't whoosh away the moment you join
	for other in _armor_sent:
		if other != peer:
			_set_player_armor.rpc_id(peer, other, _armor_sent[other])


func server_remove_player(peer: int) -> void:
	_cancel_trades_of(peer)
	_invites.erase(peer)
	_party_invites.erase(peer)
	if _states.has(peer):
		var st: Dictionary = _states[peer]
		st["sleeping"] = false
		_saved[st["key"]] = st
		_states.erase(peer)
	_viewers.erase(peer)
	_armor_sent.erase(peer)
	_map_viewers.erase(peer)
	_send_party_info.call_deferred()   # they show as offline now


func clear_all() -> void:
	_states.clear()
	_saved.clear()
	_furnaces.clear()
	_chests.clear()
	_loot.clear()
	_drops.clear()
	_torches.clear()
	_saplings.clear()
	_decay.clear()
	_sapling_given.clear()
	_maps.clear()
	_next_map = 1
	_portals.clear()
	_next_portal = 1
	portals = {}
	_frames.clear()
	_stands.clear()
	frame_items.clear()
	_chest_names.clear()
	chest_names.clear()
	_parties.clear()
	_next_party = 1
	_trophies.clear()
	trophies = {}
	shrine_center = NO_POS
	_party_invites.clear()
	parties = {}
	party_roster = []
	_refresh_chest_labels()
	stand_items.clear()
	_map_viewers.clear()
	_map_dirty.clear()
	map_view = {}
	_trades.clear()
	_invites.clear()
	_viewers.clear()
	_armor_sent.clear()
	me = {}
	open_kind = ""
	open_slots = []
	for n in _loot_nodes.values():
		n.queue_free()
	_loot_nodes.clear()
	for n in _drop_nodes.values():
		n.queue_free()
	_drop_nodes.clear()
	_drop_targets.clear()


## For mobs: where every player is and whether they're alive.
func player_list() -> Array:
	var out := []
	for peer in _states:
		var node: Node3D = main.players.get_node_or_null(str(peer))
		if node:
			out.append({"peer": peer, "pos": node.global_position, "alive": _states[peer]["alive"],
					"sight": 0.5 if _has_special(_states[peer], "night_eyes") else 1.0})
	return out


## The bed a character has used most that still exists (NO_POS if none).
func most_active_bed(key: String) -> Vector3i:
	var st: Dictionary = {}
	for s in _states.values():
		if s["key"] == key:
			st = s
	if st.is_empty():
		st = _saved.get(key, {})
	var best := NO_POS
	var best_n := 0
	for pos in st.get("beds", {}):
		if main.world.get_edited_block(pos) == Blocks.BED and st["beds"][pos] > best_n:
			best_n = st["beds"][pos]
			best = pos
	return best


func _player_pos(peer: int) -> Vector3:
	var node: Node3D = main.players.get_node_or_null(str(peer))
	return node.global_position if node else Vector3(0, -1000, 0)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return multiplayer.get_unique_id() if id == 0 else id


## The state of whoever sent the current request, if they're allowed to act.
func _actor() -> Dictionary:
	if not multiplayer.is_server():
		return {}
	var st: Dictionary = _states.get(_sender(), {})
	return st if not st.is_empty() and st["alive"] else {}


func _held(st: Dictionary, slot: int) -> Dictionary:
	if slot < 0 or slot >= Inv.HOTBAR_SIZE or st["inventory"][slot] == null:
		return {}
	return st["inventory"][slot]


func _sync_self(peer: int) -> void:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return
	_note_seen(peer, st)
	_receive_self.rpc_id(peer, {"inventory": st["inventory"], "toots": st["toots"],
			"unlocked": st["unlocked"], "seen": st["seen"], "known": st["known"], "health": st["health"], "alive": st["alive"],
			"armor": armor_points(st["inventory"]), "protect": protection_of(st["inventory"]), "bed": st["bed"], "air": st.get("air", MAX_AIR),
			"air_max": _max_air(st), "freezing": st.get("freezing", false), "buff": _buff(st), "cape": _cape_buff(st),
			"gear": gear_buffs(st["inventory"]),
			"power": {"chosen": st.get("chosen_power", ""), "id": st.get("power_id", ""), "left": st.get("power_left", 0.0), "cd": st.get("power_cd", 0.0)},
			"chilled": st.get("chilled", 0.0) > 0.0, "burning": st.get("burning", 0.0) > 0.0})
	var ids := armor_ids(st["inventory"])
	if _armor_sent.get(peer, []) != ids:
		_armor_sent[peer] = ids
		_set_player_armor.rpc(peer, ids)


func _tell(peer: int, text: String) -> void:
	_receive_notice.rpc_id(peer, text)


func _give_or_drop(peer: int, id: String, count: int, data := {}) -> void:
	var st: Dictionary = _states.get(peer, {})
	var left := count
	if not st.is_empty():
		left = Inv.add(st["inventory"], id, count, Inv.PLAYER_SLOTS, data)
	if left > 0:
		_spawn_drop(id, left, _player_pos(peer) + Vector3(0, 0.5, 0), Vector3.ZERO, 0.5, data)


# --- Admin helpers (used by chat commands) --------------------------------------------------

func server_give(peer: int, id: String, count: int) -> int:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty() or not Items.exists(id):
		return 0
	var left := count
	if Items.is_map(id):
		while left > 0:  # each map is its own map (party maps share their party's)
			var data := _make_item_data(id, st)
			if Inv.add(st["inventory"], id, 1, Inv.PLAYER_SLOTS, data) > 0:
				if not data.has("party"):
					_maps.erase(data["map"])
				break
			left -= 1
	else:
		left = Inv.add(st["inventory"], id, count, Inv.PLAYER_SLOTS)
	_sync_self(peer)
	return count - left


## /unlockall: every recipe learned (and every item counted as found).
func server_unlock_all(peer: int) -> int:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return 0
	var n := 0
	for r in Recipes.RECIPES:
		if Recipes.needs_research(r) and not st["unlocked"].has(r["out"]):
			st["unlocked"][r["out"]] = true
			n += 1
		st["known"][r["out"]] = true
	for id in Items.ITEMS:
		st["seen"][id] = true
	_sync_self(peer)
	return n


## /god, /fly, /noclip: flips a flag on a player and returns it.
func server_toggle(peer: int, flag: String) -> bool:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return false
	st[flag] = not st.get(flag, false)
	return st[flag]


# --- The arena (Arena in a Box) ---------------------------------------------------------
# Its button locks the gates (iron bars drop over every doorway onto the sand)
# and gives everyone within ARENA_HEARING a 3-2-1-FIGHT! countdown. Pressing it
# again, or ARENA_ROUND seconds later, opens them.

var _reaping := {}               # peer -> true while their Harvest Scythe lands a hit
var _arenas := {}                # button position -> {"center", "gates": [Vector3i], "locked", "left"}
const ARENA_HEARING := 200.0
const ARENA_ROUND := 300.0


func register_arena(center: Vector3i, gates: Array, button: Vector3i) -> void:
	_arenas[button] = {"center": center, "gates": gates.duplicate(), "locked": false, "left": 0.0}


func arena_locked(button: Vector3i) -> bool:
	return bool(_arenas.get(button, {}).get("locked", false))


func arena_button(peer: int, button: Vector3i) -> void:
	var a: Dictionary = _arenas.get(button, {})
	if a.is_empty():
		_tell(peer, "This button isn't wired to an arena.")
		return
	if a["locked"]:
		_set_arena_gates(button, false)
		main._receive_event.rpc("%s opened the arena gates." % _states[peer]["name"], "arena_box")
		return
	_set_arena_gates(button, true)
	a["left"] = ARENA_ROUND
	var center: Vector3 = Vector3(a["center"])
	for p in _states:
		if _player_pos(p).distance_to(center) <= ARENA_HEARING:
			_arena_countdown.rpc_id(p)
	main._receive_event.rpc("%s started an arena battle! The gates are locked." % _states[peer]["name"], "iron_sword")


func _set_arena_gates(button: Vector3i, locked: bool) -> void:
	var a: Dictionary = _arenas[button]
	a["locked"] = locked
	var list := []
	for g in a["gates"]:
		var now_b: int = main.world.get_block(g)
		if locked and Blocks.is_replaceable(now_b) or not locked and now_b == Blocks.ARENA_GATE:
			list.append([g, Blocks.ARENA_GATE if locked else Blocks.AIR, -1])
	main.world.server_set_blocks(list)
	_sync_arena.rpc(button, locked)


func _tick_arenas(delta: float) -> void:
	for b in _arenas:
		var a: Dictionary = _arenas[b]
		if a["locked"]:
			a["left"] = float(a["left"]) - delta
			if a["left"] <= 0.0:
				_set_arena_gates(b, false)
				main._receive_event.rpc("Time's up! The arena gates open.", "arena_box")


var arena_states := {}           # client: button position -> locked (for the look-at hint)


@rpc("authority", "call_local", "reliable")
func _sync_arena(button: Vector3i, locked: bool) -> void:
	arena_states[button] = locked


## Everyone near the arena: 3, 2, 1, FIGHT!
@rpc("authority", "call_local", "reliable")
func _arena_countdown() -> void:
	arena_countdown.emit()


# --- Villagers' shops -------------------------------------------------------------------
# Each villager has their own stock each day (picked from their tribe's list,
# so it's the same for everyone), plus sometimes a surprise. What people buy
# runs out until the next day.

var _villager_sold := {}         # "camp:index:day" -> {item index: how many sold}
var villager_shop := {}          # client: the shop you're looking at


func _villager_stock(m: Node3D) -> Dictionary:
	var biome: String = m.def.get("tribe", "plains")
	var t := VillagerData.tribe(biome)
	var danger: int = t["danger"]
	var day: int = main.day_night.day_number()
	var key := "%s:%d:%d" % [m.get_meta("camp", "wild"), int(m.get_meta("index", 0)), day]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) ^ main.world.world_seed
	var pool: Array = t["stock"].filter(func(e: Array) -> bool: return Items.exists(e[0]) and Recipes.value(e[0]) > 0.0)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var items := []
	for e in pool.slice(0, mini(pool.size(), 5 + rng.randi() % 3)):
		var n: int = maxi(1, roundi(float(e[1]) * rng.randf_range(0.5, 1.0)))
		var price := maxf(1.0, snappedf(Recipes.value(e[0]) * VillagerData.PRICE_MARKUP * (1.0 + 0.1 * danger), 0.5))
		items.append({"id": e[0], "count": n, "price": price, "surprise": false})
	if rng.randf() < VillagerData.SURPRISE_CHANCE:
		var picks: Array = VillagerData.SURPRISES[clampi(danger, 0, 3)].filter(func(id: String) -> bool: return Items.exists(id))
		if not picks.is_empty():
			var sid: String = picks[rng.randi() % picks.size()]
			items.append({"id": sid, "count": 1, "price": maxf(5.0, snappedf(Recipes.value(sid) * 2.6, 1.0)), "surprise": true})
	var sold: Dictionary = _villager_sold.get(key, {})
	for i in items.size():
		items[i]["count"] = maxi(0, int(items[i]["count"]) - int(sold.get(i, 0)))
	return {"name": t["one"], "tribe": t["name"], "hello": t["hello"], "items": items, "key": key, "biome": biome}


func _villager_near(peer: int, mob_id: int) -> Node3D:
	var m: Node3D = main.mobs.get_mob(mob_id)
	if m == null or not m.is_villager() or _player_pos(peer).distance_to(m.sim_pos) > STATION_REACH + 1.0:
		return null
	return m


@rpc("any_peer", "call_local", "reliable")
func req_villager(mob_id: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var m := _villager_near(peer, mob_id)
	if m == null:
		_tell(peer, "They're too far away to trade with.")
		return
	_receive_villager.rpc_id(peer, mob_id, _villager_stock(m))


@rpc("any_peer", "call_local", "reliable")
func req_buy_villager(mob_id: int, index: int, n: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var m := _villager_near(peer, mob_id)
	if m == null:
		return
	var shop := _villager_stock(m)
	var items: Array = shop["items"]
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	n = clampi(n, 1, int(it["count"]))
	if int(it["count"]) <= 0:
		_tell(peer, "They've sold out of that today.")
		return
	var cost: float = float(it["price"]) * n
	if st["toots"] + 0.0001 < cost:
		_tell(peer, "You need %s for that." % Recipes.format_toots(cost))
		return
	var got := 0
	for k in n:
		var data := _make_item_data(it["id"], st)
		if Inv.add(st["inventory"], it["id"], 1, Inv.PLAYER_SLOTS, data) > 0:
			if data.has("map") and not data.has("party"):
				_maps.erase(data["map"])
			break
		got += 1
	if got == 0:
		_tell(peer, "Your pockets are full!")
		return
	st["toots"] -= float(it["price"]) * got
	var sold: Dictionary = _villager_sold.get(shop["key"], {})
	sold[index] = int(sold.get(index, 0)) + got
	_villager_sold[shop["key"]] = sold
	_sync_self(peer)
	_receive_villager.rpc_id(peer, mob_id, _villager_stock(m))


@rpc("authority", "call_local", "reliable")
func _receive_villager(mob_id: int, shop: Dictionary) -> void:
	villager_shop = shop
	villager_shop["mob"] = mob_id
	container_changed.emit()


## (Host) freeze a player in place, or let them go.
func server_set_frozen(peer: int, on: bool) -> void:
	if not _states.has(peer):
		return
	_states[peer]["frozen"] = on
	main._set_frozen.rpc_id(peer, on)


## (Host) special maps: "everything" (all the land for 1000 blocks around),
## "boss" (every boss lair and castle marked) or "topo" (just the biome
## colors). Returns what to tell the host ("" = no room).
func server_give_special_map(peer: int, style: String) -> String:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return ""
	var pos := _player_pos(peer)
	var mid := _new_map("the host")
	var m: Dictionary = _maps[mid]
	var label: String = {"everything": "Map of Everything", "boss": "Boss Map", "topo": "Biome Map"}.get(style, "Map")
	if style == "everything" or style == "topo":
		var full := PackedByteArray()
		full.resize(MAP_REGION * MAP_REGION / 8)
		full.fill(255)
		var c := map_region_of(floori(pos.x / MAP_SCALE), floori(pos.z / MAP_SCALE))
		var r := int(SPECIAL_MAP_RADIUS / (MAP_SCALE * MAP_REGION))
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				m["regions"][c + Vector2i(dx, dz)] = full.duplicate()
		if style == "topo":
			m["style"] = "topo"
	if style == "boss" or style == "everything":
		var from := Vector2(pos.x, pos.z)
		for key in main.world.LAIR_BOSSES.values():
			var l: Dictionary = main.world.find_lair(key, from, SPECIAL_MAP_RADIUS * 2.0)   # the nearest of each boss
			if l.is_empty():
				continue
			var b := BossData.get_boss(key)
			m["marks"].append({"x": l["pos"].x, "z": l["pos"].z, "kind": "boss", "label": b.get("name", key), "fixed": true})
			if style == "boss":
				_reveal(mid, Vector3(l["pos"]))
				m.erase("last")
		for extra in [["Grimskull", main.world.find_castle(from)], ["Yeti", main.world.find_structure("mineshaft", from)]]:
			var at: Vector3 = extra[1]
			if at.y >= 0:
				m["marks"].append({"x": at.x, "z": at.z, "kind": "boss", "label": extra[0], "fixed": true})
				if style == "boss":
					_reveal(mid, at)
					m.erase("last")
	m["marks"] = m["marks"].slice(0, MAP_MAX_MARKS)
	m.erase("last")
	var data := {"map": mid, "maker": "the host", "label": label, "label_ink": "blue_ink"}
	if Inv.add(st["inventory"], "map", 1, Inv.PLAYER_SLOTS, data) > 0:
		_maps.erase(mid)
		return ""
	_sync_self(peer)
	return "Here's a %s! (%d marked)" % [label, m["marks"].size()] if style != "topo" else "Here's a %s!" % label


const SPECIAL_MAP_RADIUS := 1024.0
const PVP_SCALE := 0.4     # players hit each other this much as hard as they hit monsters


## PvP: hit another player (only when the world allows it right now).
@rpc("any_peer", "call_local", "reliable")
func req_attack_player(target: int, slot: int) -> void:
	var st := _actor()
	if st.is_empty() or not main.pvp_active():
		return
	var peer := _sender()
	var t := now()
	if target == peer or t - _attack_times.get(peer, -10.0) < ATTACK_COOLDOWN / (1.0 + _buff_power(st, "haste")):
		return
	var other: Dictionary = _states.get(target, {})
	if other.is_empty() or not other["alive"]:
		return
	var pos := _player_pos(peer)
	var tpos := _player_pos(target)
	if pos.distance_to(tpos) > ATTACK_REACH + 0.6:
		return
	_attack_times[peer] = t
	var d := Items.get_def(_held(st, slot).get("id", ""))
	var might := 0.0
	var chest = st["inventory"][Inv.ARMOR_START + 1]
	if chest != null:
		might = float(Items.get_def(chest["id"]).get("might", 0.0))
	var dmg: float = d.get("damage", 1.0) * (1.0 + _buff_power(st, "strength") + might) * PVP_SCALE * quality(_held(st, slot))
	var away := tpos - pos
	away.y = 0
	var knock := away.normalized() * 6.0 + Vector3(0, 4, 0) if away.length() > 0.01 else Vector3(0, 4, 0)
	var hp_before: float = other["health"]
	damage_player(target, dmg, "was defeated by %s" % st["name"], knock)
	_leech(peer, maxf(0.0, hp_before - float(other["health"])), weapon_leech(_held(st, slot)))
	_pvp_hit.rpc(target)


## Everyone: a quick red flash on the player who got hit.
@rpc("authority", "call_local", "unreliable")
func _pvp_hit(target: int) -> void:
	var node: Node3D = main.players.get_node_or_null(str(target)) if main else null
	if node and node.has_method("flash_hit"):
		node.flash_hit()


func server_add_toots(peer: int, amount: float) -> void:
	if _states.has(peer):
		_states[peer]["toots"] = maxf(0.0, _states[peer]["toots"] + amount)
		_sync_self(peer)


func server_heal(peer: int) -> void:
	if _states.has(peer) and _states[peer]["alive"]:
		_states[peer]["health"] = MAX_HEALTH
		_sync_self(peer)


# --- Server loop -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_animate_drops(delta)
	_animate_arrows(delta)
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or main == null or not main.in_game:
		return
	var t := now()
	_tick_powers(delta)
	if shrine_center == NO_POS:
		_shrine_timer -= delta
		if _shrine_timer <= 0.0:
			_shrine_timer = 1.0
			_try_build_shrine()
	for peer in _states:
		var st: Dictionary = _states[peer]
		var head = st["inventory"][Inv.ARMOR_START]
		var royal: bool = head != null and Items.get_def(head["id"]).get("regen", false)
		var delay := 2.0 if royal else REGEN_DELAY
		var interval := (1.0 if royal else REGEN_INTERVAL) / (1.0 + _buff_power(st, "regen"))
		if st["alive"] and st["health"] < MAX_HEALTH and t - st["hurt_time"] > delay:
			st["regen"] += delta
			if st["regen"] >= interval:
				st["regen"] = 0.0
				st["health"] = minf(MAX_HEALTH, st["health"] + 1.0)
				_sync_self(peer)
	for id in _loot.keys():
		var l: Dictionary = _loot[id]
		l["age"] += delta
		if l["kind"] == "corpse" and l["age"] > CORPSE_SECONDS:
			_remove_loot(id)
	_tick_air(delta)
	_tick_arenas(delta)
	_tick_cold(delta)
	_tick_furnaces(delta)
	_tick_torches(delta)
	_tick_trees(delta)
	_tick_maps(delta)
	_tick_arrows(delta)
	_tick_burn_chill(delta)
	_tick_portals(delta)
	_tick_drops(delta)
	_tick_trades()
	_tick_sleep(delta)
	_container_sync -= delta
	if _container_sync <= 0.0:
		_container_sync = 0.25
		for peer in _viewers:
			if _viewers[peer]["kind"] == "furnace":
				_send_container(peer)


const COAL_PER := 4.0   # fuel used up for each piece of coal left behind


func _tick_furnaces(delta: float) -> void:
	var smelt := Recipes.SMELT_SECONDS
	for pos in _furnaces:
		var f: Dictionary = _furnaces[pos]
		var slots: Array = f["slots"]
		var input = slots[0]
		var out_id: String = Recipes.SMELTING.get(input["id"], "") if input != null else ""
		var out = slots[2]
		var can_smelt: bool = out_id != "" and (out == null or (out["id"] == out_id and out["count"] < Items.max_stack(out_id)))
		if f["burn"] <= 0.0 and can_smelt and slots[1] != null:
			var fv := Recipes.fuel_value(slots[1]["id"])
			if fv > 0.0:
				f["burn"] = fv * smelt
				f["burn_max"] = f["burn"]
				# Burning wood leaves coal behind (about 1 per log). Coal itself burns away.
				if slots[1]["id"] != "coal":
					f["char"] = f.get("char", 0.0) + fv
				Inv.remove_from_slot(slots, 1, 1)
				while f.get("char", 0.0) >= COAL_PER:
					f["char"] -= COAL_PER
					if slots.size() < 4:
						slots.resize(4)
					if slots[3] == null:
						slots[3] = {"id": "coal", "count": 1}
					elif slots[3]["id"] == "coal" and slots[3]["count"] < Items.max_stack("coal"):
						slots[3]["count"] += 1
		if f["burn"] > 0.0:
			f["burn"] = maxf(0.0, f["burn"] - delta)
			if can_smelt:
				f["progress"] += delta
				if f["progress"] >= smelt:
					f["progress"] = 0.0
					Inv.remove_from_slot(slots, 0, 1)
					if slots[2] == null:
						slots[2] = {"id": out_id, "count": 1}
					else:
						slots[2]["count"] += 1
			else:
				f["progress"] = 0.0
		else:
			f["progress"] = 0.0


## The fairy power this character has right now ({} if none).
func _buff(st: Dictionary) -> Dictionary:
	return main.mobs.fairy_buff(st.get("key", "")) if main and main.mobs else {}


func _buff_power(st: Dictionary, type: String) -> float:
	var b := _buff(st)
	var c := _cape_buff(st)
	var p := _power_def(st)
	var total: float = (b.get("power", 0.0) if b.get("type", "") == type else 0.0) \
			+ (c.get("power", 0.0) if c.get("type", "") == type else 0.0) \
			+ (float(p.get("amount", 0.0)) if p.get("buff", "") == type else 0.0) \
			+ float(gear_buffs(st.get("inventory", [])).get(type, 0.0))
	return minf(total, float(MobData.BUFF_CAP.get(type, 99.0)))


## The powers from the ring and amulet you're wearing: {type: power}.
static func gear_buffs(inv: Array) -> Dictionary:
	var out := {}
	for i in [Inv.ARMOR_START, Inv.ARMOR_START + 1, Inv.ARMOR_START + 2, Inv.ARMOR_START + 3, Inv.RING_SLOT, Inv.AMULET_SLOT]:
		if i < inv.size() and inv[i] != null:
			var b: Dictionary = inv[i].get("buffs", Items.get_def(inv[i]["id"]).get("buffs", {}))
			for k in b:
				out[k] = float(out.get(k, 0.0)) + float(b[k]) * (1.0 if k in MobData.BINARY_BUFFS else quality(inv[i]))
	return out


## Life leech from a cute sword or bow: its cute roll (0.04-0.14).
static func weapon_leech(slot: Dictionary) -> float:
	if not slot.has("cute"):
		return 0.0
	var d := Items.get_def(slot.get("id", ""))
	return float(slot["cute"]) if d.get("tool", "") == "sword" or d.has("bow") else 0.0


const LEECH_PER_HIT := 1.5   # life leech never heals more than this from one hit


## Heal a little from damage you just did (life leech from rings and cute weapons).
func _leech(peer: int, dealt: float, extra := 0.0) -> void:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty() or not st["alive"] or dealt <= 0.0 or st["health"] >= MAX_HEALTH:
		return
	var share := minf(_buff_power(st, "leech") + extra, float(MobData.BUFF_CAP["leech"]))
	if share <= 0.0:
		return
	st["health"] = minf(MAX_HEALTH, st["health"] + minf(dealt * share, LEECH_PER_HIT))
	_sync_self(peer)


func _fireproof(st: Dictionary) -> bool:
	return _buff_power(st, "fireproof") >= 0.99


# --- Cute things ---------------------------------------------------------------------
# The Cute Crafter turns gear into its cute version. Each cute item rolls its
# own small bonus, stored in its slot as "cute" (0.05 = 5% better).

const CUTE_ROLL := Vector2(0.04, 0.14)


## Multiplier for a held tool (mining speed) or worn cape (power): 1.0 for plain ones.
## (Cute swords and bows give life leech instead: see weapon_leech.)
static func cute_bonus(slot: Dictionary) -> float:
	return 1.0 + float(slot.get("cute", 0.0))


## Extra armor points from cute armor (each piece adds its own share).
static func cute_armor(inv: Array) -> float:
	var extra := 0.0
	for i in range(Inv.ARMOR_START, Inv.ARMOR_START + 4):
		if i < inv.size() and inv[i] != null and inv[i].has("cute"):
			extra += float(Items.get_def(inv[i]["id"]).get("armor", 0)) * float(inv[i]["cute"]) * 1.5
	return extra


## Make the item in this slot cute (at a Cute Crafter): pays 1-3 Cutieite.
@rpc("any_peer", "call_local", "reliable")
func req_cutify(slot: int, bench: Vector3i) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if main.world.get_block(bench) != Blocks.CUTE_CRAFTER \
			or _player_pos(peer).distance_to(Vector3(bench) + Vector3(0.5, 0.5, 0.5)) > STATION_REACH:
		_tell(peer, "You need to be at a Cute Crafter.")
		return
	var inv: Array = st["inventory"]
	if slot < 0 or slot >= Inv.PLAYER_SIZE or inv[slot] == null:
		return
	var s: Dictionary = inv[slot]
	if not Items.is_cutable(s["id"]):
		_tell(peer, "That can't be made cute.")
		return
	var cost := Recipes.cute_cost(s["id"])
	if Inv.count_of(inv.slice(0, Inv.PLAYER_SLOTS), "cutieite_ingot") < cost:
		_tell(peer, "You need %d Cutieite Ingot%s for that." % [cost, "" if cost == 1 else "s"])
		return
	Inv.remove(inv, "cutieite_ingot", cost, Inv.PLAYER_SLOTS)
	var base: String = s["id"]
	s["id"] = "cute_" + base
	s["cute"] = snappedf(randf_range(CUTE_ROLL.x, CUTE_ROLL.y), 0.01)
	if not s.has("maker"):
		s["maker"] = st["name"]
	_sync_self(peer)
	_cute_done.rpc_id(peer, s["id"], s["cute"])


@rpc("authority", "call_local", "reliable")
func _cute_done(id: String, roll: float) -> void:
	notice.emit("Ta-da! Your %s is now super cute! (+%d%% better)" % [Items.display_name(id).trim_prefix("Cute "), roundi(roll * 100.0)])
	Sound.play("legendary", -8.0, 1.25, "Interface")
	container_changed.emit()


## How much of its power a cape gives at each tier (times the fairy maximum).
const CAPE_SHARE := [0.18, 0.3, 0.45]


## A cape's power: its color's power type, its tier, and how well it rolled when made.
static func cape_power(id: String, roll: float) -> float:
	var d := Items.get_def(id)
	if not d.has("cape"):
		return 0.0
	if d["buff"] in MobData.BINARY_BUFFS:
		return 1.0
	return MobData.BUFF_MAX[d["buff"]] * CAPE_SHARE[clampi(int(d["cape"]) - 1, 0, 2)] * roll


func _cape_buff(st: Dictionary) -> Dictionary:
	var inv: Array = st["inventory"]
	if inv.size() <= Inv.CAPE_SLOT or inv[Inv.CAPE_SLOT] == null:
		return {}
	var s: Dictionary = inv[Inv.CAPE_SLOT]
	var d := Items.get_def(s["id"])
	if not d.has("cape"):
		return {}
	var power := cape_power(s["id"], float(s.get("roll", 0.85)))
	return {"type": d["buff"], "power": power if d["buff"] in MobData.BINARY_BUFFS else power * cute_bonus(s)}


func _max_air(st: Dictionary) -> float:
	return MAX_AIR * (1.0 + _buff_power(st, "breath"))


## For mobs.gd: which peer is playing this character (0 = nobody).
func peer_of(key: String) -> int:
	for peer in _states:
		if _states[peer].get("key", "") == key:
			return peer
	return 0


func bed_of(key: String) -> Vector3i:
	for st in _states.values():
		if st.get("key", "") == key:
			return st["bed"] if main.world.get_edited_block(st["bed"]) == Blocks.BED else NO_POS
	var saved: Dictionary = _saved.get(key, {})
	var bed: Vector3i = saved.get("bed", NO_POS)
	return bed if main.world.get_edited_block(bed) == Blocks.BED else NO_POS


## Is this player warm enough for the snowy mountains? Wearing something in
## all four armor slots, wearing the Yeti's boots, standing by a light, or a
## bright orange fairy all keep the cold away.
func _is_warm(peer: int, st: Dictionary) -> bool:
	var inv: Array = st["inventory"]
	var full := true
	for i in range(Inv.ARMOR_START, Inv.ARMOR_START + 4):
		if inv[i] == null:
			full = false
		elif Items.get_def(inv[i]["id"]).get("warm", false):
			return true
	if full:
		return true
	var pos := _player_pos(peer)
	if main.world.lamp_light_at(Vector3i(floori(pos.x), floori(pos.y + 1.0), floori(pos.z))) >= 8:
		return true
	return _buff_power(st, "warmth") >= 0.99


## Cold: in the snowy mountains without warm gear you slowly freeze.
func _tick_cold(delta: float) -> void:
	for peer in _states:
		var st: Dictionary = _states[peer]
		var pos := _player_pos(peer)
		var freezing: bool = st["alive"] and not st.get("god", false) and main.world.biome_at(pos.x, pos.z) == "mountain" and not _is_warm(peer, st)
		if freezing != st.get("freezing", false):
			st["freezing"] = freezing
			_sync_self(peer)
			if freezing:
				_tell(peer, "Brrr! It's freezing here. Wear something in all 4 armor slots to stay warm.")
		if not freezing:
			st["cold"] = 0.0
			continue
		st["cold"] += delta / (1.0 + _buff_power(st, "warmth") * 3.0)
		if st["cold"] >= COLD_INTERVAL:
			st["cold"] = 0.0
			damage_player(peer, COLD_DAMAGE, "froze in the snow", Vector3.ZERO, true)


## Holding your breath: air runs out with your head underwater, then you
## start taking damage. Air comes back quickly once you're out.
func _tick_air(delta: float) -> void:
	for peer in _states:
		var st: Dictionary = _states[peer]
		if not st["alive"]:
			st["air"] = MAX_AIR
			continue
		var head := _player_pos(peer) + Vector3(0, 1.6, 0)
		var under: bool = Blocks.is_water(main.world.get_block(Vector3i(floori(head.x), floori(head.y), floori(head.z))))
		var before: float = st["air"]
		var max_air := _max_air(st)
		if under:
			st["air"] = minf(maxf(0.0, st["air"] - delta), max_air)
			if st["air"] <= 0.0:
				st["drown"] += delta
				if st["drown"] >= 1.0:
					st["drown"] = 0.0
					damage_player(peer, DROWN_DAMAGE, "drowned", Vector3.ZERO, true)
		else:
			st["air"] = minf(max_air, st["air"] + AIR_REFILL * delta)
			st["drown"] = 0.0
		# Tell the player whenever a whole bubble pops or refills.
		if ceili(before) != ceili(st["air"]):
			_sync_self(peer)


func _tick_torches(delta: float) -> void:
	for pos in _torches.keys():
		if main.world.get_edited_block(pos) != Blocks.TORCH:
			_torches.erase(pos)  # broken or replaced
			continue
		_torches[pos] -= delta
		if _torches[pos] <= 0.0:
			_torches.erase(pos)
			main.world.server_set_block(pos, Blocks.AIR)  # burnt out


# --- Requests: blocks ----------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func req_break(pos: Vector3i, slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var b: int = main.world.get_block(pos)
	if not Blocks.is_targetable(b) or Blocks.HARDNESS[b] < 0.0:
		return
	if shrine_block_at(pos) == b:
		_tell(peer, "The shrine's old stones won't budge.")
		return
	var frame_of := portal_at(pos, true) if b == Blocks.PORTALSTONE else 0
	if frame_of != 0 and _portals[frame_of]["partner"] != 0 and _portals[frame_of]["creator"] != st["key"]:
		_tell(peer, "This portal is linked, so only %s can break it." % _portals[frame_of]["creator_name"])
		return
	var tool: Dictionary = Items.get_def(_held(st, slot).get("id", ""))
	if not can_harvest(b, tool):
		_tell(peer, "You need %s to mine %s." % [needed_tool_text(b), Blocks.NAMES[b]])
		return
	var drop: String = Blocks.DROP[b]
	var leaf_drops: Array = []
	if Blocks.is_leaves(b):
		drop = ""
		leaf_drops = _leaf_drops(pos, b, 1.0)
	# (Find the bed's other half first: removing this one forgets which way it faced.)
	var bed_other := bed_other_half(pos, b) if b == Blocks.BED or b == Blocks.BED_FOOT else NO_POS
	if not main.world.server_set_block(pos, Blocks.AIR):
		return
	if frame_of != 0:
		_portal_broken(frame_of)
	if bed_other.y >= 0:
		main.world.server_set_block(bed_other, Blocks.AIR)
	if Blocks.is_door(b):
		# Doors are two blocks tall: break the other half too.
		for off in [Vector3i.UP, Vector3i.DOWN]:
			if Blocks.same_door(main.world.get_block(pos + off), b):
				main.world.server_set_block(pos + off, Blocks.AIR)
	# A plant sitting on this block pops off too, into your pocket.
	var above: int = main.world.get_block(pos + Vector3i.UP)
	if Blocks.is_plant(above) and main.world.server_set_block(pos + Vector3i.UP, Blocks.AIR):
		var extra: String = Blocks.DROP[above]
		if extra != "":
			_give_or_drop(peer, extra, 1)
	if b == Blocks.FURNACE and _furnaces.has(pos):
		_spill(_furnaces[pos]["slots"], pos)
		_furnaces.erase(pos)
		_close_viewers("furnace", pos)
	if b == Blocks.SUPER_CHEST:
		_close_viewers("super", pos)   # (what's inside belongs to each player, so it stays safe)
	if Blocks.is_log(b):
		_check_leaves(pos)
	if b == Blocks.CHEST and _chests.has(pos):
		_spill(_chests[pos], pos)
		_chests.erase(pos)
		if _chest_names.erase(pos):
			_receive_chest_name.rpc(pos, "")
		_close_viewers("chest", pos)
	if b == Blocks.ITEM_FRAME and _frames.has(pos):
		if _frames[pos] != null:
			_spill([_frames[pos]], pos)
		_frames.erase(pos)
		_send_frame(pos)
	if b == Blocks.ARMOR_STAND and _stands.has(pos):
		_spill(_stands[pos], pos)
		_stands.erase(pos)
		_close_viewers("stand", pos)
		_receive_stand.rpc(pos, [])
	if drop != "":
		leaf_drops.append(drop)
		var luck := _buff_power(st, "fortune") + float(tool.get("fortune", 0.0)) * quality(_held(st, slot))
		if Blocks.NAMES[b].ends_with(" Ore") and randf() < luck:
			leaf_drops.append(drop)
			_tell(peer, "Lucky! Double %s!" % Items.display_name(drop))
	for d in leaf_drops:
		var left := Inv.add(st["inventory"], d, 1, Inv.PLAYER_SLOTS)
		if left > 0:
			_spawn_drop(d, left, Vector3(pos) + Vector3(0.5, 0.3, 0.5), Vector3(0, 2, 0), 0.3)
	_sync_self(peer)


# --- Trees: falling leaves, saplings and growing ----------------------------------------
# Chop all the wood out of a tree and its leaves fall by themselves (dropping a
# quarter of what they would if you broke them). Leaves sometimes drop a
# sapling, but each tree only gives 2-3 (a big redwood 4). Plant a sapling and
# it grows into the same kind of tree in 2-3 in-game days.

const SAPLING_CHANCE := 0.1        # per leaf you break
const DECAY_RATE := 0.25           # leaves that fall drop this share of their stuff
const LEAF_REACH := 4              # leaves this far from wood (through leaves) still hang on
const GROW_DAYS := Vector2(2.0, 3.0)
const TREE_SEARCH_MAX := 3000


## What a leaf block gives when it comes down. rate: 1 = broken by hand, 0.25 = fell.
func _leaf_drops(pos: Vector3i, b: int, rate: float) -> Array:
	var out := []
	if b == Blocks.COTTON_CANDY:
		if randf() < 0.5 * rate:
			out.append("cotton_candy")
	elif randf() < 0.25 * rate:
		out.append("stick")
	if randf() < SAPLING_CHANCE * rate:
		var tree: Dictionary = main.world.tree_of_leaf(pos)
		var key: Vector3i = tree.get("pos", Vector3i(pos.x >> 3, -(pos.y >> 3) - 1, pos.z >> 3))
		var cap := 4 if tree.get("big", false) else 2 + absi(key.x * 31 + key.z * 17) % 2
		if int(_sapling_given.get(key, 0)) < cap:
			_sapling_given[key] = int(_sapling_given.get(key, 0)) + 1
			out.append(_sapling_for(b, tree.get("big", false)))
	return out


static func _sapling_for(leaf: int, big: bool) -> String:
	match leaf:
		Blocks.PINE_LEAVES: return "pine_sapling"
		Blocks.PALM_LEAVES: return "palm_sapling"
		Blocks.MAPLE_LEAVES: return "maple_sapling"
		Blocks.GOLDEN_LEAVES: return "golden_sapling"
		Blocks.COTTON_CANDY: return "candy_sapling"
	return "redwood_sapling" if big else "oak_sapling"


## Leaves that fall on their own (cotton candy only if the world made it:
## you can build with cotton candy).
func _can_fall(p: Vector3i, b: int) -> bool:
	return Blocks.is_leaves(b) and (b != Blocks.COTTON_CANDY or main.world.get_edited_block(p) < 0)


## A log was chopped at `pos`: any leaves around it that no wood holds up any
## more start to fall.
func _check_leaves(pos: Vector3i) -> void:
	var w: Node = main.world
	# Everything (leaves and wood) joined to the chopped spot.
	var seen := {}
	var todo: Array[Vector3i] = []
	var logs: Array[Vector3i] = []
	for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
		todo.append(pos + d)
	while not todo.is_empty() and seen.size() < TREE_SEARCH_MAX:
		var p: Vector3i = todo.pop_back()
		if seen.has(p):
			continue
		var b: int = w.get_block(p)
		if Blocks.is_log(b):
			seen[p] = b
			logs.append(p)
		elif Blocks.is_leaves(b):
			seen[p] = b
		else:
			continue
		for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if not seen.has(p + d):
				todo.append(p + d)
	if seen.size() >= TREE_SEARCH_MAX:
		return   # a huge forest canopy: leave it be
	# How far each leaf is from wood, going through leaves.
	var dist := {}
	var front: Array = logs.duplicate()
	for l in logs:
		dist[l] = 0
	var step := 0
	while not front.is_empty() and step < LEAF_REACH:
		step += 1
		var next := []
		for p in front:
			for d in [Vector3i.UP, Vector3i.DOWN, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
				var q: Vector3i = p + d
				if seen.has(q) and not dist.has(q) and Blocks.is_leaves(seen[q]):
					dist[q] = step
					next.append(q)
		front = next
	var falling := []
	for p in seen:
		if not dist.has(p) and _can_fall(p, seen[p]):
			falling.append(p)
	# Leaves that only touch the tree at a corner aren't joined to it above:
	# check the tree's space for any that no wood is near any more.
	if logs.is_empty():
		for x in range(-4, 5):
			for z in range(-4, 5):
				for y in range(-3, 14):
					var p := pos + Vector3i(x, y, z)
					if not seen.has(p) and _can_fall(p, w.get_block(p)) and not _wood_near(p):
						falling.append(p)
	for p in falling:
		if not _decay.has(p):
			# Not all at once: they flutter down over a few seconds, the far ones last.
			_decay[p] = randf_range(0.3, 1.2) + Vector2(p.x - pos.x, p.z - pos.z).length() * 0.25 + randf() * 2.5


## Is there wood within LEAF_REACH of these leaves (through leaves, corners count)?
func _wood_near(start: Vector3i) -> bool:
	var w: Node = main.world
	var seen := {start: 0}
	var front: Array = [start]
	for step in LEAF_REACH:
		var next := []
		for p in front:
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						var q: Vector3i = p + Vector3i(dx, dy, dz)
						if seen.has(q):
							continue
						seen[q] = 0
						var b: int = w.get_block(q)
						if Blocks.is_log(b):
							return true
						if Blocks.is_leaves(b):
							next.append(q)
		front = next
	return false


func _tick_trees(delta: float) -> void:
	var fallen := 0
	for p in _decay.keys():
		_decay[p] -= delta
		if _decay[p] > 0.0 or fallen >= 12:
			continue
		fallen += 1
		var b: int = main.world.get_block(p)
		_decay.erase(p)
		if not _can_fall(p, b) or not main.world.server_set_block(p, Blocks.AIR):
			continue
		for d in _leaf_drops(p, b, DECAY_RATE):
			_spawn_drop(d, 1, Vector3(p) + Vector3(0.5, 0.4, 0.5), Vector3(randf_range(-1, 1), 1.0, randf_range(-1, 1)), 0.3)
	_sapling_timer -= delta
	if _sapling_timer > 0.0:
		return
	_sapling_timer = 2.0
	var now_t: float = main.day_night.world_time
	for p in _saplings.keys():
		if not main.world.is_ready_at(Vector3(p)):
			continue   # its part of the world isn't loaded: it waits
		var b: int = main.world.get_block(p)
		if not Blocks.is_sapling(b):
			_saplings.erase(p)
			continue
		if now_t >= float(_saplings[p]):
			if main.world.grow_tree(p, b):
				_saplings.erase(p)
			else:
				_saplings[p] = now_t + main.day_night.DAY_LENGTH * 0.25   # no room yet: try again later


## Plants a sapling's growing timer (when it's put down).
func _sapling_planted(p: Vector3i) -> void:
	_saplings[p] = main.day_night.world_time + randf_range(GROW_DAYS.x, GROW_DAYS.y) * main.day_night.DAY_LENGTH


## Pours a container's items onto the ground at a block.
func _spill(slots: Array, pos: Vector3i) -> void:
	for s in slots:
		if s != null:
			var v := Vector3(randf_range(-1.5, 1.5), 3.0, randf_range(-1.5, 1.5))
			_spawn_drop(s["id"], s["count"], Vector3(pos) + Vector3(0.5, 0.4, 0.5), v, 0.4, Inv.extra(s))


@rpc("any_peer", "call_local", "reliable")
func req_place(pos: Vector3i, slot: int, axis := "y") -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var held := _held(st, slot)
	var block := Items.block_of(held.get("id", ""))
	if block < 0:
		return
	block = Blocks.log_variant(block, axis)  # logs lie the way you put them
	var cells := [pos]
	var turn := -1
	if block == Blocks.ITEM_FRAME or block == Blocks.ARMOR_STAND:
		if not Blocks.is_replaceable(main.world.get_block(pos)):
			return
		if block == Blocks.ITEM_FRAME:
			# Frames go on walls: axis "n0".."n3" says which way the wall faces.
			if not axis.begins_with("n"):
				_tell(peer, "Item frames go on walls.")
				return
			turn = int(axis.substr(1))
			if not Blocks.is_solid(main.world.get_block(pos - _turn_dir(turn))):
				return
		else:
			var me3: Node3D = main.players.get_node_or_null(str(peer))
			turn = posmod(roundi((me3.rotation.y if me3 else 0.0) / (PI / 2.0)) + 2, 4)   # faces you
			if not Blocks.is_open(main.world.get_block(pos + Vector3i.UP)):
				_tell(peer, "An armor stand needs 2 blocks of room.")
				return
		if not main.world.server_set_block(pos, block, turn):
			return
		if block == Blocks.ITEM_FRAME:
			_frames[pos] = null
			_send_frame(pos)
		else:
			_stands[pos] = Inv.make(5)
			_send_stand(pos)
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_sync_self(peer)
		return
	if block == Blocks.BED:
		# Beds are two blocks long (you put down the foot, the pillow goes the way
		# you're looking), need floor under both halves, and room above to stand.
		var me_node: Node3D = main.players.get_node_or_null(str(peer))
		var byaw: float = me_node.rotation.y if me_node else 0.0
		turn = posmod(roundi(byaw / (PI / 2.0)), 4)
		var fwd := _turn_dir(turn)
		var head_pos: Vector3i = pos + fwd
		for c in [pos, head_pos]:
			if not Blocks.is_replaceable(main.world.get_block(c)) or not Blocks.is_solid(main.world.get_block(c + Vector3i.DOWN)):
				_tell(peer, "A bed needs 2 blocks of flat floor in front of you.")
				return
			if not Blocks.is_open(main.world.get_block(c + Vector3i.UP)) or not Blocks.is_open(main.world.get_block(c + Vector3i(0, 2, 0))):
				_tell(peer, "There needs to be room above the bed to stand up (2 blocks).")
				return
		for p in main.players.get_children():
			if AABB(p.global_position - Vector3(0.29, 0, 0.29), Vector3(0.58, 1.79, 0.58)).intersects(AABB(Vector3(head_pos), Vector3.ONE)):
				return
		if not main.world.server_set_block(pos, Blocks.BED_FOOT, turn):
			return
		main.world.server_set_block(head_pos, Blocks.BED, turn)
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_sync_self(peer)
		return
	if Blocks.SHAPE[block] != "":
		# Shaped blocks face away from you (stairs go up away from you) and can go upside down.
		var me: Node3D = main.players.get_node_or_null(str(_sender()))
		var yaw: float = me.rotation.y if me else 0.0
		turn = posmod(roundi(yaw / (PI / 2.0)), 4)
		if axis == "top":
			turn += 4
	if Blocks.is_door(block):
		cells.append(pos + Vector3i.UP)  # doors need two blocks of space
	if Blocks.is_sapling(block) and not Blocks.sapling_ground_ok(block, main.world.get_block(pos + Vector3i.DOWN)):
		_tell(peer, "Saplings need grass or dirt to grow in." if Blocks.SAPLINGS[block - Blocks.OAK_SAPLING][2] == "dirt" \
				else "This sapling needs grass, dirt or %s." % {"sand": "sand", "snowy": "snow", "candy": "frosting"}[Blocks.SAPLINGS[block - Blocks.OAK_SAPLING][2]])
		return
	if Blocks.is_plant(block) and not Blocks.plant_can_sit_on(main.world.get_block(pos + Vector3i.DOWN)):
		_tell(peer, "Plants need solid ground under them.")
		return
	if block == Blocks.CHEST or block == Blocks.SUPER_CHEST or block == Blocks.CAMPFIRE or block == Blocks.BEDROLL:
		# These face you (a chest's name plate goes on the front).
		var cn: Node3D = main.players.get_node_or_null(str(peer))
		turn = posmod(roundi((cn.rotation.y if cn else 0.0) / (PI / 2.0)) + 2, 4)
	for c in cells:
		if not Blocks.is_replaceable(main.world.get_block(c)):
			if Blocks.is_door(block):
				_tell(peer, "A door needs 2 empty blocks, one on top of the other.")
			return
		var box := AABB(Vector3(c), Vector3.ONE)
		if Blocks.is_solid(block):
			for p in main.players.get_children():
				if AABB(p.global_position - Vector3(0.29, 0, 0.29), Vector3(0.58, 1.79, 0.58)).intersects(box):
					return
	# Doors face the player who places them (like Minecraft).
	var facing := -1
	if Blocks.is_door(block):
		var node: Node3D = main.players.get_node_or_null(str(peer))
		var yaw: float = node.rotation.y if node else 0.0
		facing = 1 if absf(cos(yaw)) >= absf(sin(yaw)) else 0
	if turn >= 0:
		facing = turn
	for c in cells:
		if not main.world.server_set_block(c, block, facing if c == pos else -1):
			return
	if block == Blocks.TORCH:
		_torches[pos] = TORCH_SECONDS
	if Blocks.is_sapling(block):
		_sapling_planted(pos)
	if block == Blocks.PORTALSTONE:
		_check_portal_frame(pos, peer)
	Inv.remove_from_slot(st["inventory"], slot, 1)
	_sync_self(peer)


## Right-click on a door (open/close) or a bed (sleep / set respawn).
@rpc("any_peer", "call_local", "reliable")
func req_use_block(pos: Vector3i) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var b: int = main.world.get_block(pos)
	if Blocks.is_door(b):
		var cells := [pos]
		for off in [Vector3i.UP, Vector3i.DOWN]:
			if Blocks.same_door(main.world.get_block(pos + off), b):
				cells.append(pos + off)
		for c in cells:
			main.world.server_set_block(c, Blocks.DOOR_TOGGLE[main.world.get_block(c)])
	elif b == Blocks.BED:
		_use_bed(peer, st, pos)
	elif b == Blocks.BEDROLL or b == Blocks.CAMPFIRE:
		_rest(peer, st, pos, b)
	elif b == Blocks.ARENA_BOX:
		var spot := preload("res://scripts/arena_kit.gd").build(self, pos, peer)
		main._teleport.rpc_id(peer, spot)
		main._receive_event.rpc("%s opened an Arena in a Box!" % st["name"], "arena_box")
	elif b == Blocks.ARENA_BUTTON:
		arena_button(peer, pos)
	elif b == Blocks.CASTLE_BOX:
		var c := preload("res://scripts/castle_kit.gd").build(self, pos, peer)
		main._teleport.rpc_id(peer, c)
		main._receive_event.rpc("%s opened a Castle in a Box!" % st["name"], "castle_box")
	elif b == Blocks.BED_FOOT:
		var head := bed_other_half(pos, b)
		if head.y >= 0:
			_use_bed(peer, st, head)


## Which way a quarter turn (0-3) points: the way a player facing that way looks.
static func _turn_dir(turn: int) -> Vector3i:
	return [Vector3i(0, 0, -1), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)][posmod(turn, 4)]


## The other half of a two-block bed (NO_POS if it's an old one-block bed).
func bed_other_half(pos: Vector3i, b: int) -> Vector3i:
	var turn = main.world.door_facing(pos)
	if turn == null:
		return NO_POS
	var fwd := _turn_dir(int(turn))
	var other: Vector3i = pos + (fwd if b == Blocks.BED_FOOT else -fwd)
	var want := Blocks.BED if b == Blocks.BED_FOOT else Blocks.BED_FOOT
	return other if main.world.get_block(other) == want else NO_POS


func _use_bed(peer: int, st: Dictionary, pos: Vector3i) -> void:
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > 4.5:
		_tell(peer, "Get a little closer to your bed.")
		return
	var new_bed: bool = st["bed"] != pos
	st["bed"] = pos
	st["beds"][pos] = st["beds"].get(pos, 0) + 1
	if not main.day_night.is_night():
		_tell(peer, "Respawn point set! You can only sleep at night." if new_bed else "You can only sleep at night.")
		return
	if _monsters_near(pos):
		_tell(peer, "You can't sleep now, there are monsters nearby!")
		return
	_start_sleep(peer, st, pos)


func _monsters_near(pos: Vector3i) -> bool:
	for m in main.mobs.all_mobs():
		if m.def["kind"] == "hostile" and m.sim_pos.distance_to(Vector3(pos)) < 8.0:
			return true
	return false


## A bedroll or a campfire: sleep through the night out on an adventure,
## without moving your respawn point.
func _rest(peer: int, st: Dictionary, pos: Vector3i, b: int) -> void:
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > 4.5:
		_tell(peer, "Get a little closer.")
		return
	if not main.day_night.is_night():
		_tell(peer, "You can only sleep at night. (This won't change where you respawn.)")
		return
	if _monsters_near(pos):
		_tell(peer, "You can't sleep now, there are monsters nearby!")
		return
	var spot := pos
	if b == Blocks.CAMPFIRE:
		# Lie down beside the fire, not in it.
		spot = Vector3i(0, -1, 0)
		var me_pos := _player_pos(peer)
		var best := INF
		for t in 4:
			var c: Vector3i = pos + _turn_dir(t)
			var w: Node = main.world
			if Blocks.is_open(w.get_block(c)) and Blocks.is_open(w.get_block(c + Vector3i.UP)) and Blocks.is_solid(w.get_block(c + Vector3i.DOWN)):
				var d := me_pos.distance_to(Vector3(c))
				if d < best:
					best = d
					spot = c
		if spot.y < 0:
			_tell(peer, "There's no room to lie down by this fire.")
			return
	_start_sleep(peer, st, spot)
	if b == Blocks.CAMPFIRE:
		_tell(peer, "You curl up by the warm fire.")


func _start_sleep(peer: int, st: Dictionary, pos: Vector3i) -> void:
	st["sleeping"] = true
	_sleep_timer = 0.0
	_you_sleep.rpc_id(peer, pos)
	var sleeping := 0
	var awake := 0
	for s in _states.values():
		if s["alive"]:
			if s["sleeping"]:
				sleeping += 1
			else:
				awake += 1
	if awake > 0:
		main._receive_event.rpc("%s went to bed. (%d of %d sleeping)" % [st["name"], sleeping, sleeping + awake], "bed")


@rpc("any_peer", "call_local", "reliable")
func req_wake() -> void:
	if multiplayer.is_server():
		_wake(_sender())


func _wake(peer: int) -> void:
	var st: Dictionary = _states.get(peer, {})
	if not st.is_empty() and st["sleeping"]:
		st["sleeping"] = false
		_you_woke.rpc_id(peer)


func _tick_sleep(delta: float) -> void:
	var any := false
	var all := true
	for st in _states.values():
		if st["sleeping"]:
			any = true
		elif st["alive"]:
			all = false
	if not any:
		_sleep_timer = 0.0
		return
	if not main.day_night.is_night():
		for peer in _states:
			_wake(peer)
		return
	if all:
		_sleep_timer += delta
		if _sleep_timer >= SLEEP_SECONDS:
			_sleep_timer = 0.0
			main.day_night.set_time_of_day(0.26)  # morning!
			main._sync_time.rpc(main.day_night.world_time)
			for peer in _states:
				_wake(peer)
			main._receive_event.rpc("Good morning! Everyone slept through the night.", "torch")
	else:
		_sleep_timer = 0.0


## Fill a bottle (any water) or a bucket (still water only) from the water at pos.
@rpc("any_peer", "call_local", "reliable")
func req_fill(pos: Vector3i, slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var b: int = main.world.get_block(pos)
	var held := _held(st, slot)
	var id: String = held.get("id", "")
	if Blocks.is_lava(b):
		# Lava only goes in a bucket, and only from a still pool (it doesn't refill).
		if id != "bucket" or b != Blocks.LAVA:
			_tell(peer, "Only a bucket can hold lava, scooped from a still lava pool." if id == "bucket" else "That would melt!")
			return
		main.world.server_set_block(pos, Blocks.AIR)
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_give_or_drop(peer, "lava_bucket", 1)
		_sync_self(peer)
		return
	if not Blocks.is_water(b):
		return
	if id == "glass_bottle":
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_give_or_drop(peer, "water_bottle", 1)
	elif id == "bucket":
		if b != Blocks.WATER:
			_tell(peer, "That water is flowing away. Scoop from still water, like a lake.")
			return
		# Like Minecraft: a still block with 2+ still neighbors refills straight away
		# (lakes never run dry); a lone block is used up.
		var still := 0
		for off in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			if main.world.get_block(pos + off) == Blocks.WATER:
				still += 1
		if still < 2:
			main.world.server_set_block(pos, Blocks.AIR)
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_give_or_drop(peer, "water_bucket", 1)
	else:
		return
	_sync_self(peer)


## Pour a water bucket out at pos: it becomes still water (and flows from there).
@rpc("any_peer", "call_local", "reliable")
func req_pour(pos: Vector3i, slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var held_id: String = _held(st, slot).get("id", "")
	if not held_id in ["water_bucket", "lava_bucket"]:
		return
	if not Blocks.is_replaceable(main.world.get_block(pos)) and not Blocks.is_plant(main.world.get_block(pos)):
		return
	if not main.world.server_set_block(pos, Blocks.WATER if held_id == "water_bucket" else Blocks.LAVA):
		return
	st["inventory"][slot] = {"id": "bucket", "count": 1}
	_sync_self(peer)


## Eat food from the hotbar.
@rpc("any_peer", "call_local", "reliable")
func req_use(slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var d := Items.get_def(_held(st, slot).get("id", ""))
	if not d.has("food"):
		return
	if st["health"] >= MAX_HEALTH:
		_tell(peer, "You're already at full health.")
		return
	st["health"] = minf(MAX_HEALTH, st["health"] + d["food"])
	Inv.remove_from_slot(st["inventory"], slot, 1)
	_sync_self(peer)


# --- Requests: moving items (Rust style) --------------------------------------------------

## The slots behind an area for a player ([] if they can't use it right now).
func _area(peer: int, area: String) -> Array:
	if area == "inv":
		return _states[peer]["inventory"]
	var v: Dictionary = _viewers.get(peer, {})
	if area != "open" or v.is_empty():
		return []
	match v["kind"]:
		"furnace":
			return _furnaces[v["key"]]["slots"] if _furnaces.has(v["key"]) else []
		"chest":
			return _chests.get(v["key"], [])
		"super":
			return _states[peer]["ender"]
		"stand":
			return _stands.get(v["key"], [])
		"loot":
			return _loot[v["key"]]["slots"] if _loot.has(v["key"]) else []
		"trade":
			return _trades[v["key"]]["offer"][peer] if _trades.has(v["key"]) else []
	return []


func _accepts(peer: int, area: String, index: int, id: String) -> bool:
	if area == "inv":
		return Inv.player_slot_accepts(index, id)
	if _viewers.get(peer, {}).get("kind", "") == "stand":
		return index >= 0 and index < 5 and Items.get_def(id).get("slot", "") == STAND_SLOTS[index]
	if _viewers.get(peer, {}).get("kind", "") == "furnace":
		if index == 0:
			return Recipes.SMELTING.has(id)
		if index == 1:
			return Recipes.fuel_value(id) > 0.0
		return false  # results only come out
	return true


## Move `count` items (0 = the whole stack) from one slot to another.
## to_index < 0 means "quick move" (right-click): to the other side, wherever it fits.
@rpc("any_peer", "call_local", "reliable")
func req_move(from_area: String, from_index: int, to_area: String, to_index: int, count: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var src := _area(peer, from_area)
	if from_index < 0 or from_index >= src.size() or src[from_index] == null:
		return
	var s: Dictionary = src[from_index]
	var n: int = s["count"] if count <= 0 else mini(count, s["count"])
	if to_index < 0:
		_quick_move(peer, from_area, from_index, n)
	else:
		var dst := _area(peer, to_area)
		if to_index >= dst.size() or (from_area == to_area and from_index == to_index):
			return
		if not _accepts(peer, to_area, to_index, s["id"]):
			if to_area == "inv" and to_index >= Inv.ARMOR_START:
				_tell(peer, "That doesn't go in this armor slot.")
			return
		var d = dst[to_index]
		var stackable: bool = d != null and d["id"] == s["id"] and Inv.extra(d).is_empty() and Inv.extra(s).is_empty()
		if d == null:
			if n == s["count"]:
				dst[to_index] = s  # the whole thing moves, with any data it carries
				src[from_index] = null
			else:
				var part: Dictionary = s.duplicate(true)
				part["count"] = n
				dst[to_index] = part
				Inv.remove_from_slot(src, from_index, n)
		elif stackable and d["count"] < Items.max_stack(s["id"]):
			var room: int = Items.max_stack(s["id"]) - d["count"]
			var moved := mini(room, n)
			if moved <= 0:
				return
			d["count"] += moved
			Inv.remove_from_slot(src, from_index, moved)
		elif stackable and n < s["count"]:
			return  # that stack is full
		elif n == s["count"] and _accepts(peer, from_area, from_index, d["id"]):
			src[from_index] = d
			dst[to_index] = s  # different items: swap them
		else:
			return
	_after_move(peer, from_area, to_area)


func _quick_move(peer: int, from_area: String, from_index: int, n: int) -> void:
	var src := _area(peer, from_area)
	var s: Dictionary = src[from_index]
	var v: Dictionary = _viewers.get(peer, {})
	var inv: Array = _states[peer]["inventory"]
	var left := n
	var data := Inv.extra(s)
	if from_area == "open":
		left = Inv.add_range(inv, s["id"], n, 0, Inv.PLAYER_SLOTS, data)
	elif not v.is_empty():
		var dst := _area(peer, "open")
		if v["kind"] == "furnace":
			var target := 0 if Recipes.SMELTING.has(s["id"]) else (1 if Recipes.fuel_value(s["id"]) > 0.0 else -1)
			if target < 0:
				_tell(peer, "%s can't be smelted or burned." % Items.display_name(s["id"]))
				return
			left = Inv.add_range(dst, s["id"], n, target, target + 1, data)
		elif v["kind"] == "stand":
			var si := STAND_SLOTS.find(Items.get_def(s["id"]).get("slot", ""))
			if si < 0:
				_tell(peer, "Only armor and capes go on an armor stand.")
				return
			left = Inv.add_range(dst, s["id"], n, si, si + 1, data)
		else:
			left = Inv.add_range(dst, s["id"], n, 0, dst.size(), data)
	else:
		# No box open: armor gets worn, hotbar <-> backpack, armor -> backpack.
		var armor_slot := Inv.armor_slot_for(s["id"])
		if from_index < Inv.ARMOR_START and armor_slot >= 0 and inv[armor_slot] == null:
			var one: Dictionary = s.duplicate(true)
			one["count"] = 1
			inv[armor_slot] = one
			left = n - 1
		elif from_index < Inv.HOTBAR_SIZE:
			left = Inv.add_range(inv, s["id"], n, Inv.HOTBAR_SIZE, Inv.PLAYER_SLOTS, data)
		elif from_index < Inv.PLAYER_SLOTS:
			left = Inv.add_range(inv, s["id"], n, 0, Inv.HOTBAR_SIZE, data)
		else:
			left = Inv.add_range(inv, s["id"], n, Inv.HOTBAR_SIZE, Inv.PLAYER_SLOTS, data)
			if left > 0:
				left = Inv.add_range(inv, s["id"], left, 0, Inv.HOTBAR_SIZE, data)
	var moved := n - left
	if moved <= 0:
		_tell(peer, "There's no room for that.")
		return
	Inv.remove_from_slot(src, from_index, moved)


func _after_move(peer: int, from_area: String, to_area: String) -> void:
	if from_area == "open" or to_area == "open":
		var v: Dictionary = _viewers.get(peer, {})
		if not v.is_empty():
			if v["kind"] == "trade" and _trades.has(v["key"]):
				_trade_changed(v["key"])
			else:
				_after_container_change(v)
	_sync_self(peer)


## Throw items on the ground (Q in the game, or drag them out of the window).
@rpc("any_peer", "call_local", "reliable")
func req_drop(area: String, index: int, count: int, dir: Vector3) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var src := _area(peer, area)
	if index < 0 or index >= src.size() or src[index] == null:
		return
	var s: Dictionary = src[index]
	var n: int = s["count"] if count <= 0 else mini(count, s["count"])
	var id: String = s["id"]
	var data := Inv.extra(s)
	Inv.remove_from_slot(src, index, n)
	var forward := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	_spawn_drop(id, n, _player_pos(peer) + Vector3(0, 1.3, 0) + forward * 0.4, forward * 4.5 + Vector3(0, 2.0, 0), DROP_PICKUP_DELAY, data)
	_after_move(peer, area, area)


# Old request names, kept so older tests and saves keep working.
@rpc("any_peer", "call_local", "reliable")
func req_swap(a: int, b: int) -> void:
	req_move("inv", a, "inv", b, 0)


@rpc("any_peer", "call_local", "reliable")
func req_take(slot: int) -> void:
	req_move("open", slot, "inv", -1, 0)


@rpc("any_peer", "call_local", "reliable")
func req_put(inv_slot: int) -> void:
	req_move("inv", inv_slot, "open", -1, 0)


@rpc("any_peer", "call_local", "reliable")
func req_take_all() -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var slots := _area(peer, "open")
	if slots.is_empty() or _viewers[peer]["kind"] == "trade":
		return
	if not Inv.move_all(slots, st["inventory"], Inv.PLAYER_SLOTS):
		_tell(peer, "Your inventory is full.")
	_after_move(peer, "open", "inv")


# --- The spawn shrine, boss trophies and powers ----------------------------------------------
# A round stone plaza at spawn with a ring of statues, one for each boss (and
# some for bosses still to come). It can't be broken. Put a boss's trophy on
# its statue (once, for everyone), then right-click it to pick its power and
# press F to use it: it lasts 5 minutes, then needs 20 minutes to come back.

const SHRINE_RADIUS := 10
const STATUE_RING := 7
var shrine_center := NO_POS     # the middle of the plaza floor (same on server and client)
var _power_stamp := 0.0         # (client) when the power times in `me` arrived
var _shrine_timer := 0.0
var _trophies := {}             # boss id -> who put it there (server)
var trophies := {}              # client copy


## What the shrine put at this spot (-1 = not part of it). Same on every computer.
func shrine_block_at(p: Vector3i) -> int:
	if shrine_center == NO_POS:
		return -1
	var c := shrine_center
	var dx := p.x - c.x
	var dz := p.z - c.z
	var r := sqrt(float(dx * dx + dz * dz))
	if r > SHRINE_RADIUS + 0.5:
		return -1
	var dy := p.y - c.y
	if dy < -3 or dy > 3:
		return -1
	if dy == 0:
		return Blocks.CHISELED_BRICKS if r < 2.5 or absf(r - STATUE_RING) < 0.6 else Blocks.STONE_BRICKS
	if dy < 0:
		return Blocks.STONE
	var si := statue_index(Vector3i(p.x, c.y + 2, p.z))
	if si >= 0:
		return Blocks.STONE_PILLAR if dy == 1 else (Blocks.BOSS_STATUE if dy == 2 else -1)
	if absi(dx) == 4 and absi(dz) == 4:
		return Blocks.STONE_PILLAR if dy <= 2 else Blocks.LAMP
	return -1


func statue_spot(i: int) -> Vector3i:
	var a := TAU * i / BossData.SHRINE_SLOTS
	return shrine_center + Vector3i(roundi(sin(a) * STATUE_RING), 2, roundi(-cos(a) * STATUE_RING))


## Which statue is at this spot (-1 = none).
func statue_index(p: Vector3i) -> int:
	if shrine_center == NO_POS:
		return -1
	for i in BossData.SHRINE_SLOTS:
		if statue_spot(i) == p:
			return i
	return -1


## Build the shrine once the ground around spawn has loaded (any world, old or new).
func _try_build_shrine() -> void:
	var w: Node = main.world
	var sp: Vector3 = w.find_spawn_point()
	var c := Vector3i(floori(sp.x), floori(sp.y - 1.0), floori(sp.z))
	for off in [Vector3i(-12, 0, -12), Vector3i(12, 0, -12), Vector3i(-12, 0, 12), Vector3i(12, 0, 12), Vector3i.ZERO]:
		if not w.is_data_loaded(Vector3(c + off)):
			return
	shrine_center = c
	for dz in range(-SHRINE_RADIUS, SHRINE_RADIUS + 1):
		for dx in range(-SHRINE_RADIUS, SHRINE_RADIUS + 1):
			if dx * dx + dz * dz > (SHRINE_RADIUS + 0.5) * (SHRINE_RADIUS + 0.5):
				continue
			for dy in range(-3, 9):
				var p := c + Vector3i(dx, dy, dz)
				var want := shrine_block_at(p)
				if want < 0:
					if dy <= 0 or Blocks.is_open(w.get_block(p)):
						continue
					want = Blocks.AIR   # clear the space above the floor
				if dy < 0 and Blocks.is_solid(w.get_block(p)):
					continue   # solid ground under the floor can stay
				if w.get_block(p) != want:
					w.server_set_block(p, want)
	_receive_shrine.rpc(shrine_center, _trophies)


@rpc("authority", "call_local", "reliable")
func _receive_shrine(center: Vector3i, placed: Dictionary) -> void:
	shrine_center = center
	trophies = placed
	if main and main.block_models and center != NO_POS:
		for i in BossData.SHRINE_SLOTS:
			main.block_models.refresh(statue_spot(i))


## Right-click a statue: put its trophy on it, or pick its power.
@rpc("any_peer", "call_local", "reliable")
func req_statue(pos: Vector3i, slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var i := statue_index(pos)
	if i < 0 or main.world.get_block(pos) != Blocks.BOSS_STATUE or _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH + 1.0:
		return
	if i >= BossData.BOSSES.size():
		_tell(peer, "This statue is waiting for a boss nobody has found yet...")
		return
	var boss: Dictionary = BossData.BOSSES[i]
	var trophy := BossData.trophy_id(boss["id"])
	if not _trophies.has(boss["id"]):
		if _held(st, slot).get("id", "") != trophy:
			_tell(peer, "The %s. Beat it in %s and bring its trophy here to unlock %s: %s." % [boss["name"], boss["lair"], boss["power"], boss["text"].to_lower()])
			return
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_trophies[boss["id"]] = st["name"]
		st["chosen_power"] = boss["id"]
		main._receive_event.rpc("%s put the %s on its statue! Everyone can now use %s (pick it at the statue, press F)." % [st["name"], Items.display_name(trophy), boss["power"]], trophy)
		_receive_shrine.rpc(shrine_center, _trophies)
		_sync_self(peer)
		return
	st["chosen_power"] = boss["id"]
	_tell(peer, "Your power is now %s: %s. Press F to use it." % [boss["power"], boss["text"].to_lower()])
	_sync_self(peer)


## F: use your chosen power (if it's ready).
@rpc("any_peer", "call_local", "reliable")
func req_use_power() -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var id: String = st.get("chosen_power", "")
	if id == "" or not _trophies.has(id):
		_tell(peer, "You haven't picked a power yet. Put a boss trophy on its statue at the shrine by spawn!")
		return
	if st.get("power_cd", 0.0) > 0.0:
		_tell(peer, "Your power needs %s more to come back." % _mmss(st["power_cd"]))
		return
	var boss := BossData.get_boss(id)
	st["power_id"] = id
	st["power_left"] = BossData.POWER_SECONDS
	st["power_cd"] = BossData.POWER_COOLDOWN
	_tell(peer, "%s! %s for 5 minutes." % [boss["power"], boss["text"]])
	_sync_self(peer)


static func mmss(secs: float) -> String:
	return _mmss(secs)


static func _mmss(secs: float) -> String:
	var s := ceili(secs)
	return "%d:%02d" % [s / 60, s % 60]


func _tick_powers(delta: float) -> void:
	for peer in _states:
		var st: Dictionary = _states[peer]
		if st.get("power_cd", 0.0) > 0.0:
			st["power_cd"] = maxf(0.0, st["power_cd"] - delta)
			if st["power_cd"] == 0.0:
				_tell(peer, "Your power is ready again (F).")
				_sync_self(peer)
		if st.get("power_left", 0.0) > 0.0:
			st["power_left"] = maxf(0.0, st["power_left"] - delta)
			if st["power_left"] == 0.0:
				_tell(peer, "Your %s wore off." % BossData.get_boss(st.get("power_id", "")).get("power", "power"))
				_sync_self(peer)


## The boss power someone has going right now ({} = none).
func _power_def(st: Dictionary) -> Dictionary:
	if st.get("power_left", 0.0) <= 0.0:
		return {}
	return BossData.get_boss(st.get("power_id", ""))


func _has_special(st: Dictionary, special: String) -> bool:
	return _power_def(st).get("special", "") == special


# --- Parties -----------------------------------------------------------------------------------
# Invite anyone who's online (P opens the party window). A party remembers
# its members by character, so leaving the game and coming back keeps you in
# it. Party members see each other's names from far away; party maps (made at
# a tier 3 bench) share what everyone in the party has explored.

const PARTY_INVITE_TIME := 30.0
const PARTY_TAG_RANGE := 200.0
var _parties := {}              # id -> {"name", "leader": key, "members": [keys]}
var _next_party := 1
var _party_invites := {}        # invited peer -> {"from": peer, "time"}
var parties := {}               # client copy: id -> {"name", "leader_peer", "members": [{"key", "name", "peer", "online", "leader"}]}
var party_roster: Array = []    # client copy: everyone online [{"peer", "name", "party"}]


func party_of_key(key: String) -> int:
	for id in _parties:
		if key in _parties[id]["members"]:
			return int(id)
	return 0


func party_of_peer(peer: int) -> int:
	return party_of_key(_states.get(peer, {}).get("key", ""))


## (Client) the boss power I have going right now ({} = none).
func active_power() -> Dictionary:
	var p: Dictionary = me.get("power", {})
	if float(p.get("left", 0.0)) - (_clock - _power_stamp) <= 0.0:
		return {}
	return BossData.get_boss(p.get("id", ""))


## (Client) seconds left on my power, and until it's ready again.
func power_times() -> Vector2:
	var p: Dictionary = me.get("power", {})
	var gone := _clock - _power_stamp
	return Vector2(maxf(0.0, float(p.get("left", 0.0)) - gone), maxf(0.0, float(p.get("cd", 0.0)) - gone))


## (Client) the party I'm in, or 0.
func my_party() -> int:
	var me_peer := multiplayer.get_unique_id()
	for id in parties:
		for m in parties[id]["members"]:
			if m["peer"] == me_peer:
				return int(id)
	return 0


## (Client) is this player in my party?
func in_my_party(peer: int) -> bool:
	var pid := my_party()
	if pid == 0:
		return false
	for m in parties[pid]["members"]:
		if m["peer"] == peer:
			return true
	return false


func _key_name(key: String) -> String:
	var peer := peer_of(key)
	if peer != 0:
		return _states[peer]["name"]
	return str(_saved.get(key, {}).get("name", key))


func _can_reach(peer: int) -> bool:
	return peer == multiplayer.get_unique_id() or peer in multiplayer.get_peers()


func _party_tell(id: int, text: String) -> void:
	for key in _parties.get(id, {}).get("members", []):
		var peer := peer_of(key)
		if peer != 0 and _can_reach(peer):
			_tell(peer, text)


@rpc("any_peer", "call_local", "reliable")
func req_party_invite(target: int) -> void:
	if multiplayer.is_server():
		party_invite(_sender(), target)


@rpc("any_peer", "call_local", "reliable")
func req_party_answer(from_peer: int, yes: bool) -> void:
	if multiplayer.is_server():
		party_answer(_sender(), from_peer, yes)


@rpc("any_peer", "call_local", "reliable")
func req_party_leave() -> void:
	if multiplayer.is_server():
		party_leave(_sender())


@rpc("any_peer", "call_local", "reliable")
func req_party_kick(key: String) -> void:
	if multiplayer.is_server():
		party_kick(_sender(), key)


## (Server) `from` asks `target` to join their party (making one if needed).
func party_invite(from: int, target: int) -> void:
	var st: Dictionary = _states.get(from, {})
	var other: Dictionary = _states.get(target, {})
	if st.is_empty() or other.is_empty() or from == target:
		return
	var mine := party_of_peer(from)
	var theirs := party_of_peer(target)
	if mine != 0 and mine == theirs:
		return
	if theirs != 0:
		_tell(from, "%s is already in %s." % [other["name"], _parties[theirs]["name"]])
		return
	_party_invites[target] = {"from": from, "time": now()}
	var party_name: String = _parties[mine]["name"] if mine != 0 else "%s's Party" % st["name"]
	if _can_reach(target):
		_party_invite.rpc_id(target, from, st["name"], party_name)
	_tell(from, "You asked %s to join your party." % other["name"])


## (Server) `peer` answers an invite from `from`.
func party_answer(peer: int, from: int, yes: bool) -> void:
	var inv: Dictionary = _party_invites.get(peer, {})
	if inv.get("from", 0) != from:
		return
	_party_invites.erase(peer)
	var st: Dictionary = _states.get(peer, {})
	var host: Dictionary = _states.get(from, {})
	if st.is_empty():
		return
	if not yes:
		if not host.is_empty():
			_tell(from, "%s said no thanks." % st["name"])
		return
	if host.is_empty() or now() - inv["time"] > PARTY_INVITE_TIME or party_of_peer(peer) != 0:
		_tell(peer, "That invite isn't available any more.")
		return
	var id := party_of_peer(from)
	if id == 0:
		id = _next_party
		_next_party += 1
		_parties[id] = {"name": "%s's Party" % host["name"], "leader": host["key"], "members": [host["key"]]}
	_parties[id]["members"].append(st["key"])
	_party_tell(id, "%s joined %s!" % [st["name"], _parties[id]["name"]])
	_send_party_info()


func party_leave(peer: int) -> void:
	var st: Dictionary = _states.get(peer, {})
	var id := party_of_peer(peer)
	if st.is_empty() or id == 0:
		return
	_remove_from_party(id, st["key"])
	_tell(peer, "You left the party.")
	_party_tell(id, "%s left the party." % st["name"])
	_send_party_info()


## The leader can take someone out of the party.
func party_kick(peer: int, key: String) -> void:
	var st: Dictionary = _states.get(peer, {})
	var id := party_of_peer(peer)
	if st.is_empty() or id == 0 or _parties[id]["leader"] != st["key"] or key == st["key"] or not key in _parties[id]["members"]:
		return
	_remove_from_party(id, key)
	var gone := peer_of(key)
	if gone != 0 and _can_reach(gone):
		_tell(gone, "You're not in %s any more." % _parties.get(id, {}).get("name", "the party"))
	_party_tell(id, "%s left the party." % _key_name(key))
	_send_party_info()


## Takes someone out; a party of one is no party, and if the leader goes
## the next person leads.
func _remove_from_party(id: int, key: String) -> void:
	var p: Dictionary = _parties[id]
	p["members"].erase(key)
	if p["members"].size() <= 1:
		_parties.erase(id)
		return
	if p["leader"] == key:
		p["leader"] = p["members"][0]
		p["name"] = "%s's Party" % _key_name(p["leader"])


## Everyone gets the list of parties and who's online.
func _send_party_info() -> void:
	if not multiplayer.is_server():
		return
	var out := {}
	for id in _parties:
		var p: Dictionary = _parties[id]
		var members := []
		for key in p["members"]:
			var peer := peer_of(key)
			members.append({"key": key, "name": _key_name(key), "peer": peer, "online": peer != 0, "leader": key == p["leader"]})
		out[int(id)] = {"name": p["name"], "leader_peer": peer_of(p["leader"]), "members": members}
	var roster := []
	for peer in _states:
		roster.append({"peer": peer, "name": _states[peer]["name"], "party": party_of_peer(peer)})
	_receive_party_info.rpc(out, roster)


@rpc("authority", "call_local", "reliable")
func _receive_party_info(info: Dictionary, roster: Array) -> void:
	parties = info
	party_roster = roster
	party_changed.emit()


@rpc("authority", "call_local", "reliable")
func _party_invite(from_peer: int, from_name: String, party_name: String) -> void:
	party_invited.emit(from_peer, from_name, party_name)


# --- Chest tools ------------------------------------------------------------------------------

const CHEST_NAME_MAX := 20
var _chest_names := {}          # Vector3i -> name (server)
var chest_names := {}           # client copy
var _chest_labels := {}         # Vector3i -> Label3D floating over the chest (client)


func _open_chest_slots(peer: int) -> Array:
	var v: Dictionary = _viewers.get(peer, {})
	if v.get("kind", "") == "super":
		return _states[peer]["ender"]
	if v.get("kind", "") != "chest":
		return []
	return _chests.get(v["key"], [])


## "Put in matching": every stack in your hotbar and backpack that's already
## somewhere in the chest goes in (like Valheim's Place stacks).
@rpc("any_peer", "call_local", "reliable")
func req_store_matching() -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var chest := _open_chest_slots(peer)
	if chest.is_empty():
		return
	var have := {}
	for s in chest:
		if s != null:
			have[s["id"]] = true
	var moved := _store(st["inventory"], chest, 0, func(s: Dictionary) -> bool: return have.has(s["id"]))
	_tell(peer, "Put %d matching item%s in the chest." % [moved, "" if moved == 1 else "s"] if moved > 0 else "Nothing you're carrying matches what's in this chest.")
	_after_move(peer, "inv", "open")


## "Store backpack": everything in your backpack (not your hotbar, not what you wear).
@rpc("any_peer", "call_local", "reliable")
func req_store_backpack() -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var chest := _open_chest_slots(peer)
	if chest.is_empty():
		return
	var moved := _store(st["inventory"], chest, Inv.HOTBAR_SIZE, func(_s: Dictionary) -> bool: return true)
	var left := 0
	for i in range(Inv.HOTBAR_SIZE, Inv.PLAYER_SLOTS):
		if st["inventory"][i] != null:
			left += 1
	if left > 0:
		_tell(peer, "The chest is full! %d stack%s didn't fit." % [left, "" if left == 1 else "s"])
	elif moved == 0:
		_tell(peer, "Your backpack is already empty.")
	_after_move(peer, "inv", "open")


## Moves slots from inventory[from..36) into the chest when `want` says so.
## Returns how many items went in.
func _store(inv: Array, chest: Array, from: int, want: Callable) -> int:
	var moved := 0
	for i in range(from, Inv.PLAYER_SLOTS):
		var s = inv[i]
		if s == null or not want.call(s):
			continue
		var left := Inv.add_slot(chest, s)
		moved += s["count"] - left
		if left == 0:
			inv[i] = null
		else:
			s["count"] = left
	return moved


## Write a name on a chest (it floats over it). Empty = no name.
@rpc("any_peer", "call_local", "reliable")
func req_name_chest(pos: Vector3i, chest_name: String) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if main.world.get_block(pos) != Blocks.CHEST or _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH + 1.0:
		return
	chest_name = chest_name.strip_edges().substr(0, CHEST_NAME_MAX)
	if chest_name.is_empty():
		_chest_names.erase(pos)
	else:
		_chest_names[pos] = chest_name
	_receive_chest_name.rpc(pos, chest_name)
	var v: Dictionary = _viewers.get(peer, {})
	if not v.is_empty():
		_after_container_change(v)


@rpc("authority", "call_local", "reliable")
func _receive_chest_name(pos: Vector3i, chest_name: String) -> void:
	if chest_name.is_empty():
		chest_names.erase(pos)
	else:
		chest_names[pos] = chest_name
	_refresh_chest_labels()


## Little name plates on named chests: one on the front, one on the lid.
func _refresh_chest_labels() -> void:
	if main == null or main.world == null:
		return
	for pos in _chest_labels.keys():
		if not chest_names.has(pos):
			if is_instance_valid(_chest_labels[pos]):
				_chest_labels[pos].queue_free()
			_chest_labels.erase(pos)
	for pos in chest_names:
		var plate: Node3D = _chest_labels.get(pos)
		if plate == null or not is_instance_valid(plate):
			plate = _make_name_plates()
			main.world.add_child(plate)
			_chest_labels[pos] = plate
		var f = main.world.door_facing(pos)
		plate.position = Vector3(pos) + Vector3(0.5, 0.0, 0.5)
		plate.rotation.y = (int(f) if f != null else 0) * PI / 2.0   # the front faces whoever put it down
		var text: String = chest_names[pos]
		# Shrink long names so they fit on the plate.
		var px := minf(0.0034, 0.5 / (maxf(text.length(), 1.0) * 30.0 * 0.58))
		for lab in plate.get_meta("labels", []):
			(lab as Label3D).text = text
			(lab as Label3D).pixel_size = px


static var _plate_mats: Array = []


## A plate built facing -Z (rotated to the chest's front): dark wood in a gold
## frame, with the name carved in cream letters.
static func _make_name_plates() -> Node3D:
	if _plate_mats.is_empty():
		var frame := StandardMaterial3D.new()
		frame.albedo_color = Color(0.78, 0.6, 0.25)
		frame.metallic = 0.6
		frame.roughness = 0.35
		var board := StandardMaterial3D.new()
		board.albedo_color = Color(0.17, 0.1, 0.06)
		board.roughness = 0.8
		_plate_mats = [frame, board]
	var root := Node3D.new()
	var labels := []
	# [plate center, plate size, label basis]
	var faces := [
		[Vector3(0, 0.3, -0.5), Vector3(0.62, 0.19, 0.03), Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))],
		# The lid plate sits on the far half, reading the right way up for whoever stands at the front.
		[Vector3(0, 1.0, 0.24), Vector3(0.62, 0.03, 0.2), Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))],
	]
	for f in faces:
		var size: Vector3 = f[1]
		var b: Basis = f[2]
		var normal: Vector3 = b.z
		for layer in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = size if layer == 0 else size - Vector3(0.05, 0.05, 0.05) + normal.abs() * 0.06
			bm.material = _plate_mats[layer]
			mi.mesh = bm
			mi.position = f[0] + normal * (0.002 if layer == 0 else 0.006)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		var lab := Label3D.new()
		lab.basis = b
		lab.position = f[0] + normal * 0.04
		lab.font_size = 30
		lab.outline_size = 0
		lab.modulate = Color(1.0, 0.93, 0.72)
		lab.double_sided = false
		lab.shaded = false
		lab.visibility_range_end = 14.0
		root.add_child(lab)
		labels.append(lab)
	root.set_meta("labels", labels)
	return root


# --- Bows and arrows ----------------------------------------------------------------------
# The server flies every arrow (so everyone agrees what it hit). Arrows fall
# as they go (drop-off), so long shots need aiming high. Every computer draws
# its own copy of each arrow along the same path.

const ARROW_GRAVITY := 14.0
const ARROW_LIFE := 6.0
const SHOOT_COOLDOWN := 0.35
const POISON_DPS := 1.0
const POISON_SECONDS := 6.0
const FROST_SECONDS := 4.0

var _arrows := {}               # id -> {"type", "pos", "vel", "damage", "effect", "peer", "age"}
var _next_arrow := 1
var _poisoned := {}             # mob id -> {"left", "tick", "peer"}
var _shoot_times := {}


## The arrow a player would shoot next: the first arrows in the hotbar, then the backpack.
static func next_arrow_slot(inv: Array) -> int:
	for i in Inv.PLAYER_SLOTS:
		if inv[i] != null and Items.get_def(inv[i]["id"]).has("arrow"):
			return i
	return -1


## Let go of the bow. charge 0..1 = how far it was pulled back.
@rpc("any_peer", "call_local", "reliable")
func req_shoot(slot: int, origin: Vector3, dir: Vector3, charge: float) -> void:
	var st := _actor()
	if st.is_empty() or not st["alive"]:
		return
	var peer := _sender()
	var bow := Items.get_def(_held(st, slot).get("id", ""))
	if not bow.has("bow"):
		return
	var t := now()
	if t - _shoot_times.get(peer, -10.0) < SHOOT_COOLDOWN:
		return
	var eye := _player_pos(peer) + Vector3(0, 1.62, 0)
	if origin.distance_to(eye) > 2.5:
		origin = eye  # don't trust a far-away starting point
	var ai := next_arrow_slot(st["inventory"])
	if ai < 0:
		_tell(peer, "You need arrows! Make some at a workbench.")
		return
	_shoot_times[peer] = t
	var arrow_id: String = st["inventory"][ai]["id"]
	var a := Items.get_def(arrow_id)
	Inv.remove_from_slot(st["inventory"], ai, 1)
	charge = clampf(charge, 0.0, 1.0)
	var speed: float = bow["power"] * (0.3 + 0.7 * charge)
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var id := _next_arrow
	_next_arrow += 1
	_arrows[id] = {"type": arrow_id, "pos": origin + d * 0.6, "vel": d * speed, "peer": peer, "age": 0.0,
			"damage": float(a["arrow"]) * float(bow["bow_damage"]) * (0.35 + 0.65 * charge), "effect": a.get("effect", ""),
			"leech": weapon_leech(_held(st, slot))}
	_arrow_spawn.rpc(id, arrow_id, _arrows[id]["pos"], _arrows[id]["vel"])
	_sync_self(peer)


## A mob shoots at a player (skeleton archers; later the castle boss).
## Shots aim a little ahead and high, and use the same flying arrows as players' bows.
func mob_shoot(mob: Node3D, target_peer: int, shot := "") -> void:
	if not _states.has(target_peer):
		return
	var r: Dictionary = mob.def.get("ranged", {})
	var kind: String = shot if shot != "" else r.get("shot", "wooden_arrow")
	var dmg: float = r.get("damage", 4.0) * float(mob.dmg_mult)
	var effect: String = r.get("effect", "")
	if r.has("shots"):
		# Takes turns: fire, then ice, then fire...
		var n: int = mob.get_meta("shot_n", 0)
		mob.set_meta("shot_n", n + 1)
		var pick: Array = r["shots"][n % r["shots"].size()]
		kind = pick[0]
		dmg = pick[1]
		effect = pick[2]
	var from: Vector3 = mob.sim_pos + Vector3(0, mob.height() * 0.8, 0)
	var to: Vector3 = _player_pos(target_peer) + Vector3(0, 1.1, 0)
	var speed: float = r.get("speed", 22.0)
	var t := from.distance_to(to) / speed
	to.y += 0.5 * ARROW_GRAVITY * t * t * (0.0 if kind in NO_DROP_SHOTS else 1.0)   # aim up to make up for the drop
	var dir := (to - from).normalized()
	dir += Vector3(randf_range(-0.03, 0.03), randf_range(-0.02, 0.02), randf_range(-0.03, 0.03))   # not perfect aim
	var id := _next_arrow
	_next_arrow += 1
	_arrows[id] = {"type": kind, "pos": from + dir * 0.8, "vel": dir.normalized() * speed, "peer": 0, "age": 0.0,
			"damage": dmg, "effect": effect, "mob": mob.type, "no_drop": kind in NO_DROP_SHOTS}
	_arrow_spawn.rpc(id, kind, _arrows[id]["pos"], _arrows[id]["vel"])


## Shots that fly straight (magic), and never land as items.
const NO_DROP_SHOTS := ["fireball", "iceball", "acorn", "gumball", "wisp", "card", "royal_bolt", "shadow_bolt",
		"hot_sauce", "toy_ball", "toy_duck", "toy_block"]
const TOY_SHOTS := ["toy_ball", "toy_duck", "toy_block"]
const SHOT_COLORS := {"fireball": Color(1.0, 0.5, 0.12), "iceball": Color(0.5, 0.9, 1.0), "acorn": Color(0.6, 0.4, 0.2),
		"gumball": Color(1.0, 0.35, 0.6), "wisp": Color(0.45, 1.0, 0.6), "royal_bolt": Color(1.0, 0.92, 0.6), "shadow_bolt": Color(0.65, 0.3, 1.0),
		"hot_sauce": Color(1.0, 0.25, 0.08), "toy_ball": Color(1.0, 0.3, 0.3), "toy_duck": Color(1.0, 0.88, 0.2), "toy_block": Color(0.3, 0.55, 1.0)}


func _tick_arrows(delta: float) -> void:
	for id in _arrows.keys():
		var ar: Dictionary = _arrows[id]
		ar["age"] += delta
		if ar["age"] > ARROW_LIFE:
			_end_arrow(id, ar["pos"], false)
			continue
		var p: Vector3 = ar["pos"]
		var v: Vector3 = ar["vel"]
		if not ar.get("no_drop", false):
			v.y -= ARROW_GRAVITY * delta
		var next := p + v * delta
		ar["vel"] = v
		if ar.has("mob"):
			# A mob's shot: it hits players, not other mobs.
			var hit_peer := 0
			for pl in player_list():
				if not pl["alive"]:
					continue
				var box := AABB(pl["pos"] - Vector3(0.35, 0, 0.35), Vector3(0.7, 1.85, 0.7))
				if box.intersects_segment(p, next) != null:
					hit_peer = pl["peer"]
					break
			if hit_peer != 0:
				var knock: Vector3 = v.normalized() * 4.0 + Vector3(0, 3, 0)
				var warded: bool = _wears_ward(hit_peer) and ar["effect"] in ["fire", "ice"]
				var why := "was shot by a %s" % MobData.display_name(ar["mob"])
				if ar["effect"] == "fire":
					why = "was roasted by %s" % MobData.display_name(ar["mob"])
				elif ar["effect"] == "ice":
					why = "was frozen solid by %s" % MobData.display_name(ar["mob"])
				var fireproof: bool = ar["effect"] == "fire" and _fireproof(_states.get(hit_peer, {}))
				var shield := 0.5 if warded or fireproof or _has_special(_states.get(hit_peer, {}), "arrow_ward") else 1.0
				damage_player(hit_peer, ar["damage"] * shield, why, knock)
				if not warded:
					_shot_effect(hit_peer, ar["effect"])
				_end_arrow(id, p, false)
				continue
		# Hit a mob anywhere along this step?
		var hit_mob: Node3D = null
		if ar.has("mob"):
			pass  # (skip mob hits for mob shots)
		var best := INF
		for m in (main.mobs.all_mobs() if not ar.has("mob") else []):
			if m.is_friendly_npc():
				continue
			var hw: float = m.half_width()
			var box := AABB(m.sim_pos - Vector3(hw, 0, hw), Vector3(hw * 2.0, m.height(), hw * 2.0)).grow(0.25)  # a little forgiving
			var hit = box.intersects_segment(p, next)
			if hit != null and p.distance_to(hit) < best:
				best = p.distance_to(hit)
				hit_mob = m
		if hit_mob != null:
			_arrow_hits(ar, hit_mob)
			_end_arrow(id, p + (next - p).normalized() * best, false)
			continue
		# Hit a block? Step through the segment in small pieces.
		var steps := maxi(1, ceili(p.distance_to(next) / 0.4))
		var stuck := false
		for k in range(1, steps + 1):
			var q := p.lerp(next, float(k) / steps)
			if Blocks.is_solid(main.world.get_block(Vector3i(floori(q.x), floori(q.y), floori(q.z)))):
				_end_arrow(id, p.lerp(next, float(k - 1) / steps), true)
				stuck = true
				break
		if not stuck:
			ar["pos"] = next
	# Poison ticks.
	for mid in _poisoned.keys():
		var ps: Dictionary = _poisoned[mid]
		ps["left"] -= delta
		ps["tick"] -= delta
		if main.mobs.get_mob(mid) == null or ps["left"] <= 0.0:
			_poisoned.erase(mid)
		elif ps["tick"] <= 0.0:
			ps["tick"] = 1.0
			main.mobs.damage_mob(mid, POISON_DPS, ps["peer"], _player_pos(ps["peer"]))


func _arrow_hits(ar: Dictionary, m: Node3D) -> void:
	var dmg: float = ar["damage"]
	match ar["effect"]:
		"silver":
			if m.def["kind"] == "hostile":
				dmg *= 1.6
		"poison":
			_poisoned[m.mob_id] = {"left": POISON_SECONDS, "tick": 1.0, "peer": ar["peer"]}
		"frost":
			m.slow_until = now() + FROST_SECONDS
	var hp_before: float = maxf(m.hp, 0.0)
	main.mobs.damage_mob(m.mob_id, dmg, ar["peer"], _player_pos(ar["peer"]))
	if not m.is_friendly_npc():
		_leech(ar["peer"], minf(dmg, hp_before), float(ar.get("leech", 0.0)))


## Wearing Grimskull's chestplate?
func _wears_ward(peer: int) -> bool:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return false
	var chest = st["inventory"][Inv.ARMOR_START + 1]
	return chest != null and Items.get_def(chest["id"]).get("ward", false)


## Burning hurts a little each second; chill slows you down (the client reads "chilled").
const LAVA_HURT := 2.0          # damage each LAVA_EVERY seconds in lava (fireproof: none)
const LAVA_EVERY := 0.5


## Is this player standing in lava? (feet or middle)
func _in_lava(peer: int) -> bool:
	var p := _player_pos(peer)
	for dy in [0.1, 0.9]:
		if Blocks.is_lava(main.world.get_block(Vector3i(floori(p.x), floori(p.y + dy), floori(p.z)))):
			return true
	return false


func _tick_burn_chill(delta: float) -> void:
	for peer in _states:
		var st: Dictionary = _states[peer]
		if st["alive"] and main.world != null and _in_lava(peer) and not _fireproof(st) and not st.get("god", false):
			if st.get("burning", 0.0) < 1.0:
				st["burning"] = 4.0      # (keeps burning a few seconds after you get out)
			st["lava_t"] = float(st.get("lava_t", 0.0)) - delta
			if st["lava_t"] <= 0.0:
				st["lava_t"] = LAVA_EVERY
				damage_player(peer, LAVA_HURT, "fell in lava", Vector3.ZERO, true)
		else:
			st["lava_t"] = 0.0
		if st.get("burning", 0.0) > 0.0 and _fireproof(st):
			st["burning"] = 0.0
		if st.get("burning", 0.0) > 0.0:
			var before: float = st["burning"]
			st["burning"] = maxf(0.0, before - delta)
			if floorf(before) != floorf(st["burning"]) and st["alive"]:
				damage_player(peer, 1.0, "burned up", Vector3.ZERO, true)
		if st.get("chilled", 0.0) > 0.0:
			st["chilled"] = maxf(0.0, st["chilled"] - delta)
			if st["chilled"] == 0.0:
				_sync_self(peer)


## Extra effects when a magic shot hits a player (used by the castle boss).
func _shot_effect(peer: int, effect: String) -> void:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty():
		return
	match effect:
		"fire":
			if not _fireproof(st):
				st["burning"] = 3.0
		"ice":
			st["chilled"] = 3.0
			_sync_self(peer)


## stuck = it landed in a block. Arrows that land can sometimes be picked up again.
func _end_arrow(id: int, at: Vector3, stuck: bool) -> void:
	var ar: Dictionary = _arrows[id]
	_arrows.erase(id)
	_arrow_end.rpc(id, at, stuck)
	if stuck and randf() < 0.5 and not ar.get("no_drop", false) and not ar.has("mob"):
		_spawn_drop(ar["type"], 1, at, Vector3.ZERO, 0.6)


@rpc("authority", "call_local", "reliable")
func _arrow_spawn(id: int, type: String, pos: Vector3, vel: Vector3) -> void:
	if main == null or main.dedicated:
		return
	var node := _arrow_model(type)
	main.add_child(node)
	node.global_position = pos
	_arrow_nodes[id] = {"node": node, "vel": vel, "stuck": false, "age": 0.0, "straight": type in NO_DROP_SHOTS}
	Sound.play_at("swing", pos, -6.0, 1.35)


@rpc("authority", "call_local", "reliable")
func _arrow_end(id: int, at: Vector3, stuck: bool) -> void:
	var a: Dictionary = _arrow_nodes.get(id, {})
	if a.is_empty():
		return
	if stuck:
		a["node"].global_position = at
		a["stuck"] = true
		a["age"] = 0.0
		Sound.play_at("dig_wood", at, -8.0, 1.3)
	else:
		a["node"].queue_free()
		_arrow_nodes.erase(id)


## A little arrow: a wooden shaft, a colored head and white feathers, pointing along -Z.
static func _arrow_model(type: String) -> Node3D:
	var root := Node3D.new()
	if type in TOY_SHOTS:
		# Little toys: a bouncy ball, a rubber duck or a toy block.
		var col: Color = SHOT_COLORS[type]
		var bits: Array = [[Vector3(0.3, 0.3, 0.3), Vector3.ZERO, col]]
		if type == "toy_duck":
			bits = [[Vector3(0.3, 0.22, 0.36), Vector3.ZERO, col], [Vector3(0.18, 0.18, 0.18), Vector3(0, 0.16, -0.12), col],
					[Vector3(0.1, 0.05, 0.1), Vector3(0, 0.14, -0.25), Color(1.0, 0.5, 0.1)]]
		elif type == "toy_block":
			bits = [[Vector3(0.32, 0.32, 0.32), Vector3.ZERO, col], [Vector3(0.12, 0.12, 0.34), Vector3.ZERO, Color(1.0, 0.95, 0.9)]]
		for bit in bits:
			var mi := MeshInstance3D.new()
			var mesh: PrimitiveMesh = SphereMesh.new() if type == "toy_ball" else BoxMesh.new()
			if mesh is SphereMesh:
				(mesh as SphereMesh).radius = 0.17
				(mesh as SphereMesh).height = 0.34
			else:
				(mesh as BoxMesh).size = bit[0]
			var mat := StandardMaterial3D.new()
			mat.albedo_color = bit[2]
			mat.roughness = 0.35
			mesh.material = mat
			mi.mesh = mesh
			mi.position = bit[1]
			root.add_child(mi)
		return root
	if type == "card":
		# A spinning playing card.
		var card := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.3, 0.02, 0.42)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.97, 0.96, 0.92)
		cm.material = cmat
		card.mesh = cm
		root.add_child(card)
		var pip := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.1, 0.03, 0.1)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.85, 0.12, 0.2)
		pm.material = pmat
		pip.mesh = pm
		root.add_child(pip)
		root.set_meta("spin", true)
		return root
	if type in NO_DROP_SHOTS:
		# A glowing ball of fire or ice, with a soft halo.
		var col: Color = SHOT_COLORS.get(type, Color(0.5, 0.9, 1.0))
		for k in 2:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22 if k == 0 else 0.36
			sm.height = sm.radius * 2.0
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = col.lightened(0.4) if k == 0 else Color(col, 0.35)
			if k == 1:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			sm.material = mat
			mi.mesh = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
		return root
	var d := Items.get_def(type)
	var parts := [[Vector3(0.035, 0.035, 0.62), Vector3(0, 0, 0), Color(0.6, 0.44, 0.26)],
			[Vector3(0.07, 0.07, 0.1), Vector3(0, 0, -0.34), d.get("color", Color.GRAY)],
			[Vector3(0.012, 0.09, 0.14), Vector3(0, 0, 0.26), Color(0.95, 0.95, 0.92)],
			[Vector3(0.09, 0.012, 0.14), Vector3(0, 0, 0.26), Color(0.95, 0.95, 0.92)]]
	for part in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part[2]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.material = mat
		mi.mesh = bm
		mi.position = part[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


func _animate_arrows(delta: float) -> void:
	for id in _arrow_nodes.keys():
		var a: Dictionary = _arrow_nodes[id]
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			_arrow_nodes.erase(id)
			continue
		a["age"] += delta
		if a["stuck"]:
			if a["age"] > 5.0:
				node.queue_free()
				_arrow_nodes.erase(id)
			continue
		if a["age"] > ARROW_LIFE + 1.0:
			node.queue_free()
			_arrow_nodes.erase(id)
			continue
		var v: Vector3 = a["vel"]
		if not a.get("straight", false):
			v.y -= ARROW_GRAVITY * delta
		a["vel"] = v
		node.global_position += v * delta
		if v.length() > 0.1:
			node.look_at(node.global_position + v, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)


# --- Dropped items -------------------------------------------------------------------------

## data: the slot's own data (a map's id...), kept until it's picked up again.
func _spawn_drop(id: String, count: int, pos: Vector3, vel: Vector3, delay: float, data := {}) -> int:
	var did := _next_drop
	_next_drop += 1
	_drops[did] = {"id": id, "count": count, "pos": pos, "vel": vel, "age": 0.0, "delay": delay, "resting": false, "data": data}
	_drop_spawn.rpc(did, id, pos)
	return did


func _remove_drop(did: int) -> void:
	_drops.erase(did)
	_drop_despawn.rpc(did)


func _tick_drops(delta: float) -> void:
	var world: Node = main.world
	var players := player_list()
	var moved := {}
	for did in _drops.keys():
		var d: Dictionary = _drops[did]
		d["age"] += delta
		d["delay"] -= delta
		if d["age"] > DROP_SECONDS or d["pos"].y < main.world.floor_y() - 10.0:
			_remove_drop(did)
			continue
		if not d["resting"] and world.is_data_loaded(d["pos"]):
			var v: Vector3 = d["vel"]
			v.y -= 20.0 * delta
			var p: Vector3 = d["pos"]
			var next := p + v * delta
			if Blocks.is_solid(world.get_block(Vector3i(floori(next.x), floori(p.y), floori(next.z)))):
				v.x = 0.0
				v.z = 0.0
				next.x = p.x
				next.z = p.z
			var below: int = world.get_block(Vector3i(floori(next.x), floori(next.y), floori(next.z)))
			if v.y < 0.0 and Blocks.is_solid(below):
				next.y = floorf(next.y) + Blocks.COLLIDE[below]
				v = Vector3(v.x * 0.5, 0, v.z * 0.5)
				if v.length() < 0.3:
					d["resting"] = true
					_merge_drop(did)
			d["vel"] = v
			d["pos"] = next
			moved[did] = next
		elif d["resting"] and not Blocks.is_solid(world.get_block(Vector3i(floori(d["pos"].x), floori(d["pos"].y - 0.05), floori(d["pos"].z)))):
			d["resting"] = false  # the block under it was broken
		if not _drops.has(did) or d["delay"] > 0.0:
			continue
		for pl in players:
			if not pl["alive"]:
				continue
			var off: Vector3 = d["pos"] - pl["pos"]
			if Vector2(off.x, off.z).length() < 1.4 and off.y > -0.6 and off.y < 2.0:
				var st: Dictionary = _states[pl["peer"]]
				var left := Inv.add(st["inventory"], d["id"], d["count"], Inv.PLAYER_SLOTS, d.get("data", {}))
				if left < d["count"]:
					_pickup_fx.rpc(did, pl["peer"])
					_sync_self(pl["peer"])
				if left == 0:
					_drops.erase(did)
					break
				d["count"] = left
	_drop_sync -= delta
	if _drop_sync <= 0.0 and not moved.is_empty():
		_drop_sync = 0.1
		for did in moved:
			if _drops.has(did):
				_drop_move.rpc(did, moved[did])


## A drop that lands next to another of the same item joins it.
func _merge_drop(did: int) -> void:
	var d: Dictionary = _drops[did]
	if not d.get("data", {}).is_empty():
		return  # one-of-a-kind items stay on their own
	for other in _drops:
		if other == did:
			continue
		var o: Dictionary = _drops[other]
		if o["resting"] and o["id"] == d["id"] and o.get("data", {}).is_empty() and o["pos"].distance_to(d["pos"]) < 1.2 \
				and o["count"] + d["count"] <= Items.max_stack(d["id"]):
			o["count"] += d["count"]
			_remove_drop(did)
			return


# --- Requests: combat ---------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func req_attack(mob_id: int, slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var t := now()
	if t - _attack_times.get(peer, -10.0) < ATTACK_COOLDOWN / (1.0 + _buff_power(st, "haste")):
		return
	var mob: Node3D = main.mobs.get_mob(mob_id)
	if mob == null:
		return
	var pos := _player_pos(peer)
	if pos.distance_to(mob.sim_pos) > ATTACK_REACH + mob.half_width():
		return
	_attack_times[peer] = t
	if mob.is_npc():
		_npc_giggle.rpc(mob.mob_id)
		_tell(peer, "QtMaMe giggles: \"Hehe, that tickles!\"")
		return
	if mob.is_fairy():
		return
	var d := Items.get_def(_held(st, slot).get("id", ""))
	var might := 0.0
	var chest = st["inventory"][Inv.ARMOR_START + 1]
	if chest != null:
		might = float(Items.get_def(chest["id"]).get("might", 0.0))
	var dmg: float = d.get("damage", 1.0) * (1.0 + _buff_power(st, "strength") + might)
	var hp_before: float = maxf(mob.hp, 0.0)
	match d.get("sword_power", ""):
		"checkmate":
			# Nearly beaten? One hit finishes it (bosses just take more).
			if mob.hp <= mob.max_hp * 0.3:
				dmg = dmg * 1.5 if mob.is_boss() else maxf(dmg, mob.hp + 1.0)
		"bonk":
			if not mob.is_boss():
				var away: Vector3 = mob.sim_pos - pos
				away.y = 0
				mob.velocity += away.normalized() * 14.0 if away.length() > 0.01 else Vector3.ZERO
				mob.velocity.y = 9.0
		"stalemate":
			var stun := 0.4 if mob.is_boss() else 1.2
			mob.stun_until = now() + stun
			mob._attack_timer = maxf(mob._attack_timer, stun)
	dmg *= quality(_held(st, slot))
	var reaping: bool = d.get("sword_power", "") == "harvest" and not mob.is_boss()
	_reaping[peer] = reaping
	var killed: bool = main.mobs.damage_mob(mob_id, dmg, peer, pos)
	_reaping.erase(peer)
	if killed and reaping and st["alive"]:
		st["health"] = minf(MAX_HEALTH, st["health"] + 2.0)
		_sync_self(peer)
	_leech(peer, minf(dmg, hp_before), weapon_leech(_held(st, slot)))


## Right-click a fairy to make friends (one fairy per character).
@rpc("any_peer", "call_local", "reliable")
func req_befriend_fairy(mob_id: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var mob: Node3D = main.mobs.get_mob(mob_id)
	if mob == null or not mob.is_fairy() or _player_pos(peer).distance_to(mob.sim_pos) > REACH:
		return
	var text: String = main.mobs.befriend_fairy(mob_id, st["key"])
	if text != "":
		_tell(peer, text)
	_sync_self(peer)


## Server: a mob bit someone (called from mobs.gd).
func on_mob_attack(peer: int, damage: float, mob: Node3D) -> void:
	var away: Vector3 = _player_pos(peer) - mob.sim_pos
	away.y = 0
	var slam := float(mob.def.get("slam", 0.0))
	var push := 12.0 if slam > 0.0 else 7.0
	var knock := away.normalized() * push + Vector3(0, 5, 0) if away.length() > 0.01 else Vector3(0, 5, 0)
	damage_player(peer, damage, "was defeated by the %s" % MobData.display_name(mob.type), knock)
	if slam > 0.0:
		# A big hammer: everyone else close by gets bonked too (a bit less).
		for other in _states:
			if other == peer or not _states[other]["alive"]:
				continue
			var off: Vector3 = _player_pos(other) - mob.sim_pos
			if off.length() < slam:
				off.y = 0
				var k := off.normalized() * 10.0 + Vector3(0, 6, 0) if off.length() > 0.01 else Vector3(0, 6, 0)
				damage_player(other, damage * 0.6, "was bonked by %s" % MobData.display_name(mob.type), k)
				if mob.def.get("slam_fire", false):
					_shot_effect(other, "fire")
		if mob.def.get("slam_fire", false):
			_shot_effect(peer, "fire")   # a fiery stomp sets you burning
		_hammer_slam.rpc(mob.sim_pos)


@rpc("authority", "call_local", "unreliable")
func _hammer_slam(at: Vector3) -> void:
	if main == null or main.dedicated:
		return
	Sound.play_at("hit", at, 4.0, 0.55)


@rpc("any_peer", "call_local", "reliable")
func req_fall_damage(amount: float) -> void:
	if _actor().is_empty():
		return
	var st := _actor()
	if _has_special(st, "no_fall"):
		return   # Pounce: you land like a cat
	var legs = st["inventory"][Inv.ARMOR_START + 2]
	if legs != null and Items.get_def(legs["id"]).get("no_fall", false):
		return   # bouncy gummy leggings
	damage_player(_sender(), clampf(amount, 0.0, 40.0), "fell from a high place", Vector3.ZERO)


func damage_player(peer: int, amount: float, cause: String, knockback: Vector3, ignore_armor := false) -> void:
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty() or not st["alive"] or amount <= 0.0:
		return
	if st.get("god", false) and cause != "gave up":
		return   # /god: nothing hurts
	_wake(peer)
	var protection := 0.0 if ignore_armor else protection_of(st["inventory"])
	amount *= 1.0 - _buff_power(st, "toughness")
	st["health"] -= amount * (1.0 - protection)
	st["hurt_time"] = now()
	st["regen"] = 0.0
	if st["health"] <= 0.0:
		_kill(peer, cause)
		return
	_sync_self(peer)
	_receive_hurt.rpc_id(peer, knockback)


func _kill(peer: int, cause: String) -> void:
	var st: Dictionary = _states[peer]
	st["alive"] = false
	st["health"] = 0.0
	st["sleeping"] = false
	_cancel_trades_of(peer)
	# Everything you carried goes into a loot bag where you fell. Anyone can loot it.
	var inv: Array = st["inventory"]
	if not Inv.is_empty(inv):
		_create_loot("bag", "", _player_pos(peer) + Vector3(0, 0.1, 0), 0.0, inv.duplicate(true), st["name"], "")
	st["inventory"] = Inv.make(Inv.PLAYER_SIZE)
	_viewers.erase(peer)
	_sync_self(peer)
	_you_died.rpc_id(peer, cause)
	_set_player_alive.rpc(peer, false)
	main._receive_event.rpc("%s %s" % [st["name"], cause], "bone")


@rpc("any_peer", "call_local", "reliable")
func req_respawn() -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var st: Dictionary = _states.get(peer, {})
	if st.is_empty() or st["alive"]:
		return
	st["alive"] = true
	st["health"] = MAX_HEALTH
	var pos: Vector3 = main.world.find_spawn_point()
	var bed: Vector3i = st["bed"]
	if bed.y >= 0:
		if main.world.get_edited_block(bed) == Blocks.BED:
			pos = Vector3(bed) + Vector3(0.5, 0.6, 0.5)
		else:
			_tell(peer, "Your bed is gone, so you woke up at the world spawn.")
			st["bed"] = NO_POS
	_sync_self(peer)
	_you_respawned.rpc_id(peer, pos)
	_set_player_alive.rpc(peer, true)


# --- Requests: crafting, the shop and QtMaMe ------------------------------------------------

func _station_ok(peer: int, pos: Vector3i, tier: int) -> bool:
	if tier <= 0:
		return true
	var b: int = main.world.get_block(pos)
	return Blocks.WORKBENCH_TIER.get(b, 0) >= tier \
			and _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) <= STATION_REACH


# --- Research ---------------------------------------------------------------------------
# Everything you've ever carried counts as "seen". Once you've seen all of a
# recipe's ingredients, it's discovered: it shows at the Research Table, where
# you learn it with toots (as long as a workbench of its tier is within
# RESEARCH_RANGE of the table). Learned recipes show up at their workbench.

const RESEARCH_RANGE := 16


## Remembers new items someone is carrying, and tells them about recipes
## they've just discovered.
func _note_seen(peer: int, st: Dictionary) -> void:
	var seen: Dictionary = st["seen"]
	var grew := false
	for s in st["inventory"]:
		if s != null and not seen.has(s["id"]):
			seen[s["id"]] = true
			grew = true
	if not grew:
		return
	var fresh := []
	for r in Recipes.RECIPES:
		if Recipes.needs_research(r) and not st["known"].has(r["out"]) and Recipes.discovered(r, seen):
			st["known"][r["out"]] = true
			fresh.append(r["out"])
	if not fresh.is_empty() and peer in _reachable_peers():
		_receive_discoveries.rpc_id(peer, fresh)


func _reachable_peers() -> Array:
	var out: Array = multiplayer.get_peers()
	out.append(multiplayer.get_unique_id())
	return out


signal recipes_discovered(ids: Array)

@rpc("authority", "call_local", "reliable")
func _receive_discoveries(ids: Array) -> void:
	recipes_discovered.emit(ids)


## The best workbench tier within RESEARCH_RANGE of a spot (0 = none).
## Works the same on every computer (only looks at blocks).
func nearby_bench_tier(at: Vector3i) -> int:
	var best := 0
	var w: Node = main.world
	var r := RESEARCH_RANGE
	for dy in range(-4, 5):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t: int = Blocks.WORKBENCH_TIER.get(w.get_block(at + Vector3i(dx, dy, dz)), 0)
				if t > best:
					best = t
					if best >= 3:
						return best
	return best


@rpc("any_peer", "call_local", "reliable")
func req_unlock(recipe_id: String, bench: Vector3i) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var r := Recipes.get_recipe(recipe_id)
	if r.is_empty() or not Recipes.needs_research(r) or st["unlocked"].has(recipe_id):
		return
	if main.world.get_block(bench) != Blocks.RESEARCH_TABLE or _player_pos(peer).distance_to(Vector3(bench) + Vector3(0.5, 0.5, 0.5)) > STATION_REACH:
		_tell(peer, "Learn new recipes at a Research Table.")
		return
	if not st["known"].has(recipe_id) and not Recipes.discovered(r, st["seen"]):
		_tell(peer, "You haven't found what that's made from yet.")
		return
	if nearby_bench_tier(bench) < int(r["station"]):
		_tell(peer, "Build a Workbench Tier %d near this Research Table to learn that." % r["station"])
		return
	if st["toots"] < r["cost"]:
		_tell(peer, "You need %s to unlock that." % Recipes.format_toots(r["cost"]))
		return
	st["toots"] -= r["cost"]
	st["unlocked"][recipe_id] = true
	st["known"][recipe_id] = true
	_sync_self(peer)
	_tell(peer, "Learned %s! Make it at a Workbench Tier %d." % [Items.display_name(recipe_id), r["station"]])


@rpc("any_peer", "call_local", "reliable")
func req_craft(recipe_id: String, bench: Vector3i, times: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var r := Recipes.get_recipe(recipe_id)
	if r.is_empty():
		return
	if r.has("bench"):
		var bb: int = main.world.get_block(bench)
		if Blocks.BUILD_BENCH.get(bb, "") != r["bench"] or _player_pos(peer).distance_to(Vector3(bench) + Vector3(0.5, 0.5, 0.5)) > STATION_REACH:
			_tell(peer, "You need to be at a %s." % {"jewelry": "Jewelry Station"}.get(r["bench"], r["bench"].capitalize()))
			return
	elif r["station"] > 0:
		if not st["unlocked"].has(recipe_id) and not r.get("auto", false):
			_tell(peer, "Learn that recipe at a Research Table first.")
			return
		if not _station_ok(peer, bench, r["station"]):
			_tell(peer, "You need to be at a Workbench Tier %d." % r["station"])
			return
	if r["out"] == "party_map" and party_of_key(st["key"]) == 0:
		_tell(peer, "You need to be in a party to make a Party Map. Press P to invite a friend!")
		return
	var made := 0
	for i in clampi(times, 1, 64):
		var inv: Array = st["inventory"].duplicate(true)
		var ok := true
		for input in r["in"]:
			if Recipes.take(inv, r, input, r["in"][input], Inv.PLAYER_SLOTS) < r["in"][input]:
				ok = false
				break
		if not ok:
			if made == 0:
				_tell(peer, "You're missing materials: %s." % Recipes.describe_inputs(r))
			break
		var data := _make_item_data(r["out"], st)
		if Inv.add(inv, r["out"], r["count"], Inv.PLAYER_SLOTS, data) > 0:
			if data.has("map") and not data.has("party"):
				_maps.erase(data["map"])  # it didn't fit, so it was never made (a party's own map stays)
			_tell(peer, "Your inventory is full.")
			break
		st["inventory"] = inv
		made += 1
	if made > 0:
		_sync_self(peer)


func _sell(peer: int, st: Dictionary, item_id: String, count: int, bonus: float) -> void:
	var value := Recipes.value(item_id) * bonus
	if value <= 0.0:
		_tell(peer, "Nobody wants to buy that.")
		return
	var sold := Inv.remove(st["inventory"], item_id, maxi(count, 0), Inv.PLAYER_SLOTS)
	if sold <= 0:
		return
	st["toots"] += value * sold
	_sync_self(peer)
	_tell(peer, "Sold %d %s for %s!" % [sold, Items.display_name(item_id), Recipes.format_toots(value * sold)])


@rpc("any_peer", "call_local", "reliable")
func req_sell(item_id: String, count: int, shop: Vector3i) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if main.world.get_block(shop) != Blocks.SHOP \
			or _player_pos(peer).distance_to(Vector3(shop) + Vector3(0.5, 0.5, 0.5)) > STATION_REACH:
		_tell(peer, "You need to be at a Block Shop.")
		return
	_sell(peer, st, item_id, count, 1.0)


func _near_npc(peer: int) -> bool:
	var npc: Node3D = main.mobs.get_npc()
	return npc != null and _player_pos(peer).distance_to(npc.sim_pos) <= STATION_REACH + 1.0


## Talking to QtMaMe makes you her friend: she'll move near your favorite bed.
@rpc("any_peer", "call_local", "reliable")
func req_meet_npc() -> void:
	var st := _actor()
	if st.is_empty() or not _near_npc(_sender()):
		return
	main.mobs.npc_set_friend(st["key"])


@rpc("any_peer", "call_local", "reliable")
func req_sell_trader(item_id: String, count: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if not _near_npc(peer):
		_tell(peer, "QtMaMe is too far away.")
		return
	_sell(peer, st, item_id, count, TRADER_BONUS)


# --- Requests: containers -------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func req_open(kind: String, key: Variant) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var pos := _player_pos(peer)
	if (kind == "furnace" or kind == "chest") and key is Vector3i:
		var want := Blocks.FURNACE if kind == "furnace" else Blocks.CHEST
		var got: int = main.world.get_block(key)
		if (got != want and not (kind == "chest" and got in [Blocks.SHRINE_CHEST, Blocks.SUPER_CHEST])) or pos.distance_to(Vector3(key)) > REACH:
			return
		if got == Blocks.SUPER_CHEST:
			kind = "super"   # (your own box: everyone can open theirs at once)
		elif kind == "chest":
			# One person in a chest at a time (so nobody's items move under their mouse).
			for other in _viewers:
				if other != peer and _viewers[other]["kind"] == "chest" and _viewers[other]["key"] == key:
					_tell(peer, "%s is using this chest right now." % _states.get(other, {}).get("name", "Someone"))
					_receive_container_closed.rpc_id(peer)
					return
		if kind == "furnace" and not _furnaces.has(key):
			_furnaces[key] = {"slots": Inv.make(4), "burn": 0.0, "burn_max": 0.0, "progress": 0.0}
		if kind == "furnace" and _furnaces[key]["slots"].size() < 4:
			_furnaces[key]["slots"].resize(4)   # older furnaces get the coal slot
		if kind == "chest" and not _chests.has(key) and got != Blocks.SUPER_CHEST:
			_chests[key] = Inv.make(CHEST_SIZE)
			if main.world.get_edited_block(key) < 0:
				if main.world.get_block(key) == Blocks.SHRINE_CHEST:
					_fill_shrine_chest(_chests[key], key)   # a treasure map!
				elif main.world.is_dungeon_chest(key):
					_fill_dungeon_chest(_chests[key], key)
				else:
					_fill_ruin_chest(_chests[key], key)   # an old chest in a ruin: something's inside!
	elif kind == "stand" and key is Vector3i:
		if main.world.get_block(key) != Blocks.ARMOR_STAND or pos.distance_to(Vector3(key)) > REACH:
			return
		if not _stands.has(key):
			_stands[key] = Inv.make(5)
	elif kind == "loot" and key is int:
		if not _loot.has(key) or pos.distance_to(_loot[key]["pos"]) > REACH:
			return
		var locked: String = _loot[key]["locked"]
		if locked != "" and locked != st["key"] and locked != st["name"]:
			_tell(peer, "This treasure belongs to %s!" % locked)
			_receive_container_closed.rpc_id(peer)
			return
	else:
		return
	_close_mine(peer)
	_viewers[peer] = {"kind": kind, "key": key}
	_send_container(peer)


# --- Cave shrines and treasure maps ---------------------------------------------------

const DUNGEON_LOOT := [["iron_ingot", 2, 5], ["gold_ingot", 1, 3], ["silver_ingot", 1, 3], ["titanium_ingot", 0, 2],
		["cutieite_ingot", 0, 2], ["ancient_coin", 2, 6], ["bronze_arrow", 4, 10], ["bone", 1, 4], ["paper", 1, 3]]
const TREASURE_TEXT := {"dungeon": "a hidden dungeon", "grotto": "a cave full of ore", "village": "a fairy village",
		"castle": "the floating castle", "yeti": "the Yeti's mine"}


## Where a shrine's map points: {"kind", "pos"} (pos.y = -1 if nothing was found).
## Like Valheim's runestones, a shrine shows the way to the nearest boss
## nobody has beaten yet. (If there's none near, it's a dungeon or grotto.)
func _pick_treasure(pos: Vector3i, rng: RandomNumberGenerator) -> Dictionary:
	var w: Node = main.world
	var from := Vector2(pos.x, pos.z)
	var best := {}
	var best_d := 2500.0
	for l in w.lairs_near(Vector3(pos), 2500.0):
		if _trophies.has(l["boss"]) or (l["boss"] == "king_cougar" and w.gen_version < 8):
			continue
		var d := Vector2(l["pos"].x, l["pos"].z).distance_to(from)
		if d < best_d:
			best_d = d
			best = {"kind": l["boss"], "pos": Vector3(l["pos"].x, l["ground"] + 1, l["pos"].z)}
	for extra in [["yeti", w.find_structure("mineshaft", from, 2500.0)], ["grimskull", w.find_castle(from, 2500.0)]]:
		var at: Vector3 = extra[1]
		if at.y >= 0 and not _trophies.has(extra[0]) and Vector2(at.x, at.z).distance_to(from) < best_d:
			best_d = Vector2(at.x, at.z).distance_to(from)
			best = {"kind": extra[0], "pos": at}
	if not best.is_empty():
		return best
	var roll := rng.randi() % 100
	var want: String = "dungeon" if roll < 38 else ("grotto" if roll < 70 else ["village", "castle", "yeti"][roll % 3])
	var at := Vector3(0, -1, 0)
	match want:
		"village":
			at = w.find_structure("village", from, 900.0)
		"castle":
			at = w.find_castle(from, 1200.0)
		"yeti":
			at = w.find_structure("mineshaft", from, 900.0)
	if at.y < 0:
		if want != "grotto":
			want = "dungeon" if want == "dungeon" or rng.randi() % 2 == 0 else "grotto"
		var s: Dictionary = w.find_site(want, from, 2500.0)
		if s.is_empty():
			s = w.find_site("", from, 4000.0)
		if not s.is_empty():
			at = Vector3(s["entrance"])
			want = s["kind"]
	return {"kind": want, "pos": at}


## A shrine's Stone Chest: an old explorer's treasure map, and a few odds and ends.
func _fill_shrine_chest(slots: Array, pos: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos) ^ main.world.world_seed ^ 0x5157
	var t := _pick_treasure(pos, rng)
	var mid := _new_map("an old explorer")
	var m: Dictionary = _maps[mid]
	var target: Vector3 = t["pos"]
	if target.y >= 0:
		# The map already shows the land around the X (and around the shrine).
		for off in [Vector3.ZERO, Vector3(60, 0, 0), Vector3(-60, 0, 0), Vector3(0, 0, 60), Vector3(0, 0, -60)]:
			_reveal(mid, target + off)
		m["marks"].append({"x": target.x, "z": target.z, "kind": "boss" if not BossData.get_boss(t["kind"]).is_empty() else "treasure", "fixed": true})
		m["treasure"] = t["kind"]
	_reveal(mid, Vector3(pos))
	m.erase("last")
	var data := {"map": mid, "maker": "an old explorer", "label": "Treasure Map", "label_ink": "red_ink"}
	if target.y >= 0:
		data["treasure"] = t["kind"]
	Inv.add(slots, "map", 1, slots.size(), data)
	Inv.add(slots, "torch", rng.randi_range(2, 5))
	Inv.add(slots, "ancient_coin", rng.randi_range(1, 3))
	if rng.randi() % 2 == 0:
		Inv.add(slots, "bone", rng.randi_range(1, 2))


## The chest at the back of a dungeon: better than a ruin's.
func _fill_dungeon_chest(slots: Array, pos: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos) ^ main.world.world_seed ^ 0xD00D
	var order := range(DUNGEON_LOOT.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for k in 4 + rng.randi() % 3:
		var e: Array = DUNGEON_LOOT[order[k]]
		var n := rng.randi_range(e[1], e[2])
		if n > 0 and Items.exists(e[0]):
			Inv.add(slots, e[0], n)


## Treasure in the chests of the floating ruins (the same for everyone, by where it is).
const RUIN_LOOT := [["ancient_coin", 1, 4], ["bone", 1, 4], ["iron_ingot", 1, 3], ["silver_ingot", 0, 2],
		["gold_ingot", 0, 1], ["bronze_arrow", 2, 8], ["titanium_ore", 0, 1], ["cutieite_ingot", 0, 1], ["paper", 1, 4]]


func _fill_ruin_chest(slots: Array, pos: Vector3i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(pos) ^ main.world.world_seed
	var kinds := 3 + rng.randi() % 3
	var order := range(RUIN_LOOT.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for k in kinds:
		var e: Array = RUIN_LOOT[order[k]]
		var n := rng.randi_range(e[1], e[2])
		if n > 0:
			Inv.add(slots, e[0], n)


@rpc("any_peer", "call_local", "reliable")
func req_close() -> void:
	if multiplayer.is_server():
		_close_mine(_sender())


func _close_mine(peer: int) -> void:
	var v: Dictionary = _viewers.get(peer, {})
	if v.get("kind", "") == "trade":
		_cancel_trade(v["key"], "%s closed the trade." % _states.get(peer, {}).get("name", "Someone"))
	_viewers.erase(peer)


func _after_container_change(v: Dictionary) -> void:
	if v["kind"] == "loot" and _loot.has(v["key"]) and Inv.is_empty(_loot[v["key"]]["slots"]):
		_remove_loot(v["key"])  # emptied: it disappears
		return
	for peer in _viewers:
		if _viewers[peer]["kind"] == v["kind"] and _viewers[peer]["key"] == v["key"]:
			_send_container(peer)
	if v["kind"] == "stand":
		_send_stand(v["key"])


func _send_container(peer: int) -> void:
	var v: Dictionary = _viewers.get(peer, {})
	if v.is_empty():
		return
	var extra := {}
	match v["kind"]:
		"furnace":
			var f: Dictionary = _furnaces.get(v["key"], {})
			if f.is_empty():
				return
			extra = {"progress": f["progress"] / Recipes.SMELT_SECONDS,
					"fuel": f["burn"] / f["burn_max"] if f["burn_max"] > 0.0 else 0.0}
		"chest":
			extra = {"title": _chest_names.get(v["key"], "Stone Chest" if main.world.get_block(v["key"]) == Blocks.SHRINE_CHEST else "Chest"),
					"named": _chest_names.has(v["key"])}
		"super":
			extra = {"title": "Super Chest", "super": true}
		"stand":
			extra = {"title": "Armor Stand"}
		"loot":
			var l: Dictionary = _loot.get(v["key"], {})
			if l.is_empty():
				return
			var title := "%s corpse" % MobData.display_name(l["mob"])
			if l["kind"] == "bag":
				title = "%s's bag" % l["owner"]
			elif l["kind"] == "treasure":
				title = "%s's treasure" % l["owner"]
			extra = {"title": title}
		"trade":
			var t: Dictionary = _trades.get(v["key"], {})
			if t.is_empty():
				return
			var other: int = t["b"] if t["a"] == peer else t["a"]
			extra = {"title": "Trading with %s" % _states.get(other, {}).get("name", "?"),
					"their": t["offer"][other], "my_toots": t["toots"][peer], "their_toots": t["toots"][other],
					"my_ready": t["ready"][peer], "their_ready": t["ready"][other],
					"partner": _states.get(other, {}).get("name", "?")}
	_receive_container.rpc_id(peer, v["kind"], v["key"], _area(peer, "open"), extra)


func _close_viewers(kind: String, key) -> void:
	for peer in _viewers.keys():
		if _viewers[peer]["kind"] == kind and _viewers[peer]["key"] == key:
			_viewers.erase(peer)
			_receive_container_closed.rpc_id(peer)


# --- Trading -------------------------------------------------------------------------

## Ask another player to trade. If they already asked you, the trade starts.
@rpc("any_peer", "call_local", "reliable")
func req_trade_request(target: int) -> void:
	var st := _actor()
	var me_peer := _sender()
	var other: Dictionary = _states.get(target, {})
	if st.is_empty() or other.is_empty() or not other["alive"] or target == me_peer:
		return
	if _player_pos(me_peer).distance_to(_player_pos(target)) > 8.0:
		_tell(me_peer, "Get closer to %s to trade." % other["name"])
		return
	if _in_trade(me_peer) or _in_trade(target):
		_tell(me_peer, "%s is busy trading." % other["name"])
		return
	var mine: Dictionary = _invites.get(me_peer, {})
	if mine.get("from", 0) == target and now() - mine["time"] < 30.0:
		_invites.erase(me_peer)
		_start_trade(target, me_peer)
		return
	_invites[target] = {"from": me_peer, "time": now()}
	_trade_invite.rpc_id(target, me_peer, st["name"])
	_tell(me_peer, "You asked %s to trade. Waiting for an answer..." % other["name"])


@rpc("any_peer", "call_local", "reliable")
func req_trade_answer(from_peer: int, yes: bool) -> void:
	if not multiplayer.is_server():
		return
	var me_peer := _sender()
	var inv: Dictionary = _invites.get(me_peer, {})
	if inv.get("from", 0) != from_peer:
		return
	_invites.erase(me_peer)
	if not yes:
		_tell(from_peer, "%s said no thanks." % _states.get(me_peer, {}).get("name", "They"))
		return
	if now() - inv["time"] > 30.0 or not _states.has(from_peer) or _in_trade(from_peer) or _in_trade(me_peer):
		_tell(me_peer, "That trade isn't available any more.")
		return
	_start_trade(from_peer, me_peer)


func _in_trade(peer: int) -> bool:
	return _viewers.get(peer, {}).get("kind", "") == "trade"


func _start_trade(a: int, b: int) -> void:
	var id := _next_trade
	_next_trade += 1
	_trades[id] = {"a": a, "b": b, "offer": {a: Inv.make(TRADE_SIZE), b: Inv.make(TRADE_SIZE)},
			"toots": {a: 0.0, b: 0.0}, "ready": {a: false, b: false}}
	for p in [a, b]:
		_viewers.erase(p)
		_viewers[p] = {"kind": "trade", "key": id}
		_send_container(p)


func _trade_changed(id: int) -> void:
	var t: Dictionary = _trades[id]
	t["ready"][t["a"]] = false  # any change means both have to say "ready" again
	t["ready"][t["b"]] = false
	_send_container(t["a"])
	_send_container(t["b"])


@rpc("any_peer", "call_local", "reliable")
func req_trade_toots(amount: float) -> void:
	var st := _actor()
	var peer := _sender()
	var v: Dictionary = _viewers.get(peer, {})
	if st.is_empty() or v.get("kind", "") != "trade" or not _trades.has(v["key"]):
		return
	_trades[v["key"]]["toots"][peer] = clampf(floorf(amount), 0.0, floorf(st["toots"]))
	_trade_changed(v["key"])


@rpc("any_peer", "call_local", "reliable")
func req_trade_ready(ready: bool) -> void:
	var st := _actor()
	var peer := _sender()
	var v: Dictionary = _viewers.get(peer, {})
	if st.is_empty() or v.get("kind", "") != "trade" or not _trades.has(v["key"]):
		return
	var id: int = v["key"]
	var t: Dictionary = _trades[id]
	t["ready"][peer] = ready
	if t["ready"][t["a"]] and t["ready"][t["b"]]:
		_finish_trade(id)
	else:
		_send_container(t["a"])
		_send_container(t["b"])


func _finish_trade(id: int) -> void:
	var t: Dictionary = _trades[id]
	var a: int = t["a"]
	var b: int = t["b"]
	var sa: Dictionary = _states[a]
	var sb: Dictionary = _states[b]
	if sa["toots"] < t["toots"][a] or sb["toots"] < t["toots"][b]:
		_trade_changed(id)
		_tell(a, "Someone doesn't have enough toots for that.")
		_tell(b, "Someone doesn't have enough toots for that.")
		return
	var inv_a: Array = sa["inventory"].duplicate(true)
	var inv_b: Array = sb["inventory"].duplicate(true)
	for s in t["offer"][b]:
		if s != null and Inv.add_slot(inv_a, s, Inv.PLAYER_SLOTS) > 0:
			_trade_changed(id)
			_tell(a, "You don't have room for everything!")
			_tell(b, "%s doesn't have room for everything." % sa["name"])
			return
	for s in t["offer"][a]:
		if s != null and Inv.add_slot(inv_b, s, Inv.PLAYER_SLOTS) > 0:
			_trade_changed(id)
			_tell(b, "You don't have room for everything!")
			_tell(a, "%s doesn't have room for everything." % sb["name"])
			return
	sa["inventory"] = inv_a
	sb["inventory"] = inv_b
	sa["toots"] += t["toots"][b] - t["toots"][a]
	sb["toots"] += t["toots"][a] - t["toots"][b]
	_trades.erase(id)
	for p in [a, b]:
		_viewers.erase(p)
		_receive_container_closed.rpc_id(p)
		_sync_self(p)
		_tell(p, "Trade done! Have fun with your new stuff.")


## Gives everything in the trade back and closes it for both players.
func _cancel_trade(id: int, why: String) -> void:
	if not _trades.has(id):
		return
	var t: Dictionary = _trades[id]
	_trades.erase(id)
	for p in [t["a"], t["b"]]:
		for s in t["offer"][p]:
			if s != null:
				_give_or_drop(p, s["id"], s["count"], Inv.extra(s))
		if _viewers.get(p, {}).get("key", -1) == id:
			_viewers.erase(p)
		if _states.has(p):
			_receive_container_closed.rpc_id(p)
			_sync_self(p)
			_tell(p, why)


func _cancel_trades_of(peer: int) -> void:
	for id in _trades.keys():
		if _trades[id]["a"] == peer or _trades[id]["b"] == peer:
			_cancel_trade(id, "The trade was cancelled.")


func _tick_trades() -> void:
	for id in _trades.keys():
		var t: Dictionary = _trades[id]
		var a: int = t["a"]
		var b: int = t["b"]
		if not _states.has(a) or not _states.has(b) or _player_pos(a).distance_to(_player_pos(b)) > 16.0:
			_cancel_trade(id, "You walked too far apart, so the trade was cancelled.")


# --- Maps ----------------------------------------------------------------------------------
# Like Valheim: a map starts blank and fills in around you wherever you walk
# while it's in your pockets (hotbar or backpack). Each map is its own thing:
# its slot carries {"map": id, "maker": name}, and the server remembers what
# that map has seen. Trade it, drop it, or put it in a chest, and whoever has
# it next keeps adding to the same map.

const MAP_SCALE := 4            # blocks per map pixel
const MAP_REGION := 32          # map pixels per side of one stored piece (128 x 128 blocks)
const MAP_REVEAL := 44.0        # how far around you a map fills in (blocks)
const MAP_MARKS := ["house", "boss", "alert", "question", "portal"]
const MAP_MAX_MARKS := 80


func _new_map(maker: String) -> int:
	var id := _next_map
	_next_map += 1
	_maps[id] = {"maker": maker, "regions": {}, "marks": []}
	return id


## The data a freshly made item carries (only maps have any).
func _make_item_data(id: String, st: Dictionary) -> Dictionary:
	if id == "map":
		return {"map": _new_map(st["name"]), "maker": st["name"]}
	if id == "party_map":
		# Every party has one shared map: a new party map is a copy of it.
		var pid := party_of_key(st["key"])
		if pid == 0:
			return {"map": _new_map(st["name"]), "maker": st["name"]}
		var p: Dictionary = _parties[pid]
		if not _maps.has(int(p.get("map", -1))):
			p["map"] = _new_map(p["name"])
		return {"map": int(p["map"]), "maker": p["name"], "party": pid, "party_name": p["name"]}
	if Items.get_def(id).has("cape"):
		return {"roll": snappedf(randf_range(0.7, 1.0), 0.01), "maker": st["name"]}
	if Items.get_def(id).has("jewel"):
		var j := roll_jewel(id)
		j["maker"] = st["name"]
		return j
	return {}


# --- Gem jewelry ---------------------------------------------------------------------
# Every ring and amulet made at the Jewelry Station rolls how well its gem came
# out (30-100%), like a fairy's glow: Faint, Glowing, Bright or Radiant. Its
# gem's power scales with the roll, and some pieces get a second, smaller
# bonus power too (a Radiant one sometimes gets fireproof or warmth!).

const JEWEL_ROLL := Vector2(0.3, 1.0)
const BONUS_CHANCE := 0.35
const BONUS_SHARE := 0.3
const BONUS_BUFFS := ["haste", "speed", "regen", "fortune", "toughness", "jump", "leech"]


static func roll_jewel(id: String) -> Dictionary:
	var d := Items.get_def(id)
	var main_buff: String = d["jewel"]
	var roll := snappedf(randf_range(JEWEL_ROLL.x, JEWEL_ROLL.y), 0.01)
	if randf() < 0.06:
		roll = 1.0
	var buffs := {main_buff: snappedf(float(MobData.BUFF_MAX[main_buff]) * Items.JEWEL_SHARE * roll, 0.01)}
	if randf() < BONUS_CHANCE + roll * 0.25:
		var pool: Array = BONUS_BUFFS.filter(func(b: String) -> bool: return b != main_buff)
		if roll >= 0.88 and randf() < 0.3:
			pool = ["fireproof", "warmth"]
		var extra: String = pool[randi() % pool.size()]
		buffs[extra] = 1.0 if extra in MobData.BINARY_BUFFS else snappedf(float(MobData.BUFF_MAX[extra]) * BONUS_SHARE * randf_range(0.5, 1.0) * roll, 0.01)
	return {"jewel_roll": roll, "buffs": buffs}


## "Radiant Ruby Ring": the jewel's name with how well it was made in front.
static func jewel_name(slot: Dictionary) -> String:
	var name := Items.display_name(slot.get("id", ""))
	if slot.has("jewel_roll"):
		name = MobData.brightness_name(float(slot["jewel_roll"])) + " " + name
	return name


## A map slot without a map behind it (/give, or a lost save) becomes a new map.
func _ensure_map(s: Dictionary, st: Dictionary) -> int:
	if not s.has("map") or not _maps.has(int(s["map"])):
		s["map"] = _new_map(s.get("maker", st["name"]))
		s["maker"] = s.get("maker", st["name"])
	return int(s["map"])


## Bits of one stored piece: which map pixels have been seen.
static func map_seen(bits: PackedByteArray, px: int, pz: int) -> bool:
	var bi := posmod(px, MAP_REGION) + posmod(pz, MAP_REGION) * MAP_REGION
	return (bits[bi >> 3] & (1 << (bi & 7))) != 0


static func map_region_of(px: int, pz: int) -> Vector2i:
	return Vector2i(floori(px / float(MAP_REGION)), floori(pz / float(MAP_REGION)))


## Fills in a circle of the map around a spot.
func _reveal(mid: int, pos: Vector3) -> void:
	var m: Dictionary = _maps[mid]
	var cx := floori(pos.x / MAP_SCALE)
	var cz := floori(pos.z / MAP_SCALE)
	if m.get("last", Vector2i(1 << 30, 0)) == Vector2i(cx, cz):
		return  # hasn't moved a map pixel since last time
	m["last"] = Vector2i(cx, cz)
	var r := int(MAP_REVEAL / MAP_SCALE)
	var regions: Dictionary = m["regions"]
	var changed := {}
	var pieces := {}
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var px := cx + dx
			var pz := cz + dz
			var key := map_region_of(px, pz)
			if not pieces.has(key):
				var bits: PackedByteArray = regions.get(key, PackedByteArray())
				if bits.is_empty():
					bits.resize(MAP_REGION * MAP_REGION / 8)
				pieces[key] = bits
			var b: PackedByteArray = pieces[key]
			var bi := posmod(px, MAP_REGION) + posmod(pz, MAP_REGION) * MAP_REGION
			var mask := 1 << (bi & 7)
			if (b[bi >> 3] & mask) == 0:
				b[bi >> 3] = b[bi >> 3] | mask
				pieces[key] = b  # packed arrays copy on write, so keep the new one
				changed[key] = true
	if changed.is_empty():
		return
	if not _map_dirty.has(mid):
		_map_dirty[mid] = {}
	for key in changed:
		regions[key] = pieces[key]
		_map_dirty[mid][key] = true


func _tick_maps(delta: float) -> void:
	_map_timer -= delta
	if _map_timer > 0.0:
		return
	_map_timer = 0.5
	for peer in _states:
		var st: Dictionary = _states[peer]
		if not st["alive"]:
			continue
		var inv: Array = st["inventory"]
		var fixed := false
		for i in Inv.PLAYER_SLOTS:
			var s = inv[i]
			if s == null or not Items.is_map(s["id"]):
				continue
			if s["id"] == "party_map" and not _party_map_live(s, st):
				continue   # someone outside the party has it: it stays as it was
			if not s.has("map") or not _maps.has(int(s["map"])):
				fixed = true
			_reveal(_ensure_map(s, st), _player_pos(peer))
		if fixed:
			_sync_self(peer)
	# Tell anyone looking at a map about the parts that just filled in.
	for peer in _map_viewers:
		var mid: int = _map_viewers[peer]
		if _map_dirty.has(mid) and _maps.has(mid):
			var out := {}
			for key in _map_dirty[mid]:
				out[key] = _maps[mid]["regions"][key]
			_receive_map_regions.rpc_id(peer, mid, out)
	_map_dirty.clear()
	# Party maps show where everyone in the party is (only to party members).
	for peer in _map_viewers:
		var mid: int = _map_viewers[peer]
		var pid := _party_with_map(mid)
		var who := []
		if pid != 0 and party_of_peer(peer) == pid and _has_map(_states.get(peer, {"inventory": []}), mid):
			for key in _parties[pid]["members"]:
				var other := peer_of(key)
				if other != 0 and other != peer and _states[other]["alive"]:
					var node: Node3D = main.players.get_node_or_null(str(other))
					var pos := _player_pos(other)
					who.append({"name": _states[other]["name"], "x": pos.x, "z": pos.z, "yaw": node.rotation.y if node else 0.0})
		if pid != 0 or not who.is_empty():
			_receive_map_members.rpc_id(peer, mid, who, pid != 0 and party_of_peer(peer) == pid)


## Is this party map with someone in its own party (so it keeps filling in)?
func _party_map_live(s: Dictionary, st: Dictionary) -> bool:
	var pid := int(s.get("party", 0))
	return pid != 0 and _parties.has(pid) and int(_parties[pid].get("map", -1)) == int(s.get("map", -2)) and party_of_key(st["key"]) == pid


## The party whose shared map this is (0 = none).
func _party_with_map(mid: int) -> int:
	for id in _parties:
		if int(_parties[id].get("map", -1)) == mid:
			return int(id)
	return 0


## Is this map in the player's pockets right now?
func _has_map(st: Dictionary, mid: int) -> bool:
	for i in Inv.PLAYER_SLOTS:
		var s = st["inventory"][i]
		if s != null and Items.is_map(s["id"]) and int(s.get("map", -1)) == mid:
			return true
	return false


## Look at the map in this slot (-1 = the first map you're carrying).
@rpc("any_peer", "call_local", "reliable")
func req_map_view(slot: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	var inv: Array = st["inventory"]
	if slot < 0:
		for i in Inv.PLAYER_SLOTS:
			if inv[i] != null and Items.is_map(inv[i]["id"]):
				slot = i
				break
	if slot < 0 or slot >= Inv.PLAYER_SLOTS or inv[slot] == null or not Items.is_map(inv[slot]["id"]):
		_tell(peer, "You need a Map! Make one out of Paper at a Workbench Tier 2.")
		_receive_map_closed.rpc_id(peer)
		return
	var mid := _ensure_map(inv[slot], st)
	_reveal(mid, _player_pos(peer))
	_map_viewers[peer] = mid
	var m: Dictionary = _maps[mid]
	_receive_map.rpc_id(peer, mid, m["maker"], m["regions"], m["marks"], str(m.get("style", "")))
	if inv[slot]["id"] == "party_map" and not _party_map_live(inv[slot], st):
		_tell(peer, "This Party Map belongs to %s. You can look, but it won't fill in or show anyone." % inv[slot].get("party_name", "another party"))
	_sync_self(peer)


@rpc("any_peer", "call_local", "reliable")
func req_map_close() -> void:
	_map_viewers.erase(_sender())


## Put a little picture on the map you're looking at.
@rpc("any_peer", "call_local", "reliable")
func req_map_mark(x: float, z: float, kind: String, label := "") -> void:
	var st := _actor()
	if st.is_empty() or not kind in MAP_MARKS:
		return
	var peer := _sender()
	var mid: int = _map_viewers.get(peer, -1)
	if not _maps.has(mid) or not _has_map(st, mid):
		return
	var pid := _party_with_map(mid)
	if pid != 0 and party_of_peer(peer) != pid:
		_tell(peer, "Only %s can draw on this map." % _parties[pid]["name"])
		return
	var marks: Array = _maps[mid]["marks"]
	if marks.size() >= MAP_MAX_MARKS:
		_tell(peer, "This map is full of pictures! Remove one first (right-click it).")
		return
	var mark := {"x": x, "z": z, "kind": kind}
	label = label.strip_edges().substr(0, 20)
	if label != "":
		mark["label"] = label
	marks.append(mark)
	_send_marks(mid)


@rpc("any_peer", "call_local", "reliable")
func req_map_unmark(index: int) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var mid: int = _map_viewers.get(_sender(), -1)
	if not _maps.has(mid) or not _has_map(st, mid):
		return
	var marks: Array = _maps[mid]["marks"]
	if index >= 0 and index < marks.size() and not marks[index].get("fixed", marks[index]["kind"] == "treasure"):   # the X stays
		marks.remove_at(index)
		_send_marks(mid)


func _send_marks(mid: int) -> void:
	for peer in _map_viewers:
		if _map_viewers[peer] == mid:
			_receive_map_marks.rpc_id(peer, mid, _maps[mid]["marks"])


@rpc("authority", "call_local", "reliable")
func _receive_map(mid: int, maker: String, regions: Dictionary, marks: Array, style := "") -> void:
	map_view = {"id": mid, "maker": maker, "regions": regions.duplicate(true), "marks": marks.duplicate(true), "style": style}
	map_received.emit()


@rpc("authority", "call_local", "reliable")
func _receive_map_regions(mid: int, regions: Dictionary) -> void:
	if map_view.get("id", -1) != mid:
		return
	for key in regions:
		map_view["regions"][key] = regions[key]
	map_updated.emit(regions.keys())


@rpc("authority", "call_local", "reliable")
func _receive_map_members(mid: int, who: Array, live: bool) -> void:
	if map_view.get("id", -1) != mid:
		return
	map_view["members"] = who
	map_view["live"] = live
	map_updated.emit([])


@rpc("authority", "call_local", "reliable")
func _receive_map_marks(mid: int, marks: Array) -> void:
	if map_view.get("id", -1) != mid:
		return
	map_view["marks"] = marks.duplicate(true)
	map_updated.emit([])


@rpc("authority", "call_local", "reliable")
func _receive_map_closed() -> void:
	map_view = {}
	map_received.emit()



# --- Scribe desk, item frames and armor stands --------------------------------------

const STAND_SLOTS := ["head", "chest", "legs", "feet", "back"]
const MINI := 48                 # a framed map shows this many map pixels across

var _frames := {}                # Vector3i -> slot (or null): what's in each item frame
var _stands := {}                # Vector3i -> 5 slots (head, chest, legs, feet, cape)
var frame_items := {}            # client copy: Vector3i -> {"slot", "mini", "c"}
var stand_items := {}            # client copy: Vector3i -> 5 item ids


## Things the Scribe can name: gear and maps.
static func can_inscribe(id: String) -> bool:
	var d := Items.get_def(id)
	return Items.is_map(id) or d.has("tool") or d.has("armor") or d.has("bow") or d.has("cape")


@rpc("any_peer", "call_local", "reliable")
func req_inscribe(slot: int, label: String, ink: String, bench: Vector3i) -> void:
	var st := _actor()
	if st.is_empty():
		return
	var peer := _sender()
	if main.world.get_block(bench) != Blocks.SCRIBE or _player_pos(peer).distance_to(Vector3(bench) + Vector3(0.5, 0.5, 0.5)) > STATION_REACH:
		_tell(peer, "You need to be at a Scribe Desk.")
		return
	var inv: Array = st["inventory"]
	if slot < 0 or slot >= inv.size() or inv[slot] == null or not can_inscribe(inv[slot]["id"]):
		return
	label = label.strip_edges().substr(0, 24)
	if label == "":
		inv[slot].erase("label")
		inv[slot].erase("label_ink")
		inv[slot].erase("scribe")
		_sync_self(peer)
		return
	if not Items.get_def(ink).has("ink") or Inv.remove(inv, ink, 1, Inv.PLAYER_SLOTS) < 1:
		_tell(peer, "You need some ink to write with.")
		return
	inv[slot]["label"] = label
	inv[slot]["label_ink"] = ink
	inv[slot]["scribe"] = st["name"]
	_tell(peer, "You wrote \"%s\" on it." % label)
	_sync_self(peer)


## Right-click an item frame: put the held item in (one of it), or take it out.
@rpc("any_peer", "call_local", "reliable")
func req_frame(pos: Vector3i, slot: int) -> void:
	var st := _actor()
	if st.is_empty() or main.world.get_block(pos) != Blocks.ITEM_FRAME:
		return
	var peer := _sender()
	if _player_pos(peer).distance_to(Vector3(pos) + Vector3(0.5, 0.5, 0.5)) > REACH:
		return
	var inside = _frames.get(pos)
	if inside == null:
		var held := _held(st, slot)
		if held.is_empty():
			_tell(peer, "Hold something, then right-click to put it in the frame.")
			return
		var one: Dictionary = held.duplicate(true)
		one["count"] = 1
		Inv.remove_from_slot(st["inventory"], slot, 1)
		_frames[pos] = one
	else:
		_give_or_drop(peer, inside["id"], 1, Inv.extra(inside))
		_frames[pos] = null
	_sync_self(peer)
	_send_frame(pos)


## What a frame shows, for everyone. Maps also send a small picture of what
## they've seen (around the middle of it).
func _frame_state(pos: Vector3i) -> Dictionary:
	var s = _frames.get(pos)
	if s == null:
		return {}
	var out := {"slot": s}
	if Items.is_map(s["id"]) and _maps.has(int(s.get("map", -1))):
		var regions: Dictionary = _maps[int(s["map"])]["regions"]
		var sum := Vector2.ZERO
		for k in regions:
			sum += Vector2(k) * MAP_REGION + Vector2(MAP_REGION, MAP_REGION) * 0.5
		var c := Vector2i(sum / maxf(1.0, regions.size())) if not regions.is_empty() else Vector2i.ZERO
		var mini := PackedByteArray()
		mini.resize(MINI * MINI)
		for y in MINI:
			for x in MINI:
				var px := c.x - MINI / 2 + x
				var pz := c.y - MINI / 2 + y
				var key := map_region_of(px, pz)
				if regions.has(key) and map_seen(regions[key], px, pz):
					mini[x + y * MINI] = 1
		out["mini"] = mini
		out["c"] = c
	return out


func _send_frame(pos: Vector3i, peer := 0) -> void:
	if peer != 0:
		_receive_frame.rpc_id(peer, pos, _frame_state(pos))
	else:
		_receive_frame.rpc(pos, _frame_state(pos))


@rpc("authority", "call_local", "reliable")
func _receive_frame(pos: Vector3i, state: Dictionary) -> void:
	if state.is_empty():
		frame_items.erase(pos)
	else:
		frame_items[pos] = state
	if main and main.block_models:
		main.block_models.refresh(pos)


func _send_stand(pos: Vector3i, peer := 0) -> void:
	var ids := []
	for s in _stands.get(pos, []):
		ids.append(s["id"] if s != null else "")
	if peer != 0:
		_receive_stand.rpc_id(peer, pos, ids)
	else:
		_receive_stand.rpc(pos, ids)


@rpc("authority", "call_local", "reliable")
func _receive_stand(pos: Vector3i, ids: Array) -> void:
	stand_items[pos] = ids
	if main and main.block_models:
		main.block_models.refresh(pos)


func _send_displays(peer: int) -> void:
	for pos in _chest_names:
		_receive_chest_name.rpc_id(peer, pos, _chest_names[pos])
	for pos in _frames:
		_send_frame(pos, peer)
	for pos in _stands:
		_send_stand(pos, peer)


# --- Portals ----------------------------------------------------------------------------
# Build a rectangle of Portalstone standing up (corners can be left out) with an
# empty middle 2-6 wide and 3-6 tall, and it fills with a dim swirl: a portal.
# Anyone can name it. When two portals of the same size have the same name,
# they link: both light up, and stepping into one takes you out of the other.
# Only two portals can share a name. Once linked, only the person who built a
# portal can rename it or break its frame.

const PORTAL_MIN := Vector2i(2, 3)
const PORTAL_MAX := Vector2i(6, 6)
const PORTAL_COOLDOWN := 3.0

var _portals := {}              # id -> {"min": Vector3i, "w", "h", "axis": "x"/"z", "name", "creator", "creator_name", "partner"}
var _next_portal := 1
var _portal_cooldown := {}      # peer -> seconds until they can use a portal again
var _portal_timer := 0.0
var portals := {}               # client copy: id -> {"min", "w", "h", "axis", "name", "creator_name", "linked"}


static func _portal_dir(axis: String) -> Vector3i:
	return Vector3i(1, 0, 0) if axis == "x" else Vector3i(0, 0, 1)


## Every cell inside a portal.
static func portal_cells(p: Dictionary) -> Array:
	var out := []
	var d := _portal_dir(p["axis"])
	for j in p["h"]:
		for i in p["w"]:
			out.append(p["min"] + d * i + Vector3i(0, j, 0))
	return out


## Is this a cell of the portal's frame (not counting the corners)?
static func in_portal_frame(p: Dictionary, c: Vector3i) -> bool:
	var d := _portal_dir(p["axis"])
	var rel: Vector3i = c - p["min"]
	var along: int = rel.x if p["axis"] == "x" else rel.z
	var across: int = rel.z if p["axis"] == "x" else rel.x
	if across != 0:
		return false
	var in_w: bool = along >= 0 and along < p["w"]
	var in_h: bool = rel.y >= 0 and rel.y < p["h"]
	return (in_w and (rel.y == -1 or rel.y == p["h"])) or (in_h and (along == -1 or along == p["w"]))


## Looks for a finished frame around a newly placed Portalstone. Returns the
## new portal's id, or 0.
func _check_portal_frame(placed: Vector3i, peer: int) -> int:
	var world: Node = main.world
	for axis in ["x", "z"]:
		var d := _portal_dir(axis)
		for start: Vector3i in [placed + d, placed - d, placed + Vector3i.UP, placed + Vector3i.DOWN]:
			if not Blocks.is_open(world.get_block(start)):
				continue
			# Walk left/down to the frame, then measure.
			var lo: Vector3i = start
			for i in PORTAL_MAX.x + 1:
				if not Blocks.is_open(world.get_block(lo - d)):
					break
				lo -= d
			for i in PORTAL_MAX.y + 1:
				if not Blocks.is_open(world.get_block(lo + Vector3i.DOWN)):
					break
				lo += Vector3i.DOWN
			var w := 0
			while w <= PORTAL_MAX.x and Blocks.is_open(world.get_block(lo + d * w)):
				w += 1
			var h := 0
			while h <= PORTAL_MAX.y and Blocks.is_open(world.get_block(lo + Vector3i(0, h, 0))):
				h += 1
			if w < PORTAL_MIN.x or w > PORTAL_MAX.x or h < PORTAL_MIN.y or h > PORTAL_MAX.y:
				continue
			var p := {"min": lo, "w": w, "h": h, "axis": axis}
			var ok := true
			for c in portal_cells(p):
				if not Blocks.is_open(world.get_block(c)):
					ok = false
					break
			if not ok:
				continue
			for i in w:
				for y in [-1, h]:
					if world.get_block(lo + d * i + Vector3i(0, y, 0)) != Blocks.PORTALSTONE:
						ok = false
			for j in h:
				for x in [-1, w]:
					if world.get_block(lo + d * x + Vector3i(0, j, 0)) != Blocks.PORTALSTONE:
						ok = false
			if not ok:
				continue
			for other in _portals.values():
				if other["min"] == lo and other["axis"] == axis:
					ok = false  # already a portal here
			if not ok:
				continue
			var st: Dictionary = _states.get(peer, {})
			var id := _next_portal
			_next_portal += 1
			p["name"] = ""
			p["creator"] = st.get("key", "")
			p["creator_name"] = st.get("name", "")
			p["partner"] = 0
			_portals[id] = p
			_fill_portal(id)
			_tell(peer, "You made a portal! Right-click it to give it a name.")
			_send_portals()
			return id
	return 0


func _fill_portal(id: int) -> void:
	var p: Dictionary = _portals[id]
	var b := Blocks.PORTAL_LIT if p["partner"] != 0 else Blocks.PORTAL
	for c in portal_cells(p):
		main.world.server_set_block(c, b)


static func _clean_name(n: String) -> String:
	return n.strip_edges().substr(0, 24)


## The portal at (or framed around) this spot, or 0.
func portal_at(c: Vector3i, frame_too := false) -> int:
	for id in _portals:
		var p: Dictionary = _portals[id]
		if c in portal_cells(p) or (frame_too and in_portal_frame(p, c)):
			return id
	return 0


func _unlink(id: int) -> void:
	var p: Dictionary = _portals.get(id, {})
	if p.is_empty() or p["partner"] == 0:
		return
	var other: int = p["partner"]
	p["partner"] = 0
	_fill_portal(id)
	if _portals.has(other):
		_portals[other]["partner"] = 0
		_fill_portal(other)


@rpc("any_peer", "call_local", "reliable")
func req_name_portal(id: int, new_name: String) -> void:
	var st := _actor()
	if st.is_empty() or not _portals.has(id):
		return
	var peer := _sender()
	var p: Dictionary = _portals[id]
	var near := false
	for c in portal_cells(p):
		if _player_pos(peer).distance_to(Vector3(c) + Vector3(0.5, 0.5, 0.5)) < REACH + 2.0:
			near = true
	if not near:
		return
	new_name = _clean_name(new_name)
	if p["partner"] != 0 and p["creator"] != st["key"]:
		_tell(peer, "Only %s can rename this portal now that it's linked." % p["creator_name"])
		return
	if new_name.to_lower() == String(p["name"]).to_lower():
		return
	# Who else has this name?
	var same: Array = []
	for oid in _portals:
		if oid != id and new_name != "" and String(_portals[oid]["name"]).to_lower() == new_name.to_lower():
			same.append(oid)
	if same.size() >= 2:
		_tell(peer, "Two portals already use the name \"%s\". Pick another name!" % new_name)
		return
	_unlink(id)
	p["name"] = new_name
	if same.size() == 1:
		var o: Dictionary = _portals[same[0]]
		if o["w"] == p["w"] and o["h"] == p["h"]:
			p["partner"] = same[0]
			o["partner"] = id
			_fill_portal(id)
			_fill_portal(same[0])
			_tell(peer, "Whoosh! \"%s\" is linked. Step in to travel!" % new_name)
			main._receive_event.rpc("%s linked the portal \"%s\"." % [st["name"], new_name], "portalstone")
		else:
			_tell(peer, "The other \"%s\" portal is %dx%d. Make them the same size to link them." % [new_name, o["w"], o["h"]])
	elif new_name != "":
		_tell(peer, "Named it \"%s\". Build another %dx%d portal with the same name to link them!" % [new_name, p["w"], p["h"]])
	_send_portals()


## A frame block (or a portal's middle) was broken.
func _portal_broken(id: int) -> void:
	var p: Dictionary = _portals.get(id, {})
	if p.is_empty():
		return
	_unlink(id)
	_portals.erase(id)
	for c in portal_cells(p):
		main.world.server_set_block(c, Blocks.AIR)
	_send_portals()


func _tick_portals(delta: float) -> void:
	for peer in _portal_cooldown.keys():
		_portal_cooldown[peer] -= delta
		if _portal_cooldown[peer] <= 0.0:
			_portal_cooldown.erase(peer)
	_portal_timer -= delta
	if _portal_timer > 0.0 or _portals.is_empty():
		return
	_portal_timer = 0.15
	for peer in _states:
		if _portal_cooldown.has(peer) or not _states[peer]["alive"]:
			continue
		var pos := _player_pos(peer)
		for dy in [0.3, 1.2]:
			var c := Vector3i(floori(pos.x), floori(pos.y + dy), floori(pos.z))
			if main.world.get_block(c) != Blocks.PORTAL_LIT:
				continue
			var id := portal_at(c)
			if id == 0 or _portals[id]["partner"] == 0:
				continue
			var to: Dictionary = _portals[_portals[id]["partner"]]
			_portal_cooldown[peer] = PORTAL_COOLDOWN
			var exit := _portal_exit(to)
			if exit.y < -999.0:
				_tell(peer, "The other \"%s\" portal is blocked on both sides, so it can't take you there. Clear a space in front of it!" % to["name"])
				break
			main._teleport.rpc_id(peer, exit)
			_portal_fx.rpc(pos, exit)
			break


## Where you come out of a portal: in front of it, on whichever side has room
## to stand (2 blocks tall). Looks along the whole width, middle first.
## y = -1000 if both sides are walled in.
func _portal_exit(p: Dictionary) -> Vector3:
	var d := _portal_dir(p["axis"])
	var out := Vector3i(0, 0, 1) if p["axis"] == "x" else Vector3i(1, 0, 0)
	var w := int(p["w"])
	var order := []
	for k in w:
		order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return absf(a - (w - 1) * 0.5) < absf(b - (w - 1) * 0.5))
	var best := Vector3(0, -1000, 0)
	var best_score := -1
	for side in [out, -out]:
		var score := 0
		var spot := Vector3(0, -1000, 0)
		for k in order:
			var c: Vector3i = p["min"] + d * k + side
			if _room_to_stand(c):
				score += 1
				if spot.y < -999.0:
					spot = Vector3(c) + Vector3(0.5, 0.05, 0.5)
		if score > best_score and spot.y > -999.0:
			best_score = score
			best = spot
	return best


func _room_to_stand(c: Vector3i) -> bool:
	var w: Node = main.world
	return not Blocks.is_solid(w.get_block(c)) and not Blocks.is_solid(w.get_block(c + Vector3i.UP)) \
			and w.get_block(c) != Blocks.PORTAL_LIT and w.get_block(c) != Blocks.PORTAL


@rpc("authority", "call_local", "reliable")
func _portal_fx(from: Vector3, to: Vector3) -> void:
	if main == null or main.dedicated:
		return
	Sound.play_at("legendary", from, -10.0, 1.5)
	Sound.play_at("legendary", to, -10.0, 1.5)


func _send_portals(peer := 0) -> void:
	var out := {}
	for id in _portals:
		var p: Dictionary = _portals[id]
		out[id] = {"min": p["min"], "w": p["w"], "h": p["h"], "axis": p["axis"], "name": p["name"],
				"creator_name": p["creator_name"], "linked": p["partner"] != 0}
	if peer != 0:
		_receive_portals.rpc_id(peer, out)
	else:
		_receive_portals.rpc(out)


@rpc("authority", "call_local", "reliable")
func _receive_portals(data: Dictionary) -> void:
	portals = data


## Client: the portal around this spot (0 = none).
func client_portal_at(c: Vector3i) -> int:
	for id in portals:
		if c in portal_cells(portals[id]):
			return id
	return 0


# --- Loot (corpses, death bags, boss treasure) -----------------------------------------------

## Server: a mob died, leave a corpse with its loot (the boss gives each
## player who hit it their own treasure).
func on_mob_killed(type: String, pos: Vector3, yaw: float, _killer: int, attackers: Array) -> void:
	var def := MobData.get_def(type)
	if def.get("boss", false):
		var names := PackedStringArray()
		for peer in attackers:
			if not _states.has(peer):
				continue
			var st: Dictionary = _states[peer]
			names.append(st["name"])
			var slots := Inv.make(9)
			for entry in def.get("treasure", []):
				if Items.rarity(entry[0]) == "legendary" and Items.max_stack(entry[0]) == 1:
					Inv.add(slots, entry[0], 1, -1, {"roll": roll_legendary()})   # each one rolls how good it is
				else:
					Inv.add(slots, entry[0], randi_range(entry[1], entry[2]))
			var boss := BossData.boss_for_mob(type)
			if not boss.is_empty():
				Inv.add(slots, BossData.trophy_id(boss["id"]), 1)
			var spot := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
			_create_loot("treasure", type, spot, yaw, slots, st["name"], st["key"])
			_legendary.rpc_id(peer, def.get("signature", ""))
		main._receive_event.rpc("The %s %s defeated by %s! Everyone who fought gets their own treasure." % [def.get("pair_name", def["name"]),
				"were" if def.has("pair_name") else "was", ", ".join(names)], "king_crown")
		return
	var slots := Inv.make(9)
	var harvest: bool = _has_special(_states.get(_killer, {}), "harvest") or _reaping.get(_killer, false)
	for entry in def.get("loot", []):
		if entry.size() > 3 and randf() > float(entry[3]):
			continue  # a rare drop that didn't happen this time
		var n := randi_range(entry[1], entry[2]) * (2 if harvest else 1)
		if n > 0:
			Inv.add(slots, entry[0], n)
	if not Inv.is_empty(slots):
		_create_loot("corpse", type, pos, yaw, slots, "", "")


func _create_loot(kind: String, mob: String, pos: Vector3, yaw: float, slots: Array, owner: String, locked: String) -> int:
	var id := _next_loot
	_next_loot += 1
	_loot[id] = {"kind": kind, "mob": mob, "pos": pos, "yaw": yaw, "slots": slots, "age": 0.0, "owner": owner, "locked": locked}
	_loot_spawn.rpc(id, kind, mob, pos, yaw, owner)
	return id


func _remove_loot(id: int) -> void:
	_loot.erase(id)
	_close_viewers("loot", id)
	_loot_despawn.rpc(id)


# --- Client side ---------------------------------------------------------------------

@rpc("authority", "call_local", "unreliable")
func _npc_giggle(id: int) -> void:
	var m: Node3D = main.mobs.get_mob(id)
	if m:
		m.voice()


@rpc("authority", "call_local", "reliable")
func _receive_self(state: Dictionary) -> void:
	# Little sounds for good things: toots coming in, a new recipe unlocked.
	if not me.is_empty():
		if state.get("toots", 0.0) > me.get("toots", 0.0) + 0.001:
			Sound.play("coin", -6.0, 1.0, "Interface")
		if state.get("unlocked", {}).size() > me.get("unlocked", {}).size():
			Sound.play("unlock", -4.0, 1.0, "Interface")
	me = state
	_power_stamp = _clock
	self_changed.emit()


@rpc("authority", "call_local", "reliable")
func _receive_container(kind: String, key: Variant, slots: Array, extra: Dictionary) -> void:
	open_kind = kind
	open_key = key
	open_slots = slots
	open_extra = extra
	container_changed.emit()


@rpc("authority", "call_local", "reliable")
func _receive_container_closed() -> void:
	open_kind = ""
	open_slots = []
	open_extra = {}
	container_changed.emit()


@rpc("authority", "call_local", "reliable")
func _receive_notice(text: String) -> void:
	notice.emit(text)


@rpc("authority", "call_local", "reliable")
func _receive_hurt(knockback: Vector3) -> void:
	if main.local_player:
		main.local_player.apply_knockback(knockback)
	hurt.emit()


@rpc("authority", "call_local", "reliable")
func _you_died(cause: String) -> void:
	died.emit(cause)


@rpc("authority", "call_local", "reliable")
func _you_respawned(pos: Vector3) -> void:
	respawned.emit(pos)


@rpc("authority", "call_local", "reliable")
func _you_sleep(bed: Vector3i) -> void:
	sleep_changed.emit(true, bed)


@rpc("authority", "call_local", "reliable")
func _you_woke() -> void:
	sleep_changed.emit(false, NO_POS)


@rpc("authority", "call_local", "reliable")
func _trade_invite(from_peer: int, from_name: String) -> void:
	trade_invited.emit(from_peer, from_name)


@rpc("authority", "call_local", "reliable")
func _legendary(item: String) -> void:
	legendary_found.emit(item)


@rpc("authority", "call_local", "reliable")
func _set_player_alive(peer: int, alive: bool) -> void:
	var node: Node3D = main.players.get_node_or_null(str(peer))
	if node and peer != multiplayer.get_unique_id():
		node.visible = alive


@rpc("authority", "call_local", "reliable")
func _set_player_armor(peer: int, ids: Array) -> void:
	var node: Node3D = main.players.get_node_or_null(str(peer))
	if node and node.has_method("set_armor"):
		node.set_armor(ids)


@rpc("authority", "call_local", "reliable")
func _loot_spawn(id: int, kind: String, mob: String, pos: Vector3, yaw: float, owner := "") -> void:
	if _loot_nodes.has(id):
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	if kind == "corpse":
		var model: Node3D = MobData.build_model(mob)["root"]
		var size: Vector2 = MobData.get_def(mob)["size"]
		model.rotation.z = PI / 2.0  # lying on its side
		model.position.y = size.x * 0.5
		n.add_child(model)
		n.set_meta("box", Vector3(size.y, size.x, size.y))
	else:
		var treasure := kind == "treasure"
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.75, 0.2) if treasure else Color(0.5, 0.36, 0.2)
		if treasure:
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.55, 0.1)
			mat.emission_energy_multiplier = 0.6
		for part in [[Vector3(0.6, 0.5, 0.6), 0.25], [Vector3(0.25, 0.15, 0.25), 0.55]]:
			var mi := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = part[0]
			mesh.material = mat
			mi.mesh = mesh
			mi.position.y = part[1]
			n.add_child(mi)
		var label := Label3D.new()
		label.text = "%s's treasure" % owner if treasure else "Loot bag"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.005
		label.outline_size = 10
		label.modulate = Color(1.0, 0.65, 0.2) if treasure else Color.WHITE
		label.position.y = 1.0
		n.add_child(label)
		n.set_meta("box", Vector3(0.7, 0.7, 0.7))
	main.add_child(n)
	_loot_nodes[id] = n


@rpc("authority", "call_local", "reliable")
func _loot_despawn(id: int) -> void:
	if _loot_nodes.has(id):
		_loot_nodes[id].queue_free()
		_loot_nodes.erase(id)


@rpc("authority", "call_local", "reliable")
func _drop_spawn(did: int, id: String, pos: Vector3) -> void:
	if _drop_nodes.has(did):
		return
	var n := Node3D.new()
	n.position = pos
	var model := ItemModels.item_model(id, 0.3 if Items.block_of(id) >= 0 and Blocks.MODEL[Items.block_of(id)] == "" else 0.45, false)
	model.name = "Model"
	n.add_child(model)
	main.add_child(n)
	_drop_nodes[did] = n
	_drop_targets[did] = pos


@rpc("authority", "call_local", "unreliable_ordered")
func _drop_move(did: int, pos: Vector3) -> void:
	_drop_targets[did] = pos


@rpc("authority", "call_local", "reliable")
func _drop_despawn(did: int) -> void:
	if _drop_nodes.has(did):
		_drop_nodes[did].queue_free()
		_drop_nodes.erase(did)
		_drop_targets.erase(did)


## The item flies to whoever picked it up, then vanishes.
@rpc("authority", "call_local", "reliable")
func _pickup_fx(did: int, peer: int) -> void:
	if not _drop_nodes.has(did):
		return
	var n: Node3D = _drop_nodes[did]
	var player: Node3D = main.players.get_node_or_null(str(peer))
	Sound.play_at("pickup", n.position, -8.0, randf_range(0.95, 1.1))
	_drop_nodes.erase(did)
	_drop_targets.erase(did)
	if player == null:
		n.queue_free()
		return
	var tw := n.create_tween()
	tw.tween_property(n, "position", player.global_position + Vector3(0, 1.0, 0), 0.15)
	tw.tween_callback(n.queue_free)


func _animate_drops(delta: float) -> void:
	for did in _drop_nodes:
		var n: Node3D = _drop_nodes[did]
		n.position = n.position.lerp(_drop_targets.get(did, n.position), minf(1.0, delta * 12.0))
		var model := n.get_node_or_null("Model")
		if model:
			model.rotation.y += delta * 1.8
			model.position.y = 0.25 + sin(_clock * 2.5 + did) * 0.06


## For clicking on corpses/bags: [{"id", "aabb"}].
func loot_targets() -> Array:
	var out := []
	for id in _loot_nodes:
		var n: Node3D = _loot_nodes[id]
		var box: Vector3 = n.get_meta("box")
		out.append({"id": id, "aabb": AABB(n.position - Vector3(box.x * 0.5, 0, box.z * 0.5), box)})
	return out


func my_inventory() -> Array:
	return me.get("inventory", Inv.make(Inv.PLAYER_SIZE))


func my_slot(i: int) -> Dictionary:
	var inv := my_inventory()
	return inv[i] if i >= 0 and i < inv.size() and inv[i] != null else {}
