# res://Items/fleche.gd
extends Node

var nom = "Flèche"
var effet = "Inflige 1 dégât"
var triple = false

func appliquer_effet(cible):
	var degats = 1
	if triple:
		degats = 3
	cible.hp -= degats
	print("La flèche a infligé ", degats, " dégâts à ", cible.name)
