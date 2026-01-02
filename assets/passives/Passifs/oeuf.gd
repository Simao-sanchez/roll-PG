# res://passifs/oeuf.gd
extends Node

var nom = "Œuf"
var effet = "Quand un arc déclenche l'effet d'une flèche, ajoute deux flèches à votre sac à dos"

func appliquer_effet(joueur):
	joueur.arc_oeuf = true
