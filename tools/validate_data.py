#!/usr/bin/env python3
"""Valida os dados do jogo (roda no CI e localmente).

Checagens:
  1. Todos os .json de game/data são JSON válido.
  2. Raridades: cada personagem do elenco (20) aparece em exatamente uma raridade,
     e as cores seguem o combinado (azul, roxo, amarelo, vermelho, branco).
  3. Cada ficha em game/data/characters/*.json existe no elenco ou nas formas Nel/GOAT,
     usa uma raridade válida e a raridade bate com a tabela de atribuições.
  4. Todas as chaves Config.f("secao.chave") usadas nos scripts existem em gameplay.json.
  5. Todo caminho res:// referenciado em .gd/.tscn/.godot existe.

Uso: python3 tools/validate_data.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
DATA = GAME / "data"

ROSTER = {
    "isagi", "bachira", "kunigami", "chigiri", "zantetsu", "barou", "shidou", "rin",
    "nagi", "reo", "aiku", "karasu", "hiori", "otoya", "igaguri", "sae", "kaiser",
    "don_lorenzo", "charles", "yukimiya",
}
EXPECTED_COLORS = {
    "raro": "#2F80ED",
    "epico": "#9B51E0",
    "lendario": "#F2C94C",
    "mitico": "#EB5757",
    "world_class": "#FFFFFF",
}
STAT_KEYS = {"chute", "velocidade", "aceleracao", "drible", "passe", "defesa", "fisico", "visao"}

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)
    print(f"ERRO: {msg}")


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        err(f"JSON inválido: {path.relative_to(ROOT)} ({exc})")
        return None


def check_json_files() -> dict[Path, object]:
    loaded: dict[Path, object] = {}
    for path in sorted(DATA.rglob("*.json")):
        data = load_json(path)
        if data is not None:
            loaded[path] = data
    print(f"[1] {len(loaded)} arquivos JSON válidos")
    return loaded


def check_rarities(loaded: dict[Path, object]) -> dict[str, str]:
    rar_path = DATA / "config" / "rarities.json"
    data = loaded.get(rar_path)
    if not isinstance(data, dict):
        err("rarities.json ausente ou inválido")
        return {}
    colors = {r["id"]: r["color"].upper() for r in data.get("rarities", [])}
    for rid, color in EXPECTED_COLORS.items():
        if colors.get(rid) != color:
            err(f"cor da raridade '{rid}' deveria ser {color}, está {colors.get(rid)}")
    assignments: dict[str, str] = {}
    for rid, members in data.get("assignments", {}).items():
        if rid not in EXPECTED_COLORS:
            err(f"raridade desconhecida em assignments: {rid}")
        for member in members:
            if member in assignments:
                err(f"personagem '{member}' aparece em mais de uma raridade")
            assignments[member] = rid
    missing = ROSTER - set(assignments)
    extra = set(assignments) - ROSTER
    if missing:
        err(f"personagens sem raridade: {sorted(missing)}")
    if extra:
        err(f"personagens fora do elenco: {sorted(extra)}")
    forced = data.get("forced_world_class", {})
    for cid in forced.get("nel", []) + forced.get("other", []):
        assignments[cid] = "world_class"
    print(f"[2] raridades OK ({len(ROSTER)} personagens, {len(forced.get('nel', []))} Nel + GOAT em World Class)")
    return assignments


def check_characters(loaded: dict[Path, object], assignments: dict[str, str]) -> None:
    count = 0
    for path, data in loaded.items():
        if path.parent.name != "characters" or not isinstance(data, dict):
            continue
        count += 1
        cid = data.get("id")
        rel = path.relative_to(ROOT)
        if cid != path.stem:
            err(f"{rel}: id '{cid}' difere do nome do arquivo")
        if cid not in assignments:
            err(f"{rel}: personagem '{cid}' não está na tabela de raridades")
        elif data.get("rarity") != assignments[cid]:
            err(f"{rel}: raridade '{data.get('rarity')}' deveria ser '{assignments[cid]}'")
        stats = data.get("stats", {})
        if set(stats) != STAT_KEYS:
            err(f"{rel}: stats devem ser exatamente {sorted(STAT_KEYS)}")
        for key, value in stats.items():
            if not isinstance(value, (int, float)) or not 0 <= value <= 100:
                err(f"{rel}: stat '{key}' fora de 0-100")
        for key in ("uniform_color", "shorts_color", "skin_color", "hair_color", "aura_color"):
            val = data.get("visual", {}).get(key, "")
            if not re.fullmatch(r"#[0-9A-Fa-f]{6}", val):
                err(f"{rel}: visual.{key} inválido ({val!r})")
    print(f"[3] {count} ficha(s) de personagem válidas")


def code_lines(path: Path) -> str:
    """Texto do script sem linhas de comentário puro (evita falsos positivos em docs)."""
    return "\n".join(
        line for line in path.read_text(encoding="utf-8").splitlines() if not line.lstrip().startswith("#")
    )


def check_config_keys(loaded: dict[Path, object]) -> None:
    gameplay = loaded.get(DATA / "config" / "gameplay.json")
    if not isinstance(gameplay, dict):
        err("gameplay.json ausente ou inválido")
        return
    used: set[str] = set()
    pattern = re.compile(r'(?<![A-Za-z0-9_])(?:Config\.)?f\("([a-z0-9_]+\.[a-z0-9_]+)"\)')
    for script in (GAME / "scripts").rglob("*.gd"):
        used.update(pattern.findall(code_lines(script)))
    for key in sorted(used):
        section, name = key.split(".")
        value = gameplay.get(section, {}).get(name)
        if not isinstance(value, (int, float)):
            err(f"Config.f(\"{key}\") usado nos scripts, mas ausente/não numérico em gameplay.json")
    unused = []
    for section, values in gameplay.items():
        for name in values:
            if f"{section}.{name}" not in used:
                unused.append(f"{section}.{name}")
    print(f"[4] {len(used)} chaves de Config usadas; {len(unused)} sem uso ainda (ok): {', '.join(unused) if unused else '-'}")


def check_resource_paths() -> None:
    pattern = re.compile(r'res://([^"\'\s)]+)')
    checked = 0
    for path in list(GAME.rglob("*.gd")) + list(GAME.rglob("*.tscn")) + [GAME / "project.godot"]:
        text = code_lines(path) if path.suffix == ".gd" else path.read_text(encoding="utf-8")
        for rel in pattern.findall(text):
            rel = rel.rstrip("/")
            if not rel or rel.endswith(("*",)):
                continue
            target = GAME / rel
            checked += 1
            # Caminhos que terminam com "/" apontam para pastas (ex.: CHARACTERS_DIR).
            if not target.exists():
                # Concatenações como CHARACTERS_DIR + id + ".json" só citam a pasta.
                err(f"{path.relative_to(ROOT)} referencia res://{rel}, que não existe")
    print(f"[5] {checked} referências res:// verificadas")


def main() -> int:
    loaded = check_json_files()
    assignments = check_rarities(loaded)
    check_characters(loaded, assignments)
    check_config_keys(loaded)
    check_resource_paths()
    if errors:
        print(f"\n{len(errors)} erro(s) encontrado(s).")
        return 1
    print("\nTudo certo: dados válidos.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
