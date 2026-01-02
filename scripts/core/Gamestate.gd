extends Node

var player_hp = 20
var max_hp = 20

var symbols_owned = []   # symboles dans le bandit manchot
var passives_owned = []  # passifs actifs
var gold = 0

func reset():
	player_hp = max_hp
	symbols_owned.clear()
	passives_owned.clear()
	gold = 0
