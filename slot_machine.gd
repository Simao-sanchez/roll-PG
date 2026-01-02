extends Node2D

@onready var grid_container = $Container
@onready var inventory_panel = $InventoryPanel

var backpack = []
var spin_duration = 2.0
var spin_speed = 0.05
var player_hp = 100
var ennemis_vaincus = 0
var dernier_ennemi = ""

# Variables pour les dégâts ennemis
var enemy_damage_values = [0, 5, 10, 13]
var pending_enemy_damage = 0

# État pour bloquer les boutons pendant les choix
var choix_en_cours = false

# Liste des ennemis avec noms et PV
var ennemis_liste = [
	{"nom": "Hobbit", "hp": 50, "texture": preload("res://Sprites_ennemy/slime.png")},
	{"nom": "Vampire", "hp": 70, "texture": preload("res://Sprites_ennemy/golem.png")},
	{"nom": "Bête", "hp": 100, "texture": preload("res://Sprites_ennemy/dragon.png")},
	{"nom": "Tréant", "hp": 65, "texture": preload("res://Sprites_ennemy/slime.png")},
	{"nom": "Poulet", "hp": 55, "texture": preload("res://Sprites_ennemy/golem.png")},
	{"nom": "Ondin", "hp": 85, "texture": preload("res://Sprites_ennemy/dragon.png")}
]

# Liste des textures disponibles pour les ennemis
var textures_ennemies = [
	preload("res://Sprites_ennemy/slime.png"),
	preload("res://Sprites_ennemy/golem.png"),
	preload("res://Sprites_ennemy/dragon.png")
]

var enemy = {}

# Chargement des scènes d'objets
var epee_scene = preload("res://Items/epee.tscn")
var bouclier_scene = preload("res://Items/bouclier.tscn")
var potion_scene = preload("res://Items/potion.tscn")
var arc_scene = preload("res://Items/arc.tscn")
var fleche_scene = preload("res://Items/fleche.tscn")
var pomme_scene = preload("res://Items/Pomme.tscn")
var danse_lame_scene = preload("res://Items/DanseLame.tscn")
var key_scene = preload("res://Items/Key.tscn")
var coffre_scene = preload("res://Items/coffre.tscn")
var gemme_verte_scene = preload("res://Items/gemme_verte.tscn")

var viande_scene = preload("res://passifs/viande.tscn")
var oeuf_scene = preload("res://passifs/oeuf.tscn")
var glace_scene = preload("res://passifs/glace.tscn")

var objets_jeu = [
	{"nom": "Épée", "texture": epee_scene, "effet": "Inflige 1 dégât supplémentaire"},
	{"nom": "Bouclier", "texture": bouclier_scene, "effet": "Réduit les dégâts de 1"},
	{"nom": "Potion", "texture": potion_scene, "effet": "Rend 10 points de vie"},
	{"nom": "Arc", "texture": arc_scene, "effet": "Triple les dégâts des flèches adjacentes"},
	{"nom": "Flèche", "texture": fleche_scene, "effet": "Inflige 1 dégât"},
	{"nom": "Pomme", "texture": pomme_scene, "effet": "Soigne 2PV au joueur"},
	{"nom": "Danse-Lame", "texture": danse_lame_scene, "effet": "Inflige 1 point de dégat pour chaque épée adjacente"},
	{"nom": "Key", "texture": key_scene, "effet": "Permet d'ouvrir un coffre adjacent, se détruit dans l'opération"},
	{"nom": "Coffre", "texture": coffre_scene, "effet": "Contient un trésor, nécessite une clé pour s'ouvrir"},
	{"nom": "Gemme_verte", "texture": gemme_verte_scene, "effet": "Une gemme rare"}
]

var passifs_jeu = [
	{"nom": "Viande", "texture": viande_scene, "effet": "Vos épées comptent double"},
	{"nom": "Œuf", "texture": oeuf_scene, "effet": "Quand un arc déclenche l'effet d'une flèche, ajoute deux flèches à votre sac à dos"},
	{"nom": "Glace", "texture": glace_scene, "effet": "Soigne 1 à 10 PV à chaque roll"}
]

