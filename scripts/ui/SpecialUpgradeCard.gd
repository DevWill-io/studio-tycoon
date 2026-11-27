extends PanelContainer
## =====================================================================
## SPECIALUPGRADECARD.GD — Card para melhorias únicas (compradas 1x)
## =====================================================================

@onready var icon_label: Label   = $Margin/VBox/TopRow/IconLabel
@onready var name_label: Label   = $Margin/VBox/TopRow/InfoBox/NameLabel
@onready var desc_label: Label   = $Margin/VBox/TopRow/InfoBox/DescLabel
@onready var status_label: Label = $Margin/VBox/TopRow/StatusLabel
@onready var buy_button: Button  = $Margin/VBox/BuyButton

var index: int = 0

# ---------------------------------------------------------------------
func _ready() -> void:
	buy_button.pressed.connect(_try_buy)
	_style_card()
	_liberar_touch_recursivo(self)
	Global.estado_atualizado.connect(refresh)
	Global.notas_alteradas.connect(refresh)
	refresh()
	
func _liberar_touch_recursivo(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for filho in node.get_children():
		_liberar_touch_recursivo(filho)

## Chamado ANTES de add_child.
func setup(index_novo: int) -> void:
	index = index_novo
	if is_node_ready():
		refresh()

# ---------------------------------------------------------------------
func refresh() -> void:
	if not is_node_ready(): return
	var d: Dictionary = Global.dados_melhorias[index]
	var comprada: bool = Global.melhorias_compradas[index]
	var custo: float = float(d["custo"])

	icon_label.text  = String(d.get("icone", "⭐"))
	name_label.text  = String(d["nome"])
	desc_label.text  = String(d.get("desc", ""))

	if comprada:
		status_label.text = "✅"
		status_label.add_theme_color_override("font_color", Color("#7dff7d"))
		buy_button.text = "Comprado"
		buy_button.disabled = true
		modulate = Color(1, 1, 1, 0.65)
	else:
		status_label.text = "🔒"
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		buy_button.text = "Comprar  " + Global.formatar_numero(custo)
		buy_button.disabled = Global.notas < custo
		modulate = Color.WHITE

# ---------------------------------------------------------------------
func _try_buy() -> void:
	if Global.comprar_melhoria(index):
		refresh()
		_animate_purchase()

func _animate_purchase() -> void:
	var original: Color = modulate
	modulate = Color(original.r * 1.4, original.g * 1.4, original.b * 0.9, original.a)
	var tw := create_tween()
	tw.tween_property(self, "modulate", original, 0.35).set_trans(Tween.TRANS_QUAD)

# ---------------------------------------------------------------------
func _style_card() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.10, 0.20, 0.95)     # tom roxo (especial)
	s.border_color = Color("#8a5fff")
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.content_margin_left   = 6
	s.content_margin_right  = 6
	s.content_margin_top    = 4
	s.content_margin_bottom = 4
	add_theme_stylebox_override("panel", s)
