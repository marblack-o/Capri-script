		if not session then
			-- provider missing is a common cause
			pcall(function()
				if uaiHandle.show then uaiHandle.show("providers") end
			end)
			onComplete(false, "No se pudo abrir sesión UAI: " .. tostring(sessionErr) .. " | Abre Providers en UAI y elige modelo.")
			return
		end

		local done = false
		local okReq, reqErr = pcall(function()
			uaiHandle.sdk.request(session, missionPrompt, {
				onComplete = function(result)
					if done then return end
					done = true
					if result and result.ok then
						onComplete(true, result.text or result.output or result.message or "Misión completada.")
					else
						local err = (result and (result.error or result.message)) or "UAI falló sin detalle"
						onComplete(false, tostring(err))
					end
				end,
			})
		end)
		if not okReq then
			if not done then
				done = true
				onComplete(false, "sdk.request error: " .. tostring(reqErr))
			end
			return
		end
		task.delay(240, function()
			if not done then
				done = true
				onComplete(false, "Timeout de misión UAI (4 min)")
			end
		end)
	end)
end

-- ═══════════════════════════════════════════
-- MISSION HEURISTICS
-- ═══════════════════════════════════════════

local function detectKind(text)
	local l = string.lower(text)
	if l:find("investiga") or l:find("busca") or l:find("analiza") or l:find("explora")
		or l:find("lista") or l:find("qué hay") or l:find("que hay") or l:find("inspeccion")
		or l:find("inspect") or l:find("scan") or l:find("describe") or l:find("resume") then
		return "research"
	end
	return "action"
end

-- Si el pedido ya es claro para ESTE juego de Roblox, no preguntes tonterías
local function isMissionClear(text)
	local l = string.lower(text)
	-- referencias implícitas al place actual
	local aboutThisGame = l:find("el juego") or l:find("este juego") or l:find("the game")
		or l:find("workspace") or l:find("datamodel") or l:find("el place")
		or l:find("el mapa") or l:find("aquí") or l:find("aqui") or l:find("this game")
		or l:find("scripts") or l:find("jugadores") or l:find("players")
	local verb = l:find("analiza") or l:find("explora") or l:find("investiga") or l:find("inspeccion")
		or l:find("lista") or l:find("busca") or l:find("scan") or l:find("inspect")
		or l:find("crea") or l:find("haz") or l:find("modifica") or l:find("cambia")
		or l:find("borra") or l:find("teleport") or l:find("spawnea")
	if verb and aboutThisGame then return true end
	-- pedidos cortos muy típicos
	if l == "analiza el juego" or l == "explora el juego" or l == "inspecciona el juego" then
		return true
	end
	if l:find("analiza") and #l < 40 then return true end
	if l:find("explora") and #l < 40 then return true end
	return false
end

