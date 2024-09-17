local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event when combat starts
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event when combat ends

local originalCloak = nil
local reequipping = false
local secureButton = nil
local ccuActive = false -- State variable to control script execution
local inCombat = false  -- Track combat state
local reequippingTimeout = false -- Timeout to avoid infinite loops

local colors = {
    prefix = "|cffdd0064",     -- CCU Prefix Color
    success = "|cff00ff00",  -- Success/Enabled/Positive Color
    error = "|cffff0000",     -- Error/Disabled/Negative Color
    highlight = "|cff8080ff", -- Highlighted Text Color
    info = "|cffffff00",       -- Information/Warning Color
    white = "|cffffffff",     -- White Color
    warning = "|cffffcc00",  -- Warning Color
}

local cloaks = {
    { id = 65274, name = string.format("%sCloak of Coordination|r", colors.highlight) },
    { id = 65360, name = string.format("%sHorde Cloak of Coordination|r", colors.highlight) },
    { id = 65361, name = string.format("%sAlliance Cloak of Coordination|r", colors.highlight) },
    { id = 63206, name = string.format("%sAlliance Wrap of Unity|r", colors.highlight) },
    { id = 63207, name = string.format("%sHorde Wrap of Unity|r", colors.highlight) },
    { id = 63352, name = string.format("%sAlliance Shroud of Cooperation|r", colors.highlight) },
    { id = 63353, name = string.format("%sHorde Shroud of Cooperation|r", colors.highlight) },
}

CCU_PREFIX = string.format("|Tinterface/addons/CoordinationCloakUtility/images/icon:16:16|t - [%sCCU|r] ", colors.prefix)

local L = {
    WELCOME_MSG = string.format("%sWelcome! Use %s/ccu help|r for commands.", colors.white, colors.prefix),
    VERSION = string.format("%sVersion: %s|r", colors.info, colors.highlight),
    ORIGINAL_CLOAK_SAVED = string.format("%sOriginal cloak saved: %s|r", colors.info, colors.highlight),
    CLOAK_EQUIPPED = string.format("%s equipped. Click the button to use it.", colors.success),
    CLOAK_ALREADY_EQUIPPED = string.format("%sCloak is already equipped. Ready to use.|r", colors.info),
    FAILED_EQUIP = string.format("%sFailed to equip the cloak. Retrying...|r", colors.error),
    SUCCESS_EQUIP = string.format("%sCloak successfully equipped after retry.|r", colors.success),
    FINAL_FAILED_EQUIP = string.format("%sFailed to equip the cloak after retrying. Please try manually.|r", colors.error),
    REEQUIP_CLOAK = string.format("%sRe-equipping original cloak now: %s|r", colors.success, colors.highlight),
    NO_CLOAK_REEQUIP = string.format("%sNo original cloak to re-equip.|r", colors.error),
    HELP_COMMAND = string.format("%sAvailable commands:", colors.info),
    CLOAK_IN_PROGRESS = string.format("%sReequipping is already in progress. Please wait.|r", colors.error),
    NO_USABLE_CLOAK = string.format("%sNo usable teleportation cloak found or all are on cooldown.|r", colors.error),
    COMBAT_ACTIVE = string.format("%sCannot use cloak while in combat!|r", colors.error),
    RETRYING_REEQUIP = string.format("%sRetrying to re-equip original cloak...|r", colors.info),
    FINAL_ATTEMPT_REEQUIP = string.format("%sFinal attempt to re-equip original cloak...|r", colors.warning),
    CLOAK_SUCCESSFULLY_REEQUIPPED = string.format("%sOriginal cloak successfully re-equipped.|r", colors.success),
    FAILED_TO_REEQUIP = string.format("%sFailed to re-equip original cloak after multiple attempts. Please try manually.|r", colors.error),
    FAILED_TO_REEQUIP_NO_EXIST = string.format("%sFailed to re-equip original cloak. It no longer exists in your inventory.|r", colors.error),
    FAILED_EQUIP_NO_EXIST = string.format("%sFailed to equip cloak. It no longer exists in your inventory.|r", colors.error),
    CLOAK_ON_CD = string.format("%s is on cooldown.|r", colors.error),
    TIMEOUT_ERROR = string.format("%sRe-equipping cloak timed out. Resetting process.|r", colors.error)
}