var passifs_actifs = []
var double_epées = false
var arc_oeuf = false

var items = []
var texture_rects = []

# Compteurs de spins pour les pouvoirs
var spin_count = 0
var cooldown_pouvoir = [5, 6, 7, 8]
var pouvoir_disponible = [false, false, false, false]
var pouvoir_boutons = []
var spin_compteur_pouvoir = [0, 0, 0, 0]

# ColorRect de fond pour rendre le ChoixPanel bien opaque
var choix_background: ColorRect

# === TOOLTIP ===
var tooltip_label: Label
var tooltip_timer: Timer
var hovered_slot_index: int = -1
var tooltip_delay := 1.0


func _ready():
	randomize()
	for i in range(13):
		backpack.append(epee_scene)
	for i in range(12):
		backpack.append(bouclier_scene)
	for i in range(5):
		backpack.append(fleche_scene)
	for i in range(2):
		backpack.append(key_scene)
		backpack.append(coffre_scene)

	pouvoir_boutons = [$Pouvoir1, $Pouvoir2, $Pouvoir3, $Pouvoir4]

	$SpinButton.pressed.connect(_on_spin_button_pressed)
	$BackpackButton.pressed.connect(_on_backpack_button_pressed)
	$InventoryPanel/CloseButton.pressed.connect(_on_close_button_pressed)
	$InventoryPanel.visible = false
	$ChoixPanel.visible = false

	$ChoixPanel/Bouton1.pressed.connect(_on_bouton1_pressed)
	$ChoixPanel/Bouton2.pressed.connect(_on_bouton2_pressed)
	$ChoixPanel/Bouton3.pressed.connect(_on_bouton3_pressed)

	$Pouvoir1.pressed.connect(_on_pouvoir1_pressed)
	$Pouvoir2.pressed.connect(_on_pouvoir2_pressed)
	$Pouvoir3.pressed.connect(_on_pouvoir3_pressed)
	$Pouvoir4.pressed.connect(_on_pouvoir4_pressed)

	# ColorRect de fond pour ChoixPanel
	choix_background = ColorRect.new()
	choix_background.color = Color(0, 0, 0, 0.8)
	choix_background.mouse_filter = Control.MOUSE_FILTER_STOP
	choix_background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choix_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(choix_background)
	choix_background.visible = false
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()
# === CRÉATION DU TOOLTIP CORRIGÉ ===
	tooltip_label = Label.new()
	tooltip_label.visible = false
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.size = Vector2(220, 60)
	tooltip_label.custom_minimum_size = Vector2(220, 60)

#Style visuel pour le rendre visible
	tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	tooltip_label.add_theme_font_size_override("font_size", 14)

# Fond semi-transparent
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.9)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(1, 1, 0, 1)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_right = 8
	style_box.corner_radius_bottom_left = 8
	tooltip_label.add_theme_stylebox_override("normal", style_box)

	tooltip_label.z_index = 100
	add_child(tooltip_label)
	tooltip_label.move_to_front()

	tooltip_timer = Timer.new()
	tooltip_timer.one_shot = true
	tooltip_timer.wait_time = tooltip_delay
	add_child(tooltip_timer)
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)

	print("Tooltip setup terminé")  # Debug


	if grid_container:
		grid_container.set_columns(5)
		for i in range(25):
			var texture_rect := TextureRect.new()
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
			texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			texture_rect.custom_minimum_size = Vector2(50, 50)
			texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS

			# Connexion des signaux pour le tooltip
			texture_rect.mouse_entered.connect(_on_grid_slot_mouse_entered.bind(i))
			texture_rect.mouse_exited.connect(_on_grid_slot_mouse_exited.bind(i))

			grid_container.add_child(texture_rect)
	else:
		push_error("Le nœud 'Container' n'a pas été trouvé.")

	if $CombatPanel/SpritesContainer/PlayerSprite:
		$CombatPanel/SpritesContainer/PlayerSprite.play("idle")
		$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_animation_finished)

	UpdateEnemy()
	UpdatePlayer()
	roll_enemy_damage()

	for i in range(pouvoir_boutons.size()):
		if pouvoir_boutons[i]:
			pouvoir_boutons[i].disabled = true
			var icon = pouvoir_boutons[i].get_node("pouvoir" + str(i+1))
			if icon:
				icon.modulate = Color(0.5, 0.5, 0.5, 1)


