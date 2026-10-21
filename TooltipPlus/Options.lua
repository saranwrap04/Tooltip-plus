--[[
    Tooltip Plus - Settings page (inside the main window: title bar > Settings)
    Author: Saranwrap

    A side bar of categories on the left, the options of the chosen category on the
    right, and for the tooltip look a live preview of the tooltip.
]]

local TP = TooltipPlus
local floor, max, min = math.floor, math.max, math.min

local controls = {}          -- every widget with a .refresh
local current                -- shown category
local preview                -- preview panel (built once, moved into the category shown)

local function db() return TP.db end
local function st() return TP.db.style end

function TP:RefreshOptions()
    for _, c in ipairs(controls) do c.refresh() end
    if preview and preview:IsVisible() then preview:Refresh() end
end

local function Changed()
    if TP.Style then TP.Style:ApplyLook() end
    TP:RefreshOptions()
end

---------------------------------------------------------------------------
-- Preview: a drawn tooltip with sample lines, following the settings
---------------------------------------------------------------------------
local BLIZZ_BACKDROP = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } }
local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local GOLD, GREY, WHITE_T = "|cffffd100", "|cff9d9d9d", "|cffffffff"
local PALADIN, WARRIOR = { 0.96, 0.55, 0.73 }, { 0.78, 0.61, 0.43 }
local HOSTILE, LEGENDARY = { 1, 0.1, 0.1 }, { 1, 0.5, 0 }