local function buildMissionPrompt(brief)
	local placeName = "unknown"
	pcall(function()
		placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	local lines = {
		"MISSION FROM CAPRI (Roblox executor host)",
		"You are Project UAI running INSIDE the live Roblox client.",
		"Target: THIS DataModel only (current place).",
		"PlaceId: " .. tostring(game.PlaceId),
		"Place name (if known): " .. tostring(placeName),
		"JobId: " .. tostring(game.JobId),
		"",
		"User request: " .. brief.original,
		"Mission type: " .. brief.kind,
	}
	if #brief.answers > 0 then
		table.insert(lines, "Clarifications:")
		for i, a in ipairs(brief.answers) do
			table.insert(lines, ("  %d) %s"):format(i, a))
		end
	end
	table.insert(lines, "")
	if brief.kind == "research" then
		table.insert(lines, "RESEARCH ONLY. Inspect with tools. Do not modify the game unless the user explicitly asked to change something.")
		table.insert(lines, "Report: hierarchy highlights, notable scripts/remotes, players, risks. Be concrete.")
	else
		table.insert(lines, "ACTION mission: perform the requested changes/creations with tools.")
		table.insert(lines, "When done, summarize what changed.")
	end
	table.insert(lines, "Never ask which game — it is this Roblox session.")
	return table.concat(lines, "\n")
end

-- ═══════════════════════════════════════════
-- MAIN APP
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
	local PANEL_W, PANEL_H = 340, 360

	local mode = "idle"
	local clarifyCount = 0
	local missionBrief = { original = "", answers = {}, kind = "action" }
	local history = {}
	local busy = false
	local missionRunning = false
	local exprState = "idle"
	local animToken = 0

	-- preload UAI in background (non-blocking)
	task.spawn(function()
		local ok, err = ensureUAI(false)
		if ok then
			print("[Capri] UAI preloaded.")
		else
			warn("[Capri] UAI preload falló (se reintentará en misión):", err)
		end
	end)

	local sprite = Instance.new("ImageButton")
	sprite.Name = "CapriSprite"
	sprite.Size = UDim2.fromOffset(76, 76)
	sprite.Position = UDim2.new(1, -94, 0.45, 0)
	sprite.BackgroundColor3 = Theme.bg
	sprite.BackgroundTransparency = 0.15
	sprite.BorderSizePixel = 0
	sprite.Image = pickImage("Cutout", "Face", "FaceCalm")
	sprite.ScaleType = Enum.ScaleType.Crop
	sprite.AutoButtonColor = false
	sprite.ZIndex = 10
	sprite.Parent = gui
	Instance.new("UICorner", sprite).CornerRadius = UDim.new(1, 0)
	local spriteStroke = Instance.new("UIStroke", sprite)
	spriteStroke.Color = Theme.accent
	spriteStroke.Thickness = 2
	spriteStroke.Transparency = 0.25

	local spriteFallback = Instance.new("TextLabel")
	spriteFallback.Size = UDim2.fromScale(1, 1)
	spriteFallback.BackgroundTransparency = 1
	spriteFallback.Text = (sprite.Image == "" and "C") or ""
	spriteFallback.TextColor3 = Theme.accent
	spriteFallback.Font = Enum.Font.GothamBlack
	spriteFallback.TextSize = 28
	spriteFallback.ZIndex = 11
	spriteFallback.Parent = sprite

	local dragging, dragMoved, dragStart, startPos = false, false, nil, nil
	local baseY = sprite.Position.Y.Offset
	do
		local t0 = os.clock()
		RunService.RenderStepped:Connect(function()
			if dragging then return end
			local wave = math.sin((os.clock() - t0) * 1.4) * 3.5
			local pos = sprite.Position
			sprite.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, baseY + wave)
		end)
	end

	sprite.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragMoved = false
			dragStart = input.Position
			startPos = sprite.Position
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
			local delta = input.Position - dragStart
			if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then dragMoved = true end
			sprite.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			baseY = sprite.Position.Y.Offset
		end
	end)

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.Position = UDim2.new(1, -PANEL_W - 100, 0.45, -PANEL_H / 2 + 32)
	panel.BackgroundColor3 = Theme.panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 20
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local ps = Instance.new("UIStroke", panel)
	ps.Color = Theme.border
	ps.Thickness = 1.5
	ps.Transparency = 0.35

	local plate = Instance.new("Frame")
	plate.Size = UDim2.new(1, -16, 1, -16)
	plate.Position = UDim2.fromOffset(8, 8)
	plate.BackgroundColor3 = Theme.plate
	plate.BorderSizePixel = 0
	plate.ZIndex = 21
	plate.Parent = panel
	Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 8)

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 48)
	header.BackgroundTransparency = 1
	header.ZIndex = 22
	header.Parent = plate

	local face = Instance.new("Frame")
	face.Size = UDim2.fromOffset(40, 40)
	face.Position = UDim2.fromOffset(8, 4)
	face.BackgroundColor3 = Theme.bg
	face.BorderSizePixel = 0
	face.ClipsDescendants = true
	face.ZIndex = 23
	face.Parent = header
	Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)
	local fs = Instance.new("UIStroke", face)
	fs.Color = Theme.green
	fs.Thickness = 1.5

	local faceImg = Instance.new("ImageLabel")
	faceImg.Size = UDim2.fromScale(1, 1)
	faceImg.BackgroundTransparency = 1
	faceImg.Image = pickImage("FaceCalm", "FaceLook", "Face")
	faceImg.ScaleType = Enum.ScaleType.Crop
	faceImg.ZIndex = 24
	faceImg.Parent = face

	local faceFallback = Instance.new("TextLabel")
	faceFallback.Size = UDim2.fromScale(1, 1)
	faceFallback.BackgroundTransparency = 1
	faceFallback.Text = (faceImg.Image == "" and "◈") or ""
	faceFallback.TextColor3 = Theme.green
	faceFallback.Font = Enum.Font.GothamBold
	faceFallback.TextSize = 16
	faceFallback.ZIndex = 25
	faceFallback.Parent = face

	local cutin = Instance.new("ImageLabel")
	cutin.Size = UDim2.fromOffset(120, 120)
	cutin.Position = UDim2.new(0.5, -60, 0.32, -60)
	cutin.BackgroundTransparency = 1
	cutin.Image = ""
	cutin.Visible = false
	cutin.ZIndex = 40
	cutin.Parent = panel

	local who = Instance.new("TextLabel")
	who.Size = UDim2.new(1, -100, 0, 20)
	who.Position = UDim2.fromOffset(56, 6)
	who.BackgroundTransparency = 1
	who.Text = "Capri"
	who.TextColor3 = Theme.accent
	who.Font = Enum.Font.GothamBold
	who.TextSize = 15
	who.TextXAlignment = Enum.TextXAlignment.Left
	who.ZIndex = 23
	who.Parent = header

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -100, 0, 16)
	status.Position = UDim2.fromOffset(56, 26)
	status.BackgroundTransparency = 1
	status.Text = "línea abierta"
	status.TextColor3 = Theme.textDim
	status.Font = Enum.Font.Code
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 23
	status.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(28, 28)
	closeBtn.Position = UDim2.new(1, -36, 0, 10)
	closeBtn.BackgroundColor3 = Theme.bg
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Theme.textDim
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.AutoButtonColor = false
	closeBtn.ZIndex = 24
	closeBtn.Parent = header
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

	local body = Instance.new("ScrollingFrame")
	body.Size = UDim2.new(1, -12, 1, -108)
	body.Position = UDim2.fromOffset(6, 52)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Theme.accent
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = 22
	body.Parent = plate
	local bodyLayout = Instance.new("UIListLayout", body)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Padding = UDim.new(0, 8)
	local bodyPad = Instance.new("UIPadding", body)
	bodyPad.PaddingTop = UDim.new(0, 4)
	bodyPad.PaddingBottom = UDim.new(0, 4)
	bodyPad.PaddingLeft = UDim.new(0, 4)
	bodyPad.PaddingRight = UDim.new(0, 4)

	local inputBar = Instance.new("Frame")
	inputBar.Size = UDim2.new(1, -12, 0, 40)
	inputBar.Position = UDim2.new(0, 6, 1, -48)
	inputBar.BackgroundColor3 = Theme.inputBg
	inputBar.BorderSizePixel = 0
	inputBar.ZIndex = 22
	inputBar.Parent = plate
	Instance.new("UICorner", inputBar).CornerRadius = UDim.new(0, 8)

	local inputBox = Instance.new("TextBox")
	inputBox.Size = UDim2.new(1, -84, 1, -8)
	inputBox.Position = UDim2.fromOffset(10, 4)
	inputBox.BackgroundTransparency = 1
	inputBox.PlaceholderText = "Habla…  (!misión en ESTE juego)"
	inputBox.PlaceholderColor3 = Theme.textDim
	inputBox.Text = ""
	inputBox.TextColor3 = Theme.text
	inputBox.Font = Enum.Font.Code
	inputBox.TextSize = 13
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus = false
	inputBox.ZIndex = 23
	inputBox.Parent = inputBar

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.fromOffset(68, 30)
	sendBtn.Position = UDim2.new(1, -74, 0.5, -15)
	sendBtn.BackgroundColor3 = Theme.accent
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "Enviar"
	sendBtn.TextColor3 = Color3.new(1, 1, 1)
	sendBtn.Font = Enum.Font.GothamBold
	sendBtn.TextSize = 12
	sendBtn.AutoButtonColor = false
	sendBtn.ZIndex = 24
	sendBtn.Parent = inputBar
	Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 6)

	local panelOpen = false
	local function setStatus(txt) status.Text = txt end

	local idleFaces = { "FaceCalm", "FaceLook", "FaceAside", "FaceSmug" }
	local talkFaces = { "FaceLook", "FaceSmug", "FaceLaugh" }
	local missionFaces = { "FaceMany", "FaceCalm", "FaceLook" }

