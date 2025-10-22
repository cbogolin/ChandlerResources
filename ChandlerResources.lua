-- ChandlerResources.lua v1.6 corrected
-- Smooth primary bar animation fixed
-- Full features from v1.5 retained

local addonName = "ChandlerResources"

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local PRIMARY_LERP_SPEED = 5      -- smoother speed for primary bar
local ORB_SIZE = 22
local ORB_SPACING = 6
local MAX_ORBS = 10

------------------------------------------------------------
-- FRAME CREATION
------------------------------------------------------------
local frame = CreateFrame("Frame", addonName.."Frame", UIParent, "BackdropTemplate")
frame:SetSize(300, 150)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, relPoint, xOfs, yOfs = self:GetPoint()
  ChandlerResourcesDB.position = {point, relPoint, xOfs, yOfs}
end)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", frame, "TOP", 0, -6)
title:SetText("Chandler Resources")

------------------------------------------------------------
-- CLASS TINT
------------------------------------------------------------
local function UpdateClassTint()
  local _, classToken = UnitClass("player")
  local colorObj = nil
  if classToken then
    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] then
      colorObj = CUSTOM_CLASS_COLORS[classToken]
    elseif RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
      colorObj = RAID_CLASS_COLORS[classToken]
    end
  end
  if colorObj then
    local r, g, b = colorObj.r * 0.35, colorObj.g * 0.35, colorObj.b * 0.35
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
    })
    frame:SetBackdropColor(r, g, b, 0.38)
  else
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)
  end
end

------------------------------------------------------------
-- PRIMARY BAR
------------------------------------------------------------
local bgBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
bgBar:SetSize(248, 22)
bgBar:SetPoint("TOP", title, "BOTTOM", 0, -10)
bgBar:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  tile = true, tileSize = 8, edgeSize = 1,
})
bgBar:SetBackdropColor(0.06, 0.06, 0.06, 1)
bgBar:SetBackdropBorderColor(0, 0, 0, 1)

local primaryBar = CreateFrame("StatusBar", addonName.."PrimaryBar", bgBar)
primaryBar:SetSize(246, 20)
primaryBar:SetPoint("CENTER", bgBar, "CENTER", 0, 0)
primaryBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
primaryBar:GetStatusBarTexture():SetHorizTile(false)
primaryBar:SetMinMaxValues(0, 1)
local primaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
primaryText:SetPoint("TOP", bgBar, "BOTTOM", 0, -6)

-- smoother interpolation logic
primaryBar.currentDisplay = 0
primaryBar.targetValue = 0
primaryBar.lastMax = 1

------------------------------------------------------------
-- ORB CONTAINER
------------------------------------------------------------
local orbContainer = CreateFrame("Frame", addonName.."OrbContainer", frame)
orbContainer:SetHeight(ORB_SIZE)
orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)
local secondaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secondaryText:SetPoint("TOP", orbContainer, "BOTTOM", 0, -6)
local orbs = {}

local ICONS = {
  mana = "Interface\\Icons\\inv_misc_gem_sapphire_02",
  rage = "Interface\\Icons\\ability_warrior_innerrage",
  energy = "Interface\\Icons\\ability_rogue_sprint",
  runic = "Interface\\Icons\\inv_sword_62",
  holy = "Interface\\Icons\\spell_holy_magicalsentry",
  shards = "Interface\\Icons\\spell_shadow_soulgem",
  chi = "Interface\\Icons\\ability_monk_chiexplosion",
  insanity = "Interface\\Icons\\spell_priest_voidtendrils",
  maelstrom = "Interface\\Icons\\spell_nature_stormreach",
  arcane = "Interface\\Icons\\spell_arcane_arcane03",
  combo = "Interface\\Icons\\inv_weapon_shortblade_38",
  essence = "Interface\\Icons\\ability_evoker_essenceburst",
  rune = "Interface\\Icons\\spell_deathknight_frozenruneweapon",
}

