--[[
  Theme.lua
  Que: tokens de color estilo J.A.R.V.I.S. (referencia HUD HTML).
  Por que: cyan/vidrio oscuro; amarillo trabajo; rojo error.
]]

local Theme = {}

-- Fondo / paneles (vidrio oscuro)
Theme.bg = Color3.fromRGB(2, 10, 20)
Theme.panel = Color3.fromRGB(3, 18, 32)
Theme.plate = Color3.fromRGB(6, 28, 48)
Theme.sidebar = Color3.fromRGB(4, 14, 26)
Theme.inputBg = Color3.fromRGB(5, 22, 38)
Theme.row = Color3.fromRGB(8, 30, 50)

-- Acentos cyan (idle / chat)
Theme.border = Color3.fromRGB(53, 200, 255)
Theme.accent = Color3.fromRGB(53, 200, 255)
Theme.chatGreen = Color3.fromRGB(53, 200, 255)
Theme.c2 = Color3.fromRGB(143, 230, 255)

-- Trabajo UAI (amarillo)
Theme.uaiYellow = Color3.fromRGB(255, 200, 60)
Theme.glitch = Color3.fromRGB(255, 210, 80)

-- Estados
Theme.green = Color3.fromRGB(80, 255, 180)
Theme.danger = Color3.fromRGB(255, 70, 90)

-- Texto
Theme.text = Color3.fromRGB(205, 239, 255)
Theme.textDim = Color3.fromRGB(120, 180, 210)

-- Burbujas
Theme.bubbleUser = Color3.fromRGB(12, 40, 64)
Theme.bubbleAi = Color3.fromRGB(6, 24, 40)

function Theme.mkCorner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = parent
	return c
end

function Theme.mkStroke(parent, color, thick, trans)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.border
	s.Thickness = thick or 1.2
	s.Transparency = trans or 0.35
	s.Parent = parent
	return s
end

function Theme.tween(obj, props, time, style)
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(time or 0.22, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

return Theme
