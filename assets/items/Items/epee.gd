# res://Items/epee.gd
extends Node

var nom = "Épée"
var effet = "Inflige 1 dégât supplémentaire"

# Fonction pour infliger 1 dégât
func appliquer_effet(cible):
	cible.hp -= 1
	print("L’épée a infligé 1 dégât à ", cible.name)

# Fonction pour infliger 50 dégâts (effet spécial au centre)
func appliquer_effet_special(cible):
	cible.hp -= 50
	print("Épée spéciale : 50 dégâts à ", cible.name)
