extends RefCounted
## Your characters, saved on this PC in user://characters.cfg.
##
## Every character has a random id. Worlds remember inventories, toots,
## unlocks and beds by that id, so each character keeps its own things no
## matter what it's called, and two characters can't mix up their stuff.
## Chests, furnaces and everything else in the world belong to the world, so
## every character sees the same chest contents.

const PATH := "user://characters.cfg"
const MAX_NAME := 20

static var _chars: Array[Dictionary] = []   # [{"id", "name", "look"}]
static var selected_id := ""


static func _static_init() -> void:
	load_all()


static func load_all() -> void:
	_chars.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section in cfg.get_sections():
		if section == "general":
			continue
		_chars.append({"id": section, "name": cfg.get_value(section, "name", "Player"),
				"look": cfg.get_value(section, "look", {}), "created": cfg.get_value(section, "created", 0)})
	_chars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["created"] < b["created"])
	selected_id = cfg.get_value("general", "selected", "")
	if get_char(selected_id).is_empty() and not _chars.is_empty():
		selected_id = _chars[0]["id"]


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "selected", selected_id)
	for c in _chars:
		cfg.set_value(c["id"], "name", c["name"])
		cfg.set_value(c["id"], "look", c["look"])
		cfg.set_value(c["id"], "created", c.get("created", 0))
	cfg.save(PATH)


static func all() -> Array[Dictionary]:
	return _chars


static func get_char(id: String) -> Dictionary:
	for c in _chars:
		if c["id"] == id:
			return c
	return {}


static func selected() -> Dictionary:
	return get_char(selected_id)


static func select(id: String) -> void:
	if not get_char(id).is_empty():
		selected_id = id
		save_all()


static func clean_name(n: String) -> String:
	n = n.strip_edges().left(MAX_NAME)
	return n if not n.is_empty() else "Player"


static func create(char_name: String, look: Dictionary, id := "") -> String:
	if id.is_empty():
		id = "c%d%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	var c := {"id": id, "name": clean_name(char_name), "look": look.duplicate(), "created": int(Time.get_unix_time_from_system())}
	var existing := get_char(id)
	if existing.is_empty():
		_chars.append(c)
	else:
		existing.merge(c, true)
	selected_id = id
	save_all()
	return id


static func update(id: String, char_name: String, look: Dictionary) -> void:
	var c := get_char(id)
	if c.is_empty():
		return
	c["name"] = clean_name(char_name)
	c["look"] = look.duplicate()
	save_all()


static func delete(id: String) -> void:
	for i in _chars.size():
		if _chars[i]["id"] == id:
			_chars.remove_at(i)
			break
	if selected_id == id:
		selected_id = _chars[0]["id"] if not _chars.is_empty() else ""
	save_all()
