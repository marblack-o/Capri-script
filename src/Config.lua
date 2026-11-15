--[[
  Config.lua
  Que: lectura/escritura de capri_config.json en el filesystem del executor.
  Por que: keys, chats e historial deben vivir fuera del repo (nunca en GitHub).
]]

local HttpService = game:GetService("HttpService")
local CONFIG_FILE = "capri_config.json"

local Config = {}

function Config.canFS()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
end

function Config.load()
	if not Config.canFS() then return {} end
	local ok, data = pcall(function()
		if isfile(CONFIG_FILE) then
			return HttpService:JSONDecode(readfile(CONFIG_FILE))
		end
		return nil
	end)
	if ok and type(data) == "table" then return data end
	return {}
end

function Config.save(cfg)
	if not Config.canFS() then return false end
	return pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
	end)
end

function Config.ensureDefaults(cfg)
	cfg = cfg or {}
	cfg.provider_keys = type(cfg.provider_keys) == "table" and cfg.provider_keys or {}
	cfg.chats = type(cfg.chats) == "table" and cfg.chats or {}
	if #cfg.chats == 0 then
		cfg.chats = {
			{
				id = HttpService:GenerateGUID(false),
				title = "General",
				messages = {},
			},
		}
	end
	cfg.active_chat = cfg.active_chat or cfg.chats[1].id
	return cfg
end

return Config
