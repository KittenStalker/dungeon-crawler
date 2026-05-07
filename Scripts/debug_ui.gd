extends Control

@onready var seed_number: Label = $Seed_number
@onready var regen_button: Button = $Regen_button

func _input(event):
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ready() -> void:
	pass

func update_seed(seed_num: String):
	seed_number.text = "Seed: {seed}".format({"seed": seed_num})
	print("\ndebug seed: ", seed_num)

func update_all(seed_num: String = ""):
	update_seed(seed_num)
