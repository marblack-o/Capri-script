--[[
  UAIBridge.lua
  Que: puente con Project UAI (carga, providers, sesiones, misiones).
]]

local UAI_URL = "https://raw.githubusercontent.com/Project-Ptolemy/ProjectUAI/main/dist/uai.lua"

local UAIBridge = {}
UAIBridge.handle = nil
UAIBridge.lastError = nil

function UAIBridge.ensure(allowVisible)
	if UAIBridge.handle and UAIBridge.handle.alive then
		return true, nil
	end
	local function boot(ui)
		local opts = {}
		opts.ui = ui and true or false
		opts.reuse = true
		local ok, h = pcall(function()
			return loadstring(game:HttpGet(UAI_URL))(opts)
		end)
		if ok and type(h) == "table" and h.alive then
			return h
		end
		return nil, (not ok and tostring(h)) or "not alive"
	end
	local h = select(1, boot(false))
	if h then
		UAIBridge.handle = h
		pcall(function()
			if h.sdk and h.sdk.createScope then
				h.sdk.createScope("capri-host")
			end
		end)
		return true, nil
	end
	if allowVisible ~= false then
		local h2 = select(1, boot(true))
		if h2 then
			UAIBridge.handle = h2
			pcall(function()
				if h2.sdk and h2.sdk.createScope then
					h2.sdk.createScope("capri-host")
				end
			end)
			return true, "needs_setup"
		end
	end
	UAIBridge.lastError = "UAI offline"
	return false, UAIBridge.lastError
end

function UAIBridge.show(section)
	local ok = UAIBridge.ensure(true)
	if not ok or not UAIBridge.handle then
		return false, "UAI offline"
	end
	local h = UAIBridge.handle
	if h.show then
		local ok2, err = pcall(function()
			h.show(section or "chat")
		end)
		return ok2, err
	end
	return false, "show() no disponible"
end

local function prov(id, preset, name, desc, keyField, link, baseUrl, model, forCapri, noKey)
	local p = {}
	p.id = id
	p.preset = preset
	p.name = name
	p.desc = desc
	p.keyField = keyField
	p.link = link
	p.baseUrl = baseUrl
	p.model = model
	p.forCapri = forCapri
	p.noKey = noKey
	return p
end

UAIBridge.PROVIDER_CATALOG = {
	prov("groq", "groq", "Groq", "Chat Capri (tools UAI limitados)", "groq_key", "https://console.groq.com/keys", "https://api.groq.com/openai/v1", "openai/gpt-oss-20b", true, nil),
	prov("openrouter", "openrouter", "OpenRouter", "Fallback con tools (gpt-4o-mini)", "openrouter_key", "https://openrouter.ai/keys", "https://openrouter.ai/api/v1", "openai/gpt-4o-mini", nil, nil),
	prov("openai", "openai", "OpenAI", "Fallback UAI tools", "openai_key", "https://platform.openai.com/api-keys", "https://api.openai.com/v1", "gpt-4o-mini", nil, nil),
	prov("deepseek", "deepseek", "DeepSeek", "Fallback UAI", "deepseek_key", "https://platform.deepseek.com/api_keys", "https://api.deepseek.com/v1", "deepseek-chat", nil, nil),
	prov("hcnsec", "hcnsec", "HCNSEC", "Key personal (red Free)", "hcnsec_key", "https://www.hcnsec.cn/", "https://api.hcnsec.cn/v1", "auto", nil, nil),
	prov("uai_free", nil, "Project UAI Free", "Sin key · 20:00-12:00 UTC+8", nil, "https://discord.gg/9xYyyYuKap", nil, nil, nil, true),
}

