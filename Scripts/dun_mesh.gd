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

func clear_mesh():
	for c in get_children():
		remove_child(c)
		c.queue_free()
	print("Mesh cleared")

func create_dungeon():
	print("Creating meshes...")
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
					call("handle_" + key, dun_cell, directions.keys()[i])
		if t%step == step-1 : await get_tree().create_timer(intervallo).timeout
	print("Done")
