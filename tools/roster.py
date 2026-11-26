"""Fonte única do elenco: personagens, visual, skills e missões Nel.

Gera (via tools/gen_data.py) os JSON em game/data e alimenta a arte (gen_art.py).
Skills seguem docs/research/part-*.md. Tudo que NÃO é canônico fica com
ref="ideia do jogo"; o que a pesquisa não confirmou fica com "A CONFIRMAR".
Cores de cabelo/olhos/uniforme são APROXIMAÇÕES visuais (não oficiais).
"""
from __future__ import annotations

ORIG = "ideia do jogo"
TBC = "A CONFIRMAR"

# --------------------------------------------------------------------------- kits
KITS = {
    "bluelock": dict(main="#2F80ED", sec="#FFFFFF", shorts="#0B1226", pattern="stripes", team="Blue Lock"),
    "munchen": dict(main="#B3202A", sec="#D4AF37", shorts="#111111", pattern="stripes", team="Bastard München"),
    "barcha": dict(main="#A50044", sec="#004D98", shorts="#004D98", pattern="stripes", team="FC Barcha"),
    "manshine": dict(main="#6CABDD", sec="#FFFFFF", shorts="#FFFFFF", pattern="plain", team="Manshine City"),
    "ubers": dict(main="#1E3A8A", sec="#F2C94C", shorts="#0F1B44", pattern="hoops", team="Ubers"),
    "pxg": dict(main="#0A2240", sec="#E03C4B", shorts="#0A2240", pattern="sash", team="Paris X Gen"),
    "real": dict(main="#F4F4F4", sec="#D4AF37", shorts="#F4F4F4", pattern="plain", team="Real Madrid Youth"),
    "japan": dict(main="#FFFFFF", sec="#C8102E", shorts="#FFFFFF", pattern="plain", team="Japan U-20"),
    "original": dict(main="#16161D", sec="#D4AF37", shorts="#16161D", pattern="stripes", team="Original do jogo"),
    "goat": dict(main="#F2C94C", sec="#FFFFFF", shorts="#E03C4B", pattern="hoops", team="GOAT"),
}

