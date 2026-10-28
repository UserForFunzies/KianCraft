extends RefCounted
## A blocky person: legs, body, arms and head, plus armor that shows up when
## worn (helmet, chestplate, leggings, boots, or the legendary crown).
## Used for other players in the world and for the character window.
##
## build() returns a Dictionary of the parts so callers can animate them:
##   root, head (pivot at eye height), arm_l, arm_r, leg_l, leg_r

const Items = preload("res://scripts/items.gd")

const Skins = preload("res://scripts/skins.gd")
const SKIN := Color(0.95, 0.8, 0.65)
const EYE_HEIGHT := 1.62

# --- The look catalog ----------------------------------------------------------------
# A look is a Dictionary of numbers: which skin, hair, face, top, bottom and
# shoes, and their colors. Characters save it; players send it to each other.

const SKINS := [Color(1.0, 0.86, 0.74), Color(0.95, 0.8, 0.65), Color(0.86, 0.66, 0.5),
		Color(0.72, 0.52, 0.36), Color(0.55, 0.38, 0.25), Color(0.38, 0.26, 0.18),
		Color(0.62, 0.86, 0.55), Color(0.62, 0.8, 0.98), Color(0.85, 0.7, 0.98)]   # (and three fun ones: alien green, ice blue, fairy purple)
const HAIR := ["Short", "Spiky", "Long", "Ponytail", "Pigtails", "Buns", "Bob", "Mohawk",
		"Curly", "Bald", "Cap", "Bunny Ears", "Party Hat", "Afro", "Side Swoop", "Top Knot", "Beanie",
		"Braids", "Flower Crown", "Cat Ears", "Wizard Hat", "Shaved Sides", "Warrior Braid", "Wild Mane", "Battle Topknot"]
const HAIR_COLORS := [Color(0.33, 0.21, 0.12), Color(0.1, 0.09, 0.1), Color(0.95, 0.82, 0.45),
		Color(0.78, 0.36, 0.18), Color(0.92, 0.92, 0.95), Color(1.0, 0.55, 0.78), Color(0.3, 0.55, 0.95),
		Color(0.6, 0.38, 0.9), Color(0.35, 0.8, 0.45), Color(0.2, 0.75, 0.75), Color(0.7, 0.72, 0.78),
		Color(0.98, 0.95, 0.75), Color(0.85, 0.15, 0.2)]
const FACES := ["Smile", "Happy", "Big Eyes", "Sleepy", "Freckles", "Sunglasses", "Silly Tongue",
		"Grumpy", "Wink", "Rosy Cheeks", "Surprised", "Cat Face", "Starry Eyes", "Mustache", "Determined", "Robot",
		"Scowl", "War Cry", "Battle Weary", "One-Eyed", "Full Beard"]
const TOPS := ["T-Shirt", "Hoodie", "Striped", "Dress", "Tank Top", "Jacket", "Overalls",
		"Sweater", "Superhero", "Tuxedo", "Polo", "Flannel", "Rainbow", "Lab Coat", "Space Suit", "Knight Tabard",
		"Worn Tunic", "Fur Vest", "Chainmail Shirt", "Torn Shirt"]
const BOTTOMS := ["Pants", "Shorts", "Skirt", "Jeans", "Striped", "Leggings", "Cargo Shorts", "Tutu", "Space Pants",
		"Torn Pants", "Fur Leggings", "Battle Kilt"]
const SHOES := ["Sneakers", "Boots", "Sandals", "Bunny Slippers", "Rain Boots", "High Tops", "Flip Flops",
		"Roller Skates", "Cowboy Boots", "Fur Boots", "Worn Boots"]
const EYES := [Color(0.25, 0.45, 0.7), Color(0.3, 0.6, 0.3), Color(0.42, 0.27, 0.15), Color(0.55, 0.5, 0.25),
		Color(0.55, 0.3, 0.8), Color(0.45, 0.48, 0.52), Color(0.9, 0.6, 0.15), Color(0.85, 0.25, 0.4)]
const EXTRAS := ["Nothing", "Backpack", "Scarf", "Headphones", "Hair Bow", "Glasses", "Bandana",
		"Fairy Wings", "Bow Tie", "Star Badge", "Eyepatch", "Bandages", "Fur Mantle", "War Horns", "Battle Sash", "Quiver"]
## Battle-worn looks: scars, and war paint (in a color).
const SCARS := ["None", "Cheek Scar", "Eye Scar", "Cross Scar", "Chin Scar", "Stitches", "Burn Mark", "Claw Marks", "Broken Nose"]
const WARPAINT := ["None", "Stripes", "Skull", "Slash", "Tribal", "Mask", "Ash Smudges"]
const COLORS := [Color(0.85, 0.22, 0.25), Color(0.95, 0.55, 0.2), Color(0.98, 0.85, 0.3),
		Color(0.35, 0.72, 0.38), Color(0.25, 0.65, 0.7), Color(0.28, 0.45, 0.85), Color(0.5, 0.32, 0.8),
		Color(0.95, 0.5, 0.72), Color(0.95, 0.95, 0.95), Color(0.55, 0.57, 0.62), Color(0.15, 0.16, 0.2),
		Color(0.45, 0.3, 0.2), Color(0.2, 0.3, 0.55), Color(0.55, 0.75, 0.95), Color(0.15, 0.6, 0.55),
		Color(0.6, 0.85, 0.25), Color(0.5, 0.12, 0.2), Color(0.78, 0.68, 0.95)]

## Ready-made looks to start from: cute, cool, plain and silly.
const PRESETS := [
	{"name": "Sunny", "style": "Cute", "look": {"skin": 0, "hair": 4, "hair_color": 2, "face": 2, "top": 3, "top_color": 7, "bottom": 2, "bottom_color": 7, "shoes": 2, "shoe_color": 8}},
	{"name": "Bun Bun", "style": "Cute", "look": {"skin": 1, "hair": 5, "hair_color": 5, "face": 9, "top": 7, "top_color": 13, "bottom": 1, "bottom_color": 8, "shoes": 3, "shoe_color": 7}},
	{"name": "Ace", "style": "Cool", "look": {"skin": 2, "hair": 1, "hair_color": 1, "face": 5, "top": 5, "top_color": 10, "bottom": 3, "bottom_color": 12, "shoes": 1, "shoe_color": 10}},
	{"name": "Nova", "style": "Cool", "look": {"skin": 3, "hair": 3, "hair_color": 7, "face": 8, "top": 1, "top_color": 6, "bottom": 0, "bottom_color": 10, "shoes": 0, "shoe_color": 8}},
	{"name": "Sam", "style": "Plain", "look": {"skin": 1, "hair": 0, "hair_color": 0, "face": 0, "top": 0, "top_color": 5, "bottom": 0, "bottom_color": 12, "shoes": 0, "shoe_color": 11}},
	{"name": "Alex", "style": "Plain", "look": {"skin": 4, "hair": 6, "hair_color": 0, "face": 1, "top": 0, "top_color": 3, "bottom": 3, "bottom_color": 12, "shoes": 0, "shoe_color": 8}},
	{"name": "Captain Goof", "style": "Silly", "look": {"skin": 2, "hair": 12, "hair_color": 3, "face": 6, "top": 8, "top_color": 5, "bottom": 4, "bottom_color": 0, "shoes": 4, "shoe_color": 2}},
	{"name": "Pickle", "style": "Silly", "look": {"skin": 0, "hair": 7, "hair_color": 8, "face": 6, "top": 2, "top_color": 3, "bottom": 4, "bottom_color": 3, "shoes": 3, "shoe_color": 8}},
	{"name": "Bunny", "style": "Silly", "look": {"skin": 1, "hair": 11, "hair_color": 4, "face": 9, "top": 1, "top_color": 8, "bottom": 1, "bottom_color": 7, "shoes": 3, "shoe_color": 8}},
	{"name": "Dapper", "style": "Cool", "look": {"skin": 5, "hair": 8, "hair_color": 1, "face": 0, "top": 9, "top_color": 10, "bottom": 0, "bottom_color": 10, "shoes": 1, "shoe_color": 10}},
	{"name": "Astro", "style": "Cool", "look": {"skin": 2, "hair": 0, "hair_color": 1, "face": 12, "top": 14, "top_color": 8, "bottom": 8, "bottom_color": 8, "shoes": 1, "shoe_color": 9, "extra": 9, "extra_color": 5, "eye_color": 0}},
	{"name": "Ranger", "style": "Plain", "look": {"skin": 3, "hair": 13, "hair_color": 0, "face": 14, "top": 11, "top_color": 0, "bottom": 3, "bottom_color": 12, "shoes": 8, "shoe_color": 11, "extra": 1, "extra_color": 3, "eye_color": 2}},
	{"name": "Pixie", "style": "Cute", "look": {"skin": 8, "hair": 18, "hair_color": 5, "face": 9, "top": 3, "top_color": 17, "bottom": 7, "bottom_color": 7, "shoes": 2, "shoe_color": 7, "extra": 7, "extra_color": 13, "eye_color": 4}},
	{"name": "Zap", "style": "Silly", "look": {"skin": 6, "hair": 7, "hair_color": 6, "face": 15, "top": 12, "top_color": 0, "bottom": 5, "bottom_color": 6, "shoes": 7, "shoe_color": 2, "extra": 3, "extra_color": 10, "eye_color": 6}},
	{"name": "Sir Kian", "style": "Cool", "look": {"skin": 1, "hair": 6, "hair_color": 2, "face": 14, "top": 15, "top_color": 5, "bottom": 0, "bottom_color": 9, "shoes": 1, "shoe_color": 11, "extra": 0, "extra_color": 0, "eye_color": 0}},
	{"name": "Grizzled Knight", "style": "Battle", "look": {"skin": 2, "hair": 21, "hair_color": 10, "face": 20, "top": 18, "top_color": 9, "bottom": 11, "bottom_color": 16, "shoes": 10, "shoe_color": 11, "extra": 14, "extra_color": 16, "eye_color": 5, "scars": 2, "warpaint": 0, "paint_color": 0}},
	{"name": "Scar", "style": "Battle", "look": {"skin": 4, "hair": 23, "hair_color": 1, "face": 16, "top": 17, "top_color": 11, "bottom": 10, "bottom_color": 11, "shoes": 9, "shoe_color": 11, "extra": 12, "extra_color": 11, "eye_color": 6, "scars": 7, "warpaint": 1, "paint_color": 0}},
	{"name": "Warlord", "style": "Battle", "look": {"skin": 3, "hair": 22, "hair_color": 3, "face": 17, "top": 16, "top_color": 16, "bottom": 9, "bottom_color": 10, "shoes": 10, "shoe_color": 10, "extra": 13, "extra_color": 8, "eye_color": 2, "scars": 3, "warpaint": 2, "paint_color": 8}},
	{"name": "Wanderer", "style": "Battle", "look": {"skin": 1, "hair": 24, "hair_color": 0, "face": 18, "top": 19, "top_color": 11, "bottom": 9, "bottom_color": 12, "shoes": 10, "shoe_color": 11, "extra": 11, "extra_color": 8, "eye_color": 2, "scars": 5, "warpaint": 6, "paint_color": 10}},
	{"name": "Raider", "style": "Battle", "look": {"skin": 5, "hair": 21, "hair_color": 1, "face": 19, "top": 17, "top_color": 10, "bottom": 11, "bottom_color": 10, "shoes": 9, "shoe_color": 11, "extra": 15, "extra_color": 11, "eye_color": 0, "scars": 1, "warpaint": 4, "paint_color": 0}},
]

