--[[
  UI_Chat.lua
  Qué: workbench centrado inspirado en Project UAI (sidebar + contenido + tabs).
  Por qué: chats múltiples, providers, accesos nativos UAI (chat/providers/logs)
           y explorador simple de archivos del executor cuando listfiles existe.
  Bordes: verde = chat normal · amarillo = trabajo UAI.
]]

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local UI_Chat = {}
UI_Chat.__index = UI_Chat

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

local function copyText(s)
	if type(setclipboard) == "function" then pcall(setclipboard, tostring(s)) return true end
	if type(toclipboard) == "function" then pcall(toclipboard, tostring(s)) return true end
	return false
end

function UI_Chat.new(opts)
	local self = setmetatable({}, UI_Chat)
	self.gui = opts.gui
	self.Theme = opts.Theme
	self.Assets = opts.Assets
	self.Config = opts.Config
	self.cfg = opts.cfg
	self.UAI = opts.UAI
	self.Visual = opts.Visual
	self.API_KEY = opts.apiKey
	self.onSend = opts.onSend -- function(text)
	self.sessionGreeted = false
	self.activeTab = "chats"
	self:_build()
	return self
end

function UI_Chat:persist()
	self.Config.save(self.cfg)
end

function UI_Chat:getActiveChat()
	for _, ch in ipairs(self.cfg.chats) do
		if ch.id == self.cfg.active_chat then return ch end
	end
	return self.cfg.chats[1]
end

function UI_Chat:setBorderMode(mode)
	if mode == "uai" then
		self.Theme.tween(self.windowStroke, { Color = self.Theme.uaiYellow, Transparency = 0.05 }, 0.2)
	else
		self.Theme.tween(self.windowStroke, { Color = self.Theme.chatGreen, Transparency = 0.15 }, 0.2)
	end
end

function UI_Chat:setStatus(txt)
	self.statusLbl.Text = txt
	local working = txt:find("hack") or txt:find("espera") or txt:find("afinando") or txt:find("traduc")
	if working then
		self.titleLbl.Text = "Capri · en el sistema"
		self.titleLbl.TextColor3 = self.Theme.uaiYellow
		self:setBorderMode("uai")
	else
		self.titleLbl.Text = "Capri"
		self.titleLbl.TextColor3 = self.Theme.accent
		self:setBorderMode("chat")
	end
end

