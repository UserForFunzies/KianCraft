extends Control
## Draws one map: the land's colors and height lines (like a hiking map)
## wherever the map has been, blank parchment everywhere else, your arrow,
## and the little pictures you put on it.
##
## Scroll to zoom, drag to move around, click to put the chosen picture
## down, right-click a picture to take it off.

const Blocks = preload("res://scripts/blocks.gd")
const Survival = preload("res://scripts/survival.gd")

signal mark_requested(x: float, z: float, kind: String)
signal unmark_requested(index: int)
signal hover_changed(text: String)

const PARCHMENT := Color(0.86, 0.79, 0.62)
const INK := Color(0.32, 0.22, 0.13)
const ZOOM_MIN := 0.06           # far enough out to see thousands of blocks at once
const ZOOM_MAX := 8.0
const MARK_PX := 30.0
const BUILD_USEC := 6000         # time per frame spent drawing new map pieces (keeps opening smooth)
const SEA := 28                  # world.gd SEA_LEVEL

var world: Node
var regions := {}                # Vector2i -> PackedByteArray (which pixels have been seen)
var marks: Array = []
var portals := {}                # survival.portals: shown where this map has been
var members: Array = []
var show_all_portals := false    # (portals are now a picture you put on the map yourself)          # party maps: [{"name", "x", "z", "yaw"}] of your party
var tool := ""                   # picture to put down on click ("" = just look around)
var player_pos := Vector3.ZERO
var player_yaw := 0.0
var center := Vector2.ZERO       # world x, z in the middle of the view
var zoom := 2.0                  # screen pixels per block

var _topo := {}                  # region key -> Image with the land colors (seen or not)
var _tex := {}                   # region key -> ImageTexture with only the seen part
var _dragging := false
var _moved := 0.0
var _frame_start := 0

static var _mark_icons := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true


var style := ""                  # "topo" = just the biome colors (no hills or contour lines)


func set_style(s: String) -> void:
	if s != style:
		style = s
		_topo.clear()
		_tex.clear()


func set_map(new_regions: Dictionary, new_marks: Array) -> void:
	regions = new_regions
	marks = new_marks
	_tex.clear()
	queue_redraw()


func regions_changed(keys: Array) -> void:
	for k in keys:
		_tex.erase(k)
	queue_redraw()


func center_on_player() -> void:
	center = Vector2(player_pos.x, player_pos.z)
	queue_redraw()


func zoom_by(k: float) -> void:
	_zoom_at(size / 2.0, k)


func _to_screen(w: Vector2) -> Vector2:
	return (w - center) * zoom + size / 2.0


func _to_world(s: Vector2) -> Vector2:
	return (s - size / 2.0) / zoom + center


func _zoom_at(at: Vector2, k: float) -> void:
	var before := _to_world(at)
	zoom = clampf(zoom * k, ZOOM_MIN, ZOOM_MAX)
	center += before - _to_world(at)  # keep the spot under the mouse still
	queue_redraw()


# --- Drawing -----------------------------------------------------------------------

