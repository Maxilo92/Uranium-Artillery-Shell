-- Research is balanced separately for the base game and Space Age, because the
-- science tree those two builds present is not the same one.
--
-- Base game:
--   * Space science is the final science (post rocket launch, infinite research).
--   * Vanilla Artillery costs 2000; the Atomic Bomb 5000.
--   MK1 sits between the two; MK2 is a true endgame weapon behind space science.
--
-- Space Age (base-data-updates.lua):
--   * space-science-pack moves to prerequisite "space-platform" - it is now a
--     mid-expansion gate, available before any of the four planets, so it can no
--     longer stand in for "endgame".
--   * Vanilla Artillery is rewritten to need metallurgic-science-pack (Vulcanus)
--     and drops to count 1500. The Atomic Bomb recipe goes from 30 to 100
--     uranium-235.
--   MK1 mirrors the Space Age Artillery pack list and is pushed to 4000 so it is
--   a real step past Artillery rather than a formality. MK2 moves behind
--   cryogenic-science-pack (Aquilo) - the point where you have cleared the hard
--   content - and to count 6000.
--
-- In both builds MK1 keeps "artillery" as a hard prerequisite, so the uranium
-- shell can never be researched before the ordinary artillery shell.
local space_age = mods["space-age"] ~= nil

local mk1_unit
local mk2_prerequisites
local mk2_unit

if space_age then
  mk1_unit = {
    count = 4000,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"military-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1},
      {"metallurgic-science-pack", 1}
    },
    time = 45
  }

  mk2_prerequisites = {"uranium-artillery-shell", "atomic-bomb", "cryogenic-science-pack"}
  mk2_unit = {
    count = 6000,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"military-science-pack", 1},
      {"production-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1},
      {"cryogenic-science-pack", 1}
    },
    time = 60
  }
else
  mk1_unit = {
    count = 2500,
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"military-science-pack", 1},
      {"utility-science-pack", 1}
    },
    time = 30
  }

  mk2_prerequisites = {"uranium-artillery-shell", "atomic-bomb", "space-science-pack"}
  mk2_unit = {
    count = 3000,
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
    time = 60
  }
end

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
    unit = mk1_unit,
    order = "e-a-b"
  },
  {
    type = "technology",
    name = "uranium-artillery-shell-mk2",
    icon_size = 256,
    -- No `icon` alongside `icons`: when both are given the engine reads `icons`
    -- and silently drops `icon`. The tinted entry below is the one that shows.
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
    prerequisites = mk2_prerequisites,
    unit = mk2_unit,
    order = "e-a-c"
  }
})