## Each part of the look: [key, display name, options list, color key or ""].
const PARTS := [
	["skin", "Skin", SKINS, ""],
	["hair", "Hair", HAIR, "hair_color"],
	["face", "Face", FACES, ""],
	["eye_color", "Eyes", EYES, ""],
	["top", "Top", TOPS, "top_color"],
	["bottom", "Bottom", BOTTOMS, "bottom_color"],
	["shoes", "Shoes", SHOES, "shoe_color"],
	["extra", "Extra", EXTRAS, "extra_color"],
	["scars", "Scars", SCARS, ""],
	["warpaint", "War Paint", WARPAINT, "paint_color"],
]
## Tabs in the character creator: [name, part keys].
const GROUPS := [["Body", ["skin", "eye_color"]], ["Hair", ["hair"]], ["Face", ["face", "eye_color"]],
		["Clothes", ["top", "bottom", "shoes"]], ["Extras", ["extra"]], ["Battle", ["scars", "warpaint"]]]


static func default_look(top_color := -1) -> Dictionary:
	var look: Dictionary = PRESETS[4]["look"].duplicate()
	for k in ["eye_color", "extra", "extra_color", "scars", "warpaint", "paint_color"]:
		look[k] = look.get(k, 0)
	if top_color >= 0:
		look["top_color"] = top_color
	return look


static func random_look() -> Dictionary:
	return {"skin": randi() % SKINS.size(), "hair": randi() % HAIR.size(), "hair_color": randi() % HAIR_COLORS.size(),
		"face": randi() % FACES.size(), "top": randi() % TOPS.size(), "top_color": randi() % COLORS.size(),
		"bottom": randi() % BOTTOMS.size(), "bottom_color": randi() % COLORS.size(),
		"shoes": randi() % SHOES.size(), "shoe_color": randi() % COLORS.size(),
		"eye_color": randi() % EYES.size(), "extra": randi() % EXTRAS.size() if randf() < 0.6 else 0, "extra_color": randi() % COLORS.size(),
		"scars": randi() % SCARS.size() if randf() < 0.2 else 0, "warpaint": randi() % WARPAINT.size() if randf() < 0.12 else 0, "paint_color": randi() % COLORS.size()}


## Fills in anything missing and keeps every number in range.
static func clean_look(look: Dictionary) -> Dictionary:
	var out := default_look()
	for k in out:
		if look.has(k):
			out[k] = int(look[k])
	var ranges := {"skin": SKINS.size(), "hair": HAIR.size(), "hair_color": HAIR_COLORS.size(), "face": FACES.size(),
			"top": TOPS.size(), "top_color": COLORS.size(), "bottom": BOTTOMS.size(), "bottom_color": COLORS.size(),
			"shoes": SHOES.size(), "shoe_color": COLORS.size(), "eye_color": EYES.size(), "extra": EXTRAS.size(),
			"extra_color": COLORS.size(), "scars": SCARS.size(), "warpaint": WARPAINT.size(), "paint_color": COLORS.size()}
	for k in ranges:
		out[k] = posmod(out[k], ranges[k])
	return out


static func shirt_color(look: Dictionary) -> Color:
	return COLORS[clean_look(look)["top_color"]]


static func skin_color(look: Dictionary) -> Color:
	return SKINS[clean_look(look)["skin"]]


## A material for a part of a character. kind: what it's made of (see skins.gd):
## clothes are "cloth", skin "skin", hair "hair", shoes "leather"...
static func _mat(c: Color, kind := "cloth") -> StandardMaterial3D:
	return Skins.material_copy(c, kind)


## A flat color (tiny face details stay crisp).
static func _flat(c: Color) -> StandardMaterial3D:
	return Skins.material_copy(c, "plain")


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


