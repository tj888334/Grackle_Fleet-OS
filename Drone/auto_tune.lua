-- =========================================================================
-- AERONAUTICS FLEET OS - DYNAMIC AUTO-TUNER
-- =========================================================================
-- This script safely calibrates PID parameters for a specific vehicle.
-- It attempts to estimate mass, center of thrust imbalances, and axis 
-- inversions to provide a generally stable baseline configuration.
-- =========================================================================

local scriptDir = fs.getDir(shell.getRunningProgram())
local rootDir = fs.combine(scriptDir, "..")
package.path = package.path .. ";/" .. scriptDir .. "/?.lua;/" .. rootDir .. "/?.lua;/" .. rootDir .. "/Modules/?.lua"

local config = require("config")
local stabilizer = require("Modules.stabilizer")

local relay = peripheral.find("redstone_relay")

if not relay then
    print("WARNING: Hardware relay not found dynamically using peripheral.find.")
    print("Continuing in 3 seconds...")
    os.sleep(3)
end

if not sublevel then
    print("CRITICAL: sublevel API not found.")
    return
end

local function setHardwareOutput(mapping, value, isAnalog)
    if mapping.device == "computer" then
        if isAnalog then
            redstone.setAnalogOutput(mapping.side, value)
        else
            redstone.setOutput(mapping.side, value > 0)
        end
    elseif mapping.device == "relay" then
        if relay then
            if isAnalog then
                relay.setAnalogOutput(mapping.side, value)
            else
                relay.setOutput(mapping.side, value > 0)
            end
        end
    end
end

term.clear()
term.setCursorPos(1,1)
print("=== DRONE DYNAMIC AUTO-TUNER ===")
print("Ensure you have at least a 20x20x20 clear test area.")
print("(Lateral drift will occur since position-hold cannot be")
print("used until auto-tune verifies axis polarities)")
print("Enter the current Max RPM of your propellers (default 128):")
write("> ")
local rpmInput = read()
local currentMaxRPM = tonumber(rpmInput) or 128

print("Do you want to assume manual control after test? (y/n)")
write("> ")
local assumeInput = string.lower(read() or "")
local passControl = assumeInput == "y" or assumeInput == "yes"

local function setAllOff()
    setHardwareOutput(config.outputs.main_throttle.fl, 15, true)
    setHardwareOutput(config.outputs.main_throttle.fr, 15, true)
    setHardwareOutput(config.outputs.main_throttle.bl, 15, true)
    setHardwareOutput(config.outputs.main_throttle.br, 15, true)
    setHardwareOutput(config.outputs.yaw_direction.front_left, 0, false)
    setHardwareOutput(config.outputs.yaw_direction.front_right, 0, false)
    setHardwareOutput(config.outputs.yaw_direction.rear_left, 0, false)
    setHardwareOutput(config.outputs.yaw_direction.rear_right, 0, false)
end

local function getEuler()
    local ok, pose = pcall(sublevel.getLogicalPose)
    if ok and pose and pose.orientation then
        local p, y, r = pose.orientation:toEuler()
        return math.deg(p) * (config.tuning.gimbal_pitch_invert or 1), math.deg(y), math.deg(r) * (config.tuning.gimbal_roll_invert or 1)
    end
    return 0, 0, 0
end

local function waitForLevel(timeoutSec)
    timeoutSec = timeoutSec or 10.0
    local waited = 0
    while waited < timeoutSec do
        local p, y, r = getEuler()
        local ok_v, velo = pcall(sublevel.getLinearVelocity)
        local vSpeed = (ok_v and velo) and math.sqrt(velo.x^2 + velo.y^2 + velo.z^2) or 0
        if math.abs(p) < 0.5 and math.abs(r) < 0.5 and vSpeed < 0.5 then break end
        os.sleep(0.5)
        waited = waited + 0.5
    end
end

local logInfo = {}
local function tPrint(text)
    print(text)
    table.insert(logInfo, text)
end

