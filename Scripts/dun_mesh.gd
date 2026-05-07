@tool
extends Node3D

func remove_up_wall():
	$up_wall.free()
func remove_up_door():
	$up_door.free()

func remove_down_wall():
	$down_wall.free()
func remove_down_door():
	$down_door.free()

func remove_right_wall():
	$right_wall.free()
func remove_right_door():
	$right_door.free()

func remove_left_wall():
	$left_wall.free()
func remove_left_door():
	$left_door.free()
