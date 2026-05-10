local experimentalPitchRollWithAltDrop = [[
    local is_moving = pitch_fwd or pitch_back or roll_left or roll_right
    if is_moving and not was_moving then
        baselineAlt = curAlt
    elseif not is_moving then
        baselineAlt = curAlt
    end
    was_moving = is_moving

    local alt_drop = baselineAlt - curAlt
    local drop_factor = 1.0
    if alt_drop > 0 then
        local max_drop = altLockActive and (config.tuning.max_alt_drop_lock or 1.0) or (config.tuning.max_alt_drop_manual or 3.5)
        -- Reduce angle proportionately up to max_drop blocks of drop
        drop_factor = math.max(0, 1.0 - (alt_drop / max_drop))
    end

    if pitch_fwd then targetPitch = -config.tuning.max_pitch_target * drop_factor end
    if pitch_back then targetPitch = config.tuning.max_pitch_target * drop_factor end
    if roll_left then targetRoll = -config.tuning.max_roll_target * drop_factor end
    if roll_right then targetRoll = config.tuning.max_roll_target * drop_factor end
]]

return {
    experimental_code = experimentalPitchRollWithAltDrop,
    auto_tune_climb_test = [[
local t_climb = 0
local pidAltClimb = stabilizer.createPID(config.tuning.pid_alt.p, config.tuning.pid_alt.i, config.tuning.pid_alt.d)
local currentAltForClimb = 0
local ok_c, pc = pcall(sublevel.getLogicalPose)
if ok_c and pc and pc.position then currentAltForClimb = pc.position.y end
local target_climb_alt = currentAltForClimb + 5.0

while t_climb < 4.0 do
    local p, y, r = getEuler()
    local curAlt = currentAltForClimb
    local ok2, pose2 = pcall(sublevel.getLogicalPose)
    if ok2 and pose2 and pose2.position then curAlt = pose2.position.y end
    local dt = 0.05
    local altCorr = pidAltClimb:update(target_climb_alt, curAlt, dt)
    local tilt_factor = math.max(0.5, math.cos(math.rad(p)) * math.cos(math.rad(r)))
    local master = math.max(0, math.min(15, (takeoffPower + altCorr) / tilt_factor))
    local mixed = stabilizer.mixQuad(master, 0, 0, 15)
    setHardwareOutput(config.outputs.main_throttle.fl, math.floor(15 - math.max(0, math.min(15, mixed.fl))), true)
    setHardwareOutput(config.outputs.main_throttle.fr, math.floor(15 - math.max(0, math.min(15, mixed.fr))), true)
    setHardwareOutput(config.outputs.main_throttle.bl, math.floor(15 - math.max(0, math.min(15, mixed.bl))), true)
    setHardwareOutput(config.outputs.main_throttle.br, math.floor(15 - math.max(0, math.min(15, mixed.br))), true)
    os.sleep(dt)
    t_climb = t_climb + dt
end

tPrint(" -> Gradually increasing tilt angle until altitude drops significantly...")

local max_test_angle = 25
local max_safe_angle = 15
local t_fwd = 0

local start_alt_fwd = 0
local ok_pose_start, pose_start = pcall(sublevel.getLogicalPose)
if ok_pose_start and pose_start and pose_start.position then start_alt_fwd = pose_start.position.y end

local min_alt_fwd = start_alt_fwd
local pidPitchFwd = stabilizer.createPID(0.1, 0.02, 0.1)
local pidRollFwd = stabilizer.createPID(0.1, 0.02, 0.1)

local is_aborting = false

while t_fwd < 2.5 do
    -- Ramp from 0 to max_test_angle over 2.5 seconds
    local target_p = -(t_fwd / 2.5) * max_test_angle
    
    local p, y, r = getEuler()
    local dt = 0.05
    
    local cAlt = start_alt_fwd
    local ok2, pose2 = pcall(sublevel.getLogicalPose)
    if ok2 and pose2 and pose2.position then 
        cAlt = pose2.position.y
        if cAlt < min_alt_fwd then min_alt_fwd = cAlt end
    end
    
    local alt_drop = start_alt_fwd - cAlt
    
    if alt_drop > 0.8 then
        tPrint(string.format("  -> Altitude drop exceeded 0.8 blocks at %.1f degrees.", -target_p))
        max_safe_angle = math.max(5, math.floor(-target_p - 2.0))
        is_aborting = true
        break
    end
    
    local tilt_factor = math.max(0.3, math.cos(math.rad(p)) * math.cos(math.rad(r)))
    local master = math.max(0, math.min(15, takeoffPower / tilt_factor))
    
    local mixed = stabilizer.mixQuad(master, pidPitchFwd:update(target_p, p, dt), pidRollFwd:update(0, r, dt), 15)
    
    setHardwareOutput(config.outputs.main_throttle.fl, math.floor(15 - math.max(0, math.min(15, mixed.fl))), true)
    setHardwareOutput(config.outputs.main_throttle.fr, math.floor(15 - math.max(0, math.min(15, mixed.fr))), true)
    setHardwareOutput(config.outputs.main_throttle.bl, math.floor(15 - math.max(0, math.min(15, mixed.bl))), true)
    setHardwareOutput(config.outputs.main_throttle.br, math.floor(15 - math.max(0, math.min(15, mixed.br))), true)
    
    if math.abs(p) > 50 or math.abs(r) > 50 then
        tPrint("  -> ABORTING: Dangerous angle reached")
        max_safe_angle = math.max(5, math.floor(-target_p - 5.0))
        is_aborting = true
        break
    end
    
    os.sleep(dt)
    t_fwd = t_fwd + dt
end

if not is_aborting then
    max_safe_angle = max_test_angle
    tPrint(string.format("  -> Drone achieved test maximum (%.1f deg) with minimal altitude loss.", max_test_angle))
end
]]
}