local sidesToTest = {
    ["Front-Left"]  = config.outputs.main_throttle.fl,
    ["Front-Right"] = config.outputs.main_throttle.fr,
    ["Back-Left"]   = config.outputs.main_throttle.bl,
    ["Back-Right"]  = config.outputs.main_throttle.br
}

tPrint("\n[ Commencing Takeoff Threshold Test ]")
setAllOff()
os.sleep(1.5)

local startAlt, startX, startZ = 0, 0, 0
local ok_start_pose, start_pose = pcall(sublevel.getLogicalPose)
if ok_start_pose and start_pose and start_pose.position then
    startAlt = start_pose.position.y
    startX = start_pose.position.x
    startZ = start_pose.position.z
end

local takeoffPower = nil
local rec_max_drop_manual = 2.5
local rec_max_drop_lock = 1.0

for pwr = 1, 15 do
    tPrint("Testing global power level " .. pwr .. " (Signal " .. (15 - pwr) .. ")...")
    for _, mapping in pairs(sidesToTest) do setHardwareOutput(mapping, 15 - pwr, true) end
    os.sleep(1.0) 
    
    local ok_v, velo = pcall(sublevel.getLinearVelocity)
    local vY = (ok_v and velo) and velo.y or 0
    
    local currentAlt = startAlt
    local ok_p, currPose = pcall(sublevel.getLogicalPose)
    if ok_p and currPose and currPose.position then currentAlt = currPose.position.y end

    if (currentAlt > startAlt + 0.3) or (vY > 0.2) then
        takeoffPower = pwr
        tPrint("  -> LIFTOFF DETECTED! (Velocity Y: " .. string.format("%.2f", vY) .. ")")
        break
    end
end

setAllOff()
os.sleep(1.5)

if takeoffPower then
    tPrint("Estimated Minimum Hover Power: " .. takeoffPower .. " / 15")
    local targetHoverPower = 7
    -- Calculate air density compensation for sea level (Y=63)
    -- This is an approximation since CA's exact curve is complex, but it normalizes
    -- the recommendation so builders get consistent RPM targets anywhere.
    local altitudeDiff = startAlt - 63.0
    local densityFactor = math.max(0.1, 1 - (altitudeDiff * 0.0025)) -- Roughly 0.25% thrust loss per block
    
    local seaLevelTakeoffPower = takeoffPower * densityFactor
    local rpmMultiplier = seaLevelTakeoffPower / targetHoverPower
    local recommendedRPM = currentMaxRPM * rpmMultiplier
    tPrint(string.format("\n[ Thrust Recommendation ]"))
    tPrint(string.format("Try increasing propeller max RPM to roughly: %d (Normalized to Sea Level)", math.floor(recommendedRPM)))
    
    tPrint(string.format("\n[ Atmospheric & Ceiling Info ]"))
    tPrint(string.format("Note: Create Aeronautics simulates decreasing air density at higher altitudes."))
    tPrint(string.format("This Auto-Tune was calibrated at Ground Altitude: Y=%.1f", startAlt))
    local twr = 15.0 / takeoffPower
    tPrint(string.format("Current absolute Thrust-to-Weight Ratio: %.2f", twr))
    
    if twr < 1.2 then
        tPrint(" -> Warning: You have very little thrust reserve. Your drone will likely not be able to ascend much higher.")
    elseif twr > 2.0 then
        tPrint(" -> Excellent thrust reserve. You should have a very high maximum altitude ceiling.")
    else
        tPrint(" -> Moderate thrust reserve. Your ceiling will be noticeably limited.")
    end
else
    tPrint("WARNING: Did not detect liftoff even at full power. Drone may be overweight or rotors lack RPM.")
end

tPrint("\n[ Calibrating for Stabilized Aerial Test ]")
waitForLevel(10.0)

if not takeoffPower then return end

