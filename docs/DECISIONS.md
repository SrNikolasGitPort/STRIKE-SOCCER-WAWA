# Decisões de arquitetura

Registro das decisões tomadas durante o desenvolvimento. Cada item tem data e motivo.

## 2026-11-26 (M1)

**D1. Godot 4.3, renderer Mobile, GDScript tipado.**
Projeto 100% em texto (versionável), exporta Windows e Android por linha de comando no CI. 4.3 foi escolhida por estar disponível como imagem/release estável e ter templates de export conhecidos.

**D2. Tudo procedural no M1.**
Campo, bola, jogador e HUD são montados por código. Assim não há dependência de assets externos nem risco de licença. Os modelos placeholder usam nomes definitivos de ficha (`data/characters/<id>.json`); modelos `.glb` finais entram depois sem mexer no código (ver D8).

**D3. Config em JSON, não em código.**
Todo valor balanceável fica em `game/data/config/gameplay.json` e é lido via `Config.f("secao.chave")`. O script `tools/validate_data.py` falha o CI se uma chave usada no código não existir no JSON.

**D4. Fichas de personagem e raridades em JSON (não `.tres`).**
JSON é validável no CI em Python, sem precisar do Godot. O pedido original citava `.tres`; mantemos a mesma ideia (dados fora do código) com formato mais fácil de validar. Se o M3 pedir `Resource` tipado, criamos um loader que converte o JSON.

**D5. Raridades definitivas** (`game/data/config/rarities.json`):
- Raro (azul): Isagi, Igaguri, Chigiri
- Épico (roxo): Zantetsu, Otoya, Bachira, **Hiori (provisório, aguardando confirmação do dono)**
- Lendário (amarelo): Aiku, Kunigami, Karasu, Reo, Nagi
- Mítico (vermelho): Yukimiya, Charles, Barou, Shidou, Itoshi Rin
- World Class (branco): Itoshi Sae, Don Lorenzo, Kaiser
- Todas as formas Nel e o Igaguri GOAT são World Class.

**D6. Eixos do campo.**
O time 0 ataca em +X, o time 1 em -X. A câmera olha para +X, então "frente" = +X e "direita" = +Z. Isso simplifica controles, câmera e IA do M2.

**D7. Física da bola em RigidBody3D com ajustes manuais.**
Quique, atrito e arrasto vêm do `PhysicsMaterial`; o efeito (Magnus) é uma força aplicada só com o giro vertical. A condução de bola é um "puxão" suave em direção a um ponto à frente dos pés (não é colisão perfeita), para dar sensação de controle em tela de toque. No online (M5) esta simulação roda só no servidor.

**D8. Fluxo de troca de modelos 3D.**
Quando houver `.glb` final de um personagem, basta colocá-lo em `game/assets/models/<id>.glb` e referenciá-lo na ficha. O `player.gd` usa o modelo procedural enquanto o campo `model` estiver vazio (a ser implementado no M4).

**D9. CI.**
`lint.yml` valida dados e sintaxe (gdparse). `build.yml` baixa o Godot e os templates oficiais, configura SDK/JDK do Android e exporta Windows e APK debug (com keystore de debug gerada na hora). `release.yml` roda em tags `v*` e gera também o APK release assinado se os Secrets existirem.

## Pendências de decisão

- Raridade do **Hiori** (hoje Épico/provisório).
- Servidor online (M5): hospedagem e provedor de auth (Firebase Auth ou Supabase Auth com Google).
