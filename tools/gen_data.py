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
           "rest", "copy", "dashshot", "multishot"}
errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)
    print("ERRO:", msg)


def main() -> int:
    chars, skills, quests = roster.build_all()
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
