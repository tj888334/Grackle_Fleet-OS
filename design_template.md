# [Vehicle Name / Project Title]

## Overview
[A brief human-readable description of the vehicle, its purpose, and how it fundamentally operates in the Create/Aeronautics physics engine.]

## Required Hardware & Peripherals
[List all physical CC:Tweaked peripherals required to be attached to the computer/network for this vehicle to function.]
* **Sensors:** (e.g., 1x `gimbal_sensor`, 1x `speedometer`)
* **Inputs:** (e.g., 1x `linked_typewriter`, or wireless modems)
* **Controllers:** (e.g., 2x `redstone_relay`, specific sequencers)

## Sub-System Specifications
[Break down the specific moving systems (throttle, steering, landing gear) so both the AI and engineers know exactly how signals translate to physical movement.]

### Sub-System: [Name of Sub-System, e.g., Throttle Control]
* **Controller:** [Peripheral name, e.g., `redstone_relay_1`]
* **Hardware:** [Physical Create Mod mechanism, e.g., Analog RPM Limiters, Directional Gearshifts]
* **Logic Constraint:** [How the logic works, e.g., [BINARY] (0 or 15), [ANALOG] (0-15), [INVERTED] (15 is OFF, 0 is MAX)]
* **Mapping:**
  * `[controller_side]` -> `[Action/Component Affected]`
  * `[controller_side]` -> `[Action/Component Affected]`

### Sub-System: [Name of Sub-System, e.g., Directional Vectoring]
* **Controller:** [Peripheral name]
* **Hardware:** [Physical mechanism]
* **Logic Constraint:** [Logic constraints]
* **Mapping:**
  * `[controller_side]` -> `[Action/Component Affected]`

## Software & Configuration Guidelines
* **Control Scheme:** [What is the expected mapping for human pilots?]
* **Tuning Requirements:** [Are there specific PID values, max speeds, or rates that need configuring?]
