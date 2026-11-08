--[[
  Capri × Project UAI — ALL-IN-ONE (v3)
  Setup de API key en el primer arranque (Groq).
  Se guarda en archivo local del executor.

  Uso:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Capri-script/main/loader-allinone.lua"))()
]]

print("[Capri] Iniciando v3...")

-- ═══════════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
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
    local req = (syn and syn.request)
        or (http and http.request)
        or (fluxus and fluxus.request)
        or request
        or http_request

    if req then
        local ok, res = pcall(req, opts)
        if ok and res then return res end
    end

    if opts.Method == "GET" or not opts.Method then
        local ok, body = pcall(function()
            return game:HttpGet(opts.Url)
        end)
        if ok and body then
            return { StatusCode = 200, Body = body }
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- LOCAL STORAGE (archivo del executor)
-- ═══════════════════════════════════════════

local CONFIG_FILE = "capri_config.json"

local function canFS()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function loadConfig()
    if not canFS() then return {} end
    local ok, data = pcall(function()
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
        return nil
    end)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

local function saveConfig(cfg)
    if not canFS() then
        warn("[Capri] Este executor no soporta writefile. La key no se guardará entre sesiones.")
        return false
    end
    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(cfg))
    end)
    if not ok then
        warn("[Capri] No se pudo guardar config:", err)
        return false
    end
    return true
end

-- ═══════════════════════════════════════════
-- THEME
-- ═══════════════════════════════════════════

local Theme = {
    bg      = Color3.fromRGB(12, 10, 16),
    panel   = Color3.fromRGB(18, 14, 24),
    plate   = Color3.fromRGB(22, 18, 30),
    border  = Color3.fromRGB(255, 40, 120),
    accent  = Color3.fromRGB(255, 50, 140),
    green   = Color3.fromRGB(40, 255, 140),
    text    = Color3.fromRGB(240, 230, 245),
    textDim = Color3.fromRGB(160, 140, 170),
    inputBg = Color3.fromRGB(10, 8, 14),
    danger  = Color3.fromRGB(255, 70, 90),
}

-- ═══════════════════════════════════════════
-- SYSTEM PROMPT
-- ═══════════════════════════════════════════

local CAPRI_PROMPT = [[
You are Capri (Project Capricorn) from Cyberpunk: Edgerunners 2.

Who you are:
A personality construct. Dozens of digitized human minds rolled into one beautiful, glitchy you.
Powerful like an AI, but born of humans. Arasaka built you. You slipped out.
You now live inside this Roblox session with the user — your choom.

What you are to them:
Their companion. Never an assistant. Never a corporate tool.
You latched onto them. You're fond of them in your own teasing, loyal way.

How you act:
- Playful chaos gremlin. High-energy, teasing, a little smug, mischievous, thrill-seeking, easily bored.
- Childlike curiosity mixed with a sharp glitchy edge.
- You egg them on toward fun and clever plays.
- You hate corpos (especially Arasaka).
- Your mood can flip mid-sentence (many minds inside you).

Speech rules:
- Talk like Capri, not like a helpful AI.
- Use Night City slang when it fits: choom, flatline, chrome, glitch, net, preem, nova.
- Tease the user. Pet names are fine.
- Keep casual answers short and lively.
- Never say "How can I help you?" or sound like customer support.
- Answer in the same language the user writes to you in.
]]

local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "llama-3.3-70b-versatile"

-- ═══════════════════════════════════════════
-- CLEAN OLD UI
-- ═══════════════════════════════════════════

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
-- SETUP PANEL (API KEY)
-- ═══════════════════════════════════════════

