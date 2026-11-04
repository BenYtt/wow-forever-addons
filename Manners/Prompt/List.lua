-- Manners -- the list of who is next, hung under the prompt (or over it, in
-- the bottom third of the screen).

local _, ns = ...
local Prompt = ns.Prompt
local S, R, lib = Prompt.state, Prompt.regions, Prompt.lib
local ink, GREYS, SetLine, ReasonColor = lib.ink, lib.GREYS, lib.SetLine, lib.ReasonColor

-- The texture each row's icon wears, so one that has not changed is not set again.
local painted = {}

-- The list and its background live outside the panel, so hiding the button
-- does not hide them. Every branch that takes the prompt down has to say so.
local function HideQueue()
	if not R.queueRows then return end
	for i, fs in ipairs(R.queueRows) do
		fs:SetText("")
		R.queueBars[i]:Hide()
		R.queueIcons[i]:Hide()
	end
	R.queueBack:Hide()
	R.queueHair:Hide()
	-- Nobody listed, so nobody to press.
	Prompt:PaintRows(nil)
	if S.activeLook then S.activeLook:PaintQueue(nil, 0, S.queueAbove) end
end

-- The list of who is next, and the panel behind it; the preview draws it too.
function Prompt:PaintQueue(rows)
	local p = ns.db.profile.prompt
	local shown = 0
	for i, fs in ipairs(R.queueRows) do
		local row = rows and rows[i]
		-- The icon of the buff the row offers, on the looks drawn here with the
		-- spell icon on; set only when it is a different one.
		local icon = R.queueIcons[i]
		if row and row.icon and not S.activeLook then
			if painted[i] ~= row.icon then
				painted[i] = row.icon
				icon:SetTexture(row.icon)
			end
			icon:Show()
		else
			icon:Hide()
		end
		if row then
			-- The words after the name in the look's own dimmer grey.
			local text = row.text
			if row.detail then
				text = text .. "  " .. (ink.rowReason or GREYS.panel.reason) .. row.detail .. "|r"
			end
			SetLine(fs, text)
			local c = ReasonColor(row.reason)
			R.queueBars[i]:SetVertexColor(c[1], c[2], c[3], 0.9)
			R.queueBars[i]:SetShown(not S.activeLook)
			shown = shown + 1
		else
			fs:SetText("")
			R.queueBars[i]:Hide()
		end
	end

	-- A look of its own lays the list out itself; then the names as buttons,
	-- laid on the lines where they now are (Rows.lua).
	if S.activeLook then
		S.activeLook:PaintQueue(rows, shown, S.queueAbove)
		self:PaintRows(rows)
		return
	end

	-- Sized to the filled rows, not the slider.
	local back = shown > 0 and p.style ~= "minimal"
	if back then R.queueBack:SetHeight(6 + shown * (p.fontSize + 4)) end

	-- Rows hanging above are placed here, where the number filled is known.
	if S.queueAbove then
		local rowHeight = p.fontSize + 4
		for i, fs in ipairs(R.queueRows) do
			if i <= shown then
				fs:ClearAllPoints()
				fs:SetPoint("BOTTOMLEFT", R.art, "TOPLEFT",
					S.queueTextX, 4 + (shown - i) * rowHeight)
			end
		end
	end
	R.queueBack:SetShown(back)
	R.queueHair:SetShown(back)
	-- The names as buttons, laid on the lines where they now are (Rows.lua).
	self:PaintRows(rows)
end

lib.HideQueue = HideQueue
