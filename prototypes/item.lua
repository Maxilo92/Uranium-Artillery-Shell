local item = table.deepcopy(data.raw["ammo"]["artillery-shell"])
item.name = "uranium-artillery-shell"
-- Sort directly after the vanilla artillery shell ("d[explosive-cannon-shell]-d[artillery]")
-- instead of ahead of it, which is where the old order string put them.
item.order = "d[explosive-cannon-shell]-e[artillery-uranium]"

-- Use custom icon
item.icon = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-projectile-mk1.png"
item.icon_size = 64

-- Point to the new projectile. The green map trace lives on the projectile
-- prototype itself (map_color); the delivery has no such property.
item.ammo_type.action.action_delivery.projectile = "uranium-artillery-projectile"

-- Green muzzle flash when the turret fires
item.ammo_type.action.action_delivery.source_effects = {
    type = "create-explosion",
    entity_name = "uranium-artillery-cannon-muzzle-flash"
}

data:extend({item})

-- Components for the high-yield shell
local rad_core = {
    type = "item",
    name = "stabilized-radiation-core",
    icon = "__Uranium-Artillery-Shell__/graphics/stabilized-radiation-core.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "d[uranium]-a[radiation-core]",
    stack_size = 50
}

local dense_casing = {
    type = "item",
    name = "dense-uranium-casing",
    icon = "__Uranium-Artillery-Shell__/graphics/dense-uranium-casing.png",
    icon_size = 64,
    subgroup = "intermediate-product",
    order = "d[uranium]-b[dense-casing]",
    stack_size = 50
}

-- High-yield artillery shell (~3x atomic bomb strength)
local mk2 = table.deepcopy(data.raw["ammo"]["artillery-shell"])
mk2.name = "uranium-artillery-shell-mk2"
mk2.order = "d[explosive-cannon-shell]-f[artillery-uranium-mk2]"
mk2.icon = "__Uranium-Artillery-Shell__/graphics/uranium-artillery-projectile-mk2.png"
mk2.icon_size = 64
mk2.ammo_type.action.action_delivery.projectile = "uranium-artillery-projectile-mk2"

mk2.ammo_type.action.action_delivery.source_effects = {
    type = "create-explosion",
    entity_name = "uranium-artillery-cannon-muzzle-flash"
}

data:extend({rad_core, dense_casing, mk2})
