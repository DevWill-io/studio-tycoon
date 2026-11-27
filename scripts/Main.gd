extends Control
## =====================================================================
## MAIN.GD — HUD, Instrumento, FloatingText, Tabs, NPS, Crítico, Groove,
##           Frenesi, GoldenNote, Estágios Visuais e Prestígio
## Blocos cobertos: 3, 4, 5, 6, 7
## =====================================================================

# ============ EXPORTS ============
@export var floating_text_scene: PackedScene
@export var upgrade_card_scene: PackedScene
@export var special_card_scene: PackedScene
@export var golden_note_scene: PackedScene
@export var achievement_popup_scene: PackedScene
@export var offline_popup_scene: PackedScene
@export var victory_modal_scene: PackedScene
@export var background_top_color: Color = Color("#1a1a2e")
@export var background_bottom_color: Color = Color("#16213e")
@export var instrument_emoji: String = "🎸"

# ============ ONREADY ============
@onready var background: TextureRect        = $Background
@onready var safe_area: MarginContainer     = $SafeArea
@onready var hud_panel: PanelContainer      = $SafeArea/Root/HUD
@onready var notas_label: Label             = $SafeArea/Root/HUD/HUDMargin/HBox/StatsBox/NotasLabel
@onready var nps_label: Label               = $SafeArea/Root/HUD/HUDMargin/HBox/StatsBox/NPSLabel
@onready var per_click_label: Label         = $SafeArea/Root/HUD/HUDMargin/HBox/StatsBox/PerClickLabel
@onready var discos_label: Label            = $SafeArea/Root/HUD/HUDMargin/HBox/RightBox/DiscosLabel
@onready var ach_button: Button             = $SafeArea/Root/HUD/HUDMargin/HBox/RightBox/ButtonsBox/AchButton
@onready var cfg_button: Button             = $SafeArea/Root/HUD/HUDMargin/HBox/RightBox/ButtonsBox/CfgButton
@onready var stage: Control                 = $SafeArea/Root/Stage
@onready var instrument: PanelContainer     = $SafeArea/Root/Stage/Instrument
@onready var inst_label: Label              = $SafeArea/Root/Stage/Instrument/Center/InstLabel
@onready var groove_bar: ProgressBar        = $SafeArea/Root/Stage/GrooveBar
@onready var float_layer: Control           = $SafeArea/Root/Stage/FloatLayer
@onready var bottom_panel: PanelContainer   = $SafeArea/Root/Bottom

# ============ ESTADO INTERNO ============
var _is_touch_device: bool = false
var _ultimo_clique_ms: int = 0
const COOLDOWN_CLIQUE_MS: int = 60 # 60ms = até ~16 cliques por segundo (suave para dedos, bloqueia spam)
var _click_stream: AudioStream
var _sparkle_stream: AudioStream
var _instrument_tween: Tween
var _golden_timer: Timer = null
var _last_groove_mult: float = 1.0
var _frenesi_tween: Tween
var _frenesi_border: PanelContainer = null

# ─── [BLOCO 8] Conquistas ───
var _popup_queue: Array[int] = []
var _popup_ativo: bool = false

# ─── [BLOCO 9] ───
var _settings_overlay: PanelContainer = null  

# ─── [BLOCO 10]  FPS  ───
var _fps_label: Label = null

# Background transition
var _bg_tween: Tween
var _bg_top_atual: Color
var _bg_bottom_atual: Color
var _bg_from_top: Color
var _bg_from_bottom: Color
var _bg_to_top: Color
var _bg_to_bottom: Color

# =====================================================================
# READY
# =====================================================================
func _ready() -> void:
	_is_touch_device = DisplayServer.is_touchscreen_available()
	inst_label.text = instrument_emoji

	_apply_safe_area()
	_setup_background()
	_style_panels()
	_click_stream = _generate_click_beep()
	_sparkle_stream = _generate_sparkle()
	_setup_frenesi_border()
	_setup_golden_timer()
	_connect_ui()
	
	_setup_fps_counter()
	Global.aplicar_configuracoes_graficas()
	Global.graficos_alterados.connect(_on_graficos_alterados)
	Global.mostrar_fps_alterado.connect(func(ativo: bool):
		if _fps_label: _fps_label.visible = ativo)
	
	# get_viewport().size_changed.connect(_ajustar_breakpoint)
	# _ajustar_breakpoint()

	Global.notas_alteradas.connect(_refresh_hud)
	Global.estado_atualizado.connect(_refresh_hud)
	Global.groove_alterada.connect(_on_groove_alterada)
	Global.frenesi_alterado.connect(_on_frenesi_alterado)
	Global.estagio_alterado.connect(_on_estagio_alterado)
	Global.conquista_desbloqueada.connect(_on_conquista_desbloqueada)
	Global.album_diamante_comprado_signal.connect(_on_album_diamante_comprado)

	_popular_tab("Equipamentos", "equipamento", Global.dados_equipamentos.size())
	_popular_tab("Estúdio e Equipe", "equipe", Global.dados_equipe.size())
	_popular_tab_melhorias()
	_popular_tab_carreira()
	Global.verificar_conquistas()

	_refresh_hud()
	call_deferred("_mostrar_offline_se_pendente")
	print("[Main] Pronto. Touch device=%s  FloatingText=%s  UpgradeCard=%s  Golden=%s" % [
		_is_touch_device,
		str(floating_text_scene != null),
		str(upgrade_card_scene != null),
		str(golden_note_scene != null)
	])

func _connect_ui() -> void:
	ach_button.pressed.connect(_abrir_modal_conquistas)
	cfg_button.pressed.connect(_abrir_settings)

# =====================================================================
# SAFE AREA
# =====================================================================
func _apply_safe_area() -> void:
	var base_top: int = 12
	safe_area.add_theme_constant_override("margin_left", 12)
	safe_area.add_theme_constant_override("margin_right", 12)
	safe_area.add_theme_constant_override("margin_bottom", 12)

	if not _is_touch_device:
		safe_area.add_theme_constant_override("margin_top", base_top)
		return

	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.y <= 0:
		safe_area.add_theme_constant_override("margin_top", base_top)
		return

	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var vp_h: float = get_viewport_rect().size.y
	var ratio: float = float(safe_rect.position.y) / float(screen.y)
	var top_px: int = int(ceil(ratio * vp_h))
	safe_area.add_theme_constant_override("margin_top", max(top_px, base_top))

