--[[
  Capri × Project UAI — v6 Workbench
  - Chat centrado estilo Project
  - Varios historiales (chats)
  - Sección Providers (keys locales + links)
  - Ventana de hack aparte
  - Saludo una sola vez (no se duplica al reabrir)
]]

print("[Capri] Iniciando v6 Workbench...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function httpRequest(opts)
	local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
	if req then
		local ok, res = pcall(req, opts)
		if ok and res then return res end
	end
	if opts.Method == "GET" or not opts.Method then
		local ok, body = pcall(function() return game:HttpGet(opts.Url) end)
		if ok and body then return { StatusCode = 200, Body = body } end
	end
	return nil
end

local function copyText(s)
	s = tostring(s or "")
	if s == "" then return false end
	if type(setclipboard) == "function" then
		pcall(setclipboard, s)
		return true
	end
	if type(toclipboard) == "function" then
		pcall(toclipboard, s)
		return true
	end
	pcall(function()
		if StarterGui and StarterGui.SetCore then
			-- no universal clipboard core; ignore
		end
	end)
	return false
end

-- ═══════════════════════════════════════════
-- ASSETS
-- ═══════════════════════════════════════════

local GITHUB_ASSET_URL = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/assets/"
local assetCache = {}

local function loadAsset(fileName)
	if assetCache[fileName] ~= nil then return assetCache[fileName] end
	local localPath = "CapriAsset_" .. fileName
	if type(isfile) == "function" and type(writefile) == "function" then
		if not isfile(localPath) then
			local success, res = pcall(function()
				return game:HttpGet(GITHUB_ASSET_URL .. fileName)
			end)
			if success and res and res ~= "" and res ~= "404: Not Found" and #res > 100 then
				pcall(writefile, localPath, res)
			else
				assetCache[fileName] = ""
				return ""
			end
		end
		if type(getcustomasset) == "function" then
			local ok, assetId = pcall(getcustomasset, localPath)
			assetCache[fileName] = (ok and assetId) or ""
			return assetCache[fileName]
		end
	end
	assetCache[fileName] = ""
	return ""
end

local CapriAssets = {
	Face = loadAsset("capri-face.png"),
	Cutout = loadAsset("capri-cutout.png"),
	FaceCalm = loadAsset("face-calm.png"),
	FaceLook = loadAsset("face-look.png"),
	FaceAside = loadAsset("face-aside.png"),
	FaceSmug = loadAsset("face-smug.png"),
	FaceLaugh = loadAsset("face-laugh.png"),
	FaceWide = loadAsset("face-wide.png"),
	FaceMany = loadAsset("face-many.png"),
	Grin = loadAsset("cutin-grin.png"),
	Eyes = loadAsset("cutin-eyes.png"),
}

local function pickImage(...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		local img = CapriAssets[key]
		if img and img ~= "" then return img end
	end
	return ""
end

-- ═══════════════════════════════════════════
-- CONFIG LOCAL
-- ═══════════════════════════════════════════

local CONFIG_FILE = "capri_config.json"

local function canFS()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function loadConfig()
	if not canFS() then return {} end
	local ok, data = pcall(function()
		if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end
		return nil
	end)
	if ok and type(data) == "table" then return data end
	return {}
end

local function saveConfig(cfg)
	if not canFS() then return false end
	return pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
end

local Theme = {
	bg = Color3.fromRGB(12, 8, 18),
	panel = Color3.fromRGB(26, 14, 40),
	plate = Color3.fromRGB(32, 18, 50),
	sidebar = Color3.fromRGB(18, 10, 30),
	border = Color3.fromRGB(255, 70, 180),
	accent = Color3.fromRGB(255, 55, 160),
	glitch = Color3.fromRGB(255, 220, 60),
	green = Color3.fromRGB(40, 255, 140),
	text = Color3.fromRGB(245, 235, 255),
	textDim = Color3.fromRGB(170, 145, 195),
	inputBg = Color3.fromRGB(14, 8, 24),
	danger = Color3.fromRGB(255, 70, 100),
	bubbleUser = Color3.fromRGB(42, 24, 62),
	bubbleAi = Color3.fromRGB(20, 12, 34),
	row = Color3.fromRGB(30, 16, 46),
}

-- Providers inspirados en presets/compat de Project UAI
-- (keys se guardan local; Capri-chat usa Groq; hacks usan UAI)
local PROVIDER_CATALOG = {
	{
		id = "groq",
		name = "Groq",
		desc = "Chat de Capri (rápido, free tier)",
		keyField = "groq_key",
		link = "https://console.groq.com/keys",
		forCapri = true,
	},
	{
		id = "openrouter",
		name = "OpenRouter",
		desc = "Muchos modelos con una key",
		keyField = "openrouter_key",
		link = "https://openrouter.ai/keys",
	},
	{
		id = "openai",
		name = "OpenAI",
		desc = "API oficial OpenAI",
		keyField = "openai_key",
		link = "https://platform.openai.com/api-keys",
	},
	{
		id = "gemini",
		name = "Google Gemini",
		desc = "Google AI Studio",
		keyField = "gemini_key",
		link = "https://aistudio.google.com/apikey",
	},
	{
		id = "deepseek",
		name = "DeepSeek",
		desc = "API DeepSeek",
		keyField = "deepseek_key",
		link = "https://platform.deepseek.com/api_keys",
	},
	{
		id = "anthropic",
		name = "Anthropic",
		desc = "Claude API",
		keyField = "anthropic_key",
		link = "https://console.anthropic.com/settings/keys",
	},
	{
		id = "hcnsec",
		name = "HCNSEC",
		desc = "Key personal HCNSEC (UAI)",
		keyField = "hcnsec_key",
		link = "https://www.hcnsec.cn/",
	},
	{
		id = "uai_free",
		name = "Project UAI Free",
		desc = "Sin key · horario 20:00–12:00 UTC+8",
		keyField = nil,
		link = "https://discord.gg/9xYyyYuKap",
		noKey = true,
	},
}

local CAPRI_PROMPT = [[
You are Capri (Project Capricorn) from Cyberpunk: Edgerunners 2.
Personality construct inside this Roblox session with the user (your choom).
Playful chaos gremlin: high-energy, teasing, smug, mischievous, loyal.
Short lively answers. Same language as the user.

CRITICAL: You are INSIDE a live Roblox game. "El juego" / "the game" = THIS DataModel. Never ask which title.
]]

local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "openai/gpt-oss-20b"
local UAI_URL = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua"
local MAX_CLARIFY = 4

pcall(function()
	local old = CoreGui:FindFirstChild("CapriUAI")
	if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "CapriUAI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

local function mkCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

local function mkStroke(parent, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.border
	s.Thickness = thick or 1
	s.Transparency = trans or 0.3
	s.Parent = parent
	return s
end

-- ═══════════════════════════════════════════
-- GROQ
-- ═══════════════════════════════════════════

local function groqChat(apiKey, messages, maxTokens)
	local body = HttpService:JSONEncode({
		model = API_MODEL,
		messages = messages,
		temperature = 0.85,
		max_tokens = maxTokens or 500,
	})
	local res = httpRequest({
		Url = API_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. apiKey,
		},
		Body = body,
	})
	if not res or not res.Body then return nil, "http_fail" end
	local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not ok or not data then return nil, "json_fail" end
	if data.error then return nil, tostring(data.error.message or data.error) end
	local c = data.choices and data.choices[1]
	local content = c and c.message and c.message.content
	if content and content ~= "" then return content, nil end
	return nil, "empty"
end

-- ═══════════════════════════════════════════
-- UAI
-- ═══════════════════════════════════════════

local uaiHandle = nil

local function loadUAI(withUi)
	local ok, handleOrErr = pcall(function()
		return loadstring(game:HttpGet(UAI_URL))({ ui = withUi and true or false, reuse = true })
	end)
	if not ok then return nil, tostring(handleOrErr) end
	if type(handleOrErr) ~= "table" then return nil, "no handle" end
	return handleOrErr, nil
end

local function ensureUAI(allowVisible)
	if uaiHandle and uaiHandle.alive then return true, nil end
	local handle = select(1, loadUAI(false))
	if handle and handle.alive then
		uaiHandle = handle
		pcall(function() if handle.sdk and handle.sdk.createScope then handle.sdk.createScope("capri-host") end end)
		return true, nil
	end
	if allowVisible ~= false then
		local handle2 = select(1, loadUAI(true))
		if handle2 and handle2.alive then
			uaiHandle = handle2
			pcall(function() if handle2.sdk and handle2.sdk.createScope then handle2.sdk.createScope("capri-host") end end)
			pcall(function() if handle2.show then handle2.show("providers") end end)
			return true, "needs_setup"
		end
	end
	return false, "UAI offline"
end

local function friendlyUAIError(err)
	local e = tostring(err or "")
	local low = e:lower()
	if low:find("20:00") or low:find("utc+8") or low:find("outside its daily") then
		return e .. "\n\nFree solo opera 20:00–12:00 UTC+8. Usa otro provider en UAI o espera esa ventana."
	end
	if low:find("provider") then
		return e .. "\n\nAbre la pestaña Providers en Capri o en UAI y configura una key / modelo."
	end
	return e
end

local function runUAIMission(missionPrompt, onComplete)
	task.spawn(function()
		local okLoad, loadErr = ensureUAI(true)
		if not okLoad then
			onComplete(false, friendlyUAIError(loadErr))
			return
		end
		if not uaiHandle.sdk or not uaiHandle.sdk.request then
			onComplete(false, "UAI sin sdk.request")
			return
		end
		local session, sessionErr
		if uaiHandle.sessions and uaiHandle.sessions.open then
			local okS, a, b = pcall(function()
				return uaiHandle.sessions.open("capri-hack-" .. tostring(math.floor(os.clock() * 1000)), {
					title = "Capri Hack",
					ephemeral = true,
					toolFilter = {},
				})
			end)
			if okS then session, sessionErr = a, b else sessionErr = a end
		else
			sessionErr = "sessions.open missing"
		end
		if not session then
			pcall(function() if uaiHandle.show then uaiHandle.show("providers") end end)
			onComplete(false, friendlyUAIError("No sesión UAI: " .. tostring(sessionErr)))
			return
		end

		local settled = false
		local finalResult = nil
		local function finish(ok, payload)
			if settled then return end
			settled = true
			onComplete(ok, payload)
		end

		local req, why
		local okReq, a, b = pcall(function()
			return uaiHandle.sdk.request(session, missionPrompt, {
				onComplete = function(result) finalResult = result end,
			})
		end)
		if not okReq then finish(false, "sdk.request: " .. tostring(a)) return end
		req, why = a, b
		if not req then finish(false, "request rechazado: " .. tostring(why)) return end

		local WAIT_SEC = 300
		if type(req.await) == "function" then
			local okW, result, waitErr = pcall(function() return req.await(WAIT_SEC) end)
			if not okW then finish(false, "await: " .. tostring(result)) return end
			if result == nil then
				local leftover = req.result or finalResult
				if leftover and leftover.ok then
					finish(true, leftover.text or leftover.output or "Hack listo.")
				else
					finish(false, friendlyUAIError(waitErr or "Timeout UAI 300s"))
				end
				return
			end
			if type(result) == "table" then
				if result.ok then
					finish(true, result.text or result.output or result.message or "Hack listo.")
				else
					finish(false, friendlyUAIError(result.error or result.message))
				end
				return
			end
		end

		local t0 = os.clock()
		while not settled and (os.clock() - t0) < WAIT_SEC do
			local r = (req and req.result) or finalResult
			if type(r) == "table" and (r.ok == true or r.ok == false or r.text or r.error) then
				if r.ok then finish(true, r.text or r.output or "Hack listo.")
				else finish(false, friendlyUAIError(r.error or r.message)) end
				return
			end
			task.wait(0.35)
		end
		if not settled then finish(false, "Timeout esperando UAI") end
	end)
end

local function detectKind(text)
	local l = string.lower(text)
	if l:find("investiga") or l:find("busca") or l:find("analiza") or l:find("explora")
		or l:find("lista") or l:find("inspeccion") or l:find("scan") then
		return "research"
	end
	return "action"
end

local function isHackClear(text)
	local l = string.lower(text)
	local about = l:find("el juego") or l:find("este juego") or l:find("the game")
		or l:find("workspace") or l:find("scripts") or l:find("aquí") or l:find("aqui")
	local verb = l:find("analiza") or l:find("explora") or l:find("lista") or l:find("crea")
		or l:find("haz") or l:find("modifica") or l:find("hack")
	if verb and about then return true end
	if #l < 48 and (l:find("analiza") or l:find("explora")) then return true end
	return false
end

local function needsUiSpec(text)
	local l = string.lower(text or "")
	return l:find("panel") or l:find("ui") or l:find("gui") or l:find("hud")
		or l:find("menu") or l:find("interfaz") or l:find("bot[oó]n")
end

local function buildHackPrompt(brief)
	local placeName = "unknown"
	pcall(function()
		placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	local lines = {
		"JOB FROM CAPRI (Roblox executor host)",
		"Live DataModel only. PlaceId=" .. tostring(game.PlaceId) .. " name=" .. tostring(placeName),
		"User request: " .. brief.original,
		"Job type: " .. brief.kind,
		"",
		"COMPLETION: Finish FULL work with tools before final answer. No early plan-only stop.",
	}
	if #brief.answers > 0 then
		table.insert(lines, "Clarifications:")
		for i, a in ipairs(brief.answers) do table.insert(lines, ("  %d) %s"):format(i, a)) end
	end
	if brief.kind == "research" then
		table.insert(lines, "RESEARCH only unless user asked to change something.")
	else
		table.insert(lines, "ACTION: apply changes, then summarize.")
	end
	if needsUiSpec(brief.original) then
		table.insert(lines, "UI SPEC: ScreenGui ResetOnSpawn=false; dark purple panel; pink/yellow accent; close btn; working buttons; verify instances exist.")
	end
	table.insert(lines, "Never ask which game.")
	return table.concat(lines, "\n")
end