## look: a look Dictionary (or just a Color for the shirt, for old callers).
## head_pivot: pass a node to hang the head on (the player's camera pivot),
## or null to make one.
static func build(look_in: Variant, head_pivot: Node3D = null) -> Dictionary:
	var look := clean_look(look_in) if look_in is Dictionary else default_look()
	var top_c: Color = look_in if look_in is Color else COLORS[look["top_color"]]
	var bottom_c: Color = COLORS[look["bottom_color"]]
	var shoe_c: Color = COLORS[look["shoe_color"]]
	var hair_c: Color = HAIR_COLORS[look["hair_color"]]
	var skin_c: Color = SKINS[look["skin"]]
	var root := Node3D.new()
	var top := _mat(top_c)
	var top_dark := _mat(top_c.darkened(0.25))
	var top_light := _mat(top_c.lightened(0.3))
	var skin := _mat(skin_c, "skin")
	var skin_shade := _mat(skin_c.darkened(0.12), "skin")
	var bottom := _mat(bottom_c)
	var bottom_dark := _mat(bottom_c.darkened(0.25))
	var bottom_light := _mat(bottom_c.lightened(0.3))
	var shoe := _mat(shoe_c, "leather")
	var sole := _mat(Color(0.12, 0.1, 0.09), "leather")
	var white := _mat(Color(0.97, 0.97, 0.97))
	var black := _mat(Color(0.08, 0.08, 0.1))
	var gold := _mat(Color(0.95, 0.78, 0.3), "metal")
	var hair := _mat(hair_c, "hair")
	var parts := {"root": root, "look": look}
	var top_style: int = look["top"]
	var bottom_style: int = look["bottom"]
	var dress := top_style == 3

	# --- Legs: bottoms + shoes -----------------------------------------------------
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.position = Vector3(0.13 * side, 0.75, 0)
		match bottom_style:
			1:  # shorts
				_box(leg, Vector3(0.245, 0.28, 0.265), Vector3(0, -0.14, 0), bottom)
				_box(leg, Vector3(0.22, 0.36, 0.24), Vector3(0, -0.44, 0), skin)
			2:  # skirt (legs are skin, the skirt hangs from the hips)
				_box(leg, Vector3(0.22, 0.62, 0.24), Vector3(0, -0.31, 0), skin)
			3:  # jeans
				_box(leg, Vector3(0.24, 0.62, 0.26), Vector3(0, -0.31, 0), bottom)
				_box(leg, Vector3(0.25, 0.06, 0.27), Vector3(0, -0.58, 0), bottom_light)
			4:  # striped
				for k in 5:
					_box(leg, Vector3(0.24, 0.125, 0.26), Vector3(0, -0.06 - k * 0.125, 0), bottom if k % 2 == 0 else white)
			5:  # leggings: snug, with a stripe down the side
				_box(leg, Vector3(0.225, 0.62, 0.245), Vector3(0, -0.31, 0), bottom)
				_box(leg, Vector3(0.03, 0.6, 0.25), Vector3(0.11 * side, -0.31, 0), bottom_light)
			6:  # cargo shorts with side pockets
				_box(leg, Vector3(0.25, 0.34, 0.27), Vector3(0, -0.17, 0), bottom)
				_box(leg, Vector3(0.03, 0.12, 0.14), Vector3(0.13 * side, -0.24, 0), bottom_dark)
				_box(leg, Vector3(0.22, 0.3, 0.24), Vector3(0, -0.47, 0), skin)
			7:  # tutu over tights
				_box(leg, Vector3(0.22, 0.62, 0.24), Vector3(0, -0.31, 0), white)
			8:  # space pants: puffy, with knee pads
				_box(leg, Vector3(0.27, 0.62, 0.29), Vector3(0, -0.31, 0), bottom)
				_box(leg, Vector3(0.2, 0.12, 0.03), Vector3(0, -0.3, -0.155), _mat(Color(0.55, 0.57, 0.62)))
			9:  # torn pants: ragged at the shin, a patch on the knee
				_box(leg, Vector3(0.24, 0.48, 0.26), Vector3(0, -0.24, 0), bottom)
				_box(leg, Vector3(0.22, 0.16, 0.24), Vector3(0, -0.55, 0), skin)
				for k in 3:
					_box(leg, Vector3(0.06, 0.05 + k * 0.02, 0.265), Vector3(-0.08 + k * 0.08, -0.5 - k * 0.015, 0), bottom)
				_box(leg, Vector3(0.1, 0.1, 0.02), Vector3(0.03 * side, -0.28, -0.135), _mat(bottom_c.darkened(0.35)))
			10:  # fur leggings bound with straps
				_box(leg, Vector3(0.26, 0.62, 0.28), Vector3(0, -0.31, 0), _mat(bottom_c, "fur"))
				for y in [-0.18, -0.38]:
					_box(leg, Vector3(0.27, 0.03, 0.29), Vector3(0, y, 0), _mat(Color(0.3, 0.2, 0.12), "leather"))
			11:  # battle kilt over bare knees
				_box(leg, Vector3(0.22, 0.62, 0.24), Vector3(0, -0.31, 0), skin)
			_:  # pants
				_box(leg, Vector3(0.24, 0.62, 0.26), Vector3(0, -0.31, 0), bottom)
				_box(leg, Vector3(0.245, 0.04, 0.265), Vector3(0, -0.58, 0), bottom_dark)
		match look["shoes"]:
			1:  # boots
				_box(leg, Vector3(0.26, 0.22, 0.3), Vector3(0, -0.6, -0.02), shoe)
				_box(leg, Vector3(0.27, 0.04, 0.31), Vector3(0, -0.73, -0.02), sole)
			2:  # sandals
				_box(leg, Vector3(0.23, 0.08, 0.28), Vector3(0, -0.68, -0.02), skin)
				_box(leg, Vector3(0.24, 0.03, 0.3), Vector3(0, -0.735, -0.02), shoe)
				_box(leg, Vector3(0.245, 0.03, 0.06), Vector3(0, -0.66, -0.09), shoe)
			3:  # bunny slippers
				_box(leg, Vector3(0.3, 0.13, 0.36), Vector3(0, -0.68, -0.04), shoe)
				_box(leg, Vector3(0.05, 0.12, 0.03), Vector3(-0.06, -0.57, -0.17), shoe)
				_box(leg, Vector3(0.05, 0.12, 0.03), Vector3(0.06, -0.57, -0.17), shoe)
				_box(leg, Vector3(0.04, 0.04, 0.02), Vector3(-0.05, -0.65, -0.225), black)
				_box(leg, Vector3(0.04, 0.04, 0.02), Vector3(0.05, -0.65, -0.225), black)
			4:  # rain boots
				_box(leg, Vector3(0.27, 0.3, 0.3), Vector3(0, -0.57, -0.02), shoe)
				_box(leg, Vector3(0.28, 0.04, 0.31), Vector3(0, -0.42, -0.02), _mat(shoe_c.lightened(0.3)))
			5:  # high tops
				_box(leg, Vector3(0.26, 0.2, 0.3), Vector3(0, -0.62, -0.02), shoe)
				_box(leg, Vector3(0.27, 0.035, 0.31), Vector3(0, -0.73, -0.02), white)
				_box(leg, Vector3(0.1, 0.1, 0.02), Vector3(0, -0.6, -0.17), white)
				_box(leg, Vector3(0.265, 0.03, 0.305), Vector3(0, -0.53, -0.02), white)
			6:  # flip flops
				_box(leg, Vector3(0.23, 0.1, 0.27), Vector3(0, -0.67, -0.02), skin)
				_box(leg, Vector3(0.25, 0.03, 0.31), Vector3(0, -0.735, -0.02), shoe)
				_box(leg, Vector3(0.03, 0.05, 0.1), Vector3(0, -0.7, -0.1), shoe)
			7:  # roller skates
				_box(leg, Vector3(0.26, 0.22, 0.3), Vector3(0, -0.58, -0.02), shoe)
				_box(leg, Vector3(0.2, 0.04, 0.32), Vector3(0, -0.71, -0.02), _mat(Color(0.6, 0.6, 0.65)))
				for wz in [-0.11, 0.09]:
					_box(leg, Vector3(0.22, 0.07, 0.07), Vector3(0, -0.76, wz), _mat(Color(0.95, 0.4, 0.6)))
			8:  # cowboy boots
				_box(leg, Vector3(0.26, 0.32, 0.3), Vector3(0, -0.56, -0.02), shoe)
				_box(leg, Vector3(0.27, 0.05, 0.32), Vector3(0, -0.73, -0.03), _mat(shoe_c.darkened(0.4)))
				_box(leg, Vector3(0.1, 0.12, 0.02), Vector3(0, -0.5, -0.17), _mat(shoe_c.lightened(0.3)))
			9:  # fur boots
				_box(leg, Vector3(0.28, 0.26, 0.32), Vector3(0, -0.6, -0.02), _mat(shoe_c, "fur"))
				_box(leg, Vector3(0.3, 0.07, 0.34), Vector3(0, -0.46, -0.02), _mat(shoe_c.lightened(0.25), "fur"))
				_box(leg, Vector3(0.28, 0.03, 0.32), Vector3(0, -0.73, -0.02), sole)
			10:  # worn boots: scuffed, with a strap
				_box(leg, Vector3(0.26, 0.24, 0.3), Vector3(0, -0.6, -0.02), _mat(shoe_c.darkened(0.15), "leather"))
				_box(leg, Vector3(0.27, 0.03, 0.31), Vector3(0, -0.56, -0.02), _mat(Color(0.35, 0.3, 0.25), "leather"))
				_box(leg, Vector3(0.27, 0.04, 0.31), Vector3(0, -0.73, -0.02), sole)
				_box(leg, Vector3(0.08, 0.05, 0.02), Vector3(0.05, -0.66, -0.17), _mat(shoe_c.lightened(0.2), "leather"))
			_:  # sneakers
				_box(leg, Vector3(0.25, 0.1, 0.3), Vector3(0, -0.66, -0.02), shoe)
				_box(leg, Vector3(0.26, 0.035, 0.31), Vector3(0, -0.73, -0.02), white)
				_box(leg, Vector3(0.1, 0.02, 0.06), Vector3(0, -0.6, -0.14), white)
		root.add_child(leg)
		parts["leg_l" if side < 0 else "leg_r"] = leg

	# --- Body: the top -------------------------------------------------------------
	_box(root, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.09, 0), top)
	match top_style:
		1:  # hoodie: hood, pocket, strings
			_box(root, Vector3(0.44, 0.22, 0.12), Vector3(0, 1.36, 0.17), top_dark)
			_box(root, Vector3(0.3, 0.14, 0.02), Vector3(0, 0.92, -0.145), top_dark)
			_box(root, Vector3(0.02, 0.12, 0.02), Vector3(-0.06, 1.28, -0.145), white)
			_box(root, Vector3(0.02, 0.12, 0.02), Vector3(0.06, 1.28, -0.145), white)
		2:  # stripes
			for k in 3:
				_box(root, Vector3(0.505, 0.07, 0.285), Vector3(0, 0.92 + k * 0.17, 0), white)
		3:  # dress: a flared skirt
			_box(root, Vector3(0.58, 0.36, 0.36), Vector3(0, 0.66, 0), top)
			_box(root, Vector3(0.6, 0.04, 0.38), Vector3(0, 0.5, 0), top_light)
			_box(root, Vector3(0.52, 0.05, 0.3), Vector3(0, 0.85, 0), top_light)
		4:  # tank top: straps only
			_box(root, Vector3(0.505, 0.15, 0.285), Vector3(0, 1.33, 0), skin)
			_box(root, Vector3(0.06, 0.15, 0.29), Vector3(-0.14, 1.33, 0), top)
			_box(root, Vector3(0.06, 0.15, 0.29), Vector3(0.14, 1.33, 0), top)
		5:  # jacket: open front with a white shirt and lapels
			_box(root, Vector3(0.14, 0.6, 0.02), Vector3(0, 1.09, -0.145), white)
			_box(root, Vector3(0.05, 0.2, 0.025), Vector3(-0.09, 1.28, -0.147), top_dark)
			_box(root, Vector3(0.05, 0.2, 0.025), Vector3(0.09, 1.28, -0.147), top_dark)
		6:  # overalls over a white shirt
			_box(root, Vector3(0.505, 0.38, 0.285), Vector3(0, 1.21, 0), white)
			_box(root, Vector3(0.3, 0.3, 0.29), Vector3(0, 1.0, 0), top)
			_box(root, Vector3(0.05, 0.25, 0.29), Vector3(-0.12, 1.25, 0), top)
			_box(root, Vector3(0.05, 0.25, 0.29), Vector3(0.12, 1.25, 0), top)
			_box(root, Vector3(0.04, 0.04, 0.02), Vector3(-0.12, 1.14, -0.15), gold)
			_box(root, Vector3(0.04, 0.04, 0.02), Vector3(0.12, 1.14, -0.15), gold)
		7:  # sweater with a zigzag band
			for k in 5:
				_box(root, Vector3(0.1, 0.06, 0.02), Vector3(-0.2 + k * 0.1, 1.16 + (0.03 if k % 2 else -0.03), -0.145), top_light)
			_box(root, Vector3(0.52, 0.06, 0.3), Vector3(0, 0.81, 0), top_dark)
		8:  # superhero: a star and a cape
			_box(root, Vector3(0.14, 0.14, 0.02), Vector3(0, 1.15, -0.145), gold)
			_box(root, Vector3(0.48, 0.95, 0.03), Vector3(0, 0.95, 0.16), _mat(Color(0.85, 0.15, 0.2)))
		9:  # tuxedo: black jacket, white shirt, bow tie
			_box(root, Vector3(0.505, 0.62, 0.285), Vector3(0, 1.09, 0), black)
			_box(root, Vector3(0.14, 0.58, 0.02), Vector3(0, 1.1, -0.145), white)
			_box(root, Vector3(0.12, 0.05, 0.03), Vector3(0, 1.33, -0.155), _mat(top_c))
		10:  # polo: collar and buttons
			_box(root, Vector3(0.3, 0.06, 0.29), Vector3(0, 1.38, 0), top_light)
			for k in 2:
				_box(root, Vector3(0.03, 0.03, 0.02), Vector3(0, 1.3 - k * 0.07, -0.145), white)
		11:  # flannel: a checked shirt
			for k in 4:
				_box(root, Vector3(0.505, 0.04, 0.285), Vector3(0, 0.88 + k * 0.15, 0), top_dark)
			for k in 3:
				_box(root, Vector3(0.04, 0.62, 0.285), Vector3(-0.15 + k * 0.15, 1.09, 0), top_dark)
		12:  # rainbow stripes
			var bands := [Color(0.9, 0.25, 0.25), Color(0.98, 0.6, 0.2), Color(0.98, 0.88, 0.3), Color(0.35, 0.75, 0.4), Color(0.3, 0.5, 0.9), Color(0.6, 0.35, 0.85)]
			for k in 6:
				_box(root, Vector3(0.505, 0.105, 0.285), Vector3(0, 1.345 - k * 0.104, 0), _mat(bands[k]))
		13:  # lab coat: long white coat over the shirt
			_box(root, Vector3(0.53, 0.62, 0.3), Vector3(0, 1.09, 0), white)
			_box(root, Vector3(0.14, 0.58, 0.02), Vector3(0, 1.1, -0.155), top)
			_box(root, Vector3(0.54, 0.3, 0.31), Vector3(0, 0.66, 0), white)
			_box(root, Vector3(0.1, 0.03, 0.02), Vector3(-0.15, 1.2, -0.16), _mat(Color(0.3, 0.5, 0.9)))   # a pen
		14:  # space suit: white with a chest panel
			_box(root, Vector3(0.53, 0.64, 0.3), Vector3(0, 1.09, 0), white)
			_box(root, Vector3(0.22, 0.16, 0.02), Vector3(0, 1.16, -0.16), top)
			for k in 3:
				_box(root, Vector3(0.04, 0.04, 0.02), Vector3(-0.06 + k * 0.06, 1.16, -0.172), _mat([Color(0.9, 0.2, 0.2), Color(0.3, 0.9, 0.3), Color(0.98, 0.85, 0.2)][k]))
			_box(root, Vector3(0.4, 0.5, 0.14), Vector3(0, 1.1, 0.2), _mat(Color(0.8, 0.82, 0.86)))   # air tank
		15:  # knight's tabard with a sword on the front
			_box(root, Vector3(0.505, 0.62, 0.285), Vector3(0, 1.09, 0), _mat(Color(0.75, 0.77, 0.82)))
			_box(root, Vector3(0.38, 0.66, 0.02), Vector3(0, 1.0, -0.15), top)
			# a sword pointing down: blade, guard, handle
			_box(root, Vector3(0.05, 0.26, 0.02), Vector3(0, 1.0, -0.162), _mat(Color(0.9, 0.92, 0.96)))
			_box(root, Vector3(0.16, 0.04, 0.02), Vector3(0, 1.15, -0.162), gold)
			_box(root, Vector3(0.04, 0.08, 0.02), Vector3(0, 1.21, -0.162), _mat(Color(0.45, 0.28, 0.15)))
		16:  # worn tunic: rope belt, frayed hem, a patch
			_box(root, Vector3(0.53, 0.2, 0.31), Vector3(0, 0.72, 0), top)
			for k in 4:
				_box(root, Vector3(0.08, 0.05, 0.315), Vector3(-0.18 + k * 0.12, 0.6 - (k % 2) * 0.02, 0), top)
			_box(root, Vector3(0.12, 0.12, 0.02), Vector3(0.12, 1.2, -0.145), _mat(top_c.darkened(0.35)))
			_box(root, Vector3(0.16, 0.12, 0.02), Vector3(0, 1.36, -0.145), skin)
		17:  # fur vest over bare arms
			_box(root, Vector3(0.505, 0.62, 0.285), Vector3(0, 1.09, 0), skin)
			for s2 in [-1, 1]:
				_box(root, Vector3(0.18, 0.62, 0.3), Vector3(0.16 * s2, 1.09, 0), _mat(top_c, "fur"))
			_box(root, Vector3(0.53, 0.12, 0.32), Vector3(0, 1.36, 0), _mat(top_c.lightened(0.2), "fur"))
		18:  # chainmail shirt
			_box(root, Vector3(0.52, 0.66, 0.3), Vector3(0, 1.07, 0), _mat(Color(0.6, 0.62, 0.66), "metal"))
			_box(root, Vector3(0.53, 0.04, 0.31), Vector3(0, 0.75, 0), _mat(Color(0.45, 0.47, 0.5), "metal"))
		19:  # torn shirt: ripped sleeves and a tear across the front
			_box(root, Vector3(0.2, 0.03, 0.02), Vector3(-0.06, 1.12, -0.145), skin).rotation.z = 0.35
			_box(root, Vector3(0.12, 0.03, 0.02), Vector3(0.1, 0.98, -0.145), skin).rotation.z = -0.3
		_:  # t-shirt collar
			_box(root, Vector3(0.26, 0.06, 0.29), Vector3(0, 1.38, 0), top_dark)
	if bottom_style == 11 and not dress:   # battle kilt: pleated, with a studded belt
		_box(root, Vector3(0.56, 0.32, 0.34), Vector3(0, 0.64, 0), _mat(bottom_c, "leather"))
		for k in 4:
			_box(root, Vector3(0.02, 0.3, 0.345), Vector3(-0.21 + k * 0.14, 0.64, 0), _mat(bottom_c.darkened(0.3), "leather"))
		_box(root, Vector3(0.58, 0.07, 0.36), Vector3(0, 0.79, 0), _mat(Color(0.25, 0.17, 0.1), "leather"))
		_box(root, Vector3(0.08, 0.06, 0.02), Vector3(0, 0.79, -0.185), gold)
	elif bottom_style == 7 and not dress:   # tutu: a wide frilly ring
		_box(root, Vector3(0.7, 0.14, 0.5), Vector3(0, 0.72, 0), bottom)
		_box(root, Vector3(0.74, 0.04, 0.54), Vector3(0, 0.66, 0), bottom_light)
	elif bottom_style == 2 and not dress:
		_box(root, Vector3(0.56, 0.3, 0.34), Vector3(0, 0.66, 0), bottom)
		_box(root, Vector3(0.58, 0.04, 0.36), Vector3(0, 0.52, 0), bottom_light)
	elif not dress:
		_box(root, Vector3(0.52, 0.07, 0.3), Vector3(0, 0.79, 0), _mat(Color(0.3, 0.2, 0.12)))  # belt
		_box(root, Vector3(0.08, 0.06, 0.02), Vector3(0, 0.79, -0.155), gold)

	# --- Arms ----------------------------------------------------------------------
	var sleeve := skin if top_style in [4, 17] else (_mat(Color(0.6, 0.62, 0.66), "metal") if top_style == 18 else black if top_style == 9 else (white if top_style in [13, 14] else (_mat(Color(0.75, 0.77, 0.82)) if top_style == 15 else top)))
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.36 * side, 1.38, 0)
		_box(arm, Vector3(0.2, 0.34, 0.22), Vector3(0, -0.14, 0), sleeve)
		if top_style == 19:
			_box(arm, Vector3(0.205, 0.05, 0.225), Vector3(0, -0.2, 0), top_dark)   # a ragged short sleeve
		elif top_style not in [4, 17]:
			_box(arm, Vector3(0.205, 0.04, 0.225), Vector3(0, -0.31, 0), top_dark if top_style != 9 else white)
		_box(arm, Vector3(0.18, 0.26, 0.2), Vector3(0, -0.45, 0), skin)
		_box(arm, Vector3(0.19, 0.11, 0.21), Vector3(0, -0.62, 0), skin_shade)
		root.add_child(arm)
		parts["arm_l" if side < 0 else "arm_r"] = arm

	# --- Head: face and hair ---------------------------------------------------------
	var head := head_pivot
	if head == null:
		head = Node3D.new()
		head.position.y = EYE_HEIGHT
		root.add_child(head)
	var face := _box(head, Vector3(0.48, 0.48, 0.48), Vector3(0, 0.02, 0), skin)
	face.name = "Face"
	_build_face(face, look["face"], hair_c, skin_c, EYES[look["eye_color"]])
	_build_marks(face, look["scars"], look["warpaint"], COLORS[look["paint_color"]], skin_c)
	_build_hair(face, look["hair"], hair, hair_c, top_c)
	_build_extra(root, face, look["extra"], COLORS[look["extra_color"]])
	parts["head"] = head
	parts["face"] = face

	# Empty holders that set_armor() fills in.
	for slot in ["head", "chest", "legs", "feet", "back", "neck"]:
		parts["armor_" + slot] = []
	return parts


