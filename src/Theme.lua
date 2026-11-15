--[[
  Theme.lua
  Qué: tokens de color y estilo del workbench Capri.
  Por qué: un solo sitio para el look púrpura/glitch y bordes verde (chat) / amarillo (UAI).
]]

local Theme = {
	bg = Color3.fromRGB(12, 8, 18),
	panel = Color3.fromRGB(26, 14, 40),
	plate = Color3.fromRGB(32, 18, 50),
	sidebar = Color3.fromRGB(18, 10, 30),
	border = Color3.fromRGB(255, 70, 180),
	accent = Color3.fromRGB(255, 55, 160),
	glitch = Color3.fromRGB(255, 220, 60),
	chatGreen = Color3.fromRGB(60, 220, 120),
	uaiYellow = Color3.fromRGB(255, 210, 50),
	green = Color3.fromRGB(40, 255, 140),
	text = Color3.fromRGB(245, 235, 255),
	textDim = Color3.fromRGB(170, 145, 195),
	inputBg = Color3.fromRGB(14, 8, 24),
	danger = Color3.fromRGB(255, 70, 100),
	bubbleUser = Color3.fromRGB(42, 24, 62),
	bubbleAi = Color3.fromRGB(20, 12, 34),
	row = Color3.fromRGB(30, 16, 46),
}

function Theme.mkCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = parent
	return c
end

function Theme.mkStroke(parent, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.border
	s.Thickness = thick or 1.4
	s.Transparency = trans or 0.25
	s.Parent = parent
	return s
end

function Theme.tween(obj, props, time, style)
	local TweenService = game:GetService("TweenService")
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

return Theme
