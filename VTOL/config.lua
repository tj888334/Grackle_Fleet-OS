-- VTOL Configuration File

return {
    -- Keybinds matched to the ctrl_typewriter output
    controls = {
        left_fwd  = "W", left_back = "S",
        right_fwd = "UP", right_back= "DOWN",
        strafe_left  = "A", strafe_right = "D",
        throttle_up   = "SPACE", throttle_down = "SHIFT",
        lock_alt      = "L", brake = "B",
    },

    -- Flight mechanics and stabilisation tuning
    tuning = {
        -- Rate at which master power increases/decreases per tick. 
        -- Min: 0.1 (very slow resp), Max: 15 (instant snap to max)
        throttle_rate = 0.5,
        
        -- Maximum target angles for pitch and roll in degrees.
        -- Min: 0, Max: ~45 (higher values risk instability)
        max_pitch_target = 12, max_roll_target  = 15,
        
        -- PID controller gains (Proportional, Integral, Derivative) for flight stabilization.
        pid_alt   = { p = 1.0, i = 0.1, d = 0.5 },
        -- P (Proportional): Tuning this alters how hard the craft tries to correct tilt. 
        --    Recommended: 0.3 - 0.6. Min: 0.1. Max: 1.0+. (Too high = violent rapid shaking).
        -- I (Integral): Corrects sustained, long-term drift caused by unbalanced weight.
        --    Recommended: 0.0 - 0.02. Min: 0.0. Max: 0.1. (Too high = slow, growing oscillations).
        -- D (Derivative): Dampens the movement to prevent overshooting the target angle.
        --    Recommended: 0.1 - 0.3. Min: 0.0. Max: 1.0. (Too high = jittery, stuttering flight).
        pid_pitch = { p = 0.1, i = 0.02, d = 0.1 },
        pid_roll  = { p = 0.1, i = 0.02, d = 0.1 },
        
        -- Multipliers to invert sensor readings if the gimbal is mounted backwards/upside-down.
        -- Valid values: 1 (normal) or -1 (inverted)
        gimbal_pitch_invert = -1, gimbal_roll_invert  = 1,
        
        -- Swap the axes used for airbraking if it rolls instead of pitching
        brake_swap_axes = true,
        brake_pitch_invert = 1, -- Change to -1 if the brake pitches the wrong way
        brake_roll_invert = 1,  -- Change to -1 if the brake rolls the wrong way
    },

    -- Names of the peripheral components attached to the vehicle network
    hardware = {
        relay_throttle_name = "redstone_relay_1", relay_tilt_name = "redstone_relay_2"
    },

    -- Redstone relay mapping for the analog throttle (controls engine RPM limiters, 0-15 inverted)
    -- Valid directions: "front", "back", "left", "right", "top", "bottom"
    throttle_sides = {
        front_left  = "left", front_right = "right",
        back_left   = "back", back_right  = "top"
    },

    -- Redstone relay mapping for the binary tilt mechanisms (directional gearshifts, 0 or 15)
    tilt_sides = {
        left_fwd   = "left", left_back  = "back",
        right_fwd  = "right", right_back = "top"
    }
}
