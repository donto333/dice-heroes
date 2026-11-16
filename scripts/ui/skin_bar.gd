extends StyleBox
## 그림으로 그리는 긴 막대 상자(진행 막대의 채움, 알약 칸 등). 양 끝은 그대로, 가운데만 늘린다.

const Skin := preload("res://scripts/ui/skin.gd")

var art := ""
var tint := Color.WHITE
## 양 끝으로 남길 길이(그림 높이에 대한 비율)
var cap := 0.5
## 그림이 상자 밖으로 넘치는 양(px)
var grow := 0.0


func _draw(item: RID, rect: Rect2) -> void:
	var texture: Texture2D = Skin.tex(art)
	if texture == null or rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	Skin.draw_bar(item, texture, rect.grow(grow), cap, tint)
