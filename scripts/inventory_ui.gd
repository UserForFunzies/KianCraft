extends CanvasLayer
## The inventory window. Left: your character (armor + a 3D view of you) and
## your stuff. Right: whatever you opened:
##   E                -> crafting by hand (only the hand recipes)
##   a Workbench      -> tabs for "By hand" and each tier up to that bench
##   a Furnace        -> smelting        a Chest -> storage
##   a Block Shop     -> sell for toots  QtMaMe  -> sell for DOUBLE toots
##   a corpse or bag  -> loot it         another player -> trade
##
## Moving items (like Rust):
##   drag              = move the whole stack
##   middle-drag or Shift+drag = move half      Ctrl+drag = move one
##   right-click       = quick move (box <-> your stuff, hotbar <-> backpack, wear armor)
##   drag out of the window = drop it on the ground
##   click, then click = move (handy on a touchpad)
## Every action is a request to the server (survival.gd); when the new state
## comes back, this window redraws.

const Items = preload("res://scripts/items.gd")
const Recipes = preload("res://scripts/recipes.gd")
const Inv = preload("res://scripts/inventory.gd")
const Blocks = preload("res://scripts/blocks.gd")
const UI = preload("res://scripts/ui_theme.gd")
const ItemSlot = preload("res://scripts/item_slot.gd")
const Avatar = preload("res://scripts/avatar.gd")
const Survival = preload("res://scripts/survival.gd")
const Settings = preload("res://scripts/settings.gd")
const ItemCard = preload("res://scripts/item_card.gd")
const ItemTooltip = preload("res://scripts/item_tooltip.gd")
const Sound = preload("res://scripts/sound.gd")
const MobData = preload("res://scripts/mob_data.gd")
const StatSheet = preload("res://scripts/stat_sheet.gd")

signal closed
signal opened

const SLOT := 52
const TIER_NAMES := ["By hand", "Tier 1", "Tier 2", "Tier 3"]
const PINK := Color(1.0, 0.55, 0.8)
const LEGEND := Color(1.0, 0.55, 0.1)
const HELP := "Drag = move    Shift or middle-drag = half    Ctrl-drag = one\nRight-click = quick move    Drag outside the window = drop    Q in game = drop held item"

var survival: Node
var get_look_dir: Callable          # -> Vector3 (where to throw dropped items)
var mode := ""                      # "craft", "shop", "trader", "furnace", "chest", "loot", "trade"
var station_tier := 0
var station_pos := Vector3i(0, -1, 0)
var tab := 0                        # which recipe tier is showing

var _panel: PanelContainer
var _char_slots: VBoxContainer
var _char_slots2: VBoxContainer    # amulet and ring, beside the armor
var _preview_box: Control           # the turning 3D you
var _sheet_open := false            # showing the character sheet instead of the 3D you
var _preview_vp: SubViewport
var _preview_av: Dictionary
var _preview_root: Node3D
var _stats: VBoxContainer
var _inv_grid: GridContainer
var _hot_grid: GridContainer
var _info: RichTextLabel
var _info_panel: PanelContainer
var _title: Label
var _title_icon: TextureRect
var _tabs: HBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _toots_label: Label
var _drag_icon: TextureRect
var _slots: Array[Control] = []     # every slot on screen (for finding drop targets)
var _selected := {}                 # {"area", "index"} picked by clicking
var _press := {}                    # mouse press that may turn into a drag
var _redraw_pending := false        # an update arrived mid-press; redraw when the mouse is let go
var _dragging := false
var _drag_count := 0
var _shown_armor := ["", "", "", ""]
var _look := {}
var _char_name := "You"
var _help_label: Label
var _help_open := false             # the "?" button: show all how-to text this time
var _tooltip: ItemTooltip
var _only_makeable := false         # workbench filter: only what you can make right now
var _research_tier := 0             # best workbench near the open Research Table


func _ready() -> void:
	layer = 5
	visible = false
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	# Header: title, toots, close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	_title_icon = UI.icon_rect(null, 38)
	header.add_child(_title_icon)
	_title = UI.make_title(UI.label("", 26))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var toots_pill := PanelContainer.new()
	toots_pill.theme_type_variation = "PillPanel"
	var toots_row := HBoxContainer.new()
	toots_row.add_child(UI.icon_rect(Items.coin_icon(), 26))
	_toots_label = UI.label("0", 19, UI.GOLD)
	toots_row.add_child(_toots_label)
	toots_pill.add_child(toots_row)
	header.add_child(toots_pill)
	var help_btn := UI.button("?", "FlatButton", 20)
	help_btn.custom_minimum_size = Vector2(42, 40)
	help_btn.tooltip_text = "How does this work?"
	help_btn.pressed.connect(func() -> void:
		_help_open = not _help_open
		_redraw())
	header.add_child(help_btn)
	var close_btn := UI.button("✕", "FlatButton", 20)
	close_btn.custom_minimum_size = Vector2(42, 40)
	close_btn.tooltip_text = "Close (E or Esc)"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)
	outer.add_child(header)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	outer.add_child(columns)

	# Left: character + your stuff
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	left.add_child(_build_character())
	left.add_child(UI.label("Inventory", 16, UI.TEXT_SOFT))
	_inv_grid = GridContainer.new()
	_inv_grid.columns = 9
	_inv_grid.add_theme_constant_override("h_separation", 4)
	_inv_grid.add_theme_constant_override("v_separation", 4)
	left.add_child(_inv_grid)
	left.add_child(UI.label("Hotbar", 15, UI.TEXT_SOFT))
	_hot_grid = GridContainer.new()
	_hot_grid.columns = 9
	_hot_grid.add_theme_constant_override("h_separation", 4)
	left.add_child(_hot_grid)
	_help_label = UI.label(HELP, 13, UI.TEXT_SOFT)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.custom_minimum_size = Vector2(500, 0)
	left.add_child(_help_label)

	# Right: crafting / shop / furnace / chest / loot / trade, and the info box
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(540, 0)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	right.add_child(_tabs)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)
	var info := PanelContainer.new()
	info.theme_type_variation = "CardPanel"
	info.custom_minimum_size = Vector2(0, 150)
	_info_panel = info
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("normal_font_size", 16)
	_info.add_theme_font_size_override("bold_font_size", 20)
	info.add_child(_info)
	right.add_child(info)
	info.visible = false   # (the floating item pane shows instead)
	_tooltip = ItemTooltip.new()
	root.add_child(_tooltip)

	_drag_icon = UI.icon_rect(null, 52)
	_drag_icon.visible = false
	_drag_icon.z_index = 100
	root.add_child(_drag_icon)


