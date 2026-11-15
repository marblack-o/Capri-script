--[[
  UAIBridge.lua
  Qué: puente con Project UAI (carga, providers, sesiones, misiones, navegación nativa).
  Por qué: Capri no reimplementa el agente; reutiliza sdk.request / providers / show().
  APIs clave:
    - ensure() → loadstring dist/uai.lua {ui,reuse}
    - injectProvider(prov, key) → providers.blank/save/setActive
    - runMission(prompt, cb) → sessions.open + sdk.request + await
    - show(section) → uai.show("chat"|"providers"|"logs")
]]

local UAI_URL = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua"

local UAIBridge = {
	handle = nil,
	lastError = nil,
}

function UAIBridge.ensure(allowVisible)
	if UAIBridge.handle and UAIBridge.handle.alive then
		return true, nil
	end
	local function boot(ui)
		local ok, h = pcall(function()
			return loadstring(game:HttpGet(UAI_URL))({ ui = ui and true or false, reuse = true })
		end)
		if ok and type(h) == "table" and h.alive then return h end
		return nil, (not ok and tostring(h)) or "not alive"
	end
	local h = select(1, boot(false))
	if h then
		UAIBridge.handle = h
		pcall(function()
			if h.sdk and h.sdk.createScope then h.sdk.createScope("capri-host") end
		end)
		return true, nil
	end
	if allowVisible ~= false then
		local h2 = select(1, boot(true))
		if h2 then
			UAIBridge.handle = h2
			pcall(function()
				if h2.sdk and h2.sdk.createScope then h2.sdk.createScope("capri-host") end
			end)
			return true, "needs_setup"
		end
	end
	UAIBridge.lastError = "UAI offline"
	return false, UAIBridge.lastError
end

function UAIBridge.show(section)
	local ok = UAIBridge.ensure(true)
	if not ok or not UAIBridge.handle then return false, "UAI offline" end
	local h = UAIBridge.handle
	if h.show then
		local ok2, err = pcall(function() h.show(section or "chat") end)
		return ok2, err
	end
	return false, "show() no disponible"
end

-- Catálogo alineado con presets UAI (openai-compatible + links oficiales)
UAIBridge.PROVIDER_CATALOG = {
	{ id = "groq", preset = "groq", name = "Groq", desc = "Chat Capri + fallback UAI", keyField = "groq_key",
		link = "https://console.groq.com/keys", baseUrl = "https://api.groq.com/openai/v1", model = "openai/gpt-oss-20b", forCapri = true },
	{ id = "openrouter", preset = "openrouter", name = "OpenRouter", desc = "Fallback multi-modelo", keyField = "openrouter_key",
		link = "https://openrouter.ai/keys", baseUrl = "https://openrouter.ai/api/v1", model = "openrouter/auto" },
	{ id = "openai", preset = "openai", name = "OpenAI", desc = "Fallback UAI", keyField = "openai_key",
		link = "https://platform.openai.com/api-keys", baseUrl = "https://api.openai.com/v1", model = "gpt-4o-mini" },
	{ id = "deepseek", preset = "deepseek", name = "DeepSeek", desc = "Fallback UAI", keyField = "deepseek_key",
		link = "https://platform.deepseek.com/api_keys", baseUrl = "https://api.deepseek.com/v1", model = "deepseek-chat" },
	{ id = "hcnsec", preset = "hcnsec", name = "HCNSEC", desc = "Key personal (red Free)", keyField = "hcnsec_key",
		link = "https://www.hcnsec.cn/", baseUrl = "https://api.hcnsec.cn/v1", model = "auto" },
	{ id = "uai_free", name = "Project UAI Free", desc = "Sin key · 20:00–12:00 UTC+8", keyField = nil,
		link = "https://discord.gg/9xYyyYuKap", noKey = true },
}

function UAIBridge.injectProvider(prov, apiKey)
	local okLoad, errLoad = UAIBridge.ensure(true)
	if not okLoad then return false, "UAI: " .. tostring(errLoad) end
	local uai = UAIBridge.handle
	if not uai.providers then return false, "uai.providers no existe en esta build" end

	local record
	local okB, blank = pcall(function()
		if prov.preset then
			local r = uai.providers.blank(prov.preset)
			if r then return r end
		end
		return uai.providers.blank("custom")
	end)
	if okB and type(blank) == "table" then
		record = blank
	else
		record = {}
	end
	record.label = prov.name
	record.baseUrl = record.baseUrl or prov.baseUrl
	record.apiKey = apiKey
	record.authStyle = record.authStyle or "bearer"
	record.api = record.api or "openai"
	if prov.model then
		record.model = prov.model
		record.models = record.models or { prov.model }
	end

	local okS, a, b = pcall(function()
		return uai.providers.save(record)
	end)
	if not okS then return false, "save error: " .. tostring(a) end
	if a == true then
		local saved = b
		if type(saved) == "table" and saved.id and uai.providers.setActive then
			pcall(function() uai.providers.setActive(saved.id) end)
		end
		return true, "Activo en UAI: " .. prov.name
	elseif type(a) == "table" and a.id then
		if uai.providers.setActive then pcall(function() uai.providers.setActive(a.id) end) end
		return true, "Activo en UAI: " .. prov.name
	else
		local probs = b or a
		if type(probs) == "table" then return false, table.concat(probs, "; ") end
		return false, tostring(probs)
	end