# ---------------------------------------------------------------- personagens base
# stats = (chute, velocidade, aceleracao, drible, passe, defesa, fisico, visao)
CHARS = [
    dict(id="isagi", name="Isagi", full="Yoichi Isagi", rarity="raro", pos="Atacante", kit="bluelock", num=11,
         stats=(72, 64, 66, 62, 66, 48, 60, 84), hair="short", hc="#1A1B24", eyes="#3B7BD6", skin="#F1C9A5", aura="#5CC8FF",
         bio="Atacante que lê o jogo (Meta-Visão) e evolui copiando os rivais. Quer ser o melhor do mundo.", nel="munchen"),
    dict(id="igaguri", name="Igaguri", full="Gurimu Igarashi", rarity="raro", pos="Zagueiro", kit="bluelock", num=13,
         stats=(46, 60, 60, 64, 60, 72, 66, 58), hair="bald", hc="#2A2A2A", eyes="#4A3B2A", skin="#EBC09A", aura="#C9C9C9",
         bio="Filho de monges, joga para fugir do templo. Persistente, mergulha em chutes e provoca faltas.", nel="goat"),
    dict(id="chigiri", name="Chigiri", full="Hyoma Chigiri", rarity="raro", pos="Ponta", kit="bluelock", num=10,
         stats=(66, 94, 92, 78, 62, 40, 52, 66), hair="long", hc="#E0607A", eyes="#C94B6A", skin="#F4D2B6", aura="#FF7A9A",
         bio="O mais veloz do Blue Lock. Superou uma lesão no joelho para voltar a correr.", nel="manshine"),
    dict(id="zantetsu", name="Zantetsu", full="Zantetsu Tsurugi", rarity="epico", pos="Ponta", kit="bluelock", num=21,
         stats=(74, 84, 92, 68, 66, 56, 70, 64), hair="short", hc="#3A2A20", eyes="#6B4B2A", skin="#EBC09A", aura="#9BB0FF", glasses=True,
         bio="Calmo e de poucas palavras. Aceleração explosiva nos primeiros metros e chute de esquerda."),
    dict(id="otoya", name="Otoya", full="Eita Otoya", rarity="epico", pos="Ponta", kit="bluelock", num=17,
         stats=(68, 86, 84, 76, 66, 48, 60, 74), hair="spiky", hc="#E8EEF0", hc2="#2E5E4E", eyes="#2A2A33", skin="#F1C9A5", aura="#7CFFB0",
         bio="Descontraído e provocador. Infiltra por pontos cegos com velocidade e sem fazer barulho."),
    dict(id="bachira", name="Bachira", full="Meguru Bachira", rarity="epico", pos="Ponta", kit="bluelock", num=8,
         stats=(70, 86, 88, 96, 84, 40, 52, 80), hair="wild", hc="#2B2B3A", eyes="#F2A33A", skin="#F4D2B6", aura="#FFB347",
         bio="Dribles imprevisíveis guiados por um 'monstro' imaginário. Só passa para quem o empolga.", nel="barcha"),
    dict(id="hiori", name="Hiori", full="Yo Hiori", rarity="epico", pos="Meia", kit="bluelock", num=23,
         stats=(60, 66, 64, 76, 92, 62, 60, 92), hair="short", hc="#6FD6E8", eyes="#BDEFF7", skin="#F4D2B6", aura="#6FD6E8",
         bio="Armador calmo e observador, de passes precisos. (Raridade provisória: aguardando confirmação.)"),
    dict(id="aiku", name="Aiku", full="Oliver Aiku", rarity="lendario", pos="Zagueiro", kit="japan", num=5,
         stats=(66, 76, 72, 60, 76, 92, 88, 92), hair="spiky", hc="#6B4B3A", hc2="#3FAE6B", eyes="#3FAE6B", eyes2="#8E5BD6", skin="#EBC09A", aura="#3FAE6B",
         bio="Capitão da Japan U-20 e líbero de leitura total. Ex-atacante que decidiu ser o melhor zagueiro.", nel="original"),
    dict(id="kunigami", name="Kunigami", full="Rensuke Kunigami", rarity="lendario", pos="Atacante", kit="bluelock", num=9,
         stats=(92, 76, 72, 66, 58, 58, 88, 68), hair="short", hc="#202428", eyes="#C8A24A", skin="#EBC09A", aura="#FF9F43",
         bio="Atacante de sangue quente com um chute poderoso de perna esquerda. Sonha ser o herói do futebol."),
    dict(id="karasu", name="Karasu", full="Tabito Karasu", rarity="lendario", pos="Meia", kit="bluelock", num=69,
         stats=(58, 70, 70, 78, 88, 76, 66, 94), hair="spiky", hc="#3A2E58", eyes="#4B7BD8", skin="#F1C9A5", aura="#8E72D8",
         bio="Meio-campista analítico e de língua afiada. Desmonta defesas achando o elo mais fraco."),
    dict(id="reo", name="Reo", full="Reo Mikage", rarity="lendario", pos="Meia", kit="bluelock", num=10,
         stats=(80, 80, 80, 84, 90, 78, 84, 86), hair="ponytail", hc="#8E72D8", eyes="#8E72D8", skin="#F4D2B6", aura="#B79CFF",
         bio="Herdeiro carismático que copia as habilidades dos especialistas (Chameleon).", nel="manshine"),
    dict(id="nagi", name="Nagi", full="Seishiro Nagi", rarity="lendario", pos="Meia", kit="bluelock", num=7,
         stats=(84, 70, 66, 86, 72, 50, 66, 88), hair="bob", hc="#E9EAF2", eyes="#8E8EC8", skin="#F4D2B6", aura="#CFD8FF",
         bio="Talento natural com domínio de bola perfeito. Mata a bola e chuta entre os defensores.", nel="manshine"),
    dict(id="yukimiya", name="Yukimiya", full="Kenyu Yukimiya", rarity="mitico", pos="Atacante", kit="munchen", num=14,
         stats=(82, 92, 92, 94, 72, 56, 72, 86), hair="spiky", hc="#7A3B2E", eyes="#6B3B2A", skin="#EBC09A", aura="#FF6B4A",
         bio="Atacante móvel craque do 1 contra 1. Dribles em velocidade e chutes giratórios."),
    dict(id="charles", name="Charles", full="Charles Chevalier", rarity="mitico", pos="Meia", kit="pxg", num=8,
         stats=(64, 82, 80, 84, 98, 56, 66, 96), hair="bob", hc="#C9D6F0", eyes="#6FB4E8", skin="#F4D2B6", aura="#7FB8FF",
         bio="O 'coração' do Paris X Gen. Passes de risco e visão máxima."),
    dict(id="barou", name="Barou", full="Shoei Barou", rarity="mitico", pos="Atacante", kit="bluelock", num=13,
         stats=(94, 78, 76, 86, 58, 64, 96, 80), hair="wild", hc="#1C1C22", hc2="#C23030", eyes="#D3A030", skin="#EBC09A", aura="#FF3B3B",
         bio="O 'Rei' arrogante que devora o jogo. Físico dominante e finalização fria.", nel="ubers"),
    dict(id="shidou", name="Shidou", full="Ryusei Shidou", rarity="mitico", pos="Atacante", kit="bluelock", num=9,
         stats=(94, 90, 88, 86, 52, 52, 98, 84), hair="pompadour", hc="#E0402A", eyes="#E8C14A", skin="#F1C9A5", aura="#FF5A1F",
         bio="Instinto de gol selvagem. O jogador mais forte fisicamente e explosivo.", nel="pxg"),
    dict(id="rin", name="Itoshi Rin", full="Rin Itoshi", rarity="mitico", pos="Atacante", kit="bluelock", num=10,
         stats=(94, 86, 84, 90, 88, 62, 82, 90), hair="short", hc="#1F5F6B", eyes="#2AB7A9", skin="#F1C9A5", aura="#2AE0C9",
         bio="Frio e obcecado. Joga como um marionetista, lendo e manipulando os rivais.", nel="pxg"),
    dict(id="sae", name="Itoshi Sae", full="Sae Itoshi", rarity="world_class", pos="Meia", kit="real", num=10,
         stats=(92, 84, 84, 94, 99, 66, 78, 98), hair="short", hc="#1F5F6B", eyes="#2AB7A9", skin="#F1C9A5", aura="#FFFFFF",
         bio="O maestro do Real Madrid Youth. Passes longos perfeitos e visão de jogo absurda."),
    dict(id="don_lorenzo", name="Don Lorenzo", full="Don Lorenzo", rarity="world_class", pos="Zagueiro", kit="ubers", num=3,
         stats=(64, 88, 86, 78, 88, 99, 94, 99), hair="short", hc="#2A2A2A", eyes="#B8963C", skin="#E0B48C", aura="#F2C94C",
         bio="Líbero do Ubers que come o craque rival. Alcance longo e leitura preditiva."),
    dict(id="kaiser", name="Kaiser", full="Michael Kaiser", rarity="world_class", pos="Atacante", kit="munchen", num=9,
         stats=(99, 88, 88, 90, 84, 60, 86, 96), hair="short", hc="#F4D35E", eyes="#2D9BF0", skin="#F4D2B6", aura="#4DA3FF",
         bio="O 'Imperador' do Bastard München. O chute de primeira mais rápido do mundo."),
]

