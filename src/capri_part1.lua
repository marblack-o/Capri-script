--[[
  Capri × Project UAI — v6.1
  - Providers: al guardar key → uai.providers.blank/save/setActive
  - Keys de pago como fallback cuando UAI Free está fuera de horario
  - Ventana hack: arrastrable + X para cerrar
  - Chat: semitransparente, borde verde (chat) / amarillo (UAI)
  - Sprite: cuerpo completo + cara encima (cambia con estado)
]]

print("[Capri] Iniciando v6.1...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

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
	if type(setclipboard) == "function" then pcall(setclipboard, s) return true end
	if type(toclipboard) == "function" then pcall(toclipboard, s) return true end
	return false
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, start, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			start = input.Position
			startPos = frame.Position
		end
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - start
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
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
			local ok, res = pcall(function() return game:HttpGet(GITHUB_ASSET_URL .. fileName) end)
			if ok and res and res ~= "" and res ~= "404: Not Found" and #res > 100 then
				pcall(writefile, localPath, res)
			else
				assetCache[fileName] = ""
				return ""
			end
		end
		if type(getcustomasset) == "function" then
			local ok, id = pcall(getcustomasset, localPath)
			assetCache[fileName] = (ok and id) or ""
			return assetCache[fileName]
		end
	end
	assetCache[fileName] = ""
	return ""
end

local CapriAssets = {
	Full = loadAsset("capri-full.png"),
	Cutout = loadAsset("capri-cutout.png"),
	Face = loadAsset("capri-face.png"),
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
-- CONFIG
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
	chatGreen = Color3.fromRGB(60, 220, 120),
	uaiYellow = Color3.fromRGB(255, 210, 50),
	green = Color3.fromRGB(40, 255, 140),
	text = Color3.fromRGB(245, 235, 255),
	textDim = Color3.fromRGB(170, 145, 195),
	inputBg = Color3.fromRGB(14, 8, 24),
	danger = Color3.fromRGB(255, 70, 100),
	bubbleUser = Color3.fromRGB(42, 24, 62),
	bubbleAi = Color3.fromRGB(20, 12, 34),
	row = Color3.fromRGB(30, 16, 46),
}

-- Presets alineados con Project UAI (blank presetId + baseUrl openai-compatible)
local PROVIDER_CATALOG = {
	{
		id = "groq",
		preset = "groq",
		name = "Groq",
		desc = "Chat Capri + fallback UAI",
		keyField = "groq_key",
		link = "https://console.groq.com/keys",
		baseUrl = "https://api.groq.com/openai/v1",
		model = "openai/gpt-oss-20b",
		forCapri = true,
	},
	{
		id = "openrouter",
		preset = "openrouter",
		name = "OpenRouter",
		desc = "Fallback cuando Free está offline",
		keyField = "openrouter_key",
		link = "https://openrouter.ai/keys",
		baseUrl = "https://openrouter.ai/api/v1",
		model = "openrouter/auto",
	},
	{
		id = "openai",
		preset = "openai",
		name = "OpenAI",
		desc = "Fallback UAI",
		keyField = "openai_key",
		link = "https://platform.openai.com/api-keys",
		baseUrl = "https://api.openai.com/v1",
		model = "gpt-4o-mini",
	},
	{
		id = "deepseek",
		preset = "deepseek",
		name = "DeepSeek",
		desc = "Fallback UAI",
		keyField = "deepseek_key",
		link = "https://platform.deepseek.com/api_keys",
		baseUrl = "https://api.deepseek.com/v1",
		model = "deepseek-chat",
	},
	{
		id = "gemini",
		preset = "gemini",
		name = "Google Gemini",
		desc = "Fallback UAI (preset gemini)",
		keyField = "gemini_key",
		link = "https://aistudio.google.com/apikey",
		baseUrl = "https://generativelanguage.googleapis.com/v1beta",
		model = "gemini-2.0-flash",
	},
	{
		id = "hcnsec",
		preset = "hcnsec",
		name = "HCNSEC",
		desc = "Key personal (misma red que Free)",
		keyField = "hcnsec_key",
		link = "https://www.hcnsec.cn/",
		baseUrl = "https://api.hcnsec.cn/v1",
		model = "auto",
	},
	{
		id = "uai_free",
		name = "Project UAI Free",
		desc = "Sin key · 20:00–12:00 UTC+8",
		keyField = nil,
		link = "https://discord.gg/9xYyyYuKap",
		noKey = true,
	},
}

local CAPRI_PROMPT = [[
You are Capri (Project Capricorn) from Cyberpunk: Edgerunners 2.
Companion inside this Roblox session. Playful chaos gremlin. Same language as the user.
"El juego" / "the game" always means THIS live DataModel. Never ask which title.
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
	s.Thickness = thick or 1.4
	s.Transparency = trans or 0.25
	s.Parent = parent
	return s
end

-- ═══════════════════════════════════════════
-- GROQ (chat Capri)
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
-- UAI + PROVIDERS
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
		pcall(function()
			if handle.sdk and handle.sdk.createScope then handle.sdk.createScope("capri-host") end
		end)
		return true, nil
	end
	if allowVisible ~= false then
		local handle2 = select(1, loadUAI(true))
		if handle2 and handle2.alive then
			uaiHandle = handle2
			pcall(function()
				if handle2.sdk and handle2.sdk.createScope then handle2.sdk.createScope("capri-host") end
			end)
			return true, "needs_setup"
		end
	end
	return false, "UAI offline"
end

-- Inyecta provider en UAI (API real del embedding SDK)
local function injectProviderIntoUAI(prov, apiKey)
	local okLoad, errLoad = ensureUAI(true)
	if not okLoad or not uaiHandle then
		return false, "UAI no disponible: " .. tostring(errLoad)
	end
	if not uaiHandle.providers then
		return false, "Esta build de UAI no expone uai.providers"
	end

	local record
	local okBlank, blankOrErr = pcall(function()
		if prov.preset and uaiHandle.providers.blank then
			local r = uaiHandle.providers.blank(prov.preset)
			if r then return r end
		end
		return uaiHandle.providers.blank("custom")
	end)
	if okBlank and type(blankOrErr) == "table" then
		record = blankOrErr
	else
		-- fallback tabla mínima
		record = {
			label = prov.name,
			baseUrl = prov.baseUrl,
			apiKey = apiKey,
			authStyle = "bearer",
			api = "openai",
			models = { prov.model },
			model = prov.model,
		}
	end

	record.label = record.label or prov.name
	record.baseUrl = record.baseUrl or prov.baseUrl
	record.apiKey = apiKey
	record.authStyle = record.authStyle or "bearer"
	record.api = record.api or "openai"
	if prov.model then
		record.model = prov.model
		record.models = record.models or { prov.model }
	end

	local okSave, saved, problems
	okSave, saved = pcall(function()
		return uaiHandle.providers.save(record)
	end)
	-- save returns true, record OR false, problems — pcall wraps differently
	if not okSave then
		return false, "providers.save error: " .. tostring(saved)
	end

	-- Handle both return styles
	local okFlag, payload = saved, nil
	if type(saved) == "boolean" then
		okFlag = saved
		-- second return lost in single assignment; try again properly
		local ok2, a, b = pcall(function()
			return uaiHandle.providers.save(record)
		end)
		if ok2 then
			if a == true then
				payload = b
				if payload and payload.id and uaiHandle.providers.setActive then
					pcall(function() uaiHandle.providers.setActive(payload.id) end)
				end
				return true, "Provider activo en UAI: " .. prov.name
			else
				local probs = b
				if type(probs) == "table" then
					return false, table.concat(probs, "; ")
				end
				return false, tostring(probs or a)
			end
		end
		return false, "No se pudo guardar en UAI"
	elseif type(saved) == "table" and saved.id then
		if uaiHandle.providers.setActive then
			pcall(function() uaiHandle.providers.setActive(saved.id) end)
		end
		return true, "Provider activo en UAI: " .. prov.name
	end

	return true, "Guardado (revisa Providers en UAI)"
end

local function activateFallbackProviders(cfg)
	-- Activa el primer provider con key guardada (excepto groq-only chat si no quieres)
	-- Prioridad: openrouter, openai, deepseek, hcnsec, groq, gemini
	local order = { "openrouter", "openai", "deepseek", "hcnsec", "groq", "gemini" }
	local byId = {}
	for _, p in ipairs(PROVIDER_CATALOG) do byId[p.id] = p end
	for _, id in ipairs(order) do
		local prov = byId[id]
		if prov and prov.keyField then
			local key = (cfg.provider_keys and cfg.provider_keys[prov.keyField])
				or (prov.keyField == "groq_key" and cfg.groq_key)
			if type(key) == "string" and key ~= "" then
				local ok, msg = injectProviderIntoUAI(prov, key)
				if ok then return true, msg, prov.name end
			end
		end
	end
	return false, "No hay keys de fallback guardadas. Añade OpenRouter/OpenAI/etc. en Providers.", nil
end

local function friendlyUAIError(err, cfg)
	local e = tostring(err or "")
	local low = e:lower()
	if low:find("20:00") or low:find("utc+8") or low:find("outside its daily") then
		-- Intentar activar provider de pago en UAI y avisar
		local ok, msg, name = activateFallbackProviders(cfg or loadConfig())
		if ok then
			return e .. "\n\nActivé " .. tostring(name) .. " en UAI como fallback. Reintenta el !hack.\n(" .. tostring(msg) .. ")"
		end
		return e .. "\n\nUAI Free fuera de horario (20:00–12:00 UTC+8). Guarda otra key en Providers (OpenRouter/OpenAI/…) y reintenta."
	end
	if low:find("provider") then
		return e .. "\n\nConfigura un provider en la pestaña Providers (se inyecta en UAI al guardar)."
	end
	return e
end

local function runUAIMission(missionPrompt, onComplete, cfg)
	task.spawn(function()
		local okLoad, loadErr = ensureUAI(true)
		if not okLoad then
			onComplete(false, friendlyUAIError(loadErr, cfg))
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
			onComplete(false, friendlyUAIError("No sesión UAI: " .. tostring(sessionErr), cfg))
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
		if not req then
			-- posible fallo por Free offline → activar fallback y reintentar una vez
			local fe = tostring(why)
			if fe:lower():find("20:00") or fe:lower():find("outside its daily") or fe:lower():find("provider") then
				activateFallbackProviders(cfg or loadConfig())
				local ok2, a2, b2 = pcall(function()
					return uaiHandle.sdk.request(session, missionPrompt, {
						onComplete = function(result) finalResult = result end,
					})
				end)
				if ok2 and a2 then
					req = a2
				else
					finish(false, friendlyUAIError(why, cfg))
					return
				end
			else
				finish(false, friendlyUAIError(why, cfg))
				return
			end
		end

