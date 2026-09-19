--[[
  lib/component-discover.lua
  Hardware discovery for GTNH 2.8.4 / OpenComputers 1.8.9.
]]
local component = require("component")
local discover = {}

function discover.resolveAddress(address, componentType)
  if not address then return nil end
  local full, err = component.get(address, componentType)
  if not full then return nil, tostring(err) end
  local ok, proxy = pcall(component.proxy, full)
  if not ok or not proxy then
    return nil, "Could not create proxy for " .. tostring(full)
  end
  return proxy, nil
end

function discover.listMethods(proxy)
  if not proxy or not proxy.address then return {} end
  local ok, methods = pcall(component.methods, proxy.address)
  if not ok or type(methods) ~= "table" then return {} end
  local list = {}
  for name in pairs(methods) do list[#list + 1] = name end
  table.sort(list)
  return list
end

local function hasMethod(proxy, wanted)
  if not proxy or not proxy.address then return false end
  local ok, methods = pcall(component.methods, proxy.address)
  if not ok or type(methods) ~= "table" then return false end
  return methods[wanted] ~= nil
end

local function invoke(proxy, method, ...)
  if not proxy or not proxy.address then
    return false, "Invalid component proxy"
  end
  local args = {...}
  local unpackFn = table.unpack or unpack
  return pcall(function()
    return component.invoke(proxy.address, method, unpackFn(args))
  end)
end

local function hasWirelessSensor(proxy)
  if not hasMethod(proxy, "getSensorInformation") then return false end
  local ok, info = invoke(proxy, "getSensorInformation")
  if not ok or type(info) ~= "table" then return false end
  for _, line in pairs(info) do
    if type(line) == "string" and
       line:lower():find("wireless", 1, true) then
      return true
    end
  end
  return false
end

function discover.discoverLSC(forcedAddress, debug)
  if forcedAddress then
    local proxy = discover.resolveAddress(forcedAddress, "gt_machine")
    if proxy and hasWirelessSensor(proxy) then
      return proxy, nil
    end
    if debug then
      print("[DISCOVER] Forced LSC address invalid; trying automatic discovery.")
    end
  end

  local candidates = {}
  for address in component.list("gt_machine") do
    local ok, proxy = pcall(component.proxy, address)
    if ok and proxy then candidates[#candidates + 1] = proxy end
  end

  if #candidates == 0 then
    return nil,
      "No gt_machine found. Connect the Adapter to the LSC Controller or Information Hatch."
  end

  for _, proxy in ipairs(candidates) do
    if hasWirelessSensor(proxy) then
      if debug then
        print("[DISCOVER] LSC found at " .. tostring(proxy.address))
      end
      return proxy, nil
    end
  end

  return nil, "gt_machine component(s) found, but none exposes usable Wireless EU sensor data."
end

function discover.discoverAE(forcedAddress, debug)
  if forcedAddress then
    local proxy = discover.resolveAddress(forcedAddress, "me_interface")
    if not proxy then
      proxy = discover.resolveAddress(forcedAddress, "me_controller")
    end
    if proxy then return proxy, nil end
    return nil,
      "Configured AE2 address is invalid: " .. tostring(forcedAddress)
  end

  for address in component.list("me_interface") do
    local ok, proxy = pcall(component.proxy, address)
    if ok and proxy then
      if debug then print("[DISCOVER] ME Interface: " .. tostring(address)) end
      return proxy, nil
    end
  end

  for address in component.list("me_controller") do
    local ok, proxy = pcall(component.proxy, address)
    if ok and proxy then
      if debug then print("[DISCOVER] ME Controller: " .. tostring(address)) end
      return proxy, nil
    end
  end

  return nil,
    "No AE2 component found. Connect an Adapter to an ME Interface or ME Controller."
end

return discover
