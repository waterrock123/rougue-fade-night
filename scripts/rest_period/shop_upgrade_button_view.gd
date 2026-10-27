class_name ShopUpgradeButtonView
extends PanelContainer

@onready var title_label: Label = $Margin/Content/Title
@onready var target_label: Label = $Margin/Content/Target
@onready var detail_label: Label = $Margin/Content/Detail
@onready var price_label: Label = $Margin/Content/Price
@onready var hint_label: Label = $Margin/Content/Hint
var frame_style: StyleBoxFlat


func _ready() -> void:
	frame_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", frame_style)
	_ignore_mouse(self)


func display(level: int, next_level: int, price: int, added_slots: int, pending: bool, affordable: bool) -> void:
	var maxed: bool = next_level < 0
	title_label.text = "商店已满级" if maxed else "升级商店"
	target_label.text = "Lv.%d" % level if maxed else "Lv.%d → Lv.%d" % [level, next_level]
	detail_label.text = "已达到最高等阶" if maxed else ("货架 +%d" % added_slots if added_slots > 0 else "提高商品等阶上限")
	price_label.text = "无需继续升级" if maxed else "花费 %d 金币" % price
	price_label.modulate = Color(1, 0.85, 0.45) if affordable or maxed else Color(1, 0.4, 0.35)
	hint_label.text = "" if maxed else ("4秒内再次点击确认" if pending else ("点击查看并确认" if affordable else "金币不足"))
	frame_style.border_color = Color(1, 0.8, 0.35) if pending else Color(0.6, 0.45, 0.3, 0.75)


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_ignore_mouse(child)
