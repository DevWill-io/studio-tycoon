extends Node
## =====================================================================
## GLOBAL.GD — Estado, Fórmulas, Save/Load, Offline, NPS, Groove, Frenesi,
##             Estágios Visuais e Prestígio
## Blocos cobertos: 1, 2, 5, 6, 7
## =====================================================================

# ============ SINAIS ============
signal notas_alteradas
signal upgrade_comprado(tipo: String, index: int)
signal estado_atualizado
signal progresso_offline_calculado(segundos: int, ganho: float)
signal groove_alterada(valor: float)
signal frenesi_alterado(ativo: bool)
signal estagio_alterado(novo_estagio: int)
signal prestigio_executado(discos_ganhos: int)
signal conquista_desbloqueada(index: int)
signal modo_tela_alterado(modo: int)          
signal escala_ui_alterada(escala: float)           
signal album_diamante_comprado_signal

# ============ CONSTANTES GERAIS ============
const SAVE_PATH: String = "user://save_studio_tycoon.json"
const SAVE_VERSAO: int = 1
const MULTIPLICADOR_CRESCIMENTO: float = 1.15
const AUTO_SAVE_INTERVALO: float = 30.0
const LIMITE_OFFLINE_SEGUNDOS: int = 28_800
const TAXA_PROGRESSO_OFFLINE: float = 0.5
const CUSTO_ALBUM_DIAMANTE: float = 1_000_000_000_000.0
const PRESTIGIO_MINIMO: float = 1_000_000.0
const INTERVALO_NPS: float = 0.25

# ─── Groove / Frenesi / Golden ───
const GROOVE_MAX: float = 100.0
const GROOVE_ADD_POR_CLIQUE: float = 5.0
const GROOVE_DECAY_DELAY: float = 1.5
const GROOVE_DECAY_POR_SEG: float = 15.0
const GROOVE_THRESHOLD_1: float = 50.0
const GROOVE_MULT_1: float = 1.5
const GROOVE_MULT_2: float = 2.0
const FRENESI_DURACAO: float = 25.0
const FRENESI_MULT: float = 3.0
const GOLDEN_INTERVALO_MIN: float = 75.0
const GOLDEN_INTERVALO_MAX: float = 120.0
const GOLDEN_DURACAO: float = 10.0
const GOLDEN_DURACAO_HITVIRAL_BONUS: float = 5.0
const GOLDEN_HITVIRAL_SPEEDUP: float = 0.70
const GOLDEN_CHANCE_FRENESI: float = 0.5

# ============ ESTADO DO JOGADOR ============
var notas: float = 0.0
var notas_totais: float = 0.0
var notas_ganhas_na_run: float = 0.0
var discos_de_ouro: int = 0

var cliques_totais: int = 0
var tempo_jogado: float = 0.0
var notas_douradas_clicadas: int = 0

var niveis_equipamentos: Array[int] = []
var niveis_equipe: Array[int] = []
var melhorias_compradas: Array[bool] = []
var conquistas_desbloqueadas: Array[bool] = []

var album_diamante_comprado: bool = false
var estagio_atual: int = 0

# Persistência & Preferências
var ultimo_timestamp: int = 0
var volume_bgm: float = 1.0
var volume_sfx: float = 1.0
var vibracao_ativa: bool = true

# ─── [BLOCO 9] Preferências de tela/interface ───
var modo_tela: int = 0           # 0 = windowed · 1 = fullscreen · 2 = borderless
var escala_ui: float = 1.0       # 0.85 a 1.25

# Timers
var _timer_autosave: Timer = null
var _timer_nps: Timer = null
var _dados_offline_pendentes: Dictionary = {}

# Groove / Frenesi (transientes)
var groove: float = 0.0
var groove_idle_time: float = 0.0
var frenesi_timer: float = 0.0

# ============ CONFIGURAÇÕES DE GRÁFICOS E FPS ============
# 0 = Baixo, 1 = Médio, 2 = Alto
var qualidade_grafica: int = 2
var mostrar_fps: bool = false

signal graficos_alterados(nivel: int)
signal mostrar_fps_alterado(ativo: bool)

func set_qualidade_grafica(nivel: int) -> void:
	qualidade_grafica = clamp(nivel, 0, 2)
	aplicar_configuracoes_graficas()
	graficos_alterados.emit(qualidade_grafica)
	save_game()

func set_mostrar_fps(ativo: bool) -> void:
	mostrar_fps = ativo
	mostrar_fps_alterado.emit(mostrar_fps)
	save_game()

func aplicar_configuracoes_graficas() -> void:
	match qualidade_grafica:
		0: # BAIXO
			Engine.max_fps = 30
		1: # MÉDIO
			Engine.max_fps = 60
		2: # ALTO
			Engine.max_fps = 0 # Livre (máximo da tela)

