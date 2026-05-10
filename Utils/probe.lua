local args = {...}
local target = args[1]

if not target then
    print("Usage: probe <side_or_name>")
    return
end

if not peripheral.isPresent(target) then
    print("Error: No peripheral found at '" .. target .. "'")
    return
end

-- Resolve path so it saves in the same folder as the script
local scriptPath = shell.getRunningProgram()
local scriptDir = fs.getDir(scriptPath)
local logPath = fs.combine(scriptDir, "probe_log.txt")

local file = fs.open(logPath, "w")

local function cPrint(text)
    textutils.pagedPrint(text)
    if file then file.writeLine(text) end
end

-- This new function intercepts tables and unpacks them
local function formatVal(v)
    if type(v) == "table" then
        -- Serialize the table, then squash it onto one line
        local str = textutils.serialize(v)
        if str then
            return string.gsub(str, "%s+", " ")
        else
            return "{}"
        end
    elseif type(v) == "string" then
        return '"' .. v .. '"'
    else
        return tostring(v)
    end
end

cPrint("--- PROBE REPORT ---")
cPrint("Target: " .. target)
cPrint("Type: " .. peripheral.getType(target))
cPrint("--------------------")

local methods = peripheral.getMethods(target)
if not methods or #methods == 0 then
    cPrint("No methods available.")
else
    local p = peripheral.wrap(target)
    for _, method in ipairs(methods) do
        -- Attempt to execute the method without arguments
        local success, r1, r2, r3 = pcall(p[method])
        
        local out = method .. "() -> "
        if success then
            if r1 == nil then
                out = out .. "[Success, no return / needs args]"
            else
                -- Run returns through our new formatter
                out = out .. formatVal(r1)
                if r2 ~= nil then out = out .. ", " .. formatVal(r2) end
                if r3 ~= nil then out = out .. ", " .. formatVal(r3) end
            end
        else
            out = out .. "[Requires args or execution failed]"
        end
        cPrint(out)
    end
end

cPrint("--------------------")
if file then file.close() end
print("Results saved to " .. logPath)