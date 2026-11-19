extends PanelContainer
## Çanta penceresi (I): kuşanılan eşyalar, çantadaki eşyalar, kuşan ve sat düğmeleri.
## Veriyi yerel oyuncunun client_inv kopyasından okur; işlemler sunucuya istek olarak gider.

const Items := preload("res://scripts/items.gd")

var player = null
var _title: Label
var _equipped: VBoxContainer
var _list: VBoxContainer
var _footer: Label
var _near_merchant := false
var _dirty := true


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	style.border_color = Color(0.62, 0.48, 0.25, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(390, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)
	var top := HBoxContainer.new()
	vb.add_child(top)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(1, 0.88, 0.6))
	top.add_child(_title)
	var close := Button.new()
	close.text = " X "
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: visible = false)
	top.add_child(close)
	var caption := Label.new()
	caption.text = "Kuşanılan"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	vb.add_child(caption)
	_equipped = VBoxContainer.new()
	vb.add_child(_equipped)
	vb.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_footer = Label.new()
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_footer)


func set_player(p) -> void:
	if p == player:
		return
	if player != null and is_instance_valid(player) and player.inventory_changed.is_connected(_mark_dirty):
		player.inventory_changed.disconnect(_mark_dirty)
	player = p
	if p != null:
		p.inventory_changed.connect(_mark_dirty)
	_dirty = true


func toggle() -> void:
	visible = not visible
	_dirty = true


func _mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if not visible or player == null or not is_instance_valid(player):
		return
	var near: bool = player.near_merchant()
	if near != _near_merchant:
		_near_merchant = near
		_dirty = true
	if _dirty:
		_dirty = false
		_rebuild()


func _rebuild() -> void:
	_title.text = "Çanta (%d/%d)" % [player.client_inv.size(), Items.INV_MAX]
	for c in _equipped.get_children():
		c.queue_free()
	for c in _list.get_children():
		c.queue_free()
	_equipped.add_child(_equipped_row("Silah", player.client_weapon))
	_equipped.add_child(_equipped_row("Zırh", player.client_armor))
	var items: Array = player.client_inv.duplicate()
	items.sort_custom(func(a, b) -> bool:
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		return int(a.power) > int(b.power))
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Çanta boş. Canavarlar ve Kâhin'in görevleri eşya verir."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.68))
		_list.add_child(empty)
	for item in items:
		_list.add_child(_item_row(item))
	_footer.text = "Tüccarın yanındasın: eşya satabilirsin." if _near_merchant \
		else "Satmak için kamptaki tüccara git. Çanta dolarken düşen eşya kendiliğinden satılır."


func _equipped_row(slot_name: String, item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	var slot := Label.new()
	slot.text = slot_name
	slot.custom_minimum_size = Vector2(52, 0)
	slot.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	row.add_child(slot)
	var name_label := Label.new()
	name_label.text = Items.display_name(item)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", Items.color_of(item))
	name_label.clip_text = true
	row.add_child(name_label)
	var stat := Label.new()
	stat.text = Items.stat_text(item)
	row.add_child(stat)
	return row


func _item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = Items.display_name(item)
	name_label.clip_text = true
	name_label.add_theme_color_override("font_color", Items.color_of(item))
	info.add_child(name_label)
	var stats := HBoxContainer.new()
	info.add_child(stats)
	var stat := Label.new()
	stat.text = Items.stat_text(item)
	stat.add_theme_font_size_override("font_size", 12)
	stats.add_child(stat)
	var current: Dictionary = player.client_weapon if item.slot == "weapon" else player.client_armor
	var diff := int(item.power) - int(current.get("power", 0))
	var diff_label := Label.new()
	diff_label.text = "(%+d)" % diff if diff != 0 else "(aynı)"
	diff_label.add_theme_font_size_override("font_size", 12)
	diff_label.add_theme_color_override("font_color",
		Color(0.45, 0.95, 0.5) if diff > 0 else (Color(1.0, 0.45, 0.4) if diff < 0 else Color(0.7, 0.7, 0.7)))
	stats.add_child(diff_label)

	var equip := Button.new()
	equip.text = "Kuşan"
	equip.focus_mode = Control.FOCUS_NONE
	var id := int(item.id)
	equip.pressed.connect(func() -> void: player.try_equip(id))
	row.add_child(equip)
	var sell := Button.new()
	sell.text = "Sat %d" % Items.sell_price(item)
	sell.focus_mode = Control.FOCUS_NONE
	sell.disabled = not _near_merchant
	sell.tooltip_text = "" if _near_merchant else "Tüccarın yanında satılır"
	sell.pressed.connect(func() -> void: player.try_sell(id))
	row.add_child(sell)
	return row