# ============ DADOS DE CONTEÚDO ============
var dados_equipamentos: Array[Dictionary] = [
	{"nome": "Palheta de Carbono",            "custo_base": 15.0,         "bonus": 1.0,     "icone": "🎸"},
	{"nome": "Encordoamento de Aço",          "custo_base": 120.0,        "bonus": 6.0,     "icone": "🎼"},
	{"nome": "Cabo Blindado & Afinador",      "custo_base": 900.0,        "bonus": 35.0,    "icone": "🔌"},
	{"nome": "Pedaleira Multi-Efeitos",       "custo_base": 6_500.0,      "bonus": 180.0,   "icone": "🎛️"},
	{"nome": "Microfone Condensador",         "custo_base": 48_000.0,     "bonus": 950.0,   "icone": "🎙️"},
	{"nome": "Interface de Áudio Valvulada",  "custo_base": 380_000.0,    "bonus": 5_200.0, "icone": "🔊"},
	{"nome": "Guitarra Custom Shop",          "custo_base": 3_200_000.0,  "bonus": 28_000.0,"icone": "🎸"},
	{"nome": "Console Analógico Lendário",    "custo_base": 28_000_000.0, "bonus": 160_000.0,"icone": "🎚️"},
]

var dados_equipe: Array[Dictionary] = [
	{"nome": "Pedal de Loop",                 "custo_base": 50.0,        "bonus": 2.0,      "icone": "🔁"},
	{"nome": "Metrônomo Inteligente",         "custo_base": 400.0,       "bonus": 14.0,     "icone": "⏱️"},
	{"nome": "Baterista Freelancer",          "custo_base": 3_000.0,     "bonus": 85.0,     "icone": "🥁"},
	{"nome": "Baixista de Estúdio",           "custo_base": 22_000.0,    "bonus": 450.0,    "icone": "🎸"},
	{"nome": "Engenheiro de Mixagem",         "custo_base": 175_000.0,   "bonus": 2_400.0,  "icone": "🎚️"},
	{"nome": "Produtor Executivo",            "custo_base": 1_400_000.0, "bonus": 13_500.0, "icone": "💼"},
	{"nome": "Orquestra Sinfônica Contratada","custo_base": 12_000_000.0,"bonus": 78_000.0, "icone": "🎻"},
	{"nome": "Algoritmo Global de Streaming", "custo_base": 110_000_000.0,"bonus":450_000.0,"icone": "📡"},
]

var dados_melhorias: Array[Dictionary] = [
	{"nome": "Técnica de Dedilhado",         "custo": 500.0,          "efeito": "equip_bonus_x",   "alvo": 0, "valor": 2.0,  "icone": "🎯", "desc": "Dobra a Palheta de Carbono."},
	{"nome": "Acústica Caseira",             "custo": 2_500.0,        "efeito": "equipe_bonus_x",  "alvo": 0, "valor": 2.0,  "icone": "🏠", "desc": "Dobra o NPS do Pedal de Loop."},
	{"nome": "Café Expresso Duplo",          "custo": 10_000.0,       "efeito": "crit_chance_set", "alvo": -1,"valor": 0.10, "icone": "☕", "desc": "Chance de crítico: 5% → 10%."},
	{"nome": "Ensaio na Madrugada",          "custo": 45_000.0,       "efeito": "equipe_grupo_x",  "alvo": -1,"valor": 2.0,  "icone": "🌙", "desc": "Dobra Baterista e Baixista."},
	{"nome": "Solo Inspirado",               "custo": 150_000.0,      "efeito": "crit_mult_set",   "alvo": -1,"valor": 10.0, "icone": "⭐", "desc": "Crítico passa de 5x → 10x."},
	{"nome": "Acústica Tratada",             "custo": 600_000.0,      "efeito": "nps_percent",     "alvo": -1,"valor": 0.25, "icone": "🧱", "desc": "+25% em todo NPS."},
	{"nome": "Masterização Analógica",       "custo": 2_500_000.0,    "efeito": "equip_grupo_x",   "alvo": -1,"valor": 2.0,  "icone": "🎚️", "desc": "Dobra Microfone e Interface."},
	{"nome": "Hit Viral nas Redes",          "custo": 12_000_000.0,   "efeito": "golden_boost",    "alvo": -1,"valor": 0.30, "icone": "📱", "desc": "Notas Douradas +30% freq / +5s."},
	{"nome": "Turnê Nacional",               "custo": 65_000_000.0,   "efeito": "global_percent",  "alvo": -1,"valor": 0.50, "icone": "🚌", "desc": "+50% produção global."},
	{"nome": "Selo Independente",            "custo": 350_000_000.0,  "efeito": "equip_to_nps",    "alvo": -1,"valor": 0.01, "icone": "💿", "desc": "Cada nível de equip. +1% NPS."},
	{"nome": "Patrocínio de Marca Famosa",   "custo": 2_000_000_000.0,"efeito": "equip_grupo_x",   "alvo": -1,"valor": 2.0,  "icone": "🥤", "desc": "Dobra Guitarra e Console."},
	{"nome": "Lenda Viva da Música",         "custo": 25_000_000_000.0,"efeito":"global_x",        "alvo": -1,"valor": 3.0,  "icone": "👑", "desc": "Multiplica produção global por 3x."},
]

