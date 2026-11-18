--[[
  Visual.lua (J.A.R.V.I.S. HUD)
  Que: boton orbe estilo Jarvis del HTML de referencia.
  Estados: EN LINEA / PROCESANDO / RESPONDIENDO / SISTEMA / ERROR
  Click abre el chat. Arrastrable.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

-- Colores del HTML: --c #35c8ff, trabajo amarillo, error rojo
local C_IDLE = Color3.fromRGB(53, 200, 255)
local C_TALK = Color3.fromRGB(143, 230, 255)
local C_HACK = Color3.fromRGB(255, 200, 60)
local C_DONE = Color3.fromRGB(80, 255, 180)
local C_ERR = Color3.fromRGB(255, 70, 90)

local STATE_COLOR = {}
STATE_COLOR.idle = C_IDLE
STATE_COLOR.talking = C_TALK
STATE_COLOR.hack = C_HACK
STATE_COLOR.done = C_DONE
STATE_COLOR.error = C_ERR

local STATE_LABEL = {}
STATE_LABEL.idle = "EN LINEA"
STATE_LABEL.talking = "RESPONDIENDO..."
STATE_LABEL.hack = "PROCESANDO..."
STATE_LABEL.done = "LISTO"
STATE_LABEL.error = "ERROR"

function Visual.new(gui, Assets, Theme)
	local self = setmetatable({}, Visual)
	self.gui = gui
	self.Assets = Assets
	self.Theme = Theme
	self.state = "idle"
	self.token = 0
	self.onClick = nil
	self:_build()
	return self
end

function Visual:_build()
	-- Contenedor del HUD (orbe + texto)
	local root = Instance.new("TextButton")
	root.Name = "CapriJarvis"
	root.Size = UDim2.fromOffset(110, 130)
	root.Position = UDim2.new(1, -128, 0.38, 0)
	root.BackgroundTransparency = 1
	root.Text = ""
	root.AutoButtonColor = false
	root.ZIndex = 10
	root.Parent = self.gui
	self.root = root

	-- Anillo exterior
	local ringOuter = Instance.new("Frame")
	ringOuter.Name = "RingOuter"
	ringOuter.AnchorPoint = Vector2.new(0.5, 0.5)
	ringOuter.Position = UDim2.new(0.5, 0, 0.42, 0)
	ringOuter.Size = UDim2.fromOffset(96, 96)
	ringOuter.BackgroundTransparency = 1
	ringOuter.ZIndex = 10
	ringOuter.Parent = root
	local roCorner = Instance.new("UICorner")
	roCorner.CornerRadius = UDim.new(1, 0)
	roCorner.Parent = ringOuter
	local roStroke = Instance.new("UIStroke")
	roStroke.Color = C_IDLE
	roStroke.Thickness = 1.5
	roStroke.Transparency = 0.45
	roStroke.Parent = ringOuter
	self.ringOuterStroke = roStroke

	-- Anillo medio
	local ringMid = Instance.new("Frame")
	ringMiddle.Name = "RingMiddle"
	ringMiddle.AnchorPoint = Vector2.new(0.5, 0.5)
	ringMiddle.Position = UDim2.new(0.5, 0, 0.42, 0)
	ringMiddle.Size = UDim2.fromOffset(72, 72)
	ringMiddle.BackgroundTransparency = 1
	ringMiddle.ZIndex = 11
	ringMiddle.Parent = root
	local rmCorner = Instance.new("UICorner")
	rmCorner.CornerRadius = UDim.new(1, 0)
	rmCorner.Parent = ringMiddle
	local rmStroke = Instance.new("UIStroke")
	rmStroke.Color = C_IDLE
	rmStroke.Thickness = 2
	rmStroke.Transparency = 0.25
	rmStroke.Parent = ringMiddle
	self.ringMiddleStroke = rmStroke

	-- Nucleo clickable (nodo)
	local core = Instance.new("Frame")
	core.Name = "Core"
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.new(0.5, 0, 0.42, 0)
	core.Size = UDim2.fromOffset(36, 36)
	core.BackgroundColor3 = C_IDLE
	core.BackgroundTransparency = 0.15
	core.BorderSizePixel = 0
	core.ZIndex = 12
	core.Parent = root
	self.core = core
	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core
	local coreStroke = Instance.new("UIStroke")
	coreStroke.Color = Color3.fromRGB(200, 245, 255)
	coreStroke.Thickness = 1.5
	coreStroke.Transparency = 0.2
	coreStroke.Parent = core
	self.coreStroke = coreStroke

	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "C"
	mark.TextColor3 = Color3.fromRGB(230, 250, 255)
	mark.Font = Enum.Font.GothamBold
	mark.TextSize = 16
	mark.ZIndex = 13
	mark.Parent = core

	-- Titulo + status (como #hud del HTML)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromOffset(120, 16)
	title.Position = UDim2.new(0.5, -60, 1, -28)
	title.BackgroundTransparency = 1
	title.Text = "J.A.R.V.I.S."
	title.TextColor3 = C_TALK
	title.Font = Enum.Font.GothamBold
	title.TextSize = 12
	title.ZIndex = 12
	title.Parent = root
	self.title = title

	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(120, 14)
	tag.Position = UDim2.new(0.5, -60, 1, -12)
	tag.BackgroundTransparency = 1
	tag.Text = "EN LINEA"
	tag.TextColor3 = C_IDLE
	tag.Font = Enum.Font.Code
	tag.TextSize = 11
	tag.ZIndex = 12
	tag.Parent = root
	self.tag = tag

	-- Pulso segun estado
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local pulse = 0.2 + math.abs(math.sin(t * 2.0)) * 0.25
		if self.state == "hack" then
			pulse = 0.05 + math.abs(math.sin(t * 5.5)) * 0.35
		elseif self.state == "talking" then
			pulse = 0.1 + math.abs(math.sin(t * 3.8)) * 0.28
		elseif self.state == "error" then
			pulse = 0.05 + math.abs(math.sin(t * 6)) * 0.3
		end
		self.ringMiddleStroke.Transparency = pulse
		self.ringOuterStroke.Transparency = math.clamp(pulse + 0.15, 0, 0.85)
	end)

	local dragging = false
	local moved = false
	local start = nil
	local startPos = nil

	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			start = input.Position
			startPos = root.Position
		end
	end)

	root.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if not moved and self.onClick then
				self.onClick()
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - start
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then
				moved = true
			end
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

function Visual:setFace(_keys)
end

function Visual:flashCutin(_key)
end

function Visual:setExpression(state)
	self.state = state or "idle"
	local color = STATE_COLOR[self.state] or C_IDLE
	local label = STATE_LABEL[self.state] or "EN LINEA"
	self.core.BackgroundColor3 = color
	self.ringMiddleStroke.Color = color
	self.ringOuterStroke.Color = color
	self.tag.Text = label
	self.tag.TextColor3 = color
	if self.state == "hack" or self.state == "error" then
		self.title.TextColor3 = color
	else
		self.title.TextColor3 = C_TALK
	end
end

return Visual
