--[[
    Tooltip Plus - professions
    Author: Saranwrap

    - Crafted items: skill colours (orange / yellow / green / grey), reagents,
      which of your characters know the recipe
    - Reagents: which professions use the item, which of your characters can use it
    - Recipe items: which of your characters know it, can learn it now, or later
    Your characters' professions are read at login; the recipes they know are read
    when they open each profession window.
]]

local TP = TooltipPlus
local DATA = TooltipPlusData
local tonumber, pairs, ipairs, floor, format = tonumber, pairs, ipairs, math.floor, string.format
local strsplit = strsplit

local GREY = "|cff9d9d9d"
local WHITE = "|cffffffff"
local C_LABEL = "|cffffa040"     -- same as "Crafted:"
local DIFF = {
    red    = "|cffff2020",       -- can't make / learn it yet
    orange = "|cffff8040",
    yellow = "|cffffff00",
    green  = "|cff40bf40",
    grey   = "|cff808080",
}
TP.DIFF = DIFF

local function S(i) return DATA.strings[tonumber(i) or 0] or "" end

---------------------------------------------------------------------------
-- Data
---------------------------------------------------------------------------
local cache = {}
-- crafts[spell] -> { skill, req, yellow, green, grey, item, yield, reagents = { {id, n}, ... } }
function TP:GetCraft(spell)
    spell = tonumber(spell)
    if not spell or not DATA.crafts or not DATA.crafts[spell] then return end
    local c = cache[spell]
    if c then return c end
    local skill, req, yel, gry, item, yield, reag, name, src = strsplit(":", DATA.crafts[spell])
    req, yel, gry = tonumber(req) or 0, tonumber(yel) or 0, tonumber(gry) or 0
    c = { spell = spell, skill = S(skill), req = req, yellow = yel, grey = gry,
          green = floor((yel + gry) / 2), item = tonumber(item) or 0, yield = yield, reagents = {},
          name = S(name), trainer = (src or ""):find("T") ~= nil, auto = (src or ""):find("A") ~= nil }
    for id, n in (reag or ""):gmatch("(%d+)%*(%d+)") do
        c.reagents[#c.reagents + 1] = { tonumber(id), tonumber(n) }
    end
    cache[spell] = c
    return c
end

-- reagent item -> { spell, ... } (built the first time it is needed)
local usedIn
local function UsedIn(id)
    if not usedIn then
        usedIn = {}
        for spell in pairs(DATA.crafts or {}) do
            local c = TP:GetCraft(spell)
            for _, r in ipairs(c.reagents) do
                local t = usedIn[r[1]]
                if not t then t = {}; usedIn[r[1]] = t end
                t[#t + 1] = spell
            end
        end
    end
    return usedIn[id]
end

-- craft spell -> recipe items that teach it
local recipeItems
function TP:RecipeItemsFor(spell)
    if not recipeItems then
        recipeItems = {}
        for item, raw in pairs(DATA.recipes or {}) do
            local sp = tonumber((strsplit(":", raw)))
            if sp then
                recipeItems[sp] = recipeItems[sp] or {}
                tinsert(recipeItems[sp], item)
            end
        end
    end
    return recipeItems[spell]
end
TP.UsedIn = function(_, id) return UsedIn(id) end

-- colour of a craft for a skill rank
local function DiffColor(c, rank)
    if not rank or rank < c.req then return DIFF.red end
    if rank < c.yellow then return DIFF.orange end
    if rank < c.green then return DIFF.yellow end
    if rank < c.grey then return DIFF.green end
    return DIFF.grey
end
TP.DiffColor = function(_, c, rank) return DiffColor(c, rank) end
local ORDER = { [DIFF.grey] = 1, [DIFF.green] = 2, [DIFF.yellow] = 3, [DIFF.orange] = 4, [DIFF.red] = 0 }

-- "[250 290 305 320]" in the four skill colours
function TP:SkillBands(c)
    if c.req <= 0 then return "" end
    if c.grey <= c.req then return GREY .. "[|r" .. DIFF.orange .. c.req .. "|r" .. GREY .. "]|r" end
    return GREY .. "[|r" .. DIFF.orange .. c.req .. "|r " .. DIFF.yellow .. c.yellow .. "|r " ..
        DIFF.green .. c.green .. "|r " .. DIFF.grey .. c.grey .. "|r" .. GREY .. "]|r"
end

local function ItemName(id)
    if not id or id == 0 then return "" end
    local name, _, q = GetItemInfo(id)
    if name then
        local _, _, _, hex = GetItemQualityColor(q or 1)
        return (hex or WHITE) .. name .. "|r"
    end
    return WHITE .. (DATA.names and DATA.names[id] or ("item " .. id)) .. "|r"
end

TP.ItemName = function(_, id) return ItemName(id) end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------
local function Chars()
    local chars, me = TP:CharTable()
    return chars or {}, me
end

local function Name(name, c, color)
    return (color or TP.ClassColor(c.class)) .. name .. "|r"
end

-- names joined, this character first
local function SortedNames(list, me)
    table.sort(list, function(a, b)
        if (a.name == me) ~= (b.name == me) then return a.name == me end
        return a.name < b.name
    end)
end

-- lines of names, a few per line: "      Label: a, b, c"
local function NameLines(lines, label, names)
    if #names == 0 then return end
    local per = 4
    for i = 1, #names, per do
        local chunk = {}
        for k = i, math.min(i + per - 1, #names) do chunk[#chunk + 1] = names[k] end
        lines[#lines + 1] = { "      " .. (i == 1 and (GREY .. label .. ":|r ") or "   ") .. table.concat(chunk, GREY .. ", |r") }
    end
end

---------------------------------------------------------------------------
-- Tooltip lines
---------------------------------------------------------------------------
-- under a "Crafted:" line: reagents, who knows it
function TP:CraftExtraLines(spell)
    spell = tonumber(spell)
    local c = self:GetCraft(spell)
    if not c then return end
    local lines = {}
    if self.db.reagents and #c.reagents > 0 then
        local parts = {}
        for _, r in ipairs(c.reagents) do parts[#parts + 1] = WHITE .. r[2] .. "|r " .. ItemName(r[1]) end
        for i = 1, #parts, 3 do
            local chunk = {}
            for k = i, math.min(i + 2, #parts) do chunk[#chunk + 1] = parts[k] end
            lines[#lines + 1] = { "      " .. (i == 1 and (GREY .. "Reagents:|r ") or "   ") .. table.concat(chunk, GREY .. ", |r") }
        end
    end
    if self.db.recipeInfo then
        for _, l in ipairs(self:CraftCharLines(c)) do lines[#lines + 1] = l end
    end
    return lines
end

-- your characters for a recipe: "Known by" (name in its skill colour), "Can learn" (skill high
-- enough), "Later" (has the profession, skill too low). learn / spec: from the recipe item.
function TP:CraftCharLines(c, learn, spec)
    local chars, me = Chars()
    learn = learn or c.req
    spec = spec or ""
    local known, can, later = {}, {}, {}
    for name, ch in pairs(chars) do
        local rank = ch.prof and ch.prof[c.skill]
        if ch.known and ch.known[c.spell] then
            known[#known + 1] = { name = name, text = Name(name, ch, DiffColor(c, rank)) }
        elseif rank and not c.auto and (spec == "" or (ch.spec and ch.spec[spec])) then
            local t = { name = name, text = Name(name, ch) .. " " .. GREY .. "(" .. rank .. ")|r" }
            if rank >= learn then can[#can + 1] = t else later[#later + 1] = t end
        end
    end
    for _, list in ipairs({ known, can, later }) do SortedNames(list, me) end
    local function texts(list) local t = {} for _, o in ipairs(list) do t[#t + 1] = o.text end return t end
    local lines = {}
    NameLines(lines, "Known by", texts(known))
    NameLines(lines, "Can learn", texts(can))
    NameLines(lines, "Later", texts(later))
    return lines
end

-- reagents and recipe items
function TP:GetProfessionLines(id)
    local lines = {}
    local db = self.db
    local chars, me = Chars()

    -- recipe item: who knows it / can learn it / will be able to
    local recipe = DATA.recipes and DATA.recipes[id]
    if recipe and db.recipeInfo then
        local spell, learn, spec = strsplit(":", recipe)
        local c = self:GetCraft(spell)
        if c then
            learn = tonumber(learn) or 0
            if learn <= 0 then learn = c.req end
            spec = S(spec)
            local made = c.item > 0 and ItemName(c.item) or (WHITE .. (GetSpellInfo(c.spell) or "") .. "|r")
            lines[#lines + 1] = { C_LABEL .. "Teaches:|r " .. made .. " " .. GREY .. "(" .. c.skill .. " " .. learn .. ")|r",
                                  self:SkillBands(c) }
            for _, l in ipairs(self:CraftCharLines(c, learn, spec)) do lines[#lines + 1] = l end
        end
    end

    -- reagent: professions that use it, your characters who can use it
    local spells = db.usedIn and UsedIn(id)
    if spells then
        local per, order = {}, {}
        for _, spell in ipairs(spells) do
            local c = self:GetCraft(spell)
            if not per[c.skill] then per[c.skill] = 0; order[#order + 1] = c.skill end
            per[c.skill] = per[c.skill] + 1
        end
        table.sort(order, function(a, b) return per[a] > per[b] or (per[a] == per[b] and a < b) end)
        local parts = {}
        for _, sk in ipairs(order) do parts[#parts + 1] = WHITE .. sk .. "|r " .. GREY .. per[sk] .. "|r" end
        lines[#lines + 1] = { C_LABEL .. "Used in:|r " .. table.concat(parts, GREY .. ", |r", 1, math.min(#parts, 4)) ..
            (#parts > 4 and (GREY .. " +" .. (#parts - 4) .. "|r") or ""),
            GREY .. #spells .. (#spells == 1 and " recipe|r" or " recipes|r") }
        -- your characters who know a recipe that uses it (colour = best skill colour of those recipes)
        local list = {}
        for name, ch in pairs(chars) do
            if ch.known then
                local n, best = 0, nil
                for _, spell in ipairs(spells) do
                    if ch.known[spell] then
                        n = n + 1
                        local c = self:GetCraft(spell)
                        local col = DiffColor(c, ch.prof and ch.prof[c.skill])
                        if not best or ORDER[col] > ORDER[best] then best = col end
                    end
                end
                if n > 0 then
                    list[#list + 1] = { name = name, text = Name(name, ch, best) .. " " .. GREY .. "(" .. n .. ")|r" }
                end
            end
        end
        SortedNames(list, me)
        local names = {}
        for _, o in ipairs(list) do names[#names + 1] = o.text end
        NameLines(lines, "Usable by", names)
    end
    if #lines > 0 then return lines end
end

---------------------------------------------------------------------------
-- Reading your characters' professions
---------------------------------------------------------------------------
local PROF   -- profession names in the data
local function ProfNames()
    if not PROF then
        PROF = {}
        for spell in pairs(DATA.crafts or {}) do PROF[TP:GetCraft(spell).skill] = true end
    end
    return PROF
end

local function Mine()
    local chars, me = TP:CharTable()
    return chars and me and chars[me]
end

local function ScanSkills()
    local mine = Mine()
    if not mine then return end
    local names, prof, found = ProfNames(), {}, false
    for i = 1, GetNumSkillLines() do
        local name, header, _, rank = GetSkillLineInfo(i)
        if not header and names[name] then prof[name] = rank; found = true end
    end
    if found or not mine.prof then mine.prof = prof end
    -- specialisations (Gnomish Engineer, Mooncloth Tailoring...): known when the spell name is found
    local spec = {}
    for _, s in ipairs(DATA.specs or {}) do
        if GetSpellInfo(s) then spec[s] = true end
    end
    mine.spec = spec
end

local function ScanTradeSkill()
    if IsTradeSkillLinked and IsTradeSkillLinked() then return end   -- someone else's profession
    local mine = Mine()
    if not mine then return end
    mine.known = mine.known or {}
    local name, rank = GetTradeSkillLine()
    if name and rank and rank > 0 and ProfNames()[name] then
        mine.prof = mine.prof or {}
        mine.prof[name] = rank
    end
    for i = 1, GetNumTradeSkills() do
        local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
        local spell = link and tonumber(link:match("enchant:(%d+)"))
        if spell then mine.known[spell] = true end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        ScanSkills()
        self:RegisterEvent("SKILL_LINES_CHANGED")
        self:RegisterEvent("TRADE_SKILL_SHOW")
        self:RegisterEvent("TRADE_SKILL_UPDATE")
    elseif event == "SKILL_LINES_CHANGED" then
        ScanSkills()
    else
        ScanTradeSkill()
    end
end)
