extends Node

# Procedural Sound Synthesizer & Audio Manager
# Creates arcade audio effects entirely with AudioStreamWAV buffers, ensuring
# zero dependencies on external audio files and 100% crash-proof audio playback.

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var current_note_idx: int = 0
var music_timer: float = 0.0

# Sound buffers
var snd_move: AudioStreamWAV
var snd_drop: AudioStreamWAV
var snd_grab: AudioStreamWAV
var snd_success: AudioStreamWAV
var snd_fail: AudioStreamWAV
var snd_click: AudioStreamWAV
var snd_warning: AudioStreamWAV
var snd_gameover: AudioStreamWAV

# Background melody notes (Hz)
const MELODY = [
	523.25, 587.33, 659.25, 783.99,
	659.25, 783.99, 880.00, 1046.50,
	783.99, 659.25, 587.33, 523.25,
	440.00, 523.25, 659.25, 587.33
]

func _ready():
	_create_synthesized_sounds()
	_setup_players()

func _create_synthesized_sounds():
	snd_click = _generate_tone(880.0, 0.05, "sine", 0.3, true)
	snd_move = _generate_tone(180.0, 0.08, "triangle", 0.15, true)
	snd_drop = _generate_sweep(400.0, 150.0, 0.35, "sawtooth", 0.4)
	snd_grab = _generate_sweep(200.0, 600.0, 0.25, "sine", 0.45)
	snd_success = _generate_fanfare()
	snd_fail = _generate_sweep(350.0, 120.0, 0.4, "square", 0.3)
	snd_warning = _generate_tone(900.0, 0.1, "square", 0.35, true)
	snd_gameover = _generate_sweep(500.0, 150.0, 0.8, "sawtooth", 0.5)

func _setup_players():
	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)

func play_sound(s_name: String):
	var s_mgr = get_node_or_null("/root/SettingsManager")
	if s_mgr and s_mgr.mute_audio:
		return
	var stream: AudioStreamWAV = null
	match s_name:
		"click": stream = snd_click
		"move": stream = snd_move
		"drop": stream = snd_drop
		"grab": stream = snd_grab
		"success": stream = snd_success
		"fail": stream = snd_fail
		"warning": stream = snd_warning
		"gameover": stream = snd_gameover
	
	if stream:
		for p in sfx_players:
			if not p.playing:
				p.stream = stream
				var sfx_v = s_mgr.sfx_volume if s_mgr else 0.9
				p.volume_db = linear_to_db(sfx_v)
				p.play()
				return

func _process(delta):
	var s_mgr = get_node_or_null("/root/SettingsManager")
	if s_mgr and (s_mgr.mute_audio or s_mgr.music_volume <= 0.0):
		return
		
	# Simple cheerful arcade chiptune sequencer for background ambience
	music_timer += delta
	if music_timer >= 0.22:
		music_timer = 0.0
		var note_freq = MELODY[current_note_idx]
		current_note_idx = (current_note_idx + 1) % MELODY.size()
		var mus_v = s_mgr.music_volume if s_mgr else 0.7
		var tone = _generate_tone(note_freq, 0.18, "sine", 0.12 * mus_v, true)
		music_player.stream = tone
		music_player.volume_db = linear_to_db(mus_v * 0.4)
		music_player.play()

# Generator helpers
func _generate_tone(freq: float, duration: float, waveform: String, volume: float, fade_out: bool) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var sample_val = 0.0
		var phase = fposmod(t * freq, 1.0)
		
		if waveform == "sine":
			sample_val = sin(TAU * t * freq)
		elif waveform == "square":
			sample_val = 1.0 if phase < 0.5 else -1.0
		elif waveform == "sawtooth":
			sample_val = (phase * 2.0) - 1.0
		elif waveform == "triangle":
			sample_val = (4.0 * abs(phase - 0.5)) - 1.0
			
		var env = 1.0
		if fade_out:
			env = clamp(1.0 - (float(i) / num_samples), 0.0, 1.0)
		
		var s8 = int(clamp(sample_val * volume * env * 127.0, -128.0, 127.0))
		data[i] = (s8 + 256) % 256
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _generate_sweep(start_freq: float, end_freq: float, duration: float, waveform: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var num_samples = int(duration * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	var cur_phase = 0.0
	
	for i in range(num_samples):
		var progress = float(i) / num_samples
		var freq = lerp(start_freq, end_freq, progress)
		cur_phase += (freq / sample_rate)
		var phase = fposmod(cur_phase, 1.0)
		
		var sample_val = 0.0
		if waveform == "sine":
			sample_val = sin(TAU * cur_phase)
		elif waveform == "square":
			sample_val = 1.0 if phase < 0.5 else -1.0
		elif waveform == "sawtooth":
			sample_val = (phase * 2.0) - 1.0
			
		var env = 1.0 - progress
		var s8 = int(clamp(sample_val * volume * env * 127.0, -128.0, 127.0))
		data[i] = (s8 + 256) % 256
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _generate_fanfare() -> AudioStreamWAV:
	var sample_rate = 22050
	var notes = [523.25, 659.25, 783.99, 1046.50]
	var note_dur = 0.12
	var total_dur = note_dur * notes.size()
	var num_samples = int(total_dur * sample_rate)
	var data = PackedByteArray()
	data.resize(num_samples)
	
	for idx in range(notes.size()):
		var freq = notes[idx]
		var start_i = int(idx * note_dur * sample_rate)
		var end_i = int((idx + 1) * note_dur * sample_rate)
		for i in range(start_i, end_i):
			var t = float(i - start_i) / sample_rate
			var phase = fposmod(t * freq, 1.0)
			var s_val = sin(TAU * t * freq)
			var env = clamp(1.0 - (float(i - start_i) / (note_dur * sample_rate)), 0.2, 1.0)
			var s8 = int(clamp(s_val * 0.45 * env * 127.0, -128.0, 127.0))
			data[i] = (s8 + 256) % 256
			
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
