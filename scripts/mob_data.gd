extends RefCounted
const Skins = preload("res://scripts/skins.gd")
const VillagerData = preload("res://scripts/villager_data.gd")
## Every mob type: stats, behavior, where it spawns, what it drops, and its
## blocky model.
##
## kind:
##   "passive" - runs away when hurt (bunny, chicken, deer, candy critters)
##   "neutral" - fights back when hurt (boar, ram)
##   "hostile" - hunts players on sight (wolf, cougar, bears, spiders, the King)
##   "npc"     - QtMaMe the trader: can't be hurt, helps fight hostile mobs
## spawn (a word or a list of words):
##   "animal"  - on grass/frosting under open sky, in daylight
##   "night"   - Minecraft-style: on the surface where light is 0 and it's night.
##               In daylight they run away and vanish once out of sight.
##   "cave"    - underground, where light is 0 (any time)
##   "boss" / "unique" - placed by mobs.gd, never randomly
## biome: "plains" (meadows, the default), "desert", "candy", "forest" or
## "mountain", or a list of them. Candy land has no hostile mobs.
## Bosses ("boss": true) give every player who hit them a locked treasure:
## "treasure": [[item, min, max], ...], with "signature" being the legendary item.
##   "fairy"   - tiny glowing helpers from fairy villages (see FAIRY_COLORS)
## loot: [item, min, max] rolled when it dies. You loot the corpse like a chest.
## model parts: size, pos (feet = origin, forward = -Z), color, and optional
##   "leg" (swings while walking) or "head" (part of the head group).

const BASE_MOBS := {
	"bunny": {
		"name": "Bunny", "kind": "passive", "hp": 3.0, "speed": 4.2, "size": Vector2(0.4, 0.45),
		"spawn": "animal", "weight": 4,
		"loot": [["raw_rabbit", 1, 1], ["rabbit_hide", 1, 1]],
		"parts": [
			{"size": Vector3(0.32, 0.28, 0.42), "pos": Vector3(0, 0.24, 0.02), "color": Color(0.80, 0.68, 0.54)},
			{"size": Vector3(0.26, 0.26, 0.26), "pos": Vector3(0, 0.42, -0.22), "color": Color(0.82, 0.70, 0.56), "head": true},
			{"size": Vector3(0.06, 0.22, 0.04), "pos": Vector3(-0.07, 0.63, -0.2), "color": Color(0.85, 0.74, 0.62), "head": true},
			{"size": Vector3(0.06, 0.22, 0.04), "pos": Vector3(0.07, 0.63, -0.2), "color": Color(0.85, 0.74, 0.62), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.07, 0.46, -0.355), "color": Color(0.1, 0.08, 0.08), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.07, 0.46, -0.355), "color": Color(0.1, 0.08, 0.08), "head": true},
			{"size": Vector3(0.12, 0.12, 0.1), "pos": Vector3(0, 0.3, 0.26), "color": Color(0.97, 0.96, 0.93)},
			{"size": Vector3(0.08, 0.12, 0.1), "pos": Vector3(-0.1, 0.06, -0.12), "color": Color(0.75, 0.63, 0.5), "leg": true},
			{"size": Vector3(0.08, 0.12, 0.1), "pos": Vector3(0.1, 0.06, -0.12), "color": Color(0.75, 0.63, 0.5), "leg": true},
			{"size": Vector3(0.1, 0.12, 0.16), "pos": Vector3(-0.11, 0.06, 0.14), "color": Color(0.75, 0.63, 0.5), "leg": true},
			{"size": Vector3(0.1, 0.12, 0.16), "pos": Vector3(0.11, 0.06, 0.14), "color": Color(0.75, 0.63, 0.5), "leg": true},
		],
	},
	"chicken": {
		"name": "Chicken", "kind": "passive", "hp": 4.0, "speed": 2.6, "size": Vector2(0.4, 0.75),
		"spawn": "animal", "weight": 3,
		"loot": [["raw_chicken", 1, 1], ["feather", 1, 3]],
		"parts": [
			{"size": Vector3(0.38, 0.34, 0.48), "pos": Vector3(0, 0.42, 0.02), "color": Color(0.96, 0.96, 0.93)},
			{"size": Vector3(0.24, 0.3, 0.22), "pos": Vector3(0, 0.72, -0.22), "color": Color(0.97, 0.97, 0.94), "head": true},
			{"size": Vector3(0.1, 0.07, 0.12), "pos": Vector3(0, 0.72, -0.38), "color": Color(0.95, 0.65, 0.15), "head": true},
			{"size": Vector3(0.06, 0.1, 0.12), "pos": Vector3(0, 0.9, -0.22), "color": Color(0.85, 0.12, 0.12), "head": true},
			{"size": Vector3(0.08, 0.1, 0.06), "pos": Vector3(0, 0.63, -0.33), "color": Color(0.85, 0.12, 0.12), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(-0.08, 0.78, -0.335), "color": Color(0.05, 0.05, 0.05), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(0.08, 0.78, -0.335), "color": Color(0.05, 0.05, 0.05), "head": true},
			{"size": Vector3(0.05, 0.26, 0.05), "pos": Vector3(-0.08, 0.13, 0), "color": Color(0.95, 0.75, 0.2), "leg": true},
			{"size": Vector3(0.05, 0.26, 0.05), "pos": Vector3(0.08, 0.13, 0), "color": Color(0.95, 0.75, 0.2), "leg": true},
		],
	},
	"deer": {
		"name": "Deer", "kind": "passive", "hp": 10.0, "speed": 5.5, "size": Vector2(0.8, 1.4),
		"spawn": "animal", "weight": 2,
		"loot": [["raw_venison", 2, 3], ["leather", 1, 2]],
		"parts": [
			{"size": Vector3(0.5, 0.5, 1.0), "pos": Vector3(0, 0.95, 0), "color": Color(0.62, 0.43, 0.27)},
			{"size": Vector3(0.22, 0.4, 0.22), "pos": Vector3(0, 1.3, -0.5), "color": Color(0.62, 0.43, 0.27), "head": true},
			{"size": Vector3(0.28, 0.28, 0.42), "pos": Vector3(0, 1.55, -0.62), "color": Color(0.64, 0.45, 0.29), "head": true},
			{"size": Vector3(0.04, 0.38, 0.04), "pos": Vector3(-0.11, 1.85, -0.56), "color": Color(0.86, 0.80, 0.68), "head": true},
			{"size": Vector3(0.04, 0.38, 0.04), "pos": Vector3(0.11, 1.85, -0.56), "color": Color(0.86, 0.80, 0.68), "head": true},
			{"size": Vector3(0.2, 0.04, 0.04), "pos": Vector3(-0.17, 1.95, -0.56), "color": Color(0.86, 0.80, 0.68), "head": true},
			{"size": Vector3(0.2, 0.04, 0.04), "pos": Vector3(0.17, 1.95, -0.56), "color": Color(0.86, 0.80, 0.68), "head": true},
			{"size": Vector3(0.12, 0.08, 0.06), "pos": Vector3(0, 1.5, -0.84), "color": Color(0.15, 0.1, 0.08), "head": true},
			{"size": Vector3(0.14, 0.14, 0.06), "pos": Vector3(0, 1.05, 0.52), "color": Color(0.96, 0.94, 0.9)},
			{"size": Vector3(0.11, 0.72, 0.11), "pos": Vector3(-0.16, 0.36, -0.38), "color": Color(0.55, 0.38, 0.24), "leg": true},
			{"size": Vector3(0.11, 0.72, 0.11), "pos": Vector3(0.16, 0.36, -0.38), "color": Color(0.55, 0.38, 0.24), "leg": true},
			{"size": Vector3(0.11, 0.72, 0.11), "pos": Vector3(-0.16, 0.36, 0.38), "color": Color(0.55, 0.38, 0.24), "leg": true},
			{"size": Vector3(0.11, 0.72, 0.11), "pos": Vector3(0.16, 0.36, 0.38), "color": Color(0.55, 0.38, 0.24), "leg": true},
		],
	},
	"boar": {
		"name": "Boar", "kind": "neutral", "hp": 14.0, "speed": 3.6, "damage": 3.0, "size": Vector2(0.8, 0.9),
		"spawn": "animal", "weight": 2,
		"loot": [["raw_pork", 2, 3], ["leather", 1, 1]],
		"parts": [
			{"size": Vector3(0.6, 0.55, 1.0), "pos": Vector3(0, 0.6, 0.05), "color": Color(0.36, 0.26, 0.19)},
			{"size": Vector3(0.12, 0.25, 0.7), "pos": Vector3(0, 0.95, 0.0), "color": Color(0.22, 0.16, 0.12)},
			{"size": Vector3(0.45, 0.42, 0.38), "pos": Vector3(0, 0.62, -0.6), "color": Color(0.38, 0.28, 0.2), "head": true},
			{"size": Vector3(0.22, 0.16, 0.08), "pos": Vector3(0, 0.55, -0.82), "color": Color(0.62, 0.44, 0.4), "head": true},
			{"size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(-0.15, 0.52, -0.83), "color": Color(0.95, 0.93, 0.85), "head": true},
			{"size": Vector3(0.05, 0.16, 0.05), "pos": Vector3(0.15, 0.52, -0.83), "color": Color(0.95, 0.93, 0.85), "head": true},
			{"size": Vector3(0.06, 0.06, 0.02), "pos": Vector3(-0.12, 0.72, -0.8), "color": Color(0.9, 0.3, 0.15), "head": true},
			{"size": Vector3(0.06, 0.06, 0.02), "pos": Vector3(0.12, 0.72, -0.8), "color": Color(0.9, 0.3, 0.15), "head": true},
			{"size": Vector3(0.15, 0.34, 0.15), "pos": Vector3(-0.18, 0.17, -0.32), "color": Color(0.28, 0.2, 0.15), "leg": true},
			{"size": Vector3(0.15, 0.34, 0.15), "pos": Vector3(0.18, 0.17, -0.32), "color": Color(0.28, 0.2, 0.15), "leg": true},
			{"size": Vector3(0.15, 0.34, 0.15), "pos": Vector3(-0.18, 0.17, 0.38), "color": Color(0.28, 0.2, 0.15), "leg": true},
			{"size": Vector3(0.15, 0.34, 0.15), "pos": Vector3(0.18, 0.17, 0.38), "color": Color(0.28, 0.2, 0.15), "leg": true},
		],
	},
	"ram": {
		"name": "Ram", "kind": "neutral", "hp": 12.0, "speed": 3.2, "damage": 2.5, "size": Vector2(0.8, 1.1),
		"spawn": "animal", "weight": 2,
		"loot": [["wool", 1, 3], ["raw_mutton", 1, 2]],
		"parts": [
			{"size": Vector3(0.7, 0.62, 1.0), "pos": Vector3(0, 0.78, 0.05), "color": Color(0.94, 0.93, 0.88)},
			{"size": Vector3(0.32, 0.36, 0.42), "pos": Vector3(0, 1.0, -0.62), "color": Color(0.78, 0.72, 0.64), "head": true},
			{"size": Vector3(0.12, 0.26, 0.26), "pos": Vector3(-0.22, 1.1, -0.55), "color": Color(0.55, 0.5, 0.44), "head": true},
			{"size": Vector3(0.12, 0.26, 0.26), "pos": Vector3(0.22, 1.1, -0.55), "color": Color(0.55, 0.5, 0.44), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.1, 1.06, -0.84), "color": Color(0.1, 0.08, 0.05), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.1, 1.06, -0.84), "color": Color(0.1, 0.08, 0.05), "head": true},
			{"size": Vector3(0.14, 0.48, 0.14), "pos": Vector3(-0.2, 0.24, -0.34), "color": Color(0.74, 0.68, 0.6), "leg": true},
			{"size": Vector3(0.14, 0.48, 0.14), "pos": Vector3(0.2, 0.24, -0.34), "color": Color(0.74, 0.68, 0.6), "leg": true},
			{"size": Vector3(0.14, 0.48, 0.14), "pos": Vector3(-0.2, 0.24, 0.4), "color": Color(0.74, 0.68, 0.6), "leg": true},
			{"size": Vector3(0.14, 0.48, 0.14), "pos": Vector3(0.2, 0.24, 0.4), "color": Color(0.74, 0.68, 0.6), "leg": true},
		],
	},
	"wolf": {
		"name": "Wolf", "kind": "hostile", "hp": 14.0, "speed": 5.6, "damage": 3.0, "size": Vector2(0.6, 0.85),
		"spawn": "night", "weight": 4, "sight": 20.0,
		"loot": [["wolf_pelt", 1, 1], ["raw_wolf", 0, 1]],
		"parts": [
			{"size": Vector3(0.42, 0.42, 0.9), "pos": Vector3(0, 0.6, 0.05), "color": Color(0.45, 0.45, 0.47)},
			{"size": Vector3(0.36, 0.34, 0.36), "pos": Vector3(0, 0.78, -0.55), "color": Color(0.48, 0.48, 0.5), "head": true},
			{"size": Vector3(0.18, 0.14, 0.22), "pos": Vector3(0, 0.7, -0.8), "color": Color(0.38, 0.38, 0.4), "head": true},
			{"size": Vector3(0.08, 0.14, 0.06), "pos": Vector3(-0.12, 1.0, -0.5), "color": Color(0.38, 0.38, 0.4), "head": true},
			{"size": Vector3(0.08, 0.14, 0.06), "pos": Vector3(0.12, 1.0, -0.5), "color": Color(0.38, 0.38, 0.4), "head": true},
			{"size": Vector3(0.06, 0.05, 0.02), "pos": Vector3(-0.1, 0.83, -0.735), "color": Color(1.0, 0.85, 0.2), "head": true},
			{"size": Vector3(0.06, 0.05, 0.02), "pos": Vector3(0.1, 0.83, -0.735), "color": Color(1.0, 0.85, 0.2), "head": true},
			{"size": Vector3(0.1, 0.1, 0.45), "pos": Vector3(0, 0.66, 0.68), "color": Color(0.4, 0.4, 0.42)},
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(-0.13, 0.21, -0.3), "color": Color(0.4, 0.4, 0.42), "leg": true},
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(0.13, 0.21, -0.3), "color": Color(0.4, 0.4, 0.42), "leg": true},
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(-0.13, 0.21, 0.36), "color": Color(0.4, 0.4, 0.42), "leg": true},
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(0.13, 0.21, 0.36), "color": Color(0.4, 0.4, 0.42), "leg": true},
		],
	},
	"cougar": {
		"name": "Cougar", "kind": "hostile", "hp": 18.0, "speed": 6.4, "damage": 4.0, "size": Vector2(0.7, 0.9),
		"spawn": "night", "weight": 2, "sight": 22.0,
		"loot": [["cougar_pelt", 1, 1], ["raw_cougar", 1, 2]],
		"parts": [
			{"size": Vector3(0.45, 0.42, 1.05), "pos": Vector3(0, 0.62, 0.05), "color": Color(0.78, 0.62, 0.4)},
			{"size": Vector3(0.36, 0.32, 0.34), "pos": Vector3(0, 0.82, -0.62), "color": Color(0.8, 0.64, 0.42), "head": true},
			{"size": Vector3(0.2, 0.12, 0.12), "pos": Vector3(0, 0.74, -0.84), "color": Color(0.92, 0.84, 0.7), "head": true},
			{"size": Vector3(0.08, 0.1, 0.05), "pos": Vector3(-0.12, 1.02, -0.6), "color": Color(0.5, 0.38, 0.25), "head": true},
			{"size": Vector3(0.08, 0.1, 0.05), "pos": Vector3(0.12, 1.02, -0.6), "color": Color(0.5, 0.38, 0.25), "head": true},
			{"size": Vector3(0.07, 0.05, 0.02), "pos": Vector3(-0.1, 0.87, -0.795), "color": Color(0.5, 0.9, 0.3), "head": true},
			{"size": Vector3(0.07, 0.05, 0.02), "pos": Vector3(0.1, 0.87, -0.795), "color": Color(0.5, 0.9, 0.3), "head": true},
			{"size": Vector3(0.08, 0.08, 0.75), "pos": Vector3(0, 0.6, 0.9), "color": Color(0.72, 0.56, 0.36)},
			{"size": Vector3(0.12, 0.45, 0.12), "pos": Vector3(-0.14, 0.22, -0.34), "color": Color(0.74, 0.58, 0.38), "leg": true},
			{"size": Vector3(0.12, 0.45, 0.12), "pos": Vector3(0.14, 0.22, -0.34), "color": Color(0.74, 0.58, 0.38), "leg": true},
			{"size": Vector3(0.12, 0.45, 0.12), "pos": Vector3(-0.14, 0.22, 0.4), "color": Color(0.74, 0.58, 0.38), "leg": true},
			{"size": Vector3(0.12, 0.45, 0.12), "pos": Vector3(0.14, 0.22, 0.4), "color": Color(0.74, 0.58, 0.38), "leg": true},
		],
	},
	"bear": {
		"name": "Bear", "kind": "hostile", "hp": 40.0, "speed": 4.2, "damage": 7.0, "size": Vector2(1.3, 1.5),
		"spawn": "night", "weight": 1, "sight": 16.0,
		"loot": [["bear_pelt", 1, 1], ["raw_bear", 3, 5]],
		"parts": [
			{"size": Vector3(1.1, 1.0, 1.7), "pos": Vector3(0, 1.05, 0.05), "color": Color(0.33, 0.22, 0.14)},
			{"size": Vector3(0.66, 0.62, 0.6), "pos": Vector3(0, 1.3, -1.05), "color": Color(0.35, 0.24, 0.15), "head": true},
			{"size": Vector3(0.32, 0.26, 0.24), "pos": Vector3(0, 1.18, -1.42), "color": Color(0.55, 0.42, 0.3), "head": true},
			{"size": Vector3(0.12, 0.08, 0.04), "pos": Vector3(0, 1.26, -1.55), "color": Color(0.08, 0.05, 0.04), "head": true},
			{"size": Vector3(0.18, 0.18, 0.1), "pos": Vector3(-0.26, 1.66, -1.0), "color": Color(0.3, 0.2, 0.13), "head": true},
			{"size": Vector3(0.18, 0.18, 0.1), "pos": Vector3(0.26, 1.66, -1.0), "color": Color(0.3, 0.2, 0.13), "head": true},
			{"size": Vector3(0.08, 0.07, 0.02), "pos": Vector3(-0.17, 1.42, -1.355), "color": Color(0.05, 0.03, 0.02), "head": true},
			{"size": Vector3(0.08, 0.07, 0.02), "pos": Vector3(0.17, 1.42, -1.355), "color": Color(0.05, 0.03, 0.02), "head": true},
			{"size": Vector3(0.32, 0.6, 0.32), "pos": Vector3(-0.36, 0.3, -0.55), "color": Color(0.29, 0.19, 0.12), "leg": true},
			{"size": Vector3(0.32, 0.6, 0.32), "pos": Vector3(0.36, 0.3, -0.55), "color": Color(0.29, 0.19, 0.12), "leg": true},
			{"size": Vector3(0.32, 0.6, 0.32), "pos": Vector3(-0.36, 0.3, 0.6), "color": Color(0.29, 0.19, 0.12), "leg": true},
			{"size": Vector3(0.32, 0.6, 0.32), "pos": Vector3(0.36, 0.3, 0.6), "color": Color(0.29, 0.19, 0.12), "leg": true},
		],
	},
	"spider": {
		"name": "Giant Spider", "kind": "hostile", "hp": 20.0, "speed": 4.6, "damage": 4.0, "size": Vector2(1.2, 0.8),
		"spawn": "cave", "biome": "plains", "weight": 3, "sight": 16.0,
		"loot": [["spider_silk", 1, 3], ["venom_sac", 0, 1]],
		"parts": [
			{"size": Vector3(0.7, 0.5, 0.85), "pos": Vector3(0, 0.5, 0.25), "color": Color(0.14, 0.11, 0.1)},
			{"size": Vector3(0.48, 0.38, 0.45), "pos": Vector3(0, 0.48, -0.38), "color": Color(0.17, 0.13, 0.12), "head": true},
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(-0.12, 0.56, -0.61), "color": Color(0.95, 0.1, 0.1), "head": true},
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(0.12, 0.56, -0.61), "color": Color(0.95, 0.1, 0.1), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.05, 0.46, -0.61), "color": Color(0.95, 0.1, 0.1), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.05, 0.46, -0.61), "color": Color(0.95, 0.1, 0.1), "head": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(-0.55, 0.42, -0.3), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(0.55, 0.42, -0.3), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(-0.58, 0.42, -0.05), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(0.58, 0.42, -0.05), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(-0.58, 0.42, 0.2), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(0.58, 0.42, 0.2), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(-0.55, 0.42, 0.45), "color": Color(0.12, 0.1, 0.09), "leg": true},
			{"size": Vector3(0.75, 0.08, 0.08), "pos": Vector3(0.55, 0.42, 0.45), "color": Color(0.12, 0.1, 0.09), "leg": true},
		],
	},
}


