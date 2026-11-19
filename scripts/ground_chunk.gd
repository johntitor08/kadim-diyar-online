extends Node2D
## Zeminin 512x512'lik bir parçası. Zemin parçalara bölünür ki kameranın görmediği
## parçalar hiç çizilmesin (tek parça zeminde tüm bölgenin karoları her karede çiziliyordu).

const SIZE := 512.0

var source: Object  # draw_ground_chunk(ci, area) fonksiyonu olan nesne
var area := Rect2()


func _draw() -> void:
	source.draw_ground_chunk(self, area)


## Verilen dikdörtgeni parçalara bölüp source'un altına (çizimin arkasına) ekler.
static func fill(parent: Node2D, source_obj: Object, rect: Rect2) -> void:
	var script: GDScript = load("res://scripts/ground_chunk.gd")
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var c: Node2D = script.new()
			c.source = source_obj
			c.area = Rect2(x, y, minf(SIZE, rect.end.x - x), minf(SIZE, rect.end.y - y))
			c.z_index = -1
			parent.add_child(c)
			x += SIZE
		y += SIZE
