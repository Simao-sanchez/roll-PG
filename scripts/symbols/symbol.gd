extends Node2D

var data: Dictionary = {}

# Appelée juste après l'instanciation du symbole
func setup(symbol_id: String) -> void:
	if not Database.symbols.has(symbol_id):
		push_error("Symbol ID inconnu : " + symbol_id)
		return

	data = Database.symbols[symbol_id]

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

# Permet au slot machine de récupérer la texture finale
func get_texture() -> Texture2D:
	return $Sprite2D.texture