const CANDY_MOBS := {
	"gummy_bear": {
		"name": "Gummy Bear", "kind": "passive", "hp": 6.0, "speed": 3.0, "size": Vector2(0.5, 0.75),
		"spawn": "animal", "biome": "candy", "weight": 3,
		"loot": [["gummy", 1, 2]],
		"parts": [
			{"size": Vector3(0.4, 0.4, 0.32), "pos": Vector3(0, 0.36, 0), "color": Color(0.95, 0.25, 0.3)},
			{"size": Vector3(0.32, 0.3, 0.3), "pos": Vector3(0, 0.7, -0.02), "color": Color(0.97, 0.3, 0.35), "head": true},
			{"size": Vector3(0.1, 0.1, 0.08), "pos": Vector3(-0.12, 0.88, -0.02), "color": Color(0.9, 0.2, 0.26), "head": true},
			{"size": Vector3(0.1, 0.1, 0.08), "pos": Vector3(0.12, 0.88, -0.02), "color": Color(0.9, 0.2, 0.26), "head": true},
			{"size": Vector3(0.14, 0.1, 0.06), "pos": Vector3(0, 0.65, -0.19), "color": Color(1.0, 0.55, 0.55), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.07, 0.74, -0.175), "color": Color(0.1, 0.05, 0.05), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.07, 0.74, -0.175), "color": Color(0.1, 0.05, 0.05), "head": true},
			{"size": Vector3(0.1, 0.22, 0.1), "pos": Vector3(-0.25, 0.42, 0), "color": Color(0.9, 0.22, 0.28), "leg": true},
			{"size": Vector3(0.1, 0.22, 0.1), "pos": Vector3(0.25, 0.42, 0), "color": Color(0.9, 0.22, 0.28), "leg": true},
			{"size": Vector3(0.14, 0.16, 0.14), "pos": Vector3(-0.1, 0.08, 0), "color": Color(0.9, 0.22, 0.28), "leg": true},
			{"size": Vector3(0.14, 0.16, 0.14), "pos": Vector3(0.1, 0.08, 0), "color": Color(0.9, 0.22, 0.28), "leg": true},
		],
	},
	"marshmallow": {
		"name": "Marshmallow", "kind": "passive", "hp": 5.0, "speed": 2.4, "size": Vector2(0.5, 0.6),
		"spawn": "animal", "biome": "candy", "weight": 3,
		"loot": [["marshmallow", 1, 2]],
		"parts": [
			{"size": Vector3(0.46, 0.46, 0.46), "pos": Vector3(0, 0.31, 0), "color": Color(0.98, 0.96, 0.94)},
			{"size": Vector3(0.48, 0.06, 0.48), "pos": Vector3(0, 0.56, 0), "color": Color(0.85, 0.65, 0.42)},
			{"size": Vector3(0.06, 0.07, 0.02), "pos": Vector3(-0.1, 0.38, -0.235), "color": Color(0.15, 0.1, 0.1), "head": true},
			{"size": Vector3(0.06, 0.07, 0.02), "pos": Vector3(0.1, 0.38, -0.235), "color": Color(0.15, 0.1, 0.1), "head": true},
			{"size": Vector3(0.08, 0.04, 0.02), "pos": Vector3(-0.16, 0.3, -0.234), "color": Color(1.0, 0.65, 0.75), "head": true},
			{"size": Vector3(0.08, 0.04, 0.02), "pos": Vector3(0.16, 0.3, -0.234), "color": Color(1.0, 0.65, 0.75), "head": true},
			{"size": Vector3(0.08, 0.03, 0.02), "pos": Vector3(0, 0.28, -0.234), "color": Color(0.4, 0.2, 0.2), "head": true},
			{"size": Vector3(0.12, 0.08, 0.14), "pos": Vector3(-0.12, 0.04, -0.05), "color": Color(1.0, 0.7, 0.8), "leg": true},
			{"size": Vector3(0.12, 0.08, 0.14), "pos": Vector3(0.12, 0.04, -0.05), "color": Color(1.0, 0.7, 0.8), "leg": true},
		],
	},
	"peppermint_pig": {
		"name": "Peppermint Pig", "kind": "passive", "hp": 8.0, "speed": 3.0, "size": Vector2(0.7, 0.8),
		"spawn": "animal", "biome": "candy", "weight": 2,
		"loot": [["peppermint", 1, 2], ["candy_cane", 0, 1]],
		"parts": [
			{"size": Vector3(0.6, 0.5, 0.75), "pos": Vector3(0, 0.45, 0), "color": Color(0.98, 0.97, 0.95)},
			{"size": Vector3(0.62, 0.52, 0.12), "pos": Vector3(0, 0.45, -0.2), "color": Color(0.92, 0.15, 0.2)},
			{"size": Vector3(0.62, 0.52, 0.12), "pos": Vector3(0, 0.45, 0.12), "color": Color(0.92, 0.15, 0.2)},
			{"size": Vector3(0.4, 0.38, 0.36), "pos": Vector3(0, 0.6, -0.5), "color": Color(0.98, 0.97, 0.95), "head": true},
			{"size": Vector3(0.2, 0.14, 0.06), "pos": Vector3(0, 0.55, -0.7), "color": Color(1.0, 0.6, 0.7), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.1, 0.68, -0.685), "color": Color(0.1, 0.05, 0.05), "head": true},
			{"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.1, 0.68, -0.685), "color": Color(0.1, 0.05, 0.05), "head": true},
			{"size": Vector3(0.1, 0.1, 0.06), "pos": Vector3(-0.13, 0.82, -0.47), "color": Color(0.92, 0.15, 0.2), "head": true},
			{"size": Vector3(0.1, 0.1, 0.06), "pos": Vector3(0.13, 0.82, -0.47), "color": Color(0.92, 0.15, 0.2), "head": true},
			{"size": Vector3(0.14, 0.25, 0.14), "pos": Vector3(-0.17, 0.125, -0.25), "color": Color(0.92, 0.15, 0.2), "leg": true},
			{"size": Vector3(0.14, 0.25, 0.14), "pos": Vector3(0.17, 0.125, -0.25), "color": Color(0.92, 0.15, 0.2), "leg": true},
			{"size": Vector3(0.14, 0.25, 0.14), "pos": Vector3(-0.17, 0.125, 0.25), "color": Color(0.92, 0.15, 0.2), "leg": true},
			{"size": Vector3(0.14, 0.25, 0.14), "pos": Vector3(0.17, 0.125, 0.25), "color": Color(0.92, 0.15, 0.2), "leg": true},
		],
	},
	"qtmame": {
		"name": "QtMaMe", "kind": "npc", "hp": 1.0, "speed": 3.2, "damage": 1.5, "size": Vector2(0.6, 1.75),
		"spawn": "unique", "biome": "candy", "weight": 0, "label": "QtMaMe", "label_color": Color(1.0, 0.6, 0.85),
		"loot": [],
		"parts": [
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(-0.09, 0.25, 0), "color": Color(0.95, 0.8, 0.68), "leg": true},
			{"size": Vector3(0.11, 0.42, 0.11), "pos": Vector3(0.09, 0.25, 0), "color": Color(0.95, 0.8, 0.68), "leg": true},
			{"size": Vector3(0.14, 0.08, 0.18), "pos": Vector3(-0.09, 0.04, -0.02), "color": Color(1.0, 0.45, 0.7)},
			{"size": Vector3(0.14, 0.08, 0.18), "pos": Vector3(0.09, 0.04, -0.02), "color": Color(1.0, 0.45, 0.7)},
			{"size": Vector3(0.56, 0.5, 0.4), "pos": Vector3(0, 0.68, 0), "color": Color(1.0, 0.55, 0.78)},
			{"size": Vector3(0.58, 0.06, 0.42), "pos": Vector3(0, 0.45, 0), "color": Color(1.0, 0.9, 0.95)},
			{"size": Vector3(0.36, 0.32, 0.26), "pos": Vector3(0, 1.08, 0), "color": Color(1.0, 0.68, 0.85)},
			{"size": Vector3(0.1, 0.42, 0.1), "pos": Vector3(-0.24, 1.0, 0), "color": Color(0.95, 0.8, 0.68)},
			{"size": Vector3(0.1, 0.42, 0.1), "pos": Vector3(0.24, 1.0, 0), "color": Color(0.95, 0.8, 0.68)},
			{"size": Vector3(0.42, 0.42, 0.42), "pos": Vector3(0, 1.45, 0), "color": Color(0.96, 0.82, 0.7), "head": true},
			{"size": Vector3(0.46, 0.16, 0.46), "pos": Vector3(0, 1.66, 0.01), "color": Color(0.55, 0.32, 0.25), "head": true},
			{"size": Vector3(0.46, 0.4, 0.1), "pos": Vector3(0, 1.45, 0.2), "color": Color(0.55, 0.32, 0.25), "head": true},
			{"size": Vector3(0.13, 0.32, 0.13), "pos": Vector3(-0.29, 1.4, 0.06), "color": Color(0.55, 0.32, 0.25), "head": true},
			{"size": Vector3(0.13, 0.32, 0.13), "pos": Vector3(0.29, 1.4, 0.06), "color": Color(0.55, 0.32, 0.25), "head": true},
			{"size": Vector3(0.28, 0.12, 0.1), "pos": Vector3(0, 1.79, 0.05), "color": Color(1.0, 0.35, 0.65), "head": true},
			{"size": Vector3(0.1, 0.12, 0.02), "pos": Vector3(-0.09, 1.48, -0.215), "color": Color(0.2, 0.12, 0.2), "head": true},
			{"size": Vector3(0.1, 0.12, 0.02), "pos": Vector3(0.09, 1.48, -0.215), "color": Color(0.2, 0.12, 0.2), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(-0.11, 1.51, -0.222), "color": Color(1, 1, 1), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(0.07, 1.51, -0.222), "color": Color(1, 1, 1), "head": true},
			{"size": Vector3(0.07, 0.04, 0.02), "pos": Vector3(-0.15, 1.4, -0.212), "color": Color(1.0, 0.6, 0.7), "head": true},
			{"size": Vector3(0.07, 0.04, 0.02), "pos": Vector3(0.15, 1.4, -0.212), "color": Color(1.0, 0.6, 0.7), "head": true},
			{"size": Vector3(0.1, 0.03, 0.02), "pos": Vector3(0, 1.37, -0.212), "color": Color(0.8, 0.3, 0.4), "head": true},
		],
	},
}

static var MOBS := {}


