extends Node

func appliquer_effet(parent):
	# Soigne le joueur entre 1 et 10 PV
	var soin = randi_range(1, 10)
	parent.player_hp += soin
	if parent.player_hp > 100:
		parent.player_hp = 100
	parent.UpdatePlayer()
