--[[
  main.lua
  GTNH 2.8.4 / OpenComputers 1.8.9

  LSC Wireless EU gate -> targeted AE2 stock checks -> autocrafting.

  This version deliberately does NOT call getItemsInNetwork() without
  a filter. Large GTNH networks can make that call extremely expensive.
]]

package.path =
  "./?.lua;./lib/?.lua;/home/?.lua;/home/lib/?.lua;" ..
  package.path

local event = require("event")
local computer = require("computer")

package.loaded.config = nil
local okConfig, config = pcall(require, "config")
if not okConfig or type(config) ~= "table" then
  io.stderr:write(
    "ERROR: Could not load config.lua: " ..
    tostring(config) .. "\n"
  )
  os.exit(1)
end

local discover = require("lib.component-discover")
local lsc = require("lib.lsc")
local ae2 = require("lib.ae2")

local function fail(message)
  io.stderr:write("CONFIG ERROR: " .. message .. "\n")
  os.exit(1)
end

local function validateConfig()
  if type(config.pollInterval) ~= "number" or config.pollInterval < 1 then
    fail("pollInterval must be >= 1")
  end

  if type(config.minWirelessEU) ~= "number" or config.minWirelessEU < 0 then
    fail("minWirelessEU must be a non-negative number")
  end

  if type(config.craftTargets) ~= "table" then
    fail("craftTargets must be a table")
  end

  for i, target in ipairs(config.craftTargets) do
    if type(target) ~= "table" then
      fail("craftTargets[" .. i .. "] is not a table")
    end

    if type(target.label) ~= "string" then
      fail("craftTargets[" .. i .. "].label must be a string")
    end

    if type(target.id) ~= "number" then
      fail("craftTargets[" .. i .. "].id must be a number")
    end

    if type(target.name) ~= "string" then
      fail("craftTargets[" .. i .. "].name must be a string")
    end

    if type(target.damage) ~= "number" then
      fail("craftTargets[" .. i .. "].damage must be a number")
    end

    if type(target.minQty) ~= "number" or target.minQty < 0 then
      fail("craftTargets[" .. i .. "].minQty must be >= 0")
    end

    if type(target.craftAmount) ~= "number" or target.craftAmount <= 0 then
      fail("craftTargets[" .. i .. "].craftAmount must be > 0")
    end
  end

  config.components = config.components or {}
  config.settings = config.settings or {}

  if config.settings.maxCraftsPerCycle == nil then
    config.settings.maxCraftsPerCycle = 1
  end

  if config.settings.maxCraftsPerCycle < 1 then
    fail("maxCraftsPerCycle must be >= 1")
  end
end

validateConfig()

