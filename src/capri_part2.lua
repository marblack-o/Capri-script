        if uaiHandle.sdk and uaiHandle.sdk.request then
            local done = false
            uaiHandle.sdk.request(session, missionPrompt, {
                onComplete = function(result)
                    if done then return end
                    done = true
                    if result and result.ok then
                        onComplete(true, result.text or result.output or "Misión completada.")
                    else
                        onComplete(false, (result and result.error) or "UAI falló sin detalle")
                    end
                end,
            })
            task.delay(240, function()
                if not done then
                    done = true
                    onComplete(false, "Timeout de misión UAI (4 min)")
                end
            end)
        else
            onComplete(false, "SDK request no disponible en esta build de UAI")
        end
    end)
end

-- ═══════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
    local PANEL_W, PANEL_H = 340, 360

    local mode = "idle"
    local clarifyCount = 0
    local missionBrief = { original = "", answers = {}, kind = "action" }
    local history = {}
    local busy = false
    local missionRunning = false

    -- expression state
    local exprState = "idle" -- idle | talking | mission | done | error
    local animToken = 0

    -- SPRITE
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
            local wave = math.sin((os.clock() - t0) * 1.6) * 4
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

    -- PANEL
    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
    panel.Position = UDim2.new(1, -PANEL_W - 100, 0.45, -PANEL_H/2 + 32)
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

    -- cut-in overlay (brief)
    local cutin = Instance.new("ImageLabel")
    cutin.Size = UDim2.fromOffset(120, 120)
    cutin.Position = UDim2.new(0.5, -60, 0.35, -60)
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
    inputBox.PlaceholderText = "Habla con Capri...  (!misión)"
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

    -- ── EXPRESSION ENGINE ──
    local idleFaces = { "FaceCalm", "FaceLook", "FaceAside", "FaceSmug" }
    local talkFaces = { "FaceLook", "FaceSmug", "FaceLaugh" }
    local missionFaces = { "FaceMany", "FaceCalm", "FaceLook" }

    local function applyFace(keys)
        local img = pickImage(table.unpack(keys))
        if img ~= "" then
            faceImg.Image = img
            faceFallback.Text = ""
            -- also nudge sprite if we have matching portrait-ish
            if keys[1] == "FaceLaugh" or keys[1] == "FaceWide" then
                local s = pickImage(keys[1], "Face", "Cutout")
                if s ~= "" then sprite.Image = s; spriteFallback.Text = "" end
            end
        end
    end

    local function flashCutin(key)
        local img = pickImage(key)
        if img == "" then return end
        cutin.Image = img
        cutin.ImageTransparency = 0.15
        cutin.Visible = true
        cutin.Size = UDim2.fromOffset(80, 80)
        tween(cutin, { Size = UDim2.fromOffset(130, 130) }, 0.18, Enum.EasingStyle.Back)
        task.delay(1.1, function()
            local t = tween(cutin, { ImageTransparency = 1 }, 0.25)
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
            applyFace({"FaceLook", "FaceSmug", "FaceLaugh"})
            tween(spriteStroke, { Color = Theme.accent, Transparency = 0 }, 0.15)
            tween(fs, { Color = Theme.accent }, 0.15)
            tween(sprite, { Size = UDim2.fromOffset(82, 82) }, 0.12)
            task.delay(0.35, function()
                if animToken == token then
                    tween(sprite, { Size = UDim2.fromOffset(76, 76) }, 0.2)
                end
            end)
        elseif state == "mission" then
            applyFace({"FaceMany", "FaceCalm", "FaceLook"})
            tween(spriteStroke, { Color = Theme.green, Transparency = 0 }, 0.2)
            tween(fs, { Color = Theme.green }, 0.2)
            -- pulse stroke while mission
            task.spawn(function()
                while animToken == token and exprState == "mission" do
                    tween(spriteStroke, { Transparency = 0.05 }, 0.4)
                    task.wait(0.45)
                    if animToken ~= token then break end
                    tween(spriteStroke, { Transparency = 0.35 }, 0.4)
                    task.wait(0.45)
                end
            end)
        elseif state == "done" then
            applyFace({ "FaceLaugh", "FaceSmug", "FaceLook" })
            flashCutin("Grin")
            tween(spriteStroke, { Color = Theme.green, Transparency = 0 }, 0.15)
            tween(fs, { Color = Theme.green }, 0.15)
            task.delay(1.6, function()
                if animToken == token then setExpression("idle") end
            end)
        elseif state == "error" then
            applyFace({ "FaceWide", "FaceMany", "FaceLook" })
            flashCutin("Eyes")
            tween(spriteStroke, { Color = Theme.danger, Transparency = 0 }, 0.15)
            tween(fs, { Color = Theme.danger }, 0.15)
            task.delay(1.8, function()
                if animToken == token then setExpression("idle") end
            end)
        else -- idle
            applyFace({ "FaceCalm", "FaceLook" })
            tween(spriteStroke, { Color = Theme.accent, Transparency = 0.25 }, 0.25)
            tween(fs, { Color = Theme.green }, 0.25)
            -- idle cycle
            task.spawn(function()
                local i = 1
                while animToken == token and exprState == "idle" do
                    task.wait(2.4 + math.random() * 1.6)
                    if animToken ~= token or exprState ~= "idle" then break end
                    i = (i % #idleFaces) + 1
                    applyFace({ idleFaces[i] })
              
