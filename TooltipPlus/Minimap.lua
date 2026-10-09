--[[
    Tooltip Plus - minimap button
    Author: Saranwrap

    Left-click: recipe browser   Right-click: settings   Drag: move around the minimap
]]

local TP = TooltipPlus

local function Place(b)
    local a = math.rad(TP.db.minimapAngle or 200)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end

function TP:InitMinimap()
    local b = CreateFrame("Button", "TooltipPlusMinimapButton", Minimap)
    b:SetWidth(31); b:SetHeight(31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetWidth(20); bg:SetHeight(20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("TOPLEFT", 6, -5)
    icon:SetTexture(TP.ICON)
    b.icon = icon
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetWidth(53); border:SetHeight(53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then TP:ToggleOptions()
        elseif IsShiftKeyDown() then TP:ToggleItems()
        else TP:ToggleRecipes() end
    end)
    b:SetScript("OnMouseDown", function() icon:SetPoint("TOPLEFT", 7, -6) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("TOPLEFT", 6, -5) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(TP.NAME, 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Left-click|r recipes", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd100Shift-click|r items of your characters", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd100Right-click|r settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffffd100Drag|r move the button", 0.8, 0.8, 0.8)
        TP:AddGoldLines(GameTooltip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    b:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            TP.db.minimapAngle = math.deg(math.atan2(y / s - my, x / s - mx))
            Place(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    self.minimapButton = b
    Place(b)
    self:UpdateMinimap()
end

function TP:UpdateMinimap()
    local b = self.minimapButton
    if not b then return end
    if self.db.minimap then b:Show() else b:Hide() end
end
