--[[
  installer.lua
  GTNH 2.8.4 Automated Crafting - v7

  Usage:
    wget -f "https://raw.githubusercontent.com/OWNER/REPO/main/installer.lua" installer.lua
    lua installer.lua

  Or pass the raw GitHub directory explicitly:
    lua installer.lua "https://raw.githubusercontent.com/OWNER/REPO/main"

  IMPORTANT:
    Replace DEFAULT_BASE_URL before uploading this installer if you want
    the no-argument installation command to work.
]]

local DEFAULT_BASE_URL =
  "https://raw.githubusercontent.com/OWNER/REPO/main"

local VERSION = "v7"

local args = {...}
local baseUrl = args[1] or DEFAULT_BASE_URL
baseUrl = tostring(baseUrl):gsub("/+$", "")

local component = require("component")
local filesystem = require("filesystem")

if not component.isAvailable("internet") then
  io.stderr:write("ERROR: Internet Card required.\n")
  return
end

local internet = require("internet")

local files = {
  {remote = "main.lua",                    localPath = "/home/main.lua"},
  {remote = "config.lua",                  localPath = "/home/config.lua"},
  {remote = "lib/ae2.lua",                 localPath = "/home/lib/ae2.lua"},
  {remote = "lib/lsc.lua",                 localPath = "/home/lib/lsc.lua"},
  {remote = "lib/component-discover.lua",  localPath = "/home/lib/component-discover.lua"},
  {remote = "tests/test-ae2.lua",          localPath = "/home/tests/test-ae2.lua"},
  {remote = "tests/test-lsc.lua",          localPath = "/home/tests/test-lsc.lua"},
  {remote = "tests/test4.lua",             localPath = "/home/tests/test4.lua"},
  {remote = "tests/test-craftable.lua",    localPath = "/home/tests/test-craftable.lua"},
  {remote = "README.md",                   localPath = "/home/README.md"},
}

local function download(url, path)
  local response, reason = internet.request(url)

  if not response then
    return false, tostring(reason)
  end

  filesystem.makeDirectory(filesystem.path(path))

  local file, openReason = io.open(path, "wb")
  if not file then
    return false, tostring(openReason)
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
print("Source: " .. baseUrl)
print("")

for _, entry in ipairs(files) do
  local url = baseUrl .. "/" .. entry.remote

  io.write("[DOWNLOAD] " .. entry.remote .. " ... ")

  local ok, reason = download(url, entry.localPath)

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
print("Run:")
print("  cd /home")
print("  main")
