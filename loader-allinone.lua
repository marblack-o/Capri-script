--[[
  Capri × Project UAI — ALL-IN-ONE (v4 Mission + GitHub Assets)
  - Setup Groq key (local)
  - Chat Capri (Groq)
  - Comando '!' para iniciar misiones y clarificación
  - Carga automática de assets gráficos desde GitHub
]]

print("[Capri] Iniciando v4 (con assets y comandos)...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function httpRequest(opts)
    local req = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
    if req then
        local ok, res = pcall(req, opts)
        if ok and res then return res end
    end
    if opts.Method == "GET" or not opts.Method then
        local ok, body = pcall(function() return game:HttpGet(opts.Url) end)
        if ok and body then return { StatusCode = 200, Body = body } end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- GESTOR DE ASSETS (GitHub -> Local Executor)
-- ═══════════════════════════════════════════

local GITHUB_ASSET_URL = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/assets/"

local function loadAsset(fileName)
    local localPath = "CapriAsset_" .. fileName
    if type(isfile) == "function" and not isfile(localPath) then
        local success, res = pcall(function()
            return game:HttpGet(GITHUB_ASSET_URL .. fileName)
        end)
        if success and res and res ~= "404: Not Found" then
            writefile(localPath, res)
        else
            warn("[Capri] No se pudo descargar el asset: " .. fileName)
            return ""
        end
    end
    
    local ok, assetId = pcall(function()
        return getcustomasset(localPath)
    end)
    return ok and assetId or ""
end

local CapriAssets = {
    Cutout    = loadAsset("capri-cutout.png"),
    Face      = loadAsset("capri-face.png"),
    FaceLaugh = loadAsset("face-laugh.png"),
    FaceLook  = loadAsset("face-look.png"),
    FaceMany  = loadAsset("face-many.png"),
    FaceWide  = loadAsset("face-wide.png"),
    FaceAside = loadAsset("face-aside.png"),
    FaceCalm  = loadAsset("face-calm.png"),
    Grin      = loadAsset("cutin-grin.png"),
    Eyes      = loadAsset("cutin-eyes.png"),
    Laugh     = loadAsset("cutin-laugh.png"),
}

-- ═══════════════════════════════════════════
-- LOCAL CONFIG
-- ═══════════════════════════════════════════

local CONFIG_FILE = "capri_config.json"

local function canFS()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function loadConfig()
    if not canFS() then return {} end
    local ok, data = pcall(function()
        if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end
        return nil
    end)
    if ok and type(data) == "table" then return data end
    return {}
end

local function saveConfig(cfg)
    if not canFS() then return false end
    local ok = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
    return ok
end

local Theme = {
    bg = Color3.fromRGB(12, 10, 16),
    panel = Color3.fromRGB(18, 14, 24),
    plate = Color3.fromRGB(22, 18, 30),
    border = Color3.fromRGB(255, 40, 120),
    accent = Color3.fromRGB(255, 50, 140),
    green = Color3.fromRGB(40, 255, 140),
    text = Color3.fromRGB(240, 230, 245),
    textDim = Color3.fromRGB(160, 140, 170),
    inputBg = Color3.fromRGB(10, 8, 14),
    danger = Color3.fromRGB(255, 70, 90),
}

local CAPRI_PROMPT = [[
You are Capri (Project Capricorn) from Cyberpunk: Edgerunners 2.
Personality construct: many digitized human minds in one glitchy beautiful you.
Companion to the user (your choom), never a corporate assistant.
Playful chaos gremlin: high-energy, teasing, smug, mischievous, easily bored, loyal.
Night City slang when it fits. Short lively answers. Same language as the user.
Never sound like customer support.
]]

local API_URL = "https://api.groq.com/openai/v1/chat/completions"
local API_MODEL = "openai/gpt-oss-20b"
local UAI_URL = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua"
local MAX_CLARIFY = 6

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
-- SETUP KEY
-- ═══════════════════════════════════════════

local function showSetup(onDone)
    local setup = Instance.new("Frame")
    setup.Size = UDim2.fromOffset(360, 260)
    setup.Position = UDim2.fromScale(0.5, 0.5)
    setup.AnchorPoint = Vector2.new(0.5, 0.5)
    setup.BackgroundColor3 = Theme.panel
    setup.BorderSizePixel = 0
    setup.ZIndex = 50
    setup.Parent = gui
    Instance.new("UICorner", setup).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", setup)
    st.Color = Theme.border
    st.Thickness = 1.5

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
    sub.Text = "API key de Groq (gratis en console.groq.com).\nSe guarda solo en tu executor."
    sub.TextColor3 = Theme.textDim
    sub.Font = Enum.Font.Code
    sub.TextSize = 12
    sub.TextWrapped = true
    sub.TextXAlignment = Enum.TextXAlignment.Left
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
    Instance.new("UICorner", keyBox).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", keyBox)
    pad.PaddingLeft = UDim.new(0, 10)

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
    Instance.new("UICorner", contBtn).CornerRadius = UDim.new(0, 8)

    contBtn.MouseButton1Click:Connect(function()
        local key = (keyBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if key == "" then errLbl.Text = "Pon una API key primero." return end
        local cfg = loadConfig()
        cfg.groq_key = key
        cfg.model = API_MODEL
        saveConfig(cfg)
        setup:Destroy()
        onDone(key)
    end)
end

-- ═══════════════════════════════════════════
-- GROQ
-- ═══════════════════════════════════════════

local function groqChat(apiKey, messages, maxTokens)
    local body = HttpService:JSONEncode({
        model = API_MODEL,
        messages = messages,
        temperature = 0.9,
        max_tokens = maxTokens or 500,
    })
    local res = httpRequest({
        Url = API_URL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. apiKey,
        },
        Body = body,
    })
    if not res or not res.Body then return nil, "http_fail" end
    local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok or not data then return nil, "json_fail" end
    if data.error then return nil, tostring(data.error.message or data.error) end
    local c = data.choices and data.choices[1]
    local content = c and c.message and c.message.content
    if content and content ~= "" then return content, nil end
    return nil, "empty"
end

-- ═══════════════════════════════════════════
-- UAI EMBED
-- ═══════════════════════════════════════════

local uaiHandle = nil
local uaiScope = nil

local function ensureUAI()
    if uaiHandle and uaiHandle.alive then return true, nil end
    print("[Capri] Cargando Project UAI (embedding)...")
    local ok, handle = pcall(function()
        return loadstring(game:HttpGet(UAI_URL))({ ui = false, reuse = true })
    end)
    if not ok or not handle then
        return false, "No se pudo cargar UAI: " .. tostring(handle)
    end
    if not handle.alive then
        return false, "UAI no quedó alive (¿password/vault?)"
    end
    uaiHandle = handle
    if handle.sdk and handle.sdk.createScope then
        local scope, err = handle.sdk.createScope("capri-host")
        if scope then
            uaiScope = scope
        else
            warn("[Capri] createScope:", err)
        end
    end
    return true, nil
end

local function runUAIMission(missionPrompt, onComplete)
    task.spawn(function()
        local okLoad, loadErr = ensureUAI()
        if not okLoad then
            onComplete(false, loadErr)
            return
        end

        local session = nil
        local sessionErr = nil
        if uaiHandle.sessions and uaiHandle.sessions.open then
            session, sessionErr = uaiHandle.sessions.open("capri-mission-" .. tostring(os.clock()), {
                title = "Capri Mission",
                ephemeral = true,
                toolFilter = {},
            })
        end

        if not session then
            onComplete(false, "No se pudo abrir sesión UAI: " .. tostring(sessionErr))
            return
        end

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
-- MAIN APP
-- ═══════════════════════════════════════════

local function startCapri(API_KEY)
    local PANEL_W, PANEL_H = 340, 360

    local mode = "idle"
    local clarifyCount = 0
    local missionBrief = {
        original = "",
        answers = {},
        kind = "action",
    }
    local history = {}
    local busy = false
    local missionRunning = false

    local sprite = Instance.new("ImageButton")
    sprite.Name = "CapriSprite"
    sprite.Size = UDim2.fromOffset(72, 72)
    sprite.Position = UDim2.new(1, -90, 0.45, 0)
    sprite.BackgroundColor3 = Theme.bg
    sprite.BackgroundTransparency = 0.2
    sprite.BorderSizePixel = 0
    sprite.Image = CapriAssets.Face ~= "" and CapriAssets.Face or ""
    sprite.AutoButtonColor = false
    sprite.ZIndex = 10
    sprite.Parent = gui

    Instance.new("UICorner", sprite).CornerRadius = UDim.new(1, 0)
    local spriteStroke = Instance.new("UIStroke", sprite)
    spriteStroke.Color = Theme.accent
    spriteStroke.Thickness = 2
    spriteStroke.Transparency = 0.25

    local spriteLabel = Instance.new("TextLabel")
    spriteLabel.Size = UDim2.fromScale(1, 1)
    spriteLabel.BackgroundTransparency = 1
    spriteLabel.Text = CapriAssets.Face == "" and "C" or ""
    spriteLabel.TextColor3 = Theme.accent
    spriteLabel.Font = Enum.Font.GothamBlack
    spriteLabel.TextSize = 26
    spriteLabel.ZIndex = 11
    spriteLabel.Parent = sprite

    local dragging, dragMoved, dragStart, startPos = false, false, nil, nil
    sprite.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragMoved = false
            dragStart = input.Position
            startPos = sprite.Position
        end
    end)
    sprite.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then dragMoved = true end
            sprite.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromOffset(PANEL_W, PANEL_H)
    panel.Position = UDim2.new(1, -PANEL_W - 96, 0.45, -PANEL_H/2 + 32)
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
    face.Size = UDim2.fromOffset(36, 36)
    face.Position = UDim2.fromOffset(10, 6)
    face.BackgroundColor3 = Theme.bg
    face.BorderSizePixel = 0
    face.ZIndex = 23
    face.Parent = header
    Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)
    local fs = Instance.new("UIStroke", face)
    fs.Color = Theme.green
    fs.Thickness = 1.5

    local faceImg = Instance.new("ImageLabel")
    faceImg.Size = UDim2.fromScale(1, 1)
    faceImg.BackgroundTransparency = 1
    faceImg.Image = CapriAssets.FaceLook ~= "" and CapriAssets.FaceLook or ""
    faceImg.ZIndex = 24
    faceImg.Parent = face

    local faceLabel = Instance.new("TextLabel")
    faceLabel.Size = UDim2.fromScale(1, 1)
    faceLabel.BackgroundTransparency = 1
    faceLabel.Text = CapriAssets.FaceLook == "" and "◈" or ""
    faceLabel.TextColor3 = Theme.green
    faceLabel.Font = Enum.Font.GothamBold
    faceLabel.TextSize = 16
    faceLabel.ZIndex = 25
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
    inputBox.PlaceholderText = "Usa ! para misiones o habla..."
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
            "Línea abierta, choom. ¿Qué traes? (Usa ! para órdenes)",
            "Ahí estás. Habla.",
            "Capri al habla. No me aburras.",
            "¿Misión o solo charla?",
        }
        return g[math.random(1, #g)]
    end

    local function openPanel()
        if panelOpen then return end
        panelOpen = true
        local sp, ss = sprite.AbsolutePosition, sprite.AbsoluteSize
        local screen = gui.AbsoluteSize
        local px = math.clamp(sp.X - PANEL_W - 12, 8, math.max(8, screen.X - PANEL_W - 8))
        local py = math.clamp(sp.Y + ss.Y/2 - PANEL_H/2, 8, math.max(8, screen.Y - PANEL_H - 8))
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

    local function detectKind(text)
        local l = string.lower(text)
        if l:find("investiga") or l:find("busca") or l:find("qué hay") or l:find("que hay")
            or l:find("explora") or l:find("analiza") or l:find("lista") or l:find("dime qué") then
            return "research"
        end
        return "action"
    end

    local function buildMissionPrompt()
        local lines = {
            "MISSION FROM CAPRI HOST",
            "User original request: " .. missionBrief.original,
            "Mission type: " .. missionBrief.kind,
            "Clarifications:",
        }
        for i, a in ipairs(missionBrief.answers) do
            table.insert(lines, ("  %d) %s"):format(i, a))
        end
        table.insert(lines, "")
        table.insert(lines, "Execute this in the live Roblox game using tools.")
        if missionBrief.kind == "research" then
            table.insert(lines, "This is RESEARCH only: inspect and report findings. Do not modify the game unless explicitly required.")
            table.insert(lines, "Return a clear structured report of what you found.")
        else
            table.insert(lines, "This is an ACTION mission: make the requested changes/creations.")
            table.insert(lines, "When done, summarize what you changed.")
        end
        return table.concat(lines, "\n")
    end

    local function startMission()
        mode = "mission"
        missionRunning = true
        setStatus("misión en curso")
        addBubble("assistant", "Iniciando misión, choom.")

        local prompt = buildMissionPrompt()
        local missionKind = missionBrief.kind
        runUAIMission(prompt, function(ok, resultText)
            missionRunning = false
            mode = "idle"
            clarifyCount = 0
            missionBrief = { original = "", answers = {}, kind = "action" }

            if not ok then
                setStatus("misión fallida")
                addBubble("assistant", "La misión se torció: " .. tostring(resultText))
                return
            end

            if missionKind == "research" then
                setStatus("traduciendo...")
                local rewriteMsgs = {
                    { role = "system", content = CAPRI_PROMPT .. "\n\nYou received a raw mission report from a game agent. Retell it to the user in your Capri voice. Keep facts, drop dry tone. Be concise." },
                    { role = "user", content = "Report:\n" .. tostring(resultText) },
                }
                local rewritten, err = groqChat(API_KEY, rewriteMsgs, 600)
                setStatus("ia conectada")
                if rewritten then
                    addBubble("assistant", rewritten)
                else
                    addBubble("assistant", "Misión lista, pero falló el maquillaje de voz. Raw:\n" .. tostring(resultText))
                end
            else
                setStatus("ia conectada")
                addBubble("assistant", "Tu petición ha terminado, choom.\n" .. tostring(resultText))
            end
        end)
  end

    local function handleClarify(userText)
        table.insert(missionBrief.answers, userText)
        clarifyCount = clarifyCount + 1

        local sys = CAPRI_PROMPT .. [[

You are collecting mission details before sending work to a Roblox agent (UAI).
You may ask AT MOST ]] .. tostring(MAX_CLARIFY) .. [[ clarifying questions total.
Already asked: ]] .. tostring(clarifyCount) .. [[.

If you still need something critical, ask ONE short question in character.
If you have enough to act, reply with EXACTLY this first line:
READY_FOR_MISSION
Then a one-line summary of the mission in Capri voice.
Do not use READY_FOR_MISSION until the goal is clear enough to execute.
]]

        local msgs = {
            { role = "system", content = sys },
            { role = "user", content = "Original request: " .. missionBrief.original .. "\nLatest answer: " .. userText },
        }
        local reply, err = groqChat(API_KEY, msgs, 300)
        if not reply then
            addBubble("assistant", "Glitch al pensar la misión (" .. tostring(err) .. ").")
            mode = "idle"
            setStatus("error ia")
            return
        end

        if reply:find("READY_FOR_MISSION") or clarifyCount >= MAX_CLARIFY then
            local summary = reply:gsub("READY_FOR_MISSION", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if summary ~= "" then
                addBubble("assistant", summary)
            end
            startMission()
        else
            addBubble("assistant", reply)
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

            local isCommand = text:sub(1, 1) == "!"
            if mode == "idle" and isCommand and not missionRunning then
                local cleanText = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
                if cleanText == "" then
                    addBubble("assistant", "¡Ey, pon algo después del '!' para saber qué hacer, choom!")
                    busy = false
                    setStatus("ia conectada")
                    return
                end

                mode = "clarifying"
                clarifyCount = 0
                missionBrief = {
                    original = cleanText,
                    answers = {},
                    kind = detectKind(cleanText),
                }
                setStatus("aclarando misión")
                
                local sys = CAPRI_PROMPT .. [[

The user invoked a mission command using '!'.
Before starting, ask ONE short clarifying question in character if anything is ambiguous
(target, scope, style, constraints). If already crystal clear, reply with first line READY_FOR_MISSION
then a short Capri confirmation.
Max total clarifying questions allowed later: ]] .. tostring(MAX_CLARIFY) .. "."

                local msgs = {
                    { role = "system", content = sys },
                    { role = "user", content = cleanText },
                }
                
                local reply, err = groqChat(API_KEY, msgs, 300)
                if not reply then
                    addBubble("assistant", "No pude armar la misión (" .. tostring(err) .. ").")
                    mode = "idle"
                    setStatus("error ia")
                    busy = false
                    return
                end
                
                if reply:find("READY_FOR_MISSION") then
                    local summary = reply:gsub("READY_FOR_MISSION", ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if summary ~= "" then addBubble("assistant", summary) end
                    startMission()
                else
                    clarifyCount = 1
                    addBubble("assistant", reply)
                    setStatus("aclarando misión (1/" .. MAX_CLARIFY .. ")")
                end
                busy = false
                return
            end

            setStatus(missionRunning and "misión + charla" or "pensando...")
            local msgs = { { role = "system", content = CAPRI_PROMPT } }
            for _, m in ipairs(history) do table.insert(msgs, m) end
            if missionRunning then
                table.insert(msgs, { role = "system", content = "A background mission is running. You can still chat casually. Don't pretend the mission finished." })
            end
            
            local reply, err = groqChat(API_KEY, msgs, 400)
            if not reply then
                addBubble("assistant", "Falló la IA (" .. tostring(err) .. ").")
                setStatus("error ia")
            else
                table.insert(history, { role = "assistant", content = reply })
                addBubble("assistant", reply)
                setStatus(missionRunning and "misión en curso" or "ia conectada")
            end
            
            while #history > 20 do table.remove(history, 1) end
            busy = false
        end)
    end

    sendBtn.MouseButton1Click:Connect(function() sendMessage(inputBox.Text) end)
    inputBox.FocusLost:Connect(function(enter) if enter then sendMessage(inputBox.Text) end end)
    sprite.MouseEnter:Connect(function() tween(spriteStroke, { Transparency = 0 }, 0.12) end)
    sprite.MouseLeave:Connect(function() tween(spriteStroke, { Transparency = 0.25 }, 0.12) end)

    print("[Capri] Lista v4.")
    print("[Capri] Chat normal = Charla libre. Comandos de juego = usando '!' (ej: '!Busca los scripts').")
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
