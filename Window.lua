--[[
    Tooltip Plus - main window (Recipes, Items and Settings pages) and the shared flat style
    Author: Saranwrap
]]

local TP = TooltipPlus
local UI = {}
TP.UI = UI

local W, H = 820, 580
UI.W, UI.H = W, H

-- flat dark style: dark backdrop, black borders, orange accent
local C = {
    bg     = { 0.06, 0.06, 0.06, 0.92 },
    panel  = { 0.10, 0.10, 0.10, 1 },
    border = { 0, 0, 0, 1 },
    button = { 0.10, 0.10, 0.10, 1 },
    accent = { 0.99, 0.48, 0.17, 1 },
    danger = { 0.90, 0.30, 0.30, 1 },
    title  = { 0.10, 0.10, 0.10, 1 },
}
C.sel = { C.accent[1] * 0.45, C.accent[2] * 0.45, C.accent[3] * 0.45, 1 }
UI.C = C
UI.ACCENT = string.format("|cff%02x%02x%02x", C.accent[1] * 255, C.accent[2] * 255, C.accent[3] * 255)

function UI.Backdrop(f, bg, border)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

function UI.FlatButton(parent, label, w, h, danger)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w); b:SetHeight(h)
    UI.Backdrop(b, C.button)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(label)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(danger and C.danger or C.accent)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(C.border)) end)
    return b
end

---------------------------------------------------------------------------
-- Main window: title bar + pages
---------------------------------------------------------------------------
local Main = { pages = {} }
TP.Main = Main

function Main:Create()
    local f = CreateFrame("Frame", "TooltipPlusMain", UIParent)
    f:SetWidth(W); f:SetHeight(H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.Backdrop(f, C.bg)
    f:Hide()
    tinsert(UISpecialFrames, "TooltipPlusMain")
    self.frame = f

    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1); bar:SetHeight(30)
    local bg = bar:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture(unpack(C.title))
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    line:SetTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
    local logo = bar:CreateTexture(nil, "ARTWORK")
    logo:SetWidth(22); logo:SetHeight(22)
    logo:SetPoint("LEFT", 6, 0)
    logo:SetTexture(TP.ICON)
    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0); title:SetTextColor(1, 1, 1)
    title:SetText(TP.NAME)
    local by = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    by:SetPoint("LEFT", title, "RIGHT", 8, -1); by:SetText("v" .. TP.VERSION .. "  -  by " .. TP.AUTHOR)
    local close = UI.FlatButton(bar, "X", 22, 20, true)
    close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    local settings = UI.FlatButton(bar, "Settings", 90, 20)
    settings:SetPoint("RIGHT", close, "LEFT", -6, 0)
    settings:SetScript("OnClick", function()
        Main:Show(Main.current == "settings" and (Main.last or "recipes") or "settings")
    end)
    self.settingsBtn = settings
    -- page tabs: Recipes | Items
    self.tabs = {}
    local prev
    for _, t in ipairs({ { "items", "Items" }, { "recipes", "Recipes" } }) do
        local b = UI.FlatButton(bar, t[2], 80, 20)
        b:SetPoint("RIGHT", prev or settings, "LEFT", -6, 0)
        b:SetScript("OnClick", function() Main:Show(t[1]) end)
        self.tabs[t[1]] = b
        prev = b
    end

    for _, key in ipairs({ "recipes", "items", "settings" }) do
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 0, -31)
        p:SetPoint("BOTTOMRIGHT", 0, 0)
        p:Hide()
        self.pages[key] = p
    end
    -- each page on its own: a page that fails to build does not take the others with it
    -- (a file added in an update is only loaded after the game is restarted, not after /reload)
    local builds = {
        { "recipes",  TP.Recipes and function(p) TP.Recipes:Build(p) end },
        { "items",    TP.Items and function(p) TP.Items:Build(p) end },
        { "settings", TP.BuildSettings and function(p) TP:BuildSettings(p) end },
    }
    for _, b in ipairs(builds) do
        local ok, err = false, "file not loaded"
        if b[2] then ok, err = pcall(b[2], self.pages[b[1]]) end
        if not ok then
            self.broken = self.broken or {}
            self.broken[b[1]] = true
            TP:Print("could not open the " .. b[1] .. " page (" .. tostring(err) .. "). " ..
                "If you just updated the addon, close the game completely and start it again.")
        end
    end
end

-- key: "recipes", "items" or "settings"
function Main:Show(key)
    if not self.frame then self:Create() end
    key = key or self.last or "recipes"
    for k, p in pairs(self.pages) do
        if k == key then p:Show() else p:Hide() end
    end
    self.current = key
    if key ~= "settings" then self.last = key end
    for k, b in pairs(self.tabs) do b:SetBackdropColor(unpack(k == key and C.sel or C.button)) end
    self.settingsBtn:SetText(key == "settings" and "Back" or "Settings")
    self.settingsBtn:SetBackdropColor(unpack(key == "settings" and C.sel or C.button))
    self.frame:Show()
end

function Main:Toggle(key)
    key = key or "recipes"
    if self.frame and self.frame:IsShown() and self.current == key then
        self.frame:Hide()
    else
        self:Show(key)
    end
end

function TP:ToggleRecipes() Main:Toggle("recipes") end
function TP:ToggleItems() Main:Toggle("items") end
function TP:ToggleOptions() Main:Toggle("settings") end
function TP:ShowOptions() Main:Show("settings") end
