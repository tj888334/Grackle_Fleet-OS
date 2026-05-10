-- =========================================================================
-- AERONAUTICS FLEET OS - DRONE FLIGHT CONTROLLER
-- =========================================================================
-- This script is the primary flight controller for the Drone hardware.
-- It reads inputs from the linked typewriter, calculates stabilization 
-- via PID controllers, and outputs analog/binary redstone signals.
-- =========================================================================

local scriptDir = fs.getDir(shell.getRunningProgram())
local rootDir = fs.combine(scriptDir, "..")
package.path = package.path .. ";/" .. scriptDir .. "/?.lua;/" .. rootDir .. "/?.lua;/" .. rootDir .. "/Modules/?.lua"

local input      = require("Modules.ctrl_typewriter")
local config     = require("config")
local stabilizer = require("Modules.stabilizer")
local telemetry  = require("Utils.ship_telemetry")

local relay = peripheral.find("redstone_relay")

if not relay then 
    print("WARNING: Hardware relay not found dynamically using peripheral.find.")
    print("Continuing in 3 seconds...")
    os.sleep(3)
end

if not sublevel then
    print("CRITICAL: sublevel API not found. Please ensure the computer is on a Sable physics object.") return
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

-- =========================================================================
-- COMMAND LINE ARGUMENTS / USAGE:
--   "main.lua"
--      -> Starts the craft normally in manual mode.
--   "main.lua autohold <power>"
--      -> Starts the craft with Altitude Lock pre-engaged, using <power> 
--         (e.g. 7) as the estimated baseline hover power. Commonly used
--         when handing off from auto_tune.lua.
--   "main.lua telemetry"
--      -> Enables continuous CSV telemetry logging to flight_telemetry.csv
--         using the ship_telemetry module.
-- Note: Arguments can be combined. (e.g. "main.lua autohold 7 telemetry")
-- =========================================================================
local args = {...}
local start_autohold = false
local start_hover_power = 0
local debug_telemetry = false

for i, arg in ipairs(args) do
    if arg == "autohold" then
        start_autohold = true
        start_hover_power = tonumber(args[i+1]) or 0
    elseif arg == "telemetry" then
        debug_telemetry = true
    end
end

local masterPower = start_hover_power  

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

-- Initialize safely to OFF state
setAllOff()

local pidPitch = stabilizer.createPID(config.tuning.pid_pitch.p, config.tuning.pid_pitch.i, config.tuning.pid_pitch.d)
local pidRoll  = stabilizer.createPID(config.tuning.pid_roll.p, config.tuning.pid_roll.i, config.tuning.pid_roll.d)
local pidAlt   = stabilizer.createPID(config.tuning.pid_alt.p, config.tuning.pid_alt.i, config.tuning.pid_alt.d)

local altLockActive = start_autohold
local altLockTarget = 0
local prevLockKey = false
local baseHoverPower = start_hover_power

if start_autohold then
    local ok_p, startPose = pcall(sublevel.getLogicalPose)
    if ok_p and startPose and startPose.position then
        altLockTarget = startPose.position.y
    end
end

term.clear()

