--[[
  Assets.lua
  Qué: descarga y cachea PNG del repo (assets/) vía getcustomasset.
  Por qué: el sprite cuerpo+cara y cut-ins usan nombres reales del repo del usuario.
  Assets: capri-full, capri-cutout, face-*, cutin-*
]]

local BASE = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/assets/"
local cache = {}
local Assets = { urls = {}, images = {} }

function Assets.load(fileName)
	if cache[fileName] ~= nil then return cache[fileName] end
	local localPath = "CapriAsset_" .. fileName
	if type(isfile) == "function" and type(writefile) == "function" then
		if not isfile(localPath) then
			local ok, res = pcall(function() return game:HttpGet(BASE .. fileName) end)
			if ok and res and res ~= "" and res ~= "404: Not Found" and #res > 100 then
				pcall(writefile, localPath, res)
			else
				cache[fileName] = ""
				return ""
			end
		end
		if type(getcustomasset) == "function" then
			local ok, id = pcall(getcustomasset, localPath)
			cache[fileName] = (ok and id) or ""
			return cache[fileName]
		end
	end
	cache[fileName] = ""
	return ""
end

function Assets.pick(...)
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		local img = Assets.images[key]
		if img and img ~= "" then return img end
	end
	return ""
end

function Assets.preload()
	local map = {
		Full = "capri-full.png",
		Cutout = "capri-cutout.png",
		Face = "capri-face.png",
		FaceCalm = "face-calm.png",
		FaceLook = "face-look.png",
		FaceAside = "face-aside.png",
		FaceSmug = "face-smug.png",
		FaceLaugh = "face-laugh.png",
		FaceWide = "face-wide.png",
		FaceMany = "face-many.png",
		Grin = "cutin-grin.png",
		Eyes = "cutin-eyes.png",
		Laugh = "cutin-laugh.png",
	end
	for k, file in pairs(map) do
		Assets.images[k] = Assets.load(file)
	end
	return Assets.images
end

return Assets
