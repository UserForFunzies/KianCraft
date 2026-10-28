extends RefCounted
## The character sheet (like Diablo's): what all your gear, fairy, cape, ring,
## amulet and boss power add up to right now, so you can see how they stack.
## Worked out on your own computer from what the server sent (survival.me).

const Items = preload("res://scripts/items.gd")
const Inv = preload("res://scripts/inventory.gd")
const MobData = preload("res://scripts/mob_data.gd")
const Survival = preload("res://scripts/survival.gd")

const GOOD := Color(0.6, 0.95, 0.6)
const BAD := Color(1.0, 0.5, 0.45)
const PLAIN := Color(0.9, 0.9, 0.92)
const SPECIAL := Color(1.0, 0.75, 0.35)


## Every source of each buff type: {type: [[source name, amount], ...]}.
static func sources(me: Dictionary, power: Dictionary) -> Dictionary:
	var out := {}
	var add := func(type: String, who: String, amount: float) -> void:
		if amount <= 0.0:
			return
		if not out.has(type):
			out[type] = []
		out[type].append([who, amount])
	var fairy: Dictionary = me.get("buff", {})
	if fairy.has("type"):
		add.call(fairy["type"], fairy.get("name", "Fairy"), float(fairy.get("power", 0.0)))
	var cape: Dictionary = me.get("cape", {})
	if cape.has("type"):
		add.call(cape["type"], "Cape", float(cape.get("power", 0.0)))
	var inv: Array = me.get("inventory", [])
	for i in [Inv.ARMOR_START, Inv.ARMOR_START + 1, Inv.ARMOR_START + 2, Inv.ARMOR_START + 3, Inv.RING_SLOT, Inv.AMULET_SLOT]:
		if i < inv.size() and inv[i] != null:
			var b: Dictionary = Items.get_def(inv[i]["id"]).get("buffs", {})
			for k in b:
				add.call(k, Items.display_name(inv[i]["id"]), float(b[k]) * Survival.quality(inv[i]))
	if power.has("buff"):
		add.call(power["buff"], power.get("power", "Boss power"), float(power.get("amount", 0.0)))
	return out


static func total(src: Dictionary, type: String) -> float:
	var t := 0.0
	for e in src.get(type, []):
		t += float(e[1])
	return minf(t, float(MobData.BUFF_CAP.get(type, 99.0)))


static func _tip(src: Dictionary, type: String) -> String:
	var parts := PackedStringArray()
	for e in src.get(type, []):
		parts.append("%s: +%d%%" % [e[0], roundi(float(e[1]) * 100.0)])
	if MobData.BUFF_CAP.has(type):
		parts.append("(can't go above +%d%%)" % roundi(float(MobData.BUFF_CAP[type]) * 100.0))
	return "\n".join(parts) if not parts.is_empty() else "Nothing gives you this yet."


