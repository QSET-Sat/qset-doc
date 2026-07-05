=====================================================
System Requirements & Verification
=====================================================

.. dropdown:: Document Metadata

   :Document ID: SYS-REQ-001
   :Version: 1.0
   :Last Updated: July 2026

Overview
========

This document establishes the official system-level requirements for the CubeSat mission. Every requirement listed here is binding and must be formally verified before the satellite is cleared for integration.

.. important::
   **The "Shall" Rule:** Requirements using the word **shall** are mandatory and require formal verification. Requirements using the word **should** are non-binding design goals.

---

.. note::
   **Verification Methods Key:**
   
   * **I (Inspection):** Visual evaluation of drawings, software code, or physical components.
   * **A (Analysis):** Mathematical modeling, simulations (thermal, structural), or calculations.
   * **D (Demonstration):** Unmeasured operation showing a function works as intended.
   * **T (Test):** Physical measurement of performance using test equipment (TVAC, vibration table).


Requirements Summary Matrix
===========================

.. needtable::
   :types: req
   :columns: id, title, status, verification

---

Functional Requirements
=======================

.. req:: Mission Lifetime
   :id: REQ_SYS_101
   :status: Draft
   :verification: Analysis

   The satellite shall operate successfully in orbit for at least 12 months.

.. req:: Communication Link
   :id: REQ_SYS_102
   :status: Draft
   :verification: Test

   The satellite shall establish contact with the ground station at least once every 24 hours.

.. req:: Power Recovery
   :id: REQ_SYS_104
   :status: Draft
   :verification: Test

   The payload shall autonomously recover in the case of a dead battery pack


.. req:: Power Mode Autonomy
   :id: REQ_SYS_105
   :status: Draft
   :verification: Test

   The flight software shall autonomously transition to Safe Mode if the battery pack drop below 6.5V.

.. req:: Tether Deployment
   :id: REQ_SYS_106
   :status: Draft
   :verification: Test, Analysis, Inspection

   The Payload shall reliably deploy and not break when exposed to launch vibration conditions

.. req:: CAN Bus
   :id: REQ_SYS_107
   :status: Draft
   :verification: Test, Inspection

   All MCU's chosen shall have the capabillity to have two individual CAN lines


---

Performance Requirements
========================

.. req:: Power Generation Margin
   :id: REQ_SYS_201
   :status: Draft
   :verification: Analysis

   The Electrical Power System (EPS) shall generate a minimum orbit-average power (OAP) of 5.5 W under worst-case beta angle conditions.

.. req:: Communication Link Margin
   :id: REQ_SYS_202
   :status: Draft
   :verification: Analysis

   The radio communication links shall maintain a minimum link margin of +3 dB during nominal ground station passes.

.. req:: GNSS
   :id: REQ_SYS_203
   :status: Draft
   :verification: Analysis

   The GNSS position of the Satillite should be refreshed once per second.

.. req:: Payload Cathode
   :id: REQ_SYS_204
   :status: Draft
   :verification: Test, Analysis, Inspection

   The Payload shall operate at a voltage and current which allows for useage throughout the mission without degrading the cathode before the end of mission

---

Physical & Environmental Requirements
=====================================

.. req:: Mass Limit
   :id: REQ_SYS_301
   :status: Draft
   :verification: Inspection, Test

   The total satellite mass shall not exceed 3.0 kg.

.. req:: Mechanical Envelope
   :id: REQ_SYS_302
   :status: Draft
   :verification: Inspection

   The integrated satellite dimensions shall comply with the standard 3U CubeSat profile ($100 \times 100 \times 340.5\text{ mm}$).

   .. image:: ../images/CubeSats_1U_3U.png
      :align: center
      :alt: 1U and 3U CubeSat Form Factor Comparison
      :scale: 30

.. req:: Launch Vibration Survival
   :id: REQ_SYS_303
   :status: Draft
   :verification: Test

   The satellite structural frame shall withstand random vibration profiles matching RXD's guide without structural deformation.

.. req:: Component Temperature
   :id: REQ_SYS_304
   :status: Draft
   :verification: Inspection

    All components chosen for boards shall be rated for -40 - 85 degrees C 

.. req:: Component Selection
   :id: REQ_SYS_305
   :status: Draft
   :verification: Inspection

    All components chosen for boards shall be rated AEC-Q at a minimum or have space heritage 

---

Document Control & Revisions
===============================

.. list-table:: Revision History
   :widths: 15 15 45 25
   :header-rows: 1

   * - Version
     - Date
     - Description
     - Author
   * - 0.1
     - 2026-07-04
     - Migrated requirements architecture to custom Sphinx directives.
     - Jaron