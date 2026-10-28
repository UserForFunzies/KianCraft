extends RefCounted
## One look for every screen: dark worn-iron windows with a thin double gold
## trim and gem corners, beveled buttons with cut corners, sunken item slots,
## and a serif font, like an old fantasy RPG. main.gd applies it to the whole
## game window, so every menu picks it up. The pictures are painted in
## ui_art.gd and cut into nine-patch styles here.
##
## Button colors: set `button.theme_type_variation` to one of
##   "GreenButton" (do it!), "BlueButton", "GoldButton" (toots), "RedButton" (careful),
##   "TabButton" (tabs at the top of a window), "SlotButton" (inventory squares),
##   "FlatButton" (quiet text buttons).
## Panels: "CardPanel" (a lighter card inside a window), "PillPanel" (small HUD bubbles).

const Art = preload("res://scripts/ui_art.gd")

const FONT_SIZE := 19
const RADIUS := 6

const BG := Color(0.045, 0.036, 0.048, 0.97)     # window background (near-black plum)
const CARD := Color(0.08, 0.06, 0.075, 0.9)       # cards inside windows
const BORDER := Color(0.5, 0.38, 0.21, 0.6)
const TEXT := Color(0.92, 0.86, 0.74)             # warm parchment
const TEXT_SOFT := Color(0.62, 0.56, 0.5)
const GREEN := Color(0.09, 0.22, 0.14)            # dark emerald
const BLUE := Color(0.13, 0.11, 0.3)              # royal indigo
const GOLD := Color(0.86, 0.68, 0.36)
const RED := Color(0.32, 0.06, 0.1)               # burgundy
const NEUTRAL := Color(0.12, 0.09, 0.12)          # black plum iron
const GOOD := Color(0.6, 0.86, 0.55)              # "you have enough"
const BAD := Color(0.95, 0.5, 0.45)               # "you need more"
const TITLE := Color(0.95, 0.82, 0.55)            # window titles

static var _theme: Theme
static var _title_font: Font
static var _body_font: Font


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## A serif font from the computer (Palatino, Georgia...), falling back to the
## built-in one if none are there.
static func _serif(bold: float) -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Palatino Linotype", "Book Antiqua", "Palatino", "Georgia", "Cambria", "Times New Roman", "DejaVu Serif", "Liberation Serif", "serif"])
	sf.font_weight = 600 if bold > 0.2 else 500
	sf.fallbacks = [ThemeDB.fallback_font]
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.hinting = TextServer.HINTING_LIGHT
	var v := FontVariation.new()
	v.base_font = sf
	v.variation_embolden = bold
	return v


static func title_font() -> Font:
	if _title_font == null:
		_title_font = _serif(0.45)
	return _title_font


static func body_font() -> Font:
	if _body_font == null:
		_body_font = _serif(0.12)
	return _body_font