var dados_conquistas: Array[Dictionary] = [
	{"nome": "Primeiro Acorde",           "icone": "🎵", "desc": "Dê 1 clique."},
	{"nome": "Dedo de Ferro",             "icone": "💪", "desc": "Dê 1.000 cliques."},
	{"nome": "Maratonista do Ritmo",      "icone": "🏃", "desc": "Dê 10.000 cliques."},
	{"nome": "Primeira Melodia",          "icone": "🎶", "desc": "Acumule 1.000 notas."},
	{"nome": "Artista Local",             "icone": "📍", "desc": "Acumule 100.000 notas."},
	{"nome": "Fenômeno Indie",            "icone": "🌟", "desc": "Acumule 10 milhões de notas."},
	{"nome": "Estrela do Rock/Pop",       "icone": "🎤", "desc": "Acumule 1 bilhão de notas."},
	{"nome": "Magnata da Música",         "icone": "💎", "desc": "Acumule 100 bilhões de notas."},
	{"nome": "Automação Iniciada",        "icone": "⚙️", "desc": "Atinja 100 NPS."},
	{"nome": "Fábrica de Hits",           "icone": "🏭", "desc": "Atinja 100.000 NPS."},
	{"nome": "Colecionador",              "icone": "🎁", "desc": "Nível 10 em todos os 8 equipamentos."},
	{"nome": "Banda Completa",            "icone": "🎺", "desc": "Contrate 1 de cada item de equipe."},
	{"nome": "Caçador de Inspiração",     "icone": "🔮", "desc": "Clique em 5 Notas Douradas."},
	{"nome": "Disco de Ouro",             "icone": "🏆", "desc": "Faça o primeiro Prestígio."},
	{"nome": "Obra-Prima Eterna",         "icone": "👑", "desc": "Grave o Álbum de Diamante."},
]

var dados_estagios: Array[Dictionary] = [
	{"nome": "Quarto Simples", "threshold": 0.0, "icone": "🎸",
	 "cor_top": Color("#1a1a2e"), "cor_bottom": Color("#16213e"),
	 "descricao": "Um violão encostado na cama e um notebook antigo."},
	{"nome": "Garagem Acústica", "threshold": 15_000.0, "icone": "🎸",
	 "cor_top": Color("#2e1a1a"), "cor_bottom": Color("#3e1616"),
	 "descricao": "Caixas de ovo na parede e um amplificador usado."},
	{"nome": "Home Studio Indie", "threshold": 1_500_000.0, "icone": "🎹",
	 "cor_top": Color("#1a2e26"), "cor_bottom": Color("#163e21"),
	 "descricao": "Placa de áudio, monitores e um teclado MIDI."},
	{"nome": "Estúdio Profissional", "threshold": 250_000_000.0, "icone": "🎙️",
	 "cor_top": Color("#1a1a3e"), "cor_bottom": Color("#16163e"),
	 "descricao": "Sala isolada e uma grande mesa de som."},
	{"nome": "Gravadora & Arena Mundial", "threshold": 25_000_000_000.0, "icone": "🎤",
	 "cor_top": Color("#2e1a3e"), "cor_bottom": Color("#3e162e"),
	 "descricao": "Estrutura completa de gravadora e turnês mundiais."},
]

# ============ READY ============
func _ready() -> void:
	_inicializar_estado()
	_configurar_autosave()
	_configurar_timer_nps()
	if FileAccess.file_exists(SAVE_PATH):
		load_game()
		_calcular_progresso_offline()
	else:
		ultimo_timestamp = int(Time.get_unix_time_from_system())
	estagio_atual = _calcular_estagio()
	verificar_conquistas()
	aplicar_modo_tela()
	aplicar_escala_ui()
	set_process(true)
	print("[Global] Inicializado. Save=%s  Offline pendente=%s  Estágio=%d  ModoTela=%d  EscalaUI=%.2f" % [
		FileAccess.file_exists(SAVE_PATH),
		str(not _dados_offline_pendentes.is_empty()),
		estagio_atual,
		modo_tela,
		escala_ui
	])

func _process(delta: float) -> void:
	tempo_jogado += delta
	_processar_groove(delta)
	_processar_frenesi(delta)

func _inicializar_estado() -> void:
	niveis_equipamentos.resize(dados_equipamentos.size())
	for i in range(niveis_equipamentos.size()): niveis_equipamentos[i] = 0

	niveis_equipe.resize(dados_equipe.size())
	for i in range(niveis_equipe.size()): niveis_equipe[i] = 0

	melhorias_compradas.resize(dados_melhorias.size())
	for i in range(melhorias_compradas.size()): melhorias_compradas[i] = false

	conquistas_desbloqueadas.resize(dados_conquistas.size())
	for i in range(conquistas_desbloqueadas.size()): conquistas_desbloqueadas[i] = false

	estagio_atual = 0

# ============ FÓRMULAS ============
func calcular_custo_unitario(custo_base: float, nivel: int) -> float:
	return floor(custo_base * pow(MULTIPLICADOR_CRESCIMENTO, nivel))

func calcular_custo_lote(custo_base: float, nivel: int, quantidade: int) -> float:
	if quantidade <= 0: return 0.0
	var fator_nivel: float = pow(MULTIPLICADOR_CRESCIMENTO, nivel)
	var fator_qtd: float = pow(MULTIPLICADOR_CRESCIMENTO, quantidade) - 1.0
	return floor(custo_base * fator_nivel * fator_qtd / (MULTIPLICADOR_CRESCIMENTO - 1.0))