local function Hex(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end
local function Label(t) return (TP.INV_COLORS and TP.INV_COLORS.label or GOLD) .. t .. "|r" end
local function Value(t) return (TP.INV_COLORS and TP.INV_COLORS.value or WHITE_T) .. t .. "|r" end

-- sample lines: { left, {r,g,b}, right } or { bar = "health" / "power", value, max, {r,g,b}, text }
local function SampleLines(mode)
    local s = st()
    local L = {}
    local function add(l, c, r) L[#L + 1] = { l, c or { 1, 1, 1 }, r } end
    -- you: name and class colour of the character using the addon
    local myName = UnitName("player") or "You"
    local _, myFile = UnitClass("player")
    local mc = myFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[myFile]
    local myColor = mc and { mc.r, mc.g, mc.b } or WARRIOR
    if mode == "item" then
        local Stats = TP.Stats
        local function stat(text)
            local a = Stats and Stats.AnnotateText(text, s.statRatings, s.statDerived)
            add(a or text, (text:find("^Equip") and { 0, 1, 0 }) or nil)
        end
        add("Preview", LEGENDARY)
        add("Binds when picked up")
        add("Two-Hand", nil, "Axe")
        add("954 - 1592 Damage", nil, "Speed 3.70")
        add("(344.0 damage per second)")
        stat("+198 Strength")
        stat("+223 Stamina")
        stat("Equip: Improves critical strike rating by 114.")
        stat("Equip: Increases your armor penetration rating by 114.")
        add("Requires Level 80")
        if s.itemLevel then add(Label("Item level") .. " " .. Value("284")) end
        if s.statSummary and Stats then
            add(" ")
            local rows = Stats.SummaryRows({ str = 198, sta = 223, crit = 114, arp = 114 },
                s.statCompare and { { str = 150, sta = 180, crit = 80, hit = 60 } } or nil)
            add("Stat Summary", nil, s.statCompare and "|cff9d9d9dvs|r |cffa335eeYour weapon|r" or " ")
            for _, r in ipairs(rows) do add(r[1], { 1, 0.82, 0 }, r[2]) end
        end
        return L, (s.qualityBorder and LEGENDARY)
    end
    local npc = mode == "npc"
    if npc then
        add("Kel'Thuzad", HOSTILE)
        if s.levelLine then add("|cffff3030Level ??|r " .. GOLD .. "Boss|r " .. WHITE_T .. "Undead|r")
        else add("Level ?? Undead (Boss)") end
    else
        add("Preview" .. (s.tags and " |cffff9900<AFK>|r" or ""), s.classNames and PALADIN or { 0.5, 0.5, 1 })
        if s.guildRank then add("|cff40ff40<Sons of Azeroth>|r " .. GREY .. "Officer|r")
        else add("Sons of Azeroth") end
        if s.levelLine then add("|cffffcc00Level 80|r " .. WHITE_T .. "Human|r " .. Hex(PALADIN) .. "Paladin|r")
        else add("Level 80 Human Paladin (Player)") end
        if not s.hideFaction then add("Alliance"); add("PvP") end
    end
    if s.target then add(Label("Target:") .. " " .. (npc and "|cffff3030<< You >>|r" or (Hex(myColor) .. myName .. "|r"))) end
    if s.targetedBy then
        add(Label("Targeted by") .. " " .. Value("3") .. ": " .. Hex(myColor) .. "You|r, " ..
            Hex(WARRIOR) .. "Tank|r, " .. Hex(PALADIN) .. "Healer|r")
    end
    if not npc and s.talents then add(Label("Talents:") .. " " .. WHITE_T .. "Holy|r " .. GREY .. "(51/20/0)|r") end
    if npc and s.npcID then add(Label("NPC ID") .. " " .. Value("15990")) end
    local text = s.barText
    if s.healthBar then
        L[#L + 1] = { bar = "health", npc and 73 or 31200, npc and 100 or 40000, npc and HOSTILE or PALADIN,
            text and (npc and "73%" or "31.2k / 40.0k  78%") or "" }
    end
    if s.powerBar then
        L[#L + 1] = { bar = "power", npc and 52 or 8000, npc and 100 or 20000, { 0, 0.44, 0.87 },
            text and (npc and "52%" or "8000 / 20.0k  40%") or "" }
    end
    return L, s.unitBorder and (npc and HOSTILE or PALADIN)
end

local function BuildPreview()
    local UI, C = TP.UI, TP.UI.C
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetWidth(280); p:SetHeight(440)
    local head = UI.Section(p, "Preview", 280)
    head:SetPoint("TOP", 0, 0)
    -- Player / NPC / Item
    p.mode = "player"
    p.tabs = {}
    local prev
    for _, m in ipairs({ { "player", "Player" }, { "npc", "NPC" }, { "item", "Item" } }) do
        local b = UI.FlatButton(p, m[2], 88, 20)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 2, -24) end
        b:SetScript("OnClick", function() p.mode = m[1]; p:Refresh() end)
        p.tabs[m[1]] = b
        prev = b
    end
    -- the drawn tooltip
    local tip = CreateFrame("Frame", nil, p)
    tip:SetPoint("TOPRIGHT", 0, -60)
    p.tip = tip
    tip.lines, tip.rights, tip.bars = {}, {}, {}
    -- the screen (position page)
    local screen = CreateFrame("Frame", nil, p)
    screen:SetWidth(272); screen:SetHeight(153)
    screen:SetPoint("TOP", 0, -26)
    UI.Backdrop(screen, C.input)
    p.screen = screen
    local cursor = screen:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cursor:SetText("+")
    screen.cursor = cursor
    screen.boxes = {}
    for i = 1, 2 do
        local b = CreateFrame("Frame", nil, screen)
        b:SetWidth(54); b:SetHeight(26)
        UI.Backdrop(b, { 0.15, 0.15, 0.15, 0.95 }, i == 1 and C.accent or { 0.6, 0.6, 0.6, 1 })
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        screen.boxes[i] = b
    end
    local legend = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    legend:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 2, -8)
    legend:SetWidth(272)
    legend:SetJustifyH("LEFT")
    p.legend = legend

    function p:DrawTooltip()
        local s = st()
        local lines, border = SampleLines(self.mode)
        local flat = s.enabled
        tip:SetBackdrop(flat and FLAT or BLIZZ_BACKDROP)
        if flat then
            tip:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
            local b = border or s.border
            tip:SetBackdropBorderColor(b[1], b[2], b[3], 1)
        else
            tip:SetBackdropColor(0, 0, 0, 1)
            tip:SetBackdropBorderColor(1, 1, 1, 1)
        end
        tip:SetScale(flat and (s.scale or 1) or 1)
        local y, w = -10, 0
        local nl, nb = 0, 0
        for i, e in ipairs(lines) do
            if e.bar then
                nb = nb + 1
                local bar = tip.bars[nb]
                if not bar then
                    bar = CreateFrame("StatusBar", nil, tip)
                    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    local bg = bar:CreateTexture(nil, "BACKGROUND")
                    bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
                    bg:SetTexture(0, 0, 0, 0.8)
                    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    bar.text:SetPoint("CENTER")
                    tip.bars[nb] = bar
                end
                local _, size = GameTooltipText:GetFont()
                local h = (size or 12) + 1
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", 10, y)
                bar:SetPoint("RIGHT", -10, 0)
                bar:SetHeight(h)
                bar:SetMinMaxValues(0, e[2]); bar:SetValue(e[1])
                bar:SetStatusBarColor(e[3][1], e[3][2], e[3][3])
                bar.text:SetText(e[4])
                bar:Show()
                y = y - h - 3
            else
                nl = nl + 1
                local fs = tip.lines[nl]
                if not fs then
                    fs = tip:CreateFontString(nil, "OVERLAY")
                    tip.lines[nl] = fs
                    tip.rights[nl] = tip:CreateFontString(nil, "OVERLAY")
                end
                local rs = tip.rights[nl]
                fs:SetFontObject(i == 1 and GameTooltipHeaderText or GameTooltipText)
                rs:SetFontObject(GameTooltipText)
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", 10, y)
                fs:SetText(e[1])
                fs:SetTextColor(e[2][1], e[2][2], e[2][3])
                fs:Show()
                local lw = fs:GetStringWidth()
                if e[3] then
                    rs:ClearAllPoints()
                    rs:SetPoint("TOPRIGHT", -10, y)
                    rs:SetText(e[3])
                    rs:SetTextColor(1, 1, 1)
                    rs:Show()
                    lw = lw + 30 + rs:GetStringWidth()
                else
                    rs:Hide()
                end
                w = max(w, lw)
                y = y - fs:GetStringHeight() - 2
            end
        end
        for i = nl + 1, #tip.lines do tip.lines[i]:Hide(); tip.rights[i]:Hide() end
        for i = nb + 1, #tip.bars do tip.bars[i]:Hide() end
        tip:SetWidth(max(w, 140) + 20)
        tip:SetHeight(-y + 8)
    end

    function p:DrawScreen()
        local s = st()
        local W, H = UIParent:GetWidth(), UIParent:GetHeight()
        local k = 272 / W
        local cx, cy = 100, 80
        cursor:ClearAllPoints()
        cursor:SetPoint("CENTER", screen, "BOTTOMLEFT", cx, cy)
        local SIDE = { BOTTOM = "BOTTOM", TOP = "TOP", LEFT = "BOTTOMLEFT", RIGHT = "BOTTOMRIGHT" }
        local function place(box, mode)
            box:ClearAllPoints()
            if mode == "mouse" then
                box:SetPoint(SIDE[s.mouseSide] or "BOTTOM", screen, "BOTTOMLEFT",
                    cx + (s.mouseX or 0) * k * 2, cy + (s.mouseY or 0) * k * 2)
            elseif mode == "fixed" then
                local x, y = s.fixedX, s.fixedY
                if not x then x, y = W - 120, 110 end
                local point = (y > H / 2 and "TOP" or "BOTTOM") .. (x > W / 2 and "RIGHT" or "LEFT")
                box:SetPoint(point, screen, "BOTTOMLEFT", x * k, y * (153 / H))
            else
                box:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT", -6, 12)
            end
        end
        local same = s.anchorWorld == s.anchorFrame
        local b1, b2 = screen.boxes[1], screen.boxes[2]
        place(b1, s.anchorWorld)
        b1.text:SetText(same and "Both" or "World")
        if same then b2:Hide() else place(b2, s.anchorFrame); b2.text:SetText("Frames"); b2:Show() end
        local names = { default = "game default spot", mouse = "at the mouse", fixed = "your anchor point" }
        legend:SetText("Gold: units and objects in the world (" .. names[s.anchorWorld] .. ").\n" ..
            "Grey: frames and bars (" .. names[s.anchorFrame] .. ").\n+ is the mouse.")
    end

    function p:Refresh()
        local onPos = current == "position"
        if onPos then
            tip:Hide(); screen:Show(); legend:Show()
            for _, b in pairs(self.tabs) do b:Hide() end
            self:DrawScreen()
        else
            screen:Hide(); legend:Hide(); tip:Show()
            for k, b in pairs(self.tabs) do b:Show(); b:SetSelected(k == self.mode) end
            self:DrawTooltip()
        end
    end
    p:Hide()
    return p
