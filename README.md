# Uranium Artillery Shell

[Factorio Mod Portal](https://mods.factorio.com/mod/Uranium-Artillery-Shell)

**Uranium Artillery Shell** is a Factorio mod that adds a powerful new ammunition type for your artillery turrets and wagons, bringing nuclear devastation to long-range warfare.

## Features

### ☢️ Uranium Artillery Shell
*   **Massive Damage**: Deals 2000 combined damage (Physical + Explosion) in a 15 tile radius, both configurable.
*   **Nuclear Fallout**: Creates a lingering, invisible radiation field marked by a **glowing green crater**, reaching further than the blast itself (25 tiles at the default radius) and lasting 30 seconds. The fallout only affects living things - it will not chew through your own walls, and a vehicle shields you from it.
*   **Permanent Radiation**: Units and players caught in the fallout are afflicted with **Radiation Sickness**.
    *   Lasts indefinitely until death or cured.
    *   Deals **8 acid damage/second** while you stand in the fallout, plus the percentage damage below.
    *   Slows movement speed by 20% and marks the victim green.
    *   Fades to 20% strength over 30 seconds once you leave the fallout.
*   **Anti-Behemoth**: Irradiated units take an additional **5% of their max HP** as damage every second, ensuring nothing survives for long.

### 💥 MK2 Shell
*   Endgame variant with **3x radius, 3x damage** and a 90 second fallout field.

### 💊 RadAway (Antidote)
*   **Cure Yourself**: A new consumable item that instantly cures Radiation Sickness.
*   **Affordable**: Roughly the cost of a poison capsule - cheap enough to keep a stack around, not free.

### 🧬 Mutation Mechanic
*   **Radioactive Evolution**: Nests, worms and units caught in the fallout **mutate** into green variants that are faster, hit 50% harder, see further and shrug off radiation - but burn out and die on their own after 10-20 minutes.
*   **Mutated Spawners**: Green-tinted nests that spawn mutated units instead of normal ones.
*   **Contagion**: Anything a mutant hits catches radiation sickness too.
*   **Strategy**: Use with caution! While deadly to units, irradiating nests can make the local fauna much more dangerous. Turn it off with the **Enable Alien Mutation** setting.

## Settings

You can configure the following settings in the Mod Settings menu:

*   **Enable Alien Mutation**: Toggle whether radioactive nests mutate into stronger variants.
*   **Radiation Damage (%)**: Percentage of max health dealt as damage per second to irradiated units.
*   **Enable Player Radiation Damage**: Toggle whether players take radiation damage.
*   **Artillery Shell Damage**: Total damage of the explosion (Startup setting).
*   **Artillery Explosion Radius**: Radius of the explosion and radiation cloud (Startup setting).

## Recipes

Costs are anchored to the vanilla atomic bomb. That anchor differs by build: **30x Uranium-235** in the base game, **100x Uranium-235** under Space Age (which rewrites the bomb recipe). Every uranium amount below is therefore scaled up ~3x under Space Age; structural inputs (steel, plastic, processing units) are unchanged. A MK1 shell is a small fraction of a bomb per shot; a finished MK2 shell works out to roughly one bomb's worth of fissile material in either build.

Amounts shown as **base → Space Age** where they differ.

### Uranium Artillery Shell — 30s
1x Artillery Shell · 1x Depleted Uranium Fuel Cell · **10 → 30x** Uranium-238 · **2 → 6x** Uranium-235 · **5 → 10x** Explosives

### RadAway — 10s
2x Steel Plate · 5x Sulfur · 5x Coal *(same in both builds)*

### Stabilized Radiation Core — 20s
**10 → 30x** Uranium-235 · **2 → 4x** Processing Unit · **10 → 20x** Explosives

### Dense Uranium Casing — 20s
**20 → 60x** Uranium-238 · 20x Steel Plate · 10x Plastic Bar

### Uranium Artillery Shell MK2 — 90s
1x Uranium Artillery Shell · 2x Stabilized Radiation Core · 2x Dense Uranium Casing · **10 → 30x** Uranium-235 · **20 → 40x** Explosives

→ **~32x Uranium-235 in total** (base) / **~96x** (Space Age) per MK2 shell — about one atomic bomb either way.

## Technology

Research is balanced separately for the two builds, because Space Age reshapes the science tree: `space-science-pack` moves ahead of every planet (no longer an endgame gate), the vanilla Artillery technology is rewritten to require Metallurgic science (Vulcanus) and drops to 1500, and the Atomic Bomb costs more. In **both** builds MK1 keeps Artillery as a hard prerequisite, so the uranium shell can never be researched before the ordinary artillery shell.

### Uranium Artillery Shell
*   **Prerequisites**: Artillery, Nuclear Power
*   **Base game**: 2500 x Automation, Logistic, Chemical, Military, Utility (30s each) — sits between vanilla Artillery (2000) and the Atomic Bomb (5000).
*   **Space Age**: 4000 x the five above plus Space and Metallurgic science (45s each) — mirrors the Space Age Artillery pack list, a real step past Artillery rather than a formality.

### Uranium Artillery Shell MK2
*   **Base game**: Prerequisites Uranium Artillery Shell, Atomic Bomb, Space Science Pack. 3000 x the six standard packs plus Space Science (60s each).
*   **Space Age**: Prerequisites Uranium Artillery Shell, Atomic Bomb, **Cryogenic Science Pack** (Aquilo). 6000 x the seven standard packs plus Cryogenic (60s each) — a true post-Aquilo endgame weapon.

## Installation

1.  Download the latest release or clone this repository into your Factorio `mods` directory.
2.  Ensure the folder name matches the mod name and version (e.g., `Uranium-Artillery-Shell_0.2.0`).
3.  Enable the mod in the game menu.

## Compatibility

*   **Factorio Version**: 2.0 (tested against 2.0.77)
*   **DLC**: Works with or without Space Age DLC.