function UAIBridge.injectProvider(provInfo, apiKey)
	local okLoad, errLoad = UAIBridge.ensure(true)
	if not okLoad then
		return false, "UAI: " .. tostring(errLoad)
	end
	local uai = UAIBridge.handle
	if not uai.providers then
		return false, "uai.providers no existe en esta build"
	end

	local record
	local okB, blank = pcall(function()
		if provInfo.preset then
			local r = uai.providers.blank(provInfo.preset)
			if r then
				return r
			end
		end
		return uai.providers.blank("custom")
	end)
	if okB and type(blank) == "table" then
		record = blank
	else
		record = {}
	end
	record.label = provInfo.name
	record.baseUrl = record.baseUrl or provInfo.baseUrl
	record.apiKey = apiKey
	record.authStyle = record.authStyle or "bearer"
	record.api = record.api or "openai"
	if provInfo.model then
		record.model = provInfo.model
		record.models = record.models or { provInfo.model }
	end

	local okS, a, b = pcall(function()
		return uai.providers.save(record)
	end)
	if not okS then
		return false, "save error: " .. tostring(a)
	end
	if a == true then
		local saved = b
		if type(saved) == "table" and saved.id and uai.providers.setActive then
			pcall(function()
				uai.providers.setActive(saved.id)
			end)
		end
		return true, "Activo en UAI: " .. provInfo.name .. " / " .. tostring(provInfo.model or "?")
	elseif type(a) == "table" and a.id then
		if uai.providers.setActive then
			pcall(function()
				uai.providers.setActive(a.id)
			end)
		end
		return true, "Activo en UAI: " .. provInfo.name
	else
		local probs = b or a
		if type(probs) == "table" then
			return false, table.concat(probs, "; ")
		end
		return false, tostring(probs)
	end
end

function UAIBridge.activateFallback(cfg)
	local order = { "openrouter", "openai", "deepseek", "hcnsec", "groq" }
	local byId = {}
	for _, p in ipairs(UAIBridge.PROVIDER_CATALOG) do
		byId[p.id] = p
	end
	for _, id in ipairs(order) do
		local provInfo = byId[id]
		if provInfo and provInfo.keyField then
			local key = (cfg.provider_keys and cfg.provider_keys[provInfo.keyField]) or (provInfo.keyField == "groq_key" and cfg.groq_key)
			if type(key) == "string" and key ~= "" then
				local ok, msg = UAIBridge.injectProvider(provInfo, key)
				if ok then
					return true, msg, provInfo.name
				end
			end
		end
	end
	return false, "Sin keys de fallback", nil
end

function UAIBridge.friendlyError(err, cfg)
	local e = tostring(err or "")
	local low = e:lower()
	if low:find("tool choice") or low:find("tool_choice") or low:find("called a tool") then
		return e .. "\n\nEste modelo/provider no maneja bien las tools de UAI. Usa OpenRouter (openai/gpt-4o-mini) u OpenAI gpt-4o-mini, o Project UAI Free en horario."
	end
	if low:find("20:00") or low:find("utc+8") or low:find("outside its daily") then
		local ok, msg, name = UAIBridge.activateFallback(cfg or {})
		if ok then
			return e .. "\n\nFallback " .. tostring(name) .. " activado. Reintenta el !hack.\n(" .. tostring(msg) .. ")"
		end
		return e .. "\n\nFree offline (20:00-12:00 UTC+8). Guarda otra key en Providers."
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
			local openOpts = {}
			openOpts.title = "Capri Hack"
			openOpts.ephemeral = true
			local sid = "capri-hack-" .. tostring(math.floor(os.clock() * 1000))
			local okS, a, b = pcall(function()
				return uai.sessions.open(sid, openOpts)
			end)
			if okS then
				session = a
				sessionErr = b
			else
				sessionErr = a
			end
		else
			sessionErr = "sessions.open missing"
		end
		if not session then
			onComplete(false, UAIBridge.friendlyError("No sesion: " .. tostring(sessionErr), cfg))
			return
		end

		local settled = false
		local finalResult = nil
		local function finish(ok, payload)
			if settled then
				return
			end
			settled = true
			onComplete(ok, payload)
		end

		local reqOpts = {}
		reqOpts.onComplete = function(result)
			finalResult = result
		end

		local req
		local okReq, a, b = pcall(function()
			return uai.sdk.request(session, prompt, reqOpts)
		end)
		if not okReq then
			finish(false, "sdk.request: " .. tostring(a))
			return
		end
		req = a
		if not req then
			finish(false, UAIBridge.friendlyError(b, cfg))
			return
		end

		local WAIT = 300
		if type(req.await) == "function" then
			local okW, result, waitErr = pcall(function()
				return req.await(WAIT)
			end)
			if not okW then
				finish(false, "await: " .. tostring(result))
				return
			end
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
				if r.ok then
					finish(true, r.text or r.output or "Hack listo.")
				else
					finish(false, UAIBridge.friendlyError(r.error or r.message, cfg))
				end
				return
			end
			task.wait(0.35)
		end
		if not settled then
			finish(false, "Timeout UAI")
		end
	end)
end

return UAIBridge
