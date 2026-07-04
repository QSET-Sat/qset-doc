============================
CubeSat Mission Requirements 
============================

.. choice:: Project Status
   :field: Version: 0.1
   :field: Date: July 2026
   :field: Authors: Jaron

Executive Summary
=================

Provide a brief, high-level overview of the mission. What is the primary objective of the CubeSat? (e.g., "The OpenSat-1 mission aims to capture low-Earth orbit thermal imaging of wildfires...").

1. Mission Levels & Constraints
===============================

1.1 Programmatic Constraints
----------------------------
* **Launch Date:** Q4 2028-Q4 2030
* **Form Factor:** 3U `CubeSat <https://en.wikipedia.org/wiki/CubeSat>`_ standard ($10 \times 10 \times 34\text{ cm}$)
* **Target Orbit:** 400 km altitude, 45 degree inclanation

.. image:: docs\images\CubeSats_1U_3U.png


1.2 Operational Scenarios (CONOPS)
----------------------------------
Briefly list or link to the operational modes (Safe, Nominal, Science, Downlink) that the requirements must map to.


1. System Requirements & Verification Matrix (SRVM)
===================================================

.. note::
   **Verification Methods Key:**
   
   * **I (Inspection):** Visual evaluation of drawings, software code, or physical components.
   * **A (Analysis):** Mathematical modeling, simulations (thermal, structural), or calculations.
   * **D (Demonstration):** Unmeasured operation showing a function works as intended.
   * **T (Test):** Physical measurement of performance using test equipment (TVAC, vibration table).

2.1 Functional Requirements (FR)
--------------------------------

.. list-table:: Functional Requirements Matrix
   :widths: 15 45 15 25
   :header-rows: 1

   * - Req ID
     - Description
     - Method
     - Verification Success Criteria
   * - SYS-FR-001
     - The satellite shall fit within standard deployer rail constraints.
     - I, M
     - Physical dimensions must measure exactly within dispenser CAD envelope.
   * - SYS-FR-002
     - The satellite shall remain in an unpowered state until deployment switches open.
     - T
     - Deployer switches must cut off complete battery bus when depressed.
   * - SYS-FR-003
     - *[Insert New Functional Requirement]*
     - 
     - 

2.2 Performance Requirements (PR)
---------------------------------

.. list-table:: Performance Requirements Matrix
   :widths: 15 45 15 25
   :header-rows: 1

   * - Req ID
     - Description
     - Method
     - Verification Success Criteria
   * - SYS-PR-001
     - The EPS shall maintain battery cell temperatures above 0°C during eclipse.
     - A, T
     - Thermal vacuum test telemetry shows battery temperature $\ge 5^\circ\text{C}$.
   * - SYS-PR-002
     - The ADCS shall point the payload within 2.0 degrees of nadir during imaging.
     - A
     - Simulation log proves convergence within 1.5 degrees under orbital disturbances.
   * - SYS-PR-003
     - *[Insert New Performance Requirement]*
     - 
     - 


3. Subsystem-Level Constraints
==============================

3.1 Mechanical & Structural (STRUCTURES)
----------------------------------------
* **Mass Target:** Maximum $4.0\text{ kg}$ total allocation.
* **Natural Frequency:** Must be $> 100\text{ Hz}$ to avoid launch vehicle resonance.

3.2 Electrical Power System (EPS)
----------------------------------
* **Battery Capacity:** Minimum $20\text{ Wh}$ usable capacity.
* **Solar Generation:** Minimum average $6\text{ W}$ orbit-average power.

3.3 Command & Data Handling (CDH) / Flight Software (FSW)
----------------------------------------------------------
* **Fault Tolerance:** FSW shall watchdogs reset processing units within $1.0\text{ s}$ of an SEU event loop stall.

3.4 Communications (COMMS)
--------------------------
* **Frequency Bands:** UHF/VHF Amateur or S-band allocations.
* **Link Margin:** Minimum $+3\text{ dB}$ margin under worst-case atmospheric attenuation.


4. Document Control & Revision History
======================================

.. list-table:: Revision Log
   :widths: 15 15 40 30
   :header-rows: 1

   * - Revision
     - Date
     - Description of Changes
     - Author
   * - 0.1
     - 2026-07-04
     - Initial draft structural skeleton.
     - Jaron