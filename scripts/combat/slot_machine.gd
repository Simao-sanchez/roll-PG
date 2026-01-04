extends Node2D

# ---------------------------------------------------------
#                VARIABLES GLOBALES
# ---------------------------------------------------------

var backpack = []                         # Inventaire du joueur
var items = []                            # 25 symboles du spin
var texture_rects = []                    # Références aux 25 cases
var spin_count = 0
var choix_en_cours = false
var pending_enemy_damage = 0
var hovered_slot_index = -1
var draft_choices = []

var pouvoir_boutons = []
var pouvoir_disponible = [true, true, true, true]
var spin_compteur_pouvoir = [0, 0, 0, 0]
var cooldown_pouvoir = [3, 3, 3, 3]

var passifs_actifs = []
var player_hp = 100
var enemy = {}
var enemy_max_hp = 100
var ennemis_liste = []
var dernier_ennemi = ""
var ennemis_vaincus = 0

# --- Variables pour les pouvoirs ---
var powers_data = {}          # Contenu de powers.json
var last_damage_dealt = 0     # Pour Lifelink
var arrow_boost = 1.0         # Multiplicateur flèches (si tu veux l’utiliser plus tard)
var shield_factor = 1.0       # Réduction dégâts ennemis (si tu veux l’utiliser plus tard)
var bonus_damage = 0          # Dégâts bonus (si tu veux l’utiliser plus tard)

# ---------------------------------------------------------
#                REFERENCES AUX NOEUDS
# ---------------------------------------------------------

@onready var grid_container = $Container
@onready var inventory_panel = $InventoryPanel
@onready var choix_background = $ChoixPanel
@onready var tooltip_label = $TooltipLabel
@onready var tooltip_timer = $TooltipTimer
@onready var pouvoir1 = $Pouvoir1
@onready var pouvoir2 = $Pouvoir2
@onready var pouvoir3 = $Pouvoir3
@onready var pouvoir4 = $Pouvoir4

@onready var SpinButton = $SpinButton

@onready var SymbolScene = preload("res://scenes/symbols/Symbol.tscn")
@onready var symbols_data = preload("res://data/symbols.json")

# ---------------------------------------------------------
#                READY
# ---------------------------------------------------------

