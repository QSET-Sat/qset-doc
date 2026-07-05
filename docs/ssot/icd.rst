=====================================================
Interface Control Document (ICD)
=====================================================

.. dropdown:: Document Metadata

   :Version: 0.1
   :Last Updated: July 2026
   :Status: Baseline

1. Document Scope & Purpose
===========================

This document serves as the binding physical, electrical, and logical contract between all CubeSat subsystems. Any modification to a boundary, pinout, packet structure, or power characteristic defined within this document requires a formal System Change Request and approval from all affected subteam managers.

---

2. Mechanical & Structural Interfaces
=====================================

2.1 Main Bus Form Factor Constraints
------------------------------------
All internal subsystem printed circuit boards (PCBs) must comply with the standard PC104 form factor constraints to stack properly within the structural chassis.

* **Maximum Component Height (Top of PCB):** 8.5 mm
* **Maximum Component Height (Bottom of PCB):** 2.0 mm
* **Standard Board Dimensions:** 90.17 mm $\times$ 95.89 mm
* **Structural Mounting Standoffs:** M3 x 15mm aluminum threaded spacers



2.2 Payload Mechanical Clearance Envelope
------------------------------------------
The payload subsystem occupies the top U of the stack. It must maintain a minimum clear buffer distance of **5.0 mm** from the internal deployment switch rails on the +Z face of the chassis to prevent mechanical interference with launcher deployment tabs.

---

1. Electrical Interfaces & Power Characteristics
================================================

3.1 Master PC104 Bus Pin Allocations
------------------------------------
Power rails and data buses are shared across subsystems using a standardized 104-pin stackthrough connector. 

.. list-table:: Main Power & Data Bus Pinout
   :widths: 10 20 20 50
   :header-rows: 1

   * - Pin #
     - Signal Name
     - Voltage / Logic Level
     - Primary Functional Description
   * - H1-1
     - 3V3_SYS
     - 3.3V DC (Regulated)
     - Main low-power supply rail for microcontrollers
   * - H1-2
     - 5V_SYS
     - 5.0V DC (Regulated)
     - Main supply rail for sensors and payload logic
   * - H1-5
     - I2C_SDA
     - 3.3V I2C Data
     - Shared System Data Line (Requires 4.7kΩ pull-up on EPS)
   * - H1-6
     - I2C_SCL
     - 3.3V I2C Clock
     - Shared System Clock Line
   * - H1-11
     - CAN_H
     - 5.0V CAN Bus High
     - High-reliability backbone communication line
   * - H1-12
     - CAN_L
     - 5.0V CAN Bus Low
     - High-reliability backbone communication line

3.2 Subsystem Electrical Load Profiles
--------------------------------------
This section tracks the input hardware voltage tolerances and transient spikes that the Electrical Power System (EPS) regulators must accommodate.

.. list-table:: Subsystem Electrical Load Requirements
   :widths: 15 15 20 20 30
   :header-rows: 1

   * - Subsystem
     - Supply Rail
     - Max Continuous Current
     - Max Peak Current (Inrush)
     - Input Voltage Tolerance
   * - (OBC)
     - 3V3_SYS
     - 350 mA
     - 400 mA (Bootup spike)
     - $3.3\text{V} \pm 5\%$
   * - COMMS
     - 5V_SYS
     - 1.5 A (S-Band Transmit)
     - 2.8 A (PA Turn-on, <15ms)
     - $5.0\text{V} \pm 2\%$ (Low Ripple)
   * - ADCS
     - 3V3_SYS
     - 300 mA
     - 800 mA (Torquer Spike)
     - $3.3\text{V} \pm 10\%$
   * - PAYLOAD
     - 5V_SYS
     - 600 mA
     - 1.2 A (Sensor Initialization)
     - $5.0\text{V} \pm 5\%$

3.3 RF Feedline Coaxial Interface
---------------------------------
The connection between the COMMS transmitter board and the deployable antenna assembly must utilize an edge-mount **SMA Female connector** with a matched impedance of $50\ \Omega$.

---

1. Software & Logical Data Interfaces
=====================================

4.1 Shared I2C Addressing Architecture
--------------------------------------
To prevent bus contention, all peripherals connected to the primary $\text{I}^2\text{C}$ lines must utilize unique 7-bit software destination addresses.

* **Electrical Power System (EPS):** `0x40`
* **Attitude Determination (ADCS):** `0x42`
* **On-Board Computer (CDH):** `0x44` (Master Node)
* **Payload Controller:** `0x46`

4.2 Standard Telemetry Packet Structure
---------------------------------------
All frames passed between subsystems over the internal data network must use the following unified 8-byte header block structure prior to appending payload bytes.

.. list-table:: Unified Telemetry Packet Header Schema
   :widths: 15 20 25 40
   :header-rows: 1

   * - Byte Offset
     - Field Name
     - Data Type
     - Description / Notes
   * - 0
     - START_BYTE
     - uint8_t
     - Fixed synchronization byte value (Always `0xAA`)
   * - 1
     - ORIGIN_ID
     - uint8_t
     - Sender Subsystem identifier code (`0x01`=CDH, `0x02`=EPS, `0x03`=COMMS, `0x04`=PL)
   * - 2-3
     - PACKET_ID
     - uint16_t
     - Monotonically increasing sequence count for packet loss tracking
   * - 4-5
     - LENGTH
     - uint16_t
     - Total length of trailing data payload bytes (Excludes this header)
   * - 6-7
     - HEADER_CRC
     - uint16_t
     - Modbus CRC-16 computation over bytes 0-5

---

5. Document Control & Revisions
===============================

.. list-table:: Revision History
   :widths: 15 15 45 25
   :header-rows: 1

   * - Version
     - Date
     - Description
     - Author
   * - 1.0
     - 2026-07-04
     - Unified physical, electrical, and logical baselines for CDH/EPS/COMMS.
     - Systems Engineering Lead