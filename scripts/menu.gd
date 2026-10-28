extends CanvasLayer
## Main menu. Behind everything is a 3D KianCraft logo built from game blocks
## (a different style each time the game starts), which drops into place as
## an intro. In front:
##   Home:   Play, Join a friend, Characters, Settings, Quit, and a card
##           showing who you're playing as.
##   Worlds: your worlds (play, play with friends, delete) and a new world.
##   Join:   a friend's address.

const SaveSystem = preload("res://scripts/save_system.gd")
const DayNight = preload("res://scripts/day_night.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Items = preload("res://scripts/items.gd")
const Settings = preload("res://scripts/settings.gd")
const Characters = preload("res://scripts/characters.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Logo = preload("res://scripts/logo.gd")
const Backdrop = preload("res://scripts/menu_backdrop.gd")

signal play_requested(file: String, host: bool)
signal join_requested(address: String, port: int)
signal quit_requested
signal settings_requested
signal characters_requested

const DEFAULT_PORT := 7777
const VERSION := "v1.6"
const TIPS := [
	"Tip: right-click a bed to set where you wake up.",
	"Tip: maps fill in wherever you carry them.",
	"Tip: some caves hide a little shrine with a treasure map inside!",
	"Tip: a Scribe Desk lets you write a name on your gear.",
	"Tip: two portals with the same name are linked.",
	"Tip: hang maps in item frames to show them on a wall.",
	"Tip: coal comes out of the furnace when you burn wood.",
	"Tip: candy land hides Cutie ore under the frosting.",
	"Tip: press F11 for full screen.",
]

var logo: Logo
var backdrop: Backdrop
var _back_view: SubViewport
var _back_fade: ColorRect
var _place_label: Label
var _screens: Control
var _shrink := 0.0               # 0 = big logo (home), 1 = small logo at the top (other screens)
var _shrink_want := 0.0
var _view: SubViewport
var _cam: Camera3D
var _env: Environment
var _ui: Control                 # everything in front of the logo
var _home: Control
var _worlds: Control
var _join: Control
var _char_label: Label
var _char_holder: Node3D
var _char_view: SubViewport
var _world_list: ItemList
var _world_info: Label
var _new_name_edit: LineEdit
var _seed_edit: LineEdit
var _address_edit: LineEdit
var _port_edit: LineEdit
var _status: Label
var _tip: Label
var _buttons: Array[Button] = []
var _world_files: Array[String] = []
var _world_data: Array[Dictionary] = []
var _delete_dialog: ConfirmationDialog
var _time := 0.0
var _intro := false
var _fade := 1.0
var _tip_timer := 0.0


func _ready() -> void:
	layer = 10
	_build_scene()
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	# Dark edges all round (a vignette), so the menu feels framed.
	var vig := TextureRect.new()
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0))
	vg.set_color(1, Color(0.01, 0.0, 0.02, 0.78))
	vg.set_offset(0, 0.45)
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.42)
	vt.fill_to = Vector2(1.15, 1.0)
	vt.width = 256
	vt.height = 144
	vig.texture = vt
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(vig)
	# A dark band at the bottom so the buttons read well over any sky.
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.04, 0.07, 0.0))
	grad.set_color(1, Color(0.02, 0.01, 0.03, 0.9))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.25)
	gt.fill_to = Vector2(0, 0.75)
	gt.width = 4
	gt.height = 128
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(shade)

	var screens := Control.new()
	screens.set_anchors_preset(Control.PRESET_FULL_RECT)
	screens.anchor_top = 0.42
	screens.offset_bottom = -54
	screens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(screens)
	_screens = screens
	_home = _build_home()
	_worlds = _build_worlds()
	_join = _build_join()
	for s in [_home, _worlds, _join]:
		screens.add_child(s)

	# Footer: tips on the left, status in the middle, version on the right.
	var footer := HBoxContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -46
	footer.offset_left = 24
	footer.offset_right = -24
	footer.offset_bottom = -12
	footer.add_theme_constant_override("separation", 16)
	_ui.add_child(footer)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 0)
	_place_label = UI.make_title(UI.label("", 14))
	left.add_child(_place_label)
	_tip = UI.label(TIPS[randi() % TIPS.size()], 14, UI.TEXT_SOFT)
	left.add_child(_tip)
	footer.add_child(left)
	_status = UI.label("", 16, UI.GOLD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	var ver := UI.label("KianCraft %s" % VERSION, 14, UI.TEXT_SOFT)
	ver.custom_minimum_size = Vector2(380, 0)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(ver)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete world?"
	_delete_dialog.ok_button_text = "Delete forever"
	_delete_dialog.confirmed.connect(_delete_selected)
	add_child(_delete_dialog)

	refresh_character()
	refresh_worlds()
	show_screen("home")
	if DisplayServer.get_name() != "headless":
		play_intro()
		backdrop.start()
	backdrop.place_changed.connect(func(c: String) -> void: _place_label.text = c)


# --- The 3D logo scene ------------------------------------------------------------------

## The backdrop's edge smoothing follows the graphics settings (like the game).
func _back_aa() -> void:
	if _back_view == null or not is_instance_valid(self):
		return
	_back_view.msaa_3d = Settings.msaa()
	_back_view.use_taa = int(Settings.gfx["aa"]) == 2 and Settings.modern()
	if Settings.modern():
		_back_view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if int(Settings.gfx["aa"]) == 1 else Viewport.SCREEN_SPACE_AA_DISABLED


func _build_scene() -> void:
	# Behind everything: real places from a world (see menu_backdrop.gd).
	var back := SubViewportContainer.new()
	back.stretch = true
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_back_view = SubViewport.new()
	_back_view.own_world_3d = true
	_back_aa()
	Settings.on_changed(_back_aa)
	back.add_child(_back_view)
	_back_fade = ColorRect.new()
	_back_fade.color = Color(0.03, 0.04, 0.07, 1.0)
	_back_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back_fade)
	backdrop = Backdrop.new()
	_back_view.add_child(backdrop)
	backdrop.setup(_back_fade)
	visibility_changed.connect(_on_visibility)
	# The logo, in its own see-through view on top.
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	holder.add_child(_view)
	logo = Logo.new()
	logo.with_ground = false
	logo.build()
	_view.add_child(logo)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = logo.sky_top
	sky_mat.sky_horizon_color = logo.sky_bottom
	sky_mat.ground_horizon_color = logo.sky_bottom
	sky_mat.ground_bottom_color = logo.sky_bottom.darkened(0.3)
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR   # see-through: the world shows behind
	_env.sky = sky
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	_view.add_child(we)
	_add_shadow_under_logo()
	_cam = Camera3D.new()
	_cam.fov = 38
	_view.add_child(_cam)
	_place_camera()


