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
  },
  {
    type = "recipe",
    name = "stabilized-radiation-core",
    enabled = false,
    energy_required = 15,
    ingredients = {
      {type="item", name="uranium-235", amount=1},
      {type="item", name="processing-unit", amount=2},
      {type="item", name="explosives", amount=10}
    },
    results = {{type="item", name="stabilized-radiation-core", amount=1}}
  },
  {
    type = "recipe",
    name = "dense-uranium-casing",
    enabled = false,
    energy_required = 20,
    ingredients = {
      {type="item", name="uranium-238", amount=10},
      {type="item", name="steel-plate", amount=10},
      {type="item", name="plastic-bar", amount=5}
    },
    results = {{type="item", name="dense-uranium-casing", amount=1}}
  },
  {
    type = "recipe",
    name = "uranium-artillery-shell-mk2",
    enabled = false,
    energy_required = 60,
    ingredients = {
      {type="item", name="uranium-artillery-shell", amount=1},
      {type="item", name="stabilized-radiation-core", amount=2},
      {type="item", name="dense-uranium-casing", amount=2},
      {type="item", name="uranium-235", amount=5},
      {type="item", name="explosives", amount=20}
    },
    results = {{type="item", name="uranium-artillery-shell-mk2", amount=1}}
  }
})
