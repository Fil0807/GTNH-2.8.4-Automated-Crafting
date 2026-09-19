local component = require("component")

local address = "dc277e87-7056-46f5-a572-b03d3873e515"
local targetName = "gregtech:gt.metaitem.01"
local targetDamage = 17028

print("=== AE2 CRAFTABLE TEST ===")
print("Target:")
print("  Name:   " .. targetName)
print("  Damage: " .. targetDamage)
print("")

local ok, craftables = pcall(
    component.invoke,
    address,
    "getCraftables",
    { name = targetName }
)

if not ok then
    print("ERRORE getCraftables:")
    print(tostring(craftables))
    print("")
    print("FOUND = false")
    return
end

craftables = craftables or {}

local count = 0
local found = false

for _, craftable in pairs(craftables) do
    if craftable then
        count = count + 1

        local okStack, stack = pcall(function()
            return craftable.getItemStack()
        end)

        if okStack and stack then
            if stack.name == targetName
                and tonumber(stack.damage) == targetDamage then

                found = true

                print("")
                print("=== MATCH TROVATO ===")
                print("Name:   " .. tostring(stack.name))
                print("Damage: " .. tostring(stack.damage))
                print("Label:  " .. tostring(stack.label))
                print("Size:   " .. tostring(stack.size))
                print("")

                break
            end
        end
    end
end

print("=== RISULTATO ===")
print("Pattern controllati: " .. count)
print("Pattern Titanium Plate trovato: " .. tostring(found))
print("FOUND = " .. tostring(found))
