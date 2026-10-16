local shared = require("shared")

local STICKER = shared.STICKER_NAME
local MOD_NAME = "Uranium-Artillery-Shell"

local PROCESS_INTERVAL = 60 -- radiation is applied once per second
local DECAY_TICKS = 1800    -- fallout decays to MIN_DECAY over 30 seconds
local MIN_DECAY = 0.2
local MUTATION_COOLDOWN = 60

-- The engine only attaches stickers to units, characters, cars and spider
-- vehicles. Worms are turrets and nests are unit-spawners, so they can never
-- carry radiation sickness - they are handled on contact instead of per second.
local STICKABLE_TYPES = {
    ["unit"] = true,
    ["character"] = true,
}

-- Entity types that have "mutated-" counterparts.
local MUTABLE_TYPES = {
    ["unit"] = true,
    ["turret"] = true,
    ["unit-spawner"] = true,
}

local CONTACT_EFFECTS = {
    ["uranium-radiation-contact"] = true,
    ["uranium-radiation-contact-mk2"] = true,
}

local CLOUD_EFFECTS = {
    ["uranium-cloud-created"] = false,
    ["uranium-cloud-created-mk2"] = true,
}

-- Fixed structures the fallout eats away at. They cannot carry the radiation
-- sticker, so they suffer only while they stand in a field (see process_structures).
local STRUCTURE_TYPES = {"unit-spawner", "turret"}

local DEATH_EFFECT = "uranium-radiation-death"

-- Geiger counter: one clip per second, denser the closer to ground zero.
-- Intensity is 1 at the centre of a field and 0 at its edge.
local GEIGER_SOUNDS = {"uranium-geiger-1", "uranium-geiger-2", "uranium-geiger-3"}
local GEIGER_THRESHOLDS = {0.6, 0.25} -- above the first: level 3, above the second: level 2

--------------------------------------------------------------------------------
-- storage
--------------------------------------------------------------------------------

-- storage.radiation_targets  [unit_number] = {entity = LuaEntity, applied_tick = uint}
-- storage.radiation_clouds   array of {expires_tick, surface_index, position, radius, is_mk2, circle, label}
-- storage.entity_mutations   [unit_number] = tick of the last mutation
-- storage.character_glows    [unit_number] = LuaRenderObject
-- storage.debug_enabled      bool
local function init_storage()
    storage.radiation_targets = storage.radiation_targets or {}
    storage.radiation_clouds = storage.radiation_clouds or {}
    storage.entity_mutations = storage.entity_mutations or {}
    storage.character_glows = storage.character_glows or {}
    if storage.debug_enabled == nil then
        storage.debug_enabled = false
    end
end

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function has_radiation(entity)
    local stickers = entity.stickers
    if not stickers then return false end
    for _, sticker in pairs(stickers) do
        if sticker.valid and sticker.name == STICKER then
            return true
        end
    end
    return false
end

local function destroy_glow(unit_number)
    local glow = storage.character_glows[unit_number]
    if glow then
        if glow.valid then glow.destroy() end
        storage.character_glows[unit_number] = nil
    end
end

local function untrack(unit_number)
    storage.radiation_targets[unit_number] = nil
    destroy_glow(unit_number)
end

local function ensure_glow(character, unit_number)
    local glow = storage.character_glows[unit_number]
    if glow and glow.valid then return end
    -- A sickly green light around an irradiated player, on top of the aura the
    -- sticker draws. Anchored to the character, so it follows on its own.
    storage.character_glows[unit_number] = rendering.draw_light{
        sprite = "utility/light_small",
        scale = 1.2,
        intensity = 0.7,
        color = {r = 0.3, g = 1, b = 0.3},
        surface = character.surface,
        target = character,
    }
end

-- Kills an entity the radiation has worn down, with a visible green burst so the
-- fallout's kills are seen rather than units silently dropping dead.
local function radiation_kill(entity, force)
    entity.surface.create_entity{name = DEATH_EFFECT, position = entity.position}
    entity.die(force or entity.force)
end

local function cloud_style(is_mk2)
    if is_mk2 then
        return {r = 0.05, g = 1, b = 0.2, a = 0.6}, {r = 0.2, g = 1, b = 0.4}, 1.4, "MK2 Radiation: "
    end
    return {r = 0.1, g = 1, b = 0.1, a = 0.5}, {r = 0.6, g = 1, b = 0.6}, 1.2, "Radiation: "
end

