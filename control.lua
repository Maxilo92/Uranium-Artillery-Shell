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

    -- Infection mechanic: Mutated units infect others on contact (attack)
    local cause = event.cause
    if cause and cause.valid and cause.type == "unit" and string.find(cause.name, "^mutated%-") then
        -- Check setting
        local mutation_setting = settings.global["uranium-mutation-enabled"]
        if mutation_setting and mutation_setting.value then
            -- If the attacker is a mutated unit, infect the target
            if (entity.type == "unit" or entity.type == "character") and not string.find(entity.name, "^mutated%-") then
                 entity.surface.create_entity{
                    name = "uranium-radiation-sticker",
                    position = entity.position,
                    target = entity
                }
            end
        end
    end

    -- Handle percentage damage for units (biters/spitters) to overcome regeneration/high HP
    -- Only run this check once per second per entity to save performance
    if entity.type == "unit" then
        if event.damage_type.name == "poison" and (game.tick % 60 == 0) then
            if entity.stickers then
                local has_sticker = false
                for _, sticker in pairs(entity.stickers) do
                    if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                        has_sticker = true
                        break
                    end
                end
                
                if has_sticker then
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
        end

    -- Handle percentage damage for players (5% per second)
    elseif entity.type == "character" then
        if not settings.global["uranium-player-damage-enabled"].value then return end
        
        if event.damage_type.name == "poison" and (game.tick % 60 == 0) then
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

    -- Check if it's a spawner
    elseif entity.type == "unit-spawner" then
        -- Check if it has the radiation sticker
        local is_irradiated = false
        if entity.stickers then
            for _, sticker in pairs(entity.stickers) do
                if sticker.valid and sticker.name == "uranium-radiation-sticker" then
                    is_irradiated = true
                    break
                end
            end
        end

        if is_irradiated then
            -- Check setting
            local mutation_setting = settings.global["uranium-mutation-enabled"]
            if mutation_setting and not mutation_setting.value then return end

            -- Check if it's already mutated
            if string.find(entity.name, "mutated") then return end

            -- Mutate it
            local new_name = "mutated-" .. entity.name
            -- Check if the mutated version exists
            if game.entity_prototypes[new_name] then
                local surface = entity.surface
                local position = entity.position
                local force = entity.force
                local health_ratio = entity.health / entity.max_health
                
                -- Create new entity
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
                    -- Re-apply sticker to ensure it stays irradiated
                    if new_entity.valid then
                         surface.create_entity{
                            name = "uranium-radiation-sticker",
                            position = position,
                            target = new_entity
                        }
                    end
                end
            end
        end
    end
end)

