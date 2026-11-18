-- The first-time tour: four small speech bubbles beside the bar, each with
-- a pointer at what it explains. It starts by itself a few seconds after
-- the first login on a new install (never in combat), and /fannypack tour
-- or the Bar page's "Show the tour" plays it again.

local ADDON_NAME, ns = ...
local L = ns.L
local C = ns.C

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local WIDTH = 290
local PADDING = 16
local POINTER = 22 -- the pointer's size; it reaches about 14 out of the bubble

local function Bar() return ns.BarFrame and ns.BarFrame() end

local STEPS = {
    {
        title = L["This is your Fanny Pack"],
        text = L["Buttons for the bandages, potions, food and buffs you carry. A button appears as soon as you carry something for it."],
        target = Bar,
    },
    {
        title = L["Click to use"],
        text = L["Click a button to use its item. Right-click it to choose which item it uses, or to hide one you'd rather keep."],
        target = function() return ns.FirstShownButton() or Bar() end,
    },
    {
        title = L["Glows remind you"],
        text = L["A button glows gold when its buff is missing (buff food, elixirs, scrolls, weapon stones) and silver when it's running out."],
        target = function() return ns.GlowingButton() or ns.FirstShownButton() or Bar() end,
    },
    {
        title = L["Make it yours"],
        text = L["The bar follows your player frame. Unlock it in the options to place it anywhere, and choose its buttons, look and reminders. Type /fannypack to open them."],
        target = Bar,
        last = true,
    },
}

local bubble
local step -- the step showing, or the one to go on with after combat
local paused = false

local function Finish()
    step, paused = nil, false
    if bubble then bubble:Hide() end
    if ns.account then ns.account.tourDone = true end
end

