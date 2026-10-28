extends CanvasLayer
## The Settings window (from the main menu or the pause menu), and the
## one-time "would you like tips?" question on the very first launch.
## Every change is applied right away and saved (see settings.gd).

const Settings = preload("res://scripts/settings.gd")
const UI = preload("res://scripts/ui_theme.gd")

signal closed

const QUALITY_TEXT := [
	"No shadows or effects, short view. For old PCs and laptops.",
	"Near sun shadows, torch light, glow, waving water and leaves.",
	"Sun shadows, corner shadows, god rays, clear water, far view.",
	"Everything: far sharp shadows, bounced light, torch shadows, reflections.",
]
const COST_COLORS := {"CPU": Color(0.55, 0.8, 1.0), "GPU": Color(0.95, 0.7, 0.4)}

var _window: Control
var _welcome: Control
var _mode: OptionButton
var _res: OptionButton
var _res_note: Label
var _quality_buttons: Array[Button] = []
var _quality_text: Label
var _renderer: OptionButton
var _renderer_note: Label
var _adv_button: Button
var _scroll: ScrollContainer
var _adv_box: Control
var _adv_controls := {}       # option key -> OptionButton or CheckButton
var _adv_rows := {}           # option key -> its row (hidden on Classic when it can't work)
var _sens: HSlider
var _sens_label: Label
var _tips: CheckButton
var _volumes := {}            # setting name -> HSlider
var _tag_show: CheckButton
var _chat_size: OptionButton
var _tag_size: HSlider
var _tag_color: OptionButton
var _tag_alpha: HSlider


func _ready() -> void:
	layer = 30
	_window = _build_window()
	_window.visible = false
	add_child(_window)
	_welcome = _build_welcome()
	_welcome.visible = false
	add_child(_welcome)


func is_open() -> bool:
	return _window.visible or _welcome.visible


func open() -> void:
	_refresh()
	_window.visible = true


func close() -> void:
	if _window.visible:
		_window.visible = false
		closed.emit()


## First launch only: ask about tips.
func show_welcome_if_first_run() -> void:
	if Settings.first_run and DisplayServer.get_name() != "headless":
		_welcome.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _window.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _dimmed() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root


