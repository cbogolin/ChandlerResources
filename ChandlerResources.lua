-- ChandlerResources.lua v1.5.1
-- Updates:
--  * Smooth primary bar animation on change
--  * Reliable class-based frame tinting (supports CUSTOM_CLASS_COLORS)
--  * Primary resource bar has a 1px black border and grey-black background fill
-- All other features from v1.5 remain: centered orbs, DK runes with cooldown overlays,
-- saved position/visibility, pulsing animation for non-rune orbs.

local addonName = "ChandlerResources"

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local PRIMARY_LERP_SPEED = 8      -- higher = faster interpolation
local PRIMARY_MIN_STEP = 0.5      -- minimum change step to always move at least this much (to avoid extremely slow changes)

------------------------------------------------------------
-- FRAME CREATION
------------------------------------------------------------
local frame = CreateFrame("Frame", addonName.."Frame", UIParent, "BackdropTemplate")
frame:SetSize(280, 140)
frame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 16,
})
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
-- PRIMARY RESOURCE BAR (with border + background)
------------------------------------------------------------
-- Use BackdropTemplate so we can add a border and background behind the statusbar.
local primaryBar = CreateFrame("StatusBar", addonName.."PrimaryBar", frame, "BackdropTemplate")
primaryBar:SetSize(240, 20)
primaryBar:SetPoint("TOP", title, "BOTTOM", 0, -10)
primaryBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
primaryBar:GetStatusBarTexture():SetHorizTile(false)
primaryBar:SetMinMaxValues(0, 1)

-- Create the bar backdrop (this is the grey-black background fill + 1px black border)
primaryBar:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8x8",               -- simple solid texture for bg fill
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",   -- border texture
  tile = true, tileSize = 8, edgeSize = 8,
})
-- background fill (grey-black)
primaryBar:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
-- black border
primaryBar:SetBackdropBorderColor(0, 0, 0, 1)

-- Move the statusbar texture slightly inset so border shows
local tex = primaryBar:GetStatusBarTexture()
tex:SetPoint("TOPLEFT", primaryBar, "TOPLEFT", 1, -1)
tex:SetPoint("BOTTOMRIGHT", primaryBar, "BOTTOMRIGHT", -1, 1)

-- floating numeric display below bar
local primaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
primaryText:SetPoint("TOP", primaryBar, "BOTTOM", 0, -6)

-- smoothing fields
primaryBar.currentDisplay = 0
primaryBar.targetValue = 0
primaryBar.lastMax = 1

------------------------------------------------------------
-- SECONDARY ORB CONTAINER (centered)
------------------------------------------------------------
local maxOrbs = 10
local orbs = {}
local orbSize = 20
local spacing = 6
local orbContainer = CreateFrame("Frame", addonName.."OrbContainer", frame)
orbContainer:SetHeight(orbSize)
orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)

local secondaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secondaryText:SetPoint("TOP", orbContainer, "BOTTOM", 0, -6)

for i = 1, maxOrbs do
  local orb = CreateFrame("Frame", addonName.."Orb"..i, orbContainer, "BackdropTemplate")
  orb:SetSize(orbSize, orbSize)
  orb:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  orb:SetBackdropColor(0.18, 0.18, 0.18, 0.45)
  orb:SetBackdropBorderColor(0, 0, 0)
  orb:SetAlpha(0.8)

  -- cooldown overlay frame for runes (hidden by default)
  local cd = CreateFrame("Cooldown", nil, orb, "CooldownFrameTemplate")
  cd:SetAllPoints(orb)
  cd:SetCooldown(0, 0)
  cd:Hide()
  orb.cooldown = cd

  -- pulsing animation for non-rune orb fill
  local ag = orb:CreateAnimationGroup()
  ag:SetLooping("NONE")
  local fadeIn = ag:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0.6)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.12)
  local scaleUp = ag:CreateAnimation("Scale")
  scaleUp:SetScale(1.22, 1.22)
  scaleUp:SetDuration(0.12)
  local scaleDown = ag:CreateAnimation("Scale")
  scaleDown:SetScale(1/1.22, 1/1.22)
  scaleDown:SetDuration(0.12)
  scaleDown:SetOrder(2)
  orb.pulseAnim = ag

  orbs[i] = orb
