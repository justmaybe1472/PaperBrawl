extends Node

const SAMPLE_RATE = 44100

var _sounds: Dictionary = {}
var _music_player: AudioStreamPlayer

func _ready():
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_generate_sounds()
	_connect_events()

func _generate_sounds():
	_sounds["hit"] = _generate_tone(440.0, 0.06, 0.3)
	_sounds["crit_hit"] = _generate_tone(660.0, 0.1, 0.4)
	_sounds["enemy_kill"] = _generate_tone(220.0, 0.12, 0.25)
	_sounds["pickup"] = _generate_tone(880.0, 0.04, 0.2)
	_sounds["wave_start"] = _generate_tone_burst([523.0, 659.0, 784.0], 0.15, 0.3)
	_sounds["player_hurt"] = _generate_tone(150.0, 0.15, 0.35)
	_sounds["shop_buy"] = _generate_tone(600.0, 0.08, 0.3)
	_sounds["game_over"] = _generate_tone_burst([400.0, 300.0, 200.0], 0.3, 0.4)
	_sounds["victory"] = _generate_tone_burst([523.0, 659.0, 784.0, 1047.0], 0.2, 0.4)

func _connect_events():
	EventBus.damage_dealt.connect(func(_s, _t, _a, is_crit): _play("crit_hit" if is_crit else "hit"))
	EventBus.enemy_killed.connect(func(_id, _pos, _elite): _play("enemy_kill"))
	EventBus.material_collected.connect(func(_a, _t): _play("pickup"))
	EventBus.wave_started.connect(func(_w): _play("wave_start"))
	EventBus.player_damaged.connect(func(_a, _hp): _play("player_hurt"))
	EventBus.item_purchased.connect(func(_id, _p): _play("shop_buy"))
	EventBus.weapon_purchased.connect(func(_id, _p): _play("shop_buy"))
	EventBus.game_over.connect(func(_wave, _mat):
		if GameManager.is_victory:
			_play("victory")
		else:
			_play("game_over")
	)

func _play(sound_name: String):
	if not _sounds.has(sound_name):
		return
	var player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.stream = _sounds[sound_name]
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func _generate_tone(frequency: float, duration: float, volume: float) -> AudioStream:
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = duration + 0.02

	var playback: AudioStreamGeneratorPlayback

	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

	var sample_count = int(SAMPLE_RATE * duration)
	for i in range(sample_count):
		var t = float(i) / SAMPLE_RATE
		var envelope = 1.0 - (t / duration)
		envelope = envelope * envelope
		var value = sin(T * TAU * frequency) * envelope * volume
		playback.push_frame(Vector2(value, value))

	player.stop()
	remove_child(player)
	player.queue_free()
	return stream

func _generate_tone_burst(frequencies: Array, note_duration: float, volume: float) -> AudioStream:
	var total_duration = note_duration * frequencies.size()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = total_duration + 0.02

	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	var playback = player.get_stream_playback()

	var samples_per_note = int(SAMPLE_RATE * note_duration)
	for i in range(samples_per_note * frequencies.size()):
		var t = float(i) / SAMPLE_RATE
		var note_idx = min(int(t / note_duration), frequencies.size() - 1)
		var note_t = t - note_idx * note_duration
		var envelope = 1.0 - (note_t / note_duration)
		envelope = envelope * envelope
		var value = sin(T * TAU * frequencies[note_idx]) * envelope * volume
		playback.push_frame(Vector2(value, value))

	player.stop()
	remove_child(player)
	player.queue_free()
	return stream

func start_music():
	if _music_player.playing:
		return
	var music_stream = _generate_music_loop()
	_music_player.stream = music_stream
	_music_player.play()

func stop_music():
	_music_player.stop()

func _generate_music_loop() -> AudioStream:
	var duration = 4.0
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = duration + 0.02

	var player = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
	var playback = player.get_stream_playback()

	var bass_notes = [110.0, 110.0, 130.8, 98.0]
	var total_samples = int(SAMPLE_RATE * duration)
	for i in range(total_samples):
		var t = float(i) / SAMPLE_RATE
		var beat = int(t / (duration / 4.0)) % 4
		var beat_t = fmod(t, duration / 4.0)
		var value = sin(T * TAU * bass_notes[beat] * 2.0) * 0.08
		value += sin(T * TAU * bass_notes[beat]) * 0.06 * (1.0 - beat_t / (duration / 4.0))
		playback.push_frame(Vector2(value, value))

	player.stop()
	remove_child(player)
	player.queue_free()
	return stream
