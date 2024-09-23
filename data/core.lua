-- =====================================================================================
-- Coordination Cloak Utility Addon
-- =====================================================================================

-- Create the main frame and register events
local frame = CreateFrame("Frame")

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
<<<<<<< Updated upstream
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event when combat starts
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event when combat ends
=======
frame:RegisterEvent("PLAYER_REGEN_DISABLED")  -- Event when combat starts
frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- Event when combat ends
frame:RegisterEvent("BAG_UPDATE_DELAYED")     -- Handle inventory changes
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED") -- Handle item info loaded

-- =====================================================================================
-- Variables and Constants
-- =====================================================================================

-- Variables
local originalCloak = nil
local teleportInProgress = false
local waitingToReequip = false  -- Flag to indicate waiting to re-equip after loading screen
local secureButton = nil
local inCombat = false
local waitingForItemInfo = false
local pendingAction = nil
local ccuActive = false  -- State variable to control script execution
local cloaksInitializedOnLogin = false  -- Flag to track cloak initialization on login
local cloaksInitializedAfterTeleport = false  -- Flag to track cloak initialization after teleport
local reEquipAttempted = false  -- Flag to track re-equip attempt
local reEquipStartTime = nil    -- Timestamp when re-equip started
local reEquipTimeout = 5        -- Timeout duration in seconds

local cloaks = {65274, 65360, 65361, 63206, 63207, 63352, 63353} -- Teleportation cloak item IDs
local usableCloaks = {}  -- Table to store usable cloaks

-- Color codes
local colors = {
    prefix = "|cffdd0064",
    success = "|cff00ff00",
    error = "|cffff0000",
    highlight = "|cff8080ff",
    info = "|cffffff00",
    white = "|cffffffff",
    warning = "|cffffcc00",
}

local CCU_PREFIX = "|Tinterface/addons/CoordinationCloakUtility/images/icon:16:16|t - [" .. colors.prefix .. "CCU|r] "

-- =====================================================================================
-- Localization Strings
-- =====================================================================================

local L = {
    WELCOME_MSG = colors.white .. "Welcome! Use " .. colors.prefix .. "/ccu help|r for commands.",
    VERSION = colors.info .. "Version: |r",
    ORIGINAL_CLOAK_SAVED = colors.info .. "Original cloak saved: |r",
    CLOAK_EQUIPPED = colors.success .. " equipped. " .. colors.info .. "Click the button to use it.|r",
    CLOAK_ALREADY_EQUIPPED = colors.info .. "Cloak is already equipped. Ready to use.|r",
    FAILED_EQUIP = colors.error .. "Failed to equip the cloak. Retrying...|r",
    SUCCESS_EQUIP = colors.success .. "Cloak successfully equipped after retry.|r",
    FINAL_FAILED_EQUIP = colors.error .. "Failed to equip the cloak after retrying. Please try manually.|r",
    REEQUIP_CLOAK = colors.success .. "Re-equipping original cloak now: |r",
    REEQUIP_SUCCESS = colors.success .. "Successfully re-equipped original cloak: |r",
    REEQUIP_FAILED = colors.error .. "Failed to re-equip original cloak within the timeout period. Please check your inventory.|r",
    NO_CLOAK_REEQUIP = colors.error .. "No original cloak to re-equip.|r",
    HELP_COMMAND = colors.info .. "Available commands:",
    HELP_OPTION_PANEL = " " .. colors.prefix .. "/ccu|r - Trigger the cloak utility.",
    HELP_WELCOME = " " .. colors.prefix .. "/ccu welcome|r - Toggles the welcome message on/off.",
    HELP_HELP = " " .. colors.prefix .. "/ccu help|r - Displays this help message.",
    UNKNOWN_COMMAND = colors.warning .. "Unknown command. Type " .. colors.prefix .. "/ccu help|r for a list of commands.",
    CLOAK_ON_CD = colors.error .. "%s is on cooldown: %s" .. colors.info .. " remaining.|r",
    NO_USABLE_CLOAK = colors.error .. "No usable teleportation cloak found or all are on cooldown.|r",
    COMBAT_ACTIVE = colors.error .. "Combat is active. Please try again after leaving combat.|r",
    WELCOME_MSG_ENABLED = colors.success .. "Welcome message enabled.|r",
    WELCOME_MSG_DISABLED = colors.error .. "Welcome message disabled.|r",
    TELEPORTATION_IN_PROGRESS = colors.success .. "Teleportation in progress.|r",
    CLOAK_UNEQUIPPED = colors.info .. "Teleportation cloak unequipped.|r",
    HIDING_BUTTON = colors.info .. "Hiding button.|r",
    PROCESS_RESET = colors.info .. "Cloak usage process reset.|r",
}

