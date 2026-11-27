extends Control
## =====================================================================
## FLOATINGTEXT.GD — Texto flutuante com animação Tween + áudio dinâmico
## =====================================================================

@onready var label: Label = $Label
@onready var audio: AudioStreamPlayer = $Audio

func setup(texto: String, cor: Color, stream: AudioStream, pitch: float, duracao: float = 1.1) -> void:
	if label:
		label.text = texto
		label.add_theme_color_override("font_color", cor)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))

	if audio and stream:
		audio.stream = stream
		audio.pitch_scale = pitch
		audio.play()

	var start_y: float = position.y
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", start_y - 130.0, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duracao) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)
