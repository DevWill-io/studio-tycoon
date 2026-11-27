extends Button
## =====================================================================
## GOLDENNOTE.GD — Nota Dourada flutuante · clique ativa bônus ou frenesi
## =====================================================================

signal coletada(resultado: Dictionary)

@onready var audio: AudioStreamPlayer = $Audio

var _base_pos: Vector2 = Vector2.ZERO
var _bob_tween: Tween
var _vida_tween: Tween
var _coletada_flag: bool = false

# ---------------------------------------------------------------------
func setup(pos: Vector2, stream: AudioStream, duracao: float) -> void:
	position = pos
	_base_pos = pos
	if stream:
		audio.stream = stream
	_style()
	pressed.connect(_on_pressed)
	_iniciar_bob()
	_iniciar_vida(duracao)

# ---------------------------------------------------------------------
func _style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 0.84, 0.0, 0.92)         # dourado translúcido
	s.border_color = Color("#fff2a0")
	s.set_border_width_all(3)
	s.set_corner_radius_all(42)                       # circular
	add_theme_stylebox_override("normal", s)

	var s_hover := s.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(1.0, 0.92, 0.3, 0.95)
	add_theme_stylebox_override("hover", s_hover)
	add_theme_stylebox_override("pressed", s_hover)

# ---------------------------------------------------------------------
func _iniciar_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", _base_pos.y - 18.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", _base_pos.y + 18.0, 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------------
func _iniciar_vida(duracao: float) -> void:
	if _vida_tween and _vida_tween.is_valid():
		_vida_tween.kill()
	_vida_tween = create_tween()
	var fade_inicio: float = max(0.1, duracao - 1.0)
	_vida_tween.tween_interval(fade_inicio)
	_vida_tween.tween_property(self, "modulate:a", 0.0, 1.0)
	_vida_tween.tween_callback(_expirar)

func _expirar() -> void:
	if _coletada_flag: return
	_coletada_flag = true
	queue_free()

# ---------------------------------------------------------------------
func _on_pressed() -> void:
	if _coletada_flag: return
	_coletada_flag = true

	# Cancela as animações em andamento
	if _bob_tween and _bob_tween.is_valid(): _bob_tween.kill()
	if _vida_tween and _vida_tween.is_valid(): _vida_tween.kill()

	# Toca o som (via AudioStreamPlayer antes de sair da árvore)
	if audio and audio.stream:
		audio.play()

	# Chamar diretamente no Global (aplicar bônus/frenesi)
	var resultado: Dictionary = Global.aplicar_bonus_golden()
	coletada.emit(resultado)

	# Animação de "coleta": escala + fade
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)

	pivot_offset = size / 2.0
