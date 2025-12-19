data:extend({
  {
    type = "technology",
    name = "uranium-artillery-shell",
    icon_size = 256,
    icon = "__base__/graphics/technology/artillery.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "uranium-artillery-shell"
      },
      {
        type = "unlock-recipe",
        recipe = "uranium-antidote"
      }
    },
    prerequisites = {"artillery", "nuclear-power"},
    unit =
    {
      count = 25,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"military-science-pack", 1},
        {"utility-science-pack", 1}
      },
    time = 10
    },
    order = "e-a-b"
  },
  {
    type = "technology",
    name = "uranium-artillery-shell-mk2",
    icon_size = 256,
    icon = "__base__/graphics/technology/artillery.png",
    icons = {
      {icon = "__base__/graphics/technology/artillery.png", icon_size = 256, tint = {r=0.3, g=1, b=0.3, a=1}}
    },
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "stabilized-radiation-core"
      },
      {
        type = "unlock-recipe",
        recipe = "dense-uranium-casing"
      },
      {
        type = "unlock-recipe",
        recipe = "uranium-artillery-shell-mk2"
      }
    },
    prerequisites = {"uranium-artillery-shell", "atomic-bomb"},
    unit =
    {
      count = 200,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"military-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1}
      },
      time = 30
    },
    order = "e-a-c"
  }
})
