-- =====================================================================================
-- CCU | Coordination Cloak Utility Addon - core.lua
-- =====================================================================================

local CCU = {} -- Main addon table

-- Create the main frame and register events
local frame = CreateFrame("Frame")
CCU.frame = frame

-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Event when combat starts
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Event when combat ends
frame:RegisterEvent("BAG_UPDATE_DELAYED")     -- Handle inventory changes
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED") -- Handle item info loaded

-- =====================================================================================
-- Variables and Constants
-- =====================================================================================

-- Variables
CCU.originalCloak = nil
CCU.teleportInProgress = false
CCU.waitingToReequip = false -- Flag to indicate waiting to re-equip after loading screen
CCU.inCombat = false
CCU.waitingForItemInfo = false
CCU.pendingAction = nil
CCU.cloaksInitialized = false -- Flag to track cloak initialization
CCU.reEquipAttempted = false -- Flag to track re-equip attempt
CCU.reEquipStartTime = nil     -- Timestamp when re-equip started
CCU.reEquipTimeout = 10         -- Timeout duration in seconds
CCU.reEquipMaxRetries = 3       -- Maximum number of re-equip retries

CCU.currentCloakID = nil -- Current equipped cloak ID
CCU.lastNonTeleportationCloakID = nil -- Last non-teleportation cloak ID

CCU.cloaks = {65274, 65360, 65361, 63206, 63207, 63352, 63353} -- Teleportation cloak item IDs
CCU.usableCloaks = {} -- Table to store usable cloaks

-- Color codes
CCU.colors = {
    prefix = "|cffdd0064",
    success = "|cff00ff00",
    error = "|cffff0000",
    highlight = "|cff8080ff",
    info = "|cffffff00",
    white = "|cffffffff",
    warning = "|cffffcc00",
}

CCU.CCU_PREFIX = "|Tinterface/addons/CoordinationCloakUtility/images/icon:16:16|t - [" .. CCU.colors.prefix .. "CCU|r] "

-- =====================================================================================
-- Localization Strings
-- =====================================================================================

CCU.L = {
    WELCOME_MSG = CCU.colors.white .. "Welcome! Use " .. CCU.colors.prefix .. "/ccu help|r for commands.",
    VERSION = CCU.colors.info .. "Version: |r",
    ORIGINAL_CLOAK_SAVED = CCU.colors.info .. "Original cloak saved: |r",
    CLOAK_EQUIPPED = CCU.colors.success .. " equipped. " .. CCU.colors.info .. "Click the button to use it.|r",
    CLOAK_ALREADY_EQUIPPED = CCU.colors.info .. "Cloak is already equipped. Ready to use.|r",
    FAILED_EQUIP = CCU.colors.error .. "Failed to equip the cloak. Retrying...|r",
    SUCCESS_EQUIP = CCU.colors.success .. "Cloak successfully equipped after retry.|r",
    FINAL_FAILED_EQUIP = CCU.colors.error .. "Failed to equip the cloak after retrying. Please try manually.|r",
    REEQUIP_CLOAK = CCU.colors.success .. "Re-equipping original cloak now: |r",
    REEQUIP_SUCCESS = CCU.colors.success .. "Successfully re-equipped original cloak: |r",
    REEQUIP_FAILED = CCU.colors.error .. "Failed to re-equip original cloak within the timeout period. Please check your inventory.|r",
    NO_CLOAK_REEQUIP = CCU.colors.error .. "No original cloak to re-equip.|r",
    HELP_COMMAND = CCU.colors.info .. "Available commands:",
    HELP_OPTION_PANEL = " " .. CCU.colors.prefix .. "/ccu|r - Trigger the cloak utility.",
    HELP_WELCOME = " " .. CCU.colors.prefix .. "/ccu welcome|r - Toggles the welcome message on/off.",
    HELP_HELP = " " .. CCU.colors.prefix .. "/ccu help|r - Displays this help message.",
    UNKNOWN_COMMAND = CCU.colors.warning .. "Unknown command. Type " .. CCU.colors.prefix .. "/ccu help|r for a list of commands.",
    CLOAK_ON_CD = CCU.colors.error .. "%s is on cooldown: %s" .. CCU.colors.info .. " remaining.|r",
    NO_USABLE_CLOAK = CCU.colors.error .. "No usable teleportation cloak found or all are on cooldown.|r",
    COMBAT_ACTIVE = CCU.colors.error .. "Combat is active. Please try again after leaving combat.|r",
    WELCOME_MSG_ENABLED = CCU.colors.success .. "Welcome message enabled.|r",
    WELCOME_MSG_DISABLED = CCU.colors.error .. "Welcome message disabled.|r",
    TELEPORTATION_IN_PROGRESS = CCU.colors.success .. "Teleportation in progress.|r",
    CLOAK_UNEQUIPPED = CCU.colors.info .. "Teleportation cloak unequipped.|r",
    HIDING_BUTTON = CCU.colors.info .. "Hiding button.|r",
    PROCESS_RESET = CCU.colors.info .. "Cloak usage process reset.|r",
}