func _ready():
    # ---------------------------------------------------------
    # Chargement des pouvoirs depuis powers.json
    # ---------------------------------------------------------
	var file_p = FileAccess.open("res://data/powers.json", FileAccess.READ)
	if file_p:
		var content_p = file_p.get_as_text()
		var parsed_p = JSON.parse_string(content_p)
		if typeof(parsed_p) == TYPE_DICTIONARY:
			powers_data = parsed_p
		else:
			push_error("ERREUR : powers.json mal formé")
	else:
		push_error("ERREUR : impossible d'ouvrir powers.json")

    # ---------------------------------------------------------
    # 1. Initialisation du backpack
    # ---------------------------------------------------------
	backpack = []
	for i in range(15):
		backpack.append("empty")
	for i in range(5):
		backpack.append("sword")
	backpack.append("chest")
	for i in range(4):
		backpack.append("arrow")

    # ---------------------------------------------------------
    # 2. Connexions des boutons du sac
    # ---------------------------------------------------------
	$BackpackButton.pressed.connect(show_backpack)
	$BackpackPanel/CloseButton.pressed.connect(func():
		$BackpackPanel.visible = false
		$BackpackOverlay.visible = false
	)
	$BackpackPanel/Grid.add_theme_constant_override("h_separation", 70)
	$BackpackPanel/Grid.add_theme_constant_override("v_separation", 70)

    # ---------------------------------------------------------
    # 3. Initialisation du système de draft
    # ---------------------------------------------------------
	choix_background.visible = false
	choix_background.get_node("Bouton1").pressed.connect(
		_on_draft_button_pressed.bind(choix_background.get_node("Bouton1"))
	)
	choix_background.get_node("Bouton2").pressed.connect(
		_on_draft_button_pressed.bind(choix_background.get_node("Bouton2"))
	)
	choix_background.get_node("Bouton3").pressed.connect(
		_on_draft_button_pressed.bind(choix_background.get_node("Bouton3"))
	)

    # ---------------------------------------------------------
    # 4. Connexions des pouvoirs
    # ---------------------------------------------------------
	pouvoir1.pressed.connect(func(): on_power_pressed(1))
	pouvoir2.pressed.connect(func(): on_power_pressed(2))
	pouvoir3.pressed.connect(func(): on_power_pressed(3))
	pouvoir4.pressed.connect(func(): on_power_pressed(4))
	pouvoir1.mouse_entered.connect(func(): show_power_tooltip(1))
	pouvoir2.mouse_entered.connect(func(): show_power_tooltip(2))
	pouvoir3.mouse_entered.connect(func(): show_power_tooltip(3))
	pouvoir4.mouse_entered.connect(func(): show_power_tooltip(4))

	pouvoir1.mouse_exited.connect(hide_power_tooltip)
	pouvoir2.mouse_exited.connect(hide_power_tooltip)
	pouvoir3.mouse_exited.connect(hide_power_tooltip)
	pouvoir4.mouse_exited.connect(hide_power_tooltip)

    # ---------------------------------------------------------
    # 5. Chargement des ennemis
    # ---------------------------------------------------------
	var file = FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("ennemis"):
			ennemis_liste = parsed["ennemis"]
		else:
			push_error("ERREUR : enemies.json mal chargé")
			ennemis_liste = []
	else:
		push_error("ERREUR : impossible d'ouvrir enemies.json")
		ennemis_liste = []

    # ---------------------------------------------------------
    # 6. Création dynamique de la grille 5x5
    # ---------------------------------------------------------
	for i in range(25):
		var tex = TextureRect.new()
		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tex.custom_minimum_size = Vector2(50, 50)
		tex.mouse_filter = Control.MOUSE_FILTER_PASS

		tex.mouse_entered.connect(_on_grid_slot_mouse_entered.bind(i))
		tex.mouse_exited.connect(_on_grid_slot_mouse_exited.bind(i))

		grid_container.add_child(tex)
		texture_rects.append(tex)

    # ---------------------------------------------------------
    # 7. Initialisation des boutons de pouvoirs
    # ---------------------------------------------------------
	pouvoir_boutons = [pouvoir1, pouvoir2, pouvoir3, pouvoir4]

    # ---------------------------------------------------------
    # 8. Mise à jour initiale de l'UI combat + inventaire
    # ---------------------------------------------------------
	UpdateEnemy()
	UpdatePlayer()
	UpdateInventory()

# ---------------------------------------------------------
#                ENNEMI / JOUEUR
# ---------------------------------------------------------

func UpdateEnemy():
	if ennemis_liste.size() == 0:
		push_error("Aucun ennemi chargé")
		return

	var e = ennemis_liste[randi() % ennemis_liste.size()]
	enemy = e
	enemy_max_hp = e["hp"]

	var tex = null
	if e.has("sprite"):
		tex = load(e["sprite"])
	if tex:
		$CombatPanel/SpritesContainer/EnemySprite.texture = tex

	var hb = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hb.max_value = enemy_max_hp
	hb.value = enemy["hp"]

	$CombatPanel/SpritesContainer/EnemySprite/EnemyName.text = e["nom"]
	$CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel.text = str(enemy["hp"]) + "/" + str(enemy_max_hp)


func UpdatePlayer():
	var hb = $CombatPanel/SpritesContainer/PlayerSprite/PlayerHPBar
	hb.max_value = 100
	hb.value = player_hp
	hb.queue_redraw()
	var hl = $CombatPanel/SpritesContainer/PlayerSprite/PlayerHPLabel
	hl.text = str(player_hp) + "/100"

func create_tooltip_for(id):
	var data = Database.symbols[id]
	var name = data.get("name", id)
	var rarity = data.get("rarity", "common")
	var effects = data.get("effects", [])

	var text = name + "\n"
	text += "Rareté : " + rarity.capitalize() + "\n"

	if effects.size() > 0:
		text += "Effet : " + str(effects[0])

	return text

func get_backpack_counts():
	var counts = {}
	for id in backpack:
		if not counts.has(id):
			counts[id] = 1
		else:
			counts[id] += 1
	return counts

