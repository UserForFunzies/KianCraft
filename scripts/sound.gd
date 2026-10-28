extends Node
## Every sound in the game, made in code (like the textures), so there are no
## audio files. Sounds are built once when the game starts.
##
## Use it from anywhere:
##   Sound.play("click")                 # flat sound (menus, your own hurt...)
##   Sound.play_at("break_stone", pos)   # sound coming from a place in the world
## Volumes come from settings.gd: Master, Effects, Ambience and Interface buses.

const Blocks = preload("res://scripts/blocks.gd")
const Settings = preload("res://scripts/settings.gd")

const RATE := 22050
const POOL_3D := 24
const POOL_2D := 10
const BUSES := ["Effects", "Ambience", "Interface"]

static var instance: Node

var _streams := {}             # name -> Array[AudioStreamWAV] (variants)
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _loops := {}               # ambience name -> AudioStreamPlayer
var _beacon: AudioStreamPlayer3D
var _beacon_target := 0.0
var _beacon_level := 0.0
var _beacon_at := Vector3.ZERO
var _loop_target := {}         # ambience name -> volume 0..1
var enabled := true
var sounds_ready := false             # sounds are built on a background thread at startup
var _build_task := -1
var played := {}               # sound name -> times played (handy for checking)


# --- Static helpers (safe to call even if sound is off) -------------------------------

static func play(sound: String, volume_db := 0.0, pitch := 1.0, bus := "Effects") -> void:
	if instance and instance.enabled and instance.sounds_ready:
		instance._play2d(sound, volume_db, pitch, bus)


static func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if instance and instance.enabled and instance.sounds_ready:
		instance._play3d(sound, pos, volume_db, pitch)


static func ui(sound := "click") -> void:
	play(sound, -4.0, randf_range(0.97, 1.03), "Interface")


## Which family of sounds a block makes when stepped on, hit or broken.
static func material_of(block: int) -> String:
	if Blocks.is_plant(block):
		return "grass"
	if block in [Blocks.PALM_LEAVES, Blocks.MAPLE_LEAVES, Blocks.GOLDEN_LEAVES, Blocks.FALL_GRASS, Blocks.HAY_BALE, Blocks.DEAD_GRASS]:
		return "grass"
	if block == Blocks.GHOST_LANTERN:
		return "glass"
	if block in [Blocks.PUMPKIN, Blocks.JACK_O_LANTERN]:
		return "soft"
	if Blocks.IS_WOOD[block]:
		return "wood"
	match block:
		Blocks.GRASS, Blocks.DIRT, Blocks.LEAVES:
			return "grass"
		Blocks.SAND:
			return "sand"
		Blocks.LOG, Blocks.PLANKS, Blocks.WORKBENCH_1, Blocks.WORKBENCH_2, Blocks.WORKBENCH_3, \
				Blocks.SHOP, Blocks.CHEST, Blocks.BED, Blocks.BED_FOOT, Blocks.SCRIBE, Blocks.ITEM_FRAME, Blocks.ARMOR_STAND, Blocks.DOOR_WOOD, Blocks.DOOR_WOOD_OPEN, \
				Blocks.CANDY_CANE, Blocks.CACTUS, Blocks.TORCH:
			return "wood"
		Blocks.GLASS, Blocks.LAMP:
			return "glass"
		Blocks.DOOR_IRON, Blocks.DOOR_IRON_OPEN, Blocks.DOOR_TITANIUM, Blocks.DOOR_TITANIUM_OPEN, Blocks.GOLD_BLOCK:
			return "metal"
		Blocks.FROSTING, Blocks.CAKE, Blocks.COTTON_CANDY, Blocks.CUTIE_ORE, Blocks.CUTE_CRAFTER:
			return "soft"
	return "stone"