## A soft dark glow behind the letters so they read on any background.
func _add_shadow_under_logo() -> void:
	var s := Sprite3D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 64
	s.texture = t
	s.pixel_size = (logo.width + 16.0) / 128.0
	s.position = logo.center() + Vector3(0, -0.5, -1.5)
	s.shaded = false
	s.transparent = true
	_view.add_child(s)


## (Old: clouds over the logo's own sky. Not used now a real world is behind it.)
func _add_clouds() -> void:
	if logo.theme in ["spooky", "portal"]:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(logo.theme)
	for i in 7:
		var c := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(rng.randf_range(8, 16), 1.2, rng.randf_range(4, 8))
		c.mesh = m
		c.material_override = mat
		c.position = Vector3(rng.randf_range(-30, logo.width + 30), rng.randf_range(16, 22), rng.randf_range(-40, -10))
		c.set_meta("cloud", true)
		_view.add_child(c)


func _place_camera() -> void:
	var c := logo.center()
	var sway := sin(_time * 0.25) * 4.0 * (1.0 - _shrink)
	# Home: big, in the upper part of the screen. Other screens: pulled back
	# so it's small and right at the top, out of the way of the window.
	var dist := lerpf(62.0, 120.0, _shrink)
	var drop := lerpf(14.0, 38.0, _shrink)
	_cam.position = Vector3(c.x + sway, c.y - 9.0, dist)
	_cam.look_at(Vector3(c.x, c.y - drop, 0), Vector3.UP)
	_cam.position.y += 6.0