func show_backpack():
	var panel = $BackpackPanel
	var grid = panel.get_node("Grid")

	panel.visible = true
	$BackpackOverlay.visible = true
	panel.move_to_front()

    # Nettoyer la grille
	for c in grid.get_children():
		c.queue_free()

    # Récupérer les objets groupés
	var counts = get_backpack_counts()

    # Ne pas afficher les "empty"
	counts.erase("empty")

    # Trier les IDs par rareté
	var ids = counts.keys()
	ids = sort_ids_by_rarity(ids)

	for id in ids:
		var data = Database.symbols[id]

        # Conteneur pour un item
		var item_box = Control.new()
		item_box.custom_minimum_size = Vector2(72, 72)
		item_box.tooltip_text = create_tooltip_for(id)

        # Animation de survol
		item_box.mouse_entered.connect(func():
			item_box.scale = Vector2(1.1, 1.1)
		)
		item_box.mouse_exited.connect(func():
			item_box.scale = Vector2(1, 1)
		)

        # Image
		var tex = TextureRect.new()
		var s = SymbolScene.instantiate()
		s.setup(id)
		tex.texture = s.get_texture()
		s.queue_free()

		tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.stretch_mode = TextureRect.STRETCH_KEEP
		tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tex.size_flags_vertical = Control.SIZE_EXPAND_FILL

		item_box.add_child(tex)

        # Compteur (ex: ×5)
		var label = Label.new()
		label.text = "x" + str(counts[id])
		label.add_theme_color_override("font_color", Color(1,1,1))
		label.position = Vector2(40, 40)
		label.z_index = 10

		item_box.add_child(label)

		grid.add_child(item_box)

    # Mettre à jour le total (sans les empty)
	var total_real_items = backpack.size() - backpack.count("empty")
	$BackpackPanel/TotalLabel.text = "Total : " + str(total_real_items)

func UpdateInventory():
	for i in range(3):
		var b = inventory_panel.get_node("PassifButton" + str(i + 1))
		if not b:
			continue

		if i < passifs_actifs.size():
			var id = passifs_actifs[i]
			if not symbols_data.has(id):
				b.visible = false
				continue

			var d = symbols_data[id]
			b.visible = true
			b.get_node("NomLabel").text = d.get("name", str(id))

			var eff = d.get("effects", [])
			b.get_node("EffetLabel").text = str(eff[0]) if eff.size() > 0 else ""

			var s = SymbolScene.instantiate()
			s.setup(id)
			b.get_node("ImageTextureRect").texture = s.get_texture()
			s.queue_free()
		else:
			b.visible = false


func add_to_backpack(id):
    # Cherche un "empty"
	var empty_index = backpack.find("empty")

    # S'il y en a un → on le remplace
	if empty_index != -1:
		backpack[empty_index] = id
	else:
        # Sinon on ajoute normalement
		backpack.append(id)


	UpdateInventory()

# ---------------------------------------------------------
#                SPIN
# ---------------------------------------------------------

func _on_spin_button_pressed():
	print("BACKPACK =", backpack)
	if choix_en_cours:
		return

	apply_pending_enemy_damage_to_player()

	SpinButton.disabled = true

	if backpack.size() == 0:
		# sécurité : si backpack vide, on met un symbole par défaut
		backpack = ["sword", "arrow", "key", "chest", "blade_dance"]

	items.clear()
	var temp = backpack.duplicate()

	for i in range(25):
		var idx = randi() % temp.size()
		items.append(temp[idx])
		temp.remove_at(idx)

	await spin_reels_column_by_column()

	resolve_key_chest_combos()

	SpinButton.disabled = false
	spin_count += 1

	check_pouvoir_cooldown()

	$CombatPanel/SpritesContainer/PlayerSprite.play("attack")
	$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_player_attack_finished, CONNECT_ONE_SHOT)
func sort_ids_by_rarity(ids):
	var rarity_order = {
		"legendary": 0,
		"epic": 1,
		"rare": 2,
		"uncommon": 3,
		"common": 4,
		"none": 5
	}

	ids.sort_custom(func(a, b):
		var ra = Database.symbols[a].get("rarity", "common")
		var rb = Database.symbols[b].get("rarity", "common")
		return rarity_order[ra] < rarity_order[rb]
	)

	return ids


func spin_reels_column_by_column():
	var cols = 5
	var rows = 5
	var total = 1.5
	var interval = total / float(cols)
	var elapsed = 0.0

	while elapsed < total:
		for c in range(cols):
			var stop = c * interval
			var end = stop + interval

			if elapsed < end:
				for r in range(rows):
					var i = c + r * cols
					if i < texture_rects.size():
						var id = backpack[randi() % backpack.size()]
						var s = SymbolScene.instantiate()
						s.setup(id)
						texture_rects[i].texture = s.get_texture()
						s.queue_free()
			else:
				for r in range(rows):
					var i = c + r * cols
					if i < items.size():
						var id = items[i]
						var s = SymbolScene.instantiate()
						s.setup(id)
						texture_rects[i].texture = s.get_texture()
						s.queue_free()

		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	for i in range(min(texture_rects.size(), items.size())):
		var s = SymbolScene.instantiate()
		s.setup(items[i])
		texture_rects[i].texture = s.get_texture()
		s.queue_free()

