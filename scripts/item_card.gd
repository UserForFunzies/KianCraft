extends RefCounted
## Diablo-style item title cards: the name colored by how special the item is,
## a type line, blue stat lines, a short description, then who made it and
## what it sells for. Kept short so it never gets busy.
##
## Colors: Basic (white), Tier 1 (green), Tier 2 (blue), Tier 3 (gold),
## Cute (pink), Legendary (orange).

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Survival = preload("res://scripts/survival.gd")
const MobData = preload("res://scripts/mob_data.gd")

const COLORS := {
	"basic": Color(0.92, 0.92, 0.9),
	"t1": Color(0.45, 0.88, 0.45),
	"t2": Color(0.45, 0.68, 1.0),
	"t3": Color(1.0, 0.82, 0.3),
	"cute": Color(1.0, 0.55, 0.8),
	"legendary": Color(1.0, 0.55, 0.1),
}
const LABELS := {"basic": "Basic", "t1": "Tier 1", "t2": "Tier 2", "t3": "Tier 3", "cute": "Cute", "legendary": "Legendary"}
const BENCH_TIER := {"sawmill": 1, "stonecutter": 2, "shaper": 3, "jewelry": 3}
const STAT := "#8fb4ff"
const SOFT := "#a89e8c"
const GOLD := "#e8c46a"

static var _rank_cache := {}


## "basic", "t1", "t2", "t3", "cute" or "legendary".
static func rank(id: String) -> String:
	if _rank_cache.has(id):
		return _rank_cache[id]
	var d := Items.get_def(id)
	var out := "basic"
	if d.get("rarity", "") == "legendary":
		out = "legendary"
	elif d.get("cute", false):
		out = "cute"
	else:
		var tier := _tier(id, 0)
		out = ["basic", "t1", "t2", "t3"][clampi(tier, 0, 3)]
	_rank_cache[id] = out
	return out


## Which workbench tier an item comes from (0 = by hand or found).
static func _tier(id: String, depth: int) -> int:
	if depth > 4:
		return 0
	var r := Recipes.get_recipe(id)
	if not r.is_empty():
		if r.has("bench"):
			return BENCH_TIER.get(r["bench"], 1)
		return int(r["station"])
	# Smelted: as good as the ore it came from.
	for ore in Recipes.SMELTING:
		if Recipes.SMELTING[ore] == id:
			return _tier(ore, depth + 1)
	var b := Items.block_of(id)
	if b >= 0 and Blocks.MIN_TIER[b] >= 2:
		return clampi(Blocks.MIN_TIER[b] - 1, 1, 3)   # ore that needs a stone/iron/titanium pick
	return 0


static func color(id: String) -> Color:
	return COLORS[rank(id)]


static func _type_line(id: String, d: Dictionary) -> String:
	var kind := "Item"
	if d.has("tool"):
		kind = {"pickaxe": "Pickaxe", "axe": "Axe", "sword": "Sword", "shovel": "Shovel"}.get(d["tool"], "Tool")
	elif d.has("bow"):
		kind = "Bow"
	elif d.has("arrow"):
		kind = "Arrow"
	elif d.has("cape"):
		kind = "Cape"
	elif d.get("slot", "") == "ring":
		kind = "Ring"
	elif d.get("slot", "") == "amulet":
		kind = "Amulet"
	elif d.has("armor"):
		kind = {"head": "Helmet", "chest": "Chestplate", "legs": "Leggings", "feet": "Boots"}.get(d.get("slot", ""), "Armor")
	elif Items.is_map(id):
		kind = "Map"
	elif d.has("food"):
		kind = "Food"
	elif d.get("plant", false):
		kind = "Plant"
	elif d.has("block"):
		kind = "Block"
	else:
		kind = "Material"
	return "%s %s" % [LABELS[rank(id)], kind]


## The card in pieces, for the floating item pane: {"name", "name_color",
## "color" (rarity), "kind", "body" (BBCode: stats, description, footer)}.
static func parts(item: Dictionary) -> Dictionary:
	var id: String = item["id"]
	var d := Items.get_def(id)
	var full := bbcode(item)
	var lines := full.split("\n")
	var body := "\n".join(lines.slice(2 if not item.has("label") else 3))
	var name_c := color(id)
	if item.has("label_ink"):
		name_c = Color(Items.get_def(str(item["label_ink"])).get("liquid", color(id))).lightened(0.15)
	var kind: String = d.get("kind_text", _type_line(id, d))
	if item.has("label"):
		kind = "%s  -  %s" % [kind, Items.display_name(id)]
	if item.get("count", 1) > 1:
		kind += "   x%d" % int(item["count"])
	var shown_name: String = item.get("label", Items.display_name(id))
	if Survival.is_perfect(item) and not item.has("label"):
		shown_name = "Perfect " + shown_name
	elif item.has("jewel_roll") and not item.has("label"):
		shown_name = Survival.jewel_name(item)
	return {"name": shown_name, "name_color": name_c, "color": color(id), "kind": kind, "body": body}


