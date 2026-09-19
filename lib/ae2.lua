--[[
  lib/ae2.lua
  AE2 inventory + autocrafting module for GTNH 2.8.4 / OC 1.8.9.

  Important:
  - NEVER calls getItemsInNetwork() without a filter.
  - Stock is queried with getItemsInNetworkById({id}).
  - Exact item identity is name + damage.
  - Labels are display-only and are never used for identity.
]]

local component = require("component")
local ae2 = {}
ae2.VERSION = "v7"

local function invoke(proxy, method, ...)
  if not proxy or not proxy.address then
    return false, "Invalid AE2 component"
  end

  local args = {...}
  local unpackFn = table.unpack or unpack

  local ok, result = pcall(function()
    return component.invoke(proxy.address, method, unpackFn(args))
  end)

  if ok then
    return true, result
  end

  local fn = proxy[method]
  if type(fn) == "function" then
    local ok2, result2 = pcall(function()
      return fn(unpackFn(args))
    end)
    if ok2 then return true, result2 end

    ok2, result2 = pcall(function()
      return fn(proxy, unpackFn(args))
    end)
    if ok2 then return true, result2 end
  end

  return false, result
end

function ae2.matchItem(item, target)
  if type(item) ~= "table" or type(target) ~= "table" then
    return false
  end

  if target.name and item.name ~= target.name then
    return false
  end

  if target.damage ~= nil and
     tonumber(item.damage) ~= tonumber(target.damage) then
    return false
  end

  return true
end

-- Returns:
--   quantity, isCraftable, itemStack, error
function ae2.getItemStatus(meProxy, target)
  if not target.id then
    return nil, nil, nil, "Target has no numeric item id"
  end

  local ok, result = invoke(
    meProxy,
    "getItemsInNetworkById",
    {target.id}
  )

  if not ok then
    return nil, nil, nil,
      "getItemsInNetworkById failed: " .. tostring(result)
  end

  if type(result) ~= "table" then
    return nil, nil, nil,
      "getItemsInNetworkById returned " .. type(result)
  end

  for _, item in ipairs(result) do
    if ae2.matchItem(item, target) then
      return tonumber(item.size) or 0,
             item.isCraftable == true,
             item,
             nil
    end
  end

  -- Not stored and not exposed as a craftable stack.
  return 0, false, nil, nil
end

function ae2.getCraftables(meProxy, filter)
  if not meProxy then
    return nil, "Nil AE2 component"
  end

  local ok, result = invoke(meProxy, "getCraftables", filter or {})

  if not ok or type(result) ~= "table" then
    return nil, "getCraftables() failed: " .. tostring(result)
  end

  return result, nil
end

function ae2.getCraftableStack(craftable)
  if not craftable then return nil end

  -- In GTNH/OC the returned Craftable is userdata. Do not inspect
  -- the userdata type or its fields before calling getItemStack():
  -- the direct call is the same form that works from the diagnostic test.
  local ok, stack = pcall(function()
    return craftable.getItemStack()
  end)
  if ok and type(stack) == "table" then
    return stack
  end

  -- Compatibility fallback for userdata implementations requiring colon syntax.
  ok, stack = pcall(function()
    return craftable:getItemStack()
  end)
  if ok and type(stack) == "table" then
    return stack
  end

  return nil
end

function ae2.findCraftable(meProxy, target)
  if not target.name then
    return nil, nil, "Target has no registry name"
  end

  -- IMPORTANT: in this GTNH/OC environment the combined
  -- {name = ..., damage = ...} filter misses the Titanium Plate,
  -- while {name = ...} returns it. This was verified directly.
  -- Therefore we filter only by registry name and verify damage
  -- against Craftable:getItemStack().
  local craftables, err = ae2.getCraftables(meProxy, {
    name = target.name
  })

  if not craftables then
    return nil, nil, err
  end

  local checked = 0

  for _, craftable in pairs(craftables) do
    if craftable then
      checked = checked + 1

      local stack = ae2.getCraftableStack(craftable)

      if stack and
         stack.name == target.name and
         tonumber(stack.damage) == tonumber(target.damage) then
        return craftable, stack, nil
      end
    end
  end

  return nil, nil,
    "No exact crafting pattern found for " ..
    tostring(target.label or target.name) ..
    " (checked " .. tostring(checked) .. " craftables)"
end

function ae2.requestCraft(craftable, amount)
  if not craftable then
    return false, "Invalid craftable object"
  end

  amount = tonumber(amount)
  if not amount or amount <= 0 then
    return false, "Invalid craft amount"
  end

  local ok, request = pcall(function()
    return craftable.request(amount)
  end)

  if not ok or not request then
    ok, request = pcall(function()
      return craftable:request(amount)
    end)
  end

  if not ok or not request then
    return false,
      "AE2 rejected the craft request " ..
      "(no CPU, missing ingredients, or unavailable pattern)"
  end

  return true, request
end

function ae2.isJobDone(job)
  if not job then return true end

  local ok, result = pcall(function()
    return job.isDone()
  end)
  if ok and result == true then return true end

  ok, result = pcall(function()
    return job:isDone()
  end)
  return ok and result == true
end

function ae2.isJobCanceled(job)
  if not job then return false end

  local ok, result = pcall(function()
    return job.isCanceled()
  end)
  if ok and result == true then return true end

  ok, result = pcall(function()
    return job:isCanceled()
  end)
  if ok and result == true then return true end

  if type(job.hasFailed) == "function" then
    ok, result = pcall(function()
      return job.hasFailed()
    end)
    if ok and result == true then return true end
  end

  return false
end

-- Defensive CPU check. It only uses getCpus(), never the whole item network.
function ae2.isCpuCraftingTarget(meProxy, targets)
  if not meProxy then return false, nil end

  local ok, cpus = invoke(meProxy, "getCpus")
  if not ok or type(cpus) ~= "table" then
    return false, nil
  end

  for _, cpu in pairs(cpus) do
    if type(cpu) == "table" and cpu.busy then
      local entry =
        cpu.craftingItem or
        cpu.activeItem or
        (cpu.storedItems and cpu.storedItems[1])

      if entry then
        for _, target in ipairs(targets) do
          if ae2.matchItem(entry, target) then
            return true, target.label
          end
        end
      end
    end
  end

  return false, nil
end

return ae2
