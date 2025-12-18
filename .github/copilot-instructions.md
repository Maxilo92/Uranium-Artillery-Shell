# Factorio Mod Development Instructions

## Project Overview
This is a Factorio mod ("Uranium Artillery Shell") that adds nuclear artillery mechanics, radiation effects, and enemy mutations.
- **Language**: Lua 5.2 (Factorio flavor)
- **API**: Factorio Mod API (v2.0+)
- **Key Features**: Custom projectiles, persistent radiation (stickers), entity mutation via script replacement.

## Architecture

### Data Stage (`data.lua`)
- **Entry Point**: `data.lua` loads all prototype definitions.
- **Prototypes**: Located in `prototypes/`. Use `data:extend({...})` to register new objects.
- **Entity Generation**: `prototypes/entity.lua` contains helper functions (`recursive_tint`, `recursive_scale`) to programmatically generate "mutated" variants of existing enemies by copying and modifying base game prototypes.

### Control Stage (`control.lua`)
- **Runtime Logic**: Handles events during gameplay.
- **Event Handling**: Use `script.on_event(defines.events.EVENT_NAME, handler)`.
- **Key Mechanics**:
  - **Radiation**: Implemented as a "sticker" entity (`uranium-radiation-sticker`) attached to units.
  - **Mutation**: `on_entity_damaged` checks for irradiated spawners and replaces them with `mutated-` variants using `surface.create_entity`.
  - **DoT (Damage over Time)**: Custom logic in `on_entity_damaged` applies percentage-based damage to irradiated units/players (bypassing standard resistance/regen).

## Development Workflows

### Prototyping
1.  Define item/recipe/entity in `prototypes/`.
2.  Ensure graphics paths match `__Uranium-Artillery-Shell__/graphics/...`.
3.  Restart Factorio to apply data stage changes.

### Scripting
- **Hot Reloading**: For `control.lua` changes, you can often reload a save, but for data changes, a full restart is required.
- **Debugging**: Use `log("message")` which outputs to `factorio-current.log`. In-game, use `/c game.print("message")` for immediate feedback.
- **Performance**: The `on_entity_damaged` handler runs frequently. Ensure expensive checks (like iterating stickers) are gated by `game.tick % 60 == 0` or similar throttles.

## Conventions & Patterns

### Entity Manipulation
- **Cloning**: When creating mutated entities, deep copy the base prototype table and modify properties (color, health, resistances).
- **Stickers**: Use stickers to tag entities for script logic. Check for stickers using `entity.stickers` and iterate to find specific names.

### Localization
- **Locale Files**: `locale/en/config.cfg` (INI format).
- **Usage**: Reference keys like `[item-name]`, `[entity-name]`, `[technology-name]`.

### Code Style
- **Lua**: Use local variables for performance.
- **Safety**: Always check `entity.valid` before accessing properties in event handlers.

## Common Tasks

### Adding a New Mutated Unit
1.  In `prototypes/entity.lua`, find the base unit prototype.
2.  Use `table.deepcopy`.
3.  Apply `recursive_tint` to give it the green radiation look.
4.  Adjust stats (health, damage).
5.  Register with `data:extend`.
6.  Update `control.lua` to handle the mutation trigger if necessary.
