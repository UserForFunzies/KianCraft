extends RefCounted
## "Castle in a Box" (host testing, /castle): builds a finished end-game castle
## around the box, then puts you in the middle of its courtyard.
##
##   North wing  - the Armory: armor stands in every set of armor (and the
##                 legendary set), and item frames full of the best gear.
##   East wing   - the Storeroom: labeled chests holding one stack of every
##                 item in the game, sorted (ores, woods, meat, plants...).
##   West wing   - the Bedrooms: beds, tables and chairs, a Super Chest.
##   South wing  - the Workshop: every workbench and station, by the gate.
##   Courtyard   - flower beds and lamp posts; maps of the whole area on the
##                 walls, with every boss and place of interest marked.

const Blocks = preload("res://scripts/blocks.gd")
const Items = preload("res://scripts/items.gd")
const Inv = preload("res://scripts/inventory.gd")
const BossData = preload("res://scripts/boss_data.gd")

const R := 20                # walls run around -R..R
const WING := 13             # inner walls of the four wings
const MAP_RADIUS := 1024     # how far the castle's maps show

var sv: Node
var w: Node
var c: Vector3i              # the courtyard floor in the middle
var cells := {}              # Vector3i -> [block, facing]


## Builds it and returns where to stand.
static func build(survival: Node, box_pos: Vector3i, peer: int) -> Vector3:
	var k := new()
	k.sv = survival
	k.w = survival.main.world
	k.c = box_pos + Vector3i.DOWN
	k._shape()
	var list := []
	for p in k.cells:
		list.append([p, k.cells[p][0], k.cells[p][1]])
	k.w.server_set_blocks(list)
	k._fill(peer)
	return Vector3(k.c) + Vector3(0.5, 1.05, 0.5)


func put(dx: int, dy: int, dz: int, b: int, facing := -1) -> void:
	cells[c + Vector3i(dx, dy, dz)] = [b, facing]


