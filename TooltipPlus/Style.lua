--[[
    Tooltip Plus - tooltip look and unit info
    Author: Saranwrap

    Position (game default, at the mouse, or a fixed spot), flat look, scale, font,
    colours, class / reaction / quality borders, unit lines (class colours, guild rank,
    level, target, talents, NPC ID), health and power bars, and IDs / icons on links.
]]

local TP = TooltipPlus
local Style = {}
TP.Style = Style

local _G, pairs, ipairs, tonumber, tostring, format, floor = _G, pairs, ipairs, tonumber, tostring, string.format, math.floor
local GetTime, UnitExists, UnitIsPlayer = GetTime, UnitExists, UnitIsPlayer

Style.DEFAULTS = {
    enabled = true,          -- flat look, colours, scale, font
    scale = 1,
    font = "default",
    fontSize = 12,
    bg = { 0.06, 0.06, 0.06, 0.92 },
    border = { 0, 0, 0, 1 },
    anchorWorld = "mouse",   -- units and objects in the 3D world: default / mouse / fixed
    anchorFrame = "default", -- unit frames, action bars, everything that uses the default spot
    mouseSide = "BOTTOM",    -- which side of the tooltip sits at the mouse
    mouseX = 0,
    mouseY = 24,
    unitBorder = true,       -- class colour (players) / reaction colour (NPCs)
    classNames = true,
    tags = true,             -- <AFK> <DND>
    guildRank = true,
    levelLine = true,
    hideFaction = true,      -- "Alliance" / "Horde" and "PvP" lines
    target = true,
    talents = true,
    npcID = true,
    healthBar = true,
    powerBar = true,
    barText = true,
    qualityBorder = true,
    itemLevel = true,
    linkIDs = true,          -- spell / quest / achievement IDs
    linkIcon = true,         -- icon beside a link clicked in chat
    targetedBy = true,       -- how many of your group target the unit, and who
    statRatings = true,      -- ratings as % at your level
    statDerived = true,      -- primary stats as what they give your class
    statSummary = true,      -- stat summary under gear
    statCompare = true,      -- with the change against the item you wear
}

Style.FONTS = {
    { "default", "Game default" },
    { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" },
    { "Fonts\\ARIALN.TTF", "Arial Narrow" },
    { "Fonts\\skurri.ttf", "Skurri" },
    { "Fonts\\MORPHEUS.ttf", "Morpheus" },
}

local function db() return TP.db.style end

local LOOK_TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3", "WorldMapTooltip" }
local tips = {}

local FLAT = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }

local function C(label) return TP.INV_COLORS and TP.INV_COLORS[label] or "|cffffffff" end

local function Hex(r, g, b)
    return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    return c and { c.r, c.g, c.b }
end

local function ReactionColor(unit)
    if UnitIsPlayer(unit) then return end
    if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then return { 0.6, 0.6, 0.6 } end
    local r = UnitReaction(unit, "player")
    local c = r and FACTION_BAR_COLORS and FACTION_BAR_COLORS[r]
    return c and { c.r, c.g, c.b }
end

---------------------------------------------------------------------------
-- Look: backdrop, border, scale, font
---------------------------------------------------------------------------
local function Paint(tt)
    local s = db()
    if not s.enabled or not tt.tpOrigBackdrop then return end
    tt:SetBackdropColor(s.bg[1], s.bg[2], s.bg[3], s.bg[4])
    local b = tt.tpBorder or s.border
    tt:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local fontObjects = { { "GameTooltipHeaderText", 2 }, { "GameTooltipText", 0 }, { "GameTooltipTextSmall", -2 } }

