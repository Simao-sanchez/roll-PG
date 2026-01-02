extends Node2D
@onready var grid_container=$Container
@onready var inventory_panel=$InventoryPanel
var SymbolScene=preload("res://scenes/symbols/Symbol.tscn")
var symbols_data={}
var backpack=[]
var spin_duration=2.0
var spin_speed=0.05
var player_hp=100
var ennemis_vaincus=0
var dernier_ennemi=""
var enemy={}
var enemy_max_hp=0
var enemy_damage_values=[0,5,10,13]
var pending_enemy_damage=0
var ennemis_liste=[
{"nom":"Hobbit","hp":50,"texture":preload("res://assets/enemies/Sprites_ennemy/slime.png")},
{"nom":"Vampire","hp":70,"texture":preload("res://assets/enemies/Sprites_ennemy/golem.png")},
{"nom":"Bête","hp":100,"texture":preload("res://assets/enemies/Sprites_ennemy/dragon.png")},
{"nom":"Tréant","hp":65,"texture":preload("res://assets/enemies/Sprites_ennemy/slime.png")},
{"nom":"Poulet","hp":55,"texture":preload("res://assets/enemies/Sprites_ennemy/golem.png")},
{"nom":"Ondin","hp":85,"texture":preload("res://assets/enemies/Sprites_ennemy/dragon.png")}
]
var textures_ennemies=[
preload("res://assets/enemies/Sprites_ennemy/slime.png"),
preload("res://assets/enemies/Sprites_ennemy/golem.png"),
preload("res://assets/enemies/Sprites_ennemy/dragon.png")
]
var choix_en_cours=false
var choix_background
var passifs_actifs=[]
var items=[]
var texture_rects=[]
var spin_count=0
var cooldown_pouvoir=[5,6,7,8]
var pouvoir_disponible=[false,false,false,false]
var pouvoir_boutons=[]
var spin_compteur_pouvoir=[0,0,0,0]
var tooltip_label
var tooltip_timer
var hovered_slot_index=-1
var tooltip_delay=1.0

func load_symbols_json():
	var f=FileAccess.open("res://data/symbols.json",FileAccess.READ)
	if f:
		var t=f.get_as_text()
		symbols_data=JSON.parse_string(t)
		if typeof(symbols_data)!=TYPE_DICTIONARY:
			symbols_data={}
	else:
		symbols_data={}

func _ready():
	randomize()
	load_symbols_json()
	backpack.clear()
	for i in range(13):backpack.append("sword")
	for i in range(12):backpack.append("shield")
	for i in range(5):backpack.append("arrow")
	for i in range(2):
		backpack.append("key")
		backpack.append("chest")
	pouvoir_boutons=[$Pouvoir1,$Pouvoir2,$Pouvoir3,$Pouvoir4]
	$SpinButton.pressed.connect(_on_spin_button_pressed)
	$BackpackButton.pressed.connect(_on_backpack_button_pressed)
	$InventoryPanel/CloseButton.pressed.connect(_on_close_button_pressed)
	$InventoryPanel.visible=false
	$ChoixPanel.visible=false
	$ChoixPanel/Bouton1.pressed.connect(_on_bouton1_pressed)
	$ChoixPanel/Bouton2.pressed.connect(_on_bouton2_pressed)
	$ChoixPanel/Bouton3.pressed.connect(_on_bouton3_pressed)
	$Pouvoir1.pressed.connect(_on_pouvoir1_pressed)
	$Pouvoir2.pressed.connect(_on_pouvoir2_pressed)
	$Pouvoir3.pressed.connect(_on_pouvoir3_pressed)
	$Pouvoir4.pressed.connect(_on_pouvoir4_pressed)
	choix_background=ColorRect.new()
	choix_background.color=Color(0,0,0,0.8)
	choix_background.mouse_filter=Control.MOUSE_FILTER_STOP
	choix_background.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choix_background.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(choix_background)
	choix_background.visible=false
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()
	tooltip_label=Label.new()
	tooltip_label.visible=false
	tooltip_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.size=Vector2(220,60)
	tooltip_label.custom_minimum_size=Vector2(220,60)
	var sb=StyleBoxFlat.new()
	sb.bg_color=Color(0,0,0,0.9)
	sb.border_width_left=2
	sb.border_width_top=2
	sb.border_width_right=2
	sb.border_width_bottom=2
	sb.border_color=Color(1,1,0,1)
	sb.corner_radius_top_left=8
	sb.corner_radius_top_right=8
	sb.corner_radius_bottom_right=8
	sb.corner_radius_bottom_left=8
	tooltip_label.add_theme_stylebox_override("normal",sb)
	tooltip_label.z_index=100
	add_child(tooltip_label)
	tooltip_label.move_to_front()
	tooltip_timer=Timer.new()
	tooltip_timer.one_shot=true
	tooltip_timer.wait_time=tooltip_delay
	add_child(tooltip_timer)
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	if grid_container:
		grid_container.set_columns(5)
		for i in range(25):
			var tex=TextureRect.new()
			tex.expand_mode=TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex.stretch_mode=TextureRect.STRETCH_KEEP
			tex.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			tex.size_flags_vertical=Control.SIZE_EXPAND_FILL
			tex.custom_minimum_size=Vector2(50,50)
			tex.mouse_filter=Control.MOUSE_FILTER_PASS
			tex.mouse_entered.connect(_on_grid_slot_mouse_entered.bind(i))
			tex.mouse_exited.connect(_on_grid_slot_mouse_exited.bind(i))
			grid_container.add_child(tex)
	if $CombatPanel/SpritesContainer/PlayerSprite:
		$CombatPanel/SpritesContainer/PlayerSprite.play("idle")
		$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_animation_finished)
	UpdateEnemy()
	UpdatePlayer()
	roll_enemy_damage()
	for i in range(pouvoir_boutons.size()):
		if pouvoir_boutons[i]:
			pouvoir_boutons[i].disabled=true
			pouvoir_boutons[i].modulate = Color(0.5, 0.5, 0.5, 1)

