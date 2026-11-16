--[[
  Visual.lua (Jarvis mode)
  Que: presencia minimal tipo Jarvis - orbe de estado + label.
  Por que: abandonamos sprite/caras/assets; mas estable y comodo.
  API compatible: setExpression, onClick, flashCutin (no-op).
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

local STATE_COLOR = {}
STATE_COLOR.idle = Color3.fromRGB(80, 200, 255)
STATE_COLOR.talking = Color3.fromRGB(120, 230, 255)
STATE_COLOR.hack = Color3.fromRGB(255, 200, 60)
STATE_COLOR.done = Color3.fromRGB(80, 255, 160)
STATE_COLOR.error = Color3.fromRGB(255, 80, 100)

local STATE_LABEL = {}
STATE_LABEL.idle = "CAPRI"
STATE_LABEL.talking = "LISTEN"
STATE_LABEL.hack = "SYSTEM"
STATE_LABEL.done = "DONE"
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
	local Theme = self.Theme

	local root = Instance.new("TextButton")
	root.Name = "CapriJarvis"
	root.Size = UDim2.fromOffset(72, 72)
	root.Position = UDim2.new(1, -90, 0.42, 0)
	root.BackgroundColor3 = Color3.fromRGB(8, 16, 28)
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Text = ""
	root.AutoButtonColor = false
	root.ZIndex = 10
	root.Parent = self.gui
	self.root = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = STATE_COLOR.idle
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = root
	self.stroke = stroke

	local core = Instance.new("Frame")
	core.Name = "Core"
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromOffset(28, 28)
	core.BackgroundColor3 = STATE_COLOR.idle
	core.BackgroundTransparency = 0.25
	core.BorderSizePixel = 0
	core.ZIndex = 11
	core.Parent = root
	self.core = core

	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core

	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Text = "C"
	mark.TextColor3 = Color3.fromRGB(220, 245, 255)
	mark.Font = Enum.Font.GothamBold
	mark.TextSize = 14
	mark.ZIndex = 12
	mark.Parent = core

	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(90, 16)
	tag.Position = UDim2.new(0.5, -45, 1, 4)
	tag.BackgroundTransparency = 1
	tag.Text = "CAPRI"
	tag.TextColor3 = STATE_COLOR.idle
	tag.Font = Enum.Font.Code
	tag.TextSize = 11
	tag.ZIndex = 12
	tag.Parent = root
	self.tag = tag

	-- Pulso suave del anillo
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local pulse = 0.12 + math.abs(math.sin(t * 2.2)) * 0.2
		if self.state == "hack" then
			pulse = 0.05 + math.abs(math.sin(t * 5)) * 0.25
		elseif self.state == "talking" then
			pulse = 0.08 + math.abs(math.sin(t * 3.5)) * 0.22
		end
		self.stroke.Transparency = pulse
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
	-- compat: ya no hay caras
end

function Visual:flashCutin(_key)
	-- compat: sin cut-ins
end

function Visual:setExpression(state)
	self.state = state or "idle"
	local color = STATE_COLOR[self.state] or STATE_COLOR.idle
	local label = STATE_LABEL[self.state] or "CAPRI"
	self.stroke.Color = color
	self.core.BackgroundColor3 = color
	self.tag.Text = label
	self.tag.TextColor3 = color
end

return Visual
