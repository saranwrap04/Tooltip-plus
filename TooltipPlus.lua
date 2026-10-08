--[[
    Tooltip Plus
    Author: Saranwrap
    Client: World of Warcraft 3.3.5a (Interface 30300)

    Adds where an item comes from to its tooltip: vendors (name, zone, price),
    quest rewards, crafting, drops (mob, zone, drop chance), objects (chests,
    herbs, ore), containers, disenchanting, prospecting, milling, skinning,
    pickpocketing and fishing, with world events (holidays), quest-only and
    hard-mode-only drops marked.
    Data: Data\*.lua, generated from the AzerothCore world database (the core
    ChromieCraft runs on) and the 3.3.5a client files.
]]

local ADDON_NAME = ...
TooltipPlus = TooltipPlus or {}
local TP = TooltipPlus
TP.NAME = "Tooltip Plus"
TP.VERSION = "1.7.1"
TP.AUTHOR = "Saranwrap"
TP.FOLDER = ADDON_NAME or "TooltipPlus"
TP.MEDIA = "Interface\\AddOns\\" .. TP.FOLDER .. "\\Media\\"
TP.ICON = TP.MEDIA .. "icon"

local DATA = TooltipPlusData
local tonumber, tostring, pairs, ipairs, floor = tonumber, tostring, pairs, ipairs, math.floor
local strsplit, strsub, strfind, format, gsub = strsplit, string.sub, string.find, string.format, string.gsub

local DEFAULTS = {
    enabled = true,
    shiftOnly = false,     -- only show the sources while Shift is held
    compact = false,       -- hide zones / extra details
    showMore = true,       -- "... and N more" lines
    itemID = true,         -- "Item ID: 12345"
    owned = true,          -- "Owned by: 2 of your characters"
    ownedDetail = true,    -- one line per character (bags / bank / equipped / mail)
    usedIn = true,         -- "Used in: Tailoring 12" + which of your characters can use it
    recipeInfo = true,     -- recipes: known by / can learn / later; crafted items: known by
    reagents = true,       -- crafted items: reagents
    stack = true,          -- stack size (next to the item ID)
    sell = true,           -- "Sells for" (vendor price)
    minimap = true,        -- minimap button
    quickSearch = true,    -- shift + right-click an item: open its recipes
    minimapAngle = 200,
    kinds = { V = true, Q = true, K = true, E = true, R = true, M = true, D = true, O = true, C = true, S = true, P = true, F = true },
}

-- Source kinds: code -> label, colour, "more" word
local KINDS = {
    V = { "Vendor",        "|cff66ccff", "vendors" },
    Q = { "Quest",         "|cffffd100", "quests" },
    K = { "Crafted",       "|cffffa040", "recipes" },
    E = { "Disenchanting", "|cffc77dff", "item groups" },
    R = { "Prospecting",   "|cff9ad0c2", "ores" },
    M = { "Milling",       "|cff9ad0c2", "herbs" },
    D = { "Drop",          "|cffff7070", "mobs" },
    O = { "Object",        "|cff4cd964", "objects" },
    C = { "Contained in",  "|cffd2a679", "containers" },
    S = { "Skinning",      "|cffd2a679", "mobs" },
    P = { "Pickpocket",    "|cffaaaaaa", "mobs" },
    F = { "Fishing",       "|cff4fc3f7", "zones" },
}
TP.KINDS = KINDS
TP.KIND_ORDER = { "V", "Q", "K", "E", "R", "M", "D", "O", "C", "S", "P", "F" }

local FACTION_TAG = { A = " |cff4a9effA|r", H = " |cffff4a4aH|r" }
local GREY = "|cff9d9d9d"

local function S(i) return DATA.strings[tonumber(i) or 0] or "" end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local GOLD   = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local SILVER = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
local COPPER = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"

