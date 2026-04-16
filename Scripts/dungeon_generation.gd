@tool 
extends Node3D
@onready var grid_map: GridMap = $GridMap
var marker = preload("res://Asset/node_3d.tscn")
var centers_visible : bool = false

@export_tool_button("Generate") var generate_dungeon: Callable = func():
	if Engine.is_editor_hint():
			generate()

@export_tool_button("Clear") var layout_clear: Callable = func():
	if Engine.is_editor_hint():
			dungeon_layout_clear()

@export_range(0,1) var survival_chance : float = 0.25

@export_tool_button("Toggle centers") var toggle_centers: Callable = func():
	if centers_visible:
		clear_centers()
		print("cleared")
	else: 
		visualize_centers()
		print("shown")

@export var border_size : int = 20 : set = set_border_size
func set_border_size(val:int)->void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

@export var min_room_size : int = 2
@export var max_room_size : int = 4
@export var room_number : int = 4
@export var room_margin : int = 1
@export var max_recursion : int = 5
@export_multiline var custom_seed : String = "" : set = set_seed
func set_seed(val:String)->void:
	custom_seed = val
	seed(val.hash())
	

@export var room_tiles : Array[PackedVector3Array] = []
@export var room_positions : PackedVector3Array = []
@export var spawned_centers : Array = []

# Визуализированные границы пространства
func visualize_border():
	for i in range(-1, border_size + 1):
		grid_map.set_cell_item(Vector3i(i,0,-1), 3)
		grid_map.set_cell_item(Vector3i(i,0,border_size), 3)
		grid_map.set_cell_item(Vector3i(border_size,0,i), 3)
		grid_map.set_cell_item(Vector3i(-1,0,i), 3)

#может быть не удалять а сделать отдельный массив (если проблема в производительности)
func visualize_centers():
	for pos in room_positions:
		pos.y += 4
		var new_marker = marker.instantiate()
		new_marker.position = pos
		spawned_centers.append(new_marker)
		add_child(new_marker)
		print("Добавлен объект на позиции: ", pos)
	centers_visible = true

func clear_centers():
	for center in spawned_centers:
		if center != null and is_instance_valid(center):
			if center is Node:
				center.free()
				print("Удален объект: ", center)
	spawned_centers.clear()
	centers_visible = false
	print("Все объекты удалены. Осталось: ", spawned_centers.size())

func dungeon_layout_clear():
	grid_map.clear()
	clear_centers()
	room_tiles.clear()
	room_positions.clear()

# Основная функция генерации комнат
func generate():
	dungeon_layout_clear()
	print("generating...")
	
	if custom_seed :
		set_seed(custom_seed)
	
	#создание комнат
	visualize_border()
	for i in room_number:
		make_room(max_recursion)
	
	var room_pos_V2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	
	#триангуляция делоне, но я не понимаю
	for p in room_positions:
		room_pos_V2.append(Vector2(p.x,p.z))
		del_graph.add_point(del_graph.get_available_point_id(),Vector2(p.x,p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(),Vector2(p.x,p.z))
	
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(room_pos_V2))
	
	for i in delaunay.size()/3:
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1,p2)
		del_graph.connect_points(p2,p3)
		del_graph.connect_points(p3,p1)
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi() % room_positions.size())
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections : Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp,c]
					possible_connections.append(con)
		var connection : PackedInt32Array = possible_connections.pick_random()
		for pc in possible_connections:
			if room_pos_V2[pc[0]].distance_squared_to(room_pos_V2[pc[1]]) <\
			room_pos_V2[connection[0]].distance_squared_to(room_pos_V2[connection[1]]):
				connection = pc
		
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0],connection[1])
		del_graph.disconnect_points(connection[0],connection[1])
	
	var hallway_graph : AStar2D = mst_graph
	
	#пересчет проходов
	#если survival chance выше, то корридоров больше
	for p in del_graph.get_point_ids():
		for c in del_graph.get_point_connections(p):
			if c>p:
				var kill : float = randf()
				if survival_chance > kill:
					hallway_graph.connect_points(p,c)
	create_hallways(hallway_graph)
	
	
	print("Centers: ", room_positions)
	visualize_centers()

#TODO изучить подробнее
func create_hallways(hallway_graph : AStar2D):
	var hallways : Array[PackedVector3Array] = []
	for p in hallway_graph.get_point_ids():
		for c in hallway_graph.get_point_connections(p):
			if c>p:
				var room_from : PackedVector3Array = room_tiles[p]
				var room_to : PackedVector3Array = room_tiles[c]
				var tile_from : Vector3 = room_from[0]
				var tile_to : Vector3 = room_to[0]
				
				for t in room_from:
					if t.distance_squared_to(room_positions[c])<\
					tile_from.distance_squared_to(room_positions[c]):
						tile_from = t
				for t in room_to:
					if t.distance_squared_to(room_positions[p])<\
					tile_to.distance_squared_to(room_positions[p]):
						tile_to = t
				var hallway : PackedVector3Array = [tile_from, tile_to]
				hallways.append(hallway)
				grid_map.set_cell_item(tile_from, 2)
				grid_map.set_cell_item(tile_to, 2)
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.update()
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	for t in grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x,t.z))
	
	for h in hallways:
		var pos_from : Vector2i = Vector2i(h[0].x, h[0].z)
		var pos_to : Vector2i = Vector2i(h[1].x, h[1].z)
		var hall : PackedVector2Array = astar.get_point_path(pos_from,pos_to)
		for t in hall:
			var pos : Vector3i = Vector3i(t.x,0,t.y)
			if grid_map.get_cell_item(pos) <0:
				grid_map.set_cell_item(pos,1)

func make_room(recursion:int):
	if !recursion > 0:
		return
	
	#TODO: Изменить на заранее заготовленные позже
	var width : int = randi_range(min_room_size, max_room_size)
	var height : int = randi_range(min_room_size, max_room_size)
	
	var start_position : Vector3i
	start_position.x = randi() % (border_size - width + 1)
	start_position.z = randi() % (border_size - height + 1)
	
	#проверка на наслоение комнат
	for r in range(-room_margin, height+room_margin):
		for c in range(-room_margin, width+room_margin):
			var position : Vector3i = start_position + Vector3i(c,0,r)
			if grid_map.get_cell_item(position) == 0:
				make_room(recursion-1) 
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var position : Vector3i = start_position + Vector3i(c,0,r)
			grid_map.set_cell_item(position, 0)
			room.append(position)
	room_tiles.append(room)
	var avg_x : float = start_position.x + (float(width)/2)
	var avg_z : float = start_position.z + (float(height)/2)
	var c_pos : Vector3 = Vector3(avg_x, 0, avg_z)
	room_positions.append(c_pos)
