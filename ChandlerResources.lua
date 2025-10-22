-- ChandlerResources v1.8
-- Smooth primary bar, circular secondary orbs, pink frame background

local addonName = "ChandlerResources"
local PRIMARY_LERP_SPEED = 5
local ORB_SIZE = 22
local ORB_SPACING = 6
local MAX_ORBS = 6 -- max secondary resource orbs

local ICONS = {
    mana = "Interface\\Icons\\inv_misc_gem_sapphire_02",
    rage = "Interface\\Icons\\ability_warrior_innerrage",
    energy = "Interface\\Icons\\ability_rogue_sprint",
    runic = "Interface\\Icons\\inv_sword_62",
    holy = "Interface\\Icons\\spell_holy_magicalsentry",
    shards = "Interface\\Icons\\spell_shadow_soulgem",
    chi = "Interface\\Icons\\ability_monk_chiexplosion",
    insanity = "Interface\\Icons\\spell_priest_voidtendrils",
    arcane = "Interface\\Icons\\spell_arcane_arcane03",
    combo = "Interface\\Icons\\inv_weapon_shortblade_38",
    essence = "Interface\\Icons\\ability_evoker_essenceburst",
    rune = "Interface\\Icons\\spell_deathknight_frozenruneweapon",
}

-- FRAME SETUP
local frame = CreateFrame("Frame", addonName.."Frame", UIParent, "BackdropTemplate")
frame:SetSize(300, 150)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Pink frame background
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
})
frame:SetBackdropColor(1, 0.4, 0.7, 0.38)

-- Title
local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", frame, "TOP", 0, -6)
title:SetText("Chandler Resources")

-- PRIMARY BAR
local bgBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
bgBar:SetSize(248, 22)
bgBar:SetPoint("TOP", title, "BOTTOM", 0, -10)
bgBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 8, edgeSize = 1,
})
bgBar:SetBackdropColor(0.06,0.06,0.06,1)
bgBar:SetBackdropBorderColor(0,0,0,1)

local primaryBar = CreateFrame("StatusBar", nil, bgBar)
primaryBar:SetSize(246, 20)
primaryBar:SetPoint("CENTER", bgBar, "CENTER", 0,0)
primaryBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
primaryBar:GetStatusBarTexture():SetHorizTile(false)
primaryBar:SetMinMaxValues(0,1)
primaryBar.currentDisplay = 0
primaryBar.targetValue = 0
primaryBar.lastMax = 1

local primaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
primaryText:SetPoint("TOP", bgBar, "BOTTOM", 0, -6)

-- ORB CONTAINER
local orbContainer = CreateFrame("Frame", nil, frame)
orbContainer:SetHeight(ORB_SIZE)
orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)

local secondaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secondaryText:SetPoint("TOP", orbContainer, "BOTTOM", 0, -6)

-- CREATE CIRCULAR ORBS
local orbs = {}
for i=1,MAX_ORBS do
    local orb = CreateFrame("Frame", nil, orbContainer, "BackdropTemplate")
    orb:SetSize(ORB_SIZE, ORB_SIZE)
    orb:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 1,
    })
    orb:SetBackdropColor(0.12,0.12,0.12,0.55)
    orb:SetBackdropBorderColor(0,0,0,1)

    local icon = orb:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(orb)
    icon:SetTexCoord(0.08,0.92,0.08,0.92)
    orb.icon = icon

    local glow = orb:CreateTexture(nil,"BORDER")
    glow:SetSize(ORB_SIZE+8, ORB_SIZE+8)
    glow:SetPoint("CENTER", orb, "CENTER", 0, 0)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:Hide()
    orb.glow = glow

    orbs[i] = orb
end

local function LayoutOrbs(count)
    if count<1 then count=1 end
    local width = count*ORB_SIZE + (count-1)*ORB_SPACING
    orbContainer:SetWidth(width)
    for i=1,count do
        local o = orbs[i]
        o:ClearAllPoints()
        if i==1 then
            o:SetPoint("LEFT", orbContainer, "LEFT", 0,0)
        else
            o:SetPoint("LEFT", orbs[i-1], "RIGHT", ORB_SPACING,0)
        end
    end
end

-- PRIMARY BAR UPDATE
local function UpdatePrimaryBar()
    local powerType = UnitPowerType("player")
    local cur = UnitPower("player", powerType) or 0
    local max = UnitPowerMax("player", powerType) or 1
    primaryBar.lastMax = max
    primaryBar.targetValue = cur
    primaryBar:SetMinMaxValues(0,max)
    primaryBar:SetStatusBarColor(0.3,0.6,1) -- blue for all
    primaryText:SetText(cur.." / "..max)
end

-- SECONDARY ORBS UPDATE (example: combo points, chi, runes)
local function UpdateSecondaryOrbs()
    local _, classToken = UnitClass("player")
    local count = 0
    if classToken=="MONK" then
        count = UnitPower("player", Enum.PowerType.Chi)
    elseif classToken=="ROGUE" or classToken=="DRUID" then
        count = UnitPower("player", Enum.PowerType.ComboPoints)
    elseif classToken=="DEATHKNIGHT" then
        count = 6 -- DK runes, simplified
    end
    secondaryText:SetText(count.." / "..MAX_ORBS)
    LayoutOrbs(MAX_ORBS)
    for i=1,MAX_ORBS do
        local orb = orbs[i]
        orb:Show()
        orb.icon:SetTexture(ICONS.combo) -- default icon, can customize per class
        orb.icon:SetDesaturated(i>count)
        orb.glow:SetShown(i<=count)
    end
end

-- SMOOTH PRIMARY BAR ANIMATION
frame:SetScript("OnUpdate", function(self, elapsed)
    local display = primaryBar.currentDisplay
    local target = primaryBar.targetValue
    local step = (target - display) * math.min(elapsed*PRIMARY_LERP_SPEED,1)
    primaryBar.currentDisplay = display + step
    primaryBar:SetValue(primaryBar.currentDisplay)
end)

-- EVENTS
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_POWER_FREQUENT")
frame:SetScript("OnEvent", function(self, event, arg1)
    UpdatePrimaryBar()
    UpdateSecondaryOrbs()
end)
