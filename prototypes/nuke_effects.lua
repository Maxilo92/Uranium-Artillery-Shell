-- Everything the uranium shells show and sound like: the blast wave and the
-- fallout field that stays behind. Nothing here deals damage; the blast damage
-- and the fallout trigger stay in entity.lua, so these visuals can be tuned
-- without touching the balance.
--
-- The blast is built the way the vanilla atomic rocket builds its own: the
-- mushroom cloud alone is a single sprite, and what actually makes the atomic
-- bomb feel like one is the thousands of invisible wave projectiles fired out
-- of ground zero, each dropping a dust cloud, a fire puff or a shockwave
-- fragment where it lands (base/prototypes/entity/atomic-bomb.lua). Earlier
-- versions of this mod copied only the mushroom and a single shockwave ring,
-- which is why the impact read as a big ordinary explosion.
--
-- The fallout used to be fully invisible apart from one green light at the
-- crater. It now has a ground haze, rising glowing motes and flickering light
-- spots scattered over the whole field, all of which live exactly as long as
-- the field itself.

local shared = require("shared")
local sounds = require("__base__.prototypes.entity.sounds")

local GRAPHICS = "__Uranium-Artillery-Shell__/graphics/entity/"

local effects = {}

-- Colours. Smoke tints follow the vanilla convention (the brown nuclear dust is
-- {0.627, 0.478, 0.345, 0.5}); the haze colour is premultiplied like the vanilla
-- poison-cloud dummy it is copied from.
local DUST_TINT = {r = 0.36, g = 0.58, b = 0.24, a = 0.5}
local SMOKE_TINT = {r = 0.46, g = 0.60, b = 0.38, a = 0.5}
local FIRE_SMOKE_TINT = {r = 0.42, g = 0.85, b = 0.30, a = 0.5}
local MUSHROOM_TINT = {r = 0.72, g = 1, b = 0.58}
local SHOCKWAVE_TINT = {r = 0.55, g = 1, b = 0.42}
local HAZE_COLOR = {r = 0.05, g = 0.30, b = 0.04, a = 0.28}
local LIGHT_GREEN = {r = 0.15, g = 1, b = 0.2}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Tints every sprite in an animation definition, whatever shape it comes in
-- (single animation, layers, stripes or a list of variations).
local function tint_all(anim, tint)
    if type(anim) ~= "table" then return end
    if anim.layers then
        for _, layer in pairs(anim.layers) do tint_all(layer, tint) end
    elseif anim.filename or anim.filenames or anim.stripes then
        anim.tint = tint
    else
        for _, variation in pairs(anim) do tint_all(variation, tint) end
    end
end

local function scale_all(anim, factor)
    if type(anim) ~= "table" then return end
    if anim.layers then
        for _, layer in pairs(anim.layers) do scale_all(layer, factor) end
    elseif anim.filename or anim.filenames or anim.stripes then
        anim.scale = (anim.scale or 1) * factor
    else
        for _, variation in pairs(anim) do scale_all(variation, factor) end
    end
end

-- Vanilla nuke-explosion still carries its animation flags as a bare string in
-- places; 2.0 wants a list.
local function normalize_flags(anim)
    if type(anim) ~= "table" then return end
    if type(anim.flags) == "string" then anim.flags = {anim.flags} end
    if anim.layers then
        for _, layer in pairs(anim.layers) do normalize_flags(layer) end
    elseif not (anim.filename or anim.filenames or anim.stripes) then
        for _, variation in pairs(anim) do normalize_flags(variation) end
    end
end

-- Fires `count` invisible projectiles from ground zero to random points within
-- `radius`, the same mechanism the atomic rocket uses for its blast wave.
local function wave(projectile, count, radius, speed)
    return {
        type = "nested-result",
        action = {
            type = "area",
            show_in_tooltip = false,
            target_entities = false,
            trigger_from_target = true,
            repeat_count = count,
            radius = radius,
            action_delivery = {
                type = "projectile",
                projectile = projectile,
                starting_speed = speed,
                starting_speed_deviation = 0.075,
            },
        },
    }
end

-- Drops `count` copies of an effect at random points within `radius`.
local function scatter(count, radius, target_effects)
    return {
        type = "nested-result",
        action = {
            type = "area",
            show_in_tooltip = false,
            target_entities = false,
            trigger_from_target = true,
            repeat_count = count,
            radius = radius,
            action_delivery = {type = "instant", target_effects = target_effects},
        },
    }
