-- Drone Configuration File
return {
    -- Key bindings for flight controls.
    -- These map to strings returned by ctrl_typewriter.lua
    -- e.g., "W", "S", "LEFT", "RIGHT", "UP", "DOWN", "L", "B"
    controls = {
        pitch_fwd = "W", pitch_back = "S",
        roll_left = "A", roll_right = "D",
        yaw_left  = "LEFT", yaw_right = "RIGHT",
        throttle_up = "UP", throttle_down = "DOWN",
        lock_alt = "L"
    },

    -- Flight dynamics and scaling.
    tuning = {
        -- Base throttle increments per tick when holding throttle up/down.
        -- Higher = faster throttle spool up, Lower = more precision.
        throttle_rate = 0.3,
        
        -- Rate at which target altitude changes when holding throttle up/down in altitude lock mode.
        alt_throttle_rate = 0.3,
        
        -- Max target degrees for tilting.
        -- Represents the maximum angle the drone will attempt to achieve when full stick is applied.
        max_pitch_target = 25, 
        max_roll_target = 15,
        max_pitch_target_lock = 3,
        max_roll_target_lock = 3,
        
        -- Altitude Hold PID (Proportional, Integral, Derivative)
        -- p: Restores current alt to target alt. High = aggressive climb/drop.
        -- i: Accommodates weight changes. High = corrects steady error, too high = oscillations.
        -- d: Dampens momentum. High = smoother stops, too high = jittery.
        pid_alt   = { p = 1.0, i = 0.1, d = 0.5 },
        
        -- Pitch & Roll PID Stabilization
        -- Auto-Tune can override these values. 
        -- Generally, p = 0.08 to 0.12, i = 0.0, d = 0.1 to 0.2
        pid_pitch = { p = 0.254, i = 0.013, d = 0.203 },
        pid_roll  = { p = 0.088, i = 0.004, d = 0.071 },
        
        -- Orientation Mapping: Fixes inverted reading from Gimbal Sensor
        -- Set to 1 or -1. Auto-Tune will attempt to automatically correct this.
        gimbal_pitch_invert = 1,
        gimbal_roll_invert = -1, -- Inverted to fix instant flipping on Starboard/Port side
    },

    -- Hardware peripheral mapping
    -- Specifies where each analog/binary redstone signal is sent.
    -- device: "relay" (looks for Redstone Relay peripheral) or "computer" (direct redstone output)
    -- side: "top", "bottom", "left", "right", "front", "back"
    outputs = {
        -- Main propeller analog throttles (0 = Full Power, 15 = Off via Analog Gearshift)
        main_throttle = {
            fl = { device = "relay", side = "right" },
            fr = { device = "relay", side = "left" },
            bl = { device = "relay", side = "back" },
            br = { device = "relay", side = "top" },
        },
        
        -- Yaw propeller directional binary signals (true = active via Directional Gearshift)
        yaw_direction = {
            front_left = { device = "computer", side = "left" }, 
            front_right = { device = "computer", side = "right" },
            rear_left = { device = "computer", side = "bottom" },
            rear_right = { device = "relay", side = "bottom" }
        }
    }
}
