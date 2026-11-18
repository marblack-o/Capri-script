--[[
  loader-allinone.lua
  Que: bootstrap J.A.R.V.I.S. modular v8.1.0 (HUD Claude)
]]

print("[JARVIS] Loader modular v8.1.0 (HUD Claude)...")

local BASE = "https://raw.githubusercontent.com/marblack-o/JARVIS-script/cf42c98ae6b9512ef91ac5ddb5cf00fd251b94e9/"

local function fetch(path)
	local url = BASE .. path
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if not ok or not body or body == "" then
		local req = (syn and syn.request) or (http and http.request) or request
		if req then
			local ok2, res = pcall(req, { Url = url, Method = "GET" })
			if ok2 and res and (res.Body or res.body) then
				body = res.Body or res.body
			end
		end
	end
	if not body or body == "" then
		error("[JARVIS] No se pudo descargar " .. path)
	end
	return body
end

local function loadMod(path)
	local src = fetch(path)
	local fn, err = loadstring(src, path)
	if not fn then error("[JARVIS] compile " .. path .. ": " .. tostring(err)) end
	local ok, mod = pcall(fn)
	if not ok then error("[JARVIS] run " .. path .. ": " .. tostring(mod)) end
	return mod
end

local modules = {
	Config = loadMod("src/Config.lua"),
	Theme = loadMod("src/Theme.lua"),
	Assets = loadMod("src/Assets.lua"),
	UAIBridge = loadMod("src/UAIBridge.lua"),
	Visual = loadMod("src/Visual.lua"),
	UI_Chat = loadMod("src/UI_Chat.lua"),
	Explorer = loadMod("src/Explorer.lua"),
	Hack = loadMod("src/Hack.lua"),
	App = loadMod("src/App.lua"),
}

assert(type(modules.Config.load) == "function", "Config.load missing")
assert(type(modules.UAIBridge.ensure) == "function", "UAIBridge.ensure missing")
assert(type(modules.Visual.new) == "function", "Visual.new missing")
assert(type(modules.UI_Chat.new) == "function", "UI_Chat.new missing")
assert(type(modules.Explorer.render) == "function", "Explorer.render missing")
assert(type(modules.Hack.new) == "function", "Hack.new missing")
assert(type(modules.App.boot) == "function", "App.boot missing")

modules.App.boot(modules)
