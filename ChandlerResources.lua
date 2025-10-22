-- ChandlerResources.lua v1.6
-- Polished visuals: static background behind primary bar, flat texture, class tint fix,
-- fantasy-themed orb icons (built-in textures), DK runes use fade cooldown overlay.

local addonName = "ChandlerResources"

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local PRIMARY_LERP_SPEED = 8      -- higher = faster interpolation
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
-- CLASS TINT (robust)
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
-- PRIMARY BAR: static background + flat statusbar + 1px black border
------------------------------------------------------------
-- Background frame (static dark fill + 1px black border)
local bgBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
bgBar:SetSize(248, 22)
bgBar:SetPoint("TOP", title, "BOTTOM", 0, -10)
bgBar:SetBackdrop({
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  tile = true, tileSize = 8, edgeSize = 1,
})
bgBar:SetBackdropColor(0.06, 0.06, 0.06, 1) -- grey-black fill
bgBar:SetBackdropBorderColor(0, 0, 0, 1)    -- 1px black border

-- Primary status bar (flat texture) inside bgBar with 1px inset
local primaryBar = CreateFrame("StatusBar", addonName.."PrimaryBar", bgBar)
primaryBar:SetSize(246, 20)
primaryBar:SetPoint("CENTER", bgBar, "CENTER", 0, 0)
primaryBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8") -- flat
primaryBar:GetStatusBarTexture():SetHorizTile(false)
primaryBar:SetMinMaxValues(0, 1)

-- Adjust texture inset so border remains visible
local tex = primaryBar:GetStatusBarTexture()
tex:SetPoint("TOPLEFT", primaryBar, "TOPLEFT", 0, 0)
tex:SetPoint("BOTTOMRIGHT", primaryBar, "BOTTOMRIGHT", 0, 0)

local primaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
primaryText:SetPoint("TOP", bgBar, "BOTTOM", 0, -6)

-- smoothing fields
primaryBar.currentDisplay = 0
primaryBar.targetValue = 0
primaryBar.lastMax = 1

------------------------------------------------------------
-- ORB CONTAINER (centered) + orb creation with icon + overlay
------------------------------------------------------------
local orbContainer = CreateFrame("Frame", addonName.."OrbContainer", frame)
orbContainer:SetHeight(ORB_SIZE)
orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)

local secondaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
secondaryText:SetPoint("TOP", orbContainer, "BOTTOM", 0, -6)

local orbs = {}

-- icon mapping for fantasy-themed built-in textures
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
  orb:SetAlpha(1)

  -- icon in center
  local icon = orb:CreateTexture(nil, "OVERLAY")
  icon:SetAllPoints(orb)
  icon:SetTexture(ICONS.mana)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  orb.icon = icon

  -- cooldown fade overlay (simple dark texture whose alpha represents remaining cooldown)
  local overlay = orb:CreateTexture(nil, "ARTWORK")
  overlay:SetAllPoints(orb)
  overlay:SetTexture("Interface\\Buttons\\WHITE8x8")
  overlay:SetVertexColor(0, 0, 0, 0) -- start invisible
  orb.overlay = overlay

  -- glow (bright outer) when filled
  local glow = orb:CreateTexture(nil, "BORDER")
  glow:SetSize(ORB_SIZE + 8, ORB_SIZE + 8)
  glow:SetPoint("CENTER", orb, "CENTER", 0, 0)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:Hide()
  orb.glow = glow

  -- pulsing animation for fill
  local ag = orb:CreateAnimationGroup()
  ag:SetLooping("NONE")
  local fadeIn = ag:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0.6)
  fadeIn:SetToAlpha(1)
  fadeIn:SetDuration(0.12)
  local scaleUp = ag:CreateAnimation("Scale")
  scaleUp:SetScale(1.18, 1.18)
  scaleUp:SetDuration(0.12)
  local scaleDown = ag:CreateAnimation("Scale")
  scaleDown:SetScale(1/1.18, 1/1.18)
  scaleDown:SetDuration(0.12)
  scaleDown:SetOrder(2)
  orb.pulseAnim = ag

  orbs[i] = orb