local function runStabilizedTest(durationSecs, pulseMapping, pulseOffset)
    local pidPitch = stabilizer.createPID(0.1, 0.02, 0.1)
    local pidRoll = stabilizer.createPID(0.1, 0.02, 0.1)
    local pidAlt = stabilizer.createPID(config.tuning.pid_alt.p, config.tuning.pid_alt.i, config.tuning.pid_alt.d)
    
    local targetAlt = 0
    local ok, pose = pcall(sublevel.getLogicalPose)
    if ok and pose and pose.position then targetAlt = pose.position.y end

    local t = 0
    while t < durationSecs do
        local p, y, r = getEuler()
        local curAlt = targetAlt
        local ok2, pose2 = pcall(sublevel.getLogicalPose)
        if ok2 and pose2 and pose2.position then curAlt = pose2.position.y end

        local dt = 0.05
        local altCorr = pidAlt:update(targetAlt, curAlt, dt)
        local masterPower = math.max(0, math.min(15, takeoffPower + altCorr))
        
        local mixed = stabilizer.mixQuad(masterPower, pidPitch:update(0, p, dt), pidRoll:update(0, r, dt), 15)
        
        if pulseMapping == config.outputs.main_throttle.fl then mixed.fl = mixed.fl + pulseOffset end
        if pulseMapping == config.outputs.main_throttle.fr then mixed.fr = mixed.fr + pulseOffset end
        if pulseMapping == config.outputs.main_throttle.bl then mixed.bl = mixed.bl + pulseOffset end
        if pulseMapping == config.outputs.main_throttle.br then mixed.br = mixed.br + pulseOffset end

        setHardwareOutput(config.outputs.main_throttle.fl, math.floor(15 - math.max(0, math.min(15, mixed.fl))), true)
        setHardwareOutput(config.outputs.main_throttle.fr, math.floor(15 - math.max(0, math.min(15, mixed.fr))), true)
        setHardwareOutput(config.outputs.main_throttle.bl, math.floor(15 - math.max(0, math.min(15, mixed.bl))), true)
        setHardwareOutput(config.outputs.main_throttle.br, math.floor(15 - math.max(0, math.min(15, mixed.br))), true)
        
        -- Break if pitch/roll gets dangerous (prevents crashing on flipped axes)
        if math.abs(p) > 40 or math.abs(r) > 40 then 
            tPrint("  -> ABORTING PULSE: Dangerous angle reached (flipped axis?)")
            break 
        end

        os.sleep(dt)
        t = t + dt
    end
end

tPrint("\n[ Attempting Stable Hover Confirmation ]")
runStabilizedTest(5.0, nil, 0)
local hoverP, hoverY, hoverR = getEuler()
tPrint(string.format("Hover State -> P: %.2f | R: %.2f", hoverP, hoverR))

tPrint("\n[ Commencing Stabilized Motor Pulse Sequence ]")
local results = {}

for name, mapping in pairs(sidesToTest) do
    tPrint("\nTesting " .. name .. "...")
    runStabilizedTest(0.5, mapping, 2)
    local p, y, r = getEuler()
    results[name] = {dp = p - hoverP, dr = r - hoverR}
    tPrint(string.format("  -> Deflection under stabilization: Pitch: %5.2f | Roll: %5.2f", p - hoverP, r - hoverR))
    
    runStabilizedTest(1.0, nil, 0)
    hoverP, hoverY, hoverR = getEuler()
end

-- tPrint("\n[ Finding Maximum Safe Tilt Angle ]")
-- tPrint(" -> Gaining safe testing altitude (approx +5 blocks)...")

local max_safe_angle = 15
tPrint(string.format("  -> Default Max Target Tilt: %d degrees", max_safe_angle))

-- Recover from forward flight
tPrint(" -> Recovering...")
runStabilizedTest(1.5, nil, 0)

tPrint("\n[ Returning Control to Pilot ]")
tPrint(" -> Stabilizing hover to neutral...")
runStabilizedTest(3.0, nil, 0)

tPrint("\n[ Analyzing Motor Pulse Data for Axis Polarity ]")
local dp_front = results["Front-Left"].dp + results["Front-Right"].dp
local dp_back = results["Back-Left"].dp + results["Back-Right"].dp
local dr_left = results["Front-Left"].dr + results["Back-Left"].dr
local dr_right = results["Front-Right"].dr + results["Back-Right"].dr

local pitch_diff = dp_front - dp_back
local roll_diff = dr_left - dr_right