-- Note: VersionNumber will be initialized after ADDON_LOADED event to avoid errors
local VersionNumber = ""

-- =====================================================================================
-- Utility Functions
-- =====================================================================================

-- Function to notify if combat is active
local function NotifyCombatLockdown()
    print(CCU_PREFIX .. L.COMBAT_ACTIVE)
end

-- Function to create the secure button for cloak usage
local function CreateSecureButton()
    secureButton = CreateFrame("Button", "CloakUseButton", UIParent, "SecureActionButtonTemplate")
    secureButton:SetSize(64, 64)
    secureButton:SetPoint("CENTER")
    secureButton:SetNormalFontObject("GameFontNormalLarge")
    secureButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    secureButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    secureButton:RegisterForClicks("AnyUp")
    secureButton:SetScript("PostClick", function()
        teleportInProgress = true
        print(CCU_PREFIX .. L.TELEPORTATION_IN_PROGRESS)
    end)
    secureButton:Hide() -- Button should be hidden by default
end

-- Function to format time in hours, minutes, and seconds with highlight and info colors
local function FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    local timeStr = ""
    if hours > 0 then
        timeStr = string.format("%s%d|r%s hr %s%02d|r%s min %s%02d|r%s sec", colors.highlight, hours, colors.info, colors.highlight, mins, colors.info, colors.highlight, secs, colors.info)
    elseif mins > 0 then
        timeStr = string.format("%s%d|r%s min %s%02d|r%s sec", colors.highlight, mins, colors.info, colors.highlight, secs, colors.info)
    else
        timeStr = string.format("%s%d|r%s sec", colors.highlight, secs, colors.info)
    end
    return timeStr
end

-- Function to update usable cloaks when inventory changes
local function UpdateUsableCloaks()
    usableCloaks = {}  -- Reset usableCloaks
    for _, cloakID in ipairs(cloaks) do
        if GetItemCount(cloakID) > 0 then
            local itemLink = select(2, GetItemInfo(cloakID))
            if itemLink then
                usableCloaks[cloakID] = itemLink
            else
                local item = Item:CreateFromItemID(cloakID)
                item:ContinueOnItemLoad(function()
                    usableCloaks[cloakID] = select(2, GetItemInfo(cloakID))
                    -- If we were waiting for item info, proceed
                    if waitingForItemInfo and pendingAction then
                        waitingForItemInfo = false
                        pendingAction()
                        pendingAction = nil
                    end
                end)
            end
        else
            usableCloaks[cloakID] = nil
        end
=======
    local timeStr = ""
    if hours > 0 then
        timeStr = string.format("%s%d|r%s hr %s%02d|r%s min %s%02d|r%s sec", colors.highlight, hours, colors.info, colors.highlight, mins, colors.info, colors.highlight, secs, colors.info)
    elseif mins > 0 then
        timeStr = string.format("%s%d|r%s min %s%02d|r%s sec", colors.highlight, mins, colors.info, colors.highlight, secs, colors.info)
    else
        timeStr = string.format("%s%d|r%s sec", colors.highlight, secs, colors.info)
>>>>>>> Stashed changes
    end
end

-- =====================================================================================
-- Core Functionality
-- =====================================================================================

