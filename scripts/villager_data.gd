extends RefCounted
## Villagers: every biome has its own folk living in little camps built from
## that biome's blocks (see world.gd camps). They sell things for toots: stuff
## from their land, priced by how hard the land is, and now and then a
## surprise (gear, a weapon, a tool or a rare crafting material).

const Blocks = preload("res://scripts/blocks.gd")

## danger: 0 easy lands .. 3 the floating islands (better stock, better surprises).
## mats: the camp's blocks. stock: [item, how many they have each day].
const TRIBES := {
	"plains": {"name": "Meadowfolk", "one": "Meadowfolk Farmer", "danger": 0,
		"hello": "Howdy! Fresh from the fields. Take a look!",
		"skin": Color(0.96, 0.8, 0.66), "cloth": Color(0.45, 0.62, 0.3), "cloth2": Color(0.6, 0.42, 0.25), "look": "farmer",
		"mats": {"wall": Blocks.PLANKS, "floor": Blocks.COBBLESTONE, "roof": Blocks.HAY_BALE, "trim": Blocks.LOG, "light": Blocks.LAMP, "fence": "oak"},
		"stock": [["cooked_pork", 6], ["cooked_chicken", 6], ["wool", 8], ["leather", 4], ["oak_sapling", 3], ["poppy", 4], ["dandelion", 4], ["daisy", 4], ["feather", 8], ["bucket", 1], ["hunting_bow", 1], ["wooden_arrow", 16]]},
	"forest": {"name": "Wood Elves", "one": "Wood Elf", "danger": 0,
		"hello": "Welcome, traveller. The forest provides, and so do we.",
		"skin": Color(0.92, 0.86, 0.72), "cloth": Color(0.18, 0.45, 0.26), "cloth2": Color(0.55, 0.42, 0.2), "look": "elf",
		"mats": {"wall": Blocks.REDWOOD_PLANKS, "floor": Blocks.REDWOOD_PLANKS, "roof": Blocks.LEAVES, "trim": Blocks.REDWOOD_LOG, "light": Blocks.LAMP, "fence": "redwood"},
		"stock": [["redwood_sapling", 3], ["redwood_log", 16], ["feather", 8], ["wooden_arrow", 24], ["bronze_arrow", 12], ["hunting_bow", 1], ["iron_bow", 1], ["bluebell", 4], ["cornflower", 4], ["cooked_venison", 6], ["spider_silk", 4]]},
	"desert": {"name": "Sand Lizardfolk", "one": "Lizardfolk Trader", "danger": 1,
		"hello": "Sssso, you crossed the sands! Gold, sandstone, ssspices...",
		"skin": Color(0.45, 0.68, 0.32), "cloth": Color(0.88, 0.72, 0.42), "cloth2": Color(0.75, 0.3, 0.2), "look": "lizard",
		"mats": {"wall": Blocks.SANDSTONE, "floor": Blocks.SANDSTONE, "roof": Blocks.PALM_PLANKS, "trim": Blocks.CARVED_SANDSTONE, "light": Blocks.LAMP, "fence": "sandstone"},
		"stock": [["sandstone", 32], ["cactus", 8], ["cactus_flower", 4], ["palm_sapling", 3], ["gold_ingot", 3], ["sand_bear_pelt", 1], ["cougar_pelt", 1], ["silver_ingot", 3], ["poison_arrow", 8]]},
	"candy": {"name": "Gingerbread Folk", "one": "Gingerbread Baker", "danger": 0,
		"hello": "Hello, sweetie! Everything here is extra tasty today!",
		"skin": Color(0.72, 0.44, 0.22), "cloth": Color(1.0, 0.6, 0.8), "cloth2": Color(0.98, 0.97, 0.95), "look": "ginger",
		"mats": {"wall": Blocks.CAKE, "floor": Blocks.CANDY_PLANKS, "roof": Blocks.FROSTING, "trim": Blocks.CANDY_CANE, "light": Blocks.LAMP, "fence": "candy"},
		"stock": [["cotton_candy", 12], ["candy_cane", 12], ["gummy", 8], ["marshmallow", 8], ["lollipop", 4], ["candy_tulip", 4], ["candy_sapling", 2], ["cutieite_ingot", 1], ["peppermint", 4]]},
	"mountain": {"name": "Mountain Dwarves", "one": "Dwarf Smith", "danger": 2,
		"hello": "Hah! A customer! Best iron under the mountain, this.",
		"skin": Color(0.95, 0.75, 0.62), "cloth": Color(0.42, 0.25, 0.18), "cloth2": Color(0.6, 0.62, 0.66), "look": "dwarf",
		"mats": {"wall": Blocks.STONE_BRICKS, "floor": Blocks.COBBLESTONE, "roof": Blocks.PINE_PLANKS, "trim": Blocks.PINE_LOG, "light": Blocks.LAMP, "fence": "stone_brick"},
		"stock": [["iron_ingot", 6], ["copper_ingot", 8], ["tin_ingot", 8], ["coal", 16], ["iron_pickaxe", 1], ["iron_axe", 1], ["iron_shovel", 1], ["iron_helmet", 1], ["polar_bear_pelt", 1], ["hare_fur", 4], ["edelweiss", 3], ["titanium_ore", 2]]},
	"fall": {"name": "Fox Folk", "one": "Fox Folk Peddler", "danger": 1,
		"hello": "Psst! Got some lovely things. Fair prices. Mostly.",
		"skin": Color(0.92, 0.5, 0.2), "cloth": Color(0.55, 0.25, 0.15), "cloth2": Color(0.95, 0.85, 0.55), "look": "fox",
		"mats": {"wall": Blocks.MAPLE_PLANKS, "floor": Blocks.MAPLE_PLANKS, "roof": Blocks.MAPLE_LEAVES, "trim": Blocks.MAPLE_LOG, "light": Blocks.JACK_O_LANTERN, "fence": "maple"},
		"stock": [["pumpkin_pie", 6], ["pumpkin", 6], ["acorn", 12], ["fox_fur", 2], ["maple_sapling", 3], ["golden_sapling", 1], ["hay_bale", 8], ["candy_corn", 8], ["bronze_sword", 1]]},
	"spooky": {"name": "Spider Folk", "one": "Spider Folk Weaver", "danger": 2,
		"hello": "Ssshhh... come in, come in. We spin the finest silk.",
		"skin": Color(0.22, 0.18, 0.26), "cloth": Color(0.38, 0.2, 0.45), "cloth2": Color(0.85, 0.85, 0.9), "look": "spider",
		"mats": {"wall": Blocks.DEAD_PLANKS, "floor": Blocks.COBBLESTONE, "roof": Blocks.DEAD_PLANKS, "trim": Blocks.DEAD_LOG, "light": Blocks.GHOST_LANTERN, "fence": "dead"},
		"stock": [["spider_silk", 12], ["venom_sac", 4], ["ectoplasm", 4], ["candy_corn", 8], ["bone", 12], ["witch_hat", 1], ["glowshroom", 6], ["poison_arrow", 16], ["ancient_coin", 2]]},
	"sky": {"name": "Sky Folk", "one": "Sky Folk Merchant", "danger": 3,
		"hello": "Few climb this high. Our treasures are worth the trip.",
		"skin": Color(0.9, 0.92, 1.0), "cloth": Color(0.4, 0.55, 0.95), "cloth2": Color(1.0, 0.85, 0.35), "look": "bird",
		"mats": {"wall": Blocks.WHITE_MARBLE, "floor": Blocks.GOLD_INLAID_BRICKS, "roof": Blocks.MARBLE_BRICKS, "trim": Blocks.CHISELED_BRICKS, "light": Blocks.LAMP, "fence": "gold"},
		"stock": [["titanium_ingot", 4], ["gold_ingot", 6], ["frost_arrow", 16], ["titanium_arrow", 16], ["feather", 16], ["ancient_coin", 4], ["titanium_bow", 1], ["silver_ingot", 6]]},
	"chess": {"name": "Boardroom Bankers", "one": "Banker", "danger": 2,
		"hello": "Good day! Everything's for sale, if the price is right. Let's do business.",
		"skin": Color(0.95, 0.82, 0.7), "cloth": Color(0.15, 0.15, 0.2), "cloth2": Color(0.85, 0.1, 0.15), "look": "suit",
		"mats": {"wall": Blocks.MARBLE_BRICKS, "floor": Blocks.CHECKER_TILE, "roof": Blocks.ONYX_BRICKS, "trim": Blocks.GOLD_BLOCK, "light": Blocks.LAMP, "fence": "gold"},
		"stock": [["gold_ingot", 6], ["paper", 16], ["map", 1], ["white_marble", 16], ["black_onyx", 16], ["checker_tile", 8], ["gold_ring", 1], ["silver_ring", 1], ["blue_ink", 3], ["ancient_coin", 3]]},
	"fastfood": {"name": "Fry Cooks", "one": "Fry Cook", "danger": 2,
		"hello": "Welcome! Can I take your order? Today's special: everything!",
		"skin": Color(0.98, 0.84, 0.72), "cloth": Color(0.95, 0.95, 0.95), "cloth2": Color(0.9, 0.15, 0.15), "look": "chef",
		"mats": {"wall": Blocks.CIRCUS_STRIPES, "floor": Blocks.SESAME_BUN, "roof": Blocks.FRY_BOX, "trim": Blocks.GOLD_BLOCK, "light": Blocks.LAMP, "fence": "gold"},
		"stock": [["french_fries", 12], ["chicken_nugget", 12], ["cooked_pork", 6], ["cooked_bear", 4], ["toy_prize", 3], ["pumpkin_pie", 4], ["sesame_bun", 16]]},
}

