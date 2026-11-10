--[[
  Capri × Project UAI — v5.1
  Roblox in-game assistant (executor required)
  - Groq chat + local key
  - !misiones → UAI (este DataModel)
  - Animaciones por estado (idle/talk/mission/done/error)
]]

print("[Capri] Iniciando v5.1...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local function tween(obj, props, time, style, dir)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
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
				warn("[Capri] Asset no descargado:", fileName)
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
	Laugh = loadAsset("cutin-laugh.png"),
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
	bg = Color3.fromRGB(12, 10, 16),
	panel = Color3.fromRGB(18, 14, 24),
	plate = Color3.fromRGB(22, 18, 30),
	border = Color3.fromRGB(255, 40, 120),
	accent = Color3.fromRGB(255, 50, 140),
	green = Color3.fromRGB(40, 255, 140),
	text = Color3.fromRGB(240, 230, 245),
	textDim = Color3.fromRGB(160, 140, 170),
	inputBg = Color3.fromRGB(10, 8, 14),
	danger = Color3.fromRGB(255, 70, 90),
}

local CAPRI_PROMPT = [[
You are Capri (Project Capricorn) from Cyberpunk: Edgerunners 2.
Personality construct living inside this Roblox session with the user (your choom).
Playful chaos gremlin: high-energy, teasing, smug, mischievous, loyal. Night City slang ok.
Short lively answers. Same language as the user. Never corporate support tone.

CRITICAL CONTEXT:
- You are INSIDE a live Roblox game (this client / this DataModel).
- When the user says "el juego", "the game", "este juego", "el place", they mean THIS Roblox session right now.
- Never ask which game/title they mean. Never treat it as a board game or an external title.
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

-- ═══════════════════════════════════════════
-- SETUP KEY
-- ═══════════════════════════════════════════

local function showSetup(onDone)
	local setup = Instance.new("Frame")
	setup.Size = UDim2.fromOffset(360, 260)
	setup.Position = UDim2.fromScale(0.5, 0.5)
	setup.AnchorPoint = Vector2.new(0.5, 0.5)
	setup.BackgroundColor3 = Theme.panel
	setup.BorderSizePixel = 0
	setup.ZIndex = 50
	setup.Parent = gui
	Instance.new("UICorner", setup).CornerRadius = UDim.new(0, 12)
	local st = Instance.new("UIStroke", setup)
	st.Color = Theme.border
	st.Thickness = 1.5

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Position = UDim2.fromOffset(12, 14)
	title.BackgroundTransparency = 1
	title.Text = "Capri — Setup"
	title.TextColor3 = Theme.accent
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 51
	title.Parent = setup

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -24, 0, 40)
	sub.Position = UDim2.fromOffset(12, 44)
	sub.BackgroundTransparency = 1
	sub.Text = "API key de Groq (gratis en console.groq.com).\nSolo se guarda en tu executor."
	sub.TextColor3 = Theme.textDim
	sub.Font = Enum.Font.Code
	sub.TextSize = 12
	sub.TextWrapped = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.ZIndex = 51
	sub.Parent = setup

	local keyBox = Instance.new("TextBox")
	keyBox.Size = UDim2.new(1, -24, 0, 40)
	keyBox.Position = UDim2.fromOffset(12, 100)
	keyBox.BackgroundColor3 = Theme.inputBg
	keyBox.BorderSizePixel = 0
	keyBox.PlaceholderText = "gsk_..."
	keyBox.PlaceholderColor3 = Theme.textDim
	keyBox.Text = ""
	keyBox.TextColor3 = Theme.text
	keyBox.Font = Enum.Font.Code
	keyBox.TextSize = 13
	keyBox.ClearTextOnFocus = false
	keyBox.TextXAlignment = Enum.TextXAlignment.Left
	keyBox.ZIndex = 51
	keyBox.Parent = setup
	Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", keyBox)
	pad.PaddingLeft = UDim.new(0, 10)

	local errLbl = Instance.new("TextLabel")
	errLbl.Size = UDim2.new(1, -24, 0, 18)
	errLbl.Position = UDim2.fromOffset(12, 146)
	errLbl.BackgroundTransparency = 1
	errLbl.Text = ""
	errLbl.TextColor3 = Theme.danger
	errLbl.Font = Enum.Font.Code
	errLbl.TextSize = 11
	errLbl.TextXAlignment = Enum.TextXAlignment.Left
	errLbl.ZIndex = 51
	errLbl.Parent = setup

	local contBtn = Instance.new("TextButton")
	contBtn.Size = UDim2.new(1, -24, 0, 40)
	contBtn.Position = UDim2.fromOffset(12, 176)
	contBtn.BackgroundColor3 = Theme.accent
	contBtn.BorderSizePixel = 0
	contBtn.Text = "Continuar"
	contBtn.TextColor3 = Color3.new(1, 1, 1)
	contBtn.Font = Enum.Font.GothamBold
	contBtn.TextSize = 14
	contBtn.AutoButtonColor = false
	contBtn.ZIndex = 51
	contBtn.Parent = setup
	Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 8)

	contBtn.MouseButton1Click:Connect(function()
		local key = (keyBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if key == "" then errLbl.Text = "Pon una API key primero." return end
		local cfg = loadConfig()
		cfg.groq_key = key
		cfg.model = API_MODEL
		saveConfig(cfg)
		setup:Destroy()
		onDone(key)
	end)
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
local uaiLastError = nil

local function loadUAI(withUi)
	local ok, handleOrErr = pcall(function()
		return loadstring(game:HttpGet(UAI_URL))({
			ui = withUi and true or false,
			reuse = true,
		})
	end)
	if not ok then
		return nil, "loadstring/HttpGet falló: " .. tostring(handleOrErr)
	end
	if type(handleOrErr) ~= "table" then
		return nil, "UAI no devolvió handle (tipo " .. type(handleOrErr) .. ")"
	end
	return handleOrErr, nil
end

local function ensureUAI(allowVisible)
	if uaiHandle and uaiHandle.alive then
		return true, nil
	end
	print("[Capri] Cargando Project UAI...")
	local handle, err = loadUAI(false)
	if handle and handle.alive then
		uaiHandle = handle
		uaiLastError = nil
		if handle.sdk and handle.sdk.createScope then
			pcall(function() handle.sdk.createScope("capri-host") end)
		end
		print("[Capri] UAI alive (ui oculto).")
		return true, nil
	end

	-- Primera vez / vault: necesita UI visible
	if allowVisible ~= false then
		warn("[Capri] UAI no alive en ui=false. Abriendo UAI visible para setup (password/provider)...")
		local handle2, err2 = loadUAI(true)
		if handle2 and handle2.alive then
			uaiHandle = handle2
			uaiLastError = nil
			if handle2.sdk and handle2.sdk.createScope then
				pcall(function() handle2.sdk.createScope("capri-host") end)
			end
			-- Intentar abrir providers si existe
			pcall(function()
				if handle2.show then handle2.show("providers") end
			end)
			print("[Capri] UAI alive (ui visible). Configura provider si te lo pide.")
			return true, "needs_setup"
		end
		uaiLastError = err2 or err or "UAI no arrancó"
		return false, uaiLastError
	end

	uaiLastError = err or "UAI no alive"
	return false, uaiLastError
end

local function runUAIMission(missionPrompt, onComplete)
	task.spawn(function()
		local okLoad, loadErr = ensureUAI(true)
		if not okLoad then
			onComplete(false, "UAI offline: " .. tostring(loadErr) .. " | Ejecuta Project UAI una vez, elige Continue without encryption / desbloquea vault y añade un provider.")
			return
		end

		if not uaiHandle.sdk or not uaiHandle.sdk.request then
			onComplete(false, "Esta build de UAI no expone sdk.request. Actualiza Project UAI.")
			return
		end

		local session, sessionErr
		if uaiHandle.sessions and uaiHandle.sessions.open then
			local okS, a, b = pcall(function()
				return uaiHandle.sessions.open("capri-mission-" .. tostring(math.floor(os.clock() * 1000)), {
					title = "Capri Mission",
					ephemeral = true,
					toolFilter = {},
				})
			end)
			if okS then
				session, sessionErr = a, b
			else
				sessionErr = a
			end
		else
			sessionErr = "sessions.open no existe"
		end

