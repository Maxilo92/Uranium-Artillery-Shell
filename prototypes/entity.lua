-- Helper to recursively tint animations
local function recursive_tint(anim, tint)
    if not anim then return end
    if anim.layers then
        for _, layer in pairs(anim.layers) do
            recursive_tint(layer, tint)
        end
    elseif anim.filenames or anim.stripes or anim.filename then
        -- It's a single animation definition
        anim.tint = tint
        if anim.hr_version then
            recursive_tint(anim.hr_version, tint)
        end
    elseif type(anim) == "table" then
        -- Check if it's a list of variations
        local is_list = false
        for k, _ in pairs(anim) do
            if type(k) == "number" then
                is_list = true
                break
            end
        end
        
        if is_list then
            for _, variation in pairs(anim) do
                if type(variation) == "table" then
                    recursive_tint(variation, tint)
                end
            end
        else
             -- Fallback for other structures
            anim.tint = tint
            if anim.hr_version then
                recursive_tint(anim.hr_version, tint)
            end
        end
    end
end

-- Helper to recursively scale animations
local function recursive_scale(anim, scale)
    if not anim then return end
    if anim.layers then
        for _, layer in pairs(anim.layers) do
            recursive_scale(layer, scale)
        end
    elseif anim.filenames or anim.stripes or anim.filename then
        anim.scale = (anim.scale or 1) * scale
        if anim.hr_version then
            recursive_scale(anim.hr_version, scale)
        end
    elseif type(anim) == "table" then
         -- Check if it's a list of variations
        local is_list = false
        for k, _ in pairs(anim) do
            if type(k) == "number" then
                is_list = true
                break
            end
        end
        
        if is_list then
            for _, variation in pairs(anim) do
                if type(variation) == "table" then
                    recursive_scale(variation, scale)
                end
            end
        else
            anim.scale = (anim.scale or 1) * scale
            if anim.hr_version then
                recursive_scale(anim.hr_version, scale)
            end
        end
    end
end

local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "uranium-artillery-projectile"

-- Add green glow to projectile (Tracer effect)
projectile.light = {intensity = 0.8, size = 15, color = {r=0.2, g=1, b=0.2}}
if projectile.animation then
    projectile.animation.tint = {r=0.5, g=1, b=0.5}
end

-- Define the radiation cloud (based on poison cloud)
local cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
cloud.name = "uranium-radiation-cloud"
cloud.duration = 1800 -- 30 seconds
cloud.fade_away_duration = 120
cloud.spread_duration = 20
cloud.color = {r=0.2, g=1, b=0.2, a=0.3} -- Greenish cloud, more transparent
cloud.affected_by_wind = false -- Stop it from moving
cloud.show_when_smoke_off = true
-- cloud.animation = nil -- Invisible cloud

-- Define a green fire trail for the sticker
local trail = table.deepcopy(data.raw["fire"]["fire-flame"])
trail.name = "uranium-radiation-trail"
trail.damage_per_tick = {amount = 0, type = "fire"} -- No extra damage, just visual
trail.maximum_damage_multiplier = 1
trail.initial_lifetime = 60
trail.lifetime_increase_by = 0
trail.lifetime_increase_cooldown = 100
trail.limit_one_per_tile = false
trail.spread_delay = 100
trail.spread_delay_deviation = 100
trail.maximum_spread_count = 100
trail.emissions_per_second = {} -- No pollution
trail.smoke = nil -- Invisible trail
-- Remove fire graphics, keep only smoke
trail.on_fuel_effect = nil
trail.working_sound = nil
trail.pictures = {
    {
        filename = "__core__/graphics/empty.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 1,
        axially_symmetrical = false,
        direction_count = 1,
        shift = {0, 0}
    }
}

