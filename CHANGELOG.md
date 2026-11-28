# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

## 1.0.0-beta (tag única)
- Controles: pulo, mira vertical (chutar para cima, F/Z ou arrastar o botão de chute), trava de mira (Tab), botão de bola alta removido.
- Ball Predict (trajetória do chute) e versão avançada na Metavisão.
- Passe direto no parceiro mirado; sem mira vai para um parceiro aberto (balanceado).
- Carrinho de desarme (rouba e derruba), drible com pedaladas e Angle Breaker, skills de drible (zigzag, elástico, roleta, finta, caneta).
- Goleiro bot por time.
- Metavisão: buff mínimo de velocidade, Ball Predict avançada e Dimensão Omnisférica própria de cada personagem (cúpula quadriculada 3D + motivos); hitbox/interceptação para Aiku e Karasu.
- Rin: Chute Curvo (bem mais curvo) e Chute Curvo Destrutivo (Nel).
- Sae (cabelo rosa, olhos verdes) e Shidou (cabelo amarelo com mechas rosas, olhos rosas) corrigidos.
- Perfil: apelido, bio, título, avatar, status da carreira, histórico e personalização de cores.
- Interface mobile com margens seguras, menus animados, músicas novas (menu, partida, despertar, vitória).
- Skills retrabalhadas e rebalanceadas.

## 1.0.0-rc2 (em andamento)
- Balanceamento: médias por raridade normalizadas (raro 64, épico 70, lendário 75, mítico 80, World Class 86, Nel 88, GOAT 82) e limites nos parâmetros de skill.
- TEMPORÁRIO: `dev.unlock_all` em gameplay.json libera todos os personagens, Nel e GOAT (e todas as skills de Despertar) para testes.
- Cutscene de despertar: câmera cinemática orbitando o jogador, pose, anéis, letterbox, câmera lenta local (só offline).
- Skills de Despertar do jogador têm cutscene cinemática própria.
- Parâmetro `immune` das skills de esquiva agora é respeitado.

## [1.0.0-rc1] - 2026-11-27

### Adicionado
- 30 personagens (20 base + 9 formas Nel World Class + Igaguri GOAT), 137 skills, 30 missões Nel, raridades
- Skills por dados com 15 tipos de efeito; Despertar com 2–3 skills; **barra de Fluxo = Despertar** (encha e aperte G)
- Cutscenes de skill (letterbox, FOV punch, onomatopeias em kana, câmera lenta local offline)
- Bots, modos 2v2, 4v4 e Treinamento; resultado com moedas/XP; progressão e save; loja por raridade
- Menus completos (principal, modos, seleção com cartas/ficha/missões, configurações PT/EN)
- Câmera orbital estilo Roblox (botão direito/setas/analógico/arrastar), movimento e mira relativos à câmera
- Drible (Q) e desarme (C/Espaço); HUD de skills em quadrados nomeados
- Multiplayer: host autoritativo (ENet), código de sala, UPnP, LAN, servidor mestre opcional, amigos, login Google (device flow)
- 122 texturas PNG e 43 sons/músicas gerados por scripts (`tools/`)
- Testes headless de sistemas no CI

### Limitações conhecidas
- Online e login Google não puderam ser testados com dispositivos reais por mim; teste e reporte
- Imagens oficiais do mangá não são incluídas (direitos autorais): use `assets/custom_portraits/`
- Hiori: raridade provisória (Épico) — aguardando confirmação

## [0.1.0-m1] - 2026-11-26

### Adicionado
- Projeto Godot 4.3 (renderer Mobile) em `game/`
- Campo 3D procedural com traves, rede, arena fechada e refletores
- Bola com física responsiva (quique, atrito, arrasto, efeito)
- Jogador controlável (Isagi placeholder): corrida, sprint com stamina, condução, chute com força, passe, passe alto e curva
- Câmera 3ª pessoa dinâmica com tremor de impacto
- HUD: placar, cronômetro, stamina, barra de força, mensagens e FPS
- Controles de teclado, gamepad e toque (joystick + botões virtuais)
- Partida de 5 minutos com gol em câmera lenta e fim de jogo
- Qualidade gráfica Baixo/Médio/Alto
- Config em JSON, tabela de raridades (azul, roxo, amarelo, vermelho, branco)
- CI: validação de dados, checagem de GDScript, export Windows/Android e Release por tag
- Documentação: README, DECISIONS, SETUP, ROADMAP, TESTING, SKILLS_RESEARCH
