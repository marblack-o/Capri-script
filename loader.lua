--[[
  Capri × Project UAI
  Loader — ejecuta esto con loadstring

  Uso:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/TU_USUARIO/capri-uai/main/loader.lua"))()

  Las API keys / providers se configuran DESPUÉS de que cargue el panel
  (desde el propio panel de Capri o desde la UI de Project UAI).
]]

local BASE = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/"

-- Cambia esta URL cuando subas el repo a tu GitHub
-- Ejemplo: https://raw.githubusercontent.com/tuuser/capri-uai/main/

local function fetch(path)
    local ok, result = pcall(function()
        return game:HttpGet(BASE .. path)
    end)
    if not ok or not result or result == "" then
        error("[Capri] No se pudo descargar: " .. path .. "\nRevisa que el repo sea público y la URL sea correcta.")
    end
    return result
end

print("[Capri] Cargando host...")

local hostSrc = fetch("src/host.lua")
local hostFn, err = loadstring(hostSrc)
if not hostFn then
    error("[Capri] Error al compilar host.lua:\n" .. tostring(err))
end

local ok, result = pcall(hostFn, {
    baseUrl = BASE,
    fetch = fetch,
})

if not ok then
    error("[Capri] Falló al iniciar:\n" .. tostring(result))
end

return result
