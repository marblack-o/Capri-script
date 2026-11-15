--[[
  Hack.lua
  Qué: ventana de trabajo UAI (arrastrable + ✕) y armado del prompt de misión.
  Por qué: separar el flujo !hack del chat libre; esperar await completo del agente.
]]

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Hack = {}
Hack.__index = Hack

local function makeDraggable(frame, handle)
	local dragging, start, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, start, startPos = true, input.Position, frame.Position
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

function Hack.new(opts)
	local self = setmetatable({}, Hack)
	self.gui = opts.gui
	self.Theme = opts.Theme
	self.UAI = opts.UAI
	self.cfg = opts.cfg
	self.ui = opts.ui
	self.visual = opts.visual
	self.apiKey = opts.apiKey
	self.groqChat = opts.groqChat
	self.capriPrompt = opts.capriPrompt
	self.running = false
	self.mode = "idle"
	self.clarifyCount = 0
	self.brief = { original = "", answers = {}, kind = "action" }
	self.MAX_CLARIFY = 4
	self:_build()
	return self
end

function Hack:_build()
	local Theme = self.Theme
	local win = Instance.new("Frame")
	win.Size = UDim2.fromOffset(340, 220)
	win.Position = UDim2.new(1, -360, 1, -240)
	win.BackgroundColor3 = Theme.panel
	win.BackgroundTransparency = 0.1
	win.Visible = false
	win.ZIndex = 40
	win.Parent = self.gui
	Theme.mkCorner(win, 10)
	Theme.mkStroke(win, Theme.uaiYellow, 2, 0.1)
	self.win = win

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 32)
	bar.BackgroundColor3 = Theme.sidebar
	bar.BackgroundTransparency = 0.15
	bar.ZIndex = 41
	bar.Parent = win
	Theme.mkCorner(bar, 10)
	makeDraggable(win, bar)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 1, 0)
	title.Position = UDim2.fromOffset(10, 0)
	title.BackgroundTransparency = 1
	title.Text = "Capri · Hack"
	title.TextColor3 = Theme.uaiYellow
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 42
	title.Parent = bar
	self.title = title

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(28, 24)
	close.Position = UDim2.new(1, -32, 0.5, -12)
	close.BackgroundColor3 = Theme.bg
	close.Text = "✕"
	close.TextColor3 = Theme.textDim
	close.Font = Enum.Font.GothamBold
	close.TextSize = 13
	close.AutoButtonColor = false
	close.ZIndex = 43
	close.Parent = bar
	Theme.mkCorner(close, 5)
	close.MouseButton1Click:Connect(function() win.Visible = false end)

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -20, 0, 18)
	status.Position = UDim2.fromOffset(10, 38)
	status.BackgroundTransparency = 1
	status.Text = "en cola"
	status.TextColor3 = Theme.textDim
	status.Font = Enum.Font.Code
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 41
	status.Parent = win
	self.status = status

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 1, -66)
	body.Position = UDim2.fromOffset(10, 58)
	body.BackgroundTransparency = 1
	body.Text = ""
	body.TextColor3 = Theme.text
	body.Font = Enum.Font.Code
	body.TextSize = 12
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.ZIndex = 41
	body.Parent = win
	self.body = body
end

function Hack.detectKind(text)
	local l = string.lower(text)
	if l:find("investiga") or l:find("busca") or l:find("analiza") or l:find("explora")
		or l:find("lista") or l:find("scan") then
		return "research"
	end
	return "action"
end

function Hack.isClear(text)
	local l = string.lower(text)
	local about = l:find("el juego") or l:find("este juego") or l:find("the game")
		or l:find("workspace") or l:find("scripts")
	local verb = l:find("analiza") or l:find("explora") or l:find("lista") or l:find("crea")
		or l:find("haz") or l:find("hack")
	if verb and about then return true end
	if #l < 48 and (l:find("analiza") or l:find("explora")) then return true end
	return false
end

