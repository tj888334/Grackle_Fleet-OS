local logInfo = {}
local function tPrint(text)
    print(text)
    table.insert(logInfo, text)
end

term.clear()
term.setCursorPos(1,1)

tPrint("--- SHIP AND QUATERNION PROBE ---")

tPrint("\nTesting quaternion.fromShip()...")
local ok, q = pcall(quaternion.fromShip)
if ok then
    tPrint("Type of q: " .. type(q))
    if type(q) == "table" then
        for k, v in pairs(q) do
            tPrint(tostring(k) .. ": " .. tostring(v))
        end
        local mt = getmetatable(q)
        if mt then
            for k, v in pairs(mt) do
                if k == "__index" and type(v) == "table" then
                    tPrint("Methods in __index:")
                    for mk, mv in pairs(v) do
                        tPrint("  -> " .. tostring(mk))
                    end
                else
                    tPrint("meta: " .. tostring(k))
                end
            end
        end
    end
else
    tPrint("Error calling quaternion.fromShip(): " .. tostring(q))
end

tPrint("\nTesting sublevel.getLogicalPose()...")
local okPose, pose = pcall(sublevel.getLogicalPose)
if okPose then
    tPrint("Type of pose: " .. type(pose))
    if type(pose) == "table" then
        for k, v in pairs(pose) do
            tPrint(tostring(k) .. ": " .. tostring(v))
        end
    end
else
    tPrint("Error calling sublevel.getLogicalPose(): " .. tostring(pose))
end

local f = fs.open("ship_probe_log.txt", "w")
if f then
    for _, line in ipairs(logInfo) do
        f.writeLine(line)
    end
    f.close()
    print("\nLog saved to ship_probe_log.txt")
end
