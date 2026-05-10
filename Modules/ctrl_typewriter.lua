-- =========================================================================
-- AERONAUTICS FLEET OS - TYPEWRITER INPUT MULTIPLEXER
-- =========================================================================
-- Standardized module to grab and parse raw input keycodes.
-- Designed to work alongside Create: Typewriter's "linked_typewriter" block.
-- =========================================================================

local tw = peripheral.find("linked_typewriter") or peripheral.find("typewriter")
if not tw then print("Warning: No typewriter found!") end

local specialKeys = {
    [32]  = "SPACE", [340] = "SHIFT", [341] = "CTRL", [258] = "TAB",
    [257] = "ENTER", [265] = "UP", [264] = "DOWN", [263] = "LEFT", [262] = "RIGHT"
}

return {
    getPressed = function()
        local state = {}
        if not tw then return state end
        local rawKeys = tw.getPressedKeyCodes()
        
        if type(rawKeys) == "table" then
            for _, code in ipairs(rawKeys) do
                local keyName
                if specialKeys[code] then
                    keyName = specialKeys[code]
                elseif code >= 33 and code <= 126 then
                    keyName = string.upper(string.char(code))
                else
                    keyName = tostring(code) 
                end
                state[keyName] = true
            end
        end
        return state
    end
}