func _on_player_attack_finished():
	var t = get_tree().create_timer(1.0)
	t.timeout.connect(func(): ApplyDamage(items, texture_rects))

# ---------------------------------------------------------
#                DEGATS
# ---------------------------------------------------------

func ApplyDamage(local_items, local_tex):
	if spin_count == 0:
		return

	var deg = 0
	var heal = 0

	var center = 12
	var e_c = 0
	var e_o = 0
	var f = 0
	var bd = 0

	# --- Marquage flèches boostées ---
	for i in range(local_items.size()):
		var id = local_items[i]

		if not Database.symbols.has(id):
			continue

		var d = Database.symbols[id]

		if d.has("effects") and d["effects"].has("triple_adjacent_arrows"):
			for j in get_adjacent_indices(i):
				if j < local_items.size() and local_items[j] == "arrow":
					local_tex[j].modulate = Color(1, 0.5, 0.5, 1)
					var t = get_tree().create_timer(2.0)
					t.timeout.connect(func(): local_tex[j].modulate = Color(1, 1, 1, 1))

	# --- Calcul dégâts / heal ---
	for i in range(local_items.size()):
		var id = local_items[i]

		if not Database.symbols.has(id):
			continue

		var d = Database.symbols[id]

		if not d.has("type"):
			continue

		var t = d["type"]

		if t == "attack":
			if id == "sword":
				if i == center:
					e_c += 1
				else:
					e_o += 1

			elif id == "arrow":
				var v = d.get("value", 1)
				if local_tex[i].modulate == Color(1, 0.5, 0.5, 1):
					f += v * 3
				else:
					f += v

			elif id == "blade_dance":
				var adj = get_adjacent_indices(i)
				var c = 0
				for j in adj:
					if j < local_items.size() and local_items[j] == "sword":
						c += 1
				bd += c

		elif t == "heal":
			var hv = d.get("value", 0)
			heal += hv

	# --- Total dégâts ---
	var e_d = e_o * 5 + e_c * 50
	deg = e_d + f + bd
	last_damage_dealt = deg

	# --- Mise à jour HP ennemi ---
	var rest = enemy["hp"] - deg
	if rest < 0:
		rest = 0

	enemy["hp"] = rest

	# --- Affichage dégâts ---
	var dl = $CombatPanel/SpritesContainer/DamageLabel
	if dl:
		dl.text = str(deg)
		dl.visible = true
		dl.position = Vector2(0, -50)

	# --- Barre de vie ennemi ---
	var hb = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hb.max_value = enemy_max_hp
	hb.value = rest
	hb.queue_redraw()

	var hl = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hl.text = str(rest) + "/" + str(enemy_max_hp)

	# --- Highlight épée centrale ---
	if e_c > 0:
		local_tex[center].modulate = Color(1, 1, 0.5, 1)
		var t2 = get_tree().create_timer(0.5)
		t2.timeout.connect(func(): local_tex[center].modulate = Color(1, 1, 1, 1))

	# --- Heal joueur ---
	player_hp += heal
	if player_hp > 100:
		player_hp = 100

	UpdatePlayer()

	# --- Ennemi mort ? ---
	if rest == 0:
		ennemis_vaincus += 1
		start_draft()
		return

	# Sinon, l’ennemi attaque normalement
	roll_enemy_damage()


func apply_fireball(amount):
	enemy["hp"] = max(enemy["hp"] - amount, 0)
	UpdateEnemy()

func apply_heal(amount):
	player_hp = min(player_hp + amount, 100)
	UpdatePlayer()

func apply_lifelink():
	player_hp = min(player_hp + last_damage_dealt, 100)
	UpdatePlayer()

