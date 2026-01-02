extends Node2D

@onready var jouer_button: Button = $JouerButton

func _ready() -> void:
	print("=== Menu chargé ===")
	if jouer_button:
		print("JouerButton trouvé: ", jouer_button.name)
		jouer_button.pressed.connect(_on_jouer_pressed)
		print("Signal pressed connecté: ", jouer_button.pressed.is_connected(_on_jouer_pressed))
	else:
		print("ERREUR: JouerButton introuvable ! Vérifiez le chemin $JouerButton")
	
	# Test existence scène
	var scene_path = "res://slot_machine.tscn"
	if ResourceLoader.exists(scene_path):
		print("Scène OK: ", scene_path)
	else:
		print("ERREUR: Scène manquante: ", scene_path)

func _on_jouer_pressed() -> void:
	print("Bouton Jouer cliqué !")
	var scene_path = "res://village.tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file.call_deferred(scene_path)
		print("Changement de scène lancé...")
	else:
		print("ERREUR: Impossible de charger ", scene_path)