-- Function to initialize and cache item info for cloaks (Initial Load)
local function InitializeCloaksOnLogin()
    cloaksInitializedOnLogin = false
    local pendingItems = #cloaks
    if pendingItems == 0 then
        cloaksInitializedOnLogin = true
        UpdateUsableCloaks()
        if waitingForItemInfo and pendingAction then
            waitingForItemInfo = false
            pendingAction()
            pendingAction = nil
        end
        return
    end

    for _, cloakID in ipairs(cloaks) do
        local item = Item:CreateFromItemID(cloakID)
        item:ContinueOnItemLoad(function()
            pendingItems = pendingItems - 1
            -- Check if the player has the cloak
            if GetItemCount(cloakID) > 0 then
                -- Store the cloak ID and link
                local itemLink = select(2, GetItemInfo(cloakID))
                usableCloaks[cloakID] = itemLink
                print("Initialized cloak on login:", cloakID, itemLink)
            end
            -- All cloaks have been initialized
            if pendingItems == 0 then
                cloaksInitializedOnLogin = true
                UpdateUsableCloaks()  -- Ensure usableCloaks is updated
                -- If we were waiting for cloaks to be initialized, proceed
                if waitingForItemInfo and pendingAction then
                    waitingForItemInfo = false
                    pendingAction()
                    pendingAction = nil
                end
            end
        end)
    end
end

-- Function to initialize and cache item info for cloaks (After Teleportation)
local function InitializeCloaksAfterTeleport()
    cloaksInitializedAfterTeleport = false
    local pendingItems = #cloaks
    if pendingItems == 0 then
        cloaksInitializedAfterTeleport = true
        UpdateUsableCloaks()
        if waitingForItemInfo and pendingAction then
            waitingForItemInfo = false
            pendingAction()
            pendingAction = nil
        end
        return
    end

    for _, cloakID in ipairs(cloaks) do
        local item = Item:CreateFromItemID(cloakID)
        item:ContinueOnItemLoad(function()
            pendingItems = pendingItems - 1
            -- Check if the player has the cloak
            if GetItemCount(cloakID) > 0 then
                -- Store the cloak ID and link
                local itemLink = select(2, GetItemInfo(cloakID))
                usableCloaks[cloakID] = itemLink
                print("Initialized cloak after teleport:", cloakID, itemLink)
            end
            -- All cloaks have been initialized
            if pendingItems == 0 then
                cloaksInitializedAfterTeleport = true
                UpdateUsableCloaks()  -- Ensure usableCloaks is updated
                -- If we were waiting for cloaks to be initialized, proceed
                if waitingForItemInfo and pendingAction then
                    waitingForItemInfo = false
                    pendingAction()
                    pendingAction = nil
                end
            end
        end)
    end
end

-- Function to toggle the welcome message
local function ToggleWelcomeMessage()
    CCUDB.showWelcomeMessage = not CCUDB.showWelcomeMessage
    local status = CCUDB.showWelcomeMessage and L.WELCOME_MSG_ENABLED or L.WELCOME_MSG_DISABLED
    print(CCU_PREFIX .. status)
end

-- Function to display the help message
local function DisplayHelp()
    print(CCU_PREFIX .. L.HELP_COMMAND)
    print(CCU_PREFIX .. L.HELP_OPTION_PANEL)
    print(CCU_PREFIX .. L.HELP_WELCOME)
    print(CCU_PREFIX .. L.HELP_HELP)
end