end

function UAIBridge.activateFallback(cfg)
	local order = { "openrouter", "openai", "deepseek", "hcnsec", "groq" }
	local byId = {}
	for _, p in ipairs(UAIBridge.PROVIDER_CATALOG) do byId[p.id] = p end
	for _, id in ipairs(order) do
		local prov = byId[id]
		if prov and prov.keyField then
			local key = (cfg.provider_keys and cfg.provider_keys[prov.keyField])
				or (prov.keyField == "groq_key" and cfg.groq_key)
			if type(key) == "string" and key ~= "" then
				local ok, msg = UAIBridge.injectProvider(prov, key)
				if ok then return true, msg, prov.name end
			end
		end
	end
	return false, "Sin keys de fallback", nil
end

function UAIBridge.friendlyError(err, cfg)
	local e = tostring(err or "")
	local low = e:lower()
	if low:find("20:00") or low:find("utc+8") or low:find("outside its daily") then
		local ok, msg, name = UAIBridge.activateFallback(cfg or {})
		if ok then
			return e .. "\n\nFallback " .. tostring(name) .. " activado en UAI. Reintenta el !hack.\n(" .. tostring(msg) .. ")"
		end
		return e .. "\n\nFree offline (20:00–12:00 UTC+8). Guarda otra key en Providers y reintenta."
	end
	if low:find("provider") then
		return e .. "\n\nConfigura Providers (se inyectan en UAI al guardar)."
	end
	return e
end

function UAIBridge.runMission(prompt, onComplete, cfg)
	task.spawn(function()
		local okLoad, loadErr = UAIBridge.ensure(true)
		if not okLoad then
			onComplete(false, UAIBridge.friendlyError(loadErr, cfg))
			return
		end
		local uai = UAIBridge.handle
		if not uai.sdk or not uai.sdk.request then
			onComplete(false, "sdk.request no disponible")
			return
		end
		local session, sessionErr
		if uai.sessions and uai.sessions.open then
			local okS, a, b = pcall(function()
				return uai.sessions.open("capri-hack-" .. tostring(math.floor(os.clock() * 1000)), {
					title = "Capri Hack",
					ephemeral = true,
					toolFilter = {},
				})
			end)
			if okS then session, sessionErr = a, b else sessionErr = a end
		else
			sessionErr = "sessions.open missing"
		end
		if not session then
			onComplete(false, UAIBridge.friendlyError("No sesión: " .. tostring(sessionErr), cfg))
			return
		end

		local settled, finalResult = false, nil
		local function finish(ok, payload)
			if settled then return end
			settled = true
			onComplete(ok, payload)
		end

		local req
		local okReq, a, b = pcall(function()
			return uai.sdk.request(session, prompt, {
				onComplete = function(result) finalResult = result end,
			})
		end)
		if not okReq then finish(false, "sdk.request: " .. tostring(a)) return end
		req = a
		if not req then
			finish(false, UAIBridge.friendlyError(b, cfg))
			return
		end

		local WAIT = 300
		if type(req.await) == "function" then
			local okW, result, waitErr = pcall(function() return req.await(WAIT) end)
			if not okW then finish(false, "await: " .. tostring(result)) return end
			if result == nil then
				local left = req.result or finalResult
				if left and left.ok then
					finish(true, left.text or left.output or "Hack listo.")
				else
					finish(false, UAIBridge.friendlyError(waitErr or (left and left.error) or "Timeout", cfg))
				end
				return
			end
			if type(result) == "table" then
				if result.ok then
					finish(true, result.text or result.output or result.message or "Hack listo.")
				else
					finish(false, UAIBridge.friendlyError(result.error or result.message, cfg))
				end
				return
			end
		end

		local t0 = os.clock()
		while not settled and (os.clock() - t0) < WAIT do
			local r = (req and req.result) or finalResult
			if type(r) == "table" and (r.ok == true or r.ok == false or r.text or r.error) then
				if r.ok then finish(true, r.text or r.output or "Hack listo.")
				else finish(false, UAIBridge.friendlyError(r.error or r.message, cfg)) end
				return
			end
			task.wait(0.35)
		end
		if not settled then finish(false, "Timeout UAI") end
	end)
end

return UAIBridge