## The card's text (BBCode) for one inventory slot.
static func bbcode(item: Dictionary, describe := true) -> String:
	var id: String = item["id"]
	var d := Items.get_def(id)
	var c := color(id).to_html(false)
	var name: String = item.get("label", Items.display_name(id))
	if Survival.is_perfect(item) and not item.has("label"):
		name = "Perfect " + name
	elif item.has("jewel_roll") and not item.has("label"):
		name = Survival.jewel_name(item)
	var name_c := c
	if item.has("label_ink"):
		name_c = Color(Items.get_def(str(item["label_ink"])).get("liquid", color(id))).lightened(0.15).to_html(false)
	var out := "[b][color=#%s]%s[/color][/b]\n[color=#%s]%s[/color]" % [name_c, _safe(name), c, d.get("kind_text", _type_line(id, d))]
	if item.has("label"):
		out += "\n[color=%s]%s[/color]" % [SOFT, _safe(Items.display_name(id))]
	var stats := PackedStringArray()
	var q := Survival.quality(item)
	if d.get("rarity", "") == "legendary" and item.has("roll"):
		stats.append("[color=#ffd166]%s[/color]" % ("PERFECT roll: 100%" if Survival.is_perfect(item) else "Rolled %d%% (100%% is Perfect)" % roundi(q * 100.0)))
	if d.has("damage"):
		stats.append("%s Damage" % _num(float(d["damage"]) * q))
	if d.has("tool") and d["tool"] != "sword":
		stats.append("Digs %sx faster" % _num(d.get("speed", 1.0)))
	if d.has("bow"):
		stats.append("x%s arrow damage" % _num(d["bow_damage"]))
	if d.has("arrow"):
		stats.append("%s Damage" % _num(d["arrow"]))
	if d.has("armor"):
		stats.append("+%d Armor" % roundi(float(d["armor"]) * q))
	if d.has("food"):
		stats.append("Heals %s" % _num(d["food"]))
	for l in d.get("lines", []):
		stats.append(l)
	if item.has("cute"):
		var weapon: bool = d.get("tool", "") == "sword" or d.has("bow")
		if weapon:
			stats.append("[color=#ff8cc8]Cute bonus: %d%% life leech (heals you as you hit)[/color]" % roundi(float(item["cute"]) * 100.0))
		elif not (d.has("cape") and d.get("buff", "") in MobData.BINARY_BUFFS):
			var what := "armor" if d.has("armor") else ("power" if d.has("cape") else "speed")
			stats.append("[color=#ff8cc8]Cute bonus: +%d%% %s[/color]" % [roundi(float(item["cute"]) * 100.0), what])
	if item.has("jewel_roll"):
		stats.append("[color=#ffd166]Gem rolled %d%% (100%% is Radiant)[/color]" % roundi(float(item["jewel_roll"]) * 100.0))
	var buffs: Dictionary = item.get("buffs", d.get("buffs", {}))
	for k in buffs:
		stats.append(MobData.buff_text(k, float(buffs[k]) * q))
	if d.has("cape"):
		var power := Survival.cape_power(id, float(item.get("roll", 0.85)))
		var line := MobData.buff_text(d["buff"], power)
		if item.has("roll") and not d["buff"] in MobData.BINARY_BUFFS:
			line += "  [color=%s](made %d%% well)[/color]" % [SOFT, roundi(float(item["roll"]) * 100.0)]
		stats.append(line)
	if not stats.is_empty():
		out += "\n[color=%s]%s[/color]" % [STAT, "\n".join(stats)]
	if d.has("flavor"):
		out += "\n[i][color=#c9a25b]\"%s\"[/color][/i]" % d["flavor"]
	elif describe:
		out += "\n[color=%s]%s[/color]" % [SOFT, Items.describe(id)]
	if item.has("treasure"):
		var boss := preload("res://scripts/boss_data.gd").get_boss(str(item["treasure"]))
		if not boss.is_empty():
			out += "\n[color=#ff8a5c]The skull marks the lair of the %s![/color]" % boss["name"]
		else:
			out += "\n[color=#ff8a5c]X marks %s![/color]" % Survival.TREASURE_TEXT.get(str(item["treasure"]), "treasure")
	var foot := PackedStringArray()
	if item.has("maker"):
		foot.append("[color=#9ec5ff]Made by %s[/color]" % _safe(str(item["maker"])))
	if item.has("scribe"):
		foot.append("[color=#9ec5ff]Inscribed by %s[/color]" % _safe(str(item["scribe"])))
	var v := Recipes.value(id)
	if v > 0.0:
		foot.append("[color=%s]Sells for %s%s[/color]" % [GOLD, Recipes.format_toots(v), "" if Items.max_stack(id) == 1 else " each"])
	if not foot.is_empty():
		out += "\n" + "\n".join(foot)
	return out


static func _num(v) -> String:
	return ("%.1f" % float(v)).trim_suffix(".0")


static func _safe(t: String) -> String:
	return t.replace("[", "[lb]")
