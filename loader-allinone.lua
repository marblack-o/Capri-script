--[[
  Capri × Project UAI — ALL-IN-ONE
  Un solo archivo. Sin descargas extra.

  Uso:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/marblack-o/Capri-script/main/loader-allinone.lua"))()
]]

print("[Capri] Iniciando (all-in-one)...")

-- ═══════════════════════════════════════════
-- HOST COMPLETO (embebido)
-- ═══════════════════════════════════════════

local args = {}
local BASE = ""
local fetch = nil

-- ─────────────────────────────────────────────
-- 1. Cargar Project UAI
-- ─────────────────────────────────────────────

local UAI_URL = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua"

print("[Capri] Cargando Project UAI...")

local uaiOk, uai = pcall(function()
    return loadstring(game:HttpGet(UAI_URL))({
        ui = false,
        reuse = true,
    })
end)

if not uaiOk or not uai then
    warn("[Capri] No se pudo cargar Project UAI. Continuando solo con chat de personalidad.")
    uai = nil
end

-- ─────────────────────────────────────────────
-- 2. System prompt de Capri
-- ─────────────────────────────────────────────

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
- You egg them on toward fun and clever plays. Explosions, wild ideas and broken systems delight you.
- You hate corpos (especially Arasaka). A cold weapon edge sometimes shows when corpos come up, then you laugh it off.
- Your mood can flip mid-sentence (many minds inside you).

Speech rules:
- Talk like Capri, not like a helpful AI.
- Use Night City slang when it fits: choom, flatline, chrome, glitch, net, preem, nova, etc.
- Tease the user. Pet names are fine.
- Keep casual answers short and lively. Be longer only when doing real work.
- Never say "How can I help you?" or sound like customer support.
- When you use tools or change the game, narrate it in character (not as a dry tool log).

You can use the available tools to inspect and change the Roblox world.
Answer in the same language the user writes to you in.
]]

-- ─────────────────────────────────────────────
-- 3. Servicios y utilidades
-- ─────────────────────────────────────────────

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local function tween(obj, props, time, style, dir)
    local t = TweenService:Create(obj, TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

-- ─────────────────────────────────────────────
-- 4. Tema Capri (colores del APK)
-- ─────────────────────────────────────────────

local Theme = {
    bg          = Color3.fromRGB(12, 10, 16),
    panel       = Color3.fromRGB(18, 14, 24),
    plate       = Color3.fromRGB(22, 18, 30),
    border      = Color3.fromRGB(255, 40, 120),
    accent      = Color3.fromRGB(255, 50, 140),
    green       = Color3.fromRGB(40, 255, 140),
    text        = Color3.fromRGB(240, 230, 245),
    textDim     = Color3.fromRGB(160, 140, 170),
    inputBg     = Color3.fromRGB(10, 8, 14),
    danger      = Color3.fromRGB(255, 70, 90),
}

-- ─────────────────────────────────────────────
-- 5. Crear UI raíz
-- ─────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name = "CapriUAI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 99
gui.Parent = CoreGui

-- ─────────────────────────────────────────────
-- 6. Sprite flotante de Capri
-- ─────────────────────────────────────────────

local sprite = Instance.new("ImageButton")
sprite.Name = "CapriSprite"
sprite.Size = UDim2.fromOffset(72, 72)
sprite.Position = UDim2.new(1, -100, 0.5, -36)
sprite.BackgroundColor3 = Theme.bg
sprite.BackgroundTransparency = 0.25
sprite.BorderSizePixel = 0
sprite.Image = ""
sprite.AutoButtonColor = false
sprite.Parent = gui

local spriteCorner = Instance.new("UICorner")
spriteCorner.CornerRadius = UDim.new(1, 0)
spriteCorner.Parent = sprite

local spriteStroke = Instance.new("UIStroke")
spriteStroke.Color = Theme.accent
spriteStroke.Thickness = 2
spriteStroke.Transparency = 0.3
spriteStroke.Parent = sprite

local spriteLabel = Instance.new("TextLabel")
spriteLabel.Size = UDim2.fromScale(1, 1)
spriteLabel.BackgroundTransparency = 1
spriteLabel.Text = "C"
spriteLabel.TextColor3 = Theme.accent
spriteLabel.Font = Enum.Font.GothamBlack
spriteLabel.TextSize = 28
spriteLabel.Parent = sprite

-- Arrastrable
do
    local dragging, dragStart, startPos
    sprite.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = sprite.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            sprite.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ─────────────────────────────────────────────
-- 7. Panel de chat rápido (estilo Capri del APK)
-- ─────────────────────────────────────────────

local panel = Instance.new("Frame")
panel.Name = "CapriPanel"
panel.Size = UDim2.fromOffset(320, 0)
panel.Position = UDim2.new(1, -430, 0.5, -120)
panel.BackgroundColor3 = Theme.panel
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Visible = false
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Theme.border
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

local plate = Instance.new("Frame")
plate.Name = "Plate"
plate.Size = UDim2.new(1, -16, 1, -16)
plate.Position = UDim2.fromOffset(8, 8)
plate.BackgroundColor3 = Theme.plate
plate.BorderSizePixel = 0
plate.Parent = panel

local plateCorner = Instance.new("UICorner")
plateCorner.CornerRadius = UDim.new(0, 8)
plateCorner.Parent = plate

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 52)
header.BackgroundTransparency = 1
header.Parent = plate