# ------------------------------------------------------------------------ skills
SKILLS: list[dict] = []


def sk(sid, owner, cat, pt, en, effect, cd, ono=None, ref=TBC, jp="", **p):
    """Registra uma skill. cat: normal | awake | nel (Despertar Nel) | goat."""
    SKILLS.append(dict(id=sid, owner=owner, cat=cat, name_pt=pt, name_en=en, jp=jp, effect=effect,
                       cooldown=float(cd), ono=ono, ref=ref, params=p))


# ---- Isagi
sk("isagi_direct_shot", "isagi", "normal", "Chute Direto", "Direct Shot", "shot", 6, "don", power=0.92, loft=0.08, aim=0.8)
sk("isagi_backheel", "isagi", "normal", "Calcanhar Reverso", "Reverse Back Heel Shot", "shot", 8, "ba", power=0.8, loft=0.05, aim=1.0, goal_aim=True)
sk("isagi_offball", "isagi", "normal", "Movimento Sem Bola", "Off-the-Ball Movement", "dash", 9, "shu", duration=2.0, speed=1.3)
sk("isagi_spatial", "isagi", "awake", "Consciência Espacial", "Spatial Awareness", "vision", 12, "kiin", duration=6.0, assist=0.9)
sk("isagi_flow", "isagi", "awake", "Estado de Flow", "Flow State", "buff", 14, "gogogo", duration=8.0, speed=1.18, shot=1.2, magnet=0.5)
sk("isagi_nel_metavision", "isagi", "nel", "Metavisão", "Metavision", "vision", 12, "kiin", duration=7.0, assist=1.0, slow=0.6, ref="cap. 182 (confirmar)")
sk("isagi_nel_metaburst", "isagi", "nel", "Ponto Meta-Burst", "Meta-Burst Point", "steal", 11, "baki", radius=5.5, pull=1.0)
sk("isagi_nel_twogun", "isagi", "nel", "Voleio de Duas Armas", "Two-Gun Volley", "shot", 13, "zudon", power=1.18, loft=0.22, curve=0.4, aim=1.0, air=True)
# ---- Igaguri
sk("igaguri_dive", "igaguri", "normal", "Mergulho de Bloqueio", "Diving", "block", 9, "baki", duration=1.0, radius=2.6, ref="MAL (sec.)")
sk("igaguri_malicia", "igaguri", "normal", "Malícia", "Malicious Dribbling", "shockwave", 10, "ba", radius=2.4, knock=3.0, stun=0.8, ref="cap. 208 (sec.)")
sk("igaguri_perseverance", "igaguri", "normal", "Perseverança", "Perseverance", "rest", 14, "go", amount=45.0, ref=ORIG)
sk("igaguri_malicia_total", "igaguri", "awake", "Malícia Total", "Total Malice", "shockwave", 14, "dododo", radius=4.0, knock=4.5, stun=1.4, ref=ORIG)
sk("igaguri_heroic_dive", "igaguri", "awake", "Mergulho Heroico", "Heroic Dive", "block", 16, "gogogo", duration=1.6, radius=3.6, ref=ORIG)
sk("goat_karma_dive", "igaguri", "goat", "Mergulho do Sagrado Karma", "Sacred Karma Dive", "block", 14, "bonk", duration=1.4, radius=4.0, ref=ORIG)
sk("goat_transcendental", "igaguri", "goat", "Malícia Transcendental", "Transcendental Malice", "shockwave", 15, "bonk", radius=3.4, knock=1.0, stun=1.8, ref=ORIG)
sk("goat_sermon", "igaguri", "goat", "Sermão do Templo", "Temple Sermon", "zone", 18, "gong", radius=7.0, duration=3.0, slow=0.45, ref=ORIG)
# ---- Chigiri
sk("chigiri_long_sprint", "chigiri", "normal", "Corrida de Longa Distância", "Long-Distance Sprinting", "dash", 9, "shu", duration=1.7, speed=1.55, push=14.0)
sk("chigiri_no_break", "chigiri", "normal", "Drible Sem Parar", "No-Break Dribble", "dash", 8, "zaa", duration=2.2, speed=1.35, magnet=0.9)
sk("chigiri_pressure", "chigiri", "normal", "Pressão em Alta Velocidade", "High-Speed Pressure", "steal", 10, "baki", radius=3.0, pull=0.8, speed=1.3)
sk("chigiri_immense", "chigiri", "awake", "Velocidade Imensa", "Immense Speed", "dash", 14, "zaa", duration=3.5, speed=1.85, magnet=0.6)
sk("chigiri_sprint_through", "chigiri", "awake", "Atravessar a Defesa", "Sprint through the Defense", "evade", 13, "shu", duration=1.6, speed=1.7, immune=True)
sk("chigiri_nel_immense", "chigiri", "nel", "Velocidade Imensa Plena", "Immense Speed (Nel)", "dash", 12, "zaa", duration=4.5, speed=2.05, magnet=0.8, ref=ORIG)
sk("chigiri_nel_crimson", "chigiri", "nel", "Corrida Carmesim", "Crimson Run", "evade", 12, "shu", duration=2.0, speed=1.9, immune=True, ref=ORIG)
sk("chigiri_nel_burst", "chigiri", "nel", "Disparada Final", "Final Burst", "buff", 15, "gogogo", duration=6.0, speed=1.35, shot=1.2, magnet=0.7, ref=ORIG)
# ---- Zantetsu
sk("zantetsu_accel", "zantetsu", "normal", "Aceleração Explosiva", "Explosive Acceleration", "dash", 8, "shu", duration=1.2, speed=1.7)
sk("zantetsu_cutin", "zantetsu", "normal", "Chute de Corte", "Left Foot Shooting", "shot", 7, "don", power=0.9, loft=0.08, curve=-0.5, aim=0.8)
sk("zantetsu_cross", "zantetsu", "normal", "Cruzamento de Linha de Fundo", "Byline Cross", "pass", 7, "hyu", speed=1.0, loft=0.45, curve=0.35)
sk("zantetsu_blade", "zantetsu", "awake", "Investida Lâmina", "Blade Rush", "buff", 14, "shu", duration=5.0, speed=1.35, shot=1.25, ref=ORIG)
sk("zantetsu_iron", "zantetsu", "awake", "Cortador de Ferro", "Iron Cutter", "evade", 13, "baki", duration=1.5, speed=1.6, immune=True, ref=ORIG)
# ---- Otoya
sk("otoya_infiltration", "otoya", "normal", "Infiltração Veloz", "High Speed Infiltration", "dash", 8, "shu", duration=1.8, speed=1.5)
sk("otoya_offball", "otoya", "normal", "Movimento Sem Bola", "Off-the-Ball Movements", "evade", 9, "hyu", duration=1.4, speed=1.4, immune=True)
sk("otoya_taunt", "otoya", "normal", "Provocação", "Taunt", "mark", 11, "dododo", duration=3.0, radius=9.0, speed_debuff=0.8, power_debuff=0.75, ref=ORIG)
sk("otoya_ninja", "otoya", "awake", "Ninja Total", "Ninja Stealth Walk", "dash", 14, "hyu", duration=5.0, speed=1.6, magnet=0.5)
sk("otoya_blindspot", "otoya", "awake", "Ponto Cego Perfeito", "Perfect Blind Spot", "buff", 14, "kiin", duration=5.0, shot=1.3, speed=1.15, ref=ORIG)
# ---- Bachira
sk("bachira_elastic", "bachira", "normal", "Drible Elástico", "Elastic Dribbling", "evade", 7, "hyu", duration=1.2, speed=1.45, immune=True)
sk("bachira_lift", "bachira", "normal", "Monster Lift", "Monster Lift", "shot", 8, "paan", power=0.55, loft=0.65, aim=0.7)
sk("bachira_backspin", "bachira", "normal", "Passe Longo com Efeito", "Long-Range Backspin Pass", "pass", 9, "hyu", speed=1.25, loft=0.55)
sk("bachira_monstrance", "bachira", "awake", "Monstrance", "Monstrance", "dash", 14, "gogogo", duration=4.0, speed=1.5, magnet=1.0)
sk("bachira_triple", "bachira", "awake", "Triplo Túnel", "Triple Nutmeg", "evade", 12, "baki", duration=1.8, speed=1.55, immune=True)
sk("bachira_egotistical", "bachira", "awake", "Estilo Egoísta", "Egotistical Style", "buff", 15, "zudon", duration=6.0, shot=1.3, speed=1.12, magnet=0.6)
sk("bachira_nel_monster", "bachira", "nel", "Monstro Desperto", "Monster Awakening", "buff", 15, "gogogo", duration=7.0, speed=1.3, shot=1.25, magnet=0.9, ref="blog (não confiável); ideia do jogo")
sk("bachira_nel_roulette", "bachira", "nel", "Roleta e Lift", "Roulette Lift", "evade", 10, "paan", duration=1.6, speed=1.6, immune=True, ref="cap. 296 (sec.)")
sk("bachira_nel_cross", "bachira", "nel", "Cruzamento Veloz", "Quick Cross", "pass", 8, "hyu", speed=1.35, loft=0.3, curve=0.3, ref="cap. 296 (sec.)")
# ---- Hiori
sk("hiori_first_touch", "hiori", "normal", "Passe de Primeira", "First Touch Pass", "pass", 5, "hyu", speed=1.1, loft=0.03)
sk("hiori_rabona", "hiori", "normal", "Cruzamento de Rabona", "Rabona Cross", "pass", 8, "paan", speed=1.05, loft=0.4, curve=0.5)
sk("hiori_scissors", "hiori", "normal", "Tesoura Hipervelocidade", "Hyperspeed Scissors", "evade", 8, "shu", duration=1.2, speed=1.45, immune=True)
sk("hiori_metavision", "hiori", "awake", "Metavisão", "Metavision", "vision", 12, "kiin", duration=6.0, assist=0.95, slow=0.7)
sk("hiori_protagonism", "hiori", "awake", "Protagonismo", "Protagonism", "mark", 13, "gogogo", duration=5.0, radius=12.0, speed_debuff=0.8, power_debuff=0.7)
sk("hiori_two_stage", "hiori", "awake", "Passe Falso em 2 Tempos", "2-Stage Fake Pass", "pass", 10, "baki", speed=1.4, loft=0.05, target_buff=1.3)
# ---- Aiku
sk("aiku_total_defense", "aiku", "normal", "Defesa Total", "Total Defense", "steal", 9, "kiin", radius=5.0, pull=1.0)
sk("aiku_libero", "aiku", "normal", "Varredura de Líbero", "Libero Sweep", "block", 9, "zaa", duration=1.1, radius=3.0, ref=ORIG)
sk("aiku_anticipation", "aiku", "normal", "Antecipação", "Reflex", "mark", 11, "kiin", duration=4.0, radius=10.0, speed_debuff=0.75, power_debuff=0.8)
sk("aiku_flow", "aiku", "awake", "Estado de Flow", "Flow State", "vision", 14, "gogogo", duration=8.0, assist=0.7, slow=0.75)
sk("aiku_offensive_libero", "aiku", "awake", "Líbero Ofensivo", "Attacking Libero", "buff", 14, "don", duration=5.0, speed=1.25, shot=1.3, magnet=0.7, ref=ORIG)
sk("aiku_fortress", "aiku", "awake", "Fortaleza", "Fortress", "zone", 15, "gong", radius=5.5, duration=4.0, slow=0.5, ref=ORIG)
sk("aiku_nel_flow", "aiku", "nel", "Flow Total", "Total Flow", "vision", 12, "gogogo", duration=9.0, assist=0.95, slow=0.6, ref="Nel original (não existe no mangá)")
sk("aiku_nel_libero", "aiku", "nel", "Líbero Dourado", "Golden Libero", "buff", 13, "don", duration=6.0, speed=1.35, shot=1.4, magnet=0.8, ref="Nel original (não existe no mangá)")
sk("aiku_nel_fortress", "aiku", "nel", "Fortaleza Eterna", "Eternal Fortress", "zone", 14, "gong", radius=6.5, duration=5.0, slow=0.6, ref="Nel original (não existe no mangá)")
# ---- Kunigami
sk("kunigami_left_shot", "kunigami", "normal", "Chute de Esquerda", "Left-Foot Shot", "shot", 6, "zudon", power=1.0, loft=0.07, aim=0.7)
sk("kunigami_power_charge", "kunigami", "normal", "Investida de Ombro", "Power Charge", "shockwave", 9, "go", radius=2.6, knock=4.0, stun=0.4, ref=ORIG)
sk("kunigami_press", "kunigami", "normal", "Corrida de Pressão", "Press Run", "steal", 10, "dododo", radius=3.2, pull=0.8, speed=1.25, ref=ORIG)
sk("kunigami_hero", "kunigami", "awake", "Modo Herói", "Hero Mode", "buff", 14, "gogogo", duration=6.0, shot=1.4, speed=1.12, ref=ORIG)
sk("kunigami_hot_blood", "kunigami", "awake", "Empurrão de Sangue Quente", "Hot-Blood Push", "evade", 12, "go", duration=1.6, speed=1.5, immune=True, ref=ORIG)
# ---- Karasu
sk("karasu_arm_block", "karasu", "normal", "Bloqueio de Braço", "Expert Ball Control", "buff", 10, "go", duration=2.0, shield=True, magnet=0.8)
sk("karasu_feint", "karasu", "normal", "Finta de Passe", "Feints", "evade", 8, "hyu", duration=1.2, speed=1.4, immune=True)
sk("karasu_weak_link", "karasu", "normal", "Análise do Elo Fraco", "Sharp Analytical Ability", "mark", 11, "kiin", duration=5.0, radius=10.0, speed_debuff=0.8, power_debuff=0.8)
sk("karasu_metavision", "karasu", "awake", "Metavisão", "Metavision", "vision", 12, "kiin", duration=6.0, assist=0.9, slow=0.7)
sk("karasu_crow_rule", "karasu", "awake", "Regra do Corvo", "Crow's Rule", "mark", 14, "gogogo", duration=5.0, radius=12.0, speed_debuff=0.7, power_debuff=0.6, silence=True, ref=ORIG)
# ---- Reo
sk("reo_precise_pass", "reo", "normal", "Passe Preciso", "Precise Pass", "pass", 5, "hyu", speed=1.15, loft=0.05)
sk("reo_copy_shot", "reo", "normal", "Cópia do Chute Direto", "Direct Shot (copy)", "shot", 7, "don", power=0.78, loft=0.08, aim=0.8)
sk("reo_copy_run", "reo", "normal", "Cópia de Corrida", "Run Copy", "dash", 9, "shu", duration=1.8, speed=1.4)
sk("reo_chameleon", "reo", "awake", "Camaleão", "The Chameleon", "copy", 16, "gogogo", fraction=0.75)
sk("reo_organizer", "reo", "awake", "Organizador", "Organizer", "buff", 14, "kiin", duration=6.0, speed=1.12, shot=1.15, allies=8.0, ref=ORIG)
sk("reo_nel_chameleon", "reo", "nel", "Camaleão Pleno", "The Chameleon (Nel)", "copy", 12, "gogogo", fraction=0.92, ref="cap. 297 (sec.)")
sk("reo_nel_organizer", "reo", "nel", "Maestro do Manshine", "Manshine Conductor", "buff", 13, "kiin", duration=7.0, speed=1.2, shot=1.25, allies=10.0, ref=ORIG)
sk("reo_nel_perfect_copy", "reo", "nel", "Cópia Perfeita", "Perfect Copy", "copy", 14, "zudon", fraction=1.0, ref=ORIG)
# ---- Nagi
sk("nagi_trap_shot", "nagi", "normal", "Chute com Domínio", "Trap Shot", "shot", 6, "paan", power=0.95, loft=0.07, aim=0.9, trap=True)
sk("nagi_creative_trap", "nagi", "normal", "Domínio Criativo", "Creative Trap", "evade", 8, "hyu", duration=1.0, speed=1.3, immune=True, magnet=1.0)
sk("nagi_black_hole", "nagi", "normal", "Domínio Buraco Negro", "Black Hole Trap", "steal", 9, "zaa", radius=4.2, pull=1.0)
sk("nagi_two_stage", "nagi", "awake", "Voleio Falso em 2 Estágios", "2 Stage Fake Volley Shot", "shot", 11, "zudon", power=1.1, loft=0.2, curve=0.6, aim=1.0, air=True)
sk("nagi_flow_trap", "nagi", "awake", "Domínio em Flow", "Flow Trap", "buff", 13, "gogogo", duration=6.0, magnet=1.0, speed=1.1, shot=1.1)
sk("nagi_nel_two_stage", "nagi", "nel", "Voleio Falso em 2 Estágios (Nel)", "2 Stage Fake Volley (Nel)", "shot", 9, "zudon", power=1.25, loft=0.2, curve=0.7, aim=1.0, air=True)
sk("nagi_nel_revolver", "nagi", "nel", "Revólver de Cinco Tiros", "Five-Shot Revolver Fake Volley", "multishot", 14, "dododo", power=0.9, shots=3, ref="só o nome (Sportskeeda); efeito A CONFIRMAR")
sk("nagi_nel_flow", "nagi", "nel", "Flow de Domínio Absoluto", "Absolute Trap Flow", "buff", 12, "gogogo", duration=7.0, magnet=1.0, speed=1.18, shot=1.2, ref=ORIG)
# ---- Yukimiya
sk("yukimiya_drag", "yukimiya", "normal", "Tesoura de Arrasto", "Drag Scissors", "evade", 7, "shu", duration=1.2, speed=1.5, immune=True)
sk("yukimiya_gyro", "yukimiya", "normal", "Chute Giroscópico", "Gyro Shot", "shot", 7, "paan", power=0.95, loft=0.3, curve=0.7, aim=0.8)
sk("yukimiya_sword_screw", "yukimiya", "normal", "Parafuso da Espada", "Sword Screw", "shot", 9, "kiin", power=0.9, loft=0.4, curve=-0.4, aim=0.9)
sk("yukimiya_flow", "yukimiya", "awake", "Estado de Flow", "Flow State", "buff", 14, "gogogo", duration=6.0, speed=1.2, magnet=0.9, shot=1.15)
sk("yukimiya_predator", "yukimiya", "awake", "Olhar de Predador", "Predator Eye", "vision", 12, "kiin", duration=5.0, assist=1.0, slow=0.8, ref="cap. 217 (confirmar)")
sk("yukimiya_emperor", "yukimiya", "awake", "Estilo Imperador do 1x1", "1-on-1 Emperor Style", "evade", 13, "go", duration=2.0, speed=1.7, immune=True)
# ---- Charles
sk("charles_risky_pass", "charles", "normal", "Passe Arriscado", "Passing Accuracy", "pass", 5, "hyu", speed=1.2, loft=0.04)
sk("charles_sky_arch", "charles", "normal", "Passe Arco do Céu", "Sky Arch Pass", "pass", 8, "paan", speed=1.1, loft=0.6, curve=0.4)
sk("charles_rabona", "charles", "normal", "Cruzamento de Rabona", "Rabona Cross", "pass", 8, "hyu", speed=1.1, loft=0.35, curve=0.5)
sk("charles_metavision", "charles", "awake", "Metavisão", "Metavision", "vision", 12, "kiin", duration=6.0, assist=0.95, slow=0.7)
sk("charles_heart_pass", "charles", "awake", "Passe do Coração", "Heart of PXG Pass", "pass", 13, "gogogo", speed=1.4, loft=0.05, target_buff=1.4, ref=ORIG)
# ---- Barou
sk("barou_middle_shot", "barou", "normal", "Chute Médio", "Middle Shot", "shot", 6, "don", power=0.98, loft=0.1, aim=0.75)
sk("barou_charging", "barou", "normal", "Habilidade de Investida", "Charging Skill", "shockwave", 9, "go", radius=2.8, knock=4.5, stun=0.5)
sk("barou_chop", "barou", "normal", "Finta de Corte", "Chop Feint", "evade", 8, "ba", duration=1.2, speed=1.45, immune=True)
sk("barou_villain_flow", "barou", "awake", "Fluxo Vilão", "Villainous Soccer", "buff", 14, "gogogo", duration=6.0, speed=1.2, magnet=0.9, shot=1.2)
sk("barou_lightning", "barou", "awake", "Drible Relâmpago", "Lightning Dribble", "dash", 11, "baki", duration=2.2, speed=1.4, magnet=1.0)
sk("barou_nel_stealth", "barou", "nel", "Chute Assassino Furtivo", "Stealth Kill Shot", "shot", 11, "zudon", power=1.1, loft=0.15, curve=0.8, aim=1.0, ref="cap. 216")
sk("barou_nel_predator", "barou", "nel", "Olhar de Predador", "Predator Eye", "vision", 12, "kiin", duration=6.0, assist=1.0, slow=0.8, ref="cap. 217")
sk("barou_nel_double", "barou", "nel", "Chute de Túnel Duplo", "Double Nutmeg Shot", "shot", 11, "dododo", power=1.2, loft=0.1, aim=1.0)
# ---- Shidou
sk("shidou_drive", "shidou", "normal", "Chute Drive", "Drive Shot", "shot", 6, "zudon", power=1.0, loft=0.08, aim=0.75)
sk("shidou_aggressive", "shidou", "normal", "Drible Agressivo", "Aggressive Dribble", "evade", 8, "dododo", duration=1.3, speed=1.5, immune=True)
sk("shidou_bicycle", "shidou", "normal", "Bicicleta", "Bicycle Kick", "shot", 10, "baki", power=1.05, loft=0.35, aim=1.0, air=True)
sk("shidou_dragon", "shidou", "awake", "Dragon Drive", "Dragon Drive", "dashshot", 13, "zudon", power=1.2, loft=0.12, aim=1.0, run=0.55, speed=1.6, ref="anime T2 ep. 10")
sk("shidou_bigbang", "shidou", "awake", "Big Bang Drive", "Big Bang Drive", "shot", 14, "zudon", power=1.3, loft=0.3, aim=1.0, air=True)
sk("shidou_instinct", "shidou", "awake", "Instinto de Gol", "Extreme Spatial Awareness", "vision", 12, "kiin", duration=5.0, assist=1.0, slow=0.8)
sk("shidou_nel_dragon", "shidou", "nel", "Dragon Drive II", "Dragon Drive II", "dashshot", 11, "zudon", power=1.35, loft=0.12, aim=1.0, run=0.5, speed=1.8, ref="evolução do jogo (sem técnica Nel oficial)")
sk("shidou_nel_bigbang", "shidou", "nel", "Big Bang Drive II", "Big Bang Drive II", "shot", 12, "zudon", power=1.45, loft=0.3, aim=1.0, air=True, ref="evolução do jogo")
sk("shidou_nel_frenzy", "shidou", "nel", "Frenesi do Artilheiro", "Goal Poacher Frenzy", "buff", 15, "gogogo", duration=7.0, speed=1.25, shot=1.35, magnet=0.8, ref=ORIG)
# ---- Rin
sk("rin_trivela", "rin", "normal", "Chute de Trivela", "Trivela Shot", "shot", 6, "paan", power=0.95, loft=0.1, curve=0.8, aim=0.85)
sk("rin_elastico", "rin", "normal", "Caneta Elástica", "Elastico Nutmeg", "evade", 8, "hyu", duration=1.3, speed=1.5, immune=True)
sk("rin_oppressive", "rin", "normal", "Passe Opressor", "Oppressive Pass", "pass", 7, "go", speed=1.45, loft=0.05)
sk("rin_puppet", "rin", "awake", "Fluxo do Marionetista", "Puppet Flow", "mark", 13, "gogogo", duration=5.0, radius=12.0, speed_debuff=0.75, power_debuff=0.75)
sk("rin_cog_burst", "rin", "awake", "Explosão do Centro de Gravidade", "Centre of Gravity Full Burst", "shockwave", 12, "dododo", radius=3.2, knock=5.0, stun=0.6)
sk("rin_sync", "rin", "awake", "Sincronização", "Synchronization", "steal", 11, "kiin", radius=4.8, pull=1.0)
sk("rin_nel_scissor", "rin", "nel", "Voleio Tesoura", "Scissor Kick Volley", "shot", 11, "zudon", power=1.25, loft=0.25, curve=0.5, aim=1.0, air=True, ref="cap. 275")
sk("rin_nel_opposite", "rin", "nel", "Aceleração Oposta", "Opposite Acceleration", "evade", 10, "shu", duration=1.8, speed=1.8, immune=True, ref="Japan U-20 (confirmar)")
sk("rin_nel_puppet", "rin", "nel", "Fluxo do Marionetista II", "Puppet Flow II", "vision", 12, "gogogo", duration=7.0, assist=1.0, slow=0.7, ref="cap. 269-270 (confirmar)")
# ---- Sae
sk("sae_long_pass", "sae", "normal", "Passe Longo Cortante", "Long Driven Pass", "pass", 6, "hyu", speed=1.6, loft=0.28)
sk("sae_trivela", "sae", "normal", "Passe de Trivela", "Trivela", "pass", 7, "paan", speed=1.25, loft=0.1, curve=0.6)
sk("sae_counter", "sae", "normal", "Contra-Drible", "Counter Dribbling", "evade", 8, "kiin", duration=1.2, speed=1.4, immune=True)
sk("sae_metavision", "sae", "awake", "Meta Visão", "Meta Vision", "vision", 12, "kiin", duration=6.0, assist=1.0, slow=0.5)
sk("sae_ultra_pass", "sae", "awake", "Passe Ultrarrápido", "Ultra-Fast Pass", "pass", 10, "zudon", speed=2.0, loft=0.02)
sk("sae_nutmeg_combo", "sae", "awake", "Combo Elástico e Rabona", "Elastico/Rabona Nutmeg", "evade", 12, "baki", duration=1.8, speed=1.6, immune=True)
# ---- Don Lorenzo
sk("lorenzo_manmark", "don_lorenzo", "normal", "Marcação Individual", "Manmarking", "mark", 10, "go", duration=5.0, radius=10.0, speed_debuff=0.75, power_debuff=0.85)
sk("lorenzo_intercept", "don_lorenzo", "normal", "Interceptação Preditiva", "Predictive Interception", "steal", 8, "kiin", radius=4.6, pull=1.0, ref=ORIG)
sk("lorenzo_libero_pass", "don_lorenzo", "normal", "Lançamento de Líbero", "Libero Pass", "pass", 7, "hyu", speed=1.5, loft=0.35, ref=ORIG)
sk("lorenzo_ace_eater", "don_lorenzo", "awake", "Devorador de Ases", "Ace-Eater", "mark", 14, "gogogo", duration=5.0, radius=14.0, speed_debuff=0.7, power_debuff=0.6, silence=True, ref="apelido (sec.)")
sk("lorenzo_libero_zone", "don_lorenzo", "awake", "Zona de Líbero", "Libero Zone", "zone", 15, "gong", radius=6.0, duration=4.5, slow=0.55, ref=ORIG)
# ---- Kaiser
sk("kaiser_impact", "kaiser", "normal", "Kaiser Impact", "Kaiser Impact", "shot", 6, "zudon", power=1.12, loft=0.06, aim=0.9, ref="cap. 162")
sk("kaiser_offball", "kaiser", "normal", "Movimento Sem Bola", "Off the Ball Movements", "evade", 8, "shu", duration=1.3, speed=1.4, immune=True)
sk("kaiser_pressure", "kaiser", "normal", "Domínio Sob Pressão", "Pressure Control", "buff", 9, "go", duration=2.5, shield=True, magnet=0.9, ref=ORIG)
sk("kaiser_impact_evo", "kaiser", "awake", "Kaiser Impact Evoluído", "Evolved Kaiser Impact", "shot", 12, "zudon", power=1.4, loft=0.06, aim=1.0, ref=TBC)
sk("kaiser_metavision", "kaiser", "awake", "Metavisão", "Metavision", "vision", 12, "kiin", duration=6.0, assist=1.0, slow=0.6, ref="sec. (confirmar)")

