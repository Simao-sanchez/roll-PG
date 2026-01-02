extends Node2D

var data: Dictionary = {}

func setup(symbol_id: String) -> void:
	# Vérifier que le symbole existe dans Database.symbols
	if not Database.symbols.has(symbol_id):
		push_error("Symbol ID inconnu : " + symbol_id)
		return

	data = Database.symbols[symbol_id]

	# Charger la texture
	if data.has("sprite"):
		var tex = load(data["sprite"])
		if tex:
			$Sprite2D.texture = tex
		else:
			push_warning("Impossible de charger la texture : " + data["sprite"])

	# Nom optionnel
	$Label.text = data.get("name", "")

func get_texture() -> Texture2D:
	return $Sprite2D.texture
