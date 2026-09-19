-- tests/test4.lua
-- Targeted AE2 inventory test.
-- Uses numeric item ID + damage; labels are NOT used for matching.

local component = require("component")

local address = "dc277e87-7056-46f5-a572-b03d3873e515"

local items = {
  {
    id = 7437,
    damage = 17028
  },
  {
    id = 2858,
    damage = 8
  },
  {
    id = 2859,
    damage = 8
  },
  {
    id = 2860,
    damage = 8
  }
}

print("=== AE2 ITEM TEST ===")
print("")

for _, target in ipairs(items) do
  local ok, result = pcall(
    component.invoke,
    address,
    "getItemsInNetworkById",
    {target.id}
  )

  if not ok then
    print("ID: " .. target.id)
    print("Errore: " .. tostring(result))
    print("")
  else
    local found = false

    for _, item in ipairs(result) do
      if type(item) == "table"
         and item.name == (
           target.id == 7437
             and "gregtech:gt.metaitem.01"
             or (
               target.id == 2858
                 and "tectech:gt.spacetime_compression_field_generator"
                 or (
                   target.id == 2859
                     and "tectech:gt.time_acceleration_field_generator"
                     or "tectech:gt.stabilisation_field_generator"
                 )
             )
         )
         and tonumber(item.damage) == target.damage then

        found = true

        print("Nome:      " .. tostring(item.label))
        print("ID:        " .. tostring(target.id))
        print("Quantità:  " .. tostring(item.size))
        print("Craftabile: " .. tostring(item.isCraftable))
        print("")
      end
    end

    if not found then
      print("ID:        " .. tostring(target.id))
      print("Quantità:  0")
      print("Craftabile: false")
      print("")
    end
  end

  print("------------------------------")
end