# =====================================================================
# FUNDO (estágios visuais)
# =====================================================================
func _setup_background() -> void:
	var d: Dictionary = Global.dados_estagios[Global.estagio_atual]
	_bg_top_atual = d["cor_top"]
	_bg_bottom_atual = d["cor_bottom"]
	_aplicar_gradiente(_bg_top_atual, _bg_bottom_atual)

func _aplicar_gradiente(top: Color, bottom: Color) -> void:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	grad.add_point(0.5, top.lerp(bottom, 0.4))

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 720
	tex.height = 1280
	background.texture = tex

# =====================================================================
# ESTILO
# =====================================================================
func _style_panels() -> void:
	hud_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.10, 0.10, 0.18, 0.95), Color("#3a3a5c"), 14))
	bottom_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.08, 0.08, 0.15, 0.97), Color("#3a3a5c"), 14))
	instrument.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.16, 0.16, 0.28, 0.85), Color("#7df9ff"), 20))

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.10, 0.9)
	bg.corner_radius_top_left = 8
	bg.corner_radius_top_right = 8
	bg.corner_radius_bottom_left = 8
	bg.corner_radius_bottom_right = 8
	groove_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#7df9ff")
	fill.corner_radius_top_left = 8
	fill.corner_radius_top_right = 8
	fill.corner_radius_bottom_left = 8
	fill.corner_radius_bottom_right = 8
	groove_bar.add_theme_stylebox_override("fill", fill)
	groove_bar.value = 0.0

func _make_panel_style(bg: Color, border: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(corner)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

# =====================================================================
# ÁUDIO PROCEDURAL
# =====================================================================
func _generate_click_beep() -> AudioStream:
	var sample_rate: int = 22050
	var duration: float = 0.08
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var freq: float = 660.0
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(num_samples))
		var sample: float = sin(2.0 * PI * freq * t) * env * 0.28
		var s16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func _generate_sparkle() -> AudioStream:
	var sample_rate: int = 22050
	var duration: float = 0.45
	var num_samples: int = int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var freqs: Array[float] = [659.25, 830.61, 987.77]
	for i in range(num_samples):
		var t: float = float(i) / float(sample_rate)
		var env: float = pow(1.0 - (float(i) / float(num_samples)), 1.5)
		var sample: float = 0.0
		for f in freqs:
			sample += sin(2.0 * PI * f * t)
		sample = sample / float(freqs.size()) * env * 0.35
		var s16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s16)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

# =====================================================================
# INPUT
# =====================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		Global.toggle_fullscreen()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_tap(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not _is_touch_device:
			_on_tap(event.position)

func _on_tap(pos: Vector2) -> void:
	if not instrument.get_global_rect().has_point(pos):
		return
	
	# Trava de cooldown para evitar travamento por spam de cliques
	var agora: int = Time.get_ticks_msec()
	if agora - _ultimo_clique_ms < COOLDOWN_CLIQUE_MS:
		return
	_ultimo_clique_ms = agora
	
	_do_click(pos)

func _do_click(pos: Vector2) -> void:
	Global.cliques_totais += 1
	Global.adicionar_groove()
	Global.verificar_conquistas()

	var ganho_base: float = Global.calcular_notas_por_clique()
	var is_crit: bool = randf() < Global.get_crit_chance()
	var ganho_final: float = ganho_base
	if is_crit:
		ganho_final *= Global.get_crit_mult()
	Global.adicionar_notas(ganho_final)

	_animate_instrument()
	if is_crit:
		_spawn_floating_text(pos, "CRÍTICO! +" + Global.formatar_numero(ganho_final),
			Color("#ffd700"), randf_range(1.8, 2.2))
		_vibrar_se_possivel(45)
	else:
		_spawn_floating_text(pos, "+" + Global.formatar_numero(ganho_final),
			Color.WHITE, randf_range(0.90, 1.15))
	_refresh_hud()

# =====================================================================
# ANIMAÇÃO INSTRUMENTO
# =====================================================================
func _animate_instrument() -> void:
	if _instrument_tween and _instrument_tween.is_valid():
		_instrument_tween.kill()
	instrument.pivot_offset = instrument.size / 2.0
	_instrument_tween = create_tween()
	_instrument_tween.tween_property(instrument, "scale", Vector2(0.94, 0.94), 0.06).set_trans(Tween.TRANS_QUAD)
	_instrument_tween.tween_property(instrument, "scale", Vector2(1.02, 1.02), 0.08).set_trans(Tween.TRANS_QUAD)
	_instrument_tween.tween_property(instrument, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_QUAD)

# =====================================================================
# FLOATING TEXT
# =====================================================================
func _spawn_floating_text(screen_pos: Vector2, texto: String, cor: Color, pitch: float) -> void:
	if floating_text_scene == null: return
	
	# Gráfico Baixo (0): não cria textos normais (brancos) para não lagar
	if Global.qualidade_grafica == 0 and cor == Color.WHITE:
		return
	
	# Gráfico Médio (1): máximo de 8 textos ao mesmo tempo na tela
	if Global.qualidade_grafica == 1 and float_layer.get_child_count() >= 8:
		return

	var ft := floating_text_scene.instantiate()
	float_layer.add_child(ft)
	var local_pos: Vector2 = float_layer.get_global_transform_with_canvas().affine_inverse() * screen_pos
	ft.position = local_pos - Vector2(40, 20) + Vector2(randf_range(-30, 30), 0)
	ft.setup(texto, cor, _click_stream, pitch)

# =====================================================================
# HUD
# =====================================================================
func _refresh_hud() -> void:
	notas_label.text = "🎵 " + Global.formatar_numero(Global.notas)
	nps_label.text = "📈 " + Global.formatar_nps()
	per_click_label.text = "👆 " + Global.formatar_numero(Global.calcular_notas_por_clique()) + "/clique"
	discos_label.text = "🏆 " + str(Global.discos_de_ouro)
	groove_bar.value = Global.groove
	ach_button.tooltip_text = "Conquistas: %d/%d (+%d%% bônus)" % [
		Global.contar_conquistas(),
		Global.dados_conquistas.size(),
		Global.get_bonus_conquistas_pct()
	]
	# Só atualiza a aba Carreira se ela for a aba ativa no momento (index 3)
	var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
	if tabs and tabs.current_tab == 3:
		_refresh_carreira()

