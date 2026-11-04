-- Manners -- options window: the buff order, a list of the class's buffs in
-- the order they are tried, built from five definitions of Who to buff (the
-- layout's ids). Added to the kinds Widgets.lua started; see there for what a
-- row is.
--
-- orderNote is the caption (what the walk does, and whose order this is);
-- orderPick's values are the lines, in the order they are tried -- each with the
-- spell's own icon, its place, its name, and an arrow up and one down that do
-- what picking that buff and pressing orderUp or orderDown did; orderReset is
-- the button under the list, there only while the player has an order of their
-- own. The first buff the walk can use is what a person with none of them is
-- offered, so its place is in the window's gold on a faint wash of it; a buff not
-- learned or switched off is drawn dim, and the first line has no arrow up and
-- the last none down. A buff that has just moved lights up for a moment, since the
-- pointer stays where it was and the buff does not.

local _, ns = ...
local W = ns.WindowWidgets
local T, KIND = W.Theme, W.KIND

local function Bind() return ns.WindowBind end

local PARTS = { orderNote = "note", orderPick = "pick", orderUp = "up", orderDown = "down",
	orderReset = "reset" }
local PART_ORDER = { "note", "pick", "up", "down", "reset" }
-- The list is as wide as its longest name wants and no wider than this: a row
-- with an arrow at the far end of a page's width is a long way to go.
local LIST_WIDTH, LINE, GAP, PAD = 400, 28, 2, 3
local ARROW_WIDTH, ARROW_HEIGHT = 24, 20
-- The window's gold at a strength the grey notes on it stay readable over: the
-- renderer's contrast check holds every word to 4.5:1 on what is behind it.
local WASH = { 1, 0.82, 0, 0.05 }
local FLASH_SECONDS = 0.6
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The icon the client has for the buff, or a question mark.
local function IconOf(key)
	local buff = ns.FindBuff(ns.caps.class, key)
	local info = buff and ns.BuffInfo(buff)
	local icon = info and ns.plain(info.icon)
	if type(icon) == "number" or type(icon) == "string" then return icon end
	return UNKNOWN_ICON
end

---------------------------------------------------------------------------
-- an arrow: the window's own small button (the number box's nudge arrows), a
-- little larger, with the client's arrows on it
---------------------------------------------------------------------------

local function ArrowLook(b)
	local on = b:IsEnabled() and true or false
	W.Gradient(b.face, "VERTICAL", on and T.btnBottom or T.btnOffBottom, on and T.btnTop or T.btnOffTop)
	W.Colour(b.icon, on and T.gold or T.btnOffInk)
	b.icon:SetDesaturated(not on)
end

local function Clicked(b)
	local line = b.line
	local row = line.row
	if not b:IsEnabled() then return end
	local part = b.step < 0 and row.up or row.down
	if not (row.pick and part) or not line.key then return end
	local key = line.key
	-- Picked, then pressed: what picking the buff and pressing the button did.
	Bind().Commit(row.pick, key)
	Bind().Run(part)
	row.moved = key
	row:Refresh()
end

local function Tip(b)
	local line = b.line
	local part = b.step < 0 and line.row.up or line.row.down
	local text = part and Bind().Text(part, "name")
	if not text or text == "" then return end
	GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
	GameTooltip:AddLine(W.Trim(text), 1, 1, 1)
	GameTooltip:Show()
end