## The surprise a villager might have today, by how hard their land is.
const SURPRISES := [
	["bronze_sword", "bronze_pickaxe", "bronze_axe", "bronze_helmet", "bronze_chestplate", "leather_boots", "iron_bow", "cutieite_ingot"],
	["iron_sword", "iron_pickaxe", "iron_chestplate", "iron_leggings", "iron_bow", "silver_arrow", "cutieite_ingot", "titanium_ore"],
	["titanium_sword", "titanium_pickaxe", "iron_chestplate", "titanium_helmet", "titanium_boots", "gold_ring", "silver_amulet", "titanium_ingot"],
	["titanium_sword", "titanium_chestplate", "titanium_leggings", "titanium_bow", "gold_amulet", "silver_ring", "cute_titanium_sword", "cutieite_ingot"],
]
const SURPRISE_CHANCE := 0.45
const PRICE_MARKUP := 2.2


static func tribe(biome: String) -> Dictionary:
	return TRIBES.get(biome, TRIBES["plains"])


static func mob_type(biome: String) -> String:
	return "villager_" + (biome if TRIBES.has(biome) else "plains")


## A villager's look: a person built from boxes, with their tribe's touches.
static func parts(biome: String) -> Array:
	var t: Dictionary = tribe(biome)
	var skin: Color = t["skin"]
	var c1: Color = t["cloth"]
	var c2: Color = t["cloth2"]
	var look: String = t["look"]
	var k := 0.78 if look == "dwarf" else (1.08 if look == "elf" else 1.0)   # dwarves are short, elves tall
	var w := 1.2 if look == "dwarf" else 1.0
	var eye := Color(0.1, 0.1, 0.12)
	var out := [
		{"size": Vector3(0.2 * w, 0.68 * k, 0.22), "pos": Vector3(-0.12 * w, 0.34 * k, 0), "color": c2.darkened(0.3), "leg": true},
		{"size": Vector3(0.2 * w, 0.68 * k, 0.22), "pos": Vector3(0.12 * w, 0.34 * k, 0), "color": c2.darkened(0.3), "leg": true},
		{"size": Vector3(0.5 * w, 0.66 * k, 0.28), "pos": Vector3(0, 1.0 * k, 0), "color": c1},
		{"size": Vector3(0.14, 0.6 * k, 0.16), "pos": Vector3(-0.33 * w, 1.02 * k, 0), "color": c1.darkened(0.12)},
		{"size": Vector3(0.14, 0.6 * k, 0.16), "pos": Vector3(0.33 * w, 1.02 * k, 0), "color": c1.darkened(0.12)},
		{"size": Vector3(0.44, 0.44, 0.42), "pos": Vector3(0, 1.56 * k, 0), "color": skin, "head": true},
		{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(-0.1, 1.6 * k, -0.215), "color": eye, "head": true},
		{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(0.1, 1.6 * k, -0.215), "color": eye, "head": true},
		{"size": Vector3(0.14, 0.03, 0.02), "pos": Vector3(0, 1.46 * k, -0.215), "color": skin.darkened(0.35), "head": true},
		{"size": Vector3(0.52 * w, 0.06, 0.3), "pos": Vector3(0, 0.7 * k, 0), "color": c2},   # belt
	]
	var hy := 1.56 * k
	match look:
		"farmer":
			out.append({"size": Vector3(0.72, 0.05, 0.72), "pos": Vector3(0, hy + 0.24, 0), "color": Color(0.9, 0.78, 0.4), "head": true})   # straw hat
			out.append({"size": Vector3(0.36, 0.14, 0.36), "pos": Vector3(0, hy + 0.32, 0), "color": Color(0.9, 0.78, 0.4), "head": true})
		"elf":
			for sx in [-1.0, 1.0]:
				out.append({"size": Vector3(0.06, 0.1, 0.2), "pos": Vector3(sx * 0.25, hy + 0.06, 0.02), "color": skin, "head": true})   # pointy ears
				out.append({"size": Vector3(0.05, 0.08, 0.12), "pos": Vector3(sx * 0.27, hy + 0.16, 0.06), "color": skin, "head": true})
			out.append({"size": Vector3(0.48, 0.18, 0.48), "pos": Vector3(0, hy + 0.27, 0.02), "color": Color(0.85, 0.75, 0.35), "head": true})   # golden hair
			out.append({"size": Vector3(0.46, 0.5, 0.08), "pos": Vector3(0, hy - 0.05, 0.22), "color": Color(0.85, 0.75, 0.35), "head": true})
		"lizard":
			out.append({"size": Vector3(0.3, 0.18, 0.22), "pos": Vector3(0, hy - 0.06, -0.3), "color": skin.darkened(0.08), "head": true})   # snout
			out.append({"size": Vector3(0.06, 0.05, 0.02), "pos": Vector3(-0.1, 1.6 * k, -0.22), "color": Color(1.0, 0.85, 0.2), "head": true})
			out.append({"size": Vector3(0.12, 0.12, 0.6), "pos": Vector3(0, 0.6 * k, 0.42), "color": skin, "leg": false})   # tail
			for i in 3:
				out.append({"size": Vector3(0.06, 0.1, 0.08), "pos": Vector3(0, hy + 0.26 - i * 0.02, 0.05 + i * 0.12), "color": Color(0.9, 0.4, 0.2), "head": true})   # frills
		"ginger":
			for b in [0.86, 1.02, 1.18]:
				out.append({"size": Vector3(0.07, 0.07, 0.02), "pos": Vector3(0, b * k, -0.145), "color": Color(1.0, 0.3, 0.45)})   # gumdrop buttons
			out.append({"size": Vector3(0.36, 0.04, 0.02), "pos": Vector3(0, hy + 0.12, -0.215), "color": Color(0.98, 0.97, 0.95), "head": true})   # icing
			out.append({"size": Vector3(0.36, 0.3, 0.36), "pos": Vector3(0, hy + 0.36, 0), "color": Color(0.98, 0.97, 0.95), "head": true})   # chef's hat
		"dwarf":
			out.append({"size": Vector3(0.4, 0.34, 0.1), "pos": Vector3(0, hy - 0.2, -0.22), "color": Color(0.75, 0.38, 0.18), "head": true})   # big beard
			out.append({"size": Vector3(0.26, 0.2, 0.08), "pos": Vector3(0, hy - 0.44, -0.2), "color": Color(0.75, 0.38, 0.18), "head": true})
			out.append({"size": Vector3(0.5, 0.16, 0.5), "pos": Vector3(0, hy + 0.27, 0), "color": Color(0.62, 0.62, 0.66), "head": true})   # iron helm
			out.append({"size": Vector3(0.06, 0.18, 0.06), "pos": Vector3(-0.22, hy + 0.4, 0), "color": Color(0.95, 0.92, 0.85), "head": true})   # horns
			out.append({"size": Vector3(0.06, 0.18, 0.06), "pos": Vector3(0.22, hy + 0.4, 0), "color": Color(0.95, 0.92, 0.85), "head": true})
		"fox":
			for sx in [-1.0, 1.0]:
				out.append({"size": Vector3(0.12, 0.18, 0.06), "pos": Vector3(sx * 0.14, hy + 0.3, 0), "color": skin, "head": true})   # fox ears
			out.append({"size": Vector3(0.18, 0.12, 0.16), "pos": Vector3(0, hy - 0.08, -0.28), "color": Color(0.98, 0.95, 0.9), "head": true})   # white snout
			out.append({"size": Vector3(0.06, 0.05, 0.03), "pos": Vector3(0, hy - 0.04, -0.37), "color": Color(0.1, 0.08, 0.08), "head": true})
			out.append({"size": Vector3(0.22, 0.22, 0.6), "pos": Vector3(0, 0.6 * k, 0.4), "color": skin})   # bushy tail
			out.append({"size": Vector3(0.18, 0.18, 0.16), "pos": Vector3(0, 0.62 * k, 0.74), "color": Color(0.98, 0.95, 0.9)})
		"spider":
			for i in 4:
				out.append({"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.15 + i * 0.1, 1.68 * k, -0.215), "color": Color(0.9, 0.15, 0.2), "head": true, "glow": true})   # lots of eyes
			for sx in [-1.0, 1.0]:
				for j in 2:
					out.append({"size": Vector3(0.5, 0.08, 0.08), "pos": Vector3(sx * 0.5, (0.86 + j * 0.24) * k, 0.06), "color": skin})   # extra arms
		"bird":
			out.append({"size": Vector3(0.14, 0.1, 0.18), "pos": Vector3(0, hy - 0.04, -0.3), "color": Color(1.0, 0.75, 0.25), "head": true})   # beak
			out.append({"size": Vector3(0.1, 0.24, 0.3), "pos": Vector3(0, hy + 0.3, 0.05), "color": c1, "head": true})   # crest
			for sx in [-1.0, 1.0]:
				out.append({"size": Vector3(0.08, 0.5, 0.36), "pos": Vector3(sx * 0.36, 1.05 * k, 0.12), "color": Color(0.95, 0.95, 1.0)})   # wings
		"suit":
			out.append({"size": Vector3(0.08, 0.36, 0.02), "pos": Vector3(0, 1.06 * k, -0.145), "color": c2})   # red tie
			out.append({"size": Vector3(0.22, 0.4, 0.02), "pos": Vector3(0, 1.08 * k, -0.142), "color": Color(0.96, 0.96, 0.96)})   # shirt
			out.append({"size": Vector3(0.46, 0.08, 0.44), "pos": Vector3(0, hy + 0.24, 0), "color": Color(0.1, 0.1, 0.12), "head": true})   # top hat brim
			out.append({"size": Vector3(0.32, 0.3, 0.3), "pos": Vector3(0, hy + 0.42, 0), "color": Color(0.1, 0.1, 0.12), "head": true})
			out.append({"size": Vector3(0.1, 0.3, 0.36), "pos": Vector3(0.42, 0.66 * k, -0.06), "color": Color(0.35, 0.22, 0.12)})   # briefcase
		"chef":
			out.append({"size": Vector3(0.4, 0.1, 0.4), "pos": Vector3(0, hy + 0.26, 0), "color": Color(0.98, 0.98, 0.98), "head": true})
			out.append({"size": Vector3(0.46, 0.3, 0.46), "pos": Vector3(0, hy + 0.44, 0), "color": Color(0.98, 0.98, 0.98), "head": true})   # puffy hat
			out.append({"size": Vector3(0.52, 0.4, 0.02), "pos": Vector3(0, 0.92 * k, -0.15), "color": c2})   # red apron
			out.append({"size": Vector3(0.2, 0.04, 0.02), "pos": Vector3(0, hy - 0.02, -0.216), "color": Color(0.35, 0.22, 0.12), "head": true})   # moustache
	return out
