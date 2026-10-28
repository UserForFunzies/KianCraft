extends CanvasLayer

const MobData = preload("res://scripts/mob_data.gd")
## Everything drawn over the game: hearts, toots, the hotbar, friendly hints
## about what you're looking at, chat, and the pause / death screens.
## Looks come from ui_theme.gd.

const Items = preload("res://scripts/items.gd")
const Inv = preload("res://scripts/inventory.gd")
const Recipes = preload("res://scripts/recipes.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Settings = preload("res://scripts/settings.gd")

signal resume_requested
signal leave_requested
signal chat_submitted(text: String)
signal respawn_requested
signal trade_answered(from_peer: int, yes: bool)
signal party_answered(from_peer: int, yes: bool)
signal wake_requested
signal settings_requested

const CHAT_VISIBLE_SECONDS := 10.0
const CHAT_MAX_LINES := 60
const MAX_HEALTH := 20.0
const SLOT_SIZE := 58
## Shown on the pause screen (and with F1): [keys, what they do]
const CONTROLS := [
	["W A S D", "Walk"], ["Space", "Jump / swim up"], ["Ctrl", "Run"], ["Shift", "Sneak"],
	["Hold left click", "Mine / attack"], ["Right click", "Use, open, eat or place"],
	["E", "Inventory and crafting"], ["1 - 9 or wheel", "Pick a hotbar slot"],
	["Q", "Drop one (Ctrl+Q = all)"], ["M", "Map (if you have one)"], ["P", "Party"], ["F", "Use your boss power"], ["T", "Chat"], ["Esc", "Pause"],
]

var player: Node            # the local player, set via bind_player()
var _invite_kind := "trade"
var _disc: PanelContainer           # "New recipes unlocked at the Research Table"
var _disc_icon: TextureRect
var _disc_name: Label
var _disc_more: Label
var _disc_queue: Array = []
var _disc_t := 0.0                  # time on the current one
var _disc_slide := 0.0              # 0 = hidden off the right edge, 1 = in place
const DISC_EACH := 1.1
const DISC_FAST := 0.55
var _power_chip: PanelContainer
var players_root: Node      # used to count players
var day_night: Node         # for the clock
var survival: Node          # for inventory, health and toots
var mobs: Node              # for the boss health bar
var _shields: Array[TextureRect] = []
var _bubbles: Array[TextureRect] = []
var _bubble_row: HBoxContainer
var _shield_row: HBoxContainer
var _boss_box: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _invite: PanelContainer
var _invite_label: Label
var _invite_from := 0
var _invite_time := 0.0
var _sleep: Control
var _sleep_label: Label
var _legend: PanelContainer
var _legend_name: Label
var _legend_time := 0.0
var _status_row: HBoxContainer
var _cold_icon: Control
var _fairy_icon: Control
var _fairy_text: Label
var _debug: Label
var _debug_pill: PanelContainer
signal pvp_toggle_requested(on: bool)
signal lock_commands_requested
var _world_win: Control
var _world_box: VBoxContainer
var _world_info := {}
var _world_pvp := false
var _world_host := false
var _lock_armed := false
var debug_on := false
var _clock_label: Label
var _toots_label: Label
var _hearts: Array[TextureRect] = []
var _slots: Array[Button] = []
var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _item_pill: PanelContainer
var _item_name: Label
var _item_name_time := 0.0
var _look_pill: PanelContainer
var _look_title: Label
var _look_hint: Label
var _notice_pill: PanelContainer
var _notice: Label
var _notice_time := 0.0
var _hurt_overlay: ColorRect
var _chat_bg: PanelContainer
var _chat_log: VBoxContainer
var _chat_input: LineEdit
var _chat_times: Array[float] = []
var _chat_head: Control
## Chat sizes (Settings): [width, lines shown, text size].
const CHAT_SIZES := [[380, 6, 15], [480, 9, 16], [600, 12, 18]]
## News of what's happening (bosses, deaths, sleeping...): little cards that
## slide in at the top, like new recipes do. They don't open the chat.
var _event: PanelContainer
var _event_icon: TextureRect
var _event_text: Label
var _event_queue: Array = []
var _event_t := 0.0
var _event_slide := 0.0
var events_seen: Array[String] = []     # recent news (for tests and the log)
const EVENT_SECONDS := 3.6
var _controls_win: Control
var _pause: Control
var _session_label: Label
var _death: Control
var _death_label: Label
var _help_card: PanelContainer
var _help_hint: Label
var _pause_controls: PanelContainer
var _clock := 0.0
var _last_health := MAX_HEALTH
var _shake := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hurt_overlay = ColorRect.new()
	_hurt_overlay.color = Color(0.85, 0.0, 0.0, 0.0)
	_hurt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt_overlay)

	_build_crosshair(root)
	_build_top_bar(root)
	_build_status(root)
	_build_bottom(root)
	_build_chat(root)

	_notice_pill = _pill(root)
	_notice = UI.label("", 22, Color(1.0, 0.93, 0.65))
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_pill.add_child(_notice)
	_center_top(_notice_pill, 70)

	# F3: a small pill at the very top in the middle (never over menus).
	_debug_pill = _pill(root)
	_debug = UI.label("", 13, UI.TEXT_SOFT)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_pill.add_child(_debug)
	_center_top(_debug_pill, 6)
	_debug_pill.visible = false

	_help_card = _controls_card(2)
	_help_card.visible = false
	root.add_child(_help_card)
	_help_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_build_events(root)

	_build_boss_bar(root)
	_build_invite(root)
	_build_legendary(root)
	_build_discoveries(root)
	_build_pause_menu()
	_build_death_screen()
	update_tips()
	_build_sleep_screen()