end

-- A copy of one of the vanilla wave projectiles with its payload swapped out.
local function wave_projectile(name, source, payload)
    local projectile = table.deepcopy(data.raw["projectile"][source])
    projectile.name = name
    projectile.action = {{type = "direct", action_delivery = {type = "instant", target_effects = {payload}}}}
    return projectile
end

--------------------------------------------------------------------------------
-- prototypes shared by both shells
--------------------------------------------------------------------------------

-- Radioactive dust: the brown cloud ring of the atomic bomb, turned green.
local dust = table.deepcopy(data.raw["explosion"]["cluster-nuke-explosion"])
dust.name = "uranium-blast-dust"
tint_all(dust.animations, DUST_TINT)

-- Billowing fire smoke that rides the shockwave outwards. The name predates
-- this file and is kept so it stays the same prototype.
local fire_smoke = table.deepcopy(data.raw["explosion"]["atomic-fire-smoke"])
fire_smoke.name = "uranium-radiation-smoke-puff"
tint_all(fire_smoke.animations, FIRE_SMOKE_TINT)

local nuclear_smoke = table.deepcopy(data.raw["trivial-smoke"]["nuclear-smoke"])
nuclear_smoke.name = "uranium-nuclear-smoke"
nuclear_smoke.color = SMOKE_TINT

-- A glowing green speck. Used for the motes that rise out of the fallout, off
-- irradiated units and out of anything the radiation kills.
local mote = {
    type = "trivial-smoke",
    name = "uranium-radiation-mote",
    duration = 150,
    fade_in_duration = 25,
    fade_away_duration = 90,
    spread_duration = 150,
    start_scale = 1,
    end_scale = 0.35,
    color = {r = 1, g = 1, b = 1, a = 1},
    cyclic = true, -- a single frame; the engine only accepts that on a looping smoke
    affected_by_wind = false,
    movement_slow_down_factor = 0.985,
    render_layer = "air-object",
    animation = {
        filename = GRAPHICS .. "radiation-mote.png",
        priority = "high",
        width = 64,
        height = 64,
        frame_count = 1,
        scale = 0.55,
        draw_as_glow = true,
    },
}

-- Short green burst where the radiation finishes something off, so its kills
-- are visible instead of units quietly vanishing somewhere off-screen.
local death = table.deepcopy(data.raw["explosion"]["explosion"])
death.name = "uranium-radiation-death"
tint_all(death.animations, {r = 0.5, g = 1, b = 0.4})
death.light = {intensity = 0.8, size = 8, color = LIGHT_GREEN}
death.light_intensity_factor_final = 0
death.light_size_factor_final = 0.5
death.smoke = nil
death.smoke_count = nil
death.created_effect = {
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {
                type = "create-trivial-smoke",
                smoke_name = mote.name,
                repeat_count = 8,
                offset_deviation = {{-0.5, -0.5}, {0.5, 0.5}},
                speed_from_center = 0.03,
                speed_from_center_deviation = 0.02,
                initial_height = 0.4,
                only_when_visible = true,
            },
        },
    },
}

data:extend({dust, fire_smoke, nuclear_smoke, mote, death})

effects.MOTE = mote.name

--------------------------------------------------------------------------------
-- per-shell prototypes
--------------------------------------------------------------------------------