func calcular_max_compravel(custo_base: float, nivel: int, notas_disponiveis: float) -> int:
	if notas_disponiveis < calcular_custo_unitario(custo_base, nivel): return 0
	var fator_nivel: float = pow(MULTIPLICADOR_CRESCIMENTO, nivel)
	var num: float = notas_disponiveis * (MULTIPLICADOR_CRESCIMENTO - 1.0) / (custo_base * fator_nivel) + 1.0
	var n: int = int(floor(log(num) / log(MULTIPLICADOR_CRESCIMENTO)))
	while calcular_custo_lote(custo_base, nivel, n + 1) <= notas_disponiveis: n += 1
	while n > 0 and calcular_custo_lote(custo_base, nivel, n) > notas_disponiveis: n -= 1
	return n

func get_multiplicador_prestigio() -> float:
	return 1.0 + float(discos_de_ouro) * 0.15

func get_multiplicador_conquistas() -> float:
	var count: int = 0
	for c in conquistas_desbloqueadas:
		if c: count += 1
	return 1.0 + float(count) * 0.02

# ============ GETTERS DE MELHORIAS ============
func _melhoria_ativa(index_mel: int) -> bool:
	return index_mel >= 0 and index_mel < melhorias_compradas.size() and melhorias_compradas[index_mel]

func get_mult_equipamento(index_equip: int) -> float:
	var m: float = 1.0
	if _melhoria_ativa(0) and index_equip == 0: m *= 2.0
	if _melhoria_ativa(6) and (index_equip == 4 or index_equip == 5): m *= 2.0
	if _melhoria_ativa(10) and (index_equip == 6 or index_equip == 7): m *= 2.0
	return m

func get_mult_equipe(index_eq: int) -> float:
	var m: float = 1.0
	if _melhoria_ativa(1) and index_eq == 0: m *= 2.0
	if _melhoria_ativa(3) and (index_eq == 2 or index_eq == 3): m *= 2.0
	return m

func get_mult_global() -> float:
	var m: float = 1.0
	if _melhoria_ativa(8):  m *= 1.5
	if _melhoria_ativa(11): m *= 3.0
	return m

func get_crit_chance() -> float:
	if _melhoria_ativa(2): return 0.10
	return 0.05

func get_crit_mult() -> float:
	if _melhoria_ativa(4): return 10.0
	return 5.0

func get_golden_boost() -> float:
	if _melhoria_ativa(7): return 0.30
	return 0.0

# ============ PRODUÇÃO ============
func calcular_notas_por_clique() -> float:
	var base: float = 1.0
	for i in range(dados_equipamentos.size()):
		var bonus: float = float(dados_equipamentos[i]["bonus"]) \
						* float(niveis_equipamentos[i]) \
						* get_mult_equipamento(i)
		base += bonus
	return base \
		* get_multiplicador_prestigio() \
		* get_multiplicador_conquistas() \
		* get_mult_global() \
		* get_groove_mult() \
		* get_frenesi_mult()

func calcular_nps() -> float:
	var base: float = 0.0
	for i in range(dados_equipe.size()):
		var bonus: float = float(dados_equipe[i]["bonus"]) \
						* float(niveis_equipe[i]) \
						* get_mult_equipe(i)
		base += bonus

	if _melhoria_ativa(9):
		var total_niveis_equip: int = 0
		for n in niveis_equipamentos: total_niveis_equip += n
		base *= 1.0 + float(total_niveis_equip) * 0.01

	var mult_especifico: float = 1.0
	if _melhoria_ativa(5): mult_especifico *= 1.25

	return base \
		* mult_especifico \
		* get_multiplicador_prestigio() \
		* get_multiplicador_conquistas() \
		* get_mult_global() \
		* get_frenesi_mult()

# ============ COMPRAS ============
func comprar_equipamento(index: int, quantidade: int) -> int:
	if index < 0 or index >= dados_equipamentos.size(): return 0
	var d: Dictionary = dados_equipamentos[index]
	var nivel: int = niveis_equipamentos[index]
	var qtd: int = _resolver_quantidade(d["custo_base"], nivel, quantidade)
	if qtd <= 0: return 0
	var custo: float = calcular_custo_lote(d["custo_base"], nivel, qtd)
	if custo > notas: return 0
	notas -= custo
	niveis_equipamentos[index] += qtd
	upgrade_comprado.emit("equipamento", index)
	verificar_conquistas()
	estado_atualizado.emit()
	return qtd

func comprar_equipe(index: int, quantidade: int) -> int:
	if index < 0 or index >= dados_equipe.size(): return 0
	var d: Dictionary = dados_equipe[index]
	var nivel: int = niveis_equipe[index]
	var qtd: int = _resolver_quantidade(d["custo_base"], nivel, quantidade)
	if qtd <= 0: return 0
	var custo: float = calcular_custo_lote(d["custo_base"], nivel, qtd)
	if custo > notas: return 0
	notas -= custo
	niveis_equipe[index] += qtd
	upgrade_comprado.emit("equipe", index)
	verificar_conquistas()
	estado_atualizado.emit()
	return qtd

func comprar_melhoria(index: int) -> bool:
	if index < 0 or index >= dados_melhorias.size(): return false
	if melhorias_compradas[index]: return false
	var custo: float = dados_melhorias[index]["custo"]
	if notas < custo: return false
	notas -= custo
	melhorias_compradas[index] = true
	upgrade_comprado.emit("melhoria", index)
	verificar_conquistas()
	estado_atualizado.emit()
	return true

