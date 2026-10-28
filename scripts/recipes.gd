extends RefCounted
## Crafting recipes, smelting, fuel, and item values.
##
## Rust-style crafting:
## - "station": 0 = craft anywhere (starter recipes, always known and free).
##   1/2/3 = needs a workbench of that tier or higher nearby.
## - "cost": toots you pay ONCE to unlock the recipe (per player).
##   After that you only pay the materials ("in") every time you craft.
## - Higher tiers cost more toots and need rarer materials.
##
## Values: an item crafted or smelted is worth CRAFT_VALUE_SHARE (90%) of what
## went into it, so turning things into other things never creates toots.

const Items = preload("res://scripts/items.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Inv = preload("res://scripts/inventory.gd")

const CRAFT_VALUE_SHARE := 0.9
const SMELT_SECONDS := 4.0
## Cooked meat is worth a little more than raw: +12%, but never more than
## COOK_BONUS_MAX toots, which is less than the cheapest fuel needed to cook
## one piece. So cooking makes food better, but can't be used to make toots.
const COOK_BONUS := 0.12
const COOK_BONUS_MAX := 0.3

static var RECIPES := [
	# --- By hand (free, always unlocked) --------------------------------------------
	{"out": "planks", "count": 4, "station": 0, "cost": 0, "in": {"log": 1}, "exact": true},
	{"out": "redwood_planks", "count": 4, "station": 0, "cost": 0, "in": {"redwood_log": 1}},
	{"out": "pine_planks", "count": 4, "station": 0, "cost": 0, "in": {"pine_log": 1}},
	{"out": "palm_planks", "count": 4, "station": 0, "cost": 0, "in": {"palm_log": 1}},
	{"out": "candy_planks", "count": 4, "station": 0, "cost": 0, "in": {"candy_cane": 1}},
	{"out": "maple_planks", "count": 4, "station": 0, "cost": 0, "in": {"maple_log": 1}},
	{"out": "dead_planks", "count": 4, "station": 0, "cost": 0, "in": {"dead_log": 1}},
	{"out": "jack_o_lantern", "count": 1, "station": 0, "cost": 0, "in": {"pumpkin": 1, "torch": 1}},
	{"out": "pumpkin_pie", "count": 1, "station": 0, "cost": 0, "in": {"pumpkin": 1, "cake": 1}},
	{"out": "stick", "count": 4, "station": 0, "cost": 0, "in": {"planks": 2}},
	{"out": "wooden_pickaxe", "count": 1, "station": 0, "cost": 0, "in": {"planks": 3, "stick": 2}},
	{"out": "wooden_axe", "count": 1, "station": 0, "cost": 0, "in": {"planks": 3, "stick": 2}},
	{"out": "wooden_sword", "count": 1, "station": 0, "cost": 0, "in": {"planks": 2, "stick": 1}},
	{"out": "workbench_1", "count": 1, "station": 0, "cost": 0, "in": {"planks": 12, "log": 4}},
	{"out": "torch", "count": 2, "station": 0, "cost": 0, "in": {"stick": 1, "planks": 1}},
	{"out": "campfire", "count": 1, "station": 0, "cost": 0, "in": {"log": 2, "stick": 3, "cobblestone": 3}},
	{"out": "bedroll", "count": 1, "station": 0, "cost": 0, "in": {"wool": 2, "leather": 1}},

	# --- Workbench Tier 1: stone tools, basic blocks, copper & tin ---------------------
	{"out": "research_table", "count": 1, "station": 1, "cost": 0, "auto": true, "in": {"planks": 8, "stick": 4, "cobblestone": 2}},
	{"out": "shop", "count": 1, "station": 1, "cost": 0, "auto": true, "in": {"planks": 8, "log": 2}},
	{"out": "furnace", "count": 1, "station": 1, "cost": 8, "in": {"cobblestone": 10}},
	{"out": "stone_pickaxe", "count": 1, "station": 1, "cost": 6, "in": {"cobblestone": 3, "stick": 2}},
	{"out": "stone_axe", "count": 1, "station": 1, "cost": 6, "in": {"cobblestone": 3, "stick": 2}},
	{"out": "stone_sword", "count": 1, "station": 1, "cost": 8, "in": {"cobblestone": 2, "stick": 1}},
	{"out": "chest", "count": 1, "station": 1, "cost": 4, "in": {"planks": 8}},
	{"out": "bed", "count": 1, "station": 1, "cost": 10, "in": {"planks": 3, "wool": 3}},
	{"out": "wooden_door", "count": 1, "station": 1, "cost": 6, "in": {"planks": 6}},
	{"out": "leather_helmet", "count": 1, "station": 1, "cost": 6, "in": {"leather": 3}},
	{"out": "leather_chestplate", "count": 1, "station": 1, "cost": 10, "in": {"leather": 5, "rabbit_hide": 2}},
	{"out": "leather_leggings", "count": 1, "station": 1, "cost": 8, "in": {"leather": 4}},
	{"out": "leather_boots", "count": 1, "station": 1, "cost": 5, "in": {"leather": 2, "rabbit_hide": 1}},
	{"out": "lamp", "count": 2, "station": 1, "cost": 15, "in": {"glass": 1, "copper_ingot": 1, "planks": 2}},
	{"out": "bronze_ingot", "count": 2, "station": 1, "cost": 20, "in": {"copper_ingot": 1, "tin_ingot": 1}},
	{"out": "bronze_pickaxe", "count": 1, "station": 1, "cost": 30, "in": {"bronze_ingot": 3, "stick": 2}},
	{"out": "bronze_axe", "count": 1, "station": 1, "cost": 30, "in": {"bronze_ingot": 3, "stick": 2}},
	{"out": "bronze_sword", "count": 1, "station": 1, "cost": 35, "in": {"bronze_ingot": 2, "stick": 1}},
	{"out": "bronze_helmet", "count": 1, "station": 1, "cost": 20, "in": {"bronze_ingot": 3}},
	{"out": "bronze_chestplate", "count": 1, "station": 1, "cost": 35, "in": {"bronze_ingot": 6, "leather": 1}},
	{"out": "bronze_leggings", "count": 1, "station": 1, "cost": 30, "in": {"bronze_ingot": 5}},
	{"out": "bronze_boots", "count": 1, "station": 1, "cost": 15, "in": {"bronze_ingot": 2}},
	{"out": "paper", "count": 1, "station": 1, "cost": 3, "in": {"grass_tuft": 3}},
	{"out": "glass_bottle", "count": 2, "station": 1, "cost": 4, "in": {"glass": 1}},
	{"out": "scribe", "count": 1, "station": 1, "cost": 10, "in": {"planks": 6, "paper": 3, "black_ink": 1}},
	{"out": "item_frame", "count": 1, "station": 1, "cost": 3, "in": {"stick": 8, "leather": 1}},
	{"out": "armor_stand", "count": 1, "station": 1, "cost": 6, "in": {"planks": 2, "stick": 6, "cobblestone": 1}},
	{"out": "black_ink", "count": 1, "station": 1, "cost": 3, "in": {"coal": 1, "water_bottle": 1}},
	{"out": "red_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "poppy": 1}},
	{"out": "yellow_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "dandelion": 1}},
	{"out": "blue_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "cornflower": 1}},
	{"out": "white_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "daisy": 1}},
	{"out": "purple_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "bluebell": 1}},
	{"out": "pink_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "cactus_flower": 1}},
	{"out": "green_ink", "count": 1, "station": 1, "cost": 5, "in": {"coal": 1, "water_bottle": 1, "grass_tuft": 1}},
	{"out": "bucket", "count": 1, "station": 2, "cost": 25, "in": {"iron_ingot": 3}},
	{"out": "workbench_2", "count": 1, "station": 1, "cost": 60, "in": {"planks": 10, "cobblestone": 10, "bronze_ingot": 6}},

	# --- Workbench Tier 2: iron & silver -------------------------------------------------
	{"out": "iron_pickaxe", "count": 1, "station": 2, "cost": 90, "in": {"iron_ingot": 3, "stick": 2}},
	{"out": "iron_axe", "count": 1, "station": 2, "cost": 90, "in": {"iron_ingot": 3, "stick": 2}},
	{"out": "iron_sword", "count": 1, "station": 2, "cost": 100, "in": {"iron_ingot": 2, "silver_ingot": 1, "stick": 1}},
	{"out": "iron_door", "count": 1, "station": 2, "cost": 50, "in": {"iron_ingot": 6}},
	{"out": "iron_helmet", "count": 1, "station": 2, "cost": 60, "in": {"iron_ingot": 3}},
	{"out": "iron_chestplate", "count": 1, "station": 2, "cost": 110, "in": {"iron_ingot": 6, "wolf_pelt": 1}},
	{"out": "iron_leggings", "count": 1, "station": 2, "cost": 90, "in": {"iron_ingot": 5}},
	{"out": "iron_boots", "count": 1, "station": 2, "cost": 45, "in": {"iron_ingot": 2}},
	{"out": "map", "count": 1, "station": 2, "cost": 40, "in": {"paper": 8}},
	{"out": "super_chest", "count": 1, "station": 2, "cost": 60, "in": {"chest": 1, "gold_ingot": 1, "ancient_coin": 3}},
	{"out": "party_map", "count": 1, "station": 3, "cost": 120, "in": {"paper": 8, "gold_ingot": 1, "blue_ink": 1}},
	{"out": "workbench_3", "count": 1, "station": 2, "cost": 220, "in": {"planks": 10, "iron_ingot": 10, "silver_ingot": 6}},

	# --- Workbench Tier 3: titanium & gold ----------------------------------------------
	{"out": "titanium_pickaxe", "count": 1, "station": 3, "cost": 320, "in": {"titanium_ingot": 3, "stick": 2}},
	{"out": "titanium_axe", "count": 1, "station": 3, "cost": 320, "in": {"titanium_ingot": 3, "stick": 2}},
	{"out": "titanium_sword", "count": 1, "station": 3, "cost": 380, "in": {"titanium_ingot": 2, "gold_ingot": 1, "stick": 1}},
	{"out": "titanium_door", "count": 1, "station": 3, "cost": 180, "in": {"titanium_ingot": 6}},
	{"out": "titanium_helmet", "count": 1, "station": 3, "cost": 220, "in": {"titanium_ingot": 3, "gold_ingot": 1}},
	{"out": "titanium_chestplate", "count": 1, "station": 3, "cost": 400, "in": {"titanium_ingot": 6, "gold_ingot": 2, "sand_bear_pelt": 1}},
	{"out": "titanium_leggings", "count": 1, "station": 3, "cost": 300, "in": {"titanium_ingot": 5, "gold_ingot": 1}},
	{"out": "titanium_boots", "count": 1, "station": 3, "cost": 160, "in": {"titanium_ingot": 2, "gold_ingot": 1}},
	{"out": "gold_block", "count": 1, "station": 3, "cost": 150, "in": {"gold_ingot": 9}},
	# Rings and amulets: small powers you wear next to your armor.
	{"out": "gold_ring", "count": 1, "station": 3, "cost": 180, "in": {"gold_ingot": 3, "ancient_coin": 2}},
	{"out": "silver_ring", "count": 1, "station": 3, "cost": 180, "in": {"silver_ingot": 3, "ancient_coin": 2}},
	{"out": "gold_amulet", "count": 1, "station": 3, "cost": 200, "in": {"gold_ingot": 3, "spider_silk": 3, "ancient_coin": 1}},
	{"out": "silver_amulet", "count": 1, "station": 3, "cost": 200, "in": {"silver_ingot": 3, "spider_silk": 3, "ancient_coin": 1}},
]

## Furnace: input item -> output item (one at a time, SMELT_SECONDS each).
static var SMELTING := {
	"copper_ore": "copper_ingot",
	"tin_ore": "tin_ingot",
	"iron_ore": "iron_ingot",
	"silver_ore": "silver_ingot",
	"titanium_ore": "titanium_ingot",
	"gold_ore": "gold_ingot",
	"cutie_ore": "cutieite_ingot",
	"sand": "glass",
}


## How many Cutieite Ingots it costs to make this cute: 1, 2 or 3 by the
## workbench tier its recipe needs (plus the item itself).
static func cute_cost(id: String) -> int:
	var r := get_recipe(id)
	return clampi(int(r.get("station", 1)) if not r.is_empty() else 1, 1, 3)


static func _static_init() -> void:
	for m in Items.MEATS:
		SMELTING["raw_" + m[0]] = "cooked_" + m[0]
	RECIPES.append_array(GEAR_RECIPES)
	for r in BUILD_RECIPES:
		var e: Dictionary = r.duplicate(true)
		if e.has("bench"):
			e["station"] = 0
			e["cost"] = 0
		RECIPES.append(e)
	# A fence (or wall) and a wedge for every material that has a slab, at the
	# same bench, from the same thing.
	for fi in Blocks.FAMILIES.size():
		var slab_id: String = Blocks.FAMILIES[fi][0] + "_slab"
		for r in BUILD_RECIPES:
			if r["out"] != slab_id:
				continue
			var input: String = r["in"].keys()[0]
			var wood: bool = Blocks.FAMILIES[fi][6]
			var fence := {"out": Blocks.fence_item(fi), "count": 3, "station": 0, "cost": 0, "bench": r["bench"],
					"in": {input: 2, "stick": 2} if wood else {input: 3}}
			var wedge := {"out": Blocks.wedge_item(fi), "count": 3, "station": 0, "cost": 0, "bench": r["bench"], "in": {input: 2}}
			for e in [fence, wedge]:
				if r.get("exact", false):
					e["exact"] = true
				RECIPES.append(e)
	# Capes: wool and the flower that picks the color. Better benches make
	# better capes, with extra things from that flower's part of the world.
	for ci in Items.CAPES.size():
		var cd: Array = Items.CAPES[ci]
		RECIPES.append({"out": Items.cape_id(ci, 1), "count": 1, "station": 1, "cost": 8, "in": {"wool": 3, cd[0]: 2}})
		RECIPES.append({"out": Items.cape_id(ci, 2), "count": 1, "station": 2, "cost": 40,
				"in": {"wool": 4, cd[0]: 3, cd[4]: 2, "spider_silk": 2}})
		RECIPES.append({"out": Items.cape_id(ci, 3), "count": 1, "station": 3, "cost": 150,
				"in": {"wool": 4, cd[0]: 4, cd[5]: 1, "gold_ingot": 1}})


## The building benches themselves: each one unlocks at its workbench tier.
## Things made at them ("bench": ...) are free to make once you have the bench.
const BUILD_RECIPES := [
	{"out": "sawmill", "count": 1, "station": 1, "cost": 15, "in": {"planks": 8, "log": 2, "copper_ingot": 1}},
	{"out": "ghost_lantern", "count": 2, "station": 2, "cost": 30, "in": {"ectoplasm": 2, "glass": 1, "iron_ingot": 1}},
	{"out": "cute_crafter", "count": 1, "station": 1, "cost": 25, "in": {"candy_cane": 4, "cotton_candy": 4, "cutieite_ingot": 3}},
	{"out": "stonecutter", "count": 1, "station": 2, "cost": 45, "in": {"cobblestone": 12, "iron_ingot": 2}},
	{"out": "shaper", "count": 1, "station": 3, "cost": 120, "in": {"iron_ingot": 6, "titanium_ingot": 1, "stone_bricks": 4}},
	# The Jewelry Station: Cinderstone (where water meets lava) and one of each gem from the Deep.
	{"out": "jewelry_station", "count": 1, "station": 3, "cost": 250,
			"in": {"cinderstone": 4, "ruby": 1, "sapphire": 1, "diamond": 1, "onyx_gem": 1, "amethyst": 1, "gold_ingot": 2}},
	{"out": "ruby_ring", "count": 1, "bench": "jewelry", "in": {"silver_ingot": 2, "ruby": 1}},
	{"out": "ruby_amulet", "count": 1, "bench": "jewelry", "in": {"gold_ingot": 2, "ruby": 2}},
	{"out": "sapphire_ring", "count": 1, "bench": "jewelry", "in": {"silver_ingot": 2, "sapphire": 1}},
	{"out": "sapphire_amulet", "count": 1, "bench": "jewelry", "in": {"gold_ingot": 2, "sapphire": 2}},
	{"out": "amethyst_ring", "count": 1, "bench": "jewelry", "in": {"silver_ingot": 2, "amethyst": 1}},
	{"out": "amethyst_amulet", "count": 1, "bench": "jewelry", "in": {"gold_ingot": 2, "amethyst": 2}},
	{"out": "diamond_ring", "count": 1, "bench": "jewelry", "in": {"gold_ingot": 2, "diamond": 1}},
	{"out": "diamond_amulet", "count": 1, "bench": "jewelry", "in": {"gold_ingot": 3, "diamond": 2}},
	{"out": "onyx_ring", "count": 1, "bench": "jewelry", "in": {"titanium_ingot": 2, "onyx_gem": 1}},
	{"out": "onyx_amulet", "count": 1, "bench": "jewelry", "in": {"titanium_ingot": 2, "gold_ingot": 1, "onyx_gem": 2}},
	{"out": "oak_slab", "count": 2, "bench": "sawmill", "in": {"planks": 1}},
	{"out": "oak_stairs", "count": 2, "bench": "sawmill", "in": {"planks": 3}},
	{"out": "oak_column", "count": 1, "bench": "sawmill", "in": {"planks": 2}},
	{"out": "oak_table", "count": 1, "bench": "sawmill", "in": {"planks": 4, "stick": 2}},
	{"out": "oak_chair", "count": 1, "bench": "sawmill", "in": {"planks": 3, "stick": 2}},
	{"out": "carved_oak", "count": 1, "bench": "sawmill", "in": {"planks": 1}},
	{"out": "redwood_slab", "count": 2, "bench": "sawmill", "in": {"redwood_planks": 1}},
	{"out": "redwood_stairs", "count": 2, "bench": "sawmill", "in": {"redwood_planks": 3}},
	{"out": "redwood_column", "count": 1, "bench": "sawmill", "in": {"redwood_planks": 2}},
	{"out": "redwood_table", "count": 1, "bench": "sawmill", "in": {"redwood_planks": 4, "stick": 2}},
	{"out": "redwood_chair", "count": 1, "bench": "sawmill", "in": {"redwood_planks": 3, "stick": 2}},
	{"out": "carved_redwood", "count": 1, "bench": "sawmill", "in": {"redwood_planks": 1}},
	{"out": "pine_slab", "count": 2, "bench": "sawmill", "in": {"pine_planks": 1}},
	{"out": "pine_stairs", "count": 2, "bench": "sawmill", "in": {"pine_planks": 3}},
	{"out": "pine_column", "count": 1, "bench": "sawmill", "in": {"pine_planks": 2}},
	{"out": "pine_table", "count": 1, "bench": "sawmill", "in": {"pine_planks": 4, "stick": 2}},
	{"out": "pine_chair", "count": 1, "bench": "sawmill", "in": {"pine_planks": 3, "stick": 2}},
	{"out": "carved_pine", "count": 1, "bench": "sawmill", "in": {"pine_planks": 1}},
	{"out": "palm_slab", "count": 2, "bench": "sawmill", "in": {"palm_planks": 1}},
	{"out": "palm_stairs", "count": 2, "bench": "sawmill", "in": {"palm_planks": 3}},
	{"out": "palm_column", "count": 1, "bench": "sawmill", "in": {"palm_planks": 2}},
	{"out": "palm_table", "count": 1, "bench": "sawmill", "in": {"palm_planks": 4, "stick": 2}},
	{"out": "palm_chair", "count": 1, "bench": "sawmill", "in": {"palm_planks": 3, "stick": 2}},
	{"out": "carved_palm", "count": 1, "bench": "sawmill", "in": {"palm_planks": 1}},
	{"out": "candy_slab", "count": 2, "bench": "sawmill", "in": {"candy_planks": 1}},
	{"out": "candy_stairs", "count": 2, "bench": "sawmill", "in": {"candy_planks": 3}},
	{"out": "candy_column", "count": 1, "bench": "sawmill", "in": {"candy_planks": 2}},
	{"out": "candy_table", "count": 1, "bench": "sawmill", "in": {"candy_planks": 4, "stick": 2}},
	{"out": "candy_chair", "count": 1, "bench": "sawmill", "in": {"candy_planks": 3, "stick": 2}},
	{"out": "carved_candy", "count": 1, "bench": "sawmill", "in": {"candy_planks": 1}},
	{"out": "bookshelf", "count": 1, "bench": "sawmill", "in": {"planks": 3, "paper": 3}},
{"out": "portalstone", "count": 4, "bench": "stonecutter", "in": {"cobblestone": 4, "cutieite_ingot": 1}},
	{"out": "maple_slab", "count": 2, "bench": "sawmill", "in": {"maple_planks": 1}},
	{"out": "maple_stairs", "count": 2, "bench": "sawmill", "in": {"maple_planks": 3}},
	{"out": "maple_column", "count": 1, "bench": "sawmill", "in": {"maple_planks": 2}},
	{"out": "maple_table", "count": 1, "bench": "sawmill", "in": {"maple_planks": 4, "stick": 2}},
	{"out": "maple_chair", "count": 1, "bench": "sawmill", "in": {"maple_planks": 3, "stick": 2}},
	{"out": "carved_maple", "count": 1, "bench": "sawmill", "in": {"maple_planks": 1}},
	{"out": "hay_bale", "count": 1, "bench": "sawmill", "in": {"grass_tuft": 9}},
	{"out": "dead_slab", "count": 2, "bench": "sawmill", "in": {"dead_planks": 1}},
	{"out": "dead_stairs", "count": 2, "bench": "sawmill", "in": {"dead_planks": 3}},
	{"out": "dead_column", "count": 1, "bench": "sawmill", "in": {"dead_planks": 2}},
	{"out": "dead_table", "count": 1, "bench": "sawmill", "in": {"dead_planks": 4, "stick": 2}},
	{"out": "dead_chair", "count": 1, "bench": "sawmill", "in": {"dead_planks": 3, "stick": 2}},
	{"out": "carved_dead", "count": 1, "bench": "sawmill", "in": {"dead_planks": 1}},
	{"out": "gravestone", "count": 1, "bench": "stonecutter", "in": {"cobblestone": 2}},
	{"out": "stone_bricks", "count": 1, "bench": "stonecutter", "in": {"cobblestone": 1}},
	{"out": "cobblestone_slab", "count": 2, "bench": "stonecutter", "in": {"cobblestone": 1}},
	{"out": "cobblestone_stairs", "count": 1, "bench": "stonecutter", "in": {"cobblestone": 1}},
	{"out": "cobblestone_column", "count": 1, "bench": "stonecutter", "in": {"cobblestone": 1}},
	{"out": "stone_brick_slab", "count": 2, "bench": "stonecutter", "in": {"stone_bricks": 1}},
	{"out": "stone_brick_stairs", "count": 1, "bench": "stonecutter", "in": {"stone_bricks": 1}},
	{"out": "stone_brick_column", "count": 1, "bench": "stonecutter", "in": {"stone_bricks": 1}},
	{"out": "sandstone_slab", "count": 2, "bench": "stonecutter", "in": {"sandstone": 1}},
	{"out": "sandstone_stairs", "count": 1, "bench": "stonecutter", "in": {"sandstone": 1}},
	{"out": "sandstone_column", "count": 1, "bench": "stonecutter", "in": {"sandstone": 1}},
	{"out": "stone_pillar", "count": 2, "bench": "stonecutter", "in": {"stone_bricks": 2}},
	{"out": "chiseled_bricks", "count": 1, "bench": "stonecutter", "in": {"stone_bricks": 1}},
	{"out": "carved_sandstone", "count": 1, "bench": "stonecutter", "in": {"sandstone": 1}},
	# Marble and onyx from the chessboard kingdom.
	{"out": "marble_bricks", "count": 1, "bench": "stonecutter", "in": {"white_marble": 1}},
	{"out": "onyx_bricks", "count": 1, "bench": "stonecutter", "in": {"black_onyx": 1}},
	{"out": "marble_slab", "count": 2, "bench": "stonecutter", "in": {"marble_bricks": 1}},
	{"out": "onyx_slab", "count": 2, "bench": "stonecutter", "in": {"onyx_bricks": 1}},
	{"out": "marble_stairs", "count": 1, "bench": "stonecutter", "in": {"marble_bricks": 1}},
	{"out": "onyx_stairs", "count": 1, "bench": "stonecutter", "in": {"onyx_bricks": 1}},
	{"out": "marble_column", "count": 1, "bench": "stonecutter", "in": {"white_marble": 1}},
	{"out": "onyx_column", "count": 1, "bench": "stonecutter", "in": {"black_onyx": 1}},
	{"out": "checker_tile", "count": 2, "bench": "stonecutter", "in": {"white_marble": 1, "black_onyx": 1}},
	{"out": "copper_block", "count": 1, "bench": "shaper", "in": {"copper_ingot": 9}},
	{"out": "iron_block", "count": 1, "bench": "shaper", "in": {"iron_ingot": 9}},
	{"out": "silver_block", "count": 1, "bench": "shaper", "in": {"silver_ingot": 9}},
	{"out": "titanium_block", "count": 1, "bench": "shaper", "in": {"titanium_ingot": 9}},
	{"out": "copper_slab", "count": 2, "bench": "shaper", "in": {"copper_block": 1}},
	{"out": "iron_slab", "count": 2, "bench": "shaper", "in": {"iron_block": 1}},
	{"out": "silver_slab", "count": 2, "bench": "shaper", "in": {"silver_block": 1}},
	{"out": "titanium_slab", "count": 2, "bench": "shaper", "in": {"titanium_block": 1}},
	{"out": "gold_slab", "count": 2, "bench": "shaper", "in": {"gold_block": 1}},
	{"out": "gold_inlaid_bricks", "count": 4, "bench": "shaper", "in": {"stone_bricks": 4, "gold_ingot": 1}},
	{"out": "silver_inlaid_bricks", "count": 4, "bench": "shaper", "in": {"stone_bricks": 4, "silver_ingot": 1}},
	{"out": "titanium_inlaid_bricks", "count": 4, "bench": "shaper", "in": {"stone_bricks": 4, "titanium_ingot": 1}},
]


## Shovels, bows and arrows.
const GEAR_RECIPES := [
	{"out": "wooden_shovel", "count": 1, "station": 0, "cost": 0, "in": {"planks": 1, "stick": 2}},
	{"out": "stone_shovel", "count": 1, "station": 1, "cost": 4, "in": {"cobblestone": 1, "stick": 2}},
	{"out": "bronze_shovel", "count": 1, "station": 1, "cost": 18, "in": {"bronze_ingot": 1, "stick": 2}},
	{"out": "iron_shovel", "count": 1, "station": 2, "cost": 55, "in": {"iron_ingot": 1, "stick": 2}},
	{"out": "titanium_shovel", "count": 1, "station": 3, "cost": 200, "in": {"titanium_ingot": 1, "stick": 2}},
	{"out": "hunting_bow", "count": 1, "station": 1, "cost": 12, "in": {"stick": 3, "wool": 2}},
	{"out": "iron_bow", "count": 1, "station": 2, "cost": 80, "in": {"iron_ingot": 2, "stick": 2, "spider_silk": 3}},
	{"out": "titanium_bow", "count": 1, "station": 3, "cost": 300, "in": {"titanium_ingot": 2, "gold_ingot": 1, "spider_silk": 4}},
	{"out": "wooden_arrow", "count": 4, "station": 1, "cost": 2, "in": {"stick": 1, "feather": 1}},
	{"out": "stone_arrow", "count": 4, "station": 1, "cost": 4, "in": {"stick": 1, "cobblestone": 1, "feather": 1}},
	{"out": "bronze_arrow", "count": 8, "station": 1, "cost": 10, "in": {"stick": 2, "bronze_ingot": 1, "feather": 2}},
	{"out": "iron_arrow", "count": 8, "station": 2, "cost": 25, "in": {"stick": 2, "iron_ingot": 1, "feather": 2}},
	{"out": "poison_arrow", "count": 6, "station": 2, "cost": 30, "in": {"stick": 2, "venom_sac": 1, "feather": 2}},
	{"out": "silver_arrow", "count": 8, "station": 2, "cost": 40, "in": {"stick": 2, "silver_ingot": 1, "feather": 2}},
	{"out": "titanium_arrow", "count": 8, "station": 3, "cost": 90, "in": {"stick": 2, "titanium_ingot": 1, "feather": 2}},
	{"out": "frost_arrow", "count": 6, "station": 3, "cost": 90, "in": {"stick": 2, "hare_fur": 2, "titanium_ingot": 1}},
]

static var _values := {}


## "planks" and "log" in a recipe mean any kind of wood. (Recipes marked
## "exact" want that very item: oak planks come only from oak logs.)
const GROUPS := {
	"planks": ["planks", "redwood_planks", "pine_planks", "palm_planks", "candy_planks", "maple_planks", "dead_planks"],
	"log": ["log", "redwood_log", "pine_log", "palm_log", "maple_log", "dead_log"],
}


## The items that count for this recipe input.
static func choices(r: Dictionary, input: String) -> Array:
	if r.get("exact", false) or not GROUPS.has(input):
		return [input]
	return GROUPS[input]


## How many of this input you have (any kind of wood counts for "planks").
static func have(inv: Array, r: Dictionary, input: String, limit := -1) -> int:
	var n := 0
	for id in choices(r, input):
		n += Inv.count_of(inv.slice(0, limit) if limit > 0 else inv, id)
	return n


## Takes `count` of this input. Uses up the kind you have the most of first.
static func take(inv: Array, r: Dictionary, input: String, count: int, limit := -1) -> int:
	var kinds := choices(r, input).duplicate()
	var src := inv.slice(0, limit) if limit > 0 else inv
	kinds.sort_custom(func(a, b): return Inv.count_of(src, a) > Inv.count_of(src, b))
	var got := 0
	for id in kinds:
		if got >= count:
			break
		got += Inv.remove(inv, id, count - got, limit)
	return got


## Recipe ids are the output item id (each output has one recipe).
## Has someone found everything this recipe needs? (For "planks" or "log",
## any kind counts.) `seen` is the set of item ids they've ever carried.
static func discovered(r: Dictionary, seen: Dictionary) -> bool:
	for input in r["in"]:
		var any := false
		for id in choices(r, input):
			if seen.has(id):
				any = true
				break
		if not any:
			return false
	return true


## Learned at a Research Table (so it shows up at its workbench)?
static func needs_research(r: Dictionary) -> bool:
	return int(r.get("station", 0)) > 0 and not r.has("bench") and not r.get("auto", false)


static func get_recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["out"] == id:
			return r
	return {}


static func fuel_value(id: String) -> float:
	return Items.get_def(id).get("fuel", 0.0)


## Sell value of one item, in toots.
static func value(id: String) -> float:
	var cd := Items.get_def(id)
	if cd.get("cute", false):
		return (value(cd["base"]) + value("cutieite_ingot") * cute_cost(cd["base"])) * 0.9
	if _values.has(id):
		return _values[id]
	_values[id] = 0.0  # guards against recipe loops
	var v := 0.0
	var d := Items.get_def(id)
	if d.has("value"):
		v = d["value"]
	elif d.get("cooked", false):
		var raw := value("raw_" + id.trim_prefix("cooked_"))
		v = raw + minf(raw * COOK_BONUS, COOK_BONUS_MAX)
	else:
		var r := get_recipe(id)
		if not r.is_empty():
			var total := 0.0
			for input in r["in"]:
				total += value(input) * r["in"][input]
			v = total * CRAFT_VALUE_SHARE / r["count"]
		else:
			for ore in SMELTING:
				if SMELTING[ore] == id:
					v = value(ore) * CRAFT_VALUE_SHARE
					break
	_values[id] = v
	return v


static func format_toots(amount: float) -> String:
	var s := ("%.1f" % amount).trim_suffix(".0")
	return "%s toot%s" % [s, "" if s == "1" else "s"]


## "3 Planks, 2 Sticks" style text.
static func describe_inputs(r: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in r["in"]:
		parts.append("%d %s" % [r["in"][id], Items.display_name(id)])
	return ", ".join(parts)
