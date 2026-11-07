--[[
  Capri × Project UAI
  Loader

  Uso:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Capri-script/main/loader.lua"))()
]]

local BASE = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/"

local function httpGet(url)
    -- 1) game:HttpGet
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and res and res \~= "" then
        return res
    end

    -- 2) syn.request / http.request / request (ejecutores)
    local req = (syn and syn.request) or (http and http.request) or request
    if req then
        local ok2, res2 = pcall(function()
            local r = req({ Url = url, Method = "GET" })
            return r and (r.Body or r.body)
        end)
        if ok2 and res2 and res2 \~= "" then
            return res2
        end
    end

    return nil
end

local function fetch(path)
    local url = BASE .. path
    print("[Capri] Descargando:", url)
    local result = httpGet(url)
    if not result then
        error("[Capri] No se pudo descargar: " .. path .. "\nURL: " .. url .. "\nPrueba de nuevo o usa el loader all-in-one.")
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
