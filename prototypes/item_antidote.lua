local antidote = {
    type = "capsule",
    name = "uranium-antidote",
    icons = {
        {
            icon = "__base__/graphics/icons/fluid/steam.png", -- Looks like a vial?
            icon_size = 64,
            tint = {r=1, g=0.5, b=0.5} -- Reddish/Pink antidote
        }
    },
    subgroup = "capsule",
    order = "z[antidote]",
    capsule_action = {
        type = "use-on-self",
        attack_parameters = {
            type = "projectile",
            activation_type = "consume",
            ammo_category = "capsule",
            cooldown = 30,
            range = 0,
            ammo_type = {
                -- No `category` here: AmmoType has none. The ammo category of a
                -- capsule comes from `ammo_category` on the attack parameters
                -- above, which is already set.
                target_type = "position",
                action = {
                    type = "direct",
                    action_delivery = {
                        type = "instant",
                        target_effects = {
                            {
                                type = "create-trivial-smoke",
                                smoke_name = "smoke",
                                offset_deviation = {{-0.1, -0.1}, {0.1, 0.1}},
                                speed_from_center = 0.05
                            }
                        }
                    }
                }
            }
        }
    },
    stack_size = 100
}

data:extend({antidote})
