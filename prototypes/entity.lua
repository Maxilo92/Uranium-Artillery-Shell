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
    projectile.animation.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell.png"
    projectile.animation.tint = {r=0.5, g=1, b=0.5}
end

-- Use custom shadow if available
if projectile.shadow then
    projectile.shadow.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell-shadow.png"
end

-- Define the radiation cloud (based on poison cloud)
local cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
cloud.name = "uranium-radiation-cloud"
cloud.duration = 1800 -- 30 seconds
cloud.fade_away_duration = 120
cloud.spread_duration = 300 -- 5 seconds to spread fully
cloud.spread_radius = 25 -- Match the action radius
cloud.color = {r=0.2, g=1, b=0.2, a=0} -- Make cloud invisible
cloud.animation = nil -- Remove visual cloud
cloud.affected_by_wind = false -- Stop it from moving
cloud.show_when_smoke_off = false
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
    damage_per_tick = { amount = 0, type = "acid" }, -- Move periodic damage to control.lua for performance
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

-- MK2 cloud and glow (endgame, longer and larger)
local cloud_mk2 = table.deepcopy(cloud)
cloud_mk2.name = "uranium-radiation-cloud-mk2"
cloud_mk2.duration = 5400 -- 90 seconds (3x base duration)
cloud_mk2.fade_away_duration = 360
cloud_mk2.spread_duration = 900 -- 15 seconds to spread across 75 tiles
cloud_mk2.spread_radius = 75 -- 3x MK1 radius
cloud_mk2.color = {r=0.1, g=1, b=0.4, a=0} -- Invisible MK2 cloud
cloud_mk2.animation = nil -- Remove visual MK2 cloud

if cloud_mk2.animation then
    cloud_mk2.animation = table.deepcopy(data.raw["trivial-smoke"]["smoke"].animation)
    recursive_scale(cloud_mk2.animation, 75) -- Scale to match 75 tile radius (3x MK1)
    recursive_tint(cloud_mk2.animation, {r=0.05, g=1, b=0.2, a=0.01})
    cloud_mk2.animation.animation_speed = 0.008 -- Even slower for larger cloud
end
-- Keep MK2 cloud visible

-- MK2 Cloud action with 3x radius
cloud_mk2.action = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "nested-result",
                action = {
                    type = "area",
                    radius = 75, -- 3x MK1 radius (25 * 3)
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "create-sticker",
                                sticker = "uranium-radiation-sticker"
                            },
                            {
                                type = "damage",
                                damage = {amount = 12, type = "acid"} -- Higher damage for MK2
                            },
                            {
                                type = "script",
                                effect_id = "uranium-radiation-contact-mk2"
                            }
                        }
                    }
                }
            }
        }
    }
}
cloud_mk2.action_frequency = 60 -- Same frequency as MK1

local glow_mk2 = table.deepcopy(glow)
glow_mk2.name = "uranium-radiation-glow-mk2"
glow_mk2.light = {intensity = 1, size = 30, color = {r=0.05, g=1, b=0.2}}
glow_mk2.initial_lifetime = 5400 -- 90 seconds

data:extend({cloud_mk2, glow_mk2})

-- Tint the cloud animation
if cloud.animation then
   -- Replace with generic smoke to avoid blue tint from poison-cloud
   -- Use "smoke" which is white/grey, so tinting works well
   cloud.animation = table.deepcopy(data.raw["trivial-smoke"]["smoke"].animation)
   recursive_scale(cloud.animation, 25) -- Scale to match 25 tile radius
    recursive_tint(cloud.animation, {r=0.1, g=1, b=0.1, a=0.01})
   cloud.animation.animation_speed = 0.01 -- Slow motion smoke to last full duration
end
-- Keep cloud visible

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
cloud.action_frequency = 60 -- Apply sticker every 1.0 second (60 ticks) to reduce entity creation overhead

-- Define a green smoke for the explosion
-- Use "smoke" instead of "smoke-fast" for a fluffier, less triangular look
local smoke = table.deepcopy(data.raw["trivial-smoke"]["smoke"]) 
smoke.name = "uranium-explosion-smoke"
smoke.color = {r=0.2, g=1, b=0.2, a=0.5}
if smoke.animation then
    recursive_scale(smoke.animation, 2.5) -- Make it bigger
    recursive_tint(smoke.animation, {r=0.2, g=1, b=0.2, a=0.5})
end