-- Note: VersionNumber will be initialized after ADDON_LOADED event to avoid errors
CCU.VersionNumber = ""

-- =====================================================================================
-- Utility Functions
-- =====================================================================================

-- Function to notify if combat is active
function CCU:NotifyCombatLockdown()
    print(CCU.CCU_PREFIX .. CCU.L.COMBAT_ACTIVE)
end

-- Function to create the secure button for cloak usage
function CCU:CreateSecureButton()
    if InCombatLockdown() then return end

    self.secureButton = CreateFrame("Button", "CCU_CloakUseButton", UIParent, "SecureActionButtonTemplate")
    local button = self.secureButton
    button:SetSize(64, 64)
    button:SetPoint("CENTER")
    button:SetNormalFontObject("GameFontNormalLarge")
    button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    button:RegisterForClicks("AnyUp")
    button:SetScript("PostClick", function()
        CCU.teleportInProgress = true
        print(CCU.CCU_PREFIX .. CCU.L.TELEPORTATION_IN_PROGRESS)
    end)
    button:Hide()
end

-- Function to format time in hours, minutes, and seconds with highlight and info colors
function CCU:FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    local timeStr = ""
    if hours > 0 then
        timeStr = string.format("%s%d|r%s hr %s%02d|r%s min %s%02d|r%s sec", self.colors.highlight, hours, self.colors.info, self.colors.highlight, mins, self.colors.info, self.colors.highlight, secs, self.colors.info)
    elseif mins > 0 then
        timeStr = string.format("%s%d|r%s min %s%02d|r%s sec", self.colors.highlight, mins, self.colors.info, self.colors.highlight, secs, self.colors.info)
    else
        timeStr = string.format("%s%d|r%s sec", self.colors.highlight, secs, self.colors.info)
    end
    return timeStr
end

-- Function to update usable cloaks when inventory changes
function CCU:UpdateUsableCloaks()
    self.usableCloaks = {} -- Reset usableCloaks
    local pendingItems = 0
    for _, cloakID in ipairs(self.cloaks) do
        if GetItemCount(cloakID) > 0 then
            local itemLink = select(2, GetItemInfo(cloakID))
            if itemLink then
                self.usableCloaks[cloakID] = itemLink
            else
                pendingItems = pendingItems + 1
                local item = Item:CreateFromItemID(cloakID)
                item:ContinueOnItemLoad(function()
                    self.usableCloaks[cloakID] = select(2, GetItemInfo(cloakID))
                    pendingItems = pendingItems - 1
                    if pendingItems == 0 and self.waitingForItemInfo and self.pendingAction then
                        self.waitingForItemInfo = false
                        self.pendingAction()
                        self.pendingAction = nil
                    end
                end)
            end
        else
            self.usableCloaks[cloakID] = nil
        end
    end
    if pendingItems == 0 and self.waitingForItemInfo and self.pendingAction then
        self.waitingForItemInfo = false
        self.pendingAction()
        self.pendingAction = nil
    end
end

-- =====================================================================================
-- Core Functionality
-- =====================================================================================

-- Function to initialize and cache item info for cloaks
function CCU:InitializeCloaks()
    self.cloaksInitialized = false
    local pendingItems = #self.cloaks
    if pendingItems == 0 then
        self.cloaksInitialized = true
        self:UpdateUsableCloaks()
        return
    end

    for _, cloakID in ipairs(self.cloaks) do
        local item = Item:CreateFromItemID(cloakID)
        item:ContinueOnItemLoad(function()
            pendingItems = pendingItems - 1
            if GetItemCount(cloakID) > 0 then
                local itemLink = select(2, GetItemInfo(cloakID))
                self.usableCloaks[cloakID] = itemLink
            end
            if pendingItems == 0 then
                self.cloaksInitialized = true
                self:UpdateUsableCloaks()
                if self.waitingForItemInfo and self.pendingAction then
                    self.waitingForItemInfo = false
                    self.pendingAction()
                    self.pendingAction = nil
                end
            end
        end)
    end
