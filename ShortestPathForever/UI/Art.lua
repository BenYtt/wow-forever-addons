---@class SPFNamespace
local ns = select(2, ...)

-- Art at its native aspect (AGENTS.md: never stretch art). An atlas is sized from C_Texture.GetAtlasInfo to fit
-- inside its box, and a file icon is drawn whole. Every other file sets art only where its line says why its shape is
-- right (tools/lint_art.py).

---@class SPFArt
local Art = {}
ns.Art = Art

---@type table<string, AtlasInfo|false>
local infos = {}

-- The client's size for `atlas`, asked once; nil when the client lacks it.
---@param atlas string
---@return AtlasInfo?
function Art.Info(atlas)
	local info = infos[atlas]
	if info == nil then
		info = C_Texture.GetAtlasInfo(atlas) or false
		infos[atlas] = info
	end
	return info or nil
end

-- `atlas` at its native shape, as large as fits in `width` by `height`. The caller anchors the texture by one point,
-- so it stays centred in its box. False, leaving the texture alone, when the client lacks it.
---@param texture Texture
---@param atlas string
---@param width number
---@param height number
---@return boolean
function Art.Fit(texture, atlas, width, height)
	local info = Art.Info(atlas)
	if not info then
		return false
	end
	texture:SetAtlas(atlas)
	local scale = math.min(width / info.width, height / info.height)
	texture:SetSize(info.width * scale, info.height * scale)
	return true
end

-- A file icon, square as every one is, `size` across and whole: a texture that drew an atlas before keeps that
-- atlas's crop until it is reset.
---@param texture Texture
---@param file string|integer
---@param size number
function Art.Icon(texture, file, size)
	texture:SetTexCoord(0, 1, 0, 1)
	texture:SetTexture(file)
	texture:SetSize(size, size)
end