# =====================================================================
# POPULAR ABAS
# =====================================================================
func _popular_tab(nome_tab: String, tipo: String, quantidade: int) -> void:
	var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
	var tab_node: Node = tabs.get_node_or_null(nome_tab)
	if tab_node == null:
		push_warning("[Main] Aba '%s' não encontrada." % nome_tab)
		return
	var container: VBoxContainer = tab_node.get_node_or_null("CardsContainer")
	if container == null:
		push_warning("[Main] Aba '%s' sem CardsContainer." % nome_tab)
		return
	for filho in container.get_children():
		filho.queue_free()
	if upgrade_card_scene == null:
		push_warning("[Main] upgrade_card_scene NÃO atribuído no Inspetor!")
		return
	for i in range(quantidade):
		var card: PanelContainer = upgrade_card_scene.instantiate()
		card.setup(tipo, i)
		container.add_child(card)

func _popular_tab_melhorias() -> void:
	var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
	var tab_node: ScrollContainer = tabs.get_node_or_null("Pesquisa")
	if tab_node == null: return
	tab_node.scroll_deadzone = 12 # Evita comprar sem querer ao arrastar
	
	var container: VBoxContainer = tab_node.get_node_or_null("CardsContainer")
	if container == null: return
	for filho in container.get_children():
		filho.queue_free()
	if special_card_scene == null: return
	for i in range(Global.dados_melhorias.size()):
		var card: PanelContainer = special_card_scene.instantiate()
		card.setup(i)
		container.add_child(card)
	_liberar_touch_recursivo(container)

# =====================================================================
# VIBRAÇÃO
# =====================================================================
func _vibrar_se_possivel(ms: int) -> void:
	if Global.vibracao_ativa and _is_touch_device:
		Input.vibrate_handheld(ms)

# =====================================================================
# GROOVE
# =====================================================================
func _on_groove_alterada(valor: float) -> void:
	groove_bar.value = valor
	var novo_mult: float = Global.get_groove_mult()
	if novo_mult != _last_groove_mult:
		_last_groove_mult = novo_mult
		per_click_label.text = "👆 " + Global.formatar_numero(Global.calcular_notas_por_clique()) + "/clique"

# =====================================================================
# FRENESI
# =====================================================================
func _on_frenesi_alterado(ativo: bool) -> void:
	if ativo:
		_iniciar_frenesi_visual()
		_spawn_center_toast("🔥 SHOW AO VIVO! ×3 🔥", Color("#ffd700"), 2.5)
	else:
		_parar_frenesi_visual()
		_spawn_center_toast("Frenesi encerrado", Color(1, 1, 1, 0.6), 1.5)
	_refresh_hud()

func _setup_frenesi_border() -> void:
	if _frenesi_border != null: return
	_frenesi_border = PanelContainer.new()
	_frenesi_border.name = "FrenesiBorder"
	_frenesi_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frenesi_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("#ffd700")
	style.set_border_width_all(10)
	_frenesi_border.add_theme_stylebox_override("panel", style)
	_frenesi_border.visible = false
	stage.add_child(_frenesi_border)

func _iniciar_frenesi_visual() -> void:
	if _frenesi_tween and _frenesi_tween.is_valid():
		_frenesi_tween.kill()
	_frenesi_border.visible = true
	_frenesi_border.modulate.a = 0.85
	
	if Global.qualidade_grafica == 0:
		return # No Baixo fica estática para economizar processamento
		
	_frenesi_border.modulate.a = 1.0
	_frenesi_tween = create_tween().set_loops()
	_frenesi_tween.tween_property(_frenesi_border, "modulate:a", 0.35, 0.5)
	_frenesi_tween.tween_property(_frenesi_border, "modulate:a", 1.0, 0.5)

func _parar_frenesi_visual() -> void:
	if _frenesi_tween and _frenesi_tween.is_valid():
		_frenesi_tween.kill()
	if _frenesi_border:
		_frenesi_border.visible = false

# =====================================================================
# GOLDEN NOTE
# =====================================================================
func _setup_golden_timer() -> void:
	if _golden_timer != null: return
	_golden_timer = Timer.new()
	_golden_timer.name = "GoldenTimer"
	_golden_timer.one_shot = true
	_golden_timer.timeout.connect(_on_golden_timer_timeout)
	add_child(_golden_timer)
	_agendar_proxima_golden()

func _agendar_proxima_golden() -> void:
	_golden_timer.wait_time = Global.calcular_golden_intervalo()
	_golden_timer.start()

func _on_golden_timer_timeout() -> void:
	_spawn_golden_note()
	_agendar_proxima_golden()

func _spawn_golden_note() -> void:
	if golden_note_scene == null: return
	var gn: Button = golden_note_scene.instantiate()
	float_layer.add_child(gn)
	var area: Vector2 = float_layer.size
	if area.x < 200 or area.y < 200:
		area = Vector2(500, 500)
	var pos := Vector2(
		randf_range(60.0, max(61.0, area.x - 140.0)),
		randf_range(60.0, max(61.0, area.y - 140.0))
	)
	gn.setup(pos, _sparkle_stream, Global.calcular_golden_duracao())
	gn.coletada.connect(_on_golden_coletada)

func _on_golden_coletada(resultado: Dictionary) -> void:
	if String(resultado.get("tipo", "")) == "frenesi":
		pass
	else:
		var valor: float = float(resultado.get("valor", 0.0))
		_spawn_center_toast("🌟 BÔNUS! +" + Global.formatar_numero(valor) + " notas",
			Color("#ffd700"), 2.0)

