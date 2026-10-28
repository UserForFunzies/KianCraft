extends RefCounted
## The pictures behind every menu: dark worn-metal panels with a thin double
## gold trim and gem corners, beveled buttons with cut corners, sunken item
## slots. All painted here in code (no image files) and cut into nine-patch
## styles by ui_theme.gd.

const GOLD_HI := Color(0.9, 0.72, 0.4)
const GOLD := Color(0.74, 0.57, 0.31)
const GOLD_DIM := Color(0.5, 0.38, 0.21)
const BRONZE := Color(0.34, 0.25, 0.16)
const EDGE := Color(0.015, 0.01, 0.015)
const IRON := Color(0.045, 0.036, 0.048)      # near-black with a little royal plum
const VELVET := Color(0.1, 0.05, 0.09)        # deep plum, for the middle of windows

static var _cache := {}


## How far a pixel is inside a box with cut (chamfered) corners. < 0 = outside.
static func _inside(x: int, y: int, w: int, h: int, cut: int) -> float:
	var fx := x + 0.5
	var fy := y + 0.5
	var rx := w - fx
	var ry := h - fy
	var d := minf(minf(fx, fy), minf(rx, ry))
	var k := 0.7071
	d = minf(d, (fx + fy - cut) * k)
	d = minf(d, (rx + fy - cut) * k)
	d = minf(d, (fx + ry - cut) * k)
	d = minf(d, (rx + ry - cut) * k)
	return d


static func _grain(rng: RandomNumberGenerator, c: Color, amount: float) -> Color:
	var n := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + n, 0, 1), clampf(c.g + n * 0.9, 0, 1), clampf(c.b + n * 0.8, 0, 1), c.a)


## A small gold diamond with a dark gem in it (panel corners).
static func _gem(img: Image, cx: int, cy: int, r: int, gem: Color) -> void:
	for dy in range(-r - 1, r + 2):
		for dx in range(-r - 1, r + 2):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var m := absi(dx) + absi(dy)
			if m == r + 1:
				img.set_pixel(x, y, EDGE)
			elif m <= r:
				var c := GOLD_HI.lerp(GOLD_DIM, float(dy + r) / (2.0 * r))
				if m <= r - 2:
					c = gem.lightened(0.25) if dx + dy < 0 else gem
				img.set_pixel(x, y, c)


## The big window frame: worn dark iron, a bright and a dim gold line, an
## inner shadow, and a gem in each corner.
static func panel() -> Image:
	if _cache.has("panel"):
		return _cache["panel"]
	var S := 112
	var cut := 10
	var C := 26                    # how far the gold corner brackets reach (inside PANEL_MARGIN)
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in S:
		for x in S:
			var d := _inside(x, y, S, S, cut)
			var c := Color(0, 0, 0, 0)
			var top := 1.0 - float(y) / S
			var corner := (x < C or x >= S - C) and (y < C or y >= S - C)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = EDGE
			elif d < 2.0:
				c = GOLD_HI.lerp(GOLD, 1.0 - top)
			elif d < 4.0:
				c = Color(0.1, 0.075, 0.05)
			elif d < 5.0:
				c = GOLD_DIM
			elif corner and d < 7.0:
				c = GOLD.lerp(GOLD_DIM, (d - 5.0) / 2.0)   # a thicker gold bracket at each corner
			elif corner and d < 8.0:
				c = EDGE
			else:
				var mid := 1.0 - clampf(Vector2(x - S * 0.5, y - S * 0.5).length() / (S * 0.6), 0.0, 1.0)
				c = _grain(rng, IRON.lerp(VELVET, mid * 0.5), 0.01)
				if d < 11.0:
					c = c.darkened((11.0 - d) / 6.0 * 0.5)   # inner shadow under the trim
			if c.a > 0.0:
				c.a = 0.97 if d >= 8.0 or (not corner and d >= 5.0) else 1.0
			img.set_pixel(x, y, c)
	var gem := Color(0.5, 0.08, 0.06)
	for p in [Vector2i(9, 9), Vector2i(S - 10, 9), Vector2i(9, S - 10), Vector2i(S - 10, S - 10)]:
		_gem(img, p.x, p.y, 5, gem)
	_cache["panel"] = img
	return img