end

-- helper to layout centered
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
  orbContainer:ClearAllPoints()
  orbContainer:SetPoint("TOP", primaryText, "BOTTOM", 0, -18)
end

------------------------------------------------------------
-- UTILS: power name/color
------------------------------------------------------------
local powerInfo = {
  [Enum.PowerType.Mana]        = {name = "Mana", color = {0, 0.4, 1}, icon = ICONS.mana},
  [Enum.PowerType.Rage]        = {name = "Rage", color = {1, 0, 0}, icon = ICONS.rage},
  [Enum.PowerType.Focus]       = {name = "Focus", color = {1, 0.5, 0}, icon = ICONS.combo},
  [Enum.PowerType.Energy]      = {name = "Energy", color = {1, 1, 0}, icon = ICONS.energy},
  [Enum.PowerType.RunicPower]  = {name = "Runic Power", color = {0, 0.82, 1}, icon = ICONS.runic},
  [Enum.PowerType.Insanity]    = {name = "Insanity", color = {0.6, 0, 1}, icon = ICONS.insanity},
  [Enum.PowerType.Maelstrom]   = {name = "Maelstrom", color = {0, 0.5, 1}, icon = ICONS.maelstrom},
  [Enum.PowerType.LunarPower]  = {name = "Astral Power", color = {0.3, 0.52, 0.9}, icon = ICONS.arcane},
  [Enum.PowerType.Fury]        = {name = "Fury", color = {0.79, 0.26, 0.99}, icon = ICONS.rage},
  [Enum.PowerType.Pain]        = {name = "Pain", color = {1, 0.61, 0}, icon = ICONS.rage},
}

local function GetPowerColor(powerType)
  return unpack((powerInfo[powerType] and powerInfo[powerType].color) or {0.5, 0.5, 0.5})
end

local function GetPowerName(powerType)
  return (powerInfo[powerType] and powerInfo[powerType].name) or "Resource"
end

local function GetSecondaryIcon(id, name)
  -- map by known ids or names to ICONS
  if id == Enum.PowerType.ComboPoints then return ICONS.combo end
  if id == Enum.PowerType.HolyPower then return ICONS.holy end
  if id == Enum.PowerType.Chi then return ICONS.chi end
  if id == Enum.PowerType.SoulShards then return ICONS.shards end
  if id == Enum.PowerType.ArcaneCharges then return ICONS.arcane end
  return ICONS.combo
end

------------------------------------------------------------
-- SMOOTH PRIMARY BAR (OnUpdate)
------------------------------------------------------------
frame:SetScript("OnUpdate", function(self, elapsed)
  -- smooth interp
  local display = primaryBar.currentDisplay or 0
  local target = primaryBar.targetValue or 0
  local max = primaryBar.lastMax or 1
  if display ~= target then
    local diff = (target - display)
    local step = diff * math.min(1, elapsed * PRIMARY_LERP_SPEED)
    if math.abs(step) < 0.01 then
      step = (step > 0 and 0.01) or (step < 0 and -0.01)
    end
    local newDisplay = display + step
    if newDisplay < 0 then newDisplay = 0 end
    if newDisplay > max then newDisplay = max end
    primaryBar.currentDisplay = newDisplay
    primaryBar:SetValue(newDisplay)
  end
end)