func _on_visibility() -> void:
	if not is_inside_tree():
		return
	if visible and DisplayServer.get_name() != "headless":
		backdrop.start()
	elif not visible:
		backdrop.stop()   # free the menu's world while you play


## Starts the scenes behind the menu (the menu does this itself, except in tests).
func start_backdrop() -> void:
	backdrop.start()


func play_intro() -> void:
	_intro = true
	_fade = 0.0
	_ui.modulate.a = 0.0
	logo.play_intro()


func _skip_intro() -> void:
	logo.finish()
	_intro = false


func is_intro_playing() -> bool:
	return _intro


func _input(event: InputEvent) -> void:
	if _intro and visible and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_skip_intro()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if _char_view:
		_char_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible and _home.visible else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	_time += delta
	_shrink = move_toward(_shrink, _shrink_want, delta * 3.0)
	_screens.anchor_top = lerpf(0.42, 0.16, _shrink)
	_place_camera()
	for c in _view.get_children():
		if c is MeshInstance3D and c.has_meta("cloud"):
			c.position.x += delta * 0.8
			if c.position.x > logo.width + 40:
				c.position.x = -40
	if _intro and not logo.is_playing():
		_intro = false
	if not _intro and _fade < 1.0:
		_fade = minf(1.0, _fade + delta * 2.5)
		_ui.modulate.a = _fade
	if _char_holder and _char_holder.get_child_count() > 0:
		_char_holder.get_child(0).rotation.y = sin(_time * 0.8) * 0.5
	_tip_timer += delta
	if _tip_timer > 9.0:
		_tip_timer = 0.0
		_tip.text = TIPS[randi() % TIPS.size()]


# --- Screens ---------------------------------------------------------------------------

func show_screen(which: String) -> void:
	_home.visible = which == "home"
	_worlds.visible = which == "worlds"
	_join.visible = which == "join"
	_shrink_want = 0.0 if which == "home" else 1.0
	if which == "worlds":
		refresh_worlds(_selected_file())


func current_screen() -> String:
	return "worlds" if _worlds.visible else ("join" if _join.visible else "home")


func _centered() -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_home() -> Control:
	var root := _centered()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	root.add_child(row)
	var col_panel := PanelContainer.new()
	row.add_child(col_panel)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(340, 0)
	col.add_theme_constant_override("separation", 10)
	col_panel.add_child(col)
	var play := _button(col, "Play", func() -> void: show_screen("worlds"), "GreenButton", 26)
	play.custom_minimum_size = Vector2(0, 64)
	_button(col, "Join a friend", func() -> void: show_screen("join"), "BlueButton", 20)
	_button(col, "Characters", func() -> void: characters_requested.emit(), "Button", 20)
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 10)
	_button(small, "Settings", func() -> void: settings_requested.emit(), "Button", 18)
	_button(small, "Quit", func() -> void: quit_requested.emit(), "Button", 18)
	col.add_child(small)

	# Who you're playing as.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 0)
	row.add_child(card)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 4)
	card.add_child(cbox)
	var you := UI.make_title(UI.label("Playing As", 15))
	you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(you)
	_char_label = UI.label("", 20)
	_char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cbox.add_child(_char_label)
	var pv := SubViewportContainer.new()
	pv.stretch = true
	pv.custom_minimum_size = Vector2(220, 190)
	_char_view = SubViewport.new()
	_char_view.own_world_3d = true
	_char_view.transparent_bg = true
	_char_view.msaa_3d = Viewport.MSAA_4X
	pv.add_child(_char_view)
	var cam := Camera3D.new()
	cam.fov = 30
	_char_view.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.25, -3.6), Vector3(0, 1.0, 0))   # in front of them (faces look toward -Z)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, PI + 0.5, 0)
	_char_view.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.environment.ambient_light_energy = 0.75
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_char_view.add_child(env)
	_char_holder = Node3D.new()
	_char_view.add_child(_char_holder)
	cbox.add_child(pv)
	var change := UI.button("Change character", "Button", 15)
	change.custom_minimum_size = Vector2(0, 38)
	change.pressed.connect(func() -> void: characters_requested.emit())
	cbox.add_child(change)
	return root