local function destroy_overlay(cloud)
    if cloud.circle then
        if cloud.circle.valid then cloud.circle.destroy() end
        cloud.circle = nil
    end
    if cloud.label then
        if cloud.label.valid then cloud.label.destroy() end
        cloud.label = nil
    end
end

local function create_overlay(cloud, tick)
    local surface = game.surfaces[cloud.surface_index]
    if not surface then return end
    local remaining = cloud.expires_tick - tick
    if remaining <= 0 then return end

    local circle_color, text_color, scale, label = cloud_style(cloud.is_mk2)
    cloud.circle = rendering.draw_circle{
        color = circle_color,
        radius = cloud.radius,
        filled = false,
        surface = surface,
        target = cloud.position,
        time_to_live = remaining,
    }
    cloud.label = rendering.draw_text{
        text = label .. math.ceil(remaining / 60) .. "s",
        surface = surface,
        target = cloud.position,
        color = text_color,
        alignment = "center",
        vertical_alignment = "bottom",
        scale = scale,
        time_to_live = remaining,
    }
end

--------------------------------------------------------------------------------
-- mutation
--------------------------------------------------------------------------------

-- Replaces an irradiated entity with its "mutated-" variant. Returns the new
-- entity, or nil when nothing was mutated.
local function try_mutate(entity, unit_number, applied_tick, tick)
    if string.find(entity.name, "^mutated%-") then return nil end

    local new_name = "mutated-" .. entity.name
    if not prototypes.entity[new_name] then return nil end

    -- Guards against the same entity mutating twice in the same second.
    local last_mutation = storage.entity_mutations[unit_number]
    if last_mutation and tick - last_mutation < MUTATION_COOLDOWN then return nil end

    local surface = entity.surface
    local position = entity.position
    local force = entity.force
    local direction = entity.direction
    local health_ratio = entity.health / entity.max_health

    local new_entity = surface.create_entity{
        name = new_name,
        position = position,
        direction = direction,
        force = force,
        fast_replace = true,
        spill = false,
        create_build_effect_smoke = false,
    }
    if not new_entity then
        log("[Uranium] Failed to create " .. new_name .. " at (" .. position.x .. ", " .. position.y .. ")")
        return nil
    end

    new_entity.health = new_entity.max_health * health_ratio

    -- Remember the source so a failed destroy() cannot duplicate the entity by
    -- mutating it a second time on the next pass.
    storage.entity_mutations[unit_number] = tick
    untrack(unit_number)
    if entity.valid then entity.destroy() end

    local new_id = new_entity.unit_number

    -- Carry the radiation sickness over so the mutant keeps decaying.
    if STICKABLE_TYPES[new_entity.type] then
        surface.create_entity{name = STICKER, position = new_entity.position, target = new_entity}
        if new_id then
            storage.radiation_targets[new_id] = {entity = new_entity, applied_tick = applied_tick}
        end
    end

    return new_entity
end

--------------------------------------------------------------------------------
-- per-second processing
--------------------------------------------------------------------------------

local function apply_radiation_damage(entity, unit_number, percent)
    if percent <= 0 then return end
    local damage = entity.max_health * percent
    if entity.health > damage then
        entity.health = entity.health - damage
    else
        untrack(unit_number)
        radiation_kill(entity)
    end
end

local function process_targets(tick)
    local targets = storage.radiation_targets
    if not next(targets) then return end

    local damage_percent = settings.global["uranium-radiation-damage-percent"].value / 100
    local player_damage = settings.global["uranium-player-damage-enabled"].value
    local mutation_enabled = settings.global["uranium-mutation-enabled"].value

    -- Mutation inserts and removes entries, so iterate over a key snapshot
    -- instead of the live table.
    local ids, count = {}, 0
    for unit_number in pairs(targets) do
        count = count + 1
        ids[count] = unit_number
    end

    for i = 1, count do
        local unit_number = ids[i]
        local entry = targets[unit_number]
        local entity = entry and entry.entity

        if not (entity and entity.valid) then
            untrack(unit_number)
        elseif not has_radiation(entity) then
            untrack(unit_number)
        else
            local applied_tick = entry.applied_tick or tick
            local decay = math.max(MIN_DECAY, 1 - (tick - applied_tick) / DECAY_TICKS)

            if mutation_enabled and MUTABLE_TYPES[entity.type] then
                local mutant = try_mutate(entity, unit_number, applied_tick, tick)
                if mutant then
                    entity = mutant
                    unit_number = mutant.unit_number or unit_number
                end
            end

            if entity.valid then
                if entity.type == "character" then
                    ensure_glow(entity, unit_number)
                    if player_damage then
                        apply_radiation_damage(entity, unit_number, damage_percent * decay)
                    end
                else
                    apply_radiation_damage(entity, unit_number, damage_percent * decay)
                end
            end
        end
    end