static func _static_init() -> void:
	MOBS = BASE_MOBS.duplicate(true)
	MOBS.merge(CANDY_MOBS.duplicate(true))
	for t in BASE_MOBS:
		if not MOBS[t].has("biome"):
			MOBS[t]["biome"] = "plains"
	# Desert cousins: the same shapes in sandy colors.
	var sand_bear: Dictionary = BASE_MOBS["bear"].duplicate(true)
	sand_bear.merge({"name": "Sand Bear", "hp": 44.0, "damage": 7.5, "biome": "desert", "weight": 2,
			"loot": [["sand_bear_pelt", 1, 1], ["raw_bear", 2, 4]]}, true)
	sand_bear["parts"] = _recolor(sand_bear["parts"], 0.11)
	MOBS["sand_bear"] = sand_bear
	var sand_spider: Dictionary = BASE_MOBS["spider"].duplicate(true)
	sand_spider.merge({"name": "Sand Spider", "hp": 22.0, "damage": 4.5, "speed": 4.8, "biome": "desert",
			"spawn": ["night", "cave"], "weight": 3, "loot": [["spider_silk", 1, 3], ["venom_sac", 0, 1]]}, true)
	sand_spider["parts"] = _recolor(sand_spider["parts"], 0.09, 4.5)
	MOBS["sand_spider"] = sand_spider
	# The boss: a giant golden cougar wearing a crown with a huge glowing gem.
	var king: Dictionary = BASE_MOBS["cougar"].duplicate(true)
	king.merge({"name": "King Cougar", "kind": "hostile", "boss": true, "hp": 420.0, "damage": 11.0,
			"speed": 5.4, "sight": 30.0, "size": Vector2(1.7, 2.3), "spawn": "boss", "biome": "desert",
			"weight": 0, "loot": []}, true)
	var parts: Array = []
	for part in king["parts"]:
		var p: Dictionary = part.duplicate()
		p["size"] = p["size"] * 2.4
		p["pos"] = p["pos"] * 2.4
		p["color"] = (p["color"] as Color).lerp(Color(0.95, 0.75, 0.4), 0.35)
		parts.append(p)
	var gold := Color(1.0, 0.8, 0.2)
	var hz := -1.49  # the head's z after scaling
	parts.append({"size": Vector3(0.92, 0.18, 0.86), "pos": Vector3(0, 2.43, hz), "color": gold, "head": true})
	for c in [Vector3(-0.36, 2.62, hz - 0.34), Vector3(0.36, 2.62, hz - 0.34), Vector3(-0.36, 2.62, hz + 0.34), Vector3(0.36, 2.62, hz + 0.34), Vector3(0, 2.66, hz - 0.38)]:
		parts.append({"size": Vector3(0.14, 0.24, 0.14), "pos": c, "color": gold, "head": true})
	parts.append({"size": Vector3(0.32, 0.28, 0.08), "pos": Vector3(0, 2.45, hz - 0.45), "color": Color(1.0, 0.9, 0.35), "head": true, "glow": true})
	king["parts"] = parts
	king["treasure"] = [["king_crown", 1, 1], ["king_pelt", 1, 1], ["gold_ingot", 2, 4], ["raw_cougar", 3, 3]]
	king["signature"] = "king_crown"
	MOBS["king_cougar"] = king

	# Meadow animals and hunters also live in the tall forest.
	for t in ["bunny", "chicken", "deer", "boar", "wolf", "cougar", "bear", "spider"]:
		MOBS[t]["biome"] = ["plains", "forest"]

	# --- Snowy mountains --------------------------------------------------------------
	var hare: Dictionary = BASE_MOBS["bunny"].duplicate(true)
	hare.merge({"name": "Snow Hare", "biome": "mountain", "loot": [["raw_rabbit", 1, 1], ["hare_fur", 1, 1]]}, true)
	hare["parts"] = _tint(hare["parts"], Color(0.97, 0.98, 1.0), 0.85)
	MOBS["snow_hare"] = hare
	var goat: Dictionary = BASE_MOBS["ram"].duplicate(true)
	goat.merge({"name": "Mountain Goat", "biome": "mountain", "hp": 14.0, "speed": 3.6, "damage": 3.0,
			"loot": [["raw_goat", 1, 2], ["goat_horn", 0, 1], ["wool", 0, 1]]}, true)
	goat["parts"] = _tint(goat["parts"], Color(0.9, 0.9, 0.88), 0.6)
	goat["parts"].append({"size": Vector3(0.06, 0.34, 0.06), "pos": Vector3(-0.1, 1.38, -0.55), "color": Color(0.35, 0.32, 0.28), "head": true})
	goat["parts"].append({"size": Vector3(0.06, 0.34, 0.06), "pos": Vector3(0.1, 1.38, -0.55), "color": Color(0.35, 0.32, 0.28), "head": true})
	goat["parts"].append({"size": Vector3(0.12, 0.14, 0.06), "pos": Vector3(0, 0.82, -0.84), "color": Color(0.97, 0.97, 0.95), "head": true})
	MOBS["mountain_goat"] = goat
	var polar: Dictionary = BASE_MOBS["bear"].duplicate(true)
	polar.merge({"name": "Polar Bear", "hp": 52.0, "damage": 8.0, "biome": "mountain", "weight": 2, "spawn": ["night", "cave"],
			"loot": [["polar_bear_pelt", 1, 1], ["raw_polar_bear", 2, 4]]}, true)
	polar["parts"] = _tint(polar["parts"], Color(0.95, 0.96, 0.98), 0.8)
	MOBS["polar_bear"] = polar
	var dire: Dictionary = BASE_MOBS["wolf"].duplicate(true)
	dire.merge({"name": "Dire Wolf", "hp": 26.0, "damage": 5.0, "speed": 6.0, "size": Vector2(0.85, 1.2), "biome": "mountain",
			"weight": 3, "spawn": ["night", "cave"], "loot": [["dire_wolf_pelt", 1, 1], ["raw_wolf", 1, 2]]}, true)
	var big_parts: Array = []
	for part in dire["parts"]:
		var p: Dictionary = part.duplicate()
		p["size"] = p["size"] * 1.4
		p["pos"] = p["pos"] * 1.4
		var c: Color = p["color"]
		if c.r < 0.9:
			p["color"] = c.darkened(0.25)
		big_parts.append(p)
	dire["parts"] = big_parts
	MOBS["dire_wolf"] = dire

	# The Yeti: a huge white furry giant who lives at the bottom of mine shafts.
	var fur := Color(0.92, 0.94, 0.98)
	var shade := Color(0.78, 0.82, 0.9)
	var face := Color(0.55, 0.7, 0.85)
	MOBS["yeti"] = {
		"name": "Yeti", "kind": "hostile", "boss": true, "hp": 700.0, "damage": 16.0, "speed": 4.4, "sight": 26.0,
		"size": Vector2(1.6, 3.1), "spawn": "boss", "biome": "mountain", "weight": 0, "loot": [],
		"treasure": [["yeti_boots", 1, 1], ["yeti_fur", 1, 1], ["titanium_ingot", 2, 4], ["raw_goat", 3, 3]],
		"signature": "yeti_boots",
		"parts": [
			{"size": Vector3(0.5, 1.1, 0.55), "pos": Vector3(-0.38, 0.55, 0), "color": shade, "leg": true},
			{"size": Vector3(0.5, 1.1, 0.55), "pos": Vector3(0.38, 0.55, 0), "color": shade, "leg": true},
			{"size": Vector3(0.6, 0.18, 0.75), "pos": Vector3(-0.38, 0.09, -0.1), "color": face},
			{"size": Vector3(0.6, 0.18, 0.75), "pos": Vector3(0.38, 0.09, -0.1), "color": face},
			{"size": Vector3(1.5, 1.35, 0.95), "pos": Vector3(0, 1.75, 0), "color": fur},
			{"size": Vector3(1.0, 0.5, 0.2), "pos": Vector3(0, 1.6, -0.5), "color": shade},
			{"size": Vector3(0.42, 1.45, 0.45), "pos": Vector3(-0.98, 1.55, 0), "color": fur},
			{"size": Vector3(0.42, 1.45, 0.45), "pos": Vector3(0.98, 1.55, 0), "color": fur},
			{"size": Vector3(0.46, 0.3, 0.5), "pos": Vector3(-0.98, 0.72, -0.05), "color": face},
			{"size": Vector3(0.46, 0.3, 0.5), "pos": Vector3(0.98, 0.72, -0.05), "color": face},
			{"size": Vector3(0.95, 0.85, 0.85), "pos": Vector3(0, 2.78, -0.05), "color": fur, "head": true},
			{"size": Vector3(0.62, 0.48, 0.06), "pos": Vector3(0, 2.72, -0.5), "color": face, "head": true},
			{"size": Vector3(0.12, 0.12, 0.03), "pos": Vector3(-0.16, 2.84, -0.535), "color": Color(0.05, 0.08, 0.15), "head": true},
			{"size": Vector3(0.12, 0.12, 0.03), "pos": Vector3(0.16, 2.84, -0.535), "color": Color(0.05, 0.08, 0.15), "head": true},
			{"size": Vector3(0.36, 0.1, 0.03), "pos": Vector3(0, 2.6, -0.535), "color": Color(0.2, 0.25, 0.4), "head": true},
			{"size": Vector3(0.06, 0.1, 0.03), "pos": Vector3(-0.12, 2.56, -0.54), "color": Color(0.97, 0.97, 0.95), "head": true},
			{"size": Vector3(0.06, 0.1, 0.03), "pos": Vector3(0.12, 2.56, -0.54), "color": Color(0.97, 0.97, 0.95), "head": true},
			{"size": Vector3(0.14, 0.34, 0.14), "pos": Vector3(-0.42, 3.25, -0.05), "color": Color(0.7, 0.62, 0.5), "head": true},
			{"size": Vector3(0.14, 0.34, 0.14), "pos": Vector3(0.42, 3.25, -0.05), "color": Color(0.7, 0.62, 0.5), "head": true},
		],
	}

	# --- Fall forest critters (cute, and they run away; no meat) ------------------------
	var sq := Color(0.72, 0.42, 0.22)
	MOBS["squirrel"] = {
		"name": "Squirrel", "kind": "passive", "hp": 3.0, "speed": 5.0, "size": Vector2(0.35, 0.45),
		"spawn": "animal", "biome": "fall", "weight": 4, "loot": [["acorn", 1, 3]],
		"parts": [
			{"size": Vector3(0.24, 0.26, 0.34), "pos": Vector3(0, 0.2, 0.02), "color": sq},
			{"size": Vector3(0.2, 0.2, 0.2), "pos": Vector3(0, 0.36, -0.2), "color": sq.lightened(0.05), "head": true},
			{"size": Vector3(0.05, 0.08, 0.04), "pos": Vector3(-0.07, 0.5, -0.2), "color": sq.darkened(0.2), "head": true},
			{"size": Vector3(0.05, 0.08, 0.04), "pos": Vector3(0.07, 0.5, -0.2), "color": sq.darkened(0.2), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(-0.05, 0.39, -0.305), "color": Color(0.08, 0.06, 0.05), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(0.05, 0.39, -0.305), "color": Color(0.08, 0.06, 0.05), "head": true},
			{"size": Vector3(0.1, 0.12, 0.1), "pos": Vector3(0, 0.22, -0.1), "color": Color(0.95, 0.88, 0.75)},
			{"size": Vector3(0.18, 0.42, 0.14), "pos": Vector3(0, 0.42, 0.24), "color": sq.lightened(0.12)},   # big fluffy tail
			{"size": Vector3(0.18, 0.14, 0.18), "pos": Vector3(0, 0.66, 0.18), "color": sq.lightened(0.18)},
			{"size": Vector3(0.06, 0.1, 0.08), "pos": Vector3(-0.08, 0.05, -0.08), "color": sq.darkened(0.15), "leg": true},
			{"size": Vector3(0.06, 0.1, 0.08), "pos": Vector3(0.08, 0.05, -0.08), "color": sq.darkened(0.15), "leg": true},
			{"size": Vector3(0.07, 0.1, 0.1), "pos": Vector3(-0.08, 0.05, 0.1), "color": sq.darkened(0.15), "leg": true},
			{"size": Vector3(0.07, 0.1, 0.1), "pos": Vector3(0.08, 0.05, 0.1), "color": sq.darkened(0.15), "leg": true},
		],
	}
	var spine := Color(0.45, 0.35, 0.27)
	MOBS["hedgehog"] = {
		"name": "Hedgehog", "kind": "passive", "hp": 4.0, "speed": 2.4, "size": Vector2(0.4, 0.35),
		"spawn": "animal", "biome": "fall", "weight": 3, "loot": [["quill", 1, 3]],
		"parts": [
			{"size": Vector3(0.36, 0.26, 0.42), "pos": Vector3(0, 0.18, 0.04), "color": spine},
			{"size": Vector3(0.3, 0.08, 0.36), "pos": Vector3(0, 0.33, 0.06), "color": spine.darkened(0.2)},   # spikes
			{"size": Vector3(0.2, 0.16, 0.16), "pos": Vector3(0, 0.15, -0.2), "color": Color(0.9, 0.78, 0.62), "head": true},
			{"size": Vector3(0.06, 0.05, 0.06), "pos": Vector3(0, 0.13, -0.3), "color": Color(0.1, 0.08, 0.08), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(-0.06, 0.19, -0.285), "color": Color(0.08, 0.06, 0.05), "head": true},
			{"size": Vector3(0.04, 0.04, 0.02), "pos": Vector3(0.06, 0.19, -0.285), "color": Color(0.08, 0.06, 0.05), "head": true},
			{"size": Vector3(0.06, 0.06, 0.06), "pos": Vector3(-0.1, 0.03, -0.08), "color": Color(0.85, 0.72, 0.58), "leg": true},
			{"size": Vector3(0.06, 0.06, 0.06), "pos": Vector3(0.1, 0.03, -0.08), "color": Color(0.85, 0.72, 0.58), "leg": true},
			{"size": Vector3(0.06, 0.06, 0.06), "pos": Vector3(-0.1, 0.03, 0.14), "color": Color(0.85, 0.72, 0.58), "leg": true},
			{"size": Vector3(0.06, 0.06, 0.06), "pos": Vector3(0.1, 0.03, 0.14), "color": Color(0.85, 0.72, 0.58), "leg": true},
		],
	}
	var fox: Dictionary = BASE_MOBS["wolf"].duplicate(true)
	fox.merge({"name": "Fox", "kind": "passive", "hp": 8.0, "speed": 5.8, "damage": 0.0, "size": Vector2(0.5, 0.65),
			"spawn": "animal", "biome": "fall", "weight": 2, "loot": [["fox_fur", 1, 1]]}, true)
	var fox_parts: Array = []
	for part in fox["parts"]:
		var p: Dictionary = part.duplicate()
		p["size"] = p["size"] * 0.75
		p["pos"] = p["pos"] * 0.75
		var c: Color = p["color"]
		if c.r > 0.9:
			p["color"] = Color(0.12, 0.1, 0.08)   # eyes
		else:
			p["color"] = Color(0.92, 0.48, 0.18).lerp(c, 0.15)
		fox_parts.append(p)
	fox_parts.append({"size": Vector3(0.1, 0.1, 0.14), "pos": Vector3(0, 0.5, 0.8), "color": Color(0.97, 0.95, 0.9)})   # white tail tip
	fox_parts.append({"size": Vector3(0.2, 0.12, 0.06), "pos": Vector3(0, 0.5, -0.62), "color": Color(0.97, 0.95, 0.9), "head": true})   # white chin
	fox["parts"] = fox_parts
	MOBS["fox"] = fox

	# --- Cave monsters (never in the meadows, and only away from spawn) -------------------
	var gskin := Color(0.42, 0.62, 0.32)
	MOBS["gremlin"] = {
		"name": "Cave Gremlin", "kind": "hostile", "hp": 12.0, "speed": 5.4, "damage": 2.5, "size": Vector2(0.55, 0.9),
		"spawn": "cave", "biome": ["forest", "candy", "desert", "mountain", "fall"], "weight": 4, "sight": 16.0,
		"min_dist": 260.0,
		"loot": [["gremlin_tooth", 1, 2], ["copper_ore", 0, 2], ["tin_ore", 0, 1]],
		"parts": [
			{"size": Vector3(0.36, 0.38, 0.28), "pos": Vector3(0, 0.45, 0), "color": gskin},
			{"size": Vector3(0.42, 0.34, 0.36), "pos": Vector3(0, 0.82, -0.04), "color": gskin.lightened(0.05), "head": true},
			{"size": Vector3(0.26, 0.08, 0.06), "pos": Vector3(-0.3, 0.92, 0.0), "color": gskin, "head": true},   # big pointy ears
			{"size": Vector3(0.26, 0.08, 0.06), "pos": Vector3(0.3, 0.92, 0.0), "color": gskin, "head": true},
			{"size": Vector3(0.09, 0.09, 0.02), "pos": Vector3(-0.1, 0.86, -0.23), "color": Color(1.0, 0.9, 0.2), "head": true},
			{"size": Vector3(0.09, 0.09, 0.02), "pos": Vector3(0.1, 0.86, -0.23), "color": Color(1.0, 0.9, 0.2), "head": true},
			{"size": Vector3(0.2, 0.05, 0.02), "pos": Vector3(0, 0.72, -0.23), "color": Color(0.95, 0.93, 0.85), "head": true},   # grin
			{"size": Vector3(0.1, 0.3, 0.1), "pos": Vector3(-0.24, 0.48, -0.04), "color": gskin.darkened(0.1)},
			{"size": Vector3(0.1, 0.3, 0.1), "pos": Vector3(0.24, 0.48, -0.04), "color": gskin.darkened(0.1)},
			{"size": Vector3(0.38, 0.12, 0.3), "pos": Vector3(0, 0.3, 0), "color": Color(0.4, 0.28, 0.18)},   # ragged shorts
			{"size": Vector3(0.12, 0.26, 0.12), "pos": Vector3(-0.1, 0.13, 0), "color": gskin.darkened(0.15), "leg": true},
			{"size": Vector3(0.12, 0.26, 0.12), "pos": Vector3(0.1, 0.13, 0), "color": gskin.darkened(0.15), "leg": true},
		],
	}
	var rock := Color(0.48, 0.55, 0.45)
	MOBS["cave_troll"] = {
		"name": "Cave Troll", "kind": "hostile", "hp": 90.0, "speed": 3.0, "damage": 9.0, "size": Vector2(1.3, 2.6),
		"spawn": "cave", "biome": ["forest", "candy", "desert", "mountain", "fall"], "weight": 1, "sight": 18.0,
		"min_dist": 480.0,
		"loot": [["troll_hide", 1, 1], ["iron_ore", 2, 4], ["silver_ore", 0, 2], ["gremlin_tooth", 0, 2]],
		"parts": [
			{"size": Vector3(0.4, 0.9, 0.45), "pos": Vector3(-0.3, 0.45, 0), "color": rock.darkened(0.1), "leg": true},
			{"size": Vector3(0.4, 0.9, 0.45), "pos": Vector3(0.3, 0.45, 0), "color": rock.darkened(0.1), "leg": true},
			{"size": Vector3(1.2, 1.0, 0.8), "pos": Vector3(0, 1.4, 0.05), "color": rock},
			{"size": Vector3(0.9, 0.3, 0.6), "pos": Vector3(0, 1.0, -0.1), "color": Color(0.38, 0.28, 0.18)},   # loincloth
			{"size": Vector3(0.36, 1.2, 0.4), "pos": Vector3(-0.8, 1.25, -0.05), "color": rock.lightened(0.05)},
			{"size": Vector3(0.36, 1.2, 0.4), "pos": Vector3(0.8, 1.25, -0.05), "color": rock.lightened(0.05)},
			{"size": Vector3(0.44, 0.34, 0.46), "pos": Vector3(0.8, 0.52, -0.1), "color": Color(0.42, 0.35, 0.28)},   # a big club
			{"size": Vector3(0.7, 0.6, 0.6), "pos": Vector3(0, 2.2, -0.15), "color": rock.lightened(0.08), "head": true},
			{"size": Vector3(0.22, 0.14, 0.2), "pos": Vector3(0, 2.15, -0.5), "color": rock.darkened(0.15), "head": true},   # big nose
			{"size": Vector3(0.1, 0.1, 0.02), "pos": Vector3(-0.17, 2.32, -0.46), "color": Color(1.0, 0.55, 0.15), "head": true},
			{"size": Vector3(0.1, 0.1, 0.02), "pos": Vector3(0.17, 2.32, -0.46), "color": Color(1.0, 0.55, 0.15), "head": true},
			{"size": Vector3(0.06, 0.14, 0.04), "pos": Vector3(-0.16, 1.98, -0.46), "color": Color(0.95, 0.93, 0.82), "head": true},   # tusks
			{"size": Vector3(0.06, 0.14, 0.04), "pos": Vector3(0.16, 1.98, -0.46), "color": Color(0.95, 0.93, 0.82), "head": true},
		],
	}

	# --- The Deep (gen 12 worlds): pale albino cave creatures with pink eyes --------------
	# Tougher than the caves above, and they sometimes carry gems.
	var everywhere := ["plains", "forest", "candy", "desert", "mountain", "fall", "spooky", "sky", "chess", "fastfood"]
	for al in [["spider", "albino_spider", "Albino Spider", 3, [["spider_silk", 1, 3], ["amethyst", 0, 1]]],
			["gremlin", "albino_gremlin", "Albino Gremlin", 4, [["gremlin_tooth", 1, 2], ["ruby", 0, 1], ["sapphire", 0, 1]]],
			["cave_troll", "albino_troll", "Albino Troll", 1, [["troll_hide", 1, 1], ["iron_ore", 2, 4], ["diamond", 0, 1], ["onyx_gem", 0, 1]]]]:
		var base: Dictionary = MOBS[al[0]] if MOBS.has(al[0]) else BASE_MOBS[al[0]]
		var pale: Dictionary = base.duplicate(true)
		pale.merge({"name": al[2], "hp": float(base["hp"]) * 1.4, "damage": float(base["damage"]) * 1.3, "spawn": "cave",
				"biome": everywhere, "weight": al[3], "min_dist": 0.0, "deep": true, "hot": false, "loot": al[4]}, true)
		pale["parts"] = _albino(base["parts"])
		MOBS[al[1]] = pale

	# --- The lava caverns (gen 14): fiery parts of the Deep ---------------------------------
	# Everything here is fireproof and lives only where the Deep runs hot.
	var ember := Color(1.0, 0.5, 0.12)
	var coal := Color(0.18, 0.1, 0.08)
	MOBS["fire_imp"] = {
		"name": "Fire Imp", "kind": "hostile", "hp": 32.0, "speed": 5.2, "damage": 6.0, "size": Vector2(0.6, 1.0),
		"spawn": "cave", "biome": everywhere, "weight": 4, "sight": 18.0, "deep": true, "hot": true, "fireproof": true,
		"ranged": {"range": 14.0, "every": 2.8, "damage": 5.0, "speed": 18.0, "shot": "fireball", "effect": "fire"},
		"loot": [["ember", 1, 2], ["ruby", 0, 1]],
		"parts": [
			{"size": Vector3(0.36, 0.4, 0.28), "pos": Vector3(0, 0.5, 0), "color": Color(0.85, 0.22, 0.1)},
			{"size": Vector3(0.4, 0.36, 0.36), "pos": Vector3(0, 0.88, -0.03), "color": Color(0.9, 0.28, 0.12), "head": true},
			{"size": Vector3(0.06, 0.2, 0.06), "pos": Vector3(-0.14, 1.12, -0.03), "color": coal, "head": true},   # little horns
			{"size": Vector3(0.06, 0.2, 0.06), "pos": Vector3(0.14, 1.12, -0.03), "color": coal, "head": true},
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(-0.09, 0.92, -0.22), "color": Color(1.0, 0.95, 0.4), "head": true, "glow": true},
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(0.09, 0.92, -0.22), "color": Color(1.0, 0.95, 0.4), "head": true, "glow": true},
			{"size": Vector3(0.3, 0.14, 0.3), "pos": Vector3(0, 1.1, 0.0), "color": ember, "head": true, "glow": true},    # flame hair
			{"size": Vector3(0.36, 0.06, 0.2), "pos": Vector3(-0.32, 0.68, 0.12), "color": coal},                          # bat wings
			{"size": Vector3(0.36, 0.06, 0.2), "pos": Vector3(0.32, 0.68, 0.12), "color": coal},
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(-0.1, 0.15, 0), "color": Color(0.6, 0.15, 0.08), "leg": true},
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(0.1, 0.15, 0), "color": Color(0.6, 0.15, 0.08), "leg": true},
		],
	}
	MOBS["magma_slime"] = {
		"name": "Magma Slime", "kind": "hostile", "hp": 44.0, "speed": 3.2, "damage": 7.0, "size": Vector2(0.95, 0.9),
		"spawn": "cave", "biome": everywhere, "weight": 3, "sight": 14.0, "deep": true, "hot": true, "fireproof": true,
		"loot": [["magma_rock", 1, 3], ["ember", 0, 2]],
		"parts": [
			{"size": Vector3(0.9, 0.7, 0.9), "pos": Vector3(0, 0.35, 0), "color": Color(0.32, 0.12, 0.08)},
			{"size": Vector3(0.7, 0.5, 0.7), "pos": Vector3(0, 0.36, 0), "color": ember, "glow": true},
			{"size": Vector3(0.94, 0.12, 0.94), "pos": Vector3(0, 0.72, 0), "color": Color(0.4, 0.16, 0.1), "head": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(-0.18, 0.5, -0.46), "color": Color(1.0, 0.9, 0.3), "head": true, "glow": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(0.18, 0.5, -0.46), "color": Color(1.0, 0.9, 0.3), "head": true, "glow": true},
		],
	}
	var scale_c := Color(0.75, 0.18, 0.1)
	MOBS["fire_drake"] = {
		"name": "Fire Drake", "kind": "hostile", "hp": 64.0, "speed": 5.8, "damage": 9.0, "size": Vector2(1.1, 1.0),
		"spawn": "cave", "biome": everywhere, "weight": 2, "sight": 24.0, "deep": true, "hot": true, "fireproof": true, "fly": true,
		"ranged": {"range": 18.0, "every": 2.4, "damage": 6.0, "speed": 20.0, "shot": "fireball", "effect": "fire"},
		"loot": [["drake_scale", 1, 2], ["ember", 1, 2], ["sapphire", 0, 1]],
		"parts": [
			{"size": Vector3(0.6, 0.5, 1.1), "pos": Vector3(0, 0.6, 0.05), "color": scale_c},
			{"size": Vector3(0.44, 0.4, 0.56), "pos": Vector3(0, 0.9, -0.7), "color": scale_c.lightened(0.08), "head": true},
			{"size": Vector3(0.3, 0.2, 0.3), "pos": Vector3(0, 0.82, -1.05), "color": scale_c.darkened(0.1), "head": true},    # snout
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(-0.13, 0.98, -0.99), "color": Color(1.0, 0.9, 0.2), "head": true, "glow": true},
			{"size": Vector3(0.08, 0.08, 0.02), "pos": Vector3(0.13, 0.98, -0.99), "color": Color(1.0, 0.9, 0.2), "head": true, "glow": true},
			{"size": Vector3(0.06, 0.24, 0.06), "pos": Vector3(-0.14, 1.18, -0.6), "color": coal, "head": true},
			{"size": Vector3(0.06, 0.24, 0.06), "pos": Vector3(0.14, 1.18, -0.6), "color": coal, "head": true},
			{"size": Vector3(1.1, 0.06, 0.7), "pos": Vector3(-0.85, 0.85, 0.0), "color": Color(0.5, 0.12, 0.08)},   # wings
			{"size": Vector3(1.1, 0.06, 0.7), "pos": Vector3(0.85, 0.85, 0.0), "color": Color(0.5, 0.12, 0.08)},
			{"size": Vector3(0.26, 0.24, 0.8), "pos": Vector3(0, 0.6, 0.9), "color": scale_c.darkened(0.12)},        # tail
			{"size": Vector3(0.2, 0.06, 0.2), "pos": Vector3(0, 0.88, 0.4), "color": ember, "glow": true},           # glowing belly fire
			{"size": Vector3(0.16, 0.36, 0.16), "pos": Vector3(-0.22, 0.2, -0.3), "color": scale_c.darkened(0.2), "leg": true},
			{"size": Vector3(0.16, 0.36, 0.16), "pos": Vector3(0.22, 0.2, -0.3), "color": scale_c.darkened(0.2), "leg": true},
		],
	}
	# The boss: a huge giant of black rock with lava running through his cracks,
	# a beard and hair of flame, and a stomp that shakes the ground.
	var rock2 := Color(0.2, 0.15, 0.14)
	var lava2 := Color(1.0, 0.48, 0.1)
	MOBS["fire_giant"] = {
		"name": "Fire Giant", "kind": "hostile", "boss": true, "hp": 2200.0, "damage": 22.0, "speed": 3.4, "sight": 32.0,
		"size": Vector2(1.9, 4.6), "spawn": "boss", "biome": everywhere, "weight": 0, "fireproof": true, "deep": true, "hot": true,
		"slam": 6.0, "slam_fire": true, "enrage": true,
		"ranged": {"range": 24.0, "every": 2.2, "damage": 7.0, "speed": 20.0, "chase": true, "shots": [["fireball", 7.0, "fire"], ["fireball", 7.0, "fire"]]},
		"summon": {"type": "imp_minion", "every": 18.0, "count": 2, "max": 4},
		"loot": [],
		"treasure": [["giant_heart", 1, 1], ["titanium_ingot", 3, 6], ["ruby", 1, 3], ["diamond", 0, 2], ["ember", 4, 8], ["drake_scale", 1, 3]],
		"signature": "giant_heart",
		"parts": [
			{"size": Vector3(0.7, 1.7, 0.75), "pos": Vector3(-0.5, 0.85, 0), "color": rock2, "leg": true},
			{"size": Vector3(0.7, 1.7, 0.75), "pos": Vector3(0.5, 0.85, 0), "color": rock2, "leg": true},
			{"size": Vector3(0.22, 1.2, 0.05), "pos": Vector3(-0.5, 0.9, -0.39), "color": lava2, "glow": true, "leg": true},   # lava cracks
			{"size": Vector3(0.22, 1.2, 0.05), "pos": Vector3(0.5, 0.9, -0.39), "color": lava2, "glow": true, "leg": true},
			{"size": Vector3(1.9, 1.6, 1.1), "pos": Vector3(0, 2.5, 0), "color": rock2.lightened(0.05)},
			{"size": Vector3(0.9, 1.0, 0.05), "pos": Vector3(0, 2.5, -0.56), "color": lava2, "glow": true},                    # glowing chest
			{"size": Vector3(2.0, 0.3, 1.2), "pos": Vector3(0, 1.75, 0), "color": Color(0.35, 0.22, 0.12)},                    # belt
			{"size": Vector3(0.3, 0.25, 0.08), "pos": Vector3(0, 1.75, -0.62), "color": Color(1.0, 0.8, 0.25)},                 # gold buckle
			{"size": Vector3(0.6, 1.8, 0.65), "pos": Vector3(-1.3, 2.4, 0), "color": rock2},
			{"size": Vector3(0.6, 1.8, 0.65), "pos": Vector3(1.3, 2.4, 0), "color": rock2},
			{"size": Vector3(0.7, 0.6, 0.7), "pos": Vector3(-1.3, 1.35, 0), "color": lava2.darkened(0.2), "glow": true},      # burning fists
			{"size": Vector3(0.7, 0.6, 0.7), "pos": Vector3(1.3, 1.35, 0), "color": lava2.darkened(0.2), "glow": true},
			{"size": Vector3(1.0, 1.0, 1.0), "pos": Vector3(0, 3.8, -0.1), "color": rock2.lightened(0.1), "head": true},
			{"size": Vector3(0.18, 0.14, 0.04), "pos": Vector3(-0.24, 3.92, -0.61), "color": Color(1.0, 0.95, 0.4), "head": true, "glow": true},
			{"size": Vector3(0.18, 0.14, 0.04), "pos": Vector3(0.24, 3.92, -0.61), "color": Color(1.0, 0.95, 0.4), "head": true, "glow": true},
			{"size": Vector3(0.9, 0.5, 0.3), "pos": Vector3(0, 3.35, -0.55), "color": lava2, "head": true, "glow": true},       # flame beard
			{"size": Vector3(1.1, 0.5, 1.1), "pos": Vector3(0, 4.45, -0.05), "color": Color(1.0, 0.62, 0.15), "head": true, "glow": true},  # flame hair
			{"size": Vector3(0.6, 0.4, 0.6), "pos": Vector3(0, 4.85, 0.05), "color": Color(1.0, 0.85, 0.3), "head": true, "glow": true},
		],
	}
	var imp_minion: Dictionary = MOBS["fire_imp"].duplicate(true)
	imp_minion.merge({"spawn": "summon", "weight": 0, "loot": [["ember", 0, 1]]}, true)
	MOBS["imp_minion"] = imp_minion

	# --- The spooky forest (mid-game: about iron-gear strength) ---------------------------
	# By day: black cats and crows (harmless) and scarecrows (fight back if you
	# hit them). At night: zombies, ghosts and witches come hunting.
	var black := Color(0.1, 0.1, 0.13)
	MOBS["black_cat"] = {
		"name": "Black Cat", "kind": "passive", "hp": 6.0, "speed": 5.0, "size": Vector2(0.4, 0.55),
		"spawn": "animal", "biome": "spooky", "weight": 3, "loot": [],
		"parts": [
			{"size": Vector3(0.28, 0.26, 0.56), "pos": Vector3(0, 0.3, 0.04), "color": black},
			{"size": Vector3(0.26, 0.24, 0.24), "pos": Vector3(0, 0.46, -0.3), "color": black, "head": true},
			{"size": Vector3(0.07, 0.1, 0.04), "pos": Vector3(-0.08, 0.62, -0.3), "color": black, "head": true},
			{"size": Vector3(0.07, 0.1, 0.04), "pos": Vector3(0.08, 0.62, -0.3), "color": black, "head": true},
			{"size": Vector3(0.06, 0.05, 0.02), "pos": Vector3(-0.06, 0.48, -0.425), "color": Color(0.7, 1.0, 0.3), "head": true},
			{"size": Vector3(0.06, 0.05, 0.02), "pos": Vector3(0.06, 0.48, -0.425), "color": Color(0.7, 1.0, 0.3), "head": true},
			{"size": Vector3(0.06, 0.06, 0.4), "pos": Vector3(0, 0.55, 0.4), "color": black},   # tail held up
			{"size": Vector3(0.07, 0.2, 0.07), "pos": Vector3(-0.09, 0.1, -0.18), "color": black, "leg": true},
			{"size": Vector3(0.07, 0.2, 0.07), "pos": Vector3(0.09, 0.1, -0.18), "color": black, "leg": true},
			{"size": Vector3(0.07, 0.2, 0.07), "pos": Vector3(-0.09, 0.1, 0.24), "color": black, "leg": true},
			{"size": Vector3(0.07, 0.2, 0.07), "pos": Vector3(0.09, 0.1, 0.24), "color": black, "leg": true},
		],
	}
	var crow: Dictionary = BASE_MOBS["chicken"].duplicate(true)
	crow.merge({"name": "Crow", "biome": "spooky", "weight": 3, "speed": 3.4, "loot": [["feather", 1, 3]]}, true)
	var crow_parts: Array = []
	for part in crow["parts"]:
		var p: Dictionary = part.duplicate()
		var c: Color = p["color"]
		p["color"] = Color(0.12, 0.12, 0.16) if c.r > 0.9 and c.g > 0.9 else (Color(0.3, 0.3, 0.32) if c.g > 0.5 else c)
		if c.r > 0.8 and c.g < 0.2:
			p["color"] = Color(0.15, 0.15, 0.2)   # no red comb on a crow
		crow_parts.append(p)
	crow["parts"] = crow_parts
	MOBS["crow"] = crow
	var straw := Color(0.88, 0.74, 0.35)
	var shirt := Color(0.55, 0.3, 0.25)
	MOBS["scarecrow"] = {
		"name": "Scarecrow", "kind": "neutral", "hp": 24.0, "speed": 2.6, "damage": 4.0, "size": Vector2(0.7, 1.9),
		"spawn": "animal", "biome": "spooky", "weight": 2, "sight": 14.0,
		"loot": [["hay_bale", 0, 1], ["pumpkin", 0, 1], ["stick", 1, 3], ["candy_corn", 0, 2]],
		"parts": [
			{"size": Vector3(0.08, 0.9, 0.08), "pos": Vector3(0, 0.45, 0), "color": Color(0.45, 0.32, 0.2), "leg": true},   # the pole
			{"size": Vector3(0.6, 0.7, 0.32), "pos": Vector3(0, 1.25, 0), "color": shirt},
			{"size": Vector3(0.06, 0.6, 0.06), "pos": Vector3(-0.12, 1.25, -0.17), "color": shirt.darkened(0.3)},   # patches
			{"size": Vector3(1.5, 0.12, 0.12), "pos": Vector3(0, 1.45, 0), "color": shirt.darkened(0.15)},   # arms out wide
			{"size": Vector3(0.14, 0.14, 0.14), "pos": Vector3(-0.8, 1.45, 0), "color": straw},   # straw hands
			{"size": Vector3(0.14, 0.14, 0.14), "pos": Vector3(0.8, 1.45, 0), "color": straw},
			{"size": Vector3(0.5, 0.48, 0.5), "pos": Vector3(0, 1.85, 0), "color": Color(0.95, 0.55, 0.15), "head": true},   # pumpkin head
			{"size": Vector3(0.1, 0.08, 0.02), "pos": Vector3(-0.12, 1.92, -0.255), "color": Color(1.0, 0.9, 0.35), "head": true},
			{"size": Vector3(0.1, 0.08, 0.02), "pos": Vector3(0.12, 1.92, -0.255), "color": Color(1.0, 0.9, 0.35), "head": true},
			{"size": Vector3(0.28, 0.05, 0.02), "pos": Vector3(0, 1.76, -0.255), "color": Color(1.0, 0.9, 0.35), "head": true},
			{"size": Vector3(0.6, 0.06, 0.6), "pos": Vector3(0, 2.11, 0), "color": Color(0.5, 0.38, 0.22), "head": true},   # floppy hat
			{"size": Vector3(0.3, 0.18, 0.3), "pos": Vector3(0, 2.22, 0), "color": Color(0.5, 0.38, 0.22), "head": true},
		],
	}
	var zskin := Color(0.45, 0.62, 0.45)
	MOBS["zombie"] = {
		"name": "Zombie", "kind": "hostile", "hp": 26.0, "speed": 3.3, "damage": 4.5, "size": Vector2(0.6, 1.8),
		"spawn": "night", "biome": "spooky", "weight": 4, "sight": 18.0,
		"loot": [["candy_corn", 0, 2], ["iron_ore", 0, 1], ["leather", 0, 1]],
		"parts": [
			{"size": Vector3(0.22, 0.72, 0.24), "pos": Vector3(-0.13, 0.36, 0), "color": Color(0.25, 0.3, 0.5), "leg": true},
			{"size": Vector3(0.22, 0.72, 0.24), "pos": Vector3(0.13, 0.36, 0), "color": Color(0.25, 0.3, 0.5), "leg": true},
			{"size": Vector3(0.5, 0.62, 0.28), "pos": Vector3(0, 1.03, 0), "color": Color(0.3, 0.55, 0.6)},   # torn shirt
			{"size": Vector3(0.16, 0.16, 0.7), "pos": Vector3(-0.33, 1.25, -0.3), "color": zskin},   # arms out in front
			{"size": Vector3(0.16, 0.16, 0.7), "pos": Vector3(0.33, 1.25, -0.3), "color": zskin},
			{"size": Vector3(0.46, 0.46, 0.46), "pos": Vector3(0, 1.58, 0), "color": zskin, "head": true},
			{"size": Vector3(0.1, 0.06, 0.02), "pos": Vector3(-0.1, 1.62, -0.235), "color": Color(0.05, 0.05, 0.05), "head": true},
			{"size": Vector3(0.1, 0.06, 0.02), "pos": Vector3(0.1, 1.62, -0.235), "color": Color(0.05, 0.05, 0.05), "head": true},
			{"size": Vector3(0.18, 0.05, 0.02), "pos": Vector3(0, 1.47, -0.235), "color": Color(0.2, 0.3, 0.2), "head": true},
		],
	}
	MOBS["ghost"] = {
		"name": "Ghost", "kind": "hostile", "hp": 18.0, "speed": 4.4, "damage": 4.0, "size": Vector2(0.7, 1.7),
		"spawn": "night", "biome": "spooky", "weight": 3, "sight": 22.0,
		"loot": [["ectoplasm", 1, 2], ["candy_corn", 0, 1]],
		"parts": [
			{"size": Vector3(0.7, 0.9, 0.6), "pos": Vector3(0, 0.95, 0), "color": Color(0.92, 0.95, 1.0)},   # floating sheet
			{"size": Vector3(0.6, 0.5, 0.55), "pos": Vector3(0, 1.55, 0), "color": Color(0.95, 0.97, 1.0), "head": true},
			{"size": Vector3(0.16, 0.12, 0.6), "pos": Vector3(-0.25, 0.45, 0), "color": Color(0.88, 0.9, 0.96), "leg": true},   # wavy hem
			{"size": Vector3(0.16, 0.18, 0.6), "pos": Vector3(0.0, 0.42, 0), "color": Color(0.88, 0.9, 0.96), "leg": true},
			{"size": Vector3(0.16, 0.12, 0.6), "pos": Vector3(0.25, 0.45, 0), "color": Color(0.88, 0.9, 0.96), "leg": true},
			{"size": Vector3(0.12, 0.16, 0.02), "pos": Vector3(-0.12, 1.6, -0.285), "color": Color(0.1, 0.1, 0.15), "head": true},
			{"size": Vector3(0.12, 0.16, 0.02), "pos": Vector3(0.12, 1.6, -0.285), "color": Color(0.1, 0.1, 0.15), "head": true},
			{"size": Vector3(0.12, 0.12, 0.02), "pos": Vector3(0, 1.42, -0.285), "color": Color(0.1, 0.1, 0.15), "head": true},   # "ooo"
		],
	}
	var wskin := Color(0.55, 0.75, 0.45)
	var dress := Color(0.32, 0.18, 0.42)
	MOBS["witch"] = {
		"name": "Witch", "kind": "hostile", "hp": 30.0, "speed": 3.8, "damage": 5.5, "size": Vector2(0.6, 2.0),
		"spawn": "night", "biome": "spooky", "weight": 2, "sight": 22.0,
		"loot": [["candy_corn", 1, 3], ["ectoplasm", 0, 1], ["witch_hat", 1, 1, 0.12]],
		"parts": [
			{"size": Vector3(0.56, 0.8, 0.5), "pos": Vector3(0, 0.4, 0), "color": dress, "leg": true},   # long dress
			{"size": Vector3(0.48, 0.55, 0.3), "pos": Vector3(0, 1.08, 0), "color": dress.lightened(0.08)},
			{"size": Vector3(0.14, 0.55, 0.14), "pos": Vector3(-0.32, 1.05, 0), "color": dress},
			{"size": Vector3(0.14, 0.55, 0.14), "pos": Vector3(0.32, 1.05, 0), "color": dress},
			{"size": Vector3(0.06, 1.3, 0.06), "pos": Vector3(0.42, 0.85, -0.12), "color": Color(0.45, 0.32, 0.2)},   # broom
			{"size": Vector3(0.18, 0.28, 0.18), "pos": Vector3(0.42, 0.18, -0.12), "color": Color(0.85, 0.72, 0.35)},
			{"size": Vector3(0.42, 0.42, 0.42), "pos": Vector3(0, 1.57, 0), "color": wskin, "head": true},
			{"size": Vector3(0.08, 0.14, 0.12), "pos": Vector3(0, 1.52, -0.26), "color": wskin.darkened(0.1), "head": true},   # pointy nose
			{"size": Vector3(0.08, 0.06, 0.02), "pos": Vector3(-0.1, 1.63, -0.215), "color": Color(0.9, 0.3, 0.9), "head": true},
			{"size": Vector3(0.08, 0.06, 0.02), "pos": Vector3(0.1, 1.63, -0.215), "color": Color(0.9, 0.3, 0.9), "head": true},
			{"size": Vector3(0.8, 0.06, 0.8), "pos": Vector3(0, 1.8, 0), "color": dress.darkened(0.2), "head": true},   # hat brim
			{"size": Vector3(0.38, 0.3, 0.38), "pos": Vector3(0, 1.98, 0), "color": dress.darkened(0.2), "head": true},
			{"size": Vector3(0.22, 0.3, 0.22), "pos": Vector3(0.04, 2.25, 0.04), "color": dress.darkened(0.2), "head": true},
			{"size": Vector3(0.1, 0.22, 0.1), "pos": Vector3(0.1, 2.45, 0.1), "color": dress.darkened(0.2), "head": true},
		],
	}

	# --- Floating islands: skeletons ----------------------------------------------------
	# Night: skeletons and skeleton archers (they shoot back!). Day: armored
	# skeleton knights and fast bone hounds guard the ruins.
	var bone := Color(0.9, 0.88, 0.8)
	var bone_dark := Color(0.7, 0.68, 0.6)
	var skel := {
		"name": "Skeleton", "kind": "hostile", "hp": 22.0, "speed": 3.8, "damage": 4.5, "size": Vector2(0.6, 1.9),
		"spawn": "night", "biome": "sky", "weight": 4, "sight": 20.0,
		"loot": [["bone", 1, 3], ["ancient_coin", 0, 1], ["iron_ingot", 0, 1]],
		"parts": [
			{"size": Vector3(0.1, 0.8, 0.1), "pos": Vector3(-0.12, 0.4, 0), "color": bone, "leg": true},
			{"size": Vector3(0.1, 0.8, 0.1), "pos": Vector3(0.12, 0.4, 0), "color": bone, "leg": true},
			{"size": Vector3(0.36, 0.1, 0.16), "pos": Vector3(0, 0.84, 0), "color": bone_dark},   # hips
			{"size": Vector3(0.08, 0.5, 0.08), "pos": Vector3(0, 1.12, 0.04), "color": bone},     # spine
			{"size": Vector3(0.4, 0.06, 0.2), "pos": Vector3(0, 1.0, 0.02), "color": bone},      # ribs
			{"size": Vector3(0.42, 0.06, 0.22), "pos": Vector3(0, 1.14, 0.02), "color": bone},
			{"size": Vector3(0.44, 0.06, 0.22), "pos": Vector3(0, 1.28, 0.02), "color": bone},
			{"size": Vector3(0.5, 0.08, 0.16), "pos": Vector3(0, 1.4, 0.02), "color": bone_dark},  # shoulders
			{"size": Vector3(0.08, 0.62, 0.08), "pos": Vector3(-0.28, 1.1, -0.04), "color": bone},
			{"size": Vector3(0.08, 0.62, 0.08), "pos": Vector3(0.28, 1.1, -0.04), "color": bone},
			{"size": Vector3(0.4, 0.4, 0.4), "pos": Vector3(0, 1.66, 0), "color": bone, "head": true},
			{"size": Vector3(0.1, 0.1, 0.02), "pos": Vector3(-0.09, 1.7, -0.205), "color": Color(0.08, 0.08, 0.1), "head": true},
			{"size": Vector3(0.1, 0.1, 0.02), "pos": Vector3(0.09, 1.7, -0.205), "color": Color(0.08, 0.08, 0.1), "head": true},
			{"size": Vector3(0.22, 0.05, 0.02), "pos": Vector3(0, 1.54, -0.205), "color": Color(0.3, 0.28, 0.25), "head": true},
		],
	}
	MOBS["skeleton"] = skel
	var archer: Dictionary = skel.duplicate(true)
	archer.merge({"name": "Skeleton Archer", "hp": 18.0, "damage": 3.0, "weight": 3, "sight": 24.0,
			"ranged": {"range": 16.0, "every": 2.4, "damage": 4.0, "speed": 22.0, "shot": "wooden_arrow"},
			"loot": [["bone", 1, 2], ["wooden_arrow", 1, 4], ["ancient_coin", 0, 1]]}, true)
	archer["parts"].append({"size": Vector3(0.06, 0.9, 0.06), "pos": Vector3(-0.36, 1.1, -0.15), "color": Color(0.5, 0.34, 0.2)})   # bow
	archer["parts"].append({"size": Vector3(0.02, 0.86, 0.02), "pos": Vector3(-0.3, 1.1, -0.15), "color": Color(0.9, 0.9, 0.85)})   # string
	MOBS["skeleton_archer"] = archer
	var knight: Dictionary = skel.duplicate(true)
	knight.merge({"name": "Skeleton Knight", "hp": 36.0, "damage": 6.0, "speed": 3.2, "spawn": "day", "weight": 3,
			"loot": [["bone", 1, 3], ["ancient_coin", 1, 2], ["silver_ingot", 0, 1], ["titanium_ore", 0, 1]]}, true)
	var steel := Color(0.55, 0.57, 0.62)
	knight["parts"].append({"size": Vector3(0.48, 0.56, 0.28), "pos": Vector3(0, 1.14, 0.02), "color": steel})   # breastplate
	knight["parts"].append({"size": Vector3(0.44, 0.24, 0.44), "pos": Vector3(0, 1.86, 0), "color": steel, "head": true})   # helmet
	knight["parts"].append({"size": Vector3(0.06, 0.2, 0.3), "pos": Vector3(0, 2.05, 0), "color": Color(0.7, 0.15, 0.15), "head": true})   # plume
	knight["parts"].append({"size": Vector3(0.08, 0.08, 0.9), "pos": Vector3(0.32, 0.95, -0.45), "color": Color(0.75, 0.75, 0.8)})   # sword
	knight["parts"].append({"size": Vector3(0.06, 0.5, 0.4), "pos": Vector3(-0.36, 1.1, -0.1), "color": Color(0.45, 0.32, 0.2)})   # shield
	MOBS["skeleton_knight"] = knight
	var hound: Dictionary = BASE_MOBS["wolf"].duplicate(true)
	hound.merge({"name": "Bone Hound", "hp": 16.0, "damage": 3.5, "speed": 6.4, "spawn": "day", "biome": "sky", "weight": 2,
			"loot": [["bone", 1, 3]]}, true)
	var hound_parts: Array = []
	for part in hound["parts"]:
		var p: Dictionary = part.duplicate()
		var c: Color = p["color"]
		p["color"] = Color(1.0, 0.35, 0.2) if c.r > 0.9 and c.g > 0.7 else bone.lerp(bone_dark, (1.0 - c.v))   # glowing red eyes
		hound_parts.append(p)
	hound["parts"] = hound_parts
	MOBS["bone_hound"] = hound

	# --- The castle boss: Grimskull, a huge two-headed black skeleton ----------------------
	# The left head breathes fire, the right head ice. Tier 3 (titanium) gear fight.
	var blk := Color(0.12, 0.11, 0.14)
	var blk2 := Color(0.22, 0.2, 0.25)
	var fire := Color(1.0, 0.45, 0.1)
	var ice := Color(0.4, 0.85, 1.0)
	MOBS["grimskull"] = {
		"name": "Grimskull", "kind": "hostile", "boss": true, "hp": 1200.0, "damage": 20.0, "speed": 3.9, "sight": 30.0,
		"size": Vector2(1.6, 3.4), "spawn": "boss", "biome": "sky", "weight": 0, "loot": [],
		"ranged": {"range": 26.0, "every": 1.7, "speed": 18.0, "chase": true,
				"shots": [["fireball", 6.0, "fire"], ["iceball", 5.0, "ice"]]},
		"treasure": [["grim_chestplate", 1, 1], ["bone", 6, 10], ["ancient_coin", 4, 8], ["titanium_ingot", 3, 5], ["gold_ingot", 2, 3]],
		"signature": "grim_chestplate",
		"parts": [
			{"size": Vector3(0.24, 1.3, 0.24), "pos": Vector3(-0.32, 0.65, 0), "color": blk, "leg": true},
			{"size": Vector3(0.24, 1.3, 0.24), "pos": Vector3(0.32, 0.65, 0), "color": blk, "leg": true},
			{"size": Vector3(0.9, 0.2, 0.4), "pos": Vector3(0, 1.35, 0), "color": blk2},               # hips
			{"size": Vector3(0.18, 1.0, 0.18), "pos": Vector3(0, 1.95, 0.06), "color": blk},           # spine
			{"size": Vector3(1.0, 0.12, 0.5), "pos": Vector3(0, 1.75, 0.04), "color": blk},           # ribs
			{"size": Vector3(1.1, 0.12, 0.52), "pos": Vector3(0, 2.0, 0.04), "color": blk},
			{"size": Vector3(1.15, 0.12, 0.52), "pos": Vector3(0, 2.25, 0.04), "color": blk},
			{"size": Vector3(1.5, 0.22, 0.42), "pos": Vector3(0, 2.5, 0.04), "color": blk2},          # wide shoulders
			{"size": Vector3(0.2, 1.3, 0.2), "pos": Vector3(-0.85, 1.85, -0.1), "color": blk},
			{"size": Vector3(0.2, 1.3, 0.2), "pos": Vector3(0.85, 1.85, -0.1), "color": blk},
			{"size": Vector3(0.3, 0.3, 0.3), "pos": Vector3(-0.85, 1.12, -0.2), "color": fire},       # a fiery fist
			{"size": Vector3(0.3, 0.3, 0.3), "pos": Vector3(0.85, 1.12, -0.2), "color": ice},         # an icy fist
			# Left head: fire.
			{"size": Vector3(0.62, 0.62, 0.62), "pos": Vector3(-0.42, 2.98, 0), "color": blk2, "head": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(-0.56, 3.04, -0.315), "color": fire, "head": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(-0.28, 3.04, -0.315), "color": fire, "head": true},
			{"size": Vector3(0.36, 0.08, 0.02), "pos": Vector3(-0.42, 2.8, -0.315), "color": fire.darkened(0.2), "head": true},
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(-0.62, 3.42, 0), "color": fire, "head": true},   # flame horns
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(-0.22, 3.42, 0), "color": fire, "head": true},
			# Right head: ice.
			{"size": Vector3(0.62, 0.62, 0.62), "pos": Vector3(0.42, 2.98, 0), "color": blk2, "head": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(0.28, 3.04, -0.315), "color": ice, "head": true},
			{"size": Vector3(0.14, 0.14, 0.02), "pos": Vector3(0.56, 3.04, -0.315), "color": ice, "head": true},
			{"size": Vector3(0.36, 0.08, 0.02), "pos": Vector3(0.42, 2.8, -0.315), "color": ice.darkened(0.2), "head": true},
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(0.22, 3.42, 0), "color": ice, "head": true},     # icicle horns
			{"size": Vector3(0.12, 0.3, 0.12), "pos": Vector3(0.62, 3.42, 0), "color": ice, "head": true},
		],
	}

	# --- The biome bosses (each lives in its own lair; see world.lair_in_region) -------

	# Boar King: a huge black boar with golden tusks and a crown. Calls boars to help.
	var bk: Dictionary = BASE_MOBS["boar"].duplicate(true)
	bk.merge({"name": "Boar King", "kind": "hostile", "boss": true, "hp": 260.0, "damage": 8.0, "speed": 5.0,
			"sight": 26.0, "size": Vector2(2.0, 2.2), "spawn": "boss", "biome": "plains", "weight": 0, "loot": [],
			"summon": {"type": "boar", "every": 18.0, "count": 2, "max": 4},
			"treasure": [["boar_king_ring", 1, 1], ["leather", 4, 6], ["raw_pork", 4, 6], ["bronze_ingot", 3, 5], ["iron_ingot", 1, 2]],
			"signature": "boar_king_ring"}, true)
	bk["parts"] = _scaled(bk["parts"], 2.4, Color(0.2, 0.15, 0.13), 0.35)
	var bk_head := _head_top(bk["parts"])
	bk["parts"].append_array(_crown_at(bk_head, 0.9))
	for sx in [-0.42, 0.42]:
		bk["parts"].append({"size": Vector3(0.14, 0.5, 0.14), "pos": Vector3(sx, 1.25, -2.05), "color": Color(1.0, 0.85, 0.35), "head": true})   # golden tusks
	MOBS["boar_king"] = bk

	# Old Oakheart: a walking oak giant with glowing eyes, throwing acorns.
	var bark := Color(0.4, 0.28, 0.16)
	var bark2 := Color(0.3, 0.2, 0.12)
	var leaf := Color(0.28, 0.55, 0.22)
	MOBS["oakheart"] = {
		"name": "Old Oakheart", "kind": "hostile", "boss": true, "hp": 360.0, "damage": 10.0, "speed": 2.8, "sight": 28.0,
		"size": Vector2(1.8, 4.0), "spawn": "boss", "biome": "forest", "weight": 0, "loot": [],
		"ranged": {"range": 22.0, "every": 2.4, "speed": 16.0, "chase": true, "shots": [["acorn", 5.0, ""]]},
		"summon": {"type": "wolf", "every": 25.0, "count": 2, "max": 3},
		"treasure": [["oakheart_amulet", 1, 1], ["log", 16, 24], ["iron_ingot", 2, 4], ["gold_ingot", 1, 2], ["stick", 8, 12]],
		"signature": "oakheart_amulet",
		"parts": [
			{"size": Vector3(0.6, 1.4, 0.6), "pos": Vector3(-0.5, 0.7, 0), "color": bark2, "leg": true},
			{"size": Vector3(0.6, 1.4, 0.6), "pos": Vector3(0.5, 0.7, 0), "color": bark2, "leg": true},
			{"size": Vector3(1.6, 1.8, 1.1), "pos": Vector3(0, 2.3, 0), "color": bark},
			{"size": Vector3(0.2, 1.6, 0.06), "pos": Vector3(-0.4, 2.3, -0.56), "color": bark2},     # bark lines
			{"size": Vector3(0.2, 1.4, 0.06), "pos": Vector3(0.35, 2.2, -0.56), "color": bark2},
			{"size": Vector3(0.45, 1.8, 0.45), "pos": Vector3(-1.1, 2.4, 0), "color": bark},        # branch arms
			{"size": Vector3(0.45, 1.8, 0.45), "pos": Vector3(1.1, 2.4, 0), "color": bark},
			{"size": Vector3(0.7, 0.5, 0.7), "pos": Vector3(-1.1, 1.4, -0.1), "color": leaf},
			{"size": Vector3(0.7, 0.5, 0.7), "pos": Vector3(1.1, 1.4, -0.1), "color": leaf},
			{"size": Vector3(1.2, 0.9, 1.0), "pos": Vector3(0, 3.55, -0.05), "color": bark, "head": true},
			{"size": Vector3(0.22, 0.18, 0.04), "pos": Vector3(-0.28, 3.65, -0.57), "color": Color(1.0, 0.9, 0.3), "head": true, "glow": true},
			{"size": Vector3(0.22, 0.18, 0.04), "pos": Vector3(0.28, 3.65, -0.57), "color": Color(1.0, 0.9, 0.3), "head": true, "glow": true},
			{"size": Vector3(0.6, 0.1, 0.04), "pos": Vector3(0, 3.3, -0.57), "color": bark2, "head": true},
			{"size": Vector3(2.2, 0.9, 1.8), "pos": Vector3(0, 4.3, 0), "color": leaf, "head": true},          # leafy crown
			{"size": Vector3(1.4, 0.6, 1.2), "pos": Vector3(0, 4.9, 0), "color": leaf.lightened(0.1), "head": true},
		],
	}

	# Gummy Giant: an enormous red gummy bear that flings gumballs.
	var gum := Color(0.92, 0.22, 0.3)
	var gum2 := Color(1.0, 0.45, 0.5)
	MOBS["gummy_giant"] = {
		"name": "Gummy Giant", "kind": "hostile", "boss": true, "hp": 550.0, "damage": 13.0, "speed": 3.6, "sight": 28.0,
		"size": Vector2(2.2, 3.6), "spawn": "boss", "biome": "candy", "weight": 0, "loot": [],
		"ranged": {"range": 24.0, "every": 2.0, "speed": 17.0, "chase": true, "shots": [["gumball", 7.0, ""]]},
		"treasure": [["gummy_leggings", 1, 1], ["cotton_candy", 8, 12], ["candy_cane", 8, 12], ["cutieite_ingot", 2, 4], ["iron_ingot", 2, 4]],
		"signature": "gummy_leggings",
		"parts": [
			{"size": Vector3(0.75, 1.0, 0.75), "pos": Vector3(-0.55, 0.5, 0), "color": gum, "leg": true},
			{"size": Vector3(0.75, 1.0, 0.75), "pos": Vector3(0.55, 0.5, 0), "color": gum, "leg": true},
			{"size": Vector3(2.0, 1.7, 1.5), "pos": Vector3(0, 1.85, 0), "color": gum},
			{"size": Vector3(1.2, 1.1, 0.1), "pos": Vector3(0, 1.8, -0.78), "color": gum2},             # tummy
			{"size": Vector3(0.6, 1.0, 0.6), "pos": Vector3(-1.25, 2.0, 0), "color": gum},
			{"size": Vector3(0.6, 1.0, 0.6), "pos": Vector3(1.25, 2.0, 0), "color": gum},
			{"size": Vector3(1.5, 1.2, 1.3), "pos": Vector3(0, 3.25, 0), "color": gum, "head": true},
			{"size": Vector3(0.45, 0.45, 0.3), "pos": Vector3(-0.6, 3.95, 0), "color": gum, "head": true},   # round ears
			{"size": Vector3(0.45, 0.45, 0.3), "pos": Vector3(0.6, 3.95, 0), "color": gum, "head": true},
			{"size": Vector3(0.24, 0.24, 0.04), "pos": Vector3(-0.32, 3.4, -0.67), "color": Color(1, 1, 1), "head": true},
			{"size": Vector3(0.24, 0.24, 0.04), "pos": Vector3(0.32, 3.4, -0.67), "color": Color(1, 1, 1), "head": true},
			{"size": Vector3(0.12, 0.12, 0.04), "pos": Vector3(-0.32, 3.38, -0.7), "color": Color(0.1, 0.05, 0.08), "head": true},
			{"size": Vector3(0.12, 0.12, 0.04), "pos": Vector3(0.32, 3.38, -0.7), "color": Color(0.1, 0.05, 0.08), "head": true},
			{"size": Vector3(0.5, 0.3, 0.2), "pos": Vector3(0, 3.0, -0.7), "color": gum2, "head": true},     # snout
		],
	}

	# Scarecrow King: a giant scarecrow with a glowing pumpkin head and a crown,
	# who throws burning pumpkins and calls crows.
	var sk: Dictionary = MOBS["scarecrow"].duplicate(true)
	sk.merge({"name": "Scarecrow King", "kind": "hostile", "boss": true, "hp": 620.0, "damage": 14.0, "speed": 3.4,
			"sight": 28.0, "size": Vector2(2.0, 4.2), "spawn": "boss", "biome": "fall", "weight": 0, "loot": [],
			"ranged": {"range": 24.0, "every": 2.2, "speed": 15.0, "chase": true, "shots": [["fireball", 7.0, "fire"]]},
			"summon": {"type": "crow", "every": 14.0, "count": 3, "max": 6},
			"treasure": [["harvest_scythe", 1, 1], ["pumpkin", 4, 6], ["hay_bale", 4, 6], ["candy_corn", 6, 10], ["gold_ingot", 2, 3], ["silver_ingot", 2, 3]],
			"signature": "harvest_scythe"}, true)
	sk["parts"] = _scaled(sk["parts"], 2.1, Color(0.0, 0.0, 0.0), 0.0)
	for p in sk["parts"]:
		if p.get("head", false) and (p["color"] as Color).r > 0.95:
			p["glow"] = true   # the carved face glows
	sk["parts"].append_array(_crown_at(_head_top(sk["parts"]), 0.8))
	MOBS["scarecrow_king"] = sk

	# Lantern Witch: a tall green-glowing witch carrying a ghost lantern.
	# She throws ghostly wisps and calls ghosts.
	var lw: Dictionary = MOBS["witch"].duplicate(true)
	lw.merge({"name": "Lantern Witch", "kind": "hostile", "boss": true, "hp": 900.0, "damage": 15.0, "speed": 4.0,
			"sight": 30.0, "size": Vector2(1.4, 3.8), "spawn": "boss", "biome": "spooky", "weight": 0, "loot": [],
			"ranged": {"range": 26.0, "every": 1.8, "speed": 18.0, "chase": true, "shots": [["wisp", 8.0, ""], ["wisp", 8.0, ""], ["iceball", 6.0, "ice"]]},
			"summon": {"type": "ghost", "every": 16.0, "count": 2, "max": 4},
			"treasure": [["ghostlight_pickaxe", 1, 1], ["ectoplasm", 4, 6], ["titanium_ingot", 2, 4], ["gold_ingot", 2, 3], ["witch_hat", 1, 1]],
			"signature": "ghostlight_pickaxe"}, true)
	lw["parts"] = _scaled(lw["parts"], 1.9, Color(0.2, 0.45, 0.3), 0.35)
	lw["parts"].append({"size": Vector3(0.36, 0.5, 0.36), "pos": Vector3(-0.8, 1.6, -0.3), "color": Color(0.55, 1.0, 0.65), "glow": true})   # the lantern
	lw["parts"].append({"size": Vector3(0.06, 0.4, 0.06), "pos": Vector3(-0.8, 2.05, -0.3), "color": Color(0.2, 0.2, 0.22)})
	MOBS["lantern_witch"] = lw

	# --- The chessboard kingdom (mid-game) -------------------------------------------
	# By day: little white and black pawns hop about (harmless). At night the
	# playing-card soldiers march: hearts with spears, spades throwing cards.
	for white in [true, false]:
		MOBS["white_pawn" if white else "black_pawn"] = {
			"name": "White Pawn" if white else "Black Pawn", "kind": "passive", "hp": 10.0, "speed": 2.6, "size": Vector2(0.6, 1.25),
			"spawn": "animal", "biome": "chess", "weight": 3,
			"loot": [["white_marble" if white else "black_onyx", 1, 2]],
			"parts": _pawn_parts(white)}
	MOBS["heart_soldier"] = {
		"name": "Heart Soldier", "kind": "hostile", "hp": 24.0, "speed": 3.6, "damage": 5.0, "size": Vector2(0.75, 2.15),
		"spawn": "night", "biome": "chess", "weight": 4, "sight": 20.0,
		"loot": [["playing_card", 1, 2], ["paper", 0, 1], ["iron_ore", 0, 1]],
		"parts": _card_parts("heart", true)}
	MOBS["spade_soldier"] = {
		"name": "Spade Soldier", "kind": "hostile", "hp": 20.0, "speed": 3.4, "damage": 3.5, "size": Vector2(0.75, 2.15),
		"spawn": "night", "biome": "chess", "weight": 3, "sight": 22.0,
		"ranged": {"range": 16.0, "every": 2.3, "damage": 4.0, "speed": 20.0, "shot": "card"},
		"loot": [["playing_card", 1, 3], ["paper", 0, 1], ["ancient_coin", 0, 1]],
		"parts": _card_parts("spade", false)}
	# The royal guard the King calls (they don't mind the sun).
	var guard: Dictionary = MOBS["heart_soldier"].duplicate(true)
	guard.merge({"name": "Royal Card Guard", "spawn": "summon", "weight": 0, "loot": [["playing_card", 0, 1]]}, true)
	MOBS["card_guard"] = guard

	# The King & Queen: always a pair, either both white or both black. The
	# King is big, slow and hits hard, and calls his card guards; the Queen is
	# quick and throws royal bolts. Beat both for the treasure (each color
	# drops its own legendary sword). See mobs.gd for how the pair works.
	for white in [true, false]:
		var col := "white" if white else "black"
		var treasure := [["white_throne_blade" if white else "black_throne_blade", 1, 1],
				["white_marble" if white else "black_onyx", 8, 12], ["checker_tile", 4, 6], ["titanium_ingot", 2, 4], ["gold_ingot", 2, 3]]
		var pair_name := "%s King & Queen" % col.capitalize()
		MOBS[col + "_king"] = {
			"name": "%s King" % col.capitalize(), "pair_name": pair_name, "pair": col + "_queen",
			"kind": "hostile", "boss": true, "hp": 760.0, "damage": 15.0, "speed": 2.7, "sight": 28.0,
			"size": Vector2(2.0, 4.6), "spawn": "boss", "biome": "chess", "weight": 0, "loot": [],
			"summon": {"type": "card_guard", "every": 15.0, "count": 2, "max": 4},
			"treasure": treasure, "signature": treasure[0][0],
			"parts": _scaled(_royal_parts(white, false), 2.0, Color.BLACK, 0.0)}
		MOBS[col + "_queen"] = {
			"name": "%s Queen" % col.capitalize(), "pair_name": pair_name, "pair": col + "_king",
			"kind": "hostile", "boss": true, "hp": 540.0, "damage": 11.0, "speed": 4.8, "sight": 30.0,
			"size": Vector2(1.6, 4.2), "spawn": "boss", "biome": "chess", "weight": 0, "loot": [],
			"ranged": {"range": 24.0, "every": 1.7, "speed": 19.0, "chase": true,
					"shots": [["royal_bolt" if white else "shadow_bolt", 7.0, ""], ["royal_bolt" if white else "shadow_bolt", 7.0, ""], ["card", 5.0, ""]]},
			"treasure": treasure, "signature": treasure[0][0],
			"parts": _scaled(_royal_parts(white, true), 1.85, Color.BLACK, 0.0)}

	# --- Fast Food Land (mid-game) ---------------------------------------------------------
	# By day: little nugget buddies and happy meal boxes wander about. At night
	# the food gets grumpy: angry fries, spicy nuggets (they throw hot sauce)
	# and chomping meal boxes.
	MOBS["nugget_buddy"] = {
		"name": "Nugget Buddy", "kind": "passive", "hp": 8.0, "speed": 3.0, "size": Vector2(0.55, 0.65),
		"spawn": "animal", "biome": "fastfood", "weight": 3, "loot": [["chicken_nugget", 1, 2]],
		"parts": _nugget_parts(false)}
	MOBS["happy_box"] = {
		"name": "Happy Meal Box", "kind": "passive", "hp": 10.0, "speed": 2.6, "size": Vector2(0.65, 0.95),
		"spawn": "animal", "biome": "fastfood", "weight": 3, "loot": [["french_fries", 1, 2], ["toy_prize", 0, 1, 0.25]],
		"parts": _box_parts(false)}
	MOBS["angry_fries"] = {
		"name": "Angry Fries", "kind": "hostile", "hp": 22.0, "speed": 4.2, "damage": 4.5, "size": Vector2(0.6, 1.5),
		"spawn": "night", "biome": "fastfood", "weight": 4, "sight": 20.0,
		"loot": [["french_fries", 1, 3], ["paper", 0, 1], ["iron_ore", 0, 1]],
		"parts": _fries_parts()}
	MOBS["spicy_nugget"] = {
		"name": "Spicy Nugget", "kind": "hostile", "hp": 18.0, "speed": 3.6, "damage": 3.5, "size": Vector2(0.75, 0.95),
		"spawn": "night", "biome": "fastfood", "weight": 3, "sight": 22.0,
		"ranged": {"range": 15.0, "every": 2.6, "damage": 3.5, "speed": 17.0, "shot": "hot_sauce", "effect": "fire"},
		"loot": [["chicken_nugget", 1, 3], ["ancient_coin", 0, 1]],
		"parts": _nugget_parts(true)}
	MOBS["chomp_box"] = {
		"name": "Chomp Box", "kind": "hostile", "hp": 34.0, "speed": 3.0, "damage": 6.0, "size": Vector2(0.8, 1.15),
		"spawn": "night", "biome": "fastfood", "weight": 2, "sight": 18.0,
		"loot": [["french_fries", 1, 2], ["toy_prize", 0, 1, 0.4], ["chicken_nugget", 0, 2]],
		"parts": _box_parts(true)}
	var minion: Dictionary = MOBS["angry_fries"].duplicate(true)
	minion.merge({"name": "Fry Minion", "spawn": "summon", "weight": 0, "loot": [["french_fries", 0, 1]]}, true)
	MOBS["fry_minion"] = minion

	# Chuckles the Clown: a giant clown in the circus tent. He swings a huge
	# hammer (it hits everyone close to him) and throws little toys.
	MOBS["clown"] = {
		"name": "Chuckles the Clown", "kind": "hostile", "boss": true, "hp": 1100.0, "damage": 17.0, "speed": 3.6, "sight": 30.0,
		"size": Vector2(2.2, 5.2), "spawn": "boss", "biome": "fastfood", "weight": 0, "loot": [], "slam": 4.5,
		"ranged": {"range": 22.0, "every": 1.6, "speed": 17.0, "chase": true,
				"shots": [["toy_ball", 5.0, ""], ["toy_duck", 5.0, ""], ["toy_block", 6.0, ""]]},
		"summon": {"type": "fry_minion", "every": 16.0, "count": 2, "max": 4},
		"treasure": [["circus_hammer", 1, 1], ["toy_prize", 3, 5], ["french_fries", 6, 10], ["titanium_ingot", 3, 5], ["gold_ingot", 2, 4]],
		"signature": "circus_hammer",
		"parts": _scaled(_clown_parts(), 2.2, Color.BLACK, 0.0)}

	# Fairies: tiny and glowing. The look is made in build_fairy (color varies).
	# Villagers: one kind for every biome (see villager_data.gd).
	for vb in VillagerData.TRIBES:
		var vt: Dictionary = VillagerData.TRIBES[vb]
		var tall := 1.55 if vt["look"] == "dwarf" else (2.05 if vt["look"] == "elf" else 1.9)
		MOBS[VillagerData.mob_type(vb)] = {"name": vt["one"], "kind": "villager", "tribe": vb, "hp": 20.0, "speed": 1.8,
				"size": Vector2(0.6, tall), "spawn": "unique", "biome": vb, "weight": 0, "loot": [], "parts": VillagerData.parts(vb)}
	MOBS["fairy"] = {"name": "Fairy", "kind": "fairy", "hp": 1.0, "speed": 6.0, "size": Vector2(0.4, 0.5),
			"spawn": "unique", "biome": "forest", "weight": 0, "loot": [], "parts": []}