## Armor slots, a turning 3D view of you, and your health/armor numbers.
func _build_character() -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	_char_slots = VBoxContainer.new()
	_char_slots.add_theme_constant_override("separation", 4)
	row.add_child(_char_slots)
	_char_slots2 = VBoxContainer.new()
	_char_slots2.add_theme_constant_override("separation", 4)
	_char_slots2.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_char_slots2)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(150, 220)
	_preview_box = view
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_vp = SubViewport.new()
	_preview_vp.own_world_3d = true
	_preview_vp.transparent_bg = true
	_preview_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view.add_child(_preview_vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.05, -3.3)
	cam.fov = 40
	_preview_vp.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.95, 0))
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 2.6, 0)
	_preview_vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.6
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	_preview_vp.add_child(env)
	_preview_root = Node3D.new()
	_preview_vp.add_child(_preview_root)
	_set_preview_look()
	row.add_child(view)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 6)
	_stats.custom_minimum_size = Vector2(190, 0)
	row.add_child(_stats)
	return card


func set_player_look(look: Dictionary, char_name: String) -> void:
	_look = look
	_char_name = char_name
	if _preview_root:
		_set_preview_look()


func _set_preview_look() -> void:
	for n in _preview_root.get_children():
		n.queue_free()
	_preview_av = Avatar.build(_look if not _look.is_empty() else Avatar.default_look())
	_preview_root.add_child(_preview_av["root"])
	_shown_armor = ["?", "?", "?", "?"]


func bind(s: Node) -> void:
	survival = s
	survival.self_changed.connect(_on_changed)
	survival.container_changed.connect(_on_container_changed)


func is_open() -> bool:
	return visible


## A building bench: "sawmill", "stonecutter" or "shaper".
var build_bench := ""


func open_build(bench: String, pos: Vector3i) -> void:
	mode = "craft"
	build_bench = bench
	station_tier = 0
	station_pos = pos
	tab = 0
	_show()


func open_scribe(pos: Vector3i) -> void:
	mode = "scribe"
	station_pos = pos
	_show()


func open_cute(pos: Vector3i) -> void:
	mode = "cute"
	station_pos = pos
	_show()


func open_research(pos: Vector3i) -> void:
	mode = "research"
	station_pos = pos
	_research_tier = survival.nearby_bench_tier(pos)
	_show()


func open_craft(tier: int, pos: Vector3i) -> void:
	mode = "craft"
	build_bench = ""
	station_tier = tier
	station_pos = pos
	tab = tier  # start on the newest things this bench can make
	_show()


func open_shop(pos: Vector3i) -> void:
	mode = "shop"
	station_pos = pos
	_show()


var villager_id := 0


func open_villager(mob_id: int) -> void:
	mode = "villager"
	villager_id = mob_id
	_show()


func open_trader() -> void:
	mode = "trader"
	_show()


func open_container(kind: String) -> void:
	mode = kind
	_show()


func close() -> void:
	if not visible:
		return
	if _tooltip:
		_tooltip.hide_now()
	if mode in ["furnace", "chest", "loot", "trade", "stand"]:
		survival.req_close.rpc_id(1)
	visible = false
	_end_drag()
	_selected = {}
	mode = ""
	closed.emit()


## Tips setting on, or the "?" button pressed.
func _tips() -> bool:
	return Settings.show_tips or _help_open