func _shape() -> void:
	# Clear the ground, lay the floor, fill under it on hills.
	for dz in range(-R - 2, R + 3):
		for dx in range(-R - 2, R + 3):
			for dy in range(1, 17):
				if w.get_block(c + Vector3i(dx, dy, dz)) != Blocks.AIR:
					put(dx, dy, dz, Blocks.AIR)
			var inside: bool = absi(dx) <= R and absi(dz) <= R
			put(dx, 0, dz, Blocks.STONE_BRICKS if inside else Blocks.GRASS)
			for dy in range(-6, 0):
				if Blocks.is_open(w.get_block(c + Vector3i(dx, dy, dz))) or Blocks.is_water(w.get_block(c + Vector3i(dx, dy, dz))):
					put(dx, dy, dz, Blocks.COBBLESTONE)
	# Courtyard: a gold-inlaid cross path, flower beds and lamp posts.
	for dz in range(-WING + 1, WING):
		for dx in range(-WING + 1, WING):
			var path: bool = absi(dx) <= 1 or absi(dz) <= 1
			put(dx, 0, dz, Blocks.GOLD_INLAID_BRICKS if path and (absi(dx) == 0 or absi(dz) == 0) else (Blocks.CHISELED_BRICKS if path else Blocks.STONE_BRICKS))
	var flowers := [Blocks.POPPY, Blocks.DANDELION, Blocks.CORNFLOWER, Blocks.DAISY, Blocks.BLUEBELL]
	for q in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var x: int = q.x * 7 + dx
				var z: int = q.y * 7 + dz
				put(x, 0, z, Blocks.GRASS)
				if (absi(dx) == 3 or absi(dz) == 3):
					put(x, 1, z, Blocks.OAK_SLAB)   # a little hedge border
				elif dx == 0 and dz == 0:
					put(x, 1, z, Blocks.STONE_PILLAR)
					put(x, 2, z, Blocks.STONE_PILLAR)
					put(x, 3, z, Blocks.LAMP)
				else:
					put(x, 1, z, flowers[posmod(x * 3 + z * 7, flowers.size())])
	# Outer walls with battlements, a gate in the south wall.
	for i in range(-R, R + 1):
		for side in [Vector2i(i, -R), Vector2i(i, R), Vector2i(-R, i), Vector2i(R, i)]:
			for dy in range(1, 9):
				put(side.x, dy, side.y, Blocks.CHISELED_BRICKS if dy == 8 else Blocks.STONE_BRICKS)
			if posmod(i, 2) == 0:
				put(side.x, 9, side.y, Blocks.STONE_BRICKS)
	for dx in range(-1, 2):
		for dy in range(1, 5):
			put(dx, dy, R, Blocks.AIR)
	for gx in [-2, 2]:
		put(gx, 5, R + 1, Blocks.LAMP)
	# Corner towers, with a lamp on top.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					for dy in range(1, 13):
						put(sx * R + dx, dy, sz * R + dz, Blocks.CHISELED_BRICKS if absi(dx) == 2 and absi(dz) == 2 else Blocks.STONE_BRICKS)
					if (dx + dz) % 2 == 0:
						put(sx * R + dx, 13, sz * R + dz, Blocks.STONE_BRICKS)
			put(sx * R, 13, sz * R, Blocks.LAMP)
	# The four wings: plank floors, inner walls with windows and doors, a lit ceiling.
	for dz in range(-R + 1, R):
		for dx in range(-R + 1, R):
			var wing: bool = absi(dx) >= WING or absi(dz) >= WING
			if not wing:
				continue
			var corner: bool = absi(dx) >= WING and absi(dz) >= WING
			put(dx, 0, dz, Blocks.REDWOOD_PLANKS if not corner else Blocks.STONE_BRICKS)
			put(dx, 7, dz, Blocks.LAMP if (posmod(dx, 4) == 0 and posmod(dz, 4) == 0) else Blocks.PLANKS)
			if corner:
				for dy in range(1, 7):
					put(dx, dy, dz, Blocks.STONE_BRICKS)
	for i in range(-WING, WING + 1):
		for side in [Vector2i(i, -WING), Vector2i(i, WING), Vector2i(-WING, i), Vector2i(WING, i)]:
			for dy in range(1, 7):
				var door: bool = absi(i) <= 1 and dy <= 3
				var window: bool = dy == 3 and posmod(i, 3) == 0 and absi(i) > 2 and absi(i) < WING
				put(side.x, dy, side.y, Blocks.AIR if door else (Blocks.GLASS if window else (Blocks.CHISELED_BRICKS if dy == 6 else Blocks.STONE_BRICKS)))
	# The south wing has a passage from the gate to the courtyard.
	for dz in range(WING, R):
		for dy in range(1, 5):
			for dx in range(-1, 2):
				put(dx, dy, dz, Blocks.AIR)
			if dz > WING:
				put(-2, dy, dz, Blocks.STONE_BRICKS)
				put(2, dy, dz, Blocks.STONE_BRICKS)
		put(0, 5, dz, Blocks.LAMP if dz % 3 == 0 else Blocks.STONE_BRICKS)
	# West wing: beds, tables and chairs.
	for bz in [-10, -7, -4, 4, 7, 10]:
		put(-18, 1, bz, Blocks.BED_FOOT, 1)
		put(-19, 1, bz, Blocks.BED, 1)
	for tz in [-1, 1]:
		put(-16, 1, tz * 2, Blocks.OAK_TABLE)
		put(-15, 1, tz * 2, Blocks.OAK_CHAIR, 1)
	put(-17, 1, 0, Blocks.SUPER_CHEST, 3)
	put(-14, 1, 11, Blocks.CAMPFIRE, 0)
	put(-14, 1, -11, Blocks.BEDROLL, 3)
	# South wing: every station along the back wall.
	var stations := [Blocks.WORKBENCH_1, Blocks.WORKBENCH_2, Blocks.WORKBENCH_3, Blocks.FURNACE, Blocks.FURNACE,
			Blocks.FURNACE, Blocks.RESEARCH_TABLE, Blocks.SCRIBE, Blocks.SHOP, Blocks.SAWMILL, Blocks.STONECUTTER,
			Blocks.SHAPER, Blocks.CUTE_CRAFTER, Blocks.SUPER_CHEST]
	var spots := []
	for dx in range(-12, -3, 2):
		spots.append(dx)
	for dx in range(4, 13, 2):
		spots.append(dx)
	for i in mini(stations.size(), spots.size() * 2):
		var row := i / spots.size()
		put(spots[i % spots.size()], 1, R - 1 - row * 3, stations[i], 0)


