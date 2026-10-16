-- Constants shared between the data stage (prototypes) and the runtime stage
-- (control.lua). Keeping them in one place stops the debug overlay from drawing
-- a circle that does not match the area the fallout actually covers.
local shared = {}

shared.STICKER_NAME = "uranium-radiation-sticker"

shared.MK1_CLOUD_DURATION = 1800 -- 30 seconds
shared.MK2_CLOUD_DURATION = 5400 -- 90 seconds

-- Acid damage one fallout pulse deals. The cloud applies this to everything that
-- breathes; control.lua applies the same number to nests, which do not.
shared.MK1_CONTACT_DAMAGE = 8
shared.MK2_CONTACT_DAMAGE = 12

-- MK2 is three times the radius / damage of MK1.
shared.MK2_MULTIPLIER = 3

-- Mutants are unstable and decay to death on their own. The rate is derived from
-- max health so lifespan no longer depends on size; the old flat rate killed a
-- small biter in 50 seconds and a behemoth in about 13 hours.
--
-- The three windows differ because the engine does not treat them alike: idle
-- units are updated less often than every tick, so their measured lifespan comes
-- out roughly four times the nominal value. Worms and nests decay at the full
-- rate. These numbers were picked so all three land in the 10-20 minute range.
shared.MUTANT_DECAY_TICKS = 60 * 60 * 4        -- units: ~13-19 minutes in practice
shared.MUTANT_WORM_DECAY_TICKS = 60 * 60 * 10  -- worms: 10 minutes
shared.MUTANT_NEST_DECAY_TICKS = 60 * 60 * 20  -- nests: 20 minutes, as before

-- The fallout field reaches further than the blast itself. The factor keeps the
-- default fallout radius at the historical 25 tiles (15 * 5/3) while still
-- following the "Artillery Explosion Radius" startup setting.
shared.FALLOUT_RADIUS_FACTOR = 5 / 3

function shared.blast_radius()
    return settings.startup["uranium-artillery-radius"].value
end

function shared.fallout_radius()
    return math.floor(shared.blast_radius() * shared.FALLOUT_RADIUS_FACTOR + 0.5)
end

return shared