-- Function to handle changes in the back slot (cloak slot)
local function HandleBackSlotItem()
    if inCombat then return end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    print("HandleBackSlotItem - Equipped Cloak ID:", equippedCloakID)

    -- Check if a teleportation cloak is equipped
    if equippedCloakID and usableCloaks[equippedCloakID] then
        print("Teleportation cloak detected:", usableCloaks[equippedCloakID])
        -- Save original cloak if not already saved
        if not originalCloak then
            originalCloak = CCUDB.lastEquippedCloak or nil
            if originalCloak == equippedCloakID then
                originalCloak = nil  -- Avoid saving the teleportation cloak as the original cloak
            end
            if originalCloak then
                local originalCloakLink = select(2, GetItemInfo(originalCloak))
                print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. (originalCloakLink or "Unknown Cloak"))
            else
                print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. "No cloak equipped.")
            end
        end

        -- Check if the cloak is off cooldown
        local start, duration = GetItemCooldown(equippedCloakID)
        local remaining = math.ceil(start + duration - GetTime())
        local itemLink = usableCloaks[equippedCloakID]
        if duration == 0 then
            -- Cloak is off cooldown, show the button
            print(CCU_PREFIX .. itemLink .. L.CLOAK_EQUIPPED)
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(equippedCloakID))
            secureButton:Show()
            print("Secure button shown for cloak:", itemLink)
        else
            -- Cloak is on cooldown, hide the button
            local remainingTime = FormatTime(remaining)
            print(CCU_PREFIX .. string.format(L.CLOAK_ON_CD, itemLink, remainingTime))
            secureButton:Hide()
            print("Secure button hidden due to cooldown.")
        end

        return
    end

    -- No teleportation cloak equipped
    print(CCU_PREFIX .. L.CLOAK_UNEQUIPPED)
    if secureButton:IsShown() then
        secureButton:Hide()
        print("Secure button hidden as no teleportation cloak is equipped.")
    end
    teleportInProgress = false
end

-- Function to reset the cloak usage process
local function ResetCloakProcess()
    teleportInProgress = false
    originalCloak = nil
    reEquipAttempted = false
    reEquipStartTime = nil
    if secureButton:IsShown() then
        secureButton:Hide()
    end
    print(CCU_PREFIX .. L.PROCESS_RESET)
end

-- Function to re-equip the original cloak after teleportation
local function ReequipOriginalCloak()
    if not teleportInProgress then return end
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    print("ReequipOriginalCloak - Equipped Cloak ID:", equippedCloakID)

    if equippedCloakID == originalCloak or not originalCloak then
        if originalCloak then
            print(CCU_PREFIX .. colors.success .. "Original cloak is already equipped.|r")
        else
            print(CCU_PREFIX .. L.NO_CLOAK_REEQUIP)
        end
        ResetCloakProcess()
    else
        if IsPlayerInWorld() then
            if not reEquipAttempted then
                local originalCloakLink = select(2, GetItemInfo(originalCloak))
                if not originalCloakLink then
                    waitingForItemInfo = true
                    pendingAction = ReequipOriginalCloak
                    print("Waiting for item info to re-equip original cloak.")
                    return
                end
                EquipItemByName(originalCloak)
                print(CCU_PREFIX .. L.REEQUIP_CLOAK .. originalCloakLink)
                reEquipAttempted = true
                reEquipStartTime = GetTime()
                -- Register for equipment change event
                frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
                print("Attempting to re-equip original cloak.")
            else
                -- Check if timeout has been reached
                if GetTime() - reEquipStartTime >= reEquipTimeout then
                    print(CCU_PREFIX .. L.REEQUIP_FAILED)
                    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")  -- Unregister here
                    ResetCloakProcess()
                else
                    print("Re-equip attempt in progress. Timeout in:", reEquipTimeout - (GetTime() - reEquipStartTime), "seconds.")
                end
            end
        else
            -- Player is in loading screen, set flag to attempt re-equip after
            waitingToReequip = true
            print("Player is in loading screen. Will attempt to re-equip after loading.")
        end
    end
end

-- Function to get an available teleportation cloak
local function GetAvailableCloakID()
    if inCombat then
        NotifyCombatLockdown()
        return nil, nil
    end

    for cloakID, itemLink in pairs(usableCloaks) do
        -- Ensure item data is loaded
        if not GetItemInfo(cloakID) then
            waitingForItemInfo = true
            pendingAction = HandleCloakUse
            print("Item info not loaded for cloak ID:", cloakID)
            return nil, nil
        end

        local start, duration = GetItemCooldown(cloakID)
        local remaining = math.ceil(start + duration - GetTime())
        if duration == 0 then
            return cloakID, itemLink
        else
            local remainingTime = FormatTime(remaining)
            print(CCU_PREFIX .. string.format(L.CLOAK_ON_CD, itemLink, remainingTime))
        end
    end
    return nil, nil
