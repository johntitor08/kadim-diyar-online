extends PanelContainer
## Tüccar penceresi (B): iksir ve bu dönemin vitrini (seviyene göre silah/zırh). Vitrin 10 dakikada bir
## yenilenir. Satış çanta penceresinden yapılır; market açılınca çanta da açılır.

const Items := preload("res://scripts/items.gd")

var player = null
var _gold: Label
var _list: VBoxContainer
var _footer: Label
var _dirty := true
var _last_second := -1


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.05, 0.94)
	style.border_color = Color(0.85, 0.65, 0.3, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(400, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	var title := Label.new()
	title.text = "Tüccar"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	top.add_child(title)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	top.add_child(_gold)
	var close := Button.new()
	close.text = " X "
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	vb.add_child(_list)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	vb.add_child(_footer)


func set_player(p) -> void:
	if p == player:
		return
	if player != null and is_instance_valid(player):
		for sig in [player.market_changed, player.inventory_changed]:
			if sig.is_connected(_mark_dirty):
				sig.disconnect(_mark_dirty)
	player = p
	if p != null:
		p.market_changed.connect(_mark_dirty)
		p.inventory_changed.connect(_mark_dirty)
	_dirty = true


func open() -> void:
	visible = true
	_dirty = true
	if player != null:
		player.open_market()


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not visible or player == null or not is_instance_valid(player):
		return
	if not player.near_merchant() or player.dead:
		visible = false
		return
	_gold.text = "Altın %d   " % player.gold
	var left := _seconds_left()
	if left != _last_second:
		_last_second = left
		_footer.text = "Vitrin %d:%02d sonra yenilenir. Eşya satmak için çantadaki \"Sat\" düğmesi." % [left / 60, left % 60]
		if left <= 0 and not player.client_market.is_empty():
			player.open_market()
	if _dirty:
		_dirty = false
		_rebuild()


func _seconds_left() -> int:
	var m: Dictionary = player.client_market
	if m.is_empty():
		return 0
	var passed := (Time.get_ticks_msec() - int(m.received)) / 1000
	return maxi(int(m.left) - passed, 0)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	# İksir satırı
	_list.add_child(_row("Can İksiri", "Azami canın %%%d'ı" % int(player.POTION_HEAL * 100), Color(0.95, 0.4, 0.45),
		player.POTION_COST, player.potions < player.POTION_MAX and player.gold >= player.POTION_COST,
		"%d/%d" % [player.potions, player.POTION_MAX], func() -> void: player.try_buy_potion()))
	_list.add_child(HSeparator.new())
	var m: Dictionary = player.client_market
	if m.is_empty():
		var wait := Label.new()
		wait.text = "Vitrin yükleniyor..."
		_list.add_child(wait)
		return
	var bag_full: bool = player.client_inv.size() >= Items.INV_MAX
	for i in m.offers.size():
		var item: Dictionary = m.offers[i]
		var sold: bool = i in m.bought
		var current: Dictionary = player.client_weapon if item.slot == "weapon" else player.client_armor
		var diff := int(item.power) - int(current.get("power", 0))
		var stat := "%s  (%s)" % [Items.stat_text(item), ("%+d" % diff) if diff != 0 else "aynı"]
		var can: bool = not sold and not bag_full and player.gold >= int(item.price)
		var index: int = i
		_list.add_child(_row(Items.display_name(item), stat, Items.color_of(item), int(item.price), can,
			"Satıldı" if sold else ("Çanta dolu" if bag_full else ""), func() -> void: player.try_market_buy(index)))


func _row(title: String, sub: String, col: Color, price: int, enabled: bool, note: String, action: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = title
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", col)
	info.add_child(name_label)
	var sub_label := Label.new()
	sub_label.text = sub + ("   " + note if note != "" else "")
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	info.add_child(sub_label)
	var buy := Button.new()
	buy.text = "Al  %d" % price
	buy.custom_minimum_size = Vector2(88, 0)
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = not enabled
	buy.pressed.connect(action)
	row.add_child(buy)
	return row