func _resolver_quantidade(custo_base: float, nivel: int, quantidade: int) -> int:
	if quantidade == -1:
		return calcular_max_compravel(custo_base, nivel, notas)
	return max(quantidade, 0)

# ============ FORMATAÇÃO ============
func formatar_numero(valor: float) -> String:
	if valor < 0.0: return "-" + formatar_numero(-valor)
	if valor < 1000.0: return str(int(valor))
	var sufixos: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
	var v: float = valor
	var idx: int = 0
	while v >= 1000.0 and idx < sufixos.size() - 1:
		v /= 1000.0
		idx += 1
	if v >= 100.0:
		return "%.1f%s" % [v, sufixos[idx]]
	return "%.2f%s" % [v, sufixos[idx]]

func formatar_nps() -> String:
	return formatar_numero(calcular_nps()) + "/s"

# ============ HELPERS DE ESTADO ============
func adicionar_notas(valor: float) -> void:
	if valor <= 0.0: return
	notas += valor
	notas_totais += valor
	notas_ganhas_na_run += valor
	_verificar_estagio()
	verificar_conquistas()
	notas_alteradas.emit()

func gastar_notas(valor: float) -> bool:
	if valor > notas: return false
	notas -= valor
	notas_alteradas.emit()
	return true

# =====================================================================
# TIMERS
# =====================================================================
func _configurar_autosave() -> void:
	if _timer_autosave != null: return
	_timer_autosave = Timer.new()
	_timer_autosave.name = "AutoSaveTimer"
	_timer_autosave.wait_time = AUTO_SAVE_INTERVALO
	_timer_autosave.autostart = true
	_timer_autosave.one_shot = false
	_timer_autosave.timeout.connect(save_game)
	add_child(_timer_autosave)

func _configurar_timer_nps() -> void:
	if _timer_nps != null: return
	_timer_nps = Timer.new()
	_timer_nps.name = "TimerNPS"
	_timer_nps.wait_time = INTERVALO_NPS
	_timer_nps.autostart = true
	_timer_nps.one_shot = false
	_timer_nps.timeout.connect(_aplicar_nps_passivo)
	add_child(_timer_nps)

func _aplicar_nps_passivo() -> void:
	var nps: float = calcular_nps()
	if nps <= 0.0: return
	adicionar_notas(nps * INTERVALO_NPS)

# =====================================================================
# GROOVE / FRENESI
# =====================================================================
func _processar_groove(delta: float) -> void:
	if groove <= 0.0: return
	groove_idle_time += delta
	if groove_idle_time > GROOVE_DECAY_DELAY:
		var antes: float = groove
		groove = max(0.0, groove - GROOVE_DECAY_POR_SEG * delta)
		if groove != antes:
			groove_alterada.emit(groove)

func _processar_frenesi(delta: float) -> void:
	if frenesi_timer <= 0.0: return
	frenesi_timer -= delta
	if frenesi_timer <= 0.0:
		frenesi_timer = 0.0
		frenesi_alterado.emit(false)

func adicionar_groove() -> void:
	groove = min(GROOVE_MAX, groove + GROOVE_ADD_POR_CLIQUE)
	groove_idle_time = 0.0
	groove_alterada.emit(groove)

func get_groove_mult() -> float:
	if groove >= GROOVE_MAX: return GROOVE_MULT_2
	if groove >= GROOVE_THRESHOLD_1: return GROOVE_MULT_1
	return 1.0

func ativar_frenesi() -> void:
	frenesi_timer = FRENESI_DURACAO
	frenesi_alterado.emit(true)

func get_frenesi_mult() -> float:
	return FRENESI_MULT if frenesi_timer > 0.0 else 1.0

# =====================================================================
# NOTA DOURADA
# =====================================================================
func aplicar_bonus_golden() -> Dictionary:
	notas_douradas_clicadas += 1
	verificar_conquistas()
	if randf() < GOLDEN_CHANCE_FRENESI:
		ativar_frenesi()
		return {"tipo": "frenesi", "duracao": FRENESI_DURACAO}
	var bonus_instant: float = max(notas * 0.15, calcular_nps() * 60.0)
	adicionar_notas(bonus_instant)
	return {"tipo": "bonus", "valor": bonus_instant}

func calcular_golden_intervalo() -> float:
	var base: float = randf_range(GOLDEN_INTERVALO_MIN, GOLDEN_INTERVALO_MAX)
	if _melhoria_ativa(7):
		base *= GOLDEN_HITVIRAL_SPEEDUP
	return base

func calcular_golden_duracao() -> float:
	var base: float = GOLDEN_DURACAO
	if _melhoria_ativa(7):
		base += GOLDEN_DURACAO_HITVIRAL_BONUS
	return base

# =====================================================================
# ESTÁGIOS VISUAIS
# =====================================================================
func _calcular_estagio() -> int:
	var idx: int = 0
	for i in range(dados_estagios.size()):
		if notas_totais >= float(dados_estagios[i]["threshold"]):
			idx = i
	return idx

func _verificar_estagio() -> void:
	var novo: int = _calcular_estagio()
	if novo != estagio_atual:
		estagio_atual = novo
		estagio_alterado.emit(novo)