function UI_Chat:_build()
	local Theme, Assets = self.Theme, self.Assets
	local WIN_W, WIN_H = 760, 460

	local window = Instance.new("Frame")
	window.Name = "CapriWorkbench"
	window.Size = UDim2.fromOffset(WIN_W, WIN_H)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = Theme.panel
	window.BackgroundTransparency = 0.2
	window.BorderSizePixel = 0
	window.Visible = false
	window.ZIndex = 20
	window.Parent = self.gui
	Theme.mkCorner(window, 14)
	self.window = window
	self.windowStroke = Theme.mkStroke(window, Theme.chatGreen, 2, 0.15)

	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundColor3 = Theme.sidebar
	titleBar.BackgroundTransparency = 0.22
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 21
	titleBar.Parent = window
	Theme.mkCorner(titleBar, 14)
	makeDraggable(window, titleBar)

	local titleFace = Instance.new("ImageLabel")
	titleFace.Size = UDim2.fromOffset(28, 28)
	titleFace.Position = UDim2.fromOffset(12, 6)
	titleFace.BackgroundTransparency = 1
	titleFace.Image = Assets.pick("FaceCalm", "Face")
	titleFace.ScaleType = Enum.ScaleType.Crop
	titleFace.ZIndex = 22
	titleFace.Parent = titleBar
	Theme.mkCorner(titleFace, 8)
	self.titleFace = titleFace

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.4, 0, 1, 0)
	titleLbl.Position = UDim2.fromOffset(48, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = "Capri"
	titleLbl.TextColor3 = Theme.accent
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 22
	titleLbl.Parent = titleBar
	self.titleLbl = titleLbl

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size = UDim2.new(0.4, -90, 1, 0)
	statusLbl.Position = UDim2.new(0.4, 0, 0, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = "chat"
	statusLbl.TextColor3 = Theme.textDim
	statusLbl.Font = Enum.Font.Code
	statusLbl.TextSize = 12
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	statusLbl.ZIndex = 22
	statusLbl.Parent = titleBar
	self.statusLbl = statusLbl

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
	Theme.mkCorner(closeBtn, 6)
	closeBtn.MouseButton1Click:Connect(function() self:close() end)

	local body = Instance.new("Frame")
	body.Size = UDim2.new(1, -16, 1, -52)
	body.Position = UDim2.fromOffset(8, 44)
	body.BackgroundTransparency = 1
	body.ZIndex = 21
	body.Parent = window

	-- sidebar
	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.new(0, 190, 1, 0)
	sidebar.BackgroundColor3 = Theme.sidebar
	sidebar.BackgroundTransparency = 0.18
	sidebar.ZIndex = 22
	sidebar.Parent = body
	Theme.mkCorner(sidebar, 10)

	local function tabBtn(text, xScale)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.5, -6, 0, 26)
		b.Position = UDim2.new(xScale, xScale == 0 and 6 or 0, 0, 6)
		b.BackgroundColor3 = Theme.row
		b.Text = text
		b.TextColor3 = Theme.text
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.AutoButtonColor = false
		b.ZIndex = 23
		b.Parent = sidebar
		Theme.mkCorner(b, 6)
		return b
	end
	self.tabChats = tabBtn("Chats", 0)
	self.tabProv = tabBtn("Providers", 0.5)
	self.tabChats.Position = UDim2.fromOffset(6, 6)
	self.tabProv.Position = UDim2.new(0.5, 0, 0, 6)

	-- UAI native shortcuts
	local uaiRow = Instance.new("Frame")
	uaiRow.Size = UDim2.new(1, -12, 0, 22)
	uaiRow.Position = UDim2.fromOffset(6, 36)
	uaiRow.BackgroundTransparency = 1
	uaiRow.ZIndex = 23
	uaiRow.Parent = sidebar
	local function mini(label, x, section)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.33, -4, 1, 0)
		b.Position = UDim2.new(x, 0, 0, 0)
		b.BackgroundColor3 = Theme.bg
		b.Text = label
		b.TextColor3 = Theme.glitch
		b.Font = Enum.Font.Code
		b.TextSize = 10
		b.AutoButtonColor = false
		b.ZIndex = 24
		b.Parent = uaiRow
		Theme.mkCorner(b, 4)
		b.MouseButton1Click:Connect(function()
			local ok, err = self.UAI.show(section)
			if not ok then
				self:addBubble("assistant", "No pude abrir UAI " .. tostring(section) .. ": " .. tostring(err), true)
			end
		end)
	end
	mini("UAI", 0, "chat")
	mini("Prov", 0.33, "providers")
	mini("Logs", 0.66, "logs")

	local sideList = Instance.new("ScrollingFrame")
	sideList.Size = UDim2.new(1, -12, 1, -100)
	sideList.Position = UDim2.fromOffset(6, 62)
	sideList.BackgroundTransparency = 1
	sideList.ScrollBarThickness = 3
	sideList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sideList.CanvasSize = UDim2.new(0, 0, 0, 0)
	sideList.ZIndex = 23
	sideList.Parent = sidebar
	Instance.new("UIListLayout", sideList).Padding = UDim.new(0, 5)
	self.sideList = sideList

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
	Theme.mkCorner(newChatBtn, 6)
	self.newChatBtn = newChatBtn
	newChatBtn.MouseButton1Click:Connect(function()
		local ch = { id = HttpService:GenerateGUID(false), title = "Nuevo chat", messages = {} }
		table.insert(self.cfg.chats, 1, ch)
		self.cfg.active_chat = ch.id
		self:persist()
		self:setTab("chats")
		self:renderActiveChat()
	end)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -206, 1, 0)
	content.Position = UDim2.fromOffset(198, 0)
	content.BackgroundColor3 = Theme.plate
	content.BackgroundTransparency = 0.26
	content.ZIndex = 22
	content.Parent = body
	Theme.mkCorner(content, 10)
	self.content = content

	local msgScroll = Instance.new("ScrollingFrame")
	msgScroll.Size = UDim2.new(1, -12, 1, -56)
	msgScroll.Position = UDim2.fromOffset(6, 6)
	msgScroll.BackgroundTransparency = 1
	msgScroll.ScrollBarThickness = 4
	msgScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	msgScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	msgScroll.ZIndex = 23
	msgScroll.Parent = content
	local lay = Instance.new("UIListLayout", msgScroll)
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	self.msgScroll = msgScroll

	local providersPane = Instance.new("ScrollingFrame")
	providersPane.Size = UDim2.new(1, -12, 1, -12)
	providersPane.Position = UDim2.fromOffset(6, 6)
	providersPane.BackgroundTransparency = 1
	providersPane.Visible = false
	providersPane.ScrollBarThickness = 4
	providersPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	providersPane.ZIndex = 23
	providersPane.Parent = content
	Instance.new("UIListLayout", providersPane).Padding = UDim.new(0, 8)
	self.providersPane = providersPane

	local filesPane = Instance.new("ScrollingFrame")
	filesPane.Size = UDim2.new(1, -12, 1, -12)
	filesPane.Position = UDim2.fromOffset(6, 6)
	filesPane.BackgroundTransparency = 1
	filesPane.Visible = false
	filesPane.ScrollBarThickness = 4
	filesPane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	filesPane.ZIndex = 23
	filesPane.Parent = content
	Instance.new("UIListLayout", filesPane).Padding = UDim.new(0, 4)
	self.filesPane = filesPane

	local inputBar = Instance.new("Frame")
	inputBar.Size = UDim2.new(1, -12, 0, 40)
	inputBar.Position = UDim2.new(0, 6, 1, -48)
	inputBar.BackgroundColor3 = Theme.inputBg
	inputBar.BackgroundTransparency = 0.12
	inputBar.ZIndex = 24
	inputBar.Parent = content
	Theme.mkCorner(inputBar, 8)
	self.inputBar = inputBar

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
	self.inputBox = inputBox

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
	Theme.mkCorner(sendBtn, 6)
	sendBtn.MouseButton1Click:Connect(function()
		if self.onSend then self.onSend(inputBox.Text) end
	end)
	inputBox.FocusLost:Connect(function(enter)
		if enter and self.onSend then self.onSend(inputBox.Text) end
	end)

	self.tabChats.MouseButton1Click:Connect(function() self:setTab("chats") end)
	self.tabProv.MouseButton1Click:Connect(function() self:setTab("providers") end)

	-- third tab via long-press side: Files button under new chat
	local filesBtn = Instance.new("TextButton")
	filesBtn.Size = UDim2.new(1, -12, 0, 22)
	filesBtn.Position = UDim2.new(0, 6, 1, -60)
	filesBtn.BackgroundColor3 = Theme.bg
	filesBtn.Text = "Archivos / UAI"
	filesBtn.TextColor3 = Theme.textDim
	filesBtn.Font = Enum.Font.Code
	filesBtn.TextSize = 11
	filesBtn.AutoButtonColor = false
	filesBtn.ZIndex = 23
	filesBtn.Parent = sidebar
	Theme.mkCorner(filesBtn, 5)
	filesBtn.MouseButton1Click:Connect(function() self:setTab("files") end)