# ---------------------------------------------------------
#                ADJACENCE + KEY/chest
# ---------------------------------------------------------
func on_power_pressed(index):
	if not pouvoir_disponible[index - 1]:
		return

	var power_id = "power" + str(index)
	var data = powers_data[power_id]

	match data["effect"]:
		"fireball":
			apply_fireball(data["value"])

		"heal":
			apply_heal(data["value"])

		"lifelink":
			apply_lifelink()

		"none":
			print("Pouvoir sans effet")

    # Désactiver le pouvoir
	pouvoir_disponible[index - 1] = false
	pouvoir_boutons[index - 1].disabled = true
	pouvoir_boutons[index - 1].modulate = Color(0.5, 0.5, 0.5, 1)

    # Reset du compteur pour le cooldown
	spin_compteur_pouvoir[index - 1] = 0


func show_power_tooltip(index):
	var power_id = "power" + str(index)
	var data = powers_data[power_id]

	var name = data["name"]
	var effect = data["effect"]
	var cooldown = data["cooldown"]

	var text = name + "\n"

	match effect:
		"fireball":
			text += "Inflige " + str(data["value"]) + " dégâts.\n"

		"heal":
			text += "Soigne " + str(data["value"]) + " PV.\n"

		"lifelink":
			text += "Soigne du montant des dégâts infligés au dernier tour.\n"
			text += "Actuellement : +" + str(last_damage_dealt) + " PV\n"

		"none":
			text += "Aucun effet.\n"

	text += "Recharge : " + str(cooldown) + " tours"

	tooltip_label.text = text
	tooltip_label.visible = true
	tooltip_label.global_position = get_viewport().get_mouse_position() + Vector2(16, 16)

func hide_power_tooltip():
	tooltip_label.visible = false

func apply_bonus_damage(amount):
    # On stocke un bonus qui sera appliqué au prochain spin
	pending_enemy_damage += amount

func apply_arrow_boost(multiplier):
    # On active un flag pour le prochain spin
	arrow_boost = multiplier

func apply_shield(factor):
    # Réduction des dégâts ennemis
	shield_factor = factor


func get_adjacent_indices(i):
	var r = []
	var x = i % 5
	var y = i / 5

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				var nx = x + dx
				var ny = y + dy
				if nx >= 0 and nx < 5 and ny >= 0 and ny < 5:
					r.append(nx + ny * 5)
	return r

func resolve_key_chest_combos():
	var pairs = []
	for i in range(items.size()):
		if items[i] == "key":
			for j in get_adjacent_indices(i):
				if j < items.size() and items[j] == "chest":
					pairs.append([i, j])
	for p in pairs:
		var c = p[1]
		items[c] = "chest_ouvert"

# ---------------------------------------------------------
#                TOOLTIP GRILLE
# ---------------------------------------------------------

func _on_grid_slot_mouse_entered(i):
	if i < 0 or i >= items.size():
		return
	hovered_slot_index = i
	if tooltip_timer:
		tooltip_timer.start()

func _on_grid_slot_mouse_exited(i):
	if hovered_slot_index == i:
		hovered_slot_index = -1
		if tooltip_timer:
			tooltip_timer.stop()
		if tooltip_label:
			tooltip_label.visible = false

func _on_TooltipTimer_timeout():
	if hovered_slot_index < 0 or hovered_slot_index >= items.size():
		return
	var id = items[hovered_slot_index]
	if not symbols_data.has(id):
		return
	var d = symbols_data[id]
	if tooltip_label:
		tooltip_label.text = d.get("name", str(id))
		tooltip_label.visible = true
		tooltip_label.global_position = get_viewport().get_mouse_position() + Vector2(16, 16)

# ---------------------------------------------------------
#                POUVOIRS / COOLDOWN
# ---------------------------------------------------------

func check_pouvoir_cooldown():
	for i in range(pouvoir_boutons.size()):
		spin_compteur_pouvoir[i] += 1
		if not pouvoir_disponible[i] and spin_compteur_pouvoir[i] >= cooldown_pouvoir[i]:
			pouvoir_disponible[i] = true
			if pouvoir_boutons[i] and not choix_en_cours:
				pouvoir_boutons[i].disabled = false
				pouvoir_boutons[i].modulate = Color(1, 1, 0, 1)

# ---------------------------------------------------------
#                DEGATS ENNEMIS
# ---------------------------------------------------------

func roll_enemy_damage():
	if enemy.has("attack"):
		pending_enemy_damage = enemy["attack"]
	else:
		pending_enemy_damage = 0

	var dl = $CombatPanel/SpritesContainer/EnemySprite/EnemyDamageLabel
	if dl:
		dl.text = str(pending_enemy_damage)

