extends PanelContainer
## =====================================================================
## UPGRADECARD.GD — Card reutilizável para Equipamentos e Equipe
## =====================================================================

@onready var icon_label: Label  = $Margin/VBox/TopRow/IconLabel
@onready var name_label: Label  = $Margin/VBox/TopRow/InfoBox/NameLabel
@onready var level_label: Label = $Margin/VBox/TopRow/InfoBox/LevelLabel
@onready var bonus_label: Label = $Margin/VBox/TopRow/BonusLabel
@onready var buy1: Button       = $Margin/VBox/ButtonsRow/Buy1
@onready var buy10: Button      = $Margin/VBox/ButtonsRow/Buy10
@onready var buy_max: Button    = $Margin/VBox/ButtonsRow/BuyMax

var tipo: String = "equipamento"   # "equipamento" | "equipe"
var index: int = 0

# ---------------------------------------------------------------------
func _ready() -> void:
	buy1.pressed.connect(_try_buy.bind(1))
	buy10.pressed.connect(_try_buy.bind(10))
	buy_max.pressed.connect(_try_buy.bind(-1))
	_style_card()
	Global.estado_atualizado.connect(refresh)
	Global.notas_alteradas.connect(refresh)
	refresh()

## Chamado ANTES do add_child (is_node_ready() == false nesse momento).
func setup(tipo_novo: String, index_novo: int) -> void:
	tipo = tipo_novo
	index = index_novo
	if is_node_ready():
		refresh()

# ---------------------------------------------------------------------
# Helpers de leitura de dados
# ---------------------------------------------------------------------
func _get_data() -> Dictionary:
	if tipo == "equipamento":
		return Global.dados_equipamentos[index]
	return Global.dados_equipe[index]

func _get_nivel() -> int:
	if tipo == "equipamento":
		return Global.niveis_equipamentos[index]
	return Global.niveis_equipe[index]

# ---------------------------------------------------------------------
# Refresh — chamado em _ready e sempre que o estado global muda
# ---------------------------------------------------------------------
func refresh() -> void:
	if not is_node_ready():
		return
	var d: Dictionary = _get_data()
	var nivel: int = _get_nivel()

	icon_label.text  = String(d.get("icone", "🎵"))
	name_label.text  = String(d["nome"])
	level_label.text = "Nível " + str(nivel)
	var sufixo: String = " /clique" if tipo == "equipamento" else " NPS"
	bonus_label.text = "+" + Global.formatar_numero(float(d["bonus"])) + sufixo

	var custo1: float  = Global.calcular_custo_lote(d["custo_base"], nivel, 1)
	var custo10: float = Global.calcular_custo_lote(d["custo_base"], nivel, 10)
	var max_qtd: int   = Global.calcular_max_compravel(d["custo_base"], nivel, Global.notas)
	var custo_max: float = Global.calcular_custo_lote(d["custo_base"], nivel, max_qtd) if max_qtd > 0 else 0.0

	buy1.text   = "1x  "  + Global.formatar_numero(custo1)
	buy10.text  = "10x  " + Global.formatar_numero(custo10)
	buy_max.text = "MAX\n" + (Global.formatar_numero(custo_max) if max_qtd > 0 else "—")

	_apply_state(buy1,    Global.notas >= custo1)
	_apply_state(buy10,   Global.notas >= custo10)
	_apply_state(buy_max, max_qtd > 0)

func _apply_state(btn: Button, disponivel: bool) -> void:
	btn.disabled = not disponivel
	btn.modulate = Color.WHITE if disponivel else Color(1, 1, 1, 0.5)

# ---------------------------------------------------------------------
# Compra
# ---------------------------------------------------------------------
func _try_buy(qtd: int) -> void:
	var comprado: int = 0
	if tipo == "equipamento":
		comprado = Global.comprar_equipamento(index, qtd)
	else:
		comprado = Global.comprar_equipe(index, qtd)

	if comprado > 0:
		_animate_purchase()
	refresh()

func _animate_purchase() -> void:
	var original: Color = modulate
	modulate = Color(1.4, 1.4, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", original, 0.28).set_trans(Tween.TRANS_QUAD)

# ---------------------------------------------------------------------
# Estilo via StyleBoxFlat (card escuro com borda sutil)
# ---------------------------------------------------------------------
func _style_card() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.13, 0.20, 0.95)
	s.border_color = Color("#3a3a5c")
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left   = 6
	s.content_margin_right  = 6
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	add_theme_stylebox_override("panel", s)
