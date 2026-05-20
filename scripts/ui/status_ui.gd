class_name StatusUI
extends HBoxContainer

var status_instance: StatusInstance

@onready var status_icon: TextureRect = $StatusIcon
@onready var stack_label: Label = $StatusIcon/StackLabel
@onready var duration_label: Label = $DurationLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if status_icon != null:
		status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stack_label != null:
		stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if duration_label != null:
		duration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_display()


func _process(_delta: float) -> void:
	# 持续时间由 StatusController 每帧递减，这里只负责读取并更新显示。
	_refresh_duration()


# 初始化状态图标。PlayScene 会在状态列表变化时重新创建这些 UI。
func setup(new_status_instance: StatusInstance) -> void:
	status_instance = new_status_instance
	_refresh_static_info()
	_refresh_display()


# 设置图标和鼠标提示文本，这些信息来自 StatusData。
func _refresh_static_info() -> void:
	if status_instance == null or status_instance.status_data == null:
		tooltip_text = ""
		return

	var status_data := status_instance.status_data
	if status_icon != null and status_data.icon != null:
		status_icon.texture = status_data.icon

	var desc := status_data.desc.strip_edges()
	if desc.is_empty():
		tooltip_text = status_data.status_name
	else:
		tooltip_text = "%s\n%s" % [status_data.status_name, desc]


# 层数和时间都属于运行时信息，可能随状态变化而变化。
func _refresh_display() -> void:
	_refresh_stack()
	_refresh_duration()


# 只有层数大于 1 时才显示层数，避免单层状态把图标挤得太吵。
func _refresh_stack() -> void:
	if stack_label == null:
		return

	if status_instance == null or status_instance.stacks <= 1:
		stack_label.hide()
		return

	stack_label.text = str(status_instance.stacks)
	stack_label.show()


# 永久状态不显示时间；限时状态显示向上取整的剩余秒数。
func _refresh_duration() -> void:
	if duration_label == null:
		return

	if status_instance == null or not status_instance.is_temporary():
		duration_label.hide()
		return

	duration_label.text = "%ss" % int(ceil(status_instance.remaining_duration))
	duration_label.show()
