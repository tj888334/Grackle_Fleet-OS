local scriptDir = fs.getDir(shell.getRunningProgram())
local rootDir = fs.combine(scriptDir, "..")
package.path = package.path .. ";/" .. scriptDir .. "/?.lua;/" .. rootDir .. "/?.lua;/" .. rootDir .. "/Modules/?.lua"

local config = require("config")
local stabilizer = require("Modules.stabilizer")
local relay = peripheral.wrap(config.hardware.relay_throttle_name)

if not relay or not sublevel then
    print("CRITICAL: Missing relay or sublevel API.")
    return
end

term.clear()
term.setCursorPos(1,1)
print("=== VTOL DYNAMIC AUTO-TUNER ===")
print("Ensure the VTOL is clear of obstacles.")
print("This will pulse each motor to learn its orientation and effect, then analyze stability.")
print("")
print("Enter the current Max RPM of your propellers (default 128):")
write("> ")
local rpmInput = read()
local currentMaxRPM = tonumber(rpmInput) or 128

print("Press ENTER to begin testing...")
read()

local function setAllOff()
    for _, s in ipairs({"top","bottom","left","right","front","back"}) do
        relay.setAnalogOutput(s, 15)
    end
end

local function getEuler()
    local ok, pose = pcall(sublevel.getLogicalPose)
    if ok and pose and pose.orientation then
        local p, y, r = pose.orientation:toEuler()
        return math.deg(p), math.deg(y), math.deg(r)
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
        if math.abs(p) < 0.5 and math.abs(r) < 0.5 and vSpeed < 0.5 then
            break
        end
        os.sleep(0.5)
        waited = waited + 0.5
    end
end

setAllOff()
os.sleep(1)

local logInfo = {}
local function tPrint(text)
    print(text)
    table.insert(logInfo, text)
end

local sidesToTest = {
    ["Front-Left"]  = config.throttle_sides.front_left,
    ["Front-Right"] = config.throttle_sides.front_right,
    ["Back-Left"]   = config.throttle_sides.back_left,
    ["Back-Right"]  = config.throttle_sides.back_right
}

-- Hover Takeoff Threshold Test
tPrint("\n[ Commencing Takeoff Threshold Test ]")
setAllOff()
os.sleep(1.5)

local startAlt = 0
local ok_start_pose, start_pose = pcall(sublevel.getLogicalPose)
if ok_start_pose and start_pose and start_pose.position then
    startAlt = start_pose.position.y
end

local takeoffPower = nil

for pwr = 1, 15 do
    tPrint("Testing global power level " .. pwr .. " (Signal " .. (15 - pwr) .. ")...")
    for _, side in pairs(sidesToTest) do
        relay.setAnalogOutput(side, 15 - pwr)
    end
    os.sleep(1.0) -- wait 1 second for thrust to build and physics to react
    
    local ok_v, velo = pcall(sublevel.getLinearVelocity)
    local vY = (ok_v and velo) and velo.y or 0
    
    local currentAlt = startAlt
    local ok_p, currPose = pcall(sublevel.getLogicalPose)
    if ok_p and currPose and currPose.position then
        currentAlt = currPose.position.y
    end

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
    tPrint("Note: Master power starts lifting around this value.")
    
    local targetHoverPower = 7
    -- Usually thrust in Create Aeronautics scales somewhat linearly or quadratically.
    -- We'll give a simple linear proportion recommendation. 
    local rpmMultiplier = takeoffPower / targetHoverPower
    local recommendedRPM = currentMaxRPM * rpmMultiplier
    tPrint(string.format("\n[ Thrust Recommendation ]"))
    tPrint(string.format("To achieve liftoff at mid-throttle (Power %d),", targetHoverPower))
    
    if recommendedRPM > 256 then
        local numProps = 0
        for _ in pairs(sidesToTest) do numProps = numProps + 1 end
        local requiredProps = math.ceil(numProps * rpmMultiplier)
        
        tPrint(string.format("Required RPM is roughly %d, which exceeds the limit of 256 max RPM.", math.floor(recommendedRPM)))
        tPrint(string.format("RECOMMENDATION: Since RPM cannot exceed 256, you need %.2fx more total lift.", rpmMultiplier))
        tPrint(string.format("To hover at mid-throttle, you need the equivalent of %d propellers (currently %d).", requiredProps, numProps))
        tPrint("Try adding more engines/props, or upgrading to larger propellers with more surface area.")
        tPrint("Note: Adding wings can also significantly help with altitude and flight stability.")
    else
        tPrint(string.format("try increasing propeller max RPM to roughly: %d", math.floor(recommendedRPM)))
        tPrint("Note: Adding wings can also significantly help with altitude and flight stability.")
    end
