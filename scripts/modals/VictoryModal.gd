extends PanelContainer
## =====================================================================
## VICTORYMODAL.GD — Tela de vitória + estatísticas + modo infinito
## =====================================================================

signal continuar_solicitado

@onready var time_row: Label = $Margin/VBox/StatsBox/TempoRow
@onready var cliques_row: Label = $Margin/VBox/StatsBox/CliquesRow
@onready var discos_row: Label = $Margin/VBox/StatsBox/DiscosRow
@onready var conquistas_row: Label = $Margin/VBox/StatsBox/ConquistasRow
@onready var golden_row: Label = $Margin/VBox/StatsBox/GoldenRow
@onready var continuar_button: Button = $Margin/VBox/ContinuarButton

func _ready() -> void:
	_style()
	continuar_button.pressed.connect(_continuar)
	_preencher_stats()
	_animar_entrada()

func _preencher_stats() -> void:
	time_row.text = "⏱️  Tempo total jogado: " + Global.formatar_tempo(Global.tempo_jogado)
	cliques_row.text = "👆 Cliques dados: " + Global.formatar_numero(float(Global.cliques_totais))
	discos_row.text = "🏆 Discos de Ouro: " + str(Global.discos_de_ouro)
	conquistas_row.text = "🏅 Conquistas: %d/%d" % [
		Global.contar_conquistas(), Global.dados_conquistas.size()
	]
	golden_row.text = "🌟 Notas Douradas Coletadas: " + str(Global.notas_douradas_clicadas)

func _animar_entrada() -> void:
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	pivot_offset = size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	tw.tween_property(self, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _continuar() -> void:
	continuar_solicitado.emit()
	queue_free()

func _style() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.10, 0.18, 0.99)
	s.border_color = Color("#ffd700")
	s.set_border_width_all(3)
	s.set_corner_radius_all(20)
	add_theme_stylebox_override("panel", s)
