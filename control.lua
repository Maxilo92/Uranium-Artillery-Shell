-- Initialize globals and register command to toggle debug overlays
script.on_init(function()
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.debug_enabled = global.debug_enabled or false
    global.entity_mutations = global.entity_mutations or {} -- Track mutation timing to prevent race conditions
    global.radiation_targets = global.radiation_targets or {} -- Track sticker application ticks for decay logic
    global.player_radiation_glows = global.player_radiation_glows or {} -- Track player radiation glow rendering IDs
end)

-- Ensure globals exist after configuration changes or save loads
script.on_configuration_changed(function(_)
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.debug_enabled = global.debug_enabled or false
    global.entity_mutations = global.entity_mutations or {} -- Track mutation timing to prevent race conditions
    global.radiation_targets = global.radiation_targets or {} -- Track sticker application ticks for decay logic
    global.player_radiation_glows = global.player_radiation_glows or {} -- Track player radiation glow rendering IDs
end)

commands.add_command("uranium-debug", "Enable debug overlays (on/off/toggle)", function(cmd)
    if not global then global = {} end
    global.cloud_overlays = global.cloud_overlays or {}
    global.radiation_clouds = global.radiation_clouds or {}
    global.debug_enabled = global.debug_enabled or false
    local arg = (cmd.parameter or ""):lower()
    if arg == "on" then
        global.debug_enabled = true
        game.print("[Uranium] Debug overlays: ON")
        
        -- Create overlays for all existing radiation clouds
        for i = #global.radiation_clouds, 1, -1 do
            local cloud = global.radiation_clouds[i]
            local remaining_ticks = cloud.expires_tick - game.tick
            if remaining_ticks > 0 then
                local surface = game.surfaces[cloud.surface_index]
                if surface then
                    local circle_id = rendering.draw_circle{
                        color = cloud.is_mk2 and {r=0.05, g=1, b=0.2, a=0.6} or {r=0.1, g=1, b=0.1, a=0.5},
                        radius = cloud.radius,
                        filled = false,
                        surface = surface,
                        target = cloud.position,
                        time_to_live = remaining_ticks
                    }
                    
                    local remaining_seconds = math.ceil(remaining_ticks / 60)
                    local label = cloud.is_mk2 and "MK2 Radiation: " or "Radiation: "
                    local color = cloud.is_mk2 and {r=0.2, g=1, b=0.4} or {r=0.6, g=1, b=0.6}
                    local scale = cloud.is_mk2 and 1.4 or 1.2
                    
                    rendering.draw_text{
                        text = label .. remaining_seconds .. "s",
                        surface = surface,
                        target = cloud.position,
                        color = color,
                        alignment = "center",
                        vertical_alignment = "bottom",
                        scale = scale,
                        time_to_live = 60
                    }
                    
                    table.insert(global.cloud_overlays, {
                        circle_id = circle_id,
                        expires_tick = cloud.expires_tick,
                        surface_index = cloud.surface_index,
                        position = cloud.position,
                        is_mk2 = cloud.is_mk2
                    })
                end
            else
                -- Cloud expired, remove from tracking
                table.remove(global.radiation_clouds, i)
            end
        end
    elseif arg == "off" then
        global.debug_enabled = false
        game.print("[Uranium] Debug overlays: OFF")
        -- Clean up overlay tracking (rendered items are ephemeral and will expire)
        global.cloud_overlays = {}
    else
        global.debug_enabled = not global.debug_enabled
        game.print("[Uranium] Debug overlays toggled: " .. (global.debug_enabled and "ON" or "OFF"))
        
        if global.debug_enabled then
            -- Create overlays for existing clouds when toggling on
            for i = #global.radiation_clouds, 1, -1 do
                local cloud = global.radiation_clouds[i]
                local remaining_ticks = cloud.expires_tick - game.tick
                if remaining_ticks > 0 then
                    local surface = game.surfaces[cloud.surface_index]
                    if surface then
                        local circle_id = rendering.draw_circle{
                            color = cloud.is_mk2 and {r=0.05, g=1, b=0.2, a=0.6} or {r=0.1, g=1, b=0.1, a=0.5},
                            radius = cloud.radius,
                            filled = false,
                            surface = surface,
                            target = cloud.position,
                            time_to_live = remaining_ticks
                        }
                        
                        local remaining_seconds = math.ceil(remaining_ticks / 60)
                        local label = cloud.is_mk2 and "MK2 Radiation: " or "Radiation: "
                        local color = cloud.is_mk2 and {r=0.2, g=1, b=0.4} or {r=0.6, g=1, b=0.6}
                        local scale = cloud.is_mk2 and 1.4 or 1.2
                        
                        rendering.draw_text{
                            text = label .. remaining_seconds .. "s",
                            surface = surface,
                            target = cloud.position,
                            color = color,
                            alignment = "center",
                            vertical_alignment = "bottom",
                            scale = scale,
                            time_to_live = 60
                        }
                        
                        table.insert(global.cloud_overlays, {
                            circle_id = circle_id,
                            expires_tick = cloud.expires_tick,
                            surface_index = cloud.surface_index,
                            position = cloud.position,
                            is_mk2 = cloud.is_mk2
                        })
                    end
                else
                    table.remove(global.radiation_clouds, i)
                end
            end
        else
            global.cloud_overlays = {}
        end
    end
end)