end

-- Function to equip and prepare the teleportation cloak
local function EquipAndUseCloak(cloakID, cloakLink)
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    -- Check if the cloak is on cooldown before equipping
    local start, duration = GetItemCooldown(cloakID)
    local remaining = math.ceil(start + duration - GetTime())
    if duration > 0 then
        local remainingTime = FormatTime(remaining)
        print(CCU_PREFIX .. string.format(L.CLOAK_ON_CD, cloakLink, remainingTime))
        ccuActive = false
        return
    end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)

    -- Save the original cloak if not already saved
    if not originalCloak then
        originalCloak = equippedCloakID
        if originalCloak == cloakID then
            originalCloak = nil  -- Avoid saving the teleportation cloak as the original cloak
        end
        local originalCloakLink = originalCloak and select(2, GetItemInfo(originalCloak))
        CCUDB.lastEquippedCloak = originalCloak
        if originalCloakLink then
            print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. originalCloakLink)
        else
            print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. "No cloak equipped.")
        end
    end

    if equippedCloakID == cloakID then
        print(CCU_PREFIX .. L.CLOAK_ALREADY_EQUIPPED)
    else
        EquipItemByName(cloakID)
        print(CCU_PREFIX .. "Equipped teleportation cloak:", cloakID, cloakLink)
    end

    -- Set up and show the secure button
    secureButton:SetAttribute("type", "item")
    secureButton:SetAttribute("item", cloakLink)
    secureButton:SetNormalTexture(GetItemIcon(cloakID))
    secureButton:Show()
    print("Secure button shown for cloak:", cloakLink)
end

-- =====================================================================================
-- Command Handler
-- =====================================================================================

-- Handler for the /ccu command
local function HandleCloakUse()
    if inCombat then
        NotifyCombatLockdown()
        return
    end

    -- Check if cloaks are initialized (on login or after teleport)
    if not (cloaksInitializedOnLogin or cloaksInitializedAfterTeleport) then
        waitingForItemInfo = true
        pendingAction = HandleCloakUse
        print("Cloaks not initialized yet. Waiting for item info.")
        return
    end

    -- Check if usableCloaks is empty
    local hasUsableCloak = false
    for _, _ in pairs(usableCloaks) do
        hasUsableCloak = true
        break
    end

    if not hasUsableCloak then
        print(CCU_PREFIX .. L.NO_USABLE_CLOAK)
        return
    end

    ccuActive = true  -- Enable script processing

    -- Get an available cloak
    local cloakID, cloakLink = GetAvailableCloakID()
    if cloakID then
        EquipAndUseCloak(cloakID, cloakLink)
    else
        -- Do not print the error message here as it may be due to item info not being available
        ccuActive = false  -- Reset state if no cloak is usable
    end
end

-- Function to handle slash commands
local function HandleSlashCommands(input)
    input = input:trim():lower()

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    print("HandleBackSlotItem - Equipped Cloak ID:", equippedCloakID)

    -- Check if a teleportation cloak is equipped
    if equippedCloakID and usableCloaks[equippedCloakID] then
        print("Teleportation cloak detected:", usableCloaks[equippedCloakID])
        -- Save original cloak if not already saved
        if not originalCloak then
            originalCloak = CCUDB.lastEquippedCloak or nil
            if originalCloak == equippedCloakID then
                originalCloak = nil  -- Avoid saving the teleportation cloak as the original cloak
            end
            if originalCloak then
                local originalCloakLink = select(2, GetItemInfo(originalCloak))
                print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. (originalCloakLink or "Unknown Cloak"))
            else
                print(CCU_PREFIX .. L.ORIGINAL_CLOAK_SAVED .. "No cloak equipped.")
            end
        end

        -- Check if the cloak is off cooldown
        local start, duration = GetItemCooldown(equippedCloakID)
        local remaining = math.ceil(start + duration - GetTime())
        local itemLink = usableCloaks[equippedCloakID]
        if duration == 0 then
            -- Cloak is off cooldown, show the button
            print(CCU_PREFIX .. itemLink .. L.CLOAK_EQUIPPED)
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(equippedCloakID))
            secureButton:Show()
            print("Secure button shown for cloak:", itemLink)
        else
            -- Cloak is on cooldown, hide the button
            local remainingTime = FormatTime(remaining)
            print(CCU_PREFIX .. string.format(L.CLOAK_ON_CD, itemLink, remainingTime))
            secureButton:Hide()
            print("Secure button hidden due to cooldown.")
        end

        return
    end

    -- No teleportation cloak equipped
    print(CCU_PREFIX .. L.CLOAK_UNEQUIPPED)
    if secureButton:IsShown() then
        secureButton:Hide()
        print("Secure button hidden as no teleportation cloak is equipped.")
    end
    teleportInProgress = false
