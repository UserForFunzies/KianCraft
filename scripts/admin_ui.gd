extends CanvasLayer
## The admin panel (/admin, host only for now): jump around the world, move,
## freeze or hunt players, and every host power as a button. Each button just
## sends the matching chat command, so the same rules apply (and they stop
## working if the world's host commands are turned off for good).

const UI = preload("res://scripts/ui_theme.gd")

signal closed

var main: Node
var _root: Control
var _players_box: VBoxContainer
var _online := {}
var _me := 1

const GO_BOSSES := [["Boar King", "boarking"], ["Old Oakheart", "oakheart"], ["Gummy Giant", "gummy"], ["King Cougar", "temple"],
		["Scarecrow King", "scarecrow"], ["Yeti", "yeti"], ["Lantern Witch", "witch"], ["Grimskull", "castle"],
		["King & Queen", "queen"], ["Chuckles", "clown"], ["Fire Giant", "giant"]]
const GO_PLACES := [["Villager camp", "camp"], ["Spawn shrine", "shrine"], ["Fairy village", "village"], ["Dungeon", "dungeon"], ["Grotto", "grotto"],
		["Mine shaft", "mineshaft"], ["QtMaMe", "qtmame"]]
const GO_BIOMES := [["Meadows", "meadows"], ["Tall Forest", "forest"], ["Desert", "desert"], ["Candy Land", "candy"],
		["Mountains", "mountains"], ["Fall Forest", "fall"], ["Spooky Forest", "spooky"], ["Floating Islands", "islands"],
		["Chessboard", "chess"], ["Fast Food", "food"]]
const ME := [["God mode", "/god"], ["Fly", "/fly"], ["No-clip", "/noclip"], ["Walls solid", "/clip"], ["Heal me", "/heal"],
		["Make it day", "/time day"], ["Make it night", "/time night"], ["Clear sky", "/weather clear"], ["Storm", "/weather storm"],
		["Unlock all recipes", "/unlockall"], ["Castle in a Box", "/castle"], ["Map of Everything", "/map_everything"],
		["Boss Map", "/map_boss"], ["Biome Map", "/map_topo"], ["Cheat Sheet", "/cheatsheet"], ["Save the world", "/save"]]


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := UI.header("Admin", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var done := UI.button("Done", "GreenButton", 17)
	done.custom_minimum_size = Vector2(96, 40)
	done.pressed.connect(close)
	head.add_child(done)
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	# 1. Go to: the nearest boss, place or biome.
	var go := _card(row, "GO TO THE NEAREST...", 300)
	var go_scroll := ScrollContainer.new()
	go_scroll.custom_minimum_size = Vector2(290, 400)
	go_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	go.add_child(go_scroll)
	var go_list := VBoxContainer.new()
	go_list.add_theme_constant_override("separation", 6)
	go_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_scroll.add_child(go_list)
	for group in [["Bosses", GO_BOSSES], ["Places", GO_PLACES], ["Biomes", GO_BIOMES]]:
		go_list.add_child(UI.label(group[0], 14, UI.TEXT_SOFT))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for e in group[1]:
			grid.add_child(_cmd_button(e[0], "/goto " + e[1], 136))
		go_list.add_child(grid)
	# 2. Players.
	var pl := _card(row, "PLAYERS", 330)
	var pscroll := ScrollContainer.new()
	pscroll.custom_minimum_size = Vector2(320, 400)
	pscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pl.add_child(pscroll)
	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", 10)
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pscroll.add_child(_players_box)
	# 3. Me and the world.
	var me := _card(row, "ME & THE WORLD", 300)
	var mgrid := GridContainer.new()
	mgrid.columns = 2
	mgrid.add_theme_constant_override("h_separation", 6)
	mgrid.add_theme_constant_override("v_separation", 6)
	for e in ME:
		mgrid.add_child(_cmd_button(e[0], e[1], 140))
	me.add_child(mgrid)


func _card(parent: Control, title: String, w: float) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(w, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	col.add_child(UI.label(title, 13, UI.GOLD))
	parent.add_child(card)
	return col


func _cmd_button(text: String, command: String, w := 0.0, variation := "Button") -> Button:
	var b := UI.button(text, variation, 14)
	b.custom_minimum_size = Vector2(w, 34)
	b.tooltip_text = command
	b.pressed.connect(func() -> void:
		if main:
			main.run_admin(command))
	return b


func is_open() -> bool:
	return _root.visible


func open(online: Dictionary, me: int) -> void:
	_online = online
	_me = me
	_root.visible = true
	_draw_players()


func close() -> void:
	if _root.visible:
		_root.visible = false
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _draw_players() -> void:
	for c in _players_box.get_children():
		_players_box.remove_child(c)
		c.queue_free()
	var others := 0
	for peer in _online:
		if int(peer) == _me:
			continue
		others += 1
		var who: String = str(_online[peer])
		var arg := who.replace(" ", "")
		_players_box.add_child(UI.label(who, 17))
		var r1 := HBoxContainer.new()
		r1.add_theme_constant_override("separation", 6)
		for e in [["Go to", "/tpto "], ["Bring here", "/bring "], ["Freeze", "/freeze "], ["Unfreeze", "/unfreeze "]]:
			r1.add_child(_cmd_button(e[0], e[1] + arg))
		_players_box.add_child(r1)
		var r2 := HBoxContainer.new()
		r2.add_theme_constant_override("separation", 6)
		r2.add_child(UI.label("Send a hunt:", 14, UI.TEXT_SOFT))
		for e in [["Cats & dogs", 1], ["Bears", 2], ["Trolls", 3], ["A boss!", 4]]:
			var b := _cmd_button(e[0], "/hunt %s %d" % [arg, e[1]], 0.0, "RedButton" if e[1] == 4 else "Button")
			r2.add_child(b)
		_players_box.add_child(r2)
	if others == 0:
		var l := UI.label("Nobody else is here yet. When friends join, you can jump to them, bring them over, freeze them, or send a hunt after them!", 14, UI.TEXT_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_players_box.add_child(l)