func _on_spin_button_pressed():
	if choix_en_cours:return
	apply_pending_enemy_damage_to_player()
	$SpinButton.disabled=true
	items.clear()
	var temp=backpack.duplicate()
	for i in range(25):
		var idx=randi()%temp.size()
		items.append(temp[idx])
		temp.remove_at(idx)
	texture_rects=grid_container.get_children()
	await spin_reels_column_by_column()
	resolve_key_coffre_combos()
	$SpinButton.disabled=false
	spin_count+=1
	check_pouvoir_cooldown()
	if $CombatPanel/SpritesContainer/PlayerSprite:
		$CombatPanel/SpritesContainer/PlayerSprite.play("attack")
		$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.connect(_on_player_attack_finished,CONNECT_ONE_SHOT)

func spin_reels_column_by_column():
	var cols=5
	var rows=5
	var total=spin_duration
	var interval=total/float(cols)
	var elapsed=0.0
	while elapsed<total:
		for c in range(cols):
			var stop=c*interval
			var end=stop+interval
			if elapsed<end:
				for r in range(rows):
					var i=c+r*cols
					if i<texture_rects.size():
						var id=backpack[randi()%backpack.size()]
						var s=SymbolScene.instantiate()
						s.setup(id)
						texture_rects[i].texture=s.get_texture()
						s.queue_free()
			else:
				for r in range(rows):
					var i=c+r*cols
					if i<items.size():
						var id=items[i]
						var s=SymbolScene.instantiate()
						s.setup(id)
						texture_rects[i].texture=s.get_texture()
						s.queue_free()
		await get_tree().create_timer(spin_speed).timeout
		elapsed+=spin_speed
	for i in range(min(texture_rects.size(),items.size())):
		var s=SymbolScene.instantiate()
		s.setup(items[i])
		texture_rects[i].texture=s.get_texture()
		s.queue_free()

func update_slot_texture(i):
	if i<0 or i>=items.size():return
	var id=items[i]
	var s=SymbolScene.instantiate()
	s.setup(id)
	texture_rects[i].texture=s.get_texture()
	s.queue_free()

func _on_player_attack_finished():
	if $CombatPanel/SpritesContainer/PlayerSprite and $CombatPanel/SpritesContainer/PlayerSprite.has_signal("animation_finished"):
		if $CombatPanel/SpritesContainer/PlayerSprite.is_connected("animation_finished",Callable(self,"_on_player_attack_finished")):
			$CombatPanel/SpritesContainer/PlayerSprite.animation_finished.disconnect(Callable(self,"_on_player_attack_finished"))
	var t=get_tree().create_timer(1.0)
	t.timeout.connect(func():ApplyDamage(items,texture_rects))

