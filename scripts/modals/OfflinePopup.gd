extends PanelContainer
## =====================================================================
## OFFLINEPOPUP.GD — Exibe ganhos offline ao abrir o jogo
## =====================================================================

signal fechado

@onready var time_label: Label = $Margin/VBox/TimeLabel
@onready var gain_label: Label = $Margin/VBox/GainLabel
@onready var ok_button: Button = $Margin/VBox/OKButton

var _dados: Dictionary = {}

func _ready() -> void:
	_style()
	ok_button.pressed.connect(_fechar)
	# Começa invisível, aparece via show_dados
	modulate.a = 0.0

func setup(dados: Dictionary) -> void:
	_dados = dados

func show_dados() -> void:
	var segs: int = int(_dados.get("segundos", 0))
	var ganho: float = float(_dados.get("ganho", 0.0))
	time_label.text = "Você ficou ausente por " + Global.formatar_tempo(float(segs))
	gain_label.text = "+" + Global.formatar_numero(ganho) + " notas"
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)

func _fechar() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		fechado.emit()
		queue_free()
	)

func _style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.12, 0.22, 0.98)
	s.border_color = Color("#7df9ff")
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	add_theme_stylebox_override("panel", s)