## Each fairy color gives a different helpful power: [name, color, buff].
## How strong it is depends on how brightly the fairy glows (see buff_power).
const FAIRY_COLORS := [
	["Red", Color(1.0, 0.35, 0.35), "haste"],
	["Orange", Color(1.0, 0.62, 0.25), "warmth"],
	["Yellow", Color(1.0, 0.95, 0.4), "speed"],
	["Green", Color(0.45, 1.0, 0.5), "regen"],
	["Blue", Color(0.45, 0.75, 1.0), "fireproof"],
	["Purple", Color(0.75, 0.5, 1.0), "fortune"],
	["Pink", Color(1.0, 0.6, 0.85), "toughness"],
	["White", Color(0.95, 0.97, 1.0), "jump"],
]
## The powers (buffs) fairies, capes, rings and amulets give, at full strength
## (a radiant fairy). Dimmer fairies and capes give a share of it.
##   haste     - swing and mine faster        warmth    - never feel the cold
##   speed     - run faster                   regen     - heal faster
##   fireproof - fire can't burn you          fortune   - chance of double ore
##   toughness - take less damage             jump      - jump higher
##   leech     - heal from the damage you deal (rings and cute weapons only)
const BUFF_MAX := {"haste": 0.35, "warmth": 1.0, "speed": 0.35, "regen": 2.0, "fireproof": 1.0,
		"fortune": 0.5, "toughness": 0.3, "jump": 0.3, "leech": 0.25}