## Scars (lighter, raised lines) and war paint.
static func _build_marks(face: Node3D, scars: int, paint: int, paint_c: Color, skin_c: Color) -> void:
	var z := -0.252
	var scar := _flat(skin_c.lerp(Color(0.92, 0.62, 0.6), 0.55))
	var deep := _flat(skin_c.darkened(0.35))
	var stitch := _flat(Color(0.12, 0.1, 0.1))
	match scars:
		1:  # a slash across the cheek
			_box(face, Vector3(0.14, 0.022, 0.02), Vector3(0.13, -0.05, z), scar).rotation.z = 0.5
		2:  # over the eye, from brow to cheek
			_box(face, Vector3(0.024, 0.24, 0.02), Vector3(-0.11, 0.03, z - 0.012), scar).rotation.z = 0.18
		3:  # a cross on the cheek
			_box(face, Vector3(0.12, 0.022, 0.02), Vector3(-0.15, -0.06, z), scar).rotation.z = 0.7
			_box(face, Vector3(0.12, 0.022, 0.02), Vector3(-0.15, -0.06, z - 0.002), scar).rotation.z = -0.7
		4:  # on the chin
			_box(face, Vector3(0.022, 0.08, 0.02), Vector3(0.04, -0.18, z), scar).rotation.z = -0.3
		5:  # a stitched-up cut
			_box(face, Vector3(0.18, 0.02, 0.02), Vector3(0.1, 0.0, z), deep).rotation.z = -0.3
			for k in 4:
				_box(face, Vector3(0.012, 0.05, 0.02), Vector3(0.03 + k * 0.045, 0.02 - k * 0.013, z - 0.004), stitch).rotation.z = -0.3
		6:  # an old burn on one side
			_box(face, Vector3(0.12, 0.14, 0.02), Vector3(0.15, -0.02, z + 0.004), _flat(skin_c.lerp(Color(0.8, 0.45, 0.4), 0.45)))
			_box(face, Vector3(0.06, 0.05, 0.02), Vector3(0.18, 0.07, z + 0.002), _flat(skin_c.lerp(Color(0.85, 0.5, 0.45), 0.35)))
		7:  # three claw marks
			for k in 3:
				_box(face, Vector3(0.02, 0.2, 0.02), Vector3(-0.17 + k * 0.05, -0.02, z - 0.004 * k), scar).rotation.z = 0.35
		8:  # a broken nose
			_box(face, Vector3(0.06, 0.03, 0.02), Vector3(0.012, -0.02, -0.277), _flat(skin_c.darkened(0.25))).rotation.z = 0.4
	var p := _flat(paint_c)
	var zp := -0.249
	match paint:
		1:  # stripes under the eyes
			for s in [-1, 1]:
				for k in 2:
					_box(face, Vector3(0.1, 0.025, 0.02), Vector3(0.12 * s, -0.04 - k * 0.045, zp), p)
		2:  # a skull: dark around the eyes, teeth on the mouth
			for s in [-1, 1]:
				_box(face, Vector3(0.15, 0.13, 0.02), Vector3(0.11 * s, 0.03, zp + 0.002), _flat(Color(0.05, 0.05, 0.06)))
			for k in 4:
				_box(face, Vector3(0.02, 0.06, 0.02), Vector3(-0.06 + k * 0.04, -0.13, zp - 0.008), p)
		3:  # a slash from forehead to jaw
			_box(face, Vector3(0.05, 0.42, 0.02), Vector3(0.02, 0.0, zp), p).rotation.z = 0.5
		4:  # tribal lines on the forehead and cheeks
			_box(face, Vector3(0.24, 0.03, 0.02), Vector3(0, 0.16, zp), p)
			for s in [-1, 1]:
				_box(face, Vector3(0.03, 0.12, 0.02), Vector3(0.19 * s, -0.04, zp), p)
				_box(face, Vector3(0.06, 0.03, 0.02), Vector3(0.16 * s, -0.1, zp), p)
		5:  # a painted band across the eyes, like a mask
			_box(face, Vector3(0.48, 0.1, 0.02), Vector3(0, 0.03, zp + 0.004), p)
		6:  # ash and dirt smudges
			var ash := _flat(Color(paint_c.darkened(0.5), 1.0))
			for q in [Vector3(-0.15, -0.07, 0), Vector3(0.1, 0.13, 0), Vector3(0.17, -0.12, 0)]:
				_box(face, Vector3(0.08, 0.05, 0.02), q + Vector3(0, 0, zp), ash)


