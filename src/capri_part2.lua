		local WAIT_SEC = 300
		if type(req.await) == "function" then
			local okW, result, waitErr = pcall(function() return req.await(WAIT_SEC) end)
			if not okW then finish(false, "await: " .. tostring(result)) return end
			if result == nil then
				local leftover = req.result or finalResult
				if leftover and leftover.ok then
					finish(true, leftover.text or leftover.output or "Hack listo.")
				else
					local errMsg = tostring(waitErr or (leftover and leftover.error) or "Timeout UAI")
					-- si falló por horario, intentar fallback
					if errMsg:lower():find("outside its daily") or errMsg:lower():find("20:00") then
						finish(false, friendlyUAIError(errMsg, cfg))
					else
						finish(false, friendlyUAIError(errMsg, cfg))
					end
				end
				return
			end
			if type(result) == "table" then
				if result.ok then
					finish(true, result.text or result.output or result.message or "Hack listo.")
				else
					local errMsg = tostring(result.error or result.message or "UAI falló")
					if errMsg:lower():find("outside its daily") or errMsg:lower():find("20:00") then
						local okF = activateFallbackProviders(cfg or loadConfig())
						if okF then
							finish(false, friendlyUAIError(errMsg, cfg) .. "\n\nFallback activado — manda el !hack otra vez.")
						else
							finish(false, friendlyUAIError(errMsg, cfg))
						end
					else
						finish(false, friendlyUAIError(errMsg, cfg))
					end
				end
				return
			end
		end

		local t0 = os.clock()
		while not settled and (os.clock() - t0) < WAIT_SEC do
			local r = (req and req.result) or finalResult
			if type(r) == "table" and (r.ok == true or r.ok == false or r.text or r.error) then
				if r.ok then finish(true, r.text or r.output or "Hack listo.")
				else finish(false, friendlyUAIError(r.error or r.message, cfg)) end
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
	if needsUiSpec(brief.original) then
		table.insert(lines, "UI SPEC: ScreenGui ResetOnSpawn=false; dark purple panel; pink/yellow accent; close btn; working buttons.")
	end
	table.insert(lines, "Never ask which game.")
	return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════