## On/off powers: any fairy or cape with one gives all of it (half-warm is silly).
const BINARY_BUFFS := ["warmth", "fireproof"]
## Everything you have together never adds up past this.
const BUFF_CAP := {"haste": 0.6, "speed": 0.6, "toughness": 0.6, "leech": 0.3, "fortune": 0.75, "jump": 0.6}
const BRIGHTNESS_NAMES := [[0.5, "Faint"], [0.7, "Glowing"], [0.88, "Bright"], [2.0, "Radiant"]]


static func buff_power(color_index: int, brightness: float) -> float:
	var type: String = FAIRY_COLORS[color_index][2]
	if type in BINARY_BUFFS:
		return 1.0
	return BUFF_MAX[type] * clampf(brightness, 0.0, 1.0)


## A power in words, for tooltips and the fairy message.
static func buff_text(type: String, power: float) -> String:
	var pct := roundi(power * 100.0)
	match type:
		"haste":
			return "Swings and mines faster: +%d%%" % pct
		"warmth":
			return "Warm: never feels the cold"
		"speed":
			return "Faster feet: +%d%% speed" % pct
		"regen":
			return "Heals faster: +%d%% healing" % pct
		"fireproof":
			return "Fireproof: fire can't burn you"
		"fortune":
			return "Lucky miner: %d%% chance of double ore" % pct
		"toughness":
			return "Tougher: %d%% less damage" % pct
		"jump":
			return "Jumps higher: +%d%%" % pct
		"leech":
			return "Life leech: heals %d%% of the damage dealt" % pct
		"strength":
			return "Hits harder: +%d%%" % pct
	return "%s: +%d%%" % [type.capitalize(), pct]