# =====================================================================
# TOAST CENTRAL
# =====================================================================
func _spawn_center_toast(texto: String, cor: Color, duracao: float = 2.0) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_layer.add_child(cc)

	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", cor)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cc.add_child(label)

	cc.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(cc, "modulate:a", 1.0, 0.35)
	tw.tween_interval(max(0.1, duracao - 0.85))
	tw.tween_property(cc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(cc.queue_free)

# =====================================================================
# ESTÁGIO — TRANSIÇÃO DE FUNDO
# =====================================================================
func _on_estagio_alterado(novo: int) -> void:
	var d: Dictionary = Global.dados_estagios[novo]
	_bg_from_top = _bg_top_atual
	_bg_from_bottom = _bg_bottom_atual
	_bg_to_top = d["cor_top"]
	_bg_to_bottom = d["cor_bottom"]

	if _bg_tween and _bg_tween.is_valid(): _bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_method(_tween_bg, 0.0, 1.0, 1.2)
	_bg_tween.tween_callback(func():
		_bg_top_atual = _bg_to_top
		_bg_bottom_atual = _bg_to_bottom)

	_spawn_center_toast("🎬 Novo estágio: " + String(d["nome"]) + "!", Color("#7df9ff"), 3.0)
	_refresh_carreira()

func _tween_bg(t: float) -> void:
	var c_top: Color = _bg_from_top.lerp(_bg_to_top, t)
	var c_bottom: Color = _bg_from_bottom.lerp(_bg_to_bottom, t)
	_aplicar_gradiente(c_top, c_bottom)

# =====================================================================
# CARREIRA — Cards gerados por código
# =====================================================================
func _popular_tab_carreira() -> void:
	var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
	var tab_node: ScrollContainer = tabs.get_node_or_null("Carreira")
	if tab_node == null: return
	tab_node.scroll_deadzone = 12 # Evita clicar no prestígio sem querer ao arrastar
	
	var container: VBoxContainer = tab_node.get_node_or_null("CardsContainer")
	if container == null: return
	for filho in container.get_children():
		filho.queue_free()
	container.add_child(_criar_card_estagio())
	container.add_child(_criar_card_proximo())
	container.add_child(_criar_card_prestigio())
	container.add_child(_criar_card_album_diamante())
	_liberar_touch_recursivo(container)
	
func _liberar_touch_recursivo(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for filho in node.get_children():
		_liberar_touch_recursivo(filho)

func _criar_painel(nome_node: String, cor_borda: Color = Color("#3a3a5c")) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = nome_node
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.20, 0.95)
	style.border_color = cor_borda
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	return {"panel": panel, "vbox": vbox}

# ─── Card Estágio Atual ───
func _criar_card_estagio() -> Control:
	var r: Dictionary = _criar_painel("CardEstagio")
	var vbox: VBoxContainer = r["vbox"]
	var titulo := Label.new()
	titulo.text = "🎬 Estágio Atual"
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color("#7df9ff"))
	vbox.add_child(titulo)

	var nome := Label.new()
	nome.name = "NomeLabel"
	nome.add_theme_font_size_override("font_size", 20)
	vbox.add_child(nome)

	var desc := Label.new()
	desc.name = "DescLabel"
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	_atualizar_card_estagio(r["panel"])
	return r["panel"]

func _atualizar_card_estagio(panel: PanelContainer) -> void:
	if not is_instance_valid(panel): return
	var vbox: VBoxContainer = panel.get_child(0)
	var nome: Label = vbox.get_node_or_null("NomeLabel")
	var desc: Label = vbox.get_node_or_null("DescLabel")
	if nome == null or desc == null: return
	var d: Dictionary = Global.dados_estagios[Global.estagio_atual]
	nome.text = String(d["icone"]) + "  " + String(d["nome"])
	desc.text = String(d["descricao"])

# ─── Card Próximo Estágio ───
func _criar_card_proximo() -> Control:
	var r: Dictionary = _criar_painel("CardProximo", Color("#ffd700"))
	var vbox: VBoxContainer = r["vbox"]
	var titulo := Label.new()
	titulo.text = "🎯 Próximo Estágio"
	titulo.add_theme_font_size_override("font_size", 14)
	titulo.add_theme_color_override("font_color", Color("#ffd700"))
	vbox.add_child(titulo)

	var nome := Label.new()
	nome.name = "NomeLabel"
	nome.add_theme_font_size_override("font_size", 18)
	vbox.add_child(nome)

	var prog := ProgressBar.new()
	prog.name = "ProgBar"
	prog.custom_minimum_size.y = 20
	prog.show_percentage = false
	vbox.add_child(prog)

	var info := Label.new()
	info.name = "InfoLabel"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	vbox.add_child(info)

	_atualizar_card_proximo(r["panel"])
	return r["panel"]

func _atualizar_card_proximo(panel: PanelContainer) -> void:
	if not is_instance_valid(panel): return
	var vbox: VBoxContainer = panel.get_child(0)
	var nome: Label = vbox.get_node_or_null("NomeLabel")
	var prog: ProgressBar = vbox.get_node_or_null("ProgBar")
	var info: Label = vbox.get_node_or_null("InfoLabel")
	if nome == null or prog == null or info == null: return

	var idx_atual: int = Global.estagio_atual
	if idx_atual >= Global.dados_estagios.size() - 1:
		nome.text = "🏆 Estágio Final Alcançado!"
		prog.value = 100
		info.text = "Você chegou à Gravadora & Arena Mundial!"
		return

	var prox: Dictionary = Global.dados_estagios[idx_atual + 1]
	var thresh_atual: float = float(Global.dados_estagios[idx_atual]["threshold"])
	var thresh_prox: float = float(prox["threshold"])
	nome.text = String(prox["icone"]) + "  " + String(prox["nome"])
	var pct: float = clamp((Global.notas_totais - thresh_atual) / (thresh_prox - thresh_atual) * 100.0, 0.0, 100.0)
	prog.value = pct
	var falta: float = max(0.0, thresh_prox - Global.notas_totais)
	info.text = "Faltam %s notas (%.1f%%)" % [Global.formatar_numero(falta), pct]

