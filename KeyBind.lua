-- Hover key binding, like Bartender's /kb: while it's on, hover a button
-- on the bar and press a key (with Shift, Ctrl or Alt if you like) to bind
-- it to that button. Escape over a button clears its key; Done, or Escape
-- elsewhere, ends it. Key bindings can't change in combat, so a fight ends it.

local ADDON_NAME, ns = ...
local L = ns.L
local C = ns.C

local panel -- the little box with the instructions and Done
local overlays = {} -- one per button on the bar while binding (reused)

-- One frame takes the key presses, and binds to the overlay under the
-- mouse at that moment: an overlay of its own per button could miss the
-- mouse leaving when the bar is laid out again, and bind the wrong one.
local catcher = CreateFrame("Frame", nil, UIParent)
catcher:Hide()

local function HoveredOverlay()
    for _, overlay in ipairs(overlays) do
        if overlay:IsShown() and overlay:IsMouseOver() then return overlay end
    end
end

-- Keys that are only modifiers: they wait for the real key.
local MODIFIERS = {
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
    LMETA = true, RMETA = true, UNKNOWN = true,
}

local function Command(button)
    return "CLICK " .. button:GetName() .. ":LeftButton"
end

local function KeyText(button)
    local key = GetBindingKey(Command(button))
    return key and (GetBindingText and GetBindingText(key) or key) or L["no key"]
end

-- The key as the game writes bindings: modifiers first, e.g. "SHIFT-F".
local function WithModifiers(key)
    local prefix = ""
    if IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then prefix = prefix .. "META-" end
    return prefix .. key
end

local function Save()
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
end

local function ShowTooltip(overlay)
    local button = overlay.button
    GameTooltip:SetOwner(overlay, "ANCHOR_TOP")
    GameTooltip:SetText(button.kind.name, 1, 1, 1)
    GameTooltip:AddLine(L["Key: %s"]:format(KeyText(button)), C.accent[1], C.accent[2], C.accent[3])
    GameTooltip:AddLine(L["Press a key to bind it. Escape clears the key."], 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

-- Binds key to the overlay's button, in place of its old key. A key that
-- did something else before is taken over, and chat says what it was.
local function Bind(overlay, key)
    if InCombatLockdown() then return end
    local button = overlay.button
    local command = Command(button)
    for _, old in ipairs({ GetBindingKey(command) }) do SetBinding(old, nil) end
    if key then
        local previous = GetBindingAction(key)
        if previous and previous ~= "" and previous ~= command then
            local what = _G["BINDING_NAME_" .. previous] or previous
            ns.Print(L["%s was bound to %s; now it's %s."], GetBindingText and GetBindingText(key) or key, what,
                button.kind.name)
        end
        SetBinding(key, command)
    end
    Save()
    overlay.key:SetText(GetBindingKey(command) and ns.ShortKey(GetBindingKey(command)) or "")
    ShowTooltip(overlay)
end

local function CreateOverlay()
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:RegisterForClicks("AnyUp")
    local tint = overlay:CreateTexture(nil, "BACKGROUND")
    tint:SetAllPoints()
    tint:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.35)
    overlay.tint = tint
    overlay.key = ns.Text(overlay, 12, C.white, "OVERLAY")
    overlay.key:SetPoint("CENTER")

    overlay:SetScript("OnEnter", function(self)
        self.tint:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7)
        if not InCombatLockdown() then
            catcher:EnableKeyboard(true)
            catcher:SetPropagateKeyboardInput(false) -- every key binds while over a button
        end
        ShowTooltip(self)
    end)
    overlay:SetScript("OnLeave", function(self)
        self.tint:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.35)
        if not HoveredOverlay() and not InCombatLockdown() then catcher:EnableKeyboard(false) end
        GameTooltip:Hide()
    end)
    -- Mouse buttons and the wheel can be bound too (not left and right).
    overlay:SetScript("OnClick", function(self, mouseButton)
        local keys = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }
        if keys[mouseButton] then Bind(self, WithModifiers(keys[mouseButton])) end
    end)
    overlay:EnableMouseWheel(true)
    overlay:SetScript("OnMouseWheel", function(self, delta)
        Bind(self, WithModifiers(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"))
    end)
    return overlay
end

catcher:SetScript("OnKeyDown", function(self, key)
    local overlay = HoveredOverlay()
    if not overlay then
        -- The mouse left without the overlay noticing: let keys through again.
        self:SetPropagateKeyboardInput(true)
        self:EnableKeyboard(false)
        return
    end
    if MODIFIERS[key] then return end
    if key == "ESCAPE" then
        Bind(overlay, nil)
    else
        Bind(overlay, WithModifiers(key))
    end
end)

local function CreatePanel()
    panel = CreateFrame("Frame", "FannyPackKeyBind", UIParent)
    panel:SetSize(340, 120)
    panel:SetPoint("TOP", 0, -140)
    panel:SetFrameStrata("DIALOG")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    ns.Rounded(panel, "BACKGROUND", C.bg)
    ns.Rounded(panel, "BORDER", C.accent, "rounded-border")
    tinsert(UISpecialFrames, "FannyPackKeyBind") -- Escape away from the buttons ends it

    local title = ns.Text(panel, 14, C.text)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(L["Bind keys"])
    local text = ns.Text(panel, 12, C.muted)
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    text:SetWidth(340 - 32)
    text:SetText(L["Hover a button on the bar and press a key, with Shift, Ctrl or Alt if you like. Escape over a button clears its key."])

    local done = ns.CreateButton(panel, L["Done"], 80, "primary")
    done:SetHeight(26)
    done:SetPoint("BOTTOMRIGHT", -12, 12)
    done:SetScript("OnClick", function() ns.StopKeyBinding() end)
    local game = ns.CreateButton(panel, L["Game's Key Bindings"], 150)
    game:SetHeight(26)
    game:SetPoint("RIGHT", done, "LEFT", -8, 0)
    game:SetScript("OnClick", function()
        ns.StopKeyBinding()
        ns.OpenKeyBindings()
    end)
    panel:SetScript("OnHide", function() ns.StopKeyBinding() end)
end

-- Starts binding: an overlay on every button on the bar now.
function ns.StartKeyBinding()
    if InCombatLockdown() then
        ns.Refuse(L["You can't change key bindings in combat."])
        return
    end
    if not panel then CreatePanel() end
    local i = 0
    for _, button in ipairs(ns.ShownButtons()) do
        i = i + 1
        local overlay = overlays[i] or CreateOverlay()
        overlays[i] = overlay
        overlay.button = button
        overlay:ClearAllPoints()
        overlay:SetAllPoints(button)
        local key = GetBindingKey(Command(button))
        overlay.key:SetText(key and ns.ShortKey(key) or "")
        overlay:Show()
    end
    for j = i + 1, #overlays do overlays[j]:Hide() end
    for _, overlay in ipairs(overlays) do overlay.tint:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.35) end
    local hovered = HoveredOverlay()
    if hovered then hovered.tint:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.7) end
    catcher:Show()
    panel:Show()
end

function ns.StopKeyBinding()
    if not InCombatLockdown() then
        catcher:SetPropagateKeyboardInput(true)
        catcher:EnableKeyboard(false)
    end
    catcher:Hide()
    for _, overlay in ipairs(overlays) do overlay:Hide() end
    if panel and panel:IsShown() then panel:Hide() end
end

function ns.KeyBindingShowing()
    return panel ~= nil and panel:IsShown()
end

-- A fight ends it: bindings can't change then.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function() ns.StopKeyBinding() end)