func _on_spin_button_pressed():
	if choix_en_cours:
		return  # Bloque le spin pendant les choix
	apply_pending_enemy_damage_to_player()
	$SpinButton.disabled = true
	items.clear()
	var temp_backpack = backpack.duplicate()
	
	for i in range(25):
		var index = randi() % temp_backpack.size()
		items.append(temp_backpack[index])
		temp_backpack.remove_at(index)
	
	texture_rects = grid_container.get_children()
	await spin_reels_column_by_column()
	resolve_key_coffre_combos()
	$SpinButton.disabled = false
	spin_count += 1
	check_pouvoir_cooldown()
	if $CombatPanel/SpritesContainer/PlayerSprite:
		$CombatPanel/SpritesContainer/PlayerSprite.play("attack")
		$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_player_attack_finished, CONNECT_ONE_SHOT)

# Toutes les colonnes tournent en même temps, mais s'arrêtent une par une de gauche à droite.
func spin_reels_column_by_column() -> void:
	var columns = 5
	var rows = 5
	var total_cols = columns

	# temps total pour le spin
	var total_time = spin_duration
	# temps entre les arrêts de colonnes (gauche -> droite)
	var col_interval = total_time / float(total_cols)

	var elapsed = 0.0

	while elapsed < total_time:
		# Détermine pour chaque colonne si elle tourne encore
		for col in range(columns):
			var col_stop_time = col * col_interval
			var col_end_time = col_stop_time + col_interval
			# Si on est avant le moment où cette colonne doit s'arrêter, elle tourne
			if elapsed < col_end_time:
				for row in range(rows):
					var idx = col + row * columns
					if idx >= 0 and idx < texture_rects.size():
						var texture_rect = texture_rects[idx]
						var random_item = backpack[randi() % backpack.size()]
						if random_item is PackedScene:
							var instance = random_item.instantiate()
							if instance.has_node("Sprite2D"):
								texture_rect.texture = instance.get_node("Sprite2D").texture
							instance.queue_free()
						else:
							texture_rect.texture = random_item
			# Sinon, cette colonne est arrêtée : on affiche le résultat final si ce n'est pas déjà fait
			else:
				for row in range(rows):
					var idx_final = col + row * columns
					if idx_final < items.size() and idx_final < texture_rects.size():
						var texture_rect_final = texture_rects[idx_final]
						var item = items[idx_final]
						if item is PackedScene:
							var instance_final = item.instantiate()
							if instance_final.has_node("Sprite2D"):
								texture_rect_final.texture = instance_final.get_node("Sprite2D").texture
							instance_final.queue_free()
						else:
							texture_rect_final.texture = item

		var t = get_tree().create_timer(spin_speed)
		await t.timeout
		elapsed += spin_speed

	# Sécurité : à la fin, on force les résultats finaux partout
	for i in range(min(texture_rects.size(), items.size())):
		var texture_rect_final2 = texture_rects[i]
		var item2 = items[i]
		if item2 is PackedScene:
			var instance_final2 = item2.instantiate()
			if instance_final2.has_node("Sprite2D"):
				texture_rect_final2.texture = instance_final2.get_node("Sprite2D").texture
			instance_final2.queue_free()
		else:
			texture_rect_final2.texture = item2

# Ancienne fonction (non utilisée par le spin principal)
func AnimateTextureRect(texture_rect, item):
	var start_time = Time.get_ticks_msec()
	var end_time = start_time + int(spin_duration * 1000)
	
	while Time.get_ticks_msec() < end_time:
		var random_item = backpack[randi() % backpack.size()]
		
		if random_item is PackedScene:
			var instance = random_item.instantiate()
			if instance.has_node("Sprite2D"):
				texture_rect.texture = instance.get_node("Sprite2D").texture
			instance.queue_free()
		else:
			texture_rect.texture = random_item
			
		var timer = get_tree().create_timer(spin_speed)
		await timer.timeout
	
	if item is PackedScene:
		var instance2 = item.instantiate()
		if instance2.has_node("Sprite2D"):
			texture_rect.texture = instance2.get_node("Sprite2D").texture
		instance2.queue_free()
	else:
		texture_rect.texture = item