-- Clean up orphaned overlays when player leaves game (helps with memory cleanup)
script.on_event(defines.events.on_player_left_game, function()
    if global and global.cloud_overlays then
        global.cloud_overlays = {}
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
            -- Remove radiation glow when cured
            if global.player_radiation_glows[player.index] then
                rendering.free(global.player_radiation_glows[player.index])
                global.player_radiation_glows[player.index] = nil
            end
            if global.radiation_targets then
                global.radiation_targets[player.character.unit_number] = nil
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
            -- Track sticker age for decay
            local unit_id = entity.unit_number
            local applied_tick = game.tick
            if unit_id then
                local entry = (global.radiation_targets or {})[unit_id]
                if entry and entry.applied_tick then
                    applied_tick = entry.applied_tick
                else
                    global.radiation_targets[unit_id] = {applied_tick = game.tick}
                end
            end

            -- Mutation Logic (gated to once per second to prevent race conditions with on_script_trigger_effect)
            if event.damage_type.name == "acid" and (game.tick % 60 == 0) then
                local mutation_setting = settings.global["uranium-mutation-enabled"]
                if mutation_setting and mutation_setting.value and not string.find(entity.name, "^mutated%-") then
                    -- Check if this entity mutated recently to prevent race condition with on_script_trigger_effect handler
                    local last_mutation_tick = global.entity_mutations[unit_id] or 0
                    if game.tick - last_mutation_tick >= 60 then  -- Only allow mutations once per second
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
                                
                                -- Track mutation and destroy old entity
                                global.entity_mutations[unit_id] = game.tick
                                if global.radiation_targets then
                                    global.radiation_targets[unit_id] = nil -- reset decay tracking for old entity
                                end
                                if entity.valid then
                                    entity.destroy()
                                end
                                
                                return -- Entity replaced
                            else
                                -- Log error if entity creation failed
                                log("[Uranium] Failed to create mutated entity " .. new_name .. " at position (" .. position.x .. ", " .. position.y .. ")")
                            end
                        end
                    end
                end
            end

            -- Percentage Damage Logic (only apply if entity still valid after potential mutation)
            if entity.valid and event.damage_type.name == "acid" and (game.tick % 60 == 0) then
                -- Compute decay factor based on sticker age (30s lifetime to 20% strength)
                local age_ticks = game.tick - applied_tick
                local decay_factor = math.max(0.2, 1 - (age_ticks / 1800))

                local damage_percent = (settings.global["uranium-radiation-damage-percent"].value / 100) * decay_factor
                local damage_amount = entity.max_health * damage_percent
                if entity.health > damage_amount then
                    entity.health = entity.health - damage_amount
                else
                    entity.die(entity.force)
                end
            end
        else
            -- No sticker: clear decay tracking
            if entity.unit_number and global.radiation_targets then
                global.radiation_targets[entity.unit_number] = nil
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
                    -- Track sticker age for decay
                    local unit_id = entity.unit_number
                    local applied_tick = game.tick
                    if unit_id then
                        local entry = (global.radiation_targets or {})[unit_id]
                        if entry and entry.applied_tick then
                            applied_tick = entry.applied_tick
                        else
                            global.radiation_targets[unit_id] = {applied_tick = game.tick}
                        end
                    end
                    -- Deal percentage of max health as extra damage (use mod setting, scaled by decay)
                    local age_ticks = game.tick - applied_tick
                    local decay_factor = math.max(0.2, 1 - (age_ticks / 1800))
                    local damage_percent = (settings.global["uranium-radiation-damage-percent"].value / 100) * decay_factor
                    local damage_amount = entity.max_health * damage_percent
                    if entity.health > damage_amount then
                        entity.health = entity.health - damage_amount
                    else
                        entity.die(entity.force)
                    end
                else
                    if entity.unit_number and global.radiation_targets then
                        global.radiation_targets[entity.unit_number] = nil
                    end
                end
            end
        end
    end
end)

