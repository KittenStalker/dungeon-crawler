extends PanelContainer

const slot = preload("uid://dsc4spirm1bwn") 
@onready var grid_container: GridContainer = $MarginContainer/GridContainer

func _ready() -> void:
	var inv_data = preload("uid://dp56bv52163px")
	populate_item_grid(inv_data)

func set_inventory_data(inventory_data: InventoryData) -> void:
	inventory_data.inventory_updated.connect(populate_item_grid)
	populate_item_grid(inventory_data)

func populate_item_grid(inventory_data: InventoryData) -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	for slot_data in inventory_data.slot_data:
		var slot = slot.instantiate()
		grid_container.add_child(slot)
		
		slot.slot_clicked.connect(inventory_data.on_slot_clicked)
		
		if slot_data:
			slot.set_slot_data(slot_data)
