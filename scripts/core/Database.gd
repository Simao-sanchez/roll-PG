extends Node

var symbols = {}
var passives = {}
var enemies = {}

func _ready():
	symbols = load_json("res://data/symbols.json")
	passives = load_json("res://data/passives.json")
	enemies = load_json("res://data/enemies.json")

func load_json(path):
	if not FileAccess.file_exists(path):
		push_warning("Fichier JSON manquant : " + path)
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text())