function Style:ApplyLook()
    local s = db()
    for tt in pairs(tips) do
        if s.enabled then
            tt:SetBackdrop(FLAT)
            tt:SetScale(s.scale or 1)
            Paint(tt)
        elseif tt.tpOrigBackdrop then
            tt:SetBackdrop(tt.tpOrigBackdrop)
            tt:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
                TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
            tt:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
            tt:SetScale(1)
        end
    end
    for _, f in ipairs(fontObjects) do
        local obj = _G[f[1]]
        if obj then
            obj.tpOrig = obj.tpOrig or { obj:GetFont() }
            local o = obj.tpOrig
            if s.enabled and o[1] then
                local face = s.font ~= "default" and s.font or o[1]
                obj:SetFont(face, (s.fontSize or 12) + f[2], o[3])
            elseif o[1] then
                obj:SetFont(o[1], o[2], o[3])
            end
        end
    end
    if self.icon and TP.UI then TP.UI.Backdrop(self.icon, s.bg, s.border) end
end

local function SetBorder(tt, color)
    tt.tpBorder = color
    Paint(tt)
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local follow = CreateFrame("Frame")
follow:Hide()

local SIDE = {   -- tooltip point at the mouse
    BOTTOM = "BOTTOM", TOP = "TOP", LEFT = "BOTTOMLEFT", RIGHT = "BOTTOMRIGHT",
}

local function PlaceAtMouse(tt)
    local s = db()
    local x, y = GetCursorPosition()
    local scale = tt:GetEffectiveScale()
    tt:ClearAllPoints()
    tt:SetPoint(SIDE[s.mouseSide] or "BOTTOM", UIParent, "BOTTOMLEFT", x / scale + (s.mouseX or 0), y / scale + (s.mouseY or 0))
end

follow:SetScript("OnUpdate", function(self)
    local tt = self.tt
    if not tt or not tt:IsShown() or tt:GetOwner() ~= self.owner
        or (tt.GetAnchorType and tt:GetAnchorType() ~= "ANCHOR_NONE") then
        self.tt = nil
        self:Hide()
        return
    end
    PlaceAtMouse(tt)
end)

local mover
local function Mover()
    if mover then return mover end
    local s = db()
    local f = CreateFrame("Frame", "TooltipPlusAnchor", UIParent)
    f:SetWidth(180); f:SetHeight(60)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    if s.fixedX and s.fixedY then
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", s.fixedX, s.fixedY)
    else
        f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -CONTAINER_OFFSET_X - 13, CONTAINER_OFFSET_Y)
    end
    local UI = TP.UI
    if UI then UI.Backdrop(f, { UI.C.accent[1] * 0.35, UI.C.accent[2] * 0.35, UI.C.accent[3] * 0.35, 0.85 }, UI.C.accent) end
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    fs:SetText("Tooltip Plus: anchor point\nDrag it.  Right-click: done")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local us, fs2 = UIParent:GetEffectiveScale(), self:GetEffectiveScale()
        x, y = x * fs2 / us, y * fs2 / us
        db().fixedX, db().fixedY = floor(x + 0.5), floor(y + 0.5)
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db().fixedX, db().fixedY)
        if TP.RefreshOptions then TP:RefreshOptions() end
    end)
    f:SetScript("OnMouseUp", function(self, button) if button == "RightButton" then self:Hide() end end)
    f:Hide()
    mover = f
    return f
end

function Style:ResetMover()
    db().fixedX, db().fixedY = nil, nil
    local f = Mover()
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -CONTAINER_OFFSET_X - 13, CONTAINER_OFFSET_Y)
end

function Style:ToggleMover()
    local f = Mover()
    if f:IsShown() then f:Hide() else f:Show() end
end

local function PlaceFixed(tt)
    local f = Mover()
    local x, y = f:GetCenter()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local point = ((y or 0) * scale > h / 2 and "TOP" or "BOTTOM") .. ((x or 0) * scale > w / 2 and "RIGHT" or "LEFT")
    tt:ClearAllPoints()
    tt:SetPoint(point, f, point)
end

local function DefaultAnchor(tt, parent)
    if tt ~= GameTooltip then return end
    local s = db()
    local world = parent == UIParent and GetMouseFocus() == WorldFrame
    local mode = world and s.anchorWorld or s.anchorFrame
    if mode == "mouse" then
        tt:SetOwner(parent, "ANCHOR_NONE")
        PlaceAtMouse(tt)
        follow.tt, follow.owner = tt, parent
        follow:Show()
    elseif mode == "fixed" then
        follow.tt = nil
        PlaceFixed(tt)
    else
        follow.tt = nil
    end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
