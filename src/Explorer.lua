--[[
  Explorer.lua
  Que: explorador DENTRO de Capri (DataModel + archivos del executor).
  Por que: no solo abrir la UI nativa de UAI; listar/inspeccionar desde Capri.
]]

local Explorer = {}

local function clear(pane)
	for _, c in ipairs(pane:GetChildren()) do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function label(pane, text, order, color, Theme)
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, -8, 0, 18)
	row.BackgroundTransparency = 1
	row.Text = text
	row.TextColor3 = color or Theme.textDim
	row.Font = Enum.Font.Code
	row.TextSize = 11
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextTruncate = Enum.TextTruncate.AtEnd
	row.LayoutOrder = order
	row.ZIndex = 24
	row.Parent = pane
	return row
end

local function button(pane, text, order, Theme, onClick)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -8, 0, 28)
	b.BackgroundColor3 = Theme.row
	b.BackgroundTransparency = 0.1
	b.Text = "  " .. text
	b.TextColor3 = Theme.text
	b.Font = Enum.Font.Code
	b.TextSize = 12
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.ZIndex = 24
	b.Parent = pane
	Theme.mkCorner(b, 6)
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function listChildren(inst, maxN)
	local out = {}
	local ok, children = pcall(function() return inst:GetChildren() end)
	if not ok then return out end
	for i, ch in ipairs(children) do
		if i > maxN then break end
		table.insert(out, ch)
	end
	return out
end

function Explorer.render(pane, Theme, UAI)
	clear(pane)
	local order = 0
	local function nextOrder()
		order = order + 1
		return order
	end

	label(pane, "Explorador Capri (in-script, no solo UAI nativo)", nextOrder(), Theme.glitch, Theme)

	-- Raices del juego (cliente)
	label(pane, "-- DataModel --", nextOrder(), Theme.accent, Theme)
	local roots = {
		{ "Workspace", workspace },
		{ "Players", game:GetService("Players") },
		{ "ReplicatedStorage", game:GetService("ReplicatedStorage") },
		{ "ReplicatedFirst", game:GetService("ReplicatedFirst") },
		{ "Lighting", game:GetService("Lighting") },
		{ "StarterGui", game:GetService("StarterGui") },
	}

	local detail
	detail = label(pane, "Click un servicio o instancia para listar hijos.", nextOrder(), Theme.textDim, Theme)

	local function showInstance(inst, title)
		clear(pane)
		label(pane, "Explorador Capri", nextOrder(), Theme.glitch, Theme)
		button(pane, "< Volver a raices", nextOrder(), Theme, function()
			Explorer.render(pane, Theme, UAI)
		end)
		label(pane, title .. "  [" .. inst.ClassName .. "]", nextOrder(), Theme.accent, Theme)
		local okCount, count = pcall(function() return #inst:GetChildren() end)
		label(pane, "Hijos: " .. tostring(okCount and count or "?"), nextOrder(), Theme.textDim, Theme)
		for _, ch in ipairs(listChildren(inst, 60)) do
			local name = ch.Name
			local className = ch.ClassName
			button(pane, name .. "  (" .. className .. ")", nextOrder(), Theme, function()
				showInstance(ch, name)
			end)
		end
	end

	for _, entry in ipairs(roots) do
		local title, inst = entry[1], entry[2]
		button(pane, title, nextOrder(), Theme, function()
			showInstance(inst, title)
		end)
	end

	-- Archivos del executor
	label(pane, "-- Archivos executor --", nextOrder(), Theme.accent, Theme)
	if type(listfiles) == "function" then
		local ok, files = pcall(listfiles, "")
		if ok and type(files) == "table" then
			local n = 0
			for _, path in ipairs(files) do
				n = n + 1
				if n > 50 then break end
				local p = tostring(path)
				button(pane, p, nextOrder(), Theme, function()
					local preview = "(no readable)"
					if type(readfile) == "function" and type(isfile) == "function" and isfile(p) then
						local okR, body = pcall(readfile, p)
						if okR and type(body) == "string" then
							preview = body:sub(1, 400)
						end
					end
					clear(pane)
					label(pane, "Archivo: " .. p, nextOrder(), Theme.glitch, Theme)
					button(pane, "< Volver", nextOrder(), Theme, function()
						Explorer.render(pane, Theme, UAI)
					end)
					label(pane, preview, nextOrder(), Theme.textDim, Theme)
				end)
			end
			if n == 0 then
				label(pane, "(carpeta vacia)", nextOrder(), Theme.textDim, Theme)
			end
		else
			label(pane, "listfiles fallo", nextOrder(), Theme.danger, Theme)
		end
	else
		label(pane, "listfiles no disponible en este executor", nextOrder(), Theme.textDim, Theme)
	end

	label(pane, "-- UAI nativo (opcional) --", nextOrder(), Theme.accent, Theme)
	button(pane, "Abrir chat UAI", nextOrder(), Theme, function() UAI.show("chat") end)
	button(pane, "Abrir providers UAI", nextOrder(), Theme, function() UAI.show("providers") end)
	button(pane, "Abrir logs UAI", nextOrder(), Theme, function() UAI.show("logs") end)
end

return Explorer
