# SHARED BRIEF — UO Skill System research (read this first)

## Goal
Produce source-accurate markdown SECTIONS that will be merged into ONE deliverable:
`E:\Workspaces\game-clone\research\02-skills.md`
The final document documents the COMPLETE Ultima Online skill system for a faithful
single-player offline clone (ServUO-like mechanics, classic/AoS-T2A era focus).

## Local source checkouts (USE THESE — they are real, on disk, greppable)
| What | Path | Notes |
|---|---|---|
| ServUO (runuo-derived, C#) | `E:\Workspaces\game-clone\.research-src\servuo` | branch `pub57`. Primary source of truth for mechanics. |
| ModernUO (rewrite of ServUO) | `E:\Workspaces\game-clone\.research-src\modernuo` | Secondary/verification source. |
| ClassicUO (client) | `E:\Workspaces\game-clone\.research-src\classicuo` | Client-side: skill list, groups, gumps, caps, delays. |
| Pre-fetched raw files | `E:\Workspaces\game-clone\.research-src\raw` | e.g. `servuo-Skills.cs`, `servuo-SkillCheck.cs`, `servuo-SkillsGump.cs` |

Use the `grep` and `glob` tools (not shell grep) to search these trees, and `read` to
read files with line numbers. ALWAYS read the file before asserting anything about it.

## Citation format (MANDATORY on every non-obvious claim)
- Source: `ServUO:Scripts/Services/Craft/DefBlacksmithy.cs:120` plus
  GitHub URL `https://github.com/ServUO/ServUO/blob/pub57/Scripts/Services/Craft/DefBlacksmithy.cs#L120`
- Web: `[UOGuide — Blacksmithy](https://www.uoguide.com/Blacksmithy)`
- ModernUO paths are relative to `Projects/` e.g. `ModernUO:Projects/Server/Skills.cs:1`,
  URL `https://github.com/modernuo/ModernUO/blob/main/Projects/Server/Skills.cs#L1`

## Confidence markers (MANDATORY per formula/table)
- `[SRC]` — read directly out of server/client source code, cite file:line.
- `[WEB]` — authoritative prose source (UOGuide / UO Stratics / official patch notes), cite URL.
- `[SRC+WEB]` — both agree.
- `[PARTIAL]` — partially evidenced; say exactly which part is missing.
- `[UNVERIFIED]` — do NOT invent numbers. State what would have to be measured to know
  (e.g. "measure X over N attempts on a live shard / read packet Y").
- `[ERA]` — era note (classic/T2A vs AoS vs SE vs ML vs SA); state which expansion introduced it.

## Hard rules
1. NEVER invent a number, formula, or item. If source does not contain it, write `UNVERIFIED`
   and say what measurement would resolve it.
2. Prefer source-code constants and literals over wiki prose. Quote exact literals
   (e.g. `0.5 * (1.0 + skill/100)`) and give the file:line.
3. Where ServUO and ModernUO disagree, show BOTH with citations.
4. Dense markdown: tables over prose. Short lines. No filler, no "in conclusion".
5. Do NOT write the head of the final document (title/TOC) — only your own section,
   starting at `## <YourSectionTitle>`.
6. Write the section to the exact output file given in your task prompt. Then reply with
   a <=15 line summary: file path, table/section count, and any UNVERIFIED gaps.

## Era reference (use consistently)
- **Classic / pre-AoS (1997–2003)**: 700.0 total skill cap, 100.0 individual cap, 225 stat cap.
- **AoS (2003)**: Necromancy, Chivalry, Focus, Bushido, Ninjitsu, Spellweaving later; powerscrolls to 120.
- **SE (2005)**: Spellweaving; **ML (2007)**: Throwing for gargoyles only, Mysticism later;
  **SA (2009)**: Mysticism, Throwing, Imbuing (skills 55/56/57 — the 3 "future" slots).
- Verify these era claims against web sources; mark `[ERA]`.
