extends Node
## Procedural sound effects. Every SFX is synthesized at startup (no audio
## assets to import) and played through a pool of AudioStreamPlayers routed
## to the SFX bus. play() adds slight pitch jitter and throttles per-sound
## so dense horde moments don't turn into white noise.
##
## Also auto-wires UI sounds: any Button added to the tree gets click and
## focus blips.

const MIX_RATE := 22050
const POOL_SIZE := 16

## Minimum ms between repeats of the same sound (default 35).
const MIN_GAP_MS := {
	"enemy_hit": 60,
	"enemy_die": 50,
	"xp": 50,
	"explosion": 90,
	"ui_move": 45,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}  # name -> last played msec
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 0x5F0CC5  # deterministic noise: same sounds every launch
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # UI sounds while paused
		add_child(p)
		_players.append(p)
	_generate_all()
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.free()
	_players.clear()
	_streams.clear()
	_last.clear()


func play(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sfx_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(sfx_name, -10000)) < int(MIN_GAP_MS.get(sfx_name, 35)):
		return
	_last[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.play()


func _on_node_added(n: Node) -> void:
	if n is Button:  # also OptionButton / CheckButton
		n.pressed.connect(play.bind("ui_select", -4.0, 1.0))
		n.focus_entered.connect(play.bind("ui_move", -6.0, 1.0))
		n.mouse_entered.connect(play.bind("ui_move", -6.0, 1.0))


# ---------------------------------------------------------------- recipes

func _generate_all() -> void:
	var b: PackedFloat32Array

	# Rivet Gun: snappy metallic pop.
	b = _buf(0.09)
	_sweep(b, 1500, 480, 1, 0.26, 2.0)
	_noise(b, 0.14, 0.8, 6.0)
	_streams["rivet"] = _wav(b)

	# Railspike Driver: heavier punch.
	b = _buf(0.18)
	_sweep(b, 760, 130, 2, 0.30, 1.6)
	_noise(b, 0.16, 0.5, 4.0)
	_streams["spike"] = _wav(b)

	# Plasma Mortar launch: deep whoomp.
	b = _buf(0.32)
	_sweep(b, 170, 50, 0, 0.55, 1.2)
	_noise(b, 0.22, 0.12, 2.0)
	_streams["mortar"] = _wav(b)

	# Shell / mortar blast: rumbling boom.
	b = _buf(0.6)
	_noise(b, 0.95, 0.16, 2.2)
	_sweep(b, 110, 35, 0, 0.5, 1.5)
	_streams["explosion"] = _wav(b)

	# Tesla Arc: bright crackling zap.
	b = _buf(0.15)
	_noise(b, 0.42, 0.85, 1.2)
	_sweep(b, 2400, 280, 2, 0.18, 1.0)
	_crackle(b, 0.35)
	_streams["tesla"] = _wav(b)

	# Nano Swarm launch: soft rising chirp.
	b = _buf(0.16)
	_sweep(b, 350, 1000, 3, 0.18, 0.7)
	_streams["swarm"] = _wav(b)

	# Spitter glob: wet descending blip.
	b = _buf(0.14)
	_sweep(b, 560, 170, 0, 0.30, 1.2)
	_noise(b, 0.10, 0.6, 2.0)
	_streams["spit"] = _wav(b)

	# Enemy hit: short dull thud.
	b = _buf(0.07)
	_noise(b, 0.5, 0.3, 1.5)
	_sweep(b, 220, 90, 0, 0.30, 1.5)
	_streams["enemy_hit"] = _wav(b)

	# Enemy death: squelchy pop.
	b = _buf(0.22)
	_sweep(b, 300, 70, 0, 0.40, 1.3)
	_noise(b, 0.35, 0.4, 1.8)
	_streams["enemy_die"] = _wav(b)

	# Player hurt: harsh alarm buzz.
	b = _buf(0.22)
	_sweep(b, 260, 110, 1, 0.28, 1.4)
	_noise(b, 0.15, 0.6, 2.0)
	_streams["player_hurt"] = _wav(b)

	# Player destroyed: long power-down dive.
	b = _buf(0.9)
	_sweep(b, 480, 40, 2, 0.30, 1.0)
	_noise(b, 0.30, 0.2, 1.6)
	_streams["player_die"] = _wav(b)

	_streams["level_up"] = _wav(_tone_seq([392.0, 523.3, 659.3, 784.0], 0.085, 1, 0.20))
	_streams["crate"] = _wav(_tone_seq([523.3, 659.3, 784.0, 1046.5], 0.08, 1, 0.20))
	_streams["evolve"] = _wav(_tone_seq([392.0, 493.9, 587.3, 740.0, 987.8], 0.1, 1, 0.22))
	_streams["pickup"] = _wav(_tone_seq([660.0, 990.0], 0.06, 1, 0.18))
	_streams["ui_select"] = _wav(_tone_seq([620.0, 930.0], 0.045, 1, 0.15))

	# XP gem: tiny glass blip.
	b = _buf(0.055)
	_sweep(b, 1150, 1500, 0, 0.15, 1.0)
	_streams["xp"] = _wav(b)

	# Medkit: soft rising hum.
	b = _buf(0.3)
	_sweep(b, 440, 880, 0, 0.20, 0.8)
	_streams["heal"] = _wav(b)

	# Deflector recharge: bright rising shimmer.
	b = _buf(0.25)
	_sweep(b, 600, 1400, 3, 0.18, 0.9)
	_streams["shield_up"] = _wav(b)

	# Deflector break: metallic clang with a fizzle tail.
	b = _buf(0.28)
	_sweep(b, 950, 220, 1, 0.22, 1.8)
	_noise(b, 0.28, 0.7, 2.5)
	_streams["shield_break"] = _wav(b)

	# Magnet: long vacuum sweep.
	b = _buf(0.35)
	_sweep(b, 250, 1300, 0, 0.18, 0.6)
	_streams["magnet"] = _wav(b)

	# UI focus tick.
	b = _buf(0.04)
	_sweep(b, 750, 750, 0, 0.12, 1.0)
	_streams["ui_move"] = _wav(b)


# ---------------------------------------------------------------- synthesis

func _buf(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * MIX_RATE))
	return b


