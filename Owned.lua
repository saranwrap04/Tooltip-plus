--[[
    Tooltip Plus - your characters' items, gold and currencies
    Author: Saranwrap

    Remembered for every character of the account (TooltipPlusChars):
    bags + keyring, bank, equipped items, mailbox, currencies (emblems, badges...)
    and gold. Guild banks are remembered per guild (TooltipPlusGuilds).
    The bank, the mailbox and the guild bank are read when you open them.
]]

local TP = TooltipPlus
local tonumber, pairs, ipairs, format = tonumber, pairs, ipairs, string.format

local GREY = "|cff9d9d9d"
-- tooltip colours: labels red, numbers gold, characters / places green, details silver
local C_LABEL, C_VALUE, C_OWNER, C_SILVER = "|cffca3c3c", "|cffffd200", "|cff80ff00", "|cffc7c7cf"
TP.INV_COLORS = { label = C_LABEL, value = C_VALUE, owner = C_OWNER, silver = C_SILVER }

local PLACES = { "bags", "bank", "equip", "mail", "currency" }
local PLACE_NAME = { bags = "Bags", bank = "Bank", equip = "Equipped", mail = "Mail", currency = "Currency" }
TP.PLACES, TP.PLACE_NAME = PLACES, PLACE_NAME

local realm, me, mine

local function ItemID(link)
    return link and tonumber(tostring(link):match("item:(%d+)"))
end

local function Add(t, link, n)
    local id = ItemID(link)
    if id then t[id] = (t[id] or 0) + (n or 1) end
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------
local function ScanBagIDs(ids)
    local t = {}
    for _, bag in ipairs(ids) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, count = GetContainerItemInfo(bag, slot)
                Add(t, link, count)
            end
        end
    end
    return t
end

local function ScanBags()
    mine.bags = ScanBagIDs({ 0, 1, 2, 3, 4, KEYRING_CONTAINER or -2 })
end

