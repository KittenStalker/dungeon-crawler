@tool 
extends Node3D

@onready var grid_map: GridMap = $GridMap
@onready var inventory_interface: Control = $CanvasLayer/InventoryInterface
@onready var player: CharacterBody3D = $Player

const marker = preload("res://Asset/node_3d.tscn") #center TODO rework

var spawned_count : int = 0
var centers_visible : bool = false

var rng = RandomNumberGenerator.new()

@export_tool_button("Generate") var generate_dungeon: Callable = func():
	if Engine.is_editor_hint():
			generate()

@export_tool_button("Clear") var layout_clear: Callable = func():
	if Engine.is_editor_hint():
			dungeon_layout_clear()

@export_range(0,1) var survival_chance : float = 1.0

@export_tool_button("Toggle centers") var toggle_centers: Callable = func():
	if centers_visible:
		clear_centers()
		print("cleared")
	else: 
		visualize_centers()
		print("shown")

@export var border_size : int = 150 : set = set_border_size
func set_border_size(val:int)->void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

@export var min_room_size : int = 6
@export var max_room_size : int = 12
@export var room_number : int = 30
@export var room_margin : int = 3
@export var max_recursion : int = 8
@export_multiline var custom_seed : String = "" : set = set_seed
func set_seed(val:String)->void:
	custom_seed = val
	if val.is_empty():
		rng.randomize()
	else:
		rng.seed = hash(val)

@export var room_tiles : Array[PackedVector3Array] = []
@export var room_positions : PackedVector3Array = []
@export var spawned_centers : Array = []
func _ready() -> void:


	$DunMesh.mesh_created.connect(func(): spawn_random())
	full_regenerate()
	
	player.toggle_inventory.connect(toggle_inventory_interface)
	inventory_interface.set_player_inventory_data(player.inventory_data)

func full_regenerate():
	$TopCamera.make_current()
	await generate(custom_seed)
	
	$DunMesh.call_deferred("create_dungeon")

func spawn_random():
	print("Preparing random cords")
	Array(room_positions).shuffle()
	var random_pos = Array(room_positions).pick_random()
	random_pos.y += 2
	print(random_pos)
	spawn_at(random_pos)
	return random_pos

func spawn_at(coords: Vector3):
	spawned_count += 1
	player.global_position = coords
	player.update_ui(custom_seed)
	print("Spawned at: ", coords)
	player.set_camera()
	print("Spawned count: ", spawned_count)

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
	centers_visible = true
	print("Добавлено позиций: ", spawned_centers.size())

func clear_centers():
	for center in spawned_centers:
		if center != null and is_instance_valid(center):
			if center is Node:
				center.free()
	spawned_centers.clear()
	centers_visible = false
	print("Все объекты удалены. Осталось: ", spawned_centers.size())

func dungeon_layout_clear():
	grid_map.clear()
	clear_centers()
	room_tiles.clear()
	room_positions.clear()

# Основная функция генерации комнат
func generate(seed: String = ""):
	dungeon_layout_clear()
	clear_graph()
	print("generating...")
	
	if seed:
		custom_seed = seed
	print("custom seed: " + custom_seed) #в игре приоритет отдается сиду, вызываемому в коде, а в редакторе из редактора
	
	#создание комнат
	visualize_border()
	for i in room_number:
		make_room(max_recursion)
	#создание проходов
	delunay_gen()
	
	
	print("Centers: ", room_positions)
	visualize_centers()
	print("Done generating layout\n")

func delunay_gen():
	var room_pos_V2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	#триангуляция делоне
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
	visited_points.append(rng.randi() % room_positions.size())
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
				var kill : float = rng.randf()
				if survival_chance > kill:
					hallway_graph.connect_points(p,c)
	create_hallways(hallway_graph)
	draw_graph_3d(hallway_graph, room_positions)

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
	
	var width : int = rng.randi_range(min_room_size, max_room_size)
	var height : int = rng.randi_range(min_room_size, max_room_size)
	
	var start_position : Vector3i
	start_position.x = rng.randi() % (border_size - width + 1)
	start_position.z = rng.randi() % (border_size - height + 1)
	
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

func _on_button_pressed() -> void:
	full_regenerate()

func _on_text_edit_text_changed() -> void:
	if $TextEdit.text == "random":
		custom_seed = ""
	else:
		custom_seed = $TextEdit.text
	print("button text: ", $TextEdit.text)

var graph_mesh_instance: MeshInstance3D = null

func draw_graph_3d(hallway_graph: AStar2D, room_positions: Array):
	# Очищаем старый
	clear_graph()
	
	var vertices = PackedVector3Array()
	
	for p in hallway_graph.get_point_ids():
		var from_pos = room_positions[p]
		for c in hallway_graph.get_point_connections(p):
			if c > p:
				var to_pos = room_positions[c]
				vertices.append(Vector3(from_pos.x, from_pos.y + 0.1, from_pos.z))
				vertices.append(Vector3(to_pos.x, to_pos.y + 0.1, to_pos.z))
	
	if vertices.is_empty():
		return
	
	# Создаем ArrayMesh
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	# Добавляем индексы
	var indices = PackedInt32Array()
	for i in range(vertices.size()):
		indices.append(i)
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	
	# Создаем MeshInstance3D
	graph_mesh_instance = MeshInstance3D.new()
	graph_mesh_instance.mesh = array_mesh
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	graph_mesh_instance.material_override = material
	
	add_child(graph_mesh_instance)

func clear_graph():
	if graph_mesh_instance:
		graph_mesh_instance.queue_free()
		graph_mesh_instance = null

########## INVENTORY
func toggle_inventory_interface() -> void:
	inventory_interface.visible = not inventory_interface.visible
	if inventory_interface.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
