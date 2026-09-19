-- tests/test-lsc.lua
package.path =
  "./?.lua;./lib/?.lua;/home/?.lua;/home/lib/?.lua;" ..
  package.path

local discover = require("lib.component-discover")
local lsc = require("lib.lsc")

print("=== LSC TEST ===")

local proxy, err = discover.discoverLSC(nil, true)
if not proxy then
  print("ERROR: " .. tostring(err))
  return
end

print("LSC address: " .. tostring(proxy.address))

local value, rawLine, info, wirelessEnabled =
  lsc.getWirelessEU(proxy, true)

if not value then
  print("ERROR: " .. tostring(rawLine))
  return
end

print("")
print("Selected sensor line:")
print("  " .. tostring(rawLine))
print("")
print("Parsed Wireless EU:")
print("  " .. lsc.formatNumber(value))
print("  " .. lsc.formatEU(value))
print("")
print("Wireless mode:")
print("  " .. tostring(wirelessEnabled))
print("")
print("Threshold example (5e20 EU):")
print("  " .. tostring(value >= 5e20))
print("")
print("LSC test complete. No AE2 operation was performed.")