local function printBanner()
  print("================================================================")
  print("       GTNH 2.8.4 - AE2 AUTOCRAFT + WIRELESS EU GATE")
  print("================================================================")
  print("Minimum Wireless EU: " .. lsc.formatEU(config.minWirelessEU))
  print(string.format("Polling interval:      %d seconds", config.pollInterval))
  print(string.format("Configured targets:    %d", #config.craftTargets))
  print("Stock lookup:          getItemsInNetworkById({id})")
  print("Item identity:         registry name + damage")
  print("Craftable lookup:       getCraftables({name}) + exact damage check")
  print("AE2 module:              " .. tostring(ae2.VERSION or "unknown"))
  print("Press [Ctrl+C] to stop.")
  print("----------------------------------------------------------------")
end

print("Initializing hardware components...")

local lscProxy, lscErr =
  discover.discoverLSC(
    config.components.lscAddress,
    config.settings.debug
  )

if not lscProxy then
  io.stderr:write("HARDWARE ERROR: " .. tostring(lscErr) .. "\n")
  os.exit(1)
end

print(
  "[OK] Lapotronic Supercapacitor connected (" ..
  tostring(lscProxy.address) .. ")"
)

local meProxy, meErr =
  discover.discoverAE(
    config.components.meAddress,
    config.settings.debug
  )

if not meProxy then
  io.stderr:write("HARDWARE ERROR: " .. tostring(meErr) .. "\n")
  os.exit(1)
end

print(
  "[OK] AE2 Network Interface connected (" ..
  tostring(meProxy.address) .. ")"
)

if config.settings.debug then
  print("\n[DEBUG] LSC methods:")
  for _, method in ipairs(discover.listMethods(lscProxy)) do
    print("  - " .. method)
  end

  print("\n[DEBUG] AE2 methods:")
  for _, method in ipairs(discover.listMethods(meProxy)) do
    print("  - " .. method)
  end

  print("")
end

printBanner()

local state = {
  activeJob = nil,
  running = true,
  cycleCount = 0,
}

local function checkActiveJob(timeStr)
  if not state.activeJob then return end

  local target = state.activeJob.target
  local elapsed = math.floor(
    computer.uptime() - state.activeJob.startTime
  )

  if ae2.isJobDone(state.activeJob.status) then
    print(
      string.format(
        "[%s] [CRAFT COMPLETE] '%s' (%ds)",
        timeStr,
        target.label,
        elapsed
      )
    )
    state.activeJob = nil
    return
  end

  if ae2.isJobCanceled(state.activeJob.status) then
    print(
      string.format(
        "[%s] [CRAFT CANCELED] '%s'",
        timeStr,
        target.label
      )
    )
    state.activeJob = nil
    return
  end

  if config.settings.debug then
    print(
      string.format(
        "  [DEBUG] Active craft '%s' (%ds)",
        target.label,
        elapsed
      )
    )
  end
end

local function runCycle()
  state.cycleCount = state.cycleCount + 1
  local timeStr = os.date("%H:%M:%S")

  checkActiveJob(timeStr)

  --------------------------------------------------------------
  -- 1. LSC Wireless EU gate
  --------------------------------------------------------------
  local wirelessEU, rawLine, rawInfo, wirelessEnabled =
    lsc.getWirelessEU(
      lscProxy,
      config.settings.debug
    )

  if not wirelessEU then
    io.stderr:write(
      string.format(
        "[%s] [LSC WARNING] %s\n",
        timeStr,
        tostring(rawLine)
      )
    )
    return
  end

  if config.settings.requireWirelessMode and wirelessEnabled == false then
    print(
      string.format(
        "[%s] Wireless mode is DISABLED -> autocrafting paused",
        timeStr
      )
    )
    return
  end

  local enoughPower = wirelessEU >= config.minWirelessEU

  print(
    string.format(
      "[%s] Wireless EU: %s | Threshold: %s | Status: %s",
      timeStr,
      lsc.formatEU(wirelessEU),
      lsc.formatEU(config.minWirelessEU),
      enoughPower and "SUFFICIENT" or "INSUFFICIENT"
    )
  )

  if not enoughPower then
    return
  end

  --------------------------------------------------------------
  -- 2. Do not overlap our own craft
  --------------------------------------------------------------
  if config.settings.waitForActiveCraft and state.activeJob then
    local elapsed = math.floor(
      computer.uptime() - state.activeJob.startTime
    )

    print(
      string.format(
        "  [WAIT] '%s' still crafting (%ds)",
        state.activeJob.target.label,
        elapsed
      )
    )
    return
  end

  --------------------------------------------------------------
  -- 3. Check AE2 CPUs without reading the whole inventory
  --------------------------------------------------------------
  if config.settings.waitForActiveCraft and
     config.settings.preventDuplicateCpuCraft then

    local busy, label =
      ae2.isCpuCraftingTarget(
        meProxy,
        config.craftTargets
      )

    if busy then
      print(
        "  [WAIT] AE2 CPU already crafting '" ..
        tostring(label) .. "'"
      )
      return
    end
  end

  --------------------------------------------------------------
  -- 4. Targeted stock checks + crafting
  --------------------------------------------------------------
  local craftsStarted = 0
  local maxCrafts = config.settings.maxCraftsPerCycle or 1

  for index, target in ipairs(config.craftTargets) do

    local currentQty, craftableStatus, itemStack, quantityErr =
      ae2.getItemStatus(meProxy, target)

    if quantityErr then
      print(
        "  [AE2 WARNING] " ..
        tostring(quantityErr)
      )
    else
      print(
        string.format(
          "  [%d] %s | Qty: %s | Craftable: %s",
          index,
          target.label,
          lsc.formatNumber(currentQty),
          tostring(craftableStatus)
        )
      )

      if currentQty < target.minQty then
        print(
          string.format(
            "      [LOW STOCK] %s / %s -> request x%s",
            lsc.formatNumber(currentQty),
            lsc.formatNumber(target.minQty),
            lsc.formatNumber(target.craftAmount)
          )
        )

        local craftable, stack, findErr =
          ae2.findCraftable(
            meProxy,
            target
          )

        if not craftable then
          print("      [NOTICE] " .. tostring(findErr))
        else
          local success, requestOrError =
            ae2.requestCraft(
              craftable,
              target.craftAmount
            )

          if success then
            print(
              string.format(
                "      [CRAFT STARTED] '%s' x%s",
                target.label,
                lsc.formatNumber(target.craftAmount)
              )
            )

            state.activeJob = {
              target = target,
              status = requestOrError,
              startTime = computer.uptime(),
            }

            craftsStarted = craftsStarted + 1

            if craftsStarted >= maxCrafts then
              return
            end
          else
            print(
              "      [FAILED] '" ..
              target.label ..
              "': " ..
              tostring(requestOrError)
            )
          end
        end
      elseif config.settings.debug then
        print(
          string.format(
            "      [OK] %s / %s",
            lsc.formatNumber(currentQty),
            lsc.formatNumber(target.minQty)
          )
        )
      end
    end
  end
end

while state.running do
  local ok, err = pcall(runCycle)

  if not ok then
    io.stderr:write(
      "[RUNTIME ERROR] " .. tostring(err) .. "\n"
    )
  end

  local ev =
    event.pull(
      config.pollInterval or 5,
      "interrupted"
    )

  if ev == "interrupted" then
    print("\n[INFO] Ctrl+C received. Shutting down...")
    state.running = false
  end
end

print("Program terminated successfully.")
