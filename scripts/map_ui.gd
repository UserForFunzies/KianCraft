extends CanvasLayer
## The map window: press M, or right-click while holding a map.
## Shows the map you're carrying, who made it, and lets you put little
## pictures on it (a house, a boss, "!" and "?").

const UI = preload("res://scripts/ui_theme.gd")
const MapView = preload("res://scripts/map_view.gd")
const Settings = preload("res://scripts/settings.gd")

signal opened
signal closed

## [kind, button text]
const TOOLS := [["house", "Home"], ["boss", "Boss"], ["alert", "Look!"], ["question", "Hmm?"], ["portal", "Portal"]]

var survival: Node
var get_player: Callable          # -> the local player (Node3D) or null

var _root: Control
var _view: MapView
var _title: Label
var _coords: Label
var _hint: Label
var _tool_buttons := {}


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	_root.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_title = UI.make_title(UI.label("Map", 26))
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_coords = UI.label("", 16, UI.TEXT_SOFT)
	header.add_child(_coords)
	var close_btn := UI.button("Close  (M)", "FlatButton", 17)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	box.add_child(header)

	_view = MapView.new()
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(640, 400)
	_view.mark_requested.connect(func(x: float, z: float, kind: String) -> void:
		survival.req_map_mark.rpc_id(1, x, z, kind, _label_edit.text)
		_label_edit.text = "")
	_view.unmark_requested.connect(func(i: int) -> void: survival.req_map_unmark.rpc_id(1, i))
	_view.hover_changed.connect(func(t: String) -> void: _coords.text = t)
	box.add_child(_view)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.add_child(UI.label("Pictures:", 17, UI.TEXT_SOFT))
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for t in TOOLS:
		var b := UI.button(t[1], "TabButton", 17)
		b.toggle_mode = true
		b.button_group = group
		b.icon = MapView.mark_icon(t[0])
		b.custom_minimum_size = Vector2(0, 46)
		var kind: String = t[0]
		b.toggled.connect(func(on: bool) -> void:
			if on:
				_view.tool = kind
			elif _view.tool == kind:
				_view.tool = "")
		footer.add_child(b)
		_tool_buttons[kind] = b
	_label_edit = LineEdit.new()
	_label_edit.placeholder_text = "Name it (optional)"
	_label_edit.max_length = 20
	_label_edit.custom_minimum_size = Vector2(170, 0)
	_label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_label_edit)
	for z in [["-", 1.0 / 1.4], ["+", 1.4]]:
		var zb := UI.button(z[0], "Button", 22)
		zb.custom_minimum_size = Vector2(46, 46)
		var k: float = z[1]
		zb.pressed.connect(func() -> void: _view.zoom_by(k))
		footer.add_child(zb)
	var me_btn := UI.button("Find me", "BlueButton", 17)
	me_btn.custom_minimum_size = Vector2(0, 46)
	me_btn.pressed.connect(func() -> void: _view.center_on_player())
	footer.add_child(me_btn)
	box.add_child(footer)

	_hint = UI.label("Pick a picture (type a name for it if you like), then click the map to put it there. Right-click a picture to take it off. Scroll to zoom, drag to look around.", 15, UI.TEXT_SOFT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)


func bind(s: Node) -> void:
	survival = s
	survival.map_received.connect(_on_received)
	survival.map_updated.connect(_on_updated)
	_view.world = survival.main.world if survival.main else null


func is_open() -> bool:
	return _root.visible


## slot: the inventory slot holding the map (-1 = the first map you carry).
var _slot := -1
var _label_edit: LineEdit


func open(slot: int) -> void:
	_slot = slot
	if _view.world == null and survival.main:
		_view.world = survival.main.world
	_title.text = "Opening the map..."
	_view.set_map({}, [])
	_hint.visible = Settings.show_tips
	_root.visible = true
	_update_player()
	_view.center_on_player()
	opened.emit()
	survival.req_map_view.rpc_id(1, slot)


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	for b in _tool_buttons.values():
		b.button_pressed = false
	_view.tool = ""
	if multiplayer.has_multiplayer_peer():
		survival.req_map_close.rpc_id(1)
	closed.emit()


func _on_received() -> void:
	if not _root.visible:
		return
	var m: Dictionary = survival.map_view
	if m.is_empty():
		close()  # you don't have a map (the server told you why)
		return
	var slot_item: Dictionary = survival.my_slot(_slot) if _slot >= 0 else {}
	var label: String = slot_item.get("label", "")
	if slot_item.get("id", "") == "party_map":
		_title.text = (label if label != "" else "Party Map") + "  -  " + str(slot_item.get("party_name", m["maker"]))
	else:
		_title.text = ("%s  -  " % label if label != "" else "Map  -  ") + "made by %s" % m["maker"]
	_view.members = []
	_view.set_style(str(m.get("style", "")))
	_view.set_map(m["regions"], m["marks"])


func _on_updated(keys: Array) -> void:
	if not _root.visible or survival.map_view.is_empty():
		return
	if keys.is_empty():
		_view.marks = survival.map_view["marks"]
		_view.members = survival.map_view.get("members", [])
		_view.queue_redraw()
	else:
		_view.regions_changed(keys)


func _update_player() -> void:
	var p: Node3D = get_player.call() if get_player.is_valid() else null
	if p != null:
		_view.player_pos = p.global_position
		_view.player_yaw = p.rotation.y


func _process(_delta: float) -> void:
	if _root.visible:
		_update_player()
		_view.portals = survival.portals
		_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed("map") or event.is_action_pressed("pause") or event.is_action_pressed("inventory")):
		get_viewport().set_input_as_handled()
		close()
