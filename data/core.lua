-- core.lua

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

local originalCloak = nil
local reequipping = false
local isHandlingCloak = false
local secureButton = nil

local CCU_PREFIX = "|cff950041CCU|r "

-- Cloak data including their IDs and associated colors
local cloakData = {
    {id = 65274, name = "|cff9b59b6Cloak of Coordination|r", spellID = 89158}, -- Purple
    {id = 65360, name = "|cff9b59b6Horde Cloak of Coordination|r", spellID = 89158}, -- Purple
    {id = 65361, name = "|cff9b59b6Alliance Cloak of Coordination|r", spellID = 89158}, -- Purple
    {id = 63206, name = "|cff3498dbAlliance Wrap of Unity|r", spellID = 89291}, -- Blue
    {id = 63207, name = "|cff3498dbHorde Wrap of Unity|r", spellID = 89291}, -- Blue
    {id = 63352, name = "|cff2ecc71Alliance Shroud of Cooperation|r", spellID = 89158}, -- Green
    {id = 63353, name = "|cff2ecc71Horde Shroud of Cooperation|r", spellID = 89158}, -- Green
}

-- Function to ensure the original cloak is saved before equipping a new one
local function EnsureOriginalCloakSaved()
    if not originalCloak then
        local slotID = GetInventorySlotInfo("BackSlot")
        originalCloak = GetInventoryItemID("player", slotID)
        if originalCloak then
            print(CCU_PREFIX .. "Original cloak ID saved: |cff8080ff" .. originalCloak .. "|r")
        else
            print(CCU_PREFIX .. "|cffff0000No original cloak found to save.|r")
        end
    end
end

-- Function to get the first available cloak ID that is not on cooldown
local function GetAvailableCloak()
    for _, cloak in ipairs(cloakData) do
        if GetItemCount(cloak.id) > 0 then
            local start, duration = GetItemCooldown(cloak.id)
            if duration == 0 then
                return cloak.id, cloak.name -- Return the first available and usable cloak
            elseif GetInventoryItemID("player", GetInventorySlotInfo("BackSlot")) == cloak.id then
                print(CCU_PREFIX .. "|cffff0000" .. cloak.name .. " is already equipped but on cooldown.|r")
                return nil, nil
            else
                print(CCU_PREFIX .. "|cffff0000" .. cloak.name .. " is on cooldown.|r")
                return nil, nil
            end
        end
    end
    print(CCU_PREFIX .. "|cffff0000No usable Cloak of Coordination, Wrap of Unity, or Shroud of Cooperation found.|r")
    return nil, nil
end

-- Function to create the secure button
local function CreateSecureButton()
    secureButton = CreateFrame("Button", "CloakUseButton", UIParent, "SecureActionButtonTemplate")
    secureButton:SetSize(64, 64)
    secureButton:SetPoint("CENTER")
    
    secureButton:SetNormalFontObject("GameFontNormalLarge")
    secureButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    secureButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    secureButton:RegisterForClicks("AnyUp")
    secureButton:SetScript("PostClick", OnCloakUsed)
    secureButton:Hide()
end

-- Function to equip the cloak and show the button for use
local function EquipAndUseCloak(cloakID, cloakName)
    EnsureOriginalCloakSaved()
    isHandlingCloak = true  -- Begin handling cloak

    EquipItemByName(cloakID)

    C_Timer.After(1.5, function()
        local backSlotID = GetInventorySlotInfo("BackSlot")
        if GetInventoryItemID("player", backSlotID) == cloakID then
            print(CCU_PREFIX .. cloakName .. " equipped. Please click the button to use it.")
            
            local itemLink = select(2, GetItemInfo(cloakID))
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(cloakID))
            secureButton:Show()
        else
            print(CCU_PREFIX .. "|cffff0000Failed to equip the cloak. Retrying...|r")
            EquipItemByName(cloakID) -- Retry equipping the cloak
        end
        isHandlingCloak = false  -- Done handling cloak
    end)
end

-- Function to handle cloak use and re-equip the original cloak
local function ReequipOriginalCloak()
    if originalCloak then
        EquipItemByName(originalCloak)
        print(CCU_PREFIX .. "|cff00ff00Re-equipping original cloak now.|r")
        originalCloak = nil  -- Clear original cloak after re-equipping
    else
        print(CCU_PREFIX .. "|cffff0000No original cloak to re-equip.|r")
    end
    secureButton:Hide()  -- Ensure the button hides after re-equipping
end

-- Function to handle cloak use and trigger the re-equip
local function OnCloakUsed()
    secureButton:Hide()  -- Hide the button after use
    reequipping = true
    ReequipOriginalCloak()  -- Re-equip the original cloak
end

-- Slash command to trigger cloak use
local function HandleCloakUse()
    local cloakID, cloakName = GetAvailableCloak()
    if cloakID then
        EquipAndUseCloak(cloakID, cloakName)
    else
        secureButton:Hide()  -- Ensure button is hidden if no cloak is usable
    end
end

-- Event Handlers
local function OnPlayerLogin()
    SLASH_EQUIPCOORD1 = "/equipcoord"
    SlashCmdList["EQUIPCOORD"] = HandleCloakUse
    CreateSecureButton()
end

-- Check if the equipped cloak is one of the teleportation cloaks
local function IsTeleportationCloakEquipped()
    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    
    for _, cloak in ipairs(cloakData) do
        if cloak.id == equippedCloakID then
            return true
        end
    end
    return false
end

local function OnPlayerEquipmentChanged()
    if IsTeleportationCloakEquipped() then
        secureButton:Show()
    else
        secureButton:Hide()  -- Hide the button if no teleportation cloak is equipped
        originalCloak = nil  -- Reset original cloak if no teleportation cloak is equipped
    end
end

local function OnSpellcastSucceeded(unit, _, spellID)
    if unit == "player" then
        for _, cloak in ipairs(cloakData) do
            if spellID == cloak.spellID then
                print(CCU_PREFIX .. "|cff00ff00Detected " .. cloak.name .. " spell cast.|r")
                ReequipOriginalCloak()
                reequipping = false
                break
            end
        end
    end
end

-- Register events
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        OnPlayerEquipmentChanged()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcastSucceeded(...)
    end
end)
