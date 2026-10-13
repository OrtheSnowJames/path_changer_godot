extends Node2D

@onready var control = get_node("Node2D/Control")
@onready var control_1 = $"Node2D/Control"

func _ready() -> void:
	var _control_2 = get_node_or_null("Node2D/Control")