-- MK2 smoke: long-lived green ring that shrinks over 90s
local smoke_mk2 = table.deepcopy(smoke)
smoke_mk2.name = "uranium-explosion-smoke-mk2"
smoke_mk2.color = {r=0.1, g=1, b=0.35, a=0.35}
smoke_mk2.duration = 5400 -- 90 seconds
smoke_mk2.fade_away_duration = 600 -- 10s gentle fade out
smoke_mk2.fade_in_duration = 30
smoke_mk2.start_scale = 4.0 -- start large at rim
smoke_mk2.end_scale = 0.2 -- shrink towards center
smoke_mk2.affected_by_wind = false -- keep the ring shape stable
smoke_mk2.spread_duration = 0 -- no outward spread
if smoke_mk2.animation then
    recursive_scale(smoke_mk2.animation, 1.2) -- slightly larger frames for MK2
    recursive_tint(smoke_mk2.animation, smoke_mk2.color)
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

local function remove_smoke_effects(effects)
    if not effects then return nil end
    if effects.type then effects = {effects} end
    local cleaned = {}
    for _, effect in pairs(effects) do
        local drop = false
        if effect.type == "create-entity" and effect.entity_name and string.find(effect.entity_name, "smoke") then
            drop = true
        elseif effect.type == "create-trivial-smoke" and effect.smoke_name and string.find(effect.smoke_name, "smoke") then
            drop = true
        end

        if not drop then
            if effect.type == "nested-result" and effect.action and effect.action.action_delivery then
                effect.action.action_delivery.target_effects = remove_smoke_effects(effect.action.action_delivery.target_effects)
            end
            if effect.action_delivery then
                effect.action_delivery.target_effects = remove_smoke_effects(effect.action_delivery.target_effects)
            end
            table.insert(cleaned, effect)
        end
    end
    return cleaned
end

-- Strip smoke from explosion effects entirely (no blue lingering smoke)
explosion.smoke = nil
if explosion.created_effect then
    explosion.created_effect = remove_smoke_effects(explosion.created_effect)
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

data:extend({projectile, cloud, explosion})

-- High-yield projectile (~3x atomic bomb equivalent)
local projectile_mk2 = table.deepcopy(projectile)
projectile_mk2.name = "uranium-artillery-projectile-mk2"

-- Make tracer brighter
projectile_mk2.light = {intensity = 1, size = 18, color = {r=0.2, g=1, b=0.2}}
if projectile_mk2.animation then
    -- Use custom MK2 projectile sprite
    projectile_mk2.animation.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell.png"
    projectile_mk2.animation.tint = {r=0.3, g=1, b=0.3}
    recursive_scale(projectile_mk2.animation, 1.5) -- Larger visual similar to atomic projectile
end

-- Use custom shadow for MK2
if projectile_mk2.shadow then
    projectile_mk2.shadow.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell-shadow.png"
end

-- Custom muzzle flash for uranium artillery
local muzzle_flash = {
    type = "explosion",
    name = "uranium-artillery-cannon-muzzle-flash",
    flags = {"not-on-map"},
    animations = {
        {
            filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shoot-map-visualization.png",
            priority = "high",
            width = 64,
            height = 64,
            frame_count = 1,
            animation_speed = 1,
            shift = {0, 0},
            tint = {r=0.2, g=1, b=0.2, a=0.8}
        }
    },
    light = {intensity = 1, size = 20, color = {r=0.2, g=1, b=0.2}},
    smoke = "smoke-fast",
    sound = data.raw["artillery-projectile"]["artillery-projectile"].sound or nil
}

-- Increase blast radius and damage, and add stacked nuclear explosions
projectile_mk2.action = table.deepcopy(projectile.action)
local mk2_effects = projectile_mk2.action.action_delivery.target_effects
-- Increase ground effects radius
for _, effect in pairs(mk2_effects) do
    if effect.type == "create-entity" and effect.entity_name == "uranium-radiation-cloud" then
        effect.entity_name = "uranium-radiation-cloud-mk2"
    elseif effect.type == "create-entity" and effect.entity_name == "uranium-radiation-glow" then
        effect.entity_name = "uranium-radiation-glow-mk2"
    elseif effect.type == "script" and effect.effect_id == "uranium-cloud-created" then
        effect.effect_id = "uranium-cloud-created-mk2"
    elseif effect.type == "set-tile" and effect.radius then
        effect.radius = effect.radius * 3 -- triple radius vs base
    elseif effect.type == "nested-result" and effect.action and effect.action.radius then
        effect.action.radius = effect.action.radius * 3 -- triple blast radius
        local te = effect.action.action_delivery.target_effects
        if te then
            if te[1] and te[1].damage and te[1].damage.amount then
                te[1].damage.amount = te[1].damage.amount * 3
            end
            if te[2] and te[2].damage and te[2].damage.amount then
                te[2].damage.amount = te[2].damage.amount * 3
            end
        end
    end
