# Scooby.lua by Scooby

Lavender is a premium, modern Gamesense Lua focused on accuracy, stability and a clean experience. It features a custom resolver and quality-of-life systems that push consistency beyond stock GS and many public scripts.

## Highlights
- Custom per-target resolver with animstate-aware max body yaw and dynamic amplitude
- Robust side inference: trace-line, trace-bullet sampling, relative-yaw heuristics, jitter detection
- Stability memory: remembers last good side/amplitude and smoothly homes back after hits
- Adaptive brute stages with center bias reset after repeated misses
- Spread-aware miss handling and reclassification to avoid false "ignored" when HC is high
- Side-flip cooldown to prevent over-flipping and stabilize decisions
- Temporary per-target safety overrides (Force Safe Point / Prefer Body Aim) after repeated high-confidence misses
- Clean info panel and ESP flags for visibility into resolver state

## What’s new (latest update)
- Reclassify high-confidence "spread" misses (HC ≥ 85, or head with HC ≥ 60) as resolver-related to adapt aggressively instead of ignoring
- Add per-target flip cooldown (~0.35s) to prevent rapid oscillation on jitter/desync targets
- Apply short-lived safety overrides per-target after repeated high-confidence misses:
  - Head high-confidence misses: Force Safe Point for ~1.25s
  - Non-head repeated misses: Prefer Body Aim for ~1.75s
- Preserve previous max-amplitude bias after confident misses to brute faster
- Improved logging: miss notifications/console now show "resolver (reclassed)" when reclassified

## Usage
- Drop `lavender.lua` into your Gamesense Lua directory and load it
- In AA settings, enable Lavender resolver and optional info panel/flags
- Use standard GS keybinds (DT, On Shot AA, Quick Peek, Prefer/Force Safe Point, Body Aim)
- Lavender will automatically adapt per target; you can observe state in the resolver panel and ESP flag `LAVENDER`

## Philosophy
- Favor reliable inference first (animstate limits, freestand, relative-yaw), then controlled brute with stabilizers
- Avoid destabilizing on true spread/DT/prediction errors; react decisively only on high-confidence signals
- Smooth transitions and reuse last known-good parameters to reduce jitter and maintain accuracy

## Credits
- Authored by Scooby
- Built for Gamesense; inspired by best practices and refined from live play data

## License
See `LICENSE`.
