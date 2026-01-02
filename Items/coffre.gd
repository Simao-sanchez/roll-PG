extends Node2D

@export var nom: String = "Coffre"
@export var description: String = "Contient un trésor, nécessite une clé pour s'ouvrir"

func get_display_name() -> String:
	return nom

func get_description() -> String:
	return description
