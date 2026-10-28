extends RefCounted
## Block types, world dimensions, and the procedurally painted texture atlas.
##
## Every block is described once in DEFS below (name, textures, how it treats
## light, how hard it is to mine and what it drops). Fast lookup arrays like
## TRANSPARENT are built from DEFS when the game starts.
## To add a block: add an id constant, bump COUNT, and add a DEFS entry
## (and a new texture tile + painter case if it needs its own look).

# --- World dimensions (shared by the world and the chunk mesher) -------------
const CHUNK_SIZE := 16    # blocks along X and Z per chunk
const CHUNK_HEIGHT := 96  # blocks along Y (the world is one chunk tall)

# --- Block ids (stored as bytes in chunk data) -------------------------------
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const LOG := 5
const LEAVES := 6
const PLANKS := 7
const COBBLESTONE := 8
const BEDROCK := 9
const GLASS := 10
const WATER := 11
const LAMP := 12
const COPPER_ORE := 13
const TIN_ORE := 14
const IRON_ORE := 15
const SILVER_ORE := 16
const TITANIUM_ORE := 17
const GOLD_ORE := 18
const WORKBENCH_1 := 19
const WORKBENCH_2 := 20
const WORKBENCH_3 := 21
const FURNACE := 22
const SHOP := 23
const GOLD_BLOCK := 24
const CHEST := 25
const TORCH := 26
const BED := 27
const DOOR_WOOD := 28
const DOOR_WOOD_OPEN := 29
const DOOR_IRON := 30
const DOOR_IRON_OPEN := 31
const DOOR_TITANIUM := 32
const DOOR_TITANIUM_OPEN := 33
const SANDSTONE := 34
const CACTUS := 35
const FROSTING := 36
const CAKE := 37
const CANDY_CANE := 38
const COTTON_CANDY := 39
const WATER_FLOW_1 := 40     # flowing water, 1-4 blocks from where it came from
const WATER_FLOW_2 := 41
const WATER_FLOW_3 := 42
const WATER_FLOW_4 := 43
const SNOW := 44
const PINE_LEAVES := 45
const MUSHROOM_CAP := 46
const MUSHROOM_STEM := 47
const SNOWY_STONE := 48
# Little plants that sit on the ground (drawn as two crossed pictures).
const TALL_GRASS := 49
const FERN := 50
const POPPY := 51
const DANDELION := 52
const CORNFLOWER := 53
const DAISY := 54
const BLUEBELL := 55
const TOADSTOOL := 56
const DRY_SHRUB := 57
const CACTUS_FLOWER := 58
const LOLLIPOP := 59
const CANDY_TULIP := 60
const FROST_GRASS := 61
const EDELWEISS := 62
# Woods. Every log comes in 3 directions (standing up, lying along X, lying along Z).
const LOG_X := 63
const LOG_Z := 64
const REDWOOD_LOG := 65
const REDWOOD_LOG_X := 66
const REDWOOD_LOG_Z := 67
const PINE_LOG := 68
const PINE_LOG_X := 69
const PINE_LOG_Z := 70
const PALM_LOG := 71
const PALM_LOG_X := 72
const PALM_LOG_Z := 73
const CANDY_CANE_X := 74
const CANDY_CANE_Z := 75
const REDWOOD_PLANKS := 76
const PINE_PLANKS := 77
const PALM_PLANKS := 78
const CANDY_PLANKS := 79
const PALM_LEAVES := 80
# Building blocks: shapes (slabs, stairs, columns, tables, chairs) and fancy blocks.
const OAK_SLAB := 81
const OAK_STAIRS := 82
const OAK_COLUMN := 83
const OAK_TABLE := 84
const OAK_CHAIR := 85
const CARVED_OAK := 86
const REDWOOD_SLAB := 87
const REDWOOD_STAIRS := 88
const REDWOOD_COLUMN := 89
const REDWOOD_TABLE := 90
const REDWOOD_CHAIR := 91
const CARVED_REDWOOD := 92
const PINE_SLAB := 93
const PINE_STAIRS := 94
const PINE_COLUMN := 95
const PINE_TABLE := 96
const PINE_CHAIR := 97
const CARVED_PINE := 98
const PALM_SLAB := 99
const PALM_STAIRS := 100
const PALM_COLUMN := 101
const PALM_TABLE := 102
const PALM_CHAIR := 103
const CARVED_PALM := 104
const CANDY_SLAB := 105
const CANDY_STAIRS := 106
const CANDY_COLUMN := 107
const CANDY_TABLE := 108
const CANDY_CHAIR := 109
const CARVED_CANDY := 110
const BOOKSHELF := 111
const STONE_BRICKS := 112
const COBBLESTONE_SLAB := 113
const COBBLESTONE_STAIRS := 114
const COBBLESTONE_COLUMN := 115
const STONE_BRICK_SLAB := 116
const STONE_BRICK_STAIRS := 117
const STONE_BRICK_COLUMN := 118
const SANDSTONE_SLAB := 119
const SANDSTONE_STAIRS := 120
const SANDSTONE_COLUMN := 121
const STONE_PILLAR := 122
const CHISELED_BRICKS := 123
const CARVED_SANDSTONE := 124
const COPPER_BLOCK := 125
const IRON_BLOCK := 126
const SILVER_BLOCK := 127
const TITANIUM_BLOCK := 128
const COPPER_SLAB := 129
const IRON_SLAB := 130
const SILVER_SLAB := 131
const TITANIUM_SLAB := 132
const GOLD_SLAB := 133
const GOLD_INLAID_BRICKS := 134
const SILVER_INLAID_BRICKS := 135
const TITANIUM_INLAID_BRICKS := 136
const SAWMILL := 137
const STONECUTTER := 138
const SHAPER := 139
const CUTIE_ORE := 140
const CUTE_CRAFTER := 141
const PORTALSTONE := 142
const PORTAL := 143          # inside a portal frame, not linked yet (dim)
const PORTAL_LIT := 144      # linked to its partner: glows, and takes you there
# The fall forest.
const FALL_GRASS := 145
const MAPLE_LOG := 146
const MAPLE_LOG_X := 147
const MAPLE_LOG_Z := 148
const MAPLE_PLANKS := 149
const MAPLE_LEAVES := 150
const GOLDEN_LEAVES := 151
const PUMPKIN := 152
const HAY_BALE := 153
const LEAF_PILE := 154
const GOLD_LEAF_PILE := 155
const MAPLE_SLAB := 156
const MAPLE_STAIRS := 157
const MAPLE_COLUMN := 158
const MAPLE_TABLE := 159
const MAPLE_CHAIR := 160
const CARVED_MAPLE := 161
# The spooky forest.
const DEAD_GRASS := 162
const DEAD_LOG := 163
const DEAD_LOG_X := 164
const DEAD_LOG_Z := 165
const DEAD_PLANKS := 166
const JACK_O_LANTERN := 167
const GRAVESTONE := 168
const COBWEB := 169
const GLOWSHROOM := 170
const GHOST_LANTERN := 171
const DEAD_SLAB := 172
const DEAD_STAIRS := 173
const DEAD_COLUMN := 174
const DEAD_TABLE := 175
const DEAD_CHAIR := 176
const CARVED_DEAD := 177
const VINE := 178            # hangs under low floating islands; climb it!
const BED_FOOT := 179        # the other half of a bed (BED is the pillow end)
const SCRIBE := 180          # the Scribe Desk: write names on your things
const ITEM_FRAME := 181      # hangs on a wall and shows one item (maps show their land)
const ARMOR_STAND := 182     # wears a set of armor (and a cape)
const SHRINE_CHEST := 183    # the stone chest in a cave shrine (holds a treasure map)
const FENCE_START := 184     # then a fence (or wall) and a wedge for each of FAMILIES, in order
const BOSS_STATUE := 214     # a statue at the spawn shrine (one per boss)
const RESEARCH_TABLE := 215  # learn new recipes (for the workbenches nearby)
const SUPER_CHEST := 216     # your own storage: every Super Chest opens the same box, just for you
const CAMPFIRE := 217        # light, and somewhere to rest through the night
const BEDROLL := 218         # sleep anywhere (doesn't move your respawn point)
const OAK_SAPLING := 219     # saplings (from leaves) grow into trees over a few days
const REDWOOD_SAPLING := 220
const PINE_SAPLING := 221
const PALM_SAPLING := 222
const MAPLE_SAPLING := 223
const GOLDEN_SAPLING := 224
const CANDY_SAPLING := 225
const CASTLE_BOX := 226      # (host testing) right-click: a whole end-game castle appears around you
# The chessboard kingdom: marble and onyx (the ground there), and what the
# stonecutter makes from them.
const WHITE_MARBLE := 227
const BLACK_ONYX := 228
const MARBLE_BRICKS := 229
const ONYX_BRICKS := 230
const MARBLE_SLAB := 231
const ONYX_SLAB := 232
const MARBLE_STAIRS := 233
const ONYX_STAIRS := 234
const MARBLE_COLUMN := 235
const ONYX_COLUMN := 236
const CHECKER_TILE := 237
# Fast Food Land: the ground is a giant sesame bun; giant fry boxes stand
# around; the clown lives in a striped circus tent.
const SESAME_BUN := 238
const FRIES_BLOCK := 239
const FRY_BOX := 240
const CIRCUS_STRIPES := 241
# The arena (host testing, /arena).
const ARENA_BOX := 242       # right-click: a whole battle arena appears around you
const ARENA_GATE := 243      # iron bars that drop over the arena's doorways when it locks
const ARENA_BUTTON := 244    # the control room's big red button
# More flowing water (like Minecraft: 7 blocks from its source), and falling water.
const WATER_FLOW_5 := 245
const WATER_FLOW_6 := 246
const WATER_FLOW_7 := 247
const WATER_FALL := 248
# The Deep (worlds made with gen 12): a hard Bedstone crust near the bottom of
# the world, and under it big dark caverns of Deepstone full of gems and lava.
const BEDSTONE := 249        # the crust: needs a titanium (tier 5) pickaxe
const DEEPSTONE := 250
const RUBY_ORE := 251
const SAPPHIRE_ORE := 252
const DIAMOND_ORE := 253
const ONYX_ORE := 254
const AMETHYST_ORE := 255
const STALACTITE := 256      # (and stalagmites: the same pointy stone, hanging or standing)
const GLOW_CRYSTAL := 257    # little glowing crystals growing on cavern floors
const LAVA := 258
const LAVA_FLOW_1 := 259
const LAVA_FLOW_2 := 260
const LAVA_FLOW_3 := 261
const LAVA_FALL := 262
const CINDERSTONE := 263     # made where water meets lava
const JEWELRY_STATION := 264
const MAGMA_ROCK := 265      # the walls of the lava caverns (gen 14), with glowing cracks
const COUNT := 266

## Building materials that get a fence (wood) or wall (stone, metal) and a
## wedge: [item prefix, name, tile, tool, tier, hardness, wood].
const FAMILIES := [
	["oak", "Oak", T_PLANKS, "axe", 0, 2.0, true],
	["redwood", "Redwood", T_REDWOOD_PLANKS, "axe", 0, 2.0, true],
	["pine", "Pine", T_PINE_PLANKS, "axe", 0, 2.0, true],
	["palm", "Palm", T_PALM_PLANKS, "axe", 0, 2.0, true],
	["candy", "Candy", T_CANDY_PLANKS, "axe", 0, 2.0, true],
	["maple", "Maple", T_MAPLE_PLANKS, "axe", 0, 2.0, true],
	["dead", "Deadwood", T_DEAD_PLANKS, "axe", 0, 2.0, true],
	["cobblestone", "Cobblestone", T_COBBLE, "pickaxe", 1, 3.0, false],
	["stone_brick", "Stone Brick", T_STONE_BRICKS, "pickaxe", 1, 3.0, false],
	["sandstone", "Sandstone", T_SANDSTONE, "pickaxe", 1, 3.0, false],
	["copper", "Copper", T_COPPER_BLOCK, "pickaxe", 2, 5.0, false],
	["iron", "Iron", T_IRON_BLOCK, "pickaxe", 2, 5.0, false],
	["silver", "Silver", T_SILVER_BLOCK, "pickaxe", 2, 5.0, false],
	["titanium", "Titanium", T_TITANIUM_BLOCK, "pickaxe", 2, 5.0, false],
	["gold", "Gold", T_GOLD_BLOCK, "pickaxe", 2, 5.0, false],
]


static func fence_block(family: int) -> int:
	return FENCE_START + family * 2


static func wedge_block(family: int) -> int:
	return FENCE_START + family * 2 + 1


## The item id of a family's fence/wall and wedge.
static func fence_item(family: int) -> String:
	return FAMILIES[family][0] + ("_fence" if FAMILIES[family][6] else "_wall")


static func wedge_item(family: int) -> String:
	return FAMILIES[family][0] + "_wedge"
const FLOW_MAX := 7         # water spreads this many blocks from a source

# --- Fluids ----------------------------------------------------------------------
# Every fluid has a source block (still: lakes, a poured bucket), flowing blocks
# getting weaker the further they spread (level 1..reach), and a falling block.
# world.gd runs them all with the same rules; lava and slime just add entries.
const FLUIDS := {
	"water": {"source": WATER, "flows": [WATER_FLOW_1, WATER_FLOW_2, WATER_FLOW_3, WATER_FLOW_4, WATER_FLOW_5, WATER_FLOW_6, WATER_FLOW_7],
		"fall": WATER_FALL, "reach": 7, "tick": 0.25},
	# Lava: thick and slow. It only spreads 3 blocks and moves every few water ticks.
	"lava": {"source": LAVA, "flows": [LAVA_FLOW_1, LAVA_FLOW_2, LAVA_FLOW_3], "fall": LAVA_FALL, "reach": 3, "tick": 1.0},
}
const FALLING := 8          # fluid_level() of a falling block
static var FLUID_LEVEL: Array[int] = []      # block -> -1 (not a fluid), 0 source, 1..7 flowing, 8 falling
static var FLUID_KIND: Array[String] = []    # block -> "" or the fluid's name

const MAX_LIGHT := 15

# --- Texture atlas tiles -------------------------------------------------------
const T_GRASS_TOP := 0
const T_GRASS_SIDE := 1
const T_DIRT := 2
const T_STONE := 3
const T_SAND := 4
const T_LOG_SIDE := 5
const T_LOG_TOP := 6
const T_LEAVES := 7
const T_PLANKS := 8
const T_COBBLE := 9
const T_BEDROCK := 10
const T_GLASS := 11
const T_WATER := 12
const T_LAMP := 13
const T_COPPER_ORE := 14
const T_TIN_ORE := 15
const T_IRON_ORE := 16
const T_SILVER_ORE := 17
const T_TITANIUM_ORE := 18
const T_GOLD_ORE := 19
const T_BENCH_TOP := 20
const T_BENCH1_SIDE := 21
const T_BENCH2_SIDE := 22
const T_BENCH3_SIDE := 23
const T_FURNACE_SIDE := 24
const T_FURNACE_TOP := 25
const T_SHOP_SIDE := 26
const T_SHOP_TOP := 27
const T_GOLD_BLOCK := 28
const T_CHEST_SIDE := 29
const T_CHEST_TOP := 30
const T_TORCH := 31
const T_BED_TOP := 32
const T_BED_SIDE := 33
const T_BED_ICON := 34
const T_DOOR_WOOD := 35
const T_DOOR_WOOD_TOP := 36
const T_DOOR_IRON := 37
const T_DOOR_IRON_TOP := 38
const T_DOOR_TITANIUM := 39
const T_DOOR_TITANIUM_TOP := 40
const T_SANDSTONE := 41
const T_SANDSTONE_TOP := 42
const T_CACTUS_SIDE := 43
const T_CACTUS_TOP := 44
const T_FROSTING_TOP := 45
const T_FROSTING_SIDE := 46
const T_CAKE := 47
const T_CANDY_CANE := 48
const T_CANDY_CANE_TOP := 49
const T_COTTON_CANDY := 50
const T_SNOW := 51
const T_SNOW_SIDE := 52
const T_PINE_LEAVES := 53
const T_MUSHROOM_CAP := 54
const T_MUSHROOM_STEM := 55
const T_MUSHROOM_UNDER := 56
const T_SNOWY_STONE_SIDE := 57
const T_TALL_GRASS := 58
const T_FERN := 59
const T_POPPY := 60
const T_DANDELION := 61
const T_CORNFLOWER := 62
const T_DAISY := 63
const T_BLUEBELL := 64
const T_TOADSTOOL := 65
const T_DRY_SHRUB := 66
const T_CACTUS_FLOWER := 67
const T_LOLLIPOP := 68
const T_CANDY_TULIP := 69
const T_FROST_GRASS := 70
const T_EDELWEISS := 71
const T_REDWOOD_SIDE := 72
const T_REDWOOD_TOP := 73
const T_REDWOOD_PLANKS := 74
const T_PINE_SIDE := 75
const T_PINE_TOP := 76
const T_PINE_PLANKS := 77
const T_PALM_SIDE := 78
const T_PALM_TOP := 79
const T_PALM_PLANKS := 80
const T_CANDY_PLANKS := 81
const T_PALM_LEAVES := 82
const T_CARVED_OAK := 83
const T_CARVED_REDWOOD := 84
const T_CARVED_PINE := 85
const T_CARVED_PALM := 86
const T_CARVED_CANDY := 87
const T_BOOKSHELF := 88
const T_STONE_BRICKS := 89
const T_PILLAR_SIDE := 90
const T_PILLAR_TOP := 91
const T_CHISELED := 92
const T_CARVED_SANDSTONE := 93
const T_COPPER_BLOCK := 94
const T_IRON_BLOCK := 95
const T_SILVER_BLOCK := 96
const T_TITANIUM_BLOCK := 97
const T_GOLD_INLAY := 98
const T_SILVER_INLAY := 99
const T_TITANIUM_INLAY := 100
const T_SAWMILL_SIDE := 101
const T_SAWMILL_TOP := 102
const T_STONECUTTER_SIDE := 103
const T_STONECUTTER_TOP := 104
const T_SHAPER_SIDE := 105
const T_SHAPER_TOP := 106
const T_CUTIE_ORE := 107
const T_CUTE_CRAFTER_SIDE := 108
const T_CUTE_CRAFTER_TOP := 109
const T_PORTALSTONE := 110
const T_PORTAL := 111
const T_PORTAL_LIT := 112
const T_FALL_GRASS_TOP := 113
const T_FALL_GRASS_SIDE := 114
const T_MAPLE_SIDE := 115
const T_MAPLE_TOP := 116
const T_MAPLE_PLANKS := 117
const T_MAPLE_LEAVES := 118
const T_GOLDEN_LEAVES := 119
const T_PUMPKIN_SIDE := 120
const T_PUMPKIN_TOP := 121
const T_HAY_SIDE := 122
const T_HAY_TOP := 123
const T_LEAF_PILE := 124
const T_GOLD_LEAF_PILE := 125
const T_CARVED_MAPLE := 126
const T_DEAD_GRASS_TOP := 127
const T_DEAD_GRASS_SIDE := 128
const T_DEAD_SIDE := 129
const T_DEAD_TOP := 130
const T_DEAD_PLANKS := 131
const T_JACK_FACE := 132
const T_GRAVESTONE := 133
const T_COBWEB := 134
const T_GLOWSHROOM := 135
const T_GHOST_LANTERN := 136
const T_CARVED_DEAD := 137
const T_VINE := 138
const T_BED_BLANKET := 139
const T_BED_PILLOW := 140
const T_SCRIBE_SIDE := 141
const T_SCRIBE_TOP := 142
const T_FRAME := 143
const T_STAND_ICON := 144
const T_SHRINE_CHEST_SIDE := 145
const T_SHRINE_CHEST_TOP := 146
const T_RESEARCH_SIDE := 147
const T_RESEARCH_TOP := 148
const T_SUPER_CHEST_SIDE := 149
const T_SUPER_CHEST_TOP := 150
const T_CAMPFIRE := 151
const T_BEDROLL := 152
const T_SAPLING_OAK := 153      # (the 7 saplings, in the same order as their blocks)
const T_SAPLING_REDWOOD := 154
const T_SAPLING_PINE := 155
const T_SAPLING_PALM := 156
const T_SAPLING_MAPLE := 157
const T_SAPLING_GOLDEN := 158
const T_SAPLING_CANDY := 159
const T_CASTLE_BOX := 160
const T_MARBLE := 161
const T_ONYX := 162
const T_MARBLE_BRICKS := 163
const T_ONYX_BRICKS := 164
const T_CHECKER := 165
const T_BUN_TOP := 166
const T_BUN_SIDE := 167
const T_FRIES_TOP := 168
const T_FRIES_SIDE := 169
const T_FRY_BOX := 170
const T_CIRCUS := 171
const T_ARENA_BOX := 172
const T_GATE := 173
const T_BUTTON_TOP := 174
const T_BUTTON_SIDE := 175
const T_BEDSTONE := 176
const T_DEEPSTONE := 177
const T_RUBY_ORE := 178
const T_SAPPHIRE_ORE := 179
const T_DIAMOND_ORE := 180
const T_ONYX_ORE := 181
const T_AMETHYST_ORE := 182
const T_LAVA := 183
const T_CINDERSTONE := 184
const T_JEWEL_TOP := 185
const T_JEWEL_SIDE := 186
const T_GLOW_CRYSTAL := 187
const T_MAGMA := 188
const TILE_COUNT := 189