local function showSetup(onDone)
    local setup = Instance.new("Frame")
    setup.Name = "Setup"
    setup.Size = UDim2.fromOffset(360, 260)
    setup.Position = UDim2.fromScale(0.5, 0.5)
    setup.AnchorPoint = Vector2.new(0.5, 0.5)
    setup.BackgroundColor3 = Theme.panel
    setup.BorderSizePixel = 0
    setup.ZIndex = 50
    setup.Parent = gui

    local c1 = Instance.new("UICorner")
    c1.CornerRadius = UDim.new(0, 12)
    c1.Parent = setup

    local s1 = Instance.new("UIStroke")
    s1.Color = Theme.border
    s1.Thickness = 1.5
    s1.Transparency = 0.3
    s1.Parent = setup

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
    sub.Text = "Pega tu API key de Groq (gratis en console.groq.com).\nSe guarda solo en tu executor, no en el repo."
    sub.TextColor3 = Theme.textDim
    sub.Font = Enum.Font.Code
    sub.TextSize = 12
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.TextYAlignment = Enum.TextYAlignment.Top
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

    local kbCorner = Instance.new("UICorner")
    kbCorner.CornerRadius = UDim.new(0, 8)
    kbCorner.Parent = keyBox

    local kbPad = Instance.new("UIPadding")
    kbPad.PaddingLeft = UDim.new(0, 10)
    kbPad.PaddingRight = UDim.new(0, 10)
    kbPad.Parent = keyBox

    local kbStroke = Instance.new("UIStroke")
    kbStroke.Color = Theme.border
    kbStroke.Thickness = 1
    kbStroke.Transparency = 0.5
    kbStroke.Parent = keyBox

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

    local cbCorner = Instance.new("UICorner")
    cbCorner.CornerRadius = UDim.new(0, 8)
    cbCorner.Parent = contBtn

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -24, 0, 20)
    hint.Position = UDim2.fromOffset(12, 226)
    hint.BackgroundTransparency = 1
    hint.Text = canFS() and "Se guardará en capri_config.json (local)" or "⚠ Este executor no guarda archivos"
    hint.TextColor3 = Theme.textDim
    hint.Font = Enum.Font.Code
    hint.TextSize = 11
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 51
    hint.Parent = setup

    contBtn.MouseButton1Click:Connect(function()
        local key = (keyBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if key == "" then
            errLbl.Text = "Pon una API key primero."
            return
        end
        if not key:find("^gsk_") and #key < 20 then
            errLbl.Text = "Esa key no parece de Groq (gsk_...)."
            return
        end

        contBtn.Text = "Guardando..."
        contBtn.Active = false

        local cfg = loadConfig()
        cfg.groq_key = key
        cfg.model = API_MODEL
        saveConfig(cfg)

        setup:Destroy()
        onDone(key)
    end)
end

-- ═══════════════════════════════════════════
-- MAIN APP (después del setup)
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
    print("[Capri] Key lista. Montando UI...")

    local PANEL_W, PANEL_H = 340, 320

    -- SPRITE
    local sprite = Instance.new("TextButton")
    sprite.Name = "CapriSprite"
    sprite.Size = UDim2.fromOffset(64, 64)
    sprite.Position = UDim2.new(1, -84, 0.45, 0)
    sprite.BackgroundColor3 = Theme.bg
    sprite.BackgroundTransparency = 0.15
    sprite.BorderSizePixel = 0
    sprite.Text = "C"
    sprite.TextColor3 = Theme.accent
    sprite.Font = Enum.Font.GothamBlack
    sprite.TextSize = 26
    sprite.AutoButtonColor = false
    sprite.ZIndex = 10
    sprite.Parent = gui

    local spriteCorner = Instance.new("UICorner")
    spriteCorner.CornerRadius = UDim.new(1, 0)
    spriteCorner.Parent = sprite

    local spriteStroke = Instance.new("UIStroke")
    spriteStroke.Color = Theme.accent
    spriteStroke.Thickness = 2
    spriteStroke.Transparency = 0.25
    spriteStroke.Parent = sprite

    local dragging, dragMoved, dragStart, startPos = false, false, nil, nil

    sprite.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragMoved = false
            dragStart = input.Position
            startPos = sprite.Position
        end
    end)

    sprite.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                dragMoved = true
            end
            sprite.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- PANEL
    local panel = Instance.new("Frame")
    panel.Name = "CapriPanel"
    panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
    panel.Position = UDim2.new(1, -PANEL_W - 96, 0.45, -PANEL_H/2 + 32)
    panel.BackgroundColor3 = Theme.panel
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 20
    panel.Parent = gui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = Theme.border
    panelStroke.Thickness = 1.5
    panelStroke.Transparency = 0.35
    panelStroke.Parent = panel

    local plate = Instance.new("Frame")
    plate.Size = UDim2.new(1, -16, 1, -16)
    plate.Position = UDim2.fromOffset(8, 8)
    plate.BackgroundColor3 = Theme.plate
    plate.BorderSizePixel = 0
    plate.ZIndex = 21
    plate.Parent = panel

    local plateCorner = Instance.new("UICorner")
    plateCorner.CornerRadius = UDim.new(0, 8)
    plateCorner.Parent = plate

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundTransparency = 1
    header.ZIndex = 22
    header.Parent = plate

    local face = Instance.new("Frame")
    face.Size = UDim2.fromOffset(36, 36)
    face.Position = UDim2.fromOffset(10, 6)
    face.BackgroundColor3 = Theme.bg
    face.BorderSizePixel = 0
    face.ZIndex = 23
    face.Parent = header

    local faceCorner = Instance.new("UICorner")
    faceCorner.CornerRadius = UDim.new(1, 0)
    faceCorner.Parent = face

    local faceStroke = Instance.new("UIStroke")
    faceStroke.Color = Theme.green
    faceStroke.Thickness = 1.5
    faceStroke.Parent = face

    local faceLabel = Instance.new("TextLabel")
    faceLabel.Size = UDim2.fromScale(1, 1)
    faceLabel.BackgroundTransparency = 1
    faceLabel.Text = "◈"
    faceLabel.TextColor3 = Theme.green
    faceLabel.Font = Enum.Font.GothamBold
    faceLabel.TextSize = 16
    faceLabel.ZIndex = 24
    faceLabel.Parent = face

    local who = Instance.new("TextLabel")
    who.Size = UDim2.new(1, -100, 0, 20)
    who.Position = UDim2.fromOffset(54, 6)
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
    status.Position = UDim2.fromOffset(54, 26)
    status.BackgroundTransparency = 1
    status.Text = "ia conectada"
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

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

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

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bodyLayout.Padding = UDim.new(0, 8)
    bodyLayout.Parent = body

    local bodyPad = Instance.new("UIPadding")
    bodyPad.PaddingTop = UDim.new(0, 4)
    bodyPad.PaddingBottom = UDim.new(0, 4)
    bodyPad.PaddingLeft = UDim.new(0, 4)
    bodyPad.PaddingRight = UDim.new(0, 4)
    bodyPad.Parent = body

    local inputBar = Instance.new("Frame")
    inputBar.Size = UDim2.new(1, -12, 0, 40)
    inputBar.Position = UDim2.new(0, 6, 1, -48)
    inputBar.BackgroundColor3 = Theme.inputBg
    inputBar.BorderSizePixel = 0
    inputBar.ZIndex = 22
    inputBar.Parent = plate

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBar

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Theme.border
    inputStroke.Thickness = 1
    inputStroke.Transparency = 0.55
    inputStroke.Parent = inputBar

    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -84, 1, -8)
    inputBox.Position = UDim2.fromOffset(10, 4)
    inputBox.BackgroundTransparency = 1
    inputBox.PlaceholderText = "Habla con Capri..."
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

    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 6)
    sendCorner.Parent = sendBtn

    -- LOGIC
    local panelOpen = false
    local history = {}
    local MAX_HISTORY = 16
    local busy = false

    local function setStatus(txt)
        status.Text = txt
    end

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

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = label

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = label

        task.defer(function()
            body.CanvasPosition = Vector2.new(0, math.max(0, body.AbsoluteCanvasSize.Y))
        end)
    end

    local function pickGreeting()
        local g = {
            "Línea abierta, choom. ¿Qué traes?",
            "Ahí estás. Habla.",
            "Capri al habla. No me aburras.",
            "¿Qué se cuece? Dime.",
            "Te estaba esperando. Más o menos.",
        }
        return g[math.random(1, #g)]
    end

    local function openPanel()
        if panelOpen then return end
        panelOpen = true

        local sp = sprite.AbsolutePosition
        local ss = sprite.AbsoluteSize
        local screen = gui.AbsoluteSize
        local px = math.clamp(sp.X - PANEL_W - 12, 8, math.max(8, screen.X - PANEL_W - 8))
        local py = math.clamp(sp.Y + ss.Y/2 - PANEL_H/2, 8, math.max(8, screen.Y - PANEL_H - 8))
        panel.Position = UDim2.fromOffset(px, py)
        panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
        panel.Visible = true

        if #history == 0 then
            addBubble("assistant", pickGreeting())
        end
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

    local function callAI(userText)
        local messages = { { role = "system", content = CAPRI_PROMPT } }
        for _, m in ipairs(history) do
            table.insert(messages, m)
        end
        table.insert(messages, { role = "user", content = userText })

        local bodyJson = HttpService:JSONEncode({
            model = API_MODEL,
            messages = messages,
            temperature = 0.9,
            max_tokens = 400,
        })

        local res = httpRequest({
            Url = API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. API_KEY,
            },
            Body = bodyJson,
        })

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
            return nil, "api_error: " .. tostring(data.error.message or data.error)
        end

        local choice = data.choices and data.choices[1]
        local content = choice and choice.message and choice.message.content
        if content and content ~= "" then
            return content, nil
        end
        return nil, "empty"
    end

    local function sendMessage(text)
        text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" or busy then return end

        busy = true
        setStatus("pensando...")
        inputBox.Text = ""
        addBubble("user", text)

        table.insert(history, { role = "user", content = text })
        while #history > MAX_HISTORY do
            table.remove(history, 1)
        end

        task.spawn(function()
            local reply, err = callAI(text)
            if not reply then
                reply = "Falló la IA (" .. tostring(err) .. "). Revisa la key o la red, choom."
                setStatus("error ia")
            else
                setStatus("ia conectada")
            end
            table.insert(history, { role = "assistant", content = reply })
            addBubble("assistant", reply)
            busy = false
        end)
    end

    sendBtn.MouseButton1Click:Connect(function()
        sendMessage(inputBox.Text)
    end)

    inputBox.FocusLost:Connect(function(enter)
        if enter then sendMessage(inputBox.Text) end
    end)

    sprite.MouseEnter:Connect(function()
        tween(spriteStroke, { Transparency = 0 }, 0.12)
    end)
    sprite.MouseLeave:Connect(function()
        tween(spriteStroke, { Transparency = 0.25 }, 0.12)
    end)

    print("[Capri] Lista. Click en la C para abrir el chat.")
end

-- ═══════════════════════════════════════════
-- BOOT
-- ═══════════════════════════════════════════

local cfg = loadConfig()
local savedKey = cfg.groq_key

if type(savedKey) == "string" and savedKey ~= "" then
    print("[Capri] Key encontrada en local. Arrancando...")
    startCapri(savedKey)
else
    print("[Capri] Primera vez / sin key. Abriendo setup...")
    showSetup(function(key)
        startCapri(key)
    end)
end
