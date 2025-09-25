-- DexorEH Loader by MrCatMemes
local success, result = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/MrCatMemes/DexorEH/main/dexoreh.lua")
end)

if success then
    loadstring(result)()
else
    warn("Failed to load DexorEH Hub: " .. tostring(result))
end