func apply_pending_enemy_damage_to_player():
	if pending_enemy_damage <= 0:
		return

	player_hp -= pending_enemy_damage
	if player_hp < 0:
		player_hp = 0

	UpdatePlayer()
	pending_enemy_damage = 0

# ---------------------------------------------------------
#                INVENTAIRE UI
# ---------------------------------------------------------

func _on_backpack_button_pressed():
	$InventoryPanel.visible = !$InventoryPanel.visible
	if $InventoryPanel.visible:
		$InventoryPanel.move_to_front()
	UpdateInventory()

func _on_close_button_pressed():
	$InventoryPanel.visible = false
func start_draft():
	choix_en_cours = true
	choix_background.visible = true
	choix_background.move_to_front()

	draft_choices.clear()

	# 1. Déterminer la rareté du draft
	var rarity = pick_rarity()
	print("Draft rarity =", rarity)

	# 2. Récupérer tous les symboles de cette rareté
	var pool = get_symbols_by_rarity(rarity)

	if pool.size() == 0:
		push_error("Aucun symbole trouvé pour la rareté : " + rarity)
		return

	# 3. Tirer 3 objets différents
	draft_choices = pick_three_unique(pool)

	# 4. Remplir les 3 boutons
	for i in range(draft_choices.size()):
		var id = draft_choices[i]
		var data = Database.symbols[id]

		var bouton = choix_background.get_node("Bouton" + str(i+1))
		bouton.set_meta("id", id)

		# Nom
		bouton.get_node("NomLabel").text = data.get("name", id)

		# Effet
		var eff = data.get("effects", [])
		bouton.get_node("EffetLabel").text = str(eff[0]) if eff.size() > 0 else ""

		# Image
		var s = SymbolScene.instantiate()
		s.setup(id)
		bouton.get_node("ImageTextureRect").texture = s.get_texture()
		s.queue_free()

		# Couleur selon rareté de l’item
		var item_rarity = data.get("rarity", "common")
		bouton.modulate = get_rarity_color(item_rarity)

		bouton.disabled = false
		bouton.visible = true

func get_symbols_by_rarity(rarity):
	var list = []
	for id in Database.symbols.keys():
		var data = Database.symbols[id]
		if data.get("rarity", "common") == rarity:
			list.append(id)
	return list

func get_rarity_color(rarity):
	match rarity:
		"common":
			return Color(1, 1, 1, 1) # blanc / normal
		"uncommon":
			return Color(0.2, 1, 0.2, 1) # vert
		"rare":
			return Color(0.2, 0.4, 1, 1) # bleu
		"epic":
			return Color(0.6, 0.2, 1, 1) # violet
		"legendary":
			return Color(1, 0.5, 0.1, 1) # orange/rouge
		_:
			return Color(1, 1, 1, 1)

func pick_three_unique(list):
	list.shuffle()
	return list.slice(0, min(3, list.size()))

	# Récupérer tous les IDs d'objets depuis Database
var all_ids = Database.symbols.keys()
func pick_rarity():
	var r = randf() * 100.0

	if r < 1.0:
		return "legendary"
	elif r < 1.0 + 5.0:
		return "epic"
	elif r < 1.0 + 5.0 + 15.0:
		return "rare"
	elif r < 1.0 + 5.0 + 15.0 + 30.0:
		return "uncommon"
	else:
		return "common"

	# Tirer 3 objets aléatoires
	for i in range(3):
		draft_choices.append(all_ids[randi() % all_ids.size()])

	# Remplir les 3 boutons
	for i in range(3):
		var id = draft_choices[i]
		var data = Database.symbols[id]

		var bouton = choix_background.get_node("Bouton" + str(i+1))
		bouton.set_meta("id", id)

		bouton.get_node("NomLabel").text = data.get("name", id)

		var eff = data.get("effects", [])
		bouton.get_node("EffetLabel").text = str(eff[0]) if eff.size() > 0 else ""

		var s = SymbolScene.instantiate()
		s.setup(id)
		bouton.get_node("ImageTextureRect").texture = s.get_texture()
		s.queue_free()

		bouton.disabled = false
		bouton.visible = true

func _on_draft_button_pressed(button):
	var id = button.get_meta("id")
	if id == null:
		return

	# Ajouter au backpack
	add_to_backpack(id)


	# Fermer le panel
	choix_background.visible = false
	choix_en_cours = false

	UpdateInventory()

	# Charger un nouvel ennemi
	UpdateEnemy()