end

-- Function to toggle the welcome message
function CCU:ToggleWelcomeMessage()
    CCUDB.showWelcomeMessage = not CCUDB.showWelcomeMessage
    local status = CCUDB.showWelcomeMessage and self.L.WELCOME_MSG_ENABLED or self.L.WELCOME_MSG_DISABLED
    print(self.CCU_PREFIX .. status)
end

-- Function to display the help message
function CCU:DisplayHelp()
    print(self.CCU_PREFIX .. self.L.HELP_COMMAND)
    print(self.CCU_PREFIX .. self.L.HELP_OPTION_PANEL)
    print(self.CCU_PREFIX .. self.L.HELP_WELCOME)
    print(self.CCU_PREFIX .. self.L.HELP_HELP)
end

-- Function to handle changes in the back slot (cloak slot)
function CCU:HandleBackSlotItem()
    if self.inCombat then return end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)
    self.currentCloakID = equippedCloakID

    -- Update lastNonTeleportationCloakID if a non-teleportation cloak is equipped
    if self.currentCloakID and not self.usableCloaks[self.currentCloakID] then
        self.lastNonTeleportationCloakID = self.currentCloakID
        CCUDB.lastEquippedCloak = self.currentCloakID
    elseif not self.currentCloakID then
        -- Cloak slot is empty
        self.lastNonTeleportationCloakID = nil
    end

    -- Check if a teleportation cloak is equipped
    if equippedCloakID and self.usableCloaks[equippedCloakID] then
        -- Always update originalCloak when a teleportation cloak is equipped
        self.originalCloak = self.lastNonTeleportationCloakID or nil
        if self.originalCloak and self.originalCloak ~= equippedCloakID then
            local originalCloakLink = select(2, GetItemInfo(self.originalCloak))
            print(self.CCU_PREFIX .. self.L.ORIGINAL_CLOAK_SAVED .. (originalCloakLink or "Unknown Cloak"))
        else
            print(self.CCU_PREFIX .. self.L.ORIGINAL_CLOAK_SAVED .. "No cloak equipped.")
        end

        -- Check if the cloak is off cooldown
        local start, duration = GetItemCooldown(equippedCloakID)
        local remaining = math.ceil(start + duration - GetTime())
        local itemLink = self.usableCloaks[equippedCloakID]

        if duration == 0 then
            -- Cloak is off cooldown, show the button
            print(self.CCU_PREFIX .. itemLink .. self.L.CLOAK_EQUIPPED)
            if not InCombatLockdown() then
                self.secureButton:SetAttribute("type", "item")
                self.secureButton:SetAttribute("item", itemLink)
                self.secureButton:SetNormalTexture(GetItemIcon(equippedCloakID))
                self.secureButton:Show()
            end
        else
            -- Cloak is on cooldown, hide the button
            local remainingTime = self:FormatTime(remaining)
            print(self.CCU_PREFIX .. string.format(self.L.CLOAK_ON_CD, itemLink, remainingTime))
            if not InCombatLockdown() then
                self.secureButton:Hide()
            end
        end

        return
    else
        -- No teleportation cloak equipped
        self.originalCloak = nil -- Reset original cloak if not teleporting

        if not InCombatLockdown() and self.secureButton:IsShown() then
            self.secureButton:Hide()
        end
    end
end

-- Function to reset the cloak usage process
function CCU:ResetCloakProcess()
    self.teleportInProgress = false
    self.originalCloak = nil -- Ensure originalCloak is reset
    self.reEquipAttempted = false
    self.reEquipStartTime = nil
    if not InCombatLockdown() and self.secureButton:IsShown() then
        self.secureButton:Hide()
    end
    print(self.CCU_PREFIX .. self.L.PROCESS_RESET)
    -- Call HandleBackSlotItem to re-evaluate current cloak state
    self:HandleBackSlotItem()
end

