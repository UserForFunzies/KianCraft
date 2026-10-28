extends PanelContainer
## The floating item card (like Diablo's): a frame edged in the item's rarity
## color, its picture in a gold-rimmed slot, the name and kind, then its
## stats, a short description or flavor line, and who made it and its price.
## It follows the mouse and stays on screen.

const UI = preload("res://scripts/ui_theme.gd")
const Items = preload("res://scripts/items.gd")
const ItemCard = preload("res://scripts/item_card.gd")

const WIDTH := 330.0

var _icon: TextureRect
var _name: Label
var _kind: Label
var _body: RichTextLabel
var _extra: VBoxContainer
var _anchor: Control             # the slot or card that showed it (hide when the mouse leaves)


func _ready() -> void:
	top_level = true
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.slot_style("selected"))
	frame.custom_minimum_size = Vector2(64, 64)
	_icon = UI.icon_rect(null, 52)
	frame.add_child(_icon)
	head.add_child(frame)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	_name = UI.make_title(UI.label("", 22))
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.custom_minimum_size = Vector2(WIDTH - 110, 0)
	names.add_child(_name)
	_kind = UI.label("", 14, UI.TEXT_SOFT)
	names.add_child(_kind)
	head.add_child(names)
	box.add_child(UI.accent_line())
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.custom_minimum_size = Vector2(WIDTH - 30, 0)
	_body.add_theme_font_size_override("normal_font_size", 16)
	_body.add_theme_font_size_override("bold_font_size", 17)
	_body.add_theme_font_size_override("italics_font_size", 15)
	box.add_child(_body)
	_extra = VBoxContainer.new()
	_extra.add_theme_constant_override("separation", 4)
	box.add_child(_extra)
	visible = false


## Show an item (from a slot dictionary). `extra`: more controls to put at the
## bottom (a recipe's ingredients, say). `anchor`: hide when the mouse leaves it.
func show_item(item: Dictionary, anchor: Control = null, extra: Array = []) -> void:
	if item.is_empty():
		hide_now()
		return
	var p := ItemCard.parts(item)
	var rim: Color = p["color"]
	add_theme_stylebox_override("panel", UI.card(rim.lerp(UI.Art.GOLD_DIM, 0.25), 14.0))
	_icon.texture = Items.icon(item["id"])
	_name.text = p["name"]
	_name.add_theme_color_override("font_color", p["name_color"])
	_kind.text = p["kind"]
	_kind.add_theme_color_override("font_color", rim.darkened(0.1))
	_body.text = p["body"]
	for c in _extra.get_children():
		_extra.remove_child(c)
		c.queue_free()
	for c in extra:
		_extra.add_child(c)
	_anchor = anchor
	visible = true
	reset_size()
	_follow()


## A card for a recipe nobody's found yet.
func show_mystery(anchor: Control, tier: int) -> void:
	add_theme_stylebox_override("panel", UI.card(UI.Art.GOLD_DIM, 14.0))
	_icon.texture = null
	_name.text = "An Unknown Recipe"
	_name.add_theme_color_override("font_color", UI.TEXT_SOFT)
	_kind.text = "Tier %s" % ["I", "II", "III"][clampi(tier - 1, 0, 2)]
	_kind.add_theme_color_override("font_color", UI.TEXT_SOFT)
	_body.text = "[i]Find everything it's made from out in the world, and it will be revealed here.[/i]"
	for c in _extra.get_children():
		_extra.remove_child(c)
		c.queue_free()
	_anchor = anchor
	visible = true
	reset_size()
	_follow()


func hide_now() -> void:
	visible = false
	_anchor = null


func _process(_delta: float) -> void:
	if not visible:
		return
	if _anchor != null and (not is_instance_valid(_anchor) or not _anchor.is_visible_in_tree() \
			or not _anchor.get_global_rect().has_point(_anchor.get_global_mouse_position())):
		hide_now()
		return
	_follow()


## Next to the mouse, flipping to the other side near the screen edges.
func _follow() -> void:
	var m := get_global_mouse_position()
	var view := get_viewport_rect().size
	var s := size
	var pos := m + Vector2(22, 18)
	if pos.x + s.x > view.x - 8:
		pos.x = m.x - s.x - 22
	if pos.y + s.y > view.y - 8:
		pos.y = view.y - s.y - 8
	global_position = pos.max(Vector2(8, 8))
