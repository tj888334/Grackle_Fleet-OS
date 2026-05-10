# Drone Hardware & Requirements Specification

## Overview
A small (9x9x3), nimble, manned recon craft. Operates similarly to a real-world quadcopter drone, utilizing independent propeller throttles for pitch, roll, and altitude. Yaw is controlled by a dedicated perpendicular forward-mounted propeller due to torque limitations in Create Aeronautics.

## Sensors & Input
* **Computer Setup**: 
  * One central computer.
  * `linked_typewriter` (Mechanical Keyboard) is mounted on the **top** side.
  * A `redstone_relay` is mounted on the **back** side.
  * The computer's **left** and **right** sides are open.
  * The `redstone_relay` provides 5 open sides.
  * This provides exactly 7 output sides (5 on relay + 2 on computer), which is enough for the 4x main prop throttles, 1x yaw throttle, and 2x yaw direction signals.
* **Secondary Input**: `linked_controller` (Optional/Future remote control implementation).

## Sub-System 1: Main Prop Throttle (Flight & Stabilization)
* **Configuration**: Four fixed-position propellers arranged diagonally from the center of gravity. 
* **Hardware**: 4x Analog Gearshifts.
* **Control Logic [INVERTED]**: Signal 15 = OFF, Signal 0 = MAX RPM. (1 redstone link each).
* **Mapping**: 
  * Front-Left (FL)
  * Front-Right (FR)
  * Back-Left (BL)
  * Back-Right (BR)
* **Mechanics**:
  * Altitude is maintained by base master throttle.
  * Pitch and Roll are achieved by varying the throttle distribution across these four propellers (e.g., lower front throttle + higher back throttle = pitch forward).
  * Throttle response curve should be configurable.

## Sub-System 2: Yaw Control
* **Configuration**: Two fixed propellers mounted perpendicular to the main props facing sideways. One in the front (between FL/FR), one in the back (between BL/BR).
* **Hardware**: 
  * 2x Directional Gearshifts (Direction/Activation control)
* **Control Logic (Direction) [BINARY]**: 
  * Default (Unpowered) = Propellers OFF
  * Front Rotor Left = (1 redstone link)
  * Front Rotor Right = (1 redstone link)
  * Rear Rotor Left = (1 redstone link)
  * Rear Rotor Right = (1 redstone link)
* **Mechanics**:
  * Program turns individual rotors to left or right direction depending on desired yaw input, without analog acceleration curves.
  * To yaw left: Front left, Rear right.
  * To yaw right: Front right, Rear left.

## Sub-System 3: Flight Control Mapping
* **Method**: Default input via `linked_typewriter`. All controls configurable.
* **Default Bindings**:
  * `UP` = Throttle Up
  * `DOWN` = Throttle Down
  * `RIGHT` = Yaw Right
  * `LEFT` = Yaw Left
  * `W` = Pitch Forward
  * `S` = Pitch Backward
  * `D` = Roll Right
  * `A` = Roll Left