## Wood colors by tile: [bark, inside rings, planks]. (Oak uses the old tiles.)
const WOOD_TILES := {
	T_REDWOOD_SIDE: "redwood", T_REDWOOD_TOP: "redwood", T_REDWOOD_PLANKS: "redwood",
	T_PINE_SIDE: "pine", T_PINE_TOP: "pine", T_PINE_PLANKS: "pine",
	T_PALM_SIDE: "palm", T_PALM_TOP: "palm", T_PALM_PLANKS: "palm",
	T_MAPLE_SIDE: "maple", T_MAPLE_TOP: "maple", T_MAPLE_PLANKS: "maple",
	T_DEAD_SIDE: "dead", T_DEAD_TOP: "dead", T_DEAD_PLANKS: "dead",
}
const WOOD_COLORS := {
	"oak": [Color(0.40, 0.30, 0.18), Color(0.72, 0.58, 0.36), Color(0.70, 0.55, 0.33)],
	"redwood": [Color(0.42, 0.18, 0.12), Color(0.78, 0.42, 0.3), Color(0.68, 0.32, 0.22)],
	"pine": [Color(0.26, 0.19, 0.13), Color(0.62, 0.48, 0.3), Color(0.5, 0.37, 0.24)],
	"palm": [Color(0.6, 0.5, 0.34), Color(0.88, 0.8, 0.6), Color(0.86, 0.76, 0.52)],
	"maple": [Color(0.5, 0.33, 0.24), Color(0.85, 0.62, 0.45), Color(0.8, 0.5, 0.36)],
	"dead": [Color(0.24, 0.22, 0.24), Color(0.5, 0.46, 0.48), Color(0.42, 0.38, 0.42)],
}
static var TILE_PX := 32    # pixels per tile in the atlas (64 with the Ultra HD textures)
const LEVEL_PX := [32, 32, 64]     # atlas pixels per tile for Simple, Detailed, Ultra HD
const LEVEL_RES := [16, 32, 64]    # pixels each tile is painted at
const BASE_PX := 16         # tiles are designed on a 16x16 grid (low detail = 1 pixel per cell)

## Ore speck colors, by tile.
const ORE_COLORS := {
	T_COPPER_ORE: Color(0.85, 0.50, 0.28),
	T_TIN_ORE: Color(0.80, 0.82, 0.78),
	T_IRON_ORE: Color(0.78, 0.62, 0.50),
	T_SILVER_ORE: Color(0.92, 0.94, 0.98),
	T_TITANIUM_ORE: Color(0.55, 0.72, 0.92),
	T_GOLD_ORE: Color(1.0, 0.84, 0.25),
	T_RUBY_ORE: Color(0.92, 0.12, 0.22),
	T_SAPPHIRE_ORE: Color(0.2, 0.4, 1.0),
	T_DIAMOND_ORE: Color(0.62, 0.96, 1.0),
	T_ONYX_ORE: Color(0.06, 0.05, 0.08),
	T_AMETHYST_ORE: Color(0.72, 0.38, 0.98),
}
## The five gems of the Deep, in order: [item id, name, ore block, color].
const GEMS := [
	["ruby", "Ruby", RUBY_ORE, Color(0.92, 0.12, 0.22)],
	["sapphire", "Sapphire", SAPPHIRE_ORE, Color(0.2, 0.4, 1.0)],
	["diamond", "Diamond", DIAMOND_ORE, Color(0.62, 0.96, 1.0)],
	["onyx_gem", "Onyx", ONYX_ORE, Color(0.16, 0.13, 0.2)],
	["amethyst", "Amethyst", AMETHYST_ORE, Color(0.72, 0.38, 0.98)],
]
const DEEP_GRAY := Color(0.3, 0.31, 0.38)
const BENCH_TRIM := {
	T_BENCH1_SIDE: Color(0.80, 0.48, 0.26),   # copper
	T_BENCH2_SIDE: Color(0.72, 0.72, 0.75),   # iron
	T_BENCH3_SIDE: Color(0.58, 0.76, 0.95),   # titanium
}

## Door tiles: [bottom half, top half] for each kind of door.
const DOOR_COLORS := {
	T_DOOR_WOOD: [Color(0.62, 0.45, 0.25), Color(0.42, 0.29, 0.15)],
	T_DOOR_IRON: [Color(0.74, 0.74, 0.77), Color(0.45, 0.45, 0.5)],
	T_DOOR_TITANIUM: [Color(0.58, 0.75, 0.95), Color(0.3, 0.42, 0.62)],
}

## One entry per block id.
## Extra keys: "model" = drawn by block_models.gd instead of as a cube
## ("torch", "door", "bed"); "collide" = how tall its collision box is
## (0 = walk through it); "icon" = tile to show in menus.
## tiles: [top, sides, bottom]. atten: light lost passing through (15 = blocks it).
## hardness: seconds to break by hand (-1 = unbreakable). tool/tier: what's needed
## to break it at all ("" = anything, even bare hands). drop: item id given.
const DEFS := [
	{"name": "Air", "tiles": [0, 0, 0], "transparent": true, "atten": 0, "hardness": -1},
	{"name": "Grass", "tiles": [T_GRASS_TOP, T_GRASS_SIDE, T_DIRT], "hardness": 0.6, "drop": "dirt", "tool": "shovel"},
	{"name": "Dirt", "tiles": [T_DIRT, T_DIRT, T_DIRT], "hardness": 0.6, "drop": "dirt", "tool": "shovel"},
	{"name": "Stone", "tiles": [T_STONE, T_STONE, T_STONE], "hardness": 3.0, "drop": "cobblestone", "tool": "pickaxe", "tier": 1},
	{"name": "Sand", "tiles": [T_SAND, T_SAND, T_SAND], "hardness": 0.6, "drop": "sand", "tool": "shovel"},
	{"name": "Log", "tiles": [T_LOG_TOP, T_LOG_SIDE, T_LOG_TOP], "hardness": 2.0, "drop": "log", "tool": "axe"},
	{"name": "Leaves", "tiles": [T_LEAVES, T_LEAVES, T_LEAVES], "transparent": true, "atten": 2, "hardness": 0.3, "drop": "", "tool": "axe"},
	{"name": "Planks", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "hardness": 2.0, "drop": "planks", "tool": "axe"},
	{"name": "Cobblestone", "tiles": [T_COBBLE, T_COBBLE, T_COBBLE], "hardness": 3.0, "drop": "cobblestone", "tool": "pickaxe", "tier": 1},
	{"name": "Bedrock", "tiles": [T_BEDROCK, T_BEDROCK, T_BEDROCK], "hardness": -1},
	{"name": "Glass", "tiles": [T_GLASS, T_GLASS, T_GLASS], "transparent": true, "atten": 0, "hardness": 0.5, "drop": "glass"},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Lamp", "tiles": [T_LAMP, T_LAMP, T_LAMP], "emit": 14, "hardness": 0.5, "drop": "lamp"},
	{"name": "Copper Ore", "tiles": [T_COPPER_ORE, T_COPPER_ORE, T_COPPER_ORE], "hardness": 4.0, "drop": "copper_ore", "tool": "pickaxe", "tier": 2},
	{"name": "Tin Ore", "tiles": [T_TIN_ORE, T_TIN_ORE, T_TIN_ORE], "hardness": 4.0, "drop": "tin_ore", "tool": "pickaxe", "tier": 2},
	{"name": "Iron Ore", "tiles": [T_IRON_ORE, T_IRON_ORE, T_IRON_ORE], "hardness": 5.0, "drop": "iron_ore", "tool": "pickaxe", "tier": 3},
	{"name": "Silver Ore", "tiles": [T_SILVER_ORE, T_SILVER_ORE, T_SILVER_ORE], "hardness": 5.0, "drop": "silver_ore", "tool": "pickaxe", "tier": 3},
	{"name": "Titanium Ore", "tiles": [T_TITANIUM_ORE, T_TITANIUM_ORE, T_TITANIUM_ORE], "hardness": 7.0, "drop": "titanium_ore", "tool": "pickaxe", "tier": 4},
	{"name": "Gold Ore", "tiles": [T_GOLD_ORE, T_GOLD_ORE, T_GOLD_ORE], "hardness": 7.0, "drop": "gold_ore", "tool": "pickaxe", "tier": 4},
	{"name": "Workbench Tier 1", "tiles": [T_BENCH_TOP, T_BENCH1_SIDE, T_PLANKS], "hardness": 2.5, "drop": "workbench_1", "tool": "axe"},
	{"name": "Workbench Tier 2", "tiles": [T_BENCH_TOP, T_BENCH2_SIDE, T_PLANKS], "hardness": 3.0, "drop": "workbench_2", "tool": "axe"},
	{"name": "Workbench Tier 3", "tiles": [T_BENCH_TOP, T_BENCH3_SIDE, T_PLANKS], "hardness": 3.5, "drop": "workbench_3", "tool": "axe"},
	{"name": "Furnace", "tiles": [T_FURNACE_TOP, T_FURNACE_SIDE, T_FURNACE_TOP], "hardness": 3.0, "drop": "furnace", "tool": "pickaxe", "tier": 1},
	{"name": "Block Shop", "tiles": [T_SHOP_TOP, T_SHOP_SIDE, T_PLANKS], "hardness": 2.5, "drop": "shop", "tool": "axe"},
	{"name": "Gold Block", "tiles": [T_GOLD_BLOCK, T_GOLD_BLOCK, T_GOLD_BLOCK], "hardness": 5.0, "drop": "gold_block", "tool": "pickaxe", "tier": 3},
	{"name": "Chest", "tiles": [T_CHEST_TOP, T_CHEST_SIDE, T_CHEST_TOP], "hardness": 2.5, "drop": "chest", "tool": "axe"},
	{"name": "Torch", "tiles": [T_TORCH, T_TORCH, T_TORCH], "transparent": true, "atten": 0, "emit": 12, "hardness": 0.05, "drop": "torch", "model": "torch", "collide": 0.0},
	{"name": "Bed", "tiles": [T_BED_TOP, T_BED_SIDE, T_PLANKS], "icon": T_BED_ICON, "transparent": true, "atten": 0, "hardness": 1.0, "drop": "bed", "tool": "axe", "model": "bed", "collide": 0.5625},
	{"name": "Wooden Door", "tiles": [T_DOOR_WOOD, T_DOOR_WOOD, T_DOOR_WOOD], "transparent": true, "atten": 0, "hardness": 2.5, "drop": "wooden_door", "tool": "axe", "model": "door", "collide": 1.0},
	{"name": "Wooden Door", "tiles": [T_DOOR_WOOD, T_DOOR_WOOD, T_DOOR_WOOD], "transparent": true, "atten": 0, "hardness": 2.5, "drop": "wooden_door", "tool": "axe", "model": "door", "collide": 0.0},
	{"name": "Iron Door", "tiles": [T_DOOR_IRON, T_DOOR_IRON, T_DOOR_IRON], "transparent": true, "atten": 0, "hardness": 6.0, "drop": "iron_door", "tool": "pickaxe", "tier": 3, "model": "door", "collide": 1.0},
	{"name": "Iron Door", "tiles": [T_DOOR_IRON, T_DOOR_IRON, T_DOOR_IRON], "transparent": true, "atten": 0, "hardness": 6.0, "drop": "iron_door", "tool": "pickaxe", "tier": 3, "model": "door", "collide": 0.0},
	{"name": "Titanium Door", "tiles": [T_DOOR_TITANIUM, T_DOOR_TITANIUM, T_DOOR_TITANIUM], "transparent": true, "atten": 0, "hardness": 9.0, "drop": "titanium_door", "tool": "pickaxe", "tier": 5, "model": "door", "collide": 1.0},
	{"name": "Titanium Door", "tiles": [T_DOOR_TITANIUM, T_DOOR_TITANIUM, T_DOOR_TITANIUM], "transparent": true, "atten": 0, "hardness": 9.0, "drop": "titanium_door", "tool": "pickaxe", "tier": 5, "model": "door", "collide": 0.0},
	{"name": "Sandstone", "tiles": [T_SANDSTONE_TOP, T_SANDSTONE, T_SANDSTONE_TOP], "hardness": 2.0, "drop": "sandstone", "tool": "pickaxe", "tier": 1},
	{"name": "Cactus", "tiles": [T_CACTUS_TOP, T_CACTUS_SIDE, T_CACTUS_TOP], "hardness": 0.6, "drop": "cactus", "tool": "axe"},
	{"name": "Frosting", "tiles": [T_FROSTING_TOP, T_FROSTING_SIDE, T_CAKE], "hardness": 0.6, "drop": "cake", "tool": "shovel"},
	{"name": "Cake", "tiles": [T_CAKE, T_CAKE, T_CAKE], "hardness": 0.6, "drop": "cake", "tool": "shovel"},
	{"name": "Candy Cane", "tiles": [T_CANDY_CANE_TOP, T_CANDY_CANE, T_CANDY_CANE_TOP], "hardness": 2.0, "drop": "candy_cane", "tool": "axe"},
	{"name": "Cotton Candy", "tiles": [T_COTTON_CANDY, T_COTTON_CANDY, T_COTTON_CANDY], "transparent": true, "atten": 2, "hardness": 0.3, "drop": "cotton_candy", "tool": "axe"},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Snow", "tiles": [T_SNOW, T_SNOW_SIDE, T_DIRT], "hardness": 0.5, "drop": "snow", "tool": "shovel"},
	{"name": "Pine Needles", "tiles": [T_PINE_LEAVES, T_PINE_LEAVES, T_PINE_LEAVES], "transparent": true, "atten": 2, "hardness": 0.3, "drop": "", "tool": "axe"},
	{"name": "Mushroom Cap", "tiles": [T_MUSHROOM_CAP, T_MUSHROOM_CAP, T_MUSHROOM_UNDER], "hardness": 0.8, "drop": "mushroom", "tool": "axe"},
	{"name": "Mushroom Stem", "tiles": [T_MUSHROOM_UNDER, T_MUSHROOM_STEM, T_MUSHROOM_UNDER], "hardness": 1.0, "drop": "mushroom", "tool": "axe"},
	{"name": "Snowy Stone", "tiles": [T_SNOW, T_SNOWY_STONE_SIDE, T_STONE], "hardness": 3.0, "drop": "cobblestone", "tool": "pickaxe", "tier": 1},
]

