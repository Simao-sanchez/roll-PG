extends Node2D

@onready var foxy = $Foxy           # Area2D cliquable
@onready var btn_retour = $UI/BoutonRetour
@onready var label = $UI/Label

var slot_machine_scene = preload("res://slot_machine.tscn")  # Ton jeu principal

func _ready():
	# Setup UI
	if btn_retour:
		btn_retour.text = "← Retour Village"
		btn_retour.pressed.connect(_on_retour_village)
	
	if label:
		label.text = "🏠 Maison du Guerrier\nClique FOXy pour jouer !"
	
	print("🏠 Maison chargée - Clique Foxy")

# SIGNAL Foxy (connecte dans Node dock → input_event)
func _on_foxy_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🦊 FOXy cliquée → Slot Machine !")
		get_tree().change_scene_to_packed(slot_machine_scene)

# SIGNAL Bouton Retour
func _on_retour_village():
	print("← Retour Village")
	get_tree().change_scene_to_file("res://Village.tscn")

# SIGNAL auto si t'as pas Label (optionnel)
func _on_label_input_event(_viewport, _event, _shape_idx):
	pass  # Ignore


func _on_bouton_retour_pressed():
	pass # Replace with function body.
