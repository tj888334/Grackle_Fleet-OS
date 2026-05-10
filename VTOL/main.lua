local scriptDir = fs.getDir(shell.getRunningProgram())
local rootDir = fs.combine(scriptDir, "..")
-- Ensure we can load modules from the script's folder and the root of the project
package.path = package.path .. ";/" .. scriptDir .. "/?.lua;/" .. rootDir .. "/?.lua"

local input      = require("Modules.ctrl_typewriter")
local config     = require("config")
local stabilizer = require("Modules.stabilizer")

local relay_throttle = peripheral.wrap(config.hardware.relay_throttle_name)
local relay_tilt     = peripheral.wrap(config.hardware.relay_tilt_name)

if not relay_tilt or not relay_throttle then 
    print("CRITICAL: Hardware mapping failed.") return 
end

if not sublevel then
    print("CRITICAL: sublevel API not found. Please ensure the computer is on a Sable physics object.") return
end

local masterPower = 0  
local pidPitch = stabilizer.createPID(config.tuning.pid_pitch.p, config.tuning.pid_pitch.i, config.tuning.pid_pitch.d)
local pidRoll  = stabilizer.createPID(config.tuning.pid_roll.p, config.tuning.pid_roll.i, config.tuning.pid_roll.d)
local pidAlt   = stabilizer.createPID(config.tuning.pid_alt.p, config.tuning.pid_alt.i, config.tuning.pid_alt.d)

local altLockActive = false
local altLockTarget = 0
local prevLockKey = false
local baseHoverPower = 0

term.clear()