local bankOpen = false
local function ScanBank()
    if not bankOpen then return end
    local ids = { BANK_CONTAINER or -1 }
    for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do ids[#ids + 1] = bag end
    mine.bank = ScanBagIDs(ids)
end

local function ScanEquip()
    local t = {}
    for slot = 1, 19 do Add(t, GetInventoryItemLink("player", slot), 1) end
    mine.equip = t
end

local function ScanMail()
    local t = {}
    for i = 1, GetInboxNumItems() do
        for j = 1, ATTACHMENTS_MAX_RECEIVE or 12 do
            local link = GetInboxItemLink(i, j)
            if link then
                local _, _, count = GetInboxItem(i, j)
                Add(t, link, count)
            end
        end
    end
    mine.mail = t
end

-- currencies (Currency tab): emblems, badges, tokens...
local function ScanCurrency()
    if not GetCurrencyListSize then return end
    local t, found = {}, false
    for i = 1, GetCurrencyListSize() do
        local _, isHeader, _, _, _, count, _, _, itemID = GetCurrencyListInfo(i)
        if not isHeader and itemID and itemID > 0 then
            found = true
            if count and count > 0 then t[itemID] = count end
        end
    end
    if found or not mine.currency then mine.currency = t end
end

local function ScanGuild()
    mine.guild = IsInGuild() and GetGuildInfo("player") or nil
end

-- guild bank: the tab shown (each tab is read when you look at it)
local function ScanGuildBank()
    local guild = IsInGuild() and GetGuildInfo("player")
    if not guild or not GetCurrentGuildBankTab then return end
    local tab = GetCurrentGuildBankTab()
    local _, _, canView = GetGuildBankTabInfo(tab)
    if not canView then return end
    TooltipPlusGuilds[realm] = TooltipPlusGuilds[realm] or {}
    local g = TooltipPlusGuilds[realm][guild] or {}
    TooltipPlusGuilds[realm][guild] = g
    local t = {}
    for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB or 98 do
        local link = GetGuildBankItemLink(tab, slot)
        if link then
            local _, count = GetGuildBankItemInfo(tab, slot)
            Add(t, link, count)
        end
    end
    g[tab] = t
    g.tabs = GetNumGuildBankTabs()
    for k in pairs(g) do                     -- tabs that no longer exist
        if type(k) == "number" and k > g.tabs then g[k] = nil end
    end
end

---------------------------------------------------------------------------
-- Tooltip: counts per character
---------------------------------------------------------------------------
local function ClassColor(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "|cffffffff" end
    return format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

-- "Bags: 24"  or  "90 (Bags: 24, Bank: 66)"
local function CountText(parts, total)
    if #parts == 1 then return C_OWNER .. parts[1] .. "|r" end
    return C_OWNER .. total .. "|r" .. C_SILVER .. " (" .. table.concat(parts, ", ") .. ")|r"
end

-- total count, { {left, right}, ... }  (nil when nobody has it)
function TP:GetOwned(id)
    if not realm or not TooltipPlusChars[realm] then return end
    local owners, total = {}, 0
    for name, c in pairs(TooltipPlusChars[realm]) do
        local parts, n = {}, 0
        for _, place in ipairs(PLACES) do
            local k = c[place] and c[place][id]
            if k and k > 0 then
                n = n + k
                parts[#parts + 1] = PLACE_NAME[place] .. ": " .. k
            end
        end
        if n > 0 then
            total = total + n
            owners[#owners + 1] = { name, CountText(parts, n) }
        end
    end
    table.sort(owners, function(a, b)
        if (a[1] == me) ~= (b[1] == me) then return a[1] == me end
        return a[1] < b[1]
    end)
    local lines = {}
    for _, o in ipairs(owners) do lines[#lines + 1] = { C_OWNER .. o[1] .. "|r", o[2] } end
    -- guild banks
    local guilds = TooltipPlusGuilds and TooltipPlusGuilds[realm]
    if guilds then
        local names = {}
        for g in pairs(guilds) do names[#names + 1] = g end
        table.sort(names)
        for _, g in ipairs(names) do
            local n = 0
            for tab, items in pairs(guilds[g]) do
                if type(tab) == "number" and items[id] then n = n + items[id] end
            end
            if n > 0 then
                total = total + n
                lines[#lines + 1] = { C_OWNER .. "<" .. g .. ">|r", C_OWNER .. "Guild: " .. n .. "|r" }
            end
        end
    end
    if total == 0 then return end
    return total, lines
end

-- every item any of your characters (or guild banks) has: id -> total
function TP:AllOwnedItems(onlyChar)
    local all = {}
    for name, c in pairs(realm and TooltipPlusChars[realm] or {}) do
        if not onlyChar or onlyChar == name then
            for _, place in ipairs(PLACES) do
                for id, n in pairs(c[place] or {}) do all[id] = (all[id] or 0) + n end
            end
        end
    end
    if not onlyChar or onlyChar == "#guild" then
        for _, g in pairs(TooltipPlusGuilds and TooltipPlusGuilds[realm] or {}) do
            for tab, items in pairs(g) do
                if type(tab) == "number" then
                    for id, n in pairs(items) do all[id] = (all[id] or 0) + n end
                end
            end
        end
    end
    return all
end

---------------------------------------------------------------------------
-- Gold
---------------------------------------------------------------------------
-- { {name, copper, class}, ... }, total
function TP:GetGold()
    local list, total = {}, 0
    for name, c in pairs(realm and TooltipPlusChars[realm] or {}) do
        if c.money then
            list[#list + 1] = { name, c.money, c.class }
            total = total + c.money
        end
    end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    return list, total
end

function TP:AddGoldLines(tt)
    local list, total = self:GetGold()
    if #list == 0 then return end
    tt:AddLine(" ")
    for _, o in ipairs(list) do
        tt:AddDoubleLine(ClassColor(o[3]) .. o[1] .. "|r", self:FormatPrice(o[2] .. "c"))
    end
    tt:AddDoubleLine(C_LABEL .. "Total|r", self:FormatPrice(total .. "c"))
end

function TP:PrintGold()
    local list, total = self:GetGold()
    for _, o in ipairs(list) do self:Print(ClassColor(o[3]) .. o[1] .. "|r  " .. self:FormatPrice(o[2] .. "c")) end
    self:Print(C_LABEL .. "Total|r  " .. self:FormatPrice(total .. "c"))
end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------
-- for the professions / recipes modules: this realm's characters, this character's name
function TP:CharTable() return realm and TooltipPlusChars[realm], me end
TP.ClassColor = ClassColor

-- characters of this realm: { name, label (class colour), isMe }, this character first
function TP:GetChars()
    local list = {}
    for name, c in pairs(realm and TooltipPlusChars[realm] or {}) do
        list[#list + 1] = { name = name, isMe = (name == me),
            label = ClassColor(c.class) .. name .. "|r" .. (name == me and (GREY .. " (this character)|r") or "") }
    end
    table.sort(list, function(a, b)
        if a.isMe ~= b.isMe then return a.isMe end
        return a.name < b.name
    end)
    return list
end

-- /tplus chars, /tplus forget <name>
function TP:ListChars()
    local list = {}
    for name, c in pairs(TooltipPlusChars[realm] or {}) do list[#list + 1] = ClassColor(c.class) .. name .. "|r" end
    table.sort(list)
    self:Print("characters remembered on " .. realm .. ": " .. (#list > 0 and table.concat(list, ", ") or "none"))
end

function TP:ForgetChar(name)
    name = name and name:gsub("^%l", string.upper)
    local chars = TooltipPlusChars[realm]
    if not name or name == "" or not chars or not chars[name] then
        self:Print("no character named \"" .. (name or "") .. "\" on " .. realm .. ".")
    elseif name == me then
        self:Print("this is the character you are playing; log on another one to forget it.")
    else
        chars[name] = nil
        self:Print(name .. " forgotten.")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
local pending, wait = {}, 0
local function Later(what, delay)
    pending[what] = true
    wait = delay or 0.5
    f:Show()
end
f:Hide()
f:SetScript("OnUpdate", function(self, elapsed)
    wait = wait - elapsed
    if wait > 0 then return end
    self:Hide()
    if pending.bags then ScanBags() end
    if pending.bank then ScanBank() end
    if pending.equip then ScanEquip() end
    if pending.currency then ScanCurrency() end
    if pending.guild then ScanGuild() end
    if pending.guildbank then ScanGuildBank() end
    pending = {}
end)

f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        TooltipPlusChars = TooltipPlusChars or {}
        TooltipPlusGuilds = TooltipPlusGuilds or {}
        realm, me = GetRealmName(), UnitName("player")
        TooltipPlusChars[realm] = TooltipPlusChars[realm] or {}
        mine = TooltipPlusChars[realm][me] or {}
        TooltipPlusChars[realm][me] = mine
        local _, class = UnitClass("player")
        mine.class, mine.faction = class, UnitFactionGroup("player")
        mine.money = GetMoney()
        ScanBags(); ScanEquip(); ScanGuild()
        Later("currency", 3)
        for _, e in ipairs({ "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                             "PLAYERBANKSLOTS_CHANGED", "MAIL_INBOX_UPDATE", "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE",
                             "PLAYER_GUILD_UPDATE", "GUILDBANKFRAME_OPENED", "GUILDBANKBAGSLOTS_CHANGED" }) do
            self:RegisterEvent(e)
        end
    elseif event == "BAG_UPDATE" then
        local bag = tonumber(arg1) or 0
        if bag > NUM_BAG_SLOTS then Later("bank") else Later("bags") end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        Later("equip")
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        ScanBank()
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        Later("bank")
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false        -- keep what was read while it was open
    elseif event == "MAIL_INBOX_UPDATE" then
        ScanMail()
    elseif event == "PLAYER_MONEY" then
        mine.money = GetMoney()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        Later("currency")
    elseif event == "PLAYER_GUILD_UPDATE" then
        Later("guild")
    elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
        Later("guildbank", 0.3)
    end
end)
