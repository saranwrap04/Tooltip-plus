--[[
    Tooltip Plus - item stats
    Author: Saranwrap

    On item tooltips:
      - ratings as what they give at your level: +32 Critical Strike Rating (0.70% crit)
      - primary stats as what they give your class: +40 Stamina (+400 health)
      - what changes compared to the item you wear in that slot (base stats of both items,
        without gems and enchants)
    Rating formula (3.3.5): percent = rating / base / H(level)
]]

local TP = TooltipPlus
local Stats = {}
TP.Stats = Stats

local _G, pairs, ipairs, tonumber, floor, format, abs = _G, pairs, ipairs, tonumber, math.floor, string.format, math.abs

---------------------------------------------------------------------------
-- Conversions
---------------------------------------------------------------------------
-- level 60 rating per 1 % (per 1 skill point for defense / expertise)
local BASE = {
    def = 1.5, dodge = 13.8, parry = 13.8, block = 5, hit = 10, spellhit = 8, crit = 14,
    haste = 10, exp = 2.5, arp = 4.69512176513672 / 1.1, resil = 28.75,
}
local LOW34 = { def = true, dodge = true, parry = true, block = true, resil = true }
local H80 = 3.2789989471436

local function H(level, key)
    if level >= 80 then return H80 end
    if level >= 70 then return (82 / 52) * (131 / 63) ^ ((level - 70) / 10) end
    if level >= 60 then return 82 / (262 - 3 * level) end
    if level >= 10 then
        if LOW34[key] and level < 34 then return (34 - 8) / 52 end
        return (level - 8) / 52
    end
    return 2 / 52
end

local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7,
    MAGE = 8, WARLOCK = 9, DRUID = 10 }
