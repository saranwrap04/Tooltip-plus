--[[
    Tooltip Plus - flat widgets: check boxes, drop-downs, sliders, colour swatches,
    section headings and side-bar buttons
    Author: Saranwrap
]]

local TP = TooltipPlus
local UI = TP.UI
local C = UI.C
local floor, format, max, min = math.floor, string.format, math.max, math.min

local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow"

local function Tip(frame, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.Tip = Tip

local function Inset(f, bg)
    f:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(unpack(bg or C.input))
    f:SetBackdropBorderColor(unpack(C.border))
end

-- gold label above a control
local function TopLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    return fs
end

---------------------------------------------------------------------------
-- Check box: dark square, filled with the accent colour when ticked
---------------------------------------------------------------------------
function UI.Check(parent, label, get, set, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    local box = CreateFrame("Frame", nil, b)
    box:SetWidth(16); box:SetHeight(16)
    box:SetPoint("LEFT", 0, 0)
    Inset(box)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 2, -2); fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(label)
    b:SetWidth(24 + fs:GetStringWidth() + 4)
    b.refresh = function()
        local on = get() and true or false
        if on then fill:Show() else fill:Hide() end
        b.enabled = b.enabledFunc == nil or b.enabledFunc()
        fs:SetTextColor(b.enabled and 1 or 0.5, b.enabled and 1 or 0.5, b.enabled and 1 or 0.5)
    end
    b:SetScript("OnClick", function()
        if b.enabled == false then return end
        set(not get())
        b.refresh()
        if b.changed then b.changed() end
    end)
    b:SetScript("OnEnter", function() box:SetBackdropBorderColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function() box:SetBackdropBorderColor(unpack(C.border)) end)
    Tip(b, tip)
    b.label = fs
    return b
end

---------------------------------------------------------------------------
-- Drop-down: label above, dark box, the choice and a gold arrow on the right
-- getOptions() -> { { value, label }, ... }
---------------------------------------------------------------------------
local openMenu
local catcher = CreateFrame("Button", nil, UIParent)
catcher:SetAllPoints(UIParent)
catcher:SetFrameStrata("FULLSCREEN")
catcher:RegisterForClicks("AnyUp")
catcher:Hide()
catcher:SetScript("OnClick", function() if openMenu then openMenu:Hide() end end)

local function MenuFrame()
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    Inset(menu, C.panel)
    menu:SetBackdropBorderColor(unpack(C.border))
    menu:Hide()
    menu.buttons = {}
    menu:SetScript("OnHide", function(self)
        if openMenu == self then openMenu = nil; catcher:Hide() end
    end)
    return menu
end

function UI.Dropdown(parent, w, getOptions, get, set, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(22)
    Inset(b)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -26, 0)
    fs:SetJustifyH("RIGHT")
    b:SetFontString(fs)
    local ab = CreateFrame("Frame", nil, b)
    ab:SetWidth(20); ab:SetHeight(20)
    ab:SetPoint("RIGHT", -1, 0)
    Inset(ab, C.button)
    local arrow = ab:CreateTexture(nil, "OVERLAY")
    arrow:SetWidth(14); arrow:SetHeight(14)
    arrow:SetPoint("CENTER", 0, 0)
    arrow:SetTexture(ARROW)
    arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)       -- turned to point down
    arrow:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    if label then
        b.title = TopLabel(b, label)
        b.title:SetPoint("BOTTOMLEFT", b, "TOPLEFT", 2, 3)
    end
    local menu = MenuFrame()

    function b:Refresh()
        for _, o in ipairs(getOptions()) do
            if o[1] == get() then self:SetText(o[2]) return end
        end
        self:SetText("")
    end
    b.refresh = function() b:Refresh() end

    b:SetScript("OnClick", function(self)
        if menu:IsShown() then menu:Hide() return end
        if openMenu then openMenu:Hide() end
        local opts = getOptions()
        for i, o in ipairs(opts) do
            local mb = menu.buttons[i]
            if not mb then
                mb = CreateFrame("Button", nil, menu)
                mb:SetHeight(20)
                mb:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 20)
                mb:SetPoint("RIGHT", -2, 0)
                local hl = mb:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetTexture(WHITE8)
                hl:SetGradientAlpha("HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.45,
                    C.accent[1], C.accent[2], C.accent[3], 0)
                local mark = mb:CreateTexture(nil, "ARTWORK")
                mark:SetWidth(6); mark:SetHeight(6)
                mark:SetPoint("LEFT", 6, 0)
                mark:SetTexture(C.accent[1], C.accent[2], C.accent[3], 1)
                mb.mark = mark
                local t = mb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                t:SetPoint("LEFT", 18, 0)
                t:SetPoint("RIGHT", -6, 0)
                t:SetJustifyH("LEFT")
                mb:SetFontString(t)
                menu.buttons[i] = mb
            end
            local cur = o[1] == get()
            mb:SetText(o[2])
            mb:GetFontString():SetTextColor(cur and C.accent[1] or 1, cur and C.accent[2] or 1, cur and C.accent[3] or 1)
            if cur then mb.mark:Show() else mb.mark:Hide() end
            mb:SetScript("OnClick", function()
                menu:Hide()
                set(o[1])
                b:Refresh()
                if b.changed then b.changed() end
            end)
            mb:Show()
        end
        for i = #opts + 1, #menu.buttons do menu.buttons[i]:Hide() end
        menu:SetWidth(max(w, 140))
        menu:SetHeight(#opts * 20 + 4)
        menu:ClearAllPoints()
        menu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
        catcher:Show()
        menu:Show()
        openMenu = menu
    end)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    b:SetScript("OnHide", function() menu:Hide() end)
    return b
