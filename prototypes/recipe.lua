-- Costing is anchored to the vanilla atomic bomb, and that anchor differs by
-- build:
--   * Base game: the atomic bomb is 30 uranium-235.
--   * Space Age (base-data-updates.lua): the atomic bomb recipe is rewritten to
--     100 uranium-235.
-- So under Space Age every uranium amount below is scaled up roughly 3x. Only the
-- fissile material moves - structural inputs (steel, plastic, processing units)
-- stay put. A finished MK2 shell works out to about one atomic bomb's worth of
-- uranium-235 in either build.
--
-- RadAway is not anchored to the bomb (it is a poison-capsule-tier consumable)
-- and is identical in both builds.
local space_age = mods["space-age"] ~= nil

-- amounts[base] under base game, amounts[sa] under Space Age
local function pick(base, sa)
  if space_age then return sa end
  return base
end

data:extend({
  {
    type = "recipe",
    name = "uranium-artillery-shell",
    enabled = false,
    energy_required = 30,
    ingredients =
    {
      {type="item", name="artillery-shell", amount=1},
      -- Factorio 2.0 renamed the spent cell to depleted-uranium-fuel-cell
      {type="item", name="depleted-uranium-fuel-cell", amount=1},
      {type="item", name="uranium-238", amount=pick(10, 30)},
      {type="item", name="uranium-235", amount=pick(2, 6)},
      {type="item", name="explosives", amount=pick(5, 10)}
    },
    results = {{type="item", name="uranium-artillery-shell", amount=1}}
  },
  {
    type = "recipe",
    name = "uranium-antidote",
    enabled = false,
    energy_required = 10,
    ingredients =
    {
      {type="item", name="steel-plate", amount=2},
      {type="item", name="sulfur", amount=5},
      {type="item", name="coal", amount=5}
    },
    results = {{type="item", name="uranium-antidote", amount=1}}
  },
  {
    type = "recipe",
    name = "stabilized-radiation-core",
    enabled = false,
    energy_required = 20,
    ingredients = {
      {type="item", name="uranium-235", amount=pick(10, 30)},
      {type="item", name="processing-unit", amount=pick(2, 4)},
      {type="item", name="explosives", amount=pick(10, 20)}
    },
    results = {{type="item", name="stabilized-radiation-core", amount=1}}
  },
  {
    type = "recipe",
    name = "dense-uranium-casing",
    enabled = false,
    energy_required = 20,
    ingredients = {
      {type="item", name="uranium-238", amount=pick(20, 60)},
      {type="item", name="steel-plate", amount=20},
      {type="item", name="plastic-bar", amount=10}
    },
    results = {{type="item", name="dense-uranium-casing", amount=1}}
  },
  {
    type = "recipe",
    name = "uranium-artillery-shell-mk2",
    enabled = false,
    energy_required = 90,
    ingredients = {
      {type="item", name="uranium-artillery-shell", amount=1},
      {type="item", name="stabilized-radiation-core", amount=2},
      {type="item", name="dense-uranium-casing", amount=2},
      {type="item", name="uranium-235", amount=pick(10, 30)},
      {type="item", name="explosives", amount=pick(20, 40)}
    },
    results = {{type="item", name="uranium-artillery-shell-mk2", amount=1}}
  }
})
