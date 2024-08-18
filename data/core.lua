-- core.lua

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

local originalCloak = nil
local reequipping = false
local isHandlingCloak = false
local secureButton = nil

-- List of all relevant cloak item IDs
local cloakIDs = {
    65274, -- Universal Cloak of Coordination
    65360, -- Horde Cloak of Coordination
    65361, -- Alliance Cloak of Coordination
    63206, -- Alliance Wrap of Unity
    63207, -- Horde Wrap of Unity
}

-- Function to ensure the original cloak is saved before equipping a new one
local function EnsureOriginalCloakSaved()
    if not originalCloak then
        local slotID = GetInventorySlotInfo("BackSlot")
        originalCloak = GetInventoryItemID("player", slotID)
        if originalCloak then
            print("Original cloak ID saved: " .. originalCloak)
        else
            print("No original cloak found to save.")
        end
    end
end

-- Function to get the first available cloak ID
local function GetAvailableCloakID()
    for _, id in ipairs(cloakIDs) do
        if GetItemCount(id) > 0 then
            return id -- Return the first available cloak ID
        end
    end
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
    secureButton:Hide()
end

-- Function to equip the cloak and show the button for use
local function EquipAndUseCloak(cloakID)
    EnsureOriginalCloakSaved()
    isHandlingCloak = true  -- Begin handling cloak

    -- Equip the Cloak of Coordination using item ID
    EquipItemByName(cloakID)

    -- Set the button attributes and show it
    C_Timer.After(1.5, function()
        local backSlotID = GetInventorySlotInfo("BackSlot")
        if GetInventoryItemID("player", backSlotID) == cloakID then
            print("Cloak equipped. Please click the button to use it.")
            
            -- Use the item link instead of the item ID
            local itemLink = select(2, GetItemInfo(cloakID))
            secureButton:SetAttribute("type", "item")
            secureButton:SetAttribute("item", itemLink)
            secureButton:SetNormalTexture(GetItemIcon(cloakID))
            secureButton:Show()
        else
            print("Failed to equip the cloak. Retrying...")
            EquipItemByName(cloakID) -- Retry equipping the cloak
        end
        isHandlingCloak = false  -- Done handling cloak
    end)
end

-- Function to handle cloak use and re-equip the original cloak
local function OnCloakUsed()
    secureButton:Hide()
    reequipping = true

    -- Countdown to re-equip original cloak
    local secondsRemaining = 11
    C_Timer.NewTicker(1, function(ticker)
        if secondsRemaining > 0 then
            print("Re-equipping original cloak in " .. secondsRemaining .. " seconds...")
            secondsRemaining = secondsRemaining - 1
        else
            ticker:Cancel() -- Stop the timer
            if originalCloak then
                EquipItemByName(originalCloak)
                print("Re-equipping original cloak now.")
                originalCloak = nil -- Clear original cloak after re-equipping
            else
                print("No original cloak to re-equip.")
            end
            reequipping = false
        end
    end, secondsRemaining + 1)
end

-- Slash command to trigger cloak use
local function HandleCloakUse()
    local cloakID = GetAvailableCloakID()
    if cloakID then
        EquipAndUseCloak(cloakID)
    else
        print("No Cloak of Coordination or Wrap of Unity found.")
    end
end

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Register the slash command
        SLASH_EQUIPCOORD1 = "/equipcoord"
        SlashCmdList["EQUIPCOORD"] = HandleCloakUse

        -- Create the secure button
        CreateSecureButton()

        -- Set the button's post-click action
        secureButton:SetScript("PostClick", OnCloakUsed)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if not reequipping and not isHandlingCloak then
            originalCloak = nil -- Only reset if not re-equipping or handling the cloak
        end
    end
end)
