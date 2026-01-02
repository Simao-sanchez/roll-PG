extends Node2D

@export var nom: String = "Key"
@export var description: String = "Permet d'ouvrir un coffre adjacent, se détruit dans l'opération"

func get_display_name() -> String:
	return nom

func get_description() -> String:
	return description