## A plain colored box (for swatches, bars and little things).
static func box(color: Color, radius := RADIUS, border := 0, border_color := BORDER, margin := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(mini(radius, 4))
	s.set_border_width_all(border)
	s.border_color = border_color
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s


## The ornate window frame.
static func glass(_color := BG, _radius := 14, margin := 26.0, _shadow := 18) -> StyleBoxTexture:
	return _tex(Art.panel(), 28, margin)


## A card inside a window; `rim` = edge color (an item's rarity color, say).
static func card(rim := Art.BRONZE, margin := 12.0) -> StyleBoxTexture:
	return _tex(Art.card(rim), 7, margin)


static func _tex(img: Image, cut: int, margin: float, tile := true) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = ImageTexture.create_from_image(img)
	s.set_texture_margin_all(cut)
	s.set_content_margin_all(margin)
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


static func _button_styles(t: Theme, type: String, base: Color, text_color := TEXT) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s := _tex(Art.button(base, state), 9, 9.0, false)
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 7
		s.content_margin_bottom = 8 if state != "pressed" else 6
		t.set_stylebox(state, type, s)
	t.set_stylebox("hover_pressed", type, t.get_stylebox("pressed", type))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, text_color)
	t.set_color("font_hover_color", type, text_color.lightened(0.15))
	t.set_color("font_pressed_color", type, text_color.darkened(0.08))
	t.set_color("font_focus_color", type, text_color)
	t.set_color("font_hover_pressed_color", type, text_color)
	t.set_color("font_disabled_color", type, Color(0.62, 0.6, 0.56, 0.6))
	t.set_color("font_outline_color", type, Color(0, 0, 0, 0.75))
	t.set_constant("outline_size", type, 3)
	t.set_font("font", type, title_font())


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = FONT_SIZE

	t.set_stylebox("panel", "PanelContainer", glass())
	t.set_stylebox("panel", "Panel", glass())
	t.add_type("CardPanel")
	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", card())
	t.add_type("PillPanel")
	t.set_type_variation("PillPanel", "PanelContainer")
	var pill := _tex(Art.pill(), 8, 8.0)
	pill.content_margin_left = 12
	pill.content_margin_right = 12
	pill.content_margin_top = 5
	pill.content_margin_bottom = 5
	t.set_stylebox("panel", "PillPanel", pill)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.7))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	_button_styles(t, "Button", NEUTRAL)
	for v in [["GreenButton", GREEN], ["BlueButton", BLUE], ["GoldButton", Color(0.48, 0.35, 0.13)], ["RedButton", RED]]:
		t.add_type(v[0])
		t.set_type_variation(v[0], "Button")
		_button_styles(t, v[0], v[1], Color(1.0, 0.93, 0.75) if v[0] == "GoldButton" else TEXT)

	# Quiet buttons: just text until you hover them (close, ?, small actions).
	t.add_type("FlatButton")
	t.set_type_variation("FlatButton", "Button")
	_button_styles(t, "FlatButton", NEUTRAL)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 6
	flat.content_margin_bottom = 6
	t.set_stylebox("normal", "FlatButton", flat)
	var flat_on := StyleBoxFlat.new()
	flat_on.bg_color = Color(GOLD, 0.06)
	flat_on.border_width_bottom = 1
	flat_on.border_color = Color(GOLD, 0.7)
	flat_on.content_margin_left = 12
	flat_on.content_margin_right = 12
	flat_on.content_margin_top = 6
	flat_on.content_margin_bottom = 6
	t.set_stylebox("hover", "FlatButton", flat_on)
	t.set_stylebox("pressed", "FlatButton", flat_on)
	t.set_stylebox("disabled", "FlatButton", flat)
	t.set_color("font_color", "FlatButton", TEXT_SOFT)
	t.set_color("font_hover_color", "FlatButton", TITLE)

	# Tabs: words on the window, the chosen one underlined in gold with a glow.
	t.add_type("TabButton")
	t.set_type_variation("TabButton", "Button")
	_button_styles(t, "TabButton", NEUTRAL)
	var tab := StyleBoxEmpty.new()
	tab.content_margin_left = 16
	tab.content_margin_right = 16
	tab.content_margin_top = 8
	tab.content_margin_bottom = 9
	var tab_hover := StyleBoxFlat.new()
	tab_hover.bg_color = Color(GOLD, 0.05)
	tab_hover.border_width_bottom = 1
	tab_hover.border_color = Color(GOLD, 0.35)
	tab_hover.content_margin_left = 16
	tab_hover.content_margin_right = 16
	tab_hover.content_margin_top = 8
	tab_hover.content_margin_bottom = 9
	var tab_on := _tex(Art.tab_on(), 3, 9.0, false)
	tab_on.content_margin_left = 16
	tab_on.content_margin_right = 16
	t.set_stylebox("normal", "TabButton", tab)
	t.set_stylebox("hover", "TabButton", tab_hover)
	t.set_stylebox("pressed", "TabButton", tab_on)
	t.set_stylebox("hover_pressed", "TabButton", tab_on)
	t.set_stylebox("disabled", "TabButton", tab)
	t.set_color("font_color", "TabButton", TEXT_SOFT)
	t.set_color("font_hover_color", "TabButton", TEXT)
	t.set_color("font_pressed_color", "TabButton", TITLE)
	t.set_color("font_hover_pressed_color", "TabButton", TITLE)

	# Inventory squares.
	t.add_type("SlotButton")
	t.set_type_variation("SlotButton", "Button")
	for pair in [["normal", "normal"], ["hover", "hover"], ["pressed", "selected"], ["hover_pressed", "selected"], ["disabled", "normal"]]:
		t.set_stylebox(pair[0], "SlotButton", slot_style(pair[1]))
	t.set_stylebox("focus", "SlotButton", StyleBoxEmpty.new())

	var edit := _tex(Art.field(false), 6, 10.0)
	var edit_focus := _tex(Art.field(true), 6, 10.0)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_stylebox("read_only", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.5, 0.46, 0.4))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.3))

	t.set_stylebox("panel", "ItemList", _tex(Art.field(false), 6, 6.0))
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(GOLD, 0.14)
	sel.border_width_left = 2
	sel.border_color = GOLD
	sel.set_content_margin_all(6)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	var hov := sel.duplicate()
	hov.bg_color = Color(GOLD, 0.06)
	hov.border_color = Color(GOLD, 0.4)
	t.set_stylebox("hovered", "ItemList", hov)
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", TITLE)
	t.set_color("font_hovered_color", "ItemList", TEXT)
	t.set_constant("v_separation", "ItemList", 6)

	_button_styles(t, "OptionButton", NEUTRAL)
	var popup := card(Art.GOLD_DIM, 6.0)
	t.set_stylebox("panel", "PopupMenu", popup)
	var phov := StyleBoxFlat.new()
	phov.bg_color = Color(GOLD, 0.16)
	t.set_stylebox("hover", "PopupMenu", phov)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TITLE)

	t.set_stylebox("background", "ProgressBar", _tex(Art.field(false), 4, 0.0))
	t.set_stylebox("fill", "ProgressBar", _tex(Art.bar(Color(0.2, 0.5, 0.25)), 3, 0.0, false))

	var slider_bg := _tex(Art.field(false), 4, 0.0)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider_bg)
	t.set_stylebox("grabber_area", "HSlider", _tex(Art.bar(Art.GOLD_DIM), 3, 0.0, false))
	t.set_stylebox("grabber_area_highlight", "HSlider", _tex(Art.bar(Art.GOLD), 3, 0.0, false))
	t.set_icon("grabber", "HSlider", _grabber_icon(false))
	t.set_icon("grabber_highlight", "HSlider", _grabber_icon(true))
	t.set_constant("center_grabber", "HSlider", 1)

	var tip := card(Art.GOLD_DIM, 10.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	for sb in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sb, _tex(Art.bar(Color(0.3, 0.24, 0.16)), 3, 0.0, false))
		t.set_stylebox("grabber_highlight", sb, _tex(Art.bar(Art.GOLD_DIM), 3, 0.0, false))
		t.set_stylebox("grabber_pressed", sb, _tex(Art.bar(Art.GOLD), 3, 0.0, false))
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.35)
		track.set_content_margin_all(4)
		t.set_stylebox("scroll", sb, track)

	var line := StyleBoxLine.new()
	line.color = Color(Art.GOLD_DIM, 0.75)
	line.thickness = 1
	line.grow_begin = -8
	line.grow_end = -8
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 14)

	t.set_stylebox("panel", "AcceptDialog", glass(BG, 12, 18.0))
	t.add_type("CheckButton")
	for pair in [["checked", true, false], ["unchecked", false, false], ["checked_disabled", true, true], ["unchecked_disabled", false, true]]:
		t.set_icon(pair[0], "CheckButton", ImageTexture.create_from_image(Art.toggle(pair[1], pair[2])))
		t.set_icon(pair[0] + "_mirrored", "CheckButton", ImageTexture.create_from_image(Art.toggle(pair[1], pair[2])))
	t.set_icon("checked", "CheckBox", ImageTexture.create_from_image(Art.checkbox(true)))
	t.set_icon("unchecked", "CheckBox", ImageTexture.create_from_image(Art.checkbox(false)))
	t.set_icon("radio_checked", "CheckBox", ImageTexture.create_from_image(Art.checkbox(true)))
	t.set_icon("radio_unchecked", "CheckBox", ImageTexture.create_from_image(Art.checkbox(false)))
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_font("font", "CheckButton", body_font())
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", TITLE)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", TITLE)
	return t


