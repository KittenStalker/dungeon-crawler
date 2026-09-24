extends Resource
class_name InventoryData

@export var slot_data: Array[SlotData]

signal inventory_updated(inventory_data: InventoryData)
signal inventory_interact(inventory_data: InventoryData, index: int, button: int)

func on_slot_clicked(index: int, button : int) -> void:
	inventory_interact.emit(self, index, button)

func grab_slot_data(index: int) -> SlotData:
	var current_slot_data = slot_data[index]
	
	if current_slot_data:
		slot_data[index] = null
		inventory_updated.emit(self)
		return current_slot_data
	else:
		return null

func drop_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var current_slot_data = slot_data[index]
	
	var return_slot_data: SlotData
	if current_slot_data and current_slot_data.can_fully_merge_with(grabbed_slot_data):
		current_slot_data.fully_merge_with(grabbed_slot_data)
	else:
		slot_data[index] = grabbed_slot_data
		return_slot_data = current_slot_data
		
	inventory_updated.emit(self)

	return return_slot_data

func drop_single_slot_data(grabbed_slot_data: SlotData, index: int) -> SlotData:
	var current_slot_data = slot_data[index]
	
	if not current_slot_data:
		slot_data[index] = grabbed_slot_data.create_single_slot_data()
	
	inventory_updated.emit(self)
	
	if grabbed_slot_data.quantity > 0:
		return grabbed_slot_data
	else:
		return null