end

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
-- each: key, side-bar label, title, help, preview mode (nil: no preview), build(f, add)
local CATEGORIES = {
    { group = "Item info" },
    { "general", "General", "General",
        "Tooltip Plus adds where an item comes from, what it is used for and who has it to the item tooltip." },
    { "sources", "Item sources", "Item sources",
        "Where to get an item: vendors, quests, drops with the drop chance, crafting and more." },
    { "details", "Item details", "Item details",
        "The small lines at the bottom of the Tooltip Plus block, and what your characters have." },
    { "professions", "Professions", "Professions",
        "Recipes and materials, for every profession." },
    { group = "Tooltip look" },
    { "position", "Position", "Position",
        "Where tooltips open. Bags, the map and other windows place their own tooltips.", true },
    { "look", "Appearance", "Appearance",
        "Background, border, scale and font of every tooltip.", "player" },
    { "units", "Units", "Units",
        "Lines on the tooltip of players and NPCs.", "player" },
    { "bars", "Health bars", "Health bars",
        "Bars inside the tooltip of players and NPCs.", "player" },
    { "links", "Items and links", "Items and links",
        "Item tooltips and links clicked in chat.", "item" },
    { "stats", "Item stats", "Item stats",
        "What the stats of an item give your character, and what changes compared to what you wear.", "item" },
}

