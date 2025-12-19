-- Initialize global table for mutation timers and debug mode
script.on_init(function()
    global = global or {}
    global.irradiation_timers = {}
    global.debug_mode = false
    global.mutated_carriers = {}
    global.carrier_cursor = 1
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
    
    -- Ensure global table exists (for existing saves)
    if not global then return end
    global.irradiation_timers = global.irradiation_timers or {}

    -- Infection mechanic: Mutated units infect others on contact (attack)
    local cause = event.cause
    if cause and cause.valid and cause.type == "unit" and string.find(cause.name, "^mutated%-") then
        -- Check setting
        local mutation_setting = settings.global["uranium-mutation-enabled"]
        if mutation_setting and mutation_setting.value then
            -- If the attacker is a mutated unit, infect the target (including normal nests)
            if entity.type == "unit" or entity.type == "character" or entity.type == "unit-spawner" then
                -- Skip if already mutated
                if not string.find(entity.name, "^mutated%-") then
                    entity.surface.create_entity{
                        name = "uranium-radiation-sticker",
                        position = entity.position,
                        target = entity
                    }
                    if entity.unit_number then
                        global.mutated_carriers[entity.unit_number] = entity
                    end
                    
                    -- Debug message
                    if global.debug_mode then
                        game.print("[DEBUG] " .. cause.name .. " infected " .. entity.name .. " via attack")
                    end
                end
            end
        end
    end

    -- Optimization: Only check for radiation effects if damage is acid (from sticker) or if we are checking for mutation
    -- Since the sticker deals acid damage every tick, we can rely on that to trigger the check.
    -- We skip this check for other damage types to save performance (e.g. gunshots).
    if event.damage_type.name ~= "acid" then return end

    -- Handle percentage damage for units (biters/spitters) to overcome regeneration/high HP
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
            -- Mutation Logic with Delay
            local mutation_setting = settings.global["uranium-mutation-enabled"]
            if mutation_setting and mutation_setting.value and not string.find(entity.name, "^mutated%-") then
                local new_name = "mutated-" .. entity.name
                -- Attempt mutation without relying on prototype tables; mutation will be pcalled later
                do
                    local unit_number = entity.unit_number
                    if unit_number then
                        -- Initialize timer if not exists
                        if not global.irradiation_timers[unit_number] then
                            global.irradiation_timers[unit_number] = game.tick
                        end
                        
                        -- Check if enough time has passed
                        local delay_ticks = settings.global["uranium-mutation-delay"].value * 60
                        local elapsed = game.tick - global.irradiation_timers[unit_number]
                        
                        if elapsed >= delay_ticks then
                            local surface = entity.surface
                            local position = entity.position
                            local force = entity.force
                            local health_ratio = entity.health / entity.max_health
                            local unit_group = (entity.type == "unit" and entity.unit_group) or nil
                            
                            -- Create mutation effect
                            surface.create_entity{
                                name = "uranium-explosion-smoke",
                                position = position
                            }
                            
                            -- Debug message
                            if global.debug_mode then
                                game.print("[DEBUG] Mutating " .. entity.name .. " at " .. serpent.line(position))
                            end
                            
                            local ok_create, new_entity = pcall(function()
                                return surface.create_entity{
                                    name = new_name,
                                    position = position,
                                    force = force,
                                    fast_replace = true,
                                    spill = false,
                                    create_build_effect_smoke = false
                                }
                            end)
                            if ok_create and new_entity then
                                new_entity.health = new_entity.max_health * health_ratio
                                
                                if unit_group and unit_group.valid then
                                    unit_group.add_member(new_entity)
                                end

                                surface.create_entity{
                                    name = "uranium-radiation-sticker",
                                    position = position,
                                    target = new_entity
                                }
                                -- Track mutated carrier for efficient contagion
                                if new_entity.unit_number then
                                    global.mutated_carriers[new_entity.unit_number] = new_entity
                                end
                                
                                -- Clean up timer
                                global.irradiation_timers[unit_number] = nil
                                
                                if entity.valid then
                                    entity.destroy()
                                end
                                
                                return
                            end
                        end
                    end
                end
            end

            -- Percentage Damage Logic
            if (game.tick % 60 == 0) then
                -- Deal percentage of max health as extra damage
                local damage_percent = settings.global["uranium-radiation-damage-percent"].value / 100
                local damage_amount = entity.max_health * damage_percent
                if entity.health > damage_amount then
                    entity.health = entity.health - damage_amount
                else
                    -- Clean up timer before death
                    local unit_number = entity.unit_number
                    if unit_number and global.irradiation_timers[unit_number] then
                        global.irradiation_timers[unit_number] = nil
                    end
                    entity.die(entity.force)
                end
            end
        end

    -- Handle percentage damage for players (5% per second)
    elseif entity.type == "character" then
        if not settings.global["uranium-player-damage-enabled"].value then return end
        
        if (game.tick % 60 == 0) then
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
end, {
    {filter = "type", type = "unit"},
    {filter = "type", type = "unit-spawner"},
    {filter = "type", type = "turret"},
    {filter = "type", type = "character"}
})