## Adds a how-to line, only when tips are wanted.
func _tip(text: String, size := 15) -> void:
	if not _tips():
		return
	var l := UI.label(text, size, UI.TEXT_SOFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	_content.add_child(l)


func redraw() -> void:
	if visible:
		_redraw()


func _show() -> void:
	if not visible:
		opened.emit()
	_help_open = false
	_selected = {}
	visible = true
	_scroll.scroll_vertical = 0
	_set_info({})
	_redraw()


func _process(delta: float) -> void:
	if not visible and _tooltip and _tooltip.visible:
		_tooltip.hide_now()
	if visible and _preview_av.has("root"):
		_preview_av["root"].rotation.y += delta * 0.6
	if _dragging:
		_drag_icon.position = _drag_icon.get_global_mouse_position() - Vector2(26, 26)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _on_changed() -> void:
	if visible:
		_redraw()


func _on_container_changed() -> void:
	if not visible:
		return
	if mode in ["furnace", "chest", "loot", "trade", "stand"] and survival.open_kind == "":
		close()  # it was broken, emptied, or the trade ended
		return
	if mode == "trade" or survival.open_kind == "trade":
		mode = "trade"
	if not _press.is_empty() or _dragging:
		_redraw_pending = true  # the furnace updates a few times a second; don't pull the slot out from under the mouse
		return
	_redraw()


# --- Mouse: clicks, quick moves and dragging ---------------------------------------------

func _slot(area: String, index: int, item, size := SLOT, hint: Texture2D = null) -> Control:
	var s := ItemSlot.new()
	var sel: bool = _selected.get("area", "") == area and _selected.get("index", -1) == index
	s.setup(area, index, item if item != null else {}, size, sel, hint)
	s.pressed_with.connect(_on_slot_pressed)
	s.hovered.connect(_set_info)
	_slots.append(s)
	return s


func _on_slot_pressed(slot: Control, event: InputEventMouseButton) -> void:
	if slot.area == "their":
		return  # you can look, but not touch
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_selected = {}
		if not slot.item.is_empty():
			survival.req_move.rpc_id(1, slot.area, slot.index, "", -1, 0)
		return
	# Remember which slot (not the on-screen box: that can be rebuilt while you hold the button).
	_press = {"area": slot.area, "index": slot.index, "item": slot.item.duplicate(), "button": event.button_index,
			"pos": event.global_position, "shift": event.shift_pressed, "ctrl": event.ctrl_pressed}


func _input(event: InputEvent) -> void:
	if not visible or _press.is_empty():
		return
	if event is InputEventMouseMotion and not _dragging:
		if event.global_position.distance_to(_press["pos"]) > 6.0 and not _press["item"].is_empty():
			_start_drag()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == _press["button"]:
		get_viewport().set_input_as_handled()
		if _dragging:
			_finish_drag(event.global_position)
		else:
			_click(_press["area"], _press["index"], _press["item"])
		_press = {}
		if _redraw_pending:
			_redraw_pending = false
			_redraw()


func _start_drag() -> void:
	var total: int = _press["item"]["count"]
	_drag_count = 0
	if _press["button"] == MOUSE_BUTTON_MIDDLE or _press["shift"]:
		_drag_count = ceili(total / 2.0)
	elif _press["ctrl"]:
		_drag_count = 1
	_dragging = true
	_selected = {}
	_drag_icon.texture = Items.icon(_press["item"]["id"])
	_drag_icon.visible = true


func _finish_drag(at: Vector2) -> void:
	var src_area: String = _press["area"]
	var src_index: int = _press["index"]
	var target: Control = null
	for s in _slots:
		if is_instance_valid(s) and s.get_global_rect().has_point(at):
			target = s
	if target != null:
		if target.area != "their" and (target.area != src_area or target.index != src_index):
			survival.req_move.rpc_id(1, src_area, src_index, target.area, target.index, _drag_count)
	elif not _panel.get_global_rect().has_point(at):
		var dir: Vector3 = get_look_dir.call() if get_look_dir.is_valid() else Vector3.FORWARD
		survival.req_drop.rpc_id(1, src_area, src_index, _drag_count, dir)
	_end_drag()
	if _redraw_pending:
		_redraw_pending = false
		_redraw()


func _end_drag() -> void:
	_dragging = false
	_drag_icon.visible = false
	_press = {}


## Click a slot, then click where it should go.
func _click(area: String, index: int, item: Dictionary) -> void:
	if _selected.is_empty():
		if not item.is_empty():
			_selected = {"area": area, "index": index}
	else:
		if _selected["area"] != area or _selected["index"] != index:
			survival.req_move.rpc_id(1, _selected["area"], _selected["index"], area, index, 0)
		_selected = {}
	_redraw()


# --- Info box -------------------------------------------------------------------------

func _set_info(item: Dictionary, extra: Array = []) -> void:
	if item.is_empty():
		_info.text = "[color=#9ea6b8]Point at anything to learn about it.[/color]" if _tips() else ""
		_info_panel.add_theme_stylebox_override("panel", _card_box(Color(1, 1, 1, 0.08)))
		if _tooltip:
			_tooltip.hide_now()
		return
	if _tooltip:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		_tooltip.show_item(item, _anchor_of(hovered), extra)
	# A Diablo-style title card: the border and name show how special it is.
	_info.text = ItemCard.bbcode(item)
	_info_panel.add_theme_stylebox_override("panel", _card_box(ItemCard.color(item["id"])))


## The card or slot under the mouse (so the pane hides when the mouse leaves it).
func _anchor_of(c: Control) -> Control:
	var n: Node = c
	while n != null and n is Control:
		if n is ItemSlot or (n is PanelContainer and (n as PanelContainer).theme_type_variation == "CardPanel") or n.has_meta("tile"):
			return n
		n = n.get_parent()
	return c


func _card_box(edge: Color) -> StyleBoxTexture:
	return UI.card(Color(edge.lerp(UI.Art.GOLD_DIM, 0.35), 1.0), 12.0)


# --- Drawing -------------------------------------------------------------------------

func _clear(c: Node) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()


func _redraw() -> void:
	_slots.clear()
	var inv: Array = survival.my_inventory()
	for c in [_inv_grid, _hot_grid, _content, _tabs, _char_slots, _char_slots2, _stats]:
		_clear(c)
	for i in range(Inv.HOTBAR_SIZE, Inv.PLAYER_SLOTS):
		_inv_grid.add_child(_slot("inv", i, inv[i]))
	for i in Inv.HOTBAR_SIZE:
		_hot_grid.add_child(_slot("inv", i, inv[i]))
	_draw_character(inv)
	_help_label.visible = _tips()
	_toots_label.text = ("%.1f" % survival.me.get("toots", 0.0)).trim_suffix(".0")
	_tabs.visible = false
	match mode:
		"craft":
			_draw_craft()
		"shop", "trader":
			_draw_shop(mode == "trader")
		"villager":
			_draw_villager()
		"furnace":
			_draw_furnace()
		"chest":
			_draw_chest()
		"loot":
			_draw_loot()
		"trade":
			_draw_trade()
		"cute":
			_draw_cute()
		"scribe":
			_draw_scribe()
		"research":
			_draw_research()
		"stand":
			_draw_stand()


func _draw_character(inv: Array) -> void:
	var hints := ["leather_helmet", "leather_chestplate", "leather_leggings", "leather_boots", "red_cape"]
	for i in 5:
		var s := _slot("inv", Inv.ARMOR_START + i, inv[Inv.ARMOR_START + i], 50, Items.icon(hints[i]))
		s.tooltip_text = ["Helmet", "Chestplate", "Leggings", "Boots", "Cape"][i]
		_char_slots.add_child(s)
	for j in 2:
		var gi: int = [Inv.AMULET_SLOT, Inv.RING_SLOT][j]
		var gs := _slot("inv", gi, inv[gi] if gi < inv.size() else null, 50, Items.icon(["gold_amulet", "gold_ring"][j]))
		gs.tooltip_text = ["Amulet", "Ring"][j]
		_char_slots2.add_child(gs)
	var ids := Survival.armor_ids(inv)
	if ids != _shown_armor:
		_shown_armor = ids
		Avatar.set_armor(_preview_av, ids)
	var hp: float = survival.me.get("health", 20.0)
	var armor := Survival.armor_points(inv)
	var top := HBoxContainer.new()
	var name_l := UI.label(_char_name, 20)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var sheet_b := UI.button("Stats" if not _sheet_open else "Back", "TabButton", 15)
	sheet_b.tooltip_text = "Your character sheet: everything your gear, fairy, cape, ring, amulet and powers add up to"
	sheet_b.custom_minimum_size = Vector2(70, 30)
	sheet_b.pressed.connect(func() -> void:
		_sheet_open = not _sheet_open
		_redraw())
	top.add_child(sheet_b)
	_stats.add_child(top)
	_preview_box.visible = not _sheet_open
	_stats.custom_minimum_size = Vector2(360 if _sheet_open else 190, 0)
	if _sheet_open:
		_draw_sheet(inv)
		return
	var hp_row := HBoxContainer.new()
	hp_row.add_child(UI.icon_rect(Items.heart_icon("full"), 24))
	hp_row.add_child(UI.label("  %d / 20" % ceili(hp), 18))
	_stats.add_child(hp_row)
	var ar_row := HBoxContainer.new()
	ar_row.add_child(UI.icon_rect(Items.shield_icon("full" if armor > 0 else "empty"), 24))
	ar_row.add_child(UI.label("  Armor %d" % armor, 18))
	_stats.add_child(ar_row)
	var blocks := UI.label("Blocks %d%% of damage" % roundi(float(survival.me.get("protect", 0.0)) * 100.0) if armor > 0 else "No armor", 15, UI.TEXT_SOFT)
	blocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_child(blocks)
	var head = inv[Inv.ARMOR_START]
	if head != null and Items.get_def(head["id"]).get("regen", false):
		_stats.add_child(UI.label("Royal Mending!", 16, LEGEND))
	# Your powers right now, from your fairy, cape, ring and amulet.
	var powers := _my_powers()
	for k in powers:
		var on: bool = k in MobData.BINARY_BUFFS
		var l := UI.label(MobData.buff_name(k) if on else "%s +%d%%" % [MobData.buff_name(k), roundi(powers[k] * 100.0)], 15, Color(0.75, 0.9, 1.0))
		l.tooltip_text = MobData.buff_text(k, powers[k])
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_stats.add_child(l)


## The character sheet: every number that matters, by section. Hover a line
## to see where it comes from.
func _draw_sheet(inv: Array) -> void:
	var held := {}
	var lp = survival.main.local_player if survival.main else null
	if lp != null and is_instance_valid(lp):
		var hb: int = lp.hotbar_index
		if hb >= 0 and hb < inv.size() and inv[hb] != null:
			held = inv[hb]
	var rows: Array = StatSheet.rows(survival.me, survival.active_power(), held, survival.power_times().x)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 236)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var section := ""
	for r in rows:
		if r[0] != section:
			section = r[0]
			grid.add_child(UI.label(section.to_upper(), 13, LEGEND))
			grid.add_child(Control.new())
		var n := UI.label(r[1], 14, UI.TEXT_SOFT)
		var v := UI.label(r[2], 14, r[4])
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for l in [n, v]:
			l.tooltip_text = r[3]
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(n)
		grid.add_child(v)
	_stats.add_child(scroll)


