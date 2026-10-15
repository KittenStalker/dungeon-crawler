@tool
extends Node3D

@export var grid_map_path : NodePath
@onready var grid_map : GridMap = get_node(grid_map_path)

@export_tool_button("Start") var start: Callable = func():
	if Engine.is_editor_hint():
			create_dungeon()

@export_tool_button("Clear") var clear: Callable = func():
	if Engine.is_editor_hint():
			clear_mesh()

@export_range(1,10) var step : int = 10
@export_range(0,1	) var intervallo : float = 0

var dun_cell_scene : PackedScene = preload("res://Asset/dun_mesh.tscn")

var directions : Dictionary = {
	"up" : Vector3i.FORWARD,
	"down" : Vector3i.BACK,
	"left" : Vector3i.LEFT,
	"right" : Vector3i.RIGHT
}

signal mesh_created

func handle_none(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_door")
func handle_00(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")
func handle_01(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_door")
func handle_02(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")
func handle_10(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_door")
func handle_11(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")
func handle_12(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")
func handle_20(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")
func handle_21(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
func handle_22(cell:Node3D, dir:String):
	cell.call("remove_" + dir + "_wall")
	cell.call("remove_" + dir + "_door")

# Возвращает true, когда проём нужно открыть полностью (без арки и колонны):
#  - тайл выходит в коридор (тип 1) двумя и более сторонами => угол/перекрёсток;
#  - рядом вдоль стены стоит ещё один дверной тайл, тоже смотрящий в коридор
#    в ту же сторону => проём шире одной клетки.
func _should_open_fully(cell : Vector3i, dir : Vector3i) -> bool:
	var corridor_sides : int = 0
	for d in directions.values():
		if grid_map.get_cell_item(cell + d) == 1:
			corridor_sides += 1
	if corridor_sides >= 2:
		return true
	# перпендикуляр к dir в плоскости XZ
	var perp : Vector3i = Vector3i(dir.z, 0, dir.x)
	for s in [perp, -perp]:
		var side : Vector3i = cell + s
		if grid_map.get_cell_item(side) == 2 and grid_map.get_cell_item(side + dir) == 1:
			return true
	return false

func clear_mesh():
	for c in get_children():
		remove_child(c)
		c.queue_free()
	print("Mesh cleared")

func create_dungeon():
	print("Creating meshes...")
	print("Clear previous mesh")
	clear_mesh()
	var t : int = 0
	
	for cell in grid_map.get_used_cells():
		var cell_index : int = grid_map.get_cell_item(cell)
		if cell_index <=2 && cell_index >=0:
			var dun_cell : Node3D = dun_cell_scene.instantiate()
			dun_cell.position = Vector3(cell)
			add_child(dun_cell)
			t += 1
			for i in 4:   #определение стороны для двери
				var cell_n : Vector3i = cell + directions.values()[i]
				var cell_n_index : int = grid_map.get_cell_item(cell_n)
				if cell_n_index == -1 || cell_n_index == 3:
					handle_none(dun_cell, directions.keys()[i])
				else:
					var key : String = str(cell_index) + str(cell_n_index)
					if key == "21" and _should_open_fully(cell, directions.values()[i]):
						handle_22(dun_cell, directions.keys()[i])
					else:
						# убираем две арки, оставляем пустое пространство вместо двух арок рядом
						call("handle_" + key, dun_cell, directions.keys()[i]) 
		if t%step == step-1 : await get_tree().create_timer(intervallo).timeout
	print("Done creating meshes\n")
	mesh_created.emit()
