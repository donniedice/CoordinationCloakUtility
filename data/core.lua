local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local originalCloak = nil
local reequipping = false
local secureButton = nil

local cloaks = {
    { id = 65274, name = "|cff9b59b6Cloak of Coordination|r" },
    { id = 65360, name = "|cff9b59b6Horde Cloak of Coordination|r" },
    { id = 65361, name = "|cff9b59b6Alliance Cloak of Coordination|r" },
    { id = 63206, name = "|cff3498dbAlliance Wrap of Unity|r" },
    { id = 63207, name = "|cff3498dbHorde Wrap of Unity|r" },
    { id = 63352, name = "|cff2ecc71Alliance Shroud of Cooperation|r" },
    { id = 63353, name = "|cff2ecc71Horde Shroud of Cooperation|r" },
}

local CCU_PREFIX = "|Tinterface/addons/CoordinationCloakUtility/images/icon:16:16|t - [|cffdd0064CCU|r] "

--=====================================================================================
-- Localization Strings
--=====================================================================================
local L = {
    WELCOME_MSG = string.format("%sWelcome! Use |cffdd0064/ccu help|r for commands.", "|cffffffff"),
    VERSION = string.format("%sVersion: |r", "|cffffff00"),
    ORIGINAL_CLOAK_SAVED = string.format("%sOriginal cloak saved: |r", "|cffffff00"),
    CLOAK_EQUIPPED = string.format("%s equipped. Click the button to use it.", "|cff00ff00"),
    CLOAK_ALREADY_EQUIPPED = string.format("%sCloak is already equipped. Ready to use.|r", "|cffffff00"),
    FAILED_EQUIP = string.format("%sFailed to equip the cloak. Retrying...|r", "|cffff0000"),
    SUCCESS_EQUIP = string.format("%sCloak successfully equipped after retry.|r", "|cff00ff00"),
    FINAL_FAILED_EQUIP = string.format("%sFailed to equip the cloak after retrying. Please try manually.|r", "|cffff0000"),
    REEQUIP_CLOAK = string.format("%sRe-equipping original cloak now: |r", "|cff00ff00"),
    NO_CLOAK_REEQUIP = string.format("%sNo original cloak to re-equip.|r", "|cffff0000"),
    HELP_COMMAND = string.format("%sAvailable commands:", "|cffffff00"),
    HELP_OPTION_PANEL = " |cffdd0064/ccu|r - Trigger the cloak utility.",
    HELP_WELCOME = " |cffdd0064/ccu welcome|r - Toggles the welcome message on/off.",
    HELP_HELP = " |cffdd0064/ccu help|r - Displays this help message.",
    UNKNOWN_COMMAND = string.format("%sUnknown command. Type %s/ccu help|r for a list of commands.", "|cffffcc00", CCU_PREFIX),
    CLOAK_ON_CD = string.format("%s is equipped but on cooldown.|r", "|cffff0000"),
    NO_USABLE_CLOAK = string.format("%sNo usable teleportation cloak found or all are on cooldown.|r", "|cffff0000"),
}

-- Version Number
local VersionNumber = string.format("%s%s|r", "|cff8080ff", C_AddOns.GetAddOnMetadata("CoordinationCloakUtility", "Version"))

-- Function to save the original cloak before equipping the teleportation cloak
local function SaveOriginalCloak()
    local slotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", slotID)

    if not originalCloak and equippedCloakID then
        for _, cloak in ipairs(cloaks) do
            if equippedCloakID == cloak.id then return end
        end
        originalCloak = equippedCloakID
        print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. string.format("%s%s|r", "|cff8080ff", GetItemInfo(originalCloak) or originalCloak))
    end
end

-- Function to get the first available cloak ID that is not on cooldown
local function GetAvailableCloakID()
    for _, cloak in ipairs(cloaks) do
        local start, duration = GetItemCooldown(cloak.id)
        if GetItemCount(cloak.id) > 0 then
            if duration == 0 then
                return cloak.id, cloak.name -- Return the first available cloak ID not on cooldown
            elseif GetInventoryItemID("player", GetInventorySlotInfo("BackSlot")) == cloak.id then
                print(CCU_PREFIX .. cloak.name .. L.CLOAK_ON_CD)
                return nil
            end
        end
    end
    print(CCU_PREFIX .. L.NO_USABLE_CLOAK)
    return nil
end

