--[[
  installer-v8.lua
  GTNH 2.8.4 Automated Crafting

  Source repository:
  https://github.com/Fil0807/GTNH-2.8.4-Automated-Crafting
]]

local VERSION = "v8"
local BASE =
  "https://raw.githubusercontent.com/Fil0807/GTNH-2.8.4-Automated-Crafting/main"

local component = require("component")
local filesystem = require("filesystem")
local internet = require("internet")

if not component.isAvailable("internet") then
  io.stderr:write("ERROR: Internet Card required.\n")
  return
end

local files = {
  "main.lua",
  "config.lua",
  "lib/ae2.lua",
  "lib/lsc.lua",
  "lib/component-discover.lua",
  "tests/test-ae2.lua",
  "tests/test-lsc.lua",
  "tests/test4.lua",
  "tests/test-craftable.lua",
  "README.md",
}

local function download(url, path)
  local response, reason = internet.request(url)
  if not response then
    return false, tostring(reason)
  end

  filesystem.makeDirectory(filesystem.path(path))

  local file, err = io.open(path, "wb")
  if not file then
    return false, tostring(err)
  end

  for chunk in response do
    file:write(chunk)
  end

  file:close()
  return true
end

print("============================================================")
print(" GTNH Automated Crafting - " .. VERSION)
print("============================================================")
print("Source: " .. BASE)
print("")

for _, relative in ipairs(files) do
  io.write("[DOWNLOAD] " .. relative .. " ... ")

  local ok, reason =
    download(BASE .. "/" .. relative, "/home/" .. relative)

  if not ok then
    print("FAILED")
    io.stderr:write("  " .. tostring(reason) .. "\n")
    return
  end

  print("OK")
end

print("")
print("============================================================")
print(" Installation complete")
print(" Project version: " .. VERSION)
print(" AE2 module:      " .. VERSION)
print(" Files installed: " .. #files)
print("============================================================")
print("")
print("Run: main")
