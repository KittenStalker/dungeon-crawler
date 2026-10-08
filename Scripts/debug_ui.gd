extends Control

@onready var seed_number: Label = $Seed_number

func _process(_delta):
	$Fps_label.text = str(Engine.get_frames_per_second())

func update_seed(seed_num: String):
	seed_number.text = "Seed: {seed}".format({"seed": seed_num})
	print("\ndebug seed: ", seed_num)

func update_all(seed_num: String = ""):
	update_seed(seed_num)