end

function UI_Chat:open()
	self.window.Visible = true
	self:setTab("chats")
	self:renderActiveChat()
end

function UI_Chat:close()
	self.window.Visible = false
end

function UI_Chat:toggle()
	if self.window.Visible then self:close() else self:open() end
end

function UI_Chat:clearMessages()
	for _, c in ipairs(self.msgScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

function UI_Chat:addBubble(role, text, skipPersist)
	local ch = self:getActiveChat()
	if not skipPersist then
		ch.messages = ch.messages or {}
		table.insert(ch.messages, { role = role, content = tostring(text) })
		if role == "user" and (ch.title == "General" or ch.title == "Nuevo chat") then
			ch.title = string.sub(tostring(text), 1, 28)
		end
		self:persist()
	end
	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.new(1, -6, 0, 0)
	bubble.AutomaticSize = Enum.AutomaticSize.Y
	bubble.BackgroundTransparency = 1
	bubble.LayoutOrder = #self.msgScroll:GetChildren() + 1
	bubble.ZIndex = 24
	bubble.Parent = self.msgScroll
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundColor3 = role == "user" and self.Theme.bubbleUser or self.Theme.bubbleAi
	label.BackgroundTransparency = 0.2
	label.Text = tostring(text)
	label.TextColor3 = role == "user" and self.Theme.textDim or self.Theme.text
	label.Font = Enum.Font.Code
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 25
	label.Parent = bubble
	local p = Instance.new("UIPadding", label)
	p.PaddingTop = UDim.new(0, 8)
	p.PaddingBottom = UDim.new(0, 8)
	p.PaddingLeft = UDim.new(0, 10)
	p.PaddingRight = UDim.new(0, 10)
	self.Theme.mkCorner(label, 8)
	task.defer(function()
		self.msgScroll.CanvasPosition = Vector2.new(0, math.max(0, self.msgScroll.AbsoluteCanvasSize.Y))
	end)
end

function UI_Chat:renderActiveChat()
	self:clearMessages()
	local ch = self:getActiveChat()
	for _, m in ipairs(ch.messages or {}) do
		self:addBubble(m.role, m.content, true)
	end
	if not self.sessionGreeted and #(ch.messages or {}) == 0 then
		self.sessionGreeted = true
		self:addBubble("assistant", "Workbench modular. Chats · Providers (→ UAI) · Archivos · atajos UAI arriba.")
	end
end

function UI_Chat:refreshChatList()
	for _, c in ipairs(self.sideList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for i, ch in ipairs(self.cfg.chats) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -4, 0, 30)
		btn.BackgroundColor3 = (ch.id == self.cfg.active_chat) and self.Theme.accent or self.Theme.row
		btn.BackgroundTransparency = 0.12
		btn.Text = "  " .. (ch.title or "Chat")
		btn.TextColor3 = self.Theme.text
		btn.Font = Enum.Font.Code
		btn.TextSize = 12
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.AutoButtonColor = false
		btn.LayoutOrder = i
		btn.ZIndex = 24
		btn.Parent = self.sideList
		self.Theme.mkCorner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			self.cfg.active_chat = ch.id
			self:persist()
			self:refreshChatList()
			self:renderActiveChat()
		end)
	end
