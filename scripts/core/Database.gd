extends Node

var symbols = {}
var passives = {}
var enemies = {}

func _ready():
	print("TYPE symbols =", typeof(symbols))
	symbols = load_json("res://data/symbols.json")
	passives = load_json("res://data/passives.json")
	enemies = load_json("res://data/enemies.json")

func load_json(path):
	if not FileAccess.file_exists(path):
		push_warning("Fichier JSON manquant : " + path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()

	var json = JSON.new()
	var error = json.parse(content)

	if error != OK:
		push_error("Erreur JSON dans " + path + " : " + json.get_error_message())
		return {}

	return json.get_data()