-- Define the radiation sticker (persistent damage)
local sticker = {
    type = "sticker",
    name = "uranium-radiation-sticker",
    flags = {"not-on-map"},
    duration_in_ticks = 4294967295, -- Effectively infinite (until death or cured)
    target_movement_modifier = 0.8,
    damage_per_tick = { amount = 1 / 60, type = "acid" }, -- Minimal damage to trigger events, real damage is in control.lua
    spread_fire_entity = "uranium-radiation-trail", -- Leave a trail
    fire_spread_cooldown = 30, -- Every 0.5 seconds
    fire_spread_radius = 0.1,
    stickers = {
        {
            filename = "__core__/graphics/shoot-cursor-green.png", -- Simple green marker
            priority = "extra-high",
            width = 258,
            height = 183,
            shift = {0, 0},
            tint = {r=0.5, g=1, b=0.5, a=0.5},
            scale = 0.2,
            flags = {"no-crop"}
        }
    }
}
-- Define a glowing crater effect (using fire entity for light)
local glow = table.deepcopy(data.raw["fire"]["fire-flame"])
glow.name = "uranium-radiation-glow"
glow.damage_per_tick = {amount = 0, type = "fire"}
glow.maximum_damage_multiplier = 1
glow.initial_lifetime = 1800 -- 30 seconds
glow.lifetime_increase_by = 0
glow.lifetime_increase_cooldown = 100
glow.limit_one_per_tile = true
glow.spread_delay = 0
glow.spread_delay_deviation = 0
glow.maximum_spread_count = 0 -- Don't spread
glow.emissions_per_second = {}
-- Green light
glow.light = {intensity = 0.8, size = 20, color = {r=0.1, g=1, b=0.1}}
-- Remove smoke and fire graphics, we just want the light
glow.smoke = nil
glow.on_fuel_effect = nil
glow.pictures = nil 
glow.working_sound = nil
-- Add a subtle ground patch if possible, or just rely on light
-- Using a simple empty animation to avoid errors if pictures are required
glow.pictures = {
    {
        filename = "__core__/graphics/empty.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 1,
        axially_symmetrical = false,
        direction_count = 1,
        shift = {0, 0}
    }
}

data:extend({sticker, trail, glow})

-- Tint the cloud animation
if cloud.animation then
   -- Replace with generic smoke to avoid blue tint from poison-cloud
   -- Use "smoke" which is white/grey, so tinting works well
   cloud.animation = table.deepcopy(data.raw["trivial-smoke"]["smoke"].animation)
   recursive_scale(cloud.animation, 8) -- Make it large (radius ~6)
   recursive_tint(cloud.animation, {r=0.1, g=1, b=0.1, a=0.5})
   cloud.animation.animation_speed = 0.03 -- Slow motion smoke to last full duration
end
cloud.animation = nil -- Invisible cloud, but we keep the code above in case we want it back later

-- Cloud damage action
cloud.action = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "nested-result",
                action = {
                    type = "area",
                    radius = 25, -- Radiation radius (larger than explosion)
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "create-sticker",
                                sticker = "uranium-radiation-sticker"
                            },
                            {
                                type = "damage",
                                damage = {amount = 8, type = "acid"}
                            },
                            {
                                type = "script",
                                effect_id = "uranium-radiation-contact"
                            }
                        }
                    }
                }
            }
        }
    }
}
cloud.action_frequency = 30 -- Apply sticker every 0.5 seconds (30 ticks)

-- Define a green smoke for the explosion
-- Use "smoke" instead of "smoke-fast" for a fluffier, less triangular look
local smoke = table.deepcopy(data.raw["trivial-smoke"]["smoke"]) 
smoke.name = "uranium-explosion-smoke"
smoke.color = {r=0.2, g=1, b=0.2, a=0.5}
if smoke.animation then
    recursive_scale(smoke.animation, 2.5) -- Make it bigger
    recursive_tint(smoke.animation, {r=0.2, g=1, b=0.2, a=0.5})
end

-- Define the explosion visual
local source_name = "nuke-explosion"
if not data.raw["explosion"][source_name] then
    source_name = "atomic-bomb-explosion"
end
if not data.raw["explosion"][source_name] then
    source_name = "big-artillery-explosion"
end

local explosion = table.deepcopy(data.raw["explosion"][source_name])
explosion.name = "uranium-artillery-explosion"

-- Add green light flash to explosion
explosion.light = {intensity = 1, size = 50, color = {r=0.2, g=1, b=0.2}}

-- Tint the explosion animations green
-- Removed tinting as per request (explosion itself should not be green)
-- if explosion.animations then
--    recursive_tint(explosion.animations, {r=0.2, g=1, b=0.2, a=1})
-- end

-- Scale down the explosion to look "weaker"
local function scale_anim(anim)
    if anim.scale then
        anim.scale = anim.scale * 0.7
    else
        anim.scale = 0.7
    end
    -- Fix flags if they are a string (Factorio 2.0 requires a list)
    if anim.flags and type(anim.flags) == "string" then
        anim.flags = { anim.flags }
    end
    if anim.hr_version then
        scale_anim(anim.hr_version)
    end
end

