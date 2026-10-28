extends CanvasLayer
## The loading screen, from pressing Play (or Join) until the ground around
## you is ready. Two looks:
##   HD (Block textures Detailed or Ultra HD): a little floating island that
##     builds itself block by block in real 3D light with the game's own
##     textures, turning slowly, over a sky gradient.
##   Classic (Simple textures): a plain card with a spinning block.
## Both show what's happening, a progress bar and a tip.

const Blocks = preload("res://scripts/blocks.gd")
const ItemModels = preload("res://scripts/item_models.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Settings = preload("res://scripts/settings.gd")

const TIPS := [
	"Tip: two buckets of water side by side make water that never runs out.",
	"Tip: every biome has its own villagers. They sell things for toots!",
	"Tip: press E for your bag, and Stats to see what your gear really does.",
	"Tip: legendary drops roll how good they are. 100% is Perfect!",
	"Tip: right-click a fairy to make friends. Each color has its own power.",
	"Tip: a Research Table teaches you new recipes once you've seen the ingredients.",
	"Tip: flowing water pushes you. Swim upstream to get back to the source!",
]
const BUILD_TIME := 2.4          # seconds for the island to build itself
const MIN_SHOW := 1.2            # always show for at least this long (no flicker)
const FADE_TIME := 0.5

var progress := 0.0              # 0..1, set by main.gd
var hd := true
var _root: Control
var _bg: ColorRect
var _title: Label
var _status: Label
var _tip: Label
var _bar: ProgressBar
var _pct: Label
var _view: SubViewport
var _view_box: SubViewportContainer
var _spinner: TextureRect
var _island: Node3D
var _pieces: Array = []          # [{"node", "rest", "delay"}]
var _t := 0.0
var _shown := 0.0
var _closing := -1.0
var _tip_t := 0.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.035, 0.06, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_bg)
	# The HD sky: a soft dusk gradient behind the island.
	var sky := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.16, 0.22, 0.42))
	g.set_color(1, Color(0.95, 0.66, 0.48))
	g.add_point(0.62, Color(0.55, 0.45, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.name = "Sky"
	_root.add_child(sky)
	_view_box = SubViewportContainer.new()
	_view_box.stretch = true
	_view_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_view_box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_view_box.add_child(_view)
	# The words and the bar, low in the middle.
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.offset_bottom = -54
	col.custom_minimum_size = Vector2(560, 0)
	col.offset_left = -280
	col.offset_right = 280
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	_root.add_child(col)
	_spinner = UI.icon_rect(null, 64)
	_spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spinner.pivot_offset = Vector2(32, 32)
	col.add_child(_spinner)
	_title = UI.make_title(UI.label("Loading...", 34))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_status = UI.label("", 16, UI.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(480, 18)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := UI.box(Color(0.86, 0.68, 0.36), 6, 0)
	fill.set_content_margin_all(0)
	var back := UI.box(Color(0.06, 0.05, 0.07, 0.9), 6, 1, Color(0.5, 0.38, 0.21))
	back.set_content_margin_all(0)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	bar_row.add_child(_bar)
	_pct = UI.label("0%", 15, UI.GOLD)
	_pct.custom_minimum_size = Vector2(44, 0)
	bar_row.add_child(_pct)
	col.add_child(bar_row)
	_tip = UI.label("", 14, UI.TEXT_SOFT)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tip)


func is_showing() -> bool:
	return _root.visible


## Shows the screen. title: "Loading Kian's World".
func show_loading(title: String, status := "") -> void:
	hd = int(Settings.gfx.get("detail_textures", 1)) >= 1
	_title.text = title
	_status.text = status
	_tip.text = TIPS[randi() % TIPS.size()]
	progress = 0.0
	_t = 0.0
	_shown = 0.0
	_closing = -1.0
	_root.modulate.a = 1.0
	_root.visible = true
	_root.get_node("Sky").visible = hd
	_view_box.visible = hd
	_spinner.visible = not hd
	if hd:
		_build_island()
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		_spinner.texture = preload("res://scripts/items.gd").icon("grass")


func set_status(text: String) -> void:
	_status.text = text


## Fades away (once it's been up for a moment).
func finish() -> void:
	if _root.visible and _closing < 0.0:
		_closing = 0.0


func hide_now() -> void:
	_root.visible = false
	_closing = -1.0
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_island()


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_t += delta
	_shown += delta
	_bar.value = lerpf(_bar.value, progress, minf(1.0, delta * 6.0))
	_pct.text = "%d%%" % roundi(_bar.value * 100.0)
	_tip_t += delta
	if _tip_t > 6.0:
		_tip_t = 0.0
		_tip.text = TIPS[randi() % TIPS.size()]
	if not hd:
		_spinner.rotation = sin(_t * 3.0) * 0.4
		_spinner.scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 6.0))
	else:
		_animate_island(delta)
	if _closing >= 0.0 and _shown >= MIN_SHOW:
		_closing += delta
		_root.modulate.a = 1.0 - clampf(_closing / FADE_TIME, 0.0, 1.0)
		if _closing >= FADE_TIME:
			hide_now()