## {type: power} of everything helping you (what the server sent).
func _my_powers() -> Dictionary:
	var out := {}
	var me: Dictionary = survival.me
	for src in [me.get("buff", {}), me.get("cape", {})]:
		if src.has("type"):
			out[src["type"]] = float(out.get(src["type"], 0.0)) + float(src.get("power", 0.0))
	var g: Dictionary = me.get("gear", {})
	for k in g:
		out[k] = float(out.get(k, 0.0)) + float(g[k])
	for k in out.keys():
		out[k] = minf(out[k], float(MobData.BUFF_CAP.get(k, 99.0)))
		if out[k] <= 0.0:
			out.erase(k)
	return out


func _draw_craft() -> void:
	if build_bench != "":
		_draw_build()
		return
	if station_tier == 0:
		_title.text = "Crafting"
		_title_icon.texture = Items.icon("planks")
	else:
		_title.text = "Workbench %s" % TIER_NAMES[station_tier]
		_title_icon.texture = Items.icon("workbench_%d" % station_tier)
		# Tabs: by hand, then each tier this bench can do. Higher tiers stay hidden.
		_tabs.visible = true
		var group := ButtonGroup.new()
		for t in station_tier + 1:
			var b := UI.button(TIER_NAMES[t], "TabButton", 20)
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = t == tab
			b.custom_minimum_size = Vector2(110, 46)
			b.pressed.connect(func() -> void:
				tab = t
				_scroll.scroll_vertical = 0
				_redraw())
			_tabs.add_child(b)

	var show_tier := 0 if station_tier == 0 else tab
	# Only what you know how to make: by hand, the things you've found the
	# ingredients for; at a workbench, what you've learned at a Research Table.
	var seen: Dictionary = survival.me.get("seen", {})
	var learned: Dictionary = survival.me.get("unlocked", {})
	var list := []
	for r in Recipes.RECIPES:
		if r["station"] != show_tier or r.has("bench"):
			continue
		if show_tier == 0 and not Recipes.discovered(r, seen):
			continue
		if show_tier > 0 and not r.get("auto", false) and not learned.has(r["out"]):
			continue
		list.append(r)
	var inv: Array = survival.my_inventory().slice(0, Inv.PLAYER_SLOTS)
	var makeable := func(r: Dictionary) -> bool:
		for id in r["in"]:
			if Recipes.have(inv, r, id) < r["in"][id]:
				return false
		return true
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return makeable.call(a) and not makeable.call(b))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var count_label := UI.label("%d recipe%s" % [list.size(), "" if list.size() == 1 else "s"], 15, UI.TEXT_SOFT)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(count_label)
	var only := CheckButton.new()
	only.text = "Craftable"
	only.button_pressed = _only_makeable
	only.focus_mode = Control.FOCUS_NONE
	only.toggled.connect(func(on: bool) -> void:
		_only_makeable = on
		_redraw())
	bar.add_child(only)
	_content.add_child(bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var shown := 0
	for r in list:
		if _only_makeable and not makeable.call(r):
			continue
		grid.add_child(_recipe_card(r))
		shown += 1
	_content.add_child(grid)
	if shown == 0:
		var empty := UI.label("Nothing to make here yet." if show_tier == 0 else
				"You haven't learned anything for this tier yet.\nLearn recipes at a Research Table near this workbench.", 17, UI.TEXT_SOFT)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(500, 80)
		_content.add_child(empty)

	if station_tier == 0 and _tips():
		var hint := PanelContainer.new()
		hint.theme_type_variation = "CardPanel"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UI.icon_rect(Items.icon("workbench_1"), 52))
		var t := UI.label("Want to make more things?\nCraft a Workbench, place it, and right-click it!", 18)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		hint.add_child(row)
		_content.add_child(hint)
	elif show_tier > 0:
		_tip("New recipes are learned at a Research Table. Find new things out in the world to discover more.")


const BENCH_INFO := {
	"sawmill": ["Sawmill", "sawmill", "Turn planks into stairs, slabs, columns, tables, chairs and carved wood. Every kind of wood keeps its color!"],
	"stonecutter": ["Stonecutter", "stonecutter", "Cut stone into bricks, stairs, slabs, columns, pillars and carved blocks."],
	"shaper": ["Shaper", "shaper", "Shape metal into blocks and slabs, and set metal into stone bricks."],
	"jewelry": ["Jewelry Station", "jewelry_station", "Set gems from the Deep into rings and amulets. Every piece comes out a little different: Faint, Glowing, Bright or Radiant!"],
}


## A building bench: everything it can make, sorted by what it's made from.
func _draw_build() -> void:
	var info: Array = BENCH_INFO[build_bench]
	_title.text = info[0]
	_title_icon.texture = Items.icon(info[1])
	_tip(info[2])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var seen: Dictionary = survival.me.get("seen", {})
	for r in Recipes.RECIPES:
		if r.get("bench", "") == build_bench and Recipes.discovered(r, seen):
			grid.add_child(_recipe_card(r))
	_content.add_child(grid)
	if grid.get_child_count() == 0:
		_content.add_child(UI.label("Bring some building materials to see what you can make.", 17, UI.TEXT_SOFT))


## An item picture in a small gold-rimmed slot.
func _framed_icon(id: String, size: float, dim := false) -> PanelContainer:
	var f := PanelContainer.new()
	f.add_theme_stylebox_override("panel", UI.slot_style("normal"))
	f.custom_minimum_size = Vector2(size, size)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UI.icon_rect(Items.icon(id) if id != "" else null, size - 12)
	if dim:
		ic.modulate = Color(0.55, 0.52, 0.5)
	f.add_child(ic)
	return f


# --- Research Table ---------------------------------------------------------------------

const TIER_ROMAN := ["", "I", "II", "III"]