function Hack.buildPrompt(brief)
	local placeName = "unknown"
	pcall(function()
		placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	local lines = {
		"JOB FROM CAPRI (Roblox executor host)",
		"Live DataModel only. PlaceId=" .. tostring(game.PlaceId) .. " name=" .. tostring(placeName),
		"User request: " .. brief.original,
		"Job type: " .. brief.kind,
		"COMPLETION: Finish FULL work with tools before final answer.",
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
	local l = string.lower(brief.original)
	if l:find("panel") or l:find("ui") or l:find("gui") then
		table.insert(lines, "UI SPEC: ScreenGui ResetOnSpawn=false; dark purple; pink/yellow accent; close btn.")
	end
	table.insert(lines, "Never ask which game.")
	return table.concat(lines, "\n")
end

function Hack:open(title)
	self.win.Visible = true
	self.title.Text = "Capri · " .. (title or "Hack")
	self.status.Text = "trabajando…"
	self.body.Text = "Esperando turno completo de UAI…"
end

function Hack:start()
	self.running = true
	self.mode = "hack"
	self.ui:setStatus("hackeando · espera…")
	self.visual:setExpression("hack")
	self.ui:setBorderMode("uai")
	self:open(string.sub(self.brief.original, 1, 40))
	self.ui:addBubble("assistant", "Me meto al sistema. Ventana de hack: arrastra o ✕.")

	local prompt = Hack.buildPrompt(self.brief)
	local kind = self.brief.kind
	print("[Capri] Hack:\n" .. prompt)

	self.UAI.runMission(prompt, function(ok, resultText)
		self.running = false
		self.mode = "idle"
		self.clarifyCount = 0
		self.brief = { original = "", answers = {}, kind = "action" }
		if not ok then
			self.ui:setStatus("hack fallido")
			self.visual:setExpression("error")
			self.status.Text = "falló"
			self.body.Text = tostring(resultText)
			self.ui:addBubble("assistant", "El hack se torció:\n" .. tostring(resultText))
			self.ui:setBorderMode("chat")
			return
		end
		self.status.Text = "listo"
		if kind == "research" then
			self.ui:setStatus("traduciendo…")
			self.visual:setExpression("talking")
			local rewritten = select(1, self.groqChat(self.apiKey, {
				{ role = "system", content = self.capriPrompt .. "\nRetell report in Capri voice. Concise." },
				{ role = "user", content = tostring(resultText) },
			}, 700))
			self.ui:setStatus("chat")
			self.visual:setExpression("done")
			local out = rewritten or tostring(resultText)
			self.body.Text = out
			self.ui:addBubble("assistant", out)
		else
			self.ui:setStatus("chat")
			self.visual:setExpression("done")
			self.body.Text = tostring(resultText)
			self.ui:addBubble("assistant", "Trabajo listo, choom.\n" .. tostring(resultText))
		end
		self.ui:setBorderMode("chat")
	end, self.cfg)
end

function Hack:begin(cleanText)
	self.brief = { original = cleanText, answers = {}, kind = Hack.detectKind(cleanText) }
	self.clarifyCount = 0
	if Hack.isClear(cleanText) then
		self:start()
		return
	end
	self.mode = "clarifying"
	self.ui:setStatus("afinando el hack")
	self.visual:setExpression("talking")
	local reply = select(1, self.groqChat(self.apiKey, {
		{ role = "system", content = self.capriPrompt .. "\n!hack in THIS Roblox game. ONE question max. Never ask which game. If clear: READY_FOR_HACK" },
		{ role = "user", content = cleanText },
	}, 220))
	if not reply or reply:find("READY_FOR_HACK") or Hack.isClear(cleanText) then
		if reply then
			local s = reply:gsub("READY_FOR_HACK", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if s ~= "" and not Hack.isClear(cleanText) then self.ui:addBubble("assistant", s) end
		end
		self:start()
	else
		self.clarifyCount = 1
		self.ui:addBubble("assistant", reply)
		self.visual:setExpression("idle")
	end
end

function Hack:clarify(userText)
	table.insert(self.brief.answers, userText)
	self.clarifyCount = self.clarifyCount + 1
	local reply = select(1, self.groqChat(self.apiKey, {
		{ role = "system", content = self.capriPrompt .. "\nClarifying hack THIS game. READY_FOR_HACK if enough." },
		{ role = "user", content = "Original: " .. self.brief.original .. "\nAnswer: " .. userText },
	}, 220))
	if not reply or reply:find("READY_FOR_HACK") or self.clarifyCount >= self.MAX_CLARIFY then
		self:start()
	else
		self.ui:addBubble("assistant", reply)
		self.visual:setExpression("idle")
		self.ui:setStatus("afinando el hack (" .. self.clarifyCount .. "/" .. self.MAX_CLARIFY .. ")")
	end
end

return Hack