-- Commands
commands.add_command("uranium-give", "Give uranium artillery shells and antidotes", function(command)
    local player = game.get_player(command.player_index)
    if player then
        player.insert{name="uranium-artillery-shell", count=10}
        player.insert{name="uranium-antidote", count=10}
        player.print("Received Uranium Artillery Shells and Antidotes.")
    end
end)

commands.add_command("uranium-clear", "Remove all radiation from the surface", function(command)
    local player = game.get_player(command.player_index)
    if player then
        local surface = player.surface
        local count = 0
        for _, entity in pairs(surface.find_entities_filtered{name="uranium-radiation-sticker"}) do
            entity.destroy()
            count = count + 1
        end
        for _, entity in pairs(surface.find_entities_filtered{name="uranium-radiation-cloud"}) do
            entity.destroy()
            count = count + 1
        end
        player.print("Removed " .. count .. " radiation entities.")
    end
end)

commands.add_command("uranium-mutate", "Mutate the selected entity", function(command)
    local player = game.get_player(command.player_index)
    if player and player.selected then
        local entity = player.selected
        local new_name = "mutated-" .. entity.name
        do
            local surface = entity.surface
            local position = entity.position
            local force = entity.force
            local health_ratio = entity.health / entity.max_health
            local unit_group = (entity.type == "unit" and entity.unit_group) or nil
            
            local ok_create, new_entity = pcall(function()
                return surface.create_entity{
                    name = new_name,
                    position = position,
                    force = force,
                    fast_replace = true,
                    spill = false,
                    create_build_effect_smoke = false
                }
            end)
            if ok_create and new_entity then
                new_entity.health = new_entity.max_health * health_ratio
                if unit_group and unit_group.valid then
                    unit_group.add_member(new_entity)
                end
                if entity.valid then entity.destroy() end
                if new_entity.unit_number then
                    global.mutated_carriers[new_entity.unit_number] = new_entity
                end
                player.print("Entity mutated.")
            else
                player.print("This entity cannot be mutated.")
            end
        end
    else
        player.print("No entity selected.")
    end
end)