local function Short(n)
    if n >= 1e6 then return format("%.1fm", n / 1e6) end
    if n >= 1e4 then return format("%.1fk", n / 1e3) end
    return tostring(n)
end

function Style.NpcID(unit)
    local guid = UnitGUID(unit)
    if not guid or UnitIsPlayer(unit) then return end
    local kind = tonumber(guid:sub(5, 5), 16)
    kind = kind and kind % 8
    if kind == 3 or kind == 5 then return tonumber(guid:sub(7, 12), 16) end   -- creature, vehicle
end

-- talents: inspected players, cached by GUID
local talentCache = {}
Style.talentCache = talentCache

local function SpecText(inspect)
    local group = GetActiveTalentGroup and GetActiveTalentGroup(inspect) or nil
    local best, bestPts, pts = nil, -1, {}
    for i = 1, 3 do
        local name, _, spent = GetTalentTabInfo(i, inspect, nil, group)
        pts[i] = spent or 0
        if name and (spent or 0) > bestPts then best, bestPts = name, spent end
    end
    if not best or bestPts <= 0 then return "|cff9d9d9dNo talents|r" end
    return "|cffffffff" .. best .. "|r |cff9d9d9d(" .. pts[1] .. "/" .. pts[2] .. "/" .. pts[3] .. ")|r"
end

local inspect = CreateFrame("Frame")
inspect:RegisterEvent("INSPECT_TALENT_READY")

local state = { }     -- the unit shown in GameTooltip
Style.state = state

local function TalentLine(unit)
    if UnitIsUnit(unit, "player") then return SpecText(false) end
    local guid = UnitGUID(unit)
    local c = guid and talentCache[guid]
    if c then return c.text end
    if not CheckInteractDistance(unit, 1) then return "|cff9d9d9dcome closer to read them|r" end
    return "|cff9d9d9d...|r"
end

local function WantInspect(unit)
    if not db().talents or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    if (UnitLevel(unit) or 0) < 10 then return end
    local guid = UnitGUID(unit)
    local c = guid and talentCache[guid]
    if c and GetTime() - c.time < 300 then return end
    return true
end

inspect:SetScript("OnUpdate", function(self, elapsed)
    if not self.wait then return end
    self.wait = self.wait - elapsed
    if self.wait > 0 then return end
    self.wait = nil
    local unit = state.unit
    if not unit or not UnitExists(unit) or UnitGUID(unit) ~= self.guid then return end
    if InspectFrame and InspectFrame:IsShown() then return end
    if not CanInspect(unit) or not CheckInteractDistance(unit, 1) then return end
    self.asked, self.askedAt, self.askedUnit = self.guid, GetTime(), unit
    NotifyInspect(unit)
end)

inspect:SetScript("OnEvent", function(self, event)
    if event ~= "INSPECT_TALENT_READY" or not self.asked or GetTime() - (self.askedAt or 0) > 3 then return end
    local unit = self.askedUnit
    if not unit or UnitGUID(unit) ~= self.asked then self.asked = nil return end
    talentCache[self.asked] = { text = SpecText(true), time = GetTime() }
    self.asked = nil
    if state.unit and UnitGUID(state.unit) == UnitGUID(unit) then Style:UpdateLines(true) end
end)

-- bars
local bars = {}
local function Bar(i)
    if bars[i] then return bars[i] end
    local b = CreateFrame("StatusBar", nil, GameTooltip)
    b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    b:SetMinMaxValues(0, 1)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -1, 1); bg:SetPoint("BOTTOMRIGHT", 1, -1)
    bg:SetTexture(0, 0, 0, 0.8)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", 0, 0)
    b:Hide()
    bars[i] = b
    return b
end

local function HideBars() for _, b in pairs(bars) do b:Hide() end end

