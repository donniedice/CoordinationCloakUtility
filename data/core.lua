local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

local originalCloak = nil
local reequipping = false
local secureButton = nil

local cloakIDs = {
    65274, -- Universal Cloak of Coordination
    65360, -- Horde Cloak of Coordination
    65361, -- Alliance Cloak of Coordination
    63206, -- Alliance Wrap of Unity
    63207, -- Horde Wrap of Unity
}

local CCU_PREFIX = "|cff950041CCU|r "

-- Function to save the original cloak before equipping the teleportation cloak
local function SaveOriginalCloak()
    local slotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", slotID)

    if not originalCloak and equippedCloakID and not tContains(cloakIDs, equippedCloakID) then
        originalCloak = equippedCloakID
        print(CCU_PREFIX .. "Original cloak ID saved: |cff8080ff" .. originalCloak .. "|r")
    end
end

-- Function to get the first available cloak ID that is not on cooldown
local function GetAvailableCloakID()
    for _, id in ipairs(cloakIDs) do
        local start, duration = GetItemCooldown(id)
        if GetItemCount(id) > 0 then
            if duration == 0 then
                return id -- Return the first available cloak ID not on cooldown
            elseif GetInventoryItemID("player", GetInventorySlotInfo("BackSlot")) == id then
                print(CCU_PREFIX .. "|cffff0000Cloak of Coordination is already equipped but on cooldown.|r")
                return nil
            end
        end
    end
    print(CCU_PREFIX .. "|cffff0000No Cloak of Coordination or Wrap of Unity available or off cooldown.|r")
    return nil
end

-- Function to create the secure button for manual cloak use
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

-- Function to equip the teleportation cloak and show the button for use
local function EquipAndUseCloak(cloakID)
    SaveOriginalCloak()

    EquipItemByName(cloakID)

    C_Timer.After(1.5, function()
        local backSlotID = GetInventorySlotInfo("BackSlot")
        if GetInventoryItemID("player", backSlotID) == cloakID then
            print(CCU_PREFIX .. "|cff00ff00Cloak equipped.|r Please click the button to use it.")
            
            local itemLink = select(2, GetItemInfo(cloakID))
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(cloakID))
            secureButton:Show()
        else
            print(CCU_PREFIX .. "|cffff0000Failed to equip the cloak.|r Retrying...")
            EquipItemByName(cloakID)
        end
    end)
end

-- Function to handle re-equipping the original cloak
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

-- Function to handle when the cloak button is clicked
local function OnCloakUsed()
    secureButton:Hide()  -- Ensure the button hides after use
    ReequipOriginalCloak()  -- Trigger the re-equip
end

-- Slash command to trigger cloak use
local function HandleCloakUse()
    local cloakID = GetAvailableCloakID()
    if cloakID then
        EquipAndUseCloak(cloakID)
    else
        print(CCU_PREFIX .. "|cffff0000No usable Cloak of Coordination or Wrap of Unity found, or it is on cooldown.|r")
    end
end

-- Event Handlers
local function OnPlayerLogin()
    SLASH_EQUIPCOORD1 = "/equipcoord"
    SlashCmdList["EQUIPCOORD"] = HandleCloakUse
    CreateSecureButton()
end

local function OnPlayerEquipmentChanged()
    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    
    if equippedCloakID and tContains(cloakIDs, equippedCloakID) then
        secureButton:Show()
    elseif not reequipping then
        originalCloak = nil
        secureButton:Hide()
    end
end

local function OnSpellcastSucceeded(unit, _, spellID)
    if unit == "player" and spellID == 89158 then -- Cloak of Coordination spell ID
        print(CCU_PREFIX .. "|cff00ff00Detected Cloak of Coordination spell cast.|r")
        ReequipOriginalCloak()
        reequipping = false
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
