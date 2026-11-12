## 2024-05-24 - [Avoid Hardcoded CJK Characters in WitcherScript HUD]
**Learning:** Hardcoding CJK (Chinese, Japanese, Korean) characters in WitcherScript for HUD messages (e.g. `DisplayHudMessage`) causes font display issues like empty boxes for players who do not have the respective language fonts installed. This leads to a poor debug/UX experience for international players.
**Action:** Always use English (ASCII) strings for debug messages or fallback HUD elements in WitcherScript to ensure they render correctly across all localized versions of the game.