# --- Building --------------------------------------------------------------------------

func _pill(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "PillPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## Keeps a control centered horizontally, `y` pixels from the top.
func _center_top(c: Control, y: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_top = y


func _build_crosshair(root: Control) -> void:
	var cross := Control.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	for r in [Rect2(-11, -2, 22, 4), Rect2(-2, -11, 4, 22)]:
		var shadow := ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.45)
		shadow.position = r.position + Vector2(1, 1)
		shadow.size = r.size
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(shadow)
	for r in [Rect2(-10, -1, 20, 2), Rect2(-1, -10, 2, 20)]:
		var bar := ColorRect.new()
		bar.color = Color(1, 1, 1, 0.9)
		bar.position = r.position
		bar.size = r.size
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(bar)
	# What you're looking at, just under the crosshair.
	_look_pill = PanelContainer.new()
	_look_pill.theme_type_variation = "PillPanel"
	_look_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_look_title = UI.label("", 18)
	_look_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_look_title)
	_look_hint = UI.label("", 15, UI.TEXT_SOFT)
	_look_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_look_hint)
	_look_pill.add_child(box)
	root.add_child(_look_pill)
	_look_pill.anchor_left = 0.5
	_look_pill.anchor_right = 0.5
	_look_pill.anchor_top = 0.5
	_look_pill.anchor_bottom = 0.5
	_look_pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_look_pill.offset_top = 34


func _build_top_bar(root: Control) -> void:
	var clock_pill := _pill(root)
	clock_pill.position = Vector2(14, 12)
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 12)
	_clock_label = UI.label("", 16)
	clock_row.add_child(_clock_label)
	# The "?" reminds you where the controls are; F1 opens them.
	_help_hint = UI.label("?", 15, UI.TEXT_SOFT)
	clock_row.add_child(_help_hint)
	clock_pill.add_child(clock_row)

	var toots_pill := _pill(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UI.icon_rect(Items.coin_icon(), 30))
	_toots_label = UI.label("0", 20, UI.GOLD)
	row.add_child(_toots_label)
	toots_pill.add_child(row)
	toots_pill.anchor_left = 1.0
	toots_pill.anchor_right = 1.0
	toots_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toots_pill.offset_right = -14
	toots_pill.offset_top = 12


## Status effects (below the clock): a snowflake when you're freezing, and
## your fairy's power while it's with you.
func _build_status(root: Control) -> void:
	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(14, 58)
	_status_row.add_theme_constant_override("separation", 8)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_status_row)
	_cold_icon = _status_chip(Items.snowflake_icon(), "Freezing!", Color(0.65, 0.85, 1.0))
	_fairy_icon = _status_chip(Items.sparkle_icon(), "", Color.WHITE)
	_fairy_text = _fairy_icon.get_meta("label")
	_power_chip = _status_chip(Items.icon("trophy_yeti"), "", UI.GOLD)


func _status_chip(icon: Texture2D, text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.theme_type_variation = "PillPanel"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var ic := UI.icon_rect(icon, 22)
	ic.modulate = color
	row.add_child(ic)
	var l := UI.label(text, 14, color)
	row.add_child(l)
	pill.add_child(row)
	pill.set_meta("label", l)
	pill.set_meta("icon", ic)
	pill.visible = false
	_status_row.add_child(pill)
	return pill


func _build_bottom(root: Control) -> void:
	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 6)

	_item_pill = PanelContainer.new()
	_item_pill.theme_type_variation = "PillPanel"
	_item_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_item_name = UI.label("", 20)
	_item_pill.add_child(_item_name)
	bottom.add_child(_item_pill)

	_bubble_row = HBoxContainer.new()
	_bubble_row.add_theme_constant_override("separation", 6)
	_bubble_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 10:
		var b := UI.icon_rect(Items.bubble_icon(), 22)
		_bubble_row.add_child(b)
		_bubbles.append(b)
	_bubble_row.visible = false
	bottom.add_child(_bubble_row)

	_shield_row = HBoxContainer.new()
	_shield_row.add_theme_constant_override("separation", 4)
	_shield_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in int(MAX_HEALTH / 2):
		var sh := UI.icon_rect(Items.shield_icon("full"), 24)
		_shield_row.add_child(sh)
		_shields.append(sh)
	bottom.add_child(_shield_row)

	var hearts := HBoxContainer.new()
	hearts.add_theme_constant_override("separation", 2)
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in int(MAX_HEALTH / 2):
		var h := UI.icon_rect(Items.heart_icon("full"), 26)
		hearts.add_child(h)
		_hearts.append(h)
	bottom.add_child(hearts)

	var bar_box := HBoxContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_box.add_theme_constant_override("separation", 5)
	bottom.add_child(bar_box)
	for i in Inv.HOTBAR_SIZE:
		var slot := Button.new()
		slot.theme_type_variation = "SlotButton"
		slot.toggle_mode = true
		var chosen := UI.slot_style("selected")
		slot.add_theme_stylebox_override("pressed", chosen)
		slot.add_theme_stylebox_override("hover_pressed", chosen)
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.focus_mode = Control.FOCUS_NONE
		var icon := UI.icon_rect(null, SLOT_SIZE - 14)
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 7
		icon.offset_top = 7
		icon.offset_right = -7
		icon.offset_bottom = -7
		slot.add_child(icon)
		var num := UI.label(str(i + 1), 12, Color(1, 1, 1, 0.5))
		num.position = Vector2(6, 2)
		slot.add_child(num)
		var count := UI.label("", 16, Color.WHITE, 5)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -34
		count.offset_top = -24
		count.offset_right = -5
		count.offset_bottom = -2
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.add_child(count)
		bar_box.add_child(slot)
		_slots.append(slot)
		_slot_icons.append(icon)
		_slot_counts.append(count)
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 14)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_chat(root: Control) -> void:
	# A small dark scroll with a gold edge, in the bottom-left corner. It grows
	# upward as lines come in and only shows the newest few.
	_chat_bg = PanelContainer.new()
	_chat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.045, 0.72)
	sb.border_color = Color(UI.GOLD, 0.55)
	sb.border_width_left = 2
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_right = 1
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	_chat_bg.add_theme_stylebox_override("panel", sb)
	_chat_bg.anchor_top = 1.0
	_chat_bg.anchor_bottom = 1.0
	_chat_bg.offset_left = 14
	_chat_bg.offset_bottom = -64
	_chat_bg.offset_top = -64
	_chat_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_chat_bg)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	_chat_bg.add_child(col)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	head.add_child(UI.make_title(UI.label("Chat", 14)))
	head.add_child(UI.accent_line())
	head.visible = false
	_chat_head = head
	col.add_child(head)
	_chat_log = VBoxContainer.new()
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_theme_constant_override("separation", 2)
	col.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something!  (Enter = send, Esc = cancel)"
	_chat_input.max_length = 200
	_chat_input.anchor_top = 1.0
	_chat_input.anchor_bottom = 1.0
	_chat_input.offset_left = 14
	_chat_input.offset_top = -58
	_chat_input.offset_bottom = -14
	_chat_input.visible = false
	apply_chat_size.call_deferred()
	Settings.on_changed(apply_chat_size)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	_chat_input.gui_input.connect(_on_chat_gui_input)
	root.add_child(_chat_input)