end

-- helper to position container centered with given count
local function LayoutOrbs(count)
  if count < 1 then count = 1 end
  local width = count * orbSize + (count - 1) * spacing
  orbContainer:SetWidth(width)
  -- position orbs left to right, container is centered relative to primaryText
  for i = 1, count do
    local orb = orbs[i]
    orb:ClearAllPoints()
    if i == 1 then
      orb:SetPoint("LEFT", orbContainer, "LEFT", 0, 0)
    else
      orb:SetPoint("LEFT", orbs[i-1], "RIGHT", spacing, 0)
    end
  end
  orbContainer:ClearAllPoints()
  orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)
end

------------------------------------------------------------
-- RESOURCE TYPE INFO and class tint
------------------------------------------------------------
local powerInfo = {
  [Enum.PowerType.Mana]        = {name = "Mana", color = {0, 0.4, 1}},
  [Enum.PowerType.Rage]        = {name = "Rage", color = {1, 0, 0}},
  [Enum.PowerType.Focus]       = {name = "Focus", color = {1, 0.5, 0}},
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

-- Robust class tint using CUSTOM_CLASS_COLORS if present, fallback to RAID_CLASS_COLORS
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
    -- muted tint: scale color down and apply alpha 0.38
    local r, g, b = colorObj.r * 0.35, colorObj.g * 0.35, colorObj.b * 0.35
    frame:SetBackdropColor(r, g, b, 0.38)
  else
    frame:SetBackdropColor(0, 0, 0, 0.6)
  end
end

------------------------------------------------------------
-- PRIMARY BAR SMOOTHING ONUPDATE
------------------------------------------------------------
-- We'll run a small OnUpdate to smoothly lerp the displayed value towards the target
local lastUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
  lastUpdate = lastUpdate + elapsed
  -- Smooth primary bar interpolation
  local display = primaryBar.currentDisplay or 0
  local target = primaryBar.targetValue or 0
  local max = primaryBar.lastMax or 1

  if display ~= target then
    -- compute step based on elapsed and speed
    local diff = target - display
    local step = diff * math.min(1, elapsed * PRIMARY_LERP_SPEED)
    -- if step is tiny, push it to a minimum so animation does not stall
    if math.abs(step) < 0.01 then
      step = (step > 0 and 0.01) or (step < 0 and -0.01)
    end
    local newDisplay = display + step

    -- clamp between 0 and max
    if newDisplay < 0 then newDisplay = 0 end
    if newDisplay > max then newDisplay = max end

    primaryBar.currentDisplay = newDisplay
    primaryBar:SetValue(newDisplay)
  end
end)

------------------------------------------------------------
-- RUNE HANDLING + GENERIC SECONDARY
------------------------------------------------------------
local function UpdateRunes()
  local _, class = UnitClass("player")
  if class ~= "DEATHKNIGHT" then
    return nil
  end

  local total = 6
  LayoutOrbs(total)
  secondaryText:SetText("Runes")

  for i = 1, total do
    local start, duration, ready = GetRuneCooldown(i)
    local orb = orbs[i]
    orb:Show()

    -- distinct rune styling (frosty look)
    orb:SetBackdropColor(0.22, 0.28, 0.38, 1) -- base rune bg
    orb:SetBackdropBorderColor(0.06, 0.12, 0.18)

    if start and duration and duration > 0 and not ready then
      orb.cooldown:SetCooldown(start, duration)
      orb.cooldown:Show()
      orb:SetAlpha(0.8)
      orb.active = false
      orb.pulseAnim:Stop()
    else
      orb.cooldown:Clear()
      orb.cooldown:Hide()
      orb:SetBackdropColor(0.65, 0.85, 1, 1)
      if not orb.active then
        orb.pulseAnim:Play()
        orb.active = true
      end
      orb:SetAlpha(1)
    end
  end
end

