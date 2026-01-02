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
    # Masquer les choix au démarrage
    choix_en_cours = false
    $ChoixPanel.visible = false
    choix_background.visible = false

    # Charger les ennemis depuis enemies.json
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

    # Créer la grille 5x5
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

    pouvoir_boutons = [pouvoir1, pouvoir2, pouvoir3, pouvoir4]

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

# ---------------------------------------------------------
#                SPIN
# ---------------------------------------------------------

func _on_spin_button_pressed():
    if choix_en_cours:
        return

    apply_pending_enemy_damage_to_player()

    SpinButton.disabled = true

    if backpack.size() == 0:
        # sécurité : si backpack vide, on met un symbole par défaut
        backpack = ["sword", "arrow", "key", "coffre", "blade_dance"]

    items.clear()
    var temp = backpack.duplicate()

    for i in range(25):
        var idx = randi() % temp.size()
        items.append(temp[idx])
        temp.remove_at(idx)

    await spin_reels_column_by_column()

    resolve_key_coffre_combos()

    SpinButton.disabled = false
    spin_count += 1

    check_pouvoir_cooldown()

    $CombatPanel/SpritesContainer/PlayerSprite.play("attack")
    $CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_player_attack_finished, CONNECT_ONE_SHOT)

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

    # Marquage flèches boostées
    for i in range(local_items.size()):
        var id = local_items[i]
        if not symbols_data.has(id):
            continue

        var d = symbols_data[id]
        if d.has("effects") and d["effects"].has("triple_adjacent_arrows"):
            for j in get_adjacent_indices(i):
                if j < local_items.size() and local_items[j] == "arrow":
                    local_tex[j].modulate = Color(1, 0.5, 0.5, 1)
                    var t = get_tree().create_timer(2.0)
                    t.timeout.connect(func(): local_tex[j].modulate = Color(1, 1, 1, 1))

    # Calcul dégâts / heal
    for i in range(local_items.size()):
        var id = local_items[i]
        if not symbols_data.has(id):
            continue

        var d = symbols_data[id]
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

    var e_d = e_o * 5 + e_c * 50
    deg = e_d + f + bd

    var rest = enemy["hp"] - deg
    if rest < 0:
        rest = 0

    var dl = $CombatPanel/SpritesContainer/DamageLabel
    if dl:
        dl.text = str(deg)
        dl.visible = true
        dl.position = Vector2(0, -50)

    enemy["hp"] = rest

    var hb = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
    hb.max_value = enemy_max_hp
    hb.value = rest
    hb.queue_redraw()

    var hl = $CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
    hl.text = str(rest) + "/" + str(enemy_max_hp)

    if e_c > 0:
        local_tex[center].modulate = Color(1, 1, 0.5, 1)
        var t2 = get_tree().create_timer(0.5)
        t2.timeout.connect(func(): local_tex[center].modulate = Color(1, 1, 1, 1))

    player_hp += heal
    if player_hp > 100:
        player_hp = 100

    UpdatePlayer()

    if rest == 0:
        ennemis_vaincus += 1
        # Pour l'instant : nouvel ennemi simple, sans choix complexe
        UpdateEnemy()
        roll_enemy_damage()
    else:
        roll_enemy_damage()

# ---------------------------------------------------------
#                ADJACENCE + KEY/COFFRE
# ---------------------------------------------------------

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

func resolve_key_coffre_combos():
    var pairs = []
    for i in range(items.size()):
        if items[i] == "key":
            for j in get_adjacent_indices(i):
                if j < items.size() and items[j] == "coffre":
                    pairs.append([i, j])
    for p in pairs:
        var c = p[1]
        items[c] = "coffre_ouvert"

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