-- Function to handle re-equipping the original cloak
local function ReequipOriginalCloak()
    if originalCloak then
        EquipItemByName(originalCloak)
        print(CCU_PREFIX .. L.REEQUIP_CLOAK .. string.format("%s%s|r", "|cff8080ff", GetItemInfo(originalCloak) or originalCloak))

        -- Double check after 1.5 seconds to ensure the original cloak was re-equipped
        C_Timer.After(1.5, function()
            local backSlotID = GetInventorySlotInfo("BackSlot")
            if GetInventoryItemID("player", backSlotID) ~= originalCloak then
                EquipItemByName(originalCloak)
                print(CCU_PREFIX .. "|cffff0000Retrying to re-equip original cloak.|r")
                
                -- Third check after another 1.5 seconds
                C_Timer.After(1.5, function()
                    if GetInventoryItemID("player", backSlotID) ~= originalCloak then
                        EquipItemByName(originalCloak)
                        print(CCU_PREFIX .. "|cffff0000Final attempt to re-equip original cloak.|r")
                    else
                        print(CCU_PREFIX .. "|cff00ff00Original cloak re-equipped successfully.|r")
                        originalCloak = nil -- Clear original cloak after successful re-equipping
                        reequipping = false -- Reset reequipping flag
                    end
                end)
            else
                print(CCU_PREFIX .. "|cff00ff00Original cloak re-equipped successfully.|r")
                originalCloak = nil -- Clear original cloak after successful re-equipping
                reequipping = false -- Reset reequipping flag
            end
        end)
    else
        print(CCU_PREFIX .. L.NO_CLOAK_REEQUIP)
        reequipping = false -- Reset reequipping flag even if no original cloak
    end
    secureButton:Hide()  -- Ensure the button hides after re-equipping
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
        reequipping = true   -- Set reequipping flag to true
        -- Do not immediately re-equip, wait for PLAYER_LOGIN or PLAYER_ENTERING_WORLD event
    end)
    secureButton:Hide()
end

-- Function to equip the teleportation cloak and show the button for use
local function EquipAndUseCloak(cloakID, cloakName)
    SaveOriginalCloak()
    EquipItemByName(cloakID)

    -- Delayed check to verify if the cloak was successfully equipped
    C_Timer.After(0.5, function()
        local backSlotID = GetInventorySlotInfo("BackSlot")
        if GetInventoryItemID("player", backSlotID) == cloakID then
            print(CCU_PREFIX .. cloakName .. L.CLOAK_EQUIPPED)
            
            local itemLink = select(2, GetItemInfo(cloakID))
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(cloakID))
            secureButton:Show() -- Show the button for the user to click
        else
            print(CCU_PREFIX .. L.FAILED_EQUIP)
            EquipItemByName(cloakID)

            -- Second delayed check after retrying
            C_Timer.After(0.5, function()
                local backSlotID = GetInventorySlotInfo("BackSlot")
                if GetInventoryItemID("player", backSlotID) == cloakID then
                    print(CCU_PREFIX .. L.SUCCESS_EQUIP)
                else
                    print(CCU_PREFIX .. L.FINAL_FAILED_EQUIP)
                end
            end)
        end
    end)
end

-- Slash command to trigger cloak use
local function HandleCloakUse()
    if reequipping then
        print(CCU_PREFIX .. "|cffff0000Reequipping is already in progress. Please wait.|r")
        return
    end
    SaveOriginalCloak() -- Ensure the original cloak is saved before equipping
    local cloakID, cloakName = GetAvailableCloakID()
    if cloakID then
        EquipAndUseCloak(cloakID, cloakName)
    else
        print(CCU_PREFIX .. L.NO_USABLE_CLOAK)
    end
end

-- Toggle Welcome Message
local function ToggleWelcomeMessage()
    CCUDB.showWelcomeMessage = not CCUDB.showWelcomeMessage
    local status = CCUDB.showWelcomeMessage and CCU_PREFIX .. L.WELCOME_MSG_ENABLED or CCU_PREFIX .. L.WELCOME_MSG_DISABLED
   
    print(status)
end

local function DisplayHelp()
    print(CCU_PREFIX .. L.HELP_COMMAND)
    print(CCU_PREFIX .. L.HELP_OPTION_PANEL)
    print(CCU_PREFIX .. L.HELP_WELCOME)
    print(CCU_PREFIX .. L.HELP_HELP)
end

-- Handle Slash Commands
local function HandleSlashCommands(input)
    input = input:trim():lower()  -- Convert input to lowercase

    if input == "" then
        HandleCloakUse()  -- Trigger cloak use when `/ccu` is used without any additional input
    elseif input == "welcome" then
        ToggleWelcomeMessage()
    elseif input == "help" then
        DisplayHelp()
    else
        print(CCU_PREFIX .. L.UNKNOWN_COMMAND)
    end
end

-- Event Handlers
local function OnPlayerLogin()
    SLASH_CCU1 = "/ccu"
    SlashCmdList["CCU"] = HandleSlashCommands

    CreateSecureButton()

    -- Load the saved setting for the welcome message
    if CCUDB == nil then
        CCUDB = {}
    end

    if CCUDB.showWelcomeMessage == nil then
        CCUDB.showWelcomeMessage = true -- Default to showing the welcome message if not set
    end

    -- Login message
    if CCUDB.showWelcomeMessage then
        print(CCU_PREFIX .. L.WELCOME_MSG)
        print(CCU_PREFIX .. L.VERSION .. VersionNumber)
    end

    -- Attempt to re-equip the original cloak on login
    if reequipping then
        ReequipOriginalCloak()
    end
end

local function OnPlayerEnteringWorld()
    -- Backup attempt to re-equip the original cloak after loading screens
    if reequipping then
        ReequipOriginalCloak()
    end
end

local function OnPlayerEquipmentChanged()
    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    
    if equippedCloakID then
        for _, cloak in ipairs(cloaks) do
            if equippedCloakID == cloak.id then
                secureButton:Show()
                return
            end
        end
    end
    -- If no cloak is equipped or the equipped item is not in the cloaks list, hide the button
    secureButton:Hide()
end

-- Register events
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        OnPlayerEquipmentChanged()
    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld()
    end
end)