## Mob type -> its voice.
const VOICES := {
	"bunny": "squeak", "marshmallow": "squeak", "gummy_bear": "squeak", "chicken": "cluck",
	"deer": "bleat", "boar": "oink", "peppermint_pig": "oink", "ram": "baa",
	"wolf": "growl", "cougar": "growl", "bear": "growl_low", "sand_bear": "growl_low",
	"spider": "hiss", "sand_spider": "hiss", "king_cougar": "roar", "qtmame": "giggle",
	"snow_hare": "squeak", "mountain_goat": "baa", "polar_bear": "growl_low", "dire_wolf": "growl",
	"squirrel": "squeak", "hedgehog": "squeak", "fox": "squeak", "gremlin": "hiss", "cave_troll": "growl_low",
	"grimskull": "roar", "skeleton": "hiss", "skeleton_archer": "hiss", "skeleton_knight": "growl", "bone_hound": "growl",
	"black_cat": "squeak", "crow": "cluck", "scarecrow": "growl", "zombie": "growl_low", "ghost": "hiss", "witch": "hiss",
	"yeti": "roar", "fairy": "giggle",
}


# --- Setup ------------------------------------------------------------------------

func _ready() -> void:
	instance = self
	_setup_buses()
	if enabled:
		_build_task = WorkerThreadPool.add_task(_build_all)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Effects"
		p.unit_size = 6.0
		p.max_distance = 40.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	_beacon = AudioStreamPlayer3D.new()
	_beacon.bus = "Ambience"
	_beacon.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_beacon.panning_strength = 1.0
	_beacon.volume_db = -80.0
	add_child(_beacon)
	for loop_name in ["wind", "crickets", "cave", "rain"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.volume_db = -80.0
		add_child(p)
		_loops[loop_name] = p
		_loop_target[loop_name] = 0.0
	Settings.on_changed(apply_volumes)
	apply_volumes()


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	# A touch of room echo on effects makes caves and builds feel less flat.
	var fx := AudioServer.get_bus_index("Effects")
	if AudioServer.get_bus_effect_count(fx) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.35
		rev.wet = 0.08
		rev.dry = 1.0
		AudioServer.add_bus_effect(fx, rev)


static func _db(v: float) -> float:
	return linear_to_db(maxf(v, 0.0001))


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, _db(Settings.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Effects"), _db(Settings.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), _db(Settings.ambience_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Interface"), _db(Settings.ui_volume))


func _variant(sound: String) -> AudioStream:
	var v: Array = _streams.get(sound, [])
	return v[randi() % v.size()] if not v.is_empty() else null


func _play2d(sound: String, volume_db: float, pitch: float, bus: String) -> void:
	var s := _variant(sound)
	if s == null:
		return
	played[sound] = played.get(sound, 0) + 1
	var p := _pool2d[_next2d]
	_next2d = (_next2d + 1) % _pool2d.size()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _play3d(sound: String, pos: Vector3, volume_db: float, pitch: float) -> void:
	var s := _variant(sound)
	if s == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > 42.0:
		return  # too far away to hear
	played[sound] = played.get(sound, 0) + 1
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


# --- Ambience ----------------------------------------------------------------------

## Called a few times a second by main.gd. Each loop fades toward its target.
## QtMaMe's tune. strength 0..1 (0 = silent). It's always heard from her
## direction (placed a few blocks from you that way), and louder when she's near.
func set_beacon(at: Vector3, strength: float) -> void:
	_beacon_target = strength
	_beacon_at = at


func set_ambience(targets: Dictionary) -> void:
	for k in _loop_target:
		_loop_target[k] = targets.get(k, 0.0)


func stop_ambience() -> void:
	set_ambience({})
	_beacon_target = 0.0


func _exit_tree() -> void:
	if _build_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1


func _process(delta: float) -> void:
	if _build_task >= 0 and WorkerThreadPool.is_task_completed(_build_task):
		WorkerThreadPool.wait_for_task_completion(_build_task)
		_build_task = -1
		for k in _loops:
			_loops[k].stream = _streams[k][0]
		sounds_ready = true
		print("Sounds ready (%d)" % _streams.size())
	if not sounds_ready:
		return
	_update_beacon(delta)
	for k in _loops:
		var p: AudioStreamPlayer = _loops[k]
		var cur := db_to_linear(p.volume_db) if p.playing else 0.0
		var target: float = _loop_target[k]
		cur = move_toward(cur, target, delta * 0.35)
		if cur <= 0.001:
			if p.playing:
				p.stop()
			p.volume_db = -80.0
		else:
			p.volume_db = _db(cur)
			if not p.playing:
				p.play()