func _row(parent: Control, label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UI.label(label, 17, UI.TEXT_SOFT)
	l.custom_minimum_size = Vector2(170, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _heading(parent: Control, text: String) -> void:
	var h := UI.label(text.to_upper(), 13, UI.GOLD)
	h.add_theme_constant_override("line_spacing", 2)
	parent.add_child(h)


func _build_window() -> Control:
	var root := _dimmed()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	# Everything below the title scrolls, so it fits any screen.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(580, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	_scroll.add_child(box)

	var head := HBoxContainer.new()
	var title := UI.header("Settings", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := UI.button("Done", "GreenButton", 17)
	x.custom_minimum_size = Vector2(96, 40)
	x.pressed.connect(close)
	head.add_child(x)
	outer.add_child(head)
	outer.add_child(_scroll)

	_heading(box, "Display")
	_mode = OptionButton.new()
	for m in Settings.WINDOW_MODES:
		_mode.add_item(m)
	_mode.item_selected.connect(func(i: int) -> void:
		Settings.window_mode = i
		_apply())
	_row(box, "Window", _mode)
	_res = OptionButton.new()
	for r in Settings.RESOLUTION_NAMES:
		_res.add_item(r)
	_res.item_selected.connect(func(i: int) -> void:
		Settings.resolution = i
		_apply())
	_row(box, "Resolution", _res)
	_res_note = UI.label("", 14, UI.TEXT_SOFT)
	_res_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_res_note)

	box.add_child(HSeparator.new())
	_heading(box, "Graphics")
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in Settings.QUALITY_NAMES.size():
		var b := UI.button(Settings.QUALITY_NAMES[i], "TabButton", 17)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 42)
		b.pressed.connect(func() -> void:
			Settings.set_quality(i)
			_apply())
		q_row.add_child(b)
		_quality_buttons.append(b)
	box.add_child(q_row)
	_quality_text = UI.label("", 14, UI.TEXT_SOFT)
	_quality_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_quality_text)
	_renderer = OptionButton.new()
	for r in Settings.RENDERERS:
		_renderer.add_item(r)
	_renderer.item_selected.connect(func(i: int) -> void:
		Settings.renderer = i
		_apply())
	_row(box, "Renderer", _renderer)
	_renderer_note = UI.label("", 13, UI.TEXT_SOFT)
	_renderer_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_renderer_note)
	_adv_button = UI.button("Show advanced graphics", "Button", 15)
	_adv_button.custom_minimum_size = Vector2(0, 36)
	_adv_button.pressed.connect(func() -> void:
		_adv_box.visible = not _adv_box.visible
		_refresh())
	box.add_child(_adv_button)
	_adv_box = _build_advanced()
	_adv_box.visible = false
	box.add_child(_adv_box)

	box.add_child(HSeparator.new())
	_heading(box, "Sound")
	for v in [["Master", "master_volume"], ["Effects", "sfx_volume"], ["Ambience", "ambience_volume"], ["Interface", "ui_volume"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pct := UI.label("", 15, UI.TEXT_SOFT)
		pct.custom_minimum_size = Vector2(52, 0)
		var key: String = v[1]
		slider.value_changed.connect(func(x: float) -> void:
			Settings.set_volume(key, x)
			pct.text = "%d%%" % int(round(x * 100))
			Settings.apply(get_tree()))
		row.add_child(slider)
		row.add_child(pct)
		_volumes[key] = [slider, pct]
		_row(box, v[0], row)

	box.add_child(HSeparator.new())
	_heading(box, "Party name tags")
	_tag_show = CheckButton.new()
	_tag_show.text = "See party members' names from far away"
	_tag_show.toggled.connect(func(on: bool) -> void:
		Settings.party_tags = on
		_apply())
	_row(box, "Show", _tag_show)
	_tag_size = _slider(box, "Size", 0.5, 2.0, 0.1, func(v: float) -> void: Settings.tag_size = v)
	_tag_color = OptionButton.new()
	for c in Settings.TAG_COLORS:
		var sw := Image.create(14, 14, false, Image.FORMAT_RGBA8)
		sw.fill(c[1])
		_tag_color.add_icon_item(ImageTexture.create_from_image(sw), c[0])
	_tag_color.item_selected.connect(func(i: int) -> void:
		Settings.tag_color = i
		_apply())
	_row(box, "Color", _tag_color)
	_tag_alpha = _slider(box, "Opacity", 0.2, 1.0, 0.05, func(v: float) -> void: Settings.tag_alpha = v)

	box.add_child(HSeparator.new())
	_heading(box, "Controls & help")
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 10)
	_sens = HSlider.new()
	_sens.min_value = 0.25
	_sens.max_value = 3.0
	_sens.step = 0.05
	_sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sens.value_changed.connect(func(v: float) -> void:
		Settings.mouse_sensitivity = v
		_sens_label.text = "%.2fx" % v)
	_sens.drag_ended.connect(func(_c: bool) -> void: _apply())
	sens_row.add_child(_sens)
	_sens_label = UI.label("", 15, UI.TEXT_SOFT)
	_sens_label.custom_minimum_size = Vector2(52, 0)
	sens_row.add_child(_sens_label)
	_row(box, "Mouse speed", sens_row)
	_tips = CheckButton.new()
	_tips.text = "Show tips and how-to text"
	_tips.toggled.connect(func(on: bool) -> void:
		Settings.show_tips = on
		_apply())
	_row(box, "Tips", _tips)
	_chat_size = OptionButton.new()
	for n in ["Small", "Medium", "Large"]:
		_chat_size.add_item(n)
	_chat_size.item_selected.connect(func(i: int) -> void:
		Settings.chat_size = i
		_apply())
	_row(box, "Chat size", _chat_size)
	var keys := UI.label("F11 fullscreen  ·  F1 controls  ·  F3 FPS", 13, UI.TEXT_SOFT)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keys)
	return root