func ApplyDamage(local_items,local_tex):
	var deg=0
	var heal=0
	var center=12
	var e_c=0
	var e_o=0
	var f=0
	var bd=0
	for i in range(local_items.size()):
		var id=local_items[i]
		if not symbols_data.has(id):continue
		var d=symbols_data[id]
		if d.has("effects") and d["effects"].has("triple_adjacent_arrows"):
			for j in get_adjacent_indices(i):
				if j<local_items.size() and local_items[j]=="arrow":
					local_tex[j].modulate=Color(1,0.5,0.5,1)
					var t=get_tree().create_timer(2.0)
					t.timeout.connect(func():local_tex[j].modulate=Color(1,1,1,1))
	for i in range(local_items.size()):
		var id=local_items[i]
		if not symbols_data.has(id):continue
		var d=symbols_data[id]
		if not d.has("type"):continue
		var t=d["type"]
		if t=="attack":
			if id=="sword":
				if i==center:e_c+=1
				else:e_o+=1
			elif id=="arrow":
				var v=d["value"] if d.has("value") else 1
				if local_tex[i].modulate==Color(1,0.5,0.5,1):f+=v*3
				else:f+=v
			elif id=="blade_dance":
				var adj=get_adjacent_indices(i)
				var c=0
				for j in adj:
					if j<local_items.size() and local_items[j]=="sword":c+=1
				bd+=c
		elif t=="heal":
			var hv=d["value"] if d.has("value") else 0
			heal+=hv
	var e_d=e_o*5+e_c*50
	deg=e_d+f+bd
	var rest=enemy["hp"]-deg
	if rest<0:rest=0
	var dl=$CombatPanel/SpritesContainer/PlayerSprite/DamageLabel
	if dl:
		dl.text=str(deg)
		dl.visible=true
		dl.position=Vector2(0,-50)
	enemy["hp"]=rest
	var hb=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hb.max_value=enemy_max_hp
	hb.value=rest
	hb.queue_redraw()
	var hl=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hl.text=str(rest)+"/"+str(enemy_max_hp)
	if e_c>0:
		local_tex[center].modulate=Color(1,1,0.5,1)
		var t2=get_tree().create_timer(0.5)
		t2.timeout.connect(func():local_tex[center].modulate=Color(1,1,1,1))
	player_hp+=heal
	if player_hp>100:player_hp=100
	UpdatePlayer()
	if rest==0:
		ennemis_vaincus+=1
		if ennemis_vaincus%2==0:AfficherChoixPassif()
		else:
			UpdateEnemy()
			AfficherChoixObjet()
	roll_enemy_damage()

func get_adjacent_indices(i):
	var r=[]
	var x=i%5
	var y=i/5
	for dx in range(-1,2):
		for dy in range(-1,2):
			if dx!=0 or dy!=0:
				var nx=x+dx
				var ny=y+dy
				if nx>=0 and nx<5 and ny>=0 and ny<5:
					r.append(nx+ny*5)
	return r

func resolve_key_coffre_combos():
	var pairs=[]
	for i in range(items.size()):
		if items[i]=="key":
			for j in get_adjacent_indices(i):
				if j<items.size() and items[j]=="chest":
					pairs.append([i,j])
	for p in pairs:
		var a=p[0]
		var b=p[1]
		backpack.erase("key")
		backpack.erase("chest")
		backpack.append("green_gem")
		items[a]="green_gem"
		items[b]="green_gem"
	for k in range(items.size()):
		update_slot_texture(k)
func AfficherChoixObjet():
	choix_en_cours=true
	desactiver_boutons_jeu()
	choix_background.visible=true
	$ChoixPanel.visible=true
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()
	var all=get_all_items_from_json()
	var c=[]
	while c.size()<3:
		var id=all[randi()%all.size()]
		if not c.has(id):c.append(id)
	for i in range(3):
		var id=c[i]
		var d=symbols_data[id]
		var b=$ChoixPanel.get_node("Bouton"+str(i+1))
		b.get_node("NomLabel").text=d["name"]
		var eff=d["effects"] if d.has("effects") else []
		b.get_node("EffetLabel").text=str(eff[0]) if eff.size()>0 else ""
		var s=SymbolScene.instantiate()
		s.setup(id)
		b.get_node("ImageTextureRect").texture=s.get_texture()
		s.queue_free()

func AfficherChoixPassif():
	choix_en_cours=true
	desactiver_boutons_jeu()
	choix_background.visible=true
	$ChoixPanel.visible=true
	choix_background.move_to_front()
	$ChoixPanel.move_to_front()
	var all=get_all_passives_from_json()
	var c=[]
	while c.size()<3:
		var id=all[randi()%all.size()]
		if not c.has(id):c.append(id)
	for i in range(3):
		var id=c[i]
		var d=symbols_data[id]
		var b=$ChoixPanel.get_node("Bouton"+str(i+1))
		b.get_node("NomLabel").text=d["name"]
		var eff=d["effects"] if d.has("effects") else []
		b.get_node("EffetLabel").text=str(eff[0]) if eff.size()>0 else ""
		var s=SymbolScene.instantiate()
		s.setup(id)
		b.get_node("ImageTextureRect").texture=s.get_texture()
		s.queue_free()