# ─── Card Prestígio ───
func _criar_card_prestigio() -> Control:
	var r: Dictionary = _criar_painel("CardPrestigio", Color("#8a5fff"))
	var vbox: VBoxContainer = r["vbox"]
	var titulo := Label.new()
	titulo.text = "💿 Lançar Álbum (Prestígio)"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color("#c0a0ff"))
	vbox.add_child(titulo)

	var info := Label.new()
	info.name = "InfoLabel"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var discos_label := Label.new()
	discos_label.name = "DiscosLabel"
	discos_label.add_theme_font_size_override("font_size", 16)
	discos_label.add_theme_color_override("font_color", Color("#ffd700"))
	vbox.add_child(discos_label)

	var mult_label := Label.new()
	mult_label.name = "MultLabel"
	mult_label.add_theme_font_size_override("font_size", 12)
	mult_label.add_theme_color_override("font_color", Color("#a0ffe0"))
	vbox.add_child(mult_label)

	var aviso := Label.new()
	aviso.text = "⚠️ Reseta notas e upgrades. Mantém discos, conquistas e estágio."
	aviso.add_theme_font_size_override("font_size", 10)
	aviso.add_theme_color_override("font_color", Color(1, 0.7, 0.5, 0.9))
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(aviso)

	var btn := Button.new()
	btn.name = "PrestigioBtn"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_abrir_confirmacao_prestigio)
	vbox.add_child(btn)

	_atualizar_card_prestigio(r["panel"])
	return r["panel"]

func _atualizar_card_prestigio(panel: PanelContainer) -> void:
	if not is_instance_valid(panel): return
	var vbox: VBoxContainer = panel.get_child(0)
	var info: Label = vbox.get_node_or_null("InfoLabel")
	var lbl_discos: Label = vbox.get_node_or_null("DiscosLabel") # <-- Nome novo aqui
	var mult_label: Label = vbox.get_node_or_null("MultLabel")
	var btn: Button = vbox.get_node_or_null("PrestigioBtn")
	
	if info == null or lbl_discos == null or mult_label == null or btn == null: return

	var discos_ganhos: int = Global.calcular_discos_prestigio()
	var pode: bool = Global.pode_prestigiar()
	info.text = "Notas nesta run: %s\nMínimo: %s" % [
		Global.formatar_numero(Global.notas_ganhas_na_run),
		Global.formatar_numero(Global.PRESTIGIO_MINIMO)
	]
	
	if pode:
		lbl_discos.text = "🏆 +%d discos ao lançar" % discos_ganhos # <-- Usando o nome novo
		mult_label.text = "Mult. prestígio: +%d%% → +%d%%" % [
			int(Global.discos_de_ouro * 15.0),
			int((Global.discos_de_ouro + discos_ganhos) * 15.0)
		]
		btn.text = "💿 Lançar Álbum"
		btn.disabled = false
	else:
		var falta: float = Global.PRESTIGIO_MINIMO - Global.notas_ganhas_na_run
		lbl_discos.text = "🔒 Faltam %s notas" % Global.formatar_numero(falta) # <-- Usando o nome novo
		mult_label.text = "Mult. prestígio atual: +%d%%" % int(Global.discos_de_ouro * 15.0)
		btn.text = "🔒 Bloqueado"
		btn.disabled = true

# ─── Confirmação e execução ───
func _abrir_confirmacao_prestigio() -> void:
	var discos: int = Global.calcular_discos_prestigio()
	if discos <= 0: return
	var dialog := ConfirmationDialog.new()
	dialog.title = "💿 Lançar Álbum?"
	var texto := "Você ganhará %d discos de ouro!\n\n" % discos
	texto += "Total após lançar: %d discos\n" % (Global.discos_de_ouro + discos)
	texto += "Novo multiplicador: +%d%%\n\n" % int((Global.discos_de_ouro + discos) * 15.0)
	texto += "⚠️ Vai resetar:\n"
	texto += "• Notas atuais e notas da run\n"
	texto += "• Todos os upgrades e melhorias\n\n"
	texto += "✓ Vai manter:\n"
	texto += "• Discos, conquistas, estágio\n"
	texto += "• Estatísticas (cliques, tempo)"
	dialog.dialog_text = texto
	dialog.ok_button_text = "Confirmar"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(_on_prestigio_confirmado)
	add_child(dialog)
	dialog.popup_centered()

func _on_prestigio_confirmado() -> void:
	var discos_ganhos: int = Global.executar_prestigio()
	if discos_ganhos > 0:
		_spawn_center_toast("💿 +%d DISCOS DE OURO! 💿" % discos_ganhos, Color("#ffd700"), 3.0)
		_vibrar_se_possivel(80)
		_refresh_carreira()

# =====================================================================
# REFRESH CARREIRA
# =====================================================================
func _refresh_carreira() -> void:
	var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
	if tabs == null: return
	var tab_node: Node = tabs.get_node_or_null("Carreira")
	if tab_node == null: return
	var container: VBoxContainer = tab_node.get_node_or_null("CardsContainer")
	if container == null: return
	var card_estagio = container.get_node_or_null("CardEstagio")
	if card_estagio: _atualizar_card_estagio(card_estagio)
	var card_proximo = container.get_node_or_null("CardProximo")
	if card_proximo: _atualizar_card_proximo(card_proximo)
	var card_prestigio = container.get_node_or_null("CardPrestigio")
	if card_prestigio: _atualizar_card_prestigio(card_prestigio)
	var card_album = container.get_node_or_null("CardAlbumDiamante")
	if card_album: _atualizar_card_album_diamante(card_album)

# =====================================================================
# [BLOCO 8] — CONQUISTAS (Popups + Modal)
# =====================================================================

# ─── POPUP QUEUE ──────────────────────────────────────────────────────
func _on_conquista_desbloqueada(idx: int) -> void:
	_popup_queue.append(idx)
	if not _popup_ativo:
		_mostrar_proximo_popup()

func _mostrar_proximo_popup() -> void:
	if _popup_queue.is_empty():
		_popup_ativo = false
		return

	_popup_ativo = true
	var idx: int = _popup_queue.pop_front()

	if achievement_popup_scene == null:
		push_warning("[Main] achievement_popup_scene NÃO atribuído!")
		_popup_ativo = false
		return

	var popup: PanelContainer = achievement_popup_scene.instantiate()
	add_child(popup)
	popup.setup(Global.dados_conquistas[idx])
	popup.animation_finished.connect(_on_popup_finalizado)
	popup.play(size.x)

	_vibrar_se_possivel(60)

func _on_popup_finalizado() -> void:
	# Pequeno delay antes do próximo para não sobrepor
	await get_tree().create_timer(0.25).timeout
	_mostrar_proximo_popup()