local function Money(c)
    c = tonumber(c) or 0
    local g, s, cu = floor(c / 10000), floor(c / 100) % 100, c % 100
    local t = ""
    if g > 0 then t = t .. "|cffffffff" .. g .. "|r" .. GOLD .. " " end
    if s > 0 then t = t .. "|cffffffff" .. s .. "|r" .. SILVER .. " " end
    if cu > 0 or t == "" then t = t .. "|cffffffff" .. cu .. "|r" .. COPPER end
    return (t:gsub("%s+$", ""))
end

local function ItemIcon(id)
    local icon = GetItemIcon and GetItemIcon(id)
    if not icon then icon = select(10, GetItemInfo(id)) end
    return icon
end

-- "250000c+2x47241+1500h" -> coins, item icons, honor / arena points
function TP:FormatPrice(price)
    local out = {}
    for tok in (price or ""):gmatch("[^%+]+") do
        local n, kind = tok:match("^(%d+)(%a)$")
        if kind == "c" then
            out[#out + 1] = Money(n)
        elseif kind == "h" then
            local icon = (UnitFactionGroup("player") == "Horde") and "Interface\\PVPFrame\\PVP-Currency-Horde" or "Interface\\PVPFrame\\PVP-Currency-Alliance"
            out[#out + 1] = "|cffffffff" .. n .. "|r|T" .. icon .. ":0:0:2:0|t"
        elseif kind == "a" then
            out[#out + 1] = "|cffffffff" .. n .. "|r|TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:0:0:2:0|t"
        elseif kind == "r" then
            out[#out + 1] = GREY .. "(" .. n .. " rating)|r"
        else
            local cnt, id = tok:match("^(%d+)x(%d+)$")
            if cnt then
                id = tonumber(id)
                local icon = ItemIcon(id)
                if icon then
                    out[#out + 1] = "|cffffffff" .. cnt .. "|r|T" .. icon .. ":0:0:2:0|t"
                else
                    out[#out + 1] = "|cffffffff" .. cnt .. " " .. (DATA.currency[id] or ("item " .. id)) .. "|r"
                end
            end
        end
    end
    return table.concat(out, " ")
end

-- colours
local C_ZONE   = "|cff19ff19"   -- zones / instances (green, like the bonus lines on items)
local C_DIFF   = "|cffffd100"   -- 10 / 25 / Heroic
local C_HC     = "|cffff6060"   -- heroic raid (10 HC / 25 HC)
local C_LIMIT  = "|cffffa040"   -- limited stock
local C_NAME   = "|cffffffff"   -- normal names
local C_BOSS   = "|cffff8040"   -- bosses
local C_TRASH  = "|cffd0d0d0"   -- instance trash mobs
local C_RARE   = "|cffc77dff"   -- rare mobs
local C_SKILL  = "|cffffd100"   -- skill needed / quest level
TP.COLORS = { zone = C_ZONE, boss = C_BOSS, trash = C_TRASH, rare = C_RARE }

local C_EVENT  = "|cffff80c0"   -- world events (holidays)
local C_QUEST  = "|cffffd100"   -- quest-only drops
local C_HARD   = "|cffff6060"   -- hard mode only
TP.COLORS.event = C_EVENT

local function Diff(extra)
    if not extra or extra == "" then return nil end
    local t = extra:gsub("_", " ")
    return (t:find("HC") and C_HC or C_DIFF) .. t .. "|r"
end

local function Br(t) return GREY .. "[|r" .. t .. GREY .. "]|r" end
local SEP = GREY .. " - |r"

-- "[Zone [25 HC]] - " with the zone and the difficulty in colour ("" when there is neither)
local function Place(zone, extra, extraColor)
    local z = S(zone)
    if TP.db.compact then z = "" end
    local d = extra and extra ~= "" and (extraColor and (extraColor .. extra .. "|r") or Diff(extra)) or nil
    if z ~= "" and d then return Br(C_ZONE .. z .. "|r " .. Br(d)) .. SEP end
    if z ~= "" then return Br(C_ZONE .. z .. "|r") .. SEP end
    if d then return Br(d) .. SEP end
    return ""
end

-- flags: A / H faction only, q quest, h hard mode, e<string> world event
local function Tags(fl)
    if not fl or fl == "" then return "" end
    local t = ""
    if fl:find("A", 1, true) then t = t .. FACTION_TAG.A end
    if fl:find("H", 1, true) then t = t .. FACTION_TAG.H end
    if fl:find("q", 1, true) then t = t .. " " .. C_QUEST .. "(quest)|r" end
    if fl:find("h", 1, true) then t = t .. " " .. C_HARD .. "(hard mode)|r" end
    local ev = fl:match("e(%d+)")
    if ev then t = t .. " " .. C_EVENT .. "(" .. S(ev) .. ")|r" end
    return t
end

local function Pct(p)
    if p == "0.01-" then return GREY .. "<0.01%|r" end
    local v = tonumber(p) or 0
    local c = v >= 100 and "|cff4cd964" or (v >= 20 and "|cffffffff" or (v >= 5 and "|cffcccccc" or GREY))
    return c .. p .. "%|r"
end

local MOB_COLOR = { B = C_BOSS, T = C_TRASH, R = C_RARE }
local function MobName(name, mtype)
    return (MOB_COLOR[mtype] or C_NAME) .. S(name) .. "|r" .. (mtype == "R" and (" " .. C_RARE .. "(rare)|r") or "")
end

-- Decodes one source: { code, fields } or { more = code, n = count }
local function Decode(src)
    if strsub(src, 1, 1) == "+" then
        local k, n = src:match("^%+(%a)(%d+)$")
        return { more = k, n = n }
    end
    return { code = strsub(src, 1, 1), f = { strsplit(":", strsub(src, 2)) } }
end

-- One source -> left text, right text
--   Vendor: [Dalaran] - Name A (limited stock)          price
--   Drop:   [Ulduar [25]] - Boss (hard mode)            12%
function TP:FormatSource(r, indent)
    if r.more then
        local info = KINDS[r.more]
        return GREY .. "   ... and " .. r.n .. " more " .. (info and info[3] or "") .. "|r"
    end
    local code, f = r.code, r.f
    local info = KINDS[code]
    if not info then return end
    local label = indent and "      " or (info[2] .. info[1] .. ":|r ")
    if code == "V" then
        local name, zone, fac, price, limited, fl = f[1], f[2], f[3], f[4], f[5], f[6]
        return label .. Place(zone) .. C_NAME .. S(name) .. "|r" .. (FACTION_TAG[fac] or "") ..
            (limited == "L" and (" " .. C_LIMIT .. "(limited stock)|r") or "") .. Tags(fl), self:FormatPrice(price)
    elseif code == "Q" then
        local title, zone, fac, lvl, fl = f[1], f[2], f[3], tonumber(f[4]) or 0, f[5]
        return label .. Place(zone) .. C_NAME .. S(title) .. "|r" ..
            (lvl > 0 and (" " .. GREY .. "(level |r" .. C_SKILL .. lvl .. "|r" .. GREY .. ")|r") or "") ..
            (FACTION_TAG[fac] or "") .. Tags(fl)
    elseif code == "K" then
        local skill, rank = S(f[1]), tonumber(f[2]) or 0
        local c = self.GetCraft and self:GetCraft(f[3])
        if c then
            local y = c.yield ~= "1" and (" " .. GREY .. "(makes " .. c.yield .. ")|r") or ""
            return label .. C_NAME .. skill .. "|r" .. y, self:SkillBands(c)
        end
        return label .. C_NAME .. skill .. "|r" .. (rank > 0 and (" " .. GREY .. "(skill |r" .. C_SKILL .. rank .. "|r" .. GREY .. ")|r") or "")
    elseif code == "F" then
        return label .. Br(C_ZONE .. S(f[1]) .. "|r") .. Tags(f[6]), Pct(f[4])
    elseif code == "D" or code == "S" or code == "P" then
        local name, zone, extra, p, mtype, fl = f[1], f[2], f[3], f[4], f[5], f[6]
        if indent then
            -- inside a "[Zone [25]] - trash mobs" group: zone and mode are in the heading
            return label .. MobName(name, mtype) .. Tags(fl), Pct(p)
        end
        return label .. Place(zone, extra) .. MobName(name, mtype) .. Tags(fl), Pct(p)
    else
        local name, zone, extra, p, fl = f[1], f[2], f[3], f[4], f[6]
        return label .. Place(zone, extra) .. C_NAME .. S(name) .. "|r" .. Tags(fl), Pct(p)
    end
end

-- All the lines for an item (or nil). Drops from instance trash are grouped
-- under a "<Instance> trash mobs" heading after the bosses / other mobs.
function TP:GetLines(itemID)
    local raw = DATA.items[itemID]
    if not raw then return end
    local db = self.db
    local list = {}
    for src in raw:gmatch("[^,]+") do list[#list + 1] = Decode(src) end

    local lines = {}
    local function add(r, indent)
        local left, right = self:FormatSource(r, indent)
        if left then lines[#lines + 1] = { left, right } end
    end
    local i = 1
    while i <= #list do
        local r = list[i]
        local code = r.code or r.more
        if db.kinds[code] == false then
            i = i + 1
        elseif r.code == "D" then
            -- all the drop entries of this item
            local drops, more = {}, nil
            while i <= #list and (list[i].code == "D" or list[i].more == "D") do
                if list[i].more then more = list[i] else drops[#drops + 1] = list[i] end
                i = i + 1
            end
            local groups, order = {}, {}
            for _, d in ipairs(drops) do
                if d.f[5] == "T" and S(d.f[2]) ~= "" then
                    local z = d.f[2] .. ":" .. (d.f[3] or "")     -- one group per instance + mode
                    if not groups[z] then groups[z] = {}; order[#order + 1] = z end
                    tinsert(groups[z], d)
                else
                    add(d)
                end
            end
            for _, z in ipairs(order) do
                local g = groups[z][1].f
                local d = Diff(g[3])
                lines[#lines + 1] = { KINDS.D[2] .. "Drop:|r " .. Br(C_ZONE .. S(g[2]) .. "|r" .. (d and (" " .. Br(d)) or "")) ..
                    SEP .. C_TRASH .. "trash mobs|r" }
                for _, d in ipairs(groups[z]) do add(d, true) end
            end
            if more and db.showMore then add(more) end
        else
            if not r.more or db.showMore then add(r) end
            -- under a "Crafted:" line: reagents, which of your characters know it
            if r.code == "K" and r.f[3] and self.CraftExtraLines then
                for _, l in ipairs(self:CraftExtraLines(r.f[3]) or {}) do lines[#lines + 1] = l end
            end
            i = i + 1
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------------------
local done = {}

local function AddToTooltip(tt)
    if not TP.db or not TP.db.enabled or done[tt] then return end
    local _, link = tt:GetItem()
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return end
    done[tt] = true
    local lines = (not TP.db.shiftOnly or IsShiftKeyDown()) and TP:GetLines(id)
    local hint = TP.db.shiftOnly and not IsShiftKeyDown() and DATA.items[id]
    local showAll = not TP.db.shiftOnly or IsShiftKeyDown()
    local prof = showAll and TP.GetProfessionLines and TP:GetProfessionLines(id)
    if prof then
        lines = lines or {}
        for _, l in ipairs(prof) do lines[#lines + 1] = l end
    end
    local hasLines = lines and #lines > 0
    local count, owners
    if TP.db.owned and TP.GetOwned then count, owners = TP:GetOwned(id) end
    local _, _, _, _, _, _, _, stack, _, _, sell = GetItemInfo(id)
    stack = TP.db.stack and stack and stack > 1 and stack
    sell = TP.db.sell and sell and sell > 0 and not (MerchantFrame and MerchantFrame:IsShown()) and sell
    if not hasLines and not hint and not count and not TP.db.itemID and not stack and not sell then return end
    -- own block: empty line, then "Tooltip Plus:" heading, then the sources
    tt:AddLine(" ")
    tt:AddLine((TP.UI and TP.UI.ACCENT or "|cfffc7a2b") .. "Tooltip Plus:|r")
    if hasLines then
        for _, l in ipairs(lines) do
            if l[2] then tt:AddDoubleLine(l[1], l[2]) else tt:AddLine(l[1]) end
        end
    elseif hint then
        tt:AddLine(GREY .. "Hold Shift for item sources|r")
    end
    if sell then
        tt:AddDoubleLine(GREY .. "Sells for|r", TP:FormatPrice(sell .. "c"))
    end
    -- "ID 33445  Stack 20                Count 90", then who has it
    local IC = TP.INV_COLORS
    if TP.db.itemID or stack or count then
        local left = {}
        if TP.db.itemID then left[#left + 1] = IC.label .. "ID|r " .. IC.value .. id .. "|r" end
        if stack then left[#left + 1] = IC.label .. "Stack|r " .. IC.value .. stack .. "|r" end
        tt:AddDoubleLine(#left > 0 and table.concat(left, "   ") or " ",
                         count and (IC.label .. "Count|r " .. IC.value .. count .. "|r") or " ")
    end
    if owners and TP.db.ownedDetail then
        for _, l in ipairs(owners) do tt:AddDoubleLine(l[1], l[2]) end
    end
    -- empty line after the block, so another addon's lines below stay apart
    tt:AddLine(" ")
    tt:Show()
end

local function Hook(tt)
    if not tt or tt.tooltipPlusHooked then return end
    tt.tooltipPlusHooked = true
    tt:HookScript("OnTooltipSetItem", AddToTooltip)
    tt:HookScript("OnTooltipCleared", function(self) done[self] = nil end)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function TP:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage((TP.UI and TP.UI.ACCENT or "|cfffc7a2b") .. "Tooltip Plus|r: " .. tostring(msg))
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if name ~= TP.FOLDER then return end
    self:UnregisterEvent("ADDON_LOADED")
    TooltipPlusDB = TooltipPlusDB or {}
    CopyDefaults(DEFAULTS, TooltipPlusDB)
    TP.db = TooltipPlusDB
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3,
                          ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ItemRefShoppingTooltip3 }) do
        Hook(tt)
    end
    if TP.InitInterfacePanel then TP:InitInterfacePanel() end
    if TP.InitMinimap then TP:InitMinimap() end
end)

SLASH_TOOLTIPPLUS1 = "/tooltipplus"
SLASH_TOOLTIPPLUS2 = "/tplus"
SlashCmdList["TOOLTIPPLUS"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "on" or msg == "off" then
        TP.db.enabled = (msg == "on")
        TP:Print("item sources " .. (TP.db.enabled and "on." or "off."))
    elseif msg:match("^%d+$") then
        local lines = TP:GetLines(tonumber(msg))
        if not lines then TP:Print("No source known for item " .. msg .. ".") return end
        for _, l in ipairs(lines) do TP:Print(l[1] .. (l[2] and ("  " .. l[2]) or "")) end
    elseif msg == "recipes" or msg == "r" then
        TP:ToggleRecipes()
    elseif msg == "items" or msg == "i" then
        TP:ToggleItems()
    elseif msg == "gold" then
        TP:PrintGold()
    elseif msg == "settings" or msg == "options" then
        TP:ShowOptions()
    elseif msg == "minimap" then
        TP.db.minimap = not TP.db.minimap
        TP:UpdateMinimap()
        if TP.RefreshOptions then TP:RefreshOptions() end
        TP:Print("minimap button " .. (TP.db.minimap and "shown." or "hidden."))
    elseif msg == "chars" then
        TP:ListChars()
    elseif msg:match("^forget ") then
        TP:ForgetChar(strtrim(msg:sub(8)))
    elseif msg == "help" then
        TP:Print("/tplus - settings   /tplus on|off - turn the item sources on / off   /tplus <itemID> - print an item's sources")
        TP:Print("/tplus recipes - recipes   /tplus items - items of your characters   /tplus gold - gold of your characters")
        TP:Print("/tplus settings - settings   /tplus minimap - show / hide the minimap button")
        TP:Print("/tplus chars - characters remembered   /tplus forget <name> - forget a deleted character")
    else
        TP:ToggleOptions()
    end
end
