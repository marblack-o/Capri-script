	local function applyFace(keys)
		local img = pickImage(table.unpack(keys))
		if img ~= "" then
			faceImg.Image = img
			faceFallback.Text = ""
		end
	end

	local function flashCutin(key)
		local img = pickImage(key)
		if img == "" then return end
		cutin.Image = img
		cutin.ImageTransparency = 0.1
		cutin.Visible = true
		cutin.Size = UDim2.fromOffset(70, 70)
		tween(cutin, { Size = UDim2.fromOffset(128, 128) }, 0.16, Enum.EasingStyle.Back)
		task.delay(0.95, function()
			local t = tween(cutin, { ImageTransparency = 1 }, 0.22)
			t.Completed:Wait()
			cutin.Visible = false
			cutin.ImageTransparency = 0
		end)
	end

	local function setExpression(state)
		exprState = state
		animToken = animToken + 1
		local token = animToken

		if state == "talking" then
			applyFace(talkFaces)
			tween(spriteStroke, { Color = Theme.accent, Transparency = 0 }, 0.12)
			tween(fs, { Color = Theme.accent }, 0.12)
			tween(sprite, { Size = UDim2.fromOffset(84, 84) }, 0.1)
			task.delay(0.28, function()
				if animToken == token then
					tween(sprite, { Size = UDim2.fromOffset(76, 76) }, 0.18)
				end
			end)
		elseif state == "mission" then
			applyFace(missionFaces)
			tween(spriteStroke, { Color = Theme.green, Transparency = 0 }, 0.15)
			tween(fs, { Color = Theme.green }, 0.15)
			task.spawn(function()
				local i = 1
				while animToken == token and exprState == "mission" do
					tween(spriteStroke, { Transparency = 0.05 }, 0.35)
					task.wait(0.4)
					if animToken ~= token then break end
					tween(spriteStroke, { Transparency = 0.4 }, 0.35)
					task.wait(0.4)
					if animToken ~= token then break end
					i = (i % #missionFaces) + 1
					applyFace({ missionFaces[i] })
				end
			end)
		elseif state == "done" then
			applyFace({ "FaceLaugh", "FaceSmug", "FaceLook" })
			flashCutin("Grin")
			tween(spriteStroke, { Color = Theme.green, Transparency = 0 }, 0.12)
			tween(fs, { Color = Theme.green }, 0.12)
			task.delay(1.5, function()
				if animToken == token then setExpression("idle") end
			end)
		elseif state == "error" then
			applyFace({ "FaceWide", "FaceMany", "FaceLook" })
			flashCutin("Eyes")
			tween(spriteStroke, { Color = Theme.danger, Transparency = 0 }, 0.12)
			tween(fs, { Color = Theme.danger }, 0.12)
			task.delay(1.7, function()
				if animToken == token then setExpression("idle") end
			end)
		else
			applyFace({ "FaceCalm", "FaceLook" })
			tween(spriteStroke, { Color = Theme.accent, Transparency = 0.25 }, 0.22)
			tween(fs, { Color = Theme.green }, 0.22)
			task.spawn(function()
				local i = 1
				while animToken == token and exprState == "idle" do
					task.wait(2.8 + math.random() * 1.8)
					if animToken ~= token or exprState ~= "idle" then break end
					i = (i % #idleFaces) + 1
					applyFace({ idleFaces[i] })
				end
			end)
		end
	end

	setExpression("idle")

	local function addBubble(role, text)
		local bubble = Instance.new("Frame")
		bubble.Size = UDim2.new(1, -4, 0, 0)
		bubble.AutomaticSize = Enum.AutomaticSize.Y
		bubble.BackgroundTransparency = 1
		bubble.LayoutOrder = #body:GetChildren() + 1
		bubble.ZIndex = 23
		bubble.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundColor3 = role == "user" and Color3.fromRGB(30, 22, 40) or Theme.bg
		label.BackgroundTransparency = 0.15
		label.BorderSizePixel = 0
		label.Text = tostring(text)
		label.TextColor3 = role == "user" and Theme.textDim or Theme.text
		label.Font = Enum.Font.Code
		label.TextSize = 13
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.ZIndex = 24
		label.Parent = bubble
		local p = Instance.new("UIPadding", label)
		p.PaddingTop = UDim.new(0, 8)
		p.PaddingBottom = UDim.new(0, 8)
		p.PaddingLeft = UDim.new(0, 10)
		p.PaddingRight = UDim.new(0, 10)
		Instance.new("UICorner", label).CornerRadius = UDim.new(0, 6)
		task.defer(function()
			body.CanvasPosition = Vector2.new(0, math.max(0, body.AbsoluteCanvasSize.Y))
		end)
	end

	local function pickGreeting()
		local g = {
			"Línea abierta. Charla libre o !misión en este juego.",
			"Capri al habla. !analiza el juego si quieres que escarbe.",
			"Ahí estás, choom. ¿Charla o misión?",
		}
		return g[math.random(1, #g)]
	end

	local function openPanel()
		if panelOpen then return end
		panelOpen = true
		local sp, ss = sprite.AbsolutePosition, sprite.AbsoluteSize
		local screen = gui.AbsoluteSize
		local px = math.clamp(sp.X - PANEL_W - 12, 8, math.max(8, screen.X - PANEL_W - 8))
		local py = math.clamp(sp.Y + ss.Y / 2 - PANEL_H / 2, 8, math.max(8, screen.Y - PANEL_H - 8))
		panel.Position = UDim2.fromOffset(px, py)
		panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
		panel.Visible = true
		if #history == 0 then addBubble("assistant", pickGreeting()) end
	end

	local function closePanel()
		if not panelOpen then return end
		panelOpen = false
		panel.Visible = false
	end

	sprite.MouseButton1Click:Connect(function()
		if dragMoved then return end
		if panelOpen then closePanel() else openPanel() end
	end)
	closeBtn.MouseButton1Click:Connect(closePanel)

	local function startMission()
		mode = "mission"
		missionRunning = true
		setStatus("misión en curso")
		setExpression("mission")
		addBubble("assistant", "Iniciando misión, choom. Escarbando este juego.")

		local prompt = buildMissionPrompt(missionBrief)
		local missionKind = missionBrief.kind
		print("[Capri] Mission prompt:\n" .. prompt)

		runUAIMission(prompt, function(ok, resultText)
			missionRunning = false
			mode = "idle"
			clarifyCount = 0
			missionBrief = { original = "", answers = {}, kind = "action" }

			if not ok then
				setStatus("misión fallida")
				setExpression("error")
				local tip = tostring(resultText)
				if tip:lower():find("provider") or tip:lower():find("sesión") or tip:lower():find("uai") then
					tip = tip .. "\n\nTip: ejecuta Project UAI solo, acepta storage/password y configura un provider. Luego reintenta la !misión."
				end
				addBubble("assistant", "La misión se torció:\n" .. tip)
				return
			end

			if missionKind == "research" then
				setStatus("traduciendo...")
				setExpression("talking")
				local rewriteMsgs = {
					{ role = "system", content = CAPRI_PROMPT .. "\n\nRaw report from the Roblox agent about THIS game. Retell in Capri voice. Keep facts. Concise." },
					{ role = "user", content = "Report:\n" .. tostring(resultText) },
				}
				local rewritten, err = groqChat(API_KEY, rewriteMsgs, 700)
				setStatus("ia conectada")
				setExpression("done")
				if rewritten then
					addBubble("assistant", rewritten)
				else
					addBubble("assistant", "Misión lista (sin maquillaje de voz):\n" .. tostring(resultText))
				end
			else
				setStatus("ia conectada")
				setExpression("done")
				addBubble("assistant", "Tu petición ha terminado, choom.\n" .. tostring(resultText))
			end
		end)
	end

	local function beginMissionFlow(cleanText)
		missionBrief = {
			original = cleanText,
			answers = {},
			kind = detectKind(cleanText),
		}
		clarifyCount = 0

		if isMissionClear(cleanText) then
			mode = "mission"
			addBubble("assistant", "Claro — este juego, ahora. Lanzo la misión.")
			startMission()
			return
		end

		mode = "clarifying"
		setStatus("aclarando misión")
		setExpression("talking")

		local sys = CAPRI_PROMPT .. [[

The user started a Roblox mission with '!'.
Context: they are already inside a live Roblox place. "The game" ALWAYS means this DataModel.
Ask at most ONE short clarifying question only if a real choice is missing (what to create, which property, which player).
NEVER ask which game/title.
If clear enough, reply with first line exactly:
READY_FOR_MISSION
Then one short Capri line.
Max clarifying questions total: ]] .. tostring(MAX_CLARIFY)

		local reply, err = groqChat(API_KEY, {
			{ role = "system", content = sys },
			{ role = "user", content = cleanText },
		}, 250)

		if not reply then
			-- si Groq falla pero el pedido parece accionable, igual intenta misión
			addBubble("assistant", "No pude aclarar (" .. tostring(err) .. "). Lanzo igual sobre este juego.")
			startMission()
			return
		end

		if reply:find("READY_FOR_MISSION") or isMissionClear(cleanText) then
			local summary = reply:gsub("READY_FOR_MISSION", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if summary ~= "" then addBubble("assistant", summary) end
			startMission()
		else
			clarifyCount = 1
			addBubble("assistant", reply)
			setExpression("idle")
			setStatus("aclarando misión (1/" .. MAX_CLARIFY .. ")")
		end
	end

	local function handleClarify(userText)
		table.insert(missionBrief.answers, userText)
		clarifyCount = clarifyCount + 1
		setExpression("talking")

		local sys = CAPRI_PROMPT .. [[

Collecting mission details for UAI in THIS Roblox game.
Already asked: ]] .. tostring(clarifyCount) .. "/" .. tostring(MAX_CLARIFY) .. [[.
Never ask which game. If enough info, first line:
READY_FOR_MISSION
Else one short question.
]]

		local reply, err = groqChat(API_KEY, {
			{ role = "system", content = sys },
			{ role = "user", content = "Original: " .. missionBrief.original .. "\nAnswer: " .. userText },
		}, 250)

		if not reply then
			addBubble("assistant", "Glitch (" .. tostring(err) .. "). Lanzo con lo que hay.")
			startMission()
			return
		end

		if reply:find("READY_FOR_MISSION") or clarifyCount >= MAX_CLARIFY then
			local summary = reply:gsub("READY_FOR_MISSION", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if summary ~= "" and clarifyCount < MAX_CLARIFY then addBubble("assistant", summary) end
			startMission()
		else
			addBubble("assistant", reply)
			setExpression("idle")
			setStatus("aclarando misión (" .. clarifyCount .. "/" .. MAX_CLARIFY .. ")")
		end
	end

	local function sendMessage(text)
		text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if text == "" or busy then return end
		busy = true
		inputBox.Text = ""
		addBubble("user", text)
		table.insert(history, { role = "user", content = text })

		task.spawn(function()
			if mode == "clarifying" then
				setStatus("pensando...")
				handleClarify(text)
				busy = false
				return
			end

			if mode == "idle" and text:sub(1, 1) == "!" and not missionRunning then
				local cleanText = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
				if cleanText == "" then
					addBubble("assistant", "Pon algo después del '!'. Ej: !analiza el juego")
					busy = false
					return
				end
				beginMissionFlow(cleanText)
				busy = false
				return
			end

			setStatus(missionRunning and "misión + charla" or "pensando...")
			setExpression("talking")
			local msgs = { { role = "system", content = CAPRI_PROMPT } }
			for _, m in ipairs(history) do table.insert(msgs, m) end
			if missionRunning then
				table.insert(msgs, { role = "system", content = "A background mission is running on THIS Roblox game. Chat casually; don't pretend it finished." })
			end
			local reply, err = groqChat(API_KEY, msgs, 400)
			if not reply then
				addBubble("assistant", "Falló la IA (" .. tostring(err) .. ").")
				setExpression("error")
				setStatus("error ia")
			else
				table.insert(history, { role = "assistant", content = reply })
				addBubble("assistant", reply)
				setExpression(missionRunning and "mission" or "idle")
				setStatus(missionRunning and "misión en curso" or "ia conectada")
			end
			while #history > 20 do table.remove(history, 1) end
			busy = false
		end)
	end

	sendBtn.MouseButton1Click:Connect(function() sendMessage(inputBox.Text) end)
	inputBox.FocusLost:Connect(function(enter) if enter then sendMessage(inputBox.Text) end end)
	sprite.MouseEnter:Connect(function() tween(spriteStroke, { Transparency = 0 }, 0.12) end)
	sprite.MouseLeave:Connect(function()
		if exprState == "idle" then tween(spriteStroke, { Transparency = 0.25 }, 0.12) end
	end)

	print("[Capri] Lista v5.1")
	print("[Capri] Chat libre · !misión en ESTE juego · UAI en background")
end

-- BOOT
local cfg = loadConfig()
if type(cfg.model) == "string" and cfg.model ~= "" then
	if cfg.model == "llama-3.3-70b-versatile" or cfg.model == "llama-3.1-70b-versatile" then
		cfg.model = API_MODEL
		saveConfig(cfg)
	else
		API_MODEL = cfg.model
	end
end

local savedKey = cfg.groq_key
if type(savedKey) == "string" and savedKey ~= "" then
	print("[Capri] Key local OK.")
	startCapri(savedKey)
else
	print("[Capri] Setup de key...")
	showSetup(function(key) startCapri(key) end)
end