## A lighter frame for cards inside windows (and item cards: `rim` is the
## rarity color).
static func card(rim: Color = BRONZE) -> Image:
	var key := "card_" + rim.to_html()
	if _cache.has(key):
		return _cache[key]
	var S := 48
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in S:
		for x in S:
			var d := _inside(x, y, S, S, 5)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = rim
			elif d < 2.0:
				c = Color(0.03, 0.025, 0.02, 0.95)
			else:
				c = _grain(rng, Color(0.075, 0.055, 0.07, 0.9), 0.01)
				if y < 6:
					c = c.lightened(0.04 * (6 - y) / 6.0)
			img.set_pixel(x, y, c)
	_cache[key] = img
	return img


## The little rounded bubbles on the HUD (toots, item name, status).
static func pill() -> Image:
	if _cache.has("pill"):
		return _cache["pill"]
	var S := 32
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := _inside(x, y, S, S, 6)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = Color(0, 0, 0, 0.6)
			elif d < 2.0:
				c = Color(GOLD_DIM, 0.85)
			else:
				c = Color(0.035, 0.03, 0.025, 0.74)
			img.set_pixel(x, y, c)
	_cache["pill"] = img
	return img


## A beveled button with cut corners. state: normal, hover, pressed, disabled.
static func button(base: Color, state: String) -> Image:
	var key := "btn_%s_%s" % [base.to_html(), state]
	if _cache.has(key):
		return _cache[key]
	var W := 64
	var H := 40
	var cut := 6
	var rim: Color = {"normal": GOLD, "hover": Color(1.0, 0.85, 0.5), "pressed": GOLD_DIM.lerp(GOLD, 0.5),
			"disabled": Color(0.3, 0.28, 0.26)}[state]
	var b := base
	if state == "hover":
		b = base.lightened(0.12)
	elif state == "pressed":
		b = base.darkened(0.25)
	elif state == "disabled":
		var g := base.get_luminance() * 0.7
		b = Color(g, g, g * 0.95)
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var d := _inside(x, y, W, H, cut)
			var t := float(y) / (H - 1)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = EDGE
			elif d < 2.0:
				c = rim.lightened(0.18 * (1.0 - t)).darkened(0.2 * t)
			elif d < 3.0:
				c = b.darkened(0.65)
			elif d < 4.0 and state != "disabled":
				c = Color(rim, 0.55).blend(Color(b.darkened(0.3), 0.45))   # a thin inner gold line
				c.a = 1.0
			else:
				if state == "pressed":
					c = b.darkened(0.2 * (1.0 - t)).lightened(0.06 * t)   # pushed in: dark at the top
				else:
					c = b.lightened(0.22 * (1.0 - t)).darkened(0.3 * t)
					if y >= 4 and y <= 5:
						c = c.lightened(0.08)   # a shine near the top
				if d < 4.0:
					c = c.lightened(0.1) if y < H / 2 and state != "pressed" else c.darkened(0.15)
			img.set_pixel(x, y, c)
	if state != "disabled":
		for sx in [4, W - 5]:
			_gem(img, sx, H / 2, 2, Color(0.55, 0.1, 0.12) if state != "pressed" else Color(0.35, 0.06, 0.08))
	_cache[key] = img
	return img


## An ornate on/off switch: a dark track with a gold rim, and a gem that
## slides to the right and glows when it's on.
static func toggle(on: bool, disabled := false) -> Image:
	var key := "toggle_%s_%s" % [on, disabled]
	if _cache.has(key):
		return _cache[key]
	var W := 46
	var H := 24
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var rim := GOLD if not disabled else Color(0.3, 0.28, 0.26)
	for y in H:
		for x in W:
			var d := _inside(x, y, W, H, 7)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = EDGE
			elif d < 2.0:
				c = rim
			else:
				var lit := Color(0.12, 0.28, 0.16) if on else Color(0.05, 0.04, 0.05)
				c = lit.darkened(0.35 * float(y) / H)
				if d < 4.0:
					c = c.darkened(0.4)
			img.set_pixel(x, y, c)
	var cx := W - 12 if on else 11
	var gem := Color(0.35, 0.85, 0.45) if on else Color(0.35, 0.3, 0.32)
	if disabled:
		gem = Color(0.3, 0.3, 0.3)
	for dy in range(-8, 9):
		for dx in range(-8, 9):
			var r := Vector2(dx, dy).length()
			var x := cx + dx
			var y := H / 2 + dy
			if x < 0 or y < 0 or x >= W or y >= H or r > 8.2:
				continue
			var c: Color = EDGE if r > 7.2 else (GOLD_HI.lerp(GOLD_DIM, float(dy + 8) / 16.0) if r > 5.0 else (gem.lightened(0.35) if dx + dy < -2 else gem))
			img.set_pixel(x, y, c)
	_cache[key] = img
	return img


