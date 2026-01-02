extends Button

@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	# Vérification nœud (optionnel, pour debug)
	if not audio_player:
		push_error("AudioStreamPlayer2D manquant sous %s!" % name)
		return
	

func _on_pressed() -> void:
	# Jouer son (arrête si déjà en cours)
	if audio_player.playing:
		audio_player.stop()
	audio_player.play()
	
	# Animation fluide au clic (zoom + clignotement)
	var tween = create_tween()
	tween.set_parallel()  # Animations simultanées
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)
	tween.tween_property(self, "modulate:a", 0.6, 0.05).from(1.0)
	tween.tween_property(self, "modulate:a", 1.0, 0.05)
	
	# TODO: Logique machine à sous (lancer spin, etc.)
	# ex: get_parent().start_spin()
