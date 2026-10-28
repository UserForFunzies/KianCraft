extends RefCounted
## "Arena in a Box" (host testing, /arena): an old Roman-style battle arena.
##
##   The floor   - an oval of sand with stone pillars, low walls to hide
##                 behind, and a parkour course: hops up to a tower, a narrow
##                 bridge, and a ring of floating stepping stones.
##   The stands  - eight rows of stone seats all the way round, rising up to
##                 a tall outer wall with arches, lamps along the top.
##   Change rooms - one on each side (east and west) under the seats, full of
##                 every weapon, bow, arrow, armor set, cape, ring and amulet.
##                 Their gates open onto the sand.
##   Control room - high up on the north side, with windows over the sand and
##                 the Arena Button: press it and every gate slams shut and
##                 locks, and everyone within 200 blocks gets "3, 2, 1, FIGHT!".
##                 Press it again (or wait ROUND_SECONDS) to open the gates.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Inv = preload("res://scripts/inventory.gd")

const A := 24.0              # the sand oval's half-width (east-west)
const B := 17.0              # and half-length (north-south)
const SEAT_ROWS := 8
const WALL_H := 15
const TOP := 18              # cleared up to this height
const ROUND_SECONDS := 300.0

var sv: Node
var w: Node
var c: Vector3i              # the middle of the sand (floor level)
var cells := {}              # Vector3i -> [block, facing]
var gates: Array = []        # where gate bars drop when the arena locks
var button := Vector3i.ZERO
var rooms := []              # [center, side] of each change room


## Builds it, registers it, and returns where to stand (in the control room).
static func build(survival: Node, box_pos: Vector3i, _peer: int) -> Vector3:
	var k := new()
	k.sv = survival
	k.w = survival.main.world
	k.c = box_pos + Vector3i.DOWN
	k._shape()
	var list := []
	for p in k.cells:
		list.append([p, k.cells[p][0], k.cells[p][1]])
	k.w.server_set_blocks(list)
	k._fill()
	survival.register_arena(k.c, k.gates, k.button)
	return Vector3(k.button) + Vector3(0.5, 0.05, -1.5)


func put(dx: int, dy: int, dz: int, b: int, facing := -1) -> void:
	cells[c + Vector3i(dx, dy, dz)] = [b, facing]


## How far outside the sand oval a spot is, in blocks (0 = its edge).
static func ring(dx: float, dz: float) -> float:
	return sqrt(pow(dx * B / A, 2.0) + dz * dz) - B


## Which way is "out" from the middle (0 north, 1 east, 2 south, 3 west), for seat backs.
static func outward(dx: float, dz: float) -> int:
	var nx := dx * B / A
	if absf(nx) > absf(dz):
		return 1 if nx > 0 else 3
	return 2 if dz > 0 else 0


