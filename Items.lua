--[[
    Tooltip Plus - Items page: everything your characters have, in one list
    Author: Saranwrap

    Search by name across the bags, bank, equipped items, mailbox and currencies
    of all your characters on this realm, and your guild banks. Hover an item to
    see who has it and where; shift-click to link it.
]]

local TP = TooltipPlus
local UI = TP.UI
local C = UI.C
local Backdrop, FlatButton = UI.Backdrop, UI.FlatButton
local pairs, ipairs, floor, min = pairs, ipairs, math.floor, math.min
local GREY = "|cff9d9d9d"

local ROW_H = 20
local I = { list = {}, filter = { text = "", who = "" } }
TP.Items = I

local function ItemInfo(id)
    local name, link, q = GetItemInfo(id)
    return name, link, q
end

function I:Rebuild()
    local f = self.filter
    local all = TP:AllOwnedItems(f.who ~= "" and f.who or nil)
    local list, unknown = {}, 0
    for id, n in pairs(all) do
        local name, _, q = ItemInfo(id)
        if name then
            if f.text == "" or name:lower():find(f.text, 1, true) then
                list[#list + 1] = { id = id, n = n, name = name, q = q or 1 }
            end
        else
            unknown = unknown + 1         -- not in the game's item cache yet
        end
    end
    table.sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    self.list = list
    self.count:SetText(GREY .. #list .. (#list == 1 and " item|r" or " items|r") ..
        (unknown > 0 and (GREY .. "   (" .. unknown .. " not loaded yet: hover them once in your bags)|r") or ""))
    FauxScrollFrame_SetOffset(self.scroll, 0)
    self.scroll:SetVerticalScroll(0)
    self:UpdateList()
end

function I:UpdateList()
    local list, rows = self.list, self.rows
    local offset = FauxScrollFrame_GetOffset(self.scroll)
    FauxScrollFrame_Update(self.scroll, #list, #rows, ROW_H)
    local IC = TP.INV_COLORS
    for i, row in ipairs(rows) do
        local it = list[offset + i]
        if it then
            row.item = it
            row.icon:SetTexture(GetItemIcon and GetItemIcon(it.id) or select(10, GetItemInfo(it.id)))
            local _, _, _, hex = GetItemQualityColor(it.q)
            row.name:SetText((hex or "|cffffffff") .. it.name .. "|r")
            row.count:SetText(IC.label .. "Count|r " .. IC.value .. it.n .. "|r")
            row:Show()
        else
            row:Hide()
        end
    end
end

function I:Build(f)
    self.frame = f

    -- character filter
    local who = UI.Dropdown(f, 180, function()
        local o = { { "", "All characters" } }
        for _, c in ipairs(TP:GetChars()) do o[#o + 1] = { c.name, c.name } end
        o[#o + 1] = { "#guild", "Guild banks" }
        return o
    end, function() return I.filter.who end, function(v) I.filter.who = v; I:Rebuild() end)
    who:SetPoint("TOPLEFT", 10, -9)
    self.who = who

    local box = CreateFrame("EditBox", "TooltipPlusItemSearch", f)
    box:SetWidth(260); box:SetHeight(22)
    box:SetPoint("LEFT", who, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(8, 8, 0, 0)
    Backdrop(box, C.panel)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText("Search an item...")
    box:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then hint:Show() else hint:Hide() end
        I.filter.text = (self:GetText() or ""):lower()
        I:Rebuild()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and box:HasFocus() then box:SetText((GetItemInfo(link)) or link) end
    end)
    self.search = box

    local reset = FlatButton(f, "Reset", 60, 22)
    reset:SetPoint("LEFT", box, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        I.filter.who = ""
        box:SetText(""); box:ClearFocus()
        who:Refresh()
        I:Rebuild()
    end)

    -- gold of your characters, top right
    local gold = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gold:SetPoint("TOPRIGHT", -14, -14)
    gold:SetJustifyH("RIGHT")
    self.gold = gold
    local goldHit = CreateFrame("Frame", nil, f)
    goldHit:SetAllPoints(gold)
    goldHit:EnableMouse(true)
    goldHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("Gold of your characters", 1, 1, 1)
        TP:AddGoldLines(GameTooltip)
        GameTooltip:Show()
    end)
    goldHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.count:SetPoint("TOPLEFT", 14, -42)

    -- list
    local lp = CreateFrame("Frame", nil, f)
    lp:SetPoint("TOPLEFT", 10, -64)
    lp:SetPoint("BOTTOMRIGHT", -10, 28)
    Backdrop(lp, C.panel)
    local scroll = CreateFrame("ScrollFrame", "TooltipPlusItemScroll", lp, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() I:UpdateList() end)
    end)
    self.scroll = scroll
    self.rows = {}
    local nrows = floor((UI.H - 31 - 64 - 28 - 8) / ROW_H)
    for i = 1, nrows do
        local row = CreateFrame("Button", nil, lp)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", lp, "RIGHT", -26, 0)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.06)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(18); row.icon:SetHeight(18)
        row.icon:SetPoint("LEFT", 2, 0)
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.count:SetPoint("RIGHT", -6, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            local _, link = GetItemInfo(self.item.id)
            if not link then return end
            if button == "RightButton" and IsShiftKeyDown() then TP:QuickSearch(link) return end
            if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(link)
            elseif IsModifiedClick("DRESSUP") then DressUpItemLink(link) end
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.item.id)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[i] = row
    end

    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMRIGHT", -14, 9)
    help:SetText("Hover: who has it and where.  Shift-click: link.  Ctrl-click: try on.  " ..
        "Bank, mailbox and guild bank are read when you open them.")

    f:SetScript("OnShow", function()
        who:Refresh()
        local _, total = TP:GetGold()
        gold:SetText(GREY .. "Gold (all characters):|r  " .. TP:FormatPrice(total .. "c"))
        I:Rebuild()
    end)
end