static func _build_face(face: Node3D, style: int, hair_c: Color, skin_c: Color, eye_c := Color(0.25, 0.45, 0.7)) -> void:
	var white := _flat(Color(0.97, 0.97, 0.97))
	var iris := _flat(eye_c)
	var pupil := _flat(Color(0.06, 0.06, 0.09))
	var brow := _flat(hair_c.darkened(0.2))
	var mouth := _flat(Color(0.62, 0.3, 0.3))
	var blush := _flat(Color(0.98, 0.62, 0.6))
	var z := -0.245
	_box(face, Vector3(0.05, 0.06, 0.04), Vector3(0, -0.03, -0.255), _flat(skin_c.darkened(0.12)))  # nose
	for side in [-0.11, 0.11]:
		var sx := signf(side)
		match style:
			1, 8:  # happy: closed smiling eyes (wink: only the right one)
				if style == 8 and side < 0:
					_box(face, Vector3(0.1, 0.07, 0.02), Vector3(side, 0.03, z), white)
					_box(face, Vector3(0.05, 0.07, 0.02), Vector3(side + 0.02 * sx, 0.03, z - 0.007), iris)
				else:
					_box(face, Vector3(0.1, 0.025, 0.02), Vector3(side, 0.04, z), pupil)
			2:  # big eyes
				_box(face, Vector3(0.13, 0.12, 0.02), Vector3(side, 0.03, z), white)
				_box(face, Vector3(0.08, 0.1, 0.02), Vector3(side + 0.02 * sx, 0.02, z - 0.007), iris)
				_box(face, Vector3(0.04, 0.05, 0.02), Vector3(side + 0.02 * sx, 0.02, z - 0.013), pupil)
				_box(face, Vector3(0.025, 0.025, 0.02), Vector3(side, 0.06, z - 0.016), white)
			3:  # sleepy
				_box(face, Vector3(0.1, 0.04, 0.02), Vector3(side, 0.02, z), white)
				_box(face, Vector3(0.1, 0.03, 0.02), Vector3(side, 0.045, z - 0.004), _flat(skin_c.darkened(0.2)))
				_box(face, Vector3(0.05, 0.03, 0.02), Vector3(side + 0.02 * sx, 0.015, z - 0.007), iris)
			5, 15:  # sunglasses, robot visor (drawn once below)
				pass
			10:  # surprised: big round eyes
				_box(face, Vector3(0.11, 0.11, 0.02), Vector3(side, 0.04, z), white)
				_box(face, Vector3(0.05, 0.05, 0.02), Vector3(side, 0.04, z - 0.007), pupil)
			11:  # cat face: slit eyes and whiskers
				_box(face, Vector3(0.1, 0.07, 0.02), Vector3(side, 0.03, z), _flat(eye_c.lightened(0.3)))
				_box(face, Vector3(0.02, 0.07, 0.02), Vector3(side, 0.03, z - 0.007), pupil)
				for wy in [-0.05, -0.08]:
					_box(face, Vector3(0.1, 0.012, 0.02), Vector3(side * 1.75, wy, z - 0.002), _flat(Color(0.2, 0.2, 0.22)))
			12:  # starry eyes
				_box(face, Vector3(0.1, 0.07, 0.02), Vector3(side, 0.03, z), white)
				var star := _flat(Color(1.0, 0.82, 0.25))
				_box(face, Vector3(0.07, 0.02, 0.02), Vector3(side, 0.03, z - 0.007), star)
				_box(face, Vector3(0.02, 0.07, 0.02), Vector3(side, 0.03, z - 0.008), star)
			14, 16, 18:  # determined / scowl / battle weary: a narrow look
				_box(face, Vector3(0.1, 0.04 if style != 18 else 0.035, 0.02), Vector3(side, 0.025, z), white)
				_box(face, Vector3(0.05, 0.04, 0.02), Vector3(side + 0.02 * sx, 0.025, z - 0.007), iris)
				if style == 18:
					_box(face, Vector3(0.1, 0.02, 0.02), Vector3(side, -0.005, z + 0.002), _flat(skin_c.darkened(0.25)))   # tired shadows
			17:  # war cry: wide fierce eyes
				_box(face, Vector3(0.11, 0.08, 0.02), Vector3(side, 0.03, z), white)
				_box(face, Vector3(0.04, 0.04, 0.02), Vector3(side, 0.03, z - 0.007), pupil)
			19:  # one-eyed: the other is shut by an old wound
				if side < 0:
					_box(face, Vector3(0.11, 0.02, 0.02), Vector3(side, 0.03, z), _flat(skin_c.darkened(0.35)))
				else:
					_box(face, Vector3(0.1, 0.06, 0.02), Vector3(side, 0.03, z), white)
					_box(face, Vector3(0.05, 0.06, 0.02), Vector3(side + 0.02 * sx, 0.03, z - 0.007), iris)
			_:
				_box(face, Vector3(0.1, 0.07, 0.02), Vector3(side, 0.03, z), white)
				_box(face, Vector3(0.05, 0.07, 0.02), Vector3(side + 0.02 * sx, 0.03, z - 0.007), iris)
				_box(face, Vector3(0.025, 0.035, 0.02), Vector3(side + 0.02 * sx, 0.03, z - 0.013), pupil)
		# Eyebrows (grumpy ones tilt down toward the middle).
		var brow_y := 0.1 if style not in [7, 14, 16, 17] else 0.085
		if style == 10:
			brow_y = 0.13
		if style != 15:
			_box(face, Vector3(0.11, 0.03 if style in [16, 17, 20] else 0.025, 0.02), Vector3(side, brow_y, z - 0.002), brow).rotation.z = (0.35 * sx if style in [7, 14, 16, 17] else 0.0)
		if style in [2, 4, 9]:
			_box(face, Vector3(0.07, 0.035, 0.02), Vector3(side * 1.45, -0.05, z + 0.002), blush)
	if style == 4:  # freckles
		for f in [Vector3(-0.15, -0.04, 0), Vector3(-0.12, -0.07, 0), Vector3(0.13, -0.04, 0), Vector3(0.16, -0.07, 0)]:
			_box(face, Vector3(0.02, 0.02, 0.02), f + Vector3(0, 0, z - 0.004), _flat(skin_c.darkened(0.35)))
	if style == 5:  # sunglasses
		var lens := _flat(Color(0.05, 0.05, 0.08))
		_box(face, Vector3(0.42, 0.03, 0.02), Vector3(0, 0.07, z - 0.006), lens)
		_box(face, Vector3(0.14, 0.09, 0.02), Vector3(-0.11, 0.03, z - 0.006), lens)
		_box(face, Vector3(0.14, 0.09, 0.02), Vector3(0.11, 0.03, z - 0.006), lens)
	if style == 15:  # robot: a glowing visor and a speaker grill
		var glow := _flat(eye_c.lightened(0.4))
		glow.emission_enabled = true
		glow.emission = eye_c
		_box(face, Vector3(0.4, 0.09, 0.02), Vector3(0, 0.04, z - 0.006), _flat(Color(0.15, 0.16, 0.2)))
		_box(face, Vector3(0.34, 0.04, 0.02), Vector3(0, 0.04, z - 0.012), glow)
		for k in 4:
			_box(face, Vector3(0.025, 0.06, 0.02), Vector3(-0.06 + k * 0.04, -0.12, z), _flat(Color(0.3, 0.32, 0.36)))
		return
	if style == 20:  # a full beard
		_box(face, Vector3(0.46, 0.2, 0.06), Vector3(0, -0.15, -0.23), brow)
		_box(face, Vector3(0.3, 0.1, 0.06), Vector3(0, -0.28, -0.22), brow)
		_box(face, Vector3(0.22, 0.05, 0.02), Vector3(0, -0.08, z - 0.03), brow)
		_box(face, Vector3(0.12, 0.03, 0.02), Vector3(0, -0.13, z - 0.032), _flat(Color(0.3, 0.12, 0.12)))
		return
	if style == 13:  # mustache
		_box(face, Vector3(0.22, 0.05, 0.02), Vector3(0, -0.08, z - 0.006), brow)
		_box(face, Vector3(0.05, 0.05, 0.02), Vector3(-0.12, -0.1, z - 0.006), brow)
		_box(face, Vector3(0.05, 0.05, 0.02), Vector3(0.12, -0.1, z - 0.006), brow)
	# Mouth
	match style:
		10:  # surprised: a little "o"
			_box(face, Vector3(0.06, 0.07, 0.02), Vector3(0, -0.13, z), _flat(Color(0.3, 0.1, 0.12)))
		11:  # cat: a tiny "w"
			_box(face, Vector3(0.04, 0.02, 0.02), Vector3(-0.025, -0.11, z), mouth)
			_box(face, Vector3(0.04, 0.02, 0.02), Vector3(0.025, -0.11, z), mouth)
		14, 16:  # determined / scowl: a firm line
			_box(face, Vector3(0.14, 0.025, 0.02), Vector3(0, -0.12, z), mouth)
			if style == 16:
				_box(face, Vector3(0.03, 0.025, 0.02), Vector3(-0.08, -0.135, z), mouth)
				_box(face, Vector3(0.03, 0.025, 0.02), Vector3(0.08, -0.135, z), mouth)
		17:  # war cry: a wide open shout with teeth
			_box(face, Vector3(0.18, 0.1, 0.02), Vector3(0, -0.13, z), _flat(Color(0.25, 0.08, 0.1)))
			_box(face, Vector3(0.16, 0.025, 0.02), Vector3(0, -0.09, z - 0.004), white)
		18, 19:  # weary: a flat, tired mouth
			_box(face, Vector3(0.12, 0.022, 0.02), Vector3(0.01, -0.125, z), mouth)
		6:  # silly tongue
			_box(face, Vector3(0.14, 0.04, 0.02), Vector3(0, -0.12, z), _flat(Color(0.3, 0.1, 0.12)))
			_box(face, Vector3(0.07, 0.07, 0.02), Vector3(0.02, -0.16, z - 0.005), _flat(Color(0.95, 0.45, 0.55)))
		7:  # grumpy
			_box(face, Vector3(0.12, 0.025, 0.02), Vector3(0, -0.13, z), mouth)
		1, 2, 8, 9, 12:  # big smile
			_box(face, Vector3(0.16, 0.03, 0.02), Vector3(0, -0.12, z), mouth)
			_box(face, Vector3(0.03, 0.03, 0.02), Vector3(-0.085, -0.1, z), mouth)
			_box(face, Vector3(0.03, 0.03, 0.02), Vector3(0.085, -0.1, z), mouth)
		_:
			_box(face, Vector3(0.12, 0.025, 0.02), Vector3(0, -0.12, z), mouth)


static func _build_hair(face: Node3D, style: int, hair: Material, hair_c: Color, top_c: Color) -> void:
	var top_hair := func() -> void:
		_box(face, Vector3(0.5, 0.12, 0.5), Vector3(0, 0.2, 0.0), hair)
		_box(face, Vector3(0.5, 0.36, 0.08), Vector3(0, 0.06, 0.22), hair)
		for side in [-1, 1]:
			_box(face, Vector3(0.05, 0.22, 0.42), Vector3(0.235 * side, 0.1, 0.03), hair)
	match style:
		0:  # short
			top_hair.call()
			_box(face, Vector3(0.3, 0.05, 0.03), Vector3(-0.06, 0.13, -0.245), hair)
		1:  # spiky
			top_hair.call()
			for k in 5:
				_box(face, Vector3(0.1, 0.14, 0.1), Vector3(-0.18 + k * 0.09, 0.3 + (k % 2) * 0.03, -0.05 + (k % 2) * 0.1), hair).rotation.z = (k - 2) * 0.25
		2:  # long
			top_hair.call()
			_box(face, Vector3(0.52, 0.62, 0.1), Vector3(0, -0.12, 0.24), hair)
			for side in [-1, 1]:
				_box(face, Vector3(0.06, 0.5, 0.2), Vector3(0.245 * side, -0.08, 0.14), hair)
			_box(face, Vector3(0.44, 0.06, 0.03), Vector3(0, 0.15, -0.245), hair)
		3:  # ponytail
			top_hair.call()
			_box(face, Vector3(0.1, 0.08, 0.06), Vector3(0, 0.12, 0.28), _mat(top_c))
			_box(face, Vector3(0.14, 0.42, 0.14), Vector3(0, -0.08, 0.34), hair)
		4:  # pigtails
			top_hair.call()
			for side in [-1, 1]:
				_box(face, Vector3(0.12, 0.34, 0.12), Vector3(0.3 * side, -0.06, 0.08), hair)
				_box(face, Vector3(0.08, 0.06, 0.08), Vector3(0.3 * side, 0.12, 0.08), _mat(top_c))
		5:  # buns
			top_hair.call()
			for side in [-1, 1]:
				_box(face, Vector3(0.18, 0.16, 0.18), Vector3(0.17 * side, 0.32, 0.05), hair)
		6:  # bob
			top_hair.call()
			for side in [-1, 1]:
				_box(face, Vector3(0.07, 0.36, 0.44), Vector3(0.25 * side, 0.0, 0.02), hair)
			_box(face, Vector3(0.44, 0.07, 0.03), Vector3(0, 0.15, -0.245), hair)
		7:  # mohawk
			_box(face, Vector3(0.12, 0.2, 0.5), Vector3(0, 0.32, 0.0), hair)
		8:  # curly
			for k in 10:
				var a := k * TAU / 10.0
				_box(face, Vector3(0.2, 0.2, 0.2), Vector3(cos(a) * 0.2, 0.22 + sin(k * 1.7) * 0.04, sin(a) * 0.2 + 0.03), hair)
			_box(face, Vector3(0.3, 0.2, 0.3), Vector3(0, 0.3, 0.02), hair)
		9:  # bald: a little shine
			_box(face, Vector3(0.1, 0.02, 0.1), Vector3(-0.08, 0.245, -0.05), _mat(Color(1, 1, 1, 1)))
		10:  # cap (in the top's color) over short hair
			top_hair.call()
			var cap := _mat(top_c)
			_box(face, Vector3(0.52, 0.14, 0.52), Vector3(0, 0.24, 0.0), cap)
			_box(face, Vector3(0.44, 0.03, 0.2), Vector3(0, 0.18, -0.33), cap)
		11:  # bunny ears headband
			top_hair.call()
			var white := _mat(Color(0.97, 0.97, 0.97))
			var pink := _mat(Color(1.0, 0.7, 0.8))
			for side in [-1, 1]:
				_box(face, Vector3(0.1, 0.36, 0.05), Vector3(0.12 * side, 0.44, 0.0), white).rotation.z = -0.12 * side
				_box(face, Vector3(0.05, 0.26, 0.02), Vector3(0.12 * side, 0.44, -0.03), pink).rotation.z = -0.12 * side
		12:  # party hat
			top_hair.call()
			var cols := [Color(0.95, 0.3, 0.4), Color(0.98, 0.85, 0.3), Color(0.3, 0.7, 0.95)]
			for k in 5:
				var w := 0.34 - k * 0.07
				_box(face, Vector3(w, 0.08, w), Vector3(0, 0.3 + k * 0.08, 0), _mat(cols[k % 3]))
			_box(face, Vector3(0.08, 0.08, 0.08), Vector3(0, 0.72, 0), _mat(Color(1, 1, 1)))
		13:  # afro: a big round cloud of hair
			for k in 14:
				var a := k * TAU / 14.0
				_box(face, Vector3(0.26, 0.26, 0.26), Vector3(cos(a) * 0.26, 0.2 + sin(k * 2.3) * 0.06, sin(a) * 0.26 + 0.04), hair)
			_box(face, Vector3(0.5, 0.3, 0.5), Vector3(0, 0.36, 0.04), hair)
		14:  # side swoop: a long fringe across one eye's corner
			top_hair.call()
			_box(face, Vector3(0.34, 0.1, 0.05), Vector3(-0.07, 0.17, -0.25), hair).rotation.z = 0.25
			_box(face, Vector3(0.1, 0.16, 0.05), Vector3(0.19, 0.08, -0.25), hair)
		15:  # top knot
			top_hair.call()
			_box(face, Vector3(0.18, 0.18, 0.18), Vector3(0, 0.36, 0.06), hair)
			_box(face, Vector3(0.12, 0.04, 0.12), Vector3(0, 0.28, 0.06), _mat(top_c))
		16:  # beanie
			top_hair.call()
			var knit := _mat(top_c)
			_box(face, Vector3(0.53, 0.2, 0.53), Vector3(0, 0.22, 0), knit)
			_box(face, Vector3(0.54, 0.06, 0.54), Vector3(0, 0.13, 0), _mat(top_c.darkened(0.25)))
			_box(face, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.38, 0), _mat(Color(0.97, 0.97, 0.97)))
		17:  # braids
			top_hair.call()
			for side in [-1, 1]:
				for k in 4:
					_box(face, Vector3(0.11, 0.11, 0.11), Vector3(0.2 * side, -0.12 - k * 0.1, 0.16), hair)
				_box(face, Vector3(0.08, 0.05, 0.08), Vector3(0.2 * side, -0.5, 0.16), _mat(top_c))
		18:  # flower crown over long hair
			top_hair.call()
			_box(face, Vector3(0.52, 0.5, 0.1), Vector3(0, -0.06, 0.24), hair)
			var petals := [Color(1.0, 0.5, 0.7), Color(1.0, 0.9, 0.35), Color(0.6, 0.75, 1.0), Color(1.0, 1.0, 1.0)]
			for k in 8:
				var a := k * TAU / 8.0
				_box(face, Vector3(0.09, 0.09, 0.09), Vector3(cos(a) * 0.25, 0.25, sin(a) * 0.25), _mat(petals[k % 4]))
		19:  # cat ears
			top_hair.call()
			for side in [-1, 1]:
				_box(face, Vector3(0.14, 0.14, 0.06), Vector3(0.15 * side, 0.32, 0.02), hair).rotation.z = 0.785
				_box(face, Vector3(0.07, 0.07, 0.02), Vector3(0.15 * side, 0.32, -0.015), _mat(Color(1.0, 0.7, 0.8))).rotation.z = 0.785
		21:  # shaved sides: a strip on top
			_box(face, Vector3(0.16, 0.12, 0.5), Vector3(0, 0.27, 0.0), hair)
			for side in [-1, 1]:
				_box(face, Vector3(0.02, 0.18, 0.4), Vector3(0.245 * side, 0.12, 0.04), _mat(hair_c.darkened(0.2).lerp(Color(0.5, 0.45, 0.4), 0.3), "hair"))
		22:  # a long warrior braid down the back
			top_hair.call()
			for k in 6:
				_box(face, Vector3(0.12, 0.12, 0.12), Vector3(0, 0.0 - k * 0.11, 0.3 + k * 0.01), hair)
			_box(face, Vector3(0.08, 0.06, 0.08), Vector3(0, -0.66, 0.31), _mat(Color(0.45, 0.3, 0.15), "leather"))
		23:  # a wild mane
			top_hair.call()
			for k in 9:
				var a := -PI * 0.9 + k * PI * 1.8 / 8.0
				_box(face, Vector3(0.16, 0.24, 0.16), Vector3(cos(a) * 0.27, 0.1 + sin(k * 1.9) * 0.06, 0.12 + sin(a) * 0.12), hair).rotation.z = cos(a) * 0.4
			_box(face, Vector3(0.54, 0.5, 0.14), Vector3(0, -0.08, 0.26), hair)
		24:  # battle topknot with shaved sides
			_box(face, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.23, 0.0), _mat(hair_c.darkened(0.15), "hair"))
			_box(face, Vector3(0.16, 0.2, 0.16), Vector3(0, 0.36, 0.04), hair)
			_box(face, Vector3(0.18, 0.05, 0.18), Vector3(0, 0.29, 0.04), _mat(Color(0.5, 0.35, 0.18), "leather"))
			_box(face, Vector3(0.1, 0.24, 0.1), Vector3(0, 0.32, 0.18), hair).rotation.x = 0.9
		20:  # wizard hat with stars
			top_hair.call()
			var robe := _mat(top_c.darkened(0.15))
			_box(face, Vector3(0.7, 0.04, 0.7), Vector3(0, 0.25, 0), robe)
			for k in 5:
				var w := 0.4 - k * 0.075
				_box(face, Vector3(w, 0.13, w), Vector3(0.0 + k * 0.015, 0.33 + k * 0.12, 0.0 + k * 0.015), robe)
			_box(face, Vector3(0.06, 0.06, 0.02), Vector3(0.06, 0.42, -0.19), _mat(Color(1.0, 0.85, 0.3)))