func _window(title: String, width: float) -> Array:
	var root := _centered()
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var t := UI.make_title(UI.label(title, 28))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var back := UI.button("Back", "FlatButton", 16)
	back.pressed.connect(func() -> void: show_screen("home"))
	head.add_child(back)
	box.add_child(head)
	box.add_child(UI.accent_line())
	return [root, box]


func _build_worlds() -> Control:
	var w := _window("Your worlds", 760)
	var box: VBoxContainer = w[1]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	_world_list = ItemList.new()
	_world_list.custom_minimum_size = Vector2(430, 140)
	_world_list.add_theme_font_size_override("font_size", 18)
	_world_list.fixed_icon_size = Vector2i(32, 32)
	_world_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world_list.item_activated.connect(func(_i: int) -> void: _play_selected(false))
	_world_list.item_selected.connect(func(_i: int) -> void: _show_world_info())
	row.add_child(_world_list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	var info_card := PanelContainer.new()
	info_card.theme_type_variation = "CardPanel"
	info_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_world_info = UI.label("", 15, UI.TEXT_SOFT)
	_world_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_card.add_child(_world_info)
	side.add_child(info_card)
	_button(side, "Play", func() -> void: _play_selected(false), "GreenButton", 22)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	side.add_child(row2)
	_button(row2, "Play with friends", func() -> void: _play_selected(true), "BlueButton", 17)
	var del := _button(row2, "Delete", _ask_delete, "RedButton", 15, false)
	del.custom_minimum_size = Vector2(90, 46)

	box.add_child(UI.label("NEW WORLD", 13, UI.GOLD))
	var new_row := HBoxContainer.new()
	new_row.add_theme_constant_override("separation", 8)
	_new_name_edit = LineEdit.new()
	_new_name_edit.placeholder_text = "World name"
	_new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_name_edit.text_submitted.connect(func(_t: String) -> void: _create_world())
	new_row.add_child(_new_name_edit)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "Seed (optional)"
	_seed_edit.custom_minimum_size = Vector2(130, 0)
	new_row.add_child(_seed_edit)
	# World rules for the new world (they're saved with it).
	var rules_row := new_row
	_pvp_button = _button(rules_row, "", func() -> void:
		new_pvp = PVP_MODES[(PVP_MODES.find(new_pvp) + 1) % PVP_MODES.size()]
		_update_rule_buttons(), "Button", 15)
	_pvp_button.tooltip_text = "Can players hit each other? Off, On, or the host turns it on and off while playing."
	_cmd_button = _button(rules_row, "", func() -> void:
		new_host_commands = not new_host_commands
		_update_rule_buttons(), "Button", 15)
	_cmd_button.tooltip_text = "Host commands (/give, /fly, /god...). Turn them off for good to earn achievements in this world (you can't turn them back on)."
	_pvp_button.size_flags_horizontal = Control.SIZE_FILL
	_cmd_button.size_flags_horizontal = Control.SIZE_FILL
	_button(new_row, "Create", _create_world, "GreenButton", 18, false)
	box.add_child(new_row)
	_update_rule_buttons()
	return w[0]


const PVP_MODES := ["off", "on", "host"]
const PVP_NAMES := {"off": "PvP: Off", "on": "PvP: On", "host": "PvP: Host decides"}
var new_pvp := "off"
var new_host_commands := true
var _pvp_button: Button
var _cmd_button: Button


func _update_rule_buttons() -> void:
	_pvp_button.text = PVP_NAMES[new_pvp]
	_cmd_button.text = "Host commands: On" if new_host_commands else "Host commands: Off forever"


func _build_join() -> Control:
	var w := _window("Join a friend", 520)
	var box: VBoxContainer = w[1]
	var help := UI.label("Your friend picks a world and presses \"Play with friends\". Their address is on their pause screen.", 15, UI.TEXT_SOFT)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(500, 0)
	box.add_child(help)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_address_edit = LineEdit.new()
	_address_edit.placeholder_text = "Host address (like 192.168.1.20)"
	_address_edit.text = "127.0.0.1"
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address_edit)
	_port_edit = LineEdit.new()
	_port_edit.text = str(DEFAULT_PORT)
	_port_edit.custom_minimum_size = Vector2(80, 0)
	join_row.add_child(_port_edit)
	box.add_child(join_row)
	_button(box, "Join", func() -> void: join_requested.emit(_address_edit.text.strip_edges(), get_port()), "BlueButton", 22)
	return w[0]


