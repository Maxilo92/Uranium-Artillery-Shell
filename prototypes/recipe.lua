data:extend({
  {
    type = "recipe",
    name = "uranium-artillery-shell",
    enabled = false,
    energy_required = 20,
    ingredients =
    {
      {type="item", name="artillery-shell", amount=1},
      -- Factorio 2.0 renamed the spent cell to depleted-uranium-fuel-cell
      {type="item", name="depleted-uranium-fuel-cell", amount=1},
      {type="item", name="uranium-238", amount=5}
    },
    results = {{type="item", name="uranium-artillery-shell", amount=1}}
  },
  {
    type = "recipe",
    name = "uranium-antidote",
    enabled = false,
    energy_required = 5,
    ingredients =
    {
      {type="item", name="coal", amount=1},
      {type="item", name="water-barrel", amount=1}
    },
    results = {{type="item", name="uranium-antidote", amount=1}}
  }
})
