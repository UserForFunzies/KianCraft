extends CanvasLayer
## Character select and character creator (from the main menu).
##
## Select: pick who to play as, edit them, delete them, or make a new one.
## Creator: name, a ready-made style to start from (cute, cool, plain, silly),
## then change each part (hair, face, top, bottom, shoes, skin) and colors,
## with a turning 3D preview.

const Characters = preload("res://scripts/characters.gd")
const Avatar = preload("res://scripts/avatar.gd")
const UI = preload("res://scripts/ui_theme.gd")

signal closed
signal changed          # the selected character changed (or was edited)

var _select: Control
var _create: Control
var _list: VBoxContainer
var _sel_name: Label
var _sel_preview: Node3D
var _cr_preview: Node3D
var _name_edit: LineEdit
var _part_labels := {}
var _color_rows := {}
var _look := {}
var _editing_id := ""        # "" = making a new character
var _spin := 0.0
var _hint: Label
var _tab := 0
var _tab_buttons: Array[Button] = []
var _options_box: VBoxContainer
var _cr_cam: Camera3D
var _drag_turn := 0.0        # how far you've turned the preview by dragging it
var _dragging := false
var _cam_at := Vector3(0, 1.0, 0)


func _ready() -> void:
	layer = 15
	_select = _build_select()
	_create = _build_create()
	add_child(_select)
	add_child(_create)
	_select.visible = false
	_create.visible = false


func is_open() -> bool:
	return _select.visible or _create.visible


func open_select() -> void:
	_create.visible = false
	_select.visible = true
	_refresh_select()


func open_create(edit_id := "") -> void:
	_editing_id = edit_id
	var c := Characters.get_char(edit_id)
	if c.is_empty():
		_look = Avatar.random_look()
		_name_edit.text = ""
		_hint.text = "Make your character! Start from a style, then change anything you like."
	else:
		_look = Avatar.clean_look(c["look"])
		_name_edit.text = c["name"]
		_hint.text = "Changing how %s looks." % c["name"]
	_select.visible = false
	_create.visible = true
	_refresh_create()


func close() -> void:
	_select.visible = false
	_create.visible = false
	closed.emit()


func _process(delta: float) -> void:
	if not is_open():
		return
	_spin += delta * 0.7
	# Characters face the camera (their faces look toward -Z, where the camera is),
	# gently turning side to side so you can see them from a few angles.
	if _sel_preview and _sel_preview.get_child_count() > 0:
		_sel_preview.get_child(0).rotation.y = sin(_spin) * 0.6
	if _cr_preview and _cr_preview.get_child_count() > 0:
		var sway := 0.0 if _dragging else sin(_spin) * 0.35
		_cr_preview.get_child(0).rotation.y = _drag_turn + sway
	if _cr_cam:
		# Hair and Face tabs zoom in on the head.
		var close: bool = _tab in [1, 2]
		var want_pos := Vector3(0, 1.62, -2.1) if close else Vector3(0, 1.15, -4.2)
		var want_at := Vector3(0, 1.6, 0) if close else Vector3(0, 1.0, 0)
		var k := minf(1.0, delta * 6.0)
		_cr_cam.position = _cr_cam.position.lerp(want_pos, k)
		_cam_at = _cam_at.lerp(want_at, k)
		_cr_cam.look_at(_cam_at, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _create.visible and not Characters.all().is_empty():
			open_select()
		else:
			close()


# --- Building ------------------------------------------------------------------------

func _screen() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	return root


## A 3D view that shows one character. Returns the node to put the model in.
func _preview(parent: Control, size: Vector2, draggable := false) -> Node3D:
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = size
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	view.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = 32
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.15, -4.2), Vector3(0, 1.0, 0))
	if draggable:
		_cr_cam = cam
		view.mouse_filter = Control.MOUSE_FILTER_STOP
		view.mouse_default_cursor_shape = Control.CURSOR_DRAG
		view.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				_dragging = e.pressed
			elif e is InputEventMouseMotion and _dragging:
				_drag_turn += e.relative.x * 0.012)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.55, PI + 0.6, 0)   # from the front, a little to the side
	vp.add_child(light)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, 0.4, 0)
	rim.light_energy = 0.35
	vp.add_child(rim)
	# A round stand to stand on.
	var stand := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.6
	cyl.height = 0.08
	stand.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.93, 0.74, 0.36, 0.9)
	sm.metallic = 0.3
	stand.material_override = sm
	stand.position.y = -0.04
	vp.add_child(stand)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.77, 0.85)
	env.environment.ambient_light_energy = 0.7
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	vp.add_child(env)
	var holder := Node3D.new()
	vp.add_child(holder)
	parent.add_child(view)
	return holder


