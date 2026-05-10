# Hover-Capable Quad-Tilt VTOL Dropship

## Overview
A quad-rotor vertical take-off and landing (VTOL) dropship built using Create Aeronautics. It uses directional gearshifts for pitch/roll vectoring and analog RPM limiters for individual rotor throttle to achieve stabilization and flight.

## Required Hardware & Peripherals
* **Sensors:** 1x `gimbal_sensor` (Upright orientation)
* **Inputs:** 1x `linked_typewriter`
* **Controllers:** 2x `redstone_relay`

## Sub-System Specifications

### Sub-System: Throttle Control
* **Controller:** `redstone_relay_1`
* **Hardware:** Analog RPM Limiters (Individual rotor power)
* **Logic Constraint:** [ANALOG] [INVERTED] Signal 15 = OFF (0 RPM). Signal 0 = MAX RPM.
* **Mapping:**
  * `left` -> Front Left Rotor (FL)
  * `right` -> Front Right Rotor (FR)
  * `back` -> Back Left Rotor (BL)
  * `top` -> Back Right Rotor (BR)

### Sub-System: Directional Vectoring (Tilt)
* **Controller:** `redstone_relay_2`
* **Hardware:** Directional Gearshifts + Torsion Springs
* **Logic Constraint:** [BINARY] Exactly 15 (Tilt activated) or 0 (Neutral/Straight).
* **Mapping:**
  * `left` -> Left Pods Forward (FWD)
  * `back` -> Left Pods Backward (BACK)
  * `right` -> Right Pods Forward (FWD)
  * `top` -> Right Pods Backward (BACK)
