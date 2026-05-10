-- =========================================================================
-- AERONAUTICS FLEET OS - FLIGHT TELEMETRY
-- =========================================================================
-- Manages raw and calculated flight data logging to CSV format.
-- Extremely useful for analyzing PID step responses or debugging flight.
-- =========================================================================

local Module = {}
local logFile = nil
local startTime = 0
local currentFilename = ""
local MAX_LOG_SIZE = 512 * 1024 -- 512 KB size limit for proper log hygiene

function Module.start(filename)
    if logFile then
        logFile.close()
    end
    filename = filename or "flight_telemetry.csv"
    currentFilename = filename
    
    local backupName = currentFilename .. ".old"
    if fs.exists(backupName) then
        fs.delete(backupName)
    end

    logFile = fs.open(filename, "w")
    if logFile then
        logFile.writeLine("Time,AltTarget,CurAlt,MasterPower,AltCorr,VelX,VelY,VelZ,TgtPitch,TgtRoll,ActPitch,ActRoll,PCorr,RCorr,FL,FR,BL,BR")
        logFile.flush()
        startTime = os.epoch("utc") / 1000
    end
    return logFile ~= nil
end

function Module.logTick(data)
    if not logFile then return end
    
    local t = (os.epoch("utc") / 1000) - startTime
    
    local line = string.format("%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d",
        t, 
        data.altLockTarget or 0, 
        data.curAlt or 0, 
        data.masterPower or 0, 
        data.altCorr or 0, 
        data.vx or 0, data.vy or 0, data.vz or 0, 
        data.targetPitch or 0, data.targetRoll or 0, 
        data.p or 0, data.r or 0, 
        data.pCorr or 0, data.rCorr or 0, 
        data.fl or 0, data.fr or 0, data.bl or 0, data.br or 0
    )
    
    logFile.writeLine(line)
    logFile.flush()
    
    if fs.exists(currentFilename) and fs.getSize(currentFilename) > MAX_LOG_SIZE then
        logFile.close()
        local backupName = currentFilename .. ".old"
        if fs.exists(backupName) then
            fs.delete(backupName)
        end
        fs.move(currentFilename, backupName)
        
        logFile = fs.open(currentFilename, "w")
        if logFile then
            logFile.writeLine("Time,AltTarget,CurAlt,MasterPower,AltCorr,VelX,VelY,VelZ,TgtPitch,TgtRoll,ActPitch,ActRoll,PCorr,RCorr,FL,FR,BL,BR")
            logFile.flush()
        end
    end
end

function Module.stop()
    if logFile then
        logFile.close()
        logFile = nil
    end
end

local args = {...}
local isRequired = false
if #args == 1 and type(args[1]) == "string" and package.loaded then
    if package.loaded[args[1]] ~= false then
        isRequired = true
    end
end

if not isRequired then
    term.clear()
    term.setCursorPos(1,1)
    
    print("--- AERONAUTICS PHYSICS TELEMETRY ---")
    
    if not sublevel then
        print("ERROR: sublevel API not found. Please ensure the computer is placed on a Sable physics object.")
        return Module
    end
    
    local function formatVector(v)
        return string.format("X: %.3f, Y: %.3f, Z: %.3f", v.x, v.y, v.z)
    end
    
    print("\n[ Core Metrics ]")
    local ok_mass, mass = pcall(sublevel.getMass)
    if ok_mass and mass then
        print("Total Mass:         " .. tostring(mass) .. " kg")
    end
    
    local ok_com, com = pcall(sublevel.getCenterOfMass)
    if ok_com and com then
        print("Center of Mass:     " .. formatVector(com))
    end
    
    local ok_velo, velo = pcall(sublevel.getLinearVelocity)
    if ok_velo and velo then
        print("Linear Velocity:    " .. formatVector(velo))
    end
    
    local ok_ang, ang = pcall(sublevel.getAngularVelocity)
    if ok_ang and ang then
        print("Angular Velocity:   " .. formatVector(ang))
    end
    
    print("\n[ Pose Data ]")
    local ok_pose, pose = pcall(sublevel.getLogicalPose)
    if ok_pose and pose then
        print("Position:           " .. formatVector(pose.position))
        if pose.orientation then
            local p, y, r = pose.orientation:toEuler()
            print(string.format("Orientation (deg):  Pitch: %.2f, Yaw: %.2f, Roll: %.2f", math.deg(p), math.deg(y), math.deg(r)))
        end
    end
    
    print("\n[ Inertia ]")
    local ok_inertia, inertia = pcall(sublevel.getInertiaTensor)
    if ok_inertia and inertia then
        print("Inertia Tensor:     Available (3x3 Matrix)")
    end
end

return Module