## Adds a frequency-swept oscillator with a 1.5 ms anti-click attack and a
## (1-t)^decay release into buf.
func _sweep(buf: PackedFloat32Array, f0: float, f1: float, wave: int,
		vol: float, decay: float) -> void:
	var n := buf.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		phase += lerpf(f0, f1, t) / MIX_RATE
		var env := pow(1.0 - t, decay) * minf(float(i) / 32.0, 1.0)
		buf[i] += _osc(wave, phase) * vol * env


## Adds one-pole low-passed white noise. lowpass 1.0 = unfiltered hiss,
## small values = dull rumble.
func _noise(buf: PackedFloat32Array, vol: float, lowpass: float, decay: float) -> void:
	var n := buf.size()
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += lowpass * (_rng.randf_range(-1.0, 1.0) - y)
		buf[i] += y * vol * pow(1.0 - t, decay)


## Randomly mutes ~2 ms spans so sustained noise reads as electric crackle.
func _crackle(buf: PackedFloat32Array, mute_chance: float) -> void:
	var span := int(0.002 * MIX_RATE)
	var i := 0
	while i < buf.size():
		if _rng.randf() < mute_chance:
			for k in mini(span, buf.size() - i):
				buf[i + k] = 0.0
		i += span


## Short square-ish arpeggio; notes ring slightly into each other.
func _tone_seq(notes: Array, note_dur: float, wave: int, vol: float) -> PackedFloat32Array:
	var buf := _buf(note_dur * notes.size() + 0.12)
	var phase := 0.0
	for k in notes.size():
		var start := int(k * note_dur * MIX_RATE)
		var len := int(note_dur * MIX_RATE * 1.5)
		for i in len:
			var idx := start + i
			if idx >= buf.size():
				break
			var t := float(i) / len
			phase += float(notes[k]) / MIX_RATE
			var env := pow(1.0 - t, 1.8) * minf(float(i) / 32.0, 1.0)
			buf[idx] += _osc(wave, phase) * vol * env
	return buf


func _osc(wave: int, phase: float) -> float:
	var p := fmod(phase, 1.0)
	match wave:
		0: return sin(p * TAU)                  # sine
		1: return 1.0 if p < 0.5 else -1.0      # square
		2: return 2.0 * p - 1.0                 # saw
		3: return 4.0 * absf(p - 0.5) - 1.0     # triangle
	return 0.0


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.data = data
	return s