local function flightLoop()
    while true do
        local keys = input.getPressed()
        
        local lockKeyCurrentlyPressed = keys[config.controls.lock_alt]
        if lockKeyCurrentlyPressed and not prevLockKey then
            altLockActive = not altLockActive
            if altLockActive then
                local ok, pose = pcall(sublevel.getLogicalPose)
                if ok and pose and pose.position then
                    altLockTarget = pose.position.y
                end
                baseHoverPower = masterPower
                pidAlt.integral = 0
                pidAlt.prevError = 0
            end
        end
        prevLockKey = lockKeyCurrentlyPressed
        
        if altLockActive then
            if keys[config.controls.throttle_up] then
                altLockTarget = altLockTarget + (config.tuning.throttle_rate * 0.2)
            elseif keys[config.controls.throttle_down] then
                altLockTarget = altLockTarget - (config.tuning.throttle_rate * 0.2)
            end
            
            local curAlt = 0
            local ok, pose = pcall(sublevel.getLogicalPose)
            if ok and pose and pose.position then
                curAlt = pose.position.y
            end
            
            local altCorr = pidAlt:update(altLockTarget, curAlt, 0.05)
            masterPower = baseHoverPower + altCorr
            masterPower = math.max(0, math.min(15, masterPower))
        else
            if keys[config.controls.throttle_up] then
                masterPower = masterPower + config.tuning.throttle_rate
            elseif keys[config.controls.throttle_down] then
                masterPower = masterPower - config.tuning.throttle_rate
            end
            masterPower = math.max(0, math.min(15, masterPower))
        end

        local tilt_l_fwd = keys[config.controls.left_fwd]
        local tilt_l_bak = keys[config.controls.left_back]
        local tilt_r_fwd = keys[config.controls.right_fwd]
        local tilt_r_bak = keys[config.controls.right_back]

        local targetPitch, targetRoll = 0, 0
        local ok_pose, pose = pcall(sublevel.getLogicalPose)
        local ok_v, velo = pcall(sublevel.getLinearVelocity)

        if keys[config.controls.brake] and ok_pose and ok_v and pose and pose.orientation and velo then
            local p_rad, y_rad, r_rad = pose.orientation:toEuler()
            -- Rotate global velocity into the craft's local yaw space
            local sY, cY = math.sin(-y_rad), math.cos(-y_rad)
            local localX = velo.x * cY - velo.z * sY
            local localZ = velo.x * sY + velo.z * cY

            local localForward = config.tuning.brake_swap_axes and localZ or localX
            local localRight   = config.tuning.brake_swap_axes and localX or localZ
            
            localForward = localForward * (config.tuning.brake_pitch_invert or 1)
            localRight = localRight * (config.tuning.brake_roll_invert or 1)

            -- Deadzone to prevent locking into a list once we arrive at near-zero velocity
            if math.abs(localForward) < 0.2 then localForward = 0 end
            if math.abs(localRight) < 0.2 then localRight = 0 end

            -- If moving Forward (Positive), tilt rotors Backward to counter it
            if localForward > 0.2 then 
                tilt_l_bak = true; tilt_r_bak = true 
            elseif localForward < -0.2 then 
                tilt_l_fwd = true; tilt_r_fwd = true 
            end

            -- Automatically pitch to slow down. 
            -- Positive targetPitch means nose UP (backward). Negative targetPitch means nose DOWN (forward).
            targetPitch = math.max(-config.tuning.max_pitch_target, math.min(config.tuning.max_pitch_target, localForward * 5.0))
            
            -- Automatically roll to slow down.
            -- Negative targetRoll means lean LEFT. Positive targetRoll means lean RIGHT.
            -- If moving right (localRight > 0), we want to lean left (-Roll)
            targetRoll = math.max(-config.tuning.max_roll_target, math.min(config.tuning.max_roll_target, localRight * -5.0))
        else
            if keys[config.controls.strafe_left] then targetRoll = -config.tuning.max_roll_target end
            if keys[config.controls.strafe_right] then targetRoll = config.tuning.max_roll_target end

            local leftPitch = (tilt_l_fwd and -1 or 0) + (tilt_l_bak and 1 or 0)
            local rightPitch = (tilt_r_fwd and -1 or 0) + (tilt_r_bak and 1 or 0)
            targetPitch = (leftPitch + rightPitch) * (config.tuning.max_pitch_target / 2)
        end

        local tilt_outputs = {
            [config.tilt_sides.left_fwd]   = tilt_l_fwd and 15 or 0,
            [config.tilt_sides.left_back]  = tilt_l_bak and 15 or 0,
            [config.tilt_sides.right_fwd]  = tilt_r_fwd and 15 or 0,
            [config.tilt_sides.right_back] = tilt_r_bak and 15 or 0
        }

        for side, signal in pairs(tilt_outputs) do
            relay_tilt.setAnalogOutput(side, signal)
        end

        local pCorr, rCorr = 0, 0
        local p, r = 0, 0
        
        if ok_pose and pose and pose.orientation then
            local p_rad, y_rad, r_rad = pose.orientation:toEuler()
            p = math.deg(p_rad)
            r = math.deg(r_rad)
            
            p, r = p * config.tuning.gimbal_pitch_invert, r * config.tuning.gimbal_roll_invert
            
            local dt = 0.05 
            pCorr = pidPitch:update(targetPitch, p, dt)
            rCorr = pidRoll:update(targetRoll, r, dt)
        end

        local fl, fr, bl, br = 0, 0, 0, 0
        if masterPower > 0 then
            local mixed = stabilizer.mixQuad(masterPower, pCorr, rCorr, 15, altLockActive)
            fl, fr, bl, br = mixed.fl, mixed.fr, mixed.bl, mixed.br
        end

        relay_throttle.setAnalogOutput(config.throttle_sides.front_left,  math.floor(15 - fl))
        relay_throttle.setAnalogOutput(config.throttle_sides.front_right, math.floor(15 - fr))
        relay_throttle.setAnalogOutput(config.throttle_sides.back_left,   math.floor(15 - bl))
        relay_throttle.setAnalogOutput(config.throttle_sides.back_right,  math.floor(15 - br))

        -- Terminal UI
        term.setCursorPos(1, 1)
        
        local function cPrint(text)
            term.clearLine()
            print(text)
        end

        cPrint("=== AERONAUTICS FLEET OS : VTOL ===")
        cPrint("")
        cPrint(string.format(" Master Power:   %5.1f / 15.0", masterPower))
        cPrint(string.format(" Altitude Lock:  %s %s", altLockActive and "ON" or "OFF", altLockActive and string.format("(Tgt: %.1f)", altLockTarget) or ""))
        cPrint("")
        cPrint(string.format(" Target Pitch: %5.1f | Roll: %5.1f", targetPitch, targetRoll))
        cPrint(string.format(" Actual Pitch: %5.1f | Roll: %5.1f", p, r))
        cPrint(string.format(" Correction P: %5.1f | R: %5.1f", pCorr, rCorr))
        cPrint("")
        cPrint(" --- Throttle Output (0=Max, 15=Off) ---")
        cPrint(string.format(" FL: %2d  |  FR: %2d", math.floor(15 - fl), math.floor(15 - fr)))
        cPrint(string.format(" BL: %2d  |  BR: %2d", math.floor(15 - bl), math.floor(15 - br)))
        cPrint("")
        cPrint(" --- Vectoring Sub-System (0 / 15) ---")
        cPrint(string.format(" L-FWD: %2d | L-BCK: %2d", tilt_outputs[config.tilt_sides.left_fwd], tilt_outputs[config.tilt_sides.left_back]))
        cPrint(string.format(" R-FWD: %2d | R-BCK: %2d", tilt_outputs[config.tilt_sides.right_fwd], tilt_outputs[config.tilt_sides.right_back]))

        os.sleep(0.05)
    end
end

local ok, err = pcall(flightLoop)

term.clear()
term.setCursorPos(1, 1)

if not ok and err ~= "Terminated" then
    print("Flight computer crashed:")
    print(err)
end
