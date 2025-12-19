-- Initialize globals and register command to toggle debug overlays
script.on_init(function()
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.debug_enabled = global.debug_enabled or false
end)

-- Ensure globals exist after configuration changes or save loads
script.on_configuration_changed(function(_)
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.debug_enabled = global.debug_enabled or false
end)

commands.add_command("uranium-debug", "Enable debug overlays (on/off/toggle)", function(cmd)
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.debug_enabled = global.debug_enabled or false
    local arg = (cmd.parameter or ""):lower()
    if arg == "on" then
        global.debug_enabled = true
        game.print("[Uranium] Debug overlays: ON")
    elseif arg == "off" then
        global.debug_enabled = false
        game.print("[Uranium] Debug overlays: OFF")
        -- Clean up overlay tracking (rendered items are ephemeral and will expire)
        global.cloud_overlays = {}
    else
        global.debug_enabled = not global.debug_enabled
        game.print("[Uranium] Debug overlays toggled: " .. (global.debug_enabled and "ON" or "OFF"))
    end
end)

script.on_event(defines.events.on_player_used_capsule, function(event)
    local item = event.item
    if item.name == "uranium-antidote" then
        local player = game.get_player(event.player_index)
        if player and player.character then
            -- Remove the radiation sticker
            if player.character.stickers then
                for _, sticker in pairs(player.character.stickers) do
                    if sticker.name == "uranium-radiation-sticker" then
                        sticker.destroy()
                    end
                end
            end
            player.print({"message.cured"})
        end
    end
end)

script.on_event(defines.events.on_entity_damaged, function(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    -- Handle percentage damage and mutation for units, turrets, and spawners
    -- Only run this check once per second per entity to save performance
    if entity.type == "unit" or entity.type == "turret" or entity.type == "unit-spawner" then
        local has_sticker = false
        if entity.stickers then
            for _, sticker in pairs(entity.stickers) do
                if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                    has_sticker = true
                    break
                end
            end
        end
        
        if has_sticker then
            -- Mutation Logic
            local mutation_setting = settings.global["uranium-mutation-enabled"]
            if mutation_setting and mutation_setting.value and not string.find(entity.name, "^mutated%-") then
                local new_name = "mutated-" .. entity.name
                if prototypes.entity[new_name] then
                    local surface = entity.surface
                    local position = entity.position
                    local force = entity.force
                    local health_ratio = entity.health / entity.max_health
                    
                    local new_entity = surface.create_entity{
                        name = new_name,
                        position = position,
                        force = force,
                        fast_replace = true,
                        spill = false,
                        create_build_effect_smoke = false
                    }
                    if new_entity then
                        new_entity.health = new_entity.max_health * health_ratio
                        -- Re-apply sticker only to entities that accept stickers (units/characters/turrets)
                        if new_entity.type == "unit" or new_entity.type == "character" or new_entity.type == "turret" then
                            surface.create_entity{
                                name = "uranium-radiation-sticker",
                                position = position,
                                target = new_entity
                            }
                        end
                        
                        -- Ensure the old entity is removed to prevent duplication
                        if entity.valid then
                            entity.destroy()
                        end
                        
                        return -- Entity replaced
                    end
                end
            end

            -- Percentage Damage Logic
            if event.damage_type.name == "acid" and (game.tick % 60 == 0) then
                -- Deal percentage of max health as extra damage
                local damage_percent = settings.global["uranium-radiation-damage-percent"].value / 100
                local damage_amount = entity.max_health * damage_percent
                if entity.health > damage_amount then
                    entity.health = entity.health - damage_amount
                else
                    entity.die(entity.force)
                end
            end
        end

    -- Handle percentage damage for players
    elseif entity.type == "character" then
        if not settings.global["uranium-player-damage-enabled"].value then return end
        
        if event.damage_type.name == "acid" and (game.tick % 60 == 0) then
            if entity.stickers then
                local has_sticker = false
                for _, sticker in pairs(entity.stickers) do
                    if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                        has_sticker = true
                        break
                    end
                end
                
                if has_sticker then
                    -- Deal 5% of max health as extra damage
                    local damage_amount = entity.max_health * 0.05
                    if entity.health > damage_amount then
                        entity.health = entity.health - damage_amount
                    else
                        entity.die(entity.force)
                    end
                end
            end
        end
    end
end)

-- Script trigger effects: mutate spawners on contact and create debug overlays for clouds
script.on_event(defines.events.on_script_trigger_effect, function(event)
    if not global then global = {} end
    -- Mutate spawners when any entity is affected by the radiation cloud (independent of damage/resistance)
    if event.effect_id == "uranium-radiation-contact" then
        local target = event.target_entity
        if target and target.valid and target.type == "unit-spawner" then
            local mutation_setting = settings.global["uranium-mutation-enabled"]
            if mutation_setting and mutation_setting.value and not string.find(target.name, "^mutated%-") then
                local new_name = "mutated-" .. target.name
                if prototypes.entity[new_name] then
                    local surface = target.surface
                    local position = target.position
                    local force = target.force
                    local health_ratio = target.health / target.max_health

                    local new_entity = surface.create_entity{
                        name = new_name,
                        position = position,
                        force = force,
                        fast_replace = true,
                        spill = false,
                        create_build_effect_smoke = false
                    }
                    if new_entity then
                        new_entity.health = new_entity.max_health * health_ratio
                        -- Do not re-apply sticker to spawners (they do not accept stickers)
                        if target.valid then target.destroy() end
                    end
                end
            end
        end
        return
    end

    -- Debug overlay for created radiation clouds
    if event.effect_id == "uranium-cloud-created" then
        if not global or not global.debug_enabled then return end
        global.cloud_overlays = global.cloud_overlays or {}

        local surface = game.surfaces[event.surface_index]
        if not surface then return end

        local position = event.target_position or event.position or event.source_position
        if not position then return end

        local radius = settings.startup["uranium-artillery-radius"].value
        local expires_tick = game.tick + 1800 -- cloud.duration

        local circle_id = rendering.draw_circle{
            color = {r=0.1, g=1, b=0.1, a=0.5},
            radius = radius,
            filled = false,
            surface = surface,
            target = position,
            time_to_live = 1800 -- match cloud duration, auto-expire
        }

        -- Initial text (will be redrawn each second with TTL)
        rendering.draw_text{
            text = "Radiation: 30s",
            surface = surface,
            target = position,
            color = {r=0.6, g=1, b=0.6},
            alignment = "center",
            vertical_alignment = "bottom",
            scale = 1.2,
            time_to_live = 60
        }

        table.insert(global.cloud_overlays, {
            circle_id = circle_id,
            expires_tick = expires_tick,
                surface_index = event.surface_index,
                position = position
        })
    end
end)

-- Update debug overlay timers once per second
script.on_event(defines.events.on_tick, function()
    if (not global) or (not global.cloud_overlays) or (game.tick % 60 ~= 0) then return end
    for i = #global.cloud_overlays, 1, -1 do
        local o = global.cloud_overlays[i]
        local remaining = math.max(0, math.ceil((o.expires_tick - game.tick) / 60))
        if remaining <= 0 then
            -- Let overlays expire naturally; just stop tracking
            table.remove(global.cloud_overlays, i)
        else
            local surface = game.surfaces[o.surface_index]
            if surface and o.position then
                rendering.draw_text{
                    text = "Radiation: " .. remaining .. "s",
                    surface = surface,
                    target = o.position,
                    color = {r=0.6, g=1, b=0.6},
                    alignment = "center",
                    vertical_alignment = "bottom",
                    scale = 1.2,
                    time_to_live = 60
                }
            end
        end
    end
end)

