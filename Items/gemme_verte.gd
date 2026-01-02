extends Node2D

@export var nom: String = "Gemme_verte"
@export var description: String = "Une gemme rare"

func get_display_name() -> String:
	return nom

func get_description() -> String:
	return description