func _on_player_attack_finished():
	if $CombatPanel/SpritesContainer/PlayerSprite and $CombatPanel/SpritesContainer/PlayerSprite.has_signal("animation_finished"):
		if $CombatPanel/SpritesContainer/PlayerSprite.is_connected("animation_finished", Callable(self, "_on_player_attack_finished")):
			$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.disconnect(Callable(self, "_on_player_attack_finished"))
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		ApplyDamage(items, texture_rects)
	)

func ApplyDamage(local_items, local_texture_rects):
	var degats = 0
	var epee_centre = false
	var centre_index = 12
	var arc_ajout = 0
	var _nombre_fleches = 0
	var nombre_epees_hors_centre = 0
	var nombre_epees_centre = 0
	var degats_fleches = 0
	var degats_epees = 0
	var soins = 0
	var degats_danse_lame = 0

	for i in range(local_items.size()):
		if local_items[i] == arc_scene:
			for j in get_adjacent_indices(i):
				if j < local_items.size() and local_items[j] == fleche_scene:
					var instance = local_items[j].instantiate()
					var fleche_script = instance.get_script()
					if fleche_script:
						fleche_script.set("triple", true)
					local_texture_rects[j].modulate = Color(1, 0.5, 0.5, 1)
					var timer = get_tree().create_timer(2.0)
					timer.timeout.connect(func():
						local_texture_rects[j].modulate = Color(1, 1, 1, 1)
					)
					instance.queue_free()
					if arc_oeuf:
						arc_ajout += 2

	for i in range(local_items.size()):
		if local_items[i] == epee_scene:
			if i == centre_index:
				epee_centre = true
				nombre_epees_centre += 1
			else:
				nombre_epees_hors_centre += 1
		elif local_items[i] == fleche_scene:
			var instance2 = local_items[i].instantiate()
			var fleche_script2 = instance2.get_script()
			if fleche_script2 and fleche_script2.get("triple"):
				degats_fleches += 3
				fleche_script2.set("triple", false)
			else:
				degats_fleches += 1
			instance2.queue_free()
			_nombre_fleches += 1
		elif local_items[i] == potion_scene:
			soins += 10
		elif local_items[i] == pomme_scene:
			soins += 2
		elif local_items[i] == danse_lame_scene:
			var adjacents = get_adjacent_indices(i)
			var count = 0
			for j in adjacents:
				if j < local_items.size() and local_items[j] == epee_scene:
					count += 1
			degats_danse_lame += count

	if double_epées:
		degats_epees = (nombre_epees_hors_centre * 2) + (nombre_epees_centre * 100)
	else:
		degats_epees = nombre_epees_hors_centre + (nombre_epees_centre * 50)

	degats = degats_epees + degats_fleches + degats_danse_lame

	var points_restants = enemy.hp - degats
	if points_restants < 0:
		points_restants = 0

	var damage_label = $CombatPanel/SpritesContainer/PlayerSprite/DamageLabel
	if damage_label:
		damage_label.text = str(degats)
		damage_label.visible = true
		damage_label.position = Vector2(0, -50)

	enemy.hp = points_restants
	var hp_bar = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hp_bar.max_value = enemy.hp
	hp_bar.value = points_restants
	hp_bar.queue_redraw()
	var hp_label = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hp_label.text = str(points_restants) + "/" + str(enemy.hp)

	if epee_centre:
		var centre_texture = local_texture_rects[centre_index]
		centre_texture.modulate = Color(1, 1, 0.5, 1)
		var timer2 = get_tree().create_timer(0.5)
		timer2.timeout.connect(func():
			centre_texture.modulate = Color(1, 1, 1, 1)
		)

	player_hp += soins
	if player_hp > 100:
		player_hp = 100
	UpdatePlayer()

	if points_restants == 0:
		ennemis_vaincus += 1
		if ennemis_vaincus % 2 == 0:
			AfficherChoixPassif()
		else:
			UpdateEnemy()
			AfficherChoixObjet()

	for i in range(arc_ajout):
		backpack.append(fleche_scene)
	
	roll_enemy_damage()

