---@type string, SkillUpNamespace
local _, ns = ...

-- Art at its native aspect (AGENTS.md: never stretch art): an atlas is sized from C_Texture.GetAtlasInfo, never
-- pulled to a box of another shape. Only nine-slice pieces, bars and fills stretch, by design.

---@class SkillUpArt
local Art = {}
ns.Art = Art

-- The atlas's width over its height; square when the client doesn't know it.
---@param atlas string
---@return number
local function Aspect(atlas)
	local info = C_Texture.GetAtlasInfo(atlas)
	if info and info.width > 0 and info.height > 0 then
		return info.width / info.height
	end
	return 1
end

-- `atlas` at the largest size inside `width` by `height` at its own aspect. The caller anchors it by one point.
---@param texture Texture
---@param atlas string
---@param width number
---@param height number
---@return number width
---@return number height
function Art.Fit(texture, atlas, width, height)
	texture:SetAtlas(atlas)
	local aspect = Aspect(atlas)
	local w, h = width, width / aspect
	if h > height then
		w, h = height * aspect, height
	end
	texture:SetSize(w, h)
	return w, h
end

-- `|A:atlas:height:width|a` with the width from the atlas's aspect.
---@param atlas string
---@param height number
---@return string
function Art.Markup(atlas, height)
	return ("|A:%s:%d:%d|a"):format(atlas, height, math.floor(height * Aspect(atlas) + 0.5))
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
