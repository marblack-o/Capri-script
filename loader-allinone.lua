--[[
  Capri × Project UAI — v5.2 loader
  Sprite libre + chat púrpura/glitch + "hack" en vez de misión
]]
print("[Capri] Iniciando v5.2...")
local BASE = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/"
local function fetch(path)
    local ok, body = pcall(function() return game:HttpGet(BASE .. path) end)
    if not ok or not body or body == "" then
        local req = (syn and syn.request) or (http and http.request) or request
        if req then
            local ok2, res = pcall(req, {Url = BASE .. path, Method = "GET"})
            if ok2 and res and (res.Body or res.body) then
                body = res.Body or res.body
            end
        end
    end
    if not body or body == "" then
        error("[Capri] No se pudo descargar " .. path)
    end
    return body
end
local src = fetch("src/capri_part1.lua") .. fetch("src/capri_part2.lua") .. fetch("src/capri_part3.lua")
local fn, err = loadstring(src)
if not fn then error("[Capri] compile: " .. tostring(err)) end
fn()
