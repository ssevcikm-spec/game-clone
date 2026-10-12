#!/usr/bin/env python3
"""check-art-fallback - MERENI pravidla "UO art jen jako ZALOHA" (uzivatel 2026-10-12).

Pravidlo: **UO art se pouziva JEN tam, kde neni rozhodnuty nas.** Kde nas art
rozhodnuty JE, musi se kreslit nas.

Proc to je potreba meret: `assets/own-art.json` je JEDINE misto, ktere rika,
ktera (kind, id) se berou z naseho artu; vsechno ostatni padá na `assets/uo/`.
Kdo do sady prida sprite (pipeline `tools/artgen/`) a zapomene ho do
konfigurace zapsat, dostane presne vadu, kterou pravidlo zakazuje: **nas art
existuje, ale hra kresli UO** - a v obraze to nikdo nepozna, protoze "to
prece vypada jako UO".

Co metrika meri (staticky, nad manifesty):
  * `nabizene`  - (kind, id) z manifestu VRSTVY, ktera je v konfiguraci
                  (= aktivni nase sada). Zaznamy s `kind == "anim"` se
                  NEPOCITAJI: postava se bere z anim listu
                  (`render/anim_player.gd`), manifest je jen zrcadli (je to
                  napsane i v manifestu samotnem).
  * `deklarovane` - (kind, id) z `sprites` v `assets/own-art.json`.
  * VADA 1: `nabizene - deklarovane` = nas sprite v aktivni sade, ktery hra
            NEPOUZIVA -> kresli se UO (presne to pravidlo zakazuje).
  * VADA 2: `deklarovane - nabizene` = konfigurace slibuje sprite, ktery v sade
            NENI -> hra by sahala po necem, co neexistuje.
  * VAROVANI: sada na disku, kterou zadna vrstva nepouziva. To NENI vada:
            starsi sady (`own`, `own-lit`) a srovnavaci (`own2x`) zustavaji
            schvalne. Ale je to seznam mist, kde "nas art existuje a nepouziva
            se" - kdo ji povysi na rozhodnutou, musi ji deklarovat.

Verdikt: zadna VADA => exit 0. Exit 1 = VADA (pouziva to
`_analyza/p70-art-fallback-mutace.py`).

Kde to je: `tools/` (ne `_analyza/`), aby se metrika dovezla s repem.
NENI to brana v `tools/gates/run-all.py` (nova brana je zmena smlouvy).

Spousteni:
  $env:PYTHONIOENCODING='utf-8'; python tools/check-art-fallback.py [--root .]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def sprites_z_manifestu(path: Path) -> tuple[set[tuple[str, int]], int]:
    """(nabizene (kind, id), pocet anim framu). Anim framy se nevraceji."""
    data = json.loads(path.read_text(encoding="utf-8"))
    nabizene: set[tuple[str, int]] = set()
    anim = 0
    for rec in data.get("sprites") or []:
        if not isinstance(rec, dict):
            continue
        kind = str(rec.get("kind", rec.get("type", "")))
        ident = rec.get("id", rec.get("index"))
        if not isinstance(ident, int):
            continue
        if kind == "anim":
            anim += 1
            continue
        nabizene.add((kind, ident))
    return nabizene, anim


def main() -> int:
    ap = argparse.ArgumentParser(description="UO art jen jako zaloha (mereni)")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    args = ap.parse_args()
    root = Path(args.root).resolve()

    cfg_path = root / "assets" / "own-art.json"
    if not cfg_path.exists():
        print(f"CHYBA: chybi {cfg_path} - pravidlo nema co merit")
        return 1
    cfg = json.loads(cfg_path.read_text(encoding="utf-8"))

    nabizene: set[tuple[str, int]] = set()
    deklarovane: set[tuple[str, int]] = set()
    anim_framu = 0
    pouzite_manifesty: set[str] = set()
    vrstvy: list[str] = []

    for layer in cfg.get("layers", []):
        jmeno = str(layer.get("name", "?"))
        vrstvy.append(jmeno)
        for kind, hodnoty in (layer.get("sprites") or {}).items():
            for v in hodnoty:
                deklarovane.add((str(kind), int(v)))
        # `groups` je aliasovani dlazdic (jedno id = vic variant) - deklaruje
        # se stejne jako sprites, takze se bere taky.
        for kind, skupiny in (layer.get("groups") or {}).items():
            for skupina in skupiny:
                for v in skupina:
                    deklarovane.add((str(kind), int(v)))
        cesta_manifestu = layer.get("manifest")
        if not cesta_manifestu:
            continue
        rel = str(cesta_manifestu).replace("res://", "")
        pouzite_manifesty.add(rel)
        p = root / rel
        if not p.exists():
            print(f"CHYBA: vrstva '{jmeno}' ukazuje na manifest '{rel}', ktery neexistuje")
            return 1
        nabizene_vrstvy, anim = sprites_z_manifestu(p)
        nabizene |= nabizene_vrstvy
        anim_framu += anim
        print(f"vrstva '{jmeno}': manifest nabizí {len(nabizene_vrstvy)} (kind,id), "
              f"anim framu {anim}")

    vada_nepouzite = sorted(nabizene - deklarovane)
    vada_chybejici = sorted(deklarovane - nabizene)

    nepouzite_sady: list[str] = []
    assets = root / "assets"
    if assets.is_dir():
        for p in sorted(assets.glob("*/manifest.json")):
            sada = p.parent.name
            if sada == "uo":
                continue
            if p.relative_to(root).as_posix() not in pouzite_manifesty:
                nepouzite_sady.append(sada)

    out = {
        "metrika": "UO art jen jako zaloha: nabizene vs. deklarovane (kind,id)",
        "vrstvy": vrstvy,
        "deklarovanych_id": len(deklarovane),
        "nabizenych_id": len(nabizene),
        "anim_framu_mimo_kontrolu": anim_framu,
        "vada_nase_id_ktera_hra_nepouziva": [f"{k}:{i}" for k, i in vada_nepouzite],
        "vada_deklarovane_ktere_v_sade_nejsou": [f"{k}:{i}" for k, i in vada_chybejici],
        "sady_na_disku_nepouzite": nepouzite_sady,
        "stav": "VADA" if (vada_nepouzite or vada_chybejici) else "OK",
    }
    report = root / ".cache" / "check-art-fallback.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    print("=" * 64)
    print(f"deklarovanych (kind,id) v konfiguraci: {len(deklarovane)}")
    print(f"nabizenych (kind,id) v aktivnich sadach: {len(nabizene)}")
    print(f"anim framu (bere se z anim listu, mimo kontrolu): {anim_framu}")
    if vada_nepouzite:
        print(f"VADA: {len(vada_nepouzite)} naseho artu se NEPOUZIVA (hra kresli UO):")
        for k, i in vada_nepouzite:
            print(f"    {k}:{i}")
    if vada_chybejici:
        print(f"VADA: {len(vada_chybejici)} deklarovanych id v sade NENI:")
        for k, i in vada_chybejici:
            print(f"    {k}:{i}")
    if nepouzite_sady:
        print("VAROVANI: sady na disku, ktere zadna vrstva nepouziva (starsi/srovnavaci): "
              + ", ".join(nepouzite_sady))
    print("-" * 64)
    if vada_nepouzite or vada_chybejici:
        print("STAV: VADA - pravidlo 'UO jen jako zaloha' neplati "
              "(nas art existuje, ale nevykresluje se)")
        return 1
    print("STAV: OK - kazdy nas sprite v aktivni sade se take deklaruje "
          "(UO zustava jen tam, kde nas art rozhodnuty neni)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
