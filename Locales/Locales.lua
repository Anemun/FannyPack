-- Translations. All text the player sees goes through L["English text"];
-- anything without a translation for the client's language stays English.
--
-- To add a language: create Locales/<locale>.lua (for example deDE.lua)
-- that calls ns.AddTranslations("deDE", { ["English text"] = "..." }) and
-- list it in FannyPack.toc after this file.

local _, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, english) return english end,
})

-- Lower case for matching game text against the words above, also for
-- Cyrillic: the game's lower() only changes Latin letters, and Russian item
-- names start with a capital ("Эликсир..."). А-Я and Ё become а-я and ё.
function ns.Lower(text)
    text = text:lower()
    if not text:find("\208", 1, true) then return text end
    return (text:gsub("\208([\129\144-\175])", function(letter)
        local byte = letter:byte()
        if byte == 129 then return "\209\145" end -- Ё
        if byte <= 159 then return "\208" .. string.char(byte + 32) end -- А-П
        return "\209" .. string.char(byte - 32) -- Р-Я
    end))
end

-- Called by a translation file: { ["English text"] = "translated text" }.
-- Only applies when the game runs in that language.
function ns.AddTranslations(locale, translations)
    if GetLocale() ~= locale then return end
    for english, translated in pairs(translations) do
        if translated ~= "" then rawset(ns.L, english, translated) end
    end
end