## Every recipe for the workbenches near the table, as tiles: "?" until you've
## found what it's made from, then the item with its price in toots, then
## "Learned" once you've paid.
func _draw_research() -> void:
	_title.text = "Research Table"
	_title_icon.texture = Items.icon("research_table")
	var seen: Dictionary = survival.me.get("seen", {})
	var known: Dictionary = survival.me.get("known", {})
	var learned: Dictionary = survival.me.get("unlocked", {})
	var toots: float = survival.me.get("toots", 0.0)
	var total := 0
	var have := 0
	for r in Recipes.RECIPES:
		if Recipes.needs_research(r):
			total += 1
			if learned.has(r["out"]):
				have += 1
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var near := UI.label("Workbenches nearby: %s" % ("none" if _research_tier == 0 else "up to Tier %s" % TIER_ROMAN[_research_tier]), 16, UI.TEXT_SOFT)
	near.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(near)
	top.add_child(UI.label("Learned %d / %d" % [have, total], 16, UI.GOLD))
	_content.add_child(top)
	if _research_tier == 0:
		var none := UI.label("Build a Workbench within %d blocks of this table to research its recipes." % Survival.RESEARCH_RANGE, 18)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(500, 0)
		_content.add_child(none)
	for tier in range(1, 4):
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var t := UI.make_title(UI.label("Tier %s" % TIER_ROMAN[tier], 22))
		head.add_child(t)
		if tier > _research_tier:
			head.add_child(UI.label("needs a Workbench Tier %s nearby" % TIER_ROMAN[tier], 14, UI.TEXT_SOFT))
		_content.add_child(head)
		_content.add_child(UI.accent_line())
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for r in Recipes.RECIPES:
			if not Recipes.needs_research(r) or int(r["station"]) != tier:
				continue
			var found: bool = known.has(r["out"]) or Recipes.discovered(r, seen)
			grid.add_child(_research_tile(r, found, learned.has(r["out"]), tier <= _research_tier, toots))
		_content.add_child(grid)
	_tip("Carry new things to discover new recipes. Learn them here with toots, then make them at their workbench.")


func _research_tile(r: Dictionary, found: bool, learned: bool, in_reach: bool, toots: float) -> Control:
	var tile := VBoxContainer.new()
	tile.set_meta("tile", true)
	tile.add_theme_constant_override("separation", 3)
	tile.custom_minimum_size = Vector2(80, 0)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.slot_style("selected" if learned else "normal"))
	frame.custom_minimum_size = Vector2(76, 76)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(frame)
	if not found:
		var q := UI.make_title(UI.label("?", 38))
		q.add_theme_color_override("font_color", UI.Art.GOLD_DIM)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(q)
		var tier: int = int(r["station"])
		tile.mouse_entered.connect(func() -> void: _tooltip.show_mystery(tile, tier))
		tile.add_child(UI.label("", 13))
		return tile
	var ic := UI.icon_rect(Items.icon(r["out"]), 56)
	if not learned:
		ic.modulate = Color(0.72, 0.68, 0.64)
	frame.add_child(ic)
	var item := {"id": r["out"], "count": r["count"]}
	tile.mouse_entered.connect(func() -> void: _tooltip.show_item(item, tile, [_ingredient_row(r)]))
	if learned:
		var l := UI.label("Learned", 13, UI.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(l)
	else:
		var b := UI.button(Recipes.format_toots(r["cost"]), "GoldButton", 14)
		b.icon = Items.coin_icon()
		b.expand_icon = false
		b.custom_minimum_size = Vector2(80, 30)
		b.disabled = not in_reach or toots < r["cost"]
		b.tooltip_text = ("Needs a Workbench Tier %s nearby" % TIER_ROMAN[int(r["station"])]) if not in_reach else ("Need more toots! Sell things at a Block Shop." if toots < r["cost"] else "Learn it")
		var id: String = r["out"]
		b.pressed.connect(func() -> void:
			Sound.play("unlock", -4.0, 1.0, "Interface")
			survival.req_unlock.rpc_id(1, id, station_pos))
		tile.add_child(b)
	return tile


## A recipe's ingredients as small framed pictures with counts.
func _ingredient_row(r: Dictionary) -> Control:
	var inv: Array = survival.my_inventory().slice(0, Inv.PLAYER_SLOTS)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UI.label("Made from" + (" (makes %d)" % r["count"] if r["count"] > 1 else ""), 14, UI.GOLD))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	for id in r["in"]:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.add_child(_framed_icon(id, 34))
		var need: int = r["in"][id]
		var has := Recipes.have(inv, r, id)
		chip.add_child(UI.label("%d" % need, 15, UI.GOOD if has >= need else UI.TEXT))
		row.add_child(chip)
	box.add_child(row)
	return box


func _recipe_card(r: Dictionary) -> PanelContainer:
	var inv: Array = survival.my_inventory().slice(0, Inv.PLAYER_SLOTS)
	var toots: float = survival.me.get("toots", 0.0)
	var unlocked: bool = r["station"] == 0 or r.has("bench") or r.get("auto", false) or survival.me.get("unlocked", {}).has(r["out"])
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(262, 0)
	card.mouse_entered.connect(func() -> void: _set_info({"id": r["out"], "count": 1}))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(_framed_icon(r["out"], 56))
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	var name_label := UI.label(Items.display_name(r["out"]), 18, ItemCard.color(r["out"]))
	name_label.add_theme_font_override("font", UI.title_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(170, 0)
	name_box.add_child(name_label)
	if r["count"] > 1:
		name_box.add_child(UI.label("Makes %d" % r["count"], 15, UI.TEXT_SOFT))
	top.add_child(name_box)
	box.add_child(top)

	# Ingredients as pictures: green when you have enough, red when you don't.
	var have_all := true
	var needs := HFlowContainer.new()
	needs.add_theme_constant_override("h_separation", 10)
	for id in r["in"]:
		var need: int = r["in"][id]
		var have := Recipes.have(inv.slice(0, Inv.PLAYER_SLOTS), r, id)
		have_all = have_all and have >= need
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 2)
		var icon := UI.icon_rect(Items.icon(id), 28)
		icon.tooltip_text = Items.display_name(id) if Recipes.choices(r, id).size() == 1 else "Any %s" % ("Planks" if id == "planks" else "Log")
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_child(icon)
		chip.add_child(UI.label("%d/%d" % [mini(have, need), need], 16, UI.GOOD if have >= need else UI.BAD))
		needs.add_child(chip)
	box.add_child(needs)

	var buttons := HBoxContainer.new()
	if not unlocked:
		var unlock := UI.button("", "GoldButton", 18)
		unlock.icon = Items.coin_icon()
		unlock.text = "Unlock  %s" % ("%.1f" % r["cost"]).trim_suffix(".0")
		unlock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock.custom_minimum_size = Vector2(0, 44)
		unlock.disabled = toots < r["cost"]
		unlock.tooltip_text = "Need more toots! Sell things at a Block Shop." if unlock.disabled else "Pay once, keep it forever."
		unlock.pressed.connect(func() -> void: survival.req_unlock.rpc_id(1, r["out"], station_pos))
		buttons.add_child(unlock)
	else:
		var craft := UI.button("Craft" if have_all else "Missing items", "GreenButton", 16)
		craft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		craft.custom_minimum_size = Vector2(0, 44)
		craft.disabled = not have_all
		craft.pressed.connect(func() -> void:
			Sound.play("craft", -4.0, randf_range(0.95, 1.05), "Interface")
			survival.req_craft.rpc_id(1, r["out"], station_pos, 1))
		buttons.add_child(craft)
		if have_all:
			var five := UI.button("x5", "BlueButton", 16)
			five.custom_minimum_size = Vector2(54, 44)
			five.tooltip_text = "Craft up to 5"
			five.pressed.connect(func() -> void:
				Sound.play("craft", -4.0, 1.0, "Interface")
				survival.req_craft.rpc_id(1, r["out"], station_pos, 5))
			buttons.add_child(five)
	box.add_child(buttons)
	return card