local function UpdateSecondaryGeneric(id, name)
  local cur = UnitPower("player", id)
  local maxVal = UnitPowerMax("player", id)
  if not cur or maxVal == 0 then
    return false
  end
  LayoutOrbs(maxVal)
  secondaryText:SetText(name .. ": " .. cur .. " / " .. maxVal)

  for i = 1, maxVal do
    local orb = orbs[i]
    orb:Show()
    orb:SetBackdropColor(0.18, 0.18, 0.18, 0.45)
    orb:SetBackdropBorderColor(0, 0, 0)

    if i <= cur then
      orb:SetBackdropColor(0.95, 0.85, 0.24, 1)
      if not orb.active then
        orb.pulseAnim:Play()
        orb.active = true
      end
    else
      orb:SetBackdropColor(0.18, 0.18, 0.18, 0.45)
      orb.active = false
    end
    if orb.cooldown then
      orb.cooldown:Clear()
      orb.cooldown:Hide()
    end
  end

  for i = maxVal + 1, #orbs do
    orbs[i]:Hide()
    orbs[i].active = false
    if orbs[i].cooldown then
      orbs[i].cooldown:Clear()
      orbs[i].cooldown:Hide()
    end
  end

  return true
end

------------------------------------------------------------
-- MAIN UPDATE
------------------------------------------------------------
local function UpdateDisplay()
  -- class tint update
  UpdateClassTint()

  -- primary resource
  local powerType = UnitPowerType("player")
  local current = UnitPower("player", powerType) or 0
  local max = UnitPowerMax("player", powerType) or 1
  local r, g, b = GetPowerColor(powerType)
  primaryBar.lastMax = max

  -- set target value and let OnUpdate lerp the visual
  primaryBar.targetValue = current
  -- ensure currentDisplay is initialized
  if not primaryBar.currentDisplay then
    primaryBar.currentDisplay = current
    primaryBar:SetValue(current)
  end

  -- keep statusbar color and text in sync
  primaryBar:SetStatusBarColor(r, g, b)
  primaryText:SetText(string.format("%s: %d / %d", GetPowerName(powerType), current, max))

  -- secondary handling
  local _, class = UnitClass("player")
  local handled = false

  if class == "DEATHKNIGHT" then
    UpdateRunes()
    handled = true
  end

  if not handled then
    local secondaryTypes = {
      {Enum.PowerType.ComboPoints, "Combo Points"},
      {Enum.PowerType.HolyPower, "Holy Power"},
      {Enum.PowerType.Chi, "Chi"},
      {Enum.PowerType.SoulShards, "Soul Shards"},
      {Enum.PowerType.ArcaneCharges, "Arcane Charges"},
    }

    local found = false
    for _, info in ipairs(secondaryTypes) do
      local id, name = unpack(info)
      if UpdateSecondaryGeneric(id, name) then
        found = true
        break
      end
    end

    if not found then
      secondaryText:SetText("")
      for i = 1, #orbs do
        orbs[i]:Hide()
        orbs[i].active = false
        if orbs[i].cooldown then
          orbs[i].cooldown:Clear()
          orbs[i].cooldown:Hide()
        end
      end
    end
  end
end

------------------------------------------------------------
-- EVENT HANDLING
------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_POWER_UPDATE")
frame:RegisterEvent("UNIT_MAXPOWER")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_POWER_FREQUENT")
frame:RegisterEvent("RUNE_POWER_UPDATE")
frame:RegisterEvent("RUNE_TYPE_UPDATE")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("UNIT_AURA")

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
    if ChandlerResourcesDB.hidden then
      frame:Hide()
    else
      frame:Show()
    end
    UpdateClassTint()
    UpdateDisplay()
    return
  end

  if event:match("^UNIT_") and arg1 and arg1 ~= "player" then
    return
  end

  -- For runes and cooldown visuals we update always
  UpdateDisplay()
end)

-- periodic ticker to keep cooldown visuals up to date
local ticker = C_Timer.NewTicker(0.25, UpdateDisplay)

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

-- initial layout default
LayoutOrbs(6)
C_Timer.After(0.6, UpdateDisplay)
