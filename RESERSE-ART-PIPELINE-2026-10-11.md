# REŠERŠE — art pipeline: Blender + lokální ComfyUI + open zdroje (2026-10-11)

> **Co je tenhle soubor:** **rešerše** (snapshot vnějšího stavu nástrojů a licencí).
> NENÍ to stav projektu ani zadání — stav je v [`HANDOFF.md`](HANDOFF.md),
> zadání artové koleje v [`ZADANI-25-VLASTNI-ART.md`](ZADANI-25-VLASTNI-ART.md).
> **Datum vzniku:** 2026-10-11. **Datum spotřeby:** rešerše stárne rychle —
> u modelů a licencí platí „zkontroluj znovu", až se podle ní bude něco dělat
> (u licencí obzvlášť: dvě ze čtyř doporučení níž se změnila během roku 2026).
>
> **⚠ DATUM SPOTŘEBY: 2026-10-11 (session „KAMENNÁ CESTA V BRITAINU").** Podle
> **§11** (UO je military projekce, dlaždice 1:1, svislice nezkrácená) a **§12**
> („rozhoduje DRUH sady, ne poměr; id k přebití = ta, která mapa opravdu používá")
> se do hry zavedla **kamenná cesta z PBR sady `Stone_Path_007`** na **všech
> čtyřech** land id, která mapa v Britainu na cestu používá (`1001`–`1004` —
> **přeměřeno**, ne opsáno z §12). Sada se **neotáčela ani nenatahovala**:
> není to izo/top-down sada, ale PBR textura, takže se vzorkuje **přes
> kosočtvercovou masku** (`tools/artgen/pbr_dlazdice.py`). Čísla a doklady:
> `HANDOFF.md` (blok nahoře) a `LESSONS.md` (osmá část).
>
> **Jak je co ověřené** (u každého tvrzení je značka):
> * **[M]** = naměřeno na této stanici (příkaz/sonda je u čísla),
> * **[O]** = ověřeno z oficiálního zdroje (licence, API, dokumentace) — URL v §9,
> * **[R]** = z rešeršní větve (URL v §9), **neověřeno vlastní rukou**.
>
> **Proč to vzniklo:** uživatel se ptal, jak využít Blender, lokální ComfyUI
> a veřejné open-licence assety pro tenhle projekt, a slyšel, že „některé addony
> v ComfyUI umí pracovat s pamětí, generovat 3D postavy i se skeletonem a dělat
> animace z obrázků". §6 odpovídá na každou z těch tří věcí zvlášť.

---

## 0. Shrnutí — verdikt na tři otázky

| Otázka | Odpověď | Proč |
|---|---|---|
| **Blender?** | **ANO — páteř pipeline** | Naše zadání (5 směrů × 8 framů se **shodnou kamerou, světlem a siluetou**) není generativní úloha. Vlastní pipeline už je hotová a změřená: `tools/artgen/` **1,08 s/sprite**, 46 spritů (`ZADANI-25` §11) |
| **Lokální ComfyUI?** | **ANO, ale jen na 2D a na experimenty** — ne jako páteř | Na stanici je jádro **0.36.0** s 3D nody, ale **žádné 3D váhy** a GPU (`gfx1032`) není oficiálně podporovaná. Tři ze čtyř velkých 3D modelů padají na **licenci**, ne na výkon (§3) |
| **Open-licence assety?** | **ANO na 3D modely a animace, NE na izo dlaždice** | Hotový **1:1 izo 2D tileset jsem nenašel ani jeden** — veřejné sady jsou 2:1 ([R] měřeno u Kenney i OGA). Postavy a animace ano: KayKit (CC0), Mixamo (zdarma, komerčně) |

**Jedna věta:** *kreslit dlaždice generátorem, postavy a předměty renderovat z 3D (Blender), a 3D modely brát z CC0 zdrojů — ComfyUI použít na textury a na dva experimenty (TRELLIS.2, SAM 3D Body), ne na produkci.*

---

## 1. Co je na stanici (naměřeno dnes) [M]

| Věc | Hodnota | Jak změřeno |
|---|---|---|
| ComfyUI | **0.36.0** v `D:\ComfyUI\ComfyUI` | `comfyui_version.py`, `pyproject.toml` |
| Python / torch | 3.12.10, **torch 2.13.0+rocm10.0.0**, HIP 7.15 | `venv-comfy\Scripts\python.exe -c "import torch…"` |
| GPU | **AMD Radeon RX 6600** (torch ji vidí jako `cuda:0`) | tamtéž |
| AMD buildy | `amd-torch-device-gfx1032`, `amd-torchvision-device-gfx1032` | `pip list` — tedy **build pro tento konkrétní čip** |
| `custom_nodes` | **jen `__pycache__`** (žádný addon) | `Get-ChildItem D:\ComfyUI\ComfyUI\custom_nodes` |
| Start skript | `obrazky\start-comfy.ps1` pouští `--disable-all-custom-nodes` | přečteno |
| Váhy | **jediné velké: `Juggernaut-XL_v9.safetensors` 6,62 GB** (SDXL) | `Get-ChildItem models -Recurse -File \| Where Length -gt 100MB` |
| `models/detection/` | prázdné (jen `put_detection_models_here`) | tamtéž |
| Volné místo | **805,9 GB z 838,3 GB** na `E:` | `[System.IO.DriveInfo]::new('E')` |
| Blender | **5.2.1 LTS** v `C:\Program Files\Blender Foundation\Blender 5.2\` | `Test-Path` |
| Cena SDXL za obrázek | **163,44 s** (`Prompt executed in 163.44 seconds`), vzorkování 1,80 s/it × 28 kroků = ~50 s | `obrazky\comfy\server.log` |

> **Pozor na dvě pasti měření na téhle stanici:** `Get-CimInstance Win32_VideoController`
> vrací v sandboxu `Access denied` a `Get-PSDrive` hlásí `Free 0` — obojí je
> **oprávnění, ne stav** (skill `dsh-prostredi` §1b). Volné místo výš je z .NET `DriveInfo`.

---

## 2. Co ComfyUI umí **už teď, bez addonů** [M]

Jádro 0.36 má 3D a tělové nody přímo v `comfy_extras/`:

| Soubor | Co v něm je (názvy tříd) |
|---|---|
| `nodes_trellis2.py` | **TRELLIS.2** (image → 3D) |
| `nodes_sam3d_body.py` | **SAM3DBody_Loader / _Predict / _FaceExpression / _Smooth / _Render**, `BuildPoseFile` (aliasy *„pose animation", „mocap", „glb", „bvh"*) |
| `comfy_extras\sam3d_body\export\` | `bvh.py`, **`glb_skeletal.py`** (kostra!), `glb_openpose.py`, `capsules.py` |
| `nodes_mesh_postprocess.py` | Decimate, Remesh, **UnwrapMesh**, RenderUVAtlas, Bake AO, ApplyTexture, FillHoles, WeldVertices |
| `nodes_save_3d.py` / `nodes_load_3d.py` | `SaveGLB` (GLB/GLTF/OBJ/FBX/STL/USDZ/PLY…), `Load3D`, `Preview3D` |
| `nodes_hunyuan3d.py`, `nodes_stable3d.py` | Hunyuan3D v2 latenty/conditioning, Zero123/SV3D conditioning |

**Co k tomu chybí:** váhy. Všechny ty nody jsou jen kód — `models/detection/` je
prázdné a jediný stažený model je SDXL.

---

## 3. Co je na téhle GPU mrtvé — licenčně i výkonem

**Nejdřív omezení hardwaru [O]:** RX 6600 = `gfx1032`. AMD ho vede jako
*Runtime ✅ / HIP SDK ❌*, v aktuálních ROCm Windows docs jako **plně
nepodporovaný**. Dnešní SDXL tam jede na override (viz `amd-torch-device-gfx1032`
v §1). **Cokoli s vlastním HIP/CUDA kernelem (nvdiffrast, flash-attn, spconv,
Triton) nenaběhne samo** — což vyřadí celý `ComfyUI-3D-Pack` (prebuildy jen
Windows/CUDA 12.4).

| Model | Licence | VRAM | Na 8 GB gfx1032? |
|---|---|---|---|
| **TRELLIS.2** 4B | **MIT** [O: HF API `license:mit`, negated] | int8 váhy ~4 GB [R] | ⚠ **jen s ROCm patchem**, ověřen na `gfx1100`, ne na `gfx1032` [R] |
| **Hunyuan3D 2.1** | Tencent Community — **mimo EU/UK/KR** [O: text licence] | 10 / 21 / 29 GB [R] | ❌ **licence i VRAM** |
| **Hunyuan3D 2.0** (mini) | **stejná teritorialita** [O: HF API `extra_gated_eu_disallowed: true`] | mini 5 GB / shape 6 / full 12 [R] | ❌ **licence** (VRAM by šla) |
| **Pixal3D** | MIT, ale **gated + EU zakázáno** [R] | neurčeno | ❌ |
| **Zero123++** | kód Apache-2.0, **váhy CC-BY-NC** [R] | ~5 GB | ❌ **licence** (jinak nejschůdnější) |
| **SF3D** | Stability Community (free < $1M obratu) [R] | ~6 GB | ⚠ README zná jen CUDA/MPS |
| **TripoSG** 1.5B | MIT [R] | „≥8 GB, CUDA" [R] | ❌ na hraně |
| Unique3D / Wonder3D / InstantMesh / Hi3DGen | MIT/Apache [R] | — | ❌ `3D-Pack` + CUDA kernely |

> **⚠ KOREKCE rešeršní větve (ověřeno vlastní rukou):** její doporučení
> „začni Hunyuan3D 2.0 mini (5 GB)" **neplatí** — model 2.0 má na Hugging Face
> v kartě `extra_gated_eu_disallowed: true` a licence 2.1 má v textu
> *„THIS LICENSE AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED KINGDOM
> AND SOUTH KOREA"* a zákaz užití **výstupů** mimo Territory (§5c). Pro uživatele
> v ČR je tedy celá rodina Hunyuan3D nepoužitelná — a to je přesně ta vada,
> kterou číslo „5 GB" schová.

**Konzistence („paměť") [R]:** FLUX.1 Kontext [dev] je **non-commercial licence
modelu**, ale §2(d) dovoluje komerční užití **výstupů** (nutný content filter +
AI disclosure). Na 8 GB by šel jen 4-bit přes Nunchaku — ten ale oficiálně zná
**jen NVIDIA**. Qwen-Image-Edit je Apache-2.0, ale 20B. **IPAdapter_plus** je
v režimu „maintenance only" (autor, 14. 4. 2025), na SDXL+8 GB ale funguje a je
nainstalovatelný.

---

## 4. Blender — páteř pipeline

**Proč:** 40 framů se **shodnou kamerou, světlem a siluetou** je přesně to, co
3D render umí a co generativní nástroje neumí (§6).

**Geometrie je kontrakt, ne volba** [M + projekt]: naše dlaždice je **kosočtverec
1:1** (44×44 px, `ISO_STEP` 22, `core/iso.gd`), a poměr kosočtverce je
`sin(elevace)` — takže **1:1 = pohled shora (90°)**, 2:1 = 30°, √3:1 = 35,264°
(pravé izo). Projekt proto používá **elevaci 35,264° + svislé natažení √3**
(naměřeno sondou `probe_projection.py`, `ZADANI-25` §3) — tím vyjde 1:1 dlaždice
a přitom je vidět bok objektů. **Kdo tohle číslo změní, rozjede celou sadu.**

| Nástroj | Co umí | Licence | Poznámka |
|---|---|---|---|
| `tools/artgen/` (náš) | model → render → postprocess → atlas, **1,08 s/sprite** | náš kód | už hotové a změřené |
| Sprite Sheet Generator | rotuje armaturou, export PNG+JSON | GPL-3.0, zdarma | **jen 4 úhly** — my potřebujeme 5 |
| Omnidirectional Isometric Render | izo směry + spritesheet | zdarma (itch.io) | [R] licenci v repu neviděl |
| Rigify | metarig → kostra | v Blenderu | zdarma |
| [Rigify + vlastní ortho rig] | 5 azimutů × 8 framů, alfa | — | **doporučená cesta** |

**Zjištění z artové koleje, které platí i pro tuhle rešerši** (`ZADANI-25` §10):
rozhoduje **světlo, ne rozlišení** — 2× geometrie vyšla ve stejném měřítku
**měkčí** (ostrost 0,34 vs 0,79) a přínos udělal kontaktní stín + jedno slunce.
**Nepořizovat detailnější modely, dokud není dořešené světlo.**

---

## 5. Open-licence zdroje assetů (stav 2026-10-11)

| Zdroj | Licence | Co obsahuje | Pro nás |
|---|---|---|---|
| [KayKit](https://kaylousberg.itch.io/kaykit-adventurers) | **CC0** | Adventurers (4–6 postav, **75 animací**), Skeletons, Dungeon/Medieval kity, FBX/GLTF | **nejlepší kandidát na postavy** |
| [Kenney 3D](https://kenney.nl/assets?q=isometric) | **CC0** | Mini Characters/Dungeon/Forest, City/Fantasy kity, UI | kity na zem, budovy, předměty |
| [Mixamo](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) | zdarma (Adobe ID), **royalty-free i do her**, credit nepovinný | ~2000 animací, auto-rig | **chůze/útok v 5 směrech** |
| [Quaternius](https://quaternius.com/license.html) | **už NE CC0** — od 28. 8. 2026 vlastní QAL (komerčně, bez creditů, zákaz redistribuce) | 70+ balíčků, lidské postavy, Universal Animation Library | pozor: staré návody tvrdí CC0 |
| [Poly Haven](https://polyhaven.com/license) | **CC0** | HDRI, PBR textury | **konzistentní světlo scény** |
| [Poly Pizza](https://poly.pizza/docs/tos) | mix CC dle modelu | 10 700+ low-poly modelů | doplňky |
| [Sketchfab](https://sketchfab.com/) | filtr CC0/CC-BY… | miliony | ⚠ zakazuje užití free modelů pro trénink AI |
| [OpenGameArt](https://opengameart.org/) | mix (i CC-BY-SA, GPL) | 2D i 3D, kvalita kolísá | ⚠ čti licenční **pole**, ne popis |

### Dvě věci, které měření vyvrátilo

1. **Hotový 1:1 izo 2D tileset neexistuje** [R, měřeno u 3 sad]: Kenney
   Isometric Tiles Landscape (CC0) = **2:1**, Kenney Miniature Library = 2:1,
   OGA „basic isometric tiles" = 2:1. Naše mřížka je 1:1 → **dlaždice se musí
   renderovat z 3D** (Kenney/KayKit kity), nebo kreslit.
2. **CC-BY-SA a GPL assety do proprietary hry nebrat** — share-alike se táhne
   na odvozené dílo. A na OGA je „public domain" v popisu, zatímco licenční pole
   říká CC-BY (RLTiles) [R].

### Jak vést credits (ať se to nemusí dohledávat)
`credits.txt` + tabulka **asset → autor → licence → URL → datum stažení**;
u CC-BY platí [TASL](https://wiki.creativecommons.org/wiki/Recommended_practices_for_attribution)
(Title, Author, Source, License); u CC0 atribuce **není povinná**, ale vede se
kvůli dohledatelnosti; u OFL musí být u redistribuovaného fontu text licence.

---

## 6. „Paměť", 3D postavy s kostrou a animace z obrázků — co je pravda

| Co uživatel slyšel | Pravda | Kde to je |
|---|---|---|
| „addony umí **3D postavy se skeletonem**" | **PRAVDA — a už to máš nainstalované** (jen bez vah): `SAM3DBody_Predict` z jednoho obrázku → tělo + kostra, export **`glb_skeletal`**, `bvh`, `glb_openpose`, `BuildPoseFile` (aliasy *mocap/glb/bvh*) | `comfy_extras\nodes_sam3d_body.py` [M] |
| — | Váhy: `facebook/sam-3d-body-dinov3`, **gated (ruční schválení, sbírá jméno/země/afiliaci)**, 2,8 GB [O: HF API `usedStorage`]. Licence **`sam-license`**: royalty-free, **bez klauzule o nekomerčnosti**; kdo šíří odvozeniny, musí přiložit stejnou licenci; publikace musí uvést užití | [LICENSE](https://raw.githubusercontent.com/facebookresearch/sam-3d-body/main/LICENSE) [O] |
| „umí **animace z obrázků**" | **Napůl.** AI video-modely (Wan-Animate 14B, LivePortrait, MimicMotion) vyrobí **video** — měkké, s nekonzistentním světlem mezi framy. My potřebujeme 40 framů, které **do sebe zapadají**. Použitelné je to na **pohyb**, ne na sprity: natočit se mobilem → **mocap** ([Plask](https://plask.ai/en-US/pricing) free 15 s/den, [Rokoko Vision](https://www.rokoko.com/pricing) free) → retarget v Blenderu | §4 |
| „umí pracovat s **pamětí**" | To je **konzistence mezi generacemi**: IPAdapter (funguje na SDXL, „maintenance only"), FLUX Kontext (non-commercial model, komerční **výstupy** — §2(d)), Qwen-Image-Edit (Apache-2.0, 20B). Na 8 GB ROCm je realistický **jen IPAdapter + SDXL** (4-bit Nunchaku je NVIDIA-only) | §3 |
| — | ⚠ Wan-Animate 14B na `gfx1032` + 8 GB: „jde to s FP8" tvrdí jen čínský blog [R] — **needukovat na tom plán** | — |

---

## 7. Doporučený postup pro náš účel

**Vrstva 1 — hned, bez nových závislostí (nejlepší poměr cena/výsledek):**
1. **Dlaždice a textury**: generátor (Nano Banana / SDXL) → konverze do 1:1 (§10).
2. **Postavy a předměty**: **CC0 modely** (KayKit, Kenney) + **Mixamo** animace →
   náš `tools/artgen/` render (35,264° + √3, 5 azimutů, alfa, světlo dle §4).
3. **credits.txt** vést od prvního assetu.

**Vrstva 2 — experiment s jasnou branou (1 session, měřit „naběhlo/nenaběhlo"):**
4. **TRELLIS.2** (MIT, nativní v jádru 0.36) + ROCm patch — **smoke test, jestli
   na `gfx1032` vůbec nastartuje**. Když ne, končí; neopravovat.
5. **SAM 3D Body** (gated váhy) — jediná cesta „z jedné fotky tělo s kostrou",
   a je to přesně to, co uživatel slyšel. Licence je na komerční hru použitelná,
   ale **vést ji v credits** a počítat s ručním schválením přístupu.

**Vrstva 3 — až když vrstva 1 nestačí:** LoRA trénink na vlastní styl (VRAM na
ROCm **neměřeno**), Kontext/Qwen-Image-Edit (potřebuje NVIDIA 4-bit nebo 20B).

**Co NEDĚLAT:**
* Nezačínat **Hunyuan3D** (2.0 i 2.1) — v EU se licence vůbec neuplatní.
* Nestavět na **`ComfyUI-3D-Pack`** — CUDA prebuildy + nvdiffrast na nepodporované GPU.
* Neintegrovat **Zero123++ váhy** (CC-BY-NC) ani **Pixal3D** (EU gated).
* Nepoužívat **Quaternius** jako „CC0" — od 28. 8. 2026 to CC0 není.
* Nezvyšovat rozlišení modelů před dořešením světla (`ZADANI-25` §10).

---

## 8. Co jsem neověřil (a nesmí se na to spoléhat)

* **Peak VRAM** TRELLIS.2 a Pixal3D nativně — oficiálně neuvedeno [R].
* **Zda ROCm patch pro TRELLIS.2 chytne na `gfx1032`** — autor ho ověřil na `gfx1100`.
* **VRAM LoRA tréninku na ROCm** — oficiální číslo jsem nenašel.
* **Licence** UniRig (MIT ověřeno), ale `RigAnything`, `LivePortrait`, `MimicMotion`
  hlásí `NOASSERTION` → pro komerční hru **riziko** [R].
* **Ceny placených Blender addonů** (Auto-Rig Pro) — jen blogy [R].
* Zda nativní integrace TRELLIS.2 odstranila i `natten` (CUDA-only knihovna).
* **Nezměřeno vlastní rukou:** všechny VRAM údaje kromě SDXL (§1) jsou z dokumentace
  výrobce, ne z této stanice.

---

## 9. Zdroje

**Ověřeno z originálu (licence/API):**
[SAM License (Meta, 19. 11. 2025)](https://raw.githubusercontent.com/facebookresearch/sam-3d-body/main/LICENSE) ·
[facebook/sam-3d-body-dinov3 (HF API: gated, 2,8 GB)](https://huggingface.co/api/models/facebook/sam-3d-body-dinov3) ·
[Hunyuan3D 2.1 LICENSE (EU/UK/KR vyloučeno)](https://raw.githubusercontent.com/Tencent-Hunyuan/Hunyuan3D-2.1/main/LICENSE) ·
[tencent/Hunyuan3D-2 (HF API: `extra_gated_eu_disallowed`)](https://huggingface.co/api/models/tencent/Hunyuan3D-2) ·
[Comfy-Org/TRELLIS.2 (HF API: `license:mit`, negated)](https://huggingface.co/api/models/Comfy-Org/TRELLIS.2) ·
[ROCm Windows: podporované GPU](https://raw.githubusercontent.com/ROCm/rocm-install-on-windows/develop/docs/reference/system-requirements.rst)

**Rešeršní větve (neověřeno vlastní rukou, [R]):**
[TRELLIS.2 nativně v ComfyUI](https://blog.comfy.org/p/trellis2-and-pixal3d-are-now-native) ·
[docs.comfy.org TRELLIS.2](https://docs.comfy.org/tutorials/3d/trellis2) ·
[ROCm patch pro TRELLIS.2 (gfx1100)](https://github.com/DrBearJew/ComfyUI-Trellis2-ConvRot-ROCM) ·
[Hunyuan3D 2.0 VRAM (ComfyUI docs)](https://docs.comfy.org/tutorials/3d/hunyuan3D-2) ·
[ComfyUI-3D-Pack (CUDA prebuildy)](https://github.com/MrForExample/ComfyUI-3D-Pack) ·
[Zero123++ (váhy CC-BY-NC)](https://raw.githubusercontent.com/SUDO-AI-3D/zero123plus/main/README.md) ·
[FLUX.1 Kontext dev LICENSE §2(d)](https://raw.githubusercontent.com/black-forest-labs/flux/main/model_licenses/LICENSE-FLUX1-dev) ·
[Nunchaku (jen NVIDIA)](https://raw.githubusercontent.com/nunchux-ai/nunchaku/main/README.md) ·
[UniRig (MIT)](https://huggingface.co/VAST-AI/UniRig/raw/main/README.md) ·
[Mixamo FAQ (Adobe)](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) ·
[Plask ceník](https://plask.ai/en-US/pricing) · [Rokoko ceník](https://www.rokoko.com/pricing) ·
[Quaternius QAL v1.0](https://quaternius.com/license.html) ·
[KayKit Adventurers (CC0)](https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/main/README.md) ·
[Kenney izo sady](https://kenney.nl/assets?q=isometric) ·
[Poly Haven CC0](https://polyhaven.com/license) ·
[Sprite Sheet Generator (GPL-3.0)](https://extensions.blender.org/add-ons/sprite-sheet-generator/) ·
[Omnidirectional Isometric Render](https://s3rdia.itch.io/omnidirectional-isometric-render) ·
[TASL atribuce (CC wiki)](https://wiki.creativecommons.org/wiki/Recommended_practices_for_attribution) ·
[Sale of AI outputs: Gemini rights (secondary)](https://www.terms.law/ai-output-rights/gemini/)

---

## 10. Dvě dlaždicové sady z Nano Banana — verdikt a jak je zapojit

**Kontext:** uživatel vygeneroval přes Nano Banana (Gemini) dvě izo sady dlaždic
a jedna otázka zněla „můžeme je využít?". **Odpověď: ano, obě — ale jinak draze.**
Čísla jsou z mého měření (sonda `_analyza/p53-nabor/s9-nove-sady.py`, kalibrace:
UO dlaždice vyšla 1,00, což je známý správný případ).

| Sada | Tvar kosočtverce | Nezakryté buňky „tak jak je" | Po převodu na 1:1 | Verdikt |
|---|---|---|---|---|
| `Medieval_stone_road_texture_sheet` | **1,17 : 1** | 15 % | natažení **1,17×**, zbytek 4 % | **použít jako hlavní** (má i zemní/hlínové dlaždice) |
| `Cobblestone_road_pixel_art_tileset` | **1,71 : 1** (≈√3, „pravé izo") | 44 % | natažení **1,71×** | použít jen na ploché kusy; dlažební bloky s hranou se protáhnou |

**Převod (měřeno):** svislé natažení je **nutné**, ne volitelné — kosočtverec 1,71:1
na 1:1 jinak než natažením převést nelze. U obou sad je navíc **3D lem** (boční
stěna dlaždice, ~17–20 px) — buď ho **oříznout** (plochý UO vzhled), nebo nechat
(vyvýšené bloky; v rovině jde, ve svahu ne).

**Kam se to zapojuje (jediné místo, dnešní stav):**
* `render/own_art.gd` čte `assets/own-art.json` — vrstvy `{name, manifest, anim, sprites:{kind:[id]}}`,
  `page_prefix` se odvozuje z cesty manifestu.
* Vrstva vyhraje **podle id**: „vlastní vyhrava, kde je; co tam neni, zustava z UO".
* **Pozor:** validátor **odmítne stejné id ve dvou vrstvách** (`own-lit` už drží
  `land [3, 1001]`) → sada musí dostat **jiná id**, než jaká používá `own-lit`.
* Správný výběr id = **ta, která mapa skutečně používá na cestu** (měřitelné
  z `.land` dat), ne libovolná volná — jinak se přebarví terén, který cesta není.

**Dvě omezení, která je potřeba říct nahlas:**
1. Převod výše je z **náhledu 1376×768** (attachment je normalizovaná kopie).
   Do produkce patří **originály z profilu** — jinak se do atlasu zapeče JPEG
   a zmenšení.
2. Licence: Google si u výstupů Gemini **nenárokuje vlastnictví** a komerční
   užití dovoluje [O, sekundární zdroj] — ale **čistě AI obsah nemusí být
   autorsky chráněný**, takže ho nelze bránit proti kopírování. Proto se
   provenance vede v `credits.txt` (nástroj, datum, prompt).

---

## 11. UO není „izometrie" — je to **military (oblique) projekce**

**Měřeno projektem** (`ZADANI-25` §3, sonda `probe_projection.py` na těžištích
značek). Osy světa se do kresby zobrazují takto (v jednotkách šířky artu):

| osa světa | kam se kreslí | co to znamená |
|---|---|---|
| **+X** (východ) | **(+0,500; +0,500)** | 45° dolů vpravo |
| **+Y** (jih) | **(−0,500; +0,500)** | 45° dolů vlevo |
| **+Z** (výška) | **(0; −1,004)** | **svisle nahoru, nezkráceně** |

Půdorys je tedy **plán (pohled přímo shora) jen otočený o 45°** a svislé hrany
zůstávají svislé. Tomu se říká **military / oblique projekce** — a to je důvod,
proč dlaždice měří **1,00** (sonda `s9` v `_analyza/p53-nabor`) a proč je
`Z_SCALE = 4` px na jednotku výšky.

| Projekce | kosočtverec půdorysu | svislá hrana |
|---|---|---|
| **UO (military)** | **1 : 1** | svislá, **nezkrácená** |
| pravá izometrie (30°) | **√3 : 1** (1,73) | svislá, zkrácená na **0,816×** |
| 2:1 „pixel iso" (běžné) | **2 : 1** | svislá (stylizace) |

**Tři důsledky, které z toho plynou pro rozhodnutí o formátu:**

1. Svět je „plošší": krok do hloubky je **22 px** místo 11 px → při stejném zoomu
   uvidíš **2× méně** světa do hloubky než u 2:1.
2. Objekty vypadají jako **postavené výřezy** (svislé hrany, žádné zkrácení).
   To je půvab UO — a taky důvod, proč na zapečeném artu vypadá dynamické
   světlo rozbitě.
3. **Přepnutí na 2:1 není přeškálování, ale jiná kamera.** Dlaždice (plochá
   textura) se dá natáhnout; **objekty se musí vyrenderovat znovu**, protože
   se mění vztah mezi půdorysem a svislicí. To je další položka k ceně
   „20–30 granulí" v §7 — a je to tentýž důvod, proč starý art UO v 2:1
   nefunguje (panel D v `p53-format-1-1-vs-2-1.png`).

---

## 12. Top-down (čtvercová) sada se převádí OTOČENÍM, ne natahováním

**Důsledek §11:** protože půdorys UO je **plán otočený o 45°**, čtvercová
top-down dlaždice se do naší mřížky převádí **tuhým otočením −45° + jednotným
měřítkem** (152 px → 44 px, faktor **0,205**). Nevzniká žádná deformace:

* naměřeno sondou `_analyza/p53-nabor/s13-otoceni.py`: obsah dlaždice
  **0,987 → 1,000** (tvar se nemění, jen natočení), 29 z 32 dlaždic setu projde,
  dlaždice se v mřížce skládají **beze švu**;
* důkaz pohledem: `p53-otoceni-topdown.png` — panel B (otočený set) sedí na
  stejné trávě a se stejným krokem jako referenční UO cesta (land 1001, panel A).

**⚠ To mění pořadí zdrojů z §10.** Pro náš formát je nejlepší **čtvercová
(top-down) sada** — ne izo sada s „nejbližším" poměrem. Izo kosočtverec
(1,17:1 nebo 1,71:1) se musí **anisotropicky natáhnout**; čtverec **ne**.
Rozhoduje tedy *druh* (čtverec vs. kosočtverec), ne *poměr*.

**Co otočení neřeší:**

1. **„Nahoru" v artu** — trsy trávy, odlesky kaluží a zapečené stíny se otočí
   o 45° s dlaždicí. U kamene a hlíny to nevadí, u dekorace ano.
2. **Zapečené světlo** se otočí o 45° proti světlu na objektech (u země slabé).
3. **Převzorkování** 152 → 44 px → art měkne. Správně: otočit ve vysokém
   rozlišení a teprve pak zmenšit (a pro produkci vzít **originál**, ne náhled).
4. **Objekty ne.** UO kreslí objekty **ze strany** (svislice svisle), kdežto
   top-down sada kreslí předměty **zeshora**. Ploché nánosy na zemi (hlína,
   kaluže, kamínky) ✓; stojící předměty (trs trávy, balvan) ✗ — ty patří do
   3D renderu, stejně jako statiky.

**Praktický postup:** otočit −45° → zmenšit na 44×44 → `ox = oy = 0` → je to
běžný `land` sprite v existujícím kontraktu atlasu. Zapojení je hotové
(`assets/own-art.json`, §7) a id k přebití jsou změřená: UO cesta je
**1001–1004 „cobblestones"** (1001 už drží `own-lit`, tedy 1002–1004).