# ─── MODAL DE CONQUISTAS ──────────────────────────────────────────────
func _abrir_modal_conquistas() -> void:
	# Se já está aberto, fecha
	if has_node("AchievementsOverlay"):
		get_node("AchievementsOverlay").queue_free()
		return

	var overlay := PanelContainer.new()
	overlay.name = "AchievementsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fundo escuro translúcido
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.85)
	overlay.add_theme_stylebox_override("panel", bg_style)

	# Fechar ao clicar no fundo
	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			overlay.queue_free())

	# Margin com padding para o painel interno
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margin)

	# Painel interno
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.12, 0.13, 0.22, 0.99), Color("#7df9ff"), 14))
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var titulo := Label.new()
	titulo.text = "🏅 Conquistas"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("#ffd700"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func(): overlay.queue_free())
	header.add_child(close_btn)

	# Contador
	var count: int = Global.contar_conquistas()
	var total: int = Global.dados_conquistas.size()
	var bonus: int = Global.get_bonus_conquistas_pct()
	var contador := Label.new()
	contador.text = "%d / %d desbloqueadas · +%d%% bônus global" % [count, total, bonus]
	contador.add_theme_font_size_override("font_size", 12)
	contador.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(contador)

	# Separador
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scroll com a lista
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	scroll.add_child(lista)

	for i in range(Global.dados_conquistas.size()):
		lista.add_child(_criar_linha_conquista(i))

	add_child(overlay)
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)

func _criar_linha_conquista(idx: int) -> Control:
	var d: Dictionary = Global.dados_conquistas[idx]
	var unlocked: bool = Global.conquistas_desbloqueadas[idx]

	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.12, 0.22, 0.15, 0.95)      # verde escuro
		style.border_color = Color("#7dff7d")
	else:
		style.bg_color = Color(0.14, 0.14, 0.18, 0.85)      # cinza
		style.border_color = Color(0.30, 0.30, 0.40)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var icon := Label.new()
	icon.text = String(d["icone"])
	icon.add_theme_font_size_override("font_size", 28)
	icon.custom_minimum_size = Vector2(40, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.35)
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var nome := Label.new()
	nome.text = String(d["nome"])
	nome.add_theme_font_size_override("font_size", 14)
	if unlocked:
		nome.add_theme_color_override("font_color", Color("#7dff7d"))
	vbox.add_child(nome)

	var desc := Label.new()
	desc.text = String(d["desc"])
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.72, 0.72, 0.82))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var status := Label.new()
	status.text = "✅" if unlocked else "🔒"
	status.add_theme_font_size_override("font_size", 20)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(status)

	return row

# =====================================================================
# [BLOCO 9] — CARD: ÁLBUM DE DIAMANTE (Objetivo Final)
# =====================================================================
func _criar_card_album_diamante() -> Control:
	var r: Dictionary = _criar_painel("CardAlbumDiamante", Color("#00e5ff"))
	var vbox: VBoxContainer = r["vbox"]
	var titulo := Label.new()
	titulo.text = "💎 Álbum de Diamante (Objetivo Final)"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color("#00e5ff"))
	vbox.add_child(titulo)

	var info := Label.new()
	info.name = "InfoLabel"
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var req := Label.new()
	req.name = "ReqLabel"
	req.add_theme_font_size_override("font_size", 11)
	req.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	req.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(req)

	var btn := Button.new()
	btn.name = "AlbumBtn"
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_on_album_diamante_button)
	vbox.add_child(btn)

	_atualizar_card_album_diamante(r["panel"])
	return r["panel"]

func _atualizar_card_album_diamante(panel: PanelContainer) -> void:
	if not is_instance_valid(panel): return
	var vbox: VBoxContainer = panel.get_child(0)
	var info: Label = vbox.get_node_or_null("InfoLabel")
	var req: Label = vbox.get_node_or_null("ReqLabel")
	var btn: Button = vbox.get_node_or_null("AlbumBtn")
	if info == null or req == null or btn == null: return

	if Global.album_diamante_comprado:
		info.text = "🏆 Você já gravou o Álbum de Diamante!"
		req.text = "Modo Infinito ativo. Continue batendo recordes."
		btn.text = "🏆 Jogo Zerado"
		btn.disabled = true
		return

	info.text = "Grave a obra-prima final do Studio Tycoon!"
	var estagio_ok: bool = Global.estagio_atual >= Global.dados_estagios.size() - 1
	var notas_ok: bool = Global.notas >= Global.CUSTO_ALBUM_DIAMANTE
	var txt_estagio := "✅ Estágio final alcançado" if estagio_ok else "❌ Requer: Gravadora & Arena Mundial"
	var txt_notas := "✅ 1T de notas" if notas_ok else "❌ Requer: %s notas" % Global.formatar_numero(Global.CUSTO_ALBUM_DIAMANTE)
	req.text = txt_estagio + "\n" + txt_notas

	if Global.pode_comprar_album_diamante():
		btn.text = "💎 GRAVAR ÁLBUM DE DIAMANTE (1T)"
		btn.disabled = false
	else:
		btn.text = "🔒 Bloqueado"
		btn.disabled = true

func _on_album_diamante_button() -> void:
	if not Global.pode_comprar_album_diamante(): return
	var dialog := ConfirmationDialog.new()
	dialog.title = "💎 Gravar o Álbum de Diamante?"
	dialog.dialog_text = "Você usará 1 Trilhão de notas para gravar a obra-prima final.\n\n"
	dialog.dialog_text += "Isso conclui o Studio Tycoon v1.0!\n"
	dialog.dialog_text += "Você poderá continuar no Modo Infinito depois."
	dialog.ok_button_text = "💎 GRAVAR!"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(_confirmar_album_diamante)
	add_child(dialog)
	dialog.popup_centered()

func _confirmar_album_diamante() -> void:
	Global.comprar_album_diamante()

func _on_album_diamante_comprado() -> void:
	_spawn_center_toast("💎 ÁLBUM DE DIAMANTE GRAVADO! 💎", Color("#ffd700"), 3.5)
	_vibrar_se_possivel(200)
	_refresh_carreira()
	# Abre o VictoryModal após um pequeno delay para o toast aparecer
	await get_tree().create_timer(1.5).timeout
	_abrir_victory_modal()

