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
      }
    },
    prerequisites = {"artillery", "nuclear-power"},
    unit =
    {
      count = 2000,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"military-science-pack", 1},
        {"utility-science-pack", 1}
      },
      time = 30
    },
    order = "e-a-b"
  }
})
