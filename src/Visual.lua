--[[
  Visual.lua
  Que: sprite Capri (cuerpo completo + cara), bob, expresiones y cut-in.
  Por que: presencia tipo capri-desktop con assets del repo.
  Nota: las caras del pack vienen invertidas respecto al body; Rotation=180 las corrige.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Visual = {}
Visual.__index = Visual

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
	local Theme, Assets = self.Theme, self.Assets

	local root = Instance.new("ImageButton")
	root.Name = "CapriSprite"
	root.Size = UDim2.fromOffset(130, 160)
	root.Position = UDim2.new(1, -140, 0.36, 0)
	root.BackgroundTransparency = 1
	root.AutoButtonColor = false
	root.ZIndex = 10
	root.Parent = self.gui
	self.root = root

	-- Cuerpo completo (silueta)
	local body = Instance.new("ImageLabel")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundTransparency = 1
	body.Image = Assets.pick("Full", "Cutout", "Face")
	body.ScaleType = Enum.ScaleType.Fit
	body.ZIndex = 10
	body.Parent = root
	self.body = body

	-- Cara sobre la cabeza (proporcion y orientacion corregidas)
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Size = UDim2.new(0.42, 0, 0.28, 0)
	face.Position = UDim2.new(0.5, 0, 0.04, 0)
	face.BackgroundTransparency = 1
	face.Image = Assets.pick("FaceCalm", "FaceLook", "Face")
	face.ScaleType = Enum.ScaleType.Fit
	face.Rotation = 180
	face.ZIndex = 11
	face.Parent = root
	self.face = face

	local fb = Instance.new("TextLabel")
	fb.Size = UDim2.fromScale(1, 1)
	fb.BackgroundTransparency = 1
	fb.Text = (body.Image == "" and face.Image == "") and "C" or ""
	fb.TextColor3 = Theme.accent
	fb.Font = Enum.Font.GothamBlack
	fb.TextSize = 34
	fb.ZIndex = 12
	fb.Parent = root
	self.fallback = fb

	local cutin = Instance.new("ImageLabel")
	cutin.Size = UDim2.fromOffset(110, 110)
	cutin.Position = UDim2.new(0.5, -55, 0.18, 0)
	cutin.BackgroundTransparency = 1
	cutin.Visible = false
	cutin.Rotation = 180
	cutin.ZIndex = 50
	cutin.Parent = self.gui
	self.cutin = cutin

	local dragging, moved, start, startPos = false, false, nil, nil
	local baseY = root.Position.Y.Offset
	RunService.RenderStepped:Connect(function()
		if dragging then return end
		local wave = math.sin(os.clock() * 1.35) * 3.2
		local pos = root.Position
		root.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, baseY + wave)
	end)
	root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, start, startPos = true, false, input.Position, root.Position
			baseY = startPos.Y.Offset
		end
	end)
	root.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			baseY = root.Position.Y.Offset
			if not moved and self.onClick then
				self.onClick()
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - start
			if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then
				moved = true
			end
			root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			baseY = root.Position.Y.Offset
		end
	end)
end

function Visual:setFace(keys)
	local img = self.Assets.pick(table.unpack(keys))
	if img ~= "" then
		self.face.Image = img
		self.face.Rotation = 180
		self.fallback.Text = ""
	end
	if self.body.Image == "" then
		self.body.Image = self.Assets.pick("Full", "Cutout", "Face")
	end
end

function Visual:flashCutin(key)
	local img = self.Assets.pick(key)
	if img == "" then return end
	local c = self.cutin
	c.Image = img
	c.Rotation = 180
	c.ImageTransparency = 0.1
	c.Visible = true
	c.Size = UDim2.fromOffset(70, 70)
	self.Theme.tween(c, { Size = UDim2.fromOffset(120, 120) }, 0.16, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		local t = self.Theme.tween(c, { ImageTransparency = 1 }, 0.2)
		t.Completed:Wait()
		c.Visible = false
		c.ImageTransparency = 0
	end)
end

function Visual:setExpression(state)
	self.state = state
	self.token = self.token + 1
	local token = self.token
	if state == "talking" then
		self:setFace({ "FaceLook", "FaceSmug", "FaceLaugh" })
	elseif state == "hack" then
		self:setFace({ "FaceMany", "FaceCalm" })
		task.spawn(function()
			local faces = { "FaceMany", "FaceCalm", "FaceLook" }
			local i = 1
			while self.token == token and self.state == "hack" do
				task.wait(0.85)
				if self.token ~= token then break end
				i = (i % #faces) + 1
				self:setFace({ faces[i] })
			end
		end)
	elseif state == "done" then
		self:setFace({ "FaceLaugh", "FaceSmug" })
		self:flashCutin("Grin")
		task.delay(1.4, function()
			if self.token == token then self:setExpression("idle") end
		end)
	elseif state == "error" then
		self:setFace({ "FaceWide", "FaceMany" })
		self:flashCutin("Eyes")
		task.delay(1.6, function()
			if self.token == token then self:setExpression("idle") end
		end)
	else
		self:setFace({ "FaceCalm", "FaceLook" })
		task.spawn(function()
			local faces = { "FaceCalm", "FaceLook", "FaceAside", "FaceSmug" }
			local i = 1
			while self.token == token and self.state == "idle" do
				task.wait(2.8 + math.random())
				if self.token ~= token then break end
				i = (i % #faces) + 1
				self:setFace({ faces[i] })
			end
		end)
	end
end

return Visual