func _show_look(holder: Node3D, look: Dictionary) -> void:
	for c in holder.get_children():
		c.queue_free()
	if look.is_empty():
		return
	var parts := Avatar.build(look)
	holder.add_child(parts["root"])   # faces the camera


func _build_select() -> Control:
	var root := _screen()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := UI.header("Characters", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := UI.button("Back", "Button", 16)
	back.pressed.connect(close)
	head.add_child(back)
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	left.add_child(scroll)
	var new_btn := UI.button("+  New character", "GreenButton", 17)
	new_btn.custom_minimum_size = Vector2(0, 44)
	new_btn.pressed.connect(func() -> void: open_create(""))
	left.add_child(new_btn)
	row.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	_sel_name = UI.label("", 22)
	_sel_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_sel_name)
	_sel_preview = _preview(right, Vector2(260, 340))
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	var play := UI.button("Play as them", "GreenButton", 17)
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(close)
	btns.add_child(play)
	var edit := UI.button("Edit", "Button", 16)
	edit.pressed.connect(func() -> void: open_create(Characters.selected_id))
	btns.add_child(edit)
	var del := UI.button("Delete", "RedButton", 16)
	del.pressed.connect(_ask_delete)
	btns.add_child(del)
	right.add_child(btns)
	var note := UI.label("Each character has their own inventory, toots and unlocks in every world.\nChests belong to the world, so everyone shares them.", 13, UI.TEXT_SOFT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(260, 0)
	right.add_child(note)
	row.add_child(right)
	return root


func _build_create() -> Control:
	var root := _screen()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UI.header("Character creator", 26))
	_hint = UI.label("", 14, UI.TEXT_SOFT)
	box.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	# Left: name and styles to start from
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(310, 0)
	left.add_theme_constant_override("separation", 8)
	left.add_child(UI.label("NAME", 13, UI.GOLD))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your character's name"
	_name_edit.max_length = Characters.MAX_NAME
	left.add_child(_name_edit)
	left.add_child(UI.label("START FROM A STYLE", 13, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for preset in Avatar.PRESETS:
		var b := UI.button("%s\n%s" % [preset["name"], preset["style"]], "Button", 14)
		b.custom_minimum_size = Vector2(98, 48)
		b.pressed.connect(func() -> void:
			_look = Avatar.clean_look(preset["look"])
			if _name_edit.text.strip_edges().is_empty():
				_name_edit.text = preset["name"]
			_refresh_create())
		grid.add_child(b)
	left.add_child(grid)
	var rnd := UI.button("Surprise me!", "BlueButton", 16)
	rnd.pressed.connect(func() -> void:
		_look = Avatar.random_look()
		_refresh_create())
	left.add_child(rnd)
	row.add_child(left)

	# Middle: the preview
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	_cr_preview = _preview(mid, Vector2(300, 420), true)
	var turn_hint := UI.label("Drag to turn them around", 13, UI.TEXT_SOFT)
	turn_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(turn_hint)
	row.add_child(mid)

	# Right: tabs (Body, Hair, Face, Clothes, Extras), each with its parts.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 430)
	right.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in Avatar.GROUPS.size():
		var tb := UI.button(Avatar.GROUPS[i][0], "TabButton", 15)
		tb.toggle_mode = true
		tb.button_group = group
		tb.button_pressed = i == 0
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		tb.pressed.connect(func() -> void: _show_tab(idx))
		tabs.add_child(tb)
		_tab_buttons.append(tb)
	right.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_box = VBoxContainer.new()
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_options_box)
	right.add_child(scroll)
	row.add_child(right)
	_show_tab(0)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	var cancel := UI.button("Cancel", "Button", 16)
	cancel.pressed.connect(func() -> void:
		if Characters.all().is_empty():
			return  # you need at least one character
		open_select())
	bottom.add_child(cancel)
	var done := UI.button("Save character", "GreenButton", 17)
	done.custom_minimum_size = Vector2(180, 44)
	done.pressed.connect(_save)
	bottom.add_child(done)
	box.add_child(bottom)
	return root


func _show_tab(i: int) -> void:
	_tab = i
	if i < _tab_buttons.size():
		_tab_buttons[i].button_pressed = true
	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()
	_part_labels.clear()
	var keys: Array = Avatar.GROUPS[i][1]
	for part in Avatar.PARTS:
		if part[0] in keys:
			_add_part_row(part)
	if not _look.is_empty():
		_refresh_create()


func _swatch(c: Color, size: Vector2, on_press: Callable) -> Button:
	var sw := Button.new()
	sw.custom_minimum_size = size
	sw.focus_mode = Control.FOCUS_NONE
	sw.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	sw.add_theme_stylebox_override("normal", UI.box(c, 6, 1, Color(0, 0, 0, 0.4), 0))
	sw.add_theme_stylebox_override("hover", UI.box(c.lightened(0.15), 6, 2, Color(1, 1, 1, 0.8), 0))
	sw.add_theme_stylebox_override("pressed", UI.box(c, 6, 2, Color(1, 1, 1, 0.95), 0))
	sw.pressed.connect(on_press)
	return sw


## One part: its name with < > arrows (or swatches for colors-only parts),
## and its color swatches underneath.
func _add_part_row(part: Array) -> void:
	var key: String = part[0]
	var options: Array = part[2]
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	col.add_child(UI.label(String(part[1]).to_upper(), 12, UI.GOLD))
	if options[0] is Color:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		for i in options.size():
			var idx := i
			flow.add_child(_swatch(options[i], Vector2(30, 26), func() -> void:
				_look[key] = idx
				_refresh_create()))
		col.add_child(flow)
	else:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var prev := UI.button("<", "Button", 18)
		prev.custom_minimum_size = Vector2(46, 38)
		prev.pressed.connect(func() -> void: _step(key, -1, options.size()))
		line.add_child(prev)
		var name_label := UI.label("", 17)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		_part_labels[key] = name_label
		var nxt := UI.button(">", "Button", 18)
		nxt.custom_minimum_size = Vector2(46, 38)
		nxt.pressed.connect(func() -> void: _step(key, 1, options.size()))
		line.add_child(nxt)
		col.add_child(line)
	var color_key: String = part[3]
	if color_key != "":
		var palette: Array = Avatar.HAIR_COLORS if color_key == "hair_color" else Avatar.COLORS
		var flow2 := HFlowContainer.new()
		flow2.add_theme_constant_override("h_separation", 3)
		flow2.add_theme_constant_override("v_separation", 3)
		for i in palette.size():
			var idx := i
			flow2.add_child(_swatch(palette[i], Vector2(22, 22), func() -> void:
				_look[color_key] = idx
				_refresh_create()))
		col.add_child(flow2)
	_options_box.add_child(card)


# --- Updating --------------------------------------------------------------------------

func _step(key: String, d: int, count: int) -> void:
	_look[key] = posmod(int(_look.get(key, 0)) + d, count)
	_refresh_create()


func _refresh_create() -> void:
	_look = Avatar.clean_look(_look)
	for part in Avatar.PARTS:
		var key: String = part[0]
		var options: Array = part[2]
		var i: int = _look[key]
		if _part_labels.has(key):
			_part_labels[key].text = "%s   (%d/%d)" % [options[i], i + 1, options.size()] if options[i] is String else "Tone %d" % (i + 1)
	_show_look(_cr_preview, _look)


func _save() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		_hint.text = "Give your character a name first!"
		return
	if _editing_id.is_empty():
		Characters.create(n, _look)
	else:
		Characters.update(_editing_id, n, _look)
		Characters.select(_editing_id)
	changed.emit()
	open_select()


func _refresh_select() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var group := ButtonGroup.new()
	for c in Characters.all():
		var b := UI.button(c["name"], "TabButton", 17)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = c["id"] == Characters.selected_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		var id: String = c["id"]
		b.pressed.connect(func() -> void:
			Characters.select(id)
			changed.emit()
			_refresh_select())
		_list.add_child(b)
	var sel := Characters.selected()
	_sel_name.text = sel.get("name", "")
	_show_look(_sel_preview, sel.get("look", {}))


func _ask_delete() -> void:
	var sel := Characters.selected()
	if sel.is_empty():
		return
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "Delete %s?\nTheir things stay saved in your worlds, but you can't play as them again." % sel["name"]
	dlg.ok_button_text = "Delete"
	dlg.confirmed.connect(func() -> void:
		Characters.delete(sel["id"])
		changed.emit()
		if Characters.all().is_empty():
			open_create("")
		else:
			_refresh_select())
	add_child(dlg)
	dlg.popup_centered()
