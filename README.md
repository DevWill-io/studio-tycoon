# 🎸 Studio Tycoon (v1.0.6)

Um jogo *idle/clicker* de gestão de estúdio musical desenvolvido na **Godot 4.x (GDScript 2.0)**, projetado para rodar de forma fluida tanto no **PC (Windows/Linux)** quanto em **dispositivos móveis (Android)**.

Comece tocando em um quarto simples, invista em equipamentos, contrate uma equipe completa, evolua sua carreira musical até a **Gravadora & Arena Mundial** e grave o lendário **Álbum de Diamante**.

---

## ✨ Funcionalidades Principais

* **Gameplay Híbrido (Clique Ativo + Produção Passiva):** Toque no instrumento para gerar notas musicais instantaneamente (com suporte a *multitouch* de até 5 dedos otimizado) ou automatize seus ganhos com **Notas por Segundo (NPS)**.
* **Progressão Profunda:**
  * **8 Equipamentos** melhoráveis com compras em lote (`1x`, `10x` e `MAX`) calculadas via progressão geométrica exata.
  * **8 Membros de Equipe & Estúdio** que multiplicam sua produção passiva.
  * **12 Pesquisas Únicas** que desbloqueiam bônus permanentes de clique, críticos e produção global.
* **Sistemas Dinâmicos:**
  * **Barra de Groove & Acertos Críticos:** Mantenha o ritmo para multiplicar seus ganhos por clique.
  * **Nota Dourada & Modo Frenesi:** Eventos aleatórios na tela que concedem bônus imediatos ou ativam o **Show ao Vivo (`×3` produção)**.
  * **5 Estágios de Carreira:** Transições visuais de cenário conforme seu estúdio cresce.
* **Prestígio & Endgame:**
  * **Lançar Álbum (Prestígio):** Reinicie sua jornada a partir de 1M de notas para acumular **Discos de Ouro** (`+15%` de produção global por disco).
  * **Álbum de Diamante & Modo Infinito:** Conclua o objetivo principal com 1 Trilhão de notas e continue batendo recordes.
  * **15 Conquistas:** Cada conquista desbloqueada concede `+2%` de bônus permanente.
* **Ganhos Offline & Persistência:**
  * Auto-save automático a cada 30 segundos e ao fechar/pausar o app em `user://save_studio_tycoon.json`.
  * Cálculo de progresso offline de até 8 horas (rendendo 50% do NPS atual).
* **Áudio e Gráficos Procedurais:**
  * Efeitos sonoros gerados em tempo real via código (`AudioStreamWAV`) e fundos dinâmicos (`GradientTexture2D`), sem depender de assets pesados externos.
  * **Configurações de Performance:** Seletor de qualidade gráfica (**Baixo**, **Médio** e **Alto**), contador de FPS opcional, controle de escala da UI (`0.85x` a `1.50x`), volumes independentes (`BGM`/`SFX`) e vibração háptica no celular.

---

## 🛠️ Tecnologias Utilizadas

* **Engine:** Godot Engine 4.x
* **Linguagem:** GDScript 2.0
* **Resolução Base:** `1080 × 1920` (Retrato) com `Stretch Mode: canvas_items` e `Stretch Aspect: expand`
* **Persistência:** JSON local (`FileAccess`)

---

## 📂 Estrutura do Projeto

```text
res://
├── autoload/
│   └── Global.gd                   # Gerenciamento de estado, fórmulas, save/load e sinais
├── scenes/
│   ├── Main.tscn                   # Cena principal (HUD, Palco, Abas)
│   ├── ui/
│   │   ├── UpgradeCard.tscn        # Card de Equipamentos e Equipe (1x, 10x, MAX)
│   │   └── SpecialUpgradeCard.tscn # Card de Pesquisa (Melhorias únicas)
│   ├── effects/
│   │   ├── FloatingText.tscn       # Feedback visual flutuante de notas e críticos
│   │   └── GoldenNote.tscn         # Evento aleatório coletável
│   └── modals/
│       ├── AchievementPopup.tscn   # Notificação animada de conquista
│       ├── OfflinePopup.tscn       # Relatório de ganhos offline
│       └── VictoryModal.tscn       # Tela de conclusão (Álbum de Diamante)
└── scripts/
    ├── Main.gd                     
    ├── ui/                         
    ├── effects/                   
    └── modals/                     
