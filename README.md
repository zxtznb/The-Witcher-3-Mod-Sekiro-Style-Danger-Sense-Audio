## 📖 Introduction / 简介
**Danger Sense Audio** is a combat awareness mod designed to solve off-screen ambush frustrations without polluting the display with immersion-breaking HUD arrows or glowing screen borders. 
Inspired by **Sekiro: Shadows Die Twice**'s iconic **"危" (Perilous Attack)** system and **Eternal Hunt**'s out-of-frame awareness, this mod combines audio cues, gamepad haptics, and a brief, responsive bullet-time reaction window.
---
## ⚡ Key Highlights / 核心亮点
* **Zero Screen UI**: No floating markers, no arrows, 100% clean screen immersion.
* **Sekiro "危" Audio Cue**: Re-mastered and packed with **Audiokinetic Wwise 2023.1** (Bank Version 150) adhering strictly to CDPR's REDengine CS3W v2 64-bit FNV-1a checksum specification.
* **Early AI Wind-Up Detection**: Hooks into `CBTTaskAttack.OnActivate()` at the behavior tree decision phase, warning the player **0.3s to 0.5s earlier** than traditional animation hit-frame hooks.
* **Frontal Vision Safe Zone**: Enemies in front of Geralt (`<= 60°` camera view cone and visible on screen) are considered fair duels. **NO sound and NO slow-motion** will fire for front-facing enemies.
* **Tactical Bullet-Time Window**: When ambushed from behind/flanks or targeted by ranged projectiles, time slows to **0.30x for 0.45 seconds**, giving the player ample time to dodge, roll, or parry.
* **Dual Gamepad Haptics**: Heavy motor vibration (0.25s) for melee ambushes; light motor vibration (0.20s) for incoming arrows.
* **Engine Safe**: Complete cutscene, death, and finisher camera suppression; 0.8s anti-spam throttle.
---
## 🏗️ Architecture & Engineering / 架构与工程解析
### 1. Behavior Tree & Animation Hooks
```ws
// Earliest possible AI attack decision Hook
@wrapMethod(CBTTaskAttack)
function OnActivate() : EBTNodeStatus
// Fallback animation event hook for non-BT entities
@wrapMethod(CNewNPC)
function OnPreAttackEvent(...)
// High-speed projectile release hook
@wrapMethod(W3AdvancedProjectile)
function OnProjectileShot(...)
Installation / 安装指南
Clone or download this repository.
Copy modDangerSenseAudio to your game directory:
<The Witcher 3 Wild Hunt>/
└── mods/
    └── modDangerSenseAudio/
        └── content/
            ├── danger_sense.bnk
            ├── Init.bnk
            ├── soundspc.cache
            └── scripts/
                └── local/
                    └── dangerSenseAudio.ws
Launch the game via Steam, GOG, or the REDlauncher.