for i = 1, MAX_ORBS do
  local orb = CreateFrame("Frame", addonName.."Orb"..i, orbContainer, "BackdropTemplate")
  orb:SetSize(ORB_SIZE, ORB_SIZE)
  orb:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 4,
  })
  orb:SetBackdropColor(0.12, 0.12, 0.12, 0.55)
  orb:SetBackdropBorderColor(0, 0, 0, 1)

  local icon = orb:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(orb)
  icon:SetTexture(ICONS.mana)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  orb.icon = icon

  local overlay = orb:CreateTexture(nil, "ARTWORK")
  overlay:SetAllPoints(orb)
  overlay:SetTexture("Interface\\Buttons\\WHITE8x8")
  overlay:SetVertexColor(0, 0, 0, 0)
  orb.overlay = overlay

  local glow = orb:CreateTexture(nil, "BORDER")
  glow:SetSize(ORB_SIZE + 8, ORB_SIZE + 8)
  glow:SetPoint("CENTER", orb, "CENTER", 0, 0)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:Hide()
  orb.glow = glow

  orbs[i] = orb
end

local function LayoutOrbs(count)
  if count < 1 then count = 1 end
  local width = count * ORB_SIZE + (count - 1) * ORB_SPACING
  orbContainer:SetWidth(width)
  for i = 1, count do
    local o = orbs[i]
    o:ClearAllPoints()
    if i == 1 then
      o:SetPoint("LEFT", orbContainer, "LEFT", 0, 0)
    else
      o:SetPoint("LEFT", orbs[i-1], "RIGHT", ORB_SPACING, 0)
    end
  end
  orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)
end

------------------------------------------------------------
-- POWER UTILS
------------------------------------------------------------
local powerInfo = {
  [Enum.PowerType.Mana]        = {name = "Mana", color = {0, 0.4, 1}},
  [Enum.PowerType.Rage]        = {name = "Rage", color = {1, 0, 0}},
  [Enum.PowerType.Energy]      = {name = "Energy", color = {1, 1, 0}},
  [Enum.PowerType.RunicPower]  = {name = "Runic Power", color = {0, 0.82, 1}},
  [Enum.PowerType.Insanity]    = {name = "Insanity", color = {0.6, 0, 1}},
  [Enum.PowerType.Maelstrom]   = {name = "Maelstrom", color = {0, 0.5, 1}},
  [Enum.PowerType.LunarPower]  = {name = "Astral Power", color = {0.3, 0.52, 0.9}},
  [Enum.PowerType.Fury]        = {name = "Fury", color = {0.79, 0.26, 0.99}},
  [Enum.PowerType.Pain]        = {name = "Pain", color = {1, 0.61, 0}},
}

local function GetPowerColor(powerType)
  return unpack((powerInfo[powerType] and powerInfo[powerType].color) or {0.5, 0.5, 0.5})
end

local function GetPowerName(powerType)
  return (powerInfo[powerType] and powerInfo[powerType].name) or "Resource"
end

local function GetSecondaryIcon(id)
  if id == Enum.PowerType.ComboPoints then return ICONS.combo end
  if id == Enum.PowerType.HolyPower then return ICONS.holy end
  if id == Enum.PowerType.Chi then return ICONS.chi end
  if id == Enum.PowerType.SoulShards then return ICONS.shards end
  if id == Enum.PowerType.ArcaneCharges then return ICONS.arcane end
  if id == Enum.PowerType.RunicPower then return ICONS.runic end
  return ICONS.combo
end

------------------------------------------------------------
-- SMOOTH PRIMARY BAR UPDATE
------------------------------------------------------------
local function UpdatePrimaryBar()
  local powerType = UnitPowerType("player")
  local cur = UnitPower("player", powerType) or 0
  local max = UnitPowerMax("player", powerType) or 1
  primaryBar.lastMax = max
  primaryBar.targetValue = cur
  if not primaryBar.currentDisplay then primaryBar.currentDisplay = cur end
  local r, g, b = GetPowerColor(powerType)
  primaryBar:SetStatusBarColor(r, g, b)
  primaryText:SetText(string.format("%s: %d / %d", GetPowerName(powerType), cur, max))
end

frame:SetScript("OnUpdate", function(self, elapsed)
    local powerType = UnitPowerType("player")
    local cur = UnitPower("player", powerType) or 0
    local max = UnitPowerMax("player", powerType) or 1
    primaryBar.lastMax = max
    primaryBar.targetValue = cur

    local display = tonumber(primaryBar.currentDisplay) or 0
    local target = tonumber(primaryBar.targetValue) or 0
    max = tonumber(primaryBar.lastMax) or 1

    if display ~= target then
        local diff = target - display
        local step = diff * math.min(1, elapsed * PRIMARY_LERP_SPEED)
        if step == 0 or type(step) ~= "number" then
            step = 0.01 * (diff > 0 and 1 or -1)
        end
        local newDisplay = math.max(0, math.min(display + step, max))
        primaryBar.currentDisplay = newDisplay
        primaryBar:SetValue(newDisplay)
    end

    -- update the primary text
    primaryText:SetText(string.format("%s: %d / %d", GetPowerName(powerType), math.floor(display), max))
end)

