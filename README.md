# Strike Soccer WAWA

Fan game 3D de futebol inspirado em **Blue Lock** (mangá e anime), com a jogabilidade rápida de **Rematch**. Sem fins lucrativos. Todos os modelos, texturas e sons são originais, procedurais ou CC0 (veja `CREDITS.md`).

**Plataformas:** Windows e Android (Godot 4.3, renderer Mobile).
**Versão atual:** `0.1.0-m1` (Marco 1: fundação).

## O que já funciona (M1)

- Campo 3D procedural (gramado listrado, linhas, traves com rede, arena fechada, estádio com refletores)
- Bola com física responsiva (quique, atrito, arrasto, efeito/Magnus)
- 1 jogador controlável (Isagi, modelo placeholder estilizado): corrida, sprint com stamina, condução e domínio de bola
- Chute com barra de força, passe, passe alto e curva
- Placar, cronômetro de 5 minutos, gol com câmera lenta, fim de jogo
- Câmera 3ª pessoa dinâmica
- Controles: teclado, gamepad e toque (joystick + botões virtuais)
- Qualidade gráfica Baixo/Médio/Alto (tecla F2)
- CI: valida dados, checa o GDScript e gera `.exe` (zip) e `.apk` automaticamente

## Controles

| Ação | Teclado | Gamepad | Toque |
|---|---|---|---|
| Mover | WASD / setas | Analógico esquerdo | Joystick (metade esquerda) |
| Sprint | Shift | LB | SPRINT |
| Chute (segure para força) | Espaço | X | CHUTE |
| Passe | E | A | PASSE |
| Passe alto | Q | Y | ALTO |
| Reiniciar bola / nova partida | R | Back | R |
| Qualidade gráfica | F2 | - | - |

## Como rodar

1. Instale o [Godot 4.3](https://godotengine.org/download) (versão estável).
2. Abra a pasta `game/` no Godot e aperte F5.

Ou baixe os builds prontos na aba **Actions** (artefatos) ou em **Releases**.

## Builds e Releases

- A cada push na `main` o GitHub Actions valida e exporta Windows e Android (APK debug).
- Para criar uma Release: `git tag v0.1.0 && git push origin v0.1.0`. O workflow gera o APK release assinado (precisa dos Secrets) e publica tudo na aba Releases.
- Passo a passo da keystore Android e dos Secrets: [`docs/SETUP.md`](docs/SETUP.md).

## Estrutura

```
game/        projeto Godot (scenes, scripts, data, assets)
docs/        SETUP, DECISIONS, ROADMAP, SKILLS_RESEARCH, TESTING
tools/       scripts utilitários (validate_data.py)
server/      servidor dedicado (M5)
.github/     workflows de CI/CD
```

## Roadmap

| Marco | Conteúdo | Status |
|---|---|---|
| M1 | Fundação: repo, CI, campo, bola, 1 personagem, controles PC/mobile | Código pronto, aguardando 1º build |
| M2 | Partida completa, menus, 2v2/4v4 offline com bots | Pendente |
| M3 | Skills data-driven, Despertar a cada 1:30, 5 primeiros personagens | Pendente |
| M4 | Elenco completo, raridades, evolução Nel, Igaguri GOAT | Pendente |
| M5 | Online: login Google, salas por código, amigos, anti-cheat | Pendente |
| M6 | Polimento e release 1.0 | Pendente |

Detalhes em [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Licença

Código sob licença MIT (veja `LICENSE`). Blue Lock pertence a Muneyuki Kaneshiro, Kōji Nomura e Kōdansha; este projeto é um fan game não oficial e sem fins lucrativos.
