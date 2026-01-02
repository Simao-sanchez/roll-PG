extends Node2D

func utiliser(joueur):
	joueur.player_hp += 10
	if joueur.player_hp > 100:
		joueur.player_hp = 100
	joueur.UpdatePlayer()
	print("Potion utilisée : +10 PV au joueur. PV actuels : ", joueur.player_hp)
	queue_free()