func get_estagio() -> Dictionary:
	return dados_estagios[estagio_atual]

func get_proximo_estagio() -> Dictionary:
	if estagio_atual >= dados_estagios.size() - 1:
		return {}
	return dados_estagios[estagio_atual + 1]

# =====================================================================
# PRESTÍGIO ("Lançar Álbum")
# =====================================================================
func pode_prestigiar() -> bool:
	return notas_ganhas_na_run >= PRESTIGIO_MINIMO

func calcular_discos_prestigio() -> int:
	if notas_ganhas_na_run < PRESTIGIO_MINIMO:
		return 0
	return int(floor(sqrt(notas_ganhas_na_run / PRESTIGIO_MINIMO)))

func executar_prestigio() -> int:
	if not pode_prestigiar():
		return 0
	var discos_ganhos: int = calcular_discos_prestigio()
	discos_de_ouro += discos_ganhos

	# Reset (mantém notas_totais, discos, conquistas, estágio, stats)
	notas = 0.0
	notas_ganhas_na_run = 0.0

	for i in range(niveis_equipamentos.size()): niveis_equipamentos[i] = 0
	for i in range(niveis_equipe.size()): niveis_equipe[i] = 0
	for i in range(melhorias_compradas.size()): melhorias_compradas[i] = false

	groove = 0.0
	groove_idle_time = 0.0
	frenesi_timer = 0.0

	estado_atualizado.emit()
	notas_alteradas.emit()
	groove_alterada.emit(0.0)
	frenesi_alterado.emit(false)
	prestigio_executado.emit(discos_ganhos)
	verificar_conquistas()
	save_game()

	print("[Global] PRESTÍGIO! +%d discos (total: %d). Multiplicador: +%d%%" % [
		discos_ganhos, discos_de_ouro, int(discos_de_ouro * 15.0)
	])
	return discos_ganhos

# =====================================================================
# SAVE / LOAD
# =====================================================================
func save_game() -> void:
	var dados: Dictionary = {
		"versao": SAVE_VERSAO,
		"notas": notas,
		"notas_totais": notas_totais,
		"notas_ganhas_na_run": notas_ganhas_na_run,
		"discos_de_ouro": discos_de_ouro,
		"cliques_totais": cliques_totais,
		"tempo_jogado": tempo_jogado,
		"notas_douradas_clicadas": notas_douradas_clicadas,
		"niveis_equipamentos": niveis_equipamentos.duplicate(),
		"niveis_equipe": niveis_equipe.duplicate(),
		"melhorias_compradas": melhorias_compradas.duplicate(),
		"conquistas_desbloqueadas": conquistas_desbloqueadas.duplicate(),
		"album_diamante_comprado": album_diamante_comprado,
		"estagio_atual": estagio_atual,
		"volume_bgm": volume_bgm,
		"volume_sfx": volume_sfx,
		"vibracao_ativa": vibracao_ativa,
		"modo_tela": modo_tela,
		"escala_ui": escala_ui,
		"qualidade_grafica": qualidade_grafica,
		"mostrar_fps": mostrar_fps,
		"ultimo_timestamp": int(Time.get_unix_time_from_system()),
	}
	var arquivo: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if arquivo == null:
		push_error("[Global] Falha ao gravar save: " + SAVE_PATH)
		return
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()
	ultimo_timestamp = int(Time.get_unix_time_from_system())

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var arquivo: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if arquivo == null: return false
	var texto: String = arquivo.get_as_text()
	arquivo.close()

	var parsed: Variant = JSON.parse_string(texto)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[Global] Save corrompido. Ignorando.")
		return false

	var d: Dictionary = parsed

	notas                = float(d.get("notas", 0.0))
	notas_totais         = float(d.get("notas_totais", 0.0))
	notas_ganhas_na_run  = float(d.get("notas_ganhas_na_run", 0.0))
	discos_de_ouro       = int(d.get("discos_de_ouro", 0))
	cliques_totais       = int(d.get("cliques_totais", 0))
	tempo_jogado         = float(d.get("tempo_jogado", 0.0))
	notas_douradas_clicadas = int(d.get("notas_douradas_clicadas", 0))
	album_diamante_comprado = bool(d.get("album_diamante_comprado", false))
	estagio_atual        = int(d.get("estagio_atual", 0))
	volume_bgm           = clamp(float(d.get("volume_bgm", 1.0)), 0.0, 1.0)
	volume_sfx           = clamp(float(d.get("volume_sfx", 1.0)), 0.0, 1.0)
	vibracao_ativa       = bool(d.get("vibracao_ativa", true))
	modo_tela            = int(d.get("modo_tela", 0))
	escala_ui            = clamp(float(d.get("escala_ui", 1.0)), 0.85, 1.50)
	qualidade_grafica = int(d.get("qualidade_grafica", 2))
	mostrar_fps = bool(d.get("mostrar_fps", false))
	aplicar_configuracoes_graficas()
	ultimo_timestamp     = int(d.get("ultimo_timestamp", 0))

	_aplicar_array_numerico(d.get("niveis_equipamentos", []), "equip")
	_aplicar_array_numerico(d.get("niveis_equipe", []), "equipe")
	_aplicar_array_bool(d.get("melhorias_compradas", []), "melhorias")
	_aplicar_array_bool(d.get("conquistas_desbloqueadas", []), "conquistas")

	estado_atualizado.emit()
	print("[Global] Save carregado. Notas=%s Discos=%d" % [formatar_numero(notas), discos_de_ouro])
	return true