# ------------------------------------------------------------------ missões Nel
# (evento, quantidade) por skill Nel, na mesma ordem das skills "nel"/"goat" do dono.
QUESTS = {
    "isagi": [("skill_goal:isagi_direct_shot", 5), ("awaken_goal", 3), ("win", 5)],
    "igaguri": [("steal", 10), ("skill_use:igaguri_dive", 8), ("win", 3)],
    "chigiri": [("skill_goal:chigiri_no_break", 4), ("assist", 4), ("win", 5)],
    "bachira": [("skill_goal:bachira_lift", 3), ("assist", 5), ("awaken", 4)],
    "aiku": [("steal", 12), ("skill_use:aiku_libero", 8), ("win", 5)],
    "reo": [("assist", 6), ("skill_use:reo_precise_pass", 12), ("win", 5)],
    "nagi": [("skill_goal:nagi_trap_shot", 5), ("goal", 8), ("awaken", 4)],
    "barou": [("skill_goal:barou_middle_shot", 5), ("goal", 10), ("win", 5)],
    "shidou": [("skill_goal:shidou_bicycle", 3), ("goal", 12), ("awaken_goal", 3)],
    "rin": [("skill_goal:rin_trivela", 5), ("assist", 5), ("win", 6)],
}


def stats_dict(t):
    k = ("chute", "velocidade", "aceleracao", "drible", "passe", "defesa", "fisico", "visao")
    return dict(zip(k, t))


