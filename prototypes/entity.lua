local shared = require("shared")

local BLAST_RADIUS = shared.blast_radius()
local FALLOUT_RADIUS = shared.fallout_radius()
local MK2 = shared.MK2_MULTIPLIER

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

-- ArtilleryProjectilePrototype uses `picture`, not `animation`, and has no
-- `light`. The glowing green tracer comes from the sprite itself, which the base
-- projectile already draws with draw_as_glow.
projectile.map_color = {r = 0.2, g = 1, b = 0.2}
if projectile.picture then
    projectile.picture.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell.png"
    projectile.picture.tint = {r = 0.5, g = 1, b = 0.5}
end

-- Use custom shadow if available
if projectile.shadow then
    projectile.shadow.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shell-shadow.png"
end

-- Green marker while the shell is in flight on the map view
if projectile.chart_picture then
    projectile.chart_picture.filename = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-shoot-map-visualization.png"
    projectile.chart_picture.tint = {r = 0.2, g = 1, b = 0.2}
end

-- Define the radiation cloud (based on poison cloud)
local cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
cloud.name = "uranium-radiation-cloud"
cloud.duration = shared.MK1_CLOUD_DURATION
cloud.fade_away_duration = 120
cloud.color = {r=0.2, g=1, b=0.2, a=0} -- Make cloud invisible
cloud.animation = nil -- Remove visual cloud; the crater glow marks the area
cloud.affected_by_wind = false -- Stop it from moving
cloud.show_when_smoke_off = false

-- The cloud carries the fallout trigger and draws nothing. Three things follow
-- from that, and each of them used to be wrong here:
--
--   * SmokeWithTriggerPrototype has no `spread_radius`. The size of the fallout
--     field is set by the `area` radius of the trigger below and by nothing else.
--   * `spread_duration` is a real property, but it ramps up how far the smoke's
--     own particles drift - and `animation = nil` means there are no particles.
--     The override was inert, so it is gone as well; what stays is whatever
--     poison-cloud brought along, which is equally inert.
--   * `created_effect` is inherited from poison-cloud, and it spawned 21
--     `poison-cloud-visual-dummy` entities in two rings plus the poison capsule
--     explosion sound. A cloud documented as invisible was therefore painting a
--     cyan poison cloud over every uranium impact. The shell brings its own green
--     visuals (explosion, shockwave, smoke puffs, crater glow) and control.lua
--     draws the exact fallout circle with a countdown, so the inherited ones are
--     dropped rather than recoloured.
cloud.created_effect = nil

-- Kept only so saves from <= 0.1.10 do not lose a prototype on update: back then
-- the radiation sticker spawned these as spread_fire_entity. Nothing creates them
-- any more (see the sticker definition below for why).
local trail = table.deepcopy(data.raw["fire"]["fire-flame"])
trail.name = "uranium-radiation-trail"
trail.damage_per_tick = {amount = 0, type = "fire"} -- No extra damage, just visual
trail.maximum_damage_multiplier = 1
trail.initial_lifetime = 60
trail.lifetime_increase_by = 0
trail.lifetime_increase_cooldown = 100
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
        shift = {0, 0}
    }
}

-- Define the radiation sticker (persistent damage)
--
-- Two things here are load-bearing and easy to break again:
--   * No spread_fire_entity. A sticker that declares one counts as a fire sticker
--     and the engine then refuses to attach it to characters, so players could
--     never actually catch radiation sickness.
--   * The visual goes in `animation`. StickerPrototype has no `stickers`
--     property, so an animation put there is silently dropped.
local sticker = {
    type = "sticker",
    name = "uranium-radiation-sticker",
    flags = {"not-on-map"},
    hidden = true,
    duration_in_ticks = 2147483647, -- Effectively infinite (until death or cured)
    target_movement_modifier = 0.8,
    damage_per_tick = { amount = 0, type = "acid" }, -- Periodic damage lives in control.lua
    animation = {
        filename = "__core__/graphics/shoot-cursor-green.png", -- Simple green marker
        priority = "extra-high",
        width = 258,
        height = 183,
        frame_count = 1,
        shift = {0, 0},
        tint = {r=0.5, g=1, b=0.5, a=0.5},
        scale = 0.2,
        draw_as_glow = true,
        flags = {"no-crop"}
    }
}
-- Define a glowing crater effect (using fire entity for light)
local glow = table.deepcopy(data.raw["fire"]["fire-flame"])
glow.name = "uranium-radiation-glow"
glow.damage_per_tick = {amount = 0, type = "fire"}
glow.maximum_damage_multiplier = 1
glow.initial_lifetime = shared.MK1_CLOUD_DURATION
glow.lifetime_increase_by = 0
glow.lifetime_increase_cooldown = 100
-- No limit_one_per_tile: FireFlamePrototype has never had that property (the
-- engine's own knob is limit_overlapping_particles, and this fire draws no
-- particles). maximum_spread_count = 0 below is what actually keeps it to one
-- flame at the impact point.
glow.spread_delay = 0
glow.spread_delay_deviation = 0
glow.maximum_spread_count = 0 -- Don't spread
glow.emissions_per_second = {}
-- Green light
glow.light = {intensity = 0.8, size = 20, color = {r=0.1, g=1, b=0.1}}
-- Remove smoke and fire graphics, we just want the light
glow.smoke = nil
glow.on_fuel_effect = nil
glow.working_sound = nil
-- Using a simple empty animation to avoid errors if pictures are required
glow.pictures = {
    {
        filename = "__core__/graphics/empty.png",
        priority = "extra-high",
        width = 1,
        height = 1,
        frame_count = 1,
        shift = {0, 0}
    }
}

