extends Node2D

func utiliser(joueur):
	joueur.player_hp += 2
	if joueur.player_hp > 100:
		joueur.player_hp = 100
	joueur.UpdatePlayer()
	queue_free()
