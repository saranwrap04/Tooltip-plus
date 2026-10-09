--[[
    Tooltip Plus - recipe browser (/tplus recipes, minimap button)
    Author: Saranwrap

    Every recipe of every profession: search by name or reagent, filter by
    profession and by who knows / can learn it. The right side shows the skill
    colours, reagents (and how many you have), where the recipe is learned and
    which of your characters know it or can learn it.
]]

local TP = TooltipPlus
local DATA = TooltipPlusData
local pairs, ipairs, tonumber, floor, min, max = pairs, ipairs, tonumber, math.floor, math.min, math.max

local UI = TP.UI
local C = UI.C               -- colours (Window.lua)
local Backdrop, FlatButton = UI.Backdrop, UI.FlatButton
local GREY, WHITE = "|cff9d9d9d", "|cffffffff"
local function ACCENT() return UI.ACCENT end

local H = UI.H
local ROW_H, LIST_W = 18, 340

local R = { list = {}, filter = { prof = "", show = "all", sort = "skill", text = "" } }
-- filter.reagent = item: recipes that use it   filter.product = item: recipes that make it
TP.Recipes = R

---------------------------------------------------------------------------
-- Widgets (flat style)
---------------------------------------------------------------------------
-- flat drop-down: options = { { value, label }, ... }
local openMenu
local function Dropdown(parent, w, getOptions, get, set)
    local b = FlatButton(parent, "", w, 22)
    b:GetFontString():ClearAllPoints()
    b:GetFontString():SetPoint("LEFT", 8, 0)
    b:GetFontString():SetPoint("RIGHT", -18, 0)
    b:GetFontString():SetJustifyH("LEFT")
    local arrow = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    Backdrop(menu, C.panel, C.accent)
    menu:Hide()
    menu.buttons = {}
    function b:Refresh()
        for _, o in ipairs(getOptions()) do
            if o[1] == get() then self:SetText(o[2]) return end
        end
        self:SetText("")
    end
    b:SetScript("OnClick", function(self)
        if menu:IsShown() then menu:Hide() return end
        if openMenu then openMenu:Hide() end
        local opts = getOptions()
        for i, o in ipairs(opts) do
            local mb = menu.buttons[i]
            if not mb then
                mb = CreateFrame("Button", nil, menu)
                mb:SetHeight(18)
                mb:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 18)
                mb:SetPoint("RIGHT", -2, 0)
                local hl = mb:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(); hl:SetTexture(C.sel[1], C.sel[2], C.sel[3], 0.8)
                local fs = mb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                fs:SetPoint("LEFT", 6, 0)
                mb:SetFontString(fs)
                menu.buttons[i] = mb
            end
            mb:SetText((o[1] == get() and ACCENT() or "") .. o[2] .. (o[1] == get() and "|r" or ""))
            mb:SetScript("OnClick", function() menu:Hide(); set(o[1]); b:Refresh() end)
            mb:Show()
        end
        for i = #opts + 1, #menu.buttons do menu.buttons[i]:Hide() end
        menu:SetWidth(max(w, 160))
        menu:SetHeight(#opts * 18 + 4)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:Show()
        openMenu = menu
    end)
    b:SetScript("OnHide", function() menu:Hide() end)
    return b
end

UI.Dropdown = Dropdown

---------------------------------------------------------------------------
-- Data helpers
---------------------------------------------------------------------------
local function Me()
    local chars, me = TP:CharTable()
    return chars and me and chars[me], chars or {}, me
end

local function CountHave(id)
    local mine = Me()
    if not mine then return 0 end
    local n = 0
    for _, place in ipairs({ "bags", "bank" }) do
        n = n + (mine[place] and mine[place][id] or 0)
    end
    return n
end

local function CraftName(c)
    if c.item > 0 then
        local name = GetItemInfo(c.item) or (DATA.names and DATA.names[c.item])
        if name then return name end
    end
    return c.name ~= "" and c.name or ("recipe " .. c.spell)
end