-- Timeout function to reset re-equipping if it takes too long
local function ResetReequippingAfterTimeout()
    if reequippingTimeout then
        print(CCU_PREFIX .. L.TIMEOUT_ERROR)
        reequipping = false
        ccuActive = false
        reequippingTimeout = false
    end
end

-- Version Number
local VersionNumber = string.format("%s%s|r", colors.highlight, C_AddOns.GetAddOnMetadata("CoordinationCloakUtility", "Version"))

-- Function to notify if combat is active
local function NotifyCombatLockdown()
    print(CCU_PREFIX .. L.COMBAT_ACTIVE)
end

-- Function to save the original cloak before equipping the teleportation cloak
local function SaveOriginalCloak()
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    local slotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", slotID)

    if not originalCloak and equippedCloakID then
        for _, cloak in ipairs(cloaks) do
            if equippedCloakID == cloak.id then return end
        end
        originalCloak = equippedCloakID
        print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. string.format("%s%s|r", colors.highlight, GetItemInfo(originalCloak) or originalCloak))
    end
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
    secureButton:SetScript("PostClick", function()
        reequipping = true
    end)
    secureButton:Hide() -- Button should be hidden by default
end

-- Function to get the first available cloak ID that is not on cooldown
local function GetAvailableCloakID()
    if inCombat then
        NotifyCombatLockdown()
        return nil
    end

    for _, cloak in ipairs(cloaks) do
        local start, duration, enable = GetItemCooldown(cloak.id)
        if GetItemCount(cloak.id) > 0 and enable == 1 then -- Check if the item exists and is usable
            if duration == 0 then 
                return cloak.id, cloak.name -- Return the first available cloak ID not on cooldown
            else
                print(CCU_PREFIX .. cloak.name .. L.CLOAK_ON_CD)
            end
        end
    end
    return nil
end

-- Function to handle re-equipping the original cloak (with retry limit)
local function ReequipOriginalCloak()
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    if not ccuActive then return end -- Guard against unintended triggers

    -- Start timeout protection
    reequippingTimeout = true
    C_Timer.After(10, ResetReequippingAfterTimeout) -- 10-second timeout

    if originalCloak then
        local backSlotID = GetInventorySlotInfo("BackSlot")
        local equippedCloakID = GetInventoryItemID("player", backSlotID)
        local retryCount = 0
        local maxRetries = 3

        -- Check if the original cloak is already equipped
        if equippedCloakID == originalCloak then
            print(CCU_PREFIX .. L.CLOAK_SUCCESSFULLY_REEQUIPPED)
            originalCloak = nil
            reequipping = false
            ccuActive = false 
            reequippingTimeout = false 
            secureButton:Hide() -- Hide the button once re-equipped
            return
        end

        local function attemptReequip()
            -- Check if re-equipping is still needed
            if not reequipping then 
                return 
            end

            if retryCount >= maxRetries then
                print(CCU_PREFIX .. L.FAILED_TO_REEQUIP)
                reequipping = false
                ccuActive = false 
                reequippingTimeout = false
                secureButton:Hide() -- Ensure button is hidden
                return
            end

            if C_Item.DoesItemExistByID(originalCloak) then
                local itemName, itemLink = GetItemInfo(originalCloak)
                if itemName then
                    EquipItemByName(itemLink)
                    print(CCU_PREFIX .. L.REEQUIP_CLOAK .. string.format("%s%s|r", colors.highlight, itemName))

                    C_Timer.After(1.5, function()
                        local equippedCloakID = GetInventoryItemID("player", backSlotID)
                        if equippedCloakID ~= originalCloak then
                            retryCount = retryCount + 1
                            print(CCU_PREFIX .. L.RETRYING_REEQUIP)
                            attemptReequip() -- Retry if not equipped
                        else
                            print(CCU_PREFIX .. L.CLOAK_SUCCESSFULLY_REEQUIPPED)
                            originalCloak = nil
                            reequipping = false
                            ccuActive = false 
                            reequippingTimeout = false 
                            secureButton:Hide() -- Hide the button when successful
                        end
                    end)
                else
                    print(CCU_PREFIX .. L.FAILED_TO_REEQUIP)
                    reequipping = false
                    ccuActive = false 
                    reequippingTimeout = false
                    secureButton:Hide() -- Hide the button if failed
                end
            else
                print(CCU_PREFIX .. L.FAILED_TO_REEQUIP_NO_EXIST)
                reequipping = false
                ccuActive = false
                reequippingTimeout = false
                secureButton:Hide() -- Hide the button if cloak no longer exists
            end
        end

        attemptReequip() -- Start the re-equipping attempts

    else
        print(CCU_PREFIX .. L.NO_CLOAK_REEQUIP)
        reequipping = false
        ccuActive = false 
        reequippingTimeout = false
        secureButton:Hide() -- Ensure button is hidden if no original cloak
    end