# =====================================================================
# [BLOCO 9] — OFFLINE POPUP
# =====================================================================
func _mostrar_offline_se_pendente() -> void:
	if not Global.tem_offline_pendente(): return
	if offline_popup_scene == null:
		push_warning("[Main] offline_popup_scene NÃO atribuído!")
		return
	var dados: Dictionary = Global.consumir_offline_pendente()
	var popup: PanelContainer = offline_popup_scene.instantiate()
	add_child(popup)
	popup.setup(dados)
	popup.show_dados()
	popup.fechado.connect(func(): pass)

# =====================================================================
# [BLOCO 9] — VICTORY MODAL
# =====================================================================
func _abrir_victory_modal() -> void:
	if victory_modal_scene == null:
		push_warning("[Main] victory_modal_scene NÃO atribuído!")
		return
	if has_node("VictoryOverlay"): return

	var overlay := PanelContainer.new()
	overlay.name = "VictoryOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.9)
	overlay.add_theme_stylebox_override("panel", bg)
	add_child(overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	overlay.add_child(margin)

	var modal: PanelContainer = victory_modal_scene.instantiate()
	margin.add_child(modal)
	modal.continuar_solicitado.connect(func(): overlay.queue_free())

# =====================================================================
# [BLOCO 9] — CONFIGURAÇÕES
# =====================================================================
func _abrir_settings() -> void:
	if _settings_overlay != null and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null
		return

	_settings_overlay = PanelContainer.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.85)
	_settings_overlay.add_theme_stylebox_override("panel", bg)
	_settings_overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_settings_overlay.queue_free()
			_settings_overlay = null)
	add_child(_settings_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.12, 0.13, 0.22, 0.99), Color("#7df9ff"), 14))
	margin.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Header com título e botão fechar
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var titulo := Label.new()
	titulo.text = "⚙️ Configurações"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Color("#7df9ff"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		_settings_overlay.queue_free()
		_settings_overlay = null)
	header.add_child(close_btn)

	# ── Seção Áudio ──
	_adicionar_secao(vbox, "🔊 Áudio")
	_adicionar_slider(vbox, "Volume BGM", Global.volume_bgm, 0.0, 1.0, 0.05,
		func(val):
			Global.volume_bgm = val
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), linear_to_db(val))
			Global.save_game())
	_adicionar_slider(vbox, "Volume SFX", Global.volume_sfx, 0.0, 1.0, 0.05,
		func(val):
			Global.volume_sfx = val
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(val))
			Global.save_game())

	# ── Seção Tela e Janela ──
	_adicionar_secao(vbox, "🖥️ Tela e Janela")
	_adicionar_botoes_tela(vbox)

	# ── Seção Interface ──
	_adicionar_secao(vbox, "🎨 Interface")
	_adicionar_slider(vbox, "Tamanho da UI", Global.escala_ui, 0.85, 1.50, 0.05,
		func(val): Global.set_escala_ui(val))
	# ── Qualidade Gráfica ──
	var lbl_graf := Label.new()
	lbl_graf.text = "Qualidade Gráfica:"
	lbl_graf.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl_graf)

	var hbox_graf := HBoxContainer.new()
	hbox_graf.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox_graf)

	var nomes_graf: Array[String] = ["🔋 Baixo", "⚖️ Médio", "✨ Alto"]
	for i in range(3):
		var btn_g := Button.new()
		btn_g.text = nomes_graf[i]
		btn_g.custom_minimum_size = Vector2(0, 40)
		btn_g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_g.add_theme_font_size_override("font_size", 12)
		btn_g.disabled = (i == Global.qualidade_grafica)
		hbox_graf.add_child(btn_g)
		btn_g.pressed.connect(func():
			Global.set_qualidade_grafica(i)
			_reabrir_settings())

	# ── Mostrar FPS ──
	var fps_btn := Button.new()
	fps_btn.custom_minimum_size = Vector2(0, 42)
	fps_btn.add_theme_font_size_override("font_size", 13)
	fps_btn.text = "Contador de FPS: " + ("✅ ATIVO" if Global.mostrar_fps else "❌ DESATIVADO")
	fps_btn.pressed.connect(func():
		Global.set_mostrar_fps(not Global.mostrar_fps)
		fps_btn.text = "Contador de FPS: " + ("✅ ATIVO" if Global.mostrar_fps else "❌ DESATIVADO"))
	vbox.add_child(fps_btn)

	# ── Seção Vibração ──
	if _is_touch_device:
		_adicionar_secao(vbox, "📳 Vibração")
		var vib_btn := Button.new()
		vib_btn.custom_minimum_size = Vector2(0, 44)
		vib_btn.add_theme_font_size_override("font_size", 14)
		vib_btn.text = "Vibração: " + ("✅ ATIVA" if Global.vibracao_ativa else "❌ DESATIVADA")
		vib_btn.pressed.connect(func():
			Global.vibracao_ativa = not Global.vibracao_ativa
			vib_btn.text = "Vibração: " + ("✅ ATIVA" if Global.vibracao_ativa else "❌ DESATIVADA")
			Global.save_game())
		vbox.add_child(vib_btn)

	# ── Seção Estatísticas ──
	_adicionar_secao(vbox, "📊 Estatísticas")
	var stats := Label.new()
	stats.text = "⏱️ Tempo total: " + Global.formatar_tempo(Global.tempo_jogado) + "\n"
	stats.text += "👆 Cliques: " + Global.formatar_numero(float(Global.cliques_totais)) + "\n"
	stats.text += "🎵 Notas totais: " + Global.formatar_numero(Global.notas_totais) + "\n"
	stats.text += "🏆 Discos: " + str(Global.discos_de_ouro) + "\n"
	stats.text += "🏅 Conquistas: %d/%d" % [Global.contar_conquistas(), Global.dados_conquistas.size()]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	vbox.add_child(stats)

	# ── Seção Perigo ──
	_adicionar_secao(vbox, "⚠️ Zona de Perigo")
	var reset_btn := Button.new()
	reset_btn.custom_minimum_size = Vector2(0, 44)
	reset_btn.add_theme_font_size_override("font_size", 14)
	reset_btn.text = "🗑️ Resetar Save (apaga tudo)"
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0.5, 0.1, 0.1, 0.9)
	reset_style.corner_radius_top_left = 6
	reset_style.corner_radius_top_right = 6
	reset_style.corner_radius_bottom_left = 6
	reset_style.corner_radius_bottom_right = 6
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.pressed.connect(_confirmar_reset_duplo)
	vbox.add_child(reset_btn)

		# ── Seção Sair do Jogo ──
	_adicionar_secao(vbox, "🚪 Sair")
	
	var sair_btn := Button.new()
	sair_btn.custom_minimum_size = Vector2(0, 48)
	sair_btn.add_theme_font_size_override("font_size", 15)
	sair_btn.text = "Sair do Jogo (Salvar e Fechar)"
	
	# Estilo do botão (cinza escuro)
	var sair_style := StyleBoxFlat.new()
	sair_style.bg_color = Color(0.279, 0.279, 0.343, 0.9)
	sair_style.corner_radius_top_left = 6
	sair_style.corner_radius_top_right = 6
	sair_style.corner_radius_bottom_left = 6
	sair_style.corner_radius_bottom_right = 6
	sair_btn.add_theme_stylebox_override("normal", sair_style)
	
	sair_btn.pressed.connect(_sair_do_jogo)
	vbox.add_child(sair_btn)

	# Animação de entrada
	_settings_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_settings_overlay, "modulate:a", 1.0, 0.2)

