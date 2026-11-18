--[[
  App.lua
  Que: orquesta modulos JARVIS (Theme, Visual, UI_Chat, UAIBridge, Hack, Explorer).
]]

local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local App = {}

local JARVIS_PROMPT = [[
You are J.A.R.V.I.S., an advanced systems assistant inside this Roblox session.
Calm, precise, slightly witty. Same language as the user.
"El juego" / "the game" = THIS live DataModel. Never ask which title.
]]

local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "openai/gpt-oss-20b"

local function httpRequest(opts)
	local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
	if req then
		local ok, res = pcall(req, opts)
		if ok and res then
			return res
		end
	end
	if opts.Method == "GET" or not opts.Method then
		local ok, body = pcall(function()
			return game:HttpGet(opts.Url)
		end)
		if ok and body then
			local r = {}
			r.StatusCode = 200
			r.Body = body
			return r
		end
	end
	return nil
end

local function groqChat(apiKey, messages, maxTokens)
	local payload = {}
	payload.model = API_MODEL
	payload.messages = messages
	payload.temperature = 0.85
	payload.max_tokens = maxTokens or 500
	local body = HttpService:JSONEncode(payload)
	local headers = {}
	headers["Content-Type"] = "application/json"
	headers["Authorization"] = "Bearer " .. apiKey
	local opts = {}
	opts.Url = API_URL
	opts.Method = "POST"
	opts.Headers = headers
	opts.Body = body
	local res = httpRequest(opts)
	if not res or not res.Body then
		return nil, "http_fail"
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(res.Body)
	end)
	if not ok or not data then
		return nil, "json_fail"
	end
	if data.error then
		return nil, tostring(data.error.message or data.error)
	end
	local c = data.choices and data.choices[1]
	local content = c and c.message and c.message.content
	if content and content ~= "" then
		return content, nil
	end
	return nil, "empty"
end