## The Cute Crafter: every tool, weapon, piece of armor and cape you have
## (worn ones too), with what it costs to make it cute.
func _draw_cute() -> void:
	_title.text = "Cute Crafter"
	_title_icon.texture = Items.icon("cute_crafter")
	var inv: Array = survival.my_inventory()
	var ingots := Inv.count_of(inv.slice(0, Inv.PLAYER_SLOTS), "cutieite_ingot")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UI.icon_rect(Items.icon("cutieite_ingot"), 32))
	top.add_child(UI.label("You have %d Cutieite Ingot%s" % [ingots, "" if ingots == 1 else "s"], 18, PINK))
	_content.add_child(top)
	_tip("Put any crafted tool, weapon, armor or cape in, and it comes out CUTE! Cute things are a little better. Every one rolls its own bonus, so some come out extra good.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var any := false
	for i in Inv.PLAYER_SIZE:
		var s = inv[i]
		if s == null or not Items.is_cutable(s["id"]):
			continue
		any = true
		var cost := Recipes.cute_cost(s["id"])
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.custom_minimum_size = Vector2(262, 0)
		var item: Dictionary = s
		card.mouse_entered.connect(func() -> void: _set_info(item))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon_rect(Items.icon(s["id"]), 40))
		row.add_child(UI.label("→", 22, PINK))
		row.add_child(UI.icon_rect(Items.icon("cute_" + s["id"]), 40))
		var name_label := UI.label(Items.display_name(s["id"]) + (" (worn)" if i >= Inv.ARMOR_START else ""), 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.custom_minimum_size = Vector2(110, 0)
		row.add_child(name_label)
		box.add_child(row)
		var b := UI.button("Make it cute!  (%d Cutieite)" % cost, "GreenButton", 16)
		b.custom_minimum_size = Vector2(0, 42)
		b.disabled = ingots < cost
		b.tooltip_text = "Need more Cutieite! Find Cutie Ore in candy land's cake." if b.disabled else ""
		var index := i
		b.pressed.connect(func() -> void: survival.req_cutify.rpc_id(1, index, station_pos))
		box.add_child(b)
		grid.add_child(card)
	_content.add_child(grid)
	if not any:
		_content.add_child(UI.label("Bring a tool, weapon, armor or cape to make it cute!", 18, UI.TEXT_SOFT))


## The Scribe Desk: write a name on any of your tools, weapons, armor, capes
## or maps, in the color of the ink you use.
func _draw_scribe() -> void:
	_title.text = "Scribe Desk"
	_title_icon.texture = Items.icon("scribe")
	var inv: Array = survival.my_inventory()
	var inks := []
	for id in Items.ITEMS:
		if Items.get_def(id).has("ink") and Inv.count_of(inv.slice(0, Inv.PLAYER_SLOTS), id) > 0:
			inks.append(id)
	_tip("Pick a thing, type a name and choose an ink. Writing costs 1 ink, and the name shows in that color. Leave the name empty to rub it out.")
	if inks.is_empty():
		_content.add_child(UI.label("You need some ink! Make it from coal and a water bottle (add a flower for a color).", 17, UI.BAD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in Inv.PLAYER_SIZE:
		var s = inv[i]
		if s == null or not Survival.can_inscribe(s["id"]):
			continue
		var item: Dictionary = s
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.custom_minimum_size = Vector2(262, 0)
		card.mouse_entered.connect(func() -> void: _set_info(item))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.icon_rect(Items.icon(s["id"]), 36))
		var nm := UI.label(s.get("label", Items.display_name(s["id"])), 16, ItemCard.color(s["id"]))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(170, 0)
		row.add_child(nm)
		box.add_child(row)
		var edit := LineEdit.new()
		edit.max_length = 24
		edit.placeholder_text = "Write a name..."
		edit.text = s.get("label", "")
		edit.custom_minimum_size = Vector2(0, 38)
		box.add_child(edit)
		var row2 := HBoxContainer.new()
		var pick := OptionButton.new()
		for ink in inks:
			pick.add_icon_item(Items.icon(ink), Items.display_name(ink))
		pick.custom_minimum_size = Vector2(130, 38)
		pick.disabled = inks.is_empty()
		row2.add_child(pick)
		var go := UI.button("Write", "GreenButton", 16)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.custom_minimum_size = Vector2(0, 38)
		var index := i
		var ink_list := inks
		go.pressed.connect(func() -> void:
			var ink: String = ink_list[pick.selected] if not ink_list.is_empty() and pick.selected >= 0 else ""
			Sound.ui("click")
			survival.req_inscribe.rpc_id(1, index, edit.text, ink, station_pos))
		row2.add_child(go)
		box.add_child(row2)
		grid.add_child(card)
	_content.add_child(grid)


## An armor stand: five slots (helmet, chestplate, leggings, boots, cape).
func _draw_stand() -> void:
	_title.text = "Armor Stand"
	_title_icon.texture = Items.icon("armor_stand")
	var slots: Array = survival.open_slots
	var hints := ["leather_helmet", "leather_chestplate", "leather_leggings", "leather_boots", "red_cape"]
	var names := ["Helmet", "Chestplate", "Leggings", "Boots", "Cape"]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in 5:
		var col := VBoxContainer.new()
		col.add_child(UI.label(names[i], 14, UI.TEXT_SOFT))
		col.add_child(_slot("open", i, slots[i] if i < slots.size() else null, 62, Items.icon(hints[i])))
		row.add_child(col)
	_content.add_child(row)
	_tip("Right-click armor and capes in your stuff to put them on the stand. Right-click them on the stand to take them back.")


func _draw_shop(trader: bool) -> void:
	var bonus := Survival.TRADER_BONUS if trader else 1.0
	var totals := {}
	var inv: Array = survival.my_inventory()
	for i in Inv.PLAYER_SLOTS:  # worn armor isn't for sale
		if inv[i] != null:
			totals[inv[i]["id"]] = totals.get(inv[i]["id"], 0) + inv[i]["count"]
	if trader:
		_title.text = "QtMaMe's Candy Shop"
		_title_icon.texture = Items.icon("gummy")
		var hello := PanelContainer.new()
		hello.add_theme_stylebox_override("panel", UI.box(Color(0.45, 0.2, 0.38, 1.0), 14, 3, PINK, 12))
		var t := UI.label("Hiii! I'm QtMaMe! I pay DOUBLE toots for everything!\nAnd I'll come live near your bed and help keep the monsters away!", 18, Color(1.0, 0.9, 0.97))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(500, 0)
		hello.add_child(t)
		_content.add_child(hello)
	else:
		_title.text = "Block Shop"
		_title_icon.texture = Items.icon("shop")
		_tip("Sell things for toots, then spend toots unlocking recipes at a Workbench.")
	if totals.is_empty():
		_content.add_child(UI.label("You don't have anything to sell yet.\nGo mine some blocks!", 20))
	for id in totals:
		var v := Recipes.value(id) * bonus
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.mouse_entered.connect(func() -> void: _set_info({"id": id, "count": 1}))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon_rect(Items.icon(id), 42))
		var name_box := VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_theme_constant_override("separation", 0)
		name_box.add_child(UI.label("%s  x%d" % [Items.display_name(id), totals[id]], 17, LEGEND if Items.rarity(id) == "legendary" else UI.TEXT))
		var price := HBoxContainer.new()
		price.add_child(UI.icon_rect(Items.coin_icon(), 18))
		price.add_child(UI.label(" %s each" % ("%.2f" % v).trim_suffix("0").trim_suffix("0").trim_suffix("."), 15, Color(1.0, 0.86, 0.35)))
		name_box.add_child(price)
		row.add_child(name_box)
		for n in ([1, totals[id]] if totals[id] > 1 else [1]):
			var b := UI.button("Sell 1" if n == 1 else "Sell all", "GoldButton", 16)
			b.custom_minimum_size = Vector2(80 if n == 1 else 96, 42)
			b.disabled = v <= 0.0
			b.tooltip_text = "Get %s" % Recipes.format_toots(v * n)
			if trader:
				b.pressed.connect(func() -> void: survival.req_sell_trader.rpc_id(1, id, n))
			else:
				b.pressed.connect(func() -> void: survival.req_sell.rpc_id(1, id, n, station_pos))
			row.add_child(b)
		card.add_child(row)
		_content.add_child(card)


## A villager's shop: what they sell today, for toots.
func _draw_villager() -> void:
	var shop: Dictionary = survival.villager_shop
	if shop.is_empty() or int(shop.get("mob", -1)) != villager_id:
		_title.text = "Trading..."
		_content.add_child(UI.label("Saying hello...", 18, UI.TEXT_SOFT))
		return
	_title.text = "%s's Stall" % shop["name"]
	_title_icon.texture = Items.icon(shop["items"][0]["id"]) if not shop["items"].is_empty() else Items.coin_icon()
	var hello := PanelContainer.new()
	hello.add_theme_stylebox_override("panel", UI.box(Color(0.2, 0.16, 0.1, 1.0), 14, 2, UI.GOLD, 12))
	var hv := VBoxContainer.new()
	hv.add_child(UI.label(shop["tribe"].to_upper(), 12, UI.GOLD))
	var t := UI.label("\"%s\"" % shop["hello"], 17, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 0)
	hv.add_child(t)
	hello.add_child(hv)
	_content.add_child(hello)
	var toots: float = survival.me.get("toots", 0.0)
	var items: Array = shop["items"]
	for i in items.size():
		var it: Dictionary = items[i]
		var id: String = it["id"]
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.mouse_entered.connect(func() -> void: _set_info({"id": id, "count": 1}))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UI.icon_rect(Items.icon(id), 42))
		var name_box := VBoxContainer.new()
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_box.add_theme_constant_override("separation", 0)
		var nm := Items.display_name(id) + ("   ★ Surprise!" if it["surprise"] else "")
		name_box.add_child(UI.label(nm, 17, LEGEND if it["surprise"] else ItemCard.color(id)))
		var price := HBoxContainer.new()
		price.add_child(UI.icon_rect(Items.coin_icon(), 18))
		var left := int(it["count"])
		price.add_child(UI.label(" %s each   ·   %s" % [Recipes.format_toots(float(it["price"])).trim_suffix(" toots"), ("%d left today" % left) if left > 0 else "sold out"], 15, Color(1.0, 0.86, 0.35) if left > 0 else UI.TEXT_SOFT))
		name_box.add_child(price)
		row.add_child(name_box)
		for n in ([1, mini(left, 8)] if left > 1 else [1]):
			var b := UI.button("Buy 1" if n == 1 else "Buy %d" % n, "GoldButton", 16)
			b.custom_minimum_size = Vector2(80, 42)
			b.disabled = left <= 0 or toots + 0.0001 < float(it["price"]) * n
			b.tooltip_text = "Costs %s" % Recipes.format_toots(float(it["price"]) * n)
			var idx := i
			b.pressed.connect(func() -> void: survival.req_buy_villager.rpc_id(1, villager_id, idx, n))
			row.add_child(b)
		card.add_child(row)
		_content.add_child(card)


