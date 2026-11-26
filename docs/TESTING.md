# Testes

## Automáticos (CI)
- `python3 tools/validate_data.py`: JSON válido, raridades, fichas, chaves de Config, caminhos `res://`.
- `gdparse`: sintaxe do GDScript. `gdlint`: estilo (apenas aviso).
- Smoke test headless e testes GUT entram no M2/M3.

## Checklist manual do M1
PC:
- [ ] O jogo abre direto no campo, sem erros no console
- [ ] WASD move; Shift gasta a barra azul e ela recarrega depois de parar
- [ ] Segurar Espaço enche a barra de força; soltar perto da bola chuta; longe da bola não faz nada
- [ ] E (passe) e Q (passe alto) funcionam
- [ ] Marcar gol mostra "GOOOL!" com câmera lenta e volta ao saque; placar sobe para o time certo (Azul = gol em +X)
- [ ] A bola não sai do campo (arena fechada) e quica nas traves
- [ ] R reinicia a bola; no fim do tempo, R começa nova partida
- [ ] F2 alterna a qualidade (Baixo/Médio/Alto)

Android:
- [ ] O APK instala e abre em paisagem
- [ ] Joystick na metade esquerda, botões CHUTE/PASSE/ALTO/SPRINT/R na direita
- [ ] Multitoque: mover e chutar ao mesmo tempo
- [ ] FPS (canto superior direito) estável; anote o aparelho e o FPS

## Problemas conhecidos do M1
- Nunca foi executado dentro do Godot durante o desenvolvimento (o ambiente de criação não tem Godot). O primeiro build do CI e o primeiro teste manual podem revelar erros que serão corrigidos em seguida.
- Modelo do jogador é placeholder; sem áudio ainda; sem menus ainda.