## Building blocks (OAK_SLAB..SHAPER, in order), added to DEFS at startup.
## "shape" blocks are drawn as a few boxes (see SHAPES) instead of a full cube.
const BUILD_DEFS := [
	{"name": "Oak Slab", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "drop": "oak_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Oak Stairs", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "drop": "oak_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Oak Column", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "drop": "oak_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Oak Table", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "drop": "oak_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Oak Chair", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "drop": "oak_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Oak", "tiles": [T_CARVED_OAK, T_CARVED_OAK, T_CARVED_OAK], "drop": "carved_oak", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Redwood Slab", "tiles": [T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, T_REDWOOD_PLANKS], "drop": "redwood_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Redwood Stairs", "tiles": [T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, T_REDWOOD_PLANKS], "drop": "redwood_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Redwood Column", "tiles": [T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, T_REDWOOD_PLANKS], "drop": "redwood_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Redwood Table", "tiles": [T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, T_REDWOOD_PLANKS], "drop": "redwood_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Redwood Chair", "tiles": [T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, T_REDWOOD_PLANKS], "drop": "redwood_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Redwood", "tiles": [T_CARVED_REDWOOD, T_CARVED_REDWOOD, T_CARVED_REDWOOD], "drop": "carved_redwood", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Pine Slab", "tiles": [T_PINE_PLANKS, T_PINE_PLANKS, T_PINE_PLANKS], "drop": "pine_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Pine Stairs", "tiles": [T_PINE_PLANKS, T_PINE_PLANKS, T_PINE_PLANKS], "drop": "pine_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Pine Column", "tiles": [T_PINE_PLANKS, T_PINE_PLANKS, T_PINE_PLANKS], "drop": "pine_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Pine Table", "tiles": [T_PINE_PLANKS, T_PINE_PLANKS, T_PINE_PLANKS], "drop": "pine_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Pine Chair", "tiles": [T_PINE_PLANKS, T_PINE_PLANKS, T_PINE_PLANKS], "drop": "pine_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Pine", "tiles": [T_CARVED_PINE, T_CARVED_PINE, T_CARVED_PINE], "drop": "carved_pine", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Palm Slab", "tiles": [T_PALM_PLANKS, T_PALM_PLANKS, T_PALM_PLANKS], "drop": "palm_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Palm Stairs", "tiles": [T_PALM_PLANKS, T_PALM_PLANKS, T_PALM_PLANKS], "drop": "palm_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Palm Column", "tiles": [T_PALM_PLANKS, T_PALM_PLANKS, T_PALM_PLANKS], "drop": "palm_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Palm Table", "tiles": [T_PALM_PLANKS, T_PALM_PLANKS, T_PALM_PLANKS], "drop": "palm_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Palm Chair", "tiles": [T_PALM_PLANKS, T_PALM_PLANKS, T_PALM_PLANKS], "drop": "palm_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Palm", "tiles": [T_CARVED_PALM, T_CARVED_PALM, T_CARVED_PALM], "drop": "carved_palm", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Candy Slab", "tiles": [T_CANDY_PLANKS, T_CANDY_PLANKS, T_CANDY_PLANKS], "drop": "candy_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Candy Stairs", "tiles": [T_CANDY_PLANKS, T_CANDY_PLANKS, T_CANDY_PLANKS], "drop": "candy_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Candy Column", "tiles": [T_CANDY_PLANKS, T_CANDY_PLANKS, T_CANDY_PLANKS], "drop": "candy_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Candy Table", "tiles": [T_CANDY_PLANKS, T_CANDY_PLANKS, T_CANDY_PLANKS], "drop": "candy_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Candy Chair", "tiles": [T_CANDY_PLANKS, T_CANDY_PLANKS, T_CANDY_PLANKS], "drop": "candy_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Candy", "tiles": [T_CARVED_CANDY, T_CARVED_CANDY, T_CARVED_CANDY], "drop": "carved_candy", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Bookshelf", "tiles": [T_PLANKS, T_BOOKSHELF, T_PLANKS], "drop": "bookshelf", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Stone Bricks", "tiles": [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], "drop": "stone_bricks", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Cobblestone Slab", "tiles": [T_COBBLE, T_COBBLE, T_COBBLE], "drop": "cobblestone_slab", "shape": "slab", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Cobblestone Stairs", "tiles": [T_COBBLE, T_COBBLE, T_COBBLE], "drop": "cobblestone_stairs", "shape": "stairs", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Cobblestone Column", "tiles": [T_COBBLE, T_COBBLE, T_COBBLE], "drop": "cobblestone_column", "shape": "column", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Stone Brick Slab", "tiles": [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], "drop": "stone_brick_slab", "shape": "slab", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Stone Brick Stairs", "tiles": [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], "drop": "stone_brick_stairs", "shape": "stairs", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Stone Brick Column", "tiles": [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], "drop": "stone_brick_column", "shape": "column", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Sandstone Slab", "tiles": [T_SANDSTONE, T_SANDSTONE, T_SANDSTONE], "drop": "sandstone_slab", "shape": "slab", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Sandstone Stairs", "tiles": [T_SANDSTONE, T_SANDSTONE, T_SANDSTONE], "drop": "sandstone_stairs", "shape": "stairs", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Sandstone Column", "tiles": [T_SANDSTONE, T_SANDSTONE, T_SANDSTONE], "drop": "sandstone_column", "shape": "column", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Stone Pillar", "tiles": [T_PILLAR_TOP, T_PILLAR_SIDE, T_PILLAR_TOP], "drop": "stone_pillar", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Chiseled Stone Bricks", "tiles": [T_CHISELED, T_CHISELED, T_CHISELED], "drop": "chiseled_bricks", "tool": "pickaxe", "tier": 1, "hardness": 3.0},
	{"name": "Carved Sandstone", "tiles": [T_SANDSTONE_TOP, T_CARVED_SANDSTONE, T_SANDSTONE_TOP], "drop": "carved_sandstone", "tool": "pickaxe", "tier": 1, "hardness": 2.0},
	{"name": "Copper Block", "tiles": [T_COPPER_BLOCK, T_COPPER_BLOCK, T_COPPER_BLOCK], "drop": "copper_block", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Iron Block", "tiles": [T_IRON_BLOCK, T_IRON_BLOCK, T_IRON_BLOCK], "drop": "iron_block", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Silver Block", "tiles": [T_SILVER_BLOCK, T_SILVER_BLOCK, T_SILVER_BLOCK], "drop": "silver_block", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Titanium Block", "tiles": [T_TITANIUM_BLOCK, T_TITANIUM_BLOCK, T_TITANIUM_BLOCK], "drop": "titanium_block", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Copper Slab", "tiles": [T_COPPER_BLOCK, T_COPPER_BLOCK, T_COPPER_BLOCK], "drop": "copper_slab", "shape": "slab", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Iron Slab", "tiles": [T_IRON_BLOCK, T_IRON_BLOCK, T_IRON_BLOCK], "drop": "iron_slab", "shape": "slab", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Silver Slab", "tiles": [T_SILVER_BLOCK, T_SILVER_BLOCK, T_SILVER_BLOCK], "drop": "silver_slab", "shape": "slab", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Titanium Slab", "tiles": [T_TITANIUM_BLOCK, T_TITANIUM_BLOCK, T_TITANIUM_BLOCK], "drop": "titanium_slab", "shape": "slab", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Gold Slab", "tiles": [T_GOLD_BLOCK, T_GOLD_BLOCK, T_GOLD_BLOCK], "drop": "gold_slab", "shape": "slab", "tool": "pickaxe", "tier": 2, "hardness": 5.0},
	{"name": "Gold Inlaid Bricks", "tiles": [T_GOLD_INLAY, T_GOLD_INLAY, T_GOLD_INLAY], "drop": "gold_inlaid_bricks", "tool": "pickaxe", "tier": 1, "hardness": 3.5},
	{"name": "Silver Inlaid Bricks", "tiles": [T_SILVER_INLAY, T_SILVER_INLAY, T_SILVER_INLAY], "drop": "silver_inlaid_bricks", "tool": "pickaxe", "tier": 1, "hardness": 3.5},
	{"name": "Titanium Inlaid Bricks", "tiles": [T_TITANIUM_INLAY, T_TITANIUM_INLAY, T_TITANIUM_INLAY], "drop": "titanium_inlaid_bricks", "tool": "pickaxe", "tier": 1, "hardness": 3.5},
	{"name": "Sawmill", "tiles": [T_SAWMILL_TOP, T_SAWMILL_SIDE, T_PLANKS], "drop": "sawmill", "tool": "axe", "hardness": 2.5},
	{"name": "Stonecutter", "tiles": [T_STONECUTTER_TOP, T_STONECUTTER_SIDE, T_COBBLE], "drop": "stonecutter", "tool": "pickaxe", "hardness": 3.0},
	{"name": "Shaper", "tiles": [T_SHAPER_TOP, T_SHAPER_SIDE, T_IRON_BLOCK], "drop": "shaper", "tool": "pickaxe", "hardness": 4.0},
	{"name": "Cutie Ore", "tiles": [T_CUTIE_ORE, T_CUTIE_ORE, T_CUTIE_ORE], "drop": "cutie_ore", "tool": "pickaxe", "tier": 2, "hardness": 2.5},
	{"name": "Cute Crafter", "tiles": [T_CUTE_CRAFTER_TOP, T_CUTE_CRAFTER_SIDE, T_PLANKS], "drop": "cute_crafter", "tool": "axe", "hardness": 2.5},
	{"name": "Portalstone", "tiles": [T_PORTALSTONE, T_PORTALSTONE, T_PORTALSTONE], "drop": "portalstone", "tool": "pickaxe", "tier": 1, "hardness": 4.0},
	{"name": "Portal", "tiles": [T_PORTAL, T_PORTAL, T_PORTAL], "transparent": true, "atten": 1, "hardness": -1, "collide": 0.0, "emit": 4},
	{"name": "Portal", "tiles": [T_PORTAL_LIT, T_PORTAL_LIT, T_PORTAL_LIT], "transparent": true, "atten": 0, "hardness": -1, "collide": 0.0, "emit": 12},
]

## Each shape as boxes inside the block, [from, to], facing "north" (-Z).
## They're turned to face the way the player placed them, and slabs (and
## stairs) can be flipped to the top half.
const SHAPES := {
	"slab": [[Vector3(0, 0, 0), Vector3(1, 0.5, 1)]],
	"grave": [[Vector3(0.15, 0, 0.3), Vector3(0.85, 0.12, 0.7)], [Vector3(0.22, 0.12, 0.42), Vector3(0.78, 0.7, 0.58)],
			[Vector3(0.3, 0.7, 0.42), Vector3(0.7, 0.85, 0.58)]],
	"stairs": [[Vector3(0, 0, 0), Vector3(1, 0.5, 1)], [Vector3(0, 0.5, 0), Vector3(1, 1, 0.5)]],
	"column": [[Vector3(0.1, 0, 0.1), Vector3(0.9, 0.15, 0.9)], [Vector3(0.22, 0.15, 0.22), Vector3(0.78, 0.85, 0.78)],
			[Vector3(0.1, 0.85, 0.1), Vector3(0.9, 1, 0.9)]],
	"table": [[Vector3(0, 0.82, 0), Vector3(1, 1, 1)], [Vector3(0.06, 0, 0.06), Vector3(0.2, 0.82, 0.2)],
			[Vector3(0.8, 0, 0.06), Vector3(0.94, 0.82, 0.2)], [Vector3(0.06, 0, 0.8), Vector3(0.2, 0.82, 0.94)],
			[Vector3(0.8, 0, 0.8), Vector3(0.94, 0.82, 0.94)]],
	# Fences and walls join up with their neighbours (see fence_boxes); this is
	# how they look on their own, with arms both ways along X (for icons).
	"fence": [[Vector3(0.375, 0, 0.375), Vector3(0.625, 1, 0.625)], [Vector3(0, 0.375, 0.4375), Vector3(1, 0.5625, 0.5625)],
			[Vector3(0, 0.75, 0.4375), Vector3(1, 0.9375, 0.5625)]],
	"wall": [[Vector3(0.25, 0, 0.25), Vector3(0.75, 1, 0.75)], [Vector3(0, 0, 0.3125), Vector3(1, 0.8125, 0.6875)]],
	# A wedge is a smooth slope (the mesher draws it); for its icon, steps.
	"wedge": [[Vector3(0, 0, 0), Vector3(1, 0.125, 1)], [Vector3(0, 0.125, 0), Vector3(1, 0.25, 0.875)], [Vector3(0, 0.25, 0), Vector3(1, 0.375, 0.75)], [Vector3(0, 0.375, 0), Vector3(1, 0.5, 0.625)], [Vector3(0, 0.5, 0), Vector3(1, 0.625, 0.5)], [Vector3(0, 0.625, 0), Vector3(1, 0.75, 0.375)], [Vector3(0, 0.75, 0), Vector3(1, 0.875, 0.25)], [Vector3(0, 0.875, 0), Vector3(1, 1, 0.125)]],
	"chair": [[Vector3(0.15, 0.42, 0.15), Vector3(0.85, 0.52, 0.85)], [Vector3(0.15, 0.52, 0.15), Vector3(0.85, 1.0, 0.27)],
			[Vector3(0.17, 0, 0.17), Vector3(0.27, 0.42, 0.27)], [Vector3(0.73, 0, 0.17), Vector3(0.83, 0.42, 0.27)],
			[Vector3(0.17, 0, 0.73), Vector3(0.27, 0.42, 0.83)], [Vector3(0.73, 0, 0.73), Vector3(0.83, 0.42, 0.83)]],
}


## The boxes of a shape block, turned (rot 0-3 = quarter turns) and flipped
## upside down (rot + 4) the way it was placed.
## A fence or wall's boxes, with an arm toward each neighbour it joins
## (sides: +X, -X, +Z, -Z).
static func fence_boxes(block: int, sides: Array) -> Array:
	var wall: bool = SHAPE[block] == "wall"
	var out := [[Vector3(0.25, 0, 0.25), Vector3(0.75, 1, 0.75)]] if wall else [[Vector3(0.375, 0, 0.375), Vector3(0.625, 1, 0.625)]]
	var rails := [[0.0, 0.8125, 0.3125, 0.6875]] if wall else [[0.375, 0.5625, 0.4375, 0.5625], [0.75, 0.9375, 0.4375, 0.5625]]
	var post0 := 0.25 if wall else 0.375
	var post1 := 0.75 if wall else 0.625
	for r in rails:
		if sides[0]:
			out.append([Vector3(post1, r[0], r[2]), Vector3(1, r[1], r[3])])
		if sides[1]:
			out.append([Vector3(0, r[0], r[2]), Vector3(post0, r[1], r[3])])
		if sides[2]:
			out.append([Vector3(r[2], r[0], post1), Vector3(r[3], r[1], 1)])
		if sides[3]:
			out.append([Vector3(r[2], r[0], 0), Vector3(r[3], r[1], post0)])
	return out


## Do fences/walls join this neighbour? (Other fences and walls, and full blocks.)
static func fence_joins(n: int) -> bool:
	return SHAPE[n] in ["fence", "wall"] or (MODEL[n] == "" and COLLIDE[n] > 0.0 and TRANSPARENT[n] == 0)


static func shape_boxes(block: int, rot: int) -> Array:
	var shape: String = SHAPE[block]
	if shape == "":
		return [[Vector3.ZERO, Vector3.ONE]]
	var out := []
	var turns := rot & 3
	var flip := (rot & 4) != 0 and shape in ["slab", "stairs"]
	for box in SHAPES[shape]:
		var a: Vector3 = box[0]
		var b: Vector3 = box[1]
		for t in turns:  # a quarter turn around the middle: (x, z) -> (1 - z, x)
			var na := Vector3(1.0 - b.z, a.y, a.x)
			var nb := Vector3(1.0 - a.z, b.y, b.x)
			a = na
			b = nb
		if flip:
			var fa := Vector3(a.x, 1.0 - b.y, a.z)
			var fb := Vector3(b.x, 1.0 - a.y, b.z)
			a = fa
			b = fb
		out.append([a, b])
	return out


## Woods (block ids LOG_X..PALM_LEAVES, in order), added to DEFS at startup.
## [name, top tile, side tile, drop, axis, extra]. axis: "y" standing, "x"/"z" lying down.
const WOOD_DEFS := [
	["Log", T_LOG_TOP, T_LOG_SIDE, "log", "x", {}],
	["Log", T_LOG_TOP, T_LOG_SIDE, "log", "z", {}],
	["Redwood Log", T_REDWOOD_TOP, T_REDWOOD_SIDE, "redwood_log", "y", {}],
	["Redwood Log", T_REDWOOD_TOP, T_REDWOOD_SIDE, "redwood_log", "x", {}],
	["Redwood Log", T_REDWOOD_TOP, T_REDWOOD_SIDE, "redwood_log", "z", {}],
	["Pine Log", T_PINE_TOP, T_PINE_SIDE, "pine_log", "y", {}],
	["Pine Log", T_PINE_TOP, T_PINE_SIDE, "pine_log", "x", {}],
	["Pine Log", T_PINE_TOP, T_PINE_SIDE, "pine_log", "z", {}],
	["Palm Log", T_PALM_TOP, T_PALM_SIDE, "palm_log", "y", {}],
	["Palm Log", T_PALM_TOP, T_PALM_SIDE, "palm_log", "x", {}],
	["Palm Log", T_PALM_TOP, T_PALM_SIDE, "palm_log", "z", {}],
	["Candy Cane", T_CANDY_CANE_TOP, T_CANDY_CANE, "candy_cane", "x", {}],
	["Candy Cane", T_CANDY_CANE_TOP, T_CANDY_CANE, "candy_cane", "z", {}],
	["Redwood Planks", T_REDWOOD_PLANKS, T_REDWOOD_PLANKS, "redwood_planks", "", {}],
	["Pine Planks", T_PINE_PLANKS, T_PINE_PLANKS, "pine_planks", "", {}],
	["Palm Planks", T_PALM_PLANKS, T_PALM_PLANKS, "palm_planks", "", {}],
	["Candy Planks", T_CANDY_PLANKS, T_CANDY_PLANKS, "candy_planks", "", {}],
	["Palm Fronds", T_PALM_LEAVES, T_PALM_LEAVES, "", "", {"transparent": true, "atten": 2, "hardness": 0.3}],
]

## A log block in a direction: base = the standing log (LOG, REDWOOD_LOG...).
static func log_variant(base: int, axis: String) -> int:
	if not LOG_FAMILY.has(base):
		return base
	return LOG_FAMILY[base][["y", "x", "z"].find(axis)] if axis in ["y", "x", "z"] else base

const LOG_FAMILY := {
	LOG: [LOG, LOG_X, LOG_Z], REDWOOD_LOG: [REDWOOD_LOG, REDWOOD_LOG_X, REDWOOD_LOG_Z],
	PINE_LOG: [PINE_LOG, PINE_LOG_X, PINE_LOG_Z], PALM_LOG: [PALM_LOG, PALM_LOG_X, PALM_LOG_Z],
	CANDY_CANE: [CANDY_CANE, CANDY_CANE_X, CANDY_CANE_Z],
	MAPLE_LOG: [MAPLE_LOG, MAPLE_LOG_X, MAPLE_LOG_Z],
	DEAD_LOG: [DEAD_LOG, DEAD_LOG_X, DEAD_LOG_Z],
}


## The fall forest's blocks (FALL_GRASS..CARVED_MAPLE, in order), added last.
const FALL_DEFS := [
	{"name": "Autumn Grass", "tiles": [T_FALL_GRASS_TOP, T_FALL_GRASS_SIDE, T_DIRT], "hardness": 0.6, "drop": "dirt", "tool": "shovel"},
	{"name": "Maple Log", "tiles": [T_MAPLE_TOP, T_MAPLE_SIDE, T_MAPLE_TOP], "hardness": 2.0, "drop": "maple_log", "tool": "axe", "axis": "y", "wood": true},
	{"name": "Maple Log", "tiles": [T_MAPLE_TOP, T_MAPLE_SIDE, T_MAPLE_TOP], "hardness": 2.0, "drop": "maple_log", "tool": "axe", "axis": "x", "wood": true},
	{"name": "Maple Log", "tiles": [T_MAPLE_TOP, T_MAPLE_SIDE, T_MAPLE_TOP], "hardness": 2.0, "drop": "maple_log", "tool": "axe", "axis": "z", "wood": true},
	{"name": "Maple Planks", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "hardness": 2.0, "drop": "maple_planks", "tool": "axe", "wood": true},
	{"name": "Red Maple Leaves", "tiles": [T_MAPLE_LEAVES, T_MAPLE_LEAVES, T_MAPLE_LEAVES], "transparent": true, "atten": 2, "hardness": 0.3, "drop": "", "tool": "axe"},
	{"name": "Golden Leaves", "tiles": [T_GOLDEN_LEAVES, T_GOLDEN_LEAVES, T_GOLDEN_LEAVES], "transparent": true, "atten": 2, "hardness": 0.3, "drop": "", "tool": "axe"},
	{"name": "Pumpkin", "tiles": [T_PUMPKIN_TOP, T_PUMPKIN_SIDE, T_PUMPKIN_TOP], "hardness": 1.0, "drop": "pumpkin", "tool": "axe"},
	{"name": "Hay Bale", "tiles": [T_HAY_TOP, T_HAY_SIDE, T_HAY_TOP], "hardness": 0.5, "drop": "hay_bale"},
	{"name": "Leaf Pile", "tiles": [T_LEAF_PILE, T_LEAF_PILE, T_LEAF_PILE], "transparent": true, "atten": 0, "hardness": 0.0, "drop": "leaf_pile", "model": "cross", "collide": 0.0, "replace": true},
	{"name": "Golden Leaf Pile", "tiles": [T_GOLD_LEAF_PILE, T_GOLD_LEAF_PILE, T_GOLD_LEAF_PILE], "transparent": true, "atten": 0, "hardness": 0.0, "drop": "golden_leaf_pile", "model": "cross", "collide": 0.0, "replace": true},
	{"name": "Maple Slab", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "drop": "maple_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Maple Stairs", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "drop": "maple_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Maple Column", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "drop": "maple_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Maple Table", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "drop": "maple_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Maple Chair", "tiles": [T_MAPLE_PLANKS, T_MAPLE_PLANKS, T_MAPLE_PLANKS], "drop": "maple_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Maple", "tiles": [T_CARVED_MAPLE, T_CARVED_MAPLE, T_CARVED_MAPLE], "drop": "carved_maple", "tool": "axe", "hardness": 2.0, "wood": true},
]


## The spooky forest's blocks (DEAD_GRASS..CARVED_DEAD, in order), added last.
const SPOOKY_DEFS := [
	{"name": "Spooky Grass", "tiles": [T_DEAD_GRASS_TOP, T_DEAD_GRASS_SIDE, T_DIRT], "hardness": 0.6, "drop": "dirt", "tool": "shovel"},
	{"name": "Deadwood Log", "tiles": [T_DEAD_TOP, T_DEAD_SIDE, T_DEAD_TOP], "hardness": 2.0, "drop": "dead_log", "tool": "axe", "axis": "y", "wood": true},
	{"name": "Deadwood Log", "tiles": [T_DEAD_TOP, T_DEAD_SIDE, T_DEAD_TOP], "hardness": 2.0, "drop": "dead_log", "tool": "axe", "axis": "x", "wood": true},
	{"name": "Deadwood Log", "tiles": [T_DEAD_TOP, T_DEAD_SIDE, T_DEAD_TOP], "hardness": 2.0, "drop": "dead_log", "tool": "axe", "axis": "z", "wood": true},
	{"name": "Deadwood Planks", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "hardness": 2.0, "drop": "dead_planks", "tool": "axe", "wood": true},
	{"name": "Jack-o'-Lantern", "tiles": [T_PUMPKIN_TOP, T_JACK_FACE, T_PUMPKIN_TOP], "hardness": 1.0, "drop": "jack_o_lantern", "tool": "axe", "emit": 13},
	{"name": "Gravestone", "tiles": [T_GRAVESTONE, T_GRAVESTONE, T_GRAVESTONE], "hardness": 3.0, "drop": "gravestone", "tool": "pickaxe", "tier": 1, "shape": "grave"},
	{"name": "Cobweb", "tiles": [T_COBWEB, T_COBWEB, T_COBWEB], "transparent": true, "atten": 0, "hardness": 0.0, "drop": "spider_silk", "model": "cross", "collide": 0.0, "replace": true},
	{"name": "Glowshroom", "tiles": [T_GLOWSHROOM, T_GLOWSHROOM, T_GLOWSHROOM], "transparent": true, "atten": 0, "hardness": 0.0, "drop": "glowshroom", "model": "cross", "collide": 0.0, "emit": 6},
	{"name": "Ghost Lantern", "tiles": [T_GHOST_LANTERN, T_GHOST_LANTERN, T_GHOST_LANTERN], "transparent": true, "atten": 0, "hardness": 0.5, "drop": "ghost_lantern", "emit": 14},
	{"name": "Deadwood Slab", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "drop": "dead_slab", "shape": "slab", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Deadwood Stairs", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "drop": "dead_stairs", "shape": "stairs", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Deadwood Column", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "drop": "dead_column", "shape": "column", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Deadwood Table", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "drop": "dead_table", "shape": "table", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Deadwood Chair", "tiles": [T_DEAD_PLANKS, T_DEAD_PLANKS, T_DEAD_PLANKS], "drop": "dead_chair", "shape": "chair", "tool": "axe", "hardness": 1.5, "wood": true},
	{"name": "Carved Deadwood", "tiles": [T_CARVED_DEAD, T_CARVED_DEAD, T_CARVED_DEAD], "drop": "carved_dead", "tool": "axe", "hardness": 2.0, "wood": true},
	{"name": "Vine", "tiles": [T_VINE, T_VINE, T_VINE], "transparent": true, "atten": 0, "hardness": 0.0, "drop": "vine", "model": "cross", "collide": 0.0},
	{"name": "Bed", "tiles": [T_BED_BLANKET, T_BED_BLANKET, T_PLANKS], "icon": T_BED_ICON, "transparent": true, "atten": 0, "hardness": 1.0, "drop": "bed", "tool": "axe", "model": "bed", "collide": 0.5625},
	{"name": "Scribe Desk", "tiles": [T_SCRIBE_TOP, T_SCRIBE_SIDE, T_PLANKS], "hardness": 2.5, "drop": "scribe", "tool": "axe"},
	{"name": "Item Frame", "tiles": [T_FRAME, T_FRAME, T_FRAME], "transparent": true, "atten": 0, "hardness": 0.3, "drop": "item_frame", "model": "frame", "collide": 0.0},
	{"name": "Armor Stand", "tiles": [T_PLANKS, T_PLANKS, T_PLANKS], "icon": T_STAND_ICON, "transparent": true, "atten": 0, "hardness": 1.0, "drop": "armor_stand", "tool": "axe", "model": "stand", "collide": 1.0},
	{"name": "Stone Chest", "tiles": [T_SHRINE_CHEST_TOP, T_SHRINE_CHEST_SIDE, T_SHRINE_CHEST_TOP], "hardness": -1.0, "drop": ""},
]


## The chessboard kingdom's blocks (WHITE_MARBLE.. in order). Marble and onyx
## can be broken by hand (slowly); a pickaxe is much faster.
const CHESS_DEFS := [
	{"name": "White Marble", "tiles": [T_MARBLE, T_MARBLE, T_MARBLE], "hardness": 1.4, "drop": "white_marble", "tool": "pickaxe"},
	{"name": "Black Onyx", "tiles": [T_ONYX, T_ONYX, T_ONYX], "hardness": 1.4, "drop": "black_onyx", "tool": "pickaxe"},
	{"name": "Marble Bricks", "tiles": [T_MARBLE_BRICKS, T_MARBLE_BRICKS, T_MARBLE_BRICKS], "hardness": 2.5, "drop": "marble_bricks", "tool": "pickaxe", "tier": 1},
	{"name": "Onyx Bricks", "tiles": [T_ONYX_BRICKS, T_ONYX_BRICKS, T_ONYX_BRICKS], "hardness": 2.5, "drop": "onyx_bricks", "tool": "pickaxe", "tier": 1},
	{"name": "Marble Slab", "tiles": [T_MARBLE_BRICKS, T_MARBLE_BRICKS, T_MARBLE_BRICKS], "hardness": 2.5, "drop": "marble_slab", "tool": "pickaxe", "tier": 1, "shape": "slab"},
	{"name": "Onyx Slab", "tiles": [T_ONYX_BRICKS, T_ONYX_BRICKS, T_ONYX_BRICKS], "hardness": 2.5, "drop": "onyx_slab", "tool": "pickaxe", "tier": 1, "shape": "slab"},
	{"name": "Marble Stairs", "tiles": [T_MARBLE_BRICKS, T_MARBLE_BRICKS, T_MARBLE_BRICKS], "hardness": 2.5, "drop": "marble_stairs", "tool": "pickaxe", "tier": 1, "shape": "stairs"},
	{"name": "Onyx Stairs", "tiles": [T_ONYX_BRICKS, T_ONYX_BRICKS, T_ONYX_BRICKS], "hardness": 2.5, "drop": "onyx_stairs", "tool": "pickaxe", "tier": 1, "shape": "stairs"},
	{"name": "Marble Column", "tiles": [T_MARBLE, T_MARBLE, T_MARBLE], "hardness": 2.5, "drop": "marble_column", "tool": "pickaxe", "tier": 1, "shape": "column"},
	{"name": "Onyx Column", "tiles": [T_ONYX, T_ONYX, T_ONYX], "hardness": 2.5, "drop": "onyx_column", "tool": "pickaxe", "tier": 1, "shape": "column"},
	{"name": "Checker Tile", "tiles": [T_CHECKER, T_CHECKER, T_CHECKER], "hardness": 2.5, "drop": "checker_tile", "tool": "pickaxe", "tier": 1},
	{"name": "Sesame Bun", "tiles": [T_BUN_TOP, T_BUN_SIDE, T_DIRT], "hardness": 0.6, "drop": "sesame_bun", "tool": "shovel"},
	{"name": "Giant Fries", "tiles": [T_FRIES_TOP, T_FRIES_SIDE, T_FRIES_TOP], "hardness": 0.5, "drop": "french_fries"},
	{"name": "Fry Box", "tiles": [T_FRIES_TOP, T_FRY_BOX, T_FRY_BOX], "hardness": 0.8, "drop": "fry_box"},
	{"name": "Circus Stripes", "tiles": [T_CIRCUS, T_CIRCUS, T_CIRCUS], "hardness": 0.8, "drop": "circus_stripes"},
	{"name": "Arena in a Box", "tiles": [T_ARENA_BOX, T_ARENA_BOX, T_ARENA_BOX], "hardness": 0.5, "drop": "arena_box", "emit": 6},
	{"name": "Arena Gate", "tiles": [T_GATE, T_GATE, T_GATE], "hardness": -1.0, "drop": "", "transparent": true, "atten": 1},
	{"name": "Arena Button", "tiles": [T_BUTTON_TOP, T_BUTTON_SIDE, T_BUTTON_SIDE], "hardness": -1.0, "drop": "", "emit": 7},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Water", "tiles": [T_WATER, T_WATER, T_WATER], "transparent": true, "atten": 2, "hardness": -1},
	{"name": "Bedstone", "tiles": [T_BEDSTONE, T_BEDSTONE, T_BEDSTONE], "hardness": 14.0, "drop": "bedstone", "tool": "pickaxe", "tier": 5},
	{"name": "Deepstone", "tiles": [T_DEEPSTONE, T_DEEPSTONE, T_DEEPSTONE], "hardness": 3.5, "drop": "deepstone", "tool": "pickaxe", "tier": 1},
	{"name": "Ruby Ore", "tiles": [T_RUBY_ORE, T_RUBY_ORE, T_RUBY_ORE], "hardness": 6.0, "drop": "ruby", "tool": "pickaxe", "tier": 3},
	{"name": "Sapphire Ore", "tiles": [T_SAPPHIRE_ORE, T_SAPPHIRE_ORE, T_SAPPHIRE_ORE], "hardness": 6.0, "drop": "sapphire", "tool": "pickaxe", "tier": 3},
	{"name": "Diamond Ore", "tiles": [T_DIAMOND_ORE, T_DIAMOND_ORE, T_DIAMOND_ORE], "hardness": 8.0, "drop": "diamond", "tool": "pickaxe", "tier": 4},
	{"name": "Onyx Ore", "tiles": [T_ONYX_ORE, T_ONYX_ORE, T_ONYX_ORE], "hardness": 8.0, "drop": "onyx_gem", "tool": "pickaxe", "tier": 4},
	{"name": "Amethyst Ore", "tiles": [T_AMETHYST_ORE, T_AMETHYST_ORE, T_AMETHYST_ORE], "hardness": 6.0, "drop": "amethyst", "tool": "pickaxe", "tier": 3},
	{"name": "Stalactite", "tiles": [T_DEEPSTONE, T_DEEPSTONE, T_DEEPSTONE], "hardness": 1.5, "drop": "deepstone", "tool": "pickaxe", "tier": 1, "shape": "column"},
	{"name": "Glow Crystal", "tiles": [T_GLOW_CRYSTAL, T_GLOW_CRYSTAL, T_GLOW_CRYSTAL], "transparent": true, "atten": 0, "emit": 11,
			"hardness": 0.4, "drop": "glow_crystal", "model": "cross", "collide": 0.0},
	{"name": "Lava", "tiles": [T_LAVA, T_LAVA, T_LAVA], "transparent": true, "atten": 15, "emit": 15, "hardness": -1, "collide": 0.0},
	{"name": "Lava", "tiles": [T_LAVA, T_LAVA, T_LAVA], "transparent": true, "atten": 15, "emit": 15, "hardness": -1, "collide": 0.0},
	{"name": "Lava", "tiles": [T_LAVA, T_LAVA, T_LAVA], "transparent": true, "atten": 15, "emit": 15, "hardness": -1, "collide": 0.0},
	{"name": "Lava", "tiles": [T_LAVA, T_LAVA, T_LAVA], "transparent": true, "atten": 15, "emit": 15, "hardness": -1, "collide": 0.0},
	{"name": "Lava", "tiles": [T_LAVA, T_LAVA, T_LAVA], "transparent": true, "atten": 15, "emit": 15, "hardness": -1, "collide": 0.0},
	{"name": "Cinderstone", "tiles": [T_CINDERSTONE, T_CINDERSTONE, T_CINDERSTONE], "hardness": 12.0, "drop": "cinderstone", "tool": "pickaxe", "tier": 3},
	{"name": "Jewelry Station", "tiles": [T_JEWEL_TOP, T_JEWEL_SIDE, T_PLANKS], "hardness": 2.5, "drop": "jewelry_station", "tool": "axe", "wood": true},
	{"name": "Magma Rock", "tiles": [T_MAGMA, T_MAGMA, T_MAGMA], "hardness": 4.0, "drop": "magma_rock", "tool": "pickaxe", "tier": 2, "emit": 3},
]


## Ground plants (block ids TALL_GRASS..EDELWEISS, in order), added to DEFS at
## startup: see-through, no collision, break instantly, drawn as two crossed
## pictures. [name, tile, drop, grassy]. Grassy plants get replaced when you
## build on them (like tall grass in Minecraft); flowers have to be picked first.
const PLANTS := [
	["Tall Grass", T_TALL_GRASS, "grass_tuft", true],
	["Fern", T_FERN, "grass_tuft", true],
	["Poppy", T_POPPY, "poppy", false],
	["Dandelion", T_DANDELION, "dandelion", false],
	["Cornflower", T_CORNFLOWER, "cornflower", false],
	["Daisy", T_DAISY, "daisy", false],
	["Bluebell", T_BLUEBELL, "bluebell", false],
	["Toadstool", T_TOADSTOOL, "toadstool", false],
	["Dry Shrub", T_DRY_SHRUB, "stick", true],
	["Cactus Flower", T_CACTUS_FLOWER, "cactus_flower", false],
	["Lollipop", T_LOLLIPOP, "lollipop", false],
	["Candy Tulip", T_CANDY_TULIP, "candy_tulip", false],
	["Frosty Grass", T_FROST_GRASS, "grass_tuft", true],
	["Edelweiss", T_EDELWEISS, "edelweiss", false],
]

## Saplings (OAK_SAPLING.. in order): [kind, name, ground it grows on]. The
## kind says what tree it grows into (see world.gd grow_tree).
const SAPLINGS := [
	["oak", "Oak Sapling", "dirt"],
	["redwood", "Redwood Sapling", "dirt"],
	["pine", "Pine Sapling", "snowy"],
	["palm", "Palm Sapling", "sand"],
	["maple", "Maple Sapling", "dirt"],
	["golden", "Golden Maple Sapling", "dirt"],
	["candy", "Candy Sapling", "candy"],
]
## Tree leaves (they fall when their tree's wood is all chopped, and drop saplings).
const LEAF_BLOCKS := [LEAVES, PINE_LEAVES, PALM_LEAVES, MAPLE_LEAVES, GOLDEN_LEAVES, COTTON_CANDY]


static func is_sapling(b: int) -> bool:
	return b >= OAK_SAPLING and b <= CANDY_SAPLING


static func is_leaves(b: int) -> bool:
	return b in LEAF_BLOCKS


static func is_log(b: int) -> bool:
	for fam in LOG_FAMILY.values():
		if b in fam:
			return true
	return false


## Can this sapling be planted on that block?
static func sapling_ground_ok(sapling: int, below: int) -> bool:
	var dirt := below in [GRASS, DIRT]
	match SAPLINGS[sapling - OAK_SAPLING][2]:
		"sand":
			return dirt or below in [SAND]
		"snowy":
			return dirt or below in [SNOW]
		"candy":
			return dirt or below in [FROSTING, CAKE]
	return dirt


## Closed door -> open door and back.
const DOOR_TOGGLE := {
	DOOR_WOOD: DOOR_WOOD_OPEN, DOOR_WOOD_OPEN: DOOR_WOOD,
	DOOR_IRON: DOOR_IRON_OPEN, DOOR_IRON_OPEN: DOOR_IRON,
	DOOR_TITANIUM: DOOR_TITANIUM_OPEN, DOOR_TITANIUM_OPEN: DOOR_TITANIUM,
}

## Blocks you can right-click to open a menu.
const WORKBENCH_TIER := {WORKBENCH_1: 1, WORKBENCH_2: 2, WORKBENCH_3: 3}
## The building benches: block -> what it's called in recipes.
const BUILD_BENCH := {SAWMILL: "sawmill", STONECUTTER: "stonecutter", SHAPER: "shaper", JEWELRY_STATION: "jewelry"}

# Fast lookup arrays (index = block id), filled in from DEFS at startup.
static var NAMES: Array[String] = []
static var TRANSPARENT: Array[int] = []        # 1 = you can see through it
static var LIGHT_ATTENUATION: Array[int] = []
static var LIGHT_EMISSION: Array[int] = []
static var FACE_TILES: Array = []
static var HARDNESS: Array[float] = []
static var TOOL: Array[String] = []
static var MIN_TIER: Array[int] = []
static var DROP: Array[String] = []
static var MODEL: Array[String] = []           # "" = normal cube
static var COLLIDE: Array[float] = []          # collision height (1 = full block)
static var ICON: Array[int] = []
static var IS_WATER: Array[bool] = []
static var IS_LAVA: Array[bool] = []
static var IS_PLANT: Array[bool] = []
static var FACE6: Array = []                   # per block: tile for each of the 6 faces (+X,-X,+Y,-Y,+Z,-Z)
static var UV_TURN: Array = []                 # per block: 6 bools, turn that face's picture 90 degrees
static var IS_WOOD: Array[bool] = []           # logs, planks and wooden things (sounds like wood)
static var SHAPE: Array[String] = []           # "" = a full cube, else a key of SHAPES
static var REPLACE: Array[bool] = []           # building on it just replaces it

static var _atlas: ImageTexture
static var _atlas_detail := true      # (any detailed level)
static var _atlas_level := 1          # 0 Simple, 1 Detailed, 2 Ultra HD
static var _want_level := 1
static var _atlas_cache := {}         # level -> finished atlas Image
static var _job := -1                 # Ultra HD textures paint in the background
static var _job_level := -1
static var _job_out: Array = [null]
static var _materials: ImageTexture
static var _kinds := {}               # tile -> what it's made of ("stone", "planks"...)


static func _static_init() -> void:
	var all: Array = DEFS.duplicate()
	for p in PLANTS:
		all.append({"name": p[0], "tiles": [p[1], p[1], p[1]], "transparent": true, "atten": 0,
				"hardness": 0.0, "drop": p[2], "model": "cross", "collide": 0.0, "replace": p[3]})
	for wd in WOOD_DEFS:
		var e := {"name": wd[0], "tiles": [wd[1], wd[2], wd[1]], "hardness": 2.0, "drop": wd[3], "tool": "axe", "axis": wd[4], "wood": true}
		for k in wd[5]:
			e[k] = wd[5][k]
		if wd[3] == "":
			e.erase("wood")
		all.append(e)
	for bd in BUILD_DEFS + FALL_DEFS + SPOOKY_DEFS:
		var e: Dictionary = bd.duplicate()
		if e.has("shape"):
			e["model"] = "shape"
			e["transparent"] = true
			e["atten"] = 1
			e["collide"] = 0.5 if e["shape"] == "slab" else (0.85 if e["shape"] == "grave" else 1.0)
		all.append(e)
	for d in all:
		_add_def(d)
	assert(all.size() == FENCE_START, "fences must start right after the other blocks")
	for fam in FAMILIES:
		var t: int = fam[2]
		var fence := {"name": fam[1] + (" Fence" if fam[6] else " Wall"), "tiles": [t, t, t], "drop": fam[0] + ("_fence" if fam[6] else "_wall"),
				"shape": "fence" if fam[6] else "wall", "tool": fam[3], "tier": fam[4], "hardness": fam[5], "wood": fam[6]}
		var wedge := {"name": fam[1] + " Wedge", "tiles": [t, t, t], "drop": fam[0] + "_wedge", "shape": "wedge",
				"tool": fam[3], "tier": fam[4], "hardness": fam[5], "wood": fam[6]}
		for e in [fence, wedge]:
			e["model"] = "shape"
			e["transparent"] = true
			e["atten"] = 1
			e["collide"] = 1.0
			if not e["wood"]:
				e.erase("wood")
			_add_def(e)
	_add_def({"name": "Boss Statue", "tiles": [T_STONE_BRICKS, T_STONE_BRICKS, T_STONE_BRICKS], "hardness": -1.0, "drop": "",
			"model": "statue", "transparent": true, "atten": 0, "collide": 1.0})
	_add_def({"name": "Research Table", "tiles": [T_RESEARCH_TOP, T_RESEARCH_SIDE, T_PLANKS], "hardness": 2.5, "drop": "research_table", "tool": "axe", "wood": true})
	_add_def({"name": "Super Chest", "tiles": [T_SUPER_CHEST_TOP, T_SUPER_CHEST_SIDE, T_SUPER_CHEST_TOP], "hardness": 3.0, "drop": "super_chest", "tool": "axe", "emit": 5})
	_add_def({"name": "Campfire", "tiles": [T_CAMPFIRE, T_CAMPFIRE, T_CAMPFIRE], "icon": T_CAMPFIRE, "transparent": true, "atten": 0, "emit": 13, "hardness": 1.0, "drop": "campfire", "tool": "axe", "model": "campfire", "collide": 0.35})
	_add_def({"name": "Bedroll", "tiles": [T_BEDROLL, T_BEDROLL, T_BEDROLL], "icon": T_BEDROLL, "transparent": true, "atten": 0, "hardness": 0.5, "drop": "bedroll", "model": "bedroll", "collide": 0.0})
	for i in SAPLINGS.size():
		var t: int = T_SAPLING_OAK + i
		_add_def({"name": SAPLINGS[i][1], "tiles": [t, t, t], "transparent": true, "atten": 0, "hardness": 0.0,
				"drop": SAPLINGS[i][0] + "_sapling", "model": "cross", "collide": 0.0})
	_add_def({"name": "Castle in a Box", "tiles": [T_CASTLE_BOX, T_CASTLE_BOX, T_CASTLE_BOX], "hardness": 0.5, "drop": "castle_box", "emit": 6})
	for cd in CHESS_DEFS:
		var e: Dictionary = cd.duplicate()
		if e.has("shape"):
			e["model"] = "shape"
			e["transparent"] = true
			e["atten"] = 1
			e["collide"] = 0.5 if e["shape"] == "slab" else 1.0
		_add_def(e)
	assert(NAMES.size() == COUNT, "DEFS + PLANTS and COUNT don't match")
	FLUID_LEVEL.clear()
	FLUID_KIND.clear()
	for b in COUNT:
		FLUID_LEVEL.append(-1)
		FLUID_KIND.append("")
	for kind in FLUIDS:
		var fd: Dictionary = FLUIDS[kind]
		FLUID_LEVEL[fd["source"]] = 0
		FLUID_KIND[fd["source"]] = kind
		FLUID_LEVEL[fd["fall"]] = FALLING
		FLUID_KIND[fd["fall"]] = kind
		for k in fd["flows"].size():
			FLUID_LEVEL[fd["flows"][k]] = k + 1
			FLUID_KIND[fd["flows"][k]] = kind


## Adds one block's entry to every table (names, tiles, light, faces...).
static func _add_def(d: Dictionary) -> void:
	var transparent: bool = d.get("transparent", false)
	NAMES.append(d["name"])
	TRANSPARENT.append(1 if transparent else 0)
	LIGHT_ATTENUATION.append(d.get("atten", 0 if transparent else 15))
	LIGHT_EMISSION.append(d.get("emit", 0))
	FACE_TILES.append(d["tiles"])
	HARDNESS.append(d.get("hardness", 1.0))
	TOOL.append(d.get("tool", ""))
	MIN_TIER.append(d.get("tier", 0))
	DROP.append(d.get("drop", ""))
	MODEL.append(d.get("model", ""))
	COLLIDE.append(d.get("collide", 0.0 if d["name"] in ["Air", "Water"] else 1.0))
	ICON.append(d.get("icon", d["tiles"][1]))
	IS_WATER.append(d["name"] == "Water")
	IS_LAVA.append(d["name"] == "Lava")
	IS_PLANT.append(d.get("model", "") == "cross")
	SHAPE.append(d.get("shape", ""))
	IS_WOOD.append(d.get("wood", false) or d["name"] in ["Log", "Planks", "Candy Cane"] and not d.has("shape"))
	# Which picture goes on each face. Logs lying down show their rings on
	# the ends and their bark (turned to run along the log) everywhere else.
	var t: Array = d["tiles"]
	var axis: String = d.get("axis", "y" if d["name"] in ["Log", "Candy Cane"] else "")
	var faces := [t[1], t[1], t[0], t[2], t[1], t[1]]
	var turn := [false, false, false, false, false, false]
	if axis == "x":
		faces = [t[0], t[0], t[1], t[1], t[1], t[1]]
		turn = [false, false, true, true, true, true]
	elif axis == "z":
		faces = [t[1], t[1], t[1], t[1], t[0], t[0]]
		turn = [true, true, false, false, false, false]
	FACE6.append(faces)
	UV_TURN.append(turn)
	REPLACE.append(d.get("replace", false))


## Solid = you bump into it (open doors and torches aren't solid).
static func is_solid(block: int) -> bool:
	return COLLIDE[block] > 0.0


## Still or flowing water.
static func is_water(block: int) -> bool:
	return IS_WATER[block]


## 0 = still water (a lake or sea), 1-7 = flowing, 8 = falling, -1 = not water.
static func water_level(block: int) -> int:
	return FLUID_LEVEL[block] if FLUID_KIND[block] == "water" else -1


static func flow_block(level: int) -> int:
	return fluid_flow("water", level)


static func fluid_level(block: int) -> int:
	return FLUID_LEVEL[block]


static func fluid_kind(block: int) -> String:
	return FLUID_KIND[block]


static func is_fluid(block: int) -> bool:
	return FLUID_LEVEL[block] >= 0


## A fluid's flowing block `level` steps from its source.
static func fluid_flow(kind: String, level: int) -> int:
	var flows: Array = FLUIDS[kind]["flows"]
	return flows[clampi(level, 1, flows.size()) - 1]


## How high the top of a fluid block is (0..1): a source is just under full,
## each flowing step a little lower, falling water is full.
static func fluid_height(block: int) -> float:
	var lv := FLUID_LEVEL[block]
	if lv < 0:
		return 0.0
	if lv == FALLING:
		return 1.0
	var reach: int = FLUIDS[FLUID_KIND[block]]["reach"]
	return (8.0 - float(lv) * 7.0 / float(reach)) / 9.0


## Can the crosshair hit it? (anything except air, water and lava)
static func is_targetable(block: int) -> bool:
	return block != AIR and FLUID_LEVEL[block] < 0


static func is_lava(block: int) -> bool:
	return FLUID_KIND[block] == "lava"


## Can a block be placed here? (Air, water, or grass that just gets squashed.)
static func is_replaceable(block: int) -> bool:
	return block == AIR or FLUID_LEVEL[block] >= 0 or REPLACE[block]


## A little ground plant (flower, grass tuft, mushroom...).
static func is_plant(block: int) -> bool:
	return IS_PLANT[block]


## Nothing in the way: air or a plant you can walk through.
## (Use this instead of `== AIR` when asking "is there room here?")
static func is_open(block: int) -> bool:
	return block == AIR or IS_PLANT[block]


## Can this plant grow on top of that block?
static func plant_can_sit_on(below: int) -> bool:
	return is_solid(below) and MODEL[below] == "" and not IS_WATER[below]


static func is_door(block: int) -> bool:
	return DOOR_TOGGLE.has(block)


static func is_open_door(block: int) -> bool:
	return is_door(block) and COLLIDE[block] == 0.0


## Same kind of door, open or closed?
static func same_door(a: int, b: int) -> bool:
	return is_door(a) and is_door(b) and (a == b or DOOR_TOGGLE[a] == b)


static func is_interactive(block: int) -> bool:
	return WORKBENCH_TIER.has(block) or BUILD_BENCH.has(block) or block in [FURNACE, SHOP, CHEST, SUPER_CHEST, CASTLE_BOX, ARENA_BOX, ARENA_BUTTON, CAMPFIRE, BEDROLL, BED, BED_FOOT, CUTE_CRAFTER, PORTAL, PORTAL_LIT, SCRIBE, ITEM_FRAME, ARMOR_STAND, SHRINE_CHEST, BOSS_STATUE, RESEARCH_TABLE] or is_door(block)


static func get_atlas() -> ImageTexture:
	if _atlas == null:
		var lv := mini(_want_level, 1)   # Ultra HD arrives a moment later (see poll_texture_job)
		_tile_kinds()
		_atlas_cache[lv] = _with_mips(_build_atlas_image(lv))
		_atlas = ImageTexture.create_from_image(_atlas_cache[lv])
		_atlas_level = lv
		TILE_PX = LEVEL_PX[lv]
		_atlas_detail = lv > 0
	return _atlas


## Low detail paints each tile at 16x16; higher settings paint 32x32 with
## finer grain. The atlas is the same size either way, so nothing else changes.
## level: 0 Simple (16x16 pictures), 1 Detailed (32), 2 Ultra HD (64, with
## hand-made extra detail: grass blades, cracks in stone, wood grain...).
## Ultra HD takes a few seconds to paint, so it's done in the background
## (the game keeps going with Detailed until it's ready).
static func set_texture_detail(level) -> void:
	_want_level = clampi(int(level), 0, 2)
	if _atlas == null:
		get_atlas()
	_tile_kinds()
	if _want_level == _atlas_level:
		return
	if _atlas_cache.has(_want_level):
		_use_level(_want_level)
	elif _want_level < 2:
		_atlas_cache[_want_level] = _with_mips(_build_atlas_image(_want_level))
		_use_level(_want_level)
	elif _job < 0:
		_job_level = _want_level
		_job_out = [null]
		var out := _job_out
		var lv := _job_level
		_job = WorkerThreadPool.add_task(func() -> void: out[0] = _with_mips(_build_atlas_image(lv)))


## Call every frame: true when the Ultra HD textures just arrived (redo icons).
static func poll_texture_job() -> bool:
	if _job < 0 or not WorkerThreadPool.is_task_completed(_job):
		return false
	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	_atlas_cache[_job_level] = _job_out[0]
	if _want_level == _job_level and _atlas_level != _job_level:
		_use_level(_job_level)
		return true
	return false


## Waits for a background paint (when quitting).
static func finish_texture_job() -> void:
	if _job >= 0:
		WorkerThreadPool.wait_for_task_completion(_job)
		_job = -1


static func _use_level(lv: int) -> void:
	_atlas_level = lv
	_atlas_detail = lv > 0
	TILE_PX = LEVEL_PX[lv]
	_atlas.set_image(_atlas_cache[lv])


static func texture_level() -> int:
	return _atlas_level


## A little young tree: a thin stem and a few leaves in its tree's colors.
static func _sapling_pixel(t: int, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var leaf: Color = [Color(0.25, 0.55, 0.18), Color(0.2, 0.42, 0.16), Color(0.15, 0.38, 0.22), Color(0.4, 0.62, 0.2),
			Color(0.85, 0.32, 0.12), Color(0.95, 0.72, 0.2), Color(1.0, 0.68, 0.85)][t - T_SAPLING_OAK]
	var stem := Color(0.42, 0.28, 0.14)
	if t == T_SAPLING_CANDY:
		stem = Color(0.95, 0.95, 0.95) if (y % 3 == 0) else Color(0.9, 0.2, 0.25)
	elif t == T_SAPLING_PALM:
		stem = Color(0.6, 0.45, 0.26)
	var fx := float(x) - 7.5
	if (x == 7 or x == 8) and y >= 7:
		return _shade(rng, stem, 0.08)
	var on := false
	match t:
		T_SAPLING_PINE:
			on = y >= 1 and y <= 11 and absf(fx) < float(y - 1) * 0.42 + 0.6 and y % 4 != 0
		T_SAPLING_PALM:
			# Fronds arching out from the top.
			var top := 4.0 + absf(fx) * absf(fx) * 0.09
			on = absf(float(y) - top) < 1.1 and absf(fx) < 7.0
		_:
			var blobs := [Vector2(7.5, 4.5), Vector2(4.5, 7.0), Vector2(10.5, 6.5), Vector2(7.5, 8.0)]
			for bp in blobs:
				if Vector2(x, y).distance_to(bp) < 2.6:
					on = true
	if not on:
		return Color(0, 0, 0, 0)
	if rng.randf() < 0.12:
		return Color(0, 0, 0, 0)
	return _shade(rng, leaf, 0.15)


## Smaller copies of the atlas for far-away blocks, so distant leaves and
## grass don't sparkle. (Tiles line up with each halving, so they never blur
## into their neighbors until they're tiny.)
static func _with_mips(img: Image) -> Image:
	img.generate_mipmaps()
	return img


## Pixel rectangle of a tile inside the atlas (used for UI icons).
static func tile_region(tile: int) -> Rect2:
	return Rect2(tile * TILE_PX, 0, TILE_PX, TILE_PX)


static func icon_tile(block: int) -> int:
	return ICON[block]


## level 0/1/2 (or false/true for Simple/Detailed). Safe to run on a thread.
static func _build_atlas_image(level) -> Image:
	var lv := clampi(int(level), 0, 2)
	var px: int = LEVEL_PX[lv]
	var res: int = LEVEL_RES[lv]
	var img := Image.create_empty(px * TILE_COUNT, px, false, Image.FORMAT_RGBA8)
	for t in TILE_COUNT:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234 + t * 7919
		var tile := Image.create_empty(res, res, false, Image.FORMAT_RGBA8)
		_paint_tile(tile, t, rng, res)
		if lv == 2:
			_hd_pass(tile, t, rng)
		if res != px:
			tile.resize(px, px, Image.INTERPOLATE_NEAREST)
		img.blit_rect(tile, Rect2i(0, 0, px, px), Vector2i(t * px, 0))
	return img


# --- What each picture is made of ---------------------------------------------------------
# Used by the Ultra HD painter (what extra detail to add) and by the terrain
# shader's surface detail (how bumpy, rough or shiny each block is).

## tile -> kind, worked out from the tile names (T_COBBLE -> "stone"...).
static func _tile_kinds() -> Dictionary:
	if not _kinds.is_empty():
		return _kinds
	var plant_tiles := {}
	for b in COUNT:
		if IS_PLANT[b]:
			plant_tiles[FACE_TILES[b][1]] = true
	var consts: Dictionary = (load("res://scripts/blocks.gd") as GDScript).get_script_constant_map()
	var kinds := {}
	for n in consts:
		var name: String = n
		if not name.begins_with("T_") or not consts[n] is int or name == "T_COUNT":
			continue
		var t: int = consts[n]
		if t < 0 or t >= TILE_COUNT or kinds.has(t):
			continue
		var k := "other"
		if plant_tiles.has(t) or name.contains("SAPLING") or name in ["T_TORCH", "T_CAMPFIRE", "T_BED_ICON", "T_STAND_ICON"]:
			k = "plant"
		elif name in ["T_GLASS", "T_WATER", "T_PORTAL", "T_PORTAL_LIT", "T_LAMP", "T_BEDROCK", "T_LAVA", "T_MAGMA"] or name.contains("ICON"):
			k = "flat"
		elif name.ends_with("_ORE"):
			k = "ore"
		elif name in ["T_GRASS_TOP", "T_FROST_GRASS_TOP"]:
			k = "grass_top"
		elif name == "T_GRASS_SIDE":
			k = "grass_side"
		elif name.contains("LEAVES") or name in ["T_COTTON_CANDY"]:
			k = "leaves"
		elif name in ["T_DIRT"]:
			k = "dirt"
		elif name in ["T_SAND"]:
			k = "sand"
		elif name.contains("SNOW") and not name.contains("STONE"):
			k = "snow"
		elif name.contains("BLOCK") and (name.contains("GOLD") or name.contains("SILVER") or name.contains("TITANIUM") or name.contains("IRON") or name.contains("COPPER")) or name.contains("INLAY"):
			k = "metal"
		elif name.contains("PLANKS") or name.contains("CARVED") or name.contains("CHEST") or name.contains("BENCH") or name.contains("DOOR"):
			k = "planks"
		elif name == "T_LOG_TOP" or (name.ends_with("_TOP") and WOOD_TILES.has(t)):
			k = "log_top"
		elif name == "T_LOG_SIDE" or (name.ends_with("_SIDE") and WOOD_TILES.has(t)):
			k = "bark"
		elif name.contains("STONE") or name.contains("COBBLE") or name.contains("BRICK") or name.contains("SANDSTONE") or name.contains("FURNACE") or name.contains("PILLAR") or name.contains("CHISELED") \
				or name.contains("MARBLE") or name.contains("ONYX") or name.contains("CHECKER"):
			k = "stone"
		kinds[t] = k
	_kinds = kinds
	return _kinds


static func tile_kind(t: int) -> String:
	return _tile_kinds().get(t, "other")


## A tiny picture (one pixel per tile, two rows) that tells the terrain shader
## about each block's surface. Row 0: bumpiness, roughness, metal, glints.
## Row 1: how much it varies in color across the world.
static func get_material_texture() -> ImageTexture:
	if _materials != null:
		return _materials
	var img := Image.create_empty(TILE_COUNT, 2, false, Image.FORMAT_RGBA8)
	var table := {
		# bump, roughness, metallic, glint, variation
		"stone": [0.8, 0.86, 0.0, 0.0, 0.35], "ore": [0.8, 0.82, 0.0, 1.0, 0.3], "grass_top": [0.55, 0.9, 0.0, 0.0, 1.0],
		"grass_side": [0.6, 0.9, 0.0, 0.0, 0.8], "dirt": [0.7, 0.95, 0.0, 0.0, 0.8], "sand": [0.35, 0.92, 0.0, 0.0, 0.7],
		"snow": [0.3, 0.55, 0.0, 0.3, 0.3], "leaves": [0.5, 0.65, 0.0, 0.0, 1.0], "bark": [0.85, 0.9, 0.0, 0.0, 0.5],
		"log_top": [0.6, 0.85, 0.0, 0.0, 0.3], "planks": [0.55, 0.78, 0.0, 0.0, 0.25], "metal": [0.35, 0.32, 0.9, 0.0, 0.1],
		"flat": [0.0, 0.3, 0.0, 0.0, 0.0], "plant": [0.0, 0.8, 0.0, 0.0, 0.7], "other": [0.5, 0.85, 0.0, 0.0, 0.3],
	}
	for t in TILE_COUNT:
		var m: Array = table[tile_kind(t)]
		img.set_pixel(t, 0, Color(m[0], m[1], m[2], m[3]))
		img.set_pixel(t, 1, Color(m[4], 0, 0, 1))
	_materials = ImageTexture.create_from_image(img)
	return _materials


# --- Ultra HD: extra detail painted on top of each 64x64 picture ---------------------------

static func _hd_pass(img: Image, t: int, rng: RandomNumberGenerator) -> void:
	var kind: String = _kinds.get(t, "other")
	if kind == "flat" or kind == "plant":
		return
	var n := img.get_width()
	match kind:
		"grass_top":
			# Little blades of grass, some catching the light.
			for k in 340:
				var x := rng.randi() % n
				var y := rng.randi() % n
				var lean := rng.randi_range(-1, 1)
				var light := rng.randf() < 0.55
				for j in rng.randi_range(2, 4):
					var px := posmod(x + (lean if j > 1 else 0), n)
					var py := posmod(y - j, n)
					var c := img.get_pixel(px, py)
					img.set_pixel(px, py, c.lightened(0.24) if light else c.darkened(0.26))
			for k in 3:
				_hd_dot(img, rng.randi() % n, rng.randi() % n, Color(1.0, 0.95, 0.6) if k == 0 else Color(0.95, 0.95, 1.0), 1)
		"grass_side":
			# Blades hanging over the edge of the dirt.
			for x in n:
				var edge := -1
				for y in n:
					var c := img.get_pixel(x, y)
					if c.g > c.r * 1.15:
						edge = y
				if edge >= 0 and rng.randf() < 0.45:
					for j in rng.randi_range(1, 3):
						if edge + j < n:
							img.set_pixel(x, edge + j, img.get_pixel(x, edge).darkened(0.1 * j))
			_hd_pebbles(img, rng, 5, n / 2, n)
		"dirt":
			_hd_pebbles(img, rng, 9, 0, n)
			for k in 3:
				_hd_walk(img, rng, rng.randi() % n, rng.randi() % n, 10, Color(0.32, 0.22, 0.14))   # roots
		"sand":
			for k in 420:
				var x := rng.randi() % n
				var y := rng.randi() % n
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, c.lightened(0.12) if rng.randf() < 0.6 else c.darkened(0.12))
			for k in 4:
				_hd_dot(img, rng.randi() % n, rng.randi() % n, Color(0.95, 0.88, 0.8), 1)   # tiny shells
		"stone", "ore":
			for k in 4:
				_hd_walk(img, rng, rng.randi() % n, rng.randi() % n, rng.randi_range(8, 18), Color(0, 0, 0, -0.22))   # hairline cracks
			for k in 60:
				var x := rng.randi() % n
				var y := rng.randi() % n
				img.set_pixel(x, y, img.get_pixel(x, y).lightened(0.14))   # little mineral flecks
			if kind == "ore":
				# A glint on the top-left of each ore speck.
				for y in n:
					for x in n:
						var c := img.get_pixel(x, y)
						var up := img.get_pixel(posmod(x - 1, n), posmod(y - 1, n))
						if _sat(c) > 0.18 and _sat(up) < 0.12:
							img.set_pixel(x, y, c.lightened(0.45))
		"planks":
			# Wood grain running along the boards, and the odd knot.
			var seed := rng.randf() * 10.0
			for y in n:
				for x in n:
					var g := sin(float(x) * 0.22 + sin(float(y) * 0.9 + seed) * 2.5 + float(y) * 1.3)
					if g > 0.78:
						img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.16))
					elif g < -0.9:
						img.set_pixel(x, y, img.get_pixel(x, y).lightened(0.07))
			for k in 2:
				var cx := rng.randi() % n
				var cy := rng.randi() % n
				for r in [3, 2, 1]:
					_hd_ring(img, cx, cy, r, 0.12 + 0.05 * (3 - r))
		"bark":
			# Deep grooves in the bark, lit on one side.
			for k in 7:
				var x := rng.randi() % n
				var y := rng.randi() % n
				for j in rng.randi_range(8, 22):
					var py := posmod(y + j, n)
					var px := posmod(x + (1 if sin(j * 0.5 + k) > 0.6 else 0), n)
					img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.25))
					img.set_pixel(posmod(px + 1, n), py, img.get_pixel(posmod(px + 1, n), py).lightened(0.08))
		"log_top":
			for k in 2:
				var a := rng.randf() * TAU
				for r in range(4, n / 2 - 2):
					var px := posmod(n / 2 + int(cos(a) * r), n)
					var py := posmod(n / 2 + int(sin(a) * r), n)
					img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.3))   # a crack from the middle
		"leaves":
			for k in 90:
				var x := rng.randi() % n
				var y := rng.randi() % n
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					img.set_pixel(x, y, c.lightened(0.2))   # leaves catching the sun
		"snow":
			for k in 40:
				_hd_dot(img, rng.randi() % n, rng.randi() % n, Color(1, 1, 1), 0)   # sparkles
		"metal":
			for y in n:
				var k := 1.0 + sin(float(y) * 2.1 + rng.randf()) * 0.03
				for x in n:
					var c := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))   # brushed
	# Soft patches of lighter and darker (tiles seamlessly), so natural blocks
	# aren't flat noise: clumps of grass, damp dirt, streaky stone.
	var mottle: float = {"stone": 0.1, "ore": 0.08, "grass_top": 0.14, "grass_side": 0.06, "dirt": 0.14, "sand": 0.07,
			"leaves": 0.12, "bark": 0.08, "snow": 0.04}.get(kind, 0.0)
	if mottle > 0.0:
		var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
		var w := TAU / n
		for y in n:
			for x in n:
				var c := img.get_pixel(x, y)
				if c.a < 0.5:
					continue
				var m := sin(x * w * 2.0 + ph[0]) * sin(y * w * 3.0 + ph[1]) * 0.5 + sin(x * w * 5.0 + y * w * 3.0 + ph[2]) * 0.3 \
						+ sin(x * w * 7.0 - y * w * 6.0 + ph[3]) * 0.2
				var k := 1.0 + m * mottle
				if kind == "grass_top" or kind == "leaves":
					img.set_pixel(x, y, Color(c.r * (k + m * 0.05), c.g * k, c.b * (k - m * 0.04), c.a))   # yellower / bluer greens
				else:
					img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))
	# Light from the top left: raised bits get a highlight, dips a shadow, so
	# every block looks carved instead of printed.
	var amount: float = {"stone": 1.9, "ore": 1.8, "bark": 1.6, "planks": 1.2, "log_top": 1.0, "leaves": 1.5,
			"grass_top": 1.0, "grass_side": 1.0, "dirt": 1.2, "sand": 0.7, "snow": 0.5, "metal": 0.8, "other": 1.1}[kind]
	var lum := PackedFloat32Array()
	lum.resize(n * n)
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			lum[x + y * n] = c.get_luminance() if c.a > 0.5 else 0.0
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var tl := lum[posmod(x - 1, n) + posmod(y - 1, n) * n]
			var br := lum[posmod(x + 1, n) + posmod(y + 1, n) * n]
			var avg := (lum[posmod(x - 1, n) + y * n] + lum[posmod(x + 1, n) + y * n] + lum[x + posmod(y - 1, n) * n] + lum[x + posmod(y + 1, n) * n]) * 0.25
			var k := 1.0 + ((tl - br) * 1.6 + (lum[x + y * n] - avg) * 1.2) * amount
			img.set_pixel(x, y, Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a))