## Every graphics option on its own, with what it costs (CPU = processor,
## GPU = graphics card), in a scrolling list.
func _build_advanced() -> Control:
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	for opt in Settings.GFX_OPTIONS:
		var key: String = opt[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UI.label(opt[1], 15, UI.TEXT_SOFT)
		l.custom_minimum_size = Vector2(210, 0)
		row.add_child(l)
		var cost: String = opt[4]
		var tag := UI.label(cost, 12, COST_COLORS["CPU" if cost.begins_with("CPU") else "GPU"])
		tag.custom_minimum_size = Vector2(78, 0)
		row.add_child(tag)
		var c: Control
		if opt[2] == "bool":
			var cb := CheckButton.new()
			cb.toggled.connect(func(on: bool) -> void:
				Settings.set_option(key, on)
				_apply())
			c = cb
		else:
			var ob := OptionButton.new()
			for choice in opt[3]:
				ob.add_item(choice[1])
			var choices: Array = opt[3]
			ob.item_selected.connect(func(i: int) -> void:
				Settings.set_option(key, choices[i][0])
				_apply())
			c = ob
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(c)
		list.add_child(row)
		_adv_controls[key] = c
		_adv_rows[key] = row
	return list


## A slider row that saves when you let go.
func _slider(box: Control, label: String, lo: float, hi: float, step: float, set_value: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var shown := UI.label("", 15, UI.TEXT_SOFT)
	shown.custom_minimum_size = Vector2(52, 0)
	s.set_meta("shown", shown)
	s.value_changed.connect(func(v: float) -> void:
		set_value.call(v)
		shown.text = "%d%%" % int(round(v * 100)))
	s.drag_ended.connect(func(_c: bool) -> void: _apply())
	row.add_child(s)
	row.add_child(shown)
	_row(box, label, row)
	return s


func _build_welcome() -> Control:
	var root := _dimmed()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var title := UI.header("Welcome to KianCraft!", 26)
	box.add_child(title)
	var text := UI.label("Would you like tips while you play?\nThey explain the controls and what things do.", 17, UI.TEXT_SOFT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var yes := UI.button("Yes, show tips", "GreenButton", 18)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.custom_minimum_size = Vector2(0, 46)
	yes.pressed.connect(func() -> void: _answer_welcome(true))
	row.add_child(yes)
	var no := UI.button("No thanks", "Button", 18)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(0, 46)
	no.pressed.connect(func() -> void: _answer_welcome(false))
	row.add_child(no)
	box.add_child(row)
	var later := UI.label("You can change this any time in Settings, or press ? in any window.", 13, UI.TEXT_SOFT)
	later.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(later)
	return root


func _answer_welcome(tips: bool) -> void:
	Settings.show_tips = tips
	Settings.first_run = false
	_welcome.visible = false
	_apply()


func _apply() -> void:
	Settings.apply(get_tree())
	_refresh()


func _refresh() -> void:
	_tag_show.set_pressed_no_signal(Settings.party_tags)
	_chat_size.select(Settings.chat_size)
	_tag_color.select(Settings.tag_color)
	for pair in [[_tag_size, Settings.tag_size], [_tag_alpha, Settings.tag_alpha]]:
		var s: HSlider = pair[0]
		s.set_value_no_signal(pair[1])
		(s.get_meta("shown") as Label).text = "%d%%" % int(round(float(pair[1]) * 100))
	for c in [_tag_size, _tag_color, _tag_alpha]:
		c.get_parent().get_parent().modulate.a = 1.0 if Settings.party_tags else 0.45
	var vh: float = get_viewport().get_visible_rect().size.y if is_inside_tree() else 720.0
	var content: float = _scroll.get_child(0).get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(600, clampf(content, 200.0, vh - 150.0))
	_mode.select(Settings.window_mode)
	_res.select(Settings.resolution)
	_res_note.text = "The game fills your screen; 3D is drawn at this resolution (lower = faster)." \
			if Settings.window_mode != 0 else "The window opens at this size (it shrinks to fit smaller screens)."
	var custom := Settings.is_custom()
	for i in _quality_buttons.size():
		_quality_buttons[i].set_pressed_no_signal(i == Settings.quality and not custom)
	_quality_text.text = ("Custom (based on %s): your own mix from Advanced." % Settings.QUALITY_NAMES[Settings.quality]) \
			if custom else QUALITY_TEXT[Settings.quality]
	_renderer.select(Settings.renderer)
	if Settings.renderer != Settings.running_renderer():
		_renderer_note.text = "Restart KianCraft to switch renderer."
	elif Settings.renderer == 1:
		_renderer_note.text = "Classic works on almost any PC, but has no god rays, corner shadows or bounced light."
	else:
		_renderer_note.text = "Modern uses Vulkan for real-time light and shadows."
	_adv_button.text = "Hide advanced graphics" if _adv_box.visible else "Show advanced graphics"
	for opt in Settings.GFX_OPTIONS:
		var key: String = opt[0]
		var c: Control = _adv_controls[key]
		var v = Settings.gfx[key]
		if c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(bool(v))
		else:
			var choices: Array = opt[3]
			var best := 0
			for i in choices.size():
				if absf(float(choices[i][0]) - float(v)) < absf(float(choices[best][0]) - float(v)):
					best = i
			(c as OptionButton).select(best)
		_adv_rows[key].visible = Settings.modern() or not key in Settings.MODERN_ONLY
	_sens.set_value_no_signal(Settings.mouse_sensitivity)
	_sens_label.text = "%.2fx" % Settings.mouse_sensitivity
	_tips.set_pressed_no_signal(Settings.show_tips)
	for key in _volumes:
		var x: float = Settings.get_volume(key)
		_volumes[key][0].set_value_no_signal(x)
		_volumes[key][1].text = "%d%%" % int(round(x * 100))
