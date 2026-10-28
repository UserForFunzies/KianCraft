extends RefCounted
## Every item in the game: names, sell values (in toots), stack sizes, and what
## the item does (places a block, works as a tool/weapon/armor, food, fuel...).
##
## Only *base* items (found, mined or looted) have a "value" here. Crafted and
## smelted items get their value from recipes.gd: 90% of what went into them,
## so crafting never makes toots out of thin air.
## Item icons are painted in code (_paint_icon), just like block textures.

const Blocks = preload("res://scripts/blocks.gd")
const BossData = preload("res://scripts/boss_data.gd")

const MAX_STACK := 64

## Tool tiers: 1 wood, 2 stone, 3 bronze, 4 iron, 5 titanium.
## A block with "tier": N in blocks.gd needs a pickaxe of tier N or better.
const BASE_ITEMS := {
	# --- Blocks -------------------------------------------------------------------
	"dirt": {"name": "Dirt", "value": 0.5, "block": Blocks.DIRT},
	"sand": {"name": "Sand", "value": 0.5, "block": Blocks.SAND},
	"cobblestone": {"name": "Cobblestone", "value": 1.0, "block": Blocks.COBBLESTONE},
	"log": {"name": "Oak Log", "value": 2.0, "block": Blocks.LOG, "fuel": 4.0},
	"planks": {"name": "Oak Planks", "block": Blocks.PLANKS, "fuel": 1.0},
	"redwood_log": {"name": "Redwood Log", "value": 2.0, "block": Blocks.REDWOOD_LOG, "fuel": 4.0},
	"redwood_planks": {"name": "Redwood Planks", "block": Blocks.REDWOOD_PLANKS, "fuel": 1.0},
	"pine_log": {"name": "Pine Log", "value": 2.0, "block": Blocks.PINE_LOG, "fuel": 4.0},
	"pine_planks": {"name": "Pine Planks", "block": Blocks.PINE_PLANKS, "fuel": 1.0},
	"palm_log": {"name": "Palm Log", "value": 2.0, "block": Blocks.PALM_LOG, "fuel": 4.0},
	"palm_planks": {"name": "Palm Planks", "block": Blocks.PALM_PLANKS, "fuel": 1.0},
	"candy_planks": {"name": "Candy Planks", "block": Blocks.CANDY_PLANKS, "fuel": 1.0},
	"maple_log": {"name": "Maple Log", "value": 2.0, "block": Blocks.MAPLE_LOG, "fuel": 4.0},
	"dead_log": {"name": "Deadwood Log", "value": 2.0, "block": Blocks.DEAD_LOG, "fuel": 4.0},
	"dead_planks": {"name": "Deadwood Planks", "block": Blocks.DEAD_PLANKS, "fuel": 1.0},
	"dead_slab": {"name": "Deadwood Slab", "block": Blocks.DEAD_SLAB},
	"dead_stairs": {"name": "Deadwood Stairs", "block": Blocks.DEAD_STAIRS},
	"dead_column": {"name": "Deadwood Column", "block": Blocks.DEAD_COLUMN},
	"dead_table": {"name": "Deadwood Table", "block": Blocks.DEAD_TABLE},
	"dead_chair": {"name": "Deadwood Chair", "block": Blocks.DEAD_CHAIR},
	"carved_dead": {"name": "Carved Deadwood", "block": Blocks.CARVED_DEAD},
	"jack_o_lantern": {"name": "Jack-o'-Lantern", "block": Blocks.JACK_O_LANTERN},
	"gravestone": {"name": "Gravestone", "value": 1.0, "block": Blocks.GRAVESTONE},
	"glowshroom": {"name": "Glowshroom", "value": 0.8, "block": Blocks.GLOWSHROOM, "plant": true},
	"ghost_lantern": {"name": "Ghost Lantern", "block": Blocks.GHOST_LANTERN},
	"vine": {"name": "Vine", "value": 0.2, "block": Blocks.VINE, "plant": true},
	"maple_planks": {"name": "Maple Planks", "block": Blocks.MAPLE_PLANKS, "fuel": 1.0},
	"maple_slab": {"name": "Maple Slab", "block": Blocks.MAPLE_SLAB},
	"maple_stairs": {"name": "Maple Stairs", "block": Blocks.MAPLE_STAIRS},
	"maple_column": {"name": "Maple Column", "block": Blocks.MAPLE_COLUMN},
	"maple_table": {"name": "Maple Table", "block": Blocks.MAPLE_TABLE},
	"maple_chair": {"name": "Maple Chair", "block": Blocks.MAPLE_CHAIR},
	"carved_maple": {"name": "Carved Maple", "block": Blocks.CARVED_MAPLE},
	"pumpkin": {"name": "Pumpkin", "value": 1.5, "block": Blocks.PUMPKIN},
	"hay_bale": {"name": "Hay Bale", "value": 0.8, "block": Blocks.HAY_BALE, "fuel": 2.0},
	"leaf_pile": {"name": "Leaf Pile", "value": 0.1, "block": Blocks.LEAF_PILE, "plant": true},
	"golden_leaf_pile": {"name": "Golden Leaf Pile", "value": 0.1, "block": Blocks.GOLD_LEAF_PILE, "plant": true},
	# --- Building blocks (made at the Sawmill, Stonecutter and Shaper) ---------------------
	"oak_slab": {"name": "Oak Slab", "block": Blocks.OAK_SLAB},
	"oak_stairs": {"name": "Oak Stairs", "block": Blocks.OAK_STAIRS},
	"oak_column": {"name": "Oak Column", "block": Blocks.OAK_COLUMN},
	"oak_table": {"name": "Oak Table", "block": Blocks.OAK_TABLE},
	"oak_chair": {"name": "Oak Chair", "block": Blocks.OAK_CHAIR},
	"carved_oak": {"name": "Carved Oak", "block": Blocks.CARVED_OAK},
	"redwood_slab": {"name": "Redwood Slab", "block": Blocks.REDWOOD_SLAB},
	"redwood_stairs": {"name": "Redwood Stairs", "block": Blocks.REDWOOD_STAIRS},
	"redwood_column": {"name": "Redwood Column", "block": Blocks.REDWOOD_COLUMN},
	"redwood_table": {"name": "Redwood Table", "block": Blocks.REDWOOD_TABLE},
	"redwood_chair": {"name": "Redwood Chair", "block": Blocks.REDWOOD_CHAIR},
	"carved_redwood": {"name": "Carved Redwood", "block": Blocks.CARVED_REDWOOD},
	"pine_slab": {"name": "Pine Slab", "block": Blocks.PINE_SLAB},
	"pine_stairs": {"name": "Pine Stairs", "block": Blocks.PINE_STAIRS},
	"pine_column": {"name": "Pine Column", "block": Blocks.PINE_COLUMN},
	"pine_table": {"name": "Pine Table", "block": Blocks.PINE_TABLE},
	"pine_chair": {"name": "Pine Chair", "block": Blocks.PINE_CHAIR},
	"carved_pine": {"name": "Carved Pine", "block": Blocks.CARVED_PINE},
	"palm_slab": {"name": "Palm Slab", "block": Blocks.PALM_SLAB},
	"palm_stairs": {"name": "Palm Stairs", "block": Blocks.PALM_STAIRS},
	"palm_column": {"name": "Palm Column", "block": Blocks.PALM_COLUMN},
	"palm_table": {"name": "Palm Table", "block": Blocks.PALM_TABLE},
	"palm_chair": {"name": "Palm Chair", "block": Blocks.PALM_CHAIR},
	"carved_palm": {"name": "Carved Palm", "block": Blocks.CARVED_PALM},
	"candy_slab": {"name": "Candy Slab", "block": Blocks.CANDY_SLAB},
	"candy_stairs": {"name": "Candy Stairs", "block": Blocks.CANDY_STAIRS},
	"candy_column": {"name": "Candy Column", "block": Blocks.CANDY_COLUMN},
	"candy_table": {"name": "Candy Table", "block": Blocks.CANDY_TABLE},
	"candy_chair": {"name": "Candy Chair", "block": Blocks.CANDY_CHAIR},
	"carved_candy": {"name": "Carved Candy", "block": Blocks.CARVED_CANDY},
	"bookshelf": {"name": "Bookshelf", "block": Blocks.BOOKSHELF},
	"stone_bricks": {"name": "Stone Bricks", "block": Blocks.STONE_BRICKS},
	"cobblestone_slab": {"name": "Cobblestone Slab", "block": Blocks.COBBLESTONE_SLAB},
	"cobblestone_stairs": {"name": "Cobblestone Stairs", "block": Blocks.COBBLESTONE_STAIRS},
	"cobblestone_column": {"name": "Cobblestone Column", "block": Blocks.COBBLESTONE_COLUMN},
	"stone_brick_slab": {"name": "Stone Brick Slab", "block": Blocks.STONE_BRICK_SLAB},
	"stone_brick_stairs": {"name": "Stone Brick Stairs", "block": Blocks.STONE_BRICK_STAIRS},
	"stone_brick_column": {"name": "Stone Brick Column", "block": Blocks.STONE_BRICK_COLUMN},
	"sandstone_slab": {"name": "Sandstone Slab", "block": Blocks.SANDSTONE_SLAB},
	"sandstone_stairs": {"name": "Sandstone Stairs", "block": Blocks.SANDSTONE_STAIRS},
	"sandstone_column": {"name": "Sandstone Column", "block": Blocks.SANDSTONE_COLUMN},
	"stone_pillar": {"name": "Stone Pillar", "block": Blocks.STONE_PILLAR},
	"chiseled_bricks": {"name": "Chiseled Stone Bricks", "block": Blocks.CHISELED_BRICKS},
	"carved_sandstone": {"name": "Carved Sandstone", "block": Blocks.CARVED_SANDSTONE},
	"copper_block": {"name": "Copper Block", "block": Blocks.COPPER_BLOCK},
	"iron_block": {"name": "Iron Block", "block": Blocks.IRON_BLOCK},
	"silver_block": {"name": "Silver Block", "block": Blocks.SILVER_BLOCK},
	"titanium_block": {"name": "Titanium Block", "block": Blocks.TITANIUM_BLOCK},
	"copper_slab": {"name": "Copper Slab", "block": Blocks.COPPER_SLAB},
	"iron_slab": {"name": "Iron Slab", "block": Blocks.IRON_SLAB},
	"silver_slab": {"name": "Silver Slab", "block": Blocks.SILVER_SLAB},
	"titanium_slab": {"name": "Titanium Slab", "block": Blocks.TITANIUM_SLAB},
	"gold_slab": {"name": "Gold Slab", "block": Blocks.GOLD_SLAB},
	"gold_inlaid_bricks": {"name": "Gold Inlaid Bricks", "block": Blocks.GOLD_INLAID_BRICKS},
	"silver_inlaid_bricks": {"name": "Silver Inlaid Bricks", "block": Blocks.SILVER_INLAID_BRICKS},
	"titanium_inlaid_bricks": {"name": "Titanium Inlaid Bricks", "block": Blocks.TITANIUM_INLAID_BRICKS},
	"sawmill": {"name": "Sawmill", "block": Blocks.SAWMILL},
	"stonecutter": {"name": "Stonecutter", "block": Blocks.STONECUTTER},
	"shaper": {"name": "Shaper", "block": Blocks.SHAPER},
	# --- The Deep (gen 12 worlds) -------------------------------------------------------
	"bedstone": {"name": "Bedstone", "value": 2.0, "block": Blocks.BEDSTONE},
	"deepstone": {"name": "Deepstone", "value": 1.0, "block": Blocks.DEEPSTONE},
	"cinderstone": {"name": "Cinderstone", "value": 6.0, "block": Blocks.CINDERSTONE},
	"glow_crystal": {"name": "Glow Crystal", "value": 4.0, "block": Blocks.GLOW_CRYSTAL},
	"jewelry_station": {"name": "Jewelry Station", "block": Blocks.JEWELRY_STATION},
	"magma_rock": {"name": "Magma Rock", "value": 3.0, "block": Blocks.MAGMA_ROCK},
	"ember": {"name": "Ember", "value": 12.0, "icon": "blob", "color": Color(1.0, 0.5, 0.12), "fuel": 8.0},
	"drake_scale": {"name": "Drake Scale", "value": 30.0, "icon": "hide", "color": Color(0.78, 0.2, 0.12)},
	"ruby": {"name": "Ruby", "value": 30.0, "icon": "gem", "color": Color(0.92, 0.12, 0.22)},
	"sapphire": {"name": "Sapphire", "value": 30.0, "icon": "gem", "color": Color(0.2, 0.4, 1.0)},
	"amethyst": {"name": "Amethyst", "value": 30.0, "icon": "gem", "color": Color(0.72, 0.38, 0.98)},
	"diamond": {"name": "Diamond", "value": 60.0, "icon": "gem", "color": Color(0.62, 0.96, 1.0)},
	"onyx_gem": {"name": "Onyx", "value": 60.0, "icon": "gem", "color": Color(0.2, 0.17, 0.25)},
	"lava_bucket": {"name": "Lava Bucket", "icon": "bucket", "color": Color(0.75, 0.75, 0.78), "liquid": Color(1.0, 0.45, 0.08), "stack": 1},
	"glass": {"name": "Glass", "block": Blocks.GLASS},
	"lamp": {"name": "Lamp", "block": Blocks.LAMP},
	"copper_ore": {"name": "Copper Ore", "value": 4.0, "block": Blocks.COPPER_ORE},
	"tin_ore": {"name": "Tin Ore", "value": 4.0, "block": Blocks.TIN_ORE},
	"iron_ore": {"name": "Iron Ore", "value": 10.0, "block": Blocks.IRON_ORE},
	"silver_ore": {"name": "Silver Ore", "value": 18.0, "block": Blocks.SILVER_ORE},
	"titanium_ore": {"name": "Titanium Ore", "value": 30.0, "block": Blocks.TITANIUM_ORE},
	"gold_ore": {"name": "Gold Ore", "value": 50.0, "block": Blocks.GOLD_ORE},
	"cutie_ore": {"name": "Cutie Ore", "value": 8.0, "block": Blocks.CUTIE_ORE},
	"cute_crafter": {"name": "Cute Crafter", "block": Blocks.CUTE_CRAFTER},
	"portalstone": {"name": "Portalstone", "block": Blocks.PORTALSTONE},
	"workbench_1": {"name": "Workbench Tier 1", "block": Blocks.WORKBENCH_1},
	"workbench_2": {"name": "Workbench Tier 2", "block": Blocks.WORKBENCH_2},
	"workbench_3": {"name": "Workbench Tier 3", "block": Blocks.WORKBENCH_3},
	"furnace": {"name": "Furnace", "block": Blocks.FURNACE},
	"shop": {"name": "Block Shop", "block": Blocks.SHOP},
	"gold_block": {"name": "Gold Block", "block": Blocks.GOLD_BLOCK},
	"chest": {"name": "Chest", "block": Blocks.CHEST},
	"torch": {"name": "Torch", "block": Blocks.TORCH},
	"bed": {"name": "Bed", "block": Blocks.BED},
	"scribe": {"name": "Scribe Desk", "block": Blocks.SCRIBE},
	"research_table": {"name": "Research Table", "block": Blocks.RESEARCH_TABLE},
	"super_chest": {"name": "Super Chest", "block": Blocks.SUPER_CHEST},
	"white_marble": {"name": "White Marble", "block": Blocks.WHITE_MARBLE},
	"black_onyx": {"name": "Black Onyx", "block": Blocks.BLACK_ONYX},
	"marble_bricks": {"name": "Marble Bricks", "block": Blocks.MARBLE_BRICKS},
	"onyx_bricks": {"name": "Onyx Bricks", "block": Blocks.ONYX_BRICKS},
	"marble_slab": {"name": "Marble Slab", "block": Blocks.MARBLE_SLAB},
	"onyx_slab": {"name": "Onyx Slab", "block": Blocks.ONYX_SLAB},
	"marble_stairs": {"name": "Marble Stairs", "block": Blocks.MARBLE_STAIRS},
	"onyx_stairs": {"name": "Onyx Stairs", "block": Blocks.ONYX_STAIRS},
	"marble_column": {"name": "Marble Column", "block": Blocks.MARBLE_COLUMN},
	"onyx_column": {"name": "Onyx Column", "block": Blocks.ONYX_COLUMN},
	"checker_tile": {"name": "Checker Tile", "block": Blocks.CHECKER_TILE},
	"sesame_bun": {"name": "Sesame Bun", "block": Blocks.SESAME_BUN},
	"fry_box": {"name": "Fry Box", "block": Blocks.FRY_BOX},
	"circus_stripes": {"name": "Circus Stripes", "block": Blocks.CIRCUS_STRIPES},
	"arena_box": {"name": "Arena in a Box", "block": Blocks.ARENA_BOX, "rarity": "legendary", "kind_text": "Testing",
			"lines": ["Put it down in a big open space and right-click it: a whole battle arena appears!"]},
	"castle_box": {"name": "Castle in a Box", "block": Blocks.CASTLE_BOX, "rarity": "legendary", "kind_text": "Testing",
			"lines": ["Put it down in an open spot and right-click it", "A whole end-game castle appears around you"],
			"flavor": "For the host: a castle full of every item in the game, to try anything out."},
	"campfire": {"name": "Campfire", "block": Blocks.CAMPFIRE, "fuel": 4.0},
	"bedroll": {"name": "Bedroll", "block": Blocks.BEDROLL},
	"oak_sapling": {"name": "Oak Sapling", "value": 0.6, "block": Blocks.OAK_SAPLING, "plant": true, "fuel": 0.5},
	"redwood_sapling": {"name": "Redwood Sapling", "value": 1.0, "block": Blocks.REDWOOD_SAPLING, "plant": true, "fuel": 0.5},
	"pine_sapling": {"name": "Pine Sapling", "value": 0.6, "block": Blocks.PINE_SAPLING, "plant": true, "fuel": 0.5},
	"palm_sapling": {"name": "Palm Sapling", "value": 0.8, "block": Blocks.PALM_SAPLING, "plant": true, "fuel": 0.5},
	"maple_sapling": {"name": "Maple Sapling", "value": 0.8, "block": Blocks.MAPLE_SAPLING, "plant": true, "fuel": 0.5},
	"golden_sapling": {"name": "Golden Maple Sapling", "value": 1.2, "block": Blocks.GOLDEN_SAPLING, "plant": true, "fuel": 0.5},
	"candy_sapling": {"name": "Candy Sapling", "value": 1.0, "block": Blocks.CANDY_SAPLING, "plant": true},
	"item_frame": {"name": "Item Frame", "block": Blocks.ITEM_FRAME},
	"armor_stand": {"name": "Armor Stand", "block": Blocks.ARMOR_STAND},
	"wooden_door": {"name": "Wooden Door", "block": Blocks.DOOR_WOOD},
	"iron_door": {"name": "Iron Door", "block": Blocks.DOOR_IRON},
	"titanium_door": {"name": "Titanium Door", "block": Blocks.DOOR_TITANIUM},
	"sandstone": {"name": "Sandstone", "value": 1.0, "block": Blocks.SANDSTONE},
	"cactus": {"name": "Cactus", "value": 1.0, "block": Blocks.CACTUS},
	"cake": {"name": "Cake", "value": 0.5, "block": Blocks.CAKE},
	"candy_cane": {"name": "Candy Cane", "value": 2.5, "block": Blocks.CANDY_CANE, "fuel": 3.0},
	"cotton_candy": {"name": "Cotton Candy", "value": 1.0, "block": Blocks.COTTON_CANDY},
	"snow": {"name": "Snow", "value": 0.5, "block": Blocks.SNOW},
	"mushroom": {"name": "Mushroom", "value": 1.5, "block": Blocks.MUSHROOM_CAP, "food": 1.0},

	# --- Plants (put one on the ground to plant it again) ----------------------------
	"grass_tuft": {"name": "Grass Tuft", "value": 0.1, "block": Blocks.TALL_GRASS, "plant": true},
	"poppy": {"name": "Poppy", "value": 0.3, "block": Blocks.POPPY, "plant": true},
	"dandelion": {"name": "Dandelion", "value": 0.3, "block": Blocks.DANDELION, "plant": true},
	"cornflower": {"name": "Cornflower", "value": 0.3, "block": Blocks.CORNFLOWER, "plant": true},
	"daisy": {"name": "Daisy", "value": 0.3, "block": Blocks.DAISY, "plant": true},
	"bluebell": {"name": "Bluebell", "value": 0.4, "block": Blocks.BLUEBELL, "plant": true},
	"toadstool": {"name": "Toadstool", "value": 0.4, "block": Blocks.TOADSTOOL, "plant": true},
	"cactus_flower": {"name": "Cactus Flower", "value": 0.5, "block": Blocks.CACTUS_FLOWER, "plant": true},
	"lollipop": {"name": "Lollipop", "value": 0.5, "block": Blocks.LOLLIPOP, "plant": true},
	"candy_tulip": {"name": "Candy Tulip", "value": 0.4, "block": Blocks.CANDY_TULIP, "plant": true},
	"edelweiss": {"name": "Edelweiss", "value": 0.6, "block": Blocks.EDELWEISS, "plant": true},

	# --- Materials ------------------------------------------------------------------
	"stick": {"name": "Stick", "fuel": 0.5, "icon": "stick"},
	"paper": {"name": "Paper", "icon": "paper", "color": Color(0.96, 0.93, 0.84)},
	# Furnaces leave coal behind. Coal + a bottle of water makes ink (add a flower for a color).
	"coal": {"name": "Coal", "value": 0.8, "fuel": 2.5, "icon": "coal", "color": Color(0.16, 0.16, 0.18)},
	"glass_bottle": {"name": "Glass Bottle", "icon": "bottle", "color": Color(0.8, 0.88, 0.95)},
	"water_bottle": {"name": "Water Bottle", "icon": "bottle", "color": Color(0.8, 0.88, 0.95), "liquid": Color(0.3, 0.55, 0.95)},
	"black_ink": {"name": "Black Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.1, 0.1, 0.12), "ink": "black"},
	"red_ink": {"name": "Red Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.85, 0.15, 0.15), "ink": "red"},
	"yellow_ink": {"name": "Yellow Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(1.0, 0.82, 0.2), "ink": "yellow"},
	"blue_ink": {"name": "Blue Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.25, 0.42, 0.95), "ink": "blue"},
	"white_ink": {"name": "White Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.95, 0.95, 0.92), "ink": "white"},
	"purple_ink": {"name": "Purple Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.55, 0.3, 0.9), "ink": "purple"},
	"pink_ink": {"name": "Pink Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(1.0, 0.5, 0.75), "ink": "pink"},
	"green_ink": {"name": "Green Ink", "icon": "bottle", "color": Color(0.8, 0.85, 0.9), "liquid": Color(0.3, 0.7, 0.3), "ink": "green"},
	"bucket": {"name": "Bucket", "icon": "bucket", "color": Color(0.75, 0.75, 0.78), "stack": 16},
	"water_bucket": {"name": "Water Bucket", "icon": "bucket", "color": Color(0.75, 0.75, 0.78), "liquid": Color(0.3, 0.55, 0.95), "stack": 1},
	# One of a kind: each map remembers where it has been (see survival.gd maps).
	"map": {"name": "Map", "icon": "map", "color": Color(0.9, 0.82, 0.62), "unique": true},
	"party_map": {"name": "Party Map", "icon": "map", "color": Color(0.72, 0.9, 0.72), "unique": true},
	"copper_ingot": {"name": "Copper Ingot", "icon": "ingot", "color": Color(0.85, 0.5, 0.28)},
	"tin_ingot": {"name": "Tin Ingot", "icon": "ingot", "color": Color(0.8, 0.82, 0.78)},
	"bronze_ingot": {"name": "Bronze Ingot", "icon": "ingot", "color": Color(0.75, 0.55, 0.25)},
	"iron_ingot": {"name": "Iron Ingot", "icon": "ingot", "color": Color(0.75, 0.75, 0.78)},
	"silver_ingot": {"name": "Silver Ingot", "icon": "ingot", "color": Color(0.93, 0.95, 1.0)},
	"titanium_ingot": {"name": "Titanium Ingot", "icon": "ingot", "color": Color(0.58, 0.75, 0.95)},
	"gold_ingot": {"name": "Gold Ingot", "icon": "ingot", "color": Color(1.0, 0.84, 0.25)},
	"cutieite_ingot": {"name": "Cutieite Ingot", "icon": "ingot", "color": Color(1.0, 0.6, 0.82), "sparkle": true},

	# --- Mob drops ------------------------------------------------------------------
	"feather": {"name": "Feather", "value": 1.0, "icon": "feather", "color": Color(0.95, 0.95, 0.92)},
	"rabbit_hide": {"name": "Rabbit Hide", "value": 2.0, "icon": "hide", "color": Color(0.85, 0.8, 0.72)},
	"leather": {"name": "Leather", "value": 4.0, "icon": "hide", "color": Color(0.55, 0.36, 0.2)},
	"wool": {"name": "Wool", "value": 3.0, "icon": "wool", "color": Color(0.95, 0.94, 0.9)},
	"wolf_pelt": {"name": "Wolf Pelt", "value": 12.0, "icon": "hide", "color": Color(0.5, 0.5, 0.52)},
	"cougar_pelt": {"name": "Cougar Pelt", "value": 16.0, "icon": "hide", "color": Color(0.78, 0.62, 0.4)},
	"bear_pelt": {"name": "Bear Pelt", "value": 30.0, "icon": "hide", "color": Color(0.33, 0.22, 0.14)},
	"spider_silk": {"name": "Spider Silk", "value": 8.0, "icon": "silk", "color": Color(0.92, 0.92, 0.95)},
	"venom_sac": {"name": "Venom Sac", "value": 15.0, "icon": "blob", "color": Color(0.45, 0.8, 0.3)},
	"sand_bear_pelt": {"name": "Sand Bear Pelt", "value": 34.0, "icon": "hide", "color": Color(0.86, 0.72, 0.45)},
	"polar_bear_pelt": {"name": "Polar Bear Pelt", "value": 40.0, "icon": "hide", "color": Color(0.94, 0.95, 0.97)},
	"dire_wolf_pelt": {"name": "Dire Wolf Pelt", "value": 22.0, "icon": "hide", "color": Color(0.32, 0.33, 0.38)},
	"hare_fur": {"name": "Snow Hare Fur", "value": 3.0, "icon": "wool", "color": Color(0.97, 0.98, 1.0)},
	"goat_horn": {"name": "Goat Horn", "value": 6.0, "icon": "horn", "color": Color(0.85, 0.8, 0.68)},
	"yeti_fur": {"name": "Yeti Fur", "value": 140.0, "icon": "wool", "color": Color(0.86, 0.92, 1.0)},
	"king_pelt": {"name": "King Cougar Pelt", "value": 120.0, "icon": "hide", "color": Color(0.95, 0.75, 0.3)},
	"gummy": {"name": "Gummy", "value": 3.0, "food": 3.0, "icon": "gummy", "color": Color(0.95, 0.25, 0.3)},
	"marshmallow": {"name": "Marshmallow", "value": 2.0, "food": 2.0, "icon": "marshmallow", "color": Color(0.98, 0.96, 0.94)},
	"peppermint": {"name": "Peppermint", "value": 4.0, "food": 1.0, "icon": "peppermint", "color": Color(0.95, 0.15, 0.2)},
	# Fall forest critters and cave monsters.
	"acorn": {"name": "Acorn", "value": 0.5, "food": 1.0, "icon": "acorn", "color": Color(0.62, 0.42, 0.22)},
	"quill": {"name": "Hedgehog Quill", "value": 1.0, "icon": "feather", "color": Color(0.55, 0.45, 0.35)},
	"fox_fur": {"name": "Fox Fur", "value": 8.0, "icon": "hide", "color": Color(0.92, 0.5, 0.2)},
	"pumpkin_pie": {"name": "Pumpkin Pie", "food": 6.0, "icon": "pie", "color": Color(0.9, 0.55, 0.2)},
	"gremlin_tooth": {"name": "Gremlin Tooth", "value": 5.0, "icon": "fang", "color": Color(0.95, 0.93, 0.8)},
	"troll_hide": {"name": "Troll Hide", "value": 45.0, "icon": "hide", "color": Color(0.45, 0.52, 0.4)},
	# Spooky forest drops.
	"bone": {"name": "Bone", "value": 1.0, "icon": "bone", "color": Color(0.95, 0.93, 0.85)},
	"ancient_coin": {"name": "Ancient Coin", "value": 25.0, "icon": "old_coin", "color": Color(0.85, 0.7, 0.3)},
	"candy_corn": {"name": "Candy Corn", "value": 1.5, "food": 2.0, "icon": "candy_corn", "color": Color(1.0, 0.6, 0.15)},
	"ectoplasm": {"name": "Ectoplasm", "value": 9.0, "icon": "blob", "color": Color(0.55, 1.0, 0.85)},
	"witch_hat": {"name": "Witch Hat", "armor": 2, "slot": "head", "icon": "witch_hat", "color": Color(0.32, 0.18, 0.42), "value": 40.0},

	# --- Tools & weapons --------------------------------------------------------------
	"wooden_pickaxe": {"name": "Wooden Pickaxe", "tool": "pickaxe", "tier": 1, "speed": 2.0, "damage": 2.0, "icon": "pickaxe", "color": Color(0.7, 0.55, 0.33)},
	"wooden_axe": {"name": "Wooden Axe", "tool": "axe", "tier": 1, "speed": 2.0, "damage": 2.5, "icon": "axe", "color": Color(0.7, 0.55, 0.33)},
	"wooden_sword": {"name": "Wooden Sword", "tool": "sword", "tier": 1, "speed": 1.0, "damage": 4.0, "icon": "sword", "color": Color(0.7, 0.55, 0.33)},
	"stone_pickaxe": {"name": "Stone Pickaxe", "tool": "pickaxe", "tier": 2, "speed": 3.0, "damage": 3.0, "icon": "pickaxe", "color": Color(0.55, 0.55, 0.55)},
	"stone_axe": {"name": "Stone Axe", "tool": "axe", "tier": 2, "speed": 3.0, "damage": 3.5, "icon": "axe", "color": Color(0.55, 0.55, 0.55)},
	"stone_sword": {"name": "Stone Sword", "tool": "sword", "tier": 2, "speed": 1.0, "damage": 6.0, "icon": "sword", "color": Color(0.55, 0.55, 0.55)},
	"bronze_pickaxe": {"name": "Bronze Pickaxe", "tool": "pickaxe", "tier": 3, "speed": 4.0, "damage": 4.5, "icon": "pickaxe", "color": Color(0.75, 0.55, 0.25)},
	"bronze_axe": {"name": "Bronze Axe", "tool": "axe", "tier": 3, "speed": 4.0, "damage": 5.5, "icon": "axe", "color": Color(0.75, 0.55, 0.25)},
	"bronze_sword": {"name": "Bronze Sword", "tool": "sword", "tier": 3, "speed": 1.0, "damage": 9.0, "icon": "sword", "color": Color(0.75, 0.55, 0.25)},
	"iron_pickaxe": {"name": "Iron Pickaxe", "tool": "pickaxe", "tier": 4, "speed": 6.0, "damage": 6.5, "icon": "pickaxe", "color": Color(0.78, 0.78, 0.8)},
	"iron_axe": {"name": "Iron Axe", "tool": "axe", "tier": 4, "speed": 6.0, "damage": 8.5, "icon": "axe", "color": Color(0.78, 0.78, 0.8)},
	"iron_sword": {"name": "Iron Sword", "tool": "sword", "tier": 4, "speed": 1.0, "damage": 14.0, "icon": "sword", "color": Color(0.78, 0.78, 0.8)},
	"titanium_pickaxe": {"name": "Titanium Pickaxe", "tool": "pickaxe", "tier": 5, "speed": 9.0, "damage": 9.0, "icon": "pickaxe", "color": Color(0.58, 0.75, 0.95)},
	"titanium_axe": {"name": "Titanium Axe", "tool": "axe", "tier": 5, "speed": 9.0, "damage": 13.0, "icon": "axe", "color": Color(0.58, 0.75, 0.95)},
	"titanium_sword": {"name": "Titanium Sword", "tool": "sword", "tier": 5, "speed": 1.0, "damage": 22.0, "icon": "sword", "color": Color(0.58, 0.75, 0.95)},
	# Shovels dig dirt, sand, snow, frosting and cake fast.
	"wooden_shovel": {"name": "Wooden Shovel", "tool": "shovel", "tier": 1, "speed": 2.0, "damage": 1.5, "icon": "shovel", "color": Color(0.7, 0.55, 0.33)},
	"stone_shovel": {"name": "Stone Shovel", "tool": "shovel", "tier": 2, "speed": 3.0, "damage": 2.5, "icon": "shovel", "color": Color(0.55, 0.55, 0.55)},
	"bronze_shovel": {"name": "Bronze Shovel", "tool": "shovel", "tier": 3, "speed": 4.0, "damage": 3.5, "icon": "shovel", "color": Color(0.75, 0.55, 0.25)},
	"iron_shovel": {"name": "Iron Shovel", "tool": "shovel", "tier": 4, "speed": 6.0, "damage": 5.0, "icon": "shovel", "color": Color(0.78, 0.78, 0.8)},
	"titanium_shovel": {"name": "Titanium Shovel", "tool": "shovel", "tier": 5, "speed": 9.0, "damage": 7.0, "icon": "shovel", "color": Color(0.58, 0.75, 0.95)},

	# --- Bows (hold right-click to pull back, let go to shoot) ------------------------------
	# power = arrow speed at full pull (blocks/second), bow_damage = damage multiplier,
	# draw = seconds to pull all the way back.
	"hunting_bow": {"name": "Hunting Bow", "bow": 1, "power": 24.0, "bow_damage": 1.0, "draw": 0.9, "icon": "bow", "color": Color(0.62, 0.42, 0.22)},
	"iron_bow": {"name": "Iron Recurve Bow", "bow": 2, "power": 32.0, "bow_damage": 1.35, "draw": 0.8, "icon": "bow", "color": Color(0.78, 0.78, 0.8)},
	"titanium_bow": {"name": "Titanium Longbow", "bow": 3, "power": 42.0, "bow_damage": 1.75, "draw": 0.7, "icon": "bow", "color": Color(0.58, 0.75, 0.95)},

	# --- Legendary ------------------------------------------------------------------
	"king_crown": {"name": "Crown of the King Cougar", "armor": 7, "slot": "head", "icon": "crown",
			"color": Color(1.0, 0.8, 0.2), "value": 300.0, "rarity": "legendary", "regen": true,
			"kind_text": "Legendary Helmet",
			"lines": ["Royal Mending: heals 1 health every second", "Starts healing 2 seconds after you get hurt"],
			"flavor": "Taken from the King of the Sands. The great gem still feels warm."},
	"grim_chestplate": {"name": "Grimskull's Twin-Flame Chestplate", "armor": 15, "slot": "chest", "icon": "grim_chest",
			"color": Color(0.16, 0.15, 0.2), "value": 340.0, "rarity": "legendary", "ward": true, "might": 0.15, "look_tier": 4,
			"kind_text": "Legendary Chestplate",
			"lines": ["Flame & Frost Ward: fire and ice hurt you half as much, and can't burn or freeze you", "Bone Might: you hit 15% harder"],
			"flavor": "Forged in the castle in the clouds. One side is always warm, the other always cool."},
	"yeti_boots": {"name": "Boots of the Yeti", "armor": 7, "slot": "feet", "icon": "boots",
			"color": Color(0.82, 0.9, 1.0), "value": 280.0, "rarity": "legendary", "warm": true, "snow_speed": 1.3,
			"kind_text": "Legendary Boots",
			"lines": ["Yeti Warmth: you never feel the cold", "Snow Stride: 30% faster on snow and ice"],
			"flavor": "Stitched from the Yeti's own fur. They crunch happily in deep snow."},
	"gummy_leggings": {"name": "Gummy Giant's Bouncy Leggings", "armor": 11, "slot": "legs", "icon": "leggings",
			"color": Color(0.95, 0.32, 0.48), "value": 290.0, "rarity": "legendary", "look_tier": 4, "no_fall": true,
			"buffs": {"jump": 0.4}, "kind_text": "Legendary Leggings",
			"lines": ["Bouncy: falling never hurts"],
			"flavor": "Squishy, stretchy and a little bit sticky. Boing!"},
	"harvest_scythe": {"name": "Scarecrow King's Harvest Scythe", "tool": "axe", "tier": 5, "speed": 11.0, "damage": 21.0, "icon": "axe",
			"color": Color(0.95, 0.62, 0.2), "value": 300.0, "rarity": "legendary", "sword_power": "harvest",
			"kind_text": "Legendary Scythe",
			"lines": ["Reaping: monsters it beats drop twice as much, and you heal 2 health", "Chops wood like a titanium axe and then some"],
			"flavor": "The crows won't come near it. It smells faintly of pumpkin pie."},
	"ghostlight_pickaxe": {"name": "Lantern Witch's Ghostlight Pickaxe", "tool": "pickaxe", "tier": 5, "speed": 14.0, "damage": 10.0, "icon": "pickaxe",
			"color": Color(0.5, 1.0, 0.7), "gem": Color(0.55, 1.0, 0.7), "value": 300.0, "rarity": "legendary", "fortune": 0.35,
			"kind_text": "Legendary Pickaxe",
			"lines": ["Mines half again as fast as titanium", "Ghostlight: 35% chance of double ore"],
			"flavor": "A wisp of the witch's lantern lives in the head. It hums near hidden ore."},
	"white_throne_blade": {"name": "Blade of the White Throne", "tool": "sword", "tier": 5, "speed": 1.0, "damage": 24.0, "icon": "sword",
			"color": Color(0.95, 0.94, 0.9), "gem": Color(0.55, 0.85, 1.0), "value": 320.0, "rarity": "legendary", "sword_power": "stalemate",
			"kind_text": "Legendary Sword",
			"lines": ["Stalemate: every hit freezes a monster in place for a moment (bosses only briefly)"],
			"flavor": "The White Queen's own blade, carved from a single piece of moon-white marble."},
	"black_throne_blade": {"name": "Blade of the Black Throne", "tool": "sword", "tier": 5, "speed": 1.0, "damage": 26.0, "icon": "sword",
			"color": Color(0.16, 0.15, 0.2), "gem": Color(0.75, 0.35, 1.0), "value": 320.0, "rarity": "legendary", "sword_power": "checkmate",
			"kind_text": "Legendary Sword",
			"lines": ["Checkmate: monsters below 30% health fall in one hit (bosses take +50% damage instead)"],
			"flavor": "The Black King's onyx sword. It hums softly when an enemy is nearly beaten."},
	"french_fries": {"name": "French Fries", "value": 1.5, "food": 3.0, "icon": "fries", "color": Color(1.0, 0.82, 0.3)},
	"chicken_nugget": {"name": "Chicken Nugget", "value": 1.5, "food": 2.5, "icon": "nugget", "color": Color(0.88, 0.6, 0.26)},
	"toy_prize": {"name": "Toy Prize", "value": 6.0, "icon": "toy", "color": Color(0.35, 0.6, 1.0)},
	"circus_hammer": {"name": "Chuckles' Circus Hammer", "tool": "sword", "tier": 5, "speed": 1.0, "damage": 30.0, "icon": "hammer",
			"color": Color(0.9, 0.15, 0.18), "value": 340.0, "rarity": "legendary", "sword_power": "bonk",
			"kind_text": "Legendary Hammer",
			"lines": ["Bonk!: every hit sends monsters flying (bosses wobble)"],
			"flavor": "A giant squeaky circus hammer. It goes HONK when it hits something."},
	"cheatsheet": {"name": "Host Cheat Sheet", "icon": "paper", "color": Color(1.0, 0.92, 0.6), "unique": true, "kind_text": "Host Notes",
			"lines": ["/give <item> [count]  -  get any item", "/toots <amount>  -  add toots", "/heal  -  full health",
				"/spawn <mob>  -  make a mob or boss appear", "/tp <x> <z>  -  jump to a spot", "/goto <place>  -  jump to the nearest boss, place or biome",
				"/tpto <player>  -  jump to a player", "/bring <player>  -  bring a player to you", "/freeze <player>, /unfreeze <player>",
				"/hunt <player> <1-4>  -  1 cats & dogs, 2 bears, 3 trolls & gremlins, 4 a boss", "/god  -  nothing can hurt you",
				"/fly, /noclip, /clip  -  fly, fly through walls, walls solid again", "/time <day|night|0-24>, /weather <clear|rain|storm>",
				"/unlockall  -  learn every recipe", "/castle  -  a Castle in a Box", "/map_everything, /map_boss, /map_topo  -  special maps",
				"/pvp on|off  -  (if the host decides)", "/admin  -  the admin panel", "/cheatsheet  -  this note"],
			"flavor": "Shh! The host's secret notes."},
	"playing_card": {"name": "Playing Card", "value": 2.0, "icon": "card", "color": Color(0.85, 0.15, 0.2)},
	"boar_king_ring": {"name": "Ring of the Boar King", "slot": "ring", "icon": "ring", "color": Color(1.0, 0.78, 0.3),
			"gem": Color(0.85, 0.18, 0.12), "value": 260.0, "rarity": "legendary", "kind_text": "Legendary Ring",
			"buffs": {"leech": 0.12, "toughness": 0.12},
			"flavor": "Carved from the Boar King's golden tusk. It hums whenever there's a fight."},
	"giant_heart": {"name": "Heart of the Fire Giant", "slot": "amulet", "icon": "amulet", "color": Color(0.3, 0.12, 0.08),
			"gem": Color(1.0, 0.5, 0.1), "value": 320.0, "rarity": "legendary", "kind_text": "Legendary Amulet",
			"buffs": {"fireproof": 1.0, "toughness": 0.15, "regen": 1.0},
			"flavor": "Still warm, and it beats slowly. Lava feels like bath water while you wear it."},
	"oakheart_amulet": {"name": "Oakheart's Heartwood Amulet", "slot": "amulet", "icon": "amulet", "color": Color(0.55, 0.37, 0.2),
			"gem": Color(0.45, 1.0, 0.4), "value": 280.0, "rarity": "legendary", "kind_text": "Legendary Amulet",
			"buffs": {"regen": 1.5, "fortune": 0.25},
			"flavor": "A seed from the old oak's heart. It is still growing, very slowly."},

	# --- Rings & amulets (wear one of each; see survival.gear_buffs) ---------------------
	"gold_ring": {"name": "Gold Ring", "slot": "ring", "icon": "ring", "color": Color(1.0, 0.84, 0.25),
			"gem": Color(1.0, 0.32, 0.3), "buffs": {"haste": 0.12}},
	"silver_ring": {"name": "Silver Ring", "slot": "ring", "icon": "ring", "color": Color(0.9, 0.93, 1.0),
			"gem": Color(0.7, 0.45, 1.0), "buffs": {"fortune": 0.15}},
	"gold_amulet": {"name": "Gold Amulet", "slot": "amulet", "icon": "amulet", "color": Color(1.0, 0.84, 0.25),
			"gem": Color(0.4, 1.0, 0.5), "buffs": {"regen": 0.75}},
	"silver_amulet": {"name": "Silver Amulet", "slot": "amulet", "icon": "amulet", "color": Color(0.9, 0.93, 1.0),
			"gem": Color(1.0, 0.55, 0.85), "buffs": {"toughness": 0.1}},
}

## Gems and the power their jewelry gives: [gem item, buff].
## [gem item, buff, that buff at full strength (MobData.BUFF_MAX)]
const JEWEL_GEMS := [["ruby", "leech", 0.25], ["sapphire", "toughness", 0.3], ["diamond", "fortune", 0.5], ["onyx_gem", "haste", 0.35], ["amethyst", "regen", 2.0]]
const JEWEL_SHARE := 0.55     # a perfect gem's main power, as a share of a radiant fairy's


static func jewel_id(gem_index: int, kind: String) -> String:
	return "%s_%s" % [str(JEWEL_GEMS[gem_index][0]).trim_suffix("_gem"), kind]


## Every animal gives its own meat. [id, name, raw value, raw food, cooked food,
## icon shape, raw color, cooked color]. Cooked meat heals much more and sells
## for a little more (see recipes.gd; never more than the fuel it cost).
const MEATS := [
	["rabbit", "Rabbit", 1.5, 1.0, 4.0, "drumstick", Color(0.92, 0.55, 0.55), Color(0.72, 0.48, 0.28)],
	["chicken", "Chicken", 1.5, 1.5, 5.0, "drumstick", Color(0.98, 0.72, 0.68), Color(0.85, 0.6, 0.3)],
	["venison", "Venison", 2.5, 2.0, 7.0, "steak", Color(0.72, 0.2, 0.25), Color(0.45, 0.25, 0.15)],
	["pork", "Pork Chop", 2.5, 2.0, 7.0, "chop", Color(0.98, 0.6, 0.62), Color(0.78, 0.5, 0.3)],
	["mutton", "Mutton", 2.0, 2.0, 6.0, "chop", Color(0.85, 0.35, 0.38), Color(0.6, 0.36, 0.2)],
	["wolf", "Wolf Meat", 2.0, 1.0, 5.0, "rib", Color(0.7, 0.28, 0.3), Color(0.5, 0.3, 0.2)],
	["cougar", "Cougar Meat", 3.0, 2.0, 7.0, "haunch", Color(0.8, 0.38, 0.32), Color(0.6, 0.38, 0.2)],
	["bear", "Bear Meat", 4.0, 3.0, 9.0, "steak", Color(0.62, 0.18, 0.2), Color(0.4, 0.22, 0.12)],
	["goat", "Goat Meat", 2.5, 2.0, 7.0, "rib", Color(0.88, 0.45, 0.42), Color(0.66, 0.42, 0.24)],
	["polar_bear", "Polar Bear Meat", 5.0, 3.0, 10.0, "haunch", Color(0.9, 0.5, 0.5), Color(0.7, 0.45, 0.28)],
]

## Old item ids from earlier versions, and what they turned into.
const OLD_MEAT_ALIASES := {"raw_meat": "raw_pork", "cooked_meat": "cooked_pork"}

## Armor sets: [material id, name, color, armor points for head, chest, legs, feet].
## Armor points add up; the shields over your hearts show how much of each hit is blocked (see survival.protection).
const ARMOR_SETS := [
	["leather", "Leather", Color(0.55, 0.36, 0.2), [1, 3, 2, 1]],
	["bronze", "Bronze", Color(0.75, 0.55, 0.25), [2, 5, 4, 2]],
	["iron", "Iron", Color(0.78, 0.78, 0.8), [4, 8, 7, 3]],
	["titanium", "Titanium", Color(0.58, 0.75, 0.95), [6, 12, 10, 6]],
]
const ARMOR_PIECES := [["helmet", "Helmet", "head"], ["chestplate", "Chestplate", "chest"],
		["leggings", "Leggings", "legs"], ["boots", "Boots", "feet"]]
const SLOT_ORDER := ["head", "chest", "legs", "feet"]

## Old item ids from earlier versions, and what they turned into.
const ALIASES := {"leather_armor": "leather_chestplate", "bronze_armor": "bronze_chestplate",
		"iron_armor": "iron_chestplate", "titanium_armor": "titanium_chestplate"}

static var ITEMS := {}


static var _icon_index := {}         # item id -> column in the icon atlas
static var _icon_atlas: ImageTexture


## Arrows: [id, name, tier, damage, head color, effect].
## Effects: "poison" (hurts a little every second for a while), "silver" (extra
## damage to scary mobs), "frost" (slows what it hits).
const ARROWS := [
	["wooden_arrow", "Wooden Arrow", 1, 3.0, Color(0.6, 0.45, 0.28), ""],
	["stone_arrow", "Stone Arrow", 1, 4.0, Color(0.55, 0.55, 0.57), ""],
	["bronze_arrow", "Bronze Arrow", 1, 5.0, Color(0.8, 0.58, 0.28), ""],
	["iron_arrow", "Iron Arrow", 2, 6.0, Color(0.8, 0.8, 0.83), ""],
	["poison_arrow", "Poison Arrow", 2, 4.0, Color(0.45, 0.85, 0.3), "poison"],
	["silver_arrow", "Silver Arrow", 2, 6.0, Color(0.93, 0.95, 1.0), "silver"],
	["titanium_arrow", "Titanium Arrow", 3, 8.5, Color(0.58, 0.75, 0.95), ""],
	["frost_arrow", "Frost Arrow", 3, 6.5, Color(0.7, 0.92, 1.0), "frost"],
]

## Capes: the flower you make one with picks its color and its power (the same
## powers fairies give, but gentler). [flower, color name, color, power,
## tier-2 extra, tier-3 extra]. Each cape rolls how strong it is when made.
const CAPES := [
	["poppy", "Red", Color(0.85, 0.2, 0.2), "haste", "leather", "cougar_pelt"],
	["dandelion", "Yellow", Color(0.98, 0.8, 0.25), "speed", "feather", "cougar_pelt"],
	["cornflower", "Blue", Color(0.3, 0.45, 0.9), "fireproof", "rabbit_hide", "bear_pelt"],
	["daisy", "White", Color(0.95, 0.95, 0.92), "regen", "rabbit_hide", "bear_pelt"],
	["bluebell", "Violet", Color(0.52, 0.4, 0.9), "fortune", "wolf_pelt", "bear_pelt"],
	["cactus_flower", "Pink", Color(1.0, 0.5, 0.75), "toughness", "cactus", "sand_bear_pelt"],
	["edelweiss", "Frost", Color(0.78, 0.9, 1.0), "warmth", "hare_fur", "polar_bear_pelt"],
	["candy_tulip", "Candy", Color(0.8, 0.45, 0.95), "jump", "gummy", "peppermint"],
]
const CAPE_TIERS := [["cape", "Cape"], ["hero_cape", "Hero Cape"], ["royal_cape", "Royal Cape"]]


## Item id of a cape: color index 0..7, tier 1..3.
static func cape_id(color: int, tier: int) -> String:
	return "%s_%s" % [String(CAPES[color][1]).to_lower(), CAPE_TIERS[tier - 1][0]]


## Maps and party maps (both open with M and fill in as you walk).
static func is_map(id: String) -> bool:
	return id == "map" or id == "party_map"


static func _static_init() -> void:
	ITEMS = BASE_ITEMS.duplicate(true)
	# Gem jewelry from the Jewelry Station. Each piece rolls how strong it came
	# out when it's made (see survival.roll_jewel); these "buffs" are a plain one.
	for gi in JEWEL_GEMS.size():
		var jg: Array = JEWEL_GEMS[gi]
		var gem: Dictionary = BASE_ITEMS[jg[0]]
		for kind in [["ring", "Ring", Color(0.9, 0.93, 1.0)], ["amulet", "Amulet", Color(1.0, 0.84, 0.25)]]:
			ITEMS[jewel_id(gi, kind[0])] = {"name": "%s %s" % [gem["name"], kind[1]], "slot": kind[0], "icon": kind[0],
					"color": kind[2], "gem": gem["color"], "jewel": jg[1], "value": 90.0 if gem["value"] > 40.0 else 60.0,
					"buffs": {jg[1]: snappedf(float(jg[2]) * JEWEL_SHARE * 0.75, 0.01)}}
	for a in ARROWS:
		ITEMS[a[0]] = {"name": a[1], "arrow": a[3], "arrow_tier": a[2], "effect": a[5], "icon": "arrow", "color": a[4]}
	for ci in CAPES.size():
		var cd: Array = CAPES[ci]
		for t in range(1, 4):
			ITEMS[cape_id(ci, t)] = {"name": "%s %s" % [cd[1], CAPE_TIERS[t - 1][1]], "cape": t, "slot": "back",
					"buff": cd[3], "icon": "cape", "color": cd[2]}
	for m in MEATS:
		ITEMS["raw_" + m[0]] = {"name": "Raw " + m[1], "value": m[2], "food": m[3], "icon": m[5], "color": m[6], "raw": true}
		ITEMS["cooked_" + m[0]] = {"name": "Cooked " + m[1], "food": m[4], "icon": m[5], "color": m[7], "cooked": true}
	for set_def in ARMOR_SETS:
		for i in 4:
			var piece: Array = ARMOR_PIECES[i]
			ITEMS["%s_%s" % [set_def[0], piece[0]]] = {"name": "%s %s" % [set_def[1], piece[1]],
					"armor": set_def[3][i], "slot": piece[2], "icon": piece[0], "color": set_def[2],
					"look_tier": ARMOR_SETS.find(set_def) + 1}
	# A trophy from every boss (put it on its statue at the spawn shrine).
	for b in BossData.BOSSES:
		ITEMS[BossData.trophy_id(b["id"])] = {"name": "%s Trophy" % b["name"], "icon": "trophy", "color": b["color"],
				"trophy": b["id"], "rarity": "legendary", "kind_text": "Boss Trophy",
				"lines": ["Power: %s" % b["power"], b["text"]],
				"flavor": "Put it on the %s statue at the shrine by spawn. Then pick its power there and press F to use it." % b["name"]}
	# Fences, walls and wedges for every building material.
	for fi in Blocks.FAMILIES.size():
		var fam: Array = Blocks.FAMILIES[fi]
		ITEMS[Blocks.fence_item(fi)] = {"name": fam[1] + (" Fence" if fam[6] else " Wall"), "block": Blocks.fence_block(fi)}
		ITEMS[Blocks.wedge_item(fi)] = {"name": fam[1] + " Wedge", "block": Blocks.wedge_block(fi)}
	# Cute versions of every crafted tool, weapon, piece of armor and cape
	# (made at the Cute Crafter). Pastel, with hearts and sparkles.
	for id in ITEMS.keys():
		if is_cutable(id):
			var cd: Dictionary = ITEMS[id].duplicate(true)
			cd["name"] = "Cute " + cd["name"]
			cd["cute"] = true
			cd["base"] = id
			cd["color"] = cute_color(cd.get("color", Color(0.8, 0.8, 0.8)))
			ITEMS["cute_" + id] = cd
	for id in ITEMS:
		if not ITEMS[id].has("block"):
			_icon_index[id] = _icon_index.size()


## Can the Cute Crafter make this cute? (Crafted gear only: no legendary
## treasure, and nothing that's already cute.)
static func is_cutable(id: String) -> bool:
	var d: Dictionary = ITEMS.get(id, {})
	if d.is_empty() or d.get("cute", false) or d.get("rarity", "") == "legendary":
		return false
	return d.has("tool") or d.has("armor") or d.has("bow") or d.has("cape")


## Gear colors go pastel and a little pink when they're made cute.
static func cute_color(c: Color) -> Color:
	return c.lerp(Color(1.0, 0.62, 0.82), 0.45).lightened(0.18)


static func exists(id: String) -> bool:
	return ITEMS.has(id)


static func display_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else id


static func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func max_stack(id: String) -> int:
	var d := get_def(id)
	if d.has("stack"):
		return int(d["stack"])
	return 1 if d.has("tool") or d.has("armor") or d.has("bow") or d.has("cape") or d.has("buffs") or d.get("unique", false) else MAX_STACK


static func block_of(id: String) -> int:
	return get_def(id).get("block", -1)


## Looks up the item that drops when a block is broken ("" = nothing).
static func drop_of_block(block: int) -> String:
	return Blocks.DROP[block]


## A short, friendly line about what an item is for (shown when you hover it).
static func describe(id: String) -> String:
	var d := get_def(id)
	if d.has("tool"):
		match d["tool"]:
			"pickaxe":
				return "Mines stone and ore. Better pickaxes mine rarer ore, faster."
			"axe":
				return "Chops wood, planks and benches fast."
			"sword":
				return "Hits mobs hard (%d damage)." % int(d["damage"])
	if d.get("cute", false):
		return "Made cute at the Cute Crafter! Cute things are a little bit better than plain ones (each one rolls its own bonus)."
	if d.has("bow"):
		return "Hold right-click to pull back, let go to shoot. Pull all the way for the strongest, furthest shot. Needs arrows."
	if d.has("arrow"):
		var fx := {"poison": " Poisons what it hits.", "silver": " Extra strong against scary monsters.", "frost": " Slows down what it hits."}
		return "Shoot it with a bow. %d damage.%s" % [int(d["arrow"]), fx.get(d.get("effect", ""), "")]
	if d.has("cape"):
		return "Wear it in your cape slot. Each cape is a little different when it's made!"
	if d.has("buffs"):
		return "Wear it in your %s slot (next to your armor)." % d.get("slot", "ring")
	if d.get("tool", "") == "shovel":
		return "Digs dirt, sand, snow, frosting and cake quickly."
	if d.has("armor"):
		return "Wear it on your %s. +%d armor (each shield blocks a bit of damage)." % [
			{"head": "head", "chest": "body", "legs": "legs", "feet": "feet"}[d["slot"]], int(d["armor"])]
	if d.get("raw", false):
		return "Right-click to eat (heals %d). Cook it in a furnace first and it heals a lot more!" % int(d["food"])
	if d.has("food"):
		return "Right-click to eat. Heals %d health." % int(d["food"])
	match id:
		"workbench_1", "workbench_2", "workbench_3":
			return "Place it, then right-click it to unlock and craft new things."
		"sawmill":
			return "Place it and right-click it to make stairs, slabs, furniture and carved wood."
		"portalstone":
			return "Build a frame out of it (a rectangle with an empty middle, 2-6 wide and 3-6 tall). Name the portal, then build another the same size with the same name to link them!"
		"cute_crafter":
			return "Place it and right-click it to make your tools, weapons, armor and capes CUTE (and a little stronger)."
		"cutie_ore":
			return "Found in candy land's cake. Smelt it into a Cutieite Ingot."
		"cutieite_ingot":
			return "Sparkly! Use it at the Cute Crafter to make your gear cute."
		"pumpkin":
			return "A big round pumpkin. Bake it into Pumpkin Pie, carve it into a Jack-o'-Lantern, or use it to decorate!"
		"jack_o_lantern":
			return "A pumpkin with a friendly carved face, glowing from inside. Lights up the dark!"
		"ghost_lantern":
			return "A lantern full of glowing ectoplasm. Lights things up forever, with a spooky green-blue glow."
		"gravestone":
			return "Spooky decoration. It faces away from you when you place it."
		"vine":
			return "Climb it! Hold jump (or walk into it) to go up. Hang it under ledges to make ladders."
		"ancient_coin":
			return "An old coin from the floating islands. The Block Shop pays a lot for it!"
		"ectoplasm":
			return "Glowing ghost goo! Make Ghost Lanterns out of it at a Workbench Tier 2."
		"witch_hat":
			return "A pointy witch's hat. Wear it on your head!"
		"hay_bale":
			return "A cozy block of straw. Nice for a farm or a fall party."
		"stonecutter":
			return "Place it and right-click it to make bricks, stairs, slabs, pillars and carved stone."
		"shaper":
			return "Place it and right-click it to make metal blocks, metal slabs and inlaid bricks."
		"shop":
			return "Place it, then right-click it to sell things for toots."
		"furnace":
			return "Place it, then right-click it to turn ore into ingots."
		"lamp":
			return "Lights things up forever. Scary mobs can't appear near lamps."
		"torch":
			return "Easy light! It burns out after about 5 minutes."
		"chest":
			return "Place it, then right-click it to store your things. Only one person can look inside at a time."
		"super_chest":
			return "Your own magic storage! Every Super Chest opens the same box, and only you can see what's in yours. Pick it up and take it anywhere: your things stay safe inside."
		"campfire":
			return "A cozy fire that lights up the night. Right-click it to rest by the fire until morning (your respawn point stays where it was)."
		"bedroll":
			return "A blanket you can roll out anywhere. Right-click it at night to sleep. It doesn't change your respawn point."
		"oak_sapling", "redwood_sapling", "pine_sapling", "palm_sapling", "maple_sapling", "golden_sapling", "candy_sapling":
			return "Plant it on grass or dirt and it grows into a tree in a few days. (Pines like snow too, palms like sand, candy trees like frosting.)"
		"bed":
			return "Right-click it to sleep through the night and make it your respawn point."
		"wooden_door", "iron_door", "titanium_door":
			return "Place it in a 1x2 gap. Right-click to open and close. Stronger doors are harder to break."
		"scribe":
			return "Place it and right-click it to write names on your tools, weapons, armor, capes and maps, in any ink color."
		"research_table":
			return "Place it near your workbenches and right-click it to learn new recipes with toots. Find new things in the world to discover more."
		"item_frame":
			return "Hang it on a wall, then right-click it with something to show it off. Maps show their land!"
		"armor_stand":
			return "Place it, then right-click it to dress it up in armor and a cape."
		"coal":
			return "Furnaces leave it behind when they burn wood. It burns too, and with a Water Bottle it makes Ink."
		"glass_bottle":
			return "Right-click water while holding it to fill it up."
		"water_bottle":
			return "A bottle of water. Mix it with coal to make ink!"
		"bucket":
			return "Right-click still water (a lake or the sea) to scoop some up."
		"water_bucket":
			return "Right-click to pour the water out. It flows like real water, so be careful!"
		"ember":
			return "A glowing ember from the lava caverns. Great fuel for a furnace, and it sells well."
		"drake_scale":
			return "A tough red scale from a fire drake."
		"magma_rock":
			return "The cracked, glowing rock of the lava caverns, deep in the Deep."
		"lava_bucket":
			return "Right-click to pour the lava out (careful, it burns!). Pour water next to lava to make Cinderstone."
		"bedstone":
			return "The hard crust over the Deep. Only a Titanium Pickaxe (or better) can break it."
		"deepstone":
			return "The dark stone of the Deep, far below the caves."
		"cinderstone":
			return "Made where water meets still lava. You need 4 for a Jewelry Station."
		"glow_crystal":
			return "A little glowing crystal from the Deep's floors. Place it for a soft light."
		"jewelry_station":
			return "Place it and right-click it to set gems into rings and amulets. Each one rolls how good it comes out!"
		"ruby", "sapphire", "diamond", "onyx_gem", "amethyst":
			return "A gem from the Deep (below the Bedstone crust). Set it into a ring or amulet at a Jewelry Station."
		"grass_tuft":
			return "Plant it on the ground again, or turn 3 of them into Paper at a Workbench Tier 1."
		"paper":
			return "Make a Map out of it at a Workbench Tier 2."
		"map":
			return "Right-click while holding it, or press M, to look. It fills in everywhere you go while you carry it. Mark spots with little pictures!"
		"party_map":
			return "Your whole party shares this map: everywhere any of you go fills in, and you can see where your friends are. (Only works for the party it was made for.)"
	if d.has("ink"):
		return "Ink for the Scribe bench: write names on your things (the color shows on the label)."
	if d.get("plant", false):
		return "A pretty plant. Put it on the ground to plant it again."
	if id.ends_with("_ore"):
		return "Smelt it in a furnace to make an ingot."
	if id.ends_with("_ingot"):
		return "Metal for crafting tools and armor."
	if d.has("block") and Blocks.SHAPE[d["block"]] != "":
		match Blocks.SHAPE[d["block"]]:
			"slab", "stairs":
				return "Faces away from you when you place it. Click the top half of a block (or its underside) to put it upside down."
		return "Furniture! It faces away from you when you place it."
	if d.has("block"):
		return "A block you can place."
	return "Sell it at the Block Shop, or use it to craft."


# --- Icons -------------------------------------------------------------------------

## "legendary" or "" (normal).
static func rarity(id: String) -> String:
	return get_def(id).get("rarity", "")


static func resolve_alias(id: String) -> String:
	return ALIASES.get(id, OLD_MEAT_ALIASES.get(id, id))


static var _shields := {}
static var _coin: ImageTexture
static var _hearts := {}
static var _crack: ImageTexture


## A little gold toot coin.
static func coin_icon() -> ImageTexture:
	if _coin == null:
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
				if d < 7.5:
					var c := Color(1.0, 0.8, 0.22)
					if d > 6.2:
						c = Color(0.78, 0.52, 0.08)
					elif d > 5.0:
						c = Color(1.0, 0.88, 0.4)
					# a "T" for toots
					if (y >= 4 and y <= 5 and x >= 5 and x <= 10) or (x >= 7 and x <= 8 and y >= 4 and y <= 11):
						c = Color(0.72, 0.45, 0.05)
					if x + y < 9 and d < 5.0:
						c = c.lightened(0.25)
					img.set_pixel(x, y, c)
		_coin = ImageTexture.create_from_image(img)
	return _coin


## kind: "full", "half" or "empty".
static func heart_icon(kind: String) -> ImageTexture:
	if not _hearts.has(kind):
		var shape := [
			"..XX...XX..",
			".XRRX.XRRX.",
			"XRWRRXRRRRX",
			"XRRRRRRRRRX",
			"XRRRRRRRRRX",
			".XRRRRRRRX.",
			"..XRRRRRX..",
			"...XRRRX...",
			"....XRX....",
			".....X.....",
		]
		var img := Image.create_empty(11, 10, false, Image.FORMAT_RGBA8)
		for y in shape.size():
			for x in shape[y].length():
				var ch: String = shape[y][x]
				if ch == ".":
					continue
				var filled: bool = kind == "full" or (kind == "half" and x <= 5)
				var c := Color(0.15, 0.05, 0.08)
				if ch == "R":
					c = Color(0.92, 0.2, 0.25) if filled else Color(0.3, 0.12, 0.16)
				elif ch == "W":
					c = Color(1, 0.75, 0.75) if filled else Color(0.4, 0.2, 0.24)
				img.set_pixel(x, y, c)
		_hearts[kind] = ImageTexture.create_from_image(img)
	return _hearts[kind]


static var _bubble: ImageTexture
static var _snowflake: ImageTexture
static var _sparkle: ImageTexture


static func snowflake_icon() -> ImageTexture:
	if _snowflake == null:
		var img := Image.create_empty(15, 15, false, Image.FORMAT_RGBA8)
		for k in 3:
			var a := k * PI / 3.0
			for r in range(-7, 8):
				var x := 7 + int(round(cos(a) * r))
				var y := 7 + int(round(sin(a) * r))
				img.set_pixel(x, y, Color(1, 1, 1))
				if absi(r) == 5:  # little side branches
					for s in [-1, 1]:
						var bx := x + int(round(cos(a + s * 1.0) * 1.5))
						var by := y + int(round(sin(a + s * 1.0) * 1.5))
						if bx >= 0 and by >= 0 and bx < 15 and by < 15:
							img.set_pixel(bx, by, Color(1, 1, 1))
		_snowflake = ImageTexture.create_from_image(img)
	return _snowflake


## A four-pointed sparkle (for the fairy power; tinted with the fairy's color).
static func sparkle_icon() -> ImageTexture:
	if _sparkle == null:
		var img := Image.create_empty(15, 15, false, Image.FORMAT_RGBA8)
		for y in 15:
			for x in 15:
				var dx := absf(x - 7.0)
				var dy := absf(y - 7.0)
				var v := 1.0 - (dx * dy) / 3.0 - (dx + dy) / 11.0
				if v > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, clampf(v * 1.6, 0.0, 1.0)))
		_sparkle = ImageTexture.create_from_image(img)
	return _sparkle


## An air bubble (shown above your hearts while underwater).
static func bubble_icon() -> ImageTexture:
	if _bubble == null:
		var img := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
		for y in 10:
			for x in 10:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(5, 5))
				if d < 4.6:
					var c := Color(0.55, 0.8, 1.0, 0.85) if d > 3.4 else Color(0.35, 0.6, 0.95, 0.45)
					if Vector2(x, y).distance_to(Vector2(3.2, 3.2)) < 1.1:
						c = Color(1, 1, 1, 0.95)
					img.set_pixel(x, y, c)
		_bubble = ImageTexture.create_from_image(img)
	return _bubble


## kind: "full", "half" or "empty".
static func shield_icon(kind: String) -> ImageTexture:
	if not _shields.has(kind):
		var shape := [
			"XXXXXXXXX",
			"XWSSSSSSX",
			"XSSSSSSSX",
			"XSSSSSSSX",
			"XSSSSSSSX",
			".XSSSSSX.",
			".XSSSSSX.",
			"..XSSSX..",
			"...XSX...",
			"....X....",
		]
		var img := Image.create_empty(9, 10, false, Image.FORMAT_RGBA8)
		for y in shape.size():
			for x in shape[y].length():
				var ch: String = shape[y][x]
				if ch == ".":
					continue
				var filled: bool = kind == "full" or (kind == "half" and x <= 4)
				var c := Color(0.12, 0.13, 0.18)
				if ch == "S":
					c = Color(0.62, 0.72, 0.88) if filled else Color(0.25, 0.28, 0.36)
				elif ch == "W":
					c = Color(0.9, 0.95, 1.0) if filled else Color(0.35, 0.38, 0.46)
				img.set_pixel(x, y, c)
		_shields[kind] = ImageTexture.create_from_image(img)
	return _shields[kind]


## Cracks that spread from the middle. Each pixel's red channel says how far
## along the mining has to be before that crack pixel shows up.
static func crack_texture() -> ImageTexture:
	if _crack == null:
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 0, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		for branch in 7:
			var p := Vector2(7.5 + rng.randf_range(-1, 1), 7.5 + rng.randf_range(-1, 1))
			var a := branch * TAU / 7.0 + rng.randf_range(-0.3, 0.3)
			for step in 12:
				var x := clampi(int(p.x), 0, 15)
				var y := clampi(int(p.y), 0, 15)
				var stage := clampf(p.distance_to(Vector2(8, 8)) / 10.0 + rng.randf_range(0.0, 0.1), 0.05, 0.95)
				if img.get_pixel(x, y).a == 0.0 or img.get_pixel(x, y).r > stage:
					img.set_pixel(x, y, Color(stage, 0, 0, 1))
				a += rng.randf_range(-0.6, 0.6)
				p += Vector2(cos(a), sin(a))
		_crack = ImageTexture.create_from_image(img)
	return _crack


## Average color of an item's icon (used for block-break bits).
static func average_color(id_or_block) -> Color:
	var tex: Texture2D
	var region: Rect2
	if id_or_block is int:
		tex = Blocks.get_atlas()
		region = Blocks.tile_region(Blocks.FACE_TILES[id_or_block][0])
	else:
		var a := icon(id_or_block)
		tex = a.atlas
		region = a.region
	var img := tex.get_image()
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(int(region.position.y), int(region.end.y)):
		for x in range(int(region.position.x), int(region.end.x)):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				sum += c
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n) if n > 0 else Color.GRAY

const ICON_PX := 32

static var _block_icons: ImageTexture


## Texture + region for drawing an item's icon in the UI (32 x 32).
static func icon(id: String) -> AtlasTexture:
	var tex := AtlasTexture.new()
	var d := get_def(id)
	if d.has("block"):
		if _block_icons == null:
			_block_icons = ImageTexture.create_from_image(_build_block_icons())
		tex.atlas = _block_icons
		tex.region = Rect2(d["block"] * ICON_PX, 0, ICON_PX, ICON_PX)
	else:
		if _icon_atlas == null:
			_icon_atlas = ImageTexture.create_from_image(_build_icon_atlas())
		tex.atlas = _icon_atlas
		tex.region = Rect2(_icon_index.get(id, 0) * ICON_PX, 0, ICON_PX, ICON_PX)
	return tex


## Call after the block textures change (graphics setting) so icons match.
static func refresh_block_icons() -> void:
	if _block_icons != null:
		_block_icons.set_image(_build_block_icons())


## Items are drawn on a 16x16 grid, doubled to 32x32, then given a soft dark
## outline and a little light/shadow on their edges so they read clearly.
static func _build_icon_atlas() -> Image:
	var img := Image.create_empty(ICON_PX * maxi(_icon_index.size(), 1), ICON_PX, false, Image.FORMAT_RGBA8)
	for id in _icon_index:
		var small := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		_paint_icon(small, 0, get_def(id))
		if get_def(id).get("cute", false) or get_def(id).get("sparkle", false):
			_cute_touch(small, get_def(id))
		small.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
		_polish(small)
		img.blit_rect(small, Rect2i(0, 0, ICON_PX, ICON_PX), Vector2i(_icon_index[id] * ICON_PX, 0))
	return img


## Block icons: a little 3D cube (top + two sides), like an inventory in
## Minecraft. Torches, doors and beds use their flat picture instead.
static func _build_block_icons() -> Image:
	var atlas := Blocks.get_atlas().get_image()
	var img := Image.create_empty(ICON_PX * Blocks.COUNT, ICON_PX, false, Image.FORMAT_RGBA8)
	var tp := Blocks.TILE_PX
	for b in Blocks.COUNT:
		var icon := Image.create_empty(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
		if b == Blocks.AIR:
			pass
		elif Blocks.SHAPE[b] != "":
			for py in ICON_PX:
				for px in ICON_PX:
					var c := _iso_shape_pixel(atlas, b, px + 0.5, py + 0.5, tp)
					if c.a > 0.0:
						icon.set_pixel(px, py, c)
		elif Blocks.MODEL[b] != "" or Blocks.is_water(b):
			var t: int = Blocks.ICON[b]
			icon.blit_rect(atlas, Rect2i(t * tp, 0, tp, tp), Vector2i.ZERO)
			if tp != ICON_PX:
				icon.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
			if not Blocks.is_water(b):
				icon = _center_icon(icon)
		else:
			var tiles: Array = Blocks.FACE_TILES[b]
			for py in ICON_PX:
				for px in ICON_PX:
					var c := _iso_pixel(atlas, tiles, px + 0.5, py + 0.5, tp)
					if c.a > 0.0:
						icon.set_pixel(px, py, c)
		_polish(icon)
		img.blit_rect(icon, Rect2i(0, 0, ICON_PX, ICON_PX), Vector2i(b * ICON_PX, 0))
	return img


## Plants, saplings, torches and beds are drawn sitting on the ground (for the
## world), so their pictures sit low or to one side. For the icon, move the
## picture to the middle (and make tiny ones twice as big).
static func _center_icon(icon: Image) -> Image:
	var lo := Vector2i(ICON_PX, ICON_PX)
	var hi := Vector2i(-1, -1)
	for y in ICON_PX:
		for x in ICON_PX:
			if icon.get_pixel(x, y).a > 0.1:
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return icon
	var rect := Rect2i(lo, hi - lo + Vector2i.ONE)
	var part := icon.get_region(rect)
	if maxi(rect.size.x, rect.size.y) * 2 <= ICON_PX - 4:
		part.resize(rect.size.x * 2, rect.size.y * 2, Image.INTERPOLATE_NEAREST)
	var out := Image.create_empty(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	var at := (Vector2i(ICON_PX, ICON_PX) - part.get_size()) / 2
	out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), at)
	return out


## A shaped block's icon: look at its boxes from above and to the side (like
## the block cubes), and color each pixel by the face it lands on.
static func _iso_shape_pixel(atlas: Image, b: int, x: float, y: float, tp: int) -> Color:
	var d := Vector3(-1, -1, -1).normalized()
	var right := Vector3(1, 0, -1).normalized()
	var up := Vector3(-1, 2, -1).normalized()
	var scale := 19.0
	var origin := Vector3(0.5, 0.5, 0.5) + right * ((x - 16.0) / scale) + up * ((16.5 - y) / scale) - d * 4.0
	var best := INF
	var hit_face := -1
	var hit_p := Vector3.ZERO
	for box in Blocks.shape_boxes(b, 0):
		var a: Vector3 = box[0]
		var c: Vector3 = box[1]
		var t_near := -INF
		var t_far := INF
		var face := -1
		var ok := true
		for axis in 3:
			var o: float = origin[axis]
			var dv: float = d[axis]
			var t1: float = (a[axis] - o) / dv
			var t2: float = (c[axis] - o) / dv
			var enter := minf(t1, t2)
			var leave := maxf(t1, t2)
			if enter > t_near:
				t_near = enter
				face = axis
			t_far = minf(t_far, leave)
			if t_near > t_far:
				ok = false
				break
		if ok and t_near < t_far and t_near < best:
			best = t_near
			hit_face = face
			hit_p = origin + d * t_near
	if hit_face < 0:
		return Color(0, 0, 0, 0)
	var tiles: Array = Blocks.FACE6[b]
	var f: int = [0, 2, 4][hit_face]
	var uv := Vector2(hit_p.z, 1.0 - hit_p.y) if hit_face == 0 else (Vector2(hit_p.x, hit_p.z) if hit_face == 1 else Vector2(hit_p.x, 1.0 - hit_p.y))
	var shade: float = [0.78, 1.0, 0.6][hit_face]
	return _sample(atlas, tiles[f], clampf(uv.x, 0.0, 0.999), clampf(uv.y, 0.0, 0.999), tp, shade)


## Which face of the little cube a pixel lands on, and its color.
static func _iso_pixel(atlas: Image, tiles: Array, x: float, y: float, tp: int) -> Color:
	# Cube corners (in a 32x32 icon, with a 1-pixel margin):
	# top face T(16,1) R(31,8.5) B(16,16) L(1,8.5); the sides drop 14.5 pixels.
	var w := 15.0
	var h := 7.5
	var drop := 14.5
	var dx := x - 16.0
	var dy := y - 1.0
	var u := (dx / w + dy / h) * 0.5
	var v := (dy / h - dx / w) * 0.5
	if u >= 0.0 and u < 1.0 and v >= 0.0 and v < 1.0:
		return _sample(atlas, tiles[0], u, v, tp, 1.0)
	if x < 16.0:
		var a := (x - 1.0) / w
		var b := (y - 8.5 - a * h) / drop
		if a >= 0.0 and a < 1.0 and b >= 0.0 and b < 1.0:
			return _sample(atlas, tiles[1], a, b, tp, 0.78)
	else:
		var a := (x - 16.0) / w
		var b := (y - 16.0 + a * h) / drop
		if a >= 0.0 and a < 1.0 and b >= 0.0 and b < 1.0:
			return _sample(atlas, tiles[1], a, b, tp, 0.6)
	return Color(0, 0, 0, 0)


static func _sample(atlas: Image, tile: int, u: float, v: float, tp: int, shade: float) -> Color:
	var c := atlas.get_pixel(tile * tp + clampi(int(u * tp), 0, tp - 1), clampi(int(v * tp), 0, tp - 1))
	return Color(c.r * shade, c.g * shade, c.b * shade, c.a)


## Soft outline + light top-left edges + darker bottom-right edges.
static func _polish(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate()
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	for y in h:
		for x in w:
			var c: Color = src.get_pixel(x, y)
			if c.a <= 0.5:
				if solid.call(x - 1, y) or solid.call(x + 1, y) or solid.call(x, y - 1) or solid.call(x, y + 1):
					img.set_pixel(x, y, Color(0.04, 0.04, 0.07, 0.75))
				elif solid.call(x - 1, y - 1) or solid.call(x + 1, y + 1) or solid.call(x + 1, y - 1) or solid.call(x - 1, y + 1):
					img.set_pixel(x, y, Color(0.04, 0.04, 0.07, 0.3))
				continue
			if not solid.call(x, y - 1) or not solid.call(x - 1, y):
				img.set_pixel(x, y, c.lightened(0.18))
			elif not solid.call(x, y + 1) or not solid.call(x + 1, y):
				img.set_pixel(x, y, c.darkened(0.22))


static func _px(img: Image, ox: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(ox + x, y, c)


## Draws a thick diagonal handle from bottom-left toward the top-right.
static func _handle(img: Image, ox: int, from: int, to: int) -> void:
	var wood := Color(0.48, 0.33, 0.18)
	for i in range(from, to):
		_px(img, ox, i, 15 - i, wood)
		_px(img, ox, i + 1, 15 - i, wood.darkened(0.25))


# --- Tools and armor -------------------------------------------------------------------
# Painted with care: every tool leans the same way (handle bottom-left, head
# top-right, held at pixel (3,12)), with a light top-left edge, a dark
# bottom-right edge, and finer details as the tiers go up.

const WOOD := Color(0.5, 0.34, 0.19)
const WRAP := Color(0.32, 0.2, 0.12)       # leather grip wrap
const GOLD_TRIM := Color(1.0, 0.8, 0.3)


## Position along the handle (x, from `from` toward the head) and across it (y).
static func _along(x: int, y: int, from: Vector2) -> Vector2:
	var p := Vector2(x + 0.5, y + 0.5) - from
	return Vector2(p.dot(Vector2(0.7071, -0.7071)), p.dot(Vector2(0.7071, 0.7071)))


## Shading across a blade: lighter on the top-left side, darker on the bottom-right.
static func _lit(c: Color, s_across: float, edge: float) -> Color:
	if s_across < -edge:
		return c.lightened(0.32)
	if s_across > edge:
		return c.darkened(0.3)
	return c


## Wooden handle from the bottom-left corner up to `length`, with a grip wrap.
static func _paint_handle(img: Image, ox: int, length: float, tier: int) -> void:
	var base := Vector2(1.5, 14.5)
	for y in 16:
		for x in 16:
			var a := _along(x, y, base)
			if a.x < -0.3 or a.x > length or absf(a.y) > 0.72:
				continue
			var c := WOOD.lightened(0.15) if a.y < -0.1 else WOOD.darkened(0.2)
			if a.x > 1.2 and a.x < 4.4:
				var band := int(a.x * 1.4) % 2 == 0
				c = WRAP.lightened(0.18) if band else WRAP  # grip wrap
				if tier >= 4 and band:
					c = Color(0.55, 0.2, 0.18)  # red wrap on iron and up
			_px(img, ox, x, y, c)
	_px(img, ox, 1, 14, WOOD.darkened(0.35) if tier < 3 else Color(0.6, 0.6, 0.62))  # end cap


static func _paint_tool(img: Image, ox: int, d: Dictionary, kind: String) -> void:
	var c: Color = d.get("color", Color(0.8, 0.8, 0.8))
	var tier := int(d.get("tier", 1))
	var wooden := tier == 1
	var stone := tier == 2
	match kind:
		"pickaxe":
			_paint_handle(img, ox, 14.2, tier)
			# A curved head across the top-right: thick in the middle, pointed at both ends.
			var center := Vector2(2.0, 14.0)
			for y in 16:
				for x in 16:
					var p := Vector2(x + 0.5, y + 0.5) - center
					var ang := rad_to_deg(atan2(-p.y, p.x)) - 45.0   # 0 = straight up the handle
					if absf(ang) > 41.0:
						continue
					var k := absf(ang) / 41.0
					var thick := lerpf(2.05, 0.6, k * k)
					var off := p.length() - (12.4 + k * 0.6)
					if absf(off) > thick:
						continue
					var col := c
					if off > thick * 0.35:
						col = c.lightened(0.3)      # outer edge catches the light
					elif off < -thick * 0.35:
						col = c.darkened(0.3)
					if wooden and (x + y * 3) % 5 == 0:
						col = col.darkened(0.12)    # wood grain
					if stone and (x * 7 + y * 3) % 6 == 0:
						col = col.darkened(0.18)    # stone flecks
					if k > 0.82 and tier >= 3:
						col = c.lightened(0.45)     # sharp, shiny tips
					_px(img, ox, x, y, col)
			_px(img, ox, 10, 5, c.darkened(0.45))   # where the head meets the handle
			_px(img, ox, 11, 4, (GOLD_TRIM if tier >= 5 else c.lightened(0.5)) if tier >= 3 else c.darkened(0.25))
		"axe":
			_paint_handle(img, ox, 14.0, tier)
			# A flared blade on the top-left side of the handle, near the top.
			var h := Vector2(10.5, 5.5)
			for y in 16:
				for x in 16:
					var p := Vector2(x + 0.5, y + 0.5) - h
					var u := p.dot(Vector2(0.7071, -0.7071)) + 0.4   # along the handle
					var v := p.dot(Vector2(-0.7071, -0.7071))        # out toward the edge
					var reach := 5.6 - u * u * 0.09
					if v > -0.6 and v < reach and absf(u) < 1.6 + maxf(v, 0.0) * 0.42:
						var col := c
						if v > reach - 1.2:
							col = c.lightened(0.4)    # sharpened edge
						elif u > 0.9:
							col = c.darkened(0.28)
						elif u < -0.9:
							col = c.lightened(0.12)
						if wooden and (x + y * 2) % 4 == 0:
							col = col.darkened(0.12)
						if stone and (x * 5 + y) % 7 == 0:
							col = col.darkened(0.18)
						_px(img, ox, x, y, col)
					elif v <= -0.6 and v > -2.4 and absf(u) < 1.0:
						_px(img, ox, x, y, c.darkened(0.3))   # back of the head
			if tier >= 3:
				_px(img, ox, 9, 6, c.lightened(0.5))
			if tier >= 5:
				_px(img, ox, 7, 6, GOLD_TRIM)
		"sword":
			var g := Vector2(4.5, 11.5)    # middle of the crossguard
			var tip := 13.4
			for y in 16:
				for x in 16:
					var a := _along(x, y, g)
					var t := a.x
					var w := 1.75 if t < tip - 3.0 else lerpf(1.75, 0.8, (t - (tip - 3.0)) / 3.0)   # a clean point (no lone pixel at the tip)
					if t > 1.0 and t < tip and absf(a.y) < w:
						var col := _lit(c, a.y, 0.55)
						if absf(a.y) < 0.4 and t > 2.0 and t < tip - 3.0 and tier >= 3:
							col = c.darkened(0.15)    # groove down the middle
						if wooden and (x + y) % 3 == 0:
							col = col.darkened(0.1)
						_px(img, ox, x, y, col)
					elif t > -0.2 and t <= 1.0 and absf(a.y) < (3.4 if tier >= 3 else 2.8):
						var guard: Color = Color(0.42, 0.3, 0.18) if tier <= 2 else (GOLD_TRIM if tier >= 4 else c.darkened(0.2))
						_px(img, ox, x, y, guard.lightened(0.2) if a.y < 0.0 else guard.darkened(0.15))
					elif t > -3.2 and t <= -0.2 and absf(a.y) < 0.75:
						_px(img, ox, x, y, WRAP.lightened(0.2) if int(-t * 1.5) % 2 == 0 else WRAP)  # grip
					elif t > -4.6 and t <= -3.2 and absf(a.y) < 1.2:
						_px(img, ox, x, y, GOLD_TRIM if tier >= 4 else c.darkened(0.25))  # pommel
			if tier >= 5:
				_px(img, ox, 4, 11, Color(0.5, 0.85, 1.0))  # a gem in the guard
		"shovel":
			# One piece: a long handle with a D-grip at the end, a metal collar,
			# and a rounded spade blade with a point, like a real garden spade.
			_paint_handle(img, ox, 11.6, tier)
			for p in [Vector2i(0, 13), Vector2i(0, 14), Vector2i(0, 15), Vector2i(1, 15), Vector2i(2, 15), Vector2i(1, 13), Vector2i(2, 14)]:
				_px(img, ox, p.x, p.y, WOOD.darkened(0.3) if p.x + p.y > 14 else WOOD.lightened(0.1))   # D-grip
			var h2 := Vector2(11.2, 4.8)
			for y in 16:
				for x in 16:
					var a := _along(x, y, h2)
					if a.x > -2.4 and a.x <= -0.9 and absf(a.y) < 1.05:
						_px(img, ox, x, y, c.darkened(0.4) if a.y > 0.0 else c.darkened(0.2))   # the collar round the handle
						continue
					var w2 := 2.75 if a.x < 2.2 else 2.75 - (a.x - 2.2) * 1.05   # rounded, then to a point
					if a.x > -0.9 and a.x < 4.8 and absf(a.y) < w2:
						var col := _lit(c, a.y, 1.15)
						if a.x < -0.3:
							col = col.darkened(0.15)          # the top edge you step on
						if absf(a.y) < 0.45 and a.x > 0.2 and a.x < 3.0:
							col = c.darkened(0.12)            # a ridge down the middle
						if wooden and (x + y * 2) % 4 == 0:
							col = col.darkened(0.12)
						if stone and (x * 5 + y) % 7 == 0:
							col = col.darkened(0.18)
						_px(img, ox, x, y, col)
			if tier >= 3:
				_px(img, ox, 13, 3, c.lightened(0.5))   # a shiny tip


## Armor, with more shape and shine at each tier:
## 1 leather (stitches), 2 bronze (rivets), 3 iron (plates, ridges, shine),
## 4 titanium (gold trim and gems).
static func _paint_armor(img: Image, ox: int, d: Dictionary, piece: String) -> void:
	var c: Color = d.get("color", Color(0.8, 0.8, 0.8))
	var tier := int(d.get("look_tier", 1))
	var trim: Color = c.darkened(0.35) if tier < 4 else GOLD_TRIM
	var shapes := {}   # pixel -> "main", "trim" or "plate"
	for y in 16:
		for x in 16:
			var part := ""
			match piece:
				"helmet":
					var dome := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 9.5)) < 6.9 and y <= 9
					var cheek := y >= 10 and y <= 13 and ((x >= 2 and x <= 4) or (x >= 11 and x <= 13))
					if dome or cheek:
						part = "main"
						if y == 9 and x >= 2 and x <= 13:
							part = "trim"            # the rim
					if tier >= 3 and (x == 7 or x == 8) and y >= 9 and y <= 12:
						part = "trim"                # nose guard
					if tier >= 4 and y <= 3 and (x == 7 or x == 8):
						part = "plate"               # a crest on top
				"chestplate":
					var shoulder := y >= 2 and y <= 5 and ((x >= 1 and x <= 4) or (x >= 11 and x <= 14))
					var body := y >= 3 and y <= 14 and x >= 4 and x <= 11
					var neck := y <= 4 and x >= 6 and x <= 9
					var waist := y >= 13 and (x == 4 or x == 11)
					if (shoulder or body) and not neck and not waist:
						part = "main"
						if shoulder and tier >= 2:
							part = "plate"
						if body and y == 14:
							part = "trim"
						if body and tier >= 3 and (y == 8 or y == 11) and x > 4 and x < 11:
							part = "trim"            # plate seams
				"leggings":
					var belt := y >= 2 and y <= 4 and x >= 3 and x <= 12
					var leg := y >= 5 and y <= 14 and x >= 3 and x <= 12 and not (y >= 7 and x >= 7 and x <= 8)
					if belt:
						part = "trim"
					elif leg:
						part = "main"
						if tier >= 3 and y >= 9 and y <= 10:
							part = "plate"           # knee plates
				"boots":
					var lb := y >= 6 and y <= 13 and x >= 1 and x <= 6 and (y >= 10 or x >= 3)
					var rb := y >= 6 and y <= 13 and x >= 9 and x <= 14 and (y >= 10 or x <= 12)
					if lb or rb:
						part = "main"
						if y >= 13:
							part = "trim"            # sole
						elif y <= 7 and tier >= 2:
							part = "plate"           # cuff
			if part != "":
				shapes[Vector2i(x, y)] = part
	for p in shapes:
		var x: int = p.x
		var y: int = p.y
		var part: String = shapes[p]
		var col: Color = c
		if part == "trim":
			col = trim
		elif part == "plate":
			col = c.lightened(0.12)
		# Rounded shading, lit from the top-left, so it looks like it has depth.
		var shade := 0.18 - (x + y) / 30.0 * 0.36
		col = col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
		if not shapes.has(Vector2i(x, y - 1)) or not shapes.has(Vector2i(x - 1, y)):
			col = col.lightened(0.22)
		elif not shapes.has(Vector2i(x, y + 1)) or not shapes.has(Vector2i(x + 1, y)):
			col = col.darkened(0.25)
		var near_edge := not shapes.has(Vector2i(x - 2, y)) or not shapes.has(Vector2i(x + 2, y)) \
				or not shapes.has(Vector2i(x, y - 2)) or not shapes.has(Vector2i(x, y + 2))
		var on_edge := not shapes.has(Vector2i(x - 1, y)) or not shapes.has(Vector2i(x + 1, y)) \
				or not shapes.has(Vector2i(x, y - 1)) or not shapes.has(Vector2i(x, y + 1))
		if tier == 1 and part == "main" and near_edge and not on_edge and (x + y) % 2 == 0:
			col = Color(0.85, 0.75, 0.55)   # stitches near the edges
		if tier >= 2 and part in ["trim", "plate"] and (x + y) % 3 == 0 and not on_edge:
			col = c.lightened(0.5) if tier < 4 else Color(1.0, 0.95, 0.7)  # rivets
		if tier >= 3 and part == "main" and piece == "chestplate" and (x == 7 or x == 8) and y > 4 and y < 14:
			col = col.lightened(0.18) if x == 7 else col.darkened(0.08)  # center ridge
		if tier >= 3 and part == "main" and (x * 3 + y * 5) % 11 == 0:
			col = col.lightened(0.3)        # shine
		_px(img, ox, x, y, col)
	if tier >= 4:
		var gems := {"helmet": Vector2i(7, 5), "chestplate": Vector2i(7, 6), "leggings": Vector2i(7, 3), "boots": Vector2i(4, 9)}
		var gem: Vector2i = gems[piece]
		_px(img, ox, gem.x, gem.y, Color(0.4, 0.95, 1.0))
		_px(img, ox, gem.x + 1, gem.y, Color(0.2, 0.6, 0.95))
		if piece == "boots":
			_px(img, ox, 11, 9, Color(0.4, 0.95, 1.0))


## Cute touches on top of a picture. Everything goes ON the item itself (never
## loose pixels in the empty space around it, which look like specks once the
## icon gets its dark outline):
## - a little heart "sticker" where the item is wide enough to hold one,
## - a couple of shiny glints on its edges,
## - frilly white trim along the top of armor.
static func _cute_touch(img: Image, d: Dictionary) -> void:
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < 16 and y < 16 and img.get_pixel(x, y).a > 0.5
	if not d.get("sparkle", false):
		# Find a spot where a 3x3 heart sits fully on the item, preferring the
		# top right (the head of a tool, the chest of armor).
		var heart := ["X.X", "XXX", ".X."]
		var best := Vector2i(-1, -1)
		var best_score := -INF
		for y in range(0, 14):
			for x in range(0, 14):
				var fits := true
				for hy in 3:
					for hx in 3:
						if heart[hy][hx] == "X" and not solid.call(x + hx, y + hy):
							fits = false
				if not fits:
					continue
				var score: float = (x - y) * 1.0 if not (d.has("armor") or d.has("cape")) else -absf(x - 6.5) - absf(y - 6.5)
				if score > best_score:
					best_score = score
					best = Vector2i(x, y)
		if best.x >= 0:
			for hy in 3:
				for hx in 3:
					if heart[hy][hx] == "X":
						img.set_pixel(best.x + hx, best.y + hy, Color(1.0, 0.32, 0.58) if hy < 2 else Color(0.88, 0.2, 0.45))
		else:
			# Too thin for a heart (like a bow): a few pink dots along it instead.
			var placed := 0
			for y in 16:
				for x in range(15, -1, -1):
					if placed < 3 and solid.call(x, y) and (x + y) % 5 == 0:
						img.set_pixel(x, y, Color(1.0, 0.35, 0.6))
						placed += 1
	# Glints: brighten a couple of the item's own top-edge pixels.
	var glints := 0
	for y in 16:
		for x in range(15, -1, -1):
			if glints >= 2:
				break
			if solid.call(x, y) and not solid.call(x, y - 1) and (x + y) % 4 == 1:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
				glints += 1
	if d.has("armor"):
		# frilly white trim on the top edge of the shape
		for x in 16:
			for y in 16:
				if img.get_pixel(x, y).a > 0.5:
					if (x % 2 == 0) and (y == 0 or img.get_pixel(x, y - 1).a < 0.5):
						img.set_pixel(x, y, Color(1.0, 0.97, 0.99))
					break


## A bow: a curved limb bulging toward the top-right, a straight string, a grip
## wrap in the middle. Better bows get metal tips, a gold grip and a gem.
static func _paint_bow(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d.get("color", WOOD)
	var tier := int(d.get("bow", 1))
	var center := Vector2(2.5, 12.5)
	for y in 16:
		for x in 16:
			var p := Vector2(x + 0.5, y + 0.5) - center
			var ang := rad_to_deg(atan2(-p.y, p.x))   # 90 = up, 0 = right
			if ang < -2.0 or ang > 92.0:
				continue
			var k := absf(ang - 45.0) / 47.0          # 0 in the middle, 1 at the tips
			var thick := lerpf(1.25, 0.6, k)
			var off := p.length() - 10.6
			if absf(off) > thick:
				continue
			var col := c
			if off > thick * 0.3:
				col = c.lightened(0.28)
			elif off < -thick * 0.3:
				col = c.darkened(0.3)
			if tier == 1 and (x + y) % 3 == 0:
				col = col.darkened(0.1)             # wood grain
			if k < 0.14:
				col = (GOLD_TRIM if tier >= 3 else WRAP.lightened(0.15)) if (x + y) % 2 == 0 else (GOLD_TRIM.darkened(0.2) if tier >= 3 else WRAP)
			if k > 0.82 and tier >= 2:
				col = GOLD_TRIM if tier >= 3 else c.lightened(0.45)   # tipped ends
			_px(img, ox, x, y, col)
	# The string, straight between the two tips.
	for i in 12:
		var sx := 2 + i
		var sy := 2 + i
		if img.get_pixel(ox + sx, sy).a < 0.5:
			_px(img, ox, sx, sy, Color(0.95, 0.93, 0.86, 1.0) if tier < 3 else Color(0.85, 0.95, 1.0))
	if tier >= 3:
		_px(img, ox, 10, 4, Color(0.4, 0.95, 1.0))   # gem in the grip


## An arrow: wooden shaft, a head colored by what it's made of, feathers at the back.
static func _paint_arrow(img: Image, ox: int, d: Dictionary) -> void:
	var head: Color = d.get("color", Color.GRAY)
	var fx: String = d.get("effect", "")
	for i in range(3, 12):
		_px(img, ox, i, 15 - i, WOOD.lightened(0.15))
		_px(img, ox, i + 1, 15 - i, WOOD.darkened(0.15))
	# Head: a little arrowhead at the top-right.
	for p in [Vector2i(14, 1), Vector2i(13, 1), Vector2i(14, 2), Vector2i(12, 2), Vector2i(13, 2), Vector2i(13, 3),
			Vector2i(11, 3), Vector2i(12, 3), Vector2i(12, 4), Vector2i(14, 3)]:
		_px(img, ox, p.x, p.y, head.lightened(0.25) if p.x + p.y <= 15 else head.darkened(0.2))
	# Feathers at the back.
	var feather: Color = Color(0.95, 0.95, 0.92) if fx == "" else ({"poison": Color(0.4, 0.75, 0.3), "silver": Color(0.75, 0.8, 0.95), "frost": Color(0.6, 0.85, 1.0)}[fx])
	for p in [Vector2i(1, 12), Vector2i(2, 12), Vector2i(1, 13), Vector2i(3, 14), Vector2i(3, 13), Vector2i(2, 14),
			Vector2i(2, 11), Vector2i(4, 14)]:
		_px(img, ox, p.x, p.y, feather if (p.x + p.y) % 2 == 0 else feather.darkened(0.2))
	if fx == "poison":
		_px(img, ox, 12, 5, Color(0.5, 1.0, 0.35))   # a drip
	elif fx == "frost":
		_px(img, ox, 15, 0, Color(1, 1, 1))          # a sparkle


## A cape on a little hanger shape: collar and clasp at the top, flaring out
## with soft folds. Hero capes get gold trim, royal capes a gold border and a star.
static func _paint_cape(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d.get("color", Color.RED)
	var tier := int(d.get("cape", 1))
	for y in range(2, 15):
		var half := 3.0 + (y - 2) * 0.42
		for x in 16:
			var dx := absf(x + 0.5 - 8.0)
			if dx > half:
				continue
			var col := c
			var fold := int(x + 0.5 - 8.0 + 16.0) % 3
			if fold == 0 and y > 4:
				col = c.darkened(0.22)                  # folds
			elif fold == 1 and y > 4:
				col = c.lightened(0.1)
			if dx > half - 1.0:
				col = c.darkened(0.3)                   # edge
			if y >= 13 and (x + y) % 2 == 0:
				col = col.darkened(0.12)                # wavy hem
			if tier >= 2 and (y == 14 or (tier >= 3 and dx > half - 1.0)):
				col = GOLD_TRIM if (x + y) % 2 == 0 else GOLD_TRIM.darkened(0.15)
			_px(img, ox, x, y, col)
	for x in range(5, 11):
		_px(img, ox, x, 2, c.darkened(0.4))            # collar
	_px(img, ox, 7, 3, GOLD_TRIM if tier >= 2 else Color(0.8, 0.8, 0.82))   # clasp
	_px(img, ox, 8, 3, GOLD_TRIM.darkened(0.2) if tier >= 2 else Color(0.6, 0.6, 0.65))
	if tier >= 3:
		for p in [Vector2i(8, 7), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8), Vector2i(8, 9), Vector2i(7, 10), Vector2i(9, 10)]:
			_px(img, ox, p.x, p.y, GOLD_TRIM)       # a star

## Meat: the shape says which animal (drumstick, steak, chop, rib, haunch).
## Raw meat has white fat marbling; cooked meat is browned with grill marks.
static func _paint_meat(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d["color"]
	var cooked: bool = d.get("cooked", false)
	var fat := Color(0.98, 0.92, 0.88) if not cooked else Color(0.88, 0.7, 0.4)
	var bone := Color(0.96, 0.94, 0.88)
	var edge := c.darkened(0.35)
	var small: bool = String(d["name"]).ends_with("Rabbit")
	var inside := func(x: int, y: int) -> bool: return false
	match d["icon"]:
		"drumstick":
			var r := 3.6 if small else 4.6
			inside = func(x: int, y: int) -> bool:
				return Vector2(x, y).distance_to(Vector2(6, 7)) < r or Vector2(x, y).distance_to(Vector2(8.5, 9.5)) < r * 0.6
			for i in range(0, 5 if small else 6):  # bone with a knob
				_px(img, ox, 10 + i, 11 + i / 2, bone)
				_px(img, ox, 10 + i, 12 + i / 2, bone.darkened(0.12))
			_px(img, ox, 15, 14, bone)
			_px(img, ox, 14, 15, bone)
		"steak":
			inside = func(x: int, y: int) -> bool:
				var p := Vector2(x - 7.5, (y - 8.0) * 1.35)
				return p.length() < 6.5 and not (x > 10 and y < 6)
		"chop":
			inside = func(x: int, y: int) -> bool:
				return Vector2(x, y).distance_to(Vector2(6.5, 9)) < 5.0
			for i in 6:  # bone sticking up and right
				_px(img, ox, 10 + i, 6 - i, bone)
				_px(img, ox, 11 + i, 6 - i, bone.darkened(0.12))
		"rib":
			inside = func(x: int, y: int) -> bool:
				return x >= 2 and x <= 13 and y >= 5 and y <= 11 and not (x + y < 9 or x + y > 22)
			for k in 3:  # rib bones poking out the top
				for j in 3:
					_px(img, ox, 4 + k * 3, 4 - j, bone)
		"haunch":
			inside = func(x: int, y: int) -> bool:
				return Vector2(x, y).distance_to(Vector2(6, 8)) < 5.5 and y > 2
			for i in 5:
				_px(img, ox, 11 + i, 10 + i / 2, bone)
			_px(img, ox, 15, 13, bone)
			_px(img, ox, 15, 11, bone)
	for y in 16:
		for x in 16:
			if not inside.call(x, y):
				continue
			var border: bool = not inside.call(x - 1, y) or not inside.call(x + 1, y) or not inside.call(x, y - 1) or not inside.call(x, y + 1)
			var col := edge if border else c
			if not border:
				if cooked:
					if (x + y) % 4 == 0:
						col = c.darkened(0.45)  # grill marks
					elif (x * 3 + y) % 7 == 0:
						col = c.lightened(0.18)
				elif (x * 2 + y * 3) % 9 == 0 or (x + y * 2) % 11 == 0:
					col = fat  # marbling
			_px(img, ox, x, y, col)


## A ring seen from a little above, with its gem on top.
static func _paint_ring(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d.get("color", Color(1.0, 0.84, 0.25))
	var gem: Color = d.get("gem", Color(1.0, 0.3, 0.3))
	for y in 16:
		for x in 16:
			var p := Vector2((x + 0.5 - 8.0) / 5.6, (y + 0.5 - 9.5) / 4.2)
			var r := p.length()
			if r <= 1.0 and r >= 0.62:
				var col: Color = c.lightened(0.3) if p.y < -0.3 and p.x < 0.2 else (c.darkened(0.3) if p.y > 0.4 else c)
				_px(img, ox, x, y, col)
	for y in range(2, 7):
		for x in range(6, 10):
			var e := absf(x + 0.5 - 8.0) + absf(y + 0.5 - 4.5)
			if e <= 2.6:
				_px(img, ox, x, y, gem.lightened(0.45) if x < 8 and y < 4 else (gem.darkened(0.25) if e > 1.8 else gem))
	for x in [6, 9]:
		_px(img, ox, x, 6, c.darkened(0.2))   # the claws holding the gem
	if d.get("rarity", "") == "legendary":
		for p in [Vector2i(3, 9), Vector2i(12, 9)]:
			_px(img, ox, p.x, p.y, Color(1.0, 0.97, 0.75))   # tusk-gold glints


## An amulet: a chain that hangs in a V and a big round gem in a setting.
static func _paint_amulet(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d.get("color", Color(1.0, 0.84, 0.25))
	var gem: Color = d.get("gem", Color(0.4, 1.0, 0.5))
	var chain: Color = Color(1.0, 0.84, 0.3) if d.get("rarity", "") == "legendary" else c
	for i in 7:
		_px(img, ox, 2 + i, 1 + i, chain if i % 2 == 0 else chain.darkened(0.3))
		_px(img, ox, 13 - i, 1 + i, chain if i % 2 == 0 else chain.darkened(0.3))
	for y in 16:
		for x in 16:
			var dd := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 11))
			if dd < 4.4:
				var col: Color = c.darkened(0.15) if dd > 3.0 else (gem.lightened(0.4) if x < 8 and y < 11 else gem)
				if dd <= 3.0 and dd > 2.2:
					col = gem.darkened(0.2)
				_px(img, ox, x, y, col)
	_px(img, ox, 7, 9, Color(1, 1, 1, 0.9))   # a shine


static func _paint_icon(img: Image, ox: int, d: Dictionary) -> void:
	var c: Color = d.get("color", Color(0.8, 0.8, 0.8))
	var dark := c.darkened(0.35)
	var light := c.lightened(0.3)
	match d.get("icon", ""):
		"stick":
			_handle(img, ox, 2, 14)
		"ingot":
			for y in range(6, 12):
				var inset := (11 - y) / 2
				for x in range(2 + inset, 14 - inset):
					_px(img, ox, x, y, light if y == 6 else (dark if y == 11 else c))
		"pickaxe", "axe", "sword", "shovel":
			_paint_tool(img, ox, d, d["icon"])
		"bow":
			_paint_bow(img, ox, d)
		"arrow":
			_paint_arrow(img, ox, d)
		"cape":
			_paint_cape(img, ox, d)
		"fries":
			for y in range(8, 15):
				for x in range(3, 13):
					var w := y >= 8 and absf(x + 0.5 - 8.0) <= 4.0 + (y - 8) * 0.12
					if w:
						_px(img, ox, x, y, Color(0.86, 0.12, 0.14) if y > 8 else Color(0.98, 0.78, 0.2))
			for i in 6:
				var fx := 4 + i * 1.5
				for y in range(2 + (i * 5) % 4, 9):
					_px(img, ox, int(fx), y, c if y > 3 else c.darkened(0.15))
			for p in [Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11), Vector2i(6, 10), Vector2i(10, 10)]:
				_px(img, ox, p.x, p.y, Color(1.0, 0.85, 0.25))   # a smiley
		"nugget":
			for y in 16:
				for x in 16:
					var p := Vector2((x + 0.5 - 8.0) / 6.0, (y + 0.5 - 8.5) / 4.6)
					var bump := 0.08 * sin(atan2(p.y, p.x) * 5.0)
					if p.length() < 1.0 + bump:
						var col: Color = light if p.y < -0.3 else (dark if p.y > 0.5 else c)
						if (x * 3 + y * 5) % 7 == 0:
							col = col.lightened(0.15)   # crumbs
						_px(img, ox, x, y, col)
		"toy":
			for y in range(5, 13):
				for x in range(3, 11):
					_px(img, ox, x, y, c if x > 3 and y > 5 else c.lightened(0.3))   # a toy block
			for y in range(3, 9):
				for x in range(9, 15):
					if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 6)) < 2.9:
						_px(img, ox, x, y, Color(1.0, 0.85, 0.2) if x + y < 18 else Color(0.95, 0.3, 0.3))   # a ball
			_px(img, ox, 6, 8, Color.WHITE)
			_px(img, ox, 7, 9, Color.WHITE)
		"hammer":
			for i in 11:
				_px(img, ox, 3 + i, 14 - i, Color(0.62, 0.42, 0.22))   # the long handle
				_px(img, ox, 4 + i, 14 - i, Color(0.5, 0.33, 0.17))
			for y in range(0, 8):
				for x in range(7, 16):
					var u := (x - 7) - (y - 0)
					if absi(u - 4) <= 3 and y + x >= 9 and y + x <= 18:
						var band := (x + y) % 6 < 2
						_px(img, ox, x, y, Color(0.97, 0.95, 0.92) if band else (light if y < 3 else c))
		"card":
			for y in range(1, 15):
				for x in range(3, 13):
					var e := x == 3 or x == 12 or y == 1 or y == 14
					_px(img, ox, x, y, Color(0.75, 0.72, 0.68) if e else Color(0.98, 0.97, 0.94))
			for p in [Vector2i(6, 6), Vector2i(7, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
					Vector2i(9, 7), Vector2i(10, 7), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8), Vector2i(8, 9), Vector2i(5, 3), Vector2i(10, 12)]:
				_px(img, ox, p.x, p.y, Color(0.88, 0.12, 0.2))   # a heart, and the corner pips
		"gem":
			# A cut gem: a flat top, slanted facets and a sparkle.
			for y in range(3, 14):
				for x in range(1, 15):
					var half := 6.0 if y <= 6 else 6.0 - (y - 6) * 0.86
					if y == 3 and (x < 4 or x > 11):
						continue
					if absf(x + 0.5 - 8.0) > half:
						continue
					var col: Color = light if y <= 5 else (c if (x + y) % 3 != 0 else dark)
					if y > 6 and x + 0.5 < 8.0:
						col = col.darkened(0.12)
					_px(img, ox, x, y, col)
			_px(img, ox, 5, 4, Color(1, 1, 1))
			_px(img, ox, 6, 5, Color(1, 1, 1, 0.8))
		"ring":
			_paint_ring(img, ox, d)
		"amulet":
			_paint_amulet(img, ox, d)
		"grim_chest":
			_paint_armor(img, ox, d, "chestplate")
			for p in [Vector2i(5, 6), Vector2i(5, 7), Vector2i(6, 6)]:
				_px(img, ox, p.x, p.y, Color(1.0, 0.5, 0.12))     # a fire gem
			for p in [Vector2i(10, 6), Vector2i(10, 7), Vector2i(9, 6)]:
				_px(img, ox, p.x, p.y, Color(0.45, 0.88, 1.0))    # an ice gem
			for y in range(9, 14):
				_px(img, ox, 7, y, Color(0.92, 0.9, 0.82))        # bone ridge
				_px(img, ox, 8, y, Color(0.8, 0.78, 0.7))
		"armor", "chestplate", "helmet", "leggings", "boots":
			_paint_armor(img, ox, d, "chestplate" if d["icon"] == "armor" else d["icon"])
		"crown":
			for y in range(4, 13):
				for x in range(1, 15):
					var band := y >= 9
					var spike := y >= 4 and (x in [1, 2, 7, 8, 13, 14] or (y >= 6 and x in [4, 5, 10, 11]))
					if band or spike:
						_px(img, ox, x, y, light if y == 4 or y == 9 else (dark if y == 12 else c))
			for y in range(9, 12):
				for x in range(6, 10):
					_px(img, ox, x, y, Color(1.0, 0.35, 0.2) if (x + y) % 3 != 0 else Color(1.0, 0.8, 0.6))  # the great gem
		"gummy":
			for y in range(3, 15):
				for x in range(3, 13):
					var head := Vector2(x, y).distance_to(Vector2(8, 5.5)) < 3.0
					var body := Vector2(x, y).distance_to(Vector2(8, 10.5)) < 3.8
					var ears := Vector2(x, y).distance_to(Vector2(5.5, 3)) < 1.3 or Vector2(x, y).distance_to(Vector2(10.5, 3)) < 1.3
					if head or body or ears:
						_px(img, ox, x, y, light if (x + y) % 5 == 0 else c)
		"marshmallow":
			for y in range(4, 13):
				for x in range(3, 13):
					_px(img, ox, x, y, c if y > 5 else c.darkened(0.06))
			_px(img, ox, 6, 8, Color(0.2, 0.15, 0.15))
			_px(img, ox, 9, 8, Color(0.2, 0.15, 0.15))
			_px(img, ox, 5, 10, Color(1.0, 0.7, 0.8))
			_px(img, ox, 10, 10, Color(1.0, 0.7, 0.8))
		"peppermint":
			for y in 16:
				for x in 16:
					var p := Vector2(x + 0.5, y + 0.5) - Vector2(8, 8)
					if p.length() < 6.5:
						var swirl := posmod(int((atan2(p.y, p.x) + PI) / TAU * 6.0 + p.length() * 0.3), 2) == 0
						_px(img, ox, x, y, c if swirl else Color(0.98, 0.97, 0.95))
		"drumstick", "steak", "chop", "rib", "haunch":
			_paint_meat(img, ox, d)
		"horn":
			for i in 11:
				var x := 3 + i
				var y := 13 - int(i * 0.9) + int(absf(i - 5) * 0.4)
				for k in range(maxi(1, 3 - i / 4)):
					_px(img, ox, x, y + k, c if i % 3 else dark)
			_px(img, ox, 14, 4, light)
		"trophy":
			# The boss's head on a wooden shield, like a hunting trophy.
			var wood := Color(0.5, 0.33, 0.18)
			for y in range(2, 15):
				for x in range(2, 14):
					var dx := (x + 0.5 - 8.0) / 6.0
					var dy := (y + 0.5 - 7.0) / 7.5
					if dx * dx + dy * dy <= 1.0:
						_px(img, ox, x, y, wood if dx * dx + dy * dy < 0.8 else wood.darkened(0.3))
			for y in range(4, 11):
				for x in range(5, 11):
					var e := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 7.5))
					if e < 3.4:
						_px(img, ox, x, y, c if e < 2.8 else dark)
			for x in [6, 9]:
				_px(img, ox, x, 6, Color(1.0, 0.85, 0.3))   # eyes
			_px(img, ox, 7, 9, dark)
			_px(img, ox, 8, 9, dark)
			for x in [4, 11]:
				_px(img, ox, x, 4, light)   # ears / horns
				_px(img, ox, x, 3, light)
		"fang":
			# Two pointy, slightly crooked teeth with a bit of gum at the top.
			var gum := Color(0.75, 0.3, 0.35)
			for x in range(3, 13):
				_px(img, ox, x, 3, gum)
				_px(img, ox, x, 4, gum.lightened(0.15))
			for t in [[4, 8], [9, 11]]:
				for y in range(5, 5 + t[1] - 1):
					var w := maxi(1, 3 - (y - 5) / 3)
					for k in w:
						_px(img, ox, t[0] + k + (y - 5) / 4, y, c if k < w - 1 or w == 1 else dark)
			_px(img, ox, 5, 6, light)
			_px(img, ox, 10, 6, light)
		"feather":
			for i in range(2, 14):
				_px(img, ox, i, 15 - i, Color(0.6, 0.6, 0.6))
				if i > 4:
					_px(img, ox, i - 1, 14 - i, c)
					_px(img, ox, i + 1, 16 - i, c.darkened(0.1))
		"hide":
			for y in range(3, 13):
				for x in range(2, 14):
					var corner := (x < 4 or x > 11) and (y < 5 or y > 10)
					if not corner:
						_px(img, ox, x, y, c if (x * 7 + y * 3) % 6 != 0 else dark)
		"wool":
			for b in [Vector2(5, 7), Vector2(10, 7), Vector2(7.5, 10), Vector2(7.5, 5)]:
				for y in 16:
					for x in 16:
						if Vector2(x, y).distance_to(b) < 3.2:
							_px(img, ox, x, y, c if (x + y) % 4 != 0 else c.darkened(0.12))
		"silk":
			var center := Vector2(7.5, 7.5)
			for y in 16:
				for x in 16:
					var p := Vector2(x, y) - center
					var ring := int(p.length()) % 3 == 0 and p.length() < 7.5
					var spoke := absi(x - y) == 0 or absi(x + y - 15) == 0 or x == 7 or y == 7
					if (ring or spoke) and p.length() < 7.5:
						_px(img, ox, x, y, c)
		"coal":
			for y in 16:
				for x in 16:
					var p := Vector2(x + 0.5, y + 0.5)
					var lump := p.distance_to(Vector2(7, 9)) < 4.6 or p.distance_to(Vector2(10.5, 6.5)) < 3.4
					if lump:
						var col: Color = c.lightened(0.3) if (x * 3 + y * 7) % 11 == 0 else c
						_px(img, ox, x, y, col if x + y > 10 else col.lightened(0.12))
		"bottle":
			var liquid: Color = d.get("liquid", Color(0, 0, 0, 0))
			for y in range(2, 15):
				for x in 16:
					var neck := y <= 5 and x >= 6 and x <= 9
					var body := y >= 6 and Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 10.5)) < 4.8
					if not (neck or body):
						continue
					var edge := (x <= 6 or x >= 9) if neck else Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 10.5)) > 3.9
					var col: Color = c.darkened(0.15) if edge else Color(0.88, 0.94, 1.0)
					if not edge and liquid.a > 0.0 and y >= 8:
						col = liquid if (x + y) % 6 != 0 else liquid.lightened(0.25)
					_px(img, ox, x, y, col)
			for x in range(6, 10):
				_px(img, ox, x, 2, Color(0.55, 0.38, 0.22))   # cork
			_px(img, ox, 6, 9, Color(1, 1, 1))                # shine
		"bucket":
			var liquid2: Color = d.get("liquid", Color(0, 0, 0, 0))
			for y in range(4, 15):
				var half := 6.0 - (y - 4) * 0.25
				for x in 16:
					if absf(x + 0.5 - 8.0) <= half:
						var col: Color = c.lightened(0.2) if x < 6 else (c.darkened(0.2) if x > 10 else c)
						if y == 4:
							col = c.darkened(0.3)                   # the rim
							if liquid2.a > 0.0 and absf(x + 0.5 - 8.0) < half - 1.0:
								col = liquid2.lightened(0.15)
						_px(img, ox, x, y, col)
			for x in range(3, 13):
				_px(img, ox, x, 2 if x > 4 and x < 11 else 3, Color(0.4, 0.4, 0.45))   # the handle
		"bone":
			for i in range(3, 13):
				_px(img, ox, i, 15 - i, c)
				_px(img, ox, i + 1, 15 - i, c.darkened(0.15))
			for p in [Vector2i(2, 12), Vector2i(3, 14), Vector2i(1, 13), Vector2i(12, 2), Vector2i(14, 3), Vector2i(13, 1),
					Vector2i(2, 13), Vector2i(13, 2), Vector2i(3, 13), Vector2i(12, 3)]:
				_px(img, ox, p.x, p.y, c.lightened(0.05))   # knobby ends
		"old_coin":
			for y in 16:
				for x in 16:
					var dd := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
					if dd < 6.5:
						var col: Color = c if dd < 5.3 else c.darkened(0.3)
						if (x == 7 or x == 8) and y >= 5 and y <= 10:
							col = c.darkened(0.35)          # a worn old face
						if dd < 2.5 and (x + y) % 3 == 0:
							col = col.darkened(0.15)
						_px(img, ox, x, y, col.lightened(0.15) if x + y < 12 else col)
		"candy_corn":
			for y in range(2, 15):
				var half := (y - 2) * 0.42 + 0.5
				for x in 16:
					if absf(x + 0.5 - 8.0) <= half:
						var col: Color = Color(1.0, 0.97, 0.9) if y < 6 else (Color(1.0, 0.65, 0.15) if y < 10 else Color(1.0, 0.85, 0.2))
						_px(img, ox, x, y, col.lightened(0.15) if x < 7 else col)
		"witch_hat":
			for y in range(1, 15):
				for x in 16:
					var cone := y <= 11 and absf(x + 0.5 - (8.0 + (11 - y) * 0.25)) <= (y - 1) * 0.42
					var brim := y >= 12 and y <= 13 and x >= 1 and x <= 14
					if cone or brim:
						_px(img, ox, x, y, light if x < 7 and cone else c)
			for x in range(4, 12):
				_px(img, ox, x, 10, Color(0.6, 0.35, 0.8))   # a purple band
			_px(img, ox, 7, 10, Color(1.0, 0.85, 0.3))       # buckle
		"acorn":
			for y in 16:
				for x in 16:
					var p := Vector2(x + 0.5, y + 0.5)
					if y >= 4 and y <= 7 and absf(p.x - 8.0) < 4.5:
						_px(img, ox, x, y, Color(0.45, 0.3, 0.16) if (x + y) % 2 == 0 else Color(0.38, 0.25, 0.13))   # cap
					elif y > 7 and p.distance_to(Vector2(8, 9.5)) < 4.2 and y < 14:
						_px(img, ox, x, y, light if x < 7 and y < 10 else c)   # nut
			_px(img, ox, 8, 3, Color(0.35, 0.22, 0.12))
			_px(img, ox, 8, 2, Color(0.35, 0.22, 0.12))
		"pie":
			for y in range(5, 13):
				for x in range(1, 15):
					var crust := y == 5 or y >= 11 or x == 1 or x == 14
					var col: Color = Color(0.85, 0.65, 0.38) if crust else c
					if not crust and (x + y) % 5 == 0:
						col = c.lightened(0.15)
					if y == 5 and x % 2 == 0:
						col = col.lightened(0.15)          # fluted edge
					_px(img, ox, x, y, col)
			for x in range(3, 13, 3):
				_px(img, ox, x, 7, Color(1, 1, 1))          # a dollop of cream
		"blob":
			for y in 16:
				for x in 16:
					var dd := Vector2(x, y).distance_to(Vector2(7.5, 8.5))
					if dd < 5.5:
						_px(img, ox, x, y, light if dd < 2.0 else c)
		"paper":
			# Two sheets, the top one with a folded corner and some lines.
			for y in range(2, 14):
				for x in range(4, 14):
					_px(img, ox, x, y, c.darkened(0.12))
			for y in range(3, 15):
				for x in range(2, 12):
					if x + (14 - y) > 20:
						continue  # folded corner
					var col := c
					if y % 3 == 0 and x > 3 and x < 10 and y < 13:
						col = Color(0.62, 0.66, 0.78)  # lines
					_px(img, ox, x, y, col)
			for i in 3:
				_px(img, ox, 9 + i, 4 + i, c.darkened(0.25))
		"map":
			# A folded parchment map: three panels, green land, blue water,
			# a red dotted path and an X.
			for y in range(2, 14):
				for x in range(1, 15):
					var panel := (x - 1) / 5
					var lift := 1 if panel == 1 else 0  # the middle fold sits a bit higher
					if y < 2 + lift or y > 13 - (1 - lift):
						continue
					var col := c.darkened(0.08 * panel)
					if (x + y * 2) % 7 < 3 and y > 4 and y < 11:
						col = Color(0.48, 0.68, 0.38)  # land
					if x > 9 and y > 8:
						col = Color(0.42, 0.6, 0.86)  # sea
					if x == 6 or x == 11:
						col = col.darkened(0.2)  # folds
					_px(img, ox, x, y, col)
			for p in [Vector2i(3, 11), Vector2i(4, 9), Vector2i(6, 8), Vector2i(8, 7)]:
				_px(img, ox, p.x, p.y, Color(0.8, 0.2, 0.18))
			for i in 3:
				_px(img, ox, 9 + i, 4 + i, Color(0.8, 0.12, 0.12))
				_px(img, ox, 11 - i, 4 + i, Color(0.8, 0.12, 0.12))
		_:
			for y in range(4, 12):
				for x in range(4, 12):
					_px(img, ox, x, y, Color.MAGENTA)
