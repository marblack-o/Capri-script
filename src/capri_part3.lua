	local function addBubble(role, text, skipPersist)
		local ch = getActiveChat()
		if not skipPersist then
			ch.messages = ch.messages or {}
			table.insert(ch.messages, { role = role, content = tostring(text) })
			-- title from first user msg
			if role == "user" and (ch.title == "General" or ch.title == "Nuevo chat") then
				ch.title = string.sub(tostring(text), 1, 28)
			end
			persist()
		end
		local bubble = Instance.new("Frame")
		bubble.Size = UDim2.new(1, -6, 0, 0)
		bubble.AutomaticSize = Enum.AutomaticSize.Y
		bubble.BackgroundTransparency = 1
		bubble.LayoutOrder = #msgScroll:GetChildren() + 1
		bubble.ZIndex = 24
		bubble.Parent = msgScroll
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundColor3 = role == "user" and Theme.bubbleUser or Theme.bubbleAi
		label.BackgroundTransparency = 0.12
		label.BorderSizePixel = 0
		label.Text = tostring(text)
		label.TextColor3 = role == "user" and Theme.textDim or Theme.text
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
		mkCorner(label, 8)
		task.defer(function()
			msgScroll.CanvasPosition = Vector2.new(0, math.max(0, msgScroll.AbsoluteCanvasSize.Y))
		end)
	end

	local function renderActiveChat()
		clearMessages()
		local ch = getActiveChat()
		for _, m in ipairs(ch.messages or {}) do
			addBubble(m.role, m.content, true)
		end
		-- saludo solo 1 vez por sesión de script y solo si el chat está vacío
		if not sessionGreeted and #(ch.messages or {}) == 0 then
			sessionGreeted = true
			local greet = "Workbench listo. Chats a la izquierda · Providers arriba · !hack para el juego."
			addBubble("assistant", greet) -- se persiste una sola vez en este chat vacío
		end
	end

	local function refreshChatList()
		for _, c in ipairs(sideList:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for i, ch in ipairs(cfg.chats) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -4, 0, 32)
			btn.BackgroundColor3 = (ch.id == cfg.active_chat) and Theme.accent or Theme.row
			btn.Text = "  " .. (ch.title or "Chat")
			btn.TextColor3 = Theme.text
			btn.Font = Enum.Font.Code
			btn.TextSize = 12
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.AutoButtonColor = false
			btn.LayoutOrder = i
			btn.ZIndex = 24
			btn.Parent = sideList
			mkCorner(btn, 6)
			btn.MouseButton1Click:Connect(function()
				cfg.active_chat = ch.id
				persist()
				refreshChatList()
				renderActiveChat()
			end)
		end
	end

	local function buildProvidersUI()
		for _, c in ipairs(providersPane:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local note = Instance.new("TextLabel")
		note.Size = UDim2.new(1, -8, 0, 36)
		note.BackgroundTransparency = 1
		note.Text = "Keys solo en tu executor (capri_config.json). Capri-chat usa Groq. Los hacks usan Project UAI + su provider."
		note.TextColor3 = Theme.textDim
		note.Font = Enum.Font.Code
		note.TextSize = 11
		note.TextWrapped = true
		note.TextXAlignment = Enum.TextXAlignment.Left
		note.LayoutOrder = 0
		note.ZIndex = 24
		note.Parent = providersPane

		for i, prov in ipairs(PROVIDER_CATALOG) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -6, 0, prov.noKey and 72 or 96)
			row.BackgroundColor3 = Theme.row
			row.BorderSizePixel = 0
			row.LayoutOrder = i
			row.ZIndex = 24
			row.Parent = providersPane
			mkCorner(row, 8)

			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(1, -12, 0, 18)
			name.Position = UDim2.fromOffset(10, 6)
			name.BackgroundTransparency = 1
			name.Text = prov.name
			name.TextColor3 = Theme.glitch
			name.Font = Enum.Font.GothamBold
			name.TextSize = 13
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 25
			name.Parent = row

			local desc = Instance.new("TextLabel")
			desc.Size = UDim2.new(1, -12, 0, 16)
			desc.Position = UDim2.fromOffset(10, 24)
			desc.BackgroundTransparency = 1
			desc.Text = prov.desc
			desc.TextColor3 = Theme.textDim
			desc.Font = Enum.Font.Code
			desc.TextSize = 11
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.ZIndex = 25
			desc.Parent = row

			local linkBtn = Instance.new("TextButton")
			linkBtn.Size = UDim2.fromOffset(110, 24)
			linkBtn.Position = UDim2.new(1, -120, 0, 8)
			linkBtn.BackgroundColor3 = Theme.bg
			linkBtn.Text = "Copiar link"
			linkBtn.TextColor3 = Theme.accent
			linkBtn.Font = Enum.Font.GothamBold
			linkBtn.TextSize = 11
			linkBtn.AutoButtonColor = false
			linkBtn.ZIndex = 26
			linkBtn.Parent = row
			mkCorner(linkBtn, 6)
			linkBtn.MouseButton1Click:Connect(function()
				if copyText(prov.link) then
					linkBtn.Text = "¡Copiado!"
					task.delay(1.2, function() if linkBtn.Parent then linkBtn.Text = "Copiar link" end end)
				else
					linkBtn.Text = "Ver consola"
					print("[Capri] Link " .. prov.name .. ": " .. prov.link)
					task.delay(1.5, function() if linkBtn.Parent then linkBtn.Text = "Copiar link" end end)
				end
			end)

			if not prov.noKey and prov.keyField then
				local box = Instance.new("TextBox")
				box.Size = UDim2.new(1, -100, 0, 28)
				box.Position = UDim2.fromOffset(10, 48)
				box.BackgroundColor3 = Theme.inputBg
				box.BorderSizePixel = 0
				box.PlaceholderText = "API key…"
				box.PlaceholderColor3 = Theme.textDim
				local stored = cfg.provider_keys[prov.keyField] or (prov.keyField == "groq_key" and cfg.groq_key) or ""
				box.Text = stored
				box.TextColor3 = Theme.text
				box.Font = Enum.Font.Code
				box.TextSize = 12
				box.ClearTextOnFocus = false
				box.TextXAlignment = Enum.TextXAlignment.Left
				box.ZIndex = 26
				box.Parent = row
				mkCorner(box, 6)
				local pad = Instance.new("UIPadding", box)
				pad.PaddingLeft = UDim.new(0, 8)

				local saveBtn = Instance.new("TextButton")
				saveBtn.Size = UDim2.fromOffset(72, 28)
				saveBtn.Position = UDim2.new(1, -84, 0, 48)
				saveBtn.BackgroundColor3 = Theme.accent
				saveBtn.Text = "Guardar"
				saveBtn.TextColor3 = Color3.new(1, 1, 1)
				saveBtn.Font = Enum.Font.GothamBold
				saveBtn.TextSize = 11
				saveBtn.AutoButtonColor = false
				saveBtn.ZIndex = 26
				saveBtn.Parent = row
				mkCorner(saveBtn, 6)
				saveBtn.MouseButton1Click:Connect(function()
					local key = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
					cfg.provider_keys[prov.keyField] = key
					if prov.keyField == "groq_key" then
						cfg.groq_key = key
						API_KEY = key
					end
					persist()
					saveBtn.Text = "OK"
					task.delay(1, function() if saveBtn.Parent then saveBtn.Text = "Guardar" end end)
				end)
			end
		end
	end

	local function setTab(tab)
		activeTab = tab
		if tab == "chats" then
			tabChats.BackgroundColor3 = Theme.accent
			tabProv.BackgroundColor3 = Theme.row
			msgScroll.Visible = true
			inputBar.Visible = true
			providersPane.Visible = false
			newChatBtn.Visible = true
			refreshChatList()
		else
			tabChats.BackgroundColor3 = Theme.row
			tabProv.BackgroundColor3 = Theme.accent
			msgScroll.Visible = false
			inputBar.Visible = false
			providersPane.Visible = true
			newChatBtn.Visible = false
			-- side list empty-ish for providers
			for _, c in ipairs(sideList:GetChildren()) do
				if c:IsA("TextButton") then c:Destroy() end
			end
			buildProvidersUI()
		end
	end

	tabChats.MouseButton1Click:Connect(function() setTab("chats") end)
	tabProv.MouseButton1Click:Connect(function() setTab("providers") end)

	newChatBtn.MouseButton1Click:Connect(function()
		local ch = { id = HttpService:GenerateGUID(false), title = "Nuevo chat", messages = {} }
		table.insert(cfg.chats, 1, ch)
		cfg.active_chat = ch.id
		persist()
		setTab("chats")
		renderActiveChat()
	end)

	local panelOpen = false
	local function openWindow()
		panelOpen = true
		window.Visible = true
		window.Size = UDim2.fromOffset(WIN_W * 0.96, WIN_H * 0.96)
		tween(window, { Size = UDim2.fromOffset(WIN_W, WIN_H) }, 0.18, Enum.EasingStyle.Back)
		setTab("chats")
		renderActiveChat()
	end
	local function closeWindow()
		panelOpen = false
		window.Visible = false
	end

	sprite.MouseButton1Click:Connect(function()
		if dragMoved then return end
		if panelOpen then closeWindow() else openWindow() end
	end)
	closeBtn.MouseButton1Click:Connect(closeWindow)

	local function openHackWindow(titleText)
		hackWin.Visible = true
		hackTitle.Text = "Capri · " .. (titleText or "Hack")
		hackStatus.Text = "trabajando…"
		hackBody.Text = "Esperando a que UAI termine el turno completo…"
	end

	local function startHack()
		mode = "hack"
		hackRunning = true
		setStatus("hackeando · espera…")
		setExpression("hack")
		openHackWindow(string.sub(hackBrief.original, 1, 40))
		addBubble("assistant", "Me meto al sistema. Te abro la ventana del hack.")

		local prompt = buildHackPrompt(hackBrief)
		local kind = hackBrief.kind
		print("[Capri] Hack prompt:\n" .. prompt)

		runUAIMission(prompt, function(ok, resultText)
			hackRunning = false
			mode = "idle"
			clarifyCount = 0
			hackBrief = { original = "", answers = {}, kind = "action" }
			if not ok then
				setStatus("hack fallido")
				setExpression("error")
				hackStatus.Text = "falló"
				hackBody.Text = friendlyUAIError(resultText)
				addBubble("assistant", "El hack se torció:\n" .. friendlyUAIError(resultText))
				return
			end
			hackStatus.Text = "listo"
			if kind == "research" then
				setStatus("traduciendo…")
				setExpression("talking")
				local rewritten = select(1, groqChat(API_KEY, {
					{ role = "system", content = CAPRI_PROMPT .. "\nRetell this Roblox report in Capri voice. Concise." },
					{ role = "user", content = tostring(resultText) },
				}, 700))
				setStatus("en línea")
				setExpression("done")
				local out = rewritten or tostring(resultText)
				hackBody.Text = out
				addBubble("assistant", out)
			else
				setStatus("en línea")
				setExpression("done")
				hackBody.Text = tostring(resultText)
				addBubble("assistant", "Trabajo listo, choom.\n" .. tostring(resultText))
			end
		end)
	end

	local function beginHackFlow(cleanText)
		hackBrief = { original = cleanText, answers = {}, kind = detectKind(cleanText) }
		clarifyCount = 0
		if isHackClear(cleanText) then
			startHack()
			return
		end
		mode = "clarifying"
		setStatus("afinando el hack")
		setExpression("talking")
		local reply = select(1, groqChat(API_KEY, {
			{ role = "system", content = CAPRI_PROMPT .. "\nUser started !hack in THIS Roblox game. Ask ONE short question only if needed. Never ask which game. If clear, first line READY_FOR_HACK" },
			{ role = "user", content = cleanText },
		}, 220))
		if not reply or reply:find("READY_FOR_HACK") or isHackClear(cleanText) then
			if reply then
				local s = reply:gsub("READY_FOR_HACK", ""):gsub("^%s+", ""):gsub("%s+$", "")
				if s ~= "" and not isHackClear(cleanText) then addBubble("assistant", s) end
			end
			startHack()
		else
			clarifyCount = 1
			addBubble("assistant", reply)
			setExpression("idle")
		end
	end

	local function handleClarify(userText)
		table.insert(hackBrief.answers, userText)
		clarifyCount = clarifyCount + 1
		local reply = select(1, groqChat(API_KEY, {
			{ role = "system", content = CAPRI_PROMPT .. "\nClarifying hack for THIS game. If enough, first line READY_FOR_HACK. Never ask which game." },
			{ role = "user", content = "Original: " .. hackBrief.original .. "\nAnswer: " .. userText },
		}, 220))
		if not reply or reply:find("READY_FOR_HACK") or clarifyCount >= MAX_CLARIFY then
			startHack()
		else
			addBubble("assistant", reply)
			setExpression("idle")
			setStatus("afinando el hack (" .. clarifyCount .. "/" .. MAX_CLARIFY .. ")")
		end
	end

	local function sendMessage(text)
		text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" or busy then return end
		if activeTab ~= "chats" then setTab("chats") end
		busy = true
		inputBox.Text = ""
		addBubble("user", text)
		task.spawn(function()
			if mode == "clarifying" then
				handleClarify(text)
				busy = false
				return
			end
			if mode == "idle" and text:sub(1, 1) == "!" and not hackRunning then
				local clean = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
				if clean == "" then
					addBubble("assistant", "Pon el trabajo después de '!'. Ej: !analiza el juego")
					busy = false
					return
				end
				beginHackFlow(clean)
				busy = false
				return
			end
			setStatus(hackRunning and "hack + charla" or "pensando…")
			setExpression("talking")
			local ch = getActiveChat()
			local msgs = { { role = "system", content = CAPRI_PROMPT } }
			for _, m in ipairs(ch.messages or {}) do
				if m.role == "user" or m.role == "assistant" then
					table.insert(msgs, { role = m.role, content = m.content })
				end
			end
			local reply, err = groqChat(API_KEY, msgs, 450)
			if not reply then
				addBubble("assistant", "Falló la IA (" .. tostring(err) .. ").")
				setExpression("error")
				setStatus("error")
			else
				addBubble("assistant", reply)
				setExpression(hackRunning and "hack" or "idle")
				setStatus(hackRunning and "hackeando" or "en línea")
			end
			busy = false
		end)
	end

	sendBtn.MouseButton1Click:Connect(function() sendMessage(inputBox.Text) end)
	inputBox.FocusLost:Connect(function(enter) if enter then sendMessage(inputBox.Text) end end)

	task.spawn(function()
		local ok = ensureUAI(false)
		print(ok and "[Capri] UAI preload OK" or "[Capri] UAI preload luego en hack")
	end)

	print("[Capri] Lista v6 Workbench")
	print("[Capri] Click sprite → workbench centrado · Providers · !hack")