## The extra bit: a backpack, scarf, headphones, a bow, glasses, wings...
static func _build_extra(root: Node3D, face: Node3D, style: int, c: Color) -> void:
	var m := _mat(c)
	var dark := _mat(c.darkened(0.3))
	var z := -0.245
	match style:
		1:  # backpack
			_box(root, Vector3(0.4, 0.46, 0.16), Vector3(0, 1.08, 0.22), m)
			_box(root, Vector3(0.3, 0.16, 0.04), Vector3(0, 0.98, 0.31), dark)
			for side in [-1, 1]:
				_box(root, Vector3(0.05, 0.5, 0.03), Vector3(0.14 * side, 1.12, -0.15), dark)
		2:  # scarf
			_box(root, Vector3(0.54, 0.1, 0.34), Vector3(0, 1.36, 0), m)
			_box(root, Vector3(0.12, 0.3, 0.04), Vector3(0.12, 1.2, -0.17), m)
			_box(root, Vector3(0.125, 0.04, 0.045), Vector3(0.12, 1.08, -0.17), dark)
		3:  # headphones
			_box(face, Vector3(0.56, 0.05, 0.08), Vector3(0, 0.27, 0), dark)
			for side in [-1, 1]:
				_box(face, Vector3(0.08, 0.18, 0.18), Vector3(0.27 * side, 0.0, 0), m)
		4:  # a big bow on the head
			_box(face, Vector3(0.1, 0.1, 0.08), Vector3(0.12, 0.28, -0.05), dark)
			for side in [-1, 1]:
				_box(face, Vector3(0.12, 0.14, 0.06), Vector3(0.12 + 0.1 * side, 0.28, -0.05), m).rotation.z = 0.3 * side
		5:  # glasses
			var rim := _mat(c.darkened(0.4))
			for side in [-0.11, 0.11]:
				_box(face, Vector3(0.14, 0.02, 0.02), Vector3(side, 0.08, z - 0.02), rim)
				_box(face, Vector3(0.14, 0.02, 0.02), Vector3(side, -0.02, z - 0.02), rim)
				_box(face, Vector3(0.02, 0.1, 0.02), Vector3(side - 0.07, 0.03, z - 0.02), rim)
				_box(face, Vector3(0.02, 0.1, 0.02), Vector3(side + 0.07, 0.03, z - 0.02), rim)
		6:  # bandana
			_box(face, Vector3(0.5, 0.08, 0.5), Vector3(0, 0.18, 0), m)
			_box(face, Vector3(0.1, 0.12, 0.04), Vector3(0.08, 0.14, 0.27), m)
		7:  # fairy wings
			var wing := _mat(Color(c.lightened(0.4), 0.7))
			wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			wing.cull_mode = BaseMaterial3D.CULL_DISABLED
			for side in [-1, 1]:
				_box(root, Vector3(0.36, 0.42, 0.02), Vector3(0.26 * side, 1.2, 0.24), wing).rotation = Vector3(0, -0.5 * side, 0.4 * side)
				_box(root, Vector3(0.24, 0.26, 0.02), Vector3(0.2 * side, 0.92, 0.22), wing).rotation = Vector3(0, -0.4 * side, -0.4 * side)
		8:  # bow tie
			_box(root, Vector3(0.05, 0.05, 0.03), Vector3(0, 1.34, -0.155), dark)
			for side in [-1, 1]:
				_box(root, Vector3(0.07, 0.07, 0.03), Vector3(0.055 * side, 1.34, -0.155), m)
		10:  # an eyepatch on a strap
			_box(face, Vector3(0.13, 0.11, 0.02), Vector3(-0.11, 0.03, z - 0.02), _flat(Color(0.06, 0.06, 0.07)))
			_box(face, Vector3(0.5, 0.025, 0.5), Vector3(0, 0.1, 0), _flat(Color(0.1, 0.09, 0.09))).rotation.z = -0.25
		11:  # bandages: round the head and one arm
			var cloth := _mat(Color(0.93, 0.9, 0.82))
			_box(face, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.15, 0), cloth).rotation.z = 0.12
			_box(root, Vector3(0.21, 0.12, 0.23), Vector3(-0.36, 0.9, 0), cloth)
			_box(face, Vector3(0.06, 0.04, 0.02), Vector3(0.14, 0.17, z - 0.01), _flat(Color(0.75, 0.3, 0.3)))
		12:  # a fur mantle over the shoulders
			var fur := _mat(c, "fur")
			_box(root, Vector3(0.74, 0.14, 0.44), Vector3(0, 1.43, 0.02), fur)
			_box(root, Vector3(0.6, 0.4, 0.06), Vector3(0, 1.22, 0.2), fur)
		13:  # war horns on a band
			var horn := _mat(Color(0.9, 0.86, 0.75), "bone")
			_box(face, Vector3(0.52, 0.06, 0.52), Vector3(0, 0.17, 0), dark)
			for side in [-1, 1]:
				_box(face, Vector3(0.08, 0.16, 0.08), Vector3(0.28 * side, 0.27, 0), horn).rotation.z = -0.6 * side
				_box(face, Vector3(0.06, 0.14, 0.06), Vector3(0.36 * side, 0.4, 0), horn).rotation.z = -0.2 * side
		14:  # a battle sash across the chest
			_box(root, Vector3(0.08, 0.78, 0.31), Vector3(0, 1.1, 0), m).rotation.z = 0.6
			_box(root, Vector3(0.1, 0.1, 0.03), Vector3(0.12, 0.95, -0.17), _mat(Color(0.95, 0.78, 0.3), "metal"))
		15:  # a quiver of arrows on the back
			_box(root, Vector3(0.14, 0.5, 0.14), Vector3(0.1, 1.15, 0.22), _mat(c, "leather")).rotation.z = 0.3
			for k in 3:
				_box(root, Vector3(0.03, 0.14, 0.03), Vector3(0.18 + k * 0.03, 1.45, 0.22), _flat(Color(0.9, 0.9, 0.9))).rotation.z = 0.3
			_box(root, Vector3(0.04, 0.7, 0.03), Vector3(0, 1.12, -0.15), dark).rotation.z = 0.6
		9:  # a shiny star badge
			var badge := _mat(Color(1.0, 0.85, 0.3))
			badge.metallic = 0.5
			_box(root, Vector3(0.1, 0.03, 0.02), Vector3(-0.13, 1.24, -0.16), badge)
			_box(root, Vector3(0.03, 0.1, 0.02), Vector3(-0.13, 1.24, -0.16), badge)
			_box(root, Vector3(0.06, 0.06, 0.02), Vector3(-0.13, 1.24, -0.165), _mat(c))


## Shows the given armor: ids for [head, chest, legs, feet, back] ("" = none).
## Every set has its own shape, and they get grander as they go up:
##   leather  - a soft cap with ear flaps, a laced vest, stitched boots
##   bronze   - a round helm with nose and cheek guards, scale mail, round pauldrons
##   iron     - a closed knight's great helm, a plate cuirass, layered pauldrons, sabatons
##   titanium - a winged, plumed helm with a glowing visor, ornate spiked plate, gold trim
## and the legendary pieces each look like nothing else (the King's crown,
## Grimskull's burning-and-freezing bone plate, the Yeti's huge furry boots).
static func set_armor(parts: Dictionary, ids: Array) -> void:
	for slot in ["head", "chest", "legs", "feet", "back", "neck"]:
		if not parts.has("armor_" + slot):
			parts["armor_" + slot] = []
		for n in parts["armor_" + slot]:
			if is_instance_valid(n):
				n.queue_free()
		parts["armor_" + slot] = []
	if ids.size() > 4 and not String(ids[4]).is_empty():
		parts["armor_back"] = _cape(parts, ids[4])
	if ids.size() > 6 and not String(ids[6]).is_empty():
		parts["armor_neck"] = _pendant(parts, ids[6])
	for i in mini(ids.size(), 4):
		var id: String = ids[i]
		if id.is_empty():
			continue
		var d := Items.get_def(id)
		var c: Color = d.get("color", Color.GRAY)
		var tier: int = clampi(int(d.get("look_tier", 1)), 1, 4)
		var mats := _armor_mats(c, tier)
		var made: Array = []
		match id:
			"king_crown":
				made = _crown(parts["head"])
			"grim_chestplate":
				made = _grim_chest(parts, mats)
			"yeti_boots":
				made = _yeti_boots(parts)
			_:
				match i:
					0: made = _helm(parts["head"], tier, mats)
					1: made = _chest(parts, tier, mats)
					2: made = _greaves(parts, tier, mats)
					3: made = _boots(parts, tier, mats)
		if d.get("cute", false):
			made.append_array(_cute_bits(parts, i))
		parts["armor_" + ["head", "chest", "legs", "feet"][i]] = made


