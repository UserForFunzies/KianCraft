extends PanelContainer
## One inventory square. It only reports mouse presses and hovering;
## inventory_ui.gd decides what clicks and drags mean (Rust-style controls).

const Items = preload("res://scripts/items.gd")
const UI = preload("res://scripts/ui_theme.gd")

signal pressed_with(slot: Control, event: InputEventMouseButton)
signal hovered(item: Dictionary)

var area := "inv"      # "inv" = your stuff, "open" = the open box, "their" = a trade partner's offer
var index := 0
var item := {}
var selected := false
var _normal: StyleBox
var _hover: StyleBox


func setup(slot_area: String, slot_index: int, slot_item: Dictionary, size: float, is_selected := false, hint_icon: Texture2D = null) -> void:
	area = slot_area
	index = slot_index
	item = slot_item
	selected = is_selected
	custom_minimum_size = Vector2(size, size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not item.is_empty() and area != "their" else Control.CURSOR_ARROW
	var theme_ref := UI.get_theme()
	_normal = theme_ref.get_stylebox("pressed" if selected else "normal", "SlotButton")
	_hover = theme_ref.get_stylebox("pressed" if selected else "hover", "SlotButton")
	if not item.is_empty() and Items.rarity(item["id"]) == "legendary":
		var glow := UI.box(Color(0.25, 0.12, 0.03, 0.95), 12, 4, Color(1.0, 0.55, 0.1), 4)
		_normal = glow
		_hover = glow
	add_theme_stylebox_override("panel", _normal)
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	if not item.is_empty():
		var icon := UI.icon_rect(Items.icon(item["id"]), size - 16)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(icon)
		if item["count"] > 1:
			var c := UI.label(str(item["count"]), 16, Color.WHITE, 5)
			c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			c.offset_left = -32
			c.offset_top = -20
			c.offset_right = 2
			c.offset_bottom = 2
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			holder.add_child(c)
	elif hint_icon:
		# A faded picture showing what goes here (helmet, boots...).
		var ghost := UI.icon_rect(hint_icon, size - 20)
		ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
		ghost.modulate = Color(1, 1, 1, 0.22)
		holder.add_child(ghost)
	mouse_entered.connect(func() -> void:
		add_theme_stylebox_override("panel", _hover)
		hovered.emit(item))
	mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", _normal))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		accept_event()
		pressed_with.emit(self, event)