end

---------------------------------------------------------------------------
-- Slider: label above, bar with a gold thumb, min / value box / max below
---------------------------------------------------------------------------
local sliders = 0
function UI.Slider(parent, label, w, lo, hi, step, get, set, fmt)
    sliders = sliders + 1
    fmt = fmt or "%d"
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(w); f:SetHeight(50)
    local title = TopLabel(f, label)
    title:SetPoint("TOP", 0, 0)
    local s = CreateFrame("Slider", "TooltipPlusSlider" .. sliders, f)
    s:SetOrientation("HORIZONTAL")
    s:SetHeight(10)
    s:SetPoint("TOPLEFT", 0, -16)
    s:SetPoint("TOPRIGHT", 0, -16)
    Inset(s)
    local th = s:CreateTexture(nil, "OVERLAY")
    th:SetTexture(WHITE8)
    th:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    th:SetWidth(10); th:SetHeight(12)
    s:SetThumbTexture(th)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    local lof = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lof:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, -6)
    lof:SetText(format(fmt, lo))
    local hif = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hif:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, -6)
    hif:SetText(format(fmt, hi))
    local box = CreateFrame("EditBox", nil, f)
    box:SetWidth(70); box:SetHeight(18)
    box:SetPoint("TOP", s, "BOTTOM", 0, -3)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetJustifyH("CENTER")
    Inset(box)

    local function round(v) return floor(v / step + 0.5) * step end
    local function show(v) box:SetText(format(fmt, v)) end
    f.refresh = function()
        f.busy = true
        local v = get() or lo
        s:SetValue(v)
        show(v)
        f.busy = nil
    end
    local function apply(v)
        v = round(max(lo, min(hi, v)))
        set(v)
        show(v)
        if f.changed then f.changed() end
    end
    s:SetScript("OnValueChanged", function(_, v)
        if f.busy then return end
        apply(v)
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d) self:SetValue(self:GetValue() + d * step) end)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then f.busy = true; s:SetValue(round(max(lo, min(hi, v)))); f.busy = nil; apply(v) end
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f.refresh() end)
    box:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    return f
end

---------------------------------------------------------------------------
-- Colour swatch: square with the colour, label on the right
---------------------------------------------------------------------------
function UI.Swatch(parent, label, get, alpha, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    local box = CreateFrame("Frame", nil, b)
    box:SetWidth(16); box:SetHeight(16)
    box:SetPoint("LEFT", 0, 0)
    Inset(box, { 1, 1, 1, 1 })
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
    fs:SetText(label)
    b:SetWidth(24 + fs:GetStringWidth() + 4)
    b.refresh = function()
        local c = get()
        box:SetBackdropColor(c[1], c[2], c[3], 1)
    end
    b:SetScript("OnClick", function()
        local c = get()
        local prev = { c[1], c[2], c[3], c[4] }
        local function apply()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            c[1], c[2], c[3] = r, g, bl
            if alpha then c[4] = 1 - OpacitySliderFrame:GetValue() end
            b.refresh()
            if onChange then onChange() end
        end
        ColorPickerFrame.func = apply
        ColorPickerFrame.opacityFunc = apply
        ColorPickerFrame.hasOpacity = alpha and true or false
        ColorPickerFrame.opacity = alpha and (1 - (c[4] or 1)) or 0
        ColorPickerFrame.previousValues = prev
        ColorPickerFrame.cancelFunc = function()
            c[1], c[2], c[3], c[4] = prev[1], prev[2], prev[3], prev[4]
            b.refresh()
            if onChange then onChange() end
        end
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)
    b:SetScript("OnEnter", function() box:SetBackdropBorderColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function() box:SetBackdropBorderColor(unpack(C.border)) end)
    return b
end

---------------------------------------------------------------------------
-- Section heading: gold title in the middle of a thin line
---------------------------------------------------------------------------
function UI.Section(parent, text, w)
    local f = CreateFrame("Frame", nil, parent)
    f:SetWidth(w); f:SetHeight(16)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetTexture(C.line[1], C.line[2], C.line[3], C.line[4])
        if side == "LEFT" then
            line:SetPoint("LEFT", 0, 0); line:SetPoint("RIGHT", fs, "LEFT", -8, 0)
        else
            line:SetPoint("RIGHT", 0, 0); line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        end
    end
    f.text = fs
    return f
end

---------------------------------------------------------------------------
-- Side-bar entry: gold text, the selected one with a gold glow fading right
---------------------------------------------------------------------------
function UI.SideButton(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(22)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetAllPoints()
    glow:SetTexture(WHITE8)
    glow:SetGradientAlpha("HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.55,
        C.accent[1], C.accent[2], C.accent[3], 0)
    glow:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(WHITE8)
    hl:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.12, 1, 1, 1, 0)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", 10, 0)
    fs:SetJustifyH("LEFT")
    b:SetFontString(fs)
    b:SetText(label)
    function b:SetSelected(on)
        if on then glow:Show(); fs:SetTextColor(1, 1, 1) else glow:Hide(); fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3]) end
    end
    b:SetSelected(false)
    return b
end