script.on_event(defines.events.on_script_trigger_effect, function(event)
    if not global then global = {} end
    -- Mutate spawners when any entity is affected by the radiation cloud (independent of damage/resistance)
    local contact_effects = {
        ["uranium-radiation-contact"] = true,
        ["uranium-radiation-contact-mk2"] = true,
    }
    if contact_effects[event.effect_id] then
        local target = event.target_entity
        if target and target.valid and target.type == "unit-spawner" then
            local mutation_setting = settings.global["uranium-mutation-enabled"]
            if mutation_setting and mutation_setting.value and not string.find(target.name, "^mutated%-") then
                -- Check if this spawner mutated recently to prevent race condition with on_entity_damaged handler
                local unit_id = target.unit_number
                local last_mutation_tick = global.entity_mutations[unit_id] or 0
                if game.tick - last_mutation_tick >= 60 then  -- Only allow mutations once per second
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
                            -- Do not re-apply sticker to spawners (they do not accept stickers as targets)
                            
                            -- Track mutation and destroy old entity
                            global.entity_mutations[unit_id] = game.tick
                            if target.valid then target.destroy() end
                        else
                            -- Log error if entity creation failed
                            log("[Uranium] Failed to create mutated spawner " .. new_name .. " at position (" .. position.x .. ", " .. position.y .. ")")
                        end
                    end
                end
            end
        end
        return
    end

    -- Track radiation clouds (always, regardless of debug status)
    if event.effect_id == "uranium-cloud-created" then
        if not global then global = {} end
        global.radiation_clouds = global.radiation_clouds or {}
        global.cloud_overlays = global.cloud_overlays or {}

        local surface = game.surfaces[event.surface_index]
        if not surface then return end

        local position = event.target_position or event.position or event.source_position
        if not position then return end

        local radius = settings.startup["uranium-artillery-radius"].value
        local duration = 1800 -- MK1: 30 seconds
        local expires_tick = game.tick + duration
        
        -- Always track cloud data
        table.insert(global.radiation_clouds, {
            expires_tick = expires_tick,
            surface_index = event.surface_index,
            position = position,
            radius = radius,
            is_mk2 = false
        })
        
        -- Only create overlay if debug is enabled
        if not global.debug_enabled then return end

        local circle_id = rendering.draw_circle{
            color = {r=0.1, g=1, b=0.1, a=0.5},
            radius = radius,
            filled = false,
            surface = surface,
            target = position,
            time_to_live = duration
        }

        -- Initial text (will be redrawn each second with TTL)
        local initial_duration_seconds = math.ceil(duration / 60)
        rendering.draw_text{
            text = "Radiation: " .. initial_duration_seconds .. "s",
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
    
    -- Track MK2 radiation clouds (always, regardless of debug status)
    if event.effect_id == "uranium-cloud-created-mk2" then
        if not global then global = {} end
        global.radiation_clouds = global.radiation_clouds or {}
        global.cloud_overlays = global.cloud_overlays or {}

        local surface = game.surfaces[event.surface_index]
        if not surface then return end

        local position = event.target_position or event.position or event.source_position
        if not position then return end

        local radius = settings.startup["uranium-artillery-radius"].value * 3 -- MK2 is 3x larger
        local duration = 5400 -- 90 seconds
        local expires_tick = game.tick + duration
        
        -- Always track cloud data
        table.insert(global.radiation_clouds, {
            expires_tick = expires_tick,
            surface_index = event.surface_index,
            position = position,
            radius = radius,
            is_mk2 = true
        })
        
        -- Only create overlay if debug is enabled
        if not global.debug_enabled then return end

        local circle_id = rendering.draw_circle{
            color = {r=0.05, g=1, b=0.2, a=0.6},
            radius = radius,
            filled = false,
            surface = surface,
            target = position,
            time_to_live = duration
        }

        local initial_duration_seconds = 90
        rendering.draw_text{
            text = "MK2 Radiation: " .. initial_duration_seconds .. "s",
            surface = surface,
            target = position,
            color = {r=0.2, g=1, b=0.4},
            alignment = "center",
            vertical_alignment = "bottom",
            scale = 1.4,
            time_to_live = 60
        }

        table.insert(global.cloud_overlays, {
            circle_id = circle_id,
            expires_tick = expires_tick,
            surface_index = event.surface_index,
            position = position,
            is_mk2 = true
        })
    end
end)

-- Update debug overlay timers and player radiation glows
script.on_event(defines.events.on_tick, function()
    if not global then return end
    
    -- Update debug overlay timers once per second
    if global.cloud_overlays and (game.tick % 60 == 0) then
        for i = #global.cloud_overlays, 1, -1 do
            local o = global.cloud_overlays[i]
            local remaining = math.max(0, math.ceil((o.expires_tick - game.tick) / 60))
            if remaining <= 0 then
                -- Let overlays expire naturally; just stop tracking
                table.remove(global.cloud_overlays, i)
            else
                local surface = game.surfaces[o.surface_index]
                if surface and o.position then
                    local label = o.is_mk2 and "MK2 Radiation: " or "Radiation: "
                    local color = o.is_mk2 and {r=0.2, g=1, b=0.4} or {r=0.6, g=1, b=0.6}
                    local scale = o.is_mk2 and 1.4 or 1.2
                    
                    rendering.draw_text{
                        text = label .. remaining .. "s",
                        surface = surface,
                        target = o.position,
                        color = color,
                        alignment = "center",
                        vertical_alignment = "bottom",
                        scale = scale,
                        time_to_live = 60
                    }
                end
            end
        end
    end
    
    -- Update player radiation glows (every tick for smooth visual effect)
    if global.player_radiation_glows then
        for player_index, glow_id in pairs(global.player_radiation_glows) do
            local player = game.get_player(player_index)
            if player and player.character and player.character.valid then
                -- Check if player still has radiation sticker
                local has_sticker = false
                if player.character.stickers then
                    for _, sticker in pairs(player.character.stickers) do
                        if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                            has_sticker = true
                            break
                        end
                    end
                end
                
                if has_sticker then
                    -- Update glow position to follow player
                    if rendering.is_valid(glow_id) then
                        rendering.set_target(glow_id, player.character)
                    else
                        -- Glow was freed, recreate it using a green circle
                        glow_id = rendering.draw_circle{
                            color = {r=0.2, g=1, b=0.2, a=0.4},
                            radius = 0.8,
                            filled = true,
                            surface = player.character.surface,
                            target = player.character,
                            draw_on_ground = true
                        }
                        global.player_radiation_glows[player_index] = glow_id
                    end
                else
                    -- Player no longer has sticker, remove glow
                    if rendering.is_valid(glow_id) then
                        rendering.free(glow_id)
                    end
                    global.player_radiation_glows[player_index] = nil
                end
            else
                -- Player invalid, cleanup
                if rendering.is_valid(glow_id) then
                    rendering.free(glow_id)
                end
                global.player_radiation_glows[player_index] = nil
            end
        end
    end
    
    -- Create radiation glow for players that just got infected
    for _, player in pairs(game.players) do
        if player.character and player.character.valid then
            local has_sticker = false
            if player.character.stickers then
                for _, sticker in pairs(player.character.stickers) do
                    if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                        has_sticker = true
                        break
                    end
                end
            end
            
            if has_sticker and not global.player_radiation_glows[player.index] then
                -- Create new glow for this player
                local glow_id = rendering.draw_circle{
                    color = {r=0.2, g=1, b=0.2, a=0.4},
                    radius = 0.8,
                    filled = true,
                    surface = player.character.surface,
                    target = player.character,
                    draw_on_ground = true
                }
                global.player_radiation_glows[player.index] = glow_id
            end
        end
    end
end)