static func _sat(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))


static func _hd_dot(img: Image, x: int, y: int, c: Color, r: int) -> void:
	var n := img.get_width()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if absi(dx) + absi(dy) <= r:
				img.set_pixel(posmod(x + dx, n), posmod(y + dy, n), c)


## Small round stones, lit from the top left.
static func _hd_pebbles(img: Image, rng: RandomNumberGenerator, count: int, y_from: int, y_to: int) -> void:
	var n := img.get_width()
	for k in count:
		var cx := rng.randi() % n
		var cy := rng.randi_range(y_from, y_to - 1)
		var base := Color(0.5, 0.47, 0.44).lerp(Color(0.62, 0.5, 0.38), rng.randf())
		var r := rng.randf_range(1.2, 2.4)
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var d := Vector2(dx, dy).length()
				if d <= r:
					var c := base.lightened(0.25) if (dx + dy) < -1 else (base.darkened(0.25) if dx + dy > 1 else base)
					img.set_pixel(posmod(cx + dx, n), posmod(cy + dy, n), c)


## A wandering line (cracks, roots). A color with negative alpha darkens instead.
static func _hd_walk(img: Image, rng: RandomNumberGenerator, x: int, y: int, length: int, c: Color) -> void:
	var n := img.get_width()
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var p := Vector2(x, y)
	for j in length:
		var px := posmod(int(p.x), n)
		var py := posmod(int(p.y), n)
		if c.a < 0.0:
			img.set_pixel(px, py, img.get_pixel(px, py).darkened(-c.a))
		else:
			img.set_pixel(px, py, c)
		dir = dir.rotated(rng.randf_range(-0.6, 0.6))
		p += dir


