--[[
  Visual.lua
  Que: HUD Jarvis (esfera de puntos + anillos + nodo orbital).
  Adaptado del LocalScript Claude a la API Capri:
    Visual.new(gui, Assets, Theme)
    visual.onClick / setExpression / setFace / flashCutin
  Chat real sigue en UI_Chat (el nodo solo abre el panel).
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Visual = {}
Visual.__index = Visual

local SIZE = 0.28
local LAT, LON, PTS = 6, 5, 22
local C = Color3.fromRGB(53, 200, 255)
local C2 = Color3.fromRGB(143, 230, 255)
local C_HACK = Color3.fromRGB(255, 200, 60)
local C_ERR = Color3.fromRGB(255, 70, 90)
local C_DONE = Color3.fromRGB(80, 255, 180)
local NAME = "J.A.R.V.I.S."

local LABEL = {}
LABEL.idle = "EN LINEA"
LABEL.talking = "RESPONDIENDO..."
LABEL.hack = "PROCESANDO..."
LABEL.done = "LISTO"
LABEL.error = "ERROR"

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	if parent then
	o.Parent = parent
	end
	return o
end

function Visual.new(gui, Assets, Theme)
	local self = setmetatable({}, Visual)
	self.gui = gui
	self.Assets = Assets
	self.Theme = Theme
	self.state = "idle"
	self.token = 0
	self.onClick = nil
	self.accent = C
	self:_build()
	return self
end

function Visual:_build()
	local gui = self.gui
	local CENTER = Vector2.new(0.5, 0.5)

	local stage = mk("Frame", {
		Name = "JarvisStage",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0.02, 0.93),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, gui)
	self.stage = stage

	local function resize()
		local v = gui.AbsoluteSize
		if v.X < 10 or v.Y < 10 then
			return
		end
		local s = math.min(v.X, v.Y) * SIZE
		stage.Size = UDim2.fromOffset(s, s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local function circle(parent, scale, thick, transp)
		local f = mk("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, parent)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		local st = mk("UIStroke", { Color = C, Thickness = thick, Transparency = transp }, f)
		return f, st
	end

	local _, orbitStroke = circle(stage, 0.95, 1, 0.7)
	local _, midStroke = circle(stage, 0.66, 1, 0.45)
	self.orbitStroke = orbitStroke
	self.midStroke = midStroke

	local function segRing(radius, count, w, h, rotOffset, transp)
		local holder = mk("Frame", {
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 11,
		}, stage)
		for i = 1, count do
			local a = math.rad(i * 360 / count)
			mk("Frame", {
				AnchorPoint = CENTER,
				BorderSizePixel = 0,
				BackgroundColor3 = C,
				BackgroundTransparency = transp,
				Size = UDim2.fromOffset(w, h),
				Position = UDim2.fromScale(0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius),
				Rotation = math.deg(a) + rotOffset,
				ZIndex = 11,
			}, holder)
		end
		return holder
	end

	self.ringTicks = segRing(0.42, 56, 2, 7, -90, 0.35)
	self.ringArcs = segRing(0.375, 14, 28, 3, 0, 0.15)

	local sphere = mk("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, stage)

	local glow = mk("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = C,
		BackgroundTransparency = 0.88,
		ZIndex = 12,
	}, sphere)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	self.glow = glow

	local pts = {}
	local function addCurve(fn, n, size)
		for i = 0, n - 1 do
			local d = mk("Frame", {
				AnchorPoint = CENTER,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = C2,
				BorderSizePixel = 0,
				ZIndex = 13,
			}, sphere)
			pts[#pts + 1] = { d = d, p = fn(i / n) }
		end
	end

	for i = 0, LAT - 1 do
		local ph = math.rad(-75 + i * (150 / math.max(LAT - 1, 1)))
		addCurve(function(u)
			return Vector3.new(math.cos(ph) * math.cos(u * 6.283), math.sin(ph), math.cos(ph) * math.sin(u * 6.283))
		end, PTS, 2)
	end
	for i = 0, LON - 1 do
		local th = math.rad(i * (180 / math.max(LON, 1)))
		addCurve(function(u)
			local p = u * 6.283
			return Vector3.new(math.cos(p) * math.cos(th), math.sin(p), math.cos(p) * math.sin(th))
		end, PTS + 6, 2)
	end
	for _ = 1, 28 do
		local u = math.random() * 2 - 1
		local a = math.random() * 6.283
		local s = math.sqrt(math.max(0, 1 - u * u))
		local fixed = Vector3.new(s * math.cos(a), u, s * math.sin(a))
		addCurve(function()
			return fixed
		end, 1, 3)
	end
	self.pts = pts

	local core = mk("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.12, 0.12),
		BackgroundTransparency = 0.1,
		ZIndex = 14,
	}, sphere)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, core)
	self.core = core

	local node = mk("TextButton", {
		AnchorPoint = CENTER,
		Size = UDim2.fromOffset(22, 22),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C2,
		ZIndex = 20,
	}, stage)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, node)
	mk("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }, node)
	self.node = node

	local pulse = mk("Frame", {
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 19,
	}, node)
	mk("UICorner", { CornerRadius = UDim.new(1, 0) }, pulse)
	mk("UIStroke", { Color = C, Thickness = 1.5 }, pulse)
	TweenService:Create(pulse, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), {
		Size = UDim2.fromScale(2.6, 2.6),
	}):Play()

	local nodeLabel = mk("TextLabel", {
		Text = "CHAT",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = C2,
		BackgroundTransparency = 1,
		TextTransparency = 1,
		Position = UDim2.new(1, 8, 0.5, -8),
		Size = UDim2.fromOffset(40, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	}, node)

	local title = mk("TextLabel", {
		Text = NAME,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C2,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(200, 20),
		ZIndex = 15,
	}, stage)
	self.title = title

	local status = mk("TextLabel", {
		Text = "EN LINEA",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = C,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 24),
		Size = UDim2.fromOffset(200, 14),
		ZIndex = 15,
	}, stage)
	self.status = status

	local function fireClick()
		if self.onClick then
			self.onClick()
		end
	end
	node.MouseButton1Click:Connect(fireClick)
	node.MouseEnter:Connect(function()
		self._hover = true
		TweenService:Create(nodeLabel, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
	end)
	node.MouseLeave:Connect(function()
		self._hover = false
		TweenService:Create(nodeLabel, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
	end)

	-- Arrastrar el stage (opcional)
	local dragging, moved, start, startPos = false, false, nil, nil
	stage.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			start = input.Position
			startPos = stage.Position
		end
	end)
	stage.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - start
			if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then
				moved = true
			end
			stage.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)

	-- Animacion
	self._speed = 1
	self._rot = 0
	self._t = 0
	self._ang = -math.pi / 4
	self._hover = false
	local TILT = 0.35
	local ct, stn = math.cos(TILT), math.sin(TILT)

	RunService.RenderStepped:Connect(function(dt)
		local target = 1
		if self.state == "hack" or self.state == "thinking" then
			target = 3.2
		elseif self.state == "talking" then
			target = 1.7
		elseif self.state == "error" then
			target = 2.4
		end
		self._speed = self._speed + (target - self._speed) * math.min(1, dt * 3)
		self._rot = self._rot + dt * 0.25 * self._speed
		self._t = self._t + dt

		local amp = 0.025 * math.sin(self._t * 2)
		if self.state == "talking" then
			amp = 0.07 * (0.5 + 0.5 * math.sin(self._t * 14) * math.sin(self._t * 5.3))
		elseif self.state == "hack" then
			amp = 0.05 * math.sin(self._t * 8)
		elseif self.state == "error" then
			amp = 0.06 * math.sin(self._t * 10)
		end

		local R = 0.27 * (1 + amp)
		local cr, sr = math.cos(self._rot), math.sin(self._rot)
		for _, q in ipairs(self.pts) do
			local p = q.p
			local X = p.X * cr + p.Z * sr
			local Z = -p.X * sr + p.Z * cr
			local Y = p.Y * ct - Z * stn
			Z = p.Y * stn + Z * ct
			q.d.Position = UDim2.fromScale(0.5 + X * R, 0.5 + Y * R)
			q.d.BackgroundTransparency = 1 - (0.12 + 0.75 * (Z + 1) / 2)
			q.d.BackgroundColor3 = self.accent == C_HACK and C_HACK or (self.accent == C_ERR and C_ERR or C2)
		end

		core.Size = UDim2.fromScale(0.12 * (1 + amp * 3), 0.12 * (1 + amp * 3))
		glow.BackgroundTransparency = 0.88 - amp * 0.8
		glow.BackgroundColor3 = self.accent

		self.ringTicks.Rotation = (self.ringTicks.Rotation + dt * 5 * self._speed) % 360
		self.ringArcs.Rotation = (self.ringArcs.Rotation - dt * 14 * self._speed) % 360

		if not self._hover then
			self._ang = self._ang + dt * 0.3
		end
		node.Position = UDim2.fromScale(0.5 + math.cos(self._ang) * 0.475, 0.5 + math.sin(self._ang) * 0.475)
	end)
end

function Visual:setFace(_keys)
end

function Visual:flashCutin(_key)
end

function Visual:setExpression(state)
	self.state = state or "idle"
	local color = C
	if self.state == "talking" then
		color = C2
	elseif self.state == "hack" then
		color = C_HACK
	elseif self.state == "done" then
		color = C_DONE
	elseif self.state == "error" then
		color = C_ERR
	end
	self.accent = color
	if self.status then
		self.status.Text = LABEL[self.state] or "EN LINEA"
		self.status.TextColor3 = color
	end
	if self.orbitStroke then
		self.orbitStroke.Color = color
	end
	if self.midStroke then
		self.midStroke.Color = color
	end
	if self.node then
		self.node.BackgroundColor3 = color
	end
	if self.title then
		if self.state == "hack" or self.state == "error" then
			self.title.TextColor3 = color
		else
			self.title.TextColor3 = C2
		end
	end
end

return Visual
