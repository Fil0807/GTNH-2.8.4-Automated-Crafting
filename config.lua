--[[
  config.lua
  GTNH 2.8.4 / OpenComputers 1.8.9
]]

local config = {
  pollInterval = 5,

  -- 5e20 EU = 500 EEU = 0.5 ZEU.
  minWirelessEU = 5e20,

  -- Items are checked from top to bottom.
  craftTargets = {
    {
      label = "Titanium Plate",
      id = 7437,
      name = "gregtech:gt.metaitem.01",
      damage = 17028,
      minQty = 100000,
      craftAmount = 10000,
    },

    -- Gallifreyan Stabilisation Field Generator
    {
      label = "Gallifreyan Stabilisation Field Generator",
      id = 2860,
      name = "tectech:gt.stabilisation_field_generator",
      damage = 8,
      minQty = 2236,
      craftAmount = 80,
    },
  },

  components = {
    lscAddress = nil,
    meAddress = "dc277e87-7056-46f5-a572-b03d3873e515",
  },

  settings = {
    debug = false,
    waitForActiveCraft = true,
    preventDuplicateCpuCraft = true,
    maxCraftsPerCycle = 1,
    requireWirelessMode = true,
  }
}

return config