if (source_name == "nuke-explosion" or source_name == "atomic-bomb-explosion") and explosion.animations then
    if explosion.animations.layers then
        for _, layer in pairs(explosion.animations.layers) do
            scale_anim(layer)
        end
    elseif explosion.animations.filename or explosion.animations.stripes or explosion.animations.filenames then
        scale_anim(explosion.animations)
    else
        -- Assume it's a list of variations
        for _, anim in pairs(explosion.animations) do
            if type(anim) == "table" then
                scale_anim(anim)
            end
        end
    end
end

-- Replace blue smoke with green smoke in explosion effects
if explosion.created_effect then
    local effects = explosion.created_effect
    if effects.type then effects = {effects} end
    for _, effect in pairs(effects) do
        -- Handle create-entity
        if effect.type == "create-entity" then
             if effect.entity_name and (string.find(effect.entity_name, "smoke") or string.find(effect.entity_name, "cloud")) then
                effect.entity_name = "uranium-explosion-smoke"
             end
        end
        -- Handle create-trivial-smoke
        if effect.type == "create-trivial-smoke" then
             if effect.smoke_name and (string.find(effect.smoke_name, "smoke") or string.find(effect.smoke_name, "cloud")) then
                effect.smoke_name = "uranium-explosion-smoke"
             end
        end
    end
end

-- Use nuclear explosion sound
if data.raw["explosion"]["atomic-bomb-explosion"] then
    explosion.sound = table.deepcopy(data.raw["explosion"]["atomic-bomb-explosion"].sound)
end

-- Update projectile action to use new effects
projectile.action = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "create-entity",
                entity_name = "uranium-artillery-explosion"
            },
            {
                type = "create-entity",
                entity_name = "uranium-radiation-cloud",
                offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
            },
            {
                type = "script",
                effect_id = "uranium-cloud-created"
            },
            {
                type = "create-entity",
                entity_name = "uranium-radiation-glow", -- The glowing crater effect
                offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
            },
            {
                type = "set-tile",
                tile_name = "nuclear-ground",
                radius = settings.startup["uranium-artillery-radius"].value,
                apply_projection = false,
                tile_collision_mask = { layers = { ["water_tile"] = true } }
            },
            {
                type = "nested-result",
                action = {
                    type = "area",
                    radius = settings.startup["uranium-artillery-radius"].value, -- Configurable radius
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "damage",
                                damage = {amount = settings.startup["uranium-artillery-damage"].value / 2, type = "physical"} -- Split damage
                            },
                            {
                                type = "damage",
                                damage = {amount = settings.startup["uranium-artillery-damage"].value / 2, type = "explosion"}
                            }
                        }
                    }
                }
            }
        }
    }
}

data:extend({projectile, cloud, explosion, smoke})

-- Define mutated units (Green versions)
local unit_mapping = {}
local units_to_mutate = {
    "small-biter", "medium-biter", "big-biter", "behemoth-biter",
    "small-spitter", "medium-spitter", "big-spitter", "behemoth-spitter"
}

-- Helper to buff damage
local function buff_damage(attack_parameters, multiplier)
    if not attack_parameters then return end
    local ammo_type = attack_parameters.ammo_type
    if not ammo_type then return end
    
    local action = ammo_type.action
    if not action then return end
    
    -- Handle array of actions
    local actions = action
    if action.type then actions = {action} end
    
    for _, act in pairs(actions) do
        if act.action_delivery then
            local deliveries = act.action_delivery
            if deliveries.type then deliveries = {deliveries} end
            
            for _, delivery in pairs(deliveries) do
                if delivery.target_effects then
                    local effects = delivery.target_effects
                    if effects.type then effects = {effects} end
                    
                    for _, effect in pairs(effects) do
                        if effect.type == "damage" and effect.damage then
                            effect.damage.amount = effect.damage.amount * multiplier
                        end
                    end
                end
            end
        end
    end
end

