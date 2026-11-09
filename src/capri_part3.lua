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
            "Línea abierta, choom. ¿Qué traes?",
            "Ahí estás. Habla.",
            "Capri al habla. No me aburras.",
            "¿Charla o misión con '!' ?",
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
        setExpression("mission")
        addBubble("assistant", "Iniciando misión, choom.")

        local prompt = buildMissionPrompt()
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
                addBubble("assistant", "La misión se torció: " .. tostring(resultText))
                return
            end

            if missionKind == "research" then
                setStatus("traduciendo...")
                setExpression("talking")
                local rewriteMsgs = {
                    { role = "system", content = CAPRI_PROMPT .. "\n\nYou received a raw mission report from a game agent. Retell it to the user in your Capri voice. Keep facts, drop dry tone. Be concise." },
                    { role = "user", content = "Report:\n" .. tostring(resultText) },
                }
                local rewritten, err = groqChat(API_KEY, rewriteMsgs, 600)
                setStatus("ia conectada")
                setExpression("done")
                if rewritten then
                    addBubble("assistant", rewritten)
                else
                    addBubble("assistant", "Misión lista, pero falló el maquillaje de voz. Raw:\n" .. tostring(resultText))
                end
            else
                setStatus("ia conectada")
                setExpression("done")
                addBubble("assistant", "Tu petición ha terminado, choom.\n" .. tostring(resultText))
            end
        end)
    end

    local function handleClarify(userText)
        table.insert(missionBrief.answers, userText)
        clarifyCount = clarifyCount + 1
        setExpression("talking")

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
            setExpression("error")
            setStatus("error ia")
            return
        end

        if reply:find("READY_FOR_MISSION") or clarifyCount >= MAX_CLARIFY then
            local summary = reply:gsub("READY_FOR_MISSION", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if summary ~= "" then addBubble("assistant", summary) end
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

            local isCommand = text:sub(1, 1) == "!"
            if mode == "idle" and isCommand and not missionRunning then
                local cleanText = text:sub(2):gsub("^%s+", ""):gsub("%s+$", "")
                if cleanText == "" then
                    addBubble("assistant", "Pon algo después del '!' para saber qué hacer, choom.")
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
                setExpression("talking")

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
                    setExpression("error")
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
                    setExpression("idle")
                    setStatus("aclarando misión (1/" .. MAX_CLARIFY .. ")")
                end
                busy = false
                return
            end

            setStatus(missionRunning and "misión + charla" or "pensando...")
            setExpression("talking")
            local msgs = { { role = "system", content = CAPRI_PROMPT } }
            for _, m in ipairs(history) do table.insert(msgs, m) end
            if missionRunning then
                table.insert(msgs, { role = "system", content = "A background mission is running. You can still chat casually. Don't pretend the mission finished." })
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
    sprite.MouseEnter:Connect(function()
        tween(spriteStroke, { Transparency = 0 }, 0.12)
    end)
    sprite.MouseLeave:Connect(function()
        if exprState == "idle" then
            tween(spriteStroke, { Transparency = 0.25 }, 0.12)
        end
    end)

    print("[Capri] Lista v5 animada.")
    print("[Capri] Chat libre · !misión · caras idle/talk/misión/done")
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