-- MAIN UI
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
	local cfg = loadConfig()
	cfg.provider_keys = type(cfg.provider_keys) == "table" and cfg.provider_keys or {}
	cfg.chats = type(cfg.chats) == "table" and cfg.chats or {}
	if #cfg.chats == 0 then
		cfg.chats = { { id = HttpService:GenerateGUID(false), title = "General", messages = {} } }
	end
	cfg.active_chat = cfg.active_chat or cfg.chats[1].id
	if type(cfg.groq_key) ~= "string" or cfg.groq_key == "" then cfg.groq_key = API_KEY end
	saveConfig(cfg)

	local mode = "idle"
	local clarifyCount = 0
	local hackBrief = { original = "", answers = {}, kind = "action" }
	local busy = false
	local hackRunning = false
	local exprState = "idle"
	local animToken = 0
	local sessionGreeted = false
	local activeTab = "chats"

	local function getActiveChat()
		for _, ch in ipairs(cfg.chats) do
			if ch.id == cfg.active_chat then return ch end
		end
		return cfg.chats[1]
	end
	local function persist() saveConfig(cfg) end

	-- ── SPRITE: cuerpo + cara ──
	local spriteRoot = Instance.new("ImageButton")
	spriteRoot.Name = "CapriSprite"
	spriteRoot.Size = UDim2.fromOffset(110, 130)
	spriteRoot.Position = UDim2.new(1, -120, 0.4, 0)
	spriteRoot.BackgroundTransparency = 1
	spriteRoot.BorderSizePixel = 0
	spriteRoot.Image = "" -- el cuerpo va en child
	spriteRoot.AutoButtonColor = false
	spriteRoot.ZIndex = 10
	spriteRoot.Parent = gui

	local bodyImg = Instance.new("ImageLabel")
	bodyImg.Name = "Body"
	bodyImg.Size = UDim2.fromScale(1, 1)
	bodyImg.BackgroundTransparency = 1
	bodyImg.Image = pickImage("Full", "Cutout", "Face")
	bodyImg.ScaleType = Enum.ScaleType.Fit
	bodyImg.ZIndex = 10
	bodyImg.Parent = spriteRoot

	local faceImg = Instance.new("ImageLabel")
	faceImg.Name = "Face"
	faceImg.Size = UDim2.new(0.55, 0, 0.42, 0)
	faceImg.Position = UDim2.new(0.22, 0, 0.02, 0)
	faceImg.BackgroundTransparency = 1
	faceImg.Image = pickImage("FaceCalm", "FaceLook", "Face")
	faceImg.ScaleType = Enum.ScaleType.Fit
	faceImg.ZIndex = 11
	faceImg.Parent = spriteRoot

	local spriteFallback = Instance.new("TextLabel")
	spriteFallback.Size = UDim2.fromScale(1, 1)
	spriteFallback.BackgroundTransparency = 1
	spriteFallback.Text = (bodyImg.Image == "" and faceImg.Image == "") and "C" or ""
	spriteFallback.TextColor3 = Theme.accent
	spriteFallback.Font = Enum.Font.GothamBlack
	spriteFallback.TextSize = 32
	spriteFallback.ZIndex = 12
	spriteFallback.Parent = spriteRoot

	local spriteStroke = mkStroke(spriteRoot, Theme.chatGreen, 0, 1) -- invisible por defecto

	local dragging, dragMoved, dragStart, startPos = false, false, nil, nil
	local baseY = spriteRoot.Position.Y.Offset
	RunService.RenderStepped:Connect(function()
		if dragging then return end
		local wave = math.sin(os.clock() * 1.35) * 3.2
		local pos = spriteRoot.Position
		spriteRoot.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, baseY + wave)
	end)
	spriteRoot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragMoved, dragStart, startPos = true, false, input.Position, spriteRoot.Position
			baseY = startPos.Y.Offset
		end
	end)
	spriteRoot.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			baseY = spriteRoot.Position.Y.Offset
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then dragMoved = true end
			spriteRoot.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			baseY = spriteRoot.Position.Y.Offset
		end
	end)

	-- ── MAIN WINDOW ──
	local WIN_W, WIN_H = 720, 440
	local window = Instance.new("Frame")
	window.Name = "CapriWorkbench"
	window.Size = UDim2.fromOffset(WIN_W, WIN_H)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = Theme.panel
	window.BackgroundTransparency = 0.22 -- semitransparente
	window.BorderSizePixel = 0
	window.Visible = false
	window.ZIndex = 20
	window.Parent = gui
	mkCorner(window, 14)
	local windowStroke = mkStroke(window, Theme.chatGreen, 2, 0.15)

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Theme.sidebar
	titleBar.BackgroundTransparency = 0.25
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 21
	titleBar.Parent = window
	mkCorner(titleBar, 14)
	makeDraggable(window, titleBar)

	local titleFace = Instance.new("ImageLabel")
	titleFace.Size = UDim2.fromOffset(28, 28)
	titleFace.Position = UDim2.fromOffset(12, 6)
	titleFace.BackgroundTransparency = 1
	titleFace.Image = pickImage("FaceCalm", "Face")
	titleFace.ScaleType = Enum.ScaleType.Crop
	titleFace.ZIndex = 22
	titleFace.Parent = titleBar
	mkCorner(titleFace, 8)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.45, 0, 1, 0)
	titleLbl.Position = UDim2.fromOffset(48, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Capri"
	titleLbl.TextColor3 = Theme.accent
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 22
	titleLbl.Parent = titleBar

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.4, -80, 1, 0)
	statusLbl.Position = UDim2.new(0.42, 0, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "chat"
	statusLbl.TextColor3 = Theme.textDim
	statusLbl.Font = Enum.Font.Code
	statusLbl.TextSize = 12
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	statusLbl.ZIndex = 22
	statusLbl.Parent = titleBar

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(32, 28)
	closeBtn.Position = UDim2.new(1, -40, 0.5, -14)
	closeBtn.BackgroundColor3 = Theme.bg
	closeBtn.BackgroundTransparency = 0.3
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Theme.textDim
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 23
	closeBtn.Parent = titleBar
	mkCorner(closeBtn, 6)

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -52)
	body.Position = UDim2.fromOffset(8, 44)
	body.BackgroundTransparency = 1
	body.ZIndex = 21
	body.Parent = window

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 180, 1, 0)
	sidebar.BackgroundColor3 = Theme.sidebar
	sidebar.BackgroundTransparency = 0.2
	sidebar.BorderSizePixel = 0
	sidebar.ZIndex = 22
	sidebar.Parent = body
	mkCorner(sidebar, 10)

	local tabChats = Instance.new("TextButton")
	tabChats.Size = UDim2.new(0.5, -6, 0, 28)
	tabChats.Position = UDim2.fromOffset(6, 8)
	tabChats.BackgroundColor3 = Theme.accent
	tabChats.Text = "Chats"
	tabChats.TextColor3 = Color3.new(1, 1, 1)
	tabChats.Font = Enum.Font.GothamBold
	tabChats.TextSize = 12
	tabChats.AutoButtonColor = false
	tabChats.ZIndex = 23
	tabChats.Parent = sidebar
	mkCorner(tabChats, 6)

	local tabProv = Instance.new("TextButton")
	tabProv.Size = UDim2.new(0.5, -6, 0, 28)
	tabProv.Position = UDim2.new(0.5, 0, 0, 8)
	tabProv.BackgroundColor3 = Theme.row
	tabProv.Text = "Providers"
	tabProv.TextColor3 = Theme.text
	tabProv.Font = Enum.Font.GothamBold
	tabProv.TextSize = 12
	tabProv.AutoButtonColor = false
	tabProv.ZIndex = 23
	tabProv.Parent = sidebar
	mkCorner(tabProv, 6)

	local sideList = Instance.new("ScrollingFrame")
	sideList.Size = UDim2.new(1, -12, 1, -80)
	sideList.Position = UDim2.fromOffset(6, 44)
	sideList.BackgroundTransparency = 1
	sideList.BorderSizePixel = 0
	sideList.ScrollBarThickness = 3
	sideList.ScrollBarImageColor3 = Theme.glitch
	sideList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sideList.CanvasSize = UDim2.new(0, 0, 0, 0)
	sideList.ZIndex = 23
	sideList.Parent = sidebar
	Instance.new("UIListLayout", sideList).Padding = UDim.new(0, 6)

	local newChatBtn = Instance.new("TextButton")
	newChatBtn.Size = UDim2.new(1, -12, 0, 28)
	newChatBtn.Position = UDim2.new(0, 6, 1, -36)
	newChatBtn.BackgroundColor3 = Theme.row
	newChatBtn.Text = "+ Nuevo chat"
	newChatBtn.TextColor3 = Theme.glitch
	newChatBtn.Font = Enum.Font.GothamBold
	newChatBtn.TextSize = 12
	newChatBtn.AutoButtonColor = false
	newChatBtn.ZIndex = 23
	newChatBtn.Parent = sidebar
	mkCorner(newChatBtn, 6)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -196, 1, 0)
	content.Position = UDim2.fromOffset(188, 0)
	content.BackgroundColor3 = Theme.plate
	content.BackgroundTransparency = 0.28
	content.BorderSizePixel = 0
	content.ZIndex = 22
	content.Parent = body
	mkCorner(content, 10)

	local msgScroll = Instance.new("ScrollingFrame")
	msgScroll.Size = UDim2.new(1, -12, 1, -56)
	msgScroll.Position = UDim2.fromOffset(6, 6)
	msgScroll.BackgroundTransparency = 1
	msgScroll.BorderSizePixel = 0
	msgScroll.ScrollBarThickness = 4
	msgScroll.ScrollBarImageColor3 = Theme.accent
	msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	msgScroll.ZIndex = 23
	msgScroll.Parent = content
	local msgLayout = Instance.new("UIListLayout", msgScroll)
	msgLayout.Padding = UDim.new(0, 8)
	msgLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local providersPane = Instance.new("ScrollingFrame")
	providersPane.Size = UDim2.new(1, -12, 1, -12)
	providersPane.Position = UDim2.fromOffset(6, 6)
	providersPane.BackgroundTransparency = 1
	providersPane.Visible = false
	providersPane.ScrollBarThickness = 4
	providersPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	providersPane.CanvasSize = UDim2.new(0, 0, 0, 0)
	providersPane.ZIndex = 23
	providersPane.Parent = content
	Instance.new("UIListLayout", providersPane).Padding = UDim.new(0, 8)

	local inputBar = Instance.new("Frame")
	inputBar.Size = UDim2.new(1, -12, 0, 40)
	inputBar.Position = UDim2.new(0, 6, 1, -48)
	inputBar.BackgroundColor3 = Theme.inputBg
	inputBar.BackgroundTransparency = 0.15
	inputBar.BorderSizePixel = 0
	inputBar.ZIndex = 24
	inputBar.Parent = content
	mkCorner(inputBar, 8)

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -90, 1, -8)
	inputBox.Position = UDim2.fromOffset(10, 4)
	inputBox.BackgroundTransparency = 1
	inputBox.PlaceholderText = "Mensaje…  |  !hack sobre este juego"
	inputBox.PlaceholderColor3 = Theme.textDim
	inputBox.Text = ""
	inputBox.TextColor3 = Theme.text
	inputBox.Font = Enum.Font.Code
	inputBox.TextSize = 13
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.ZIndex = 25
	inputBox.Parent = inputBar

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.fromOffset(72, 30)
	sendBtn.Position = UDim2.new(1, -78, 0.5, -15)
	sendBtn.BackgroundColor3 = Theme.accent
	sendBtn.Text = "Enviar"
	sendBtn.TextColor3 = Color3.new(1, 1, 1)
	sendBtn.Font = Enum.Font.GothamBold
	sendBtn.TextSize = 12
	sendBtn.AutoButtonColor = false
	sendBtn.ZIndex = 25
	sendBtn.Parent = inputBar
	mkCorner(sendBtn, 6)

	-- ── HACK WINDOW (X + drag) ──
	local hackWin = Instance.new("Frame")
	hackWin.Size = UDim2.fromOffset(340, 220)
	hackWin.Position = UDim2.new(1, -360, 1, -240)
	hackWin.BackgroundColor3 = Theme.panel
	hackWin.BackgroundTransparency = 0.12
	hackWin.BorderSizePixel = 0
	hackWin.Visible = false
	hackWin.ZIndex = 40
	hackWin.Parent = gui
	mkCorner(hackWin, 10)
	local hackStroke = mkStroke(hackWin, Theme.uaiYellow, 2, 0.1)

	local hackBar = Instance.new("Frame")
	hackBar.Size = UDim2.new(1, 0, 0, 32)
	hackBar.BackgroundColor3 = Theme.sidebar
	hackBar.BackgroundTransparency = 0.2
	hackBar.BorderSizePixel = 0
	hackBar.ZIndex = 41
	hackBar.Parent = hackWin
	mkCorner(hackBar, 10)
	makeDraggable(hackWin, hackBar)

	local hackTitle = Instance.new("TextLabel")
	hackTitle.Size = UDim2.new(1, -40, 1, 0)
	hackTitle.Position = UDim2.fromOffset(10, 0)
	hackTitle.BackgroundTransparency = 1
	hackTitle.Text = "Capri · Hack"
	hackTitle.TextColor3 = Theme.uaiYellow
	hackTitle.Font = Enum.Font.GothamBold
	hackTitle.TextSize = 13
	hackTitle.TextXAlignment = Enum.TextXAlignment.Left
	hackTitle.ZIndex = 42
	hackTitle.Parent = hackBar

	local hackClose = Instance.new("TextButton")
	hackClose.Size = UDim2.fromOffset(28, 24)
	hackClose.Position = UDim2.new(1, -32, 0.5, -12)
	hackClose.BackgroundColor3 = Theme.bg
	hackClose.Text = "✕"
	hackClose.TextColor3 = Theme.textDim
	hackClose.Font = Enum.Font.GothamBold
	hackClose.TextSize = 13
	hackClose.AutoButtonColor = false
	hackClose.ZIndex = 43
	hackClose.Parent = hackBar
	mkCorner(hackClose, 5)
	hackClose.MouseButton1Click:Connect(function()
		hackWin.Visible = false
	end)

	local hackStatus = Instance.new("TextLabel")
	hackStatus.Size = UDim2.new(1, -20, 0, 18)
	hackStatus.Position = UDim2.fromOffset(10, 38)
	hackStatus.BackgroundTransparency = 1
	hackStatus.Text = "en cola"
	hackStatus.TextColor3 = Theme.textDim
	hackStatus.Font = Enum.Font.Code
	hackStatus.TextSize = 12
	hackStatus.TextXAlignment = Enum.TextXAlignment.Left
	hackStatus.ZIndex = 41
	hackStatus.Parent = hackWin

	local hackBody = Instance.new("TextLabel")
	hackBody.Size = UDim2.new(1, -20, 1, -66)
	hackBody.Position = UDim2.fromOffset(10, 58)
	hackBody.BackgroundTransparency = 1
	hackBody.Text = ""
	hackBody.TextColor3 = Theme.text
	hackBody.Font = Enum.Font.Code
	hackBody.TextSize = 12
	hackBody.TextWrapped = true
	hackBody.TextXAlignment = Enum.TextXAlignment.Left
	hackBody.TextYAlignment = Enum.TextYAlignment.Top
	hackBody.ZIndex = 41
	hackBody.Parent = hackWin

	local function setBorderMode(modeName)
		if modeName == "uai" then
			tween(windowStroke, { Color = Theme.uaiYellow, Transparency = 0.05 }, 0.2)
		else
			tween(windowStroke, { Color = Theme.chatGreen, Transparency = 0.15 }, 0.2)
		end
	end

	local function setStatus(txt)
		statusLbl.Text = txt
		local working = txt:find("hack") or txt:find("espera") or txt:find("afinando") or txt:find("traduc")
		if working then
			titleLbl.Text = "Capri · en el sistema"
			titleLbl.TextColor3 = Theme.uaiYellow
			setBorderMode("uai")
		else
			titleLbl.Text = "Capri"
			titleLbl.TextColor3 = Theme.accent
			setBorderMode("chat")
		end
	end

	local function applyFace(keys)
		local img = pickImage(table.unpack(keys))
		if img ~= "" then
			faceImg.Image = img
			titleFace.Image = img
			spriteFallback.Text = ""
		end
		-- cuerpo estable
		if bodyImg.Image == "" then
			bodyImg.Image = pickImage("Full", "Cutout", "Face")
		end
	end