func _draw() -> void:
	_frame_start = Time.get_ticks_usec()
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT)
	var span := float(Survival.MAP_SCALE * Survival.MAP_REGION)
	var tl := _to_world(Vector2.ZERO)
	var br := _to_world(size)
	var waiting := false
	for rz in range(floori(tl.y / span), floori(br.y / span) + 1):
		for rx in range(floori(tl.x / span), floori(br.x / span) + 1):
			var key := Vector2i(rx, rz)
			if not regions.has(key):
				continue
			var tex := _region_texture(key)
			if tex == null:
				waiting = true
				continue
			draw_texture_rect(tex, Rect2(_to_screen(Vector2(rx, rz) * span), Vector2(span, span) * zoom), false)
	# Faint grid every 128 blocks, like the squares on a paper map (hidden
	# when zoomed far out, where it would just be noise).
	var ink := Color(INK, 0.12 if span * zoom >= 24.0 else 0.0)
	for gx in range(floori(tl.x / span), floori(br.x / span) + 2):
		if ink.a == 0.0:
			break
		var sx := _to_screen(Vector2(gx * span, 0)).x
		draw_line(Vector2(sx, 0), Vector2(sx, size.y), ink, 1.0)
	for gz in range(floori(tl.y / span), floori(br.y / span) + 2):
		if ink.a == 0.0:
			break
		var sy := _to_screen(Vector2(0, gz * span)).y
		draw_line(Vector2(0, sy), Vector2(size.x, sy), ink, 1.0)
	var mfont := get_theme_default_font()
	for m in marks:
		var p := _to_screen(Vector2(m["x"], m["z"]))
		if m["kind"] == "portal":
			draw_texture_rect(portal_icon(true), Rect2(p - Vector2(14, 16), Vector2(28, 32)), false)
		else:
			draw_texture_rect(mark_icon(m["kind"]), Rect2(p - Vector2.ONE * MARK_PX / 2.0, Vector2.ONE * MARK_PX), false)
		if m.has("label"):
			draw_string_outline(mfont, p + Vector2(-70, MARK_PX * 0.5 + 14), str(m["label"]), HORIZONTAL_ALIGNMENT_CENTER, 140, 14, 4, Color(PARCHMENT, 0.9))
			draw_string(mfont, p + Vector2(-70, MARK_PX * 0.5 + 14), str(m["label"]), HORIZONTAL_ALIGNMENT_CENTER, 140, 14, INK)
	for pid in ({} if not show_all_portals else portals):
		var po: Dictionary = portals[pid]
		var d := Vector3i(1, 0, 0) if po["axis"] == "x" else Vector3i(0, 0, 1)
		var mid: Vector3i = po["min"] + d * (int(po["w"]) / 2)
		var mpx := floori(mid.x / float(Survival.MAP_SCALE))
		var mpz := floori(mid.z / float(Survival.MAP_SCALE))
		var key := Survival.map_region_of(mpx, mpz)
		if regions.has(key) and Survival.map_seen(regions[key], mpx, mpz):
			var sp := _to_screen(Vector2(mid.x + 0.5, mid.z + 0.5))
			draw_texture_rect(portal_icon(po.get("linked", false)), Rect2(sp - Vector2(14, 16), Vector2(28, 32)), false)
			if po.get("name", "") != "":
				draw_string(get_theme_default_font(), sp + Vector2(-40, 30), po["name"], HORIZONTAL_ALIGNMENT_CENTER, 80, 13, INK)
	_draw_members()
	_draw_player()
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x - 40, 40), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK)
	draw_line(Vector2(size.x - 31, 46), Vector2(size.x - 31, 70), INK, 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), INK, false, 3.0)
	if waiting:
		queue_redraw.call_deferred()  # finish drawing the rest next frame


