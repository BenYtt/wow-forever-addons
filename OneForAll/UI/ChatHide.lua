local _, FLT = ...

-- Quality of Life "chatHide" (5.7.3, user 27.10., off by default): a small button next to the chat and a key binding
-- (Key Bindings > OneForAll) hide / show all chat windows with their tabs. "chatAutoHide" (seconds, 0 = off) hides
-- the chat after that long without a new message; a new message or opening the chat input shows it again.
-- Lean: one AddMessage hook per chat window (returns at once while auto-hide is off), one timer that is restarted.

local CH = {}
FLT.ChatHide = CH
local Q = FLT.QoL
local hidden, saved = false, {}
local byAuto = false -- hidden by "Hide chat after" (shown again when that is set back to Never)
local button, timer

local function frames()
  local list = {}
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    -- EditBox: with the chat style "IM Style" the input line stays shown all the time (user 27.10.)
    for _, suffix in ipairs({ "", "Tab", "ButtonFrame", "EditBox" }) do
      local f = _G["ChatFrame" .. i .. suffix]
      if type(f) == "table" and f.SetShown then list[#list + 1] = f end
    end
  end
  if type(GeneralDockManager) == "table" then list[#list + 1] = GeneralDockManager end
  return list
end

local function setHidden(on)
  if on == hidden then return end
  hidden = on
  byAuto = false
  if on then
    wipe(saved)
    for _, f in ipairs(frames()) do if f:IsShown() then saved[#saved + 1] = f; f:Hide() end end
  else
    for _, f in ipairs(saved) do f:Show() end -- only what was shown before
    wipe(saved)
  end
  if button then button.icon:SetDesaturated(on) end
end
function CH.Toggle() setHidden(not hidden) end
function CH.IsHidden() return hidden end

-- auto-hide: (re)start the timer
local function autoSeconds() return tonumber(Q.Get("chatAutoHide")) or 0 end
local function restart()
  if timer then timer:Cancel(); timer = nil end
  local s = autoSeconds()
  if s <= 0 or not (C_Timer and C_Timer.NewTimer) then return end
  timer = C_Timer.NewTimer(s, function()
    timer = nil
    -- not while typing or with the mouse on the chat
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if (eb and (not eb.HasFocus or eb:HasFocus())) or (type(ChatFrame1) == "table" and ChatFrame1.IsMouseOver and ChatFrame1:IsMouseOver()) then restart(); return end
    setHidden(true); byAuto = true
  end)
end
local function onMessage()
  if autoSeconds() <= 0 then return end
  setHidden(false); restart()
end

-- the button left of the chat, next to the chat menu button (it stays visible while the chat is hidden)
local function makeButton()
  local b = CreateFrame("Button", "OneForAllChatHideButton", UIParent); b:SetSize(22, 22)
  local anchor = ChatFrameMenuButton or ChatFrame1
  if anchor == ChatFrameMenuButton then b:SetPoint("BOTTOM", anchor, "TOP", 0, 4)
  else b:SetPoint("TOPRIGHT", ChatFrame1, "TOPLEFT", -6, 0) end
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-Chat-Up")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnClick", CH.Toggle)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(hidden and "Show chat" or "Hide chat", 1, 0.82, 0)
    GameTooltip:AddLine("A key for it: Key Bindings > OneForAll.", 1, 1, 1, true); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

function CH.Apply()
  if Q.Get("chatHide") then
    if not button then button = makeButton() end
    button:Show()
  elseif button then button:Hide() end
  if autoSeconds() > 0 then restart() else
    if timer then timer:Cancel(); timer = nil end
    -- "Never" again (user 27.10.): bring back a chat that the timer hid; also when no button is left to show it
    if hidden and (byAuto or not Q.Get("chatHide")) then setHidden(false) end
  end
end

local hooked
local function hookAll()
  if hooked then return end
  hooked = true
  for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
    local cf = _G["ChatFrame" .. i]
    if type(cf) == "table" and cf.AddMessage then hooksecurefunc(cf, "AddMessage", onMessage) end
  end
  -- typing always brings the chat back
  if type(ChatEdit_ActivateChat) == "function" then
    hooksecurefunc("ChatEdit_ActivateChat", function() setHidden(false); restart() end)
  end
end

-- key binding (Bindings.xml)
BINDING_HEADER_ONEFORALL = "OneForAll"
BINDING_NAME_ONEFORALL_TOGGLECHAT = "Hide / show chat"
function OneForAll_ToggleChat() CH.Toggle() end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  hookAll()
  Q.On("chatHide", CH.Apply); Q.On("chatAutoHide", CH.Apply)
  CH.Apply()
end)
