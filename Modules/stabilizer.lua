-- =========================================================================
-- AERONAUTICS FLEET OS - STABILIZER KERNEL
-- =========================================================================
-- Provides PID controller logic and quadcopter motor mixing.
-- Handles additive/subtractive power normalization to prevent clipping.
-- =========================================================================

local stabilizer = {}

-- Factory function to create a stateful PID controller
function stabilizer.createPID(kP, kI, kD)
    return {
        p = kP or 0,
        i = kI or 0,
        d = kD or 0,
        integral = 0,
        prevError = 0,
        update = function(self, setpoint, processValue, dt)
            if dt <= 0 then return 0 end
            local err = setpoint - processValue
            
            -- Accumulate integral
            self.integral = self.integral + (err * dt)
            
            -- Anti-windup clamping to prevent the integral from running away if stuck
            -- Increased to 250 to allow trim for severe center of mass imbalances
            self.integral = math.max(-250, math.min(250, self.integral))
            
            -- Derivative (rate of change of error)
            local derivative = (err - self.prevError) / dt
            self.prevError = err
            
            return (self.p * err) + (self.i * self.integral) + (self.d * derivative)
        end
    }
end

-- Quadcopter Mixer implementation
-- This handles mixing throttle, pitch, and roll into 4 engine outputs.
function stabilizer.mixQuad(masterPower, pitchCorr, rollCorr, maxPowerLimit, prioritizeThrust)
    maxPowerLimit = maxPowerLimit or 15
    
    -- Based on VTOL polarity mapping:
    -- FL = Master + Pitch + Roll
    -- FR = Master + Pitch - Roll
    -- BL = Master - Pitch + Roll
    -- BR = Master - Pitch - Roll
    local raw = {
        fl = masterPower + pitchCorr + rollCorr,
        fr = masterPower + pitchCorr - rollCorr,
        bl = masterPower - pitchCorr + rollCorr,
        br = masterPower - pitchCorr - rollCorr
    }
    
    local rs = 15 - masterPower
    if rs <= 7 then
        -- Additive RS Normalization (Subtractive Power Normalization)
        -- Used at higher throttles (RS 0-7) to prevent exceeding max power limit.
        -- Reduces throttle on all engines if the most-demanded engine exceeds max power.
        local maxDemanded = math.max(raw.fl, raw.fr, raw.bl, raw.br)
        if maxDemanded > maxPowerLimit then
            local excess = maxDemanded - maxPowerLimit
            raw.fl = raw.fl - excess
            raw.fr = raw.fr - excess
            raw.bl = raw.bl - excess
            raw.br = raw.br - excess
        end
    else
        -- Subtractive RS Normalization (Additive Power Normalization)
        -- Used at lower throttles (RS 8-15) to prevent motors from shutting off limit.
        -- Increases throttle on all engines if the least-demanded engine falls below 0.
        local minDemanded = math.min(raw.fl, raw.fr, raw.bl, raw.br)
        if minDemanded < 0 then
            local deficit = 0 - minDemanded
            raw.fl = raw.fl + deficit
            raw.fr = raw.fr + deficit
            raw.bl = raw.bl + deficit
            raw.br = raw.br + deficit
        end
    end
    
    return {
        fl = math.max(0, math.min(maxPowerLimit, raw.fl)),
        fr = math.max(0, math.min(maxPowerLimit, raw.fr)),
        bl = math.max(0, math.min(maxPowerLimit, raw.bl)),
        br = math.max(0, math.min(maxPowerLimit, raw.br))
    }
end

return stabilizer