-- Function to re-equip the original cloak after teleportation
function CCU:ReequipOriginalCloak()
    if not self.teleportInProgress then return end
    if self.inCombat then
        self:NotifyCombatLockdown()
        return
    end

    -- If originalCloak is nil, we shouldn't proceed
    if not self.originalCloak then
        self:ResetCloakProcess()
        return
    end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)

    if equippedCloakID == self.originalCloak then
        print(self.CCU_PREFIX .. self.colors.success .. "Original cloak is already equipped.|r")
        self:ResetCloakProcess()
    else
        if IsPlayerInWorld() then
            if not self.reEquipAttempted then
                local originalCloakLink = select(2, GetItemInfo(self.originalCloak))
                if not originalCloakLink then
                    self.waitingForItemInfo = true
                    self.pendingAction = function() self:ReequipOriginalCloak() end
                    return
                end

                -- Attempt re-equip
                EquipItemByName(self.originalCloak)
                print(self.CCU_PREFIX .. self.L.REEQUIP_CLOAK .. originalCloakLink)
                self.reEquipAttempted = true
                self.reEquipStartTime = GetTime()

                frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
            else
                -- Check if timeout has been reached
                if GetTime() - self.reEquipStartTime >= self.reEquipTimeout then
                    print(self.CCU_PREFIX .. self.L.REEQUIP_FAILED)
                    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
                    self:ResetCloakProcess()
                end
            end
        else
            -- Player is in loading screen, set flag to attempt re-equip after
            self.waitingToReequip = true
        end
    end
end


-- Function to get an available teleportation cloak
function CCU:GetAvailableCloakID()
    if self.inCombat then
        self:NotifyCombatLockdown()
        return nil, nil
    end

    for cloakID, itemLink in pairs(self.usableCloaks) do
        -- Ensure item data is loaded
        if not GetItemInfo(cloakID) then
            self.waitingForItemInfo = true
            self.pendingAction = function() self:HandleCloakUse() end
            return nil, nil
        end

        local start, duration = GetItemCooldown(cloakID)
        local remaining = math.ceil(start + duration - GetTime())
        if duration == 0 then
            return cloakID, itemLink
        else
            local remainingTime = self:FormatTime(remaining)
            print(self.CCU_PREFIX .. string.format(self.L.CLOAK_ON_CD, itemLink, remainingTime))
        end
    end
    return nil, nil
end

-- Function to equip and prepare the teleportation cloak
function CCU:EquipAndUseCloak(cloakID, cloakLink)
    if self.inCombat then
        self:NotifyCombatLockdown()
        return
    end

    -- Check if the cloak is on cooldown before equipping
    local start, duration = GetItemCooldown(cloakID)
    local remaining = math.ceil(start + duration - GetTime())
    if duration > 0 then
        local remainingTime = self:FormatTime(remaining)
        print(self.CCU_PREFIX .. string.format(self.L.CLOAK_ON_CD, cloakLink, remainingTime))
        return
    end

    local backSlotID = GetInventorySlotInfo("BackSlot")
    local equippedCloakID = GetInventoryItemID("player", backSlotID)

    -- Save the original cloak
    self.originalCloak = self.lastNonTeleportationCloakID or CCUDB.lastEquippedCloak or nil
    if self.originalCloak == cloakID then
        self.originalCloak = nil -- Avoid saving the teleportation cloak as the original cloak
    end
    local originalCloakLink = self.originalCloak and select(2, GetItemInfo(self.originalCloak))
    CCUDB.lastEquippedCloak = self.originalCloak
    if originalCloakLink then
        print(self.CCU_PREFIX .. self.L.ORIGINAL_CLOAK_SAVED .. originalCloakLink)
    else
        print(self.CCU_PREFIX .. self.L.ORIGINAL_CLOAK_SAVED .. "No cloak equipped.")
    end

    if equippedCloakID == cloakID then
        print(self.CCU_PREFIX .. self.L.CLOAK_ALREADY_EQUIPPED)
    else
        EquipItemByName(cloakID)
    end

    -- Set up and show the secure button
    if not InCombatLockdown() then
        self.secureButton:SetAttribute("type", "item")
        self.secureButton:SetAttribute("item", cloakLink)
        self.secureButton:SetNormalTexture(GetItemIcon(cloakID))
        self.secureButton:Show()
    end
end

-- =====================================================================================
-- Command Handler
-- =====================================================================================