# --- The HD island ------------------------------------------------------------------

func _clear_island() -> void:
	for c in _view.get_children():
		c.queue_free()
	_pieces.clear()
	_island = null


func _build_island() -> void:
	_clear_island()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.78)
	env.ambient_light_energy = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-35), 0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	_view.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34
	cam.position = Vector3(0, 9.0, 27.0)
	_view.add_child(cam)
	cam.look_at(Vector3(0, -1.2, 0), Vector3.UP)
	_island = Node3D.new()
	_island.position = Vector3(0, 0.6, 0)
	_view.add_child(_island)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = Blocks.get_atlas()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var meshes := {}
	var cells := _island_cells()
	var n := cells.size()
	for i in n:
		var cell: Array = cells[i]
		var b: int = cell[1]
		if not meshes.has(b):
			meshes[b] = ItemModels.cube_mesh(b)
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[b]
		mi.material_override = mat
		var rest: Vector3 = Vector3(cell[0]) - Vector3(0.5, 0, 0.5)
		mi.position = rest + Vector3(0, 9, 0)
		mi.visible = false
		_island.add_child(mi)
		# Bottom layers first, then up: an island growing out of nothing.
		var delay: float = (float(cell[0].y + 4) / 12.0) * BUILD_TIME * 0.75 + randf() * 0.25
		_pieces.append({"node": mi, "rest": rest, "delay": delay})


## The island's blocks: an upside-down cone of stone and dirt, grass on top,
## a little tree, a pond and a flower or two.
func _island_cells() -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in range(-4, 1):
		var r := 3.6 + y * 0.75
		for z in range(-4, 5):
			for x in range(-4, 5):
				var d := Vector2(x, z).length()
				if d > r + rng.randf() * 0.4:
					continue
				var b := Blocks.STONE if y < -1 else Blocks.DIRT
				if y == 0:
					b = Blocks.GRASS
					if x >= 1 and x <= 2 and z >= -1 and z <= 0:
						b = Blocks.WATER
				out.append([Vector3i(x, y, z), b])
	for y in range(1, 4):
		out.append([Vector3i(-2, y, 1), Blocks.LOG])
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for dy in range(3, 6):
				if absi(dx) + absi(dz) + (dy - 3) <= 3 and not (dx == 0 and dz == 0 and dy == 3):
					out.append([Vector3i(-2 + dx, dy, 1 + dz), Blocks.LEAVES])
	out.append([Vector3i(2, 1, 2), Blocks.CHEST])
	out.append([Vector3i(0, 1, 2), Blocks.WORKBENCH_1])
	return out


func _animate_island(delta: float) -> void:
	if _island == null:
		return
	_island.rotation.y += delta * 0.35
	_island.position.y = 0.6 + sin(_t * 1.2) * 0.12
	for p in _pieces:
		var k: float = (_t - p["delay"]) / 0.5
		var node: MeshInstance3D = p["node"]
		if k <= 0.0:
			continue
		node.visible = true
		if k >= 1.0:
			node.position = p["rest"]
			continue
		var drop := (1.0 - k) * (1.0 - k) * 9.0
		node.position = p["rest"] + Vector3(0, drop, 0)