end

-- Function to equip the teleportation cloak and show the button for use
local function EquipAndUseCloak(cloakID, cloakName)
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    if not ccuActive then return end -- Guard against unintended triggers

    SaveOriginalCloak()

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)

    if equippedCloakID == cloakID then
        print(CCU_PREFIX .. L.CLOAK_ALREADY_EQUIPPED)
        secureButton:SetAttribute("type", "item")
        secureButton:SetAttribute("item", select(2, GetItemInfo(cloakID)))
        secureButton:SetNormalTexture(GetItemIcon(cloakID))
        secureButton:Show()
        return
    end

    if C_Item.DoesItemExistByID(cloakID) then
        EquipItemByName(cloakID)

        C_Timer.After(0.5, function()
            if GetInventoryItemID("player", backSlotID) == cloakID then
                print(CCU_PREFIX .. cloakName .. L.CLOAK_EQUIPPED)

                local itemLink = select(2, GetItemInfo(cloakID))
                secureButton:SetAttribute("type", "item")
                secureButton:SetAttribute("item", itemLink)
                secureButton:SetNormalTexture(GetItemIcon(cloakID))
                secureButton:Show()
            else
                print(CCU_PREFIX .. L.FAILED_EQUIP)
                EquipItemByName(cloakID)

                -- Second delayed check after retrying
                C_Timer.After(0.5, function()
                    if GetInventoryItemID("player", backSlotID) == cloakID then
                        print(CCU_PREFIX .. L.SUCCESS_EQUIP)
                        secureButton:Show()
                    else
                        print(CCU_PREFIX .. L.FINAL_FAILED_EQUIP)
                        secureButton:Hide() -- Hide button if final equip failed
                    end
                end)
            end
        end)
    else
        print(CCU_PREFIX .. L.FAILED_EQUIP_NO_EXIST)
        ccuActive = false -- Reset state if item does not exist
        secureButton:Hide() -- Ensure button is hidden if cloak doesn't exist
    end
end

-- Slash command to trigger cloak use
local function HandleCloakUse()
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    if reequipping then
        print(CCU_PREFIX .. L.CLOAK_IN_PROGRESS)
        return
    end
    
    ccuActive = true -- Enable script processing
    originalCloak = nil

    SaveOriginalCloak()
    
    local cloakID, cloakName = GetAvailableCloakID()
    if cloakID then
        EquipAndUseCloak(cloakID, cloakName)
    else
        print(CCU_PREFIX .. L.NO_USABLE_CLOAK)
        ccuActive = false -- Reset state if no cloak is usable
        secureButton:Hide() -- Hide button if no cloak is usable
    end
end

-- Register events and initialize
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        SLASH_CCU1 = "/ccu"
        SlashCmdList["CCU"] = HandleCloakUse
        CreateSecureButton()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if reequipping then
            print(CCU_PREFIX .. "Manual cloak change detected. Resetting re-equipping.")
            reequipping = false
            ccuActive = false
            secureButton:Hide() -- Hide the button when cloak is manually changed
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if reequipping then
            ReequipOriginalCloak()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if reequipping then
            ReequipOriginalCloak()
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
end)
