--[[
  Capri × Project UAI — ALL-IN-ONE (v5 Animated)
  - Setup Groq key (local)
  - Chat Capri (Groq)
  - Comando '!' para misiones + UAI
  - Assets + animaciones de expresión / idle / misión
]]

print("[Capri] Iniciando v5 (animada)...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
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

local GITHUB_ASSET_URL = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/assets/"
local assetCache = {}

local function loadAsset(fileName)
    if assetCache[fileName] ~= nil then
        return assetCache[fileName]
    end
    local localPath = "CapriAsset_" .. fileName
    if type(isfile) == "function" and type(writefile) == "function" then
        if not isfile(localPath) then
            local success, res = pcall(function()
                return game:HttpGet(GITHUB_ASSET_URL .. fileName)
            end)
            if success and res and res ~= "" and res ~= "404: Not Found" and #res > 100 then
                pcall(writefile, localPath, res)
            else
                warn("[Capri] Asset no descargado:", fileName)
                assetCache[fileName] = ""
                return ""
            end
        end
        if type(getcustomasset) == "function" then
            local ok, assetId = pcall(getcustomasset, localPath)
            assetCache[fileName] = (ok and assetId) or ""
            return assetCache[fileName]
        end
    end
    assetCache[fileName] = ""
    return ""
end

local CapriAssets = {
    Face      = loadAsset("capri-face.png"),
    Cutout    = loadAsset("capri-cutout.png"),
    FaceCalm  = loadAsset("face-calm.png"),
    FaceLook  = loadAsset("face-look.png"),
    FaceAside = loadAsset("face-aside.png"),
    FaceSmug  = loadAsset("face-smug.png"),
    FaceLaugh = loadAsset("face-laugh.png"),
    FaceWide  = loadAsset("face-wide.png"),
    FaceMany  = loadAsset("face-many.png"),
    Grin      = loadAsset("cutin-grin.png"),
    Laugh     = loadAsset("cutin-laugh.png"),
    Eyes      = loadAsset("cutin-eyes.png"),
}

local function pickImage(...)
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        local img = CapriAssets[key]
        if img and img ~= "" then return img end
    end
    return ""
end

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
    return pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(cfg)) end)
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

-- SETUP truncated intentionally if tool limits; full file follows in part 2
print("[Capri] ERROR: incomplete upload - wait for full push")
