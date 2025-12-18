local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "uranium-artillery-projectile"

-- Add green glow to projectile (Tracer effect)
projectile.light = {intensity = 0.8, size = 15, color = {r=0.2, g=1, b=0.2}}

-- Define the radiation cloud (based on poison cloud)
local cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
cloud.name = "uranium-radiation-cloud"
cloud.duration = 1800 -- 30 seconds
cloud.fade_away_duration = 120
cloud.spread_duration = 20
cloud.color = {r=0.2, g=0.9, b=0.2, a=0.5} -- Greenish cloud
cloud.affected_by_wind = true
cloud.show_when_smoke_off = true

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
                    radius = 12, -- Radiation radius (larger than explosion)
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "damage",
                                damage = { amount = 20, type = "poison" }
                            }
                        }
                    }
                }
            }
        }
    }
}
cloud.action_frequency = 30 -- Damage every 0.5 seconds (30 ticks)

-- Define the explosion visual
local explosion = table.deepcopy(data.raw["explosion"]["big-artillery-explosion"])
explosion.name = "uranium-artillery-explosion"

-- Add green light flash to explosion
explosion.light = {intensity = 1, size = 50, color = {r=0.2, g=1, b=0.2}}

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
                type = "nested-result",
                action = {
                    type = "area",
                    radius = 8.0, -- Larger explosion radius (Vanilla is 4.0)
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "damage",
                                damage = {amount = 1000, type = "physical"} -- Higher damage
                            },
                            {
                                type = "damage",
                                damage = {amount = 1000, type = "explosion"}
                            },
                            {
                                type = "create-entity",
                                entity_name = "uranium-artillery-explosion"
                            },
                            {
                                type = "create-entity",
                                entity_name = "uranium-radiation-cloud"
                            }
                        }
                    }
                }
            }
        }
    }
}

data:extend({projectile, cloud, explosion})