## The sheet: a list of [section, name, value text, tooltip, color].
static func rows(me: Dictionary, power: Dictionary, held: Dictionary, power_left: float) -> Array:
	var src := sources(me, power)
	var inv: Array = me.get("inventory", [])
	var out := []
	var worn := func(i: int) -> Dictionary:
		return Items.get_def(inv[i]["id"]) if i < inv.size() and inv[i] != null else {}
	# --- Defense
	var protect := float(me.get("protect", 0.0))
	var tough := total(src, "toughness")
	var taken := (1.0 - protect) * (1.0 - tough)
	out.append(["Defense", "Health", "%d / %d" % [ceili(float(me.get("health", 20.0))), int(Survival.MAX_HEALTH)], "", PLAIN])
	out.append(["Defense", "Armor", "%d  (blocks %d%%)" % [int(me.get("armor", 0)), roundi(protect * 100.0)],
			"Each armor point blocks a bit of every hit (less and less as you add more).", PLAIN])
	out.append(["Defense", "Toughness", "%d%% less damage" % roundi(tough * 100.0), _tip(src, "toughness"), GOOD if tough > 0.0 else PLAIN])
	out.append(["Defense", "A 10 damage hit does", "%.1f" % (10.0 * taken), "Armor and toughness together.", GOOD if taken < 0.75 else PLAIN])
	# --- Attack
	var hd := Items.get_def(held.get("id", ""))
	var might := float(worn.call(Inv.ARMOR_START + 1).get("might", 0.0))
	var strength := total(src, "strength")
	var dmg := float(hd.get("damage", 1.0)) * (1.0 + strength + might) * Survival.quality(held)
	var haste := total(src, "haste")
	var leech := minf(total(src, "leech") + Survival.weapon_leech(held), float(MobData.BUFF_CAP["leech"]))
	out.append(["Attack", "Damage per hit", ("%.1f" % dmg).trim_suffix(".0"),
			"%s: %s%s" % [Items.display_name(held["id"]) if not held.is_empty() else "Fists", ("%.1f" % float(hd.get("damage", 1.0))).trim_suffix(".0"),
			("\nStrength +%d%%" % roundi(strength * 100.0) if strength > 0.0 else "") + ("\nChestplate might +%d%%" % roundi(might * 100.0) if might > 0.0 else "")], PLAIN])
	out.append(["Attack", "Swings per second", "%.1f" % ((1.0 + haste) / 0.45), _tip(src, "haste"), GOOD if haste > 0.0 else PLAIN])
	out.append(["Attack", "Life leech", "%d%%" % roundi(leech * 100.0), "Heals you for part of the damage you deal (up to %.1f health a hit).\n%s" % [Survival.LEECH_PER_HIT, _tip(src, "leech")] if leech > 0.0 else "Rings and cute weapons give life leech.", GOOD if leech > 0.0 else PLAIN])
	if hd.has("sword_power"):
		out.append(["Attack", "Weapon power", str(hd["sword_power"]).capitalize(), "\n".join(hd.get("lines", [])), SPECIAL])
	# --- Moving & mining
	for t in [["Movement", "Run speed", "speed"], ["Movement", "Jump height", "jump"], ["Mining", "Mining speed", "haste"], ["Mining", "Double ore chance", "fortune"]]:
		var v := total(src, t[2])
		var txt := ("%d%%" if t[2] == "fortune" else "+%d%%") % roundi(v * 100.0)
		if t[2] == "haste" and held.has("cute") and hd.get("tool", "") != "sword":
			txt += "  (cute tool +%d%%)" % roundi(float(held["cute"]) * 100.0)
		out.append([t[0], t[1], txt, _tip(src, t[2]), GOOD if v > 0.0 else PLAIN])
	# --- Healing
	var royal: bool = worn.call(Inv.ARMOR_START).get("regen", false)
	var regen := total(src, "regen")
	var every := (1.0 if royal else Survival.REGEN_INTERVAL) / (1.0 + regen)
	out.append(["Healing", "Heals 1 health every", "%.1f s" % every,
			("Royal Mending (the crown): every second, 2 seconds after a hit\n" if royal else "Starts %d seconds after you were last hurt\n" % int(Survival.REGEN_DELAY)) + _tip(src, "regen"),
			GOOD if royal or regen > 0.0 else PLAIN])
	# --- Protections (on/off)
	var warm: bool = total(src, "warmth") >= 0.99 or worn.call(Inv.ARMOR_START + 3).get("warm", false)
	out.append(["Protection", "Cold", "Never feels it" if warm else "Wear 4 armor pieces or stand by a light", _tip(src, "warmth"), GOOD if warm else PLAIN])
	var fireproof := total(src, "fireproof") >= 0.99
	var ward: bool = worn.call(Inv.ARMOR_START + 1).get("ward", false)
	out.append(["Protection", "Fire", "Fireproof" if fireproof else ("Fire & Ice Ward" if ward else "Burns"), _tip(src, "fireproof"), GOOD if fireproof or ward else PLAIN])
	match power.get("special", ""):
		"no_fall":
			out.append(["Protection", "Falling", "Never hurts", "Pounce (boss power)", GOOD])
		"arrow_ward":
			out.append(["Protection", "Arrows", "Half damage", "Fire & Ice (boss power)", GOOD])
		"night_eyes":
			out.append(["Protection", "Night Eyes", "See in the dark", "Monsters notice you from half as far", GOOD])
		"harvest":
			out.append(["Protection", "Harvest", "Double drops", "Monsters and animals drop twice as much", GOOD])
	# --- What's active right now
	var fairy: Dictionary = me.get("buff", {})
	if not fairy.is_empty():
		out.append(["Active", "Fairy", fairy.get("name", "Fairy"), fairy.get("text", ""), GOOD])
	if not power.is_empty():
		out.append(["Active", "Boss power", "%s (%d:%02d left)" % [power.get("power", "?"), int(power_left) / 60, int(power_left) % 60], power.get("text", ""), SPECIAL])
	if royal:
		out.append(["Active", "Royal Mending", "On", "The King Cougar's crown", SPECIAL])
	if me.get("freezing", false):
		out.append(["Active", "Freezing!", "Losing health", "Get warm: armor in all 4 slots, a light, or a warmth power", BAD])
	if me.get("burning", false):
		out.append(["Active", "On fire!", "Losing health", "It stops in a few seconds", BAD])
	if me.get("chilled", false):
		out.append(["Active", "Chilled", "Slower", "Hit by ice: you move slower for a bit", BAD])
	return out