end

function UI_Chat:buildProviders()
	for _, c in ipairs(self.providersPane:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end
	end
	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -8, 0, 44)
	note.BackgroundTransparency = 1
	note.Text = "Guardar key → uai.providers.blank/save/setActive.\nFallback cuando Free está fuera de 20:00–12:00 UTC+8. Chat Capri = Groq."
	note.TextColor3 = self.Theme.textDim
	note.Font = Enum.Font.Code
	note.TextSize = 11
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.LayoutOrder = 0
	note.ZIndex = 24
	note.Parent = self.providersPane

	for i, prov in ipairs(self.UAI.PROVIDER_CATALOG) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, prov.noKey and 70 or 104)
		row.BackgroundColor3 = self.Theme.row
		row.BackgroundTransparency = 0.12
		row.LayoutOrder = i
		row.ZIndex = 24
		row.Parent = self.providersPane
		self.Theme.mkCorner(row, 8)

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -110, 0, 18)
		name.Position = UDim2.fromOffset(10, 6)
		name.BackgroundTransparency = 1
		name.Text = prov.name
		name.TextColor3 = self.Theme.glitch
		name.Font = Enum.Font.GothamBold
		name.TextSize = 13
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.ZIndex = 25
		name.Parent = row

		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -12, 0, 14)
		desc.Position = UDim2.fromOffset(10, 24)
		desc.BackgroundTransparency = 1
		desc.Text = prov.desc
		desc.TextColor3 = self.Theme.textDim
		desc.Font = Enum.Font.Code
		desc.TextSize = 11
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.ZIndex = 25
		desc.Parent = row

		local linkBtn = Instance.new("TextButton")
		linkBtn.Size = UDim2.fromOffset(96, 22)
		linkBtn.Position = UDim2.new(1, -106, 0, 8)
		linkBtn.BackgroundColor3 = self.Theme.bg
		linkBtn.Text = "Copiar link"
		linkBtn.TextColor3 = self.Theme.accent
		linkBtn.Font = Enum.Font.GothamBold
		linkBtn.TextSize = 11
		linkBtn.AutoButtonColor = false
		linkBtn.ZIndex = 26
		linkBtn.Parent = row
		self.Theme.mkCorner(linkBtn, 6)
		linkBtn.MouseButton1Click:Connect(function()
			if copyText(prov.link) then linkBtn.Text = "OK" else print(prov.link) linkBtn.Text = "F9" end
			task.delay(1, function() if linkBtn.Parent then linkBtn.Text = "Copiar link" end end)
		end)

		if not prov.noKey and prov.keyField then
			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, -100, 0, 26)
			box.Position = UDim2.fromOffset(10, 44)
			box.BackgroundColor3 = self.Theme.inputBg
			box.PlaceholderText = "API key…"
			box.Text = self.cfg.provider_keys[prov.keyField] or (prov.keyField == "groq_key" and self.cfg.groq_key) or ""
			box.TextColor3 = self.Theme.text
			box.Font = Enum.Font.Code
			box.TextSize = 12
			box.ClearTextOnFocus = false
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.ZIndex = 26
			box.Parent = row
			self.Theme.mkCorner(box, 6)
			Instance.new("UIPadding", box).PaddingLeft = UDim.new(0, 8)

			local st = Instance.new("TextLabel")
			st.Size = UDim2.new(1, -12, 0, 14)
			st.Position = UDim2.fromOffset(10, 76)
			st.BackgroundTransparency = 1
			st.Text = ""
			st.TextColor3 = self.Theme.textDim
			st.Font = Enum.Font.Code
			st.TextSize = 10
			st.TextXAlignment = Enum.TextXAlignment.Left
			st.ZIndex = 26
			st.Parent = row

			local saveBtn = Instance.new("TextButton")
			saveBtn.Size = UDim2.fromOffset(72, 26)
			saveBtn.Position = UDim2.new(1, -84, 0, 44)
			saveBtn.BackgroundColor3 = self.Theme.accent
			saveBtn.Text = "Guardar"
			saveBtn.TextColor3 = Color3.new(1, 1, 1)
			saveBtn.Font = Enum.Font.GothamBold
			saveBtn.TextSize = 11
			saveBtn.AutoButtonColor = false
			saveBtn.ZIndex = 26
			saveBtn.Parent = row
			self.Theme.mkCorner(saveBtn, 6)
			saveBtn.MouseButton1Click:Connect(function()
				local key = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
				if key == "" then st.Text = "Pon una key" st.TextColor3 = self.Theme.danger return end
				self.cfg.provider_keys[prov.keyField] = key
				if prov.keyField == "groq_key" then
					self.cfg.groq_key = key
					self.API_KEY = key
				end
				self:persist()
				st.Text = "Local OK · UAI…"
				st.TextColor3 = self.Theme.glitch
				task.spawn(function()
					local ok, msg = self.UAI.injectProvider(prov, key)
					st.Text = ok and ("UAI: " .. tostring(msg)) or ("UAI: " .. tostring(msg))
					st.TextColor3 = ok and self.Theme.chatGreen or self.Theme.danger
				end)
			end)
		end
	end