func _shape() -> void:
	var reach := int(A + 22)
	var gate_rows := {}
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var r := ring(dx, dz)
			if r > SEAT_ROWS * 2 + 4:
				continue
			var x := dx
			var z := dz
			# Solid ground under everything.
			for dy in range(-5, 0):
				if not Blocks.is_solid(w.get_block(c + Vector3i(x, dy, z))):
					put(x, dy, z, Blocks.STONE)
			var col_top := 0
			var floor_b := Blocks.SAND
			if r <= 0.0:
				col_top = 0
			elif r <= 1.2:
				col_top = 4          # the podium wall round the sand
				floor_b = Blocks.SANDSTONE
			elif r <= SEAT_ROWS * 2 + 1.2:
				var row := mini(int((r - 1.2) / 2.0), SEAT_ROWS - 1)
				col_top = 4 + row + 1
				floor_b = Blocks.SANDSTONE
			else:
				col_top = WALL_H     # the tall outer wall
				floor_b = Blocks.STONE_BRICKS
			put(x, 0, z, floor_b)
			for dy in range(1, TOP + 1):
				var b := Blocks.AIR
				if dy < col_top:
					b = Blocks.SANDSTONE if r > 1.2 and r <= SEAT_ROWS * 2 + 1.2 else (Blocks.CHISELED_BRICKS if r > 1.2 else Blocks.SANDSTONE)
					if r > SEAT_ROWS * 2 + 1.2:
						b = Blocks.STONE_BRICKS
						# Roman arches: openings round the outside, two floors of them.
						var ang := atan2(float(dz), float(dx) * B / A)
						var bay := posmod(int(floor(ang / TAU * 64.0)), 2) == 0
						if bay and (dy >= 2 and dy <= 4 or dy >= 8 and dy <= 10) and r > SEAT_ROWS * 2 + 2.2:
							b = Blocks.AIR
				elif dy == col_top and r > 1.2 and r <= SEAT_ROWS * 2 + 1.2:
					var row2 := mini(int((r - 1.2) / 2.0), SEAT_ROWS - 1)
					var front := (r - 1.2) - row2 * 2.0 < 1.0
					# The inner block of each row is where your feet go; the outer one is the seat.
					b = Blocks.AIR if front else (Blocks.SANDSTONE_STAIRS if row2 % 2 == 0 else Blocks.STONE_BRICK_STAIRS)
				elif dy == col_top and r <= 1.2 and r > 0.0:
					b = Blocks.CHISELED_BRICKS     # the podium's top edge
				elif dy == WALL_H and r > SEAT_ROWS * 2 + 1.2:
					var ang2 := atan2(float(dz), float(dx) * B / A)
					var tooth := posmod(int(floor(ang2 / TAU * 96.0)), 2) == 0
					b = Blocks.STONE_BRICKS if tooth else (Blocks.LAMP if posmod(int(floor(ang2 / TAU * 96.0)), 8) == 1 else Blocks.AIR)
				var facing := outward(dx, dz) if b in [Blocks.SANDSTONE_STAIRS, Blocks.STONE_BRICK_STAIRS] else -1
				put(x, dy, z, b, facing)
	# Lamps along the podium, every few blocks.
	for i in 24:
		var a := TAU * i / 24.0
		var lx := roundi(cos(a) * (A + 0.6))
		var lz := roundi(sin(a) * (B + 0.6))
		if absi(lx) > 3 and absi(lz) > 3:
			put(lx, 4, lz, Blocks.LAMP)
	_tunnels()
	_change_rooms()
	_control_room()
	_obstacles()


## The two main entrances (north and south) through the stands.
func _tunnels() -> void:
	for sz in [-1, 1]:
		for dz in range(int(B) - 1, int(B) + SEAT_ROWS * 2 + 6):
			for dx in range(-2, 3):
				var z: int = sz * dz
				var r := ring(dx, z)
				if r < -0.5:
					continue
				put(dx, 0, z, Blocks.STONE_BRICKS)
				for dy in range(1, 5):
					var edge := absi(dx) == 2
					put(dx, dy, z, Blocks.STONE_BRICKS if edge or dy == 4 else Blocks.AIR)
				if absi(dx) <= 1 and r > 0.5 and r <= 1.5:
					for dy in range(1, 4):
						gates.append(c + Vector3i(dx, dy, z))
				if dz % 4 == 0 and absi(dx) == 0:
					put(dx, 4, z, Blocks.LAMP)


## East and west change rooms under the seats, with gates onto the sand.
func _change_rooms() -> void:
	for sx in [-1, 1]:
		var inner := int(A) + 1           # the podium wall at the middle of the side
		var cx: int = sx * (inner + 6)
		rooms.append([c + Vector3i(cx, 1, 0), sx])
		for dz in range(-5, 6):
			for dx in range(-5, 6):
				var x: int = cx + dx
				var wall := absi(dx) == 5 or absi(dz) == 5
				put(x, 0, dz, Blocks.REDWOOD_PLANKS if not wall else Blocks.STONE_BRICKS)
				for dy in range(1, 6):
					put(x, dy, dz, Blocks.STONE_BRICKS if wall or dy == 5 else Blocks.AIR)
				if not wall and posmod(dx, 3) == 0 and posmod(dz, 3) == 0:
					put(x, 5, dz, Blocks.LAMP)
		# The corridor from the room to the sand, with the gate at the podium.
		for step in range(0, 3):
			var x2: int = sx * (inner - 1 + step)
			for dz in range(-2, 3):
				put(x2, 0, dz, Blocks.STONE_BRICKS)
				for dy in range(1, 5):
					var edge := absi(dz) == 2
					put(x2, dy, dz, Blocks.STONE_BRICKS if edge or dy == 4 else Blocks.AIR)
		for dz in range(-1, 2):
			for dy in range(1, 4):
				var gx: int = sx * inner
				gates.append(c + Vector3i(gx, dy, dz))


