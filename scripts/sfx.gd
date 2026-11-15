extends Node
## Ses efektleri: hepsi açılışta kodla sentezlenir, harici ses dosyası yok.
## M tuşu sesi açıp kapatır.

const RATE := 22050
const HEAR_RANGE := 750.0

var muted := false
var _active := false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process_unhandled_key_input(false)
		return
	_active = true
	_build()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		muted = not muted
		Network.chat_received.emit("", "Ses kapatıldı (M)." if muted else "Ses açıldı (M).", true)


## pos verilirse ses yerel oyuncuya uzaklığa göre kısılır; uzaksa hiç çalmaz.
func play(sound: String, pos = null, volume_db := 0.0) -> void:
	if not _active or muted or Network.is_dedicated or not _streams.has(sound):
		return
	var db := volume_db
	if pos != null:
		var lp = get_tree().get_first_node_in_group("local_player")
		if lp == null:
			return
		var d: float = lp.global_position.distance_to(pos)
		if d > HEAR_RANGE:
			return
		db -= 18.0 * d / HEAR_RANGE
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = db - 8.0
	p.pitch_scale = randf_range(0.94, 1.06)
	p.play()


# --- Sentez ---

func _make(duration: float, f: Callable) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(f.call(t, t / duration), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _noise() -> float:
	return randf() * 2.0 - 1.0


## f0'dan f1'e doğrusal kayan sinüsün t anındaki değeri (d: toplam süre).
func _sweep(t: float, d: float, f0: float, f1: float) -> float:
	return sin(TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * d)))


func _build() -> void:
	# Kılıç savurma: kısa hışırtı
	_streams["swing"] = _make(0.13, func(t: float, u: float) -> float:
		return _noise() * 0.16 * sin(u * PI) + _sweep(t, 0.13, 520.0, 200.0) * 0.1 * (1.0 - u))
	# Canavara isabet: tok vuruş
	_streams["hit"] = _make(0.1, func(t: float, u: float) -> float:
		return _sweep(t, 0.1, 220.0, 80.0) * 0.6 * pow(1.0 - u, 2.0) + _noise() * 0.3 * pow(1.0 - u, 4.0))
	# Oyuncu hasar aldı
	_streams["hurt"] = _make(0.16, func(t: float, u: float) -> float:
		return signf(_sweep(t, 0.16, 320.0, 140.0)) * 0.22 * (1.0 - u))
	# Canavar öldü
	_streams["kill"] = _make(0.26, func(t: float, u: float) -> float:
		return _noise() * 0.28 * pow(1.0 - u, 2.0) + _sweep(t, 0.26, 420.0, 80.0) * 0.4 * (1.0 - u))
	# Seviye atlama: yükselen dört nota
	var notes := [523.25, 659.25, 783.99, 1046.5]
	_streams["levelup"] = _make(0.62, func(t: float, _u: float) -> float:
		var i := mini(int(t / 0.11), 3)
		var local := t - i * 0.11
		var env := exp(-local * (4.0 if i == 3 else 9.0))
		return (sin(TAU * notes[i] * t) * 0.34 + sin(TAU * notes[i] * 2.0 * t) * 0.1) * env)
	# Altın
	_streams["coin"] = _make(0.17, func(t: float, u: float) -> float:
		return sin(TAU * (988.0 if t < 0.06 else 1319.0) * t) * 0.28 * (1.0 - u))
	# İksir
	_streams["potion"] = _make(0.32, func(t: float, u: float) -> float:
		return _sweep(t, 0.32, 300.0, 900.0) * 0.3 * sin(u * PI) * (0.6 + 0.4 * sin(TAU * 18.0 * t)))
	# Boss kükremesi
	_streams["boss"] = _make(0.9, func(t: float, u: float) -> float:
		return (sin(TAU * 65.0 * t) * 0.5 + sin(TAU * 98.0 * t) * 0.25 + _noise() * 0.1) \
			* sin(u * PI) * (0.7 + 0.3 * sin(TAU * 9.0 * t)))
