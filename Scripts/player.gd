extends CharacterBody3D

@onready var head: Node3D = $head

var current_speed = 5.0
var direction = Vector3.ZERO

const lerp_speed = 10.0
const speed_cap = 5.0
const mouse_sensivity = 0.1

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-deg_to_rad(event.relative.x * mouse_sensivity))
		head.rotate_x(-deg_to_rad(event.relative.y * mouse_sensivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	direction = lerp(direction, transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized(), delta * lerp_speed)
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