func _aplicar_array_numerico(raw: Variant, tipo: String) -> void:
	var arr: Array = (raw as Array) if typeof(raw) == TYPE_ARRAY else []
	if tipo == "equip":
		for i in range(niveis_equipamentos.size()):
			niveis_equipamentos[i] = int(arr[i]) if i < arr.size() else 0
	else:
		for i in range(niveis_equipe.size()):
			niveis_equipe[i] = int(arr[i]) if i < arr.size() else 0

func _aplicar_array_bool(raw: Variant, tipo: String) -> void:
	var arr: Array = (raw as Array) if typeof(raw) == TYPE_ARRAY else []
	if tipo == "melhorias":
		for i in range(melhorias_compradas.size()):
			melhorias_compradas[i] = bool(arr[i]) if i < arr.size() else false
	else:
		for i in range(conquistas_desbloqueadas.size()):
			conquistas_desbloqueadas[i] = bool(arr[i]) if i < arr.size() else false

# =====================================================================
# PROGRESSO OFFLINE
# =====================================================================
func _calcular_progresso_offline() -> void:
	if ultimo_timestamp <= 0: return
	var agora: int = int(Time.get_unix_time_from_system())
	var diferenca: int = agora - ultimo_timestamp
	if diferenca <= 0: return

	var segundos_efetivos: int = min(diferenca, LIMITE_OFFLINE_SEGUNDOS)
	var nps: float = calcular_nps()
	var ganho: float = nps * TAXA_PROGRESSO_OFFLINE * float(segundos_efetivos)

	if ganho <= 0.0:
		ultimo_timestamp = agora
		return

	adicionar_notas(ganho)
	_dados_offline_pendentes = {"segundos": segundos_efetivos, "ganho": ganho}
	ultimo_timestamp = agora
	progresso_offline_calculado.emit(segundos_efetivos, ganho)
	print("[Global] Offline: %ds ausente → +%s notas." % [segundos_efetivos, formatar_numero(ganho)])

func consumir_offline_pendente() -> Dictionary:
	var d: Dictionary = _dados_offline_pendentes.duplicate()
	_dados_offline_pendentes.clear()
	return d

func tem_offline_pendente() -> bool:
	return not _dados_offline_pendentes.is_empty()

# =====================================================================
# CICLO DE VIDA
# =====================================================================
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, \
		NOTIFICATION_WM_GO_BACK_REQUEST, \
		NOTIFICATION_APPLICATION_PAUSED, \
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			save_game()

# =====================================================================
# RESET
# =====================================================================
func resetar_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	notas = 0.0
	notas_totais = 0.0
	notas_ganhas_na_run = 0.0
	discos_de_ouro = 0
	cliques_totais = 0
	tempo_jogado = 0.0
	notas_douradas_clicadas = 0
	album_diamante_comprado = false
	volume_bgm = 1.0
	volume_sfx = 1.0
	vibracao_ativa = true
	modo_tela = 0
	escala_ui = 1.0
	groove = 0.0
	groove_idle_time = 0.0
	frenesi_timer = 0.0
	ultimo_timestamp = int(Time.get_unix_time_from_system())
	_dados_offline_pendentes.clear()
	estagio_atual = 0
	_inicializar_estado()
	estado_atualizado.emit()
	notas_alteradas.emit()
	groove_alterada.emit(0.0)
	frenesi_alterado.emit(false)
	print("[Global] Save resetado.")

# =====================================================================
# HELPERS DE TEMPO
# =====================================================================
func formatar_tempo(segundos: float) -> String:
	var s: int = int(segundos)
	var h: int = int(s / 3600.0)          # Usando float para evitar warning
	var m: int = int((s % 3600) / 60.0)   # Usando float para evitar warning
	var seg: int = s % 60
	if h > 0:
		return "%dh %02dm %02ds" % [h, m, seg]
	return "%dm %02ds" % [m, seg]

