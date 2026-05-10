local scriptDir = fs.getDir(shell.getRunningProgram())
local rootDir = fs.combine(scriptDir, "..")
package.path = package.path .. ";/" .. scriptDir .. "/?.lua;/" .. rootDir .. "/?.lua;/VTOL/?.lua"

local input  = require("Modules.ctrl_typewriter")
local config = require("VTOL.config")

local relay_throttle = peripheral.wrap(config.hardware.relay_throttle_name)
local relay_tilt     = peripheral.wrap(config.hardware.relay_tilt_name)
local gimbal         = peripheral.find("gimbal_sensor") 

if not relay_tilt or not relay_throttle then 
    print("CRITICAL: Hardware mapping failed.") return 
end

local masterPower = 0  
local integralPitch, integralRoll = 0, 0
local lastErrPitch, lastErrRoll = 0, 0

-- Live Tuning Variables
local t_p = config.tuning.pid_pitch.p
local t_i = config.tuning.pid_pitch.i
local t_d = config.tuning.pid_pitch.d
local step_size = 0.05

local function flightLoop()
    while true do
        local t_keys = input.getPressed()
        
        if t_keys[config.controls.throttle_up] then
            masterPower = masterPower + config.tuning.throttle_rate
        elseif t_keys[config.controls.throttle_down] then
            masterPower = masterPower - config.tuning.throttle_rate
        end
        masterPower = math.max(0, math.min(15, masterPower))

        local tilt_outputs = {
            [config.tilt_sides.left_fwd]   = t_keys[config.controls.left_fwd] and 15 or 0,
            [config.tilt_sides.left_back]  = t_keys[config.controls.left_back] and 15 or 0,
            [config.tilt_sides.right_fwd]  = t_keys[config.controls.right_fwd] and 15 or 0,
            [config.tilt_sides.right_back] = t_keys[config.controls.right_back] and 15 or 0
        }

        for side, signal in pairs(tilt_outputs) do
            relay_tilt.setAnalogOutput(side, signal)
        end

        local targetPitch, targetRoll = 0, 0
        if t_keys[config.controls.strafe_left] then targetRoll = -config.tuning.max_roll_target end
        if t_keys[config.controls.strafe_right] then targetRoll = config.tuning.max_roll_target end

        local leftPitch = (t_keys[config.controls.left_fwd] and -1 or 0) + (t_keys[config.controls.left_back] and 1 or 0)
        local rightPitch = (t_keys[config.controls.right_fwd] and -1 or 0) + (t_keys[config.controls.right_back] and 1 or 0)
        targetPitch = (leftPitch + rightPitch) * (config.tuning.max_pitch_target / 2)

        local pCorr, rCorr = 0, 0
        local p, r = 0, 0
        if gimbal then
            local angles = gimbal.getAngles()
            p = type(angles) == "table" and (angles.pitch or angles.x or angles[1] or 0) or 0
            r = type(angles) == "table" and (angles.roll or angles.z or angles[2] or 0) or 0
            
            p, r = p * config.tuning.gimbal_pitch_invert, r * config.tuning.gimbal_roll_invert
            
            local errPitch = targetPitch - p
            local errRoll  = targetRoll - r
            
            integralPitch = math.max(-20, math.min(20, integralPitch + errPitch))
            integralRoll  = math.max(-20, math.min(20, integralRoll + errRoll))
            
            local dPitch = errPitch - lastErrPitch
            local dRoll  = errRoll - lastErrRoll
            lastErrPitch = errPitch
            lastErrRoll  = errRoll
            
            pCorr = (errPitch * t_p) + (integralPitch * t_i) + (dPitch * t_d)
            -- For simplicity in live tuning, we share Pitch and Roll values
            rCorr = (errRoll * t_p) + (integralRoll * t_i) + (dRoll * t_d)
        end

        local fl, fr, bl, br = 0, 0, 0, 0
        if masterPower > 0 then
            fl = math.max(0, math.min(15, masterPower + pCorr + rCorr))
            fr = math.max(0, math.min(15, masterPower + pCorr - rCorr))
            bl = math.max(0, math.min(15, masterPower - pCorr + rCorr))
            br = math.max(0, math.min(15, masterPower - pCorr - rCorr))
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

        cPrint("=== VTOL LIVE PID TUNER ===")
        cPrint("Use Computer Keyboard to change values!")
        cPrint("-------------------------------------")
        cPrint(" [Q]/[A] Adjust P : " .. string.format("%.2f", t_p))
        cPrint(" [W]/[S] Adjust I : " .. string.format("%.2f", t_i))
        cPrint(" [E]/[D] Adjust D : " .. string.format("%.2f", t_d))
        cPrint(" [R]/[F] Step Size: " .. string.format("%.2f", step_size))
        cPrint("-------------------------------------")
        cPrint(string.format(" Act Pitch: %5.1f | Roll: %5.1f", p, r))
        cPrint(string.format(" Tar Pitch: %5.1f | Roll: %5.1f", targetPitch, targetRoll))
        cPrint(string.format(" P-Corr   : %5.1f | R-Corr: %5.1f", pCorr, rCorr))

        os.sleep(0.05)
    end
end

local function uiLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.q then
            t_p = t_p + step_size
        elseif key == keys.a then
            t_p = math.max(0, t_p - step_size)
        elseif key == keys.w then
            t_i = t_i + step_size
        elseif key == keys.s then
            t_i = math.max(0, t_i - step_size)
        elseif key == keys.e then
            t_d = t_d + step_size
        elseif key == keys.d then
            t_d = math.max(0, t_d - step_size)
        elseif key == keys.r then
            if step_size == 0.01 then step_size = 0.05
            elseif step_size == 0.05 then step_size = 0.1
            elseif step_size == 0.1 then step_size = 1.0 end
        elseif key == keys.f then
            if step_size == 1.0 then step_size = 0.1
            elseif step_size == 0.1 then step_size = 0.05
            elseif step_size == 0.05 then step_size = 0.01 end
        end
    end
end

term.clear()
parallel.waitForAny(flightLoop, uiLoop)
term.clear()
term.setCursorPos(1, 1)
print("Tuner terminated. Copy your favorite values directly to VTOL/config.lua!")
