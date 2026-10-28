extends CanvasLayer
## A small window for naming a portal (right-click a portal to open it).

const UI = preload("res://scripts/ui_theme.gd")

signal opened
signal closed

var survival: Node
var _root: Control
var _title: Label
var _info: Label
var _edit: LineEdit
var _save: Button
var _id := 0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_title = UI.make_title(UI.label("Portal", 26))
	box.add_child(_title)
	_info = UI.label("", 16, UI.TEXT_SOFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_edit = LineEdit.new()
	_edit.placeholder_text = "Give it a name..."
	_edit.max_length = 24
	_edit.add_theme_font_size_override("font_size", 20)
	_edit.custom_minimum_size = Vector2(0, 46)
	_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	box.add_child(_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := UI.button("Close", "FlatButton", 18)
	cancel.pressed.connect(close)
	row.add_child(cancel)
	_save = UI.button("Save name", "GreenButton", 18)
	_save.custom_minimum_size = Vector2(150, 46)
	_save.pressed.connect(_submit)
	row.add_child(_save)
	box.add_child(row)


func is_open() -> bool:
	return _root.visible


func open(id: int, my_name: String) -> void:
	var p: Dictionary = survival.portals.get(id, {})
	if p.is_empty():
		return
	_id = id
	var size_text := "%d wide, %d tall" % [p["w"], p["h"]]
	var named: bool = p["name"] != ""
	_title.text = "Portal \"%s\"" % p["name"] if named else "A new portal"
	var can_edit: bool = not p["linked"] or p["creator_name"] == my_name
	if p["linked"]:
		_info.text = "Linked! Step in to travel to the other \"%s\" portal. (%s, built by %s)" % [p["name"], size_text, p["creator_name"]]
		if not can_edit:
			_info.text += "\nOnly %s can rename it." % p["creator_name"]
	else:
		_info.text = "Give two portals of the same size (this one is %s) the same name, and they'll link up!" % size_text
	_edit.text = p["name"]
	_edit.editable = can_edit
	_save.disabled = not can_edit
	_root.visible = true
	opened.emit()
	if can_edit:
		_edit.grab_focus.call_deferred()
		_edit.select_all.call_deferred()


func close() -> void:
	if not _root.visible:
		return
	_root.visible = false
	_edit.release_focus()
	closed.emit()


func _submit() -> void:
	if _save.disabled:
		return
	survival.req_name_portal.rpc_id(1, _id, _edit.text)
	close()


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
