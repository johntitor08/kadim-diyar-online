extends HBoxContainer
## Menüdeki karakter oluşturma: canlı önizleme + ten, saç, saç rengi ve kıyafet seçimi.
## Seçim Network.local_look içinde tutulur ve kimlik dosyasına yazılır.

const Look := preload("res://scripts/look.gd")

var _values := {}  # alan -> Label


class Preview extends Control:
	const LookLib := preload("res://scripts/look.gd")
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(118, 150)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.2, 0.36, 0.18, 0.9)
		bg.set_corner_radius_all(8)
		bg.border_color = Color(0.62, 0.48, 0.25, 0.9)
		bg.set_border_width_all(2)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		var facing := Vector2(sin(_t * 0.8) * 0.9, 1.0).normalized()
		LookLib.draw(self, Network.local_look, {
			"facing": facing, "walk": _t * 8.0, "moving": true,
			"show_sword": false, "weapon": -1, "armor": -1,
			"origin": Vector2(size.x * 0.5, size.y - 14.0), "scale": 2.2,
		})


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	add_child(Preview.new())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(right)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	right.add_child(grid)
	for field in Look.FIELDS:
		var title := Label.new()
		title.text = Look.FIELDS[field][0]
		title.custom_minimum_size = Vector2(70, 0)
		title.add_theme_font_size_override("font_size", 13)
		grid.add_child(title)
		grid.add_child(_arrow("<", field, -1))
		var value := Label.new()
		value.custom_minimum_size = Vector2(96, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
		grid.add_child(value)
		_values[field] = value
		grid.add_child(_arrow(">", field, 1))
	var random := Button.new()
	random.text = "Rastgele"
	random.focus_mode = Control.FOCUS_NONE
	random.pressed.connect(func() -> void:
		Network.local_look = Look.random_look()
		_changed())
	right.add_child(random)
	_refresh()


func _arrow(text: String, field: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(30, 0)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		var look := Look.sanitize(Network.local_look)
		look[field] = posmod(int(look[field]) + step, Look.FIELDS[field][1].size())
		Network.local_look = look
		_changed())
	return b


func _changed() -> void:
	Network.save_identity()
	_refresh()


func _refresh() -> void:
	var look := Look.sanitize(Network.local_look)
	for field in _values:
		_values[field].text = Look.FIELDS[field][1][look[field]]