tPrint("\n[ Center of Mass & Hardware Diagnostics ]")
local pitch_ratio = math.abs(dp_front) / math.max(0.1, math.abs(dp_back))
if pitch_ratio < 0.6 then
    tPrint(string.format(" -> WARNING (PITCH): Back motors have %.1fx more leverage than Front.", 1/pitch_ratio))
    tPrint("    COM is too far FORWARD. Drone will pitch sluggishly and may list.")
    tPrint("    FIX: Move weight BACK or ADD/increase FRONT propellers.")
elseif pitch_ratio > 1.6 then
    tPrint(string.format(" -> WARNING (PITCH): Front motors have %.1fx more leverage than Back.", pitch_ratio))
    tPrint("    COM is too far BACKWARD. Drone will pitch sluggishly and may list.")
    tPrint("    FIX: Move weight FORWARD or ADD/increase BACK propellers.")
else
    tPrint(string.format(" -> Pitch Balance: OK (Ratio: %.2f)", pitch_ratio))
end

local roll_ratio = math.abs(dr_left) / math.max(0.1, math.abs(dr_right))
if roll_ratio < 0.6 then
    tPrint(string.format(" -> WARNING (ROLL): Right motors have %.1fx more leverage than Left.", 1/roll_ratio))
    tPrint("    COM is too far LEFT. Drone will roll sluggishly and may list.")
    tPrint("    FIX: Move weight RIGHT or ADD/increase LEFT propellers.")
elseif roll_ratio > 1.6 then
    tPrint(string.format(" -> WARNING (ROLL): Left motors have %.1fx more leverage than Right.", roll_ratio))
    tPrint("    COM is too far RIGHT. Drone will roll sluggishly and may list.")
    tPrint("    FIX: Move weight LEFT or ADD/increase RIGHT propellers.")
else
    tPrint(string.format(" -> Roll Balance: OK (Ratio: %.2f)", roll_ratio))
end

local new_pitch_invert = config.tuning.gimbal_pitch_invert or 1
local new_roll_invert = config.tuning.gimbal_roll_invert or 1

local polarityUpdates = false

if pitch_diff < -0.2 then
    tPrint(" -> DETECTED PITCH INVERSION: Positive feedback loop found on pitch axis. Fixing...")
    new_pitch_invert = new_pitch_invert * -1
    polarityUpdates = true
elseif pitch_diff > 0.2 then
    tPrint(" -> Pitch polarity is correct.")
else
    tPrint(" -> Inconclusive pitch polarity reading.")
end

if roll_diff < -0.2 then
    tPrint(" -> DETECTED ROLL INVERSION: Positive feedback loop found on roll axis. Fixing...")
    new_roll_invert = new_roll_invert * -1
    polarityUpdates = true
elseif roll_diff > 0.2 then
    tPrint(" -> Roll polarity is correct.")
else
    tPrint(" -> Inconclusive roll polarity reading.")
end

