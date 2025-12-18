local item = table.deepcopy(data.raw["ammo"]["artillery-shell"])
item.name = "uranium-artillery-shell"
item.order = "d[artillery-shell]-b[uranium]"

-- Tint the icon green to distinguish it
if item.icon then
    item.icons = {
        {
            icon = item.icon,
            icon_size = item.icon_size,
            tint = {r=0.4, g=1, b=0.4, a=1}
        }
    }
    item.icon = nil
end

-- Point to the new projectile
item.ammo_type.action.action_delivery.projectile = "uranium-artillery-projectile"

data:extend({item})
