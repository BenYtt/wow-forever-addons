local addonName, ns = ...

-- The author's Discord invite, offered to copy. WoW can't open a link or write to the clipboard, so the
-- address sits selected in a box and the player presses Ctrl+C (the window closes when they do).
--
-- Shared by all of tr0tsky's addons. The master copy is WoW Addons\shared\DiscordLink.lua: change it there
-- and copy it over each addon's copy unchanged. Each addon also ships Media\Discord.tga beside it.
--
--   ns.CreateDiscordButton(parent[, height]) -> a Discord-coloured button that opens the window
--   ns.ShowDiscordPopup()                    -> opens the window
--
-- Strings go through ns.L when the addon has one (keys "%s on Discord", "Press Ctrl+C to copy the invite.").
-- The window is built on first use, never at load.

local DISCORD_URL = "https://discord.gg/KkcnJPQQ5M"
local LOGO = "Interface\\AddOns\\" .. addonName .. "\\Media\\Discord"
local FILL = { 0.345, 0.396, 0.949 }        -- Discord's blurple, #5865F2
local HOVER = { 0.278, 0.322, 0.769 }

local WIDTH, HEIGHT, PAD = 340, 130, 18

local function L(key)
    return ns.L and ns.L[key] or key
end

local function addonTitle()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(addonName, "Title") or addonName
end

local popup

local function build()
    local name = addonName:gsub("[^%w]", "") .. "DiscordPopup"
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", 0, 80)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:Hide()
    -- Escape closes it, like the game's own dialogs.
    table.insert(UISpecialFrames, name)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", 0, -PAD)
    frame.title:SetWidth(WIDTH - 2 * PAD)
    frame.title:SetWordWrap(false)

    local prompt = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    prompt:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
    prompt:SetText(L("Press Ctrl+C to copy the invite."))

    local box = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    box:SetSize(WIDTH - 2 * PAD - 10, 22)
    box:SetPoint("TOP", prompt, "BOTTOM", 0, -8)
    box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() frame:Hide() end)
    -- The address can be selected and copied, not edited.
    box:SetScript("OnTextChanged", function(self, byUser)
        if byUser then
            self:SetText(DISCORD_URL)
            self:HighlightText()
        end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    box:SetScript("OnKeyUp", function(_, key)
        if key == "C" and IsControlKeyDown() then frame:Hide() end
    end)
    frame.box = box

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetSize(90, 22)
    close:SetPoint("BOTTOM", 0, PAD - 4)
    close:SetText(CLOSE)
    close:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnHide", function() box:ClearFocus() end)
    return frame
end

function ns.ShowDiscordPopup()
    popup = popup or build()
    popup.title:SetText(string.format(L("%s on Discord"), addonTitle()))
    popup.box:SetText(DISCORD_URL)
    popup:Show()
    popup.box:SetFocus()
    popup.box:HighlightText()
end

function ns.CreateDiscordButton(parent, height)
    height = height or 22
    local button = CreateFrame("Button", nil, parent)
    local fill = button:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(FILL[1], FILL[2], FILL[3])

    local size = height - 8
    local logo = button:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO)
    logo:SetSize(size * 4 / 3, size)                -- the picture is 4:3
    logo:SetPoint("LEFT", 8, 0)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", logo, "RIGHT", 5, 0)
    label:SetText("Discord")
    button:SetSize(8 + size * 4 / 3 + 5 + math.max(label:GetStringWidth() or 0, 40) + 10, height)

    button:SetScript("OnEnter", function() fill:SetColorTexture(HOVER[1], HOVER[2], HOVER[3]) end)
    button:SetScript("OnLeave", function() fill:SetColorTexture(FILL[1], FILL[2], FILL[3]) end)
    button:SetScript("OnClick", function() ns.ShowDiscordPopup() end)
    return button
end
