extends RefCounted
## Saving and loading worlds.
##
## Each world is one compressed file in the user data folder:
##   Windows: %APPDATA%\Godot\app_userdata\Blockcraft\worlds\
##   macOS:   ~/Library/Application Support/Godot/app_userdata/Blockcraft/worlds/
##   Linux:   ~/.local/share/godot/app_userdata/Blockcraft/worlds/
## A save only needs the seed plus the blocks players changed, so files stay small.

const WORLDS_DIR := "user://worlds"
const EXTENSION := ".world"
const FORMAT_VERSION := 1


static func list_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	for file in DirAccess.get_files_at(WORLDS_DIR):
		if not file.ends_with(EXTENSION):
			continue
		var data := load_world(file)
		if data.is_empty():
			continue
		out.append({
			"file": file,
			"name": data.get("name", file.get_basename()),
			"seed": data.get("seed", 0),
			"last_played": data.get("last_played", 0),
			"gen": data.get("gen", 1),
			"pvp": data.get("pvp", "off"),
			"host_commands": data.get("host_commands", true),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["last_played"] > b["last_played"])
	return out


## Makes a new, unused file name from a world name ("My World" -> "my_world.world").
static func new_file_name(world_name: String) -> String:
	var base := ""
	for ch in world_name.to_lower().strip_edges():
		base += ch if ch.is_valid_identifier() or ch.is_valid_int() else "_"
	if base.replace("_", "").is_empty():
		base = "world"
	var file := base + EXTENSION
	var n := 2
	while FileAccess.file_exists(WORLDS_DIR.path_join(file)):
		file = "%s_%d%s" % [base, n, EXTENSION]
		n += 1
	return file


static func load_world(file: String) -> Dictionary:
	var path := WORLDS_DIR.path_join(file)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_warning("Couldn't open save %s" % path)
		return {}
	var data = f.get_var()
	if typeof(data) != TYPE_DICTIONARY or not data.has("seed"):
		push_warning("Save file %s is damaged or not a world" % path)
		return {}
	return data


## Writes to a temporary file first, so a crash mid-save can't ruin the world.
static func save_world(file: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(WORLDS_DIR)
	data["version"] = FORMAT_VERSION
	data["last_played"] = int(Time.get_unix_time_from_system())
	var path := WORLDS_DIR.path_join(file)
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		push_error("Couldn't write save %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data)
	f.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Couldn't finish saving %s (error %d)" % [path, err])
		return false
	return true


static func delete_world(file: String) -> void:
	DirAccess.remove_absolute(WORLDS_DIR.path_join(file))


static func folder_path() -> String:
	return ProjectSettings.globalize_path(WORLDS_DIR)