func _button(parent: Control, text: String, callback: Callable, variation := "Button", size := 20, expand := true) -> Button:
	var b := UI.button(text, variation, size)
	b.custom_minimum_size = Vector2(0, 46)
	if parent is HBoxContainer and expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(callback)
	parent.add_child(b)
	_buttons.append(b)
	return b


# --- Worlds ------------------------------------------------------------------------------

func refresh_worlds(select_file := "") -> void:
	_world_list.clear()
	_world_files.clear()
	_world_data.clear()
	for w in SaveSystem.list_worlds():
		_world_list.add_item("  " + str(w["name"]), _grass_icon())
		_world_files.append(w["file"])
		_world_data.append(w)
	if _world_files.is_empty():
		_world_list.add_item("No worlds yet. Make one below!")
		_world_list.set_item_disabled(0, true)
		_show_world_info()
		return
	var idx := maxi(_world_files.find(select_file), 0)
	_world_list.select(idx)
	_show_world_info()


func _show_world_info() -> void:
	var sel := _world_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _world_data.size():
		_world_info.text = "Make a new world below: give it a name and press Create."
		return
	var w: Dictionary = _world_data[sel[0]]
	var when := "never"
	if int(w.get("last_played", 0)) > 0:
		when = Time.get_datetime_string_from_unix_time(int(w["last_played"]), true).substr(0, 16)
	var gen: int = int(w.get("gen", 1))
	var kind := "Newest world: has cave shrines and treasure maps." if gen >= 7 else "Older world: it stays just as it was made."
	var pvp: String = {"off": "Off", "on": "On", "host": "Host decides"}.get(str(w.get("pvp", "off")), "Off")
	var cmds := "On" if w.get("host_commands", true) else "Off for good"
	_world_info.text = "%s\nLast played: %s\nSeed: %s\nPvP: %s  ·  Host commands: %s\n%s" % [w["name"], when, str(w.get("seed", "")), pvp, cmds, kind]


func _grass_icon() -> Texture2D:
	var t := AtlasTexture.new()
	t.atlas = preload("res://scripts/blocks.gd").get_atlas()
	t.region = preload("res://scripts/blocks.gd").tile_region(preload("res://scripts/blocks.gd").T_GRASS_SIDE)
	return t


func _selected_file() -> String:
	var sel := _world_list.get_selected_items()
	if sel.is_empty() or sel[0] >= _world_files.size():
		return ""
	return _world_files[sel[0]]