## Short name of a power, for the character screen.
static func buff_name(type: String) -> String:
	return {"haste": "Haste", "warmth": "Warmth", "speed": "Speed", "regen": "Healing", "fireproof": "Fireproof",
			"fortune": "Fortune", "toughness": "Toughness", "jump": "Jump", "leech": "Life Leech", "strength": "Strength"}.get(type, type.capitalize())


static func brightness_name(b: float) -> String:
	for entry in BRIGHTNESS_NAMES:
		if b < entry[0]:
			return entry[1]
	return "Radiant"


static func fairy_text(color_index: int, brightness: float) -> String:
	return buff_text(FAIRY_COLORS[color_index][2], buff_power(color_index, brightness))


## A fairy's model: a glowing body with see-through wings and a soft light.
static func build_fairy(color_index: int, brightness: float) -> Dictionary:
	var root := Node3D.new()
	var c: Color = FAIRY_COLORS[color_index][1]
	var glow := StandardMaterial3D.new()
	glow.albedo_color = c
	glow.emission_enabled = true
	glow.emission = c
	glow.emission_energy_multiplier = 0.6 + brightness * 2.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var wing := StandardMaterial3D.new()
	wing.albedo_color = Color(1, 1, 1, 0.45)
	wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.18, 0.12)
	bm.material = glow
	body.mesh = bm
	body.position.y = 0.25
	root.add_child(body)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.11, 0.11, 0.11)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(1.0, 0.92, 0.85)
	skin.emission_enabled = true
	skin.emission = c.lerp(Color.WHITE, 0.6)
	skin.emission_energy_multiplier = 0.4 + brightness
	hm.material = skin
	head.mesh = hm
	head.position.y = 0.39
	root.add_child(head)
	var legs: Array[Node3D] = []
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.04 * side, 0.3, 0.05)
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.22, 0.2, 0.01)
		wm.material = wing
		w.mesh = wm
		w.position = Vector3(0.11 * side, 0.02, 0)
		pivot.add_child(w)
		root.add_child(pivot)
		legs.append(pivot)  # "legs" flap: the walk animation becomes wing beats
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.4 + brightness * 1.4
	light.omni_range = 2.5 + brightness * 3.0
	light.position.y = 0.3
	root.add_child(light)
	return {"root": root, "head": Node3D.new(), "legs": legs}