local function UpdateBars()
    local unit = state.unit
    if not unit or not UnitExists(unit) then return end
    local s = db()
    for i, kind in ipairs(state.bars or {}) do
        local b = bars[i]
        local cur, max
        if kind == "health" then
            cur, max = UnitHealth(unit), UnitHealthMax(unit)
            local col = (UnitIsDead(unit) or UnitIsGhost(unit)) and { 0.5, 0.5, 0.5 }
                or (UnitIsPlayer(unit) and ClassColor(select(2, UnitClass(unit)))) or ReactionColor(unit) or { 0.2, 0.8, 0.2 }
            b:SetStatusBarColor(col[1], col[2], col[3])
        else
            local ptype = UnitPowerType(unit)
            cur, max = UnitPower(unit), UnitPowerMax(unit)
            local col = PowerBarColor and PowerBarColor[ptype] or { r = 0, g = 0.5, b = 1 }
            b:SetStatusBarColor(col.r, col.g, col.b)
        end
        max = (max and max > 0) and max or 1
        b:SetMinMaxValues(0, max)
        b:SetValue(cur or 0)
        if s.barText then
            -- health of mobs outside your group is a percentage on 3.3.5
            if kind == "health" and max == 100 and not UnitIsPlayer(unit)
                and not UnitPlayerOrPetInParty(unit) and not UnitPlayerOrPetInRaid(unit) then
                b.text:SetText((cur or 0) .. "%")
            else
                b.text:SetText(Short(cur or 0) .. " / " .. Short(max) .. "  " .. floor((cur or 0) / max * 100 + 0.5) .. "%")
            end
        else
            b.text:SetText("")
        end
    end
end