func get_adjacent_indices(index):
	var indices = []
	var x = index % 5
	var y = index / 5
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < 5 and ny >= 0 and ny < 5:
					indices.append(nx + ny * 5)
	return indices

func AfficherChoixObjet():
	choix_en_cours = true  # Bloque les boutons
	desactiver_boutons_jeu()
	choix_background.visible = true
	$ChoixPanel.visible = true
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()

	var choix = []
	while choix.size() < 3:
		var index = randi() % objets_jeu.size()
		if not choix.has(objets_jeu[index]):
			choix.append(objets_jeu[index])
	$ChoixPanel/Bouton1/NomLabel.text = choix[0].nom
	if choix[0].texture is PackedScene:
		var instance = choix[0].texture.instantiate()
		if instance.has_node("Sprite2D"):
			$ChoixPanel/Bouton1/ImageTextureRect.texture = instance.get_node("Sprite2D").texture
		instance.queue_free()
	else:
		$ChoixPanel/Bouton1/ImageTextureRect.texture = choix[0].texture
	$ChoixPanel/Bouton1/EffetLabel.text = choix[0].effet.left(30)

	$ChoixPanel/Bouton2/NomLabel.text = choix[1].nom
	if choix[1].texture is PackedScene:
		var instance2 = choix[1].texture.instantiate()
		if instance2.has_node("Sprite2D"):
			$ChoixPanel/Bouton2/ImageTextureRect.texture = instance2.get_node("Sprite2D").texture
		instance2.queue_free()
	else:
		$ChoixPanel/Bouton2/ImageTextureRect.texture = choix[1].texture
	$ChoixPanel/Bouton2/EffetLabel.text = choix[1].effet.left(30)

	$ChoixPanel/Bouton3/NomLabel.text = choix[2].nom
	if choix[2].texture is PackedScene:
		var instance3 = choix[2].texture.instantiate()
		if instance3.has_node("Sprite2D"):
			$ChoixPanel/Bouton3/ImageTextureRect.texture = instance3.get_node("Sprite2D").texture
		instance3.queue_free()
	else:
		$ChoixPanel/Bouton3/ImageTextureRect.texture = choix[2].texture
	$ChoixPanel/Bouton3/EffetLabel.text = choix[2].effet.left(30)

func AfficherChoixPassif():
	choix_en_cours = true  # Bloque les boutons
	desactiver_boutons_jeu()
	choix_background.visible = true
	$ChoixPanel.visible = true
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()

	var choix = []
	while choix.size() < 3:
		var index = randi() % passifs_jeu.size()
		if not choix.has(passifs_jeu[index]):
			choix.append(passifs_jeu[index])
	
	for i in range(3):
		var bouton = $ChoixPanel.get_node("Bouton" + str(i + 1))
		var passif = choix[i]
		bouton.get_node("NomLabel").text = passif.nom
		bouton.get_node("EffetLabel").text = passif.effet.left(30)
		
		if passif.texture is PackedScene:
			var instance = passif.texture.instantiate()
			var sprite = instance.get_node("Sprite2D")
			if sprite:
				bouton.get_node("ImageTextureRect").texture = sprite.texture
			instance.queue_free()
		else:
			bouton.get_node("ImageTextureRect").texture = passif.texture

# Fonction pour désactiver les boutons de jeu pendant les choix
func desactiver_boutons_jeu():
	$SpinButton.disabled = true
	for bouton in pouvoir_boutons:
		if bouton:
			bouton.disabled = true