## Chests, armor stands, item frames and maps (after the blocks are in).
func _fill(peer: int) -> void:
	var maps := _make_map()
	# --- Storeroom (east wing): one stack of everything, sorted into chests.
	var groups := {}
	var order := ["Ores & Metals", "Woods", "Building Blocks", "Stations", "Plants & Flowers", "Saplings",
			"Raw Meat", "Cooked Meat", "Food", "Mob Drops & Loot", "Crafting Bits", "Tools & Weapons",
			"Armor & Capes", "Cute Gear", "Legendary"]
	for id in Items.ITEMS:
		if Items.is_map(id) or id in ["castle_box", "arena_box"] or id == "water_bucket":
			continue
		var g := _category(id)
		if not groups.has(g):
			groups[g] = []
		groups[g].append(id)
	var chest_spots := []
	for dz in range(-12, 13):
		for dy in [1, 2]:
			chest_spots.append([Vector3i(R - 1, dy, dz), 1])
	for dz in range(-12, 13):
		if absi(dz) > 1:
			for dy in [1, 2]:
				chest_spots.append([Vector3i(WING + 1, dy, dz), 3])
	var used := 0
	var all_chests := []
	for g in order + ["Maps"]:
		var ids: Array = groups.get(g, []) if g != "Maps" else []
		var part := 0
		var start := 0
		while start < ids.size() or (g == "Maps" and part == 0):
			if used >= chest_spots.size():
				break
			var slots := Inv.make(sv.CHEST_SIZE)
			if g == "Maps":
				for i in 6:
					slots[i] = maps.duplicate(true)
				slots[6] = {"id": "paper", "count": 64}
				slots[7] = {"id": "party_map", "count": 1}
				start = 1
			else:
				for i in range(start, mini(start + sv.CHEST_SIZE, ids.size())):
					slots[i - start] = {"id": ids[i], "count": Items.max_stack(ids[i])}
				start += sv.CHEST_SIZE
			var spot: Array = chest_spots[used]
			used += 1
			part += 1
			var name: String = g if part == 1 else "%s %d" % [g, part]
			all_chests.append([c + spot[0], spot[1], name, slots])
	var chest_cells := []
	for ch in all_chests:
		chest_cells.append([ch[0], Blocks.CHEST, ch[1]])
	w.server_set_blocks(chest_cells)
	for ch in all_chests:
		sv._chests[ch[0]] = ch[3]
		sv._chest_names[ch[0]] = ch[2]
		sv._receive_chest_name.rpc(ch[0], ch[2])
	# --- Armory (north wing): armor stands and walls of gear.
	var sets := []
	for s in Items.ARMOR_SETS:
		sets.append(["%s_helmet" % s[0], "%s_chestplate" % s[0], "%s_leggings" % s[0], "%s_boots" % s[0]])
	var legend := ["king_crown", "grim_chestplate", "titanium_leggings", "yeti_boots"]
	sets.append(legend)
	sets.append(["cute_titanium_helmet", "cute_titanium_chestplate", "cute_titanium_leggings", "cute_titanium_boots"])
	var capes := []
	for ci in Items.CAPES.size():
		capes.append(Items.cape_id(ci, 3))
	var stand_cells := []
	var stand_x := [-10, -6, -2, 2, 6, 10]
	for i in sets.size():
		stand_cells.append([c + Vector3i(stand_x[i], 1, -16), Blocks.ARMOR_STAND, 2])
	w.server_set_blocks(stand_cells)
	for i in sets.size():
		var pos: Vector3i = c + Vector3i(stand_x[i], 1, -16)
		var slots := Inv.make(5)
		for j in 4:
			if Items.exists(sets[i][j]):
				slots[j] = {"id": sets[i][j], "count": 1}
		slots[4] = {"id": capes[i % capes.size()], "count": 1, "roll": 1.0, "maker": "the Castle"}
		sv._stands[pos] = slots
		sv._send_stand(pos)
	var gear := []
	for id in Items.ITEMS:
		var d := Items.get_def(id)
		if d.get("rarity", "") == "legendary" and not id in ["castle_box", "arena_box"] and not d.has("slot"):
			gear.append(id)
	for id in ["titanium_sword", "titanium_pickaxe", "titanium_axe", "titanium_shovel", "titanium_bow", "iron_bow", "hunting_bow",
			"cute_titanium_sword", "cute_titanium_pickaxe", "cute_titanium_axe", "cute_titanium_shovel", "cute_titanium_bow",
			"iron_sword", "iron_pickaxe", "iron_axe", "bronze_sword", "titanium_arrow", "frost_arrow", "poison_arrow", "silver_arrow"]:
		if Items.exists(id):
			gear.append(id)
	gear.append_array(capes)
	for ci in Items.CAPES.size():
		gear.append(Items.cape_id(ci, 2))
	for id in Items.ITEMS:
		if Items.rarity(id) == "legendary" and Items.get_def(id).has("slot") and not id in gear and not id in legend:
			gear.append(id)
	var frame_spots := []
	for dy in [4, 3, 2]:
		for dx in range(-12, 13):
			frame_spots.append(c + Vector3i(dx, dy, -R + 1))
	var frame_cells := []
	var frames := {}
	for i in mini(gear.size(), frame_spots.size()):
		frame_cells.append([frame_spots[i], Blocks.ITEM_FRAME, 2])
		frames[frame_spots[i]] = {"id": gear[i], "count": 1}
	# --- Maps of the whole area on the courtyard walls (both sides of each door).
	for spot in [Vector3i(-4, 2, -WING + 1), Vector3i(4, 2, -WING + 1), Vector3i(-WING + 1, 2, -4), Vector3i(WING - 1, 2, 4)]:
		var turn := 2
		if spot.x == -WING + 1:
			turn = 3   # on the west wing's wall, facing east
		elif spot.x == WING - 1:
			turn = 1
		frame_cells.append([c + spot, Blocks.ITEM_FRAME, turn])
		frames[c + spot] = maps.duplicate(true)
	w.server_set_blocks(frame_cells)
	for pos in frames:
		sv._frames[pos] = frames[pos]
		sv._send_frame(pos)