func _draw_furnace() -> void:
	_title.text = "Furnace"
	_title_icon.texture = Items.icon("furnace")
	var slots: Array = survival.open_slots
	var extra: Dictionary = survival.open_extra
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)

	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(UI.label("Ore" if not _tips() else "Ore goes here", 14, UI.TEXT_SOFT))
	left.add_child(_slot("open", 0, slots[0] if slots.size() > 0 else null, 68))
	var fire := ProgressBar.new()
	fire.max_value = 1.0
	fire.value = extra.get("fuel", 0.0)
	fire.show_percentage = false
	fire.custom_minimum_size = Vector2(68, 14)
	fire.add_theme_stylebox_override("fill", UI.box(Color(1.0, 0.55, 0.15), 8, 0, UI.GOLD, 0))
	left.add_child(fire)
	left.add_child(_slot("open", 1, slots[1] if slots.size() > 1 else null, 68))
	left.add_child(UI.label("Fuel" if not _tips() else "Wood goes here", 14, UI.TEXT_SOFT))
	row.add_child(left)

	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(UI.label("Cooking..." if extra.get("progress", 0.0) > 0.0 else "", 16, UI.TEXT_SOFT))
	var arrow := ProgressBar.new()
	arrow.max_value = 1.0
	arrow.value = extra.get("progress", 0.0)
	arrow.show_percentage = false
	arrow.custom_minimum_size = Vector2(120, 24)
	mid.add_child(arrow)
	row.add_child(mid)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(UI.label("Result", 14, UI.TEXT_SOFT))
	right.add_child(_slot("open", 2, slots[2] if slots.size() > 2 else null, 80))
	right.add_child(UI.label("Coal", 14, UI.TEXT_SOFT))
	right.add_child(_slot("open", 3, slots[3] if slots.size() > 3 else null, 56))
	row.add_child(right)
	_content.add_child(card)

	_tip("Drag or right-click ore and wood in from your stuff. Logs and candy canes burn longest, and it keeps cooking while you're away. Burning wood leaves coal behind!")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	for ore in Recipes.SMELTING:
		var chip := HBoxContainer.new()
		chip.add_child(UI.icon_rect(Items.icon(ore), 26))
		chip.add_child(UI.label(" > ", 16, UI.TEXT_SOFT))
		chip.add_child(UI.icon_rect(Items.icon(Recipes.SMELTING[ore]), 26))
		chip.tooltip_text = "%s becomes %s" % [Items.display_name(ore), Items.display_name(Recipes.SMELTING[ore])]
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		flow.add_child(chip)
	_content.add_child(flow)