# Fonction pour réactiver les boutons de jeu après un choix
func reactiver_boutons_jeu():
	$SpinButton.disabled = false
	for i in range(pouvoir_boutons.size()):
		if pouvoir_boutons[i] and pouvoir_disponible[i]:
			pouvoir_boutons[i].disabled = false
	choix_en_cours = false

func _on_bouton1_pressed():
	$ChoixPanel.visible = false
	choix_background.visible = false
	var nom_bouton = $ChoixPanel/Bouton1/NomLabel.text
	for objet in objets_jeu:
		if objet.nom == nom_bouton:
			backpack.append(objet.texture)
			break
	for passif in passifs_jeu:
		if passif.nom == nom_bouton:
			var instance = passif.texture.instantiate()
			if instance.has_method("appliquer_effet"):
				instance.appliquer_effet(self)
			instance.queue_free()
			passifs_actifs.append(passif)
			UpdateInventory()
			break
	reactiver_boutons_jeu()  # Réactive les boutons après le choix

func _on_bouton2_pressed():
	$ChoixPanel.visible = false
	choix_background.visible = false
	var nom_bouton = $ChoixPanel/Bouton2/NomLabel.text
	for objet in objets_jeu:
		if objet.nom == nom_bouton:
			backpack.append(objet.texture)
			break
	for passif in passifs_jeu:
		if passif.nom == nom_bouton:
			var instance = passif.texture.instantiate()
			if instance.has_method("appliquer_effet"):
				instance.appliquer_effet(self)
			instance.queue_free()
			passifs_actifs.append(passif)
			UpdateInventory()
			break
	reactiver_boutons_jeu()  # Réactive les boutons après le choix

func _on_bouton3_pressed():
	$ChoixPanel.visible = false
	choix_background.visible = false
	var nom_bouton = $ChoixPanel/Bouton3/NomLabel.text
	for objet in objets_jeu:
		if objet.nom == nom_bouton:
			backpack.append(objet.texture)
			break
	for passif in passifs_jeu:
		if passif.nom == nom_bouton:
			var instance = passif.texture.instantiate()
			if instance.has_method("appliquer_effet"):
				instance.appliquer_effet(self)
			instance.queue_free()
			passifs_actifs.append(passif)
			UpdateInventory()
			break
	reactiver_boutons_jeu()  # Réactive les boutons après le choix

func _on_pouvoir1_pressed():
	if choix_en_cours or not pouvoir_disponible[0]:
		return
	player_hp += 10
	if player_hp > 100:
		player_hp = 100
	UpdatePlayer()
	pouvoir_disponible[0] = false
	spin_compteur_pouvoir[0] = 0
	if pouvoir_boutons[0]:
		pouvoir_boutons[0].disabled = true
		var icon = pouvoir_boutons[0].get_node("pouvoir1")
		if icon:
			icon.modulate = Color(0.5, 0.5, 0.5, 1)
	print("Pouvoir 1 utilisé, en recharge")
	check_pouvoir_cooldown()

func _on_pouvoir2_pressed():
	if choix_en_cours or not pouvoir_disponible[1]:
		return
	var degats_pouvoir = 10
	enemy.hp -= degats_pouvoir
	if enemy.hp < 0:
		enemy.hp = 0
	var hp_bar = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hp_bar.max_value = enemy.hp if enemy.hp > 0 else 0
	hp_bar.value = enemy.hp
	hp_bar.queue_redraw()
	var hp_label = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hp_label.text = str(enemy.hp) + "/" + str(enemy.hp)
	if enemy.hp == 0:
		ennemis_vaincus += 1
		if ennemis_vaincus % 2 == 0:
			AfficherChoixPassif()
		else:
			UpdateEnemy()
			AfficherChoixObjet()
	pouvoir_disponible[1] = false
	spin_compteur_pouvoir[1] = 0
	if pouvoir_boutons[1]:
		pouvoir_boutons[1].disabled = true
		var icon = pouvoir_boutons[1].get_node("pouvoir2")
		if icon:
			icon.modulate = Color(0.5, 0.5, 0.5, 1)
	print("Pouvoir 2 utilisé, en recharge")
	check_pouvoir_cooldown()

