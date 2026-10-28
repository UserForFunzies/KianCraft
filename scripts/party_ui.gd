extends CanvasLayer
## The party window (P): who's online, who's in your party, invite, leave.
## Party members see each other's name tags from up to 200 blocks away,
## even through hills.

const UI = preload("res://scripts/ui_theme.gd")

signal closed

var survival: Node
var players_root: Node3D
var local_player: Node3D
var _root: Control
var _party_box: VBoxContainer
var _online_box: VBoxContainer
var _party_title: Label
var _leave: Button
var _refresh_timer := 0.0


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
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := UI.header("Party", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var done := UI.button("Done", "GreenButton", 17)
	done.custom_minimum_size = Vector2(96, 40)
	done.pressed.connect(close)
	head.add_child(done)
	box.add_child(head)
	var tip := UI.label("Party members see each other's names from far away (up to 200 blocks), and later can share a party map.", 14, UI.TEXT_SOFT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(700, 0)
	box.add_child(tip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	for side in 2:
		var card := PanelContainer.new()
		card.theme_type_variation = "CardPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(340, 300)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		card.add_child(col)
		if side == 0:
			_party_title = UI.label("YOUR PARTY", 13, UI.GOLD)
			col.add_child(_party_title)
			_party_box = VBoxContainer.new()
			_party_box.add_theme_constant_override("separation", 6)
			_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.add_child(_party_box)
			_leave = UI.button("Leave party", "RedButton", 15)
			_leave.pressed.connect(func() -> void: survival.req_party_leave.rpc_id(1))
			col.add_child(_leave)
		else:
			col.add_child(UI.label("EVERYONE ONLINE", 13, UI.GOLD))
			_online_box = VBoxContainer.new()
			_online_box.add_theme_constant_override("separation", 6)
			col.add_child(_online_box)
		row.add_child(card)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.visible = true
	redraw()


func close() -> void:
	if _root.visible:
		_root.visible = false
		closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("party")):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not is_open():
		return
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 1.0   # distances change as people move
		redraw()


func _distance_to(peer: int) -> float:
	if local_player == null or players_root == null:
		return -1.0
	var n: Node3D = players_root.get_node_or_null(str(peer))
	if n == null or n == local_player:
		return -1.0
	return n.global_position.distance_to(local_player.global_position)


func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _person_row(entry: Dictionary, button: Button) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = Color(0.4, 0.9, 0.5) if entry.get("online", true) else Color(0.45, 0.47, 0.52)
	line.add_child(dot)
	var name_text: String = entry["name"]
	if entry.get("leader", false):
		name_text += "  ★"
	if entry.get("me", false):
		name_text += "  (you)"
	var l := UI.label(name_text, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(l)
	var d := _distance_to(int(entry.get("peer", 0))) if entry.get("online", true) else -1.0
	var where := UI.label("%d m" % roundi(d) if d >= 0.0 else ("" if entry.get("online", true) else "offline"), 14, UI.TEXT_SOFT)
	line.add_child(where)
	if button:
		line.add_child(button)
	return line


func redraw() -> void:
	if survival == null:
		return
	_clear(_party_box)
	_clear(_online_box)
	var my_peer := multiplayer.get_unique_id()
	var pid: int = survival.my_party()
	var party: Dictionary = survival.parties.get(pid, {})
	var i_lead: bool = not party.is_empty() and party["leader_peer"] == my_peer
	if party.is_empty():
		_party_title.text = "YOUR PARTY"
		var none := UI.label("You're not in a party yet.\nInvite someone from the list!", 16, UI.TEXT_SOFT)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_party_box.add_child(none)
		_leave.visible = false
	else:
		_party_title.text = str(party["name"]).to_upper()
		_leave.visible = true
		for m in party["members"]:
			var kick: Button = null
			if i_lead and m["peer"] != my_peer:
				kick = UI.button("Remove", "FlatButton", 14)
				var key: String = m["key"]
				kick.pressed.connect(func() -> void: survival.req_party_kick.rpc_id(1, key))
			var entry: Dictionary = m.duplicate()
			entry["me"] = m["peer"] == my_peer
			_party_box.add_child(_person_row(entry, kick))
	var others := 0
	for p in survival.party_roster:
		if p["peer"] == my_peer:
			continue
		others += 1
		var b: Button = null
		if pid == 0 or p["party"] != pid:
			b = UI.button("Invite", "BlueButton", 14)
			var target: int = p["peer"]
			b.pressed.connect(func() -> void: survival.req_party_invite.rpc_id(1, target))
		var entry: Dictionary = p.duplicate()
		entry["online"] = true
		var row := _person_row(entry, b)
		if p["party"] != 0 and p["party"] != pid:
			var tag := UI.label(str(survival.parties.get(p["party"], {}).get("name", "in a party")), 12, UI.TEXT_SOFT)
			row.add_child(tag)
			row.move_child(tag, 2)
		_online_box.add_child(row)
	if others == 0:
		var alone := UI.label("Nobody else is here right now.\nWhen a friend joins, they'll show up here.", 16, UI.TEXT_SOFT)
		alone.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_online_box.add_child(alone)