## The control room high on the north side, looking over the sand.
func _control_room() -> void:
	var z0 := -int(B) - 10    # front (inner) wall
	var z1 := -int(B) - 16    # back wall
	var floor_y := 4 + SEAT_ROWS + 1
	for dz in range(z1, z0 + 1):
		for dx in range(-6, 7):
			var wall := absi(dx) == 6 or dz == z1 or dz == z0
			put(dx, floor_y, dz, Blocks.STONE_BRICKS)
			for dy in range(1, 5):
				var y := floor_y + dy
				var b := Blocks.STONE_BRICKS if wall else Blocks.AIR
				if dz == z0 and absi(dx) < 6 and dy >= 1 and dy <= 3:
					b = Blocks.GLASS             # the big window over the sand
				if absi(dx) == 6 and absi(dz - (z0 + z1) / 2) <= 0 and dy <= 2:
					b = Blocks.AIR               # doors on both sides, out onto the top seats
				put(dx, y, dz, b)
			put(dx, floor_y + 5, dz, Blocks.LAMP if absi(dx) == 3 and dz == (z0 + z1) / 2 else Blocks.STONE_BRICKS)
			# Hold it up over the seats below.
			for dy in range(1, floor_y):
				if not cells.has(c + Vector3i(dx, dy, dz)) or cells[c + Vector3i(dx, dy, dz)][0] == Blocks.AIR:
					if wall and (absi(dx) == 6 and (dz == z0 or dz == z1)):
						put(dx, dy, dz, Blocks.STONE_PILLAR)
	# Steps from the seats up to each door.
	var mz := (z0 + z1) / 2
	for sx in [-1, 1]:
		for st in [[8, floor_y - 2, Blocks.SANDSTONE], [7, floor_y - 2, Blocks.SANDSTONE], [7, floor_y - 1, Blocks.SANDSTONE], [7, floor_y, Blocks.SANDSTONE_SLAB]]:
			put(sx * st[0], st[1], mz, st[2])
			for up in range(1, 4):
				if st[1] + up > floor_y:
					put(sx * st[0], st[1] + up, mz, Blocks.AIR)
	button = c + Vector3i(0, floor_y + 1, z0 - 2)
	put(0, floor_y + 1, z0 - 2, Blocks.ARENA_BUTTON)
	put(-2, floor_y + 1, z0 - 1, Blocks.CHISELED_BRICKS)
	put(2, floor_y + 1, z0 - 1, Blocks.CHISELED_BRICKS)


## Things on the sand: pillars and low walls to hide behind, and a parkour course.
func _obstacles() -> void:
	for p in [Vector2i(-12, -7), Vector2i(12, 7), Vector2i(-8, 9), Vector2i(9, -9), Vector2i(-16, 2), Vector2i(16, -2)]:
		var tall := 3 + posmod(p.x * 3 + p.y, 4)
		for dz in range(2):
			for dx in range(2):
				for dy in range(1, tall + 1):
					put(p.x + dx, dy, p.y + dz, Blocks.STONE_PILLAR if dy < tall else Blocks.CHISELED_BRICKS)
	for wl in [[Vector2i(-4, -11), Vector2i(1, 0)], [Vector2i(0, 11), Vector2i(1, 0)], [Vector2i(-19, -6), Vector2i(0, 1)], [Vector2i(19, 2), Vector2i(0, 1)]]:
		var start: Vector2i = wl[0]
		var d: Vector2i = wl[1]
		for i in 5:
			var q := start + d * i
			put(q.x, 1, q.y, Blocks.SANDSTONE)
			put(q.x, 2, q.y, Blocks.SANDSTONE_SLAB)
	# Parkour: stepping stones up to a tower, a narrow bridge, and down the other side.
	var hops := [Vector3i(-6, 1, -2), Vector3i(-8, 2, -4), Vector3i(-10, 3, -2), Vector3i(-10, 4, 1), Vector3i(-8, 5, 3), Vector3i(-5, 6, 3)]
	for h in hops:
		put(h.x, h.y, h.z, Blocks.CHISELED_BRICKS)
	for dz in range(2, 5):
		for dx in range(-3, 0):
			for dy in range(1, 7):
				put(dx, dy, dz, Blocks.STONE_BRICKS if dy < 6 else Blocks.CHISELED_BRICKS)
	for dx in range(0, 6):
		put(dx, 6, 3, Blocks.STONE_BRICK_SLAB)     # the narrow bridge
	for dz in range(2, 5):
		for dx in range(6, 9):
			for dy in range(1, 7):
				put(dx, dy, dz, Blocks.STONE_BRICKS if dy < 6 else Blocks.CHISELED_BRICKS)
	for i in 8:
		var a := TAU * i / 8.0
		put(roundi(cos(a) * 5.0), 2 + (i % 3), -6 + roundi(sin(a) * 3.0), Blocks.SANDSTONE)   # floating stepping stones