func _adicionar_secao(parent: VBoxContainer, titulo: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var label := Label.new()
	label.text = titulo
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("#7df9ff"))
	parent.add_child(label)

func _adicionar_slider(parent: VBoxContainer, rotulo: String, valor: float,
		min_v: float, max_v: float, step: float, ao_mudar: Callable) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = rotulo
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.custom_minimum_size = Vector2(140, 0)
	hbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = valor
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 32)
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(valor * 100.0) if max_v <= 1.0 and min_v >= 0.0 else "%.2f" % valor
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	slider.value_changed.connect(func(v):
		val_lbl.text = "%d%%" % int(v * 100.0) if max_v <= 1.0 and min_v >= 0.0 else "%.2f" % v
		ao_mudar.call(v))

func _adicionar_botoes_tela(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	parent.add_child(hbox)

	var modo_atual: int = Global.modo_tela
	var rotulos: Array[String] = ["🪟 Janela", "🖥️ Fullscreen", "⛶ Sem Borda"]
	var botoes: Array[Button] = []

	for i in range(3):
		var btn := Button.new()
		btn.text = rotulos[i]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = (i == modo_atual)
		hbox.add_child(btn)
		botoes.append(btn)
		btn.pressed.connect(func():
			Global.set_modo_tela(i)
			_reabrir_settings())

func _reabrir_settings() -> void:
	if _settings_overlay and is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()
		_settings_overlay = null
	await get_tree().create_timer(0.1).timeout
	_abrir_settings()

func _confirmar_reset_duplo() -> void:
	var dialog1 := ConfirmationDialog.new()
	dialog1.title = "⚠️ Resetar Save?"
	dialog1.dialog_text = "Isso apagará TODO o progresso:\n"
	dialog1.dialog_text += "• Notas, upgrades, melhorias\n"
	dialog1.dialog_text += "• Discos, conquistas, estágio\n"
	dialog1.dialog_text += "• Estatísticas\n\n"
	dialog1.dialog_text += "Esta ação NÃO pode ser desfeita."
	dialog1.ok_button_text = "Continuar"
	dialog1.cancel_button_text = "Cancelar"
	dialog1.confirmed.connect(_confirmar_reset_final)
	add_child(dialog1)
	dialog1.popup_centered()

func _confirmar_reset_final() -> void:
	var dialog2 := ConfirmationDialog.new()
	dialog2.title = "⚠️ TEM CERTEZA?"
	dialog2.dialog_text = "Última chance! Todos os dados serão PERDIDOS."
	dialog2.ok_button_text = "SIM, RESETAR"
	dialog2.cancel_button_text = "Não, cancelar"
	dialog2.confirmed.connect(func():
		Global.resetar_save()
		if _settings_overlay and is_instance_valid(_settings_overlay):
			_settings_overlay.queue_free()
			_settings_overlay = null
		get_tree().reload_current_scene())
	add_child(dialog2)
	dialog2.popup_centered()

# =====================================================================
# [BLOCO 10] — BREAKPOINTS DE RESPONSIVIDADE
# =====================================================================
func _ajustar_breakpoint() -> void:
	var w: float = get_viewport_rect().size.x
	var escala: float = 1.0
	var tam_card: int = 110

	if w < 400:
		escala = 0.85       # Celulares muito pequenos
		tam_card = 100
	elif w < 800:
		escala = 1.0        # Celulares normais (padrão)
	elif w < 1200:
		escala = 1.15       # Tablets
		tam_card = 120
	else:
		escala = 1.25       # Desktop / Monitores grandes
		tam_card = 130

	# Aplica a escala nas fontes (Theme Override)
	var theme = get_theme()
	if theme:
		theme.default_font_size = int(16 * escala)
		# Aumenta o tamanho mínimo dos cards
		var tabs: TabContainer = $SafeArea/Root/Bottom/BottomMargin/Tabs
		if tabs:
			for tab in tabs.get_children():
				var container = tab.get_node_or_null("CardsContainer")
				if container:
					for card in container.get_children():
						if card is PanelContainer:
							card.custom_minimum_size.y = tam_card

# =====================================================================
# [BLOCO 10] — SAIR DO JOGO
# =====================================================================
func _sair_do_jogo() -> void:
	# Salva o progresso antes de fechar
	Global.save_game()
	
	# Fecha o jogo (funciona tanto no PC quanto no Celular)
	get_tree().quit()

# =====================================================================
# CONTADOR DE FPS E OTIMIZAÇÃO GRÁFICA
# =====================================================================
func _setup_fps_counter() -> void:
	_fps_label = Label.new()
	_fps_label.name = "FPSCounter"
	_fps_label.text = "FPS: 60"
	_fps_label.add_theme_font_size_override("font_size", 14)
	_fps_label.add_theme_color_override("font_color", Color("#7dff7d"))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.position = Vector2(16, 16)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = Global.mostrar_fps
	add_child(_fps_label)

func _process(_delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _on_graficos_alterados(nivel: int) -> void:
	if nivel == 0 and _frenesi_border and _frenesi_border.visible:
		if _frenesi_tween and _frenesi_tween.is_valid():
			_frenesi_tween.kill()
		_frenesi_border.modulate.a = 0.85
