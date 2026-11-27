extends PanelContainer
## =====================================================================
## ACHIEVEMENTPOPUP.GD — Toast animado que desce do topo, segura e sobe
## =====================================================================

signal animation_finished

@onready var icon_label: Label   = $Margin/HBox/IconLabel
@onready var name_label: Label   = $Margin/HBox/VBox/NameLabel
@onready var desc_label: Label   = $Margin/HBox/VBox/DescLabel

func setup(dados: Dictionary) -> void:
	_style()
	if is_node_ready():
		icon_label.text = String(dados.get("icone", "🏅"))
		name_label.text = String(dados.get("nome", "Conquista"))
		desc_label.text = String(dados.get("desc", "")) + "  (+2% bônus!)"

func play(vp_width: float) -> void:
	# Posiciona acima da tela, centralizado
	var popup_width: float = vp_width - 40.0
	custom_minimum_size = Vector2(popup_width, 100)
	size = Vector2(popup_width, 100)
	position = Vector2(20.0, -120.0)

	# 1) Desce do topo para y=80 com bounce
	var tw := create_tween()
	tw.tween_property(self, "position:y", 80.0, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2) Segura 2.5s
	tw.tween_interval(2.5)
	# 3) Sobe de volta
	tw.tween_property(self, "position:y", -120.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		animation_finished.emit()
		queue_free()
	)

func _style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.14, 0.05, 0.97)      # marrom escuro
	s.border_color = Color("#ffd700")                # dourado
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	add_theme_stylebox_override("panel", s)