func _update_beacon(delta: float) -> void:
	if _beacon.stream == null and _streams.has("sparkle"):
		_beacon.stream = _streams["sparkle"][0]
	_beacon_level = move_toward(_beacon_level, _beacon_target * 0.6, delta * 0.25)
	if _beacon_level <= 0.001:
		if _beacon.playing:
			_beacon.stop()
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var to := _beacon_at - cam.global_position
		to.y = 0.0
		var dir := to.normalized() if to.length() > 0.5 else Vector3.ZERO
		_beacon.global_position = cam.global_position + dir * 4.0  # from her direction
	_beacon.volume_db = _db(_beacon_level)
	if not _beacon.playing:
		_beacon.play()


# --- Making the sounds -------------------------------------------------------------
# Everything is built from two ingredients: noise (rustles, crunches, whooshes)
# and tones (beeps, chimes, voices), shaped by quick fade-ins and fade-outs.

class Synth:
	var data := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()

	func _init(seconds: float, seed_value: int) -> void:
		data.resize(int(seconds * RATE))
		rng.seed = seed_value

	## Filtered noise. cutoff_hz goes from start to end over the sound.
	## smooth = one more filter stage: rounder and less hissy (good for sounds you hear a lot).
	func noise(start: float, length: float, gain: float, cut_a: float, cut_b: float, attack := 0.004, curve := 3.0, smooth := false) -> void:
		var lp := 0.0
		var lp2 := 0.0
		var lp3 := 0.0
		var n := int(length * RATE)
		var s0 := int(start * RATE)
		for i in n:
			var t := float(i) / n
			var cut := lerpf(cut_a, cut_b, t)
			var a := clampf(TAU * cut / RATE, 0.0, 1.0)
			lp += (rng.randf_range(-1.0, 1.0) - lp) * a
			lp2 += (lp - lp2) * a
			lp3 += (lp2 - lp3) * a
			var env := minf(1.0, i / maxf(attack * RATE, 1.0)) * pow(1.0 - t, curve)
			var j := s0 + i
			if j < data.size():
				data[j] += (lp3 * 3.0 if smooth else lp2 * 2.2) * gain * env

	## A tone sliding from f_a to f_b. shape: "sine", "square", "tri", "saw".
	func tone(start: float, length: float, gain: float, f_a: float, f_b: float, shape := "sine", attack := 0.005, curve := 2.0, vibrato := 0.0) -> void:
		var ph := 0.0
		var n := int(length * RATE)
		var s0 := int(start * RATE)
		for i in n:
			var t := float(i) / n
			var f := lerpf(f_a, f_b, t) * (1.0 + sin(t * length * 32.0) * vibrato)
			ph += f / RATE
			var x := fposmod(ph, 1.0)
			var w := 0.0
			match shape:
				"sine":
					w = sin(x * TAU)
				"square":
					w = 1.0 if x < 0.5 else -1.0
					w *= 0.5
				"tri":
					w = 4.0 * absf(x - 0.5) - 1.0
				"saw":
					w = (2.0 * x - 1.0) * 0.6
			var env := minf(1.0, i / maxf(attack * RATE, 1.0)) * pow(1.0 - t, curve)
			var j := s0 + i
			if j < data.size():
				data[j] += w * gain * env

	## peak: how loud the loudest moment is (0.9 = full). Sounds you hear all
	## the time (footsteps, digging) are made quieter on purpose.
	func to_wav(loop := false, peak_target := 0.9) -> AudioStreamWAV:
		var bytes := PackedByteArray()
		bytes.resize(data.size() * 2)
		var peak := 0.0
		for v in data:
			peak = maxf(peak, absf(v))
		var k := minf(1.0, peak_target / peak) if peak > 0.0 else 1.0  # never louder than peak_target (and never crackles)
		for i in data.size():
			bytes.encode_s16(i * 2, int(clampf(data[i] * k, -1.0, 1.0) * 32767.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.stereo = false
		w.data = bytes
		if loop:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = data.size()
		return w


func _add(sound: String, wav: AudioStreamWAV) -> void:
	if not _streams.has(sound):
		_streams[sound] = []
	_streams[sound].append(wav)


## Footstep / dig / break colors per material: [low cutoff, high cutoff, length, tone Hz (0 = none)]
## Kept low and round on purpose: these play hundreds of times, so they should
## sound like soft crunches, taps and knocks, never hiss or click.
const MATERIAL_SOUND := {
	"grass": [320.0, 1100.0, 0.13, 0.0],
	"sand": [500.0, 1400.0, 0.14, 0.0],
	"stone": [260.0, 850.0, 0.09, 150.0],
	"wood": [220.0, 700.0, 0.1, 118.0],
	"glass": [1300.0, 3000.0, 0.07, 1250.0],
	"metal": [600.0, 1600.0, 0.1, 420.0],
	"soft": [220.0, 600.0, 0.14, 0.0],
}


## The placing sound's color per material (kept as it was).
const PLACE_LOW := {"grass": 900.0, "sand": 1800.0, "stone": 600.0, "wood": 500.0, "glass": 3000.0, "metal": 1500.0, "soft": 500.0}


func _build_all() -> void:
	var seed_value := 1
	for m in MATERIAL_SOUND:
		var d: Array = MATERIAL_SOUND[m]
		for v in 3:
			seed_value += 1
			# Footstep: a soft crunch with a little low thump under it.
			var step := Synth.new(d[2] + 0.06, seed_value)
			step.noise(0.0, d[2], 0.4, d[1] * (1.0 + v * 0.05), d[0], 0.009, 2.2, true)
			step.tone(0.0, 0.06, 0.12, 95.0 + v * 6.0, 60.0, "sine", 0.004, 2.5)
			if d[3] > 0.0:
				step.tone(0.0, 0.05, 0.06, d[3] * (1.0 + v * 0.05), d[3] * 0.85, "sine", 0.004, 3.0)
			_add("step_" + m, step.to_wav(false, 0.42))
			# Digging: a rounder "chuff" (or a woody knock for wood).
			var dig := Synth.new(d[2] * 1.3 + 0.06, seed_value + 100)
			dig.noise(0.0, d[2] * 1.3, 0.5, d[1] * 1.05, d[0] * 0.8, 0.007, 2.0, true)
			dig.tone(0.0, 0.07, 0.16, 120.0 + v * 8.0, 70.0, "sine", 0.003, 2.5)
			if d[3] > 0.0:
				dig.tone(0.0, 0.08, 0.2, d[3] * (1.05 + v * 0.05), d[3] * 0.75, "sine", 0.003, 2.6)
			_add("dig_" + m, dig.to_wav(false, 0.5))
		# Breaking: a fuller, satisfying crumble that settles down.
		var brk := Synth.new(0.4, seed_value + 200)
		brk.noise(0.0, 0.32, 0.7, d[1] * 1.1, d[0] * 0.5, 0.006, 1.8, true)
		brk.noise(0.05, 0.16, 0.35, d[1] * 0.8, d[0] * 0.6, 0.008, 2.0, true)
		brk.tone(0.0, 0.14, 0.22, 110.0, 55.0, "sine", 0.003, 2.0)
		if d[3] > 0.0:
			brk.tone(0.0, 0.12, 0.2, d[3] * 1.1, d[3] * 0.6, "sine", 0.003, 2.0)
		if m == "glass":
			for k in 4:
				brk.tone(0.02 + k * 0.035, 0.16, 0.08, 1500.0 + k * 220.0, 1400.0 + k * 200.0, "sine", 0.004, 3.0)
		_add("break_" + m, brk.to_wav(false, 0.66))
		# Placing: unchanged (it already sounds nice).
		var place_low: float = PLACE_LOW[m]
		var place := Synth.new(0.14, seed_value + 300)
		place.noise(0.0, 0.1, 0.55, place_low * 1.5, place_low * 0.5, 0.001, 3.0)
		place.tone(0.0, 0.08, 0.35, 140.0, 90.0, "sine", 0.001, 3.0)
		_add("place_" + m, place.to_wav())

	# Swinging and hitting
	for v in 3:
		var sw := Synth.new(0.2, 50 + v)
		sw.noise(0.0, 0.2, 0.25, 300.0, 1100.0 + v * 150.0, 0.07, 1.6, true)
		_add("swing", sw.to_wav(false, 0.4))
	for v in 2:
		var hit := Synth.new(0.18, 60 + v)
		hit.noise(0.0, 0.1, 0.7, 2200.0, 400.0, 0.001, 2.5)
		hit.tone(0.0, 0.12, 0.6, 180.0 + v * 30.0, 70.0, "sine", 0.001, 2.0)
		_add("hit", hit.to_wav())
	var hurt := Synth.new(0.32, 70)
	hurt.tone(0.0, 0.28, 0.5, 300.0, 180.0, "saw", 0.01, 1.6, 0.03)
	hurt.noise(0.0, 0.12, 0.3, 1500.0, 500.0, 0.002, 2.0)
	_add("hurt", hurt.to_wav())
	var death := Synth.new(1.1, 71)
	death.tone(0.0, 1.0, 0.45, 330.0, 90.0, "tri", 0.01, 1.2, 0.02)
	death.tone(0.0, 1.0, 0.25, 247.0, 66.0, "sine", 0.01, 1.2)
	_add("death", death.to_wav())

	# Items and interface
	var pickup := Synth.new(0.14, 80)
	pickup.tone(0.0, 0.06, 0.35, 880.0, 1100.0, "sine", 0.002, 1.5)
	pickup.tone(0.05, 0.08, 0.3, 1320.0, 1500.0, "sine", 0.002, 2.0)
	_add("pickup", pickup.to_wav())
	var click := Synth.new(0.05, 81)
	click.tone(0.0, 0.035, 0.35, 1600.0, 1200.0, "sine", 0.0005, 3.0)
	click.noise(0.0, 0.02, 0.15, 6000.0, 3000.0, 0.0005, 3.0)
	_add("click", click.to_wav())
	var open := Synth.new(0.2, 82)
	open.tone(0.0, 0.12, 0.25, 520.0, 780.0, "tri", 0.002, 1.5)
	open.noise(0.0, 0.08, 0.2, 2000.0, 800.0, 0.001, 2.0)
	_add("open", open.to_wav())
	var close := Synth.new(0.18, 83)
	close.tone(0.0, 0.12, 0.25, 700.0, 450.0, "tri", 0.002, 1.5)
	_add("close", close.to_wav())
	var coin := Synth.new(0.4, 84)
	coin.tone(0.0, 0.08, 0.3, 1568.0, 1568.0, "square", 0.001, 1.2)
	coin.tone(0.07, 0.3, 0.3, 2093.0, 2093.0, "square", 0.001, 2.2)
	_add("coin", coin.to_wav())
	var craft := Synth.new(0.45, 85)
	craft.noise(0.0, 0.08, 0.35, 1800.0, 600.0, 0.001, 2.5)
	craft.tone(0.06, 0.3, 0.25, 659.0, 659.0, "tri", 0.002, 2.0)
	craft.tone(0.14, 0.3, 0.25, 988.0, 988.0, "tri", 0.002, 2.0)
	_add("craft", craft.to_wav())
	var unlock := Synth.new(0.8, 86)
	for k in 4:
		unlock.tone(k * 0.09, 0.5, 0.22, [523.0, 659.0, 784.0, 1047.0][k], [523.0, 659.0, 784.0, 1047.0][k], "tri", 0.002, 2.0)
	_add("unlock", unlock.to_wav())
	var legendary := Synth.new(2.0, 87)
	for k in 6:
		var f: float = [392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0][k]
		legendary.tone(k * 0.11, 1.4 - k * 0.1, 0.18, f, f, "saw", 0.005, 1.6, 0.004)
		legendary.tone(k * 0.11, 1.4 - k * 0.1, 0.12, f * 2.0, f * 2.0, "sine", 0.005, 2.0)
	_add("legendary", legendary.to_wav())
	var morning := Synth.new(1.2, 88)
	for k in 3:
		morning.tone(k * 0.18, 0.9, 0.22, [587.0, 740.0, 880.0][k], [587.0, 740.0, 880.0][k], "sine", 0.01, 1.8)
	_add("morning", morning.to_wav())
	for v in 3:
		var eat := Synth.new(0.12, 90 + v)
		eat.noise(0.0, 0.09, 0.5, 3500.0, 1200.0, 0.001, 2.5)
		_add("eat", eat.to_wav())
	var splash := Synth.new(0.6, 95)
	splash.noise(0.0, 0.5, 0.6, 400.0, 3500.0, 0.005, 1.4)
	splash.noise(0.05, 0.4, 0.3, 4000.0, 1500.0, 0.03, 2.0)
	_add("splash", splash.to_wav())
	var door_open := Synth.new(0.45, 96)
	door_open.tone(0.0, 0.35, 0.18, 260.0, 420.0, "saw", 0.04, 1.2, 0.05)
	door_open.noise(0.3, 0.12, 0.35, 1200.0, 300.0, 0.001, 2.5)
	_add("door_open", door_open.to_wav())
	var door_close := Synth.new(0.3, 97)
	door_close.noise(0.0, 0.18, 0.7, 1400.0, 250.0, 0.001, 2.2)
	door_close.tone(0.0, 0.15, 0.4, 120.0, 70.0, "sine", 0.001, 2.0)
	_add("door_close", door_close.to_wav())
	var bonk := Synth.new(0.25, 98)
	bonk.tone(0.0, 0.2, 0.45, 600.0, 220.0, "sine", 0.001, 2.0)
	_add("bonk", bonk.to_wav())

	# Mob voices
	for v in 2:
		var sq := Synth.new(0.16, 100 + v)
		sq.tone(0.0, 0.12, 0.3, 1700.0 + v * 200.0, 2300.0, "sine", 0.005, 1.5, 0.02)
		_add("squeak", sq.to_wav())
		var cl := Synth.new(0.3, 110 + v)
		for k in 3:
			cl.tone(k * 0.08, 0.06, 0.3, 700.0 + v * 60.0, 500.0, "square", 0.002, 2.0)
		_add("cluck", cl.to_wav())
		var bl := Synth.new(0.5, 120 + v)
		bl.tone(0.0, 0.45, 0.35, 420.0 + v * 30.0, 380.0, "saw", 0.03, 1.2, 0.06)
		_add("bleat", bl.to_wav())
		var oi := Synth.new(0.3, 130 + v)
		oi.tone(0.0, 0.25, 0.4, 160.0 + v * 20.0, 120.0, "saw", 0.01, 1.4, 0.08)
		oi.noise(0.0, 0.2, 0.25, 900.0, 300.0, 0.01, 1.5)
		_add("oink", oi.to_wav())
		var ba := Synth.new(0.6, 140 + v)
		ba.tone(0.0, 0.55, 0.35, 330.0 + v * 25.0, 300.0, "saw", 0.04, 1.0, 0.09)
		_add("baa", ba.to_wav())
		var gr := Synth.new(0.7, 150 + v)
		gr.tone(0.0, 0.6, 0.35, 110.0 + v * 15.0, 90.0, "saw", 0.06, 1.1, 0.12)
		gr.noise(0.0, 0.6, 0.35, 500.0, 300.0, 0.06, 1.1)
		_add("growl", gr.to_wav())
		var gl := Synth.new(0.9, 160 + v)
		gl.tone(0.0, 0.8, 0.4, 70.0 + v * 10.0, 55.0, "saw", 0.08, 1.0, 0.1)
		gl.noise(0.0, 0.8, 0.45, 350.0, 200.0, 0.08, 1.0)
		_add("growl_low", gl.to_wav())
		var hs := Synth.new(0.5, 170 + v)
		hs.noise(0.0, 0.45, 0.45, 5000.0, 6500.0, 0.05, 1.2)
		_add("hiss", hs.to_wav())
		var gi := Synth.new(0.6, 180 + v)
		for k in 4:
			gi.tone(k * 0.11, 0.1, 0.25, 1200.0 + k * 90.0 + v * 50.0, 1500.0 + k * 90.0, "sine", 0.005, 1.5, 0.03)
		_add("giggle", gi.to_wav())
	var roar := Synth.new(1.8, 190)
	roar.tone(0.0, 1.7, 0.45, 90.0, 60.0, "saw", 0.15, 0.9, 0.08)
	roar.tone(0.0, 1.7, 0.25, 135.0, 85.0, "saw", 0.15, 0.9, 0.1)
	roar.noise(0.0, 1.7, 0.55, 700.0, 250.0, 0.15, 0.9)
	_add("roar", roar.to_wav())

	# Ambience loops (fade in and out with the time of day and where you are).
	var wind := Synth.new(6.0, 200)
	for k in 6:
		wind.noise(k * 1.0, 2.0, 0.22, 250.0 + k * 40.0, 600.0 - k * 30.0, 0.8, 1.0)
	_add("wind", _make_loopable(wind).to_wav(true))
	var crickets := Synth.new(4.0, 210)
	var t := 0.0
	while t < 3.8:
		for k in 3:
			crickets.tone(t + k * 0.035, 0.025, 0.08, 4200.0, 4200.0, "sine", 0.003, 1.0)
		t += crickets.rng.randf_range(0.3, 0.7)
	_add("crickets", crickets.to_wav(true))
	var cave := Synth.new(6.0, 220)
	for k in 6:
		cave.noise(k * 1.0, 2.0, 0.3, 80.0, 120.0, 0.8, 1.0)
	for d in 3:
		cave.tone(0.8 + d * 1.9, 0.15, 0.12, 1800.0, 900.0, "sine", 0.001, 4.0)  # drips
	_add("cave", _make_loopable(cave).to_wav(true))
	# Rain: a soft steady hiss with patters of drops on top.
	var rain := Synth.new(6.0, 240)
	for k in 12:
		rain.noise(k * 0.5, 1.5, 0.16, 1800.0 + (k % 3) * 400.0, 2600.0, 0.6, 1.0)
		rain.noise(k * 0.5, 1.5, 0.1, 500.0, 700.0, 0.6, 1.0)
	for d in 60:
		var at := rain.rng.randf_range(0.0, 5.8)
		rain.tone(at, 0.03, 0.03, rain.rng.randf_range(1500.0, 3500.0), 800.0, "sine", 0.001, 4.0)
	_add("rain", _make_loopable(rain).to_wav(true, 0.7))
	# Thunder: a crack, then a long low rumble rolling away.
	for v in 2:
		var th := Synth.new(4.5, 250 + v)
		th.noise(0.0, 0.35, 0.5, 2500.0, 400.0, 0.004, 2.0)
		th.noise(0.05, 4.3, 0.85, 160.0 + v * 30.0, 50.0, 0.25, 1.4)
		th.noise(0.6, 2.5, 0.45, 260.0, 80.0, 0.4, 1.6)
		th.tone(0.05, 3.5, 0.25, 55.0, 38.0, "sine", 0.2, 1.5, 0.15)
		_add("thunder", th.to_wav())
	# QtMaMe's tune: a gentle music-box melody (an octave lower than before, so it
	# isn't shrill), repeating every 8 seconds, with soft bell overtones.
	var sparkle := Synth.new(8.0, 230)
	var melody := [[0.0, 784.0], [0.5, 659.0], [1.0, 784.0], [1.5, 880.0], [2.0, 784.0], [3.0, 659.0],
			[3.5, 587.0], [4.0, 523.0], [4.5, 587.0], [5.0, 659.0], [5.5, 784.0], [6.0, 659.0], [7.0, 523.0]]
	for note in melody:
		var f: float = note[1]
		sparkle.tone(note[0] + 0.05, 0.9, 0.09, f, f, "sine", 0.008, 2.4)
		sparkle.tone(note[0] + 0.05, 0.6, 0.025, f * 2.0, f * 2.0, "sine", 0.008, 3.0)
	for k in 4:
		sparkle.tone(k * 2.0 + 0.05, 1.9, 0.05, 262.0 if k % 2 == 0 else 196.0, 262.0 if k % 2 == 0 else 196.0, "sine", 0.05, 1.2)
	_add("sparkle", sparkle.to_wav(true, 0.6))


## Crossfades the end of a sound into its start so it loops without a click.
func _make_loopable(s: Synth) -> Synth:
	var n := s.data.size()
	var fade := int(0.5 * RATE)
	for i in fade:
		var k := float(i) / fade
		s.data[i] = s.data[i] * k + s.data[n - fade + i] * (1.0 - k)
	s.data.resize(n - fade)
	return s