## Change rooms: chests of gear, armor stands in every set, swords on the walls.
func _fill() -> void:
	var weapons := []
	var armor := []
	var extras := []
	for id in Items.ITEMS:
		var d := Items.get_def(id)
		if id in ["castle_box", "arena_box"]:
			continue
		if d.has("tool") or d.has("bow"):
			weapons.append(id)
		elif d.has("arrow"):
			extras.append(id)
		elif d.has("armor") or d.has("cape") or d.has("buffs"):
			armor.append(id)
	var food := ["cooked_pork", "cooked_venison", "cooked_bear", "pumpkin_pie", "french_fries"]
	for room in rooms:
		var rc: Vector3i = room[0]
		var sx: int = room[1]
		var back := rc.x + sx * 4             # the wall away from the sand
		var chest_list := []
		var groups := [["Weapons", weapons], ["Armor & Jewels", armor], ["Arrows & Snacks", extras + food]]
		var spot := 0
		for g in groups:
			var ids: Array = g[1]
			var part := 0
			var start := 0
			while start < ids.size():
				var slots := Inv.make(sv.CHEST_SIZE)
				for i in range(start, mini(start + sv.CHEST_SIZE, ids.size())):
					var id: String = ids[i]
					slots[i - start] = {"id": id, "count": Items.max_stack(id) if Items.max_stack(id) > 1 else 1}
				start += sv.CHEST_SIZE
				part += 1
				var pos := Vector3i(back, rc.y + (spot % 2), rc.z - 3 + spot / 2)
				chest_list.append([pos, g[0] if part == 1 else "%s %d" % [g[0], part], slots])
				spot += 1
		var chest_cells := []
		for ch in chest_list:
			chest_cells.append([ch[0], Blocks.CHEST, 1 if sx < 0 else 3])
		w.server_set_blocks(chest_cells)
		for ch in chest_list:
			sv._chests[ch[0]] = ch[2]
			sv._chest_names[ch[0]] = ch[1]
			sv._receive_chest_name.rpc(ch[0], ch[1])
		# Armor stands along the side walls, one set each.
		var sets := []
		for s in Items.ARMOR_SETS:
			sets.append(["%s_helmet" % s[0], "%s_chestplate" % s[0], "%s_leggings" % s[0], "%s_boots" % s[0]])
		sets.append(["king_crown", "grim_chestplate", "titanium_leggings", "yeti_boots"])
		sets.append(["cute_titanium_helmet", "cute_titanium_chestplate", "cute_titanium_leggings", "cute_titanium_boots"])
		var stand_cells := []
		var stands := []
		for i in sets.size():
			var side := -1 if i < 3 else 1
			var pos := Vector3i(rc.x - sx * 2 + sx * (i % 3) * 2, rc.y, rc.z + side * 4)
			stand_cells.append([pos, Blocks.ARMOR_STAND, 0 if side > 0 else 2])
			stands.append([pos, sets[i]])
		w.server_set_blocks(stand_cells)
		for st in stands:
			var slots := Inv.make(5)
			for j in 4:
				if Items.exists(st[1][j]):
					slots[j] = {"id": st[1][j], "count": 1}
			slots[4] = {"id": Items.cape_id(posmod(st[0].x, Items.CAPES.size()), 3), "count": 1, "roll": 1.0, "maker": "the Arena"}
			sv._stands[st[0]] = slots
			sv._send_stand(st[0])


## The gates' state, for tests and the server.
static func gate_block(locked: bool) -> int:
	return Blocks.ARENA_GATE if locked else Blocks.AIR