-- who in your party / raid targets the unit (the game only tells it for your group)
local MAX_NAMES = 6
function Style.TargetedBy(unit)
    local list = {}
    local raid = GetNumRaidMembers()
    local function check(u)
        if UnitExists(u) and UnitIsUnit(u .. "target", unit) then
            local _, file = UnitClass(u)
            local c = ClassColor(file) or { 1, 1, 1 }
            list[#list + 1] = Hex(c[1], c[2], c[3]) .. (UnitIsUnit(u, "player") and "You" or (UnitName(u) or "?")) .. "|r"
        end
    end
    if raid > 0 then
        for i = 1, raid do check("raid" .. i) end
    else
        check("player")
        for i = 1, GetNumPartyMembers() do check("party" .. i) end
    end
    return list
end

function Style.TargetedByText(unit)
    local list = Style.TargetedBy(unit)
    local head = C("label") .. "Targeted by|r " .. C("value") .. #list .. "|r"
    if #list == 0 then return head end
    local shown = {}
    for i = 1, math.min(#list, MAX_NAMES) do shown[i] = list[i] end
    local more = #list > MAX_NAMES and (" |cff9d9d9d+" .. (#list - MAX_NAMES) .. "|r") or ""
    return head .. ": " .. table.concat(shown, ", ") .. more
end

local function TargetText(unit)
    local t = unit .. "target"
    if not UnitExists(t) then return "|cff9d9d9dnone|r" end
    if UnitIsUnit(t, "player") then return "|cffff3030<< You >>|r" end
    local col = (UnitIsPlayer(t) and ClassColor(select(2, UnitClass(t)))) or ReactionColor(t) or { 1, 1, 1 }
    return Hex(col[1], col[2], col[3]) .. (UnitName(t) or "?") .. "|r"
end

-- read the tooltip lines into a table, change them, write them back
local function ReadLines(tt)
    local name, list = tt:GetName(), {}
    for i = 1, tt:NumLines() do
        local l, r = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        local e = { l = l:GetText(), lc = { l:GetTextColor() } }
        if r and r:IsShown() and r:GetText() then e.r = r:GetText(); e.rc = { r:GetTextColor() } end
        list[#list + 1] = e
    end
    return list
end

local function WriteLines(tt, list)
    local name, old = tt:GetName(), tt:NumLines()
    for i, e in ipairs(list) do
        if i <= old then
            local l, r = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
            l:SetText(e.l or " "); l:SetTextColor(e.lc[1], e.lc[2], e.lc[3]); l:Show()
            if e.r then r:SetText(e.r); r:SetTextColor(e.rc[1], e.rc[2], e.rc[3]); r:Show()
            else r:SetText(nil); r:Hide() end
        elseif e.r then
            tt:AddDoubleLine(e.l or " ", e.r, e.lc[1], e.lc[2], e.lc[3], e.rc[1], e.rc[2], e.rc[3])
        else
            tt:AddLine(e.l or " ", e.lc[1], e.lc[2], e.lc[3])
        end
    end
    for i = #list + 1, old do
        local l, r = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        l:SetText(nil); l:Hide()
        if r then r:SetText(nil); r:Hide() end
    end
end

local CLASSIF = { worldboss = "Boss", rareelite = "Rare Elite", elite = "Elite", rare = "Rare" }
local WHITE = { 1, 1, 1 }

local function LevelText(unit)
    local lvl = UnitLevel(unit) or 0
    local col
    if lvl > 0 then
        local f = GetQuestDifficultyColor or GetDifficultyColor
        local c = f and f(lvl)
        col = c and Hex(c.r, c.g, c.b) or "|cffffffff"
    else
        col = "|cffff3030"
    end
    local text = col .. (LEVEL or "Level") .. " " .. (lvl > 0 and lvl or "??") .. "|r"
    if UnitIsPlayer(unit) then
        local race = UnitRace(unit) or ""
        local class, file = UnitClass(unit)
        local cc = ClassColor(file) or WHITE
        text = text .. " |cffffffff" .. race .. "|r " .. Hex(cc[1], cc[2], cc[3]) .. (class or "") .. "|r"
    else
        local cl = CLASSIF[UnitClassification(unit) or ""]
        if cl then text = text .. " |cffffd100" .. cl .. "|r" end
        local ctype = UnitCreatureType(unit)
        if ctype and ctype ~= "" and ctype ~= "Not specified" then text = text .. " |cffffffff" .. ctype .. "|r" end
    end
    return text
end

local function OnSetUnit(tt)
    if tt ~= GameTooltip then return end
    local s = db()
    local _, unit = tt:GetUnit()
    if not unit and UnitExists("mouseover") then unit = "mouseover" end
    HideBars()
    state.unit, state.bars, state.targetLine, state.talentLine, state.byLine = nil, nil, nil, nil, nil
    if not unit then return end
    state.unit = unit
    local isPlayer = UnitIsPlayer(unit)
    local list = ReadLines(tt)
    local out = {}

    local guild, rank = GetGuildInfo(unit)
    for i, e in ipairs(list) do
        local t = e.l or ""
        local keep = true
        if i == 1 then
            if isPlayer and s.classNames then
                local cc = ClassColor(select(2, UnitClass(unit)))
                if cc then e.lc = cc end
            end
            if isPlayer and s.tags then
                if UnitIsAFK(unit) then e.l = t .. " |cffff9900<AFK>|r"
                elseif UnitIsDND(unit) then e.l = t .. " |cffff3030<DND>|r" end
            end
        elseif isPlayer and guild and s.guildRank and (t == guild or t == "<" .. guild .. ">") then
            local mine = GetGuildInfo("player") == guild
            e.l = (mine and "|cff40ff40" or "|cff8fc7ff") .. "<" .. guild .. ">|r" .. (rank and (" |cff9d9d9d" .. rank .. "|r") or "")
        elseif s.levelLine and LEVEL and t:find("^" .. LEVEL) then
            e.l = LevelText(unit)
        elseif s.hideFaction and (t == FACTION_ALLIANCE or t == FACTION_HORDE or t == PVP) then
            keep = false
        end
        if keep then out[#out + 1] = e end
    end

    local function add(left, right)
        out[#out + 1] = { l = left, lc = WHITE, r = right, rc = WHITE }
        return #out
    end
    if s.target then state.targetLine = add(C("label") .. "Target:|r " .. TargetText(unit)) end
    if s.targetedBy and (GetNumRaidMembers() > 0 or GetNumPartyMembers() > 0) then
        state.byLine = add(Style.TargetedByText(unit))
    else
        state.byLine = nil
    end
    if s.talents and isPlayer and (UnitLevel(unit) or 0) >= 10 then
        state.talentLine = add(C("label") .. "Talents:|r " .. TalentLine(unit))
        -- unit frames redraw their tooltip every 0.2 s: only start the wait once per player
        local guid = UnitGUID(unit)
        if WantInspect(unit) and inspect.guid ~= guid then inspect.guid = guid; inspect.wait = 0.25 end
    end
    if s.npcID then
        local id = Style.NpcID(unit)
        if id then add(C("label") .. "NPC ID|r " .. C("value") .. id .. "|r") end
    end
    local barKinds = {}
    if s.healthBar then barKinds[#barKinds + 1] = "health" end
    if s.powerBar and (UnitPowerMax(unit) or 0) > 0 then barKinds[#barKinds + 1] = "power" end
    local barLines = {}
    for _, k in ipairs(barKinds) do barLines[#barLines + 1] = add("                                        ") end

    WriteLines(tt, out)
    state.bars = barKinds
    local name = tt:GetName()
    for i, idx in ipairs(barLines) do
        local fs = _G[name .. "TextLeft" .. idx]
        local b = Bar(i)
        local _, size = fs:GetFont()
        b:ClearAllPoints()
        b:SetPoint("LEFT", fs, "LEFT", 0, 0)
        b:SetPoint("RIGHT", tt, "RIGHT", -10, 0)
        b:SetHeight((size or 12) + 1)
        b:Show()
    end
    UpdateBars()

    if s.unitBorder then
        SetBorder(tt, (isPlayer and ClassColor(select(2, UnitClass(unit)))) or ReactionColor(unit))
    end
    tt:Show()
end

-- refresh the target / talent lines (and the bars) while the tooltip is up
function Style:UpdateLines(force)
    local tt, unit = GameTooltip, state.unit
    if not unit or not tt:IsShown() or not UnitExists(unit) then return end
    local changed
    local name = tt:GetName()
    if state.targetLine then
        local fs = _G[name .. "TextLeft" .. state.targetLine]
        local t = C("label") .. "Target:|r " .. TargetText(unit)
        if fs and fs:GetText() ~= t then fs:SetText(t); changed = true end
    end
    if state.byLine then
        local fs = _G[name .. "TextLeft" .. state.byLine]
        local t = Style.TargetedByText(unit)
        if fs and fs:GetText() ~= t then fs:SetText(t); changed = true end
    end
    if state.talentLine then
        local fs = _G[name .. "TextLeft" .. state.talentLine]
        local t = C("label") .. "Talents:|r " .. TalentLine(unit)
        if fs and fs:GetText() ~= t then fs:SetText(t); changed = true end
    end
    if changed or force then tt:Show() end
end

local ticker = CreateFrame("Frame")
local acc = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    if state.unit and GameTooltip:IsShown() then
        UpdateBars()
        Style:UpdateLines()
    end
end)

---------------------------------------------------------------------------
-- Items and links
---------------------------------------------------------------------------
local function OnSetItem(tt)
    local s = db()
    local _, link = tt:GetItem()
    if not link then return end
    local _, _, quality, ilvl = GetItemInfo(link)
    if s.qualityBorder and quality and quality >= 2 and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        SetBorder(tt, { c.r, c.g, c.b })
    end
    -- item level, unless the tooltip already has one (from the server or another addon)
    local has
    for i = 2, tt:NumLines() do
        local fs = _G[tt:GetName() .. "TextLeft" .. i]
        local t = fs and fs:GetText()
        if t and t:gsub("|c%x%x%x%x%x%x%x%x", ""):lower():find("^item ?level:? ?%d") then has = true break end
    end
    if s.itemLevel and not has and not tt.tpIlvl and ilvl and ilvl > 1 and IsEquippableItem(link) then
        tt.tpIlvl = true
        tt:AddLine(C("label") .. "Item level|r " .. C("value") .. ilvl .. "|r")
        tt:Show()
    end
    if TP.Stats then TP.Stats:OnItem(tt, link) end
end

local function OnSetSpell(tt)
    if not db().linkIDs or tt.tpSpell then return end
    local _, _, id = tt:GetSpell()
    if not id then return end
    tt.tpSpell = true
    tt:AddLine(C("label") .. "Spell ID|r " .. C("value") .. id .. "|r")
    tt:Show()
end

local function LinkIcon(link)
    local id = tonumber(link:match("item:(%d+)") or "")
    if id then return GetItemIcon(id) end
    id = tonumber(link:match("spell:(%d+)") or link:match("enchant:(%d+)") or "")
    if id then return (select(3, GetSpellInfo(id))) end
    id = tonumber(link:match("achievement:(%d+)") or "")
    if id and GetAchievementInfo then return (select(10, GetAchievementInfo(id))) end
end

local function OnHyperlink(tt, link)
    if type(link) ~= "string" then return end
    local s = db()
    if s.linkIDs then
        local a = tonumber(link:match("achievement:(%d+)") or "")
        local q, ql = link:match("quest:(%d+):?(%-?%d*)")
        if a then
            tt:AddLine(C("label") .. "Achievement ID|r " .. C("value") .. a .. "|r")
            tt:Show()
        elseif q then
            ql = tonumber(ql)
            tt:AddLine(C("label") .. "Quest ID|r " .. C("value") .. q .. "|r" ..
                ((ql and ql > 0) and ("   " .. C("label") .. "Level|r " .. C("value") .. ql .. "|r") or ""))
            tt:Show()
        end
    end
    if tt == ItemRefTooltip and Style.icon then
        local tex = s.linkIcon and LinkIcon(link)
        if tex then
            Style.icon.tex:SetTexture(tex)
            Style.icon:Show()
        else
            Style.icon:Hide()
        end
    end
end

local function MakeIcon()
    local f = CreateFrame("Frame", nil, ItemRefTooltip)
    f:SetWidth(38); f:SetHeight(38)
    f:SetPoint("TOPRIGHT", ItemRefTooltip, "TOPLEFT", -2, 0)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 1, -1); t:SetPoint("BOTTOMRIGHT", -1, 1)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.tex = t
    f:Hide()
    Style.icon = f
end

---------------------------------------------------------------------------
-- Init (called by Tooltip Plus when its saved settings are loaded)
---------------------------------------------------------------------------
function TP:InitStyle()
    TP.db.style = TP.db.style or {}
    for k, v in pairs(Style.DEFAULTS) do
        if TP.db.style[k] == nil then
            if type(v) == "table" then
                local c = {}
                for i, x in ipairs(v) do c[i] = x end
                TP.db.style[k] = c
            else
                TP.db.style[k] = v
            end
        end
    end
    MakeIcon()
    for _, n in ipairs(LOOK_TIPS) do
        local tt = _G[n]
        if tt and tt.SetBackdrop then
            tips[tt] = true
            tt.tpOrigBackdrop = tt:GetBackdrop()
            tt:HookScript("OnShow", Paint)
            tt:HookScript("OnTooltipCleared", function(self)
                self.tpBorder, self.tpIlvl, self.tpSpell, self.tpStats = nil, nil, nil, nil
                if self == GameTooltip then HideBars(); state.unit = nil end
                Paint(self)
            end)
            if tt:HasScript("OnTooltipSetItem") then tt:HookScript("OnTooltipSetItem", OnSetItem) end
            if tt:HasScript("OnTooltipSetSpell") then tt:HookScript("OnTooltipSetSpell", OnSetSpell) end
        end
    end
    GameTooltip:HookScript("OnTooltipSetUnit", OnSetUnit)
    GameTooltip:HookScript("OnHide", function() HideBars(); state.unit = nil; inspect.guid = nil end)
    ItemRefTooltip:HookScript("OnHide", function() if Style.icon then Style.icon:Hide() end end)
    hooksecurefunc(GameTooltip, "SetHyperlink", OnHyperlink)
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", OnHyperlink)
    hooksecurefunc("GameTooltip_SetDefaultAnchor", DefaultAnchor)
    -- the game's own health bar under the tooltip, when the bars are on
    if GameTooltipStatusBar then
        GameTooltipStatusBar:HookScript("OnShow", function(self) if db().healthBar then self:Hide() end end)
    end
    Style:ApplyLook()
end

