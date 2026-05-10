local logInfo = {}
local function tPrint(text)
    print(text)
    table.insert(logInfo, text)
end

term.clear()
term.setCursorPos(1,1)
tPrint("--- GLOBAL API / SABLE ENVIRONMENT PROBE ---")

local function dumpTable(t, name)
    tPrint("\nAPI: " .. name)
    if type(t) ~= "table" then
        tPrint("  -> Not a table (" .. type(t) .. ")")
        return
    end
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
        if type(v) == "function" then
            tPrint("  -> " .. tostring(k) .. "()")
        else
            tPrint("  -> " .. tostring(k) .. " (" .. type(v) .. ")")
        end
    end
    if count == 0 then
         tPrint("  -> (Empty table)")
    end
end

-- Explicit checks for known mod namespaces
if aero then dumpTable(aero, "aero") end
if matrix then dumpTable(matrix, "matrix") end
if quaternion then dumpTable(quaternion, "quaternion") end
if sublevel then dumpTable(sublevel, "sublevel") end
if sable then dumpTable(sable, "sable") end
if aeronautics then dumpTable(aeronautics, "aeronautics") end
if ship then dumpTable(ship, "ship") end

tPrint("\n--- NON-STANDARD GLOBALS (_G) ---")
local stdlib = {
    string=true, math=true, coroutine=true, table=true, io=true, os=true, bit32=true, utf8=true,
    keys=true, textutils=true, http=true, fs=true, disk=true, peripheral=true, package=true,
    term=true, rs=true, redstone=true, colors=true, colours=true, paintutils=true,
    window=true, rednet=true, parallel=true, multishell=true, shell=true,
    gps=true, help=true, commands=true, settings=true, vector=true,
    _HOST=true, _CC_DEFAULT_SETTINGS=true, _CC_DISABLE_LUA51_FEATURES=true,
    _VERSION=true, require=true, next=true, pcall=true, xpcall=true,
    type=true, load=true, loadfile=true, assert=true, error=true,
    getfenv=true, setfenv=true, getmetatable=true, setmetatable=true,
    ipairs=true, pairs=true, rawequal=true, rawget=true, rawset=true,
    select=true, tonumber=true, tostring=true, unpack=true, print=true,
    printError=true, read=true, sleep=true, write=true,
    turtle=true, pocket=true, arg=true, _G=true,
    aero=true, matrix=true, quaternion=true, sublevel=true
}

local foundCustomGlobal = false
for k, v in pairs(_G) do
    if not stdlib[k] then
        foundCustomGlobal = true
        if type(v) == "table" then
            dumpTable(v, tostring(k))
        else
            tPrint(" - " .. tostring(k) .. " (" .. type(v) .. ")")
        end
    end
end
if not foundCustomGlobal then
    tPrint("  None detected.")
end

tPrint("\n--- CHECKING ROM APIS DIRECTORIES ---")
local directoriesToCheck = {"/rom/apis", "/rom/modules"}
for _, dir in ipairs(directoriesToCheck) do
    if fs.exists(dir) then
         tPrint("\nDirectory: " .. dir)
         local files = fs.list(dir)
         for _, file in ipairs(files) do
             tPrint(" - " .. file)
         end
    end
end

tPrint("\nProbe complete.")

local f = fs.open("api_log.txt", "w")
if f then
    for _, line in ipairs(logInfo) do
        f.writeLine(line)
    end
    f.close()
    print("\nLog saved to api_log.txt")
else
    print("\nFailed to save log to api_log.txt")
end
