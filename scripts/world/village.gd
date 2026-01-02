extends Node2D

@onready var maison = $Maison  # Adapte au nom exact !

func _ready():
	print("✅ Village OK ! Clique maison")

func _on_maison_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🏠 MAISON CLIQUÉE ! ✅")
		print("Prochaine étape: Maison.tscn")
		# Décommente pour changer scène:
		get_tree().change_scene_to_file("res://scenes/world/maison.tscn")