static func slot_style(state: String) -> StyleBoxTexture:
	return _tex(Art.slot(state), 6, 4.0)


## A small gold diamond for slider handles.
static func _grabber_icon(hot: bool) -> ImageTexture:
	var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var m := absf(x - 7.5) + absf(y - 7.5)
			if m < 7.0:
				var c: Color = (Art.GOLD_HI if hot else Art.GOLD).lerp(Art.GOLD_DIM, float(y) / 16.0)
				img.set_pixel(x, y, c if m < 6.0 else Art.EDGE)
	return ImageTexture.create_from_image(img)


# --- Small helpers used by every screen ------------------------------------------------

static func label(text: String, size := FONT_SIZE, color := TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
	if size >= 22:
		l.add_theme_font_override("font", title_font())   # big words: the heavier title serif
	return l


## Makes a label look like a window title (gold serif).
static func make_title(l: Label) -> Label:
	l.add_theme_font_override("font", title_font())
	l.add_theme_color_override("font_color", TITLE)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	return l


static func button(text: String, variation := "Button", size := FONT_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## A window title: big gold serif, an optional icon, and an ornate gold line underneath.
static func header(text: String, size := 28, icon: Texture2D = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if icon:
		row.add_child(icon_rect(icon, size + 6))
	var l := make_title(label(text, size))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	box.add_child(row)
	box.add_child(accent_line())
	return box


## The ornate line under titles: a gold gem, then a gold line fading out.
static func accent_line() -> NinePatchRect:
	var r := NinePatchRect.new()
	r.texture = ImageTexture.create_from_image(Art.divider())
	r.patch_margin_left = 12
	r.patch_margin_right = 80
	r.custom_minimum_size = Vector2(0, 11)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func icon_rect(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