## The chat's width and text size from Settings (Small by default).
func apply_chat_size() -> void:
	if _chat_bg == null or not is_instance_valid(_chat_bg):
		return
	var sz: Array = CHAT_SIZES[clampi(Settings.chat_size, 0, CHAT_SIZES.size() - 1)]
	_chat_bg.offset_right = 14 + sz[0]
	_chat_input.offset_right = 14 + sz[0]
	for l in _chat_log.get_children():
		(l as Label).add_theme_font_size_override("font_size", sz[2])
		(l as Label).custom_minimum_size.x = sz[0] - 26


## pairs: how many [key, what it does] pairs side by side.
func _controls_card(pairs := 1) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 2 * pairs
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	for c in CONTROLS:
		var chip := PanelContainer.new()
		chip.theme_type_variation = "PillPanel"
		var k := UI.label(c[0], 14, UI.GOLD)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(k)
		grid.add_child(chip)
		grid.add_child(UI.label(c[1], 15, UI.TEXT_SOFT))
	card.add_child(grid)
	return card


func _build_boss_bar(root: Control) -> void:
	_boss_box = PanelContainer.new()
	_boss_box.theme_type_variation = "PillPanel"
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	_boss_name = UI.label("King Cougar", 22, Color(1.0, 0.75, 0.25), 6)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.max_value = 1.0
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(460, 20)
	_boss_bar.add_theme_stylebox_override("fill", UI.box(Color(0.9, 0.25, 0.2), 8, 0, UI.GOLD, 0))
	box.add_child(_boss_bar)
	_boss_box.add_child(box)
	root.add_child(_boss_box)
	_center_top(_boss_box, 14)
	_boss_box.visible = false


func _build_invite(root: Control) -> void:
	_invite = PanelContainer.new()
	_invite.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_invite_label = UI.label("", 22)
	_invite_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_invite_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UI.button("Yes! (Y)", "GreenButton", 20)
	yes.custom_minimum_size = Vector2(150, 50)
	yes.pressed.connect(func() -> void: answer_invite(true))
	row.add_child(yes)
	var no := UI.button("No (N)", "RedButton", 20)
	no.custom_minimum_size = Vector2(130, 50)
	no.pressed.connect(func() -> void: answer_invite(false))
	row.add_child(no)
	box.add_child(row)
	_invite.add_child(box)
	root.add_child(_invite)
	_center_top(_invite, 110)
	_invite.visible = false


## A small panel that slides in from the right and runs through recipes
## you've just discovered, one after another.
## News card: slides down at the top of the screen, one piece of news at a time.
func _build_events(root: Control) -> void:
	_event = PanelContainer.new()
	_event.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event.add_theme_stylebox_override("panel", UI.card(UI.Art.GOLD_DIM, 12.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.slot_style("selected"))
	frame.custom_minimum_size = Vector2(38, 38)
	_event_icon = UI.icon_rect(null, 28)
	frame.add_child(_event_icon)
	row.add_child(frame)
	_event_text = UI.label("", 15, UI.TEXT, 3)
	_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_text.custom_minimum_size = Vector2(290, 0)
	_event_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_event_text)
	_event.add_child(row)
	root.add_child(_event)
	_event.visible = false