static func _armor_mats(c: Color, tier: int) -> Dictionary:
	var main := _mat(c, "leather" if tier == 1 else "metal")
	main.metallic = [0.0, 0.0, 0.45, 0.6, 0.7][tier]
	main.roughness = [0.9, 0.75, 0.45, 0.32, 0.22][tier]
	var gold_c := Color(1.0, 0.8, 0.3)
	var trim := _mat(c.darkened(0.3) if tier < 4 else gold_c, "leather" if tier == 1 else "metal")
	trim.metallic = 0.0 if tier == 1 else 0.6
	var stud := _mat(c.lightened(0.45) if tier < 4 else Color(1.0, 0.95, 0.7), "metal")
	stud.metallic = 0.6
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(0.4, 0.95, 1.0)
	gem.emission_enabled = true
	gem.emission = Color(0.3, 0.8, 1.0)
	gem.emission_energy_multiplier = 1.6
	var dark := _flat(Color(0.05, 0.05, 0.07))
	var plume := _mat(Color(0.75, 0.12, 0.18) if tier < 4 else Color(0.32, 0.18, 0.6), "cloth")
	return {"m": main, "trim": trim, "stud": stud, "gem": gem, "dark": dark, "plume": plume, "c": c}


static func _helm(head: Node3D, tier: int, k: Dictionary) -> Array:
	var o: Array = []
	match tier:
		1:  # a soft leather cap with ear flaps and a stitched band
			o.append(_box(head, Vector3(0.53, 0.2, 0.53), Vector3(0, 0.2, 0.0), k["m"]))
			for s in [-1, 1]:
				o.append(_box(head, Vector3(0.06, 0.24, 0.22), Vector3(0.26 * s, 0.0, 0.03), k["m"]))
			o.append(_box(head, Vector3(0.545, 0.04, 0.545), Vector3(0, 0.12, 0.0), k["trim"]))
			for x in [-0.15, -0.05, 0.05, 0.15]:
				o.append(_box(head, Vector3(0.03, 0.015, 0.02), Vector3(x, 0.12, -0.276), k["stud"]))   # stitches
		2:  # a round bronze helm with a nose guard and cheek guards
			o.append(_box(head, Vector3(0.55, 0.22, 0.55), Vector3(0, 0.2, 0.0), k["m"]))
			o.append(_box(head, Vector3(0.42, 0.08, 0.42), Vector3(0, 0.34, 0.0), k["m"]))
			o.append(_box(head, Vector3(0.57, 0.05, 0.57), Vector3(0, 0.1, 0.0), k["trim"]))
			o.append(_box(head, Vector3(0.06, 0.2, 0.04), Vector3(0, 0.03, -0.29), k["trim"]))
			for s in [-1, 1]:
				o.append(_box(head, Vector3(0.06, 0.24, 0.26), Vector3(0.255 * s, -0.04, -0.1), k["m"]))
			for x in [-0.22, -0.11, 0.11, 0.22]:
				o.append(_box(head, Vector3(0.035, 0.035, 0.02), Vector3(x, 0.1, -0.29), k["stud"]))
		3:  # a closed knight's great helm: visor slit and breathing holes
			o.append(_box(head, Vector3(0.57, 0.5, 0.57), Vector3(0, 0.04, 0.0), k["m"]))
			o.append(_box(head, Vector3(0.58, 0.04, 0.58), Vector3(0, 0.29, 0.0), k["trim"]))
			o.append(_box(head, Vector3(0.06, 0.09, 0.6), Vector3(0, 0.33, 0.0), k["trim"]))       # ridge over the top
			o.append(_box(head, Vector3(0.42, 0.045, 0.02), Vector3(0, 0.06, -0.29), k["dark"]))   # the eye slit
			o.append(_box(head, Vector3(0.04, 0.3, 0.025), Vector3(0, -0.04, -0.293), k["trim"]))  # center ridge
			for y in [-0.08, -0.14]:
				for x in [-0.12, -0.07, 0.07, 0.12]:
					o.append(_box(head, Vector3(0.025, 0.025, 0.02), Vector3(x, y, -0.293), k["dark"]))
		4:  # titanium: a crested helm with wings, a glowing visor and a plume
			o.append(_box(head, Vector3(0.57, 0.38, 0.57), Vector3(0, 0.12, 0.0), k["m"]))
			o.append(_box(head, Vector3(0.59, 0.05, 0.59), Vector3(0, -0.04, 0.0), k["trim"]))
			o.append(_box(head, Vector3(0.44, 0.05, 0.02), Vector3(0, 0.07, -0.293), k["gem"]))
			o.append(_box(head, Vector3(0.07, 0.22, 0.04), Vector3(0, -0.12, -0.29), k["trim"]))
			for s in [-1, 1]:
				var wing := _box(head, Vector3(0.04, 0.3, 0.24), Vector3(0.31 * s, 0.3, 0.06), k["trim"])
				wing.rotation.z = -0.55 * s
				var wing2 := _box(head, Vector3(0.035, 0.2, 0.16), Vector3(0.37 * s, 0.4, 0.12), k["stud"])
				wing2.rotation.z = -0.8 * s
				o.append_array([wing, wing2])
			o.append(_box(head, Vector3(0.07, 0.12, 0.5), Vector3(0, 0.36, 0.0), k["trim"]))
			for j in 5:
				o.append(_box(head, Vector3(0.09, 0.12, 0.11), Vector3(0, 0.42 + j * 0.035, 0.08 + j * 0.06), k["plume"]))
	return o


static func _chest(parts: Dictionary, tier: int, k: Dictionary) -> Array:
	var root: Node3D = parts["root"]
	var o: Array = []
	var arms := [parts["arm_l"], parts["arm_r"]]
	match tier:
		1:  # a laced leather vest
			o.append(_box(root, Vector3(0.54, 0.6, 0.32), Vector3(0, 1.1, 0), k["m"]))
			for j in 4:
				var y := 1.3 - j * 0.12
				var lace := _box(root, Vector3(0.14, 0.02, 0.02), Vector3(0, y, -0.168), k["trim"])
				lace.rotation.z = 0.45 if j % 2 == 0 else -0.45
				o.append(lace)
			o.append(_box(root, Vector3(0.02, 0.48, 0.02), Vector3(0, 1.1, -0.165), k["trim"]))
			for a in arms:
				o.append(_box(a, Vector3(0.24, 0.12, 0.26), Vector3(0, -0.02, 0), k["m"]))
		2:  # bronze scale mail with round pauldrons
			o.append(_box(root, Vector3(0.55, 0.62, 0.33), Vector3(0, 1.1, 0), k["m"]))
			for j in 5:
				o.append(_box(root, Vector3(0.56, 0.035, 0.34), Vector3(0, 0.88 + j * 0.11, 0), k["trim"]))   # rows of scales
			for a in arms:
				o.append(_box(a, Vector3(0.28, 0.2, 0.31), Vector3(0, -0.04, 0), k["m"]))
				o.append(_box(a, Vector3(0.29, 0.04, 0.32), Vector3(0, -0.14, 0), k["trim"]))
				o.append(_box(a, Vector3(0.05, 0.05, 0.02), Vector3(0, -0.03, -0.165), k["stud"]))
		3:  # iron plate: breastplate, gorget, faulds and layered pauldrons
			o.append(_box(root, Vector3(0.56, 0.62, 0.34), Vector3(0, 1.1, 0), k["m"]))
			o.append(_box(root, Vector3(0.44, 0.34, 0.04), Vector3(0, 1.19, -0.18), k["m"]))
			o.append(_box(root, Vector3(0.04, 0.34, 0.02), Vector3(0, 1.19, -0.202), k["trim"]))
			o.append(_box(root, Vector3(0.38, 0.08, 0.36), Vector3(0, 1.43, 0), k["trim"]))       # gorget
			for j in 2:
				o.append(_box(root, Vector3(0.58 - j * 0.02, 0.07, 0.36), Vector3(0, 0.86 - j * 0.07, 0), k["m" if j == 0 else "trim"]))   # faulds
			for a in arms:
				o.append(_box(a, Vector3(0.31, 0.13, 0.33), Vector3(0, 0.03, 0), k["m"]))
				o.append(_box(a, Vector3(0.29, 0.1, 0.31), Vector3(0, -0.08, 0), k["trim"]))
				o.append(_box(a, Vector3(0.27, 0.08, 0.29), Vector3(0, -0.17, 0), k["m"]))
		4:  # titanium: ornate spiked plate with gold trim, a glowing heart gem and a tabard
			o.append(_box(root, Vector3(0.57, 0.63, 0.35), Vector3(0, 1.1, 0), k["m"]))
			o.append(_box(root, Vector3(0.46, 0.36, 0.05), Vector3(0, 1.19, -0.18), k["m"]))
			o.append(_box(root, Vector3(0.48, 0.03, 0.06), Vector3(0, 1.37, -0.18), k["trim"]))
			o.append(_box(root, Vector3(0.48, 0.03, 0.06), Vector3(0, 1.01, -0.18), k["trim"]))
			o.append(_box(root, Vector3(0.12, 0.12, 0.03), Vector3(0, 1.2, -0.215), k["gem"]))
			o.append(_box(root, Vector3(0.4, 0.09, 0.37), Vector3(0, 1.44, 0), k["trim"]))
			o.append(_box(root, Vector3(0.22, 0.34, 0.02), Vector3(0, 0.66, -0.18), k["plume"]))   # tabard
			o.append(_box(root, Vector3(0.24, 0.03, 0.025), Vector3(0, 0.5, -0.18), k["trim"]))
			for a in arms:
				o.append(_box(a, Vector3(0.33, 0.15, 0.35), Vector3(0, 0.04, 0), k["m"]))
				o.append(_box(a, Vector3(0.34, 0.03, 0.36), Vector3(0, -0.04, 0), k["trim"]))
				o.append(_box(a, Vector3(0.3, 0.1, 0.32), Vector3(0, -0.12, 0), k["m"]))
				for z in [-0.08, 0.08]:
					var spike := _box(a, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.17, z), k["stud"])
					o.append(spike)
	return o