static func _hd_ring(img: Image, cx: int, cy: int, r: int, dark: float) -> void:
	var n := img.get_width()
	for a in 24:
		var ang := TAU * a / 24.0
		var px := posmod(cx + int(round(cos(ang) * r * 1.4)), n)
		var py := posmod(cy + int(round(sin(ang) * r)), n)
		img.set_pixel(px, py, img.get_pixel(px, py).darkened(dark))


static func _shade(rng: RandomNumberGenerator, c: Color, amount: float) -> Color:
	var k := 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## Paints one tile into `img` (res x res pixels). Shapes are worked out on the
## 16x16 design grid (x, y); at 32 pixels each cell gets 4 pixels of its own
## noise, so surfaces look finer without changing their shapes.
static func _paint_tile(img: Image, t: int, rng: RandomNumberGenerator, res: int) -> void:
	var green := Color(0.37, 0.62, 0.24)
	var dirt := Color(0.53, 0.38, 0.26)
	var bark := Color(0.40, 0.30, 0.18)
	var plank := Color(0.70, 0.55, 0.33)
	var s := BASE_PX
	var scale := float(BASE_PX) / res

	# Cobblestone and the furnace use a few random "stone" centers.
	var cells: Array[Vector2] = []
	var cell_shades: Array[float] = []
	if t == T_COBBLE or t == T_FURNACE_SIDE or t == T_FURNACE_TOP or t == T_STONECUTTER_SIDE:
		for i in 9:
			cells.append(Vector2(rng.randf() * s, rng.randf() * s))
			cell_shades.append(rng.randf_range(0.42, 0.62))
	# Ores: a few small blobs of colored specks on stone.
	var specks := {}
	if ORE_COLORS.has(t):
		for i in 5:
			var cx := rng.randf_range(2.0, 14.0)
			var cy := rng.randf_range(2.0, 14.0)
			for py in s:
				for px in s:
					if Vector2(px, py).distance_to(Vector2(cx, cy)) < rng.randf_range(0.8, 1.8):
						specks[Vector2i(px, py)] = true

	# Grass side: green "drips" of random length per column.
	var drips: Array[int] = []
	for i in s:
		drips.append(3 + rng.randi() % 3)
	for px in res:
		var x := int(px * scale)
		var drip := drips[x]
		for py in res:
			var y := int(py * scale)
			var fx := (px + 0.5) * scale - 0.5
			var fy := (py + 0.5) * scale - 0.5
			var c: Color
			var edge := x == 0 or y == 0 or x == s - 1 or y == s - 1
			match t:
				T_GRASS_TOP:
					c = _shade(rng, green, 0.12)
				T_DIRT:
					c = _shade(rng, dirt, 0.12)
					if rng.randf() < 0.1:
						c = c.darkened(0.25)
				T_GRASS_SIDE:
					c = _shade(rng, green, 0.12) if y < drip else _shade(rng, dirt, 0.12)
				T_STONE, T_COPPER_ORE, T_TIN_ORE, T_IRON_ORE, T_SILVER_ORE, T_TITANIUM_ORE, T_GOLD_ORE:
					c = _shade(rng, Color(0.5, 0.5, 0.5), 0.08)
					if rng.randf() < 0.08:
						c = c.darkened(0.2)
					if specks.has(Vector2i(x, y)):
						c = _shade(rng, ORE_COLORS[t], 0.12)
				T_RUBY_ORE, T_SAPPHIRE_ORE, T_DIAMOND_ORE, T_ONYX_ORE, T_AMETHYST_ORE:
					# Gems on dark Deepstone: bigger, brighter crystals with a white sparkle.
					c = _shade(rng, DEEP_GRAY, 0.07)
					if y % 5 == 0:
						c = c.darkened(0.1)
					if specks.has(Vector2i(x, y)):
						c = _shade(rng, ORE_COLORS[t], 0.08)
						if not specks.has(Vector2i(x - 1, y - 1)):
							c = c.lightened(0.55) if t != T_ONYX_ORE else Color(0.82, 0.8, 0.9)
				T_SAND:
					c = _shade(rng, Color(0.86, 0.80, 0.58), 0.05)
				T_LOG_SIDE, T_REDWOOD_SIDE, T_PINE_SIDE, T_PALM_SIDE, T_MAPLE_SIDE, T_DEAD_SIDE:
					var wc: Array = WOOD_COLORS[WOOD_TILES.get(t, "oak")]
					c = _shade(rng, wc[0], 0.08)
					if x % 4 == 1:
						c = c.darkened(0.2)
					if t == T_PALM_SIDE and y % 4 == 0:
						c = c.darkened(0.25)   # palm trunks have rings
					if t == T_REDWOOD_SIDE and (x * 3 + y) % 7 == 0:
						c = c.lightened(0.12)   # stringy redwood bark
				T_LOG_TOP, T_REDWOOD_TOP, T_PINE_TOP, T_PALM_TOP, T_MAPLE_TOP, T_DEAD_TOP:
					var wt: Array = WOOD_COLORS[WOOD_TILES.get(t, "oak")]
					if edge:
						c = _shade(rng, wt[0], 0.08)
					else:
						var d := Vector2(x, y).distance_to(Vector2(7.5, 7.5))
						c = _shade(rng, wt[1], 0.04)
						if int(d) % 3 == 0:
							c = c.darkened(0.15)
				T_LEAVES:
					if rng.randf() < 0.22:
						c = Color(0, 0, 0, 0)  # holes you can see through
					else:
						c = _shade(rng, Color(0.20, 0.48, 0.14), 0.18)
				T_PLANKS:
					c = _plank_pixel(rng, plank, x, y)
				T_REDWOOD_PLANKS, T_PINE_PLANKS, T_PALM_PLANKS, T_MAPLE_PLANKS, T_DEAD_PLANKS:
					c = _plank_pixel(rng, WOOD_COLORS[WOOD_TILES[t]][2], x, y)
				T_CANDY_PLANKS:
					c = _plank_pixel(rng, Color(0.98, 0.7, 0.82) if (y / 4) % 2 == 0 else Color(0.97, 0.94, 0.96), x, y)
				T_PALM_LEAVES:
					if rng.randf() < 0.2:
						c = Color(0, 0, 0, 0)
					else:
						c = _shade(rng, Color(0.3, 0.62, 0.22) if (x + y) % 5 != 0 else Color(0.42, 0.72, 0.28), 0.12)
				T_COBBLE, T_FURNACE_TOP:
					c = _cobble_pixel(rng, cells, cell_shades, fx, fy)
				T_FURNACE_SIDE:
					c = _cobble_pixel(rng, cells, cell_shades, fx, fy)
					if x >= 4 and x <= 11 and y >= 8 and y <= 13:
						c = Color(0.08, 0.06, 0.05)  # opening
						if y >= 11:
							c = _shade(rng, Color(1.0, 0.55, 0.15), 0.2)  # fire
				T_BEDROCK:
					var g2 := rng.randf_range(0.12, 0.45)
					c = Color(g2, g2, g2)
				T_GLASS:
					if edge:
						c = Color(0.85, 0.93, 0.97)
					elif (x - y == 0 or x - y == 1) and x > 2 and x < 7:
						c = Color(1, 1, 1)
					else:
						c = Color(0, 0, 0, 0)
				T_WATER:
					c = _shade(rng, Color(0.20, 0.40, 0.85, 0.65), 0.06)
				T_LAMP:
					var rim := x <= 1 or y <= 1 or x >= s - 2 or y >= s - 2
					var bar := x == 7 or x == 8 or y == 7 or y == 8
					if rim:
						c = _shade(rng, Color(0.33, 0.24, 0.14), 0.08)
					elif bar:
						c = _shade(rng, Color(0.45, 0.33, 0.2), 0.06)
					else:
						c = _shade(rng, Color(1.0, 0.86, 0.5), 0.05)
				T_BENCH_TOP:
					c = _plank_pixel(rng, plank, x, y)
					if edge or x % 5 == 0 or y % 5 == 0:
						c = _shade(rng, Color(0.38, 0.27, 0.15), 0.05)  # crafting grid
				T_BENCH1_SIDE, T_BENCH2_SIDE, T_BENCH3_SIDE:
					c = _plank_pixel(rng, plank, x, y)
					if y <= 2:
						c = _shade(rng, BENCH_TRIM[t], 0.06)  # tier-colored trim
					elif (x == 4 and y >= 5 and y <= 12) or (y == 5 and x >= 3 and x <= 6):
						c = Color(0.25, 0.25, 0.27)  # a hammer hanging on the side
					elif (x == 11 and y >= 5 and y <= 12) or (y == 6 and x >= 10 and x <= 12):
						c = _shade(rng, BENCH_TRIM[t], 0.05).darkened(0.25)  # a saw
				T_SHOP_SIDE:
					c = _plank_pixel(rng, plank, x, y)
					var d2 := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
					if d2 < 5.5:
						c = Color(1.0, 0.82, 0.25) if d2 > 4.0 or (x == 8 or x == 7) else Color(0.95, 0.72, 0.15)
				T_SHOP_TOP:
					c = Color(0.25, 0.65, 0.35) if (x / 3) % 2 == 0 else Color(0.95, 0.95, 0.9)
					c = _shade(rng, c, 0.04)
				T_GOLD_BLOCK:
					c = _shade(rng, Color(1.0, 0.82, 0.25), 0.05)
					if edge:
						c = c.lightened(0.3)
					elif x == 1 or y == 1:
						c = c.lightened(0.15)
				T_CHEST_SIDE, T_CHEST_TOP:
					c = _plank_pixel(rng, Color(0.64, 0.46, 0.24), x, y)
					if edge:
						c = _shade(rng, Color(0.36, 0.24, 0.12), 0.05)
					if t == T_CHEST_SIDE:
						if y == 5:
							c = Color(0.3, 0.2, 0.1)  # lid line
						if x >= 6 and x <= 9 and y >= 4 and y <= 8:
							c = Color(0.85, 0.85, 0.82) if (x == 6 or x == 9 or y == 4 or y == 8) else Color(0.25, 0.25, 0.28)
				T_TORCH:
					c = Color(0, 0, 0, 0)
					if x >= 7 and x <= 8 and y >= 6:
						c = _shade(rng, Color(0.5, 0.35, 0.18), 0.08)
					elif x >= 6 and x <= 9 and y >= 2 and y <= 5:
						c = Color(1.0, 0.95, 0.5) if y >= 4 else Color(1.0, 0.6, 0.15)
					elif (x == 7 or x == 8) and y == 1:
						c = Color(1.0, 0.45, 0.1)
				T_BED_TOP:
					c = _shade(rng, Color(0.82, 0.18, 0.2), 0.05)  # blanket
					if y < 5:
						c = _shade(rng, Color(0.96, 0.95, 0.92), 0.03)  # pillow
					elif (x + y) % 6 == 0:
						c = c.lightened(0.15)
				T_BED_SIDE:
					c = Color(0, 0, 0, 0)
					if y >= 7:
						c = _shade(rng, Color(0.82, 0.18, 0.2), 0.05) if y < 12 else _plank_pixel(rng, plank, x, y)
						if y >= 12 and (x <= 1 or x >= s - 2):
							c = c.darkened(0.3)
				T_BED_ICON:
					c = Color(0, 0, 0, 0)
					if y >= 6 and y <= 12:
						c = _shade(rng, Color(0.82, 0.18, 0.2), 0.05)
						if x < 5:
							c = Color(0.96, 0.95, 0.92)
						if y == 12:
							c = _plank_pixel(rng, plank, x, y)
					if y > 12 and (x <= 1 or x >= s - 2):
						c = Color(0.42, 0.29, 0.15)
				T_DOOR_WOOD, T_DOOR_WOOD_TOP, T_DOOR_IRON, T_DOOR_IRON_TOP, T_DOOR_TITANIUM, T_DOOR_TITANIUM_TOP:
					var base_t := t - (t - T_DOOR_WOOD) % 2
					var cols: Array = DOOR_COLORS[base_t]
					var top := t != base_t
					c = _shade(rng, cols[0], 0.05)
					if base_t == T_DOOR_WOOD and x % 4 == 0:
						c = c.darkened(0.15)
					if edge or (y >= 3 and y <= 12 and (x == 3 or x == 12 or y == 3 or y == 12)):
						c = _shade(rng, cols[1], 0.05)
					if top and x > 3 and x < 12 and y > 3 and y < 12:
						c = Color(0.7, 0.85, 0.95)  # little window
					if not top and x >= 11 and x <= 12 and y >= 0 and y <= 1:
						c = Color(0.95, 0.8, 0.3)  # handle (sits at the top of the bottom half)
				T_SANDSTONE, T_SANDSTONE_TOP:
					c = _shade(rng, Color(0.85, 0.75, 0.5), 0.04)
					if t == T_SANDSTONE and (y == 4 or y == 11):
						c = c.darkened(0.12)
					if t == T_SANDSTONE_TOP and edge:
						c = c.darkened(0.1)
				T_CACTUS_SIDE:
					c = _shade(rng, Color(0.3, 0.6, 0.25), 0.06)
					if x % 4 == 1:
						c = c.darkened(0.2)
					if x % 4 == 3 and y % 4 == 1:
						c = Color(0.95, 0.95, 0.8)  # prickles
				T_CACTUS_TOP:
					c = _shade(rng, Color(0.38, 0.68, 0.3), 0.05)
					if edge:
						c = c.darkened(0.25)
				T_FROSTING_TOP:
					c = _shade(rng, Color(1.0, 0.68, 0.82), 0.05)
					if rng.randf() < 0.07:
						c = [Color(0.4, 0.8, 1.0), Color(1.0, 0.95, 0.4), Color(0.6, 1.0, 0.5), Color(1, 1, 1)][rng.randi() % 4]  # sprinkles
				T_FROSTING_SIDE:
					var drip2 := 4 + int(absf(sin(x * 1.7)) * 4.0)
					c = _shade(rng, Color(1.0, 0.68, 0.82), 0.05) if y < drip2 else _shade(rng, Color(0.93, 0.78, 0.52), 0.05)
				T_CAKE:
					c = _shade(rng, Color(0.93, 0.78, 0.52), 0.05)
					if y == 7 or y == 8:
						c = _shade(rng, Color(0.95, 0.3, 0.35), 0.05)  # jam layer
				T_CANDY_CANE:
					c = Color(0.95, 0.15, 0.2) if posmod(x + y, 8) < 4 else Color(0.98, 0.97, 0.95)
				T_CANDY_CANE_TOP:
					var a := atan2(y - 7.5, x - 7.5)
					c = Color(0.95, 0.15, 0.2) if posmod(int((a + PI) / TAU * 8.0), 2) == 0 else Color(0.98, 0.97, 0.95)
				T_SNOW:
					c = _shade(rng, Color(0.93, 0.95, 0.98), 0.03)
					if rng.randf() < 0.06:
						c = Color(0.82, 0.88, 0.96)
				T_SNOW_SIDE, T_SNOWY_STONE_SIDE:
					var under := _shade(rng, dirt, 0.12) if t == T_SNOW_SIDE else _shade(rng, Color(0.5, 0.5, 0.52), 0.08)
					c = _shade(rng, Color(0.93, 0.95, 0.98), 0.03) if y < drip - 1 else under
				T_PINE_LEAVES:
					if rng.randf() < 0.16:
						c = Color(0, 0, 0, 0)
					elif rng.randf() < 0.12:
						c = Color(0.9, 0.93, 0.97)  # a little snow
					else:
						c = _shade(rng, Color(0.13, 0.33, 0.2), 0.15)
				T_MUSHROOM_CAP:
					c = _shade(rng, Color(0.85, 0.16, 0.18), 0.05)
					var spot := Vector2(posmod(x * 5 + y * 3, 7), posmod(y * 5 + x * 2, 7))
					if spot.length() < 1.5:
						c = Color(0.98, 0.96, 0.92)
				T_MUSHROOM_STEM:
					c = _shade(rng, Color(0.93, 0.89, 0.8), 0.04)
					if (x == 6 or x == 9) and y >= 6 and y <= 10:
						c = Color(0.45, 0.32, 0.2) if y < 10 else Color(0.62, 0.45, 0.25)  # a tiny door
					if x >= 6 and x <= 9 and y == 6:
						c = Color(0.45, 0.32, 0.2)
					if (x == 3 or x == 12) and (y == 4 or y == 5):
						c = Color(1.0, 0.85, 0.4)  # glowing windows
				T_MUSHROOM_UNDER:
					c = _shade(rng, Color(0.9, 0.82, 0.72), 0.05)
					if x % 3 == 0:
						c = c.darkened(0.12)
				T_COTTON_CANDY:
					if rng.randf() < 0.12:
						c = Color(0, 0, 0, 0)
					else:
						c = _shade(rng, Color(0.75, 0.75, 1.0) if (x / 5 + y / 5) % 2 == 0 else Color(1.0, 0.7, 0.88), 0.08)
				T_TALL_GRASS, T_FERN, T_POPPY, T_DANDELION, T_CORNFLOWER, T_DAISY, T_BLUEBELL, \
						T_TOADSTOOL, T_DRY_SHRUB, T_CACTUS_FLOWER, T_LOLLIPOP, T_CANDY_TULIP, \
						T_FROST_GRASS, T_EDELWEISS:
					c = _plant_pixel(t, x, y, rng)
				_:
					c = _build_tile_pixel(t, x, y, rng, edge, cells, cell_shades, fx, fy)
			c.r = clampf(c.r, 0.0, 1.0)
			c.g = clampf(c.g, 0.0, 1.0)
			c.b = clampf(c.b, 0.0, 1.0)
			img.set_pixel(px, py, c)