## icon: an item id ("" = a little gold star). color: the text color.
func show_event(text: String, icon := "", color := UI.TEXT) -> void:
	events_seen.append(text)
	if events_seen.size() > 40:
		events_seen.remove_at(0)
	if _event_queue.size() > 6:
		_event_queue.pop_front()   # lots happening at once: skip the oldest
	_event_queue.append([text, icon, color])
	if not _event.visible:
		_event.visible = true
		_event_t = 0.0
		_show_next_event()


func _show_next_event() -> void:
	if _event_queue.is_empty():
		return
	var e: Array = _event_queue[0]
	_event_text.text = e[0]
	_event_text.add_theme_color_override("font_color", e[2])
	var icon: String = e[1]
	_event_icon.texture = Items.icon(icon) if icon != "" and Items.exists(icon) else Items.icon("gold_ingot")
	_event.reset_size()


func _tick_events(delta: float) -> void:
	if _event == null or not _event.visible:
		return
	var want := 1.0 if not _event_queue.is_empty() else 0.0
	_event_slide = move_toward(_event_slide, want, delta * 4.0)
	# Slides in from the right (like new recipes), above the recipe card.
	var view := get_viewport().get_visible_rect().size
	var w := maxf(_event.size.x, _event.get_combined_minimum_size().x)
	_event.size.x = w
	var y := 70.0
	_event.position = Vector2(view.x - (w + 18.0) * smoothstep(0.0, 1.0, _event_slide), y)
	_event.modulate.a = clampf(_event_slide * 1.5, 0.0, 1.0)
	if _event_queue.is_empty():
		if _event_slide <= 0.0:
			_event.visible = false
		return
	_event_t += delta
	var each := EVENT_SECONDS * (0.6 if _event_queue.size() > 2 else 1.0)
	if _event_t >= each:
		_event_t = 0.0
		_event_queue.pop_front()
		if not _event_queue.is_empty():
			_show_next_event()


func _build_discoveries(root: Control) -> void:
	_disc = PanelContainer.new()
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.custom_minimum_size = Vector2(330, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(UI.icon_rect(Items.icon("research_table"), 30))
	var t := UI.make_title(UI.label("New recipes unlocked\nat the Research Table", 16))
	head.add_child(t)
	box.add_child(head)
	box.add_child(UI.accent_line())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.slot_style("selected"))
	frame.custom_minimum_size = Vector2(46, 46)
	_disc_icon = UI.icon_rect(null, 36)
	frame.add_child(_disc_icon)
	row.add_child(frame)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	_disc_name = UI.label("", 18)
	_disc_name.add_theme_font_override("font", UI.title_font())
	names.add_child(_disc_name)
	_disc_more = UI.label("", 13, UI.TEXT_SOFT)
	names.add_child(_disc_more)
	row.add_child(names)
	box.add_child(row)
	root.add_child(_disc)
	_disc.visible = false


func show_discoveries(ids: Array) -> void:
	for id in ids:
		if not id in _disc_queue:
			_disc_queue.append(id)
	if not _disc.visible:
		_disc.visible = true
		_disc_t = 0.0
		_show_next_discovery()


func _show_next_discovery() -> void:
	if _disc_queue.is_empty():
		return
	var id: String = _disc_queue[0]
	_disc_icon.texture = Items.icon(id)
	_disc_name.text = Items.display_name(id)
	_disc_name.add_theme_color_override("font_color", preload("res://scripts/item_card.gd").color(id))
	_disc_more.text = "+%d more" % (_disc_queue.size() - 1) if _disc_queue.size() > 1 else ""


func _tick_discoveries(delta: float) -> void:
	if _disc == null or not _disc.visible:
		return
	var want := 1.0 if not _disc_queue.is_empty() else 0.0
	_disc_slide = move_toward(_disc_slide, want, delta * 4.0)
	var view := get_viewport().get_visible_rect().size
	var w := _disc.size.x
	_disc.position = Vector2(view.x - (w + 18.0) * smoothstep(0.0, 1.0, _disc_slide), view.y * 0.32)
	if _disc_queue.is_empty():
		if _disc_slide <= 0.0:
			_disc.visible = false
		return
	_disc_t += delta
	var each := DISC_FAST if _disc_queue.size() > 5 else DISC_EACH
	if _disc_t >= each + (0.6 if _disc_queue.size() == 1 else 0.0):
		_disc_t = 0.0
		_disc_queue.pop_front()
		_show_next_discovery()