local function flightLoop()
    if debug_telemetry then
        telemetry.start("flight_telemetry.csv")
    end
    while true do
        local ok_pose, pose = pcall(sublevel.getLogicalPose)
        local ok_v, velo = pcall(sublevel.getLinearVelocity)

        local curAlt = 0
        if ok_pose and pose and pose.position then
            curAlt = pose.position.y
        end

        local keys = input.getPressed()
        
        local lockKeyCurrentlyPressed = keys[config.controls.lock_alt]
        if lockKeyCurrentlyPressed and not prevLockKey then
            altLockActive = not altLockActive
            if altLockActive then
                if ok_pose and pose and pose.position then
                    altLockTarget = pose.position.y
                end
                baseHoverPower = masterPower
                pidAlt.integral = 0
                pidAlt.prevError = 0
            end
        end
        prevLockKey = lockKeyCurrentlyPressed
        
        local altCorr = 0
        if altLockActive then
            local alt_rate = config.tuning.alt_throttle_rate or 0.5
            if keys[config.controls.throttle_up] then
                altLockTarget = altLockTarget + alt_rate
            elseif keys[config.controls.throttle_down] then
                altLockTarget = altLockTarget - alt_rate
            end
            
            altCorr = pidAlt:update(altLockTarget or 0, curAlt or 0, 0.05)
            masterPower = baseHoverPower + altCorr
            masterPower = math.max(0, math.min(15, masterPower))
        else
            if keys[config.controls.throttle_up] then
                masterPower = masterPower + config.tuning.throttle_rate
            elseif keys[config.controls.throttle_down] then
                masterPower = masterPower - config.tuning.throttle_rate
            end
            masterPower = math.max(0, math.min(15, masterPower))
            
            if masterPower == 0 then
                pidPitch.integral = 0
                pidRoll.integral = 0
                pidAlt.integral = 0
            end
        end

        local targetPitch, targetRoll = 0, 0

        local pitch_fwd = keys[config.controls.pitch_fwd]
        local pitch_back = keys[config.controls.pitch_back]
        local roll_left = keys[config.controls.roll_left]
        local roll_right = keys[config.controls.roll_right]

        local active_max_pitch = altLockActive and (config.tuning.max_pitch_target_lock or 2) or config.tuning.max_pitch_target
        local active_max_roll = altLockActive and (config.tuning.max_roll_target_lock or 2) or config.tuning.max_roll_target

        if pitch_fwd then targetPitch = -active_max_pitch end
        if pitch_back then targetPitch = active_max_pitch end
        if roll_left then targetRoll = -active_max_roll end
        if roll_right then targetRoll = active_max_roll end

        local yaw_fl, yaw_fr, yaw_rl, yaw_rr = false, false, false, false
        if keys[config.controls.yaw_left] then 
            yaw_fl = false
            yaw_fr = true
            yaw_rl = true
            yaw_rr = false
        elseif keys[config.controls.yaw_right] then 
            yaw_fl = true
            yaw_fr = false
            yaw_rl = false
            yaw_rr = true
        end

        local pCorr, rCorr = 0, 0
        local p, r = 0, 0
        
        if ok_pose and pose and pose.orientation then
            local p_rad, y_rad, r_rad = pose.orientation:toEuler()
            p = math.deg(p_rad) * (config.tuning.gimbal_pitch_invert or 1)
            r = math.deg(r_rad) * (config.tuning.gimbal_roll_invert or 1)
            
            local dt = 0.05 
            pCorr = pidPitch:update(targetPitch or 0, p or 0, dt)
            rCorr = pidRoll:update(targetRoll or 0, r or 0, dt)
        end

        local tilt_factor = math.cos(math.rad(p)) * math.cos(math.rad(r))
        tilt_factor = math.max(0.5, tilt_factor)

        local actualThrust = masterPower
        if altLockActive then
            actualThrust = masterPower / tilt_factor
        else
            actualThrust = masterPower / tilt_factor
        end
        actualThrust = math.max(0, math.min(15, actualThrust))

        local fl, fr, bl, br = 0, 0, 0, 0
        if actualThrust > 0 then
            local mixed = stabilizer.mixQuad(actualThrust, pCorr, rCorr, 15, altLockActive)
            fl, fr, bl, br = mixed.fl, mixed.fr, mixed.bl, mixed.br
        end

        setHardwareOutput(config.outputs.main_throttle.fl, math.floor(15 - fl), true)
        setHardwareOutput(config.outputs.main_throttle.fr, math.floor(15 - fr), true)
        setHardwareOutput(config.outputs.main_throttle.bl, math.floor(15 - bl), true)
        setHardwareOutput(config.outputs.main_throttle.br, math.floor(15 - br), true)

        setHardwareOutput(config.outputs.yaw_direction.front_left, yaw_fl and 15 or 0, false)
        setHardwareOutput(config.outputs.yaw_direction.front_right, yaw_fr and 15 or 0, false)
        setHardwareOutput(config.outputs.yaw_direction.rear_left, yaw_rl and 15 or 0, false)
        setHardwareOutput(config.outputs.yaw_direction.rear_right, yaw_rr and 15 or 0, false)

        term.setCursorPos(1, 1)
        
        local function cPrint(text)
            term.clearLine()
            print(text)
        end

        cPrint("=== AERONAUTICS FLEET OS : DRONE ===")
        cPrint("")
        cPrint(string.format(" Master Power:   %5.1f / 15.0", masterPower))
        cPrint(string.format(" Altitude Lock:  %s %s", altLockActive and "ON" or "OFF", altLockActive and string.format("(Tgt: %.1f)", altLockTarget) or ""))
        cPrint("")
        cPrint(string.format(" Target Pitch: %5.1f | Roll: %5.1f", targetPitch, targetRoll))
        cPrint(string.format(" Actual Pitch: %5.1f | Roll: %5.1f", p, r))
        cPrint(string.format(" Correction P: %5.1f | R: %5.1f", pCorr, rCorr))
        cPrint("")
        cPrint(" --- Main Output (0=Max, 15=Off) ---")
        cPrint(string.format(" FL: %2d  |  FR: %2d", math.floor(15 - fl), math.floor(15 - fr)))
        cPrint(string.format(" BL: %2d  |  BR: %2d", math.floor(15 - bl), math.floor(15 - br)))
        cPrint("")
        cPrint(" --- Yaw Sub-System (Dual Bin) ---")
        cPrint(string.format(" Forward Rotors:  %s | %s", yaw_fl and "L Active" or "Idle", yaw_fr and "R Active" or "Idle"))
        cPrint(string.format(" Rear Rotors:     %s | %s", yaw_rl and "L Active" or "Idle", yaw_rr and "R Active" or "Idle"))

        if debug_telemetry then
            local vx, vy, vz = 0, 0, 0
            if ok_v and velo then
                vx, vy, vz = velo.x, velo.y, velo.z
            end
            telemetry.logTick({
                altLockTarget = altLockTarget, curAlt = curAlt, 
                masterPower = masterPower, altCorr = altCorr, 
                vx = vx, vy = vy, vz = vz, 
                targetPitch = targetPitch, targetRoll = targetRoll, 
                p = p, r = r, pCorr = pCorr, rCorr = rCorr, 
                fl = math.floor(15 - fl), fr = math.floor(15 - fr), 
                bl = math.floor(15 - bl), br = math.floor(15 - br)
            })
        end

        os.sleep(0.05)
    end
end

local ok, err = pcall(flightLoop)

if debug_telemetry then
    telemetry.stop()
end

setHardwareOutput(config.outputs.main_throttle.fl, 15, true)
setHardwareOutput(config.outputs.main_throttle.fr, 15, true)
setHardwareOutput(config.outputs.main_throttle.bl, 15, true)
setHardwareOutput(config.outputs.main_throttle.br, 15, true)
setHardwareOutput(config.outputs.yaw_direction.front_left, 0, false)
setHardwareOutput(config.outputs.yaw_direction.front_right, 0, false)
setHardwareOutput(config.outputs.yaw_direction.rear_left, 0, false)
setHardwareOutput(config.outputs.yaw_direction.rear_right, 0, false)

term.clear()
term.setCursorPos(1, 1)

if not ok and err ~= "Terminated" then
    print("Flight computer crashed:")
    print(err)
end