end

function UI_Chat:buildFiles()
	for _, c in ipairs(self.filesPane:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local note = Instance.new("TextLabel")
	note.Size = UDim2.new(1, -8, 0, 40)
	note.BackgroundTransparency = 1
	note.Text = "Atajos al explorador/herramientas de Project UAI y lista local del executor (si listfiles existe)."
	note.TextColor3 = self.Theme.textDim
	note.Font = Enum.Font.Code
	note.TextSize = 11
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.LayoutOrder = 0
	note.ZIndex = 24
	note.Parent = self.filesPane

	local function action(label, order, fn)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -8, 0, 30)
		b.BackgroundColor3 = self.Theme.row
		b.Text = "  " .. label
		b.TextColor3 = self.Theme.text
		b.Font = Enum.Font.Code
		b.TextSize = 12
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.AutoButtonColor = false
		b.LayoutOrder = order
		b.ZIndex = 24
		b.Parent = self.filesPane
		self.Theme.mkCorner(b, 6)
		b.MouseButton1Click:Connect(fn)
	end
	action("Abrir chat nativo UAI", 1, function() self.UAI.show("chat") end)
	action("Abrir Providers UAI", 2, function() self.UAI.show("providers") end)
	action("Abrir Logs UAI", 3, function() self.UAI.show("logs") end)

	if type(listfiles) == "function" then
		local ok, files = pcall(listfiles, "")
		if ok and type(files) == "table" then
			local n = 0
			for _, path in ipairs(files) do
				n = n + 1
				if n > 40 then break end
				local row = Instance.new("TextLabel")
				row.Size = UDim2.new(1, -8, 0, 20)
				row.BackgroundTransparency = 1
				row.Text = "  " .. tostring(path)
				row.TextColor3 = self.Theme.textDim
				row.Font = Enum.Font.Code
				row.TextSize = 11
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.LayoutOrder = 10 + n
				row.ZIndex = 24
				row.Parent = self.filesPane
			end
		end
	else
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -8, 0, 24)
		row.BackgroundTransparency = 1
		row.Text = "  (listfiles no disponible en este executor)"
		row.TextColor3 = self.Theme.textDim
		row.Font = Enum.Font.Code
		row.TextSize = 11
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = 10
		row.ZIndex = 24
		row.Parent = self.filesPane
	end
end

function UI_Chat:setTab(tab)
	self.activeTab = tab
	self.msgScroll.Visible = tab == "chats"
	self.inputBar.Visible = tab == "chats"
	self.providersPane.Visible = tab == "providers"
	self.filesPane.Visible = tab == "files"
	self.newChatBtn.Visible = tab == "chats"
	self.tabChats.BackgroundColor3 = tab == "chats" and self.Theme.accent or self.Theme.row
	self.tabProv.BackgroundColor3 = tab == "providers" and self.Theme.accent or self.Theme.row
	if tab == "chats" then
		self:refreshChatList()
	elseif tab == "providers" then
		for _, c in ipairs(self.sideList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		self:buildProviders()
	else
		for _, c in ipairs(self.sideList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		self:buildFiles()
	end
end

return UI_Chat
