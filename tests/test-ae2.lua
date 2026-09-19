-- tests/test-ae2.lua
package.path =
  "./?.lua;./lib/?.lua;/home/?.lua;/home/lib/?.lua;" ..
  package.path

local component = require("component")
local discover = require("lib.component-discover")
local ae2 = require("lib.ae2")

local address = "dc277e87-7056-46f5-a572-b03d3873e515"

local targets = {
  {
    label = "Titanium Plate",
    id = 7437,
    name = "gregtech:gt.metaitem.01",
    damage = 17028
  }
}

print("=== AE2 TARGETED TEST ===")
print("Address: " .. address)
print("")

local proxy, err = discover.discoverAE(address, true)
if not proxy then
  print("ERROR: " .. tostring(err))
  return
end

for _, target in ipairs(targets) do
  print("Nome:      " .. target.label)
  print("ID:        " .. target.id)
  print("Damage:    " .. target.damage)

  local quantity, craftable, item, itemErr =
    ae2.getItemStatus(proxy, target)

  if itemErr then
    print("Errore:    " .. tostring(itemErr))
  else
    print("Quantità:  " .. tostring(quantity))
    print("Craftabile: " .. tostring(craftable))
  end

  print("")
end

print("No unfiltered getItemsInNetwork() call was made.")