## Grass blades: [x at the ground, height, lean per pixel up].
const BLADES := [[2, 8, -0.2], [4, 12, 0.12], [6, 6, 0.0], [7, 14, -0.1], [9, 10, 0.15],
		[11, 13, 0.05], [13, 7, -0.12], [14, 10, 0.18]]


## How far the point (x, y) is from the line a-b.
static func _seg(x: float, y: float, a: Vector2, b: Vector2) -> float:
	var p := Vector2(x, y)
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * k)


## One pixel of a ground plant, on a see-through background (y = 15 is the ground).
static func _plant_pixel(t: int, x: int, y: int, rng: RandomNumberGenerator) -> Color:
	var clear := Color(0, 0, 0, 0)
	var stem := Color(0.27, 0.56, 0.22)
	var fx := float(x)
	var fy := float(y)
	match t:
		T_TALL_GRASS, T_FROST_GRASS:
			var base_col := Color(0.4, 0.68, 0.27) if t == T_TALL_GRASS else Color(0.5, 0.68, 0.6)
			for b in BLADES:
				var top: int = 16 - b[1]
				if y >= top and x == b[0] + roundi((15 - y) * float(b[2])):
					var col := _shade(rng, base_col, 0.1).darkened(0.3 * fy / 15.0)
					if t == T_FROST_GRASS and y <= top + 1:
						col = Color(0.92, 0.96, 1.0)  # frosty tips
					return col
			return clear
		T_FERN:
			# Three fronds curving out from the middle, with little leaflets.
			for f in [[Vector2(8, 15), Vector2(2, 5)], [Vector2(8, 15), Vector2(8, 1)], [Vector2(8, 15), Vector2(14, 5)]]:
				var d := _seg(fx, fy, f[0], f[1])
				if d < 0.6:
					return _shade(rng, Color(0.2, 0.45, 0.16), 0.06)
				if d < 2.3 and y < 13 and (x + y) % 2 == 0:
					return _shade(rng, Color(0.3, 0.62, 0.24), 0.1)
			return clear
		T_POPPY, T_DANDELION, T_CORNFLOWER, T_DAISY, T_EDELWEISS:
			var head := Vector2(7.5, 5.5)
			var d := Vector2(fx, fy).distance_to(head)
			var ang := atan2(fy - head.y, fx - head.x)
			var stem_col := stem if t != T_EDELWEISS else Color(0.45, 0.58, 0.45)
			match t:
				T_POPPY:
					if d < 1.2:
						return Color(0.15, 0.1, 0.1)
					if d < 3.4:
						return _shade(rng, Color(0.9, 0.16, 0.14), 0.07).lightened(0.15 if fy < head.y - 1 else 0.0)
				T_DANDELION:
					if d < 2.8:
						return _shade(rng, Color(1.0, 0.86, 0.2), 0.06).lightened(0.2 if d < 1.2 else 0.0)
				T_CORNFLOWER:
					var spikes := 2.4 + 1.1 * absf(sin(ang * 4.0))
					if d < 1.0:
						return Color(0.25, 0.2, 0.55)
					if d < spikes:
						return _shade(rng, Color(0.32, 0.5, 0.95), 0.08)
				T_DAISY:
					if d < 1.3:
						return Color(1.0, 0.82, 0.2)
					if d < 3.6 and posmod(int((ang + PI) / TAU * 10.0), 2) == 0:
						return _shade(rng, Color(0.98, 0.98, 0.95), 0.03)
				T_EDELWEISS:
					var star := 1.6 + 2.0 * absf(cos(ang * 3.0))
					if d < 1.2:
						return Color(0.9, 0.85, 0.5)
					if d < star:
						return _shade(rng, Color(0.95, 0.96, 0.93), 0.04)
			if x == 7 and y > 7:
				return _shade(rng, stem_col, 0.05)
			if (y == 11 and x >= 4 and x <= 6) or (y == 12 and x == 5) or (y == 10 and x >= 9 and x <= 11) or (y == 9 and x == 10):
				return _shade(rng, stem_col.lightened(0.1), 0.06)  # leaves
			return clear
		T_BLUEBELL:
			# An arching stem with bells hanging from it.
			if _seg(fx, fy, Vector2(4, 15), Vector2(5, 4)) < 0.6 or _seg(fx, fy, Vector2(5, 4), Vector2(11, 3)) < 0.6:
				return _shade(rng, stem, 0.05)
			for bell in [Vector2(7, 6), Vector2(10, 6), Vector2(12.5, 8)]:
				if absf(fx - bell.x) <= 1.0 + (fy - bell.y) * 0.4 and fy >= bell.y and fy <= bell.y + 2.5:
					return _shade(rng, Color(0.42, 0.42, 0.92), 0.08)
			if (y == 12 and x >= 2 and x <= 3) or (y == 11 and x == 6):
				return _shade(rng, stem, 0.05)
			return clear
		T_TOADSTOOL:
			var cap := Vector2((fx - 7.5) / 5.5, (fy - 9.5) / 4.0)
			if cap.length() < 1.0 and fy <= 9.5:
				var spot := (x == 5 and y == 7) or (x == 9 and y == 6) or (x == 11 and y == 8) or (x == 7 and y == 9)
				return Color(0.98, 0.96, 0.9) if spot else _shade(rng, Color(0.86, 0.15, 0.16), 0.06)
			if x >= 6 and x <= 9 and y >= 10:
				return _shade(rng, Color(0.94, 0.9, 0.82), 0.04).darkened(0.15 if x == 9 else 0.0)
			return clear
		T_DRY_SHRUB:
			for s in [[Vector2(8, 15), Vector2(8, 6)], [Vector2(8, 11), Vector2(3, 5)], [Vector2(8, 10), Vector2(13, 4)],
					[Vector2(5, 8), Vector2(2, 9)], [Vector2(11, 7), Vector2(14, 8)], [Vector2(8, 6), Vector2(6, 2)], [Vector2(8, 7), Vector2(10, 3)]]:
				if _seg(fx, fy, s[0], s[1]) < 0.55:
					return _shade(rng, Color(0.55, 0.4, 0.24), 0.1)
			return clear
		T_CACTUS_FLOWER:
			if Vector2(fx, fy).distance_to(Vector2(7.5, 6.0)) < 2.4:
				return _shade(rng, Color(1.0, 0.45, 0.7), 0.06).lightened(0.25 if y < 6 else 0.0)
			if x >= 6 and x <= 9 and y >= 8:
				var c := _shade(rng, Color(0.32, 0.62, 0.27), 0.06)
				return Color(0.95, 0.95, 0.8) if (x == 6 or x == 9) and y % 3 == 0 else c
			if (x == 4 or x == 11) and y >= 9 and y <= 12:
				return _shade(rng, Color(0.32, 0.62, 0.27), 0.06)  # little arms
			if (x == 5 or x == 10) and y == 12:
				return _shade(rng, Color(0.32, 0.62, 0.27), 0.06)
			return clear
		T_LOLLIPOP:
			var center := Vector2(7.5, 5.0)
			var d := Vector2(fx, fy).distance_to(center)
			if d < 4.3:
				var a := atan2(fy - center.y, fx - center.x) + d * 0.9
				return Color(1.0, 0.3, 0.5) if posmod(int((a + PI) / TAU * 6.0), 2) == 0 else Color(1.0, 0.97, 0.97)
			if (x == 7 or x == 8) and y >= 9:
				return Color(0.97, 0.96, 0.92) if x == 7 else Color(0.85, 0.84, 0.8)
			return clear
		T_CANDY_TULIP:
			if y >= 3 and y <= 8 and x >= 5 and x <= 10:
				var notch := y <= 4 and (x == 6 or x == 9)
				var round_bottom := y == 8 and (x == 5 or x == 10)
				if not notch and not round_bottom:
					return _shade(rng, Color(0.8, 0.4, 0.95) if x % 3 != 0 else Color(1.0, 0.6, 0.85), 0.05)
			if (x == 7 or x == 8) and y > 8:
				return Color(0.45, 0.85, 0.55) if x == 7 else Color(0.35, 0.72, 0.45)
			if (y == 12 and x >= 9 and x <= 11) or (y == 11 and x == 11):
				return Color(0.45, 0.85, 0.55)
			return clear
	return clear