local function CraftIcon(c)
    if c.item > 0 then
        local icon = GetItemIcon and GetItemIcon(c.item)
        if icon then return icon end
    end
    local _, _, icon = GetSpellInfo(c.spell)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function CraftLink(c)
    if c.item > 0 then
        local _, link = GetItemInfo(c.item)
        if link then return link end
    end
    return "|cffffd000|Henchant:" .. c.spell .. "|h[" .. CraftName(c) .. "]|h|r"
end

local function TooltipLink(c)
    if c.item > 0 then return "item:" .. c.item end
    return "enchant:" .. c.spell
end

-- your characters for a craft: known, can learn, later (texts)
local function CharGroups(c)
    local _, chars, me = Me()
    local known, can, later = {}, {}, {}
    for name, ch in pairs(chars) do
        local rank = ch.prof and ch.prof[c.skill]
        local mark = name == me and (GREY .. " (you)|r") or ""
        if ch.known and ch.known[c.spell] then
            known[#known + 1] = { name, TP:DiffColor(c, rank) .. name .. "|r" .. mark }
        elseif rank then
            local t = { name, TP.ClassColor(ch.class) .. name .. "|r" .. mark .. " " .. GREY .. "(" .. rank .. ")|r" }
            if rank >= c.req then can[#can + 1] = t else later[#later + 1] = t end
        end
    end
    local function sorted(list)
        table.sort(list, function(a, b)
            if (a[1] == me) ~= (b[1] == me) then return a[1] == me end
            return a[1] < b[1]
        end)
        local out = {}
        for _, o in ipairs(list) do out[#out + 1] = o[2] end
        return out
    end
    return sorted(known), sorted(can), sorted(later)
end

-- state of a craft for this character: "known", "can", "later", "none"
local function MyState(c)
    local mine = Me()
    if not mine then return "none" end
    if mine.known and mine.known[c.spell] then return "known" end
    local rank = mine.prof and mine.prof[c.skill]
    if not rank then return "none" end
    return rank >= c.req and "can" or "later"
end

local function AltKnows(c)
    local _, chars, me = Me()
    for name, ch in pairs(chars) do
        if name ~= me and ch.known and ch.known[c.spell] then return true end
    end
end

local function AnyKnows(c)
    local _, chars = Me()
    for _, ch in pairs(chars) do
        if ch.known and ch.known[c.spell] then return true end
    end
end

local professions
local function Professions()
    if not professions then
        local set = {}
        for spell in pairs(DATA.crafts or {}) do set[TP:GetCraft(spell).skill] = true end
        professions = {}
        for name in pairs(set) do professions[#professions + 1] = name end
        table.sort(professions)
    end
    return professions
end

---------------------------------------------------------------------------
-- List
---------------------------------------------------------------------------
local reagentText = {}   -- spell -> lower-case reagent names (for the search)
local function Matches(c, text)
    if text == "" then return true end
    if CraftName(c):lower():find(text, 1, true) then return true end
    local rt = reagentText[c.spell]
    if not rt then
        local parts = {}
        for _, r in ipairs(c.reagents) do
            parts[#parts + 1] = (GetItemInfo(r[1]) or (DATA.names and DATA.names[r[1]]) or ""):lower()
        end
        rt = table.concat(parts, "\n")
        reagentText[c.spell] = rt
    end
    return rt:find(text, 1, true) ~= nil
end

function R:Rebuild()
    local f, list = self.filter, {}
    for spell in pairs(DATA.crafts or {}) do
        local c = TP:GetCraft(spell)
        local okItem = true
        if f.reagent then
            okItem = false
            for _, r in ipairs(c.reagents) do if r[1] == f.reagent then okItem = true break end end
        elseif f.product then
            okItem = c.item == f.product
        end
        if okItem and (f.prof == "" or c.skill == f.prof) and Matches(c, f.text) then
            local ok = true
            local s = f.show
            if s ~= "all" then
                local st = MyState(c)
                if s == "known" then ok = st == "known"
                elseif s == "can" then ok = st == "can"
                elseif s == "later" then ok = st == "later"
                elseif s == "alt" then ok = AltKnows(c)
                elseif s == "nobody" then ok = not AnyKnows(c) end
            end
            if ok then list[#list + 1] = c end
        end
    end
    local RANK = { known = 1, can = 2, later = 3, none = 4 }
    if f.reagent or f.product then
        -- recipes for one item: the ones this character knows first
        table.sort(list, function(a, b)
            local ra, rb = RANK[MyState(a)], RANK[MyState(b)]
            if ra ~= rb then return ra < rb end
            if a.skill ~= b.skill then return a.skill < b.skill end
            if a.req ~= b.req then return a.req > b.req end
            return CraftName(a) < CraftName(b)
        end)
    elseif f.sort == "name" then
        table.sort(list, function(a, b) return CraftName(a) < CraftName(b) end)
    else
        table.sort(list, function(a, b)
            if a.skill ~= b.skill then return a.skill < b.skill end
            if a.req ~= b.req then return a.req > b.req end
            return CraftName(a) < CraftName(b)
        end)
    end
    self.list = list
    local what = f.reagent and (" using " .. TP:ItemName(f.reagent)) or (f.product and (" making " .. TP:ItemName(f.product))) or ""
    self.count:SetText(GREY .. #list .. (#list == 1 and " recipe|r" or " recipes|r") .. what)
    if f.reagent or f.product then self.clearItem:Show() else self.clearItem:Hide() end
    FauxScrollFrame_SetOffset(self.scroll, 0)
    self.scroll:SetVerticalScroll(0)
    self:UpdateList()
end

function R:UpdateList()
    local list, rows = self.list, self.rows
    local offset = FauxScrollFrame_GetOffset(self.scroll)
    FauxScrollFrame_Update(self.scroll, #list, #rows, ROW_H)
    for i, row in ipairs(rows) do
        local c = list[offset + i]
        if c then
            row.craft = c
            row.icon:SetTexture(CraftIcon(c))
            -- name in this character's skill colour (orange / yellow / green / grey, red = skill
            -- too low), grey when it does not have the profession; a tick when it knows it
            local st = MyState(c)
            local mine = Me()
            local rank = mine and mine.prof and mine.prof[c.skill]
            local col = rank and TP:DiffColor(c, rank) or "|cff707070"
            row.name:SetText(col .. CraftName(c) .. "|r")
            if st == "known" then row.check:Show() else row.check:Hide() end
            row.req:SetText(GREY .. (self.filter.prof == "" and (c.skill .. " ") or "") .. "|r" ..
                (c.req > 0 and (TP.DIFF.orange .. c.req .. "|r") or ""))
            if self.selected == c then row.sel:Show() else row.sel:Hide() end
            row:Show()
        else
            row:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Details
---------------------------------------------------------------------------
local function DetailLine(d, i)
    local l = d.lines[i]
    if not l then
        l = CreateFrame("Button", nil, d)
        l:SetHeight(16)
        l:SetPoint("LEFT", 0, 0); l:SetPoint("RIGHT", 0, 0)
        l.icon = l:CreateTexture(nil, "ARTWORK")
        l.icon:SetWidth(14); l.icon:SetHeight(14)
        l.icon:SetPoint("LEFT", 0, 0)
        l.left = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l.left:SetJustifyH("LEFT")
        l.right = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        l.right:SetJustifyH("RIGHT")
        l.right:SetPoint("RIGHT", 0, 0)
        l:SetScript("OnEnter", function(self)
            if not self.link then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() GameTooltip:Hide() end)
        l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        l:SetScript("OnClick", function(self, button)
            if self.link and button == "RightButton" and IsShiftKeyDown() then
                TP:QuickSearch(self.link)
                return
            end
            if self.link and IsModifiedClick("CHATLINK") then
                local _, link = GetItemInfo(self.link)
                if link then ChatEdit_InsertLink(link) end
            end
        end)
        d.lines[i] = l
    end
    return l
end

function R:ShowDetails(c)
    local d = self.detail
    self.selected = c
    for _, l in ipairs(d.lines) do l:Hide() end
    if not c then
        d.title:SetText(GREY .. "Select a recipe on the left.|r")
        d.icon:Hide(); d.sub:SetText(""); d.bands:SetText("")
        return
    end
    d.icon:SetTexture(CraftIcon(c)); d.icon:Show()
    d.icon.link = TooltipLink(c)
    d.icon.craft = c
    local _, _, q = GetItemInfo(c.item > 0 and c.item or 0)
    local _, _, _, hex = GetItemQualityColor(q or 1)
    d.title:SetText((c.item > 0 and hex or WHITE) .. CraftName(c) .. "|r")
    d.sub:SetText(TP.KINDS.K[2] .. c.skill .. "|r" .. (c.yield ~= "1" and (GREY .. "   makes " .. c.yield .. "|r") or ""))
    d.bands:SetText(TP:SkillBands(c))

    local n, y = 0, -64
    local function add(left, right, icon, link, indent)
        n = n + 1
        local l = DetailLine(d, n)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", d, "TOPLEFT", indent or 0, y)
        l:SetPoint("RIGHT", d, "RIGHT", 0, 0)
        l.left:ClearAllPoints()
        if icon then
            l.icon:SetTexture(icon); l.icon:Show()
            l.left:SetPoint("LEFT", l.icon, "RIGHT", 4, 0)
        else
            l.icon:Hide()
            l.left:SetPoint("LEFT", 0, 0)
        end
        l.left:SetPoint("RIGHT", l.right, "LEFT", -6, 0)
        l.left:SetText(left or "")
        l.right:SetText(right or "")
        l.link = link
        l:Show()
        y = y - 17
    end
    local function head(text)
        y = y - 6
        add(ACCENT() .. text .. "|r")
    end

    -- reagents
    head("Reagents")
    for _, r in ipairs(c.reagents) do
        local have = CountHave(r[1])
        local hc = have >= r[2] and "|cff40bf40" or (have > 0 and "|cffffd100" or GREY)
        add(WHITE .. r[2] .. "|r " .. TP:ItemName(r[1]), hc .. "have " .. have .. "|r",
            GetItemIcon and GetItemIcon(r[1]), "item:" .. r[1], 8)
    end

    -- where it is learned
    head("Learned from")
    if c.auto then add(WHITE .. "Learned with the profession|r", nil, nil, nil, 8) end
    if c.trainer then add(WHITE .. "Trainer|r" .. (c.req > 0 and (GREY .. " (skill " .. c.req .. ")|r") or ""), nil, nil, nil, 8) end
    local items = TP:RecipeItemsFor(c.spell)
    if items then
        for _, item in ipairs(items) do
            add(TP:ItemName(item), GREY .. "hover for details|r", GetItemIcon and GetItemIcon(item), "item:" .. item, 8)
            local srcs = TP:GetLines(item)
            if srcs then
                for k = 1, min(#srcs, 4) do
                    local s = srcs[k]
                    add(s[1], s[2], nil, nil, 26)
                end
                if #srcs > 4 then add(GREY .. "... " .. (#srcs - 4) .. " more (hover the recipe)|r", nil, nil, nil, 26) end
            end
        end
    end
    if not c.auto and not c.trainer and not items then add(GREY .. "Unknown|r", nil, nil, nil, 8) end

    -- your characters
    local known, can, later = CharGroups(c)
    if #known + #can + #later > 0 then
        head("Your characters")
        local function names(label, list)
            if #list == 0 then return end
            for i = 1, #list, 3 do
                add((i == 1 and (GREY .. label .. ":|r ") or "      ") ..
                    table.concat(list, GREY .. ", |r", i, min(i + 2, #list)), nil, nil, nil, 8)
            end
        end
        names("Known by", known)
        names("Can learn", can)
        names("Later", later)
    end
    self:UpdateList()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function R:Build(f)
    self.frame = f

    -- filters
    local prof = Dropdown(f, 160, function()
        local o = { { "", "All professions" } }
        for _, p in ipairs(Professions()) do o[#o + 1] = { p, p } end
        return o
    end, function() return R.filter.prof end, function(v) R.filter.prof = v; R:Rebuild() end)
    prof:SetPoint("TOPLEFT", 10, -9)

    local box = CreateFrame("EditBox", "TooltipPlusRecipeSearch", f)
    box:SetWidth(190); box:SetHeight(22)
    box:SetPoint("LEFT", prof, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetTextInsets(8, 8, 0, 0)
    Backdrop(box, C.panel)
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText("Search name or reagent...")
    box:SetScript("OnTextChanged", function(self)
        local t = (self:GetText() or ""):lower()
        if t:match("item:%d+") then          -- a shift-clicked item: search its name
            t = (GetItemInfo(t:match("(item:%d+)")) or ""):lower()
        end
        if self:GetText() == "" then hint:Show() else hint:Hide() end
        R.filter.text = t
        R:Rebuild()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    hooksecurefunc("ChatEdit_InsertLink", function(link)
        if link and box:HasFocus() then box:SetText((GetItemInfo(link)) or link) end
    end)
    self.search = box

    local SHOW = { { "all", "All recipes" }, { "known", "Known by this character" }, { "can", "This character can learn" },
                   { "later", "This character: later" }, { "alt", "Known by another character" },
                   { "nobody", "Not known by your characters" } }
    local show = Dropdown(f, 190, function() return SHOW end,
        function() return R.filter.show end, function(v) R.filter.show = v; R:Rebuild() end)
    show:SetPoint("LEFT", box, "RIGHT", 8, 0)
    local SORT = { { "skill", "Sort: skill" }, { "name", "Sort: name" } }
    local sort = Dropdown(f, 100, function() return SORT end,
        function() return R.filter.sort end, function(v) R.filter.sort = v; R:Rebuild() end)
    sort:SetPoint("LEFT", show, "RIGHT", 8, 0)
    self.dropdowns = { prof, show, sort }

    local reset = FlatButton(f, "Reset", 60, 22)
    reset:SetPoint("LEFT", sort, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        R.filter.prof, R.filter.show, R.filter.sort = "", "all", "skill"
        R.filter.reagent, R.filter.product = nil, nil
        box:SetText(""); box:ClearFocus()
        for _, d in ipairs(R.dropdowns) do d:Refresh() end
        R:Rebuild()
    end)

    -- list
    local lp = CreateFrame("Frame", nil, f)
    lp:SetPoint("TOPLEFT", 10, -64)
    lp:SetPoint("BOTTOMLEFT", 10, 28)
    lp:SetWidth(LIST_W)
    Backdrop(lp, C.panel)
    local scroll = CreateFrame("ScrollFrame", "TooltipPlusRecipeScroll", lp, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, function() R:UpdateList() end)
    end)
    self.scroll = scroll
    self.rows = {}
    local nrows = floor((H - 31 - 64 - 28 - 8) / ROW_H)
    for i = 1, nrows do
        local row = CreateFrame("Button", nil, lp)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", lp, "RIGHT", -26, 0)
        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints(); row.sel:SetTexture(C.sel[1], C.sel[2], C.sel[3], 0.9)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetTexture(1, 1, 1, 0.06)
        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetWidth(12); row.check:SetHeight(12)
        row.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetWidth(16); row.icon:SetHeight(16)
        row.icon:SetPoint("LEFT", 2, 0)
        row.check:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 5, -3)
        row.req = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.req:SetPoint("RIGHT", -4, 0)
        row.req:SetJustifyH("RIGHT")
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", row.req, "LEFT", -6, 0)
        row.name:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(CraftLink(self.craft)) return end
            R:ShowDetails(self.craft)
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(TooltipLink(self.craft))
            -- enchants make no item, so the item tooltip lines are not there: add them
            if self.craft.item == 0 then
                local extra = TP:CraftExtraLines(self.craft.spell)
                if extra and #extra > 0 then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddDoubleLine(TP.KINDS.K[2] .. self.craft.skill .. "|r", TP:SkillBands(self.craft))
                    for _, l in ipairs(extra) do GameTooltip:AddLine(l[1]) end
                end
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.rows[i] = row
    end

    -- details
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", lp, "TOPRIGHT", 14, -6)
    d:SetPoint("BOTTOMRIGHT", -14, 28)
    d.lines = {}
    d.icon = CreateFrame("Button", nil, d)
    d.icon:SetWidth(38); d.icon:SetHeight(38)
    d.icon:SetPoint("TOPLEFT", 0, 0)
    d.icon.tex = d.icon:CreateTexture(nil, "ARTWORK"); d.icon.tex:SetAllPoints()
    d.icon.SetTexture = function(self, t) self.tex:SetTexture(t) end
    d.icon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link); GameTooltip:Show()
    end)
    d.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d.icon:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and self.craft then ChatEdit_InsertLink(CraftLink(self.craft)) end
    end)
    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", 46, -2)
    d.title:SetPoint("RIGHT", d, "RIGHT", 0, 0)
    d.title:SetJustifyH("LEFT")
    d.sub = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.sub:SetPoint("TOPLEFT", 46, -24)
    d.bands = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    d.bands:SetPoint("TOPRIGHT", 0, -24)
    self.detail = d

    -- bottom: count (+ "Show all" when the list is for one item) + help
    self.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.count:SetPoint("TOPLEFT", 14, -42)
    self.clearItem = FlatButton(f, "Show all", 70, 18)
    self.clearItem:SetPoint("LEFT", self.count, "RIGHT", 8, 0)
    self.clearItem:SetScript("OnClick", function() R.filter.reagent, R.filter.product = nil, nil; R:Rebuild() end)
    self.clearItem:Hide()
    local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    help:SetPoint("BOTTOMRIGHT", -14, 9)
    help:SetText("Names in your skill colour (red: skill too low, dark grey: not your profession), tick = you know it.  " ..
        "Shift-click: link.  Shift + right-click a reagent: its recipes.")

    f:SetScript("OnShow", function()
        for _, dd in ipairs(R.dropdowns) do dd:Refresh() end
        R:Rebuild()
        if not R.selected then R:ShowDetails(nil) end
    end)
end

---------------------------------------------------------------------------
-- Shift + right-click an item (bags, bank, chat link): its recipes
---------------------------------------------------------------------------
-- returns true when the item is a reagent or a crafted item
function TP:QuickSearch(link)
    local id = link and tonumber(tostring(link):match("item:(%d+)"))
    if not id then return end
    local f = R.filter
    if self:UsedIn(id) then
        f.reagent, f.product = id, nil
    else
        local made
        for spell in pairs(DATA.crafts or {}) do
            if self:GetCraft(spell).item == id then made = true break end
        end
        if not made then return end
        f.reagent, f.product = nil, id
    end
    f.prof, f.show, f.text = "", "all", ""
    TP.Main:Show("recipes")
    if R.search then R.search:SetText(""); R.search:ClearFocus() end
    for _, d in ipairs(R.dropdowns or {}) do d:Refresh() end
    R:Rebuild()
    R:ShowDetails(R.list[1])
    return true
end

local function Quick(link, button)
    if button ~= "RightButton" or not IsShiftKeyDown() or not TP.db or not TP.db.quickSearch then return end
    if TP:QuickSearch(link) and StackSplitFrame and StackSplitFrame:IsShown() then
        StackSplitFrame:Hide()       -- shift-click on a stack also opens the "split stack" box
    end
end
hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    Quick(GetContainerItemLink(self:GetParent():GetID(), self:GetID()), button)
end)
if BankFrameItemButtonGeneric_OnModifiedClick then
    hooksecurefunc("BankFrameItemButtonGeneric_OnModifiedClick", function(self, button)
        if self.isBag then return end
        Quick(GetContainerItemLink(BANK_CONTAINER, self:GetID()), button)
    end)
end
hooksecurefunc("SetItemRef", function(link, text, button)
    if link and link:sub(1, 5) == "item:" then Quick(link, button) end
end)
