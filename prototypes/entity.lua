local shared = require("shared")
local nuke_effects = require("prototypes.nuke_effects")

local BLAST_RADIUS = shared.blast_radius()
local FALLOUT_RADIUS = shared.fallout_radius()
local BLAST_DAMAGE = settings.startup["uranium-artillery-blast-damage"].value
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
cloud.animation = nil -- The visible fallout is drawn by nuke_effects.lua
cloud.affected_by_wind = false -- Stop it from moving
cloud.show_when_smoke_off = false

-- The cloud carries the fallout trigger and draws nothing. Three things follow
-- from that, and each of them used to be wrong here:
--
--   * SmokeWithTriggerPrototype has no `spread_radius`. The size of the fallout
--     field is set by the `area` radius of the trigger below and by nothing else.
--   * `spread_duration` is a real property, but it ramps up how far the smoke's
--     own particles drift - and `animation = nil` means there are no particles.
--   * `created_effect` is inherited from poison-cloud, and it spawned 21
--     `poison-cloud-visual-dummy` entities plus the poison capsule sound: a cyan
--     poison cloud over every uranium impact. The shell spawns its own green
--     haze instead (nuke_effects.lua), sized to the whole fallout field.
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
}
-- A pulsing green aura on the ground plus glowing motes rising off the victim.
nuke_effects.sticker_visuals(sticker)

-- The light at the crater (a fire entity, because that is what can carry one).
-- It now spans the whole fallout field and flickers; nuke_effects.lua adds
-- smaller light patches scattered across the field on top of it.
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
glow.light = {
    intensity = 0.7, size = FALLOUT_RADIUS, color = {r = 0.1, g = 1, b = 0.15},
    flicker_interval = 90, flicker_min_modifier = 0.8, flicker_max_modifier = 1.1,
}
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

local glow_mk2 = table.deepcopy(glow)
glow_mk2.name = "uranium-radiation-glow-mk2"
glow_mk2.light.size = math.min(FALLOUT_RADIUS * MK2, 60)
glow_mk2.light.intensity = 0.8
glow_mk2.initial_lifetime = shared.MK2_CLOUD_DURATION

-- The fallout trigger: once per second, everything that breathes inside the
-- field catches radiation sickness and takes a pulse of acid damage.
--
-- `entity_flags = {"breaths-air"}` limits it to living things. Without it the
-- trigger walks every chest, belt and tree in the field every second, which
-- measured as the single most expensive thing the mod does. Nests and worms are
-- handled in control.lua instead.
--
-- SmokeWithTriggerPrototype uses action_cooldown; action_frequency is not a
-- property, so setting it left the inherited poison-cloud value of 30 in place
-- and the cloud pulsed twice per second.
local function fallout_action(radius, contact_damage, effect_id)
    return {
        type = "direct",
        action_delivery = {
            type = "instant",
            target_effects = {
                {
                    type = "nested-result",
                    action = {
                        type = "area",
                        radius = radius,
                        entity_flags = {"breaths-air"},
                        action_delivery = {
                            type = "instant",
                            target_effects = {
                                {type = "create-sticker", sticker = shared.STICKER_NAME},
                                {type = "damage", damage = {amount = contact_damage, type = "acid"}},
                                {type = "script", effect_id = effect_id},
                            }
                        }
                    }
                }
            }
        }
    }
end
cloud.action = fallout_action(FALLOUT_RADIUS, shared.MK1_CONTACT_DAMAGE, "uranium-radiation-contact")
cloud.action_cooldown = 60
cloud_mk2.action = fallout_action(FALLOUT_RADIUS * MK2, shared.MK2_CONTACT_DAMAGE, "uranium-radiation-contact-mk2")
cloud_mk2.action_cooldown = 60

data:extend({cloud, cloud_mk2, glow_mk2})

-- What a shell does on impact. Damage, fallout and crater live here; everything
-- that is only seen or heard comes from nuke_effects.build.
local function impact(tier)
    local mk2 = tier == 2
    local suffix = mk2 and "-mk2" or ""
    local blast_radius = mk2 and BLAST_RADIUS * MK2 or BLAST_RADIUS
    local fallout_radius = mk2 and FALLOUT_RADIUS * MK2 or FALLOUT_RADIUS
    local duration = mk2 and shared.MK2_CLOUD_DURATION or shared.MK1_CLOUD_DURATION
    local damage = BLAST_DAMAGE * (mk2 and MK2 or 1)

    local target_effects = {
        {
            type = "create-entity",
            entity_name = "uranium-radiation-cloud" .. suffix,
            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
        },
        {
            type = "script",
            effect_id = "uranium-cloud-created" .. suffix
        },
        {
            type = "create-entity",
            entity_name = "uranium-radiation-glow" .. suffix, -- The glowing crater
            offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}}
        },
        {
            type = "set-tile",
            tile_name = "nuclear-ground",
            radius = blast_radius,
            apply_projection = false,
            tile_collision_mask = { layers = { ["water_tile"] = true } }
        },
        {
            type = "nested-result",
            action = {
                type = "area",
                radius = blast_radius,
                action_delivery = {
                    type = "instant",
                    target_effects = {
                        -- Split evenly so neither resistance type shrugs it off
                        {type = "damage", damage = {amount = damage / 2, type = "physical"}},
                        {type = "damage", damage = {amount = damage / 2, type = "explosion"}},
                    }
                }
            }
        },
        {
            type = "camera-effect",
            duration = mk2 and 90 or 60,
            ease_in_duration = 5,
            ease_out_duration = mk2 and 90 or 60,
            delay = 0,
            strength = mk2 and 6 or 3.5,
            full_strength_max_distance = mk2 and 200 or 80,
            max_distance = mk2 and 800 or 300
        },
    }
    if mk2 then
        -- Like the atomic bomb: the endgame shell levels cliffs at ground zero.
        table.insert(target_effects, 1, {type = "destroy-cliffs", radius = math.min(blast_radius, 15), explosion_at_trigger = "explosion"})
    end

    for _, effect in pairs(nuke_effects.build(suffix, blast_radius, fallout_radius, duration, mk2)) do
        table.insert(target_effects, effect)
    end
    return {type = "direct", action_delivery = {type = "instant", target_effects = target_effects}}
end

projectile.action = impact(1)

-- High-yield projectile
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
projectile_mk2.action = impact(2)

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

data:extend({projectile, projectile_mk2, muzzle_flash})

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
