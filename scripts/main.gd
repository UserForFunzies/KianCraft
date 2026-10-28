extends Node
## Game entry point: ties together the menu, world, players, saving, day/night and chat.
##
## Multiplayer model ("listen server"):
## - One person hosts a saved world. Their computer is the server AND a player.
## - Friends join with the host's IP address.
## - The server sends new players the world seed, every block edit, the time
##   of day and where they were standing last time.
## - Each player moves themselves and broadcasts their position.
## - Survival rules (mining, crafting, health, loot) and mobs run on the server
##   (survival.gd, mobs.gd); block edits and chat go through it too.
## - Only the server saves. Clients don't keep a copy of the world.
##
## Command line (handy for testing or a dedicated server; put after `--`):
##   --server              dedicated server, no local player (anyone may use admin commands)
##   --world=NAME          world to load or create (with --server or --host)
##   --host / --join=IP    skip the menu
##   --port=7777  --seed=123  --name=Steve

const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
const Menu = preload("res://scripts/menu.gd")
const DayNight = preload("res://scripts/day_night.gd")
const SaveSystem = preload("res://scripts/save_system.gd")
const Blocks = preload("res://scripts/blocks.gd")
const Survival = preload("res://scripts/survival.gd")
const Mobs = preload("res://scripts/mobs.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const MapUI = preload("res://scripts/map_ui.gd")
const PortalUI = preload("res://scripts/portal_ui.gd")
const PartyUI = preload("res://scripts/party_ui.gd")
const AdminUI = preload("res://scripts/admin_ui.gd")
const LoadingScreen = preload("res://scripts/loading_screen.gd")
const Inv = preload("res://scripts/inventory.gd")
const Items = preload("res://scripts/items.gd")
const MobData = preload("res://scripts/mob_data.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Effects = preload("res://scripts/effects.gd")
const BlockModels = preload("res://scripts/block_models.gd")
const Settings = preload("res://scripts/settings.gd")
const SettingsUI = preload("res://scripts/settings_ui.gd")
const Sound = preload("res://scripts/sound.gd")
const Characters = preload("res://scripts/characters.gd")
const Avatar = preload("res://scripts/avatar.gd")
const CharacterUI = preload("res://scripts/character_ui.gd")
const Graphics = preload("res://scripts/graphics.gd")
const TorchLights = preload("res://scripts/torch_lights.gd")
const Weather = preload("res://scripts/weather.gd")

const MAX_PLAYERS := 8
const AUTOSAVE_SECONDS := 120.0
const TIME_SYNC_SECONDS := 10.0

var world: World
var players: Node3D
var hud: Hud
var menu: Menu
var day_night: DayNight
var survival: Survival
var mobs: Mobs
var inventory_ui: InventoryUI
var map_ui: MapUI
var portal_ui: PortalUI
var party_ui: PartyUI
var admin_ui: AdminUI
var loading: LoadingScreen
var _loading_t := 0.0
const LOAD_RADIUS := 2          # chunks around you that must be ready before the loading screen goes
const LOAD_GIVE_UP := 25.0
var _tag_timer := 0.0
var block_models: BlockModels
var settings_ui: SettingsUI
var character_ui: CharacterUI
var effects: Effects
var local_player: Node
var dedicated := false
var in_game := false

var _env: Environment
var torch_lights: TorchLights
var weather: Weather
var _session_text := ""
var _world_file := ""              # save file of the world being played ("" on clients)
var _world_save := {}              # last loaded/saved data for that world
var _peer_names := {}              # server only: peer id -> character name
var _peer_keys := {}               # server only: peer id -> character id (what the world saves by)
var _peer_looks := {}              # everyone: peer id -> look (sent to new players)
var _autosave_timer := 0.0
var _time_sync_timer := 0.0
var _focus_timer := 0.0
var _ambience_timer := 0.0


func _ready() -> void:
	get_tree().auto_accept_quit = false  # lets us save before the window closes
	get_tree().root.theme = UI.get_theme()  # one look for every screen
	# Menus live on CanvasLayers, which don't pass the window's theme down, so
	# also make it the engine's default theme (every Control falls back to it).
	ThemeDB.get_default_theme().merge_with(UI.get_theme())
	ThemeDB.get_default_theme().default_font = UI.body_font()
	ThemeDB.get_default_theme().default_font_size = UI.FONT_SIZE
	# (The project is still called "Blockcraft" inside so save files stay where
	# they are; players see KianCraft.)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("KianCraft")
	Blocks.set_texture_detail(Settings.q()["detail_textures"])  # before anything draws a block
	Settings.apply_display(get_tree())
	Settings.on_changed(_on_settings_changed)
	var sound := Sound.new()
	sound.name = "Sound"
	sound.enabled = not (DisplayServer.get_name() == "headless" and "--server" in OS.get_cmdline_user_args())
	add_child(sound)
	# Every button in the game clicks softly when pressed.
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton and not n.is_connected("pressed", Sound.ui):
			n.pressed.connect(Sound.ui))
	_setup_input()
	world = World.new()
	world.name = "World"  # node names must match on every computer for RPCs
	add_child(world)
	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	effects = Effects.new()
	effects.name = "Effects"
	add_child(effects)
	effects.world = world
	world.block_changed.connect(effects.on_block_changed)
	block_models = BlockModels.new()
	block_models.name = "BlockModels"
	block_models.world = world
	add_child(block_models)
	world.block_changed.connect(block_models.on_block_changed)
	world.models_lit.connect(block_models.on_models_lit)
	_setup_environment()
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(_env, world)
	torch_lights = TorchLights.new()
	torch_lights.name = "TorchLights"
	torch_lights.world = world
	add_child(torch_lights)
	weather = Weather.new()
	weather.name = "Weather"   # same name on every computer (it receives RPCs)
	weather.main = self
	add_child(weather)
	_apply_graphics()
	survival = Survival.new()
	survival.name = "Survival"
	survival.main = self
	add_child(survival)
	block_models.survival = survival   # frames and stands show what survival says is on them
	mobs = Mobs.new()
	mobs.name = "Mobs"
	mobs.world = world
	mobs.day_night = day_night
	mobs.get_players = survival.player_list
	mobs.on_attack = survival.on_mob_attack
	mobs.on_shoot = survival.mob_shoot
	mobs.mob_killed.connect(survival.on_mob_killed)
	mobs.announce = func(text: String) -> void: _receive_event.rpc(text, "trophy_yeti" if text.contains("beat") or text.contains("defeated") else "iron_sword")
	mobs.name_of = func(peer: int) -> String: return str(survival._states.get(peer, {}).get("name", "Someone"))
	mobs.bed_for = survival.most_active_bed
	mobs.owner_peer = survival.peer_of
	mobs.bed_pos_for = survival.bed_of
	mobs.fairy_changed = func(key: String) -> void:
		var peer: int = survival.peer_of(key)
		if peer != 0:
			survival._sync_self(peer)
	add_child(mobs)

	hud = Hud.new()
	hud.players_root = players
	hud.day_night = day_night
	hud.visible = false
	hud.resume_requested.connect(_resume)
	hud.leave_requested.connect(func() -> void: leave_game(""))
	hud.chat_submitted.connect(_on_chat_submitted)
	hud.respawn_requested.connect(func() -> void: survival.req_respawn.rpc_id(1))
	hud.survival = survival
	hud.mobs = mobs
	hud.trade_answered.connect(func(from_peer: int, yes: bool) -> void: survival.req_trade_answer.rpc_id(1, from_peer, yes))
	hud.wake_requested.connect(func() -> void: survival.req_wake.rpc_id(1))
	add_child(hud)
	inventory_ui = InventoryUI.new()
	add_child(inventory_ui)
	inventory_ui.bind(survival)
	inventory_ui.closed.connect(_on_window_closed)
	inventory_ui.closed.connect(func() -> void: Sound.ui("close"))
	inventory_ui.opened.connect(func() -> void: Sound.ui("open"))
	inventory_ui.get_look_dir = func() -> Vector3:
		return -local_player._camera.global_basis.z if local_player else Vector3.FORWARD
	map_ui = MapUI.new()
	add_child(map_ui)
	map_ui.bind(survival)
	map_ui.get_player = func() -> Node3D: return local_player
	map_ui.closed.connect(_on_window_closed)
	map_ui.closed.connect(func() -> void: Sound.ui("close"))
	map_ui.opened.connect(func() -> void: Sound.ui("open"))
	portal_ui = PortalUI.new()
	portal_ui.survival = survival
	add_child(portal_ui)
	portal_ui.closed.connect(_on_window_closed)
	admin_ui = AdminUI.new()
	admin_ui.main = self
	add_child(admin_ui)
	admin_ui.closed.connect(_on_window_closed)
	hud.pvp_toggle_requested.connect(func(on: bool) -> void: req_set_pvp.rpc_id(1, on))
	hud.lock_commands_requested.connect(func() -> void: req_lock_commands.rpc_id(1))
	party_ui = PartyUI.new()
	party_ui.survival = survival
	party_ui.players_root = players
	add_child(party_ui)
	party_ui.closed.connect(_on_window_closed)
	survival.party_changed.connect(func() -> void:
		if party_ui.is_open():
			party_ui.redraw()
		_update_name_tags())
	survival.party_invited.connect(hud.show_party_invite)
	hud.party_answered.connect(func(from_peer: int, yes: bool) -> void: survival.req_party_answer.rpc_id(1, from_peer, yes))
	survival.self_changed.connect(hud.refresh)
	survival.notice.connect(hud.show_notice)
	survival.hurt.connect(hud.flash_hurt)
	survival.hurt.connect(func() -> void: Sound.play("hurt", -3.0, randf_range(0.92, 1.08)))
	survival.legendary_found.connect(func(_i: String) -> void: Sound.play("legendary", 0.0, 1.0, "Interface"))
	survival.died.connect(_on_died)
	survival.respawned.connect(_on_respawned)
	survival.sleep_changed.connect(_on_sleep_changed)
	survival.trade_invited.connect(hud.show_trade_invite)
	survival.legendary_found.connect(hud.show_legendary)
	survival.arena_countdown.connect(hud.show_countdown)
	survival.recipes_discovered.connect(func(ids: Array) -> void:
		hud.show_discoveries(ids)
		Sound.play("unlock", -6.0, 1.15, "Interface"))
	survival.container_changed.connect(_on_container_changed)

	menu = Menu.new()
	menu.play_requested.connect(play_world)
	menu.join_requested.connect(join_game)
	menu.quit_requested.connect(_quit)
	menu.settings_requested.connect(func() -> void: settings_ui.open())
	add_child(menu)
	character_ui = CharacterUI.new()
	character_ui.changed.connect(menu.refresh_character)
	add_child(character_ui)
	menu.characters_requested.connect(func() -> void:
		if Characters.all().is_empty():
			character_ui.open_create("")
		else:
			character_ui.open_select())
	loading = LoadingScreen.new()
	add_child(loading)
	settings_ui = SettingsUI.new()
	settings_ui.closed.connect(_on_settings_closed)
	add_child(settings_ui)
	hud.settings_requested.connect(func() -> void: settings_ui.open())
	_on_settings_changed()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_handle_command_line()
	if not in_game:
		settings_ui.show_welcome_if_first_run()
		if Characters.all().is_empty() and DisplayServer.get_name() != "headless":
			character_ui.open_create("")  # first thing: make a character


## Graphics/tips changed: push the new values to everything that uses them.
func _on_settings_changed() -> void:
	var q := Settings.q()
	Blocks.set_texture_detail(q["detail_textures"])
	Items.refresh_block_icons()
	world.set_render_distance(Settings.view_distance())
	_update_fog()
	_apply_graphics()
	effects.particle_scale = q["particles"]
	hud.refresh()
	hud.update_tips()
	if inventory_ui.is_open():
		inventory_ui.redraw()


func _on_settings_closed() -> void:
	if hud.is_paused() or not in_game:
		return
	_resume()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		get_viewport().set_input_as_handled()
		Settings.toggle_fullscreen(get_tree())


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


func _quit() -> void:
	Blocks.finish_texture_job()
	if in_game:
		save_world()
	get_tree().quit()


# --- Setup -------------------------------------------------------------------------

func _setup_input() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("sprint", [KEY_CTRL])
	_bind_keys("descend", [KEY_SHIFT])  # sneak
	_bind_keys("inventory", [KEY_E, KEY_TAB])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("chat", [KEY_T, KEY_ENTER])
	_bind_keys("command", [KEY_SLASH])
	_bind_keys("drop", [KEY_Q])
	_bind_keys("map", [KEY_M])
	_bind_keys("party", [KEY_P])
	_bind_keys("power", [KEY_F])
	for i in 9:
		_bind_keys("hotbar_%d" % (i + 1), [KEY_1 + i])
	_bind_mouse("break", MOUSE_BUTTON_LEFT)
	_bind_mouse("place", MOUSE_BUTTON_RIGHT)
	_bind_mouse("pick", MOUSE_BUTTON_MIDDLE)


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k  # physical = same key position on any keyboard layout
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## Sky, sun, shadows, glow, fog... for the current graphics settings.
func _apply_graphics() -> void:
	Graphics.apply(_env)
	Graphics.apply_world(world)
	day_night.apply_graphics()
	torch_lights.apply_settings()


func _setup_environment() -> void:
	_env = Graphics.make_environment()
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_update_fog()


func _update_fog() -> void:
	var far := float(world.render_distance * Blocks.CHUNK_SIZE)
	_env.fog_depth_begin = far * 0.45
	_env.fog_depth_end = far * 0.97


func _handle_command_line() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var parts := a.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else ""
	if args.has("name"):
		menu.set_player_name(args["name"])
	if args.has("port"):
		menu.set_port(args["port"].to_int())
	if args.has("server") or args.has("host"):
		dedicated = args.has("server")
		var world_name: String = args.get("world", "Server World")
		var seed_text: String = args.get("seed", "")
		var seed_value := seed_text.to_int() if seed_text.is_valid_int() else randi()
		play_world(_find_or_create_world(world_name, seed_value), true)
	elif args.has("join"):
		var address: String = args["join"] if args["join"] != "" else "127.0.0.1"
		menu.set_address(address)
		join_game(address, menu.get_port())


func _find_or_create_world(world_name: String, seed_value: int) -> String:
	for w in SaveSystem.list_worlds():
		if w["name"] == world_name or w["file"] == world_name:
			return w["file"]
	print("Creating new world \"%s\" (seed %d)" % [world_name, seed_value])
	return Menu.create_world_file(world_name, seed_value)


# --- Starting / leaving games ----------------------------------------------------------

## Loads a saved world and plays it alone, or hosts it for friends.
func play_world(file: String, host: bool) -> void:
	var data := SaveSystem.load_world(file)
	if data.is_empty():
		menu.set_status("That world couldn't be loaded. The save file may be damaged.")
		return
	_show_loading("Loading %s" % data["name"], "Building the land around you...")
	if host:
		var port := menu.get_port()
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(port, MAX_PLAYERS)
		if err != OK:
			menu.set_status("Couldn't host on port %d (error %d). Is another copy of the game already hosting?" % [port, err])
			print("Failed to host: error ", err)
			return
		multiplayer.multiplayer_peer = peer
		var ips := _local_ipv4_addresses()
		_session_text = "World: %s\nHosting on port %d.\nFriends on your network can join using: %s" % [
			data["name"], port, ", ".join(ips) if not ips.is_empty() else "(no network address found)"]
		print("Server started on port %d, world \"%s\" (seed %d). Local addresses: %s" % [
			port, data["name"], data["seed"], ips])
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		_session_text = "World: %s (singleplayer)" % data["name"]

	_world_file = file
	_world_save = data
	_peer_names = {} if dedicated else {1: menu.get_player_name()}
	_peer_keys = {} if dedicated else {1: menu.get_character_id()}
	_begin_world(data["seed"], data.get("changes", {}), data.get("world_time", 0.0), data.get("door_facing", {}), data.get("gen", 1))
	survival.server_start(data.get("survival", {}))
	mobs.server_start(data.get("mobs", {}))
	_send_rules()
	if not dedicated:
		var state: Dictionary = _position_for(menu.get_character_id(), menu.get_player_name())
		_spawn_player(1, state)
		survival.server_add_player(1, menu.get_player_name(), menu.get_character_id())
		if Settings.show_tips:
			hud.add_chat("", "Welcome to %s! Punch trees for logs, then press E to craft. T to chat, /help for commands." % data["name"])
		else:
			hud.add_chat("", "Welcome to %s!" % data["name"])


func join_game(address: String, port: int) -> void:
	if not menu.has_character():
		character_ui.open_create("")
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		menu.set_busy(false, "Couldn't start connecting (error %d)." % err)
		return
	multiplayer.multiplayer_peer = peer
	_world_file = ""
	_show_loading("Joining a friend", "Connecting to %s..." % address)
	_session_text = "Connected to %s:%d" % [address, port]
	menu.set_busy(true, "Connecting to %s:%d ..." % [address, port])
	print("Connecting to %s:%d" % [address, port])


## The loading screen goes up (not on a headless server or in tests).
func _show_loading(title: String, status: String) -> void:
	if dedicated or DisplayServer.get_name() == "headless":
		return
	_loading_t = 0.0
	loading.show_loading(title, status)


## While the loading screen is up: how much of the ground around you is ready.
func _tick_loading(delta: float) -> void:
	if not loading.is_showing() or loading._closing >= 0.0:
		return
	if not in_game or local_player == null or not is_instance_valid(local_player):
		return
	_loading_t += delta
	local_player.input_enabled = false
	var c: Vector2i = world.chunk_key_at(local_player.global_position)
	var total := 0
	var ready := 0
	for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			total += 1
			if world.is_ready_at(Vector3((c.x + dx) * 16 + 8, 0, (c.y + dz) * 16 + 8)):
				ready += 1
	loading.progress = float(ready) / float(total)
	loading.set_status("Building the land around you... (%d of %d pieces)" % [ready, total])
	if ready == total or _loading_t > LOAD_GIVE_UP:
		loading.progress = 1.0
		loading.finish()
		if not hud.is_paused() and not inventory_ui.is_open():
			local_player.input_enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin_world(seed_value: int, changes: Dictionary, world_time: float, door_facing := {}, gen := 1) -> void:
	world.start(seed_value, changes, door_facing, gen)
	world.set_render_distance(menu.get_render_distance())
	block_models.rebuild_all()
	_update_fog()
	day_night.world_time = world_time
	day_night.running = true
	weather.reset()
	in_game = true
	_autosave_timer = AUTOSAVE_SECONDS
	menu.visible = false
	hud.visible = not dedicated
	hud.set_paused(false)
	hud.clear_chat()
	hud.set_session_text(_session_text)
	menu.set_busy(false, "")
	if not dedicated:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Saves (if this computer owns the world) and returns to the main menu.
func leave_game(reason: String) -> void:
	if in_game:
		save_world()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	inventory_ui.close()
	map_ui.close()
	portal_ui.close()
	party_ui.close()
	admin_ui.close()
	loading.hide_now()
	_rules = {}
	hud.hide_death()
	hud.show_sleep(false)
	block_models.clear()
	for p in players.get_children():
		players.remove_child(p)
		p.queue_free()
	local_player = null
	hud.player = null
	survival.clear_all()
	mobs.clear()
	world.clear()
	day_night.running = false
	in_game = false
	_world_file = ""
	_peer_names.clear()
	_peer_keys.clear()
	hud.visible = false
	menu.visible = true
	menu.refresh_worlds()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.set_busy(false, reason)
	if dedicated:
		get_tree().quit()


func _spawn_player(id: int, state := {}) -> Node:
	if players.has_node(str(id)):
		return players.get_node(str(id))
	var p := Player.new()
	p.name = str(id)
	p.set_multiplayer_authority(id)
	p.world = world
	p.survival = survival
	p.mobs = mobs
	var is_local := id == multiplayer.get_unique_id()
	if is_local:
		p.display_name = menu.get_player_name()
		p.look = menu.get_character_look()
		p.position = world.find_spawn_point()
	players.add_child(p)
	if is_local:
		p.spawn_point = world.find_spawn_point()
		if not state.is_empty():
			p.apply_save_state(state)
		local_player = p
		world.set_focus(p)
		hud.bind_player(p)
		p.interact_block.connect(_on_interact_block)
		p.interact_loot.connect(_on_interact_loot)
		p.interact_npc.connect(_on_interact_npc)
		p.interact_villager.connect(_on_interact_villager)
		p.interact_fairy.connect(func(mob_id: int) -> void: survival.req_befriend_fairy.rpc_id(1, mob_id))
		p.open_map.connect(_open_map)
		p.interact_player.connect(func(peer: int) -> void: survival.req_trade_request.rpc_id(1, peer))
		inventory_ui.set_player_look(p.look, p.display_name)
	return p


func _local_ipv4_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			out.append(ip)
	return out


# --- Saving ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_tick_loading(delta)
	if Blocks.poll_texture_job():
		Items.refresh_block_icons()   # the Ultra HD textures are ready
	if day_night and survival:
		day_night.night_eyes = in_game and survival.active_power().get("special", "") == "night_eyes"
	_tag_timer -= delta
	if _tag_timer <= 0.0 and in_game:
		_tag_timer = 0.5
		_update_name_tags()
	_update_ambience(delta)
	if not in_game or not multiplayer.is_server():
		return
	_world_save["play_time"] = float(_world_save.get("play_time", 0.0)) + delta
	# Keep terrain data loaded around other players so mobs and rules work there.
	_focus_timer -= delta
	if _focus_timer <= 0.0:
		_focus_timer = 1.0
		var points := []
		for p in players.get_children():
			if p != local_player:
				points.append(p.global_position)
		world.set_extra_focus(points)
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_world()
	if not multiplayer.get_peers().is_empty():
		_time_sync_timer -= delta
		if _time_sync_timer <= 0.0:
			_time_sync_timer = TIME_SYNC_SECONDS
			_sync_time.rpc(day_night.world_time)


## Background sounds: wind by day, crickets at night, a low rumble with drips
## underground, and twinkles in candy land. They fade smoothly as things change.
func _update_ambience(delta: float) -> void:
	_ambience_timer -= delta
	if _ambience_timer > 0.0 or Sound.instance == null:
		return
	_ambience_timer = 0.5
	if not in_game or local_player == null or dedicated:
		Sound.instance.stop_ambience()
		return
	var p: Vector3 = local_player.global_position
	var head := Vector3i(floori(p.x), floori(p.y + 1.6), floori(p.z))
	var outside: bool = world.sees_sky(head)
	var deep: bool = not outside and p.y < world.surface_height(floori(p.x), floori(p.z)) - 4
	var night: bool = day_night.is_night()
	var candy: bool = world.biome_at(p.x, p.z) == "candy"
	Sound.instance.set_ambience({
		"wind": (0.35 if not night else 0.2) if outside else 0.05,
		"crickets": 0.45 if night and outside and not candy else 0.0,
		"cave": 0.55 if deep else 0.0,
		"rain": weather.rain_sound() * (0.2 if deep else 1.0),
	})
	# QtMaMe's tune: until she's moved into someone's bed, it plays from her
	# direction and gets louder the closer you are, so you can follow it to her.
	var b: Dictionary = mobs.npc_beacon
	var strength := 0.0
	if b.get("active", false):
		var d := Vector2(b["pos"].x - p.x, b["pos"].z - p.z).length()
		strength = clampf(1.0 - d / NPC_MUSIC_RANGE, 0.0, 1.0)
		strength = 0.15 + 0.85 * strength * strength if d < NPC_MUSIC_RANGE else 0.0
	Sound.instance.set_beacon(b.get("pos", Vector3.ZERO), strength)


const NPC_MUSIC_RANGE := 420.0   # how far away you can start to hear QtMaMe's tune


## Writes the world to disk. Only the server/host has a save file.
func save_world() -> bool:
	if _world_file.is_empty() or not multiplayer.is_server():
		return false
	var saved_players: Dictionary = _world_save.get("players", {})
	for p in players.get_children():
		var id := int(str(p.name))
		var key: String = _peer_keys.get(id, "")
		if key.is_empty():
			continue
		saved_players[key] = p.get_save_state() if p == local_player else p.get_remote_save_state()
	_world_save["players"] = saved_players
	_world_save["survival"] = survival.export_save()
	_world_save["mobs"] = mobs.export_save()
	_world_save["changes"] = world.get_changes()
	_world_save["door_facing"] = world.get_door_facing()
	_world_save["world_time"] = day_night.world_time
	var ok := SaveSystem.save_world(_world_file, _world_save)
	print("World saved to %s: %s" % [SaveSystem.folder_path().path_join(_world_file), "ok" if ok else "FAILED"])
	return ok


# --- Network events ------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	# Fires on everyone when someone joins (and on a new client for each existing player).
	_spawn_player(id)
	print("Peer connected: ", id)


func _on_peer_disconnected(id: int) -> void:
	if players.has_node(str(id)):
		var p := players.get_node(str(id))
		if multiplayer.is_server() and _peer_keys.has(id):
			# Remember where they were so they come back to the same spot.
			var saved: Dictionary = _world_save.get("players", {})
			saved[_peer_keys[id]] = p.get_remote_save_state()
			_world_save["players"] = saved
		players.remove_child(p)
		p.queue_free()
	if multiplayer.is_server():
		survival.server_remove_player(id)
	if multiplayer.is_server() and _peer_names.has(id):
		_receive_event.rpc("%s left the game" % _peer_names[id], "")
		_peer_names.erase(id)
		_peer_keys.erase(id)
	_peer_looks.erase(id)
	print("Peer disconnected: ", id)


func _on_connected_to_server() -> void:
	menu.set_busy(true, "Connected! Downloading world...")
	if loading.is_showing():
		loading.set_status("Connected! Downloading the world...")
	_request_world.rpc_id(1, menu.get_player_name(), menu.get_character_id())


func _on_connection_failed() -> void:
	leave_game("Couldn't connect. Check the IP address, that the host is running, and their firewall.")


func _on_server_disconnected() -> void:
	leave_game("Lost connection to the host.")


## Where a character was standing last time (by id, or by name for worlds
## saved before characters existed).
func _position_for(key: String, player_name: String) -> Dictionary:
	var saved: Dictionary = _world_save.get("players", {})
	if saved.has(key):
		return saved[key]
	return saved.get(player_name, {})


## Client -> server: "hi, I'm <name> (character <key>), please send me the world".
@rpc("any_peer", "reliable")
func _request_world(player_name: String, key := "") -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	player_name = Characters.clean_name(player_name)
	key = key.strip_edges().left(40)
	if key.is_empty():
		key = player_name
	if key in _peer_keys.values():
		key = "%s~%d" % [key, id]  # the same character twice at once: keep them apart
	_peer_names[id] = player_name
	_peer_keys[id] = key
	var state: Dictionary = _position_for(key, player_name)
	_receive_world.rpc_id(id, world.world_seed, world.get_changes(), day_night.world_time, dedicated, state, world.get_door_facing(), world.gen_version)
	_send_rules(id)
	survival.server_add_player(id, player_name, key)
	mobs.send_snapshot(id)
	_receive_event.rpc("%s joined the game!" % player_name, "")


## Server -> new client: everything needed to rebuild the world locally.
@rpc("authority", "reliable")
func _receive_world(seed_value: int, changes: Dictionary, world_time: float,
		server_is_dedicated: bool, state: Dictionary, door_facing := {}, gen := 1) -> void:
	_begin_world(seed_value, changes, world_time, door_facing, gen)
	_spawn_player(multiplayer.get_unique_id(), state)
	if server_is_dedicated and players.has_node("1"):
		var host := players.get_node("1")  # a dedicated server has no avatar
		players.remove_child(host)
		host.queue_free()
	print("World received: seed %d, %d edited chunks" % [seed_value, changes.size()])


@rpc("authority", "call_local", "unreliable")
func _sync_time(world_time: float) -> void:
	day_night.world_time = world_time


# --- Chat & commands -------------------------------------------------------------------

func _on_chat_submitted(text: String) -> void:
	if local_player:
		local_player.input_enabled = not hud.is_paused()
	if not text.is_empty():
		_send_chat.rpc_id(1, text)


## Client -> server. The server decides who said it, so names can't be faked.
@rpc("any_peer", "call_local", "reliable")
func _send_chat(text: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	text = text.strip_edges().left(200)
	if text.is_empty():
		return
	if text.begins_with("/"):
		_run_command(id, text)
	else:
		_receive_chat.rpc(_peer_names.get(id, "Player"), text)


## Server -> everyone. sender == "" means a system message.
@rpc("authority", "call_local", "reliable")
func _receive_chat(sender: String, text: String) -> void:
	if not dedicated:
		hud.add_chat(sender, text)
	print("[chat] %s%s" % ["<%s> " % sender if sender != "" else "", text])


## Server -> everyone: news (a boss woke up, someone died, everyone slept...).
## Shown as a card at the top of the screen, not in the chat.
@rpc("authority", "call_local", "reliable")
func _receive_event(text: String, icon := "") -> void:
	if not dedicated:
		hud.show_event(text, icon)
	print("[event] %s" % text)


func _tell(id: int, text: String) -> void:
	_receive_chat.rpc_id(id, "", text)


func _run_command(id: int, text: String) -> void:
	var parts := text.substr(1).split(" ", false)
	var cmd := parts[0].to_lower() if parts.size() > 0 else ""
	var is_host := id == 1 or dedicated
	var is_admin := is_admin_peer(id)
	if is_host and not is_admin and cmd in HOST_COMMANDS:
		_tell(id, "Host commands are turned off for good in this world (so achievements count).")
		return
	match cmd:
		"help":
			_tell(id, "Commands: /players, /seed, /biome, /locate <place>, /time, /weather, /kill, /save, /world." + (" Host only: %s" % HOST_HELP if is_admin else ""))
		"world":
			var r := world_rules()
			_tell(id, "%s  -  PvP: %s  -  Host commands: %s  -  Played %s" % [r["name"], pvp_text(), "allowed" if r["host_commands"] else "off for good", _time_text(float(r["play_time"]))])
		"pvp":
			if not is_host:
				_tell(id, "Only the host can change PvP.")
			elif rules_pvp_mode() != "host":
				_tell(id, "PvP in this world is always %s (picked when the world was made)." % rules_pvp_mode())
			else:
				set_pvp(parts.size() > 1 and parts[1].to_lower() in ["on", "yes", "1", "true"])
		"goto":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				var node: Node3D = players.get_node_or_null(str(id))
				var from := Vector2(node.global_position.x, node.global_position.z) if node else Vector2.ZERO
				var what := parts[1].to_lower() if parts.size() > 1 else ""
				var at := _locate_target(what, from)
				if at.y == -2:
					_tell(id, "Try /goto " + LOCATE_WORDS)
				elif at.y == -1:   # (the Deep can be below y = 0, so only -1 means "not found")
					_tell(id, "Couldn't find one of those nearby.")
				else:
					_teleport.rpc_id(id, at + Vector3(0, 0.1, 0) if what in ["deep", "gems", "lava", "lavacaverns", "caverns"] else _safe_spot(at))
					_tell(id, "Whoosh! You're at the %s." % what)
		"tpto", "bring", "freeze", "unfreeze", "hunt":
			if not is_admin:
				_tell(id, "Only the host can do that.")
				return
			var target := _peer_by_name(parts[1] if parts.size() > 1 else "")
			if target == 0:
				_tell(id, "Who? Online: " + ", ".join(PackedStringArray(_peer_names.values())))
				return
			var tname: String = _peer_names.get(target, "them")
			match cmd:
				"tpto":
					_teleport.rpc_id(id, survival._player_pos(target) + Vector3(1.5, 0.5, 0))
					_tell(id, "You jumped to %s." % tname)
				"bring":
					_teleport.rpc_id(target, survival._player_pos(id) + Vector3(1.5, 0.5, 0))
					_tell(id, "You brought %s to you." % tname)
				"freeze", "unfreeze":
					var on := cmd == "freeze"
					survival.server_set_frozen(target, on)
					_tell(id, "%s is %s." % [tname, "frozen in place" if on else "free to move again"])
				"hunt":
					var tier := clampi(parts[2].to_int() if parts.size() > 2 else 1, 1, 4)
					var n := mobs.send_hunt(target, tier, survival._player_pos(target))
					if n == 0:
						_tell(id, "The hunt couldn't find room to start near %s." % tname)
					else:
						_receive_event.rpc("%s sent %s after %s!" % [_peer_names.get(id, "The host"), HUNT_NAMES[tier - 1], tname], "bone")
		"map_everything", "map_boss", "map_topo":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				var made := survival.server_give_special_map(id, cmd.trim_prefix("map_"))
				_tell(id, made if made != "" else "No room in your pockets for a map.")
		"cheatsheet":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				survival.server_give(id, "cheatsheet", 1)
				_tell(id, "Here's the Host Cheat Sheet. Hover it in your bag to read it.")
		"admin":
			if not is_admin:
				_tell(id, "Only the host can open the admin panel.")
			else:
				_open_admin.rpc_id(id, _peer_names.duplicate())
		"biome":
			var node: Node3D = players.get_node_or_null(str(id))
			if node:
				_tell(id, "You're in the %s." % world.NICE_NAMES.get(world.biome_at(node.global_position.x, node.global_position.z), "wild"))
		"locate":
			var what := parts[1].to_lower() if parts.size() > 1 else ""
			var node: Node3D = players.get_node_or_null(str(id))
			var from := Vector2(node.global_position.x, node.global_position.z) if node else Vector2.ZERO
			var at := _locate_target(what, from)
			if at.y == -2:
				_tell(id, "Try /locate " + LOCATE_WORDS)
				return
			if at.y == -1:
				_tell(id, "Couldn't find that right now.")
			else:
				var d := from.distance_to(Vector2(at.x, at.z))
				_tell(id, "%s is at X %d, Z %d (%d blocks away)." % [what.capitalize(), int(at.x), int(at.z), int(d)])
		"tp":
			if not is_admin or parts.size() < 3 or not parts[1].is_valid_float() or not parts[2].is_valid_float():
				_tell(id, "Usage (host only): /tp <x> <z>")
			else:
				var x := parts[1].to_float()
				var z := parts[2].to_float()
				_teleport.rpc_id(id, Vector3(x, world.surface_height(int(x), int(z)) + 2, z))
		"give":
			if not is_admin:
				_tell(id, "Only the host can give items.")
			elif parts.size() < 2 or not Items.exists(parts[1]):
				_tell(id, "Usage: /give <item> [count]. Items: " + ", ".join(PackedStringArray(Items.ITEMS.keys())))
			else:
				var n := survival.server_give(id, parts[1], parts[2].to_int() if parts.size() > 2 else 1)
				_tell(id, "Gave you %d %s." % [n, Items.display_name(parts[1])])
		"toots":
			if not is_admin or parts.size() < 2 or not parts[1].is_valid_float():
				_tell(id, "Usage (host only): /toots <amount>")
			else:
				survival.server_add_toots(id, parts[1].to_float())
				_tell(id, "Added %s toots." % parts[1])
		"heal":
			if is_admin:
				survival.server_heal(id)
		"unlockall":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				var n := survival.server_unlock_all(id)
				_tell(id, "Unlocked every recipe (%d new). Happy testing!" % n)
		"arena":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				survival.server_give(id, "arena_box", 1)
				_tell(id, "Here's an Arena in a Box! Put it down in a big open space and right-click it.")
		"castle":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				survival.server_give(id, "castle_box", 1)
				_tell(id, "Here's a Castle in a Box! Put it down on open ground and right-click it.")
		"god":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				var on := survival.server_toggle(id, "god")
				if on:
					survival.server_heal(id)
				_tell(id, "God mode %s." % ("ON: nothing can hurt you" if on else "off"))
		"fly", "noclip":
			if not is_admin:
				_tell(id, "Only the host can do that.")
			else:
				var on := survival.server_toggle(id, cmd)
				if cmd == "noclip" and on:
					survival._states[id]["fly"] = true
				if cmd == "fly" and not on:
					survival._states[id]["noclip"] = false
				var st: Dictionary = survival._states[id]
				_set_move_mode.rpc_id(id, st.get("fly", false), st.get("noclip", false))
				if cmd == "fly":
					_tell(id, "Flying %s. (Space = up, Shift = down, Ctrl = fast)" % ("ON" if on else "off"))
				else:
					_tell(id, "No-clip %s. %s" % ["ON" if on else "off", "You fly through walls." if on else "Walls are solid again."])
		"clip":
			if is_admin:
				survival._states[id]["noclip"] = false
				var st: Dictionary = survival._states[id]
				_set_move_mode.rpc_id(id, st.get("fly", false), false)
				_tell(id, "Walls are solid again.")
		"kill":
			survival.damage_player(id, 1000.0, "gave up", Vector3.ZERO)
		"spawn":
			if not is_admin or parts.size() < 2 or not MobData.MOBS.has(parts[1]) or parts[1] in ["qtmame", "fairy"]:
				_tell(id, "Usage (host only): /spawn <%s>" % "|".join(PackedStringArray(MobData.MOBS.keys())))
			else:
				var node: Node3D = players.get_node_or_null(str(id))
				if node:
					var fwd := -node.global_basis.z
					var boss: bool = MobData.get_def(parts[1]).get("boss", false)
					var at := node.global_position + Vector3(fwd.x, 0, fwd.z).normalized() * (8.0 if boss else 4.0) + Vector3(0, 1, 0)
					mobs.spawn_boss(parts[1], at)
		"players":
			_tell(id, "Online: " + ", ".join(PackedStringArray(_peer_names.values())))
		"seed":
			_tell(id, "World seed: %d" % world.world_seed)
		"time":
			if parts.size() < 2:
				_tell(id, "It's %s." % day_night.clock_text())
				return
			if not is_admin:
				_tell(id, "Only the host can change the time.")
				return
			var named := {"day": 7.0, "morning": 7.0, "noon": 12.0, "evening": 18.0,
					"sunset": 18.0, "night": 21.0, "midnight": 0.0}
			var arg := parts[1].to_lower()
			var hour: float
			if named.has(arg):
				hour = named[arg]
			elif arg.is_valid_float():
				hour = clampf(arg.to_float(), 0.0, 24.0)
			else:
				_tell(id, "Try /time day, /time night or /time 13")
				return
			day_night.set_time_of_day(hour / 24.0)
			_sync_time.rpc(day_night.world_time)
			_receive_event.rpc("%s set the time to %s" % [_peer_names.get(id, "Server"), day_night.clock_text()], "torch")
		"weather":
			if parts.size() < 2:
				_tell(id, "The weather is %s." % weather.kind)
				return
			if not is_admin:
				_tell(id, "Only the host can change the weather.")
				return
			var w := parts[1].to_lower()
			if w == "snow":
				w = "storm"
			if not w in Weather.KINDS:
				_tell(id, "Try /weather clear, cloudy, rain or storm")
				return
			weather.choose(w)
			_receive_event.rpc("%s changed the weather to %s" % [_peer_names.get(id, "Server"), w], "water_bucket")
		"save":
			if not is_host:
				_tell(id, "Only the host can save.")
			elif _world_file.is_empty():
				_tell(id, "Nothing to save.")
			else:
				_tell(id, "World saved." if save_world() else "Saving FAILED. Check the Output panel.")
		_:
			_tell(id, "Unknown command /%s. Try /help" % cmd)


## Where something is, for /locate, /goto and the admin panel: a boss lair,
## a place, a biome... (y < 0: not found; y = -2: not something we know).
func _locate_target(what: String, from: Vector2) -> Vector3:
	var at := Vector3(0, -1, 0)
	match what:
		"qtmame":
			var npc := mobs.get_npc()
			at = npc.sim_pos if npc else mobs.npc_home()
		"king":
			var king: Node3D = mobs.get_mob(mobs._king_id)
			if king:
				at = king.sim_pos
		"yeti", "mineshaft":
			at = world.find_structure("mineshaft", from)
		"castle", "grimskull":
			at = world.find_castle(from)
		"village", "fairies":
			at = world.find_structure("village", from)
		"camp", "villagers", "traders":
			var cp: Dictionary = world.find_camp(from)
			if not cp.is_empty():
				at = Vector3(cp["center"].x + 2, cp["ground"] + 1, cp["center"].y + 1)   # (beside the lamp post in the middle)
		"shrine":
			at = world.find_shrine(from)
		"deep", "gems":
			at = world.find_deep(from)
		"lava", "lavacaverns", "caverns":
			at = world.find_lava_cavern(from)
		"giant", "firegiant", "fire_giant":
			var fl: Dictionary = world.find_lair("fire_giant", from, 6000.0)
			if not fl.is_empty():
				at = Vector3(fl["pos"].x + 0.5, fl["pos"].y, fl["pos"].z + 6.5)
		"boar_king", "boarking", "oakheart", "gummy_giant", "gummy", "scarecrow_king", "scarecrow", "lantern_witch", "witch", "temple", "queen", "royals", "chesscastle", "clown", "circus":
			var key: String = {"boarking": "boar_king", "gummy": "gummy_giant", "scarecrow": "scarecrow_king", "witch": "lantern_witch", "temple": "king_cougar",
					"queen": "chess_royals", "royals": "chess_royals", "chesscastle": "chess_royals", "circus": "clown"}.get(what, what)
			var lair: Dictionary = world.find_lair(key, from)
			if not lair.is_empty():
				at = Vector3(lair["pos"].x, lair["ground"] + 1, lair["pos"].z)
		"dungeon", "grotto":
			var site: Dictionary = world.find_site(what, from)
			if not site.is_empty():
				at = Vector3(site["entrance"])
		"desert", "candy", "plains", "meadows", "forest", "mountain", "mountains", "fall", "autumn", "spooky", "halloween", "sky", "islands", "chess", "chessboard", "fastfood", "food":
			var b: String = {"meadows": "plains", "mountains": "mountain", "autumn": "fall", "halloween": "spooky", "islands": "sky", "chessboard": "chess", "food": "fastfood"}.get(what, what)
			at = world.find_biome(b, from)
		_:
			return Vector3(0, -2, 0)
	return at


## Commands that need host powers (turned off for good if the world says so).
const HOST_COMMANDS := ["arena", "give", "toots", "heal", "spawn", "tp", "goto", "tpto", "bring", "freeze", "unfreeze", "hunt", "unlockall",
		"castle", "god", "fly", "noclip", "clip", "map_everything", "map_boss", "map_topo", "cheatsheet", "admin", "time", "weather"]
const HOST_HELP := "/give <item> [count], /toots <amount>, /heal, /spawn <mob>, /tp <x> <z>, /goto <place>, /tpto <player>, /bring <player>, /freeze <player>, /unfreeze <player>, /hunt <player> <1-4>, /unlockall, /castle, /arena, /god, /fly, /noclip, /clip, /map_everything, /map_boss, /map_topo, /cheatsheet, /admin, /pvp on|off"
const HUNT_NAMES := ["a pack of cats and dogs", "a sleuth of bears", "cave trolls and gremlins", "a BOSS"]

var admins := {}   # character keys allowed to use host commands besides the host (for later)


## Can this player use host commands right now?
func is_admin_peer(id: int) -> bool:
	if not world_rules()["host_commands"]:
		return false
	return id == 1 or dedicated or admins.has(_peer_keys.get(id, "?"))


func _peer_by_name(n: String) -> int:
	n = n.strip_edges().to_lower()
	if n == "":
		return 0
	for p in _peer_names:
		if str(_peer_names[p]).to_lower() == n:
			return p
	for p in _peer_names:
		if str(_peer_names[p]).to_lower().begins_with(n):
			return p
	return 0


## Somewhere safe to stand at or above a spot (the top of the ground there).
func _safe_spot(at: Vector3) -> Vector3:
	if at.y < 0:
		return Vector3(floori(at.x) + 0.5, at.y + 0.1, floori(at.z) + 0.5)   # down in the Deep: right there
	var top: int = world.surface_height(floori(at.x), floori(at.z))
	var y := top + 1.2 if at.y <= top + 2 else at.y + 1.0   # (castles on floating islands are up high)
	return Vector3(floori(at.x) + 0.5, y, floori(at.z) + 0.5)


# --- World rules ----------------------------------------------------------------------
# Picked when the world is made, saved with it, and shown in the pause menu:
#   pvp: "off", "on", or "host" (the host flips it on and off while playing)
#   host_commands: false = turned off for good (it can never be turned back on;
#     achievements will only count in worlds like that)

var _rules := {}          # client copy (the server's copy lives in _world_save)


func world_rules() -> Dictionary:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _world_save.is_empty():
		return {"name": _world_save.get("name", "World"), "seed": _world_save.get("seed", 0), "gen": _world_save.get("gen", 1),
				"created": _world_save.get("created", 0), "play_time": float(_world_save.get("play_time", 0.0)),
				"pvp": str(_world_save.get("pvp", "off")), "pvp_on": bool(_world_save.get("pvp_on", false)),
				"host_commands": bool(_world_save.get("host_commands", true))}
	var r := {"name": "World", "seed": 0, "gen": 1, "created": 0, "play_time": 0.0, "pvp": "off", "pvp_on": false, "host_commands": true}
	r.merge(_rules, true)
	return r


func rules_pvp_mode() -> String:
	return str(world_rules()["pvp"])


## Can players hurt each other right now?
func pvp_active() -> bool:
	var r := world_rules()
	return r["pvp"] == "on" or (r["pvp"] == "host" and r["pvp_on"])


func pvp_text() -> String:
	match rules_pvp_mode():
		"on":
			return "always on"
		"host":
			return "ON (the host decides)" if pvp_active() else "off (the host decides)"
	return "off"


static func _time_text(secs: float) -> String:
	var m := int(secs / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%d min" % m


## Server: the host flips PvP (only in "host decides" worlds).
func set_pvp(on: bool) -> void:
	if not multiplayer.is_server() or rules_pvp_mode() != "host":
		return
	_world_save["pvp_on"] = on
	_send_rules()
	_receive_event.rpc("PvP is now %s!" % ("ON: players can hit each other" if on else "OFF"), "iron_sword" if on else "")


## Server: turn host commands off for good.
func lock_host_commands() -> void:
	if not multiplayer.is_server() or not world_rules()["host_commands"]:
		return
	_world_save["host_commands"] = false
	for p in survival._states:
		var st: Dictionary = survival._states[p]
		for flag in ["god", "fly", "noclip", "frozen"]:
			st[flag] = false
		_set_move_mode.rpc_id(p, false, false)
		survival.server_set_frozen(p, false)
	_send_rules()
	save_world()
	_receive_event.rpc("Host commands are now OFF for good in this world. Achievements count from here on!", "trophy_yeti")


func _send_rules(to := 0) -> void:
	var r := world_rules()
	if to != 0:
		_receive_rules.rpc_id(to, r)
	elif multiplayer.has_multiplayer_peer():
		_receive_rules.rpc(r)


@rpc("authority", "call_local", "reliable")
func _receive_rules(r: Dictionary) -> void:
	_rules = r
	if hud:
		hud.set_world_info(r, pvp_active(), multiplayer.is_server())


## Client -> server: the host's buttons in the World panel.
@rpc("any_peer", "call_local", "reliable")
func req_set_pvp(on: bool) -> void:
	if multiplayer.is_server() and _sender_id() == 1:
		set_pvp(on)


@rpc("any_peer", "call_local", "reliable")
func req_lock_commands() -> void:
	if multiplayer.is_server() and _sender_id() == 1:
		lock_host_commands()


func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return 1 if id == 0 else id


## Server -> admin: open the admin panel (with who's online).
@rpc("authority", "call_local", "reliable")
func _open_admin(online: Dictionary) -> void:
	if dedicated or admin_ui == null:
		return
	_open_window()
	admin_ui.open(online, multiplayer.get_unique_id())


## Admin panel buttons just send commands, so they follow the same rules.
func run_admin(command: String) -> void:
	_send_chat.rpc_id(1, command)


## Server -> one player: you are (or aren't) frozen in place.
@rpc("authority", "call_local", "reliable")
func _set_frozen(on: bool) -> void:
	if local_player:
		local_player.frozen = on
	if on and hud:
		hud.show_notice("You're frozen in place by the host!")


## The words /locate and /goto understand.
const LOCATE_WORDS := "camp, deep, lava, giant, desert, candy, forest, fall, spooky, sky, chess, food, castle, mountain, mineshaft, village, shrine, dungeon, grotto, boarking, oakheart, gummy, scarecrow, witch, temple, queen, clown, qtmame or king"


# --- Pause / chat keys / mouse -----------------------------------------------------------

## (Host commands) fly and no-clip for this computer's player.
@rpc("authority", "call_local", "reliable")
func _set_move_mode(fly: bool, noclip: bool) -> void:
	if local_player:
		local_player.fly_mode = fly or noclip
		local_player.noclip_mode = noclip


@rpc("authority", "call_local", "reliable")
func _teleport(pos: Vector3) -> void:
	if local_player:
		local_player.respawn(pos)


func _unhandled_input(event: InputEvent) -> void:
	if not in_game or dedicated or hud.is_chat_open() or inventory_ui.is_open() or hud.is_dead_screen() \
			or hud.is_sleeping_screen() or settings_ui.is_open() or map_ui.is_open() or portal_ui.is_open() or party_ui.is_open() or admin_ui.is_open():
		return
	if event.is_action_pressed("inventory") and not hud.is_paused():
		get_viewport().set_input_as_handled()
		_open_window()
		inventory_ui.open_craft(0, Survival.NO_POS)
		return
	if event.is_action_pressed("power") and not hud.is_paused():
		get_viewport().set_input_as_handled()
		survival.req_use_power.rpc_id(1)
		return
	if event.is_action_pressed("party") and not hud.is_paused():
		get_viewport().set_input_as_handled()
		open_party()
		return
	if event.is_action_pressed("map") and not hud.is_paused():
		get_viewport().set_input_as_handled()
		_open_map(-1)
		return
	if event.is_action_pressed("pause"):
		if hud.is_paused():
			_resume()
		else:
			hud.set_paused(true)
			if local_player:
				local_player.input_enabled = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif hud.is_paused():
		return
	elif event.is_action_pressed("chat") or event.is_action_pressed("command"):
		get_viewport().set_input_as_handled()
		if local_player:
			local_player.input_enabled = false
		hud.open_chat("/" if event.is_action_pressed("command") else "")
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # click to grab the mouse again


# --- Survival windows & death -------------------------------------------------------

func open_party() -> void:
	_open_window()
	party_ui.local_player = local_player
	party_ui.open()


## Party members' names show from up to 200 blocks away (checked twice a second).
func _update_name_tags() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	for p in players.get_children():
		if p == local_player or not p.has_method("set_party_tag"):
			continue
		var peer := int(str(p.name))
		p.set_party_tag(survival.in_my_party(peer), p.global_position.distance_to(local_player.global_position))


func _open_window() -> void:
	if local_player:
		local_player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_window_closed() -> void:
	if local_player and not hud.is_paused():
		local_player.input_enabled = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_interact_block(block: int, pos: Vector3i) -> void:
	_open_window()
	if Blocks.WORKBENCH_TIER.has(block):
		inventory_ui.open_craft(Blocks.WORKBENCH_TIER[block], pos)
	elif Blocks.BUILD_BENCH.has(block):
		inventory_ui.open_build(Blocks.BUILD_BENCH[block], pos)
	elif block == Blocks.CUTE_CRAFTER:
		inventory_ui.open_cute(pos)
	elif block == Blocks.SCRIBE:
		inventory_ui.open_scribe(pos)
	elif block == Blocks.RESEARCH_TABLE:
		inventory_ui.open_research(pos)
	elif block == Blocks.ARMOR_STAND:
		survival.req_open.rpc_id(1, "stand", pos)
		inventory_ui.open_container("stand")
	elif block == Blocks.BOSS_STATUE:
		_on_window_closed()
		survival.req_statue.rpc_id(1, pos, local_player.hotbar_index if local_player else 0)
	elif block == Blocks.ITEM_FRAME:
		_on_window_closed()
		survival.req_frame.rpc_id(1, pos, local_player.hotbar_index if local_player else 0)
	elif block == Blocks.PORTAL or block == Blocks.PORTAL_LIT:
		var pid: int = survival.client_portal_at(pos)
		if pid == 0:
			_on_window_closed()
		else:
			portal_ui.open(pid, local_player.display_name if local_player else "")
	elif block == Blocks.SHOP:
		inventory_ui.open_shop(pos)
	elif block == Blocks.FURNACE:
		survival.req_open.rpc_id(1, "furnace", pos)
		inventory_ui.open_container("furnace")
	elif block == Blocks.CHEST or block == Blocks.SHRINE_CHEST or block == Blocks.SUPER_CHEST:
		survival.req_open.rpc_id(1, "chest", pos)
		inventory_ui.open_container("chest")
	else:
		_on_window_closed()  # doors and beds don't open a window
		survival.req_use_block.rpc_id(1, pos)


## Open the map in this slot (-1 = the first one you carry; held one first).
func _open_map(slot: int) -> void:
	if slot < 0:
		var order := [local_player.hotbar_index] if local_player else []
		for i in Inv.PLAYER_SLOTS:
			order.append(i)
		for i in order:
			if Items.is_map(survival.my_slot(i).get("id", "")):
				slot = i
				break
	if slot < 0:
		hud.show_notice("You need a Map! Make one out of Paper at a Workbench Tier 2.")
		return
	_open_window()
	map_ui.open(slot)


func _on_interact_villager(mob_id: int) -> void:
	_open_window()
	survival.villager_shop = {}
	survival.req_villager.rpc_id(1, mob_id)
	inventory_ui.open_villager(mob_id)


func _on_interact_npc() -> void:
	_open_window()
	survival.req_meet_npc.rpc_id(1)
	inventory_ui.open_trader()


## A trade started (someone said yes): pop the window open.
func _on_container_changed() -> void:
	if survival.open_kind == "trade" and (not inventory_ui.is_open() or inventory_ui.mode != "trade"):
		_open_window()
		inventory_ui.open_container("trade")


func _on_sleep_changed(on: bool, bed: Vector3i) -> void:
	if local_player == null:
		return
	if on:
		inventory_ui.close()
		map_ui.close()
		portal_ui.close()
		party_ui.close()
		local_player.sleep_in(bed)
		local_player.input_enabled = false
		hud.show_sleep(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		local_player.wake_up()
		hud.show_sleep(false)
		if not day_night.is_night():
			Sound.play("morning", -4.0, 1.0, "Interface")
		if not hud.is_dead_screen() and not inventory_ui.is_open():
			local_player.input_enabled = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_interact_loot(id: int) -> void:
	_open_window()
	survival.req_open.rpc_id(1, "loot", id)
	inventory_ui.open_container("loot")


func _on_died(cause: String) -> void:
	Sound.play("death", -2.0)
	inventory_ui.close()
	map_ui.close()
	portal_ui.close()
	party_ui.close()
	hud.show_sleep(false)
	hud.close_chat()
	hud.set_paused(false)
	hud.show_death(cause)
	if local_player:
		local_player.alive = false
		local_player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_respawned(pos: Vector3) -> void:
	hud.hide_death()
	if local_player:
		local_player.alive = true
		local_player.input_enabled = true
		local_player.respawn(pos)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _resume() -> void:
	hud.set_paused(false)
	if local_player:
		local_player.input_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