func _build_legendary(root: Control) -> void:
	_legend = PanelContainer.new()
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.add_theme_stylebox_override("panel", UI.card(Color(1.0, 0.55, 0.1), 18.0))
	var box := VBoxContainer.new()
	var top := UI.label("LEGENDARY!", 34, Color(1.0, 0.55, 0.1), 8)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top)
	_legend_name = UI.label("", 24, Color(1.0, 0.82, 0.4))
	_legend_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_legend_name)
	var hint := UI.label("Grab your treasure from the King's body!", 17, UI.TEXT_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_legend.add_child(box)
	root.add_child(_legend)
	_center_top(_legend, 150)
	_legend.visible = false


func _build_sleep_screen() -> void:
	_sleep = Control.new()
	_sleep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep.visible = false
	add_child(_sleep)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.12, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sleep.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := UI.label("Zzz...", 60, Color(0.75, 0.82, 1.0), 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_sleep_label = UI.label("Sweet dreams!", 20, UI.TEXT_SOFT)
	_sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sleep_label)
	var up := UI.button("Get up", "BlueButton", 22)
	up.custom_minimum_size = Vector2(200, 56)
	up.pressed.connect(func() -> void: wake_requested.emit())
	box.add_child(up)


## The boss power: what it is and how long is left (or until it's back).
func _update_power_chip() -> void:
	if survival == null or _power_chip == null:
		return
	var chosen: String = survival.me.get("power", {}).get("chosen", "")
	var boss: Dictionary = preload("res://scripts/boss_data.gd").get_boss(chosen)
	_power_chip.visible = not boss.is_empty() and survival.trophies.has(chosen)
	if not _power_chip.visible:
		return
	var t: Vector2 = survival.power_times()
	var l: Label = _power_chip.get_meta("label")
	var ic: TextureRect = _power_chip.get_meta("icon")
	ic.texture = Items.icon("trophy_" + chosen)
	ic.modulate = Color.WHITE
	if t.x > 0.0:
		l.text = "%s  %s" % [boss["power"], survival.mmss(t.x)]
		l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	elif t.y > 0.0:
		l.text = "%s back in %s" % [boss["power"], survival.mmss(t.y)]
		l.add_theme_color_override("font_color", UI.TEXT_SOFT)
	else:
		l.text = "%s ready (F)" % boss["power"]
		l.add_theme_color_override("font_color", UI.GOOD)


func show_party_invite(from_peer: int, from_name: String, party_name: String) -> void:
	show_trade_invite(from_peer, from_name)
	_invite_kind = "party"
	_invite_label.text = "%s wants you to join %s!" % [from_name, party_name] if party_name != "%s's Party" % from_name else "%s wants you to join their party!" % from_name


func show_trade_invite(from_peer: int, from_name: String) -> void:
	_invite_kind = "trade"
	_invite_from = from_peer
	_invite_time = 30.0
	_invite_label.text = "%s wants to trade with you!" % from_name
	_invite.visible = true


func answer_invite(yes: bool) -> void:
	if _invite.visible:
		_invite.visible = false
		if _invite_kind == "party":
			party_answered.emit(_invite_from, yes)
		else:
			trade_answered.emit(_invite_from, yes)


func has_invite() -> bool:
	return _invite.visible


func show_sleep(on: bool) -> void:
	_sleep.visible = on
	_sleep_label.text = "Sweet dreams! Waiting for everyone to go to bed..."


func is_sleeping_screen() -> bool:
	return _sleep.visible


func show_legendary(item: String) -> void:
	_legend_name.text = Items.display_name(item)
	_legend_time = 6.0
	_legend.visible = true


func _build_pause_menu() -> void:
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(360, 0)
	panel.add_child(box)
	box.add_child(UI.header("Paused", 30))
	_session_label = UI.label("", 14, UI.TEXT_SOFT)
	_session_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_session_label)
	box.add_child(HSeparator.new())
	var resume := UI.button("Resume", "GreenButton", 18)
	resume.custom_minimum_size = Vector2(0, 46)
	resume.pressed.connect(func() -> void: resume_requested.emit())
	box.add_child(resume)
	var settings := UI.button("Settings", "Button", 17)
	settings.custom_minimum_size = Vector2(0, 42)
	settings.pressed.connect(func() -> void: settings_requested.emit())
	box.add_child(settings)
	var help := UI.button("Controls", "Button", 17)
	help.custom_minimum_size = Vector2(0, 42)
	box.add_child(help)
	help.pressed.connect(func() -> void:
		_controls_win.visible = true
		center.visible = false)
	var world_b := UI.button("World details", "Button", 17)
	world_b.custom_minimum_size = Vector2(0, 42)
	box.add_child(world_b)
	world_b.pressed.connect(func() -> void:
		_lock_armed = false
		_draw_world_panel()
		_world_win.visible = true
		center.visible = false)
	# The world's details and rules (PvP, host commands) get their own window.
	_world_win = Control.new()
	_world_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_win.visible = false
	_pause.add_child(_world_win)
	var wc := CenterContainer.new()
	wc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_win.add_child(wc)
	var wpanel := PanelContainer.new()
	wc.add_child(wpanel)
	var wouter := VBoxContainer.new()
	wouter.add_theme_constant_override("separation", 12)
	wouter.custom_minimum_size = Vector2(460, 0)
	wpanel.add_child(wouter)
	wouter.add_child(UI.header("World", 28))
	_world_box = VBoxContainer.new()
	_world_box.add_theme_constant_override("separation", 10)
	wouter.add_child(_world_box)
	var wback := UI.button("Back", "GreenButton", 17)
	wback.custom_minimum_size = Vector2(0, 42)
	wback.pressed.connect(func() -> void:
		_world_win.visible = false
		center.visible = true)
	wouter.add_child(wback)
	# The controls get their own window (two columns, so it fits any screen).
	_controls_win = Control.new()
	_controls_win.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_win.visible = false
	_pause.add_child(_controls_win)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_win.add_child(cc)
	var cpanel := PanelContainer.new()
	cc.add_child(cpanel)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 12)
	cpanel.add_child(cbox)
	cbox.add_child(UI.header("Controls", 28))
	_pause_controls = _controls_card(2)
	cbox.add_child(_pause_controls)
	var back := UI.button("Back", "GreenButton", 17)
	back.custom_minimum_size = Vector2(0, 42)
	back.pressed.connect(func() -> void:
		_controls_win.visible = false
		center.visible = true)
	cbox.add_child(back)
	_pause.set_meta("menu", center)
	box.add_child(HSeparator.new())
	var leave := UI.button("Save and quit to menu", "Button", 16)
	leave.custom_minimum_size = Vector2(0, 40)
	leave.pressed.connect(func() -> void: leave_requested.emit())
	box.add_child(leave)