------------------------------------------------------------
-- SECONDARY RESOURCES (orbs)
------------------------------------------------------------
local function UpdateSecondary()
  local _, class = UnitClass("player")
  if class == "DEATHKNIGHT" then
    local total = 6
    LayoutOrbs(total)
    secondaryText:SetText("Runes")
    for i = 1, total do
      local start, duration, ready = GetRuneCooldown(i)
      local orb = orbs[i]
      orb:Show()
      orb.icon:SetTexture(ICONS.rune)
      if ready then
        orb.overlay:SetVertexColor(0,0,0,0)
        orb.overlay:Hide()
        orb.icon:SetDesaturated(false)
        orb.glow:Show()
      else
        local remaining = math.max(0, start+duration-GetTime())
        orb.overlay:SetVertexColor(0,0,0,0.75 * (remaining/duration))
        orb.overlay:Show()
        orb.icon:SetDesaturated(true)
        orb.glow:Hide()
      end
    end
    return true
  else
    local secondaryTypes = {
      Enum.PowerType.ComboPoints,
      Enum.PowerType.HolyPower,
      Enum.PowerType.Chi,
      Enum.PowerType.SoulShards,
      Enum.PowerType.ArcaneCharges,
    }
    for _, id in ipairs(secondaryTypes) do
      local cur = UnitPower("player", id) or 0
      local maxVal = UnitPowerMax("player", id) or 0
      if maxVal > 0 then
        LayoutOrbs(maxVal)
        secondaryText:SetText(cur .. " / " .. maxVal)
        for i = 1, maxVal do
          local orb = orbs[i]
          orb:Show()
          orb.icon:SetTexture(GetSecondaryIcon(id))
          orb.icon:SetDesaturated(i>cur)
          orb.glow:SetShown(i<=cur)
          orb.overlay:Hide()
        end
        return true
      end
    end
  end
  secondaryText:SetText("")
  for i = 1, #orbs do
    orbs[i]:Hide()
    orbs[i].overlay:Hide()
    orbs[i].glow:Hide()
  end
end

------------------------------------------------------------
-- MAIN UPDATE
------------------------------------------------------------
local function UpdateDisplay()
  UpdateClassTint()
  UpdatePrimaryBar()
  UpdateSecondary()
end

------------------------------------------------------------
-- EVENTS
------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_MAXPOWER")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("RUNE_POWER_UPDATE")
frame:RegisterEvent("RUNE_TYPE_UPDATE")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, arg1, ...)
  if event == "ADDON_LOADED" and arg1 == addonName then
    if not ChandlerResourcesDB then ChandlerResourcesDB = {} end
    if ChandlerResourcesDB.position then
      local p = ChandlerResourcesDB.position
      frame:ClearAllPoints()
      frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
      frame:SetPoint("CENTER")
    end
    UpdateClassTint()
    UpdateDisplay()
    return
  end
  UpdateDisplay()
end)

-- periodic ticker to refresh secondary resource overlays
C_Timer.NewTicker(0.12, UpdateDisplay)

------------------------------------------------------------
-- SLASH COMMANDS
------------------------------------------------------------
SLASH_CHRES1 = "/chres"
SLASH_CHRES2 = "/chandlerresources"
SlashCmdList["CHRES"] = function(msg)
  msg = msg:lower()
  if msg == "toggle" or msg == "" then
    if frame:IsShown() then
      frame:Hide()
      ChandlerResourcesDB.hidden = true
      print(addonName .. " hidden. Type /chres to show again.")
    else
      frame:Show()
      ChandlerResourcesDB.hidden = false
      print(addonName .. " shown.")
    end
  elseif msg == "reset" then
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    ChandlerResourcesDB.position = nil
    print(addonName .. " position reset to center.")
  else
    print("Commands for " .. addonName .. ":")
    print("/chres toggle - Show/hide the frame")
    print("/chres reset  - Reset position")
  end
end