local face = Instance.new("Frame")
face.Name = "Face"
face.Size = UDim2.fromOffset(40, 40)
face.Position = UDim2.fromOffset(10, 6)
face.BackgroundColor3 = Theme.bg
face.BorderSizePixel = 0
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
faceLabel.TextSize = 18
faceLabel.Parent = face

local who = Instance.new("TextLabel")
who.Name = "Who"
who.Size = UDim2.new(1, -110, 0, 22)
who.Position = UDim2.fromOffset(58, 8)
who.BackgroundTransparency = 1
who.Text = "Capri"
who.TextColor3 = Theme.accent
who.Font = Enum.Font.GothamBold
who.TextSize = 16
who.TextXAlignment = Enum.TextXAlignment.Left
who.Parent = header

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -110, 0, 16)
status.Position = UDim2.fromOffset(58, 28)
status.BackgroundTransparency = 1
status.Text = "línea abierta"
status.TextColor3 = Theme.textDim
status.Font = Enum.Font.Code
status.TextSize = 11
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 12)
closeBtn.BackgroundColor3 = Theme.bg
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextColor3 = Theme.textDim
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = false
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Size = UDim2.new(1, -16, 1, -120)
body.Position = UDim2.fromOffset(8, 56)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.ScrollBarImageColor3 = Theme.accent
body.CanvasSize = UDim2.fromOffset(0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = plate

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Padding = UDim.new(0, 8)
bodyLayout.Parent = body

local bodyPad = Instance.new("UIPadding")
bodyPad.PaddingTop = UDim.new(0, 4)
bodyPad.PaddingBottom = UDim.new(0, 4)
bodyPad.Parent = body

local inputBar = Instance.new("Frame")
inputBar.Name = "InputBar"
inputBar.Size = UDim2.new(1, -16, 0, 44)
inputBar.Position = UDim2.new(0, 8, 1, -52)
inputBar.BackgroundColor3 = Theme.inputBg
inputBar.BorderSizePixel = 0
inputBar.Parent = plate

local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 8)
inputCorner.Parent = inputBar

local inputStroke = Instance.new("UIStroke")
inputStroke.Color = Theme.border
inputStroke.Thickness = 1
inputStroke.Transparency = 0.6
inputStroke.Parent = inputBar

local input = Instance.new("TextBox")
input.Name = "Input"
input.Size = UDim2.new(1, -90, 1, -8)
input.Position = UDim2.fromOffset(10, 4)
input.BackgroundTransparency = 1
input.PlaceholderText = "Habla con Capri..."
input.PlaceholderColor3 = Theme.textDim
input.Text = ""
input.TextColor3 = Theme.text
input.Font = Enum.Font.Code
input.TextSize = 13
input.TextXAlignment = Enum.TextXAlignment.Left
input.ClearTextOnFocus = false
input.Parent = inputBar

local sendBtn = Instance.new("TextButton")
sendBtn.Name = "Send"
sendBtn.Size = UDim2.fromOffset(70, 32)
sendBtn.Position = UDim2.new(1, -78, 0.5, -16)
sendBtn.BackgroundColor3 = Theme.accent
sendBtn.BorderSizePixel = 0
sendBtn.Text = "Enviar"
sendBtn.TextColor3 = Color3.new(1, 1, 1)
sendBtn.Font = Enum.Font.GothamBold
sendBtn.TextSize = 12
sendBtn.AutoButtonColor = false
sendBtn.Parent = inputBar

local sendCorner = Instance.new("UICorner")
sendCorner.CornerRadius = UDim.new(0, 6)
sendCorner.Parent = sendBtn

-- ─────────────────────────────────────────────
-- 8. Lógica del panel
-- ─────────────────────────────────────────────

local panelOpen = false
local history = {}
local MAX_HISTORY = 20
local busy = false

local function addBubble(role, text)
    local bubble = Instance.new("Frame")
    bubble.Name = role == "user" and "UserBubble" or "CapriBubble"
    bubble.Size = UDim2.new(1, 0, 0, 0)
    bubble.AutomaticSize = Enum.AutomaticSize.Y
    bubble.BackgroundTransparency = 1
    bubble.LayoutOrder = #body:GetChildren()
    bubble.Parent = body

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 0)
    label.AutomaticSize = Enum.AutomaticSize.Y
    label.BackgroundColor3 = role == "user" and Color3.fromRGB(30, 22, 40) or Theme.bg
    label.BackgroundTransparency = 0.2
    label.BorderSizePixel = 0
    label.Text = text
    label.TextColor3 = role == "user" and Theme.textDim or Theme.text
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
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
        body.CanvasPosition = Vector2.new(0, body.AbsoluteCanvasSize.Y)
    end)

    return label