static func _tint(parts: Array, color: Color, amount: float) -> Array:
	var out := []
	for part in parts:
		var p: Dictionary = part.duplicate()
		var c: Color = p["color"]
		if c.v > 0.15 and c.s < 0.8:  # keep eyes and noses dark
			p["color"] = c.lerp(color, amount)
		out.append(p)
	return out


## Pale skin (or fur) and pink eyes, for the Deep's albino creatures.
static func _albino(parts: Array) -> Array:
	var out := []
	for part in parts:
		var p: Dictionary = part.duplicate()
		var c: Color = p["color"]
		var eye: bool = p.get("head", false) and (p["size"] as Vector3).z <= 0.03 and (c.v > 0.75 or c.v < 0.15)
		if eye:
			p["color"] = Color(1.0, 0.35, 0.5)
			p["glow"] = true
		else:
			p["color"] = c.lerp(Color(0.95, 0.93, 0.96), 0.82)
		out.append(p)
	return out


## Does this mob live in this biome?
static func lives_in(type: String, biome: String) -> bool:
	var b = get_def(type).get("biome", "plains")
	return b == biome if b is String else biome in b


## A mob's parts made k times bigger (and tinted toward a color by `mix`).
static func _scaled(parts: Array, k: float, tint: Color, mix: float) -> Array:
	var out := []
	for part in parts:
		var p: Dictionary = part.duplicate()
		p["size"] = p["size"] * k
		p["pos"] = p["pos"] * k
		if mix > 0.0:
			p["color"] = (p["color"] as Color).lerp(tint, mix)
		out.append(p)
	return out


## The top middle of a model's head (for putting a crown on it).
static func _head_top(parts: Array) -> Vector3:
	var top := Vector3(0, -99, 0)
	var sum := Vector3.ZERO
	var n := 0
	for p in parts:
		if p.get("head", false):
			sum += p["pos"]
			n += 1
			top.y = maxf(top.y, p["pos"].y + p["size"].y * 0.5)
	var mid := sum / maxf(1.0, n)
	return Vector3(mid.x, top.y, mid.z)


## A chicken nugget with little legs (spicy ones are redder, with sauce drips and cross eyebrows).
static func _nugget_parts(spicy: bool) -> Array:
	var c := Color(0.88, 0.58, 0.24) if not spicy else Color(0.86, 0.38, 0.16)
	var k := 1.0 if not spicy else 1.3
	var out := [
		{"size": Vector3(0.08, 0.16, 0.08), "pos": Vector3(-0.1, 0.08, 0) * k, "color": Color(0.95, 0.75, 0.3), "leg": true},
		{"size": Vector3(0.08, 0.16, 0.08), "pos": Vector3(0.1, 0.08, 0) * k, "color": Color(0.95, 0.75, 0.3), "leg": true},
		{"size": Vector3(0.5, 0.36, 0.38) * k, "pos": Vector3(0, 0.34, 0) * k, "color": c, "head": true},
		{"size": Vector3(0.3, 0.12, 0.3) * k, "pos": Vector3(0.06, 0.55, 0.02) * k, "color": c.lightened(0.12), "head": true},   # a bumpy top
		{"size": Vector3(0.18, 0.14, 0.2) * k, "pos": Vector3(-0.24, 0.3, 0.04) * k, "color": c.darkened(0.08), "head": true},
		{"size": Vector3(0.07, 0.08, 0.02), "pos": Vector3(-0.09, 0.4, -0.195) * k, "color": Color(0.1, 0.08, 0.06), "head": true},
		{"size": Vector3(0.07, 0.08, 0.02), "pos": Vector3(0.09, 0.4, -0.195) * k, "color": Color(0.1, 0.08, 0.06), "head": true},
		{"size": Vector3(0.12, 0.03, 0.02), "pos": Vector3(0, 0.3, -0.195) * k, "color": Color(0.55, 0.2, 0.15), "head": true},
	]
	if spicy:
		out.append({"size": Vector3(0.1, 0.03, 0.02), "pos": Vector3(-0.1, 0.48, -0.25) * k, "color": Color(0.2, 0.05, 0.05), "head": true})   # angry brows
		out.append({"size": Vector3(0.1, 0.03, 0.02), "pos": Vector3(0.1, 0.48, -0.25) * k, "color": Color(0.2, 0.05, 0.05), "head": true})
		for sx in [-0.16, 0.0, 0.14]:
			out.append({"size": Vector3(0.06, 0.14, 0.04), "pos": Vector3(sx, 0.62, -0.1) * k, "color": Color(0.95, 0.15, 0.08), "head": true, "glow": true})   # hot sauce
	else:
		out.append({"size": Vector3(0.06, 0.04, 0.02), "pos": Vector3(-0.16, 0.33, -0.195), "color": Color(1.0, 0.6, 0.6), "head": true})   # rosy cheeks
		out.append({"size": Vector3(0.06, 0.04, 0.02), "pos": Vector3(0.16, 0.33, -0.195), "color": Color(1.0, 0.6, 0.6), "head": true})
	return out


## A meal box with a handle on top. Happy ones smile; chomp boxes have a big toothy jaw.
static func _box_parts(chomp: bool) -> Array:
	var red := Color(0.88, 0.14, 0.16) if not chomp else Color(0.62, 0.1, 0.12)
	var yellow := Color(0.98, 0.8, 0.22)
	var k := 1.0 if not chomp else 1.22
	var out := [
		{"size": Vector3(0.12, 0.2, 0.12), "pos": Vector3(-0.15, 0.1, 0) * k, "color": yellow, "leg": true},
		{"size": Vector3(0.12, 0.2, 0.12), "pos": Vector3(0.15, 0.1, 0) * k, "color": yellow, "leg": true},
		{"size": Vector3(0.62, 0.5, 0.46) * k, "pos": Vector3(0, 0.45, 0) * k, "color": red, "head": true},
		{"size": Vector3(0.62, 0.06, 0.46) * k, "pos": Vector3(0, 0.71, 0) * k, "color": yellow, "head": true},   # the lid
		{"size": Vector3(0.06, 0.18, 0.06), "pos": Vector3(-0.17, 0.84, 0) * k, "color": yellow, "head": true},   # handle
		{"size": Vector3(0.06, 0.18, 0.06), "pos": Vector3(0.17, 0.84, 0) * k, "color": yellow, "head": true},
		{"size": Vector3(0.4, 0.06, 0.06), "pos": Vector3(0, 0.93, 0) * k, "color": yellow, "head": true},
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(-0.13, 0.55, -0.235) * k, "color": Color(0.1, 0.08, 0.06), "head": true},
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(0.13, 0.55, -0.235) * k, "color": Color(0.1, 0.08, 0.06), "head": true},
	]
	if chomp:
		out.append({"size": Vector3(0.5, 0.12, 0.02) * k, "pos": Vector3(0, 0.36, -0.24) * k, "color": Color(0.15, 0.03, 0.03), "head": true})   # a wide mouth
		for i in 5:
			out.append({"size": Vector3(0.06, 0.07, 0.03) * k, "pos": Vector3(-0.2 + i * 0.1, 0.4, -0.25) * k, "color": Color(0.98, 0.97, 0.92), "head": true})   # teeth
		out.append({"size": Vector3(0.12, 0.03, 0.02), "pos": Vector3(-0.13, 0.63, -0.24) * k, "color": Color(0.1, 0.05, 0.05), "head": true})   # cross brows
		out.append({"size": Vector3(0.12, 0.03, 0.02), "pos": Vector3(0.13, 0.63, -0.24) * k, "color": Color(0.1, 0.05, 0.05), "head": true})
	else:
		out.append({"size": Vector3(0.2, 0.04, 0.02), "pos": Vector3(0, 0.38, -0.235), "color": yellow, "head": true})   # a big smile
		out.append({"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(-0.12, 0.41, -0.235), "color": yellow, "head": true})
		out.append({"size": Vector3(0.05, 0.05, 0.02), "pos": Vector3(0.12, 0.41, -0.235), "color": yellow, "head": true})
	return out


## Angry fries: a red carton with fries sticking out the top and cross eyes.
static func _fries_parts() -> Array:
	var red := Color(0.86, 0.13, 0.15)
	var fry := Color(1.0, 0.82, 0.32)
	var out := [
		{"size": Vector3(0.14, 0.42, 0.14), "pos": Vector3(-0.12, 0.21, 0), "color": fry, "leg": true},
		{"size": Vector3(0.14, 0.42, 0.14), "pos": Vector3(0.12, 0.21, 0), "color": fry, "leg": true},
		{"size": Vector3(0.52, 0.6, 0.36), "pos": Vector3(0, 0.72, 0), "color": red},
		{"size": Vector3(0.1, 0.4, 0.1), "pos": Vector3(-0.34, 0.75, 0), "color": fry},   # fry arms
		{"size": Vector3(0.1, 0.4, 0.1), "pos": Vector3(0.34, 0.75, 0), "color": fry},
		{"size": Vector3(0.09, 0.11, 0.02), "pos": Vector3(-0.11, 0.8, -0.19), "color": Color.WHITE},
		{"size": Vector3(0.09, 0.11, 0.02), "pos": Vector3(0.11, 0.8, -0.19), "color": Color.WHITE},
		{"size": Vector3(0.05, 0.06, 0.02), "pos": Vector3(-0.1, 0.78, -0.2), "color": Color(0.1, 0.05, 0.05)},
		{"size": Vector3(0.05, 0.06, 0.02), "pos": Vector3(0.1, 0.78, -0.2), "color": Color(0.1, 0.05, 0.05)},
		{"size": Vector3(0.13, 0.03, 0.02), "pos": Vector3(-0.11, 0.9, -0.2), "color": Color(0.15, 0.05, 0.05)},   # angry brows
		{"size": Vector3(0.13, 0.03, 0.02), "pos": Vector3(0.11, 0.9, -0.2), "color": Color(0.15, 0.05, 0.05)},
		{"size": Vector3(0.18, 0.05, 0.02), "pos": Vector3(0, 0.6, -0.19), "color": Color(0.2, 0.05, 0.05)},
	]
	for i in 7:
		var x := -0.2 + i * 0.066
		var h := 0.35 + float((i * 5) % 3) * 0.12
		out.append({"size": Vector3(0.07, h, 0.07), "pos": Vector3(x, 1.02 + h * 0.5, -0.05 + (i % 2) * 0.1), "color": fry if i % 3 else fry.darkened(0.1), "head": true})
	return out


## Chuckles the Clown (before scaling up): big shoes, a polka-dot suit, a ruff,
## a white face with a red nose, rainbow hair, a tiny hat and a huge hammer.
static func _clown_parts() -> Array:
	var suit := Color(0.98, 0.82, 0.2)
	var face := Color(0.98, 0.97, 0.95)
	var out := [
		{"size": Vector3(0.3, 0.14, 0.56), "pos": Vector3(-0.17, 0.07, -0.1), "color": Color(0.9, 0.15, 0.15), "leg": true},   # big shoes
		{"size": Vector3(0.3, 0.14, 0.56), "pos": Vector3(0.17, 0.07, -0.1), "color": Color(0.9, 0.15, 0.15), "leg": true},
		{"size": Vector3(0.26, 0.66, 0.28), "pos": Vector3(-0.15, 0.47, 0), "color": Color(0.3, 0.5, 0.95), "leg": true},
		{"size": Vector3(0.26, 0.66, 0.28), "pos": Vector3(0.15, 0.47, 0), "color": Color(0.3, 0.5, 0.95), "leg": true},
		{"size": Vector3(0.72, 0.72, 0.52), "pos": Vector3(0, 1.16, 0), "color": suit},
		{"size": Vector3(0.88, 0.12, 0.68), "pos": Vector3(0, 1.56, 0), "color": Color.WHITE},   # the ruff
		{"size": Vector3(0.78, 0.07, 0.6), "pos": Vector3(0, 1.64, 0), "color": Color(0.9, 0.2, 0.4)},
		{"size": Vector3(0.18, 0.62, 0.2), "pos": Vector3(-0.46, 1.22, 0), "color": suit},
		{"size": Vector3(0.18, 0.62, 0.2), "pos": Vector3(0.46, 1.22, 0), "color": suit},
		{"size": Vector3(0.22, 0.2, 0.24), "pos": Vector3(-0.46, 0.84, 0), "color": Color.WHITE},   # gloves
		{"size": Vector3(0.22, 0.2, 0.24), "pos": Vector3(0.46, 0.84, 0), "color": Color.WHITE},
		{"size": Vector3(0.5, 0.5, 0.48), "pos": Vector3(0, 1.94, 0), "color": face, "head": true},
		{"size": Vector3(0.15, 0.15, 0.1), "pos": Vector3(0, 1.92, -0.28), "color": Color(0.95, 0.1, 0.12), "head": true},   # red nose
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(-0.12, 2.02, -0.245), "color": Color(0.1, 0.1, 0.15), "head": true},
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(0.12, 2.02, -0.245), "color": Color(0.1, 0.1, 0.15), "head": true},
		{"size": Vector3(0.04, 0.12, 0.02), "pos": Vector3(-0.12, 2.02, -0.246), "color": Color(0.3, 0.5, 0.95), "head": true},   # star paint
		{"size": Vector3(0.04, 0.12, 0.02), "pos": Vector3(0.12, 2.02, -0.246), "color": Color(0.3, 0.5, 0.95), "head": true},
		{"size": Vector3(0.3, 0.05, 0.02), "pos": Vector3(0, 1.79, -0.245), "color": Color(0.9, 0.1, 0.15), "head": true},   # a big grin
		{"size": Vector3(0.05, 0.06, 0.02), "pos": Vector3(-0.16, 1.83, -0.245), "color": Color(0.9, 0.1, 0.15), "head": true},
		{"size": Vector3(0.05, 0.06, 0.02), "pos": Vector3(0.16, 1.83, -0.245), "color": Color(0.9, 0.1, 0.15), "head": true},
		{"size": Vector3(0.18, 0.24, 0.34), "pos": Vector3(-0.32, 2.02, 0.04), "color": Color(1.0, 0.5, 0.15), "head": true},   # rainbow hair
		{"size": Vector3(0.18, 0.24, 0.34), "pos": Vector3(0.32, 2.02, 0.04), "color": Color(0.35, 0.85, 0.35), "head": true},
		{"size": Vector3(0.34, 0.03, 0.34), "pos": Vector3(0, 2.2, 0), "color": Color(0.45, 0.25, 0.7), "head": true},   # tiny hat
		{"size": Vector3(0.22, 0.16, 0.22), "pos": Vector3(0, 2.29, 0), "color": Color(0.45, 0.25, 0.7), "head": true},
		{"size": Vector3(0.08, 0.08, 0.08), "pos": Vector3(0, 2.41, 0), "color": Color(1.0, 0.85, 0.2), "head": true, "glow": true},
		{"size": Vector3(0.08, 1.4, 0.08), "pos": Vector3(0.62, 1.3, -0.26), "color": Color(0.62, 0.42, 0.22)},   # the hammer
		{"size": Vector3(0.56, 0.34, 0.34), "pos": Vector3(0.62, 2.04, -0.26), "color": Color(0.9, 0.15, 0.18)},
		{"size": Vector3(0.1, 0.36, 0.36), "pos": Vector3(0.44, 2.04, -0.26), "color": Color.WHITE},
		{"size": Vector3(0.1, 0.36, 0.36), "pos": Vector3(0.8, 2.04, -0.26), "color": Color.WHITE},
	]
	var dots := [Color(0.9, 0.2, 0.3), Color(0.3, 0.6, 1.0), Color(0.35, 0.85, 0.4), Color(0.8, 0.4, 0.95)]
	for i in 7:
		var dp := Vector3(-0.24 + (i % 4) * 0.16, 0.95 + (i / 4) * 0.3 + (i % 2) * 0.08, -0.27)
		out.append({"size": Vector3(0.1, 0.1, 0.02), "pos": dp, "color": dots[i % 4]})   # polka dots
	return out