func _draw_chest() -> void:
	_title.text = str(survival.open_extra.get("title", "Chest"))
	var super_chest: bool = survival.open_extra.get("super", false)
	_title_icon.texture = Items.icon("super_chest" if super_chest else "chest")
	var stone: bool = _title.text == "Stone Chest" and not survival.open_extra.get("named", false)
	if super_chest:
		var note := UI.label("Only you can see what's in here. Every Super Chest opens this same box.", 14, UI.TEXT_SOFT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(note)
	elif not stone and survival.open_key is Vector3i:
		# A name for the chest (it floats over it, so you can find your stuff).
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		var edit := LineEdit.new()
		edit.placeholder_text = "Name this chest (like \"Ores\" or \"Food\")"
		edit.tooltip_text = "The name goes on a little plate on the chest's front and lid."
		edit.max_length = 20
		edit.text = str(survival.chest_names.get(survival.open_key, ""))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pos: Vector3i = survival.open_key
		var save_name := func(_t := "") -> void:
			survival.req_name_chest.rpc_id(1, pos, edit.text)
			edit.release_focus()
		edit.text_submitted.connect(save_name)
		name_row.add_child(edit)
		var nb := UI.button("Name it", "Button", 15)
		nb.pressed.connect(save_name)
		name_row.add_child(nb)
		_content.add_child(name_row)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var take_all := UI.button("Take all", "GreenButton", 16)
	take_all.custom_minimum_size = Vector2(0, 44)
	take_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take_all.tooltip_text = "Everything in the chest goes into your stuff."
	take_all.pressed.connect(func() -> void: survival.req_take_all.rpc_id(1))
	actions.add_child(take_all)
	var match_btn := UI.button("Put in matching", "BlueButton", 16)
	match_btn.custom_minimum_size = Vector2(0, 44)
	match_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_btn.tooltip_text = "Anything you carry that's already in this chest goes in (hotbar too)."
	match_btn.pressed.connect(func() -> void: survival.req_store_matching.rpc_id(1))
	actions.add_child(match_btn)
	var pack := UI.button("Empty backpack", "Button", 16)
	pack.custom_minimum_size = Vector2(0, 44)
	pack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack.tooltip_text = "Everything in your backpack goes in. Your hotbar and what you're wearing stay."
	pack.pressed.connect(func() -> void: survival.req_store_backpack.rpc_id(1))
	actions.add_child(pack)
	_content.add_child(actions)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var slots: Array = survival.open_slots
	for i in slots.size():
		grid.add_child(_slot("open", i, slots[i], 54))
	_content.add_child(grid)
	_tip("Right-click an item to move it between the chest and your stuff.")


func _draw_loot() -> void:
	var title: String = survival.open_extra.get("title", "Loot")
	_title.text = title
	_title_icon.texture = Items.icon("king_crown" if title.ends_with("treasure") else "leather")
	var take_all := UI.button("Take all", "GreenButton", 17)
	take_all.custom_minimum_size = Vector2(0, 54)
	take_all.pressed.connect(func() -> void: survival.req_take_all.rpc_id(1))
	_content.add_child(take_all)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var slots: Array = survival.open_slots
	for i in slots.size():
		grid.add_child(_slot("open", i, slots[i], 62))
	_content.add_child(grid)
	_tip("Right-click or drag an item to take it.")


func _draw_trade() -> void:
	var extra: Dictionary = survival.open_extra
	_title.text = extra.get("title", "Trading")
	_title_icon.texture = Items.coin_icon()
	var partner: String = extra.get("partner", "them")
	for side in ["mine", "theirs"]:
		var mine: bool = side == "mine"
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var head := HBoxContainer.new()
		var who := UI.label("You give" if mine else "%s gives" % partner, 20, UI.GOLD)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(who)
		var ready: bool = extra.get("my_ready" if mine else "their_ready", false)
		head.add_child(UI.label("READY!" if ready else "thinking...", 18, UI.GOOD if ready else UI.TEXT_SOFT))
		box.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 9
		grid.add_theme_constant_override("h_separation", 4)
		var slots: Array = survival.open_slots if mine else extra.get("their", [])
		for i in slots.size():
			grid.add_child(_slot("open" if mine else "their", i, slots[i], 52))
		box.add_child(grid)
		var toots_row := HBoxContainer.new()
		toots_row.add_theme_constant_override("separation", 8)
		toots_row.add_child(UI.icon_rect(Items.coin_icon(), 24))
		if mine:
			var spin := SpinBox.new()
			spin.min_value = 0
			spin.max_value = floorf(survival.me.get("toots", 0.0))
			spin.step = 1
			spin.value = extra.get("my_toots", 0.0)
			spin.custom_minimum_size = Vector2(140, 0)
			spin.suffix = "toots"
			spin.value_changed.connect(func(v: float) -> void: survival.req_trade_toots.rpc_id(1, v))
			toots_row.add_child(spin)
		else:
			toots_row.add_child(UI.label("%d toots" % int(extra.get("their_toots", 0.0)), 18, Color(1.0, 0.86, 0.35)))
		box.add_child(toots_row)
		card.add_child(box)
		_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var my_ready: bool = extra.get("my_ready", false)
	var ready_btn := UI.button("Not ready" if my_ready else "I'm ready!", "BlueButton" if my_ready else "GreenButton", 20)
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.custom_minimum_size = Vector2(0, 52)
	ready_btn.pressed.connect(func() -> void: survival.req_trade_ready.rpc_id(1, not my_ready))
	row.add_child(ready_btn)
	var cancel := UI.button("Cancel", "RedButton", 18)
	cancel.custom_minimum_size = Vector2(120, 52)
	cancel.pressed.connect(close)
	row.add_child(cancel)
	_content.add_child(row)
	_tip("Drag or right-click your things into \"You give\". When you're both ready, the swap happens.")
