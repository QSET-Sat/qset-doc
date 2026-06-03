:orphan:

Subteam Project Document Template
=================================

.. rst-class:: section-subtitle

   A standardized template for documenting hardware subsystems, software modules, and test procedures.

.. grid:: 1 2 2 3
   :gutter: 2

   .. grid-item-card:: Component Status
      :shadow: md

      .. bdg-success-line:`Flight Proven`
      .. bdg-warning-line:`Prototype`
      .. bdg-danger-line:`Experimental`

   .. grid-item-card:: Lead Contact
      :shadow: md

      * **Subteam Lead**: [Name] ([Slack Handle])
      * **Primary Author**: [Name] ([Slack Handle])

Overview
--------
Provide a brief, high-level description of what this project/component is, its purpose in the overall mission, and its current development status.

System Architecture
-------------------
Use Mermaid diagrams to visualize components, hardware interfaces, software state machines, or physical layouts.

.. mermaid::

   graph TD
      A[Sensor Input] --> B(Processing Unit)
      B --> C{Decision Logic}
      C -- OK --> D[Telemetry Output]
      C -- Error --> E[Fault Recovery State]

Traceability (V-Model)
----------------------
Document the requirements, design specifications, and verification test cases for this project.

Requirements
^^^^^^^^^^^^
Define the system or subsystem requirements that this project is obligated to satisfy.

.. req:: Temperature Survival
   :id: REQ_TEMP_001
   :status: draft

   The subsystem shall operate within a thermal environment of -10°C to +50°C.

Design Specifications
^^^^^^^^^^^^^^^^^^^^^
Define the implementation designs that satisfy the requirements.

.. spec:: Thermal Insulation Layers
   :id: SPEC_THERM_001
   :satisfies: REQ_TEMP_001

   The design includes 3 layers of Kapton insulation wrap around the battery core to maintain temperatures above 0°C.

Test Cases & Verification
^^^^^^^^^^^^^^^^^^^^^^^^^
Define the test cases used to verify that the specifications satisfy the requirements.

.. test:: Thermal Cycling Test
   :id: TEST_THERM_001
   :verifies: SPEC_THERM_001

   Subject the insulated module to temperature cycles in the thermal chamber from -15°C to +55°C for 24 hours.

Traceability Matrix
^^^^^^^^^^^^^^^^^^^
This table auto-generates links between requirements, specs, and tests:

.. needtable::
   :filter: id in ["REQ_TEMP_001", "SPEC_THERM_001", "TEST_THERM_001"]
   :columns: id, title, type, satisfies, verifies
   :style: table

Lessons Learned Log
-------------------
At the end of every prototyping or testing phase, update this log.

.. tab-set::

   .. tab-item:: 2026-06-01 (Issue #45)

      * **What Failed**: The thermal sensor readings drifted when exposed to temperatures below -5°C.
      * **Why It Failed**: Lack of calibration data and thermal coupling on the sensor PCB.
      * **Resolution**: Added a software calibration curve offset and applied thermal paste to the coupling pad.

   .. tab-item:: 2026-05-15 (Issue #32)

      * **What Failed**: Mounting brackets bent during vibration simulation.
      * **Why It Failed**: Structural wall thickness was only 1.2mm.
      * **Resolution**: Increased wall thickness to 2.0mm and switched material to Al 6061-T6.
