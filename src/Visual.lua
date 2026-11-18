--[[
  Visual.lua
  Que: HUD J.A.R.V.I.S. (esfera Claude + estados + sombra capas + intro).
  Parent: ScreenGui del App (CoreGui). Click esfera/nodo -> onClick (UI_Chat).
  API: Visual.new, setExpression, setFace, flashCutin, onClick
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Visual = {}
Visual.__index = Visual

local rgb = Color3.fromRGB

local CFG = {
	NAME = "J.A.R.V.I.S.",
	SIZE = 0.30,
	MIN_PX = 150,
	MAX_PX = 340,
	LAT = 7,
	LON = 6,
	PTS = 28,
	STARS = 40,
	TILT = 0.35,
}

local C_SHADOW = rgb(4, 18, 40)

local STATES = {
	idle = {
		label = "EN LINEA",
		main = rgb(53, 200, 255),
		light = rgb(143, 230, 255),
		speed = 1,
		amp = function(t)
			return 0.025 * math.sin(t * 2)
		end,
	},
	listening = {
		label = "ESCUCHANDO...",
		main = rgb(70, 255, 210),
		light = rgb(170, 255, 235),
		speed = 1.4,
		amp = function(t)
			return 0.03 * (0.5 + 0.5 * math.sin(t * 4))
		end,
	},
	thinking = {
		label = "PROCESANDO...",
		main = rgb(255, 190, 60),
		light = rgb(255, 226, 150),
		speed = 3.2,
		amp = function(t)
			return 0.05 * math.sin(t * 8)
		end,
	},
	speaking = {
		label = "RESPONDIENDO...",
		main = rgb(70, 160, 255),
		light = rgb(175, 218, 255),
		speed = 1.7,
		amp = function(t)
			return 0.07 * (0.5 + 0.5 * math.sin(t * 14) * math.sin(t * 5.3))
		end,
	},
	error = {
		label = "ERROR DE ENLACE",
		main = rgb(255, 80, 95),
		light = rgb(255, 160, 168),
		speed = 0.6,
		amp = function(t)
			return 0.05 * math.sin(t * 26)
		end,
	},
}
STATES.talking = STATES.speaking
STATES.hack = STATES.thinking
STATES.done = {
	label = "LISTO",
	main = rgb(80, 255, 180),
	light = rgb(160, 255, 210),
	speed = 1.2,
	amp = function(t)
		return 0.03 * math.sin(t * 3)
	end,
}

local function near(a, b)
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01
end

local function tween(inst, time, goal, style, dir)
	local tw = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		goal
	)
	tw:Play()
	return tw
end

function Visual.new(gui, Assets, Theme)
	local self = setmetatable({}, Visual)
	self.gui = gui
	self.Assets = Assets
	self.Theme = Theme
	self.state = "idle"
	self.onClick = nil
	self.token = 0
	self.curMain = STATES.idle.main
	self.curLight = STATES.idle.light
	self.tinted = {}
	self:_build()
	return self
end

function Visual:_mk(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	elseif o:IsA("UIStroke") then
		o.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	for k, v in pairs(props) do
		if type(v) == "string" and v:sub(1, 1) == "@" and (k == "Color" or k:sub(-6) == "Color3") then
			local which = v:sub(2)
			self.tinted[#self.tinted + 1] = { o, k, which }
			o[k] = which == "main" and self.curMain or self.curLight
		else
			o[k] = v
		end
	end
	o.Parent = parent
	return o
end

function Visual:_applyTint()
	for _, e in ipairs(self.tinted) do
		e[1][e[2]] = e[3] == "main" and self.curMain or self.curLight
	end
end

function Visual:_fireClick()
	if type(self.onClick) == "function" then
		self.onClick()
	end
end

function Visual:_build()
	local gui = self.gui
	local function mk(c, p, parent)
		return self:_mk(c, p, parent)
	end
	local CENTER = Vector2.new(0.5, 0.5)
	local ROUND = UDim.new(1, 0)

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
		local s = math.clamp(math.min(v.X, v.Y) * CFG.SIZE, CFG.MIN_PX, CFG.MAX_PX)
		stage.Size = UDim2.fromOffset(s, s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local shadow = mk("Frame", {
		Name = "Shadow",
		AnchorPoint = CENTER,
		Position = UDim2.new(0.5, 6, 0.5, 8),
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, stage)
	self.shadow = shadow
	for _, L in ipairs({ { 1.00, 0.94 }, { 0.92, 0.88 }, { 0.84, 0.80 }, { 0.76, 0.68 } }) do
		local f = mk("Frame", {
			Name = "ShadowLayer",
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(L[1], L[1]),
			BackgroundColor3 = C_SHADOW,
			BackgroundTransparency = L[2],
		}, shadow)
		mk("UICorner", { CornerRadius = ROUND }, f)
	end

	local function circle(name, thick, transp)
		local f = mk("Frame", {
			Name = name,
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, stage)
		mk("UICorner", { CornerRadius = ROUND }, f)
		mk("UIStroke", { Color = "@main", Thickness = thick, Transparency = transp }, f)
		return f
	end

	self.ringOuter = circle("RingOuter", 1, 0.7)
	self.ringInner = circle("RingInner", 1, 0.45)

	local function segRing(name, radius, count, w, h, rotOffset, transp)
		local holder = mk("Frame", {
			Name = name,
			AnchorPoint = CENTER,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0, 0),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, stage)
		for i = 1, count do
			local a = math.rad(i * 360 / count)
			mk("Frame", {
				AnchorPoint = CENTER,
				BackgroundColor3 = "@main",
				BackgroundTransparency = transp,
				Size = UDim2.fromOffset(w, h),
				Position = UDim2.fromScale(0.5 + math.cos(a) * radius, 0.5 + math.sin(a) * radius),
				Rotation = math.deg(a) + rotOffset,
			}, holder)
		end
		return holder
	end

	self.ringTicks = segRing("RingTicks", 0.42, 72, 2, 7, -90, 0.35)
	self.ringArcs = segRing("RingArcs", 0.375, 18, 28, 3, 0, 0.15)

	local sphere = mk("Frame", {
		Name = "Sphere",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, stage)

	local glow = mk("Frame", {
		Name = "Glow",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		BackgroundColor3 = "@main",
		BackgroundTransparency = 0.88,
	}, sphere)
	mk("UICorner", { CornerRadius = ROUND }, glow)
	self.glow = glow

	local pts = {}
	local function addCurve(fn, n, size)
		for i = 0, n - 1 do
			local p = fn(i / n)
			local d = mk("Frame", {
				Name = "Dot",
				AnchorPoint = CENTER,
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = "@light",
				BackgroundTransparency = 1,
				ZIndex = 5,
			}, sphere)
			pts[#pts + 1] = { d = d, x = p.X, y = p.Y, z = p.Z }
		end
	end

	for i = 0, CFG.LAT - 1 do
		local ph = math.rad(-75 + i * (150 / math.max(CFG.LAT - 1, 1)))
		addCurve(function(u)
			return Vector3.new(
				math.cos(ph) * math.cos(u * 6.283),
				math.sin(ph),
				math.cos(ph) * math.sin(u * 6.283)
			)
		end, CFG.PTS, 2)
	end
	for i = 0, CFG.LON - 1 do
		local th = math.rad(i * (180 / math.max(CFG.LON, 1)))
		addCurve(function(u)
			local p = u * 6.283
			return Vector3.new(math.cos(p) * math.cos(th), math.sin(p), math.cos(p) * math.sin(th))
		end, CFG.PTS + 8, 2)
	end
	for _ = 1, CFG.STARS do
		local u, a = math.random() * 2 - 1, math.random() * 6.283
		local s = math.sqrt(math.max(0, 1 - u * u))
		local fixed = Vector3.new(s * math.cos(a), u, s * math.sin(a))
		addCurve(function()
			return fixed
		end, 1, 3)
	end
	self.pts = pts

	local core = mk("Frame", {
		Name = "Core",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 0.1,
		ZIndex = 6,
	}, sphere)
	mk("UICorner", { CornerRadius = ROUND }, core)
	self.core = core

	local sphereHit = mk("TextButton", {
		Name = "SphereHit",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		ZIndex = 7,
	}, stage)
	sphereHit.MouseButton1Click:Connect(function()
		self:_fireClick()
	end)
	sphereHit.Activated:Connect(function()
		self:_fireClick()
	end)

	local node = mk("TextButton", {
		Name = "OrbitNode",
		AnchorPoint = CENTER,
		Size = UDim2.fromOffset(22, 22),
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		BackgroundColor3 = "@light",
		ZIndex = 10,
	}, stage)
	mk("UICorner", { CornerRadius = ROUND }, node)
	mk("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1.5 }, node)
	self.node = node
	node.MouseButton1Click:Connect(function()
		self:_fireClick()
	end)
	node.Activated:Connect(function()
		self:_fireClick()
	end)

	local pulse = mk("Frame", {
		Name = "Pulse",
		AnchorPoint = CENTER,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 9,
	}, node)
	mk("UICorner", { CornerRadius = ROUND }, pulse)
	local pulseStroke = mk("UIStroke", { Color = "@main", Thickness = 1.5 }, pulse)
	local pulseInfo = TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
	TweenService:Create(pulse, pulseInfo, { Size = UDim2.fromScale(2.6, 2.6) }):Play()
	TweenService:Create(pulseStroke, pulseInfo, { Transparency = 1 }):Play()

	local nodeLabel = mk("TextLabel", {
		Name = "NodeLabel",
		Text = "CHAT",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = "@light",
		BackgroundTransparency = 1,
		TextTransparency = 1,
		Position = UDim2.new(1, 8, 0.5, -8),
		Size = UDim2.fromOffset(60, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	}, node)
	self.nodeLabel = nodeLabel

	mk("TextLabel", {
		Name = "Title",
		Text = CFG.NAME,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = "@light",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(200, 20),
		ZIndex = 5,
	}, stage)

	local status = mk("TextLabel", {
		Name = "Status",
		Text = STATES.idle.label,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = "@main",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 24),
		Size = UDim2.fromOffset(200, 14),
		ZIndex = 5,
	}, stage)
	self.status = status

	node.MouseEnter:Connect(function()
		self._hover = true
		tween(nodeLabel, 0.2, { TextTransparency = 0 })
		tween(node, 0.2, { Size = UDim2.fromOffset(26, 26) })
	end)
	node.MouseLeave:Connect(function()
		self._hover = false
		tween(nodeLabel, 0.2, { TextTransparency = 1 })
		tween(node, 0.2, { Size = UDim2.fromOffset(22, 22) })
	end)
	sphereHit.MouseEnter:Connect(function()
		self._sphereHover = true
	end)
	sphereHit.MouseLeave:Connect(function()
		self._sphereHover = false
	end)

	local dragging, start, startPos = false, nil, nil
	stage.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
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
			if math.abs(d.X) > 8 or math.abs(d.Y) > 8 then
				stage.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + d.X,
					startPos.Y.Scale,
					startPos.Y.Offset + d.Y
				)
			end
		end
	end)

	self._speed = 1
	self._rot = 0
	self._t = 0
	self._ang = -math.pi / 4
	self._amp = 0
	self._hoverK = 0
	self._hover = false
	self._sphereHover = false
	self._introT = 0
	self._introDone = false
	local ct, stn = math.cos(CFG.TILT), math.sin(CFG.TILT)

	local function easeAt(introT, delay)
		local x = math.clamp((introT - delay) / 0.9, 0, 1)
		return 1 - (1 - x) ^ 3
	end

	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		self._t = self._t + dt
		local S = STATES[self.state] or STATES.idle

		if self.curMain ~= S.main or self.curLight ~= S.light then
			local k = 1 - math.exp(-dt * 6)
			self.curMain = self.curMain:Lerp(S.main, k)
			self.curLight = self.curLight:Lerp(S.light, k)
			if near(self.curMain, S.main) and near(self.curLight, S.light) then
				self.curMain, self.curLight = S.main, S.light
			end
			self:_applyTint()
		end

		local e0, e1, e2 = 1, 1, 1
		if not self._introDone then
			self._introT = self._introT + dt
			e0 = easeAt(self._introT, 0)
			e1 = easeAt(self._introT, 0.2)
			e2 = easeAt(self._introT, 0.4)
			self.ringOuter.Size = UDim2.fromScale(0.95 * e1, 0.95 * e1)
			self.ringInner.Size = UDim2.fromScale(0.66 * e1, 0.66 * e1)
			self.ringTicks.Size = UDim2.fromScale(e2, e2)
			self.ringArcs.Size = UDim2.fromScale(e2, e2)
			if self._introT >= 1.6 then
				self._introDone = true
				e0, e1, e2 = 1, 1, 1
			end
		end

		self._speed = self._speed + (S.speed - self._speed) * math.min(1, dt * 3)
		self._amp = self._amp + (S.amp(self._t) - self._amp) * math.min(1, dt * 12)
		self._hoverK = self._hoverK + ((self._sphereHover and 1 or 0) - self._hoverK) * math.min(1, dt * 8)
		self._rot = self._rot + dt * 0.25 * self._speed

		local sh = e0 * (1 + 0.025 * math.sin(self._t * 1.3) + self._amp * 0.6)
		shadow.Size = UDim2.fromScale(0.82 * sh, 0.82 * sh)

		local R = 0.27 * (1 + self._amp + self._hoverK * 0.04) * e0
		local cr, sr = math.cos(self._rot), math.sin(self._rot)
		local lift = self._hoverK * 0.1
		local fade = 1 - e0
		for i = 1, #pts do
			local q = pts[i]
			local x, y, z = q.x, q.y, q.z
			local X = x * cr + z * sr
			local Z = -x * sr + z * cr
			local Y = y * ct - Z * stn
			Z = y * stn + Z * ct
			local d = q.d
			d.Position = UDim2.fromScale(0.5 + X * R, 0.5 + Y * R)
			d.BackgroundTransparency = math.min(1, 0.88 - 0.75 * (Z + 1) / 2 - lift + fade)
		end

		local cs = 0.12 * (1 + self._amp * 3) * e0
		core.Size = UDim2.fromScale(cs, cs)
		glow.BackgroundTransparency = math.clamp(0.88 - self._amp * 0.8 - self._hoverK * 0.05, 0, 1)
		self.ringTicks.Rotation = (self.ringTicks.Rotation + dt * 5 * self._speed) % 360
		self.ringArcs.Rotation = (self.ringArcs.Rotation - dt * 14 * self._speed) % 360

		if not self._hover then
			self._ang = self._ang + dt * 0.3
		end
		local orbit = 0.475 * e1
		node.Position = UDim2.fromScale(0.5 + math.cos(self._ang) * orbit, 0.5 + math.sin(self._ang) * orbit)
	end)
end

function Visual:setFace(_keys)
end

function Visual:flashCutin(_key)
end

function Visual:setExpression(state)
	local key = state or "idle"
	if not STATES[key] then
		key = "idle"
	end
	if key == self.state then
		return
	end
	self.state = key
	local S = STATES[key]
	if self.status then
		self.status.Text = S.label
		self.status.TextTransparency = 0.7
		tween(self.status, 0.25, { TextTransparency = 0 })
	end
end

function Visual:setChatOpen(open)
	if self.nodeLabel then
		self.nodeLabel.Text = open and "CERRAR" or "CHAT"
	end
end

return Visual
