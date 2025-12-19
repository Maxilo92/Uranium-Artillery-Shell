# Uranium Artillery Shell - AI Coding Agent Instructions

## Project Overview
A Factorio 2.0+ mod adding nuclear artillery ammunition with persistent radiation mechanics. Core features: uranium artillery shells, radiation damage-over-time system, mutation mechanics for spawners/units, and RadAway antidote.

## Architecture & Key Files

### Data Stage (Prototypes)
- **[data.lua](data.lua)**: Entry point requiring all prototype files
- **[prototypes/item.lua](prototypes/item.lua)**: Clones `artillery-shell`, tints icons green, points to custom projectile
- **[prototypes/entity.lua](prototypes/entity.lua)**: Defines all custom entities (projectile, cloud, sticker, trail, glow, mutated units)
- **[prototypes/recipe.lua](prototypes/recipe.lua)**: Uses `depleted-uranium-fuel-cell` (Factorio 2.0 name, not `spent-fuel-cell`)
- **[prototypes/technology.lua](prototypes/technology.lua)**: Unlocks recipes via `uranium-artillery-shell` tech

### Runtime (control.lua)
- **[control.lua](control.lua)**: Event handlers for:
  - `on_player_used_capsule`: RadAway consumption removes radiation sticker
  - `on_entity_damaged`: Core radiation logic - percentage damage, mutation triggers, infection spreading

### Configuration
- **[settings.lua](settings.lua)**: Five mod settings (mutation toggle, damage %, player damage toggle, startup damage/radius)
- **[info.json](info.json)**: Version `0.1.9`, requires Factorio 2.0+, no DLC dependencies

## Critical Patterns

### Entity Cloning & Modification
```lua
local item = table.deepcopy(data.raw["ammo"]["artillery-shell"])
item.name = "uranium-artillery-shell"
-- Always tint icons to distinguish from base game
item.icons = {{icon = item.icon, tint = {r=0.4, g=1, b=0.4, a=1}}}
```
Use `table.deepcopy()` for all base game prototypes. Set `item.icon = nil` after creating `icons` table.

### Recursive Animation Manipulation
Helper functions `recursive_tint()` and `recursive_scale()` in [entity.lua](prototypes/entity.lua#L2-L76) handle nested animation structures (layers, variations, hr_version). Always use these for consistent visual modifications across complex sprite definitions.

### Sticker-Based DoT System
The `uranium-radiation-sticker` entity drives all radiation mechanics:
- **Duration**: `4294967295` ticks (effectively permanent)
- **Minimal tick damage**: `1/60` acid damage to trigger `on_entity_damaged` events
- **Control.lua handles actual damage**: Percentage-based calculation (`5% max HP/sec` for units) in event handler
- **Visual trail**: `spread_fire_entity = "uranium-radiation-trail"` leaves green glow marks

### Mutation Logic (control.lua)
1. Check `uranium-mutation-enabled` setting
2. Detect `uranium-radiation-sticker` on entity
3. Create `"mutated-" .. entity.name` replacement if prototype exists
4. Preserve health ratio: `new_entity.health = new_entity.max_health * health_ratio`
5. Re-apply sticker to mutated entity
6. **Critical**: Destroy old entity to prevent duplication

### Performance Optimization
```lua
if event.damage_type.name == "acid" and (game.tick % 60 == 0) then
```
Percentage damage runs **once per second** (`game.tick % 60`) to reduce event handler load.

## Settings System
- **Startup settings** (require restart): `uranium-artillery-damage`, `uranium-artillery-radius`
- **Runtime-global settings** (changeable mid-game): `uranium-mutation-enabled`, `uranium-radiation-damage-percent`, `uranium-player-damage-enabled`
- Access in control.lua: `settings.global["setting-name"].value`
- Access in data stage: `settings.startup["setting-name"].value`

## Localization
Use structured keys in `locale/en/config.cfg` (and `locale/de/` for German):
```ini
[item-name]
uranium-artillery-shell=Uranium Artillery Shell

[mod-setting-description]
uranium-mutation-enabled=If enabled, radioactive nests will mutate...
```
Always add entries for new items/entities/settings in **all locale folders**.

## Testing & Debugging
1. **Install location**: `%APPDATA%\Factorio\mods\` (Windows) - folder must match `{name}_{version}` format
2. **Reload without restart**: Use `/reload-mods` for control.lua changes (prototypes require full restart)
3. **Debug commands**:
   - `/c game.player.insert{name="uranium-artillery-shell", count=10}`
   - `/c game.player.surface.create_entity{name="uranium-radiation-sticker", position=game.player.position, target=game.player.character}`
4. **Check logs**: `%APPDATA%\Factorio\factorio-current.log`

## Common Tasks

### Adding New Mutated Entities
1. Clone base entity in [entity.lua](prototypes/entity.lua): `table.deepcopy(data.raw["unit"]["big-biter"])`
2. Name with `mutated-` prefix: `new_entity.name = "mutated-big-biter"`
3. Apply green tint to all animations: `recursive_tint(new_entity.run_animation, {r=0.3, g=1, b=0.3})`
4. Increase stats (HP, damage): `new_entity.max_health = base.max_health * 1.5`
5. Add locale entry in [config.cfg](locale/en/config.cfg)

### Modifying Explosion Effects
Explosion definition in [entity.lua](prototypes/entity.lua#L253): clones from `nuke-explosion` > `atomic-bomb-explosion` > `big-artillery-explosion` (fallback chain). Modify `projectile.action` to change crater/cloud spawn behavior.

### Adjusting Radiation Mechanics
- **Cloud radius**: Change `cloud.action.action_delivery.action.radius` (currently 25 tiles)
- **Sticker application rate**: Modify `cloud.action_frequency` (currently 30 ticks = 0.5s)
- **Damage calculations**: Edit percentage multipliers in [control.lua](control.lua#L95-L103) event handler

## Dependencies & Compatibility
- **Factorio version**: 2.0+ only (uses `depleted-uranium-fuel-cell`)
- **Base mod dependency**: `["base >= 2.0.0"]` in [info.json](info.json)
- **No DLC required**: Works with or without Space Age
- **Mod compatibility**: Uses standard Factorio APIs - should work with most mods unless they remove base artillery/nuclear items