## Party friends: a green arrow each, with their name.
func _draw_members() -> void:
	var font := get_theme_default_font()
	for m in members:
		var p := _to_screen(Vector2(m["x"], m["z"]))
		p = p.clamp(Vector2(14, 14), size - Vector2(14, 14))   # off the edge: pinned to it
		var yaw: float = m.get("yaw", 0.0)
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([p + fwd * 11.0, p - fwd * 7.0 + side * 8.0, p - fwd * 2.5, p - fwd * 7.0 - side * 8.0])
		draw_colored_polygon(pts, Color(0.25, 0.75, 0.35))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(1, 1, 1), 2.0)
		draw_string_outline(font, p + Vector2(-60, -14), str(m["name"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 4, Color(1, 1, 1, 0.9))
		draw_string(font, p + Vector2(-60, -14), str(m["name"]), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.12, 0.4, 0.18))


func _draw_player() -> void:
	var p := _to_screen(Vector2(player_pos.x, player_pos.z))
	var fwd := Vector2(-sin(player_yaw), -cos(player_yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([p + fwd * 13.0, p - fwd * 8.0 + side * 9.0, p - fwd * 3.0, p - fwd * 8.0 - side * 9.0])
	draw_colored_polygon(pts, Color(0.9, 0.16, 0.14))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1, 1, 1), 2.5)


## The picture of one piece of map (null = not drawn yet; try next frame).
func _region_texture(key: Vector2i) -> ImageTexture:
	if _tex.has(key):
		return _tex[key]
	if not _topo.has(key):
		if Time.get_ticks_usec() - _frame_start > BUILD_USEC:
			return null  # out of time this frame; the rest gets drawn next frame
		_topo[key] = _build_topo(key)
	var topo: Image = _topo[key]
	var bits: PackedByteArray = regions[key]
	var n := Survival.MAP_REGION
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			if Survival.map_seen(bits, x, z):
				img.set_pixel(x, z, topo.get_pixel(x, z))
			elif _seen_near(bits, x, z):
				var c := topo.get_pixel(x, z)
				img.set_pixel(x, z, Color(c.lerp(PARCHMENT, 0.6), 1.0))  # a soft edge to the fog
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


func _seen_near(bits: PackedByteArray, x: int, z: int) -> bool:
	var n := Survival.MAP_REGION
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var xx: int = x + o.x
		var zz: int = z + o.y
		if xx >= 0 and zz >= 0 and xx < n and zz < n and Survival.map_seen(bits, xx, zz):
			return true
	return false


## Land colors for a whole piece: biome color, lighter up high, hill shading,
## and a darker line every 8 blocks of height (contour lines).
func _build_topo(key: Vector2i) -> Image:
	var n := Survival.MAP_REGION
	var sc := Survival.MAP_SCALE
	var w := n + 2
	var heights := PackedInt32Array()
	heights.resize(w * w)
	var biomes: Array[String] = []
	biomes.resize(w * w)
	var x0 := key.x * n - 1
	var z0 := key.y * n - 1
	for j in w:
		for i in w:
			var wx := (x0 + i) * sc + sc / 2
			var wz := (z0 + j) * sc + sc / 2
			var info: Array = world.column_info(wx, wz)
			var it: int = world.island_top(wx, wz) if world.has_method("island_top") else -1
			heights[i + j * w] = it if it > 0 else info[0]
			biomes[i + j * w] = "island" if it > 0 else info[1]
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for z in n:
		for x in n:
			var k := (x + 1) + (z + 1) * w
			var h: int = heights[k]
			var c := land_color(h, biomes[k])
			if style == "topo":
				c = land_color(SEA + 6 if h >= SEA else h, biomes[k])   # flat biome colors
			elif h >= SEA:
				var nw: int = heights[k - 1 - w]
				var slope := clampf((h - nw) * 0.05, -0.3, 0.3)
				c = c.lightened(slope) if slope > 0.0 else c.darkened(-slope)
				var east: int = heights[k + 1]
				var south: int = heights[k + w]
				if h / 8 != east / 8 or h / 8 != south / 8:
					c = c.darkened(0.22)  # contour line
			img.set_pixel(x, z, c)
	return img


static func land_color(h: int, biome: String) -> Color:
	if h < SEA:
		var depth := clampf((SEA - h) / 14.0, 0.0, 1.0)
		return Color(0.47, 0.7, 0.9).lerp(Color(0.16, 0.32, 0.62), depth)
	var c: Color
	match biome:
		"forest":
			c = Color(0.27, 0.5, 0.24)
		"fall":
			c = Color(0.85, 0.48, 0.2)
		"spooky":
			c = Color(0.36, 0.3, 0.42)
		"chess":
			c = Color(0.78, 0.78, 0.8)
		"fastfood":
			c = Color(0.86, 0.56, 0.24)
		"sky":
			c = Color(0.62, 0.78, 0.5)
		"island":
			return Color(0.42, 0.75, 0.32).lightened(0.12)
		"desert":
			c = Color(0.9, 0.81, 0.55)
		"candy":
			c = Color(0.98, 0.7, 0.85)
		"mountain":
			c = Color(0.92, 0.94, 0.98) if h < SEA + 30 else Color(0.78, 0.8, 0.86)
		_:
			c = Color(0.5, 0.72, 0.36)
			if h > SEA + 36:
				c = Color(0.6, 0.6, 0.6)  # bare rocky tops
	if h <= SEA + 1 and biome != "mountain":
		c = Color(0.93, 0.87, 0.64)  # beach
	return c.lightened(clampf((h - SEA) / 90.0, 0.0, 0.25))


# --- Mouse ------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.2)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.2)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_moved = 0.0
			else:
				_dragging = false
				if _moved < 6.0 and tool != "":
					var w := _to_world(mb.position)
					mark_requested.emit(w.x, w.y, tool)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			var i := mark_at(mb.position)
			if i >= 0:
				unmark_requested.emit(i)
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			center -= mm.relative / zoom
			_moved += mm.relative.length()
			queue_redraw()
		var w := _to_world(mm.position)
		hover_changed.emit("X %d   Z %d" % [roundi(w.x), roundi(w.y)])


## The picture under this screen point (-1 = none). Top-most wins.
func mark_at(s: Vector2) -> int:
	for i in range(marks.size() - 1, -1, -1):
		var p := _to_screen(Vector2(marks[i]["x"], marks[i]["z"]))
		if p.distance_to(s) <= MARK_PX * 0.6:
			return i
	return -1


# --- Mark pictures -----------------------------------------------------------------

static var _portal_icons := {}


## A tiny portal: a dark violet stone frame around a glowing pink-purple swirl
## (dim and grey if it isn't linked yet).
static func portal_icon(linked: bool) -> ImageTexture:
	if not _portal_icons.has(linked):
		var img := Image.create_empty(14, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 14:
				var frame := x <= 1 or x >= 12 or y <= 1 or y >= 14
				var c: Color
				if frame:
					c = Color(0.3, 0.2, 0.4) if (x + y) % 3 != 0 else Color(1.0, 0.5, 0.82)
				else:
					var p := Vector2(x + 0.5, y + 0.5) - Vector2(7, 8)
					var sw := sin(p.length() * 1.3 - atan2(p.y, p.x) * 2.0)
					c = Color(0.62, 0.28, 0.95).lerp(Color(1.0, 0.6, 0.92), (sw + 1.0) * 0.5) if linked \
							else Color(0.3, 0.26, 0.36).lerp(Color(0.45, 0.4, 0.5), (sw + 1.0) * 0.5)
				img.set_pixel(x, y, c)
		_outline_any(img)
		img.resize(28, 32, Image.INTERPOLATE_NEAREST)
		_portal_icons[linked] = ImageTexture.create_from_image(img)
	return _portal_icons[linked]


static func _outline_any(img: Image) -> void:
	for x in img.get_width():
		img.set_pixel(x, 0, Color(0.12, 0.08, 0.05))
		img.set_pixel(x, img.get_height() - 1, Color(0.12, 0.08, 0.05))
	for y in img.get_height():
		img.set_pixel(0, y, Color(0.12, 0.08, 0.05))
		img.set_pixel(img.get_width() - 1, y, Color(0.12, 0.08, 0.05))


## A small picture of a map for an item frame: land colors where the map has
## been, parchment elsewhere. mini: MINI*MINI seen flags, c: the middle map pixel.
static func mini_texture(world: Node, mini: PackedByteArray, c: Vector2i) -> ImageTexture:
	var n := int(sqrt(mini.size()))
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var col := PARCHMENT
			if mini[x + y * n] == 1:
				var wx := (c.x - n / 2 + x) * Survival.MAP_SCALE + Survival.MAP_SCALE / 2
				var wz := (c.y - n / 2 + y) * Survival.MAP_SCALE + Survival.MAP_SCALE / 2
				var info: Array = world.column_info(wx, wz)
				var it: int = world.island_top(wx, wz) if world.has_method("island_top") else -1
				col = land_color(it if it > 0 else info[0], "island" if it > 0 else info[1])
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## A little 32x32 picture for each kind of mark.
static func mark_icon(kind: String) -> ImageTexture:
	if kind == "portal":
		return portal_icon(true)
	if not _mark_icons.has(kind):
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		_paint_mark(img, kind)
		_outline(img)
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		_mark_icons[kind] = ImageTexture.create_from_image(img)
	return _mark_icons[kind]


static func _paint_mark(img: Image, kind: String) -> void:
	var white := Color(0.98, 0.98, 0.96)
	for y in 16:
		for x in 16:
			var c := Color(0, 0, 0, 0)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 8))
			match kind:
				"house":
					if y >= 2 and y <= 7 and absf(x + 0.5 - 8.0) <= (y - 1) + 0.5:
						c = Color(0.78, 0.26, 0.2)  # roof
					elif y >= 8 and y <= 14 and x >= 3 and x <= 12:
						c = Color(0.95, 0.85, 0.62)  # walls
						if x >= 7 and x <= 8 and y >= 10:
							c = Color(0.5, 0.32, 0.18)  # door
						elif x >= 4 and x <= 5 and y >= 9 and y <= 10:
							c = Color(0.5, 0.75, 0.95)  # window
				"boss":
					var head := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(8, 7)) < 5.6
					var jaw := x >= 5 and x <= 10 and y >= 10 and y <= 13
					if head or jaw:
						c = white
						var eye := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(6, 7)) < 1.6 \
								or Vector2(x + 0.5, y + 0.5).distance_to(Vector2(10, 7)) < 1.6
						if eye:
							c = Color(0.85, 0.12, 0.12)  # spooky red eyes
						elif (x == 7 or x == 8) and y == 10:
							c = Color(0.2, 0.15, 0.15)  # nose
						elif y == 12 and x % 2 == 0:
							c = Color(0.2, 0.15, 0.15)  # teeth
				"treasure":
					# A big red X, like on a pirate map.
					var u := x + 0.5 - 8.0
					var v := y + 0.5 - 8.0
					if (absf(u - v) < 1.9 or absf(u + v) < 1.9) and absf(u) < 6.5 and absf(v) < 6.5:
						c = Color(0.86, 0.12, 0.1)
				"alert":
					if d < 7.2:
						c = Color(0.95, 0.45, 0.12)
						if (x == 7 or x == 8) and ((y >= 3 and y <= 9) or (y >= 11 and y <= 12)):
							c = white
				"question":
					if d < 7.2:
						c = Color(0.25, 0.5, 0.92)
						var q := [
							"..XXXX..",
							".XX..XX.",
							".....XX.",
							"....XX..",
							"...XX...",
							"...XX...",
							"........",
							"...XX...",
							"...XX...",
						]
						var qx := x - 4
						var qy := y - 3
						if qx >= 0 and qx < 8 and qy >= 0 and qy < q.size() and q[qy][qx] == "X":
							c = white
			if c.a > 0.0:
				img.set_pixel(x, y, c)


## Dark edge around a picture so it stands out on any land color.
static func _outline(img: Image) -> void:
	var src := img.duplicate()
	for y in 16:
		for x in 16:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx >= 0 and yy >= 0 and xx < 16 and yy < 16 and src.get_pixel(xx, yy).a > 0.5:
					img.set_pixel(x, y, Color(0.12, 0.08, 0.05, 0.9))
					break