func _on_pouvoir3_pressed():
	if choix_en_cours or not pouvoir_disponible[2]:
		return
	AfficherChoixObjet()
	pouvoir_disponible[2] = false
	spin_compteur_pouvoir[2] = 0
	if pouvoir_boutons[2]:
		pouvoir_boutons[2].disabled = true
		var icon = pouvoir_boutons[2].get_node("pouvoir3")
		if icon:
			icon.modulate = Color(0.5, 0.5, 0.5, 1)
	print("Pouvoir 3 utilisé, en recharge")
	check_pouvoir_cooldown()

func _on_pouvoir4_pressed():
	if choix_en_cours or not pouvoir_disponible[3]:
		return
	pouvoir_disponible[3] = false
	spin_compteur_pouvoir[3] = 0
	if pouvoir_boutons[3]:
		pouvoir_boutons[3].disabled = true
		var icon = pouvoir_boutons[3].get_node("pouvoir4")
		if icon:
			icon.modulate = Color(0.5, 0.5, 0.5, 1)
	print("Pouvoir 4 utilisé, en recharge")
	check_pouvoir_cooldown()

func UpdateEnemy():
	var choix = []
	for ennemi in ennemis_liste:
		if ennemi.nom != dernier_ennemi:
			choix.append(ennemi)
	
	if choix.size() == 0:
		choix = ennemis_liste.duplicate()
	
	var index = randi() % choix.size()
	enemy = choix[index]
	dernier_ennemi = enemy.nom
	var texture_index = randi() % textures_ennemies.size()
	enemy.texture = textures_ennemies[texture_index]

	var hp_bar = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hp_bar.max_value = enemy.hp
	hp_bar.value = enemy.hp
	hp_bar.queue_redraw()
	$CombatPanel/SpritesContainer/EnemySprite/EnemyName.text = enemy.nom
	$CombatPanel/SpritesContainer/EnemySprite.texture = enemy.texture
	var hp_label = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hp_label.text = str(enemy.hp) + "/" + str(enemy.hp)

func UpdatePlayer():
	var hp_bar = $CombatPanel/SpritesContainer/PlayerSprite/PlayerHPBar
	hp_bar.max_value = 100
	hp_bar.value = player_hp
	hp_bar.queue_redraw()
	var hp_label = $CombatPanel/SpritesContainer/PlayerSprite/PlayerHPLabel
	hp_label.text = str(player_hp) + "/100"

func UpdateInventory():
	for i in range(3):
		var bouton = inventory_panel.get_node("PassifButton" + str(i + 1))
		if bouton:
			var label_nom = bouton.get_node("NomLabel")
			var label_effet = bouton.get_node("EffetLabel")
			var image = bouton.get_node("ImageTextureRect")
			if label_nom and label_effet and image:
				if i < passifs_actifs.size():
					bouton.visible = true
					if passifs_actifs[i].texture is PackedScene:
						var instance = passifs_actifs[i].texture.instantiate()
						var sprite = instance.get_node("Sprite2D")
						if sprite:
							image.texture = sprite.texture
						instance.queue_free()
					else:
						image.texture = passifs_actifs[i].texture
					label_nom.text = passifs_actifs[i].nom
					label_effet.text = passifs_actifs[i].effet.left(30)
				else:
					bouton.visible = false

func _on_backpack_button_pressed():
	$InventoryPanel.visible = !$InventoryPanel.visible
	if $InventoryPanel.visible:
		$InventoryPanel.move_to_front()
	UpdateInventory()

func _on_close_button_pressed():
	$InventoryPanel.visible = false

func set_double_epées(valeur):
	double_epées = valeur

func _on_animation_finished():
	if $CombatPanel/SpritesContainer/PlayerSprite and $CombatPanel/SpritesContainer/PlayerSprite.animation == "attack":
		$CombatPanel/SpritesContainer/PlayerSprite.play("idle")