local AP_PER_STR = { 2, 2, 1, 1, 1, 2, 1, 1, 1, 2 }
local AP_PER_AGI = { 0, 0, 1, 1, 0, 0, 1, 0, 0, 0 }
local RAP_PER_AGI = { 1, 0, 1, 1, 0, 0, 0, 0, 0, 0 }
local BV_PER_STR = { 0.5, 0.5, 0, 0, 0, 0, 0.5, 0, 0, 0 }
-- % crit per point at level 80
local CRIT_PER_AGI = { 0.0160, 0.0192, 0.0120, 0.0120, 0.0192, 0.0160, 0.0120, 0.0196, 0.0198, 0.0120 }
local SPELLCRIT_PER_INT = { 0, 0.0060, 0.0060, 0, 0.0060, 0, 0.0060, 0.0060, 0.0060, 0.0060 }
local EXTRA_HASTE = { [2] = true, [6] = true, [7] = true, [10] = true }   -- paladin, DK, shaman, druid: +30 % melee haste
local MANA = { [2] = true, [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [10] = true }
local CASTER = { [5] = true, [8] = true, [9] = true }

local function Me()
    local _, file = UnitClass("player")
    return CLASS_ID[file or ""] or 1, UnitLevel("player") or 80
end

-- rating -> percent (or skill points for defense / expertise) for you
function Stats.RatingValue(key, n)
    local cls, level = Me()
    local base = BASE[key]
    if not base then return end
    local v = n / base / H(level, key)
    if key == "haste" and EXTRA_HASTE[cls] then v = v * 1.3 end
    return v
end

---------------------------------------------------------------------------
-- Reading tooltip lines
---------------------------------------------------------------------------
-- names in the text -> stat key (longer names first)
local NAMES = {
    { "critical strike rating", "crit" }, { "crit rating", "crit" }, { "critical rating", "crit" },
    { "spell hit rating", "hit" }, { "hit rating", "hit" }, { "haste rating", "haste" },
    { "expertise rating", "exp" }, { "armor penetration rating", "arp" },
    { "defense rating", "def" }, { "dodge rating", "dodge" }, { "parry rating", "parry" },
    { "shield block rating", "block" }, { "block rating", "block" }, { "resilience rating", "resil" },
    { "spell penetration", "spen" }, { "ranged attack power", "rap" }, { "attack power", "ap" },
    { "spell power", "sp" }, { "block value", "bv" }, { "mana per 5", "mp5" }, { "mana every 5", "mp5" },
    { "all stats", "all" }, { "strength", "str" }, { "agility", "agi" }, { "stamina", "sta" },
    { "intellect", "int" }, { "spirit", "spi" },
}
Stats.NAMES = NAMES


local function Clean(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- one line -> { { key, n }, ... }  (nil for lines that are not plain stats)
function Stats.ParseLine(text, forSummary)
    if not text or text == "" then return end
    local t = Clean(text):lower()
    if t:find("^use:") or t:find("chance") or t:find("for %d+ sec") or t:find("forms only") or t:find("^%(%d%) set") or t:find("^set:")
        or t:find("%%") or t:find("^requires") then return end
    if forSummary and t:find("^socket bonus") then return end
    local armor = t:match("^(%d+) armor$")
    if armor then return { { "armor", tonumber(armor) } } end
    local out
    t = t:gsub("^equip: ", ""):gsub("^socket bonus: ", "")
    for seg in (t .. " and "):gmatch("(.-) and ") do
        for part in (seg .. ","):gmatch("(.-),") do
            local n = part:match(" by (%d+)") or part:match("%+(%d+)") or part:match("restores (%d+) mana per 5")
            n = tonumber(n)
            if n then
                if part:find("restores %d+ mana per 5") then
                    out = out or {}; out[#out + 1] = { "mp5", n }
                else
                    for _, nm in ipairs(NAMES) do
                        if part:find(nm[1], 1, true) then
                            out = out or {}
                            if nm[2] == "all" then
                                for _, k in ipairs({ "str", "agi", "sta", "int", "spi" }) do out[#out + 1] = { k, n } end
                            else
                                out[#out + 1] = { nm[2], n }
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- What a stat gives you
---------------------------------------------------------------------------
local function P(v) return format(v >= 10 and "%.1f" or "%.2f", v) end

-- text in brackets after a stat, or nil
function Stats.Explain(key, n, ratings, derived)
    local cls, level = Me()
    local parts = {}
    if ratings and BASE[key] then
        if key == "hit" then
            local melee = Stats.RatingValue("hit", n)
            local spell = n / BASE.spellhit / H(level, "spellhit")
            if CASTER[cls] then parts[#parts + 1] = P(spell) .. "% spell hit"
            elseif MANA[cls] and cls ~= 3 then parts[#parts + 1] = P(melee) .. "% hit, " .. P(spell) .. "% spell hit"
            else parts[#parts + 1] = P(melee) .. "% hit" end
        elseif key == "exp" then
            parts[#parts + 1] = format("%.1f expertise", Stats.RatingValue(key, n))
        elseif key == "def" then
            parts[#parts + 1] = format("+%.1f defense", Stats.RatingValue(key, n))
        else
            local names = { crit = "crit", haste = "haste", arp = "armor pen", dodge = "dodge", parry = "parry",
                block = "block", resil = "resilience" }
            parts[#parts + 1] = P(Stats.RatingValue(key, n)) .. "% " .. names[key]
        end
    elseif derived then
        if key == "str" then
            local ap = n * AP_PER_STR[cls]
            if not CASTER[cls] then parts[#parts + 1] = "+" .. ap .. " AP" end
            if BV_PER_STR[cls] > 0 then parts[#parts + 1] = "+" .. floor(n * BV_PER_STR[cls]) .. " block value" end
        elseif key == "agi" then
            if level >= 80 and not CASTER[cls] then parts[#parts + 1] = P(n * CRIT_PER_AGI[cls]) .. "% crit" end
            if AP_PER_AGI[cls] > 0 then parts[#parts + 1] = "+" .. n * AP_PER_AGI[cls] .. " AP" end
            if cls == 3 then parts[#parts + 1] = "+" .. n * RAP_PER_AGI[cls] .. " ranged AP" end
            parts[#parts + 1] = "+" .. n * 2 .. " armor"
        elseif key == "sta" then
            parts[#parts + 1] = "+" .. n * 10 .. " health"
        elseif key == "int" and MANA[cls] then
            parts[#parts + 1] = "+" .. n * 15 .. " mana"
            if level >= 80 and SPELLCRIT_PER_INT[cls] > 0 and cls ~= 3 then
                parts[#parts + 1] = P(n * SPELLCRIT_PER_INT[cls]) .. "% spell crit"
            end
        end
    end
    if #parts > 0 then return table.concat(parts, ", ") end
end

local EXPLAIN = "|cff9ec5ff"

-- the line with what its stats give (or nil)
function Stats.AnnotateText(text, ratings, derived)
    local list = Stats.ParseLine(text)
    if not list then return end
    local parts, seen = {}, {}
    for _, e in ipairs(list) do
        local x = Stats.Explain(e[1], e[2], ratings, derived)
        if x and not seen[x] then seen[x] = true; parts[#parts + 1] = x end
    end
    if #parts == 0 then return end
    return text .. " " .. EXPLAIN .. "(" .. table.concat(parts, "; ") .. ")|r"
end

---------------------------------------------------------------------------
-- Item stats (base stats, from a hidden tooltip of the item without gems / enchant)
---------------------------------------------------------------------------
local scan
local function Scanner()
    if not scan then
        scan = CreateFrame("GameTooltip", "TooltipPlusScanTip", nil, "GameTooltipTemplate")
        scan:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    return scan
end

local cache = {}
function Stats.ItemStats(link)
    local id, suffix, unique, lvl = link:match("item:(%d+):%-?%d*:%-?%d*:%-?%d*:%-?%d*:%-?%d*:(%-?%d*):(%-?%d*):?(%-?%d*)")
    if not id then id = link:match("item:(%d+)") end
    if not id then return end
    local base = "item:" .. id .. ":0:0:0:0:0:" .. (suffix ~= "" and suffix or "0") .. ":" ..
        ((unique and unique ~= "") and unique or "0") .. ":" .. ((lvl and lvl ~= "") and lvl or "0")
    if cache[base] then return cache[base] end
    local tip = Scanner()
    tip:ClearLines()
    tip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tip:SetHyperlink(base)
    local s = {}
    for i = 2, tip:NumLines() do
        local fs = _G["TooltipPlusScanTipTextLeft" .. i]
        local list = fs and Stats.ParseLine(fs:GetText(), true)
        for _, e in ipairs(list or {}) do s[e[1]] = (s[e[1]] or 0) + e[2] end
    end
    if tip:NumLines() > 0 then cache[base] = s end
    return s
end

-- slots to compare an equip location with
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

---------------------------------------------------------------------------
-- Stat summary: what the item gives you, and the change against what you wear
---------------------------------------------------------------------------
-- rows: key, label, format, shown for (all / phys / caster / mana / tank)
local ROWS = {
    { "health",    "Health",                 "%d" },
    { "mana",      "Mana",                   "%d",   "mana" },
    { "mp5",       "Mana Regen",             "%.1f", "mana" },
    { "ap",        "Attack Power",           "%d",   "phys" },
    { "rap",       "Ranged Attack Power",    "%d",   "hunter" },
    { "sp",        "Spell Power",            "%d",   "mana" },
    { "spi",       "Spirit",                 "%d",   "mana" },
    { "armor",     "Armor",                  "%d" },
    { "bv",        "Block Value",            "%d",   "tank" },
    { "crit",      "Crit Chance(%)",         "%.2f", "phys" },
    { "spellcrit", "Spell Crit Chance(%)",   "%.2f", "mana" },
    { "hit",       "Hit(%)",                 "%.2f", "phys" },
    { "spellhit",  "Spell Hit(%)",           "%.2f", "mana" },
    { "haste",     "Haste(%)",               "%.2f", "phys" },
    { "spellhaste","Spell Haste(%)",         "%.2f", "mana" },
    { "exp",       "Expertise",              "%.1f", "phys" },
    { "arp",       "Armor Penetration(%)",   "%.2f", "phys" },
    { "spen",      "Spell Penetration",      "%d",   "mana" },
    { "def",       "Defense",                "%.1f", "tank" },
    { "dodge",     "Dodge(%)",               "%.2f", "tank" },
    { "parry",     "Parry(%)",               "%.2f", "tank" },
    { "block",     "Block(%)",               "%.2f", "tank" },
    { "resil",     "Resilience(%)",          "%.2f" },
}
local TANK = { [1] = true, [2] = true, [6] = true, [10] = true }

local function Shown(who, cls)
    if not who then return true end
    if who == "mana" then return MANA[cls] and true or false end
    if who == "phys" then return not CASTER[cls] end
    if who == "hunter" then return cls == 3 end
    if who == "tank" then return TANK[cls] and true or false end
    return true
end

-- base stats of an item -> what they give you
function Stats.Derive(s)
    local cls, level = Me()
    s = s or {}
    local str, agi, sta, int = s.str or 0, s.agi or 0, s.sta or 0, s.int or 0
    local function pct(key, n) return n ~= 0 and n / BASE[key] / H(level, key) or 0 end
    local crit = pct("crit", s.crit or 0)
    local d = {
        health = sta * 10,
        mana = MANA[cls] and int * 15 or 0,
        mp5 = s.mp5 or 0,
        ap = (s.ap or 0) + str * AP_PER_STR[cls] + agi * AP_PER_AGI[cls],
        rap = (s.rap or 0) + (s.ap or 0) + agi * RAP_PER_AGI[cls],
        sp = s.sp or 0,
        spi = s.spi or 0,
        armor = (s.armor or 0) + agi * 2,
        bv = (s.bv or 0) + str * BV_PER_STR[cls],
        crit = crit + (level >= 80 and agi * CRIT_PER_AGI[cls] or 0),
        spellcrit = crit + (level >= 80 and int * SPELLCRIT_PER_INT[cls] or 0),
        hit = pct("hit", s.hit or 0),
        spellhit = pct("spellhit", s.hit or 0),
        haste = (s.haste or 0) ~= 0 and Stats.RatingValue("haste", s.haste) or 0,
        spellhaste = pct("haste", s.haste or 0),
        exp = (s.exp or 0) ~= 0 and Stats.RatingValue("exp", s.exp) or 0,
        arp = pct("arp", s.arp or 0),
        spen = s.spen or 0,
        def = (s.def or 0) ~= 0 and Stats.RatingValue("def", s.def) or 0,
        dodge = pct("dodge", s.dodge or 0),
        parry = pct("parry", s.parry or 0),
        block = pct("block", s.block or 0),
        resil = pct("resil", s.resil or 0),
    }
    return d
end

local GREEN, RED = "|cff20ff20", "|cffff3030"

local function Num(fmt, v)
    local t = format(fmt, v)
    if fmt == "%d" then t = format("%d", floor(v + 0.5)) end
    return t
end

local function Diff(fmt, d)
    if abs(d) < 0.005 then return "|cff9d9d9d0|r" end
    return (d > 0 and GREEN .. "+" or RED .. "-") .. Num(fmt, abs(d)) .. "|r"
end

-- new: base stats of the item; olds: base stats of what you wear in each slot (nil: empty)
-- -> { { label, right text }, ... }
function Stats.SummaryRows(new, olds)
    local cls = Me()
    local a = Stats.Derive(new)
    local b = {}
    for i, o in ipairs(olds or {}) do b[i] = Stats.Derive(o or {}) end
    local rows = {}
    for _, r in ipairs(ROWS) do
        local k, fmt = r[1], r[3]
        if Shown(r[4], cls) then
            local v = a[k] or 0
            local diffs, any = {}, false
            for i, o in ipairs(b) do
                local d = v - (o[k] or 0)
                if abs(d) >= 0.005 then any = true end
                diffs[i] = Diff(fmt, d)
            end
            if abs(v) >= 0.005 or any then
                local right = "|cffffffff" .. Num(fmt, v) .. "|r"
                if #diffs > 0 then right = right .. " (" .. table.concat(diffs, " / ") .. ")" end
                rows[#rows + 1] = { r[2], right }
            end
        end
    end
    return rows
end

-- the summary for a tooltip showing link: header, then { label, value (change) } rows
function Stats.Summary(link, compare)
    local new = Stats.ItemStats(link)
    if not new then return end
    local olds, names = {}, {}
    if compare then
        local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
        local slots = loc and SLOTS[loc]
        local id = tonumber(link:match("item:(%d+)"))
        for _, slot in ipairs(slots or {}) do
            local eq = GetInventoryItemLink("player", slot)
            if eq and tonumber(eq:match("item:(%d+)")) == id then olds, names = {}, {}; break end   -- the one you wear
            if not (slot == 17 and loc == "INVTYPE_WEAPON" and not eq) then
                olds[#olds + 1] = eq and Stats.ItemStats(eq) or {}
                local name, _, q = nil, nil, nil
                if eq then name, _, q = GetItemInfo(eq) end
                local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                names[#names + 1] = name and ((qc and qc.hex or "|cffffffff") .. name .. "|r") or "|cff9d9d9dempty|r"
            end
        end
    end
    local rows = Stats.SummaryRows(new, olds)
    if #rows == 0 then return end
    local head = #names > 0 and ("|cff9d9d9dvs|r " .. table.concat(names, "|cff9d9d9d / |r")) or nil
    return rows, head
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local GOLD = "|cffffd100"

function Stats:OnItem(tt, link)
    local s = TP.db.style
    if tt.tpStats then return end
    tt.tpStats = true
    if s.statRatings or s.statDerived then
        local name = tt:GetName()
        local changed
        for i = 2, tt:NumLines() do
            local fs = _G[name .. "TextLeft" .. i]
            local text = fs and fs:GetText()
            local new = text and Stats.AnnotateText(text, s.statRatings, s.statDerived)
            if new then fs:SetText(new); changed = true end
        end
        if changed then tt:Show() end
    end
    if s.statSummary and (tt == GameTooltip or tt == ItemRefTooltip) and IsEquippableItem(link) then
        local rows, head = Stats.Summary(link, s.statCompare)
        if rows then
            tt:AddLine(" ")
            tt:AddDoubleLine("Stat Summary", head or " ", 1, 1, 1, 1, 1, 1)
            for _, r in ipairs(rows) do tt:AddDoubleLine(r[1], r[2], 1, 0.82, 0, 1, 1, 1) end
            tt:Show()
        end
    end
end