def nel_stats(t):
    return tuple(min(99, v + 22) for v in t)


def build_all():
    """Retorna (personagens, skills, missões) prontos para virar JSON."""
    by_owner: dict[str, dict[str, list[str]]] = {}
    for s in SKILLS:
        by_owner.setdefault(s["owner"], {}).setdefault(s["cat"], []).append(s["id"])
    skill_by_id = {s["id"]: s for s in SKILLS}
    chars, quests = [], []
    for c in CHARS:
        k = KITS[c["kit"]]
        sk_c = by_owner.get(c["id"], {})
        base = dict(
            id=c["id"], name=c["name"], full_name=c["full"], rarity=c["rarity"], position=c["pos"], bio=c["bio"],
            stats=stats_dict(c["stats"]), number=c["num"], base_id=None, original=False,
            visual=dict(hair=c["hair"], hair_color=c["hc"], hair_accent=c.get("hc2", ""), eye_color=c["eyes"],
                        eye_color2=c.get("eyes2", ""), skin=c["skin"], aura=c["aura"], glasses=bool(c.get("glasses")),
                        kit=dict(main=k["main"], sec=k["sec"], shorts=k["shorts"], pattern=k["pattern"], team=k["team"])),
            skills=sk_c.get("normal", []), awakening=sk_c.get("awake", []),
            evolution=None,
        )
        nel_kind = c.get("nel")
        if nel_kind:
            nid = c["id"] + ("_goat" if nel_kind == "goat" else "_nel")
            base["evolution"] = nid
        chars.append(base)
        if nel_kind:
            nk = KITS["goat" if nel_kind == "goat" else nel_kind]
            owner_sk = sk_c.get("goat" if nel_kind == "goat" else "nel", [])
            if nel_kind == "goat":
                ns = (60, 80, 76, 86, 64, 92, 88, 62)
            else:
                ns = nel_stats(c["stats"])
            vis = dict(base["visual"])
            vis["kit"] = dict(main=nk["main"], sec=nk["sec"], shorts=nk["shorts"], pattern=nk["pattern"], team=nk["team"])
            vis["aura"] = "#F2C94C" if nel_kind == "goat" else "#FFFFFF"
            vis["nel"] = True
            chars.append(dict(
                id=nid, name=c["name"] + (" GOAT" if nel_kind == "goat" else " Nel"), full_name=c["full"],
                rarity="world_class", position=c["pos"], stats=stats_dict(ns), number=c["num"], base_id=c["id"],
                original=(nel_kind in ("original", "goat")), visual=vis, evolution=None,
                bio=("Evolução MEME do Igaguri (ideia original do jogo): visual e skills absurdos, mas balanceados."
                     if nel_kind == "goat" else
                     ("Versão Nel ORIGINAL do jogo (Aiku não tem time na Neo Egoist League no mangá). " if nel_kind == "original" else
                      "Versão Neo Egoist League de %s. " % c["name"]) + "World Class."),
                skills=[s for s in base["skills"]], awakening=owner_sk, evolved_normals=True))
            for i, sid in enumerate(owner_sk):
                ev, n = QUESTS[c["id"]][i]
                quests.append(dict(id="q_%s_%d" % (c["id"], i + 1), char=c["id"], unlock=sid, event=ev, target=n))
    return chars, SKILLS, quests
