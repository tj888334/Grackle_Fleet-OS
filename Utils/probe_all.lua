local args = {...}
local target = args[1]

term.clear()
term.setCursorPos(1,1)

local logInfo = {}
table.insert(logInfo, "--- AERONAUTICS HARDWARE PROBE ---")

local function tPrint(text)
    print(text)
    table.insert(logInfo, text)
end

tPrint("--- AERONAUTICS HARDWARE PROBE ---")

local names = peripheral.getNames()
if #names == 0 then
    tPrint("No peripherals found.")
else
    for _, name in ipairs(names) do
        if not target or target == name or target == peripheral.getType(name) then
            tPrint("\nPeripheral: " .. name)
            tPrint("Type: " .. peripheral.getType(name))
            local methods = peripheral.getMethods(name)
            if methods and #methods > 0 then
                tPrint("Methods exposed:")
                for _, method in ipairs(methods) do
                    tPrint("  -> " .. method .. "()")
                end
            else
                tPrint("  No methods exposed.")
            end
        end
    end
end
tPrint("\nProbe complete.")

local f = fs.open("probe_log.txt", "w")
if f then
    for _, line in ipairs(logInfo) do
        f.writeLine(line)
    end
    f.close()
    print("Log saved to probe_log.txt")
else
    print("Failed to save log to probe_log.txt")
end