func _build_death_screen() -> void:
	_death = Control.new()
	_death.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.visible = false
	add_child(_death)
	var dim := ColorRect.new()
	dim.color = Color(0.35, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(420, 0)
	panel.add_child(box)
	var title := UI.label("Oh no!", 52, UI.RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_death_label = UI.label("", 20)
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_death_label)
	var respawn := UI.button("Try again!", "GreenButton", 28)
	respawn.custom_minimum_size = Vector2(0, 70)
	respawn.pressed.connect(func() -> void: respawn_requested.emit())
	box.add_child(respawn)


# --- Updating --------------------------------------------------------------------------

func bind_player(p: Node) -> void:
	player = p
	if not p.hotbar_changed.is_connected(_on_hotbar_changed):
		p.hotbar_changed.connect(_on_hotbar_changed)
	refresh()


func _on_hotbar_changed(_i: int) -> void:
	refresh()
	_item_name_time = 2.5  # show the item's name for a moment


## Redraws hotbar, hearts and toots from the latest survival state.
func refresh() -> void:
	if survival == null:
		return
	var selected: int = player.hotbar_index if player and is_instance_valid(player) else 0
	for i in _slots.size():
		_slots[i].button_pressed = i == selected
		# The slot you're holding: bigger, a bright gold frame, full color.
		# The others step back a little so it's easy to see which one it is.
		_slots[i].pivot_offset = _slots[i].size * 0.5
		_slots[i].scale = Vector2.ONE * (1.14 if i == selected else 1.0)
		_slots[i].z_index = 1 if i == selected else 0
		_slot_icons[i].modulate = Color(1, 1, 1, 1) if i == selected else Color(0.78, 0.78, 0.82, 0.85)
		var s: Dictionary = survival.my_slot(i)
		_slot_icons[i].texture = Items.icon(s["id"]) if not s.is_empty() else null
		_slot_counts[i].text = str(s["count"]) if s.get("count", 0) > 1 else ""
	var held: Dictionary = survival.my_slot(selected)
	_item_name.text = Items.display_name(held["id"]) if not held.is_empty() else "Empty hand"
	var hp: float = survival.me.get("health", MAX_HEALTH)
	for i in _hearts.size():
		var v := hp - i * 2.0
		_hearts[i].texture = Items.heart_icon("full" if v >= 2.0 else ("half" if v >= 1.0 else "empty"))
	if hp < _last_health:
		_shake = 0.4
	_last_health = hp
	_toots_label.text = ("%.1f" % survival.me.get("toots", 0.0)).trim_suffix(".0")
	var air: float = survival.me.get("air", 10.0)
	var air_max_now: float = survival.me.get("air_max", 10.0)
	_bubble_row.visible = air < air_max_now - 0.01
	for i in _bubbles.size():
		_bubbles[i].modulate.a = 1.0 if i < ceili(air / air_max_now * 10.0) else 0.0
	_cold_icon.visible = survival.me.get("freezing", false)
	var buff: Dictionary = survival.me.get("buff", {})
	_fairy_icon.visible = not buff.is_empty()
	if not buff.is_empty():
		var c: Color = preload("res://scripts/mob_data.gd").FAIRY_COLORS[buff["color"]][1]
		_fairy_icon.get_meta("icon").modulate = c
		_fairy_text.add_theme_color_override("font_color", c)
		_fairy_text.text = "%s: %s" % [buff["name"], buff["text"]] if Settings.show_tips else buff["name"]
	var air_max: float = survival.me.get("air_max", 10.0)
	var armor: int = survival.me.get("armor", 0)
	_shield_row.modulate.a = 1.0 if armor > 0 else 0.0
	# 10 shields = blocking everything: each half shield is 5% of a hit blocked.
	var halves := roundi(float(survival.me.get("protect", 0.0)) * 20.0)
	for i in _shields.size():
		var v := halves - i * 2
		_shields[i].texture = Items.shield_icon("full" if v >= 2 else ("half" if v >= 1 else "empty"))


## 3, 2, 1, FIGHT! in big letters in the middle of the screen.
func show_countdown() -> void:
	if _countdown == null:
		_countdown = UI.label("", 120, UI.TITLE, 10)
		_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
		_countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_countdown.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
		get_child(0).add_child(_countdown)
	countdown_seen.clear()
	for i in 4:
		var word: String = ["3", "2", "1", "FIGHT!"][i]
		countdown_seen.append(word)
		_countdown.text = word
		_countdown.add_theme_color_override("font_color", UI.TITLE if i < 3 else Color(1.0, 0.35, 0.2))
		_countdown.modulate.a = 1.0
		_countdown.scale = Vector2.ONE
		_countdown.pivot_offset = get_viewport().get_visible_rect().size * 0.5
		var tw := create_tween()
		tw.tween_property(_countdown, "scale", Vector2.ONE * (1.25 if i == 3 else 0.85), 0.9)
		preload("res://scripts/sound.gd").play("unlock" if i < 3 else "legendary", -4.0, 1.0 if i < 3 else 1.1, "Interface")
		await get_tree().create_timer(1.0).timeout
	_countdown.text = ""


var _countdown: Label
var countdown_seen: Array = []


func show_notice(text: String) -> void:
	_notice.text = text
	_notice_time = 3.5


func flash_hurt() -> void:
	_hurt_overlay.color.a = 0.35


func show_death(cause: String) -> void:
	_death_label.text = "You %s.\n\nDon't worry! Your things are in a bag where you fell. Go get them back!" % cause
	_death.visible = true


func hide_death() -> void:
	_death.visible = false


func is_dead_screen() -> bool:
	return _death.visible


func set_paused(paused: bool) -> void:
	_pause.visible = paused
	_controls_win.visible = false
	_world_win.visible = false
	(_pause.get_meta("menu") as Control).visible = true


## Tips on: "? F1 controls" in the corner. Off: just a small "?".
func update_tips() -> void:
	if _help_hint:
		_help_hint.text = "?  F1 controls" if Settings.show_tips else "?"


func is_paused() -> bool:
	return _pause.visible


## The world's details and rules (from main.gd whenever they change).
func set_world_info(info: Dictionary, pvp_now: bool, is_host: bool) -> void:
	_world_info = info
	_world_pvp = pvp_now
	_world_host = is_host
	if _world_win and _world_win.visible:
		_draw_world_panel()


func _draw_world_panel() -> void:
	for c in _world_box.get_children():
		_world_box.remove_child(c)
		c.queue_free()
	var info := _world_info
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	var created := int(info.get("created", 0))
	var mins := int(float(info.get("play_time", 0.0)) / 60.0)
	var mode := str(info.get("pvp", "off"))
	var rows := [
		["Name", str(info.get("name", "?")), UI.TEXT],
		["Seed", str(info.get("seed", "?")), UI.TEXT],
		["Made", Time.get_datetime_string_from_unix_time(created, true).substr(0, 10) if created > 0 else "long ago", UI.TEXT],
		["Played", "%dh %02dm" % [mins / 60, mins % 60] if mins >= 60 else "%d min" % mins, UI.TEXT],
		["World kind", "Newest lands (gen %d)" % int(info.get("gen", 1)) if int(info.get("gen", 1)) >= 10 else "Older world (gen %d): it stays as it was made" % int(info.get("gen", 1)), UI.TEXT_SOFT],
		["PvP", {"off": "Off", "on": "Always on", "host": ("ON" if _world_pvp else "Off") + " (the host decides)"}.get(mode, "Off"), UI.BAD if _world_pvp else UI.GOOD],
		["Host commands", "Allowed" if info.get("host_commands", true) else "OFF for good: achievements count", UI.TEXT if info.get("host_commands", true) else UI.GOOD],
	]
	for r in rows:
		grid.add_child(UI.label(r[0], 15, UI.TEXT_SOFT))
		var v := UI.label(r[1], 16, r[2])
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(280, 0)
		grid.add_child(v)
	_world_box.add_child(grid)
	if not _world_host:
		return
	_world_box.add_child(UI.accent_line())
	if mode == "host":
		var pb := UI.button("Turn PvP OFF" if _world_pvp else "Turn PvP ON", "RedButton" if not _world_pvp else "BlueButton", 16)
		pb.custom_minimum_size = Vector2(0, 40)
		pb.pressed.connect(func() -> void: pvp_toggle_requested.emit(not _world_pvp))
		_world_box.add_child(pb)
	if info.get("host_commands", true):
		var lb := UI.button("Are you sure? This can't be undone!" if _lock_armed else "Turn host commands off for good...", "RedButton", 15)
		lb.custom_minimum_size = Vector2(0, 40)
		lb.tooltip_text = "No more /give, /fly, /god or the admin panel in this world, ever. Achievements will only count in worlds like that."
		lb.pressed.connect(func() -> void:
			if _lock_armed:
				_lock_armed = false
				lock_commands_requested.emit()
			else:
				_lock_armed = true
				_draw_world_panel())
		_world_box.add_child(lb)


func set_session_text(text: String) -> void:
	_session_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and _invite.visible and not is_chat_open():
		if event.physical_keycode == KEY_Y:
			answer_invite(true)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_N:
			answer_invite(false)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			debug_on = not debug_on
		elif event.physical_keycode == KEY_F1:
			_help_card.visible = not _help_card.visible


# --- Chat ------------------------------------------------------------------------

## sender == "" means a system message (joins, command replies, ...).
func add_chat(sender: String, text: String) -> void:
	var sz: Array = CHAT_SIZES[clampi(Settings.chat_size, 0, CHAT_SIZES.size() - 1)]
	var l := UI.label("", sz[2], UI.TEXT, 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = sz[0] - 26
	if sender.is_empty():
		l.text = text
		l.add_theme_color_override("font_color", Color(0.86, 0.78, 0.6))
	else:
		l.text = "%s:  %s" % [sender, text]
	_chat_log.add_child(l)
	_chat_times.append(_clock)
	while _chat_log.get_child_count() > CHAT_MAX_LINES:
		var old := _chat_log.get_child(0)
		_chat_log.remove_child(old)
		old.queue_free()
		_chat_times.remove_at(0)


func clear_chat() -> void:
	for c in _chat_log.get_children():
		_chat_log.remove_child(c)
		c.queue_free()
	_chat_times.clear()
	close_chat()


func open_chat(prefix := "") -> void:
	_chat_input.visible = true
	_chat_input.text = prefix
	_chat_input.grab_focus.call_deferred()
	_chat_input.set_caret_column.call_deferred(prefix.length())


func close_chat() -> void:
	_chat_input.release_focus()
	_chat_input.visible = false
	_chat_input.text = ""


func is_chat_open() -> bool:
	return _chat_input.visible


func _on_chat_submitted(text: String) -> void:
	text = text.strip_edges()
	close_chat()
	chat_submitted.emit(text)


func _on_chat_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_chat_input.accept_event()
		close_chat()
		chat_submitted.emit("")  # empty = just closed; main.gd re-enables the player


func _process(delta: float) -> void:
	_clock += delta
	_tick_discoveries(delta)
	_tick_events(delta)
	_update_power_chip()
	# Chat lines fade out after a while; while typing the newest few come back.
	var open := is_chat_open()
	var any_visible := false
	var shown: int = CHAT_SIZES[clampi(Settings.chat_size, 0, CHAT_SIZES.size() - 1)][1]
	var n_lines := _chat_log.get_child_count()
	for i in n_lines:
		var age := _clock - _chat_times[i]
		var a := 1.0 if open else clampf(CHAT_VISIBLE_SECONDS + 1.0 - age, 0.0, 1.0)
		var line := _chat_log.get_child(i) as Control
		line.modulate.a = a
		line.visible = a > 0.0 and i >= n_lines - shown
		any_visible = any_visible or line.visible
	_chat_head.visible = open
	_chat_bg.visible = any_visible or open
	if _chat_bg.visible:
		_chat_bg.reset_size()
		_chat_bg.offset_top = _chat_bg.offset_bottom - _chat_bg.get_combined_minimum_size().y

	_notice_time -= delta
	_notice_pill.visible = _notice_time > 0.0 and _notice.text != ""
	_notice_pill.modulate.a = clampf(_notice_time * 2.0, 0.0, 1.0)
	_item_name_time -= delta
	_item_pill.modulate.a = clampf(_item_name_time * 2.0, 0.0, 1.0)
	_hurt_overlay.color.a = maxf(0.0, _hurt_overlay.color.a - delta * 0.8)
	_invite_time -= delta
	if _invite.visible and _invite_time <= 0.0:
		answer_invite(false)
	_legend_time -= delta
	_legend.visible = _legend_time > 0.0
	_legend.modulate.a = clampf(_legend_time, 0.0, 1.0)

	# Hearts wiggle when you get hurt, and blink when you're low.
	_shake = maxf(0.0, _shake - delta)
	var hp: float = survival.me.get("health", MAX_HEALTH) if survival else MAX_HEALTH
	for i in _hearts.size():
		var wiggle := sin(_clock * 40.0 + i) * 3.0 * (_shake / 0.4)
		if hp <= 6.0:
			wiggle += sin(_clock * 8.0 + i * 0.7) * 1.5
		_hearts[i].position.y = wiggle

	if day_night:
		var t: float = day_night.time_of_day()
		var part := "Night"
		if t >= 0.22 and t < 0.3:
			part = "Sunrise"
		elif t >= 0.3 and t < 0.7:
			part = "Day"
		elif t >= 0.7 and t < 0.78:
			part = "Sunset"
		_clock_label.text = "Day %d  -  %s" % [day_night.day_number(), part]

	if player == null or not is_instance_valid(player):
		_look_pill.visible = false
		_debug.text = ""
		return
	# Boss health bar when any boss (King Cougar, Yeti, Grimskull) is near.
	var boss: Node3D = null
	var best := 48.0
	if mobs:
		for m in mobs.all_mobs():
			if m.is_boss():
				var d: float = m.position.distance_to(player.global_position)
				if d < best:
					best = d
					boss = m
	_boss_box.visible = boss != null
	if _boss_box.visible:
		_boss_bar.value = boss.hp_ratio
		_boss_name.text = MobData.display_name(boss.type)
		var bdef := MobData.get_def(boss.type)
		if bdef.has("pair"):
			# The King & Queen share one bar: half each (a fallen one counts as empty).
			var mate_ratio := 0.0
			for m in mobs.all_mobs():
				if m.type == bdef["pair"] and m.position.distance_to(boss.position) < 64.0:
					mate_ratio = m.hp_ratio
			_boss_bar.value = (boss.hp_ratio + mate_ratio) * 0.5
			_boss_name.text = bdef["pair_name"]
	var info: Dictionary = player.look_info
	_look_pill.visible = not info.is_empty() and not open
	if _look_pill.visible:
		_look_title.text = info.get("title", "")
		_look_title.add_theme_color_override("font_color", UI.BAD if info.get("danger", false) else UI.TEXT)
		_look_hint.text = info.get("hint", "")
		# How-to hints only with tips on; warnings ("you need a pickaxe") always.
		_look_hint.visible = _look_hint.text != "" and (Settings.show_tips or info.get("danger", false))
	_debug_pill.visible = debug_on and not open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED   # (hidden while a menu is open)
	if _debug_pill.visible:
		var p: Vector3 = player.global_position
		var count := players_root.get_child_count() if players_root else 1
		_debug.text = "%d FPS   ·   X %d   Y %d   Z %d   ·   %d player%s   ·   F3 hides" % [
			Engine.get_frames_per_second(), floori(p.x), floori(p.y), floori(p.z), count, "" if count == 1 else "s"]