func get_all_items_from_json():
	var r=[]
	for id in symbols_data.keys():
		var d=symbols_data[id]
		if d.has("type") and d["type"]!="passive":r.append(id)
	return r

func get_all_passives_from_json():
	var r=[]
	for id in symbols_data.keys():
		var d=symbols_data[id]
		if d.has("type") and d["type"]=="passive":r.append(id)
	return r

func desactiver_boutons_jeu():
	$SpinButton.disabled=true
	for b in pouvoir_boutons:
		if b:b.disabled=true

func reactiver_boutons_jeu():
	$SpinButton.disabled=false
	for i in range(pouvoir_boutons.size()):
		if pouvoir_boutons[i] and pouvoir_disponible[i]:
			pouvoir_boutons[i].disabled=false
	choix_en_cours=false

func _on_bouton1_pressed():_choisir_option(1)
func _on_bouton2_pressed():_choisir_option(2)
func _on_bouton3_pressed():_choisir_option(3)

func _choisir_option(n):
	$ChoixPanel.visible=false
	choix_background.visible=false
	var nom=$ChoixPanel.get_node("Bouton"+str(n)+"/NomLabel").text
	var id=""
	for k in symbols_data.keys():
		var d=symbols_data[k]
		if d.has("name") and d["name"]==nom:id=k
	if id=="":
		reactiver_boutons_jeu()
		return
	var d=symbols_data[id]
	if not d.has("type") or d["type"]!="passive":
		backpack.append(id)
		reactiver_boutons_jeu()
		return
	passifs_actifs.append(id)
	UpdateInventory()
	reactiver_boutons_jeu()

func UpdateEnemy():
	var c=[]
	for e in ennemis_liste:
		if e["nom"]!=dernier_ennemi:c.append(e)
	if c.size()==0:c=ennemis_liste.duplicate()
	var i=randi()%c.size()
	enemy=c[i]
	dernier_ennemi=enemy["nom"]
	var ti=randi()%textures_ennemies.size()
	enemy["texture"]=textures_ennemies[ti]
	enemy_max_hp=enemy["hp"]
	var hb=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hb.max_value=enemy_max_hp
	hb.value=enemy["hp"]
	hb.queue_redraw()
	$CombatPanel/SpritesContainer/EnemySprite/EnemyName.text=enemy["nom"]
	$CombatPanel/SpritesContainer/EnemySprite.texture=enemy["texture"]
	var hl=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hl.text=str(enemy["hp"])+"/"+str(enemy_max_hp)

func UpdatePlayer():
	var hb=$CombatPanel/SpritesContainer/PlayerSprite/PlayerHPBar
	hb.max_value=100
	hb.value=player_hp
	hb.queue_redraw()
	var hl=$CombatPanel/SpritesContainer/PlayerSprite/PlayerHPLabel
	hl.text=str(player_hp)+"/100"

func UpdateInventory():
	for i in range(3):
		var b=inventory_panel.get_node("PassifButton"+str(i+1))
		if b:
			if i<passifs_actifs.size():
				var id=passifs_actifs[i]
				if not symbols_data.has(id):
					b.visible=false
					continue
				var d=symbols_data[id]
				b.visible=true
				b.get_node("NomLabel").text=d["name"]
				var eff=d["effects"] if d.has("effects") else []
				b.get_node("EffetLabel").text=str(eff[0]) if eff.size()>0 else ""
				var s=SymbolScene.instantiate()
				s.setup(id)
				b.get_node("ImageTextureRect").texture=s.get_texture()
				s.queue_free()
			else:b.visible=false

func _on_backpack_button_pressed():
	$InventoryPanel.visible=!$InventoryPanel.visible
	if $InventoryPanel.visible:$InventoryPanel.move_to_front()
	UpdateInventory()

func _on_close_button_pressed():
	$InventoryPanel.visible=false

func _on_animation_finished():
	if $CombatPanel/SpritesContainer/PlayerSprite.animation=="attack":
		$CombatPanel/SpritesContainer/PlayerSprite.play("idle")

func roll_enemy_damage():
	if enemy_damage_values.size()==0:return
	pending_enemy_damage=enemy_damage_values.pick_random()
	var dl=$CombatPanel/SpritesContainer/EnemySprite/EnemyDamageLabel
	if dl:dl.text=str(pending_enemy_damage)

