--[[
    Tooltip Plus - page in Escape > Interface > AddOns
    Author: Saranwrap

    Every slash command as a button, so nothing has to be remembered.
]]

local TP = TooltipPlus
local GREY = "|cff9d9d9d"
local ACCENT = "|cfffc7a2b"

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w); b:SetHeight(22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function Heading(parent, text, anchor, y)
    local fs = Label(parent, ACCENT .. text .. "|r", "GameFontNormal")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -18)
    return fs
end

local MAX_ROWS = 10

function TP:InitInterfacePanel()
    if not InterfaceOptions_AddCategory then return end
    local p = CreateFrame("Frame", "TooltipPlusInterfacePanel", UIParent)
    p.name = TP.NAME
    p:Hide()

    local title = Label(p, TP.NAME, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local sub = Label(p, GREY .. "v" .. TP.VERSION .. "  -  by " .. TP.AUTHOR ..
        "    Shows where an item comes from, and which of your characters own it.|r")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

    -- settings window + on / off
    local h1 = Heading(p, "Settings", sub)
    local open = Button(p, "Open the settings", 180, function()
        -- close the game menu the way the game does (a plain :Hide() leaves the game menu
        -- "open" for the UI, and Escape stops working)
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        TP:ShowOptions()
    end)
    open:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -8)
    local toggle = Button(p, "", 170, nil)
    toggle:SetPoint("LEFT", open, "RIGHT", 10, 0)
    local function UpdateToggle()
        toggle:SetText(TP.db.enabled and "Turn item sources off" or "Turn item sources on")
    end
    toggle:SetScript("OnClick", function()
        TP.db.enabled = not TP.db.enabled
        TP:Print("item sources " .. (TP.db.enabled and "on." or "off."))
        UpdateToggle()
        if TP.RefreshOptions then TP:RefreshOptions() end
    end)
    local recipes = Button(p, "Recipe browser", 140, function()
        if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        TP:ToggleRecipes()
    end)
    recipes:SetPoint("LEFT", toggle, "RIGHT", 10, 0)
    local cmd1 = Label(p, GREY .. "Same as /tplus,  /tplus on | off  and  /tplus recipes|r")
    cmd1:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 2, -4)

    -- look up an item
    local h2 = Heading(p, "Look up an item", cmd1)
    local box = CreateFrame("EditBox", "TooltipPlusLookupBox", p, "InputBoxTemplate")
    box:SetWidth(200); box:SetHeight(20)
    box:SetAutoFocus(false)
    box:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 6, -8)
    local function Lookup()
        local t = box:GetText() or ""
        local id = tonumber(t:match("item:(%d+)") or t:match("^%s*(%d+)%s*$"))
        if not id then
            TP:Print("type an item ID, or shift-click an item into the box.")
            return
        end
        SlashCmdList["TOOLTIPPLUS"](tostring(id))
        box:ClearFocus()
    end
    box:SetScript("OnEnterPressed", Lookup)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local go = Button(p, "Print sources in chat", 170, Lookup)
    go:SetPoint("LEFT", box, "RIGHT", 8, 0)
    local cmd2 = Label(p, GREY .. "Item ID, or shift-click an item from your bags into the box.  Same as /tplus <item ID>|r")
    cmd2:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -4, -6)
    -- shift-click an item while the box has the focus: put its link in the box
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and box:HasFocus() then box:SetText(link) end
    end)

    -- characters
    local h3 = Heading(p, "Your characters", cmd2)
    local cmd3 = Label(p, GREY .. "Characters remembered on this realm. Forget a character you deleted.  " ..
        "Same as /tplus chars  and  /tplus forget <name>|r")
    cmd3:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 0, -6)
    local rows = {}
    for i = 1, MAX_ROWS do
        local r = CreateFrame("Frame", nil, p)
        r:SetWidth(360); r:SetHeight(22)
        r:SetPoint("TOPLEFT", cmd3, "BOTTOMLEFT", 0, -6 - (i - 1) * 24)
        r.text = Label(r, "", "GameFontHighlight")
        r.text:SetPoint("LEFT", 4, 0)
        r.btn = Button(r, "Forget", 80, function(self)
            TP:ForgetChar(self.who)
            p.Refresh()
        end)
        r.btn:SetPoint("RIGHT", 0, 0)
        r:Hide()
        rows[i] = r
    end
    local more = Label(p, "")
    more:SetPoint("TOPLEFT", rows[MAX_ROWS], "BOTTOMLEFT", 4, -4)

    function p.Refresh()
        UpdateToggle()
        local list = TP.GetChars and TP:GetChars() or {}
        for i, r in ipairs(rows) do
            local c = list[i]
            if c then
                r.text:SetText(c.label)
                r.btn.who = c.name
                if c.isMe then r.btn:Disable() else r.btn:Enable() end
                r:Show()
            else
                r:Hide()
            end
        end
        if #list == 0 then
            more:ClearAllPoints(); more:SetPoint("TOPLEFT", cmd3, "BOTTOMLEFT", 4, -8)
            more:SetText(GREY .. "None yet.|r")
        elseif #list > MAX_ROWS then
            more:ClearAllPoints(); more:SetPoint("TOPLEFT", rows[MAX_ROWS], "BOTTOMLEFT", 4, -4)
            more:SetText(GREY .. "... and " .. (#list - MAX_ROWS) .. " more: /tplus forget <name>|r")
        else
            more:SetText("")
        end
    end
    p:SetScript("OnShow", p.Refresh)

    InterfaceOptions_AddCategory(p)
    self.interfacePanel = p
end