------------------------------------------------------------
-- UPDATE HELPERS: runes (fade overlay) and generics
------------------------------------------------------------
local function UpdateRunes()
  local _, class = UnitClass("player")
  if class ~= "DEATHKNIGHT" then
    return false
  end

  local total = 6
  LayoutOrbs(total)
  secondaryText:SetText("Runes")

  for i = 1, total do
    local start, duration, ready = GetRuneCooldown(i)
    local orb = orbs[i]
    orb:Show()
    orb.icon:SetTexture(ICONS.rune)
    orb.glow:Hide()
    orb.overlay:SetVertexColor(0, 0, 0, 0) -- default invisible
    orb:SetBackdropColor(0.18, 0.22, 0.28, 1)
    orb:SetBackdropBorderColor(0.04, 0.08, 0.12, 1)

    if start and duration and duration > 0 and not ready then
      -- cooldown active: compute remaining and set overlay alpha proportionally
      local expires = start + duration
      local remaining = math.max(0, expires - GetTime())
      local frac = remaining / duration
      -- overlay alpha where 1 = full dark (recharging)
      orb.overlay:SetVertexColor(0, 0, 0, 0.75 * frac)
      orb.overlay:Show()
      orb.glow:Hide()
      orb.icon:SetDesaturated(true)
      orb.active = false
      orb.pulseAnim:Stop()
    else
      -- ready rune
      orb.overlay:SetVertexColor(0, 0, 0, 0)
      orb.overlay:Hide()
      orb.icon:SetDesaturated(false)
      orb:SetBackdropColor(0.65, 0.85, 1, 1)
      orb.glow:Show()
      if not orb.active then
        orb.pulseAnim:Play()
        orb.active = true
      end
    end
  end

  return true
end

local function UpdateSecondaryGeneric(id, name)
  local cur = UnitPower("player", id) or 0
  local maxVal = UnitPowerMax("player", id) or 0
  if maxVal == 0 then return false end

  LayoutOrbs(maxVal)
  secondaryText:SetText(name .. ": " .. cur .. " / " .. maxVal)

  for i = 1, maxVal do
    local orb = orbs[i]
    orb:Show()
    orb.icon:SetTexture(GetSecondaryIcon(id, name))
    orb.icon:SetDesaturated(false)
    orb.overlay:Hide()
    orb.glow:Hide()

    orb:SetBackdropColor(0.12, 0.12, 0.12, 0.55)
    orb:SetBackdropBorderColor(0, 0, 0, 1)

    if i <= cur then
      orb.icon:SetVertexColor(1, 0.9, 0.4)
      orb.glow:Show()
      if not orb.active then
        orb.pulseAnim:Play()
        orb.active = true
      end
    else
      orb.icon:SetVertexColor(1, 1, 1)
      orb.active = false
    end
  end

  for i = maxVal + 1, #orbs do
    orbs[i]:Hide()
    orbs[i].active = false
  end

  return true
end

------------------------------------------------------------
-- MAIN UPDATE
------------------------------------------------------------
local function UpdateDisplay()
  -- class tint
  UpdateClassTint()

  -- primary
  local powerType = UnitPowerType("player")
  local current = UnitPower("player", powerType) or 0
  local max = UnitPowerMax("player", powerType) or 1
  local r, g, b = GetPowerColor(powerType)
  primaryBar.lastMax = max
  primaryBar.targetValue = current

  if not primaryBar.currentDisplay then
    primaryBar.currentDisplay = current
    primaryBar:SetValue(current)
  end

  primaryBar:SetStatusBarColor(r, g, b)
  primaryText:SetText(string.format("%s: %d / %d", GetPowerName(powerType), current, max))

  -- secondary handling: DK runes first, but still show Runic Power as primary if applicable
  local _, class = UnitClass("player")
  local handled = false

  if class == "DEATHKNIGHT" then
    handled = UpdateRunes() or handled
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
        orbs[i].overlay:Hide()
        orbs[i].glow:Hide()
      end
    end
  end
end

------------------------------------------------------------
-- EVENTS + TICKER (for cooldown fades)
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
    if ChandlerResourcesDB.hidden then frame:Hide() else frame:Show() end
    UpdateClassTint()
    UpdateDisplay()
    return
  end

  if event == "PLAYER_LOGOUT" then
    return
  end

  if event:match("^UNIT_") and arg1 and arg1 ~= "player" then
    return
  end

  UpdateDisplay()
end)

-- periodic ticker to update rune fade overlays smoothly
local ticker = C_Timer.NewTicker(0.12, function() UpdateDisplay() end)

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

-- initial layout and update
LayoutOrbs(6)
C_Timer.After(0.6, UpdateDisplay)