const CARVED_WOOD := {T_CARVED_OAK: "oak", T_CARVED_REDWOOD: "redwood", T_CARVED_PINE: "pine",
		T_CARVED_PALM: "palm", T_CARVED_CANDY: "candy", T_CARVED_MAPLE: "maple", T_CARVED_DEAD: "dead"}
const METAL_TILES := {T_COPPER_BLOCK: Color(0.85, 0.52, 0.3), T_IRON_BLOCK: Color(0.78, 0.78, 0.8),
		T_SILVER_BLOCK: Color(0.9, 0.92, 0.97), T_TITANIUM_BLOCK: Color(0.58, 0.75, 0.95)}
const INLAY_TILES := {T_GOLD_INLAY: Color(1.0, 0.82, 0.3), T_SILVER_INLAY: Color(0.92, 0.94, 1.0), T_TITANIUM_INLAY: Color(0.55, 0.78, 1.0)}


## Marble (white with soft grey veins) or onyx (deep black with faint violet
## and white veins), smooth and a little glossy.
static func _marble_pixel(rng: RandomNumberGenerator, x: int, y: int, fx: float, fy: float, onyx: bool) -> Color:
	var base := Color(0.12, 0.115, 0.14) if onyx else Color(0.93, 0.92, 0.89)
	var c := _shade(rng, base, 0.025)
	var v := sin(fx * 0.55 + fy * 0.3 + sin(fy * 0.42 + fx * 0.1) * 2.2)
	var v2 := sin(fx * 0.21 - fy * 0.6 + 1.7 + sin(fx * 0.5) * 1.4)
	if absf(v) < 0.09:
		c = c.lerp(Color(0.42, 0.36, 0.52) if onyx else Color(0.6, 0.6, 0.63), 0.32 if onyx else 0.55)
	elif absf(v2) < 0.05:
		c = c.lerp(Color(0.6, 0.6, 0.66) if onyx else Color(0.72, 0.71, 0.72), 0.18 if onyx else 0.35)
	return c


## Stone bricks: 2 rows of bricks per 8 pixels, offset every other row.
static func _brick_pixel(rng: RandomNumberGenerator, x: int, y: int, base: Color) -> Color:
	var row := y / 4
	var bx := (x + (4 if row % 2 == 1 else 0)) % 8
	if y % 4 == 3 or bx == 7:
		return Color(0.33, 0.33, 0.35)   # mortar
	var c := _shade(rng, base, 0.05)
	if y % 4 == 0 or bx == 0:
		c = c.lightened(0.08)
	return c