-- Builds every blast and fallout prototype for one shell and returns the list
-- of target effects its projectile has to run on impact.
--
--   suffix          "" for MK1, "-mk2" for MK2
--   blast_radius    radius of the blast damage
--   fallout_radius  radius of the fallout field
--   duration        lifetime of the fallout field in ticks
--   loud            MK2 is heard map-wide like the atomic bomb; MK1 is fired
--                   in barrages, so it stays local
function effects.build(suffix, blast_radius, fallout_radius, duration, loud)
    -- The vanilla wave is sized for a radius of about 26 tiles. Everything
    -- below scales from there, counts by area.
    local k = clamp(blast_radius / 26, 0.25, 4)
    local area = k * k
    local speed = 0.35 * clamp(math.sqrt(k), 0.8, 1.5)
    local travel = 19 * k

    -- Mushroom cloud with a green flash that fades out over its first fifth.
    local mushroom = table.deepcopy(data.raw["explosion"]["nuke-explosion"])
    mushroom.name = "uranium-artillery-explosion" .. suffix
    normalize_flags(mushroom.animations)
    tint_all(mushroom.animations, MUSHROOM_TINT)
    if k > 1 then scale_all(mushroom.animations, math.min(k, 2.5)) end
    mushroom.light = {intensity = 1, size = fallout_radius * 2, color = LIGHT_GREEN}
    mushroom.light_intensity_peak_start_progress = 0
    mushroom.light_intensity_peak_end_progress = 0.15
    mushroom.light_intensity_factor_final = 0
    mushroom.light_size_peak_start_progress = 0
    mushroom.light_size_peak_end_progress = 0.1
    mushroom.light_size_factor_initial = 0.4
    mushroom.light_size_factor_final = 0.6
    mushroom.smoke = nil
    mushroom.created_effect = nil

    local shockwave = table.deepcopy(data.raw["explosion"]["atomic-nuke-shockwave"])
    shockwave.name = "uranium-artillery-shockwave" .. suffix
    tint_all(shockwave.animations, SHOCKWAVE_TINT)
    if k > 1 then scale_all(shockwave.animations, math.min(k, 2)) end

    local p_dust = wave_projectile("uranium-wave-dust" .. suffix, "atomic-bomb-wave-spawns-cluster-nuke-explosion",
        {type = "create-entity", entity_name = dust.name})
    local p_fire = wave_projectile("uranium-wave-fire" .. suffix, "atomic-bomb-wave-spawns-fire-smoke-explosion",
        {type = "create-explosion", entity_name = fire_smoke.name,
         max_movement_distance = travel, max_movement_distance_deviation = 2 * k,
         inherit_movement_distance_from_projectile = true, cycle_while_moving = true})
    local p_shock = wave_projectile("uranium-wave-shockwave" .. suffix, "atomic-bomb-wave-spawns-nuke-shockwave-explosion",
        {type = "create-explosion", entity_name = shockwave.name,
         max_movement_distance = travel, max_movement_distance_deviation = 2 * k,
         inherit_movement_distance_from_projectile = true, cycle_while_moving = true})
    local p_smoke = wave_projectile("uranium-wave-smoke" .. suffix, "atomic-bomb-wave-spawns-nuclear-smoke",
        {type = "create-trivial-smoke", smoke_name = nuclear_smoke.name, repeat_count = 10,
         offset_deviation = {{-2, -2}, {2, 2}}, starting_frame = 10, starting_frame_deviation = 20,
         speed_from_center = 0.035})

    -- Fallout: drifting ground haze. The haze patches of MK2 are drawn larger
    -- rather than spawned in greater numbers.
    local haze_scale = clamp(fallout_radius / 25, 1, 2)
    local haze = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud-visual-dummy"])
    haze.name = "uranium-fallout-haze" .. suffix
    haze.color = HAZE_COLOR
    haze.duration = duration
    haze.fade_away_duration = math.min(360, math.floor(duration / 5))
    haze.working_sound = nil -- the Geiger counter in control.lua is the sound of the field
    haze.particle_spread = {3.8 * haze_scale, 2.3 * haze_scale}
    scale_all(haze.animation, haze_scale)
    local haze_count = clamp(math.floor(math.pi * fallout_radius ^ 2 / (40 * haze_scale ^ 2) + 0.5), 8, 150)

    -- Fallout: glowing motes rising off the ground.
    local embers = {
        type = "particle-source",
        name = "uranium-fallout-embers" .. suffix,
        icon = "__base__/graphics/icons/small-scorchmark.png",
        flags = {"not-on-map"},
        hidden = true,
        subgroup = "particles",
        time_to_live = duration - 60,
        time_to_live_deviation = 60,
        time_before_start = 20,
        time_before_start_deviation = 90,
        height = 0.1,
        height_deviation = 0.1,
        vertical_speed = 0,
        vertical_speed_deviation = 0,
        horizontal_speed = 0,
        horizontal_speed_deviation = 0,
        smoke = {
            {
                name = mote.name,
                frequency = 0.12,
                position = {0, 0},
                deviation = {2, 2},
                starting_vertical_speed = 0.018,
                starting_vertical_speed_deviation = 0.01,
                vertical_speed_slowdown = 0.995,
            },
        },
    }
    local ember_count = clamp(math.floor(fallout_radius ^ 2 / 20 + 0.5), 6, 150)

    -- Fallout: patches of green light that flicker out of step with each other.
    local light = table.deepcopy(data.raw["fire"]["uranium-radiation-glow"])
    light.name = "uranium-fallout-light" .. suffix
    light.initial_lifetime = duration
    light.light = {
        intensity = 0.55, size = 10, color = LIGHT_GREEN,
        flicker_interval = 45, flicker_min_modifier = 0.55, flicker_max_modifier = 1.15, offset_flicker = true,
    }
    local light_count = clamp(math.floor(fallout_radius ^ 2 / 70 + 0.5), 4, 50)

    data:extend({mushroom, shockwave, p_dust, p_fire, p_shock, p_smoke, haze, embers, light})

    local no_water = {layers = {water_tile = true}}
    return {
        {type = "destroy-decoratives", radius = blast_radius, include_soft_decoratives = true,
         include_decals = true, invoke_decorative_trigger = true, decoratives_with_trigger_only = false},
        {type = "create-entity", entity_name = "huge-scorchmark", offsets = {{0, -0.5}}, check_buildability = true},
        {type = "create-decorative", decorative = "nuclear-ground-patch",
         -- The engine caps this ring below 24 tiles.
         spawn_min_radius = math.min(blast_radius * 0.75, 22), spawn_max_radius = math.min(blast_radius * 0.85, 23.5),
         spawn_min = math.floor(30 * math.min(k, 1)), spawn_max = math.floor(40 * math.min(k, 1)),
         apply_projection = true, spread_evenly = true},
        {type = "create-entity", entity_name = mushroom.name},
        {type = "play-sound", sound = sounds.nuclear_explosion(loud and 0.9 or 0.7),
         play_on_target_position = true, max_distance = loud and 1000 or 350},
        {type = "play-sound", sound = sounds.nuclear_explosion_aftershock(loud and 0.4 or 0.25),
         play_on_target_position = true, max_distance = loud and 1000 or 350},
        wave(p_dust.name, clamp(math.floor(1000 * area), 120, 1600), blast_radius, speed),
        wave(p_fire.name, clamp(math.floor(700 * area), 80, 1000), 4 * k, speed * 0.93),
        wave(p_shock.name, clamp(math.floor(1000 * area), 120, 1600), 8 * k, speed * 0.93),
        wave(p_smoke.name, clamp(math.floor(300 * area), 40, 500), blast_radius, speed * 0.93),
        scatter(haze_count, fallout_radius * 0.85,
            {{type = "create-smoke", entity_name = haze.name, show_in_tooltip = false, initial_height = 0}}),
        scatter(ember_count, fallout_radius * 0.9,
            {{type = "create-entity", entity_name = embers.name, tile_collision_mask = no_water}}),
        scatter(light_count, fallout_radius * 0.8,
            {{type = "create-entity", entity_name = light.name, tile_collision_mask = no_water}}),
    }