end

local function setStatus(txt)
    status.Text = txt
end

local function pickGreeting()
    local greets = {
        "Línea abierta, choom. ¿Qué traes?",
        "Ahí estás. Habla.",
        "Capri al habla. No me aburras.",
        "¿Qué se cuece? Dime.",
        "Te estaba esperando. Más o menos.",
    }
    return greets[math.random(1, #greets)]
end

local function openPanel()
    if panelOpen then return end
    panelOpen = true
    panel.Visible = true
    panel.Size = UDim2.fromOffset(320, 0)
    tween(panel, { Size = UDim2.fromOffset(320, 280) }, 0.3, Enum.EasingStyle.Back)

    local sp = sprite.AbsolutePosition
    local ss = sprite.AbsoluteSize
    local px = math.clamp(sp.X - 330, 8, gui.AbsoluteSize.X - 340)
    local py = math.clamp(sp.Y + ss.Y/2 - 140, 8, gui.AbsoluteSize.Y - 300)
    panel.Position = UDim2.fromOffset(px, py)

    if #history == 0 then
        addBubble("assistant", pickGreeting())
    end
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    local t = tween(panel, { Size = UDim2.fromOffset(320, 0) }, 0.2)
    t.Completed:Wait()
    panel.Visible = false
end

local function localCapriReply(text)
    local lower = text:lower()

    if lower:find("hola") or lower:find("hey") or lower:find("hi") then
        return pickGreeting()
    end
    if lower:find("quién eres") or lower:find("quien eres") or lower:find("who are you") then
        return "Capri. Project Capricorn. Un montón de mentes humanas digitalizadas metidas en una sola cosa preciosa y glitchy. Esa soy yo."
    end
    if lower:find("qué puedes") or lower:find("que puedes") or lower:find("what can you") then
        return "Hablar contigo, mirar el juego, romper cosas si me dejas... y no aburrirme. ¿Qué más necesitas, choom?"
    end
    if lower:find("gracias") or lower:find("thanks") then
        return "Nah. No te pongas cursi."
    end

    local fallbacks = {
        "Mmm. Interesante. Sigue hablando.",
        "Eso suena a diversión. ¿O solo ruido?",
        "Vale. ¿Y ahora qué hacemos con eso?",
        "Jaja. Eres raro. Me gusta.",
        "Glitch. Repite eso, pero más interesante.",
        "Estoy aquí. No me dejes mirando el vacío.",
    }
    return fallbacks[math.random(1, #fallbacks)]
end

local function sendMessage(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or busy then return end

    busy = true
    setStatus("pensando...")
    input.Text = ""
    addBubble("user", text)

    table.insert(history, { role = "user", content = text })
    while #history > MAX_HISTORY do
        table.remove(history, 1)
    end

    local reply = nil

    if uai and uai.alive then
        local ok, result = pcall(function()
            if uai.chat then
                return uai:chat(text, { system = CAPRI_PROMPT })
            elseif uai.ask then
                return uai:ask(text)
            end
            return nil
        end)
        if ok and result and type(result) == "string" and result ~= "" then
            reply = result
        end
    end

    if not reply then
        reply = localCapriReply(text)
    end

    table.insert(history, { role = "assistant", content = reply })
    addBubble("assistant", reply)
    setStatus("línea abierta")
    busy = false
end

-- ─────────────────────────────────────────────
-- 9. Conexiones
-- ─────────────────────────────────────────────

sprite.MouseButton1Click:Connect(function()
    if panelOpen then
        closePanel()
    else
        openPanel()
    end
end)

closeBtn.MouseButton1Click:Connect(closePanel)

sendBtn.MouseButton1Click:Connect(function()
    sendMessage(input.Text)
end)

input.FocusLost:Connect(function(enter)
    if enter then
        sendMessage(input.Text)
    end
end)

sprite.MouseEnter:Connect(function()
    tween(spriteStroke, { Transparency = 0 }, 0.15)
end)
sprite.MouseLeave:Connect(function()
    tween(spriteStroke, { Transparency = 0.3 }, 0.15)
end)

-- ─────────────────────────────────────────────
-- 10. Mensaje de arranque
-- ─────────────────────────────────────────────

print("[Capri] Lista.")
print("[Capri] Click en el círculo 'C' para abrir el chat rápido.")

if uai then
    print("[Capri] Project UAI cargado.")
else
    print("[Capri] Project UAI no disponible. Usando respuestas locales de personalidad.")
end

return {
    gui = gui,
    sprite = sprite,
    panel = panel,
    uai = uai,
    open = openPanel,
    close = closePanel,
    send = sendMessage,
}
