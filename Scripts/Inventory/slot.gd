extends PanelContainer

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var quantity_label: Label = $QuantityLabel

signal slot_clicked(index: int, button : int)

func set_slot_data(slot_data: SlotData) -> void:
	if slot_data != null:
		var item_data = slot_data.item_data
		if item_data != null:
			texture_rect.texture = item_data.texture
			tooltip_text = "%s\n%s" % [item_data.name, item_data.descrition]
			
			if slot_data.quantity > 1:
				quantity_label.text = "x%s" % slot_data.quantity
				quantity_label.show()
			else:
				quantity_label.hide()
		else:
			texture_rect.texture = null
			tooltip_text = ""
			quantity_label.hide()
	else:
		texture_rect.texture = null
		tooltip_text = ""
		quantity_label.hide()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() \
		and (event.button_index == MOUSE_BUTTON_LEFT \
		or event.button_index == MOUSE_BUTTON_RIGHT):
			slot_clicked.emit(get_index(), event.button_index)

func _on_mouse_entered() -> void:
	size.x += 5
	size.y += 5

func _on_mouse_exited() -> void:
	size.x -= 5
	size.y -= 5