end

-- The aura an irradiated unit or player carries, and the motes it sheds.
function effects.sticker_visuals(sticker)
    sticker.animation = {
        filename = GRAPHICS .. "radiation-aura.png",
        priority = "high",
        width = 128,
        height = 128,
        line_length = 4,
        frame_count = 16,
        animation_speed = 0.25,
        scale = 0.65,
        draw_as_glow = true,
        tint = {r = 1, g = 1, b = 1, a = 0.8},
    }
    sticker.render_layer = "object-under"
    sticker.update_effects = {
        {
            time_cooldown = 20,
            effect = {
                type = "create-trivial-smoke",
                smoke_name = mote.name,
                offset_deviation = {{-0.4, -0.4}, {0.4, 0.4}},
                initial_height = 0.6,
                speed = {0, -0.012},
                only_when_visible = true,
            },
        },
    }
end

-- Geiger counter clips, three intensities. control.lua plays one per second to
-- every player standing in a fallout field.
local function geiger(level)
    local variations = {}
    for i = 1, 3 do
        variations[i] = {filename = "__Uranium-Artillery-Shell__/sound/geiger-" .. level .. "-" .. i .. ".ogg", volume = 0.55}
    end
    return {type = "sound", name = "uranium-geiger-" .. level, category = "game-effect", variations = variations}
end
data:extend({geiger(1), geiger(2), geiger(3)})

return effects