func apply_pending_enemy_damage_to_player():
	if pending_enemy_damage<=0:return
	player_hp-=pending_enemy_damage
	if player_hp<0:player_hp=0
	var hb=$CombatPanel/SpritesContainer/PlayerSprite/PlayerHPBar
	hb.max_value=100
	var tw=get_tree().create_tween()
	tw.tween_property(hb,"value",player_hp,0.5)
	tw.tween_callback(func():UpdatePlayer())
	if player_hp<=0:get_tree().reload_current_scene()

func _on_pouvoir1_pressed():
	if choix_en_cours or not pouvoir_disponible[0]:return
	player_hp+=10
	if player_hp>100:player_hp=100
	UpdatePlayer()
	pouvoir_disponible[0]=false
	spin_compteur_pouvoir[0]=0
	if pouvoir_boutons[0]:
		pouvoir_boutons[0].disabled=true
		pouvoir_boutons[i].modulate = Color(0.5, 0.5, 0.5, 1)

	check_pouvoir_cooldown()

func _on_pouvoir2_pressed():
	if choix_en_cours or not pouvoir_disponible[1]:return
	var d=10
	var nh=enemy["hp"]-d
	if nh<0:nh=0
	enemy["hp"]=nh
	var hb=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPBar
	hb.max_value=enemy_max_hp
	hb.value=nh
	hb.queue_redraw()
	var hl=$CombatPanel/SpritesContainer/EnemySprite/EnemyHPLabel
	hl.text=str(nh)+"/"+str(enemy_max_hp)
	if nh==0:
		ennemis_vaincus+=1
		if ennemis_vaincus%2==0:AfficherChoixPassif()
		else:
			UpdateEnemy()
			AfficherChoixObjet()
	pouvoir_disponible[1]=false
	spin_compteur_pouvoir[1]=0
	if pouvoir_boutons[1]:
		pouvoir_boutons[1].disabled=true
		var ic=pouvoir_boutons[1].get_node("pouvoir2")
		if ic:ic.modulate=Color(0.5,0.5,0.5,1)
	check_pouvoir_cooldown()

func _on_pouvoir3_pressed():
	if choix_en_cours or not pouvoir_disponible[2]:return
	AfficherChoixObjet()
	pouvoir_disponible[2]=false
	spin_compteur_pouvoir[2]=0
	if pouvoir_boutons[2]:
		pouvoir_boutons[2].disabled=true
		var ic=pouvoir_boutons[2].get_node("pouvoir3")
		if ic:ic.modulate=Color(0.5,0.5,0.5,1)
	check_pouvoir_cooldown()

func _on_pouvoir4_pressed():
	if choix_en_cours or not pouvoir_disponible[3]:return
	pouvoir_disponible[3]=false
	spin_compteur_pouvoir[3]=0
	if pouvoir_boutons[3]:
		pouvoir_boutons[3].disabled=true
		var ic=pouvoir_boutons[3].get_node("pouvoir4")
		if ic:ic.modulate=Color(0.5,0.5,0.5,1)
	check_pouvoir_cooldown()
	
func check_pouvoir_cooldown():
	for i in range(pouvoir_boutons.size()):
		spin_compteur_pouvoir[i] += 1

		if not pouvoir_disponible[i] and spin_compteur_pouvoir[i] >= cooldown_pouvoir[i]:
			pouvoir_disponible[i] = true

			if pouvoir_boutons[i] and not choix_en_cours:
				pouvoir_boutons[i].disabled = false
				pouvoir_boutons[i].modulate = Color(1, 1, 0, 1)


func _on_grid_slot_mouse_entered(i):
	if i<0 or i>=items.size():return
	hovered_slot_index=i
	tooltip_timer.start()

func _on_grid_slot_mouse_exited(i):
	if hovered_slot_index==i:
		hovered_slot_index=-1
		tooltip_timer.stop()
		tooltip_label.visible=false

func _on_tooltip_timer_timeout():
	if hovered_slot_index<0 or hovered_slot_index>=items.size():return
	var id=items[hovered_slot_index]
	if not symbols_data.has(id):return
	var d=symbols_data[id]
	if not d.has("name"):return
	var nom=d["name"]
	var eff=d["effects"] if d.has("effects") else []
	var e=str(eff[0]) if eff.size()>0 else ""
	tooltip_label.text=nom+( "\n"+e if e!="" else "")
	var mp=get_viewport().get_mouse_position()
	tooltip_label.position=mp+Vector2(16,16)
	tooltip_label.visible=true
