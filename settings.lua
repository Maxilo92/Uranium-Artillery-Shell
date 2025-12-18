data:extend({
    {
        type = "bool-setting",
        name = "uranium-mutation-enabled",
        setting_type = "runtime-global",
        default_value = true,
        order = "a"
    },
    {
        type = "int-setting",
        name = "uranium-artillery-radius",
        setting_type = "startup",
        default_value = 15,
        minimum_value = 1,
        maximum_value = 100,
        order = "b"
    },
    {
        type = "double-setting",
        name = "uranium-artillery-damage",
        setting_type = "startup",
        default_value = 2000,
        minimum_value = 1,
        order = "c"
    },
    {
        type = "double-setting",
        name = "uranium-radiation-damage-percent",
        setting_type = "runtime-global",
        default_value = 5,
        minimum_value = 0,
        maximum_value = 100,
        order = "d"
    },
    {
        type = "bool-setting",
        name = "uranium-player-damage-enabled",
        setting_type = "runtime-global",
        default_value = true,
        order = "e"
    }
})