## A little living chess pawn: a round base it waddles on, a round head, big eyes.
static func _pawn_parts(white: bool) -> Array:
	var c := Color(0.94, 0.93, 0.9) if white else Color(0.14, 0.13, 0.17)
	var trim := c.darkened(0.12) if white else c.lightened(0.15)
	var eye := Color(0.12, 0.12, 0.16) if white else Color(0.55, 0.85, 1.0)
	return [
		{"size": Vector3(0.3, 0.16, 0.6), "pos": Vector3(-0.15, 0.08, 0), "color": c, "leg": true},
		{"size": Vector3(0.3, 0.16, 0.6), "pos": Vector3(0.15, 0.08, 0), "color": c, "leg": true},
		{"size": Vector3(0.62, 0.12, 0.62), "pos": Vector3(0, 0.22, 0), "color": trim},
		{"size": Vector3(0.4, 0.4, 0.4), "pos": Vector3(0, 0.48, 0), "color": c},
		{"size": Vector3(0.52, 0.08, 0.52), "pos": Vector3(0, 0.71, 0), "color": trim},
		{"size": Vector3(0.44, 0.42, 0.44), "pos": Vector3(0, 0.96, 0), "color": c, "head": true},
		{"size": Vector3(0.14, 0.08, 0.14), "pos": Vector3(0, 1.21, 0), "color": trim, "head": true},
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(-0.1, 1.0, -0.225), "color": eye, "head": true, "glow": not white},
		{"size": Vector3(0.08, 0.1, 0.02), "pos": Vector3(0.1, 1.0, -0.225), "color": eye, "head": true, "glow": not white},
		{"size": Vector3(0.07, 0.04, 0.02), "pos": Vector3(-0.16, 0.91, -0.225), "color": Color(1.0, 0.6, 0.7), "head": true},
		{"size": Vector3(0.07, 0.04, 0.02), "pos": Vector3(0.16, 0.91, -0.225), "color": Color(1.0, 0.6, 0.7), "head": true},
	]


## A playing-card soldier: a big card for a body, with arms, legs and a head.
static func _card_parts(suit: String, spear: bool) -> Array:
	var ink := Color(0.85, 0.12, 0.2) if suit == "heart" else Color(0.1, 0.1, 0.13)
	var paper := Color(0.97, 0.96, 0.92)
	var skin := Color(0.96, 0.82, 0.7)
	var f := -0.05   # just in front of the card
	var out := [
		{"size": Vector3(0.18, 0.75, 0.2), "pos": Vector3(-0.13, 0.375, 0), "color": ink, "leg": true},
		{"size": Vector3(0.18, 0.75, 0.2), "pos": Vector3(0.13, 0.375, 0), "color": ink, "leg": true},
		{"size": Vector3(0.74, 0.98, 0.07), "pos": Vector3(0, 1.22, 0), "color": paper},
		{"size": Vector3(0.7, 0.94, 0.02), "pos": Vector3(0, 1.22, 0.045), "color": ink.lerp(paper, 0.15)},   # the card's back
		{"size": Vector3(0.12, 0.52, 0.12), "pos": Vector3(-0.44, 1.32, 0), "color": ink},
		{"size": Vector3(0.12, 0.52, 0.12), "pos": Vector3(0.44, 1.32, 0), "color": ink},
		{"size": Vector3(0.36, 0.36, 0.36), "pos": Vector3(0, 1.9, 0), "color": skin, "head": true},
		{"size": Vector3(0.07, 0.07, 0.02), "pos": Vector3(-0.08, 1.93, -0.185), "color": Color(0.1, 0.1, 0.12), "head": true},
		{"size": Vector3(0.07, 0.07, 0.02), "pos": Vector3(0.08, 1.93, -0.185), "color": Color(0.1, 0.1, 0.12), "head": true},
		{"size": Vector3(0.14, 0.03, 0.02), "pos": Vector3(0, 1.82, -0.185), "color": Color(0.55, 0.25, 0.25), "head": true},   # a frown
		{"size": Vector3(0.4, 0.1, 0.4), "pos": Vector3(0, 2.12, 0), "color": ink, "head": true},   # a little cap
		{"size": Vector3(0.06, 0.06, 0.02), "pos": Vector3(-0.27, 1.6, f), "color": ink},   # corner pips
		{"size": Vector3(0.06, 0.06, 0.02), "pos": Vector3(0.27, 0.84, f), "color": ink},
	]
	if suit == "heart":
		for b in [[Vector2(-0.07, 1.27), Vector2(0.13, 0.12)], [Vector2(0.07, 1.27), Vector2(0.13, 0.12)],
				[Vector2(0, 1.18), Vector2(0.2, 0.1)], [Vector2(0, 1.1), Vector2(0.1, 0.07)]]:
			out.append({"size": Vector3(b[1].x, b[1].y, 0.02), "pos": Vector3(b[0].x, b[0].y, f), "color": ink})
	else:
		for b in [[Vector2(0, 1.34), Vector2(0.08, 0.07)], [Vector2(0, 1.27), Vector2(0.18, 0.08)],
				[Vector2(-0.07, 1.19), Vector2(0.13, 0.1)], [Vector2(0.07, 1.19), Vector2(0.13, 0.1)], [Vector2(0, 1.09), Vector2(0.05, 0.12)]]:
			out.append({"size": Vector3(b[1].x, b[1].y, 0.02), "pos": Vector3(b[0].x, b[0].y, f), "color": ink})
	if spear:
		out.append({"size": Vector3(0.05, 1.7, 0.05), "pos": Vector3(0.52, 1.15, -0.16), "color": Color(0.5, 0.36, 0.22)})
		out.append({"size": Vector3(0.12, 0.22, 0.04), "pos": Vector3(0.52, 2.08, -0.16), "color": Color(0.85, 0.86, 0.9)})
	return out


## The King or Queen (before scaling up): a living chess piece in a robe, with
## glowing eyes and a crown. White ones are marble and gold; black ones are
## onyx and silver with violet gems.
static func _royal_parts(white: bool, queen: bool) -> Array:
	var c := Color(0.94, 0.93, 0.89) if white else Color(0.13, 0.12, 0.16)
	var trim := Color(1.0, 0.8, 0.3) if white else Color(0.75, 0.76, 0.82)
	var gem := Color(0.45, 0.8, 1.0) if white else Color(0.8, 0.35, 1.0)
	var eye := Color(0.5, 0.85, 1.0) if white else Color(1.0, 0.35, 0.45)
	var w := 0.86 if queen else 1.0
	var out := [
		{"size": Vector3(0.3 * w, 0.4, 0.52 * w), "pos": Vector3(-0.17 * w, 0.2, 0), "color": c, "leg": true},
		{"size": Vector3(0.3 * w, 0.4, 0.52 * w), "pos": Vector3(0.17 * w, 0.2, 0), "color": c, "leg": true},
		{"size": Vector3(1.0 * w, 0.18, 1.0 * w), "pos": Vector3(0, 0.46, 0), "color": c},
		{"size": Vector3(0.86 * w, 0.1, 0.86 * w), "pos": Vector3(0, 0.6, 0), "color": trim},
		{"size": Vector3(0.7 * w, 0.62, 0.62 * w), "pos": Vector3(0, 0.96, 0), "color": c},
		{"size": Vector3(0.64 * w, 0.06, 0.58 * w), "pos": Vector3(0, 1.28, 0), "color": trim},
		{"size": Vector3(0.58 * w, 0.42, 0.52 * w), "pos": Vector3(0, 1.5, 0), "color": c},
		{"size": Vector3(0.12, 0.12, 0.04), "pos": Vector3(0, 1.5, -0.27 * w), "color": gem, "glow": true},
		{"size": Vector3(0.82 * w, 0.1, 0.72 * w), "pos": Vector3(0, 1.74, 0), "color": trim},
		{"size": Vector3(0.18, 0.6, 0.2), "pos": Vector3(-0.47 * w, 1.42, 0), "color": c},
		{"size": Vector3(0.18, 0.6, 0.2), "pos": Vector3(0.47 * w, 1.42, 0), "color": c},
		{"size": Vector3(0.52, 0.5, 0.5), "pos": Vector3(0, 2.04, 0), "color": c, "head": true},
		{"size": Vector3(0.1, 0.08, 0.02), "pos": Vector3(-0.12, 2.08, -0.255), "color": eye, "head": true, "glow": true},
		{"size": Vector3(0.1, 0.08, 0.02), "pos": Vector3(0.12, 2.08, -0.255), "color": eye, "head": true, "glow": true},
	]
	var hand := Vector3(0.6 * w, 1.3, -0.24)
	if queen:
		out.append({"size": Vector3(0.48, 0.62, 0.12), "pos": Vector3(0, 1.92, 0.27), "color": trim.darkened(0.15), "head": true})   # long hair
		out.append({"size": Vector3(0.16, 0.04, 0.02), "pos": Vector3(0, 1.93, -0.255), "color": Color(0.9, 0.35, 0.45), "head": true})   # lips
		out.append_array(_crown_at(Vector3(0, 2.29, 0), 0.46))
		out.append({"size": Vector3(0.16, 0.16, 0.16), "pos": Vector3(0, 2.7, 0), "color": gem, "head": true, "glow": true})   # the orb on top
		out.append({"size": Vector3(0.06, 0.9, 0.06), "pos": hand, "color": trim})   # a wand
		out.append({"size": Vector3(0.2, 0.2, 0.06), "pos": hand + Vector3(0, 0.55, 0), "color": gem, "glow": true})
	else:
		out.append({"size": Vector3(0.38, 0.22, 0.05), "pos": Vector3(0, 1.88, -0.26), "color": trim.lightened(0.3) if white else Color(0.8, 0.8, 0.85), "head": true})   # beard
		out.append_array(_crown_at(Vector3(0, 2.29, 0), 0.54))
		out.append({"size": Vector3(0.08, 0.3, 0.08), "pos": Vector3(0, 2.76, 0), "color": trim, "head": true})   # the cross on top
		out.append({"size": Vector3(0.26, 0.08, 0.08), "pos": Vector3(0, 2.8, 0), "color": trim, "head": true})
		out.append({"size": Vector3(0.08, 1.2, 0.08), "pos": hand, "color": trim})   # a heavy scepter
		out.append({"size": Vector3(0.24, 0.24, 0.24), "pos": hand + Vector3(0, 0.66, 0), "color": gem, "glow": true})
	if not white:
		for p in out:
			if p["color"] == Color(1.0, 0.8, 0.2):
				p["color"] = Color(0.75, 0.76, 0.82)   # silver crowns for the black pair
	return out


static func _crown_at(at: Vector3, w: float) -> Array:
	var gold := Color(1.0, 0.8, 0.2)
	var out := [{"size": Vector3(w, w * 0.22, w), "pos": at + Vector3(0, w * 0.11, 0), "color": gold, "head": true}]
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		out.append({"size": Vector3(w * 0.18, w * 0.3, w * 0.18), "pos": at + Vector3(c.x * w * 0.4, w * 0.37, c.z * w * 0.4), "color": gold, "head": true})
	out.append({"size": Vector3(w * 0.3, w * 0.25, w * 0.08), "pos": at + Vector3(0, w * 0.15, -w * 0.52), "color": Color(0.9, 0.2, 0.3), "head": true, "glow": true})
	return out


static func _recolor(parts: Array, hue: float, boost := 2.3) -> Array:
	var out := []
	for part in parts:
		var p: Dictionary = part.duplicate()
		var c: Color = p["color"]
		if c.s < 0.7 or c.v < 0.5:  # keep bright red eyes as they are
			p["color"] = Color.from_hsv(hue, 0.45, clampf(c.v * boost, 0.15, 0.95))
		out.append(p)
	return out


static func spawns_in(type: String, rule: String) -> bool:
	var s = get_def(type).get("spawn", "")
	return s == rule if s is String else rule in s


static func get_def(type: String) -> Dictionary:
	return MOBS.get(type, {})


static func display_name(type: String) -> String:
	return MOBS[type]["name"] if MOBS.has(type) else type


## Builds the blocky model. Returns {"root", "head", "legs"} so the mob can animate it.
static func build_model(type: String) -> Dictionary:
	var root := Node3D.new()
	var head := Node3D.new()
	root.add_child(head)
	var legs: Array[Node3D] = []
	var materials := {}
	for part in get_def(type).get("parts", []):
		var color: Color = part["color"]
		var glow: bool = part.get("glow", false)
		var key := [color, glow]
		var kind := Skins.part_kind(type, part)
		key.append(kind)
		if not materials.has(key):
			materials[key] = Skins.material(color, kind, glow)   # fur, scales, bone... (see skins.gd)
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part["size"]
		mesh.material = materials[key]
		mi.mesh = mesh
		var pos: Vector3 = part["pos"]
		if part.get("leg", false):
			# Pivot legs at the hip so they swing naturally.
			var pivot := Node3D.new()
			var half: float = part["size"].y * 0.5
			pivot.position = pos + Vector3(0, half, 0)
			mi.position = Vector3(0, -half, 0)
			pivot.add_child(mi)
			root.add_child(pivot)
			legs.append(pivot)
		elif part.get("head", false):
			mi.position = pos
			head.add_child(mi)
		else:
			mi.position = pos
			root.add_child(mi)
	return {"root": root, "head": head, "legs": legs}