for _, name in pairs(units_to_mutate) do
    local unit = table.deepcopy(data.raw["unit"][name])
    if unit then
        unit.name = "mutated-" .. name
        -- Tint animations green
        if unit.run_animation then recursive_tint(unit.run_animation, {r=0.5, g=1, b=0.5}) end
        if unit.attack_parameters and unit.attack_parameters.animation then 
            recursive_tint(unit.attack_parameters.animation, {r=0.5, g=1, b=0.5}) 
        end

        -- Buff stats (Aggressive: Faster, stronger, but same health)
        -- Health remains unchanged as requested
        
        -- Make them faster and more aggressive
        unit.movement_speed = unit.movement_speed * 1.3 -- 30% faster
        unit.vision_distance = unit.vision_distance * 1.5 -- See player from further away
        
        if unit.attack_parameters then
            buff_damage(unit.attack_parameters, 1.5) -- Keep damage buff
            if unit.attack_parameters.cooldown then
                unit.attack_parameters.cooldown = unit.attack_parameters.cooldown * 0.8 -- 20% faster attack speed
            end
        end

        -- Radiation suffering (Negative healing to simulate decay)
        -- They are unstable and slowly dying
        unit.healing_per_tick = -0.005 -- Lose ~0.3 HP/sec (slow decay)

        -- Add resistance to poison (radiation) so they don't die instantly to the cloud
        if not unit.resistances then unit.resistances = {} end
        table.insert(unit.resistances, {type = "poison", percent = 90})

        -- Add a light to show they are radioactive
        unit.light = {intensity = 0.4, size = 5, color = {r=0.2, g=1, b=0.2}}

        data:extend({unit})
        unit_mapping[name] = unit.name
    end
end

-- Define mutated worms (Turrets)
local worms_to_mutate = {
    "small-worm-turret", "medium-worm-turret", "big-worm-turret", "behemoth-worm-turret"
}

for _, name in pairs(worms_to_mutate) do
    local worm = table.deepcopy(data.raw["turret"][name])
    if worm then
        worm.name = "mutated-" .. name
        
        -- Tint animations green
        local anims_to_tint = {
            "folded_animation", "preparing_animation", "prepared_animation", 
            "prepared_alternative_animation", "attacking_animation", 
            "starting_attack_animation", "ending_attack_animation", "folding_animation"
        }
        
        for _, anim_name in pairs(anims_to_tint) do
            if worm[anim_name] then
                recursive_tint(worm[anim_name], {r=0.5, g=1, b=0.5})
            end
        end

        -- Buff stats (Aggressive: Stronger, faster shooting, longer range)
        -- Health remains unchanged
        
        if worm.attack_parameters then
            buff_damage(worm.attack_parameters, 1.5) -- +50% Damage
            
            if worm.attack_parameters.cooldown then
                worm.attack_parameters.cooldown = worm.attack_parameters.cooldown * 0.8 -- 20% faster shooting
            end
            
            if worm.attack_parameters.range then
                worm.attack_parameters.range = worm.attack_parameters.range * 1.2 -- +20% Range
            end
        end

        -- Radiation suffering (Negative healing to simulate decay)
        worm.healing_per_tick = -0.005 -- Lose ~0.3 HP/sec

        -- Add resistance to poison (radiation)
        if not worm.resistances then worm.resistances = {} end
        table.insert(worm.resistances, {type = "poison", percent = 90})

        -- Add a light
        worm.light = {intensity = 0.4, size = 8, color = {r=0.2, g=1, b=0.2}}

        data:extend({worm})
        -- No mapping needed for worms as they don't spawn from spawners in the same way, 
        -- but if we wanted to replace them via script we could.
    end
end

-- Define mutated spawners
local function create_mutated_spawner(original_name, new_name)
    local spawner = table.deepcopy(data.raw["unit-spawner"][original_name])
    if not spawner then return end
    spawner.name = new_name
    spawner.tint = {r=0.2, g=1, b=0.2, a=1} -- Give it a green tint so we know it's mutated
    spawner.autoplace = nil -- Prevent mutated spawners from generating in world gen
    
    -- Radiation suffering (Negative healing to simulate decay)
    spawner.healing_per_tick = -0.005 -- Lose ~0.3 HP/sec

    -- Add a light
    spawner.light = {intensity = 0.4, size = 10, color = {r=0.2, g=1, b=0.2}}

    -- Update spawn table to use mutated units
    if spawner.result_units then
        local new_result_units = {}
        for _, unit_entry in pairs(spawner.result_units) do
            -- unit_entry is {"unit-name", {{evolution, weight}, ...}}
            local original_unit = unit_entry[1]
            local spawn_points = unit_entry[2]
            
            if unit_mapping[original_unit] then
                -- Use the mutated unit name
                table.insert(new_result_units, {unit_mapping[original_unit], spawn_points})
            else
                -- Keep original if no mapping found (fallback)
                table.insert(new_result_units, unit_entry)
            end
        end
        spawner.result_units = new_result_units
    end
    
    data:extend({spawner})
end

create_mutated_spawner("biter-spawner", "mutated-biter-spawner")
create_mutated_spawner("spitter-spawner", "mutated-spitter-spawner")