# =====================================================================
# [BLOCO 8] — CONQUISTAS
# =====================================================================
func verificar_conquistas() -> void:
	if conquistas_desbloqueadas.size() < dados_conquistas.size():
		return

	var unlocks: Array[int] = []

	# 0: Primeiro Acorde — 1 clique
	if not conquistas_desbloqueadas[0] and cliques_totais >= 1:
		conquistas_desbloqueadas[0] = true; unlocks.append(0)
	# 1: Dedo de Ferro — 1.000 cliques
	if not conquistas_desbloqueadas[1] and cliques_totais >= 1_000:
		conquistas_desbloqueadas[1] = true; unlocks.append(1)
	# 2: Maratonista do Ritmo — 10.000 cliques
	if not conquistas_desbloqueadas[2] and cliques_totais >= 10_000:
		conquistas_desbloqueadas[2] = true; unlocks.append(2)
	# 3: Primeira Melodia — 1.000 notas
	if not conquistas_desbloqueadas[3] and notas_totais >= 1_000:
		conquistas_desbloqueadas[3] = true; unlocks.append(3)
	# 4: Artista Local — 100.000 notas
	if not conquistas_desbloqueadas[4] and notas_totais >= 100_000:
		conquistas_desbloqueadas[4] = true; unlocks.append(4)
	# 5: Fenômeno Indie — 10M notas
	if not conquistas_desbloqueadas[5] and notas_totais >= 10_000_000:
		conquistas_desbloqueadas[5] = true; unlocks.append(5)
	# 6: Estrela do Rock/Pop — 1B notas
	if not conquistas_desbloqueadas[6] and notas_totais >= 1_000_000_000:
		conquistas_desbloqueadas[6] = true; unlocks.append(6)
	# 7: Magnata da Música — 100B notas
	if not conquistas_desbloqueadas[7] and notas_totais >= 100_000_000_000:
		conquistas_desbloqueadas[7] = true; unlocks.append(7)
	# 8: Automação Iniciada — 100 NPS
	if not conquistas_desbloqueadas[8] and calcular_nps() >= 100:
		conquistas_desbloqueadas[8] = true; unlocks.append(8)
	# 9: Fábrica de Hits — 100.000 NPS
	if not conquistas_desbloqueadas[9] and calcular_nps() >= 100_000:
		conquistas_desbloqueadas[9] = true; unlocks.append(9)
	# 10: Colecionador — nível 10 em todos os 8 equipamentos
	if not conquistas_desbloqueadas[10]:
		var ok: bool = true
		for n in niveis_equipamentos:
			if n < 10: ok = false; break
		if ok:
			conquistas_desbloqueadas[10] = true; unlocks.append(10)
	# 11: Banda Completa — 1 de cada item de equipe
	if not conquistas_desbloqueadas[11]:
		var ok: bool = true
		for n in niveis_equipe:
			if n < 1: ok = false; break
		if ok:
			conquistas_desbloqueadas[11] = true; unlocks.append(11)
	# 12: Caçador de Inspiração — 5 Notas Douradas
	if not conquistas_desbloqueadas[12] and notas_douradas_clicadas >= 5:
		conquistas_desbloqueadas[12] = true; unlocks.append(12)
	# 13: Disco de Ouro — primeiro prestígio
	if not conquistas_desbloqueadas[13] and discos_de_ouro >= 1:
		conquistas_desbloqueadas[13] = true; unlocks.append(13)
	# 14: Obra-Prima Eterna — Álbum de Diamante
	if not conquistas_desbloqueadas[14] and album_diamante_comprado:
		conquistas_desbloqueadas[14] = true; unlocks.append(14)

	for idx in unlocks:
		conquista_desbloqueada.emit(idx)

	if unlocks.size() > 0:
		estado_atualizado.emit()

## Retorna a contagem atual de conquistas desbloqueadas.
func contar_conquistas() -> int:
	var c: int = 0
	for v in conquistas_desbloqueadas:
		if v: c += 1
	return c

## Retorna o bônus total em % (2% por conquista).
func get_bonus_conquistas_pct() -> int:
	return contar_conquistas() * 2

# =====================================================================
# [BLOCO 9] — MODO DE TELA (Windowed / Fullscreen / Borderless)
# =====================================================================
func aplicar_modo_tela() -> void:
	match modo_tela:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	modo_tela_alterado.emit(modo_tela)

func set_modo_tela(novo: int) -> void:
	novo = clamp(novo, 0, 2)
	if novo == modo_tela: return
	modo_tela = novo
	aplicar_modo_tela()
	save_game()

func toggle_fullscreen() -> void:
	if modo_tela == 1:
		set_modo_tela(0)
	else:
		set_modo_tela(1)

# =====================================================================
# [BLOCO 9] — ESCALA DA UI
# =====================================================================
func aplicar_escala_ui() -> void:
	var win: Window = get_window()
	if win == null: return
	
	# O content_scale_factor é um multiplicador DIRETO.
	# Se escala_ui for 1.50, a UI fica 50% MAIOR.
	win.content_scale_factor = clamp(escala_ui, 0.85, 1.50)
	
	escala_ui_alterada.emit(escala_ui)

func set_escala_ui(nova: float) -> void:
	nova = clamp(nova, 0.85, 1.50)
	if is_equal_approx(nova, escala_ui): return
	escala_ui = nova
	aplicar_escala_ui()
	save_game()

# =====================================================================
# [BLOCO 9] — ÁLBUM DE DIAMANTE (condição de vitória)
# =====================================================================
func pode_comprar_album_diamante() -> bool:
	if album_diamante_comprado: return false
	if estagio_atual < dados_estagios.size() - 1: return false
	return notas >= CUSTO_ALBUM_DIAMANTE

func comprar_album_diamante() -> bool:
	if not pode_comprar_album_diamante(): return false
	notas -= CUSTO_ALBUM_DIAMANTE
	album_diamante_comprado = true
	conquistas_desbloqueadas[14] = true
	conquista_desbloqueada.emit(14)
	album_diamante_comprado_signal.emit()
	estado_atualizado.emit()
	notas_alteradas.emit()
	save_game()
	print("[Global] 🏆 ÁLBUM DE DIAMANTE GRAVADO! Jogo zerado.")
	return true	