end

-- Nests carry no "breaths-air" flag, so the fallout trigger deliberately skips
-- them - that filter is what keeps it from touching every chest and tree in
-- range - and neither nests nor worms can carry the radiation sticker. They are
-- picked up here instead, once per second for every field they stand in:
-- mutation, the contact acid, and the same share of max health that radiation
-- sickness takes from units. Without that last part the fallout barely
-- scratched a fully evolved nest (~2800 HP against 8 acid per second for 30
-- seconds), and mutation then left the survivors stronger than before.
local function process_structures(tick)
    local clouds = storage.radiation_clouds
    if not clouds[1] then return end

    local mutation_enabled = settings.global["uranium-mutation-enabled"].value
    local damage_percent = settings.global["uranium-radiation-damage-percent"].value / 100

    for _, cloud in pairs(clouds) do
        if cloud.expires_tick > tick then
            local surface = game.surfaces[cloud.surface_index]
            local force = cloud.force and game.forces[cloud.force]
            if surface and force then
                local found = surface.find_entities_filtered{
                    position = cloud.position,
                    radius = cloud.radius,
                    type = STRUCTURE_TYPES,
                }
                for _, entity in pairs(found) do
                    -- Never the shooter's own side: modded player turrets can
                    -- be of type "turret" too.
                    if entity.valid and entity.force ~= force and not entity.force.get_friend(force) then
                        local target = entity
                        if mutation_enabled then
                            target = try_mutate(entity, entity.unit_number, tick, tick) or entity
                        end
                        if target.valid and cloud.contact_damage then
                            target.damage(cloud.contact_damage, force, "acid")
                        end
                        if target.valid and damage_percent > 0 then
                            local damage = target.max_health * damage_percent
                            if target.health > damage then
                                target.health = target.health - damage
                            else
                                radiation_kill(target, force)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Plays the Geiger counter to every player standing in a fallout field, and a
-- slow tick to anyone still carrying radiation sickness outside of one.
local function process_geiger(tick)
    local clouds = storage.radiation_clouds
    local targets = storage.radiation_targets
    for _, player in pairs(game.connected_players) do
        local character = player.character
        if character and character.valid then
            local position = character.position
            local surface_index = character.surface.index
            local intensity = -1
            for _, cloud in pairs(clouds) do
                if cloud.expires_tick > tick and cloud.surface_index == surface_index then
                    local dx, dy = position.x - cloud.position.x, position.y - cloud.position.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < cloud.radius then
                        intensity = math.max(intensity, 1 - distance / cloud.radius)
                    end
                end
            end

            local level
            if intensity > GEIGER_THRESHOLDS[1] then
                level = 3
            elseif intensity > GEIGER_THRESHOLDS[2] then
                level = 2
            elseif intensity >= 0 or (character.unit_number and targets[character.unit_number]) then
                level = 1
            end
            if level then
                player.play_sound{path = GEIGER_SOUNDS[level]}
            end
        end
    end
end

local function process_clouds(tick)
    local clouds = storage.radiation_clouds
    local debug_enabled = storage.debug_enabled

    for i = #clouds, 1, -1 do
        local cloud = clouds[i]
        local remaining = cloud.expires_tick - tick
        if remaining <= 0 then
            destroy_overlay(cloud)
            table.remove(clouds, i)
        elseif debug_enabled then
            if not (cloud.label and cloud.label.valid) then
                destroy_overlay(cloud)
                create_overlay(cloud, tick)
            else
                local _, _, _, label = cloud_style(cloud.is_mk2)
                cloud.label.text = label .. math.ceil(remaining / 60) .. "s"
            end
        elseif cloud.circle or cloud.label then
            destroy_overlay(cloud)
        end
    end
end

local function prune_mutation_history(tick)
    for unit_number, mutation_tick in pairs(storage.entity_mutations) do
        if tick - mutation_tick > MUTATION_COOLDOWN then
            storage.entity_mutations[unit_number] = nil
        end
    end
end

local function prune_glows()
    local targets = storage.radiation_targets
    for unit_number, glow in pairs(storage.character_glows) do
        if not glow.valid then
            storage.character_glows[unit_number] = nil
        elseif not targets[unit_number] then
            glow.destroy()
            storage.character_glows[unit_number] = nil
        end
    end
end