end

-- BOOT
local cfg = loadConfig()
if type(cfg.model) == "string" and cfg.model ~= "" and cfg.model ~= "llama-3.3-70b-versatile" then
	API_MODEL = cfg.model
end
local savedKey = cfg.groq_key
if type(savedKey) == "string" and savedKey ~= "" then
	print("[Capri] Key local OK.")
	startCapri(savedKey)
else
	-- minimal setup overlay
	local setup = Instance.new("Frame")
	setup.Size = UDim2.fromOffset(360, 220)
	setup.Position = UDim2.fromScale(0.5, 0.5)
	setup.AnchorPoint = Vector2.new(0.5, 0.5)
	setup.BackgroundColor3 = Theme.panel
	setup.ZIndex = 60
	setup.Parent = gui
	mkCorner(setup, 12)
	mkStroke(setup, Theme.glitch, 1.4, 0.2)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -24, 0, 28)
	t.Position = UDim2.fromOffset(12, 14)
	t.BackgroundTransparency = 1
	t.Text = "Capri — Groq key"
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
	mkCorner(box, 8)
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
	mkCorner(go, 8)
	go.MouseButton1Click:Connect(function()
		local key = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if key == "" then return end
		local c = loadConfig()
		c.groq_key = key
		saveConfig(c)
		setup:Destroy()
		startCapri(key)
	end)
end
