extends RefCounted
## Eşyalar: silah ve zırh. Her eşya JSON'a yazılabilen bir sözlüktür:
##   {"id": int, "slot": "weapon"|"armor", "rarity": 0-2, "ilvl": int, "power": int, "name": String}
## Silahın gücü hasara, zırhın gücü azami cana eklenir.

const INV_MAX := 12
const RARITY_NAMES := ["Sıradan", "Nadir", "Efsanevi"]
const RARITY_COLORS := [Color(0.86, 0.87, 0.9), Color(0.42, 0.67, 1.0), Color(1.0, 0.64, 0.2)]
const NAMES := {
	"weapon": [["Demir Kılıç", "Kısa Kılıç", "Asker Kılıcı"],
		["Çelik Kılıç", "Avcı Kılıcı", "Muhafız Kılıcı"],
		["Ejder Dişi", "Kadim Kılıç", "Şafak Kılıcı"]],
	"armor": [["Deri Zırh", "Pullu Yelek", "Keçe Zırh"],
		["Zincir Zırh", "Muhafız Zırhı", "Gümüş Zırh"],
		["Ejder Pulu", "Kadim Zırh", "Altın Zırh"]],
}
const POWER_MULT := [1.0, 1.5, 2.2]
const SELL_MULT := [1.0, 2.5, 6.0]
## Canavar türü -> [düşme şansı (katılan her oyuncu için), en düşük, en yüksek eşya seviyesi]
const LOOT := {
	"slime": [0.06, 1, 3], "wolf": [0.10, 3, 6], "orc": [0.18, 6, 10], "boss": [1.0, 10, 15],
}


static func power_of(slot: String, rarity: int, ilvl: int) -> int:
	if slot == "weapon":
		return int(round((2.0 + ilvl * 1.3) * POWER_MULT[rarity]))
	return int(round((10.0 + ilvl * 6.0) * POWER_MULT[rarity]))


static func make(slot: String, rarity: int, ilvl: int) -> Dictionary:
	rarity = clampi(rarity, 0, 2)
	ilvl = clampi(ilvl, 1, 99)
	return {
		"id": 0, "slot": slot, "rarity": rarity, "ilvl": ilvl,
		"power": power_of(slot, rarity, ilvl), "name": NAMES[slot][rarity].pick_random(),
	}


static func random_item(rarity: int, ilvl: int) -> Dictionary:
	return make("weapon" if randf() < 0.5 else "armor", rarity, ilvl)


static func roll_rarity(boss: bool) -> int:
	var r := randf()
	if boss:
		return 2 if r < 0.35 else 1
	if r < 0.03:
		return 2
	return 1 if r < 0.22 else 0


static func sell_price(item: Dictionary) -> int:
	return int((5 + int(item.get("ilvl", 1)) * 4) * SELL_MULT[clampi(int(item.get("rarity", 0)), 0, 2)])


static func stat_text(item: Dictionary) -> String:
	if item.is_empty():
		return "-"
	return ("+%d hasar" if item.slot == "weapon" else "+%d can") % int(item.power)


static func display_name(item: Dictionary) -> String:
	if item.is_empty():
		return "Yok"
	return "%s (Sv %d)" % [item.name, int(item.ilvl)]


static func color_of(item: Dictionary) -> Color:
	return RARITY_COLORS[clampi(int(item.get("rarity", 0)), 0, 2)] if not item.is_empty() else Color(0.6, 0.6, 0.6)


## Kayıttan ya da ağdan gelen değeri doğrular; geçersizse {} döner. Güç yeniden hesaplanır.
static func sanitize(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	var slot = value.get("slot")
	if slot != "weapon" and slot != "armor":
		return {}
	var rarity = value.get("rarity", 0)
	var ilvl = value.get("ilvl", 1)
	if not (rarity is int or rarity is float) or not (ilvl is int or ilvl is float):
		return {}
	var item := make(slot, int(rarity), int(ilvl))
	var item_name = value.get("name", "")
	if item_name is String and item_name in NAMES[slot][item.rarity]:
		item.name = item_name
	return item
