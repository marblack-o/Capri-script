-- ═══════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
	local cfg = loadConfig()
	cfg.provider_keys = type(cfg.provider_keys) == "table" and cfg.provider_keys or {}
	cfg.chats = type(cfg.chats) == "table" and cfg.chats or {}
	if #cfg.chats == 0 then
		cfg.chats = {
			{ id = HttpService:GenerateGUID(false), title = "General", messages = {} },
		}
	end
	cfg.active_chat = cfg.active_chat or cfg.chats[1].id
	if type(cfg.groq_key) ~= "string" or cfg.groq_key == "" then
		cfg.groq_key = API_KEY
	end
	saveConfig(cfg)

	local mode = "idle"
	local clarifyCount = 0
	local hackBrief = { original = "", answers = {}, kind = "action" }
	local busy = false
	local hackRunning = false
	local exprState = "idle"
	local animToken = 0
	local sessionGreeted = false -- FIX: saludo solo una vez por sesión de script
	local activeTab = "chats" -- chats | providers

	local function getActiveChat()
		for _, ch in ipairs(cfg.chats) do
			if ch.id == cfg.active_chat then return ch end
		end
		return cfg.chats[1]
	end

	local function persist()
		saveConfig(cfg)
	end

	-- SPRITE
	local sprite = Instance.new("ImageButton")
	sprite.Name = "CapriSprite"
	sprite.Size = UDim2.fromOffset(96, 96)
	sprite.Position = UDim2.new(1, -110, 0.42, 0)
	sprite.BackgroundTransparency = 1
	sprite.BorderSizePixel = 0
	sprite.Image = pickImage("Cutout", "Face", "FaceCalm")
	sprite.ScaleType = Enum.ScaleType.Fit
	sprite.AutoButtonColor = false
	sprite.ZIndex = 10
	sprite.Parent = gui
	mkCorner(sprite, 10)
	local spriteStroke = mkStroke(sprite, Theme.glitch, 1.5, 0.45)

	local spriteFallback = Instance.new("TextLabel")
	spriteFallback.Size = UDim2.fromScale(1, 1)
	spriteFallback.BackgroundTransparency = 1
	spriteFallback.Text = sprite.Image == "" and "C" or ""
	spriteFallback.TextColor3 = Theme.accent
	spriteFallback.Font = Enum.Font.GothamBlack
	spriteFallback.TextSize = 28
	spriteFallback.ZIndex = 11
	spriteFallback.Parent = sprite

	local dragging, dragMoved, dragStart, startPos = false, false, nil, nil
	local baseY = sprite.Position.Y.Offset
	RunService.RenderStepped:Connect(function()
		if dragging then return end
		local wave = math.sin(os.clock() * 1.4) * 3.5
		local pos = sprite.Position
		sprite.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, baseY + wave)
	end)
	sprite.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, dragMoved, dragStart, startPos = true, false, input.Position, sprite.Position
			baseY = startPos.Y.Offset
		end
	end)
	sprite.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			baseY = sprite.Position.Y.Offset
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - dragStart
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then dragMoved = true end
			sprite.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			baseY = sprite.Position.Y.Offset
		end
	end)

	-- MAIN WINDOW (centrado, estilo Project)
	local WIN_W, WIN_H = 720, 440
	local window = Instance.new("Frame")
	window.Name = "CapriWorkbench"
	window.Size = UDim2.fromOffset(WIN_W, WIN_H)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = Theme.panel
	window.BackgroundTransparency = 0.08
	window.BorderSizePixel = 0
	window.Visible = false
	window.ZIndex = 20
	window.Parent = gui
	mkCorner(window, 12)
	mkStroke(window, Theme.glitch, 1.4, 0.2)

	-- Title bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Theme.sidebar
	titleBar.BackgroundTransparency = 0.15
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 21
	titleBar.Parent = window
	mkCorner(titleBar, 12)

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
	titleLbl.Size = UDim2.new(0.5, 0, 1, 0)
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
	statusLbl.Position = UDim2.new(0.45, 0, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "en línea"
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
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Theme.textDim
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 23
	closeBtn.Parent = titleBar
	mkCorner(closeBtn, 6)

	-- Body layout: sidebar + content
	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -52)
	body.Position = UDim2.fromOffset(8, 44)
	body.BackgroundTransparency = 1
	body.ZIndex = 21
	body.Parent = window

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 180, 1, 0)
	sidebar.BackgroundColor3 = Theme.sidebar
	sidebar.BackgroundTransparency = 0.1
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
	sideList.CanvasSize = UDim2.new(0, 0, 0, 0)
	sideList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sideList.ZIndex = 23
	sideList.Parent = sidebar
	local sideLayout = Instance.new("UIListLayout", sideList)
	sideLayout.Padding = UDim.new(0, 6)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder

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
	content.BackgroundTransparency = 0.12
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
	local msgPad = Instance.new("UIPadding", msgScroll)
	msgPad.PaddingTop = UDim.new(0, 4)
	msgPad.PaddingBottom = UDim.new(0, 4)

	local providersPane = Instance.new("ScrollingFrame")
	providersPane.Size = UDim2.new(1, -12, 1, -12)
	providersPane.Position = UDim2.fromOffset(6, 6)
	providersPane.BackgroundTransparency = 1
	providersPane.Visible = false
	providersPane.ScrollBarThickness = 4
	providersPane.ScrollBarImageColor3 = Theme.glitch
	providersPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	providersPane.CanvasSize = UDim2.new(0, 0, 0, 0)
	providersPane.ZIndex = 23
	providersPane.Parent = content
	local provLayout = Instance.new("UIListLayout", providersPane)
	provLayout.Padding = UDim.new(0, 8)
	provLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local inputBar = Instance.new("Frame")
	inputBar.Size = UDim2.new(1, -12, 0, 40)
	inputBar.Position = UDim2.new(0, 6, 1, -48)
	inputBar.BackgroundColor3 = Theme.inputBg
	inputBar.BorderSizePixel = 0
	inputBar.ZIndex = 24
	inputBar.Parent = content
	mkCorner(inputBar, 8)
	mkStroke(inputBar, Theme.border, 1, 0.5)

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

	-- Hack window (aparte)
	local hackWin = Instance.new("Frame")
	hackWin.Size = UDim2.fromOffset(340, 220)
	hackWin.Position = UDim2.new(1, -360, 1, -240)
	hackWin.BackgroundColor3 = Theme.panel
	hackWin.BackgroundTransparency = 0.05
	hackWin.BorderSizePixel = 0
	hackWin.Visible = false
	hackWin.ZIndex = 40
	hackWin.Parent = gui
	mkCorner(hackWin, 10)
	mkStroke(hackWin, Theme.glitch, 1.5, 0.15)

	local hackTitle = Instance.new("TextLabel")
	hackTitle.Size = UDim2.new(1, -16, 0, 28)
	hackTitle.Position = UDim2.fromOffset(10, 8)
	hackTitle.BackgroundTransparency = 1
	hackTitle.Text = "Capri · Hack"
	hackTitle.TextColor3 = Theme.glitch
	hackTitle.Font = Enum.Font.GothamBold
	hackTitle.TextSize = 14
	hackTitle.TextXAlignment = Enum.TextXAlignment.Left
	hackTitle.ZIndex = 41
	hackTitle.Parent = hackWin

	local hackStatus = Instance.new("TextLabel")
	hackStatus.Size = UDim2.new(1, -20, 0, 20)
	hackStatus.Position = UDim2.fromOffset(10, 36)
	hackStatus.BackgroundTransparency = 1
	hackStatus.Text = "en cola"
	hackStatus.TextColor3 = Theme.textDim
	hackStatus.Font = Enum.Font.Code
	hackStatus.TextSize = 12
	hackStatus.TextXAlignment = Enum.TextXAlignment.Left
	hackStatus.ZIndex = 41
	hackStatus.Parent = hackWin

	local hackBody = Instance.new("TextLabel")
	hackBody.Size = UDim2.new(1, -20, 1, -70)
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

	local function setStatus(txt)
		statusLbl.Text = txt
		local working = txt:find("hack") or txt:find("espera") or txt:find("afinando") or txt:find("traduc")
		if working then
			titleLbl.Text = "Capri · en el sistema"
			titleLbl.TextColor3 = Theme.glitch
		else
			titleLbl.Text = "Capri"
			titleLbl.TextColor3 = Theme.accent
		end
	end

	local function applyFace(keys)
		local img = pickImage(table.unpack(keys))
		if img ~= "" then
			titleFace.Image = img
			local s = pickImage(keys[1], "Cutout", "Face")
			if s ~= "" then
				sprite.Image = s
				spriteFallback.Text = ""
			end
		end
	end

	local function setExpression(state)
		exprState = state
		animToken = animToken + 1
		local token = animToken
		if state == "talking" then
			applyFace({ "FaceLook", "FaceSmug", "FaceLaugh" })
			tween(spriteStroke, { Color = Theme.accent, Transparency = 0 }, 0.12)
		elseif state == "hack" then
			applyFace({ "FaceMany", "FaceCalm" })
			tween(spriteStroke, { Color = Theme.glitch, Transparency = 0 }, 0.12)
			task.spawn(function()
				while animToken == token and exprState == "hack" do
					tween(spriteStroke, { Transparency = 0.05 }, 0.35)
					task.wait(0.4)
					if animToken ~= token then break end
					tween(spriteStroke, { Transparency = 0.45 }, 0.35)
					task.wait(0.4)
				end
			end)
		elseif state == "done" then
			applyFace({ "FaceLaugh", "FaceSmug" })
			tween(spriteStroke, { Color = Theme.green, Transparency = 0 }, 0.12)
			task.delay(1.4, function() if animToken == token then setExpression("idle") end end)
		elseif state == "error" then
			applyFace({ "FaceWide", "FaceMany" })
			tween(spriteStroke, { Color = Theme.danger, Transparency = 0 }, 0.12)
			task.delay(1.6, function() if animToken == token then setExpression("idle") end end)
		else
			applyFace({ "FaceCalm", "FaceLook" })
			tween(spriteStroke, { Color = Theme.glitch, Transparency = 0.45 }, 0.2)
			task.spawn(function()
				local faces = { "FaceCalm", "FaceLook", "FaceAside", "FaceSmug" }
				local i = 1
				while animToken == token and exprState == "idle" do
					task.wait(2.8 + math.random())
					if animToken ~= token then break end
					i = (i % #faces) + 1
					applyFace({ faces[i] })
				end
			end)
		end
	end
	setExpression("idle")

	local function clearMessages()
		for _, c in ipairs(msgScroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
	end