script.on_nth_tick(PROCESS_INTERVAL, function(event)
    local tick = event.tick
    process_targets(tick)
    process_structures(tick)
    process_geiger(tick)
    process_clouds(tick)
    prune_mutation_history(tick)
    prune_glows()
end)

--------------------------------------------------------------------------------
-- events
--------------------------------------------------------------------------------

script.on_init(init_storage)

script.on_configuration_changed(function()
    init_storage()
    -- Versions before 0.2.0 kept their state in the pre-2.0 `global` table, which
    -- Factorio no longer persists. Anything they drew is orphaned in the save, so
    -- drop every render object owned by this mod and rebuild from storage.
    for _, object in pairs(rendering.get_all_objects(MOD_NAME)) do
        object.destroy()
    end
    storage.character_glows = {}
    for _, cloud in pairs(storage.radiation_clouds) do
        cloud.circle = nil
        cloud.label = nil
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    local effect_id = event.effect_id

    if CONTACT_EFFECTS[effect_id] then
        local target = event.target_entity
        if not (target and target.valid) then return end

        local unit_number = target.unit_number
        if not unit_number then return end

        if STICKABLE_TYPES[target.type] then
            -- Fresh exposure resets the decay timer. Everything else (damage,
            -- mutation) happens in the once-per-second pass.
            storage.radiation_targets[unit_number] = {entity = target, applied_tick = event.tick}
        elseif MUTABLE_TYPES[target.type] and settings.global["uranium-mutation-enabled"].value then
            -- Nests and worms cannot hold a sticker, so they would never be
            -- picked up by the per-second pass. Mutate them on contact instead.
            try_mutate(target, unit_number, event.tick, event.tick)
        end
        return
    end

    local is_mk2 = CLOUD_EFFECTS[effect_id]
    if is_mk2 == nil then return end

    local surface = game.surfaces[event.surface_index]
    if not surface then return end

    local position = event.target_position or event.source_position
    if not position then return end

    -- Whoever fired the shell owns the fallout damage dealt to nests.
    local source = event.source_entity
    local force = (source and source.valid and source.force.name) or "player"
    if not game.forces[force] then force = "player" end

    local fallout_radius = shared.fallout_radius()
    local cloud = {
        expires_tick = event.tick + (is_mk2 and shared.MK2_CLOUD_DURATION or shared.MK1_CLOUD_DURATION),
        surface_index = event.surface_index,
        position = position,
        radius = is_mk2 and fallout_radius * shared.MK2_MULTIPLIER or fallout_radius,
        is_mk2 = is_mk2,
        force = force,
        contact_damage = is_mk2 and shared.MK2_CONTACT_DAMAGE or shared.MK1_CONTACT_DAMAGE,
    }
    storage.radiation_clouds[#storage.radiation_clouds + 1] = cloud

    if storage.debug_enabled then
        create_overlay(cloud, event.tick)
    end
end)

script.on_event(defines.events.on_player_used_capsule, function(event)
    if event.item.name ~= "uranium-antidote" then return end

    local player = game.get_player(event.player_index)
    local character = player and player.character
    if not (character and character.valid) then return end

    local stickers = character.stickers
    if stickers then
        for _, sticker in pairs(stickers) do
            if sticker.valid and sticker.name == STICKER then
                sticker.destroy()
            end
        end
    end

    local unit_number = character.unit_number
    if unit_number then
        untrack(unit_number)
    end

    player.print({"message.cured"})
end)

--------------------------------------------------------------------------------
-- debug command
--------------------------------------------------------------------------------

commands.add_command("uranium-debug", {"command-help.uranium-debug"}, function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if player and not player.admin then
        player.print({"message.uranium-debug-admin-only"})
        return
    end

    local argument = (command.parameter or ""):lower()
    if argument == "on" then
        storage.debug_enabled = true
    elseif argument == "off" then
        storage.debug_enabled = false
    else
        storage.debug_enabled = not storage.debug_enabled
    end

    local tick = game.tick
    for i = #storage.radiation_clouds, 1, -1 do
        local cloud = storage.radiation_clouds[i]
        if cloud.expires_tick <= tick then
            destroy_overlay(cloud)
            table.remove(storage.radiation_clouds, i)
        elseif storage.debug_enabled then
            destroy_overlay(cloud)
            create_overlay(cloud, tick)
        else
            destroy_overlay(cloud)
        end
    end

    local message = {storage.debug_enabled and "message.uranium-debug-on" or "message.uranium-debug-off"}
    if player then
        player.print(message)
    else
        game.print(message)
    end
end)
