-- Books on map (Forever): collection alerts (a toast per book found, a bigger one with a sound
-- at each reward goal), queued, top of the screen
local _, ns = ...
local L = ns.L
local S = ns.Skin
local BOOKS = ns.BOOKS

local SHOW_TIME = 4
local queue = {}
local toast

local function create()
  local f = CreateFrame("Button", "BooksOnMapForeverToast", UIParent)
  f:SetSize(300, 70)
  f:SetPoint("TOP", 0, -160)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  S.Shadow(f, 12, 0.5, { 0.12, 0.4, 0.95 })
  S.Rounded(f, 12)
  S.EdgeGlow(f, 48, 0.18)

  local icon = S.Icon(f, 38)
  icon:SetPoint("LEFT", 14, 2)
  f.icon = icon.tex

  f.title = S.Text(f, 14, "accent")
  local w = 300 - 14 - 38 - 10 - 12 -- right of the icon
  f.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
  f.title:SetWidth(w)
  f.title:SetWordWrap(false)

  f.text = S.Text(f, 12)
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.text:SetWidth(w)
  f.text:SetWordWrap(false)

  f.bar = S.ProgressBar(f, 5)
  f.bar:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
  f.bar:SetWidth(w)
  f.bar:SetMinMaxValues(0, ns.GOALS[#ns.GOALS])

  f:SetScript("OnClick", function() ns.ToggleOptions() end)
  f:Hide()
  return f
end

local showNext

local function play(t)
  toast = toast or create()
  toast.icon:SetTexture(t.icon)
  toast.title:SetText(t.title)
  toast.text:SetText(t.text)
  toast.bar:SetValue(math.min(ns.CountDone(), ns.GOALS[#ns.GOALS]))
  toast:Show()
  S.AnimateOpen(toast, 0, 12)
  if t.sound and SOUNDKIT then pcall(PlaySound, t.sound) end
  C_Timer.After(SHOW_TIME, function()
    S.AnimateClose(toast, 0, 12)
    C_Timer.After(0.3, showNext)
  end)
end

showNext = function()
  local t = table.remove(queue, 1)
  if t then play(t) else toast.busy = nil end
end

function ns.ShowToast(icon, title, text, sound)
  queue[#queue + 1] = { icon = icon, title = title, text = text, sound = sound }
  toast = toast or create()
  if not toast.busy then
    toast.busy = true
    showNext()
  end
end

-- called by ns.SetDone for a book found (not for silent changes)
function ns.NotifyCollected(b)
  if ns.db.noToasts then return end
  local done = ns.CountDone()
  ns.ShowToast(b.icon and ("Interface\\Icons\\" .. b.icon) or ns.ICON, L["Book found!"],
    ("%s  |cff7f90ab(%d/%d)|r"):format(b.name, done, #BOOKS))
  for _, goal in ipairs(ns.GOALS) do
    if done == goal then
      ns.ShowToast(ns.ADDON_ICON, L[ns.GOAL_LABELS[goal]],
        L["%d books: hand them in at the library!"]:format(goal),
        SOUNDKIT and (SOUNDKIT.UI_QUEST_ROLLING_FORWARD_01 or SOUNDKIT.IG_QUEST_LIST_COMPLETE))
    end
  end
end