## Pictures for the building blocks and the three building benches.
static func _build_tile_pixel(t: int, x: int, y: int, rng: RandomNumberGenerator, edge: bool,
		cells: Array[Vector2], shades: Array[float], fx: float, fy: float) -> Color:
	var stone := Color(0.56, 0.56, 0.58)
	if CARVED_WOOD.has(t):
		var w: String = CARVED_WOOD[t]
		var plank: Color = Color(0.98, 0.72, 0.84) if w == "candy" else WOOD_COLORS[w][2]
		var c := _shade(rng, plank, 0.04)
		var d := absi(x - 7) + absi(y - 7)
		if edge or x == 1 or y == 1 or x == 14 or y == 14:
			c = c.darkened(0.28)                 # a carved frame
		elif d == 4 or d == 5:
			c = c.darkened(0.22)                 # a diamond in the middle
		elif d < 2:
			c = c.lightened(0.12)
		return c
	if METAL_TILES.has(t):
		var m: Color = METAL_TILES[t]
		var c := _shade(rng, m, 0.03)
		if edge:
			c = m.darkened(0.25)
		elif x == 1 or y == 1:
			c = m.lightened(0.25)                # a bevel catching the light
		elif x == 14 or y == 14:
			c = m.darkened(0.12)
		elif (x + y) % 9 == 0 and x > 3 and x < 12:
			c = m.lightened(0.18)                # shine
		return c
	if INLAY_TILES.has(t):
		var c := _brick_pixel(rng, x, y, stone)
		if (y % 4 == 3 and (x / 2) % 2 == 0) or (x == 7 and y >= 5 and y <= 10) or (y == 7 and x >= 5 and x <= 10):
			c = _shade(rng, INLAY_TILES[t], 0.06)   # metal set into the stone
		return c
	match t:
		T_RESEARCH_TOP:
			# Dark walnut with an open tome, a brass lens and a candle.
			var c := _plank_pixel(rng, Color(0.26, 0.16, 0.12), x, y)
			if x >= 2 and x <= 10 and y >= 4 and y <= 12:
				c = Color(0.9, 0.84, 0.68) if x != 6 else Color(0.62, 0.52, 0.4)   # the book
				if (y == 6 or y == 8 or y == 10) and x != 6 and x > 2 and x < 10:
					c = Color(0.35, 0.28, 0.32)   # lines of writing
			var lens := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12.5, 4.5))
			if lens < 2.6:
				c = Color(0.88, 0.68, 0.32) if lens > 1.6 else Color(0.55, 0.75, 0.85)
			if x == 13 and y >= 10 and y <= 13:
				c = Color(0.95, 0.92, 0.85) if y > 10 else Color(1.0, 0.75, 0.3)   # a candle
			if x == 0 or y == 0 or x == 15 or y == 15:
				c = Color(0.72, 0.55, 0.3)   # brass edge
			return c
		T_RESEARCH_SIDE:
			# Shelves of scrolls and books behind brass-cornered walnut.
			var c := _plank_pixel(rng, Color(0.24, 0.15, 0.11), x, y)
			if (y >= 3 and y <= 6) or (y >= 9 and y <= 12):
				var book := (x / 2) % 4
				c = [Color(0.45, 0.12, 0.15), Color(0.18, 0.2, 0.4), Color(0.85, 0.8, 0.62), Color(0.2, 0.32, 0.2)][book]
				if x % 2 == 1:
					c = c.darkened(0.25)
			if y == 7 or y == 13:
				c = Color(0.16, 0.1, 0.07)
			if (x <= 1 or x >= 14) and (y <= 1 or y >= 14):
				c = Color(0.8, 0.62, 0.32)
			return c
		T_SHRINE_CHEST_SIDE, T_SHRINE_CHEST_TOP:
			# Old carved stone with a gold rim; the side has a gold clasp.
			var c := _brick_pixel(rng, x, y, stone.darkened(0.08)) if t == T_SHRINE_CHEST_SIDE else _shade(rng, stone.darkened(0.04), 0.04)
			if x == 0 or y == 0 or x == 15 or y == 15:
				c = _shade(rng, Color(0.86, 0.68, 0.25), 0.05)
			if t == T_SHRINE_CHEST_SIDE:
				if y == 5:
					c = Color(0.86, 0.68, 0.25)                     # lid line
				if x >= 6 and x <= 9 and y >= 4 and y <= 8:
					c = Color(1.0, 0.84, 0.35) if (x == 6 or x == 9 or y == 4 or y == 8) else Color(0.2, 0.16, 0.1)
			else:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
				if d > 3.0 and d < 4.2:
					c = Color(0.86, 0.68, 0.25)                     # a gold ring on the lid
				elif d < 1.6:
					c = Color(0.55, 0.85, 1.0)                      # with a little gem
			return c
		T_SCRIBE_SIDE:
			var c := _plank_pixel(rng, WOOD_COLORS["oak"][2].darkened(0.1), x, y)
			if x >= 3 and x <= 12 and y >= 3 and y <= 12:
				c = Color(0.95, 0.92, 0.82) if (y % 3 != 0 or x < 5 or x > 10) else Color(0.35, 0.35, 0.45)   # a page with writing
			if x == 12 and y <= 9 and y >= 1:
				c = Color(0.95, 0.95, 0.98) if y < 4 else Color(0.3, 0.3, 0.32)   # a quill
			return c
		T_SCRIBE_TOP:
			var c := _plank_pixel(rng, WOOD_COLORS["oak"][2].darkened(0.1), x, y)
			if x >= 2 and x <= 9 and y >= 3 and y <= 12:
				c = Color(0.95, 0.92, 0.82)                      # open book
				if x == 5 or x == 6:
					c = Color(0.8, 0.76, 0.66)
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12.5, 5.5)) < 2.0:
				c = Color(0.1, 0.1, 0.14)                        # ink pot
			return c
		T_FRAME:
			var border := x <= 1 or y <= 1 or x >= 14 or y >= 14
			if border:
				return _shade(rng, WOOD_COLORS["oak"][0].lightened(0.15), 0.06)
			return _shade(rng, Color(0.52, 0.38, 0.26), 0.04)    # leather backing
		T_STAND_ICON:
			var wood := WOOD_COLORS["oak"][2]
			if (x == 7 or x == 8) and y >= 2:
				return wood                                      # pole
			if y >= 4 and y <= 5 and x >= 3 and x <= 12:
				return wood.darkened(0.1)                        # shoulders
			if y == 1 and x >= 6 and x <= 9:
				return wood
			if y >= 14 and x >= 3 and x <= 12:
				return Color(0.55, 0.55, 0.58)                   # stone base
			return Color(0, 0, 0, 0)
		T_BED_BLANKET:
			var c := _shade(rng, Color(0.82, 0.18, 0.2), 0.04)
			if (x + y) % 6 == 0:
				c = c.lightened(0.15)                 # a quilted pattern
			if x <= 0 or x >= 15:
				c = c.darkened(0.2)
			return c
		T_BED_PILLOW:
			var c := _shade(rng, Color(0.82, 0.18, 0.2), 0.04)
			if y < 7 and x > 1 and x < 14:
				c = _shade(rng, Color(0.97, 0.96, 0.93), 0.02)   # pillow
				if y == 6 or x == 2 or x == 13:
					c = Color(0.86, 0.85, 0.82)
			return c
		T_VINE:
			# Two twisting strands with leaves, top to bottom.
			for k in 2:
				var sx := 5 + k * 6 + int(sin(y * 0.8 + k * 2.0) * 1.6)
				if x == sx:
					return _shade(rng, Color(0.25, 0.5, 0.2), 0.08)
				if (x == sx + 1 or x == sx - 1) and (y + k * 3) % 4 == 0:
					return _shade(rng, Color(0.35, 0.65, 0.25), 0.1)   # a leaf
			return Color(0, 0, 0, 0)
		T_DEAD_GRASS_TOP:
			var c := _shade(rng, [Color(0.3, 0.27, 0.32), Color(0.26, 0.3, 0.27), Color(0.34, 0.3, 0.36)][(x * 5 + y * 3) % 3], 0.1)
			if rng.randf() < 0.05:
				c = Color(0.55, 0.38, 0.65)               # a speck of purple moss
			return c
		T_DEAD_GRASS_SIDE:
			var drip := 3 + (x * 7) % 3
			return _shade(rng, Color(0.3, 0.28, 0.32), 0.1) if y < drip else _shade(rng, Color(0.4, 0.3, 0.24), 0.12)
		T_JACK_FACE:
			var c := _shade(rng, Color(0.95, 0.55, 0.15), 0.05)
			if x % 4 == 0:
				c = c.darkened(0.2)
			var glow := Color(1.0, 0.9, 0.35)
			var eye := (y >= 4 and y <= 6) and ((x >= 3 and x <= 5 and y - 4 >= absi(x - 4) - 1) or (x >= 10 and x <= 12 and y - 4 >= absi(x - 11) - 1))
			var nose := y == 8 and (x == 7 or x == 8)
			var mouth := (y == 10 and x >= 3 and x <= 12) or (y == 11 and x >= 4 and x <= 11 and x % 3 != 0)
			if eye or nose or mouth:
				c = glow                                    # a friendly carved grin, lit from inside
			return c
		T_GRAVESTONE:
			var c := _shade(rng, Color(0.55, 0.56, 0.6), 0.07)
			if (x == 7 or x == 8) and y >= 3 and y <= 10 or (y == 5 and x >= 5 and x <= 10):
				c = Color(0.38, 0.38, 0.42)                # a carved cross
			if rng.randf() < 0.06:
				c = Color(0.35, 0.5, 0.3)                  # moss
			return c
		T_COBWEB:
			var p := Vector2(x + 0.5, y + 0.5) - Vector2(8, 8)
			var ring := absf(fmod(p.length(), 3.2) - 1.6) < 0.35 and p.length() < 7.5
			var spoke := absi(x - y) == 0 or absi(x + y - 15) == 0 or x == 7 or y == 7
			return Color(0.92, 0.92, 0.95, 1.0) if (ring or spoke) else Color(0, 0, 0, 0)
		T_SUPER_CHEST_SIDE, T_SUPER_CHEST_TOP:
			# Dark royal wood bound in gold, with a glowing coin lock.
			var wood := Color(0.27, 0.13, 0.36) if (y % 4 != 3) else Color(0.18, 0.08, 0.25)
			var c := _shade(rng, wood, 0.06)
			if edge:
				c = _shade(rng, Color(0.95, 0.75, 0.25), 0.06)
			elif t == T_SUPER_CHEST_SIDE:
				if y == 5:
					c = Color(0.85, 0.65, 0.2)   # gold band along the lid
				var d := Vector2(x - 7.5, y - 6.5).length()
				if d < 2.6:
					c = Color(1.0, 0.88, 0.4) if d < 1.6 else Color(0.7, 0.5, 0.15)   # the coin
					if d < 0.8:
						c = Color(1.0, 0.98, 0.75)
			elif (x == y or x == 15 - y) and x > 1 and x < 14:
				c = _shade(rng, Color(0.85, 0.65, 0.2), 0.05)   # gold cross on the lid
			return c
		T_CAMPFIRE:
			# The picture in menus: crossed logs with a little fire on top.
			var c := Color(0, 0, 0, 0)
			if y >= 11 and y <= 13 and (absi(x - (y - 11) * 2 - 2) <= 1 or absi(x - (13 - (y - 11) * 2)) <= 1):
				c = _shade(rng, Color(0.45, 0.3, 0.16), 0.08)
			elif y >= 13 and y <= 14 and x >= 2 and x <= 13:
				c = _shade(rng, Color(0.5, 0.5, 0.52), 0.1) if (x % 3 != 1) else Color(0, 0, 0, 0)
			var fl := 7.5 - absf(x - 7.5) * 1.4
			if y < 12 and y >= 3 and float(12 - y) < fl + 1.5:
				c = Color(1.0, 0.85, 0.35) if float(12 - y) < fl * 0.55 else Color(1.0, 0.45, 0.12)
			return c
		T_BEDROLL:
			# A rolled-out blanket: green and blue plaid, with a pillow end.
			var plaid := Color(0.22, 0.45, 0.3)
			if x % 6 < 2:
				plaid = plaid.lerp(Color(0.2, 0.3, 0.6), 0.6)
			if y % 6 < 2:
				plaid = plaid.lerp(Color(0.85, 0.8, 0.55), 0.35)
			var c := _shade(rng, plaid, 0.06)
			if y < 4:
				c = _shade(rng, Color(0.92, 0.9, 0.84), 0.03)
			if edge:
				c = c.darkened(0.25)
			return c
		T_MARBLE, T_ONYX:
			return _marble_pixel(rng, x, y, fx, fy, t == T_ONYX)
		T_MARBLE_BRICKS, T_ONYX_BRICKS:
			# Big polished blocks with thin grout, offset every other row.
			var onyx := t == T_ONYX_BRICKS
			var row := y / 8
			var bx := (x + (8 if row % 2 == 1 else 0)) % 16
			if y % 8 == 7 or bx == 15:
				return Color(0.27, 0.25, 0.31) if onyx else Color(0.72, 0.71, 0.69)
			var c := _marble_pixel(rng, x, y, fx, fy, onyx)
			if y % 8 == 0 or bx == 0:
				c = c.lightened(0.12 if onyx else 0.05)   # a polished bevel
			return c
		T_CHECKER:
			# A 2x2 chessboard with a thin gold line between the squares.
			var dark := (x < 8) != (y < 8)
			if x == 7 or x == 8 or y == 7 or y == 8:
				return _shade(rng, Color(0.85, 0.68, 0.3), 0.04)
			var c := _marble_pixel(rng, x, y, fx, fy, dark)
			if edge:
				c = c.darkened(0.15)
			return c
		T_BUN_TOP, T_BUN_SIDE:
			# Toasty golden bun, sprinkled with sesame seeds; the side is soft bread under the crust.
			var crust := Color(0.82, 0.52, 0.22)
			if t == T_BUN_SIDE and y >= 4:
				var bread := _shade(rng, Color(0.96, 0.86, 0.62), 0.04)
				return bread.darkened(0.1) if (x * 7 + y * 5) % 11 == 0 else bread   # little air holes
			var c := _shade(rng, crust, 0.05)
			var seed := posmod(x * 5 + y * 11, 29) == 0 or posmod(x * 5 + (y - 1) * 11, 29) == 0
			if seed and (t == T_BUN_TOP or y < 3):
				c = Color(0.98, 0.94, 0.8) if x % 2 == 0 else Color(0.92, 0.86, 0.68)
			elif (x + y) % 9 == 0:
				c = c.lightened(0.1)   # a shiny glaze
			return c
		T_FRIES_TOP, T_FRIES_SIDE:
			# Golden fries packed tight, crispier at the tips.
			var col := x / 3 if t == T_FRIES_SIDE else (x + y * 3) / 3
			var fry := _shade(rng, Color(1.0, 0.88, 0.42) if col % 2 == 0 else Color(1.0, 0.8, 0.3), 0.04)
			if t == T_FRIES_SIDE and x % 3 == 2:
				fry = fry.darkened(0.1)   # the gaps between fries
			if t == T_FRIES_TOP and ((x % 3 == 2) or (y % 3 == 2)):
				fry = fry.darkened(0.28)
			if t == T_FRIES_SIDE and y < 2 + (col * 7) % 3:
				fry = fry.darkened(0.12)   # crispy ends
			return fry
		T_FRY_BOX:
			# A red fry box with a yellow smiley star.
			var c := _shade(rng, Color(0.86, 0.12, 0.14), 0.03)
			if y <= 1:
				c = Color(0.98, 0.78, 0.2)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 9))
			var ang := atan2(y + 0.5 - 9.0, x + 0.5 - 8.0)
			if d < 3.2 + 1.3 * cos(ang * 5.0):
				c = Color(1.0, 0.85, 0.25)
				if (y == 8 and (x == 6 or x == 9)) or (y == 10 and x >= 6 and x <= 9):
					c = Color(0.5, 0.2, 0.08)   # its smile
			if edge:
				c = c.darkened(0.2)
			return c
		T_CIRCUS:
			# Red and white circus-tent stripes with a gold seam.
			var c := Color(0.9, 0.14, 0.16) if (x / 4) % 2 == 0 else Color(0.97, 0.95, 0.92)
			c = _shade(rng, c, 0.03)
			if y == 0 or y == 15:
				c = Color(0.98, 0.78, 0.25)
			return c
		T_ARENA_BOX:
			# A gold-bound box with crossed swords on it.
			var c := _shade(rng, Color(0.55, 0.12, 0.12), 0.05)
			if edge:
				c = _shade(rng, Color(0.98, 0.78, 0.3), 0.05)
			if absi(x - y) <= 0 and x > 2 and x < 13 or absi(x + y - 15) <= 0 and x > 2 and x < 13:
				c = Color(0.85, 0.86, 0.9)     # two crossed swords
			if (x == 4 and y == 11) or (x == 11 and y == 11) or (x == 4 and y == 4) or (x == 11 and y == 4):
				c = Color(0.98, 0.78, 0.3)
			return c
		T_GATE:
			# Heavy iron bars with rivets.
			var bar := x % 5 == 1 or x % 5 == 2 or y % 8 == 3
			if not bar:
				return Color(0, 0, 0, 0)
			var c := _shade(rng, Color(0.32, 0.32, 0.36), 0.04)
			if y % 8 == 3 and x % 5 == 1:
				c = Color(0.55, 0.55, 0.6)
			return c
		T_BUTTON_TOP:
			var c := _shade(rng, Color(0.98, 0.78, 0.3), 0.04)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d < 5.0:
				c = Color(0.92, 0.12, 0.12).lightened(0.3 if d < 2.0 else 0.0)
			elif d < 6.0:
				c = Color(0.35, 0.2, 0.1)
			return c
		T_BUTTON_SIDE:
			var c := _shade(rng, Color(0.36, 0.36, 0.4), 0.04)
			if y <= 2:
				c = Color(0.98, 0.78, 0.3)
			if y >= 6 and y <= 9 and x >= 3 and x <= 12:
				c = Color(0.92, 0.12, 0.12) if (x + y) % 4 != 0 else Color(0.98, 0.95, 0.9)   # a warning stripe
			return c
		T_CASTLE_BOX:
			# A gold-bound gift box with a little castle on it.
			var c := _shade(rng, Color(0.36, 0.14, 0.5), 0.05)
			if edge or x == 7 or x == 8:
				c = _shade(rng, Color(0.98, 0.78, 0.3), 0.05)   # gold ribbon
			var tower := (x >= 3 and x <= 5 or x >= 10 and x <= 12) and y >= 5 and y <= 12 and not (y == 5 and x % 2 == 0)
			var keep := x >= 5 and x <= 10 and y >= 8 and y <= 12
			if (tower or keep) and not (x == 7 or x == 8) or (x >= 7 and x <= 8 and y >= 10 and y <= 12):
				c = Color(0.86, 0.84, 0.8) if not (x >= 7 and x <= 8 and y >= 10) else Color(0.2, 0.12, 0.08)
			return c
		T_SAPLING_OAK, T_SAPLING_REDWOOD, T_SAPLING_PINE, T_SAPLING_PALM, T_SAPLING_MAPLE, T_SAPLING_GOLDEN, T_SAPLING_CANDY:
			return _sapling_pixel(t, x, y, rng)
		T_GLOWSHROOM:
			var cap := Vector2((x + 0.5 - 8.0) / 4.5, (y + 0.5 - 8.0) / 3.0)
			if cap.length() < 1.0 and y <= 8:
				return Color(0.7, 0.4, 1.0) if (x + y) % 4 != 0 else Color(0.9, 0.75, 1.0)
			if x >= 7 and x <= 8 and y > 8:
				return Color(0.85, 0.82, 0.9)
			if (x == 3 and y == 13) or (x == 12 and y == 12):
				return Color(0.7, 0.4, 1.0)                # little ones beside it
			return Color(0, 0, 0, 0)
		T_GHOST_LANTERN:
			var rim := x <= 1 or y <= 1 or x >= 14 or y >= 14
			var bar := x == 7 or x == 8
			if rim:
				return _shade(rng, Color(0.25, 0.25, 0.3), 0.06)
			if bar:
				return Color(0.3, 0.3, 0.36)
			return _shade(rng, Color(0.55, 1.0, 0.9), 0.05)   # a soft ghostly green-blue glow
		T_FALL_GRASS_TOP:
			var autumn := [Color(0.62, 0.55, 0.22), Color(0.72, 0.45, 0.18), Color(0.55, 0.5, 0.2)]
			var c := _shade(rng, autumn[(x * 7 + y * 3 + rng.randi() % 2) % 3], 0.1)
			if rng.randf() < 0.07:
				c = Color(0.85, 0.3, 0.15)                 # a fallen red leaf
			return c
		T_FALL_GRASS_SIDE:
			var drip := 3 + (x * 5) % 3
			return _shade(rng, Color(0.62, 0.52, 0.22), 0.1) if y < drip else _shade(rng, Color(0.53, 0.38, 0.26), 0.12)
		T_MAPLE_LEAVES, T_GOLDEN_LEAVES:
			if rng.randf() < 0.2:
				return Color(0, 0, 0, 0)
			var leaf := [Color(0.85, 0.25, 0.15), Color(0.95, 0.45, 0.15), Color(0.75, 0.18, 0.15)] if t == T_MAPLE_LEAVES \
					else [Color(0.98, 0.78, 0.2), Color(0.95, 0.62, 0.15), Color(1.0, 0.88, 0.35)]
			return _shade(rng, leaf[rng.randi() % 3], 0.08)
		T_PUMPKIN_SIDE:
			var c := _shade(rng, Color(0.95, 0.55, 0.15), 0.05)
			if x % 4 == 0:
				c = c.darkened(0.2)                        # ridges
			if x % 4 == 2:
				c = c.lightened(0.1)
			return c
		T_PUMPKIN_TOP:
			var c := _shade(rng, Color(0.92, 0.52, 0.14), 0.05)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d < 1.6:
				c = Color(0.35, 0.5, 0.2)                  # the stem
			elif int(atan2(y - 7.5, x - 7.5) * 2.5) % 2 == 0 and d > 3.0:
				c = c.darkened(0.15)
			return c
		T_HAY_SIDE:
			var c := _shade(rng, Color(0.88, 0.75, 0.35), 0.08)
			if x % 3 == 0:
				c = c.darkened(0.15)                       # straw lines
			if y >= 6 and y <= 8:
				c = Color(0.65, 0.2, 0.18)                 # a red band
			return c
		T_HAY_TOP:
			var c := _shade(rng, Color(0.88, 0.75, 0.35), 0.08)
			if (x + y) % 3 == 0:
				c = c.darkened(0.12)
			if edge:
				c = c.darkened(0.2)
			return c
		T_LEAF_PILE, T_GOLD_LEAF_PILE:
			# A little heap of leaves on the ground (the bottom few rows).
			var top := 11 + int(absf(sin(x * 0.8)) * 2.0)
			if y < top:
				if (x == 4 and y == top - 2) or (x == 11 and y == top - 3):
					return Color(0.95, 0.4, 0.15) if t == T_LEAF_PILE else Color(1.0, 0.8, 0.25)   # a leaf on top
				return Color(0, 0, 0, 0)
			var pile := [Color(0.85, 0.28, 0.15), Color(0.95, 0.5, 0.18), Color(0.7, 0.2, 0.12)] if t == T_LEAF_PILE \
					else [Color(0.98, 0.78, 0.2), Color(0.9, 0.6, 0.15), Color(1.0, 0.9, 0.4)]
			return _shade(rng, pile[(x * 3 + y) % 3], 0.08)
		T_PORTALSTONE:
			# Dark violet stone with glowing pink veins of Cutieite.
			var c := _shade(rng, Color(0.28, 0.2, 0.36), 0.08)
			var vein := absf(sin(x * 0.9 + y * 0.45) * 3.0 + cos(y * 0.7) * 2.0 - (x - 7.5) * 0.3) < 0.6
			if vein:
				c = Color(1.0, 0.5, 0.82) if (x + y) % 3 != 0 else Color(1.0, 0.75, 0.9)
			if edge:
				c = c.darkened(0.25)
			return c
		T_PORTAL, T_PORTAL_LIT:
			# A swirl. Unlinked portals are dim and patchy; linked ones are bright and full.
			var lit := t == T_PORTAL_LIT
			var p := Vector2(fx + 0.5, fy + 0.5) - Vector2(8, 8)
			var swirl := sin(p.length() * 1.1 - atan2(p.y, p.x) * 2.0)
			var base := Color(0.62, 0.28, 0.95) if lit else Color(0.28, 0.16, 0.42)
			var c := base.lerp(Color(1.0, 0.55, 0.9) if lit else Color(0.45, 0.3, 0.6), (swirl + 1.0) * 0.5)
			if lit and swirl > 0.85:
				c = Color(1.0, 0.9, 1.0)
			if not lit and (x + y * 3) % 4 != 0 and swirl < 0.3:
				c = Color(0, 0, 0, 0)          # mostly see-through until it's linked
			return c
		T_CUTIE_ORE:
			# Cake with little gem sprinkles: pink, mint and sky-blue sparkles.
			var c := _shade(rng, Color(0.93, 0.78, 0.52), 0.05)
			if y == 7 or y == 8:
				c = _shade(rng, Color(0.95, 0.3, 0.35), 0.05)   # jam layer, like cake
			var gems := [[3, 3, Color(1.0, 0.45, 0.75)], [11, 2, Color(0.5, 1.0, 0.85)], [7, 11, Color(0.55, 0.8, 1.0)],
					[13, 12, Color(1.0, 0.45, 0.75)], [2, 12, Color(0.8, 0.6, 1.0)], [9, 5, Color(0.5, 1.0, 0.85)]]
			for g in gems:
				var dx: int = absi(x - int(g[0]))
				var dy: int = absi(y - int(g[1]))
				if dx + dy <= 1:
					c = g[2] if dx + dy == 1 else Color(g[2]).lightened(0.55)   # a little diamond, bright in the middle
			return c
		T_CUTE_CRAFTER_SIDE:
			var c := _plank_pixel(rng, Color(0.98, 0.78, 0.86), x, y)
			if edge:
				c = Color(0.85, 0.5, 0.7)
			# a big heart
			var hx := x - 7.5
			var hy := y - 7.0
			var heart := pow(hx * hx / 30.0 + hy * hy / 30.0 - 1.0, 3.0) - (hx * hx / 30.0) * pow(hy / 5.5, 3.0) < 0.0
			if heart:
				c = Color(1.0, 0.42, 0.62) if (x + y) % 5 != 0 else Color(1.0, 0.75, 0.85)
			return c
		T_CUTE_CRAFTER_TOP:
			var c := _plank_pixel(rng, Color(0.98, 0.78, 0.86), x, y)
			if edge or x % 5 == 0 or y % 5 == 0:
				c = Color(0.85, 0.5, 0.7)
			if (x == 2 and y == 2) or (x == 12 and y == 12) or (x == 12 and y == 2) or (x == 2 and y == 12):
				c = Color(0.55, 0.85, 1.0)      # little gems in the corners
			return c
		T_BOOKSHELF:
			if y <= 1 or y >= 14 or y == 7 or y == 8:
				return _plank_pixel(rng, WOOD_COLORS["oak"][2], x, y)   # shelves
			if x == 0 or x == 15:
				return WOOD_COLORS["oak"][0]
			var book_cols := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.25, 0.55, 0.3), Color(0.8, 0.65, 0.25), Color(0.5, 0.3, 0.55)]
			var book := (x / 2 + (y / 8) * 3) % book_cols.size()
			var bc: Color = book_cols[book]
			if (x % 2) == 1:
				bc = bc.darkened(0.2)
			if (y % 7) == 3 and x % 2 == 0:
				bc = bc.lightened(0.35)          # a title on the spine
			return bc
		T_STONE_BRICKS:
			return _brick_pixel(rng, x, y, stone)
		T_CHISELED:
			var c := _brick_pixel(rng, x, y, stone)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d > 3.5 and d < 5.2:
				c = Color(0.4, 0.4, 0.42)
			elif d < 2.0:
				c = stone.lightened(0.15)
			return c
		T_PILLAR_SIDE:
			var c := _shade(rng, stone.lightened(0.08), 0.03)
			if x % 4 == 0:
				c = c.darkened(0.2)              # grooves running up and down
			if y <= 1 or y >= 14:
				c = stone.darkened(0.1)
			return c
		T_PILLAR_TOP:
			var c := _shade(rng, stone.lightened(0.08), 0.03)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if edge or (d > 5.0 and d < 6.0):
				c = c.darkened(0.2)
			return c
		T_CARVED_SANDSTONE:
			var c := _shade(rng, Color(0.85, 0.75, 0.5), 0.04)
			if y == 2 or y == 13:
				c = c.darkened(0.15)
			# a little sun carved in the middle
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			if d < 2.5 or (d < 4.5 and (x == 7 or x == 8 or y == 7 or y == 8)):
				c = c.darkened(0.25)
			return c
		T_SAWMILL_SIDE:
			var c := _plank_pixel(rng, WOOD_COLORS["oak"][2], x, y)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 9))
			if d < 5.0:
				c = Color(0.78, 0.8, 0.84) if d > 1.5 else Color(0.45, 0.45, 0.5)   # a round saw blade
				if d > 4.0 and int(atan2(y - 9.0, x - 8.0) * 4.0) % 2 == 0:
					c = Color(0.95, 0.95, 0.98)  # teeth
			if y <= 1:
				c = Color(0.85, 0.52, 0.3)       # copper trim
			return c
		T_SAWMILL_TOP:
			var c := _plank_pixel(rng, WOOD_COLORS["oak"][2], x, y)
			if x == 7 or x == 8:
				c = Color(0.82, 0.84, 0.88) if y > 2 and y < 13 else c   # the blade sticking up
			if edge:
				c = WOOD_COLORS["oak"][0]
			return c
		T_STONECUTTER_SIDE:
			var c := _cobble_pixel(rng, cells, shades, fx, fy)
			if y <= 2:
				c = Color(0.72, 0.72, 0.75)       # iron top edge
			if y >= 6 and y <= 9 and x >= 2 and x <= 13:
				c = Color(0.3, 0.3, 0.33)         # the slot
			return c
		T_STONECUTTER_TOP:
			var c := _shade(rng, Color(0.72, 0.72, 0.75), 0.03)
			if edge:
				c = c.darkened(0.25)
			if y == 7 or y == 8:
				c = Color(0.9, 0.9, 0.95) if x > 1 and x < 14 else c   # the blade
			return c
		T_SHAPER_SIDE:
			var c := _shade(rng, Color(0.62, 0.62, 0.66), 0.03)
			if edge:
				c = c.darkened(0.3)
			# an anvil shape
			if (y >= 4 and y <= 6 and x >= 2 and x <= 13) or (y >= 7 and y <= 10 and x >= 6 and x <= 9) or (y >= 11 and y <= 12 and x >= 4 and x <= 11):
				c = Color(0.3, 0.3, 0.34)
			if y == 1 or y == 2:
				c = Color(0.58, 0.75, 0.95)       # titanium trim
			return c
		T_DEEPSTONE:
			# Dark blue-gray stone in thin layers.
			var c := _shade(rng, DEEP_GRAY, 0.07)
			if (y + (x / 5)) % 5 == 0:
				c = c.darkened(0.14)
			elif rng.randf() < 0.06:
				c = c.lightened(0.12)
			return c
		T_BEDSTONE:
			# Very hard, nearly black rock with rusty cracks running through it.
			var g := rng.randf_range(0.13, 0.24)
			var c := Color(g, g, g * 1.08)
			var crack := absi((x * 3 + y * 7) % 13 - 6) == 0 or absi((x * 5 - y * 3 + 40) % 17 - 8) == 0
			if crack:
				c = _shade(rng, Color(0.42, 0.26, 0.16), 0.05)
			return c
		T_LAVA:
			# Glowing orange lava with yellow-hot swirls and dark crust.
			var w := sin(x * 0.9 + sin(y * 0.7) * 2.0) + sin(y * 0.8 + cos(x * 0.5) * 2.0)
			var c := Color(1.0, 0.42, 0.06).lerp(Color(1.0, 0.86, 0.3), clampf(w * 0.5, 0.0, 1.0))
			if w < -1.2:
				c = Color(0.55, 0.12, 0.04)
			return _shade(rng, c, 0.04)
		T_CINDERSTONE:
			# Glassy black-purple stone with little embers still glowing inside.
			var c := _shade(rng, Color(0.16, 0.11, 0.2), 0.05)
			if (x * 7 + y * 3) % 11 == 0:
				c = Color(0.32, 0.24, 0.42)            # glassy shine
			if (x * 5 + y * 13) % 29 == 0:
				c = Color(1.0, 0.5, 0.12)              # an ember
			if edge:
				c = c.darkened(0.2)
			return c
		T_JEWEL_TOP:
			# Purple velvet in a gold frame, with one of each gem laid out on it.
			var c := _shade(rng, Color(0.42, 0.16, 0.5), 0.04)
			if edge or x == 1 or y == 1 or x == 14 or y == 14:
				c = _shade(rng, Color(0.98, 0.78, 0.3), 0.05)
			var spots := [Vector2i(4, 4), Vector2i(11, 4), Vector2i(7, 8), Vector2i(4, 11), Vector2i(11, 11)]
			for gi in spots.size():
				var sp: Vector2i = spots[gi]
				if absi(x - sp.x) + absi(y - sp.y) <= 1:
					c = GEMS[gi][3] if gi != 3 else Color(0.1, 0.08, 0.12)
					if x == sp.x and y == sp.y - 1:
						c = c.lightened(0.5)
			return c
		T_JEWEL_SIDE:
			# Dark wood with a gold band and a little drawer.
			var c := _plank_pixel(rng, Color(0.36, 0.22, 0.14), x, y)
			if y <= 1:
				c = Color(0.98, 0.78, 0.3)
			if x >= 5 and x <= 10 and y >= 7 and y <= 11:
				c = Color(0.48, 0.3, 0.18) if not (x == 5 or x == 10 or y == 7 or y == 11) else Color(0.25, 0.15, 0.08)
				if y == 9 and (x == 7 or x == 8):
					c = Color(0.98, 0.78, 0.3)         # the drawer's handle
			return c
		T_MAGMA:
			# Dark red-black rock split by glowing orange cracks.
			var c := _shade(rng, Color(0.24, 0.1, 0.08), 0.06)
			var crack := absi((x * 3 + y * 5) % 11 - 5) == 0 or absi((x * 7 - y * 2 + 30) % 13 - 6) == 0
			if crack:
				c = Color(1.0, 0.45, 0.1) if (x + y) % 3 != 0 else Color(1.0, 0.75, 0.25)
			elif rng.randf() < 0.05:
				c = c.lightened(0.15)
			return c
		T_GLOW_CRYSTAL:
			# A cluster of glowing crystal spikes (the background is see-through).
			for spike in [[4, 9, 2], [8, 3, 2], [12, 7, 1], [6, 6, 1], [10, 10, 1]]:
				var cx: int = spike[0]
				var top: int = spike[1]
				var hw: int = spike[2]
				if y >= top and y <= 15 and absi(x - cx) <= hw + (y - top) / 6:
					var c := Color(0.55, 0.95, 1.0) if (spike[0] + spike[1]) % 2 == 0 else Color(0.8, 0.6, 1.0)
					return c.lightened(0.35) if x == cx else c
			return Color(0, 0, 0, 0)
		T_SHAPER_TOP:
			var c := _shade(rng, Color(0.62, 0.62, 0.66), 0.03)
			if edge:
				c = c.darkened(0.3)
			if x >= 4 and x <= 11 and y >= 4 and y <= 11:
				c = Color(0.38, 0.38, 0.42)
			if (x == 6 or x == 9) and y >= 5 and y <= 10:
				c = Color(1.0, 0.6, 0.25)         # glowing hot metal
			return c
	return Color.MAGENTA


static func _plank_pixel(rng: RandomNumberGenerator, base: Color, x: int, y: int) -> Color:
	var board := y / 4
	var c := _shade(rng, base, 0.05)
	if y % 4 == 3 or x == (board * 5 + 3) % BASE_PX:
		c = c.darkened(0.28)
	return c


static func _cobble_pixel(rng: RandomNumberGenerator, cells: Array[Vector2], shades: Array[float], x: float, y: float) -> Color:
	var s := float(BASE_PX)
	var p := Vector2(x + 0.5, y + 0.5)
	var d1 := INF
	var d2 := INF
	var best := 0
	for i in cells.size():
		# Wrap-around distance so the texture tiles seamlessly.
		var dx := absf(p.x - cells[i].x)
		var dy := absf(p.y - cells[i].y)
		dx = minf(dx, s - dx)
		dy = minf(dy, s - dy)
		var d := sqrt(dx * dx + dy * dy)
		if d < d1:
			d2 = d1
			d1 = d
			best = i
		elif d < d2:
			d2 = d
	if d2 - d1 < 1.0:
		return Color(0.28, 0.28, 0.28)
	var g := shades[best]
	return _shade(rng, Color(g, g, g), 0.06)
