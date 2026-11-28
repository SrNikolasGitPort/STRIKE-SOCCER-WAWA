#!/usr/bin/env python3
"""Gera game/data/{characters,skills,quests} a partir de tools/roster.py e valida tudo.

Uso: python3 tools/gen_data.py        (sobrescreve os JSON gerados)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roster  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data"
RANGES = {"raro": (58, 74), "epico": (66, 80), "lendario": (70, 86), "mitico": (76, 92), "world_class": (70, 99)}
EFFECTS = {"shot", "pass", "dash", "evade", "steal", "shockwave", "buff", "zone", "block", "vision", "mark",
           "rest", "copy", "dashshot", "multishot", "dribble"}
errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)
    print("ERRO:", msg)


TARGET_MEAN = {"raro": 64.0, "epico": 70.0, "lendario": 75.0, "mitico": 80.0, "world_class": 86.0}
NEL_MEAN = 88.0
GOAT_MEAN = 82.0
CAPS = {  # limites de balanceamento por parâmetro (todas as categorias)
    "power": 1.3, "speed": 1.8, "duration": 6.0, "knock": 5.0, "stun": 1.5, "radius": 7.0,
}
BUFF_CAPS = {"shot": 1.3, "speed": 1.25, "magnet": 1.0}


def balance_stats(c: dict) -> None:
    """Mantém a identidade (pontos fortes/fracos) mas ajusta a média da carta ao alvo da raridade."""
    if c["base_id"] is None:
        target = TARGET_MEAN[c["rarity"]]
    else:
        target = GOAT_MEAN if c["id"].endswith("_goat") else NEL_MEAN
    keys = list(c["stats"].keys())
    vals = [float(c["stats"][k]) for k in keys]
    for _ in range(12):
        mean = sum(vals) / len(vals)
        # escala os desvios (20% mais comprimidos) e recentra
        vals = [min(99.0, max(35.0, target + (v - mean) * 0.85)) for v in vals]
        if abs(sum(vals) / len(vals) - target) < 0.4:
            break
    c["stats"] = {k: int(round(v)) for k, v in zip(keys, vals)}


def balance_skill(s: dict) -> None:
    p = s["params"]
    for k, cap in CAPS.items():
        if k in p and isinstance(p[k], (int, float)) and not (k == "speed" and s["effect"] in ("buff", "steal", "pass")):
            p[k] = min(p[k], cap)
    if s["effect"] == "buff":
        for k, cap in BUFF_CAPS.items():
            if k in p:
                p[k] = min(p[k], cap)
    if s["effect"] in ("steal",) and "speed" in p:
        p["speed"] = min(p["speed"], 1.3)
    if s["effect"] == "vision" and "slow" in p:
        p["slow"] = max(p["slow"], 0.6)
    if s["effect"] == "zone" and "slow" in p:
        p["slow"] = max(p["slow"], 0.5)
    if s["effect"] == "pass" and "speed" in p:
        p["speed"] = min(p["speed"], 1.8)


def main() -> int:
    chars, skills, quests = roster.build_all()
    for s in skills:
        balance_skill(s)
    for c in chars:
        balance_stats(c)
    ids = [s["id"] for s in skills]
    if len(ids) != len(set(ids)):
        err("ids de skill duplicados")
    skill_ids = set(ids)
    for s in skills:
        if s["effect"] not in EFFECTS:
            err(f"skill {s['id']}: efeito desconhecido {s['effect']}")
        if s["cat"] not in ("normal", "awake", "nel", "goat"):
            err(f"skill {s['id']}: categoria inválida")
    cids = [c["id"] for c in chars]
    if len(cids) != len(set(cids)):
        err("ids de personagem duplicados")
    for c in chars:
        for sid in c["skills"] + c["awakening"]:
            if sid not in skill_ids:
                err(f"{c['id']}: skill inexistente {sid}")
        if len(c["skills"]) != 3:
            err(f"{c['id']}: deve ter 3 skills normais (tem {len(c['skills'])})")
        n_aw = len(c["awakening"])
        if c["base_id"] is None and n_aw not in (2, 3):
            err(f"{c['id']}: Despertar base deve ter 2 ou 3 skills (tem {n_aw})")
        if c["base_id"] is not None and n_aw != 3:
            err(f"{c['id']}: Despertar Nel/GOAT deve ter 3 skills (tem {n_aw})")
        vals = list(c["stats"].values())
        avg = sum(vals) / len(vals)
        lo, hi = RANGES[c["rarity"]]
        if not lo <= avg <= hi:
            err(f"{c['id']}: média de stats {avg:.1f} fora da faixa {lo}-{hi} de {c['rarity']}")
        c["average"] = round(avg, 1)
    q_by_char: dict[str, int] = {}
    for q in quests:
        q_by_char[q["char"]] = q_by_char.get(q["char"], 0) + 1
    for c in chars:
        if c["evolution"] and q_by_char.get(c["id"], 0) != 3:
            err(f"{c['id']}: precisa de 3 missões de evolução")
    if errors:
        print(f"{len(errors)} erro(s).")
        return 1

    (DATA / "characters").mkdir(parents=True, exist_ok=True)
    for old in (DATA / "characters").glob("*.json"):
        old.unlink()
    for c in chars:
        (DATA / "characters" / f"{c['id']}.json").write_text(json.dumps(c, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DATA / "characters" / "index.json").write_text(json.dumps({"order": cids}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (DATA / "skills").mkdir(parents=True, exist_ok=True)
    (DATA / "skills" / "skills.json").write_text(
        json.dumps({s["id"]: s for s in skills}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (DATA / "quests").mkdir(parents=True, exist_ok=True)
    (DATA / "quests" / "quests.json").write_text(json.dumps(quests, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"OK: {len(chars)} personagens, {len(skills)} skills, {len(quests)} missões")
    for c in chars:
        print(f"  {c['id']:<14} {c['rarity']:<12} média {c['average']:>5}  normais={len(c['skills'])} despertar={len(c['awakening'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