end

-- Create custom scaled atomic bomb explosion for MK2
local nuke_explosion_base = "atomic-explosion"
if not data.raw["explosion"][nuke_explosion_base] then
    if data.raw["explosion"]["nuke-explosion"] then
        nuke_explosion_base = "nuke-explosion"
    elseif data.raw["explosion"]["big-artillery-explosion"] then
        nuke_explosion_base = "big-artillery-explosion"
    end
end

-- Clone and scale the atomic explosion
local mk2_explosion = table.deepcopy(data.raw["explosion"][nuke_explosion_base])
mk2_explosion.name = "uranium-artillery-explosion-mk2"
mk2_explosion.smoke = nil -- remove default smoke hookup; we inject our own green shrinking smoke

-- Scale all explosion visuals to match MK2 size (3x larger)
if mk2_explosion.animations then
    recursive_scale(mk2_explosion.animations, 3)
end
if mk2_explosion.light then
    mk2_explosion.light.size = (mk2_explosion.light.size or 50) * 3
    mk2_explosion.light.intensity = (mk2_explosion.light.intensity or 1) * 1.5
end
-- Scale smoke/cloud effects
if mk2_explosion.smoke and mk2_explosion.smoke ~= "fast" then
    recursive_scale(mk2_explosion.smoke, 3)
end
-- Enhanced sound (louder, more simultaneous)
if mk2_explosion.sound then
    if mk2_explosion.sound.aggregation then
        mk2_explosion.sound.aggregation.max_count = (mk2_explosion.sound.aggregation.max_count or 1) * 3
    end
    if mk2_explosion.sound.audible_distance_modifier then
        mk2_explosion.sound.audible_distance_modifier = (mk2_explosion.sound.audible_distance_modifier or 1) * 2
    end
    -- Increase volume if variations exist
    if mk2_explosion.sound.variations then
        for _, variation in pairs(mk2_explosion.sound.variations) do
            if variation.volume then
                variation.volume = variation.volume * 1.3
            end
        end
    end
end
-- Scale crater size
mk2_explosion.smoke = nil
if mk2_explosion.created_effect then
    mk2_explosion.created_effect = remove_smoke_effects(mk2_explosion.created_effect)
end

-- Add atomic rocket shockwave if available
local shockwave = data.raw["explosion"]["atomic-rocket-explosion-shockwave"]
if shockwave then
    local mk2_shockwave = table.deepcopy(shockwave)
    mk2_shockwave.name = "uranium-artillery-shockwave-mk2"
    recursive_scale(mk2_shockwave.animations, 3)
    if mk2_shockwave.light then
        mk2_shockwave.light.size = (mk2_shockwave.light.size or 50) * 3
    end
    -- Scale shockwave sound
    if mk2_shockwave.sound and mk2_shockwave.sound.aggregation then
        mk2_shockwave.sound.aggregation.max_count = (mk2_shockwave.sound.aggregation.max_count or 1) * 2
    end
    data:extend({mk2_shockwave})
    -- Add shockwave to effects
    table.insert(mk2_effects, {type = "create-entity", entity_name = "uranium-artillery-shockwave-mk2"})
end

-- Use the scaled explosion for MK2 projectile
table.insert(mk2_effects, 1, {type = "create-entity", entity_name = "uranium-artillery-explosion-mk2"})

data:extend({projectile_mk2, mk2_explosion, muzzle_flash})

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
    spawner.autoplace = nil -- Prevent mutated spawners from generating in world gen
    
    -- Tint the placed entity sprite green
    spawner.tint = {r=0.3, g=1, b=0.3, a=1}
    
    -- Also tint all possible animation properties green for consistency
    if spawner.animation then
        recursive_tint(spawner.animation, {r=0.3, g=1, b=0.3})
    end
    if spawner.attack_animation then
        recursive_tint(spawner.attack_animation, {r=0.3, g=1, b=0.3})
    end
    if spawner.attacking_animation then
        recursive_tint(spawner.attacking_animation, {r=0.3, g=1, b=0.3})
    end
    
    -- Tint icons to green
    if spawner.icon then
        spawner.icons = {{icon = spawner.icon, tint = {r=0.3, g=1, b=0.3, a=1}}}
        spawner.icon = nil
    end
    
    -- Radiation suffering (Negative healing to simulate decay)
    spawner.healing_per_tick = -0.005 -- Lose ~0.3 HP/sec

    -- Add a light - use spot_light_definition like Worms do
    spawner.light = {intensity = 0.5, size = 12, color = {r=0.2, g=1, b=0.2}}

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