-- Debug mode command
commands.add_command("uranium-debug", "Toggle debug mode (makes radiation auras visible and shows debug messages)", function(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then return end
    
    -- Initialize if not exists
    if not global then global = {} end
    if global.debug_mode == nil then global.debug_mode = false end
    
    -- Toggle debug mode
    global.debug_mode = not global.debug_mode
    
    if global.debug_mode then
        player.print("[Uranium Artillery] Debug mode ENABLED - Radiation auras are now visible")
    else
        player.print("[Uranium Artillery] Debug mode DISABLED")
    end
end)

-- Auto-apply radiation sticker to mutated entities (for editor-spawned units)
script.on_event(defines.events.on_built_entity, function(event)
    if not global then return end
    
    local entity = event.entity or event.created_entity
    if entity and entity.valid and string.find(entity.name, "^mutated%-") then
        entity.surface.create_entity{
            name = "uranium-radiation-sticker",
            position = entity.position,
            target = entity
        }
        
        if entity.unit_number then
            global.mutated_carriers[entity.unit_number] = entity
        end
        if global.debug_mode then
            game.print("[DEBUG] Auto-applied radiation sticker to editor-spawned " .. entity.name)
        end
    end
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    if not global then return end
    
    local entity = event.entity or event.created_entity
    if entity and entity.valid and string.find(entity.name, "^mutated%-") then
        entity.surface.create_entity{
            name = "uranium-radiation-sticker",
            position = entity.position,
            target = entity
        }
        
        if entity.unit_number then
            global.mutated_carriers[entity.unit_number] = entity
        end
        if global.debug_mode then
            game.print("[DEBUG] Auto-applied radiation sticker to robot-built " .. entity.name)
        end
    end
end)

script.on_event(defines.events.script_raised_built, function(event)
    if not global then return end
    
    local entity = event.entity
    if entity and entity.valid and string.find(entity.name, "^mutated%-") then
        entity.surface.create_entity{
            name = "uranium-radiation-sticker",
            position = entity.position,
            target = entity
        }
        
        if entity.unit_number then
            global.mutated_carriers[entity.unit_number] = entity
        end
        if global.debug_mode then
            game.print("[DEBUG] Auto-applied radiation sticker to script-spawned " .. entity.name)
        end
    end
end)

script.on_event(defines.events.script_raised_revive, function(event)
    if not global then return end
    
    local entity = event.entity
    if entity and entity.valid and string.find(entity.name, "^mutated%-") then
        entity.surface.create_entity{
            name = "uranium-radiation-sticker",
            position = entity.position,
            target = entity
        }
        
        if entity.unit_number then
            global.mutated_carriers[entity.unit_number] = entity
        end
        if global.debug_mode then
            game.print("[DEBUG] Auto-applied radiation sticker to revived " .. entity.name)
        end
    end
end)

-- Clean up timers when entities are removed (prevent memory leaks)
script.on_event(defines.events.on_entity_died, function(event)
    if not global or not global.irradiation_timers then return end
    local entity = event.entity
    if entity and entity.unit_number then
        if global.irradiation_timers[entity.unit_number] then
            global.irradiation_timers[entity.unit_number] = nil
        end
        if global.mutated_carriers and global.mutated_carriers[entity.unit_number] then
            global.mutated_carriers[entity.unit_number] = nil
        end
    end
    
    -- Periodic cleanup every 600 ticks (10 seconds) to prevent memory bloat
    if game.tick % 600 == 0 then
        local surface_entities = game.surfaces[1].find_entities()
        local valid_unit_numbers = {}
        for _, e in pairs(surface_entities) do
            if e.unit_number then
                valid_unit_numbers[e.unit_number] = true
            end
        end
        
        for unit_num in pairs(global.irradiation_timers) do
            if not valid_unit_numbers[unit_num] then
                global.irradiation_timers[unit_num] = nil
            end
        end
        if global.mutated_carriers then
            for unit_num in pairs(global.mutated_carriers) do
                if not valid_unit_numbers[unit_num] then
                    global.mutated_carriers[unit_num] = nil
                end
            end
        end
    end
end)

script.on_event(defines.events.script_raised_destroy, function(event)
    if not global or not global.irradiation_timers then return end
    local entity = event.entity
    if entity and entity.unit_number then
        if global.irradiation_timers[entity.unit_number] then
            global.irradiation_timers[entity.unit_number] = nil
        end
        if global.mutated_carriers and global.mutated_carriers[entity.unit_number] then
            global.mutated_carriers[entity.unit_number] = nil
        end
    end
end)

-- Remote Interface
remote.add_interface("uranium_artillery", {
    mutate_entity = function(entity)
        if entity and entity.valid then
            local new_name = "mutated-" .. entity.name
            do
                local surface = entity.surface
                local position = entity.position
                local force = entity.force
                local health_ratio = entity.health / entity.max_health
                local unit_group = (entity.type == "unit" and entity.unit_group) or nil
                
                local ok_create, new_entity = pcall(function()
                    return surface.create_entity{
                        name = new_name,
                        position = position,
                        force = force,
                        fast_replace = true,
                        spill = false,
                        create_build_effect_smoke = false
                    }
                end)
                if ok_create and new_entity then
                    new_entity.health = new_entity.max_health * health_ratio
                    if unit_group and unit_group.valid then
                        unit_group.add_member(new_entity)
                    end
                    if entity.valid then entity.destroy() end
                    return new_entity
                end
            end
        end
        return nil
    end
})

-- Contagion via radiation aura clouds
script.on_event(defines.events.on_tick, function(event)
    if not global then return end

    -- Check every 20 ticks (0.33 seconds)
    if event.tick % 20 ~= 0 then return end

    local contagion_enabled = settings.global["uranium-proximity-contagion-enabled"].value
    if not contagion_enabled then return end

    -- Build a list of valid carriers from tracked set and batch process
    local ids = {}
    local total = 0
    for unit_number, entity in pairs(global.mutated_carriers) do
        if entity and entity.valid then
            total = total + 1
            ids[total] = unit_number
        else
            -- Clean invalid entries on the fly
            global.mutated_carriers[unit_number] = nil
        end
    end

    if total == 0 then return end

    local batch_size = 50
    local start_idx = global.carrier_cursor or 1
    local end_idx = math.min(start_idx + batch_size - 1, total)

    -- Process the batch
    for i = start_idx, end_idx do
        local unit_number = ids[i]
        local entity = global.mutated_carriers[unit_number]
        if entity and entity.valid then
            local surface = entity.surface

            -- In debug, show visible aura; otherwise skip to save UPS
            if global.debug_mode then
                surface.create_entity{
                    name = "uranium-radiation-aura-debug",
                    position = entity.position
                }
                rendering.draw_circle{
                    color = {r=0, g=255, b=0},
                    radius = 7,
                    width = 2,
                    target = entity,
                    surface = surface,
                    time_to_live = 25,
                    draw_on_ground = true
                }
            end

            -- Directly apply proximity contagion around the carrier
            local nearby = surface.find_entities_filtered{
                position = entity.position,
                radius = 7,
                type = {"unit", "unit-spawner", "turret"},
                limit = 15
            }

            for _, target in pairs(nearby) do
                if target.valid and target ~= entity then
                    -- Check if already has sticker
                    local has_sticker = false
                    if target.stickers then
                        for _, s in pairs(target.stickers) do
                            if s.valid and s.name == "uranium-radiation-sticker" then
                                has_sticker = true
                                break
                            end
                        end
                    end

                    if not has_sticker then
                        if target.type == "unit" or target.type == "character" then
                            -- Units/characters accept stickers
                            surface.create_entity{
                                name = "uranium-radiation-sticker",
                                position = target.position,
                                target = target
                            }
                            if target.unit_number then
                                global.mutated_carriers[target.unit_number] = target
                            end
                            if global.debug_mode then
                                game.print("[DEBUG] " .. entity.name .. " infected " .. target.name .. " via proximity (sticker)")
                            end
                        else
                            -- Nests (unit-spawner) and worms (turret) don't accept stickers; try direct mutation
                            local target_name = target.name
                            local new_name = "mutated-" .. target_name
                            local pos = target.position
                            local force = target.force
                            local health_ratio = target.health and target.max_health and (target.health / target.max_health) or 1
                            local unit_group = (target.type == "unit" and target.unit_group) or nil
                            local ok, new_entity = pcall(function()
                                return surface.create_entity{
                                    name = new_name,
                                    position = pos,
                                    force = force,
                                    fast_replace = true,
                                    spill = false,
                                    create_build_effect_smoke = false
                                }
                            end)
                            if ok and new_entity then
                                if new_entity.max_health and health_ratio then
                                    new_entity.health = new_entity.max_health * health_ratio
                                end
                                if unit_group and unit_group.valid then
                                    unit_group.add_member(new_entity)
                                end
                                if target.valid then target.destroy() end
                                if new_entity.unit_number then
                                    global.mutated_carriers[new_entity.unit_number] = new_entity
                                end
                                if global.debug_mode then
                                    game.print("[DEBUG] Mutated " .. target_name .. " via proximity into " .. new_name)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Advance cursor for next tick
    global.carrier_cursor = end_idx + 1
    if global.carrier_cursor > total then
        global.carrier_cursor = 1
    end
end)