static func _greaves(parts: Dictionary, tier: int, k: Dictionary) -> Array:
	var root: Node3D = parts["root"]
	var o: Array = []
	o.append(_box(root, Vector3(0.58, 0.07, 0.34), Vector3(0, 0.8, 0), k["trim"]))   # belt
	if tier >= 2:
		o.append(_box(root, Vector3(0.09, 0.07, 0.02), Vector3(0, 0.8, -0.175), k["stud"]))
	for leg in [parts["leg_l"], parts["leg_r"]]:
		o.append(_box(leg, Vector3(0.27 + tier * 0.005, 0.5, 0.29 + tier * 0.005), Vector3(0, -0.25, 0), k["m"]))
		match tier:
			1:
				o.append(_box(leg, Vector3(0.12, 0.1, 0.02), Vector3(0, -0.26, -0.15), k["trim"]))   # a knee patch
			2:
				o.append(_box(leg, Vector3(0.2, 0.26, 0.03), Vector3(0, -0.4, -0.155), k["trim"]))   # a shin greave
				o.append(_box(leg, Vector3(0.05, 0.05, 0.02), Vector3(0, -0.24, -0.16), k["stud"]))
			3:
				o.append(_box(leg, Vector3(0.22, 0.14, 0.05), Vector3(0, -0.25, -0.16), k["trim"]))  # knee cop
				o.append(_box(leg, Vector3(0.24, 0.05, 0.03), Vector3(0, -0.33, -0.16), k["m"]))
				o.append(_box(leg, Vector3(0.24, 0.12, 0.3), Vector3(0, -0.06, 0), k["trim"]))       # tasset at the hip
			4:
				o.append(_box(leg, Vector3(0.22, 0.14, 0.05), Vector3(0, -0.25, -0.16), k["m"]))
				o.append(_box(leg, Vector3(0.06, 0.06, 0.02), Vector3(0, -0.25, -0.19), k["gem"]))
				o.append(_box(leg, Vector3(0.26, 0.14, 0.32), Vector3(0, -0.06, 0), k["trim"]))
				o.append(_box(leg, Vector3(0.03, 0.3, 0.12), Vector3(0.15 * signf(leg.position.x), -0.3, 0.02), k["trim"]))   # side fins
	return o


static func _boots(parts: Dictionary, tier: int, k: Dictionary) -> Array:
	var o: Array = []
	for leg in [parts["leg_l"], parts["leg_r"]]:
		match tier:
			1:  # stitched leather boots with a folded top
				o.append(_box(leg, Vector3(0.28, 0.22, 0.32), Vector3(0, -0.63, -0.02), k["m"]))
				o.append(_box(leg, Vector3(0.3, 0.06, 0.33), Vector3(0, -0.5, -0.02), k["trim"]))
			2:  # bronze-banded boots with straps
				o.append(_box(leg, Vector3(0.29, 0.24, 0.33), Vector3(0, -0.62, -0.02), k["m"]))
				for y in [-0.56, -0.66]:
					o.append(_box(leg, Vector3(0.3, 0.03, 0.34), Vector3(0, y, -0.02), k["trim"]))
			3:  # iron sabatons: layered plates and a pointed toe
				o.append(_box(leg, Vector3(0.29, 0.24, 0.32), Vector3(0, -0.62, -0.01), k["m"]))
				for j in 3:
					o.append(_box(leg, Vector3(0.27 - j * 0.03, 0.05, 0.08), Vector3(0, -0.66 - j * 0.02, -0.18 - j * 0.04), k["trim" if j % 2 else "m"]))
			4:  # titanium boots with ankle wings and gold toe caps
				o.append(_box(leg, Vector3(0.3, 0.26, 0.34), Vector3(0, -0.61, -0.02), k["m"]))
				o.append(_box(leg, Vector3(0.24, 0.08, 0.08), Vector3(0, -0.68, -0.2), k["trim"]))
				var wing := _box(leg, Vector3(0.03, 0.12, 0.14), Vector3(0.16 * signf(leg.position.x), -0.52, 0.05), k["trim"])
				wing.rotation.x = -0.5
				o.append(wing)
				o.append(_box(leg, Vector3(0.05, 0.05, 0.02), Vector3(0, -0.52, -0.19), k["gem"]))
		o.append(_box(leg, Vector3(0.3, 0.03, 0.34), Vector3(0, -0.735, -0.02), k["trim"]))   # sole
	return o


## Grimskull's Twin-Flame Chestplate: dark plate with a bone ribcage, one
## shoulder burning, the other frozen in ice crystals.
static func _grim_chest(parts: Dictionary, k: Dictionary) -> Array:
	var root: Node3D = parts["root"]
	var o: Array = []
	var bone := _mat(Color(0.92, 0.9, 0.82), "bone")
	o.append(_box(root, Vector3(0.57, 0.63, 0.35), Vector3(0, 1.1, 0), k["m"]))
	o.append(_box(root, Vector3(0.06, 0.5, 0.03), Vector3(0, 1.1, -0.185), bone))   # spine of the ribcage
	for j in 4:
		o.append(_box(root, Vector3(0.38 - j * 0.04, 0.035, 0.03), Vector3(0, 1.3 - j * 0.1, -0.185), bone))
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.5, 0.12)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.4, 0.1)
	fire.emission_energy_multiplier = 2.0
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.55, 0.9, 1.0)
	ice.emission_enabled = true
	ice.emission = Color(0.3, 0.75, 1.0)
	ice.emission_energy_multiplier = 1.6
	for side in 2:
		var a: Node3D = [parts["arm_l"], parts["arm_r"]][side]
		o.append(_box(a, Vector3(0.33, 0.16, 0.35), Vector3(0, 0.03, 0), k["m"]))
		o.append(_box(a, Vector3(0.34, 0.03, 0.36), Vector3(0, -0.05, 0), bone))
		var glow: Material = fire if side == 0 else ice
		for j in 4:
			var f := _box(a, Vector3(0.07, 0.12 + j * 0.03, 0.07), Vector3(-0.08 + (j % 2) * 0.16, 0.16 + j * 0.02, -0.08 + (j / 2) * 0.16), glow)
			f.rotation.z = (j - 1.5) * 0.2
			o.append(f)
	o.append(_box(root, Vector3(0.14, 0.14, 0.04), Vector3(0, 0.92, -0.19), bone))   # a skull buckle
	o.append(_box(root, Vector3(0.03, 0.03, 0.02), Vector3(-0.035, 0.94, -0.212), fire))
	o.append(_box(root, Vector3(0.03, 0.03, 0.02), Vector3(0.035, 0.94, -0.212), ice))
	return o


## The Boots of the Yeti: huge, shaggy, with claws at the toes.
static func _yeti_boots(parts: Dictionary) -> Array:
	var o: Array = []
	var fur := _mat(Color(0.88, 0.93, 1.0), "fur")
	var claw := _mat(Color(0.25, 0.27, 0.32), "bone")
	for leg in [parts["leg_l"], parts["leg_r"]]:
		o.append(_box(leg, Vector3(0.34, 0.3, 0.38), Vector3(0, -0.6, -0.03), fur))
		o.append(_box(leg, Vector3(0.38, 0.1, 0.4), Vector3(0, -0.43, -0.02), fur))   # shaggy cuff
		for x in [-0.1, 0.0, 0.1]:
			o.append(_box(leg, Vector3(0.05, 0.05, 0.08), Vector3(x, -0.71, -0.24), claw))
	return o


## Hearts and frills on Cute gear.
static func _cute_bits(parts: Dictionary, slot: int) -> Array:
	var out: Array = []
	var heart := StandardMaterial3D.new()
	heart.albedo_color = Color(1.0, 0.35, 0.6)
	heart.emission_enabled = true
	heart.emission = Color(0.6, 0.1, 0.3)
	var frill := _mat(Color(1.0, 0.97, 0.99))
	match slot:
		0:
			out.append(_box(parts["head"], Vector3(0.12, 0.1, 0.03), Vector3(0, 0.26, -0.3), heart))
			for x in [-0.18, 0.18]:
				out.append(_box(parts["head"], Vector3(0.12, 0.12, 0.12), Vector3(x, 0.45, 0.0), heart))
		1:
			out.append(_box(parts["root"], Vector3(0.14, 0.12, 0.03), Vector3(0, 1.26, -0.22), heart))
			out.append(_box(parts["root"], Vector3(0.6, 0.05, 0.38), Vector3(0, 0.79, 0), frill))
		2:
			for leg in [parts["leg_l"], parts["leg_r"]]:
				out.append(_box(leg, Vector3(0.3, 0.05, 0.32), Vector3(0, -0.48, 0), frill))
		3:
			for leg in [parts["leg_l"], parts["leg_r"]]:
				out.append(_box(leg, Vector3(0.1, 0.08, 0.03), Vector3(0, -0.6, -0.22), heart))
	return out


## A cape hanging down the back, a little away from the body. Hero capes get a
## gold hem; royal capes a gold border and a high collar.
static func _cape(parts: Dictionary, id: String) -> Array:
	var d := Items.get_def(id)
	var c: Color = d.get("color", Color.RED)
	var tier: int = d.get("cape", 1)
	var cloth := _mat(c)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold := _mat(Color(1.0, 0.8, 0.3))
	gold.metallic = 0.6
	var out: Array = []
	var back := _box(parts["root"], Vector3(0.52, 0.78, 0.035), Vector3(0, 1.02, 0.2), cloth)
	back.rotation.x = -0.08   # hangs out a little at the bottom
	out.append(back)
	out.append(_box(parts["root"], Vector3(0.5, 0.06, 0.08), Vector3(0, 1.4, 0.17), _mat(c.darkened(0.3))))  # collar
	if tier >= 2:
		out.append(_box(back, Vector3(0.53, 0.05, 0.04), Vector3(0, -0.37, 0), gold))   # hem
	if tier >= 3:
		for x in [-0.255, 0.255]:
			out.append(_box(back, Vector3(0.03, 0.78, 0.04), Vector3(x, 0, 0), gold))
		out.append(_box(parts["root"], Vector3(0.56, 0.14, 0.06), Vector3(0, 1.47, 0.18), _mat(c.darkened(0.2))))
	return out


## An amulet on a chain, hanging on your chest (over any chestplate).
static func _pendant(parts: Dictionary, id: String) -> Array:
	var d := Items.get_def(id)
	var c: Color = d.get("color", Color(1.0, 0.84, 0.25))
	var metal := _mat(Color(1.0, 0.84, 0.3) if d.get("rarity", "") == "legendary" else c, "metal")
	metal.metallic = 0.7
	metal.roughness = 0.3
	var g: Color = d.get("gem", Color(0.4, 1.0, 0.5))
	var gem := StandardMaterial3D.new()
	gem.albedo_color = g
	gem.emission_enabled = true
	gem.emission = g
	gem.emission_energy_multiplier = 1.4
	var root: Node3D = parts["root"]
	var out: Array = []
	for sx in [-1.0, 1.0]:
		var link := _box(root, Vector3(0.025, 0.24, 0.025), Vector3(sx * 0.085, 1.36, -0.235), metal)
		link.rotation.z = sx * 0.55
		out.append(link)
	out.append(_box(root, Vector3(0.12, 0.12, 0.04), Vector3(0, 1.2, -0.24), metal))
	out.append(_box(root, Vector3(0.075, 0.075, 0.03), Vector3(0, 1.2, -0.262), gem))
	return out


static func _crown(head: Node3D) -> Array:
	var gold := _mat(Color(1.0, 0.8, 0.2))
	gold.metallic = 0.6
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(1.0, 0.35, 0.2)
	gem.emission_enabled = true
	gem.emission = Color(1.0, 0.4, 0.15)
	var out: Array = [_box(head, Vector3(0.52, 0.12, 0.52), Vector3(0, 0.3, 0), gold)]
	for p in [Vector3(-0.2, 0.42, -0.2), Vector3(0.2, 0.42, -0.2), Vector3(-0.2, 0.42, 0.2), Vector3(0.2, 0.42, 0.2), Vector3(0, 0.44, -0.22)]:
		out.append(_box(head, Vector3(0.1, 0.14, 0.1), p, gold))
	out.append(_box(head, Vector3(0.14, 0.12, 0.04), Vector3(0, 0.3, -0.27), gem))
	return out


## Walking and swinging. t = time in seconds.
static func animate(parts: Dictionary, t: float, moving: bool, swing: float, holding: bool) -> void:
	var walk := sin(t * 8.5) * 0.6 if moving else 0.0
	parts["leg_l"].rotation.x = walk
	parts["leg_r"].rotation.x = -walk
	parts["arm_l"].rotation.x = -walk * 0.8
	parts["arm_r"].rotation.x = walk * 0.8 - swing * 1.6 - (0.35 if holding else 0.0)