local function Builders()
    local UI = TP.UI
    local B = {}
    local function check(f, add, label, get, set, tip, enabledFunc)
        local c = UI.Check(f, label, get, set, tip)
        c.enabledFunc = enabledFunc
        c.changed = Changed
        add(c, 26)
        controls[#controls + 1] = c
        return c
    end
    local function opt(key) return function() return db()[key] end, function(v) db()[key] = v end end
    local function sopt(key) return function() return st()[key] end, function(v) st()[key] = v end end
    local function section(f, add, text, w)
        add(nil, 6)
        local s = UI.Section(f, text, w or 300)
        add(s, 26)
    end

    B.general = function(f, add)
        local g, s = opt("enabled")
        check(f, add, "Show item sources", g, s, "Vendors, quests, drops, crafting... in the item tooltip. /tplus on | off")
        g, s = opt("shiftOnly")
        check(f, add, "Only while holding Shift", g, s,
            "Tooltips stay short: the tooltip says \"Hold Shift\", and the sources and professions show while you hold it.",
            function() return db().enabled end)
        g, s = opt("minimap")
        local mm = check(f, add, "Minimap button", g, s, "Left-click: recipes. Right-click: settings. Drag it around the minimap.")
        mm.changed = function() TP:UpdateMinimap(); Changed() end
        section(f, add, "Commands", 560)
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetWidth(560); t:SetJustifyH("LEFT")
        t:SetText(GOLD .. "/tplus|r  settings      " .. GOLD .. "/tplus look|r  tooltip look      " ..
            GOLD .. "/tplus recipes|r  recipes      " .. GOLD .. "/tplus items|r  items of your characters\n" ..
            GOLD .. "/tplus gold|r  gold of your characters      " .. GOLD .. "/tplus <item ID>|r  an item's sources in chat\n" ..
            GOLD .. "/tplus chars|r  characters remembered      " .. GOLD .. "/tplus forget <name>|r  forget a deleted character")
        add(t, 54)
        local n = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        n:SetWidth(560); n:SetJustifyH("LEFT")
        n:SetText("Sources and drop chances come from the AzerothCore database (the core ChromieCraft runs on); " ..
            "the server can differ. Drop chance = chance per kill / per opening.")
        add(n, 30)
    end

    B.sources = function(f, add)
        local g, s = opt("compact")
        check(f, add, "Compact (hide zones)", g, s)
        g, s = opt("showMore")
        check(f, add, "\"... and N more\" lines", g, s,
            "When an item has many sources, only the main ones are listed, followed by how many more there are.")
        section(f, add, "Sources to show", 560)
        -- three columns
        local col = 0
        for _, code in ipairs(TP.KIND_ORDER) do
            local info = TP.KINDS[code]
            local c = UI.Check(f, info[2] .. info[1] .. "|r",
                function() return db().kinds[code] ~= false end, function(v) db().kinds[code] = v end)
            c.changed = Changed
            controls[#controls + 1] = c
            if col == 0 then add(c, 26) else c:SetPoint("LEFT", f.lastRow, "LEFT", col * 190, 0) end
            if col == 0 then f.lastRow = c end
            col = (col + 1) % 3
        end
    end

    B.details = function(f, add)
        local g, s = opt("itemID")
        check(f, add, "Item ID", g, s)
        g, s = opt("stack")
        check(f, add, "Stack size", g, s)
        g, s = opt("sell")
        check(f, add, "Vendor sell price", g, s,
            "\"Sells for\": what a vendor pays for one. Hidden while a vendor window is open (the game shows it there).")
        section(f, add, "Your characters", 560)
        g, s = opt("owned")
        check(f, add, "Count (all your characters)", g, s,
            "How many your characters on this realm have: bags, bank, equipped, mailbox, currencies, and your guild banks. " ..
            "Log on each character once; the bank, the mailbox and the guild bank are read when you open them.")
        g, s = opt("ownedDetail")
        check(f, add, "One line per character", g, s, "Each character (and guild bank) with where the item is and how many.",
            function() return db().owned end)
    end

    B.professions = function(f, add)
        local g, s = opt("usedIn")
        check(f, add, "Used in (professions)", g, s,
            "Materials: which professions use the item (number of recipes), and which of your characters know a recipe that uses it.")
        g, s = opt("recipeInfo")
        check(f, add, "Recipes: known / can learn", g, s,
            "Recipe items: which of your characters know it, can learn it now, or later. " ..
            "Crafted items: which of your characters know how to make it. Read when each character opens its profession window.")
        g, s = opt("reagents")
        check(f, add, "Reagents of crafted items", g, s)
        g, s = opt("quickSearch")
        check(f, add, "Shift + right-click an item: its recipes", g, s,
            "Shift + right-click a material (bags, bank, chat link) to open the recipes that use it; a crafted item opens its recipe.")
    end

    local MODES = { { "default", "Game default" }, { "mouse", "At the mouse" }, { "fixed", "Anchor point" } }
    local function dropdown(f, add, label, choices, key, tip)
        add(nil, 16)
        local d = UI.Dropdown(f, 220, function() return choices end,
            function() return st()[key] end, function(v) st()[key] = v end, label)
        d.changed = Changed
        UI.Tip(d, tip)
        add(d, 34)
        controls[#controls + 1] = d
        return d
    end
    local function slider(f, add, label, lo, hi, step, key, fmt)
        local sl = UI.Slider(f, label, 220, lo, hi, step, function() return st()[key] end,
            function(v) st()[key] = v end, fmt)
        sl.changed = Changed
        add(sl, 56)
        controls[#controls + 1] = sl
        return sl
    end

    B.position = function(f, add)
        dropdown(f, add, "Units and objects in the world", MODES, "anchorWorld",
            "Players, NPCs, mailboxes, chests... that you point at in the 3D world.")
        dropdown(f, add, "Frames and bars", MODES, "anchorFrame",
            "Unit frames, action bars, the minimap and everything else that uses the game's default tooltip spot.")
        dropdown(f, add, "At the mouse: tooltip", { { "BOTTOM", "Above the mouse" }, { "TOP", "Below the mouse" },
            { "LEFT", "On the right" }, { "RIGHT", "On the left" } }, "mouseSide")
        slider(f, add, "Mouse offset X", -100, 100, 1, "mouseX")
        slider(f, add, "Mouse offset Y", -100, 100, 1, "mouseY")
        local mv = UI.FlatButton(f, "Move anchor point", 220, 22)
        mv:SetScript("OnClick", function() TP.Style:ToggleMover() end)
        UI.Tip(mv, "Shows a box you can drag to where tooltips should open. Right-click it (or click this again) when done. " ..
            "The tooltip grows away from the nearest corner of the screen.")
        add(mv, 28)
        local rs = UI.FlatButton(f, "Reset anchor point", 220, 22)
        rs:SetScript("OnClick", function() TP.Style:ResetMover(); Changed() end)
        add(rs, 28)
    end

    B.look = function(f, add)
        local g, s = sopt("enabled")
        check(f, add, "Flat look", g, s, "A flat background with a thin border. Off: the game's own tooltip look (scale and font are kept as the game has them).")
        add(nil, 4)
        slider(f, add, "Scale", 0.5, 2, 0.05, "scale", "%.2f")
        local fonts = {}
        for i, ft in ipairs(TP.Style.FONTS) do fonts[i] = ft end
        dropdown(f, add, "Font", fonts, "font")
        slider(f, add, "Font size", 8, 20, 1, "fontSize")
        local bg = UI.Swatch(f, "Background colour", function() return st().bg end, true, Changed)
        add(bg, 26); controls[#controls + 1] = bg
        local bd = UI.Swatch(f, "Border colour", function() return st().border end, false, Changed)
        add(bd, 26); controls[#controls + 1] = bd
        local reset = UI.FlatButton(f, "Default colours", 220, 22)
        reset:SetScript("OnClick", function()
            local d = TP.Style.DEFAULTS
            for i = 1, 4 do st().bg[i] = d.bg[i]; st().border[i] = d.border[i] end
            Changed()
        end)
        add(nil, 4)
        add(reset, 28)
    end

    B.units = function(f, add)
        local list = {
            { "classNames", "Player names in class colour" },
            { "tags", "<AFK> and <DND>" },
            { "guildRank", "Guild with rank" },
            { "levelLine", "Coloured level, race and class", "Level in difficulty colour, class in class colour, Elite / Rare / Boss." },
            { "hideFaction", "Hide the faction and PvP lines" },
            { "target", "Target of the unit" },
            { "targetedBy", "Targeted by (your group)", "How many of your party or raid target the unit, and who. " ..
                "The game only tells it for your group, so it shows while you are in a party or raid." },
            { "talents", "Talents of players", "Main tree and points, e.g. Holy (51/20/0). Read when you hover a player within inspect range (about 28 yards); remembered for 5 minutes." },
            { "npcID", "NPC ID", "Shown on NPCs and vehicles." },
            { "unitBorder", "Border in class / reaction colour", "Needs the flat look (Appearance)." },
        }
        for _, o in ipairs(list) do
            local g, s = sopt(o[1])
            check(f, add, o[2], g, s, o[3])
        end
    end

    B.bars = function(f, add)
        local g, s = sopt("healthBar")
        check(f, add, "Health bar", g, s, "Replaces the game's bar under the tooltip. Class colour for players, reaction colour for NPCs.")
        g, s = sopt("powerBar")
        check(f, add, "Mana / rage / energy bar", g, s)
        g, s = sopt("barText")
        check(f, add, "Numbers on the bars", g, s,
            "The health of mobs outside your group is only known as a percentage on 3.3.5.",
            function() return st().healthBar or st().powerBar end)
    end

    B.stats = function(f, add)
        local g, s = sopt("statRatings")
        check(f, add, "Ratings as %", g, s,
            "Each rating with what it gives at your level, e.g. +32 Critical Strike Rating (0.70% crit). " ..
            "Hit, crit, haste, expertise, armor penetration, defense, dodge, parry, block and resilience.")
        g, s = sopt("statDerived")
        check(f, add, "What primary stats give", g, s,
            "Strength: attack power (and block value for warriors, paladins and shamans). Agility: crit, armor " ..
            "(and attack power for rogues, hunters and shamans). Stamina: health. Intellect: mana and spell crit. " ..
            "Crit from agility and intellect is shown at level 80.")
        g, s = sopt("statSummary")
        check(f, add, "Stat summary", g, s,
            "Under gear: what the item gives you, one line per stat (health, mana, attack or spell power, " ..
            "crit, hit, haste... as your class uses them). Base stats of the item, without gems and enchants.")
        g, s = sopt("statCompare")
        check(f, add, "Change against what you wear", g, s,
            "In brackets after each value: what you gain (green) or lose (red) against the item in that slot. " ..
            "Rings, trinkets and one-hand weapons: against both of yours (first / second).",
            function() return st().statSummary end)
    end

    B.links = function(f, add)
        local g, s = sopt("qualityBorder")
        check(f, add, "Border in item quality colour", g, s, "Needs the flat look (Appearance).")
        g, s = sopt("itemLevel")
        check(f, add, "Item level of gear", g, s)
        g, s = sopt("linkIDs")
        check(f, add, "Spell, quest and achievement IDs", g, s)
        g, s = sopt("linkIcon")
        check(f, add, "Icon beside links clicked in chat", g, s)
    end
    return B
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local pages, side = {}, {}

function TP:ShowSettingsCategory(key)
    if not pages[key] then return end
    current = key
    for k, f in pairs(pages) do if k == key then f:Show() else f:Hide() end end
    for k, b in pairs(side) do b:SetSelected(k == key) end
    local cat = pages[key].cat
    if cat[5] then
        if cat[5] ~= true then preview.mode = cat[5] end
        preview:SetParent(pages[key])
        preview:ClearAllPoints()
        preview:SetPoint("TOPRIGHT", pages[key], "TOPRIGHT", -10, -62)
        preview:Show()
    else
        preview:Hide()
    end
    TP:RefreshOptions()
end

function TP:BuildSettings(p)
    local UI = TP.UI
    local C = UI.C
    local B = Builders()

    local bar = CreateFrame("Frame", nil, p)
    bar:SetPoint("TOPLEFT", 8, -8)
    bar:SetPoint("BOTTOMLEFT", 8, 8)
    bar:SetWidth(176)
    UI.Backdrop(bar, C.panel)

    local content = CreateFrame("Frame", nil, p)
    content:SetPoint("TOPLEFT", bar, "TOPRIGHT", 6, 0)
    content:SetPoint("BOTTOMRIGHT", -8, 8)
    UI.Backdrop(content, C.panel)

    preview = BuildPreview()

    local y = -8
    local first
    for _, cat in ipairs(CATEGORIES) do
        if cat.group then
            local g = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            g:SetPoint("TOPLEFT", 10, y - 6)
            g:SetText(string.upper(cat.group))
            y = y - 22
        else
            local key = cat[1]
            local b = UI.SideButton(bar, cat[2], 172)
            b:SetPoint("TOPLEFT", 2, y)
            b:SetScript("OnClick", function() TP:ShowSettingsCategory(key) end)
            side[key] = b
            y = y - 22
            first = first or key

            local f = CreateFrame("Frame", nil, content)
            f:SetAllPoints()
            f:Hide()
            f.cat = cat
            pages[key] = f
            local title = UI.Section(f, cat[3], 600)
            title:SetPoint("TOP", 0, -10)
            local help = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            help:SetPoint("TOPLEFT", 16, -32)
            help:SetWidth(590)
            help:SetJustifyH("LEFT")
            help:SetText(cat[4])
            -- controls stacked from the top, in the left column when there is a preview
            local cy = -62
            local function add(w, h)
                if w then w:SetPoint("TOPLEFT", f, "TOPLEFT", 16, cy) end
                cy = cy - h
            end
            B[key](f, add)
        end
    end
    -- version at the bottom of the side bar
    local v = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    v:SetPoint("BOTTOMLEFT", 10, 8)
    v:SetText("v" .. TP.VERSION .. "  -  " .. TP.AUTHOR)

    p:SetScript("OnShow", function() TP:ShowSettingsCategory(current or first) end)
end
