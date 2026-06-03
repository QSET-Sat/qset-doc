Traceability & The V-Model
==========================

In aerospace, every design choice and test must trace back to a fundamental mission requirement. This is often visualized as the **V-Model**.

Using Sphinx-Needs, we can automatically track these relationships.

Example Requirements
--------------------

.. req:: Wide Operating Temperature
   :id: REQ_SYS_001

   The CubeSat shall operate normally in a temperature range of -20°C to +60°C.

.. req:: Communication Range
   :id: REQ_COM_001

   The Comms system must successfully transmit telemetry at a slant range of 1,500 km.

Example Specifications
----------------------

These design specifications satisfy the requirements defined above.

.. spec:: Passive Thermal Coating
   :id: SPEC_MEC_001
   :satisfies: REQ_SYS_001

   The chassis will be coated in a specialized thermal paint to passively regulate temperature.

.. spec:: High-Gain UHF Antenna
   :id: SPEC_COM_001
   :satisfies: REQ_COM_001

   We will deploy a deployable turnstile antenna with a minimum gain of 3dBi.

Example Test Cases
------------------

These test cases verify that the design specifications meet their goals.

.. test:: Thermal Vacuum Bakeout
   :id: TEST_TVAC_001
   :verifies: SPEC_MEC_001

   Place the assembled CubeSat in the TVAC chamber. Cycle between -20°C and +60°C for 5 cycles.

.. test:: Ground Station Link Test
   :id: TEST_RF_001
   :verifies: SPEC_COM_001

   Verify signal integrity and bit error rate using the portable ground station from a 10 km line-of-sight distance.

Traceability Matrix
-------------------

The table below is automatically generated. It shows how requirements map to design specifications and test cases.
This ensures we have no "gaps" in our engineering process (e.g., a requirement without a test).

.. needtable::
   :columns: id, title, type, satisfies, verifies
   :style: table