-- Handler for the /ccu command
function CCU:HandleCloakUse()
    if self.inCombat then
        self:NotifyCombatLockdown()
        return
    end

    -- Check if cloaks are initialized
    if not self.cloaksInitialized then
        self.waitingForItemInfo = true
        self.pendingAction = function() self:HandleCloakUse() end
        return
    end

    -- Check if usableCloaks is empty
    local hasUsableCloak = false
    for _, _ in pairs(self.usableCloaks) do
        hasUsableCloak = true
        break
    end

    if not hasUsableCloak then
        print(self.CCU_PREFIX .. self.L.NO_USABLE_CLOAK)
        return
    end

    -- Get an available cloak
    local cloakID, cloakLink = self:GetAvailableCloakID()
    if cloakID then
        self:EquipAndUseCloak(cloakID, cloakLink)
    end
end

-- Function to handle slash commands
function CCU:HandleSlashCommands(input)
    input = input:trim():lower()

    if self.inCombat then
        self:NotifyCombatLockdown()
        return
    end

    if input == "" then
        self:HandleCloakUse()
    elseif input == "welcome" then
        self:ToggleWelcomeMessage()
    elseif input == "help" then
        self:DisplayHelp()
    else
        print(self.CCU_PREFIX .. self.L.UNKNOWN_COMMAND)
    end
end

-- =====================================================================================
-- Event Handling
-- =====================================================================================

-- Function to handle re-equip after a delay
function CCU:AttemptReequipAfterDelay()
    self:InitializeCloaks()
    if self.teleportInProgress then
        self:ReequipOriginalCloak()
    end
end

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "CoordinationCloakUtility" then
            CCU:CreateSecureButton()
            -- Initialize VersionNumber using the provided string format
            CCU.VersionNumber = string.format("%s %s|r", "|cff8080ff", C_AddOns.GetAddOnMetadata("CoordinationCloakUtility", "Version"))
            -- print(CCU.CCU_PREFIX .. CCU.L.VERSION .. CCU.VersionNumber)
        end
    elseif event == "PLAYER_LOGIN" then
        -- Initialize slash command
        SLASH_CCU1 = "/ccu"
        SlashCmdList["CCU"] = function(input) CCU:HandleSlashCommands(input) end

        -- Initialize database
        if CCUDB == nil then
            CCUDB = {}
        end

        if CCUDB.showWelcomeMessage == nil then
            CCUDB.showWelcomeMessage = true
        end

        if CCUDB.showWelcomeMessage then
            print(CCU.CCU_PREFIX .. CCU.L.WELCOME_MSG)
            print(CCU.CCU_PREFIX .. CCU.L.VERSION .. CCU.VersionNumber)
        end

        CCU:InitializeCloaks()

        -- Initialize currentCloakID
        local backSlotID = GetInventorySlotInfo("BackSlot")
        CCU.currentCloakID = GetInventoryItemID("player", backSlotID)
    elseif event == "PLAYER_ENTERING_WORLD" then
        CCU:InitializeCloaks()

        if CCU.waitingToReequip and CCU.teleportInProgress then
            -- Add a 5-second delay before attempting to re-equip
            C_Timer.After(5, function() CCU:AttemptReequipAfterDelay() end)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotID == GetInventorySlotInfo("BackSlot") then
            CCU:HandleBackSlotItem()

            if CCU.reEquipAttempted and CCU.originalCloak then
                local backSlotID = GetInventorySlotInfo("BackSlot")
                local equippedCloakID = GetInventoryItemID("player", backSlotID)
                if equippedCloakID == CCU.originalCloak then
                    local originalCloakLink = select(2, GetItemInfo(CCU.originalCloak))
                    print(CCU.CCU_PREFIX .. CCU.L.REEQUIP_SUCCESS .. (originalCloakLink or "Unknown Cloak"))
                    CCU:ResetCloakProcess()
                    -- Unregister the event after re-equipping
                    frame:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
                end
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        CCU.inCombat = true
        if not InCombatLockdown() and CCU.secureButton then
            CCU.secureButton:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        CCU.inCombat = false
        CCU:HandleBackSlotItem()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        if CCU.waitingForItemInfo and CCU.pendingAction then
            CCU.waitingForItemInfo = false
            CCU.pendingAction()
            CCU.pendingAction = nil
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        CCU:UpdateUsableCloaks()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and CCU.teleportInProgress then
            -- Attempt to re-equip immediately
            CCU:ReequipOriginalCloak()
        end
    end
end)
