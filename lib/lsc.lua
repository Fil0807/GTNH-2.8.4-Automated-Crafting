--[[
  lib/lsc.lua
  Wireless EU reader for GTNH 2.8.4 / OpenComputers 1.8.9.
]]
local component = require("component")
local lsc = {}

local function stripFormatting(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("§.", ""))
end

local function normalizeSpaces(s)
  return (s:gsub("%s+", " "))
end

function lsc.formatNumber(n)
  n = tonumber(n)
  if not n then return tostring(n) end
  local negative = n < 0
  local value = math.abs(n)
  if value >= 1e15 then
    return string.format("%.6e", n)
  end
  local integer = math.floor(value + 0.5)
  local out = tostring(integer)
  local changed
  repeat
    out, changed = out:gsub("^(%d+)(%d%d%d)", "%1,%2")
  until changed == 0
  if negative then out = "-" .. out end
  return out
end

function lsc.formatEU(eu)
  eu = tonumber(eu)
  if not eu then return "N/A" end
  local units = {
    {1e24, "YEU"},
    {1e21, "ZEU"},
    {1e18, "EEU"},
    {1e15, "PEU"},
    {1e12, "TEU"},
    {1e9,  "GEU"},
    {1e6,  "MEU"},
    {1e3,  "kEU"},
  }
  local abs = math.abs(eu)
  for _, u in ipairs(units) do
    if abs >= u[1] then
      return string.format("%.2f %s", eu / u[1], u[2])
    end
  end
  return lsc.formatNumber(eu) .. " EU"
end

local function parseNumber(s)
  if type(s) ~= "string" then return nil end
  s = stripFormatting(s)
  s = s:gsub(",", "")
  s = normalizeSpaces(s)
  s = s:gsub(
    "([%+%-]?%d+%.?%d*)[x×%*]10%^([%+%-]?%d+)",
    "%1e%2"
  )
  local scientific =
    s:match("[%+%-]?%d+%.?%d*[eE][%+%-]?%d+")
  if scientific then
    return tonumber(scientific)
  end
  local decimal =
    s:match("[%+%-]?%d+%.?%d*")
  return decimal and tonumber(decimal) or nil
end

local function invoke(proxy, method, ...)
  if not proxy or not proxy.address then
    return false, "Invalid component proxy"
  end
  local args = {...}
  local unpackFn = table.unpack or unpack
  local ok, result = pcall(function()
    return component.invoke(proxy.address, method, unpackFn(args))
  end)
  return ok, result
end

function lsc.getSensorInformation(proxy)
  local ok, info = invoke(proxy, "getSensorInformation")
  if not ok then return nil, tostring(info) end
  if type(info) ~= "table" then
    return nil, "getSensorInformation() returned " .. tostring(type(info))
  end
  return info, nil
end

local function wirelessModeFromInfo(info)
  for _, line in pairs(info) do
    if type(line) == "string" then
      local lower = stripFormatting(line):lower()
      if lower:find("wireless mode", 1, true) then
        if lower:find("enabled", 1, true) then return true end
        if lower:find("disabled", 1, true) then return false end
      end
    end
  end
  return nil
end

function lsc.getWirelessEU(proxy, debug)
  local info, err = lsc.getSensorInformation(proxy)
  if not info then
    return nil, "getSensorInformation() failed: " .. tostring(err),
      nil, nil
  end

  local scientificCandidate = nil
  local numericCandidate = nil
  local numericIndex = nil

  for index, line in pairs(info) do
    if type(line) == "string" then
      local clean = normalizeSpaces(stripFormatting(line))
      local lower = clean:lower()

      if lower:find("wireless", 1, true) and
         lower:find("eu", 1, true) then

        local isRate =
          lower:find("/t", 1, true) ~= nil or
          lower:find("eu/t", 1, true) ~= nil

        if not isRate then
          local value = parseNumber(clean)
          if value then
            if clean:find("[x×%*]10%^") then
              scientificCandidate = {
                value = value,
                line = clean,
                index = index
              }
            elseif not numericCandidate then
              numericCandidate = value
              numericIndex = index
            end
          end
        end
      end
    end
  end

  local value, rawLine, selectedIndex

  if scientificCandidate then
    value = scientificCandidate.value
    rawLine = scientificCandidate.line
    selectedIndex = scientificCandidate.index
  elseif numericCandidate then
    value = numericCandidate
    rawLine = stripFormatting(info[numericIndex])
    selectedIndex = numericIndex
  else
    if debug then
      print("[LSC DEBUG] No Wireless EU sensor line found.")
      for i, line in pairs(info) do
        print("  [" .. tostring(i) .. "] " .. tostring(line))
      end
    end
    return nil,
      "No Wireless EU value found in getSensorInformation()",
      info,
      wirelessModeFromInfo(info)
  end

  local wirelessEnabled = wirelessModeFromInfo(info)

  if debug then
    print(
      string.format(
        "[LSC DEBUG] Wireless EU source [%s]: %s",
        tostring(selectedIndex),
        tostring(rawLine)
      )
    )
    print(
      "[LSC DEBUG] Parsed Wireless EU: " ..
      lsc.formatNumber(value)
    )
    print(
      "[LSC DEBUG] Wireless mode: " ..
      tostring(wirelessEnabled)
    )
  end

  return value, rawLine, info, wirelessEnabled
end

return lsc
