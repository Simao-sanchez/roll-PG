extends Node2D

var data: Dictionary = {}

# Référence vers les données du slot machine
@onready var symbols_data = preload("res://data/symbols.json").symbols

func setup(symbol_id: String) -> void:
	if not symbols_data.has(symbol_id):
		push_error("Symbol ID inconnu : " + symbol_id)
		return

	data = symbols_data[symbol_id]

	# Chargement du sprite
	if data.has("sprite"):
		var tex = load(data["sprite"])
		if tex:
			$Sprite2D.texture = tex
		else:
			push_warning("Impossible de charger la texture : " + data["sprite"])

	# Nom (optionnel)
	if data.has("name"):
		$Label.text = data["name"]
	else:
		$Label.text = ""

func get_texture() -> Texture2D:
	return $Sprite2D.texture