function App.start(modules, apiKey)
	local Config = modules.Config
	local Theme = modules.Theme
	local Assets = modules.Assets
	local Visual = modules.Visual
	local UI_Chat = modules.UI_Chat
	local UAIBridge = modules.UAIBridge
	local Hack = modules.Hack
	local Explorer = modules.Explorer

	pcall(function()
		for _, name in ipairs({ "JarvisHUD", "CapriUAI" }) do
			local old = CoreGui:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "JarvisHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	Assets.preload()
	local cfg = Config.ensureDefaults(Config.load())
	if type(cfg.groq_key) ~= "string" or cfg.groq_key == "" then
		cfg.groq_key = apiKey
	end
	Config.save(cfg)

	local visual = Visual.new(gui, Assets, Theme)
	local ui
	local hack

	local uiOpts = {}
	uiOpts.gui = gui
	uiOpts.Theme = Theme
	uiOpts.Assets = Assets
	uiOpts.Config = Config
	uiOpts.cfg = cfg
	uiOpts.UAI = UAIBridge
	uiOpts.Visual = visual
	uiOpts.apiKey = apiKey
	uiOpts.onSend = function(text)
		text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" then
			return
		end
		ui.inputBox.Text = ""
		if ui.activeTab ~= "chats" then
			ui:setTab("chats")
		end
		ui:addBubble("user", text)
		task.spawn(function()
			if hack.mode == "clarifying" then
				hack:clarify(text)
				return
			end
			if hack.mode == "idle" and text:sub(1, 1) == "!" and not hack.running then
				local clean = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
				if clean == "" then
					ui:addBubble("assistant", "Indica el trabajo tras '!'. Ej: !analiza el juego")
					return
				end
				hack:begin(clean)
				return
			end
			ui:setStatus(hack.running and "sistema + charla" or "pensando...")
			visual:setExpression("talking")
			local ch = ui:getActiveChat()
			local msgs = {}
			local sys = {}
			sys.role = "system"
			sys.content = JARVIS_PROMPT
			table.insert(msgs, sys)
			for _, m in ipairs(ch.messages or {}) do
				if m.role == "user" or m.role == "assistant" then
					local mm = {}
					mm.role = m.role
					mm.content = m.content
					table.insert(msgs, mm)
				end
			end
			local reply, err = groqChat(ui.API_KEY or apiKey, msgs, 450)
			if not reply then
				ui:addBubble("assistant", "Fallo la IA (" .. tostring(err) .. ").")
				visual:setExpression("error")
				ui:setStatus("error")
			else
				ui:addBubble("assistant", reply)
				visual:setExpression(hack.running and "hack" or "idle")
				ui:setStatus(hack.running and "en el sistema" or "chat")
			end
		end)
	end

	ui = UI_Chat.new(uiOpts)

	if Explorer and type(Explorer.render) == "function" then
		function ui:buildFiles()
			Explorer.render(self.filesPane, self.Theme, self.UAI)
		end
	end

	local hackOpts = {}
	hackOpts.gui = gui
	hackOpts.Theme = Theme
	hackOpts.UAI = UAIBridge
	hackOpts.cfg = cfg
	hackOpts.ui = ui
	hackOpts.visual = visual
	hackOpts.apiKey = apiKey
	hackOpts.groqChat = groqChat
	hackOpts.capriPrompt = JARVIS_PROMPT
	hack = Hack.new(hackOpts)

	visual.onClick = function()
		ui:toggle()
	end
	visual:setExpression("idle")

	task.spawn(function()
		local ok = UAIBridge.ensure(false)
		print(ok and "[JARVIS] UAI preload OK" or "[JARVIS] UAI bajo demanda")
	end)

	print("[JARVIS] Sistemas en linea.")
end

function App.boot(modules)
	local Config = modules.Config
	local Theme = modules.Theme
	local cfg = Config.load()
	local key = cfg.groq_key
	if type(key) == "string" and key ~= "" then
		print("[JARVIS] Key local OK.")
		App.start(modules, key)
		return
	end

	pcall(function()
		for _, name in ipairs({ "JarvisHUD", "CapriUAI" }) do
			local old = CoreGui:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "JarvisHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.IgnoreGuiInset = true
	gui.Parent = CoreGui

	local setup = Instance.new("Frame")
	setup.Size = UDim2.fromOffset(360, 220)
	setup.Position = UDim2.fromScale(0.5, 0.5)
	setup.AnchorPoint = Vector2.new(0.5, 0.5)
	setup.BackgroundColor3 = Theme.panel
	setup.BackgroundTransparency = 0.1
	setup.ZIndex = 60
	setup.Parent = gui
	Theme.mkCorner(setup, 12)
	Theme.mkStroke(setup, Theme.chatGreen, 1.5, 0.2)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -24, 0, 28)
	t.Position = UDim2.fromOffset(12, 14)
	t.BackgroundTransparency = 1
	t.Text = "J.A.R.V.I.S. - Groq key"
	t.TextColor3 = Theme.accent
	t.Font = Enum.Font.GothamBold
	t.TextSize = 18
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ZIndex = 61
	t.Parent = setup

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -24, 0, 40)
	box.Position = UDim2.fromOffset(12, 70)
	box.BackgroundColor3 = Theme.inputBg
	box.PlaceholderText = "gsk_..."
	box.Text = ""
	box.TextColor3 = Theme.text
	box.Font = Enum.Font.Code
	box.TextSize = 13
	box.ZIndex = 61
	box.Parent = setup
	Theme.mkCorner(box, 8)

	local go = Instance.new("TextButton")
	go.Size = UDim2.new(1, -24, 0, 40)
	go.Position = UDim2.fromOffset(12, 130)
	go.BackgroundColor3 = Theme.accent
	go.Text = "Continuar"
	go.TextColor3 = Color3.new(1, 1, 1)
	go.Font = Enum.Font.GothamBold
	go.TextSize = 14
	go.ZIndex = 61
	go.Parent = setup
	Theme.mkCorner(go, 8)
	go.MouseButton1Click:Connect(function()
		local k = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if k == "" then
			return
		end
		local c = Config.load()
		c.groq_key = k
		Config.save(c)
		setup:Destroy()
		gui:Destroy()
		App.start(modules, k)
	end)
end

return App
