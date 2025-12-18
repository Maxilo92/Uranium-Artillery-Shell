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
  }
})