## Which storeroom chest an item goes in.
static func _category(id: String) -> String:
	var d := Items.get_def(id)
	if d.get("rarity", "") == "legendary":
		return "Legendary"
	if d.get("cute", false):
		return "Cute Gear"
	if d.has("tool") or d.has("bow") or d.has("arrow"):
		return "Tools & Weapons"
	if d.has("armor") or d.has("cape"):
		return "Armor & Capes"
	if d.get("raw", false):
		return "Raw Meat"
	if d.get("cooked", false):
		return "Cooked Meat"
	if d.has("food"):
		return "Food"
	if id.ends_with("_sapling"):
		return "Saplings"
	if d.get("plant", false):
		return "Plants & Flowers"
	if id.ends_with("_ore") or id.ends_with("_ingot") or id == "coal":
		return "Ores & Metals"
	if d.has("block"):
		var b: int = d["block"]
		if Blocks.is_interactive(b) or b in [Blocks.LAMP, Blocks.TORCH, Blocks.CAMPFIRE]:
			return "Stations"
		if Blocks.IS_WOOD[b] or Blocks.is_log(b) or Blocks.is_leaves(b) or id.contains("planks"):
			return "Woods"
		return "Building Blocks"
	if d.has("ink") or id in ["paper", "glass_bottle", "water_bottle", "bucket", "stick", "glass"]:
		return "Crafting Bits"
	return "Mob Drops & Loot"


## One map of everything within MAP_RADIUS, with every boss and place marked.
func _make_map() -> Dictionary:
	var mid: int = sv._new_map("the Castle Cartographer")
	var m: Dictionary = sv._maps[mid]
	var full := PackedByteArray()
	full.resize(sv.MAP_REGION * sv.MAP_REGION / 8)
	full.fill(255)
	var lo: Vector2i = sv.map_region_of(floori((c.x - MAP_RADIUS) / float(sv.MAP_SCALE)), floori((c.z - MAP_RADIUS) / float(sv.MAP_SCALE)))
	var hi: Vector2i = sv.map_region_of(floori((c.x + MAP_RADIUS) / float(sv.MAP_SCALE)), floori((c.z + MAP_RADIUS) / float(sv.MAP_SCALE)))
	for rz in range(lo.y, hi.y + 1):
		for rx in range(lo.x, hi.x + 1):
			m["regions"][Vector2i(rx, rz)] = full.duplicate()
	var marks: Array = m["marks"]
	var from := Vector2(c.x, c.z)
	var add := func(at: Vector3, kind: String, label: String) -> void:
		if at.y >= 0 and marks.size() < sv.MAP_MAX_MARKS and Vector2(at.x, at.z).distance_to(from) <= MAP_RADIUS:
			marks.append({"x": at.x, "z": at.z, "kind": kind, "label": label.substr(0, 20), "fixed": true})
	add.call(Vector3(c), "house", "Test Castle")
	if sv.shrine_center != sv.NO_POS:
		add.call(Vector3(sv.shrine_center), "house", "Spawn Shrine")
	for l in w.lairs_near(Vector3(c), MAP_RADIUS):
		add.call(Vector3(l["pos"]), "boss", BossData.get_boss(l["boss"]).get("name", l["boss"]))
	add.call(w.find_structure("mineshaft", from, MAP_RADIUS), "boss", "Yeti")
	add.call(w.find_castle(from, MAP_RADIUS), "boss", "Grimskull")
	add.call(w.find_structure("village", from, MAP_RADIUS), "house", "Fairy Village")
	add.call(w.find_shrine(from, MAP_RADIUS), "question", "Cave Shrine")
	var home: Vector3 = sv.main.mobs.npc_home() if sv.main.mobs.has_method("npc_home") else Vector3(0, -1, 0)
	add.call(home, "house", "QtMaMe")
	var sites: Array = w.sites_near(Vector3(c), MAP_RADIUS)
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["entrance"].x, a["entrance"].z).distance_to(from) < Vector2(b["entrance"].x, b["entrance"].z).distance_to(from))
	for s in sites:
		add.call(Vector3(s["entrance"]), "question", "Dungeon" if s["kind"] == "dungeon" else "Grotto")
	return {"id": "map", "count": 1, "map": mid, "maker": "the Castle Cartographer", "label": "Map of Everything", "label_ink": "blue_ink"}