func roll_enemy_damage():
	if enemy_damage_values.size() == 0:
		return
	pending_enemy_damage = enemy_damage_values.pick_random()
	
	var damage_label = $CombatPanel/SpritesContainer/EnemySprite/EnemyDamageLabel
	if damage_label:
		damage_label.text = str(pending_enemy_damage)

	for passif in passifs_actifs:
		if passif.nom == "Glace":
			var instance = passif.texture.instantiate()
			if instance.has_method("appliquer_effet"):
				instance.appliquer_effet(self)
			instance.queue_free()

func apply_pending_enemy_damage_to_player():
	if pending_enemy_damage <= 0:
		return
	
	player_hp -= pending_enemy_damage
	if player_hp < 0:
		player_hp = 0
	
	var hp_bar = $CombatPanel/SpritesContainer/PlayerSprite/PlayerHPBar
	hp_bar.max_value = 100
	var tween = get_tree().create_tween()
	tween.tween_property(hp_bar, "value", player_hp, 0.5)
	tween.tween_callback(func():
		UpdatePlayer()
	)
	
	if player_hp <= 0:
		get_tree().reload_current_scene()

# Fonction pour détecter et transformer clé + coffre en gemme_verte (uniquement pour les paires adjacentes)
func resolve_key_coffre_combos():
	var found_pairs = []
	for i in range(items.size()):
		if items[i] == key_scene:
			var adj = get_adjacent_indices(i)
			for j in adj:
				if j < 0 or j >= items.size():
					continue
				if items[j] == coffre_scene:
					found_pairs.append([i, j])
	
	for pair in found_pairs:
		if backpack.has(key_scene) and backpack.has(coffre_scene):
			backpack.erase(key_scene)
			backpack.erase(coffre_scene)
			backpack.append(gemme_verte_scene)
			print("clé + coffre = gemme verte")
	
	for i in range(min(texture_rects.size(), items.size())):
		update_slot_texture(i)

func update_slot_texture(index: int) -> void:
	if index < 0 or index >= texture_rects.size():
		return
	var texture_rect = texture_rects[index]
	var item = items[index]
	if item == null:
		texture_rect.texture = null
		return
	
	if item is PackedScene:
		var instance = item.instantiate()
		if instance.has_node("Sprite2D"):
			texture_rect.texture = instance.get_node("Sprite2D").texture
		instance.queue_free()
	else:
		texture_rect.texture = item

# Vérifie la disponibilité des pouvoirs
func check_pouvoir_cooldown():
	for i in range(pouvoir_boutons.size()):
		spin_compteur_pouvoir[i] += 1
		if not pouvoir_disponible[i] and spin_compteur_pouvoir[i] >= cooldown_pouvoir[i]:
			pouvoir_disponible[i] = true
			if pouvoir_boutons[i] and not choix_en_cours:  # Ne réactive pas si choix en cours
				pouvoir_boutons[i].disabled = false
				var icon = pouvoir_boutons[i].get_node("pouvoir" + str(i+1))
				if icon:
					icon.modulate = Color(1, 1, 0, 1)
				print("Pouvoir " + str(i+1) + " disponible !")


# ========= TOOLTIP LOGIC =========

func _on_grid_slot_mouse_entered(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	hovered_slot_index = index
	tooltip_timer.start()


func _on_grid_slot_mouse_exited(index: int) -> void:
	if hovered_slot_index == index:
		hovered_slot_index = -1
		tooltip_timer.stop()
		tooltip_label.visible = false


func _on_tooltip_timer_timeout() -> void:
	if hovered_slot_index < 0 or hovered_slot_index >= items.size():
		return

	var item = items[hovered_slot_index]
	var nom := ""
	var effet := ""

	# Récupère nom/effet à partir des listes d'objets/passifs
	for obj in objets_jeu:
		if obj.texture == item:
			nom = obj.nom
			effet = obj.effet
			break

	if nom == "":
		for passif in passifs_jeu:
			if passif.texture == item:
				nom = passif.nom
				effet = passif.effet
				break

	if nom == "":
		return

	tooltip_label.text = nom + "\n" + effet

	# Position du tooltip près de la souris
	var mouse_pos = get_viewport().get_mouse_position()
	tooltip_label.position = mouse_pos + Vector2(16, 16)
	tooltip_label.visible = true
