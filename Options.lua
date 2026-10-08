--[[
    Tooltip Plus - Settings page (inside the main window: title bar > Settings)
    Author: Saranwrap
]]

local TP = TooltipPlus

local checks = {}
local function Check(parent, name, label, x, y, get, set, tip)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetWidth(24); cb:SetHeight(24)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    _G[name .. "Text"]:SetText(label)
    _G[name .. "Text"]:SetFontObject("GameFontHighlight")
    cb.get = get
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    checks[#checks + 1] = cb
    return cb
end

function TP:RefreshOptions()
    for _, cb in ipairs(checks) do cb:SetChecked(cb.get()) end
end

function TP:BuildSettings(p)
    local UI = TP.UI
    local C = UI.C
    local db = function() return TP.db end

    local function Heading(text, x, y)
        local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", x + 2, y)
        fs:SetText(text)
        fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
        local line = p:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", -2, -4)
        line:SetWidth(240)
        line:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.35)
    end

    local X1, X2, X3, Y = 14, 284, 554, -16
    local STEP = 26

    -- column 1: tooltip
    Heading("Tooltip", X1, Y)
    local y = Y - 24
    local function c1(name, label, key, tip, x)
        Check(p, "TooltipPlusOpt" .. name, label, x or X1, y,
            function() return db()[key] end, function(v) db()[key] = v end, tip)
        y = y - STEP
    end
    c1("Enabled", "Show item sources", "enabled")
    c1("Shift", "Only while holding Shift", "shiftOnly",
        "Tooltips stay short; hold Shift over an item to see where it comes from.")
    c1("Compact", "Compact (hide zones)", "compact")
    c1("More", "\"... and N more\" lines", "showMore",
        "When an item has many sources, only the main ones are listed, followed by how many more there are.")
    c1("ID", "Item ID", "itemID")
    c1("Stack", "Stack size", "stack")
    c1("Sell", "Vendor sell price", "sell",
        "\"Sells for\": what a vendor pays for one. Hidden while a vendor window is open (the game shows it there).")

    -- column 2: characters, professions, window
    Heading("Your characters", X2, Y)
    y = Y - 24
    local function c2(name, label, key, tip, x)
        Check(p, "TooltipPlusOpt" .. name, label, x or X2, y,
            function() return db()[key] end, function(v) db()[key] = v end, tip)
        y = y - STEP
    end
    c2("Owned", "Count (all your characters)", "owned",
        "How many your characters on this realm have: bags, bank, equipped, mailbox, currencies, " ..
        "and your guild banks. Log on each character once; the bank, the mailbox and the guild bank " ..
        "are read when you open them.")
    c2("OwnedDetail", "One line per character", "ownedDetail",
        "Each character (and guild bank) with where the item is and how many.", X2 + 20)
    y = y - 10
    Heading("Professions", X2, y)
    y = y - 24
    c2("UsedIn", "Used in (professions)", "usedIn",
        "Reagents: which professions use the item (number of recipes), and which of your characters " ..
        "know a recipe that uses it, coloured by skill colour.")
    c2("Recipe", "Recipes: known / can learn", "recipeInfo",
        "Recipe items: which of your characters know it, can learn it now, or later (skill too low). " ..
        "Crafted items: which of your characters know how to make it.\n" ..
        "Recipes are read when each character opens its profession window.")
    c2("Reagents", "Reagents of crafted items", "reagents")
    c2("QuickSearch", "Shift + right-click an item: its recipes", "quickSearch",
        "Shift + right-click a material (bags, bank, chat link) to open the recipes that use it; " ..
        "a crafted item opens its recipe.")
    y = y - 10
    Heading("Window", X2, y)
    y = y - 24
    Check(p, "TooltipPlusOptMinimap", "Minimap button", X2, y,
        function() return db().minimap end, function(v) db().minimap = v; TP:UpdateMinimap() end,
        "Left-click: recipes. Right-click: settings. Drag it around the minimap.")

    -- column 3: sources
    Heading("Sources to show", X3, Y)
    for i, code in ipairs(TP.KIND_ORDER) do
        local info = TP.KINDS[code]
        Check(p, "TooltipPlusOptKind" .. code, info[2] .. info[1] .. "|r", X3, Y - 24 - (i - 1) * STEP,
            function() return db().kinds[code] ~= false end, function(v) db().kinds[code] = v end)
    end

    local note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 14)
    note:SetWidth(UI.W - 32)
    note:SetJustifyH("LEFT")
    note:SetText("Sources and drop chances come from the AzerothCore database (the core ChromieCraft runs on); " ..
        "the server can differ. Drop chance = chance per kill / per opening.\n" ..
        "/tplus recipes  -  /tplus items  -  /tplus gold  -  /tplus <item ID> prints an item's sources in chat  -  " ..
        "/tplus forget <name> forgets a deleted character.")

    p:SetScript("OnShow", function() TP:RefreshOptions() end)
end
