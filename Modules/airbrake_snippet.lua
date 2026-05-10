-- This is an extracted module meant for future implementation
-- of velocity vector reversal (air brake) for larger airships.

local M = {}

-- Config expected:
-- brake_swap_axes = false
-- brake_pitch_invert = 1
-- brake_roll_invert = 1

function M.calculateBrakePitchRoll(velo, y_rad_raw, config_tuning)
    local sY, cY = math.sin(-y_rad_raw), math.cos(-y_rad_raw)
    local localX = velo.x * cY - velo.z * sY
    local localZ = velo.x * sY + velo.z * cY

    local tempFwd = config_tuning.brake_swap_axes and localX or localZ
    local tempRight = config_tuning.brake_swap_axes and localZ or localX
    
    tempFwd = tempFwd * (config_tuning.brake_pitch_invert or 1)
    tempRight = tempRight * (config_tuning.brake_roll_invert or 1)
    
    return tempFwd, tempRight
end

-- Example main loop integration snippet:
--[[
        local is_moving = pitch_fwd or pitch_back or roll_left or roll_right
        local active_max_pitch = altLockActive and (config.tuning.max_pitch_target_lock or 2) or config.tuning.max_pitch_target
        local active_max_roll = altLockActive and (config.tuning.max_roll_target_lock or 2) or config.tuning.max_roll_target

        if keys[config.controls.brake] or (altLockActive and not is_moving) then
            local brake_max_p = math.max(active_max_pitch, config.tuning.max_pitch_target / 1.5)
            local brake_max_r = math.max(active_max_roll, config.tuning.max_roll_target / 1.5)
            
            if math.abs(localForward) < 0.2 and math.abs(localRight) < 0.2 then
                targetPitch = 0
                targetRoll = 0
            else
                targetPitch = math.max(-brake_max_p, math.min(brake_max_p, localForward * 1.5))
                targetRoll = math.max(-brake_max_r, math.min(brake_max_r, localRight * -1.5))
            end
        else
            -- Normal controls here
        end
]]

return M
