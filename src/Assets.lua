--[[
  Assets.lua
  Que: descarga y cachea PNG del repo (assets/) via getcustomasset.
  Por que: sprite cuerpo+cara y cut-ins usan nombres reales del repo.
]]

local BASE = "https://raw.githubusercontent.com/marblack-o/Capri-script/main/assets/"
local cache = {}
local Assets = { urls = {}, images = {} }

function Assets.load(fileName)
	if cache[fileName] ~= nil then
		return cache[fileName]
	end
	local localPath = "CapriAsset_" .. fileName
	if type(isfile) == "function" and type(writefile) == "function" then
		if not isfile(localPath) then
			local ok, res = pcall(function()
				return game:HttpGet(BASE .. fileName)
			end)
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
		if img and img ~= "" then
			return img
		end
	end
	return ""
end

function Assets.preload()
	local map = {}
	map.Full = "capri-full.png"
	map.Cutout = "capri-cutout.png"
	map.Face = "capri-face.png"
	map.FaceCalm = "face-calm.png"
	map.FaceLook = "face-look.png"
	map.FaceAside = "face-aside.png"
	map.FaceSmug = "face-smug.png"
	map.FaceLaugh = "face-laugh.png"
	map.FaceWide = "face-wide.png"
	map.FaceMany = "face-many.png"
	map.Grin = "cutin-grin.png"
	map.Eyes = "cutin-eyes.png"
	map.Laugh = "cutin-laugh.png"
	for k, file in pairs(map) do
		Assets.images[k] = Assets.load(file)
	end
	return Assets.images
end

return Assets
