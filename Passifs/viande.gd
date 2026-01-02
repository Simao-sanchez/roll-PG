extends Node

var nom = "Viande"
var effet = "Vos épées comptent double"

func appliquer_effet(joueur):
	joueur.set_double_epées(true)
	print("Effet Viande activé : épées doublées pour le reste de la partie.")