local function CreateBubble()
    bubble = CreateFrame("Frame", "FannyPackTour", UIParent)
    bubble:SetFrameStrata("DIALOG")
    bubble:SetClampedToScreen(true)
    bubble:EnableMouse(true)
    bubble:SetWidth(WIDTH)
    ns.Rounded(bubble, "BACKGROUND", C.bg)
    -- A bright green border, two pixels wide, so the bubble stands out on
    -- any scenery.
    ns.Rounded(bubble, "BORDER", C.accent, "rounded-border")
    local inner = ns.Rounded(bubble, "BORDER", C.accent, "rounded-border")
    inner:ClearAllPoints()
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    bubble:Hide()
    tinsert(UISpecialFrames, "FannyPackTour") -- Escape skips the tour

    -- The pointer: dark, in a green outline (a bigger green one behind it).
    bubble.pointerEdge = bubble:CreateTexture(nil, "BORDER", nil, -1)
    bubble.pointerEdge:SetTexture(MEDIA .. "pointer")
    bubble.pointerEdge:SetSize(POINTER + 8, POINTER + 8)
    bubble.pointerEdge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1)
    bubble.pointer = bubble:CreateTexture(nil, "ARTWORK", nil, -8) -- over the border where they join
    bubble.pointer:SetTexture(MEDIA .. "pointer")
    bubble.pointer:SetSize(POINTER, POINTER)
    bubble.pointer:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)

    -- A thin green line on the left, like the options' cards.
    local accent = bubble:CreateTexture(nil, "ARTWORK")
    accent:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
    accent:SetSize(3, 14)
    accent:SetPoint("TOPLEFT", PADDING, -PADDING - 1)

    bubble.title = ns.Text(bubble, 14, C.text)
    bubble.title:SetPoint("TOPLEFT", PADDING + 10, -PADDING)
    bubble.counter = ns.Text(bubble, 11, C.muted)
    bubble.counter:SetPoint("TOPRIGHT", -PADDING, -PADDING - 2)
    bubble.text = ns.Text(bubble, 12, C.muted)
    bubble.text:SetPoint("TOPLEFT", bubble.title, "BOTTOMLEFT", -10, -8)
    bubble.text:SetWidth(WIDTH - PADDING * 2)

    bubble.next = ns.CreateButton(bubble, L["Next"], 80, "primary")
    bubble.next:SetHeight(26)
    bubble.next:SetPoint("BOTTOMRIGHT", -PADDING + 4, PADDING - 4)
    bubble.next:SetScript("OnClick", function()
        if STEPS[step].last then
            Finish()
        else
            ns.ShowTourStep(step + 1)
        end
    end)

    bubble.open = ns.CreateButton(bubble, L["Open options"], 110)
    bubble.open:SetHeight(26)
    bubble.open:SetPoint("RIGHT", bubble.next, "LEFT", -8, 0)
    bubble.open:SetScript("OnClick", function()
        Finish()
        ns.ToggleWindow(true)
    end)

    -- "Skip tour": a quiet link at the bottom left.
    bubble.skip = CreateFrame("Button", nil, bubble)
    bubble.skip.label = ns.Text(bubble.skip, 12, C.muted)
    bubble.skip.label:SetPoint("LEFT")
    bubble.skip.label:SetText(L["Skip tour"])
    bubble.skip:SetSize(bubble.skip.label:GetStringWidth() + 4, 20)
    bubble.skip:SetPoint("BOTTOMLEFT", PADDING, PADDING - 1)
    bubble.skip:SetScript("OnEnter", function(self) self.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
    bubble.skip:SetScript("OnLeave", function(self) self.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    bubble.skip:SetScript("OnClick", Finish)

    bubble:SetScript("OnHide", function()
        -- Escape, or hidden for a fight: Escape ends it, a fight pauses it.
        if not paused then
            step = nil
            if ns.account then ns.account.tourDone = true end
        end
    end)
end

-- Shows step i beside what it explains: above it when there's room, else
-- below, with the pointer at it.
function ns.ShowTourStep(i)
    local info = STEPS[i]
    local target = info and info.target()
    if not target then return Finish() end
    if not bubble then CreateBubble() end
    step = i

    bubble.title:SetText(info.title)
    bubble.counter:SetText(L["%d of %d"]:format(i, #STEPS))
    bubble.text:SetText(info.text)
    bubble.next.label:SetText(info.last and L["Done"] or L["Next"])
    bubble.open:SetShown(info.last or false)
    bubble.skip:SetShown(not info.last)
    bubble:SetHeight(PADDING + bubble.title:GetStringHeight() + 8 + bubble.text:GetStringHeight() + 14 + 26
        + PADDING - 4)

    local above = (target:GetTop() or 0) + bubble:GetHeight() + 30 < UIParent:GetTop()
    bubble:ClearAllPoints()
    bubble.pointer:ClearAllPoints()
    bubble.pointerEdge:ClearAllPoints()
    if above then
        bubble:SetPoint("BOTTOM", target, "TOP", 0, 20)
        bubble.pointer:SetTexCoord(0, 1, 0, 1) -- pointing down
        bubble.pointerEdge:SetTexCoord(0, 1, 0, 1)
        -- The dark pointer covers the border where they meet, so the
        -- bubble and its pointer read as one shape.
        bubble.pointer:SetPoint("TOP", bubble, "BOTTOM", 0, 2)
        bubble.pointerEdge:SetPoint("TOP", bubble, "BOTTOM", 0, 2)
    else
        bubble:SetPoint("TOP", target, "BOTTOM", 0, -20)
        bubble.pointer:SetTexCoord(0, 1, 1, 0) -- pointing up
        bubble.pointerEdge:SetTexCoord(0, 1, 1, 0)
        bubble.pointer:SetPoint("BOTTOM", bubble, "TOP", 0, -2)
        bubble.pointerEdge:SetPoint("BOTTOM", bubble, "TOP", 0, -2)
    end
    paused = false
    bubble:Show()
end

-- Starts the tour from its first step (after combat, if in a fight).
function ns.StartTour()
    if InCombatLockdown() then
        step, paused = 1, true
        return
    end
    ns.ShowTourStep(1)
end

function ns.TourShowing()
    return bubble ~= nil and bubble:IsShown()
end

-- At login: a new install gets the tour, a few seconds in.
function ns.InitTour()
    if not ns.freshInstall or ns.account.tourDone then return end
    C_Timer.After(5, ns.StartTour)
end

-- A fight pauses the tour; it goes on with the same step afterwards.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if bubble and bubble:IsShown() then
            paused = true
            bubble:Hide()
        end
    elseif paused and step then
        ns.ShowTourStep(step)
    end
end)
