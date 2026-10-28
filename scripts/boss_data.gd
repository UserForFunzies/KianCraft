extends RefCounted
## Every boss, in the order you're meant to beat them (one per biome), with
## the power its trophy unlocks at the spawn shrine. The spawn shrine has a
## statue for each, plus a few empty ones for bosses still to come.
##
## A power lasts POWER_SECONDS, then needs POWER_COOLDOWN before you can use
## it again (like Valheim's Forsaken powers). "buff" adds to one of the usual
## buff types (see survival._buff_power); "special" is handled where it matters.

const POWER_SECONDS := 300.0
const POWER_COOLDOWN := 1200.0
const SHRINE_SLOTS := 12

const BOSSES := [
	{"id": "boar_king", "mob": "boar_king", "name": "Boar King", "biome": "plains", "lair": "a ring of standing stones in the meadows",
		"color": Color(0.55, 0.36, 0.25), "power": "Charge", "buff": "speed", "amount": 0.3, "text": "Run 30% faster"},
	{"id": "oakheart", "mob": "oakheart", "name": "Old Oakheart", "biome": "forest", "lair": "a giant hollow tree in the forest",
		"color": Color(0.45, 0.32, 0.18), "power": "Regrowth", "buff": "regen", "amount": 2.0, "text": "Heal three times as fast"},
	{"id": "king_cougar", "mob": "king_cougar", "name": "King Cougar", "biome": "desert", "lair": "a sandstone temple in the desert",
		"color": Color(0.85, 0.62, 0.3), "power": "Pounce", "buff": "jump", "amount": 0.4, "special": "no_fall", "text": "Jump higher, and falling never hurts"},
	{"id": "gummy_giant", "mob": "gummy_giant", "name": "Gummy Giant", "biome": "candy", "lair": "a gingerbread fort in candy land",
		"color": Color(0.95, 0.35, 0.5), "power": "Bouncy", "buff": "toughness", "amount": 0.4, "text": "Take 40% less damage"},
	{"id": "scarecrow_king", "mob": "scarecrow_king", "name": "Scarecrow King", "biome": "fall", "lair": "a cornfield maze in the fall forest",
		"color": Color(0.9, 0.62, 0.2), "power": "Harvest", "special": "harvest", "text": "Monsters and animals drop twice as much"},
	{"id": "yeti", "mob": "yeti", "name": "Yeti", "biome": "mountain", "lair": "a deep mine in the mountains",
		"color": Color(0.85, 0.92, 1.0), "power": "Yeti Strength", "buff": "strength", "amount": 0.25, "text": "Hit 25% harder"},
	{"id": "lantern_witch", "mob": "lantern_witch", "name": "Lantern Witch", "biome": "spooky", "lair": "a crypt in the spooky forest",
		"color": Color(0.55, 0.85, 0.6), "power": "Night Eyes", "special": "night_eyes", "text": "See in the dark, and monsters only notice you from half as far"},
	{"id": "grimskull", "mob": "grimskull", "name": "Grimskull", "biome": "sky", "lair": "the castle on the floating islands",
		"color": Color(0.35, 0.3, 0.4), "power": "Fire & Ice", "buff": "strength", "amount": 0.15, "special": "arrow_ward", "text": "Hit 15% harder, and arrows only hurt half as much"},
	{"id": "chess_royals", "mob": "white_king", "mob2": "white_queen", "mobs": ["white_king", "white_queen", "black_king", "black_queen"],
		"name": "King & Queen", "biome": "chess", "lair": "the black and white castle",
		"color": Color(0.92, 0.92, 0.95), "power": "Royal Command", "buff": "haste", "amount": 0.3, "text": "Swing and mine 30% faster"},
	{"id": "clown", "mob": "clown", "name": "Chuckles the Clown", "biome": "fastfood", "lair": "the circus tent in fast food land",
		"color": Color(0.95, 0.3, 0.3), "power": "Party Time", "buff": "speed", "amount": 0.3, "text": "Run 30% faster"},
	{"id": "fire_giant", "mob": "fire_giant", "name": "Fire Giant", "biome": "deep", "lair": "the lava caverns deep below",
		"color": Color(1.0, 0.45, 0.1), "power": "Fire Walk", "buff": "fireproof", "amount": 1.0, "text": "Fire and lava can't hurt you"},
]


static func get_boss(id: String) -> Dictionary:
	for b in BOSSES:
		if b["id"] == id:
			return b
	return {}


static func boss_for_mob(mob_type: String) -> Dictionary:
	for b in BOSSES:
		if b["mob"] == mob_type or mob_type in b.get("mobs", []):
			return b
	return {}


static func trophy_id(boss_id: String) -> String:
	return "trophy_" + boss_id
