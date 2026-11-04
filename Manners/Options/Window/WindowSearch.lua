-- Manners -- options window: the search box at the top of the sidebar and its
-- results over the content. Matching and ranking are
-- ns.WindowSearch's (Search.lua); this file asks the model what is on screen
-- now, shows what was found and jumps to it.

local _, ns = ...
local UI = ns.WindowUI
local C = UI.C

local MAX_RESULTS, DELAY = 8, 0.15
-- Hung under the box, as in the game's own Settings window, and narrow enough
-- to leave most of the page in view.
local RESULT_W, RESULT_H = 320, 36

local search = { token = 0, found = {}, buttons = {} }
UI.search = search

-- Every placed control shown now, with its name, tooltip and choices read
-- with its own info table at this moment. Notes are not searched: their
-- sentences are not settings, and some are dear to compute.
local function Ask(fn, ...)
	local ok, value = pcall(fn, ...)
	if ok then return value end
	return nil
end

local function Add(out, item, sec, id, title)
	local B = ns.WindowBind
	if UI.Hidden(item) then return end
	local choices = {}
	local t = item.def.type
	if t == "select" or t == "multiselect" then
		for _, pair in ipairs(Ask(B.Values, item) or {}) do
			if type(pair[2]) == "string" then choices[#choices + 1] = pair[2] end
		end
	end
	out[#out + 1] = {
		label = Ask(B.Text, item, "name") or "", desc = Ask(B.Text, item, "desc"), choices = choices,
		section = UI.SectionText(sec), page = title, ref = { path = item.path, page = id },
	}
end

local function Entries()
	local layout, out = UI.Layout(), {}
	for _, group in ipairs(layout.groups) do
		for _, id in ipairs(group) do
			local page = layout.pages[id]
			if page and UI.PageVisible(id) then
				for _, sec in ipairs(UI.Model(id).sections) do
					for _, e in ipairs(sec.entries) do
						if e.subs then
							for _, sub in ipairs(e.subs) do
								if sub.def.type ~= "description" then Add(out, sub, sec, id, page.title) end
							end
						elseif e.isControl then
							Add(out, e.item, sec, id, page.title)
						end
					end
				end
			end
		end
	end
	return out
end
UI.SearchEntries = Entries

---------------------------------------------------------------------------
-- the box
---------------------------------------------------------------------------

local function Bad(on)
	local colour = on and C.red or C.fieldEdge
	for _, edge in ipairs(search.edges) do
		edge:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
	end
	search.bad = on and true or false
end

function UI.CloseResults()
	if search.results then search.results:Hide() end
	search.found = {}
end

-- A page shown by any other way than a result (the sidebar, a link, /manners
-- export): the results stop covering it, the box lets go of the keyboard, and
-- a search still waiting for typing to settle is dropped. The words stay.
function UI.LeaveSearch()
	search.token = search.token + 1
	search.pending = false
	UI.CloseResults()
	if search.box then search.box:ClearFocus() end
end

-- Opens the page, its fold (kept open), scrolls to the row and flashes it.
function UI.Choose(ref)
	UI.CloseResults()
	if search.box then search.box:ClearFocus() end
	local e = UI.Reveal(ref.path)
	local row = e and e.row
	if row and row.Flash then row.Flash(row) end
	return e
end

local function ShowResults(found)
	local panel = search.results
	local count = 0
	for i = 1, MAX_RESULTS do
		local b, hit = search.buttons[i], found[i]
		if hit then
			count = i
			b.ref = hit.ref
			b.label:SetText(UI.Plain(hit.label))
			local section = hit.section ~= "" and hit.section or nil
			b.where:SetText(UI.Plain(hit.page or "") .. (section and (" > " .. UI.Plain(section)) or ""))
			b:Show()
		else
			b:Hide()
		end
	end
	if count == 0 then
		-- The client's own sentence for an empty search where it has one;
		-- otherwise the list stays shut and the box turns red.
		if search.none then
			search.noneLine:SetText(search.none)
			search.noneLine:Show()
			panel:SetHeight(RESULT_H)
			panel:Show()
		else
			panel:Hide()
			Bad(true)
		end
		return
	end
	search.noneLine:Hide()
	Bad(false)
	panel:SetHeight(count * RESULT_H + 8)
	panel:Show()
end

function UI.RunSearch()
	local box = search.box
	local text = box and box:GetText() or ""
	search.pending = false
	if text:gsub("[ \t\r\n]", "") == "" then
		UI.CloseResults()
		Bad(false)
		return
	end
	local found = ns.WindowSearch.Find(text, Entries(), MAX_RESULTS) or {}
	search.found = found
	ShowResults(found)
end

-- 0.15 s after typing stops.
local function Typed()
	local box = search.box
	search.placeholder:SetShown((box:GetText() or "") == "" and not box:HasFocus())
	search.token = search.token + 1
	search.pending = true
	local token = search.token
	C_Timer.After(DELAY, function()
		if token == search.token and search.pending then ns.Guard("options search", UI.RunSearch) end
	end)
end

-- Enter takes the first result, searching first if typing has not settled.
local function Entered()
	if search.pending then UI.RunSearch() end
	local first = search.found[1]
	if first then UI.Choose(first.ref) end
end

function UI.ClearSearch()
	local box = search.box
	search.token = search.token + 1
	search.pending = false
	box:SetText("")
	box:ClearFocus()
	search.placeholder:Show()
	UI.CloseResults()
	Bad(false)
end

local function ResultButton(panel, i)
	local b = CreateFrame("Button", nil, panel)
	b:SetSize(RESULT_W - 8, RESULT_H)
	b:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -(4 + (i - 1) * RESULT_H))
	b.hover = UI.Solid(b, "BACKGROUND", C.hover)
	b.hover:SetAllPoints()
	b.hover:Hide()
	-- The first result is what Enter takes, and says so with a gold edge.
	if i == 1 then
		b.mark = UI.Solid(b, "ARTWORK", C.gold)
		b.mark:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
		b.mark:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
		b.mark:SetWidth(2)
	end
	b.label = UI.Text(b, GameFontHighlight, C.ink)
	b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -4)
	b.label:SetWidth(RESULT_W - 24)
	b.label:SetWordWrap(false)
	b.where = UI.Text(b, GameFontDisableSmall, C.hint)
	b.where:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
	b.where:SetWidth(RESULT_W - 24)
	b.where:SetWordWrap(false)
	b:SetScript("OnClick", UI.Guarded(function(self) if self.ref then UI.Choose(self.ref) end end))
	b:SetScript("OnEnter", function(self) self.hover:Show() end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:Hide()
	return b
end

local function BuildResults()
	local f = UI.frame
	local panel = CreateFrame("Frame", nil, f)
	panel:SetSize(RESULT_W, RESULT_H)
	panel:SetFrameLevel((f:GetFrameLevel() or 1) + 30)
	panel:EnableMouse(true)
	-- Opaque: the page under it would read through even a 2% gap.
	local bg = UI.Solid(panel, "BACKGROUND", { 0.043, 0.043, 0.063, 1 })
	bg:SetAllPoints()
	-- A darker ring outside the edge, the depth the mock-up's shadow gives.
	for i, alpha in ipairs({ 0.6, 0.3 }) do
		local shade = UI.Solid(panel, "BACKGROUND", { 0, 0, 0, alpha }, -i)
		shade:SetPoint("TOPLEFT", panel, "TOPLEFT", -i, i)
		shade:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", i, -i - 1)
	end
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 },
		{ "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
		local t = UI.Solid(panel, "BORDER", { 0.345, 0.345, 0.396, 1 })
		t:SetPoint(side[1])
		t:SetPoint(side[2])
		if side[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
	end
	for i = 1, MAX_RESULTS do search.buttons[i] = ResultButton(panel, i) end
	search.noneLine = UI.Text(panel, GameFontDisable, C.hint)
	search.noneLine:SetPoint("LEFT", panel, "LEFT", 12, 0)
	search.noneLine:Hide()
	-- Under the box, so it moves with the sidebar when the strip shows, and
	-- level with the page list's left edge, over the open page's gold bar.
	panel:SetPoint("TOPLEFT", search.box, "BOTTOMLEFT", -4, -4)
	panel:Hide()
	search.results = panel
	UI.results = panel
end

-- Built into the top of the sidebar; answers how much of it the box takes.
function UI.BuildSearch(parent)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(UI.SIDEBAR - 16, 24)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -10)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlight)
	box:SetTextInsets(24, 6, 0, 0)
	box:SetMaxLetters(60)
	local bg = UI.Solid(box, "BACKGROUND", C.field)
	bg:SetAllPoints()
	search.edges = {}
	for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 },
		{ "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
		local t = UI.Solid(box, "BORDER", C.fieldEdge)
		t:SetPoint(side[1])
		t:SetPoint(side[2])
		if side[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
		search.edges[#search.edges + 1] = t
	end
	local icon = box:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", box, "LEFT", 6, -1)
	icon:SetVertexColor(C.hint[1], C.hint[2], C.hint[3], 1)
	-- The client's own word, so it costs no translation.
	search.placeholder = UI.Text(box, GameFontDisable, C.hint)
	search.placeholder:SetPoint("LEFT", box, "LEFT", 24, 0)
	search.placeholder:SetText(SEARCH or "")
	search.none = type(SETTINGS_SEARCH_NOTHING_FOUND) == "string" and SETTINGS_SEARCH_NOTHING_FOUND or nil
	box:SetScript("OnTextChanged", UI.Guarded(Typed))
	box:SetScript("OnEnterPressed", UI.Guarded(Entered))
	box:SetScript("OnEscapePressed", UI.Guarded(UI.ClearSearch))
	box:SetScript("OnEditFocusGained", function() search.placeholder:Hide() end)
	box:SetScript("OnEditFocusLost", function(self)
		search.placeholder:SetShown((self:GetText() or "") == "")
	end)
	search.box = box
	BuildResults()
	return 10 + 24 + 6
end