func _play_selected(host: bool) -> void:
	if not has_character():
		characters_requested.emit()
		return
	var file := _selected_file()
	if file.is_empty():
		set_status("Pick a world first, or create a new one.")
		return
	play_requested.emit(file, host)


func _create_world() -> void:
	var world_name := _new_name_edit.text.strip_edges()
	if world_name.is_empty():
		world_name = "New World"
	var seed_text := _seed_edit.text.strip_edges()
	var seed_value: int
	if seed_text.is_empty():
		seed_value = randi()
	elif seed_text.is_valid_int():
		seed_value = seed_text.to_int()
	else:
		seed_value = hash(seed_text)  # any word works as a seed too
	var file := create_world_file(world_name, seed_value, new_pvp, new_host_commands)
	if file.is_empty():
		set_status("Couldn't create the world file. See the Output panel for details.")
		return
	_new_name_edit.text = ""
	_seed_edit.text = ""
	refresh_worlds(file)
	set_status("Created \"%s\". Press Play!" % world_name)


static func create_world_file(world_name: String, seed_value: int, pvp := "off", host_commands := true) -> String:
	var file := SaveSystem.new_file_name(world_name)
	var ok := SaveSystem.save_world(file, {
		"name": world_name,
		"seed": seed_value,
		"changes": {},
		"world_time": DayNight.NEW_WORLD_TIME * DayNight.DAY_LENGTH,
		"players": {},
		"created": int(Time.get_unix_time_from_system()),
		"pvp": pvp,
		"host_commands": host_commands,
		"play_time": 0.0,
		"gen": 14,  # 2 = new biome layout, 3 = + palm trees, 4 = + fall forest, 5 = + spooky forest, 6 = + floating islands, 7 = + cave shrines and treasure sites, 8 = + boss lairs, 9 = + chessboard kingdom, 10 = + fast food land, 11 = + villager camps, 12 = + the Deep, 13 = + 64 blocks deeper underground, 14 = + lava caverns and the Fire Giant (older worlds keep what they had)
	})
	return file if ok else ""


func _ask_delete() -> void:
	var sel := _world_list.get_selected_items()
	if _selected_file().is_empty():
		return
	_delete_dialog.dialog_text = "Delete \"%s\" forever?\nYou can't get it back!" % _world_data[sel[0]]["name"]
	_delete_dialog.popup_centered()


func _delete_selected() -> void:
	var file := _selected_file()
	if not file.is_empty():
		SaveSystem.delete_world(file)
		refresh_worlds()
		set_status("World deleted.")


# --- Character -------------------------------------------------------------------------

func refresh_character() -> void:
	var c := Characters.selected()
	_char_label.text = c.get("name", "(make a character first)")
	for n in _char_holder.get_children():
		n.queue_free()
	if not c.is_empty():
		_char_holder.add_child(Avatar.build(c.get("look", {}))["root"])


func get_player_name() -> String:
	return Characters.selected().get("name", "Player")


func get_character_id() -> String:
	return Characters.selected_id


func get_character_look() -> Dictionary:
	return Characters.selected().get("look", {})


func has_character() -> bool:
	return not Characters.selected().is_empty()


## For the command line (--name=Bob): play as a character called Bob,
## making one the first time.
func set_player_name(n: String) -> void:
	var id := "cli_" + Characters.clean_name(n).to_lower()
	if Characters.get_char(id).is_empty():
		Characters.create(n, Avatar.random_look(), id)
	Characters.select(id)
	refresh_character()


func get_render_distance() -> int:
	return Settings.view_distance()


func get_port() -> int:
	var p := _port_edit.text.strip_edges().to_int()
	return p if p > 0 and p < 65536 else DEFAULT_PORT


func set_port(p: int) -> void:
	_port_edit.text = str(p)


func set_address(a: String) -> void:
	_address_edit.text = a


func set_status(text: String) -> void:
	_status.text = text


func set_busy(busy: bool, text := "") -> void:
	for b in _buttons:
		b.disabled = busy
	set_status(text)