end

-- =====================================================================================
-- Event Handling
-- =====================================================================================

-- Function to handle re-equip after a delay
local function AttemptReequipAfterDelay()
    InitializeCloaksAfterTeleport()
    print("Attempting to re-equip original cloak after delay.")
end

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "CoordinationCloakUtility" then
            print("CoordinationCloakUtility addon loaded successfully.")
            CreateSecureButton()
            -- Initialize VersionNumber using the original GetAddOnMetadata
            if GetAddOnMetadata then
                local version = GetAddOnMetadata("CoordinationCloakUtility", "Version")
                if version then
                    VersionNumber = colors.highlight .. version .. "|r"
                    print("Addon version:", VersionNumber)
                else
                    print("Version metadata not found.")
                    VersionNumber = "Unknown"
                end
            else
                print("Error: GetAddOnMetadata is not available.")
                VersionNumber = "Unknown"
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize slash command
        SLASH_CCU1 = "/ccu"
        SlashCmdList["CCU"] = HandleSlashCommands

        -- Initialize database
        if CCUDB == nil then
            CCUDB = {}
        end

        if CCUDB.showWelcomeMessage == nil then
            CCUDB.showWelcomeMessage = true
        end

        if CCUDB.showWelcomeMessage then
            print(CCU_PREFIX .. L.WELCOME_MSG)
            print(CCU_PREFIX .. L.VERSION .. VersionNumber)
        end

        InitializeCloaksOnLogin()  -- Ensure cloaks are initialized on login
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeCloaksOnLogin()  -- Ensure cloaks are initialized when entering the world

        if waitingToReequip and teleportInProgress then
            -- Add a 5-second delay before attempting to re-equip
            C_Timer.After(5, AttemptReequipAfterDelay)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotID == GetInventorySlotInfo("BackSlot") then
            local backSlotID = GetInventorySlotInfo("BackSlot")
            local equippedCloakID = GetInventoryItemID("player", backSlotID)

            -- Save the last equipped cloak if a non-teleportation cloak is equipped
            if not (equippedCloakID and usableCloaks[equippedCloakID]) then
                CCUDB.lastEquippedCloak = equippedCloakID
                if not teleportInProgress then
                    originalCloak = nil  -- Reset original cloak if not teleporting
                end
            end

            -- Call HandleBackSlotItem() once at the end
            HandleBackSlotItem()

            if reEquipAttempted and originalCloak then
                equippedCloakID = GetInventoryItemID("player", backSlotID)
                if equippedCloakID == originalCloak then
                    local originalCloakLink = select(2, GetItemInfo(originalCloak))
                    print(CCU_PREFIX .. L.REEQUIP_SUCCESS .. (originalCloakLink or "Unknown Cloak"))
                    ResetCloakProcess()
                    -- Unregister the event after re-equipping
                    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
                end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        secureButton:Hide()
        print("Entered combat. Secure button hidden.")
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        HandleBackSlotItem()
        print("Left combat. Re-evaluating cloak status.")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if waitingForItemInfo and pendingAction then
            waitingForItemInfo = false
            pendingAction()
            pendingAction = nil
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        UpdateUsableCloaks()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and teleportInProgress then
            -- Attempt to re-equip immediately
            ReequipOriginalCloak()
        end
    end
end)
