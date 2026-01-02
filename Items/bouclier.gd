# res://Items/bouclier.gd
extends Node

var nom = "Bouclier"
var effet = "Réduit les dégâts de 1"

func appliquer_effet(cible):
	cible.hp += 1  # Exemple : soigne 1 point de vie
	print("Le bouclier a réduit les dégâts pour ", cible.name)
