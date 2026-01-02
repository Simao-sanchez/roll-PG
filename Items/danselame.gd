extends Node2D

func get_degats_adjacents(items, index, epee_scene):
	var degats = 0
	var x = index % 5
	var y = index / 5
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < 5 and ny >= 0 and ny < 5:
					var adj_index = nx + ny * 5
					if adj_index < items.size() and items[adj_index] == epee_scene:
						degats += 1
	return degats