data:extend({sticker, trail, glow})

-- MK2 cloud and glow (endgame, longer and larger)
local cloud_mk2 = table.deepcopy(cloud)
cloud_mk2.name = "uranium-radiation-cloud-mk2"
cloud_mk2.duration = shared.MK2_CLOUD_DURATION
cloud_mk2.fade_away_duration = 360
cloud_mk2.color = {r=0.1, g=1, b=0.4, a=0} -- Invisible MK2 cloud
-- No spread_duration / spread_radius / created_effect here either; see the MK1
-- cloud above. The MK2 fallout field is three times as wide purely because the
-- `area` radius of its trigger below is.

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
                    radius = FALLOUT_RADIUS * MK2,
                    -- Only living things. Without this the trigger walks every
                    -- chest, belt and tree in a 75 tile circle every second,
                    -- which measured as the single most expensive thing the mod
                    -- does. Nests have no such flag and are handled in
                    -- control.lua instead.
                    entity_flags = {"breaths-air"},
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "create-sticker",
                                sticker = "uranium-radiation-sticker"
                            },
                            {
                                type = "damage",
                                damage = {amount = shared.MK2_CONTACT_DAMAGE, type = "acid"}
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
-- SmokeWithTriggerPrototype uses action_cooldown; action_frequency is not a
-- property, so setting it left the inherited poison-cloud value of 30 in place
-- and the cloud pulsed twice per second.
cloud_mk2.action_cooldown = 60

local glow_mk2 = table.deepcopy(glow)
glow_mk2.name = "uranium-radiation-glow-mk2"
glow_mk2.light = {intensity = 1, size = 30, color = {r=0.05, g=1, b=0.2}}
glow_mk2.initial_lifetime = shared.MK2_CLOUD_DURATION

data:extend({cloud_mk2, glow_mk2})

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
                    radius = FALLOUT_RADIUS, -- Radiation radius (larger than explosion)
                    entity_flags = {"breaths-air"}, -- see the MK2 cloud for why
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "create-sticker",
                                sticker = "uranium-radiation-sticker"
                            },
                            {
                                type = "damage",
                                damage = {amount = shared.MK1_CONTACT_DAMAGE, type = "acid"}
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
cloud.action_cooldown = 60 -- Pulse once per second (see the MK2 note above)

-- Define the explosion visual
local source_name = "nuke-explosion"
if not data.raw["explosion"][source_name] then
    source_name = "big-artillery-explosion"
end

local explosion = table.deepcopy(data.raw["explosion"][source_name])
explosion.name = "uranium-artillery-explosion"

-- Add green light flash to explosion
explosion.light = {intensity = 1, size = 50, color = {r=0.2, g=1, b=0.2}}

-- Factorio 2.0 requires animation flags to be a list; the vanilla nuke-explosion
-- prototype still has them as a bare string, so normalize on load. The mushroom
-- cloud itself is kept at native scale - a previous 0.7x downscale turned the
-- already-faint draw_as_glow sprite into an indistinct smear that didn't read as
-- an atomic bomb.
local function normalize_flags(anim)
    if anim.flags and type(anim.flags) == "string" then
        anim.flags = { anim.flags }
    end
    if anim.hr_version then
        normalize_flags(anim.hr_version)
    end
end

if source_name == "nuke-explosion" and explosion.animations then
    if explosion.animations.layers then
        for _, layer in pairs(explosion.animations.layers) do
            normalize_flags(layer)
        end
    elseif explosion.animations.filename or explosion.animations.stripes or explosion.animations.filenames then
        normalize_flags(explosion.animations)
    else
        -- Assume it's a list of variations
        for _, anim in pairs(explosion.animations) do
            if type(anim) == "table" then
                normalize_flags(anim)
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

-- Shockwave ring - the single biggest visual cue that reads as "atomic bomb"
-- rather than a regular explosion. Previously only the MK2 shell had one.
local shockwave_source = data.raw["explosion"]["atomic-nuke-shockwave"]
local shockwave_name = nil
if shockwave_source then
    local mk1_shockwave = table.deepcopy(shockwave_source)
    mk1_shockwave.name = "uranium-artillery-shockwave"
    data:extend({mk1_shockwave})
    shockwave_name = mk1_shockwave.name
end

-- Green-tinted billowing smoke puffs, standing in for the lingering vanilla
-- smoke that earlier versions stripped out entirely along with everything else.
local smoke_puff_source = data.raw["explosion"]["atomic-fire-smoke"]
local smoke_puff_name = nil
if smoke_puff_source then
    local smoke_puff = table.deepcopy(smoke_puff_source)
    smoke_puff.name = "uranium-radiation-smoke-puff"
    if smoke_puff.animations and smoke_puff.animations[1] then
        smoke_puff.animations[1].tint = {r = 0.4, g = 1, b = 0.4, a = 0.5}
    end
    data:extend({smoke_puff})
    smoke_puff_name = smoke_puff.name
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
                radius = BLAST_RADIUS,
                apply_projection = false,
                tile_collision_mask = { layers = { ["water_tile"] = true } }
            },
            {
                type = "nested-result",
                action = {
                    type = "area",
                    radius = BLAST_RADIUS, -- Configurable radius
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

if shockwave_name then
    table.insert(projectile.action.action_delivery.target_effects, {type = "create-entity", entity_name = shockwave_name})
end
if smoke_puff_name then
    table.insert(projectile.action.action_delivery.target_effects, {
        type = "create-entity",
        entity_name = smoke_puff_name,
        repeat_count = 6,
        offset_deviation = {{-3, -3}, {3, 3}}
    })
end
table.insert(projectile.action.action_delivery.target_effects, {
    type = "camera-effect",
    duration = 60,
    ease_in_duration = 5,
    ease_out_duration = 60,
    delay = 0,
    strength = 3,
    full_strength_max_distance = 80,
    max_distance = 300
})

data:extend({projectile, cloud, explosion})

-- High-yield projectile (~3x atomic bomb equivalent)
local projectile_mk2 = table.deepcopy(projectile)
projectile_mk2.name = "uranium-artillery-projectile-mk2"
projectile_mk2.map_color = {r = 0.1, g = 1, b = 0.3}

if projectile_mk2.picture then
    projectile_mk2.picture.tint = {r = 0.3, g = 1, b = 0.3}
    projectile_mk2.picture.scale = (projectile_mk2.picture.scale or 1) * 1.5 -- Larger, like the atomic projectile
end
if projectile_mk2.shadow then
    projectile_mk2.shadow.scale = (projectile_mk2.shadow.scale or 1) * 1.5
end

-- Custom muzzle flash for uranium artillery
local muzzle_flash = {
    type = "explosion",
    name = "uranium-artillery-cannon-muzzle-flash",
    flags = {"not-on-map"},
    hidden = true,
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
    smoke = "smoke-fast"
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
    elseif effect.type == "create-entity" and effect.entity_name == "uranium-artillery-shockwave" then
        effect.entity_name = "uranium-artillery-shockwave-mk2" -- prototype created below
    elseif effect.type == "create-entity" and effect.entity_name == "uranium-radiation-smoke-puff" then
        effect.repeat_count = (effect.repeat_count or 1) * 2
        effect.offset_deviation = {{-3 * MK2, -3 * MK2}, {3 * MK2, 3 * MK2}}
    elseif effect.type == "camera-effect" then
        effect.strength = effect.strength * 1.7
        effect.full_strength_max_distance = effect.full_strength_max_distance * MK2
        effect.max_distance = effect.max_distance * MK2
    elseif effect.type == "script" and effect.effect_id == "uranium-cloud-created" then
        effect.effect_id = "uranium-cloud-created-mk2"
    elseif effect.type == "set-tile" and effect.radius then
        effect.radius = effect.radius * MK2 -- triple radius vs base
    elseif effect.type == "nested-result" and effect.action and effect.action.radius then
        effect.action.radius = effect.action.radius * MK2 -- triple blast radius
        local te = effect.action.action_delivery.target_effects
        if te then
            for _, damage_effect in pairs(te) do
                if damage_effect.damage and damage_effect.damage.amount then
                    damage_effect.damage.amount = damage_effect.damage.amount * MK2
                end
            end
        end
    end
end

-- Create custom scaled nuclear explosion for MK2
local mk2_explosion = table.deepcopy(data.raw["explosion"][source_name])
mk2_explosion.name = "uranium-artillery-explosion-mk2"
mk2_explosion.smoke = nil -- remove default smoke hookup

-- Scale all explosion visuals to match MK2 size (3x larger)
if mk2_explosion.animations then
    recursive_scale(mk2_explosion.animations, MK2)
end
if mk2_explosion.light then
    mk2_explosion.light.size = (mk2_explosion.light.size or 50) * MK2
    mk2_explosion.light.intensity = (mk2_explosion.light.intensity or 1) * 1.5
end
-- Enhanced sound (louder, more simultaneous)
if mk2_explosion.sound then
    if mk2_explosion.sound.aggregation then
        mk2_explosion.sound.aggregation.max_count = (mk2_explosion.sound.aggregation.max_count or 1) * MK2
    end
    if mk2_explosion.sound.audible_distance_modifier then
        mk2_explosion.sound.audible_distance_modifier = mk2_explosion.sound.audible_distance_modifier * 2
    end
    if mk2_explosion.sound.variations then
        for _, variation in pairs(mk2_explosion.sound.variations) do
            if variation.volume then
                variation.volume = variation.volume * 1.3
            end
        end
    end
end
if mk2_explosion.created_effect then
    mk2_explosion.created_effect = remove_smoke_effects(mk2_explosion.created_effect)
end

-- Scaled-up shockwave prototype for MK2. The reference to it in mk2_effects is
-- already present via the loop above, which renames the inherited MK1 entry
-- instead of adding a second one.
local shockwave = data.raw["explosion"]["atomic-nuke-shockwave"]
if shockwave then
    local mk2_shockwave = table.deepcopy(shockwave)
    mk2_shockwave.name = "uranium-artillery-shockwave-mk2"
    recursive_scale(mk2_shockwave.animations, MK2)
    if mk2_shockwave.light then
        mk2_shockwave.light.size = (mk2_shockwave.light.size or 50) * MK2
    end
    if mk2_shockwave.sound and mk2_shockwave.sound.aggregation then
        mk2_shockwave.sound.aggregation.max_count = (mk2_shockwave.sound.aggregation.max_count or 1) * 2
    end
    data:extend({mk2_shockwave})
end

-- Use the scaled explosion for MK2 projectile, replacing the inherited MK1-scale
-- one instead of stacking both clouds on top of each other.
for i = #mk2_effects, 1, -1 do
    if mk2_effects[i].type == "create-entity" and mk2_effects[i].entity_name == "uranium-artillery-explosion" then
        table.remove(mk2_effects, i)
    end
end
table.insert(mk2_effects, 1, {type = "create-entity", entity_name = "uranium-artillery-explosion-mk2"})

data:extend({projectile_mk2, mk2_explosion, muzzle_flash})

-- Define mutated units (Green versions)
local unit_mapping = {}

-- The green glow a mutant gives off.
--
-- UnitPrototype has a `light` property, so mutated biters and spitters can set
-- one directly. TurretPrototype and EnemySpawnerPrototype do not - a `light` on
-- a worm or a nest is read and thrown away, which is why mutated worms and nests
-- never lit up. The property that does work on every entity type is
-- `stateless_visualisation`, an EntityPrototype-level list whose entries may
-- carry a LightDefinition of their own. `count = 1` with no `period` makes it a
-- single, permanent visualisation rather than a repeating particle emitter,
-- which is how the base game attaches its persistent glows (see the ashland
-- trees in space-age/prototypes/entity/trees.lua).
local function mutant_glow(intensity, size)
    return {
        count = 1,
        light = {intensity = intensity, size = size, color = {r = 0.2, g = 1, b = 0.2}}
    }
end
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

-- Contagion: everything a mutant hits catches radiation sickness. Doing this in
-- the data stage means it costs nothing at runtime.
local add_contagion
add_contagion = function(trigger)
    if not trigger then return end
    local actions = trigger
    if trigger.type then actions = {trigger} end

    for _, action in pairs(actions) do
        if type(action) == "table" and action.action_delivery then
            local deliveries = action.action_delivery
            if deliveries.type then deliveries = {deliveries} end

            for _, delivery in pairs(deliveries) do
                local effects = delivery.target_effects
                if effects then
                    if effects.type then
                        effects = {effects}
                        delivery.target_effects = effects
                    end

                    local deals_damage = false
                    for _, effect in pairs(effects) do
                        if effect.type == "damage" then
                            deals_damage = true
                        elseif effect.type == "nested-result" then
                            add_contagion(effect.action)
                        end
                    end

                    if deals_damage then
                        table.insert(effects, {
                            type = "create-sticker",
                            sticker = "uranium-radiation-sticker"
                        })
                    end
                end
            end
        end
    end
end

local function infect_on_hit(attack_parameters)
    if attack_parameters and attack_parameters.ammo_type then
        add_contagion(attack_parameters.ammo_type.action)
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
        unit.movement_speed = unit.movement_speed * 1.3 -- 30% faster
        unit.vision_distance = unit.vision_distance * 1.5 -- See player from further away

        if unit.attack_parameters then
            buff_damage(unit.attack_parameters, 1.5) -- Keep damage buff
            infect_on_hit(unit.attack_parameters)
            if unit.attack_parameters.cooldown then
                unit.attack_parameters.cooldown = unit.attack_parameters.cooldown * 0.8 -- 20% faster attack speed
            end
        end

        -- Radiation suffering: scaled to max health so every mutant burns out
        -- after the same time regardless of size.
        unit.healing_per_tick = -unit.max_health / shared.MUTANT_DECAY_TICKS

        -- Survive their own fallout. This has to be "acid", the type the cloud
        -- actually deals; it was left as "poison" when 0.1.9 switched the damage
        -- type over, which quietly made the resistance do nothing.
        if not unit.resistances then unit.resistances = {} end
        table.insert(unit.resistances, {type = "acid", percent = 90})

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
        if worm.attack_parameters then
            buff_damage(worm.attack_parameters, 1.5) -- +50% Damage
            infect_on_hit(worm.attack_parameters)

            if worm.attack_parameters.cooldown then
                worm.attack_parameters.cooldown = worm.attack_parameters.cooldown * 0.8 -- 20% faster shooting
            end

            if worm.attack_parameters.range then
                worm.attack_parameters.range = worm.attack_parameters.range * 1.2 -- +20% Range
            end
        end

        -- Radiation suffering (see the unit loop above)
        worm.healing_per_tick = -worm.max_health / shared.MUTANT_WORM_DECAY_TICKS

        -- Survive their own fallout (see the unit loop above for why "acid")
        if not worm.resistances then worm.resistances = {} end
        table.insert(worm.resistances, {type = "acid", percent = 90})

        -- Add a light (see mutant_glow for why this is not worm.light)
        worm.stateless_visualisation = mutant_glow(0.4, 8)

        data:extend({worm})
    end
end

-- Define mutated spawners
local function create_mutated_spawner(original_name, new_name)
    local spawner = table.deepcopy(data.raw["unit-spawner"][original_name])
    if not spawner then return end
    spawner.name = new_name
    spawner.autoplace = nil -- Prevent mutated spawners from generating in world gen

    -- Tint the placed entity sprite green.
    --
    -- EnemySpawnerPrototype has no `tint`, and since 2.0 it has no top-level
    -- `animation` / `attack_animation` / `attacking_animation` either - all of
    -- its sprites moved into `graphics_set`. So every branch that used to stand
    -- here was dead: the nests kept the vanilla orange mask tint and were never
    -- green at all. graphics_set.animations is the live property, and tinting
    -- every layer of it matches what the worm loop above does.
    local graphics_set = spawner.graphics_set
    if graphics_set then
        recursive_tint(graphics_set.animations, {r=0.3, g=1, b=0.3})
        recursive_tint(graphics_set.underwater_animations, {r=0.3, g=1, b=0.3})
        recursive_tint(graphics_set.integration, {r=0.3, g=1, b=0.3})
    end

    -- Tint icons to green
    if spawner.icon then
        spawner.icons = {{icon = spawner.icon, icon_size = spawner.icon_size, tint = {r=0.3, g=1, b=0.3, a=1}}}
        spawner.icon = nil
    end

    -- Radiation suffering. Nests burn out far slower than units, so an irradiated
    -- base stays a threat for a while instead of dissolving on its own.
    spawner.healing_per_tick = -spawner.max_health / shared.MUTANT_NEST_DECAY_TICKS

    -- Add a light (see mutant_glow for why this is not spawner.light)
    spawner.stateless_visualisation = mutant_glow(0.5, 12)

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
