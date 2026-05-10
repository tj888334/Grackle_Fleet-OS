local tw = peripheral.find("linked_typewriter")

if not tw then
    print("Error: No linked_typewriter found on network.")
    return
end

local scriptPath = shell.getRunningProgram()
local scriptDir = fs.getDir(scriptPath)
local logPath = fs.combine(scriptDir, "twpoll_log.txt")

local file = fs.open(logPath, "w")

local function cPrint(text)
    print(text)
    if file then 
        file.writeLine(text) 
        file.flush() -- Save immediately in case of Ctrl+T termination
    end
end

cPrint("--- TYPEWRITER POLL UTILITY ---")
cPrint("Press Ctrl+T to terminate.")
cPrint("Awaiting input...")
cPrint("-------------------------------")

while true do
    local keys = tw.getPressedKeyCodes()
    
    -- Only trigger if the table exists and actually has something inside it
    if keys and #keys > 0 then
        -- Unpack the table, then squash it onto one line for easy reading
        local str = textutils.serialize(keys)
        str = string.gsub(str, "%s+", " ") 
        
        cPrint(str)
    end
    
    os.sleep(0.05)
end