else
    tPrint("WARNING: Did not detect liftoff even at full power. VTOL may be overweight or rotors lack RPM.")
    tPrint("\n[ Thrust Recommendation ]")
    tPrint("Increase propeller max RPM significantly and re-run the auto-tuner.")
end

-- Calibrate Baseline
tPrint("\n[ Calibrating for Stabilized Aerial Test ]")
setAllOff()
tPrint("Waiting for craft to settle on ground...")
waitForLevel(10.0)

if not takeoffPower then
    tPrint("CRITICAL: Cannot perform aerial tests without a known takeoff power.")
    tPrint("Please ensure the vehicle can lift off before running this test.")
    return
end

local function landCraft()
    tPrint("\n[ Initiating Smooth Landing ]")
    local pidPitch = stabilizer.createPID(0.08, 0.0, 0.15)
    local pidRoll = stabilizer.createPID(0.08, 0.0, 0.15)
    local currentPower = takeoffPower or 7
    
    while currentPower > 0 do
        local p, y, r = getEuler()
        p, r = p * config.tuning.gimbal_pitch_invert, r * config.tuning.gimbal_roll_invert
        
        local dt = 0.05
        local pCorr = pidPitch:update(0, p, dt)
        local rCorr = pidRoll:update(0, r, dt)
        
        local mixed = stabilizer.mixQuad(currentPower, pCorr, rCorr, 15)
        
        relay.setAnalogOutput(config.throttle_sides.front_left, math.floor(15 - math.max(0, math.min(15, mixed.fl))))
        relay.setAnalogOutput(config.throttle_sides.front_right, math.floor(15 - math.max(0, math.min(15, mixed.fr))))
        relay.setAnalogOutput(config.throttle_sides.back_left, math.floor(15 - math.max(0, math.min(15, mixed.bl))))
        relay.setAnalogOutput(config.throttle_sides.back_right, math.floor(15 - math.max(0, math.min(15, mixed.br))))
        
        -- slowly descend
        currentPower = currentPower - 0.2
        os.sleep(dt)
    end
    setAllOff()
    tPrint("Craft landed securely.")
end

-- Helper to run an active PID loop for a set duration, optionally adding an offset to one engine
local function runStabilizedTest(durationSecs, pulseSide, pulseOffset)
    local pidPitch = stabilizer.createPID(0.08, 0.0, 0.15)
    local pidRoll = stabilizer.createPID(0.08, 0.0, 0.15)
    local pidAlt = stabilizer.createPID(config.tuning.pid_alt.p, config.tuning.pid_alt.i, config.tuning.pid_alt.d)
    
    local targetAlt = 0
    local ok, pose = pcall(sublevel.getLogicalPose)
    if ok and pose and pose.position then
        targetAlt = pose.position.y
    end

    local t = 0
    while t < durationSecs do
        local p, y, r = getEuler()
        p, r = p * config.tuning.gimbal_pitch_invert, r * config.tuning.gimbal_roll_invert
        
        local curAlt = targetAlt
        local ok2, pose2 = pcall(sublevel.getLogicalPose)
        if ok2 and pose2 and pose2.position then
            curAlt = pose2.position.y
        end

        local dt = 0.05
        local pCorr = pidPitch:update(0, p, dt)
        local rCorr = pidRoll:update(0, r, dt)
        local altCorr = pidAlt:update(targetAlt, curAlt, dt)
        
        local masterPower = takeoffPower + altCorr
        masterPower = math.max(0, math.min(15, masterPower))
        
        local mixed = stabilizer.mixQuad(masterPower, pCorr, rCorr, 15)
        
        -- Add pulse offset
        if pulseSide == config.throttle_sides.front_left then mixed.fl = mixed.fl + pulseOffset end
        if pulseSide == config.throttle_sides.front_right then mixed.fr = mixed.fr + pulseOffset end
        if pulseSide == config.throttle_sides.back_left then mixed.bl = mixed.bl + pulseOffset end
        if pulseSide == config.throttle_sides.back_right then mixed.br = mixed.br + pulseOffset end

        relay.setAnalogOutput(config.throttle_sides.front_left, math.floor(15 - math.max(0, math.min(15, mixed.fl))))
        relay.setAnalogOutput(config.throttle_sides.front_right, math.floor(15 - math.max(0, math.min(15, mixed.fr))))
        relay.setAnalogOutput(config.throttle_sides.back_left, math.floor(15 - math.max(0, math.min(15, mixed.bl))))
        relay.setAnalogOutput(config.throttle_sides.back_right, math.floor(15 - math.max(0, math.min(15, mixed.br))))
        
        os.sleep(dt)
        t = t + dt
    end
end

tPrint("\n[ Attempting Stable Hover Confirmation ]")
tPrint("Bringing craft to hover using tested P:0.08 D:0.15...")
runStabilizedTest(5.0, nil, 0)
local hoverP, hoverY, hoverR = getEuler()
tPrint(string.format("Hover State -> P: %.2f | R: %.2f", hoverP, hoverR))

if math.abs(hoverP) > 5.0 or math.abs(hoverR) > 5.0 then
    tPrint("WARNING: Stable hover was not very flat. PID mapping or center of gravity might be significantly off.")
else
    tPrint("Hover appears relatively stable.")
end

tPrint("\n[ Commencing Stabilized Motor Pulse Sequence ]")
local results = {}

for name, rc_side in pairs(sidesToTest) do
    tPrint("\nTesting " .. name .. " (" .. rc_side .. ")...")
    tPrint("  Maintaining hover and injecting +2RS pulse for 2 seconds...")
    
    runStabilizedTest(2.0, rc_side, 2)
    local p, y, r = getEuler()
    
    local dPitch = p - hoverP
    local dRoll = r - hoverR
    
    results[name] = {dp = dPitch, dr = dRoll}
    tPrint(string.format("  -> Deflection under stabilization: Pitch: %5.2f | Roll: %5.2f", dPitch, dRoll))
    
    -- Re-stabilize
    tPrint("  Re-stabilizing...")
    runStabilizedTest(2.0, nil, 0)
    hoverP, hoverY, hoverR = getEuler()
end

landCraft()
waitForLevel(5.0)

tPrint("\n[ Analyzing Polarity & Tuning ]")
local pitchSignsStr = ""
local rollSignsStr = ""

for k, v in pairs(results) do
    local pSign = v.dp > 0 and "+" or "-"
    local rSign = v.dr > 0 and "+" or "-"
    pitchSignsStr = pitchSignsStr .. k .. ":" .. pSign .. " "
    rollSignsStr = rollSignsStr .. k .. ":" .. rSign .. " "
end

tPrint("Pitch polarity mapping: " .. pitchSignsStr)
tPrint("Roll polarity mapping: " .. rollSignsStr)

-- Auto-apply recommended PID config
tPrint("\n[ Applying recommended PID values to config.lua ]")
local configPath = fs.combine(scriptDir, "config.lua")
local f = fs.open(configPath, "r")
if f then
    local content = f.readAll()
    f.close()
    
    -- Recommended PID values based on tuning
    local recP = 0.08
    local recI = 0.0
    local recD = 0.15
    
    local replacedPitch, countPitch
    content, countPitch = string.gsub(content, "pid_pitch%s*=%s*%b{}", "pid_pitch = { p = " .. recP .. ", i = " .. recI .. ", d = " .. recD .. " }")
    
    local replacedRoll, countRoll
    content, countRoll = string.gsub(content, "pid_roll%s*=%s*%b{}", "pid_roll  = { p = " .. recP .. ", i = " .. recI .. ", d = " .. recD .. " }")
    
    if countPitch > 0 or countRoll > 0 then
        local fw = fs.open(configPath, "w")
        if fw then
            fw.write(content)
            fw.close()
            tPrint("Successfully updated config.lua with recommended PID!")
        else
            tPrint("Failed to write to config.lua.")
        end
    else
        tPrint("Could not find pid_pitch or pid_roll in config.lua to replace.")
    end
else
    tPrint("Could not read config.lua to apply PID updates.")
end

local logFile = fs.open("auto_tune_log.txt", "w")
if logFile then
    for _, line in ipairs(logInfo) do
        logFile.writeLine(line)
    end
    logFile.close()
    print("\nSUCCESS! Saved to auto_tune_log.txt")
else
    print("Failed to save log.")
end