## A square checkbox with a gold rim; checked shows a gold diamond.
static func checkbox(on: bool) -> Image:
	var key := "check_%s" % on
	if _cache.has(key):
		return _cache[key]
	var S := 22
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := _inside(x, y, S, S, 3)
			var c := Color(0, 0, 0, 0)
			if d >= 0.0:
				c = EDGE if d < 1.0 else (GOLD if d < 2.0 else Color(0.04, 0.03, 0.04))
			img.set_pixel(x, y, c)
	if on:
		_gem(img, S / 2, S / 2, 6, Color(0.55, 0.1, 0.12))
	_cache[key] = img
	return img


## A sunken square for items. state: normal, hover, selected.
static func slot(state: String) -> Image:
	var key := "slot_" + state
	if _cache.has(key):
		return _cache[key]
	var S := 48
	var rim: Color = {"normal": BRONZE, "hover": GOLD, "selected": GOLD_HI}[state]
	var thick := 2.0 if state == "selected" else 1.0
	var img := Image.create_empty(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := _inside(x, y, S, S, 3)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = EDGE
			elif d < 1.0 + thick:
				c = rim
			else:
				c = Color(0.04, 0.035, 0.032, 0.92).lightened(0.05 * float(y) / S)
				if d < 1.0 + thick + 3.0:
					c = c.darkened(0.5 * (1.0 + thick + 3.0 - d) / 3.0)   # sunken
				if state == "selected":
					c = c.lerp(Color(GOLD_HI, c.a), 0.12)
				elif state == "hover":
					c = c.lightened(0.04)
			img.set_pixel(x, y, c)
	_cache[key] = img
	return img


## A text box (dark and sunken, gold when you're typing in it).
static func field(focus: bool) -> Image:
	var key := "field_%s" % focus
	if _cache.has(key):
		return _cache[key]
	var W := 48
	var H := 32
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var d := _inside(x, y, W, H, 3)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = GOLD if focus else BRONZE
			else:
				c = Color(0.03, 0.026, 0.024, 0.9)
				if d < 4.0:
					c = c.darkened(0.4 * (4.0 - d) / 3.0)
			img.set_pixel(x, y, c)
	_cache[key] = img
	return img


## A tab that's chosen: a gold line underneath with a soft glow rising from it.
static func tab_on() -> Image:
	if _cache.has("tab_on"):
		return _cache["tab_on"]
	var W := 32
	var H := 36
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var c := Color(GOLD_HI, 0.18 * pow(float(y) / H, 2.0))
			if y >= H - 2:
				c = GOLD_HI if y == H - 2 else GOLD_DIM
			img.set_pixel(x, y, c)
	_cache["tab_on"] = img
	return img


## A divider under titles: a gold diamond, then a line that fades away.
static func divider() -> Image:
	if _cache.has("divider"):
		return _cache["divider"]
	var W := 256
	var H := 11
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	var mid := H / 2
	for x in range(10, W):
		var a := 1.0 if x < W - 80 else float(W - x) / 80.0
		img.set_pixel(x, mid, Color(GOLD, 0.95 * a))
		img.set_pixel(x, mid + 1, Color(EDGE, 0.6 * a))
	_gem(img, 5, mid, 4, Color(0.45, 0.08, 0.06))
	_cache["divider"] = img
	return img


## Grabber / thin bar pieces (scroll bars, sliders): a gold-edged bar.
static func bar(fill: Color) -> Image:
	var key := "bar_" + fill.to_html()
	if _cache.has(key):
		return _cache[key]
	var W := 16
	var H := 16
	var img := Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var d := _inside(x, y, W, H, 2)
			var c := Color(0, 0, 0, 0)
			if d < 0.0:
				pass
			elif d < 1.0:
				c = Color(GOLD_DIM, 0.9)
			else:
				c = fill.lightened(0.18 * (1.0 - float(y) / H)).darkened(0.2 * float(y) / H)
			img.set_pixel(x, y, c)
	_cache[key] = img
	return img
