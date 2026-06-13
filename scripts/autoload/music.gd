extends Node
## Procedural music: one seamless dark-synth loop (8 bars at 90 BPM, ~21 s)
## synthesized on a worker thread at startup, then looped forever on the
## Music bus. No audio assets. Note tails that spill past the loop end wrap
## back to the start, so the loop seam is inaudible.
##
## Arrangement: kick / snare / hats, a dotted saw-bass groove following an
## A-minor progression, a slow detuned power-chord pad, and a sparse sine
## lead (A-minor pentatonic, with echo) that sits over every chord.

const MIX_RATE := 22050
const BPM := 90.0
const BARS := 8
const STEPS := 16  # 16th notes per bar

# Low chord roots: Am Am F G / Am Am F E.
const PROG := [55.0, 55.0, 43.65, 49.0, 55.0, 55.0, 43.65, 41.2]
const FIFTH := 1.4983  # +7 semitones
const PENTA := [440.0, 523.25, 587.33, 659.26, 784.0, 880.0]  # A min pentatonic
# Sparse lead melody: [bar, step, PENTA index, length in steps]. Bars 0, 4
# and 7 stay empty so the loop breathes and the turnaround isn't cluttered.
const MELODY := [
	[1, 0, 3, 2], [1, 6, 2, 2], [1, 10, 1, 3],
	[2, 0, 0, 4],
	[3, 4, 3, 2], [3, 12, 2, 2],
	[5, 0, 1, 2], [5, 4, 2, 2], [5, 8, 3, 4],
	[6, 0, 5, 2], [6, 6, 4, 2], [6, 10, 3, 3],
]
const BASS_STEPS := [0, 3, 6, 8, 11, 14]  # dotted groove

var _player: AudioStreamPlayer
var _thread: Thread
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = -6.0
	add_child(_player)
	_rng.seed = 0xBADA55  # deterministic: same track every launch
	_thread = Thread.new()
	_thread.start(_render)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	if _player:
		_player.stop()
		_player.stream = null
		_player.free()
		_player = null


func _render() -> void:
	_publish.call_deferred(_compose())


func _publish(buf: PackedFloat32Array) -> void:
	if not is_instance_valid(_player):
		return
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = buf.size()
	_player.stream = s
	if DisplayServer.get_name() != "headless":
		_player.play()


# ---------------------------------------------------------------- compose

func _compose() -> PackedFloat32Array:
	var step := 60.0 / BPM / 4.0
	var bar := step * STEPS
	var buf := PackedFloat32Array()
	buf.resize(int(BARS * bar * MIX_RATE))

	for b in BARS:
		var t0 := b * bar
		var root: float = PROG[b]

		# Drums.
		_kick(buf, t0)
		_kick(buf, t0 + 8.0 * step)
		if b % 2 == 1:
			_kick(buf, t0 + 10.0 * step, 0.7)
		_snare(buf, t0 + 4.0 * step)
		_snare(buf, t0 + 12.0 * step)
		for h in [2, 6, 10, 14]:
			_hat(buf, t0 + h * step)

		# Bass: dotted groove an octave above the root.
		for s in BASS_STEPS:
			_tone(buf, t0 + s * step, step * 0.95, root * 2.0, 2, 0.26, 0.004, 1.2)

		# Pad: detuned saw power chord, slow swell across the bar.
		var pad_dur := bar * 1.25  # tail wraps into the next bar / loop start
		for f in [root * 4.0, root * 4.0 * FIFTH]:
			_tone(buf, t0, pad_dur, f * 0.996, 2, 0.040, 0.5, 0.7)
			_tone(buf, t0, pad_dur, f * 1.004, 2, 0.040, 0.5, 0.7)

	# Lead + echo.
	for m in MELODY:
		var at: float = m[0] * bar + m[1] * step
		var dur: float = m[3] * step * 1.3
		var f: float = PENTA[m[2]]
		_tone(buf, at, dur, f, 0, 0.10, 0.02, 1.0, 5.0)
		_tone(buf, at + 3.0 * step, dur, f, 0, 0.04, 0.02, 1.0, 5.0)

	_normalize(buf, 0.85)
	return buf


# ---------------------------------------------------------------- voices

## Adds one note. Indices wrap modulo the buffer so tails loop seamlessly.
## wave: 0 sine, 1 square, 2 saw. vibrato in Hz (0 = none).
func _tone(buf: PackedFloat32Array, at: float, dur: float, freq: float,
		wave: int, vol: float, attack: float, decay: float, vibrato := 0.0) -> void:
	var n := buf.size()
	var start := int(at * MIX_RATE)
	var len := int(dur * MIX_RATE)
	var attack_len := maxf(attack * MIX_RATE, 16.0)
	var phase := 0.0
	for i in len:
		var t := float(i) / len
		var f := freq
		if vibrato > 0.0:
			f *= 1.0 + 0.012 * sin(TAU * vibrato * i / MIX_RATE)
		phase += f / MIX_RATE
		var v: float
		match wave:
			0: v = sin(phase * TAU)
			1: v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			_: v = 2.0 * fmod(phase, 1.0) - 1.0
		var env := minf(i / attack_len, 1.0) * pow(1.0 - t, decay)
		buf[(start + i) % n] += v * vol * env


func _kick(buf: PackedFloat32Array, at: float, vol := 1.0) -> void:
	var n := buf.size()
	var start := int(at * MIX_RATE)
	var len := int(0.22 * MIX_RATE)
	var phase := 0.0
	for i in len:
		var t := float(i) / len
		phase += lerpf(110.0, 38.0, t) / MIX_RATE
		buf[(start + i) % n] += sin(phase * TAU) * 0.5 * vol * pow(1.0 - t, 1.6)


func _snare(buf: PackedFloat32Array, at: float) -> void:
	_noise(buf, at, 0.14, 0.18, 0.45, 1.8)
	_tone(buf, at, 0.08, 185.0, 0, 0.10, 0.002, 2.0)


func _hat(buf: PackedFloat32Array, at: float) -> void:
	_noise(buf, at, 0.03, 0.07, 0.9, 2.5)


func _noise(buf: PackedFloat32Array, at: float, dur: float, vol: float,
		lowpass: float, decay: float) -> void:
	var n := buf.size()
	var start := int(at * MIX_RATE)
	var len := int(dur * MIX_RATE)
	var y := 0.0
	for i in len:
		var t := float(i) / len
		y += lowpass * (_rng.randf_range(-1.0, 1.0) - y)
		buf[(start + i) % n] += y * vol * pow(1.0 - t, decay)


func _normalize(buf: PackedFloat32Array, target: float) -> void:
	var peak := 0.001
	for i in buf.size():
		peak = maxf(peak, absf(buf[i]))
	var g := target / peak
	for i in buf.size():
		buf[i] *= g