local function Arrow(line, file, step)
	local b = CreateFrame("Button", nil, line)
	b:RegisterForClicks("LeftButtonUp")
	b:SetSize(ARROW_WIDTH, ARROW_HEIGHT)
	b.face = W.Solid(b, "BACKGROUND", 1)
	b.face:SetAllPoints(b)
	W.Border(b, T.btnEdge)
	W.Solid(b, "HIGHLIGHT", nil, { 1, 1, 1, 0.12 }):SetAllPoints(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(file)
	b.icon:SetSize(12, 12)
	b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.line, b.step = line, step
	b:SetScript("OnClick", function(self) ns.Guard("options order", Clicked, self) end)
	b:SetScript("OnEnter", function(self) ns.Guard("options tooltip", Tip, self) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnEnable", function(self) ns.Guard("options order", ArrowLook, self) end)
	b:SetScript("OnDisable", function(self) ns.Guard("options order", ArrowLook, self) end)
	return b
end

---------------------------------------------------------------------------
-- a line of the list
---------------------------------------------------------------------------

local function FlashStep(line, elapsed)
	line.flashLeft = line.flashLeft - (tonumber(elapsed) or 0)
	if line.flashLeft <= 0 then
		line.flash:Hide()
		line:SetScript("OnUpdate", nil)
		return
	end
	line.flash:SetAlpha(line.flashLeft / FLASH_SECONDS)
end

local function Flash(line)
	line.flashLeft = FLASH_SECONDS
	line.flash:SetAlpha(1)
	line.flash:Show()
	line:SetScript("OnUpdate", function(self, elapsed) ns.Guard("options flash", FlashStep, self, elapsed) end)
end

local function Line(row, i)
	local line = CreateFrame("Frame", nil, row.list)
	line:SetHeight(LINE)
	line.row = row
	-- Behind everything: the moved line's glow, the first line's wash and the
	-- gold rule down its left edge.
	line.flash = W.Solid(line, "BACKGROUND", -3, T.flash)
	line.flash:SetAllPoints(line)
	line.flash:Hide()
	line.wash = W.Solid(line, "BACKGROUND", -2, WASH)
	line.wash:SetAllPoints(line)
	line.bar = W.Solid(line, "BORDER", 1, T.gold)
	line.bar:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
	line.bar:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", 0, 0)
	line.bar:SetWidth(2)
	line.num = W.Text(line, T.fonts.label, T.hint)
	line.num:SetWidth(22)
	line.num:SetJustifyH("CENTER")
	line.num:SetPoint("LEFT", line, "LEFT", 8, 0)
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetSize(20, 20)
	line.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	line.icon:SetPoint("LEFT", line, "LEFT", 36, 0)
	line.down = Arrow(line, "Interface\\Buttons\\Arrow-Down-Up", 1)
	line.down:SetPoint("RIGHT", line, "RIGHT", -6, 0)
	line.up = Arrow(line, "Interface\\Buttons\\Arrow-Up-Up", -1)
	line.up:SetPoint("RIGHT", line.down, "LEFT", -4, 0)
	line.text = W.Text(line, T.fonts.label, T.white)
	line.text:SetWordWrap(false)
	line.text:SetPoint("LEFT", line, "LEFT", 64, 0)
	line.text:SetPoint("RIGHT", line.up, "LEFT", -8, 0)
	row.lines[i] = line
	return line
end

-- The line for `key`, in the place it holds now, `last` being how many there are.
local function Paint(line, rank, last, key, label, usable, first, moved)
	line.key = key
	line.num:SetText(tostring(rank))
	line.text:SetText(label)
	line.icon:SetTexture(IconOf(key))
	line.icon:SetDesaturated(not usable)
	line.icon:SetAlpha(usable and 1 or 0.5)
	W.TextColour(line.text, usable and T.white or T.dim)
	W.TextColour(line.num, first and T.gold or (usable and T.hint or T.dim))
	line.wash:SetShown(first)
	line.bar:SetShown(first)
	line.up:SetEnabled(rank > 1)
	line.down:SetEnabled(rank < last)
	ArrowLook(line.up)
	ArrowLook(line.down)
	if moved then Flash(line) end
end

---------------------------------------------------------------------------
-- the kind
---------------------------------------------------------------------------

local function Part(row, kind, item)
	if not item then return nil end
	local sub = W.Build(kind, row.frame, item)
	sub.parentRow = row
	return sub
end

local function PlaceList(row, width, y)
	local n = row.count or 0
	row.list:SetShown(n > 0)
	if n == 0 then return y end
	local w = math.min(width, LIST_WIDTH)
	local h = 2 * PAD + n * LINE + (n - 1) * GAP
	row.list:ClearAllPoints()
	row.list:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
	row.list:SetSize(w, h)
	for i = 1, n do
		local line = row.lines[i]
		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", row.list, "TOPLEFT", PAD, -(PAD + (i - 1) * (LINE + GAP)))
		line:SetWidth(w - 2 * PAD)
	end
	return y + h + 8
end

KIND.order = {
	Build = function(row)
		local parts = {}
		for i, path in ipairs((row.item.layout or {}).ids or {}) do
			local which = PARTS[tostring(path):match("([^.]+)$")] or PART_ORDER[i]
			-- The caption is a grey note, as the layout draws such notes.
			if which then parts[which] = Bind().Item(path, which == "note" and { hint = true } or {}, row.ctx) end
		end
		row.pick, row.up, row.down = parts.pick, parts.up, parts.down
		row.note = Part(row, "description", parts.note)
		row.list = CreateFrame("Frame", nil, row.frame)
		W.Field(row.list)
		row.lines = {}
		row.count = 0
		row.reset = Part(row, "execute", parts.reset)
	end,
	Refresh = function(row)
		if row.note then row.note:Refresh() end
		local resetShown = row.reset ~= nil and not Bind().Hidden(row.reset.item)
		if row.reset then
			row.reset:Refresh()
			row.reset.frame:SetShown(resetShown)
		end
		local names = row.pick and Bind().Values(row.pick) or {}
		-- What the walk can use now: learned, switched on, and not a spell
		-- Automatic never reaches for. The first of those, in the list's order, is
		-- what somebody with none of them is offered.
		local usable, first = {}, nil
		for _, buff in ipairs(ns.CastableBuffs()) do usable[buff.key] = true end
		for _, v in ipairs(names) do
			if usable[v[1]] then
				first = v[1]
				break
			end
		end
		local moved = row.moved
		row.moved = nil
		for i, v in ipairs(names) do
			local line = row.lines[i] or Line(row, i)
			Paint(line, i, #names, v[1], v[2], usable[v[1]] == true, v[1] == first, moved ~= nil and v[1] == moved)
			line:Show()
		end
		for i = #names + 1, #row.lines do row.lines[i]:Hide() end
		local was, wasReset = row.count, row.resetShown
		row.count, row.resetShown = #names, resetShown
		row.list:SetShown(#names > 0)
		if (was ~= nil and was ~= row.count) or (wasReset ~= nil and wasReset ~= resetShown) then
			W.Relayout(row)
		end
	end,
	Layout = function(row, width)
		local y = 0
		if row.note then
			local h = row.note:Layout(width)
			row.note.frame:ClearAllPoints()
			row.note.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, 0)
			if h > 0 then y = h + 8 end
		end
		y = PlaceList(row, width, y)
		if row.reset and row.resetShown then
			local w = row.reset:NaturalWidth()
			row.reset:Layout(math.min(w, width))
			row.reset.frame:ClearAllPoints()
			row.reset.frame:SetPoint("TOPLEFT", row.frame, "TOPLEFT", 0, -y)
			y = y + 24
		end
		return y
	end,
	Natural = function() return LIST_WIDTH end,
}