local configPath = fs.combine(scriptDir, "config.lua")
local f = fs.open(configPath, "r")
if f then
    local content = f.readAll()
    f.close()

    local avg_pitch_res = (math.abs(dp_front) + math.abs(dp_back)) / 2
    local avg_roll_res = (math.abs(dr_left) + math.abs(dr_right)) / 2
    
    -- Safe dynamic tuning heuristic. 
    -- Minecraft physics engines heavily oscillate if P is too high.
    local p_pitch_calc = math.max(0.04, math.min(0.35, 0.15 / math.max(0.1, avg_pitch_res)))
    local p_roll_calc = math.max(0.04, math.min(0.35, 0.15 / math.max(0.1, avg_roll_res)))

    -- Low integral to prevent wind-up death spirals. High derivative to act as a dampener.
    local new_pid_pitch = string.format("{ p = %.3f, i = %.3f, d = %.3f }", p_pitch_calc, p_pitch_calc * 0.05, p_pitch_calc * 0.8)
    local new_pid_roll = string.format("{ p = %.3f, i = %.3f, d = %.3f }", p_roll_calc, p_roll_calc * 0.05, p_roll_calc * 0.8)

    tPrint(string.format("\n -> Set Pitch PID: P=%.3f, I=%.3f, D=%.3f", p_pitch_calc, p_pitch_calc * 0.05, p_pitch_calc * 0.8))
    tPrint(string.format(" -> Set Roll PID:  P=%.3f, I=%.3f, D=%.3f", p_roll_calc, p_roll_calc * 0.05, p_roll_calc * 0.8))

    if p_pitch_calc >= 0.35 or p_roll_calc >= 0.35 then
        tPrint("\n *** CRITICAL WARNING ***")
        tPrint(" -> Auto-tune hit maximum safe gain limits. Your ship is very heavy or severely imbalanced.")
        tPrint(" -> SOFTWARE CANNOT FIX SEVERE PHYSICS IMBALANCES.")
        tPrint(" -> Recommendation: Increase Total Max RPM, or physically add more propeller blocks.")
    end

    content, countPitch = string.gsub(content, "pid_pitch%s*=%s*%b{}", "pid_pitch = " .. new_pid_pitch)
    content, countRoll = string.gsub(content, "pid_roll%s*=%s*%b{}", "pid_roll  = " .. new_pid_roll)
    
    content = string.gsub(content, "max_pitch_target%s*=%s*%d+", "max_pitch_target = " .. max_safe_angle)
    content = string.gsub(content, "max_roll_target%s*=%s*%d+", "max_roll_target = " .. max_safe_angle)
    
    if polarityUpdates then
        content = string.gsub(content, "gimbal_pitch_invert%s*=%s*%-?%d+", "gimbal_pitch_invert = " .. new_pitch_invert)
        content = string.gsub(content, "gimbal_roll_invert%s*=%s*%-?%d+", "gimbal_roll_invert = " .. new_roll_invert)
    end

    if countPitch > 0 or countRoll > 0 or polarityUpdates or max_safe_angle then
        local fw = fs.open(configPath, "w")
        if fw then
            fw.write(content)
            fw.close()
            tPrint("Successfully updated config.lua with recommended settings!")
        end
    end
end

-- Write log to file
local logPath = fs.combine(scriptDir, "auto_tune_log.txt")
local logFile = fs.open(logPath, "w")
if logFile then
    for _, line in ipairs(logInfo) do
        logFile.writeLine(line)
    end
    -- Record pulse deflection results in the log
    logFile.writeLine("\n--- Raw Motor Pulse Results ---")
    for name, res in pairs(results) do
        logFile.writeLine(string.format("%s -> Pitch Deflection: %.2f | Roll Deflection: %.2f", name, res.dp, res.dr))
    end
    if math.abs(results["Front-Right"].dr) > 0 or math.abs(results["Front-Left"].dr) > 0 then
        logFile.writeLine("\nNote: Based on motor pulse results, if craft flipped during pulse, polarities have been logged above.")
    end
    logFile.close()
    print("Saved auto-tune log to " .. logPath)
else
    print("Failed to save auto-tune log to " .. logPath)
end

if passControl then
    print("\nStarting Flight Computer immediately. Get ready!")
    shell.run("main.lua", "autohold", tostring(takeoffPower))
else
    local function landCraft()
        tPrint("\n[ Auto-Landing Sequence ]")
        local pwr = takeoffPower
        while pwr > 0 do
            pwr = pwr - 0.5
            local mixed = stabilizer.mixQuad(math.max(0, pwr), 0, 0, 15)
            setHardwareOutput(config.outputs.main_throttle.fl, math.floor(15 - mixed.fl), true)
            setHardwareOutput(config.outputs.main_throttle.fr, math.floor(15 - mixed.fr), true)
            setHardwareOutput(config.outputs.main_throttle.bl, math.floor(15 - mixed.bl), true)
            setHardwareOutput(config.outputs.main_throttle.br, math.floor(15 - mixed.br), true)
            os.sleep(0.2)
        end
        setAllOff()
        tPrint(" -> Touchdown.")
    end
    landCraft()
    print("\nAuto-tune complete. Exiting.")
end
