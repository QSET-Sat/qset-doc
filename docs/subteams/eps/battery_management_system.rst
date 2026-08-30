Battery Board
=============

:Status: Draft
:Project Lead: Donovan Woo
:Reviewers: TBD
:Last Updated: 2026-08-29
:Revision: v0.2

.. contents:: Table of Contents
   :depth: 3
   :local:

----

Overview
--------

This document provides comprehensive documentation for the EPS Battery Board, one of two PCBs
that together form the satellite's Electrical Power System (EPS). The companion board is the
MPPT/Power Distribution Board. The Battery Board is responsible for safely storing, protecting,
monitoring, and distributing power from the Li-Ion battery pack to the rest of the satellite.

.. note::

   **Scope change (2026-08-19):** the Power Conditioning Module (PCM) function has moved to the
   MPPT/Power Distribution Board. As of this revision, the Battery Board's sole downstream
   responsibility is to supply protected raw battery voltage onto the PC104 bus — it no longer
   feeds a PCM stage directly. See `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_ for the updated
   output path.

This document covers:

- Battery topology and configuration rationale
- Cell-level protection and balancing architecture
- Power conditioning and switching circuitry
- IC selection with detailed justification
- Global label and schematic cross-reference mappings
- Charging methodology (CC/CV)
- Microcontroller pinout and interfacing
- PC104 bus integration
- Open risks, action items, and design change history

.. note::

   On this satellite, the EPS is split into two PCBs: the **Battery Board** (this document) and
   the **MPPT/Power Distribution Board**. This document assumes all other PCBs adhere to the
   interface standards defined here.

For the companion MPPT/PDB documentation, see the MPPT PCB document.

----

Battery Configuration
---------------------

Topology
~~~~~~~~

The battery pack uses a **2S4P** Li-Ion configuration:

- **2 series cells** → achieves the required bus voltage (~7.2 V nominal, ~8.4 V fully charged)
- **4 parallel cells per series group** → achieves the required capacity and discharge current

The battery cells used are the **NCR18650GA** (Panasonic).

Each parallel bank is treated as an independent group, with per-cell fusing to isolate individual
cell failures without taking down the whole bank.

.. list-table:: Battery Configuration Summary
   :header-rows: 1

   * - Parameter
     - Value
   * - Cell chemistry
     - Li-Ion
   * - Cell model
     - NCR18650GA
   * - Configuration
     - 2S4P
   * - Nominal voltage
     - ~7.2 V
   * - Max charge voltage
     - ~8.4 V
   * - Series groups
     - 2
   * - Parallel cells per group
     - 4
   * - Protection IC
     - BQ28Z610 (×2, split-pack)

Rationale for 2S4P
~~~~~~~~~~~~~~~~~~~

The pack was updated from 2S2P to 2S4P to handle increased current demands from the payload.
The split-pack architecture (two independent 2S2P strings each with a dedicated BQ28Z610)
was chosen over a cold-spare or series-FET configuration for the following reasons:

- **Real-time telemetry comparison** of string A vs. string B enables early fault detection,
  which is especially important given the payload's current draw.
- **No single point of failure** — partial failure of one string is survivable.
- **Reduced MOSFET heating** — each DSG/CHG FET pair handles only 50% of total current during
  normal operation. Since :math:`P = I^2 R`, halving the current reduces heat by a factor of 4.

Why 2S Protection Instead of Stacked 1S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The original design used stacked 1S cell protection ICs (BQ2970/BQ29723). This was replaced with
the BQ28Z610 2S dedicated IC for the following reasons:

- **Floating ground risk**: if the bottom bank faults, the top bank loses its connection to
  ``PACK_N``, allowing uncontrolled current paths.
- **Doubled series resistance**: stacked 1S configurations require 4 MOSFETs in the main current
  path; the 2S IC uses only 2.
- **1S ICs were not designed to be stacked**: floating ground voltages cause sensing errors. If the bottom protection IC opens its FET the midpoint voltage is no longer anchored to anything and floats to whatever value the parasitic capacitance, leakage currents, and any stray conductive path pulls it. The top IC, whose VSS is MID, now has a completely undefined reference. Its voltage measurements become meaningless garbage.
  charge even at low state of charge.
- **Space efficiency**: the BQ28Z610 integrates IV monitoring, temperature sensing, and cell
  balancing into a single compact IC.
- **Redundancy**: if one 1S IC failed, all cells were unprotected. The 2S split-pack gives
  string-level redundancy.

----

----

IC Reference
------------

Cell-Level Protection — BQ28Z610
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/bq28z610.pdf

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Dedicated 2S Li-Ion battery protection and fuel-gauge IC. Integrates cell balancing,
       current sensing, voltage sensing, temperature sensing, and state-of-health reporting.
     - Two instances used (split-pack). Each IC manages one 2S2P string.
       Protections include: cell OVP, cell UVP, charge overcurrent (OCC), discharge overcurrent
       (OCD), overload discharge, short-circuit in charge, overtemperature in charge/discharge,
       pre-charge timeout, fast-charge timeout.
       Cell balancing is passive (resistor + MOSFET bleed).
       Data output via I2C (``I2C_SDA``, ``I2C_SCK``) to the STM32 MCU.
     - I2C address is fixed at 0x55 — both ICs share the same address, requiring either a
       multiplexer or a second I2C peripheral on the MCU. Resolved by upgrading to the
       STM32F030C8T6.

.. note::

   The BQ28Z610 replaces the original BQ2970/BQ29723 1S ICs. See `Rationale for 2S Protection`_
   above for full justification.

**Why Passive Cell Balancing?**

Passive balancing bleeds excess energy as heat through resistors and MOSFETs.
Active balancing uses DC-DC converters and inductors to transfer energy between cells.

For this application, passive balancing is preferred because:

- Only 2 series cells → voltage drift between series groups is minimal.
- DC-DC converters introduce switching noise (EMI) and reduce efficiency.
- Passive components are simpler, more space-efficient, and have no additional failure modes.


Buck-Boost Converter — TPS63060
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/tps63060.pdf

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Buck-boost switching regulator. Automatically transitions between buck and boost modes
       to maintain a regulated output regardless of whether input voltage is above or below
       the output setpoint.
     - Converts an MPPT charge input to the voltage required to charge power the watchdog and deployment timer suring launch.
       Feedback resistors R66 (560 kΩ) and R67 (100 kΩ) set the output voltage.
       Output capacitors C58, C59, C60 = 22 µF each for filtering
       Input capacitors C9, C10 = 22 µF; C11 = 0.1 µF.
       Inductor L1 = 2.2 µH. (NEEDS TO BE VERIFIED FOR SWITCHING DUTY CYCLE)
     - Input voltage range: 2.5 V – 12 V.
       Efficiency: up to 93%.
       Output current at 3.3 V (V\ :sub:`IN` < 10 V): 2 A (buck mode).
       Output current at 3.3 V (V\ :sub:`IN` > 4 V): 1.3 A (boost mode).

----

E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/tps7h2140-sep.pdf
:Replaces: TPS259472ARPWR (pack-output E-Fuse) **and** TPS24750 (high-side inhibit, see
   `Removal of TPS24750`_ below)

The pack-output protection IC was upgraded from the COTS TPS259472ARPWR to the
TPS7H2140-SEP, a Space Enhanced Plastic (SEP) grade quad e-Fuse rated for 30 krad(Si) TID
and SEL immunity up to 43 MeV·cm²/mg. This single IC now also assumes the high-side inhibit
role formerly filled by the TPS24750 (a COTS, non-radiation-qualified part).

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Radiation-tolerant, quad-channel programmable electronic fuse. Wide voltage headroom
       (4.5 V – 32 V; 35 V absolute max) clears the 8.4 V peak charge voltage with large
       margin against inductive/tether spikes.
     - Protects the battery pack output and serves as the CubeSat's mandatory high-side
       inhibit. Also gates the four downstream subsystem feeds (see `Channel Topology`_).
     - :math:`R_{ON}` rises from 40 mΩ (25 °C) to 70 mΩ (125 °C), dissipating up to ~1.75 W
       at 5 A — requires extensive copper pour and thermal vias under the PowerPAD for
       vacuum conduction (no convective cooling in orbit).

**Why not the original COTS E-Fuse?**

PPTC fuses alone have a slow thermal response time; the original TPS259472ARPWR addressed
that but, like the TPS24750 it shared duty with, carries no TID/SEL qualification. Both are
replaced here by a single SEP-grade part to close that radiation-hardening gap.

Channel Topology
^^^^^^^^^^^^^^^^^

.. note::

   **Design evolution:** the four channels were initially specified tied in parallel into a
   single ~5.4 A raw-voltage rail feeding PC104 directly, with all four ``EN`` pins commoned
   to a single MCU GPIO for simplicity (2026-08-08). This was superseded on 2026-08-28: the
   four channels are now kept **electrically split**, one per downstream subsystem
   (``E_FUSE_COMMS``, ``E_FUSE_SBAND``, ``E_FUSE_OBC``, ``E_FUSE_PAYLOAD``), so that OBC can
   obtain independent current telemetry per bus and an overcurrent fault on one subsystem
   does not blind or trip the others. ``EN`` control remains commoned across all four
   channels (see `EN Signal Path`_ below) since the launch-inhibit requirement applies
   uniformly regardless of output topology.

- **All-or-nothing enable, per-channel fault isolation**: a single ``EN`` gate satisfies the
  CubeSat high-side-inhibit requirement for the whole pack, while each channel's own current
  limit and diagnostics isolate a fault to just its subsystem.
- **Trade-off accepted**: per-subsystem power sequencing at the e-Fuse level is not available;
  downstream subsystems are responsible for their own inrush/startup sequencing.

EN Signal Path
^^^^^^^^^^^^^^^

The four ``EN`` pins are tied together and driven from ``EN_D1`` — the ANDed output of the
watchdog and deployment timers (see `Timers — LTC6995HS6-1#TRMPBF (Deployment & Watchdog)`_) —
satisfying the launch-safety requirement that current be inhibited between the source and any
load until deployment is confirmed.

.. note::

   Two earlier options were considered and voided:

   - Pulling ``EN`` permanently to 3.3 V (2026-08-08, VOID) — rejected because it does not
     satisfy the mandatory high-side-inhibit requirement.
   - Driving ``EN`` from an MCU GPIO — rejected in favour of the hardware ``EN_D1`` net so
     that inhibit behaviour does not depend on firmware being alive.

**EN Polarity / Inverter Selection**

``EN_D1`` is active-high, and the enable sense required by the e-Fuse needed inversion. A
discrete MOSFET or BJT inverter was considered:

- **BJT**: robust ESD tolerance and consistent :math:`V_{BE}` threshold, but a non-zero
  :math:`V_{CE(sat)}` (~0.1–0.3 V) sits uncomfortably close to the e-Fuse's shutdown
  threshold, and requires a series base resistor.
- **Discrete MOSFET**: near-zero :math:`R_{DS(on)}` pull-down gives wider noise margin, but
  discrete power MOSFETs are highly susceptible to Single-Event Gate Rupture (SEGR) and TID
  threshold shifts that can force a false-enable state.

**Selected: SN54SC6T06-SEP** — a rad-hard (30 krad TID), quad-package logic-level open-drain
inverter IC. A single package provides 6 independent inverters, enough to invert all 4 ``EN``
lines from one small part rather than 4 discrete MOSFETs. :math:`V_{OL} < 0.2\text{ V}`,
comfortably clear of the e-Fuse's enable/disable threshold, without the SEGR/TID risk of a
bare discrete FET.

Current-Limit Resistor Sizing
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each channel's trip current is set independently by its own :math:`R_{\text{LIMx}}` resistor.

:Target: :math:`I_{OUTx,nom} = 1.35\text{ A}` per channel
:Given: :math:`K_{CL} = 2500`, :math:`V_{CL,TH} = 0.8\text{ V}`, silicon gain accuracy
        :math:`\pm 15\%`

.. math::

   R_{\text{LIMx}} = \frac{V_{CL,TH} \times K_{CL}}{I_{OUTx,nom}}
   = \frac{0.8\text{ V} \times 2500}{1.35\text{ A}} = 1481.48\ \Omega

**Selected:** :math:`R_{\text{LIMx}} = 1.47\text{ k}\Omega` (E96, 1%), giving an adjusted
nominal trip current of :math:`\approx 1.36\text{ A}`.

.. list-table:: Per-Channel Trip Current (worst-case ±15% gain accuracy)
   :header-rows: 1

   * - Parameter
     - Nominal
     - Min (−15%)
     - Max (+15%)
   * - :math:`R_{\text{LIMx}}`
     - 1.47 kΩ
     - —
     - —
   * - Channel trip current :math:`I_{OUTx}`
     - 1.36 A
     - 1.16 A
     - 1.56 A

.. note::

   An earlier version of this analysis (VOID) sized a single shared :math:`R_{CL}` for a
   4-channel *parallel* topology and derived a mismatch-adjusted system-level trip current of
   ~4.79 A. That analysis is superseded by the per-channel split topology above, but the
   per-channel resistor value it produced (1.47 kΩ) carried forward unchanged.

Diagnostics and Current Sense
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``DIAG_EN`` is **enabled** (superseding an earlier VOID decision to permanently ground it) and
connected to an MCU GPIO, now that the four channels are split per subsystem — this lets OBC
poll per-bus fault status over CAN (see `CAN Telemetry`_).

- ``CS`` outputs a 1/300 current-sense ratio, capped at 4 V. :math:`R_{CS}` must be sized so a
  worst-case 1.41 A channel peak (accounting for ~6% :math:`R_{ON}` mismatch) maps safely to
  ≤ 3.3 V for the MCU's ADC. ``SEL``/``SEH`` must be toggled in firmware to select and read
  each channel in turn.
- **Open question:** whether e-Fuse current sensing is even needed, given the BQ28Z610 gas
  gauges already provide high-resolution pack current telemetry independently.
- All digital control lines (``EN1-4``, ``SEL``, ``SEH``, ``DIAG_EN``) get 4.7 kΩ series
  isolation resistors to shield the MCU from negative transient spikes; ``FAULT`` uses a
  10 kΩ pull-up (VOL_FAULT ≤ 0.2 V at 2 mA sink; actual sink current through a 10 kΩ pull-up
  is only ~0.31 mA, well under the datasheet test point).
- All No-Connect (NC) pins are tied directly to GND per the datasheet's recommendation
  (p. 3) — unbonded floating pins act as high-impedance antennas susceptible to
  radiation-induced charge buildup.

Output Transient Protection
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Two passive clamps protect each channel output against inductive transients from fault trips,
dynamic load switching, and cosmic-ray single-event transients (SETs) on the gate driver:

**Positive spike — 1 µF flex-termination MLCC.** Harness/trace inductance
(:math:`L \approx 2\ \mu\text{H}`) dumping into the output capacitor during a fast
(< 1 µs) trip event:

.. math::

   V_{peak} = \sqrt{V_{rail}^2 + \frac{L \cdot I^2}{C_{OUT}}}
   = \sqrt{(8.4\text{ V})^2 + \frac{(2\ \mu\text{H})(1.35\text{ A})^2}{1\ \mu\text{F}}}
   \approx 8.61\text{ V}

The resulting 0.21 V (~2.5%) rise sits comfortably under the 36 V absolute maximum. A
flex-termination MLCC was chosen over rigid ceramic to absorb launch vibration and thermal
flex without cracking (which would otherwise create a hard short to ground).

**Negative spike — reverse-biased Schottky diode (1N5822U), anode to GND, cathode to**
``V_OUTx``. Clamps the negative excursion to :math:`V_{OUT,min} \approx -0.25\text{ V}`,
comfortably above the −0.3 V absolute minimum rating.

.. note::

   The e-Fuse's own **output**-side Schottky diodes previously specified for reverse-current
   blocking have been **removed**. The LM74800-Q1 ideal-diode OR-ing already in place at the
   two 2S2P string outputs (see `Ideal Diodes — LM74800-Q1`_) already blocks any reverse path
   back into the pack, so a redundant output diode was unnecessary.

Reverse-Current Protection at the E-Fuse Input
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TPS7H2140-SEP provides no active reverse-current blocking of its own — under a
short-to-power or reverse-polarity fault, reverse current is only current-limited
(:math:`I_{R1} = 2.5\text{ A}` single-channel, :math:`I_{R2} = 2.0\text{ A}` all-channel), and
while a channel is enabled, current flows through the FET with no blocking behaviour at all.
Per TI's own guidance, a series blocking diode between the battery and the e-Fuse ``IN`` pin
(their "Method 1") is required.

Three options were evaluated:

- **LM74800-style ideal-diode controller** — rejected: lower conduction loss, but
  automotive-grade (Q1) and not TID/SEE-characterized. Placing an unqualified active part at
  the single node feeding the entire pack reopens the rad-hardening gap this whole migration
  closed.
- **TPS7H2201-SEP active front-end** (battery → 2201-SEP → 2140-SEP) — rejected: architecturally
  the cleanest (matched TID/SEE ratings, genuine active blocking), but adds a second active IC
  plus its own :math:`R_{ON}`/IR drop and diagnostic overhead for a function a passive part
  already covers.
- **Rad-hard/ESCC-qualified series Schottky diode** — **selected**. Implements Method 1
  directly and passively (no control loop, no additional SEE-sensitive silicon).

**Diode selection:** two ESCC-qualified candidates were compared for the ~5–6 A series path
(per QPL005): the STPS40A45C (45 V, 2×20 A common-cathode) vs. two parallel 1N5822U (40 V, 3 A
each, 6 A combined). Electrically the STPS40A45C is the stronger part (lower :math:`V_F`,
lower dissipation at this load fraction), but its TO-254AA package contains beryllium oxide,
carrying handling/disposal requirements the program is not equipped for, at a disproportionate
cost for a part sitting at <15% utilization. **2× parallel 1N5822U** (LCC2B package) was
selected on packaging/handling grounds instead, sized for 6 A against the 34.8 W maximum
determined in the July 2026 power budget. Paralleling-mismatch risk is mitigated with
same-lot/date-code sourcing and symmetric PCB layout.

:Accepted trade-off: fixed forward-voltage loss (~0.3–0.5 V), continuous under nominal
   operation.

.. _`Removal of TPS24750`:

Removal of TPS24750
^^^^^^^^^^^^^^^^^^^^

The previous high-side inhibit, the TPS24750 (see former ``High-Side Inhibit`` section), was a
COTS part with no radiation-hardened characteristics. Its role is fully absorbed by the
TPS7H2140-SEP above. Its former downstream connection to the Power Conditioning Module (PCM)
no longer applies now that PCM has moved to the MPPT/Power Distribution Board — the E-Fuse's
(now four, split) outputs feed the PC104 bus directly for distribution to COMMS, S-band, OBC,
and Payload.

----

Per-Cell PPTC Fuses
~~~~~~~~~~~~~~~~~~~~

Four PPTC (Positive Temperature Coefficient) fuses were added, one per cell in each parallel bank.

**Why add per-cell fuses?**

Each cell can develop an internal short. Without fusing, parallel cells will sink large currents
into the shorted cell to balance the parallel voltage, causing overheating and potential fire.
The per-cell fuse isolates the faulty cell, allowing the remaining cells in the bank to continue
operating.

**Why PPTC?**

- Very low voltage drop in normal operation.
- Automatically resettable — no manual intervention required.
- Single component; minimal board space impact.
- Slow response time is not detrimental in this application (the E-Fuse handles fast faults).

**Fuse Rating**

Each fuse was selected with a trip current of **4.5 A**. With 4 cells, this gives the pack
a total fault current budget of **18 A** before tripping.

----

Ideal Diodes — LM74800-Q1
~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/lm7480-q1.pdf

Ideal diodes were added between the outputs of the two 2S2P battery strings to prevent
back-feeding current from one string into the other when the strings are at different states
of charge.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Active ideal diode controller (controls external N-channel MOSFETs to emulate a very
       low forward-voltage diode).
     - Placed at the outputs of each 2S2P string. Prevents reverse current flow between
       parallel strings with different voltages. Enables safe OR-ing of the two strings.
     - Operating temperature: −40 °C to +125 °C.
       Forward voltage drop: ~10.5 mV.
       Quiescent current: 35 µA.
       Reverse blocking response time: 0.5 µs.
       Not yet extensively flight-heritage tested in space.

**4-MOSFET Architecture (2 per Rail)**

To achieve true power path isolation and complete logical shutdown via the ``EN/UVLO`` pin,
each power rail uses two N-channel MOSFETs in a back-to-back common-source configuration:

A single MOSFET cannot fully isolate the rail because its parasitic body diode allows leakage
current even when the gate is off. With two back-to-back FETs, the body diodes face opposite
directions, providing a complete block in both forward and reverse directions.

- **MOSFET 1 (HGATE)**: disconnect switch — blocks forward leakage on shutdown.
- **MOSFET 2 (DGATE)**: active ideal diode — blocks reverse back-feeding from a
  higher-voltage parallel string.

**Open-Drain NMOS Enable Switch**

The MOSFET configuration above allows for the ideal diode to be controlled through the ''EN/UVLO'' pin. This allows the ideal diodes to serve as a high side inhibit rather than having a separate one, reducing part count and extra modes of failure that come with additional component count. The ``EN/UVLO`` pin is controlled by an open-drain inverter to allow digital logic control:

- Pull-up resistor (10 kΩ – 100 kΩ) between ``V_SNS`` and ``EN/UVLO`` → default ON state.
- Small-signal NMOS (e.g. 2N7002): Drain to ``EN/UVLO``, Source to GND, Gate driven by MCU.



.. list-table:: Enable Switch Logic
   :header-rows: 1

   * - Control Input (Gate)
     - NMOS State
     - EN/UVLO Voltage
     - Power Path Status
   * - Logic HIGH (3.3 V / 5 V)
     - ON (closed)
     - 0 V (clamped to GND)
     - **Shutdown** — back-to-back FETs isolate load; output drops to ~0 V
   * - Logic LOW (0 V)
     - OFF (open)
     - V\ :sub:`SNS` (pulled high)
     - **Active OR-ing** — 1.4 ms soft-start ramp; FETs fully enhanced
**Ideal Diode Placement: High-Side vs. Low-Side**

The ideal diodes are placed on the **positive (high-side) rail**, not in the ground return path.

Placing switching elements on the high-side preserves a continuous, unbroken ground plane
shared across all subsystems. This is critical for I2C signal integrity — if the ideal diode
were in the low-side (ground) path, the ground reference of the battery string would sit at
a different potential than the system ground whenever the switch was in transition. Any current
seeking to return to ground could find an alternative path through I2C data lines or other
shared signal cables, potentially damaging downstream ICs.

High-side placement also provides natural back-feeding protection: if one string is at a
higher voltage than the other, the ideal diode blocks reverse current on the positive rail
before it can reach the lower-voltage source, with the ground plane remaining undisturbed
throughout.

.. warning::

   **PCB Layout Critical Rules for LM74800-Q1:**

   - The **Thermal Pad (Pin 13 / RTN)** must be completely isolated from the main GND plane.
     It must sit on a standalone copper island tied strictly to the ``RTN`` net to prevent
     destroying the IC's ESD substrate during a reverse-battery fault.
   - Add **10 Ω – 47 Ω series gate resistors** on the power MOSFETs to damp high-frequency
     switching transients and prevent parasitic ringing.

----

Timers — LTC6995HS6-1#TRMPBF (Deployment & Watchdog)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.analog.com/media/en/technical-documentation/datasheets/LTC6995-6695-1-6695-2.pdf

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Silicon oscillator IC designed for long-duration timing events (seconds range).
       Generates a 50% duty cycle square wave.
       Frequency set by a voltage divider on the ``DIV`` pin (two selectable settings via
       connector pins).
       Has a hardware reset feature.
     - Two instances:

       **Watchdog Timer**: monitors the MCU. Oscillates at 2.5 s with a 1.25 s delay from the
       last received PPS signal from the OBC. If PPS is not received in time, the watchdog
       resets the MCU.

       **Deployment Timer**: ensures ``EN_D1`` is only activated after the satellite has
       completed deployment. The timer output connects to the low-side inhibit ground path;
       nothing can be activated during deployment. The ANDed output of watchdog + deployment
       timer (in ``power_control_RBF.sch``) provides dual-redundant safety to prevent false
       positive activations.
     - Supply voltage: max 6 V.
       Operating temperature: −40 °C to +125 °C.

----

High-Side Inhibit (Superseded)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::

   The TPS24750 previously served as the high-side inhibit here. As of 2026-08-19 this role
   is filled by the TPS7H2140-SEP e-Fuse — see
   `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_ for the current design, including the
   rationale for retiring the TPS24750 (a COTS, non-radiation-qualified part).

----

Low-Side Inhibit — NTJD1155L (Under Revision)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.onsemi.com/pdf/datasheet/ntjd1155l-d.pdf

Low-side inhibits cut the *ground* connection of the load from the source. Placed between the
load and ``PACK_N`` (pack negative terminal). This is a mandatory launch safety requirement to
prevent hazardous operation during launch.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Dual P+N channel MOSFET load switch. The load connects directly to the positive rail;
       the ground return path is switched.
       Pull-up resistor R: 10 kΩ – 1 MΩ.
     - Controlled by ``EN_D3`` (from the deployment timer in ``power_control_RBF.sch``).
       When the deployment timer activates, the circuit becomes connected to ground, allowing
       current to flow.
     - Supply line voltage: 1.8 V – 8 V.
       Max current: ±1.3 A. **This component is under review** — the entire battery discharge
       current passes through this device; the package is too small to handle the required
       current.

.. warning::

   **NTJD1155L is being replaced.** The entire battery current return path runs through this
   device, exceeding its 1.3 A rating. Candidate replacements:

   - **FDC6318P** (dual P-channel): larger footprint; requires a NOT gate to invert the
     enable signal since it is P-channel rather than N+P.
   - **2× discrete MOSFETs (P + N)**: requires a gate resistor and space verification.

   Additionally, the **ferrite bead** connected to the negative battery terminal has strict
   current limits and must be reviewed if the low-side switch is on the same net.

**Why Disconnect Ground During Launch?**

- Intense vibrations can cause electrostatic discharge events.
- There is an increased risk of stray currents with the ground connected during launch.
- This is a **mandatory launch requirement** per CubeSat standards.

----

Microcontroller — STM32U3B5CIT6
--------------------------------

:Replaces: STM32F030C8T6 (which itself replaced STM32F030F4P6)
:Reason for Upgrade: OBC requires a redundant dual-CAN-bus architecture for telemetry.
   The STM32F030C8T6 has **no CAN peripheral at all** and cannot provide the primary/redundant
   bus paths the OBC subteam requested; it must be replaced with a dual-CAN, multi-I2C part.

Alternatives Considered
~~~~~~~~~~~~~~~~~~~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * - Candidate
     - Pros
     - Cons
   * - **STM32U3B5CIT6** *(selected)*
     - Ultra-low active power (~12–15 µA/MHz, SMPS variant), true dual native FDCAN, hardware
       flash ECC + SRAM parity for SEU mitigation, 48-pin footprint match.
     - Cortex-M33 toolchain migration from M4; FDCAN driver stack more complex than legacy
       bxCAN; not itself a space-grade / flight-proven part.
   * - STM32G473CBT6
     - Drop-in footprint; 3 I2C, 3 FDCAN; natively supports dual BQ28Z610 strings.
     - More complex FDCAN software stack; no radiation-mitigation features.
   * - STM32F105RBT6
     - Flight heritage on some prior CubeSats; simpler bxCAN stack.
     - LQFP64 (larger footprint than the 48-pin legacy part); higher power consumption.
   * - STM32G0B1CBT6
     - Native dual FDCAN in a 48-pin package; simpler Cortex-M0+ toolchain; lower core power.
     - No hardware flash ECC / SRAM parity; lower math throughput for SoC algorithms.
   * - VA41620
     - True radiation-hardened design.
     - Extremely expensive; LQFP176 — massive PCB footprint versus the 48-pin budget.
   * - ATSAMC21J18A
     - Native 5 V operation (noise immunity); dual CAN FD; up to 6 configurable I2C SERCOMs.
     - No flash ECC; LQFP64 minimum package; Cortex-M0+ processing ceiling.

.. note::

   Older STM32F0-family parts have COTS CubeSat flight history, but as un-screened commercial
   parts carry no guaranteed silicon-level heritage across manufacturing lots. The
   STM32U3B5's hardware ECC, SRAM parity, and low-power sleep modes give some active
   system-level radiation mitigation that older non-ECC parts inherently lack — though the
   part is **not** itself considered space-grade.

**Package / power variant:** the standard (LDO) STM32U3B5CIT6 was selected over the
``Q``-suffix SMPS variant. The SMPS variant is ~50% more efficient at stepping the 3.3 V rail
down to :math:`V_{CORE}` (~1.0–1.4 V), but at ~18 µA/MHz total consumption the absolute power
saved is marginal. The SMPS variant also requires an external LC oscillator — additional
SEU-susceptible surface area and additional switching noise that would degrade the analog
telemetry ADC inputs. The LDO variant avoids both penalties.

**ICACHE:** disabled by design choice. STM32U3, unlike the U5, requires no wait states for
flash access at this operating frequency, so ICACHE's usual pitch (masking flash latency) does
not apply here. ICACHE's instruction array lives in RAM, which is more SEU-susceptible than
flash, and cache hit/miss variability would add nondeterminism to worst-case execution timing
if that is ever needed for stakeholders.

Crystal Design — NDK NX3225SA-16.000M-STD-CRS-2
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://media.digikey.com/pdf/data%20sheets/ndk%20pdfs/nx3225sa%20std-crs-2.pdf

An external HSE crystal on **PH0 (OSC_IN)** / **PH1 (OSC_OUT)** — *not* the LSE-only
``PC15-OSC32_OUT`` — serves as the MCU clock source. External crystals maintain frequency
stability across the thermal cycling of orbit, unlike internal RC oscillators.

**Frequency: 16 MHz.** The STM32U3 HSE accepts 4–50 MHz; 16 MHz divides evenly into common
UART/SPI/timer-interrupt rates, requires minimal PLL settling time to reach 96 MHz max
performance, natively locks the MSI-PLL architecture, and matches the legacy schematic's
clock frequency (preserving any inter-subsystem timing dependencies not otherwise visible).

**Part selection rationale (NDK NX3225SA-16.000M-STD-CRS-2):**

- Rated −40 °C to +125 °C, exceeding the STM32U3B5's −40 °C to +105 °C ambient (+110 °C
  junction) spec — margin against the least-controlled thermal component on the bus.
- Sealed ceramic package (3.2×2.5×0.55 mm) — lower vacuum outgassing risk than a
  plastic-molded part.
- Automotive-grade variants meet AEC-Q200; the part line shows up repeatedly in COTS reference
  designs, including ST's own AN6011 reference design at this exact frequency.
- Small footprint/mass (~17 mg) and no impact on existing firmware timing, baud calculations,
  or clock dividers.

**Load capacitor sizing** (AN2867 §3.3), :math:`C_L = 8\text{ pF}` (rated),
:math:`C_s = 5\text{ pF}` (stray, board/pin estimate):

.. math::

   C_x = 2(C_L - C_s) = 2(8 - 5) = 6\text{ pF} \rightarrow \textbf{6.8 pF (E12)}

This matches ST's own STM32U3 reference design (AN6011 Table 9) as an independent cross-check.

**Gain-margin check** (AN2867 §3.4), worst-case ESR = 120 Ω, :math:`C_0 = 3\text{ pF}`
(conservative estimate — not specified by NDK for this part number; to be confirmed with NDK
or measured before fab sign-off):

.. math::

   g_{m\_crit} = 4 \cdot ESR \cdot (2\pi F)^2 \cdot (C_0 + C_L)^2 \approx 0.587\text{ mA/V}

.. math::

   \text{gain margin} = \frac{g_m}{g_{m\_crit}} = \frac{1.5\text{ mA/V}}{0.587\text{ mA/V}}
   \approx 2.56 \quad \text{(good)}

MCU Supervisor — TPS3823-25DBVR
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/tps3823-25.pdf

A hardware supervisory circuit resets the MCU on faults, latch errors, or brownout that
firmware cannot catch on its own. The same part is already used for this function on the MPPT
board; it was re-evaluated independently here rather than simply inherited.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Voltage supervisor with watchdog input (``WDI``) and manual reset (``MR``) pin.
     - Active-low, push-pull ``RESET`` output — matches the STM32 ``NRST`` convention with no
       inverter needed. Fixed 200 ms power-on delay and 1.6 s watchdog timeout.
       15 µA quiescent draw.
     - Push-pull only (no open-drain variant exists in this family — that's the TPS3828);
       cannot be wire-ORed with another reset source. The ``-25`` suffix trips at ~2.25 V.

**Manual reset:** ``MR`` uses a pull-down solder jumper (as on the MPPT board) in place of a
physical switch, with a standard 10 kΩ pull-up so ``MR`` is not randomly triggered.

**No Schottky diode on the reset line.** Once the internal STM32 brownout level is set below
2.25 V (see `Brownout Reset`_ below), there is no contention on ``RESET*`` to arbitrate. Adding
a Schottky here would force the MCU to rely on a passive pull-up (subject to parasitic-
capacitance delay) instead of the supervisor's fast, clean active push-pull transition — a
meaningfully more robust choice against space-environment failure modes like tin-whisker growth
or leakage from damaged neighbouring components.

Brownout Reset
~~~~~~~~~~~~~~~

The internal STM32 brownout reset is configured via option bytes to **BOR0 (~1.8–2.1 V)** —
below the TPS3823-25's ~2.25 V trip point. This is deliberate: the external supervisor always
trips first on a sagging rail, avoiding contention between the two, while the internal BOR0
still provides true redundancy — if the external supervisor itself fails, the MCU can still
self-reset on brownout, just at a lower voltage.

Battery Heater PWM Timer Selection
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**TIM1** and **TIM8** drive the two battery heater channels (rather than sharing a single
timer, or using TIM3). As advanced-control timers, both feature a dedicated hardware Break
Input (``BKIN``) that trips the main output enable (``MOE``) directly — bypassing software
latency to protect gate drivers during an overcurrent event. Assigning each heater to its own
timer instance (``TIM1_CH1`` on PA8, ``TIM8_CH1N`` on PA5) avoids the shared-register global
shutdown limitation of a single timer, so a comparator fault on one pack never disables heating
on the other. TIM8's complementary output (``CH1N``) requires explicit configuration of its
output polarity (``CC1NP``) and break off-state (``OIS1N``) bits to guarantee safe FET turn-off
during idle/trip conditions, but delivers full 16-bit PWM control with true physical isolation
between the two heater circuits.

USART2 Debug Header
~~~~~~~~~~~~~~~~~~~~~

USART2 pins are broken out to a header as a secondary debug path, in case the CAN bus or the
primary programming header is unavailable or malfunctioning during bring-up testing.

Pinout
~~~~~~

.. list-table::
   :header-rows: 1
   :widths: 18 18 14 16 34

   * - Pin
     - Signal / Label
     - Peripheral
     - Function
     - Notes
   * - PH0-OSC_IN
     - ``RCC_OSC_IN``
     - RCC
     - HSE crystal input
     - 16 MHz HSE external oscillator
   * - PH1-OSC_OUT
     - ``RCC_OSC_OUT``
     - RCC
     - HSE crystal output
     - 16 MHz HSE external oscillator
   * - PA0
     - ADC1
     - ADC1
     - ``ADC1_IN3``, single-ended
     - Channel 3, rank 1, sampling time 1.5 cycles, no offset
   * - PA5
     - ``BAT_HTR2``
     - TIM8
     - PWM Generation1, Channel 1N
     - Complementary PWM output
   * - PA6
     - ``I2C2_SDA``
     - I2C2
     - I2C data line
     - Timing reg = 0x40000A0B
   * - PA8
     - ``BAT_HTR1``
     - TIM1
     - PWM Generation1, Channel 1
     - Internal clock source
   * - PA10
     - ``E_FUSE_FAULT``
     - GPIO
     - Digital input
     - Locked; input mode, no pull — fault flag from e-Fuse
   * - PA11
     - ``FDCAN1_RX``
     - FDCAN1
     - CAN FD receive
     - Nominal baud rate 250 kbps
   * - PA12
     - ``FDCAN1_TX``
     - FDCAN1
     - CAN FD transmit
     - Nominal baud rate 250 kbps
   * - PA13 (JTMS/SWDIO)
     - ``DEBUG_JTMS-SWDIO``
     - SYS (Debug)
     - SWD data I/O
     - Locked — reserved for debug/programming
   * - PA14 (JTCK/SWCLK)
     - ``DEBUG_JTCK-SWCLK``
     - SYS (Debug)
     - SWD clock
     - Locked — reserved for debug/programming
   * - PB2
     - ``I2C2_SCL``
     - I2C2
     - I2C clock line
     - Timing reg = 0x40000A0B
   * - PB3 (JTDO/TRACESWO)
     - ``I2C1_SDA``
     - I2C1
     - I2C data line
     - Shared with TRACESWO debug pin; Timing reg = 0x40000A0B
   * - PB6
     - ``I2C1_SCL``
     - I2C1
     - I2C clock line
     - Timing reg = 0x40000A0B
   * - PB7
     - ``BOOT0``
     - System
     - Boot mode select
     - Dedicated pin (non-SMPS package); not in CubeMX — set via option bytes
       (``nBOOT0``/``nSWBOOT0``). Currently unrouted/unassigned.
   * - PB8
     - ``BATT_INT``
     - GPIO (EXTI)
     - ``GPXTI8`` — external interrupt
     - Rising-edge interrupt, no pull, locked
   * - PB9
     - ``WD_TIM``
     - GPIO Output
     - Push-pull digital output
     - Watchdog/timer kick pin; init state = RESET (low); low-speed output, no pull
   * - PB12
     - ``FDCAN2_RX``
     - FDCAN2
     - CAN FD receive
     - Nominal baud rate 250 kbps
   * - PB13
     - ``FDCAN2_TX``
     - FDCAN2
     - CAN FD transmit
     - Nominal baud rate 250 kbps

.. note::

   I2C1 (``PB3``/``PB6``) services the BQ28Z610 fuel gauges; I2C2 (``PA6``/``PB2``) services
   charger timing. Unlike the legacy STM32F030C8T6 assignment, both peripherals are on
   dedicated pins with no address-based multiplexing required, and the part's two native
   FDCAN controllers (``FDCAN1``, ``FDCAN2``) replace the previous "no CAN peripheral"
   limitation outright — see `CAN Transceiver — TCAN334GDCNT`_.

.. warning::

   **FDCAN2's default pin mapping is not yet formally verified** against a second physical
   connector requirement from ConOps/systems engineering (dual-CAN-bus fault tolerance may be
   a hard mission requirement or an assumed default — TBD). See `Open Risks & TBDs`_.

CubeMX Parameter Settings (Open)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Pin mux/signal assignment above is locked; per-pin CubeMX *parameter* settings (pull config,
speed, output type, peripheral timing) are still **TBD**:

- I2C1/I2C2 bus speed (100 kHz standard-mode vs. 400 kHz fast-mode — bounded by BQ28Z610 max
  supported speed, needs confirmation) and pull-up resistor values.
- ``BOOT0`` (PB7) external pull strategy + ``nSWBOOT0``/``nBOOT0`` option-byte target state.
- ADC1 CH3 resolution, sampling time (re-check against actual source impedance), and data
  alignment.
- ``TIM8_CH1N`` PWM prescaler, period/frequency, initial duty cycle, and dead-time.
- FDCAN1/FDCAN2 data-phase bit timing (nominal already set at 250 kbps) and bench-test
  operating mode (Normal vs. Loopback).
- NVIC priority for ``EXTI8`` (``BATT_INT``) relative to other enabled interrupts.

Power Supply (Under Revision)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The MCU takes power from the 3.3 V bus (though perhaps it may be better if sourced from the
MPPT). A 100 Ω / 100 MHz ferrite bead (FB7) is placed in line on the 3.3 V supply for noise
filtering. Decoupling capacitors are placed on ``3V3BUS`` and ``3V3A`` rails per STM32
recommended layout. See `3.3V Input Protection and Filtering`_ for the connector-level
protection scheme and the current-budget calculation for this rail.

----

CAN Transceiver — TCAN334GDCNT
--------------------------------

:Datasheet: https://www.ti.com/lit/ds/symlink/tcan334.pdf

Two CAN transceivers are required, one per physical CAN pair (``FDCAN1``, ``FDCAN2``), to
convert the MCU's digital TX/RX signals to differential CAN-H/CAN-L.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - 3.3 V CAN FD transceiver, SOT-23-8 package.
     - Converts each FDCAN controller's digital TX/RX pair to a differential CAN bus signal.
       Already used on the MPPT board for the same function.
     - **Non-isolated.** A ground-reference disturbance on this board (chassis short, e-Fuse
       fault event, ESD during handling) has a direct electrical path onto the shared CAN bus
       and potentially into every other board's transceiver.

**Why TCAN334GDCNT?** Primarily consistency with the part already selected for the MPPT
board. On independent review it also offers native 3.3 V operation with no logic-level
translators, robust fault/ESD protection, and a compact footprint (SOT-23-8 vs. SOIC-8) with
passive high-impedance behaviour when unpowered.

**Standby vs. shutdown mode.** The transceiver's low-power control pin is held in **standby**,
never full shutdown, even though shutdown draws less current (nA vs. µA range):

- If the battery protection board detects an emergency condition (cell OVP, thermal runaway,
  UVP), it must be able to signal OBC immediately. Standby mode lets the transceiver jump to
  normal operation instantly; a fully shut-down transceiver would need to wait through internal
  regulator/boot stabilization first.
- If the MCU or watchdog latches up, a transceiver left in standby still lets OBC observe that
  something is wrong; a fully shut-down transceiver would look identical to a healthy idle bus.
- The power difference (µA vs. nA) is not worth the safety trade-off for a health-critical
  board — there is accordingly no scenario in which shutdown mode is preferred over standby.

**Passive network:** a 10 kΩ pull-down defaults the standby/shutdown control pin to the safe
(non-shutdown) state; a 4.7 kΩ series resistor connects that pin to an MCU GPIO for active
control, limiting current for logic-level safety where switching speed is not critical.

----

3.3V Input Protection and Filtering
-------------------------------------

The 3.3 V rail arrives at this board on a dedicated PC104 pin from the MPPT converter's
output node (other subsystems have their own separate pins from the same converter, not a
shared trace). It is a pass-through rail with no local regulation headroom
(:math:`V_{in} \approx V_{out} = 3.3\text{ V}`).

.. note::

   A full ripple-filter network (series inductor, π-network, shielding) was originally
   scoped for this rail, then **trimmed** after confirming the load on this board — two
   LTC6995 timer/watchdog ICs plus the STM32's digital core (``VDDA`` is already isolated by
   its own dedicated ferrite/local filter, out of scope here) — is digital-logic-tolerant and
   does not need a board-level ripple spec beyond staying clear of the STM32's UVLO threshold.

**Trimmed scope:**

- A single bulk decoupling capacitor at the connector, sized for local IR-drop/transient
  buffering only.
- A transient clamp (TVS, ~3.6 V :math:`V_{RWM}`) at the connector.
- A series fuse/PTC at the connector.

**Current budget** (validates the "light digital load" assumption above), for the two
LTC6995HS6-1#TRMPBF instances (deployment timer :math:`R_{SET} = 681\text{k}\Omega`;
watchdog timer :math:`R_{SET} = 238\text{k}\Omega`) plus their DIV-divider paths, using the
datasheet's typical supply-current equation:

.. math::

   I_{S(TYP)} \approx V^+ \cdot f_{MASTER} \cdot 7.8\text{pF} + \frac{V^+}{420\text{k}\Omega}
   + 1.8 \cdot I_{SET} + 50\ \mu\text{A}

.. list-table::
   :header-rows: 1

   * - Source
     - Typical
     - Conservative Worst-Case
   * - Deployment timer :math:`I_S`
     - 62.4 µA
     - —
   * - Watchdog timer :math:`I_S`
     - 70.8 µA
     - —
   * - DIV divider currents (both)
     - 4.5 µA
     - —
   * - **Total (LTC6995 ×2 + dividers)**
     - **~137.7 µA**
     - **~264.5 µA** (loose bound — datasheet's guaranteed max :math:`I_S` at
       :math:`V^+ = 5.5\text{V}` used as the loosest applicable tabulated ceiling; true
       guaranteed max at 3.3 V is not directly tabulated)
   * - STM32U3B5CIT6 digital core contribution
     - **Pending** — see `Open Risks & TBDs`_
     - Pending

The ~12 µF bulk/filter capacitance draws zero steady-state DC current once charged and is
excluded from this calculation as an inrush item, not a steady-state one.

**Open items:** confirm the STM32 UVLO threshold holds with margin against a worst-case rail
dip under a simulated cross-subsystem load step on the same MPPT converter node; audit
cross-board I2C nets for back-powering risk through MCU ESD diodes if this rail is absent
while the battery bus is live; bench-verify TVS/fuse hold under a simulated connector fault
event.

----

PC104 Bus Connector
-------------------

The PC104 stackthrough connector (``J?``) connects the EPS Battery Board to the rest of the
satellite subsystems. It carries both regulated and unregulated voltage buses, I2C telemetry,
and control signals.

.. list-table::
   :header-rows: 1
   :widths: 20 25 15 40

   * - Net / Signal
     - Connector Side
     - Direction
     - Notes
   * - ``BATT_INT``
     - H1 (female / top)
     - Out
     - GPIO interrupt from BMS MCU (PB8/EXTI8) to OBC — see resolved definition below.
   * - ``EPS_INT``
     - H1
     - In
     - Hard-reset request from OBC into the ``RST`` input of the LTC6995 watchdog timer — see
       resolved definition below.
   * - ``5VBUS``
     - H1 / H2
     - Out
     - Regulated 5 V bus
   * - ``3V3BUS``
     - H1 / H2
     - In
     - Regulated 3.3 V rail sourced from the MPPT converter — see
       `3.3V Input Protection and Filtering`_
   * - ``5V_USB_CHG``
     - H1
     - In
     - USB charge input
   * - ``E_FUSE_COMMS``, ``E_FUSE_SBAND``, ``E_FUSE_OBC``, ``E_FUSE_PAYLOAD``
     - H1 / H2
     - Out
     - Four split, individually current-limited raw battery voltage feeds from the
       TPS7H2140-SEP e-Fuse (see `Channel Topology`_). Replaces the former ``PCM_IN``/
       ``BCR_OUT`` nets, which no longer apply now that the PCM function has moved to the
       MPPT/Power Distribution Board.
   * - ``I2C_SDA``, ``I2C_SCK``
     - H1
     - Bidirectional
     - I2C to communicate with rest of satellite
   * - ``FDCAN1``, ``FDCAN2`` (CAN-H/CAN-L pairs)
     - H1 / H2
     - Bidirectional
     - Primary/redundant CAN bus to OBC via the TCAN334GDCNT transceivers.
   * - GND
     - H1 / H2
     - —
     - Multiple ground pins distributed across connector

.. note::

   **Resolved (previously open): EPS_INT / BATT_INT net definitions.**

   - ``EPS_INT`` connects to the PC104 and to the ``RST`` input of the LTC6995 watchdog timer.
     Pulling it high immediately stops the watchdog's internal oscillator, clears its counter
     dividers, and truncates its output pulse. Because it is driven from the PC104 side (OBC),
     not from the BMS MCU, ultimate hard-reset authority for this board's watchdog rests with
     OBC — consistent with OBC's higher position in the subsystem hierarchy (if OBC itself
     dies, the whole satellite is in a "zombie" state regardless of what this board can do).
   - ``BATT_INT`` connects to the BMS MCU (``PB8``/``EXTI8`` on the current STM32U3B5CIT6
     assignment) and to PC104. Deductive reasoning (no legacy firmware available to confirm
     directly) points to this being an **output** from the BMS MCU into an OBC external
     interrupt — signalling OBC to pause its main loop and execute an emergency payload-
     shedding sequence, enter safe/survival mode, or isolate the battery. A plain GPIO
     interrupt is adequate for this; PWM-encoded signalling was considered but is unnecessary
     if the only purpose is to flag "power conservation mode" conditions.
   - **Still open:** final confirmation of both interpretations with the OBC subteam.

   Approximate maximum current per connector: ~3 A (needs verification against the
   NASA-STD-8739.4 / IPC-2221B derating applied for the 5 A continuous cell-protection feed —
   see `Open Risks & TBDs`_).

   Also needed: RBF (Remove Before Flight) pins and deployment switch connections — confirm
   PC104 standard with COMMS and OBC.

**I2C Signal Integrity**

Zener diodes with resistors on both ends of the I2C lines (``I2C_SDA``, ``I2C_SCK``) have been
added for ESD protection and to suppress transients that could corrupt communication.

----

Charging Architecture
---------------------

Overview
~~~~~~~~

Charging is **handled on the MPPT/Solar board**, not the Battery Board. The Battery Board
participates in charging only through its protection ICs (which gate the charge FETs).

The EPS operates in two charging modes:

MPPT Mode (Constant-Current Phase)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:When: Battery voltage is below the End-of-Charge (EoC) threshold.
:How: The MPPT algorithm operates the solar panel at its Maximum Power Point for maximum
      power transfer. This delivers constant current to the battery as voltage rises.

EoC Mode (Constant-Voltage Phase)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:When: Battery voltage reaches the EoC threshold (~8.4 V for 2S).
:How: The solar array operating point is shifted *away* from the MPP. The battery is held at
      constant voltage while current tapers to near-zero. Excess solar power is dissipated
      as heat on the array.

Charging Phases in Detail
~~~~~~~~~~~~~~~~~~~~~~~~~~

**Pre-Charge**

A low-current phase used when the battery has been drained below the CC charge threshold
(approximately 2.5 V per cell). Pre-charge brings cells up to the point where normal CC
charging can commence safely.

**Thermal Regulation**

At the start of CC charging, the large difference between initial and final cell voltages
causes high power dissipation and heat generation. Once the cell voltage rises sufficiently,
the current no longer generates as much heat and the thermal regulation phase ends.

**Constant-Current (CC)**

Current is held constant at a fixed rate while voltage rises freely, up to the maximum cell
voltage (~4.1 V per cell for a 3.7 V nominal cell). A feedback loop monitors the duty cycle
of the DC-DC converter to prevent overcurrent as the battery voltage rises.

**Constant-Voltage (CV)**

The circuit holds the output at a constant voltage while current tapers naturally to near-zero
as the battery approaches full charge.




Emergency / Safe Mode Power Strategy (Under Revision)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In SOS/safe mode, the following subsystems must remain operational (per advisor recommendation):

- **ADCS** — attitude determination and control
- **EPS** — power management
- **COMMS** — communications

Combined power requirement in SOS mode: ~17 W. This figure was determined in April 2025, and may be subject to change.

All other subsystems should be commandably shed. Inrush current for each subsystem must be
accounted for when designing the LCL trip thresholds.

----

Interfaces
----------

.. list-table::
   :header-rows: 1

   * - Interface
     - Connects To
     - Type
     - Notes
   * - Battery pack output
     - Reverse-blocking diode → E-Fuse (TPS7H2140-SEP) ``IN``
     - Power
     - Main battery bus. 2× parallel 1N5822U ESCC Schottky diodes provide series
       reverse-current blocking (TI Method 1) ahead of the e-Fuse. MOSFETs in the main path
       must be rated ≥ 2× battery voltage due to spikes from Electrodynamic Tether deployment.
   * - E-Fuse split outputs
     - ``E_FUSE_COMMS`` / ``E_FUSE_SBAND`` / ``E_FUSE_OBC`` / ``E_FUSE_PAYLOAD`` → PC104 bus
     - Power
     - Four independently current-limited (~1.36 A each) raw battery voltage feeds. Replaces
       the former ``PCM_IN``/``BCR_OUT`` path now that PCM has moved to the MPPT/PDB.
   * - I2C1 / I2C2
     - STM32 ↔ BQ28Z610 ×2 (fuel gauges), charger timing
     - Data
     - Internal telemetry bus. Zener ESD protection on both lines.
   * - FDCAN1 / FDCAN2
     - STM32 ↔ TCAN334GDCNT ×2 ↔ PC104 bus (OBC)
     - Data
     - Primary/redundant CAN telemetry bus, resolving the legacy MCU's lack of any CAN
       peripheral.
   * - PC104 bus
     - OBC, ADCS, COMMS, and other subsystems
     - Power + Data
     - Stackthrough connector; carries the split e-Fuse feeds, I2C, and CAN telemetry.
   * - ``EN_D1``
     - E-Fuse ``EN1-4`` (via SN54SC6T06-SEP inverter)
     - GPIO
     - ANDed output of watchdog timer + deployment timer. Active high; inverted before the
       e-Fuse's active-low enable sense.
   * - ``EN_D3``
     - Low-side inhibit (PACK_N switch)
     - GPIO
     - Deployment timer output. Enables ground return path post-deployment.
   * - Battery thermistors
     - STM32 PA6 (``BAT-TEMP``)
     - Analog
     - Temperature monitoring for thermal runaway prevention.
   * - PPS from OBC
     - Watchdog timer input
     - GPIO
     - If PPS not received within 1.25 s, watchdog resets MCU.
   * - Battery heater
     - STM32 PA8 (``TIM1_CH1``), PA5 (``TIM8_CH1N``) → heater MOSFETs
     - GPIO / Power
     - Independent hardware Break-Input fault isolation per heater channel — see
       `Battery Heater PWM Timer Selection`_.
   * - E-Fuse diagnostics
     - ``DIAG_EN``/``CS``/``SEL``/``SEH`` → STM32 GPIO/ADC
     - Data
     - Per-channel fault status and current sense, relayed to OBC over CAN.

----

Signal Integrity & EMI Mitigation
-----------------------------------

The following measures have been implemented to ensure accurate telemetry and reliable
communication in the electromagnetically noisy switching environment:

- **Low-pass filter capacitors** on the BQ28Z610's ``VC1``, ``VC2``, ``SRP``, and ``SRN`` pins
  to reduce EMI coupling into the ADCs used for voltage and current sensing.
- **Zener diodes with series resistors** on both I2C lines (``I2C_SDA``, ``I2C_SCK``) for
  ESD suppression and transient protection.
- **10 Ω – 47 Ω series gate resistors** on power MOSFETs to damp switching-induced ringing.
- **Ferrite bead** (100 Ω @ 100 MHz) on the MCU 3.3 V supply rail.
- **Decoupling capacitors** on all IC supply pins per each IC's datasheet recommendation.
- **1 µF flex-termination MLCC + reverse Schottky (1N5822U)** on each e-Fuse channel output
  to clamp positive/negative inductive transients from fault trips, load switching, and
  cosmic-ray SETs — see `Output Transient Protection`_.
- **4.7 kΩ series isolation resistors** on all e-Fuse digital control lines
  (``EN1-4``, ``SEL``, ``SEH``, ``DIAG_EN``) to shield the MCU from negative transient spikes.

.. note::

   The ferrite bead on ``PACK_N`` has strict current limits. Verify that the bead's rated
   current is sufficient for the full battery discharge current before finalising layout.

----

CAN Telemetry
-------------

Now that the MCU has native dual FDCAN (see `Microcontroller — STM32U3B5CIT6`_), the following
data dictionary and polling-rate plan is tentative (2026-08-29) and subject to change with the
OBC subteam.

**Battery telemetry** (per string, ×2 for string A / string B — 16 signals total):

.. list-table::
   :header-rows: 1

   * - Signal
     - Description
     - Recommended Rate
     - Rationale
   * - ``voltage_A`` / ``voltage_B``
     - Measured voltage of each 2S branch
     - 1–10 Hz
     - Periodic analog measurement; fast enough to track charge/discharge trends.
   * - ``current_A`` / ``current_B``
     - Instantaneous pack current (+discharge / −charge)
     - 10–50 Hz
     - Current changes rapidly under varying loads; catches transient spikes.
   * - ``avg_current_A`` / ``avg_current_B``
     - Moving-average current over a sampling interval
     - 1 Hz
     - Filtered/smoothed metric; does not need high-frequency sampling.
   * - ``temp_A`` / ``temp_B``
     - Measured pack/cell temperature
     - 0.1–1 Hz (every 1–10 s)
     - Thermal mass changes slowly.
   * - ``operation_status_A`` / ``operation_status_B``
     - Current mode (Normal, Sleep, Charging)
     - On change (+1 Hz heartbeat)
     - Event-driven, with a slow heartbeat to guarantee state syncing.
   * - ``safety_status_A`` / ``safety_status_B``
     - OVP/UVP/OCC/OCD/short/over-temp fault flags
     - On change / immediate
     - Must trigger asynchronously as soon as a threshold trips.
   * - ``cycleCount_A`` / ``cycleCount_B``
     - Cumulative charge/discharge cycles
     - ~0.01 Hz (or on boot / daily)
     - Updates very rarely.
   * - ``remainingCapacity_A`` / ``remainingCapacity_B``
     - Estimated remaining charge (mAh/mWh)
     - 0.1–1 Hz
     - SoC changes continuously but slowly.

**Battery voltage distribution telemetry** (5 signals):

.. list-table::
   :header-rows: 1

   * - Signal
     - Description
     - Recommended Rate
   * - ``OBC_ALIVE``
     - Heartbeat toggled 0/1 each poll to verify OBC health
     - 1 Hz (matches supervisor poll period)
   * - ``E_FUSE_COMMS``
     - Current telemetry for the COMMS feed
     - 1–10 Hz (+ on-change for trip events)
   * - ``E_FUSE_SBAND``
     - Current telemetry for the S-band feed
     - 1–10 Hz (+ on-change for trip events)
   * - ``E_FUSE_OBC``
     - Current telemetry for the OBC feed
     - 1–10 Hz (+ on-change for trip events)
   * - ``E_FUSE_PAYLOAD``
     - Current telemetry for the Payload feed
     - 1–10 Hz (+ on-change for trip events)

Combined, this gives **21 CAN commands** total across both tables.

----

Component Change Log
--------------------

.. list-table::
   :header-rows: 1

   * - Old Component
     - New Component
     - Reason
   * - BQ2970 / BQ29723 (1S cell protection ×4)
     - BQ28Z610 (2S protection ×2)
     - 2S IC integrates protection, balancing, IV monitoring, and temperature sensing.
       Eliminates floating ground risk and stacked-1S limitations. See `Cell-Level Protection`_
       for full rationale.
   * - STM32F030F4P6
     - STM32F030C8T6 → **STM32U3B5CIT6**
     - F4P6 → C8T6: two BQ28Z610 ICs share I2C address 0x55; the F4P6 only has one I2C
       peripheral. C8T6 → U3B5CIT6: OBC requires a redundant dual-CAN bus, which the C8T6
       (and the whole F0 family) completely lacks. See `Microcontroller — STM32U3B5CIT6`_.
   * - No per-cell fusing
     - PPTC fuses (one per cell, trip at 4.5 A)
     - Isolate individual shorted cells without taking down parallel bank.
   * - No E-Fuse
     - TPS259472ARPWR → **TPS7H2140-SEP (PTPS7H2140PWPTSEP)**
     - COTS device replaced with a 30 krad(Si) TID / SEL-immune SEP-grade part; also absorbs
       the TPS24750 high-side-inhibit role. See
       `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_.
   * - TPS24750 (high-side inhibit)
     - Removed — role absorbed by TPS7H2140-SEP
     - COTS, non-radiation-qualified part; redundant once the new e-Fuse's ``EN`` gating
       satisfies the same launch-inhibit requirement.
   * - No ideal diodes
     - LM74800-Q1 (×2)
     - Prevent back-feeding between the two 2S2P strings.
   * - No reverse-current blocking at pack output
     - 2× parallel 1N5822U (ESCC Schottky)
     - Series blocking diode (TI Method 1) ahead of the e-Fuse ``IN`` pin; sized for 6 A
       against the 34.8 W July 2026 power budget.
   * - NTJD1155L (low-side inhibit)
     - Under review (FDC6318P or 2× discrete MOSFETs)
     - Original device cannot handle the full battery return current (max 1.3 A rating).
   * - No series cell balancing IC
     - BQ28Z610 (integrated passive balancing)
     - Prevents individual cell overcharge; extends pack lifespan.
   * - No MCU supervisor
     - TPS3823-25DBVR
     - Hardware reset/brownout supervision independent of firmware; coordinated with the
       STM32's internal BOR0 (~1.8–2.1 V) so the external part always trips first.
   * - No CAN transceiver
     - TCAN334GDCNT (×2)
     - Required once the MCU gained native dual FDCAN; converts digital TX/RX to
       differential CAN-H/CAN-L for the primary/redundant OBC bus.


----

Open Risks & TBDs
------------------

.. list-table::
   :header-rows: 1

   * - Risk / TBD
     - Owner
     - Target Resolution
   * - Low-side inhibit (NTJD1155L) replacement not finalised — FDC6318P vs. 2× discrete
       MOSFETs. Verify current rating, package size, and gate drive requirements.
     - TBD
     - Before PCB layout freeze
   * - Ferrite bead on ``PACK_N`` current rating — must be verified against peak discharge
       current.
     - TBD
     - Before PCB layout freeze
   * - PC104 bus connector current limit (~3 A assumed) — needs formal verification with
       standard and OBC/COMMS subteams, and against the 5 A continuous / NASA-STD-8739.4
       (AWG derating) and IPC-2221B (trace sizing) requirements identified for the
       cell-protection harness.
     - TBD
     - Coordinator review
   * - Confirm with OBC whether ``EPS_INT``/``BATT_INT`` behave as deduced (see
       `PC104 Bus Connector`_) — no legacy firmware was available to verify directly.
     - TBD
     - OBC coordination
   * - MOSFET ratings — all MOSFETs in the main power path must be rated at ≥ 2× battery
       voltage to withstand spikes from Electrodynamic Tether deployment.
     - TBD
     - Component selection review
   * - Inrush current limits — LCL trip thresholds for each subsystem not yet defined.
     - TBD
     - System-level power budget
   * - BQ28Z610 filter capacitor values (``VC1``, ``VC2``, ``SRP``, ``SRN``) — values not
       yet chosen. Document rationale when selected.
     - TBD
     - Schematic update
   * - Charging implementation — optocoupler vs. optoemulator vs. buck + op-amp feedback.
       Finalise approach considering radiation environment.
     - TBD
     - Architecture review
   * - What systems remain powered in SOS mode — formal power budget for safe mode not yet
       finalised. Advisor recommends ADCS + EPS + COMMS (17 W).
     - TBD
     - System-level review
   * - Death-of-discharge scenario — behaviour and recovery if battery fully depletes not
       yet defined.
     - TBD
     - Firmware + hardware review
   * - Confirm with OBC whether the primary system bus is strictly FDCAN, bxCAN
       (CAN 2.0B), or a hybrid — if bxCAN, this board's FDCAN1/FDCAN2 must run in Classic
       CAN mode (loses FD performance benefits while keeping the FDCAN silicon complexity).
     - TBD
     - OBC coordination
   * - FDCAN2's default CubeMX pin mapping (``PB12``/``PB13``) is not yet formally verified
       against a second-connector requirement — depends on whether dual-CAN-bus fault
       tolerance is a hard mission requirement.
     - TBD
     - Systems engineering / OBC
   * - CubeMX parameter settings (bus speeds, PWM timing, FDCAN data-phase timing, NVIC
       priorities) — see `CubeMX Parameter Settings (Open)`_.
     - TBD
     - Before code generation / bring-up
   * - Crystal :math:`C_0` for the NDK NX3225SA-16.000M-STD-CRS-2 is an estimate (3 pF, not
       published by NDK) — confirm via NDK or bench measurement before fab sign-off.
     - TBD
     - Before fab
   * - E-Fuse ``CS``/``SEL``/``SEH`` current-sense usage — determine whether e-Fuse current
       sensing is needed at all given the BQ28Z610 gas gauges already provide pack current
       telemetry; if used, size :math:`R_{CS}` for the worst-case 1.41 A channel peak.
     - TBD
     - Schematic update
   * - 3.3 V rail current budget — STM32U3B5CIT6 contribution to the connector-level current
       budget (alongside the ~138 µA typical / ~265 µA worst-case LTC6995 ×2 draw) is
       pending; see `3.3V Input Protection and Filtering`_.
     - TBD
     - Before layout freeze

----

Action Items
------------

Hardware

- [ ] Select replacement for NTJD1155L low-side inhibit — compare FDC6318P (dual P-channel,
      requires signal inversion) against 2× discrete P+N MOSFETs. Verify rated current covers
      full battery discharge path through ``PACK_N``. Check whether a NOT gate or inverter
      is needed for gate drive.
- [ ] Verify ferrite bead on ``PACK_N`` is rated for full battery discharge current.
- [ ] Verify all MOSFETs in the main power path are rated ≥ 2× battery voltage to withstand
      transient spikes from Electrodynamic Tether deployment.
- [x] Choose discrete component values for E-Fuse (TPS7H2140-SEP) circuit — per-channel
      :math:`R_{\text{LIMx}} = 1.47\text{ k}\Omega`; ``EN`` inversion via SN54SC6T06-SEP;
      see `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_.
- [ ] Choose filter capacitor values for BQ28Z610 ``VC1``, ``VC2``, ``SRP``, and ``SRN``
      pins. Document rationale for chosen values.
- [ ] Confirm inductor L1 = 2.2 µH is appropriate for TPS63060 switching duty cycle at
      the chosen output voltage and load range.
- [ ] Resolve low-side inhibit ground disconnect — confirm whether the low-side inhibit
      should be on the high-current ``PACK_N`` path, or whether the ferrite bead on that
      net must be replaced or removed.
- [ ] Confirm actual :math:`C_0` for the NDK NX3225SA-16.000M-STD-CRS-2 crystal with NDK or
      via sample measurement (currently estimated at 3 pF).
- [ ] Size :math:`R_{CS}` for e-Fuse current sensing, or confirm the feature is unused given
      redundant BQ28Z610 current telemetry.
- [ ] Reduce the 3.3 V input protection network to the trimmed scope (single bulk cap + TVS
      ~3.6 V Vrwm + series fuse/PTC) and bench-verify no UVLO-threshold dip on the STM32 under
      a simulated cross-subsystem load-step from the shared MPPT converter node.

Schematic & Design

- [x] Define ``EPS_INT`` and ``BATT_INT`` net purpose (deductive analysis complete — see
      `PC104 Bus Connector`_); still need final confirmation with OBC.
- [ ] Determine whether MCU 3.3 V supply should be sourced from the Battery Board local
      regulator or from the MPPT board. Document rationale and update schematic accordingly.
- [ ] Review MPPT and Battery Board schematics together and map potential failure modes
      across the boundary.
- [ ] Confirm with OBC whether the primary bus is strictly FDCAN, bxCAN, or a hybrid, and
      finalize CAN routing/topology (primary vs. redundant physical connector) accordingly.
- [ ] Confirm PC104 bus connector current limit against NASA-STD-8739.4/IPC-2221B derating
      and pin assignments with COMMS and OBC subteams. Clarify RBF and deployment switch pin
      locations.
- [ ] Confirm whether batteries can be mounted below the PCB and coordinate with Mechanical and MPPT (for kelvin and temperature sensing).
- [ ] Finalize CubeMX parameter settings (bus speeds, ADC sampling, PWM timing, FDCAN
      data-phase timing, NVIC priorities) and commit the ``.ioc``/generated code diff.
- [ ] Verify hardware architecture design document (HADD) reflects the STM32U3B5CIT6 pinout
      and migration rationale.

Firmware & Testing

- [ ] Define which subsystems remain powered in SOS/safe mode and formalise the 17 W
      power budget. Confirm figures are still current (originally set April 2025).
- [ ] Define behaviour and recovery procedure for death-of-discharge (battery fully depleted
      below pre-charge threshold).
- [ ] Define inrush current profile for each subsystem and set LCL trip thresholds
      accordingly.
- [ ] Determine what needs to be programmed on the STM32 — list firmware modules required
      (BQ28Z610 I2C polling, heater control, watchdog PPS handling, CAN telemetry reporting
      per the trigger/update-rate table in `CAN Telemetry`_).
- [ ] Measure STM32U3B5CIT6 current consumption and add to power budget.
- [ ] Migrate toolchain/startup code/linker scripts from Cortex-M4 to Cortex-M33 for the
      new MCU.

Procurement

- [ ] Generate KiCad Bill of Materials.
- [ ] Purchase test stock: BQ29737 ICs, CSD16406Q3 MOSFETs, 330 Ω resistors, 2.2 kΩ
      resistors, 0.1 µF capacitors.
- [ ] Verify PPTC fuse trip current is correct for the series-connected cell pairs —
      confirm 4.5 A per cell is appropriate given the 2S4P topology and expected peak
      discharge current.

----

Traceability (V-Model)
------------------------

Requirements
~~~~~~~~~~~~

.. req:: Battery pack bus voltage
   :id: REQ_EPS_001
   :status: draft

   The battery pack shall provide a nominal bus voltage of 7.2 V in a 2S Li-Ion
   configuration, with a maximum charge voltage not exceeding 8.4 V.

.. req:: Cell-level fault protection
   :id: REQ_EPS_002
   :status: draft

   Each Li-Ion cell shall be protected against overvoltage (OVP), undervoltage (UVP),
   overcurrent in charge (OCC), overcurrent in discharge (OCD), overload in discharge,
   short circuit in charge, and overtemperature in charge and discharge.

.. req:: Cell balancing
   :id: REQ_EPS_003
   :status: draft

   The battery pack shall balance series cells during charging to prevent individual cell
   overvoltage and to extend pack lifespan.

.. req:: Launch safety inhibit
   :id: REQ_EPS_004
   :status: draft

   The battery pack shall be electrically inhibited from supplying current to any load
   during launch and until satellite deployment is confirmed, in accordance with CubeSat
   launch provider requirements.

.. req:: Pack-level overcurrent protection
   :id: REQ_EPS_005
   :status: draft

   The battery pack output shall be protected against overcurrent and reverse polarity
   conditions before current reaches any downstream subsystem.

.. req:: Per-cell fault isolation
   :id: REQ_EPS_006
   :status: draft

   A single shorted cell shall be isolatable from its parallel bank without interrupting
   power delivery from the remaining cells.

.. req:: Inter-string isolation
   :id: REQ_EPS_007
   :status: draft

   The two 2S2P battery strings shall be electrically isolated from one another to prevent
   reverse current flow from a higher-voltage string into a lower-voltage string.

.. req:: Battery telemetry
   :id: REQ_EPS_008
   :status: draft

   The EPS shall measure and report battery pack voltage, current, temperature, and state
   of charge for each string independently over I2C to the STM32 MCU.

.. req:: Thermal protection
   :id: REQ_EPS_009
   :status: draft

   The EPS shall monitor battery temperature and shall activate a heater circuit to
   maintain battery temperature within the safe operating range during eclipse.

.. req:: Watchdog reset
   :id: REQ_EPS_010
   :status: draft

   The MCU shall be reset by an external hardware watchdog if a PPS signal from the OBC
   is not received within 1.25 s, without requiring MCU firmware intervention.

.. req:: Safe mode power continuity
   :id: REQ_EPS_011
   :status: draft

   In safe mode, the EPS shall maintain power to ADCS, EPS, and COMMS subsystems. Total
   power budget for safe mode shall not exceed 17 W (figure subject to revision).

.. req:: Redundant CAN telemetry bus
   :id: REQ_EPS_012
   :status: draft

   The EPS Battery Board shall report telemetry to OBC over a primary and redundant CAN bus,
   such that a fault on one physical CAN connector or transceiver does not prevent telemetry
   delivery.

Design Specifications
~~~~~~~~~~~~~~~~~~~~~~

.. spec:: 2S4P split-pack battery topology
   :id: SPEC_EPS_001
   :satisfies: REQ_EPS_001, REQ_EPS_003, REQ_EPS_007

   Two independent 2S2P battery strings using NCR18650GA cells. Each string is managed by
   a dedicated BQ28Z610 2S protection IC with integrated passive cell balancing (external
   balancing schematic ``External_Cell_Balancing.sch``). LM74800-Q1 ideal diode controllers
   with back-to-back N-channel MOSFETs are placed at each string output to prevent
   reverse current flow between strings. This topology eliminates the floating ground
   failure mode of stacked 1S ICs and halves the current through each FET pair, reducing
   :math:`I^2R` losses by a factor of four versus a single-string design.

.. spec:: BQ28Z610 cell-level protection
   :id: SPEC_EPS_002
   :satisfies: REQ_EPS_002, REQ_EPS_003, REQ_EPS_008

   Two BQ28Z610 ICs, one per 2S2P string, provide OVP, UVP, OCC, OCD, overload discharge,
   short-circuit-in-charge, and overtemperature protection for charge and discharge. Each IC
   uses two independent ADCs to sample cell voltage and current simultaneously, providing
   accurate state-of-health telemetry. Passive cell balancing is handled by an external
   balancing schematic to support the higher balancing currents required by the 4-cell
   parallel banks. Low-pass filter capacitors on ``VC1``, ``VC2``, ``SRP``, and ``SRN``
   reduce EMI coupling into the ADCs. Both ICs communicate over I2C (fixed address 0x55)
   using two independent I2C peripherals (I2C1, I2C2) on the STM32U3B5CIT6.

.. spec:: Per-cell PPTC fusing
   :id: SPEC_EPS_003
   :satisfies: REQ_EPS_006

   One PPTC fuse rated at 4.5 A trip current is placed in series with each cell. An
   internal cell short causes parallel cells to sink excessive current into the faulted
   cell; the PPTC fuse trips and isolates the shorted cell, allowing the remaining cells
   in the bank to continue operating. PPTC fuses are automatically resettable and
   introduce a negligible voltage drop under normal conditions.

.. spec:: E-Fuse pack output protection
   :id: SPEC_EPS_004
   :satisfies: REQ_EPS_005

   A TPS7H2140-SEP (PTPS7H2140PWPTSEP) radiation-tolerant quad e-Fuse is placed at the
   battery pack output, gated by a series 2× parallel 1N5822U reverse-blocking diode pair on
   its ``IN`` pin. Its four channels are split, one per downstream subsystem
   (``E_FUSE_COMMS``, ``E_FUSE_SBAND``, ``E_FUSE_OBC``, ``E_FUSE_PAYLOAD``), each
   independently current-limited to ~1.36 A via its own :math:`R_{\text{LIMx}} = 1.47
   \text{ k}\Omega`. The E-Fuse response is significantly faster than the PPTC fuses,
   protecting downstream subsystems from transient fault currents. ``EN1-4`` are commoned
   and driven from ``EN_D1`` through an SN54SC6T06-SEP inverter (see
   `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_).

.. spec:: Deployment timer and launch inhibit
   :id: SPEC_EPS_005
   :satisfies: REQ_EPS_004

   An LTC6995HS6-1 silicon oscillator deployment timer controls the low-side inhibit
   (PACK_N ground path switch), preventing any battery current from flowing until the
   satellite has completed deployment. A second LTC6995 instance acts as the watchdog
   timer. The high-side inhibit — now implemented by the TPS7H2140-SEP e-Fuse rather than
   the previous TPS24750 — is gated by the ANDed output of both timers (``EN_D1`` in
   ``power_control_RBF.sch``), providing dual-redundant safety against false positive
   activation.

.. spec:: STM32U3B5CIT6 microcontroller
   :id: SPEC_EPS_006
   :satisfies: REQ_EPS_008, REQ_EPS_009, REQ_EPS_010

   The STM32U3B5CIT6 MCU provides two independent I2C peripherals to poll both BQ28Z610
   ICs at their shared address (0x55) without a multiplexer. It receives battery
   temperature via PA6, controls heater MOSFETs via PA8 (TIM1_CH1) and PA5 (TIM8_CH1N,
   complementary), and receives e-Fuse fault/diagnostic status via PA10 and the ``CS``/
   ``SEL``/``SEH`` lines. An external 16 MHz NDK NX3225SA-16.000M-STD-CRS-2 crystal on
   PH0/PH1 provides a stable clock reference across the thermal cycling range of orbit.
   An external hardware watchdog (LTC6995) resets the MCU if PPS from the OBC is not
   received within 1.25 s; a TPS3823-25DBVR supervisor additionally provides brownout/
   fault reset independent of firmware, coordinated with the MCU's internal BOR0 threshold.

.. spec:: Redundant CAN telemetry bus
   :id: SPEC_EPS_008
   :satisfies: REQ_EPS_012

   Two native STM32U3B5CIT6 FDCAN controllers (FDCAN1 on PA11/PA12, FDCAN2 on PB12/PB13),
   each paired with its own TCAN334GDCNT transceiver, provide a primary and redundant CAN
   bus to OBC. Both transceivers are held in standby (not full shutdown) so that an
   emergency telemetry signal can be transmitted without a regulator/boot delay. See
   `CAN Transceiver — TCAN334GDCNT`_ and `CAN Telemetry`_.

.. spec:: Safe mode load shedding
   :id: SPEC_EPS_007
   :satisfies: REQ_EPS_011

   The PDM provides commandable load switching via I2C from the OBC, with individual
   LCLs per output. In safe mode, all non-essential loads are shed and power is
   maintained only to ADCS, EPS, and COMMS. The 17 W safe mode power figure must be
   validated against the final power budget before PDM LCL thresholds are set.

Test Cases & Verification
~~~~~~~~~~~~~~~~~~~~~~~~~~

.. test:: Battery Voltage Rail
   :id: TEST_EPS_001
   :verifies: SPEC_EPS_001

   Apply a calibrated DC load to the battery pack output and verify bus voltage is within
   7.0 V – 8.4 V under all expected load conditions. Measure with a calibrated multimeter.
   Pass criterion: voltage within ±2% of expected value at each load step.

.. test:: OVP/UVP Fault Activation
   :id: TEST_EPS_002
   :verifies: SPEC_EPS_001

   Drive a single cell above the BQ28Z610 OVP threshold and verify that the charge FET is
   disabled within the IC's specified fault response time. Repeat for UVP.

.. test:: Launch Inhibit
   :id: TEST_EPS_003
   :verifies: SPEC_EPS_003

   With deployment timer in the pre-deployment (inhibit) state, verify that no voltage appears
   at any load output. Simulate deployment switch activation and confirm power is enabled
   within the timer's specified delay.

.. test:: Telemetry Accuracy
   :id: TEST_EPS_004
   :verifies: SPEC_EPS_004

   Compare BQ28Z610 reported current and voltage against calibrated bench measurements across
   a range of charge/discharge currents. Pass criterion: ≤ 1% error on current, ≤ 0.5% on
   voltage.

.. test:: Redundant CAN Bus Failover
   :id: TEST_EPS_005
   :verifies: SPEC_EPS_008

   With both FDCAN1 and FDCAN2 buses connected and reporting telemetry, disconnect or
   fault-inject one physical CAN connector/transceiver. Verify telemetry continues to be
   received by OBC over the remaining bus without a firmware restart. Repeat for the other
   bus.

----

Bring-Up & Debug Procedure
----------------------------

#. **Pre-power checks**: Verify no short circuit between ``PACK_P``/``PACK_N`` and GND using
   a multimeter in continuity mode.
#. **Verify PPTC fuse placement**: Confirm each PPTC fuse is in series with its respective
   cell before connecting the battery pack.
#. **Inhibit state check**: With deployment timer in inhibit state, confirm that ``EN_D1``
   and ``EN_D3`` are logic LOW and no output voltage is present on any load rail.
#. **Apply power at current limit**: Connect bench supply at 3.3 V, 100 mA current limit.
   Confirm STM32 powers up and crystal oscillator starts (measure PH0/PH1 for 16 MHz clock).
#. **I2C communication**: Scan I2C bus (using STM32 or a logic analyser) and confirm BQ28Z610
   responds at address 0x55 on both I2C peripherals.
#. **Deployment timer simulation**: Simulate deployment switch activation. Verify that the
   low-side inhibit and high-side inhibit enable in sequence.
#. **Battery pack connection**: With all protection verified, connect battery pack. Monitor
   bus voltage and confirm it is within expected range (~7.2 V – 8.4 V).
#. **Charge cycle test**: Initiate a charge cycle and verify CC and CV phases transition
   correctly, and that the BQ28Z610 reports state-of-charge progression.
#. **Fault injection**: Force an overvoltage or overcurrent condition and confirm the
   BQ28Z610 opens the appropriate FET within the rated response time.

----

Errata
------

- No known errata for v0.1. Update this section as issues are discovered and accepted
  without fix for the current revision.

----

Lessons Learned Log
--------------------

Append-only. Add an entry after each prototyping or testing phase.

[2026-03-11] (Issue #1)
~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: Stacked 1S cell protection ICs (BQ2970) created a floating ground risk when
              the bottom bank entered a fault state.
:Why It Failed: 1S ICs were not designed to be stacked in series. The top bank lost its
                connection to PACK_N, allowing uncontrolled current paths.
:Resolution: Replaced with dedicated 2S BQ28Z610 ICs in a split-pack (2S2P × 2) topology.

[2026-03-12] (Issue #2)
~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: STM32F030F4P6 had only one I2C peripheral, insufficient for two BQ28Z610 ICs
              at the same fixed address (0x55).
:Why It Failed: IC address is hardwired; cannot be changed. A multiplexer was initially
                considered but added complexity.
:Resolution: Upgraded to STM32F030C8T6, which has two independent I2C peripherals.

[2026-08-08] (MCU Migration)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: OBC's redundant dual-CAN-bus requirement could not be met — the STM32F030C8T6
              (and the entire F0 family) has no CAN peripheral at all.
:Why It Failed: The C8T6 was selected in 2026-03 purely to gain a second I2C peripheral;
                CAN was not yet a known requirement at that time.
:Resolution: Migrated to the STM32U3B5CIT6 (dual native FDCAN, hardware flash ECC + SRAM
             parity, ultra-low-power LDO variant), after comparing against STM32G473CBT6,
             STM32F105RBT6, STM32G0B1CBT6, VA41620, and ATSAMC21J18A. See
             `Microcontroller — STM32U3B5CIT6`_.

[2026-08-19] (E-Fuse / High-Side Inhibit Consolidation)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: Both the TPS259472ARPWR (pack-output E-Fuse) and TPS24750 (high-side inhibit)
              were COTS parts with no TID/SEL qualification, leaving two unhardened ICs in
              the primary battery-protection path.
:Why It Failed: Both parts were selected early in the design for functional fit, before the
                program's radiation-hardening requirements were fully worked through for this
                board.
:Resolution: Both were replaced by a single TPS7H2140-SEP (PTPS7H2140PWPTSEP) SEP-grade
             quad e-Fuse (30 krad(Si) TID, SEL-immune to 43 MeV·cm²/mg), which now absorbs
             both roles. Its four channels were split (2026-08-28 update) to give OBC
             independent per-subsystem telemetry instead of a single combined 5.4 A rail.
             See `E-Fuse — TPS7H2140-SEP (PTPS7H2140PWPTSEP)`_.

----

References
----------

- BQ28Z610 Datasheet: https://www.ti.com/lit/ds/symlink/bq28z610.pdf
- BQ2970 Datasheet: https://www.ti.com/lit/ds/symlink/bq2970.pdf
- INA219 Datasheet: https://www.ti.com/lit/ds/symlink/ina219.pdf
- TPS63060 Datasheet: https://www.ti.com/lit/ds/symlink/tps63060.pdf
- LTC6995 Datasheet: https://www.analog.com/media/en/technical-documentation/datasheets/LTC6995-6695-1-6695-2.pdf
- TPS24750 Datasheet (superseded, see `Removal of TPS24750`_): https://www.ti.com/lit/ds/symlink/tps24750.pdf
- NTJD1155L Datasheet: https://www.onsemi.com/pdf/datasheet/ntjd1155l-d.pdf
- FDC6318P Datasheet (replacement candidate): https://www.onsemi.com/pdf/datasheet/fdc6318pd.pdf
- LM74800-Q1 Datasheet: https://www.ti.com/lit/ds/symlink/lm7480-q1.pdf
- TPS259472ARPWR Datasheet (superseded E-Fuse): https://www.digikey.com/en/products/detail/texas-instruments/TPS259472ARPWR/14124020
- TPS7H2140-SEP Datasheet (current E-Fuse): https://www.ti.com/lit/ds/symlink/tps7h2140-sep.pdf
- SN54SC6T06-SEP Datasheet (E-Fuse EN inverter): https://www.ti.com/lit/ds/symlink/sn54sc6t06-sep.pdf
- 1N5822U Datasheet (reverse-current / spike-clamp Schottky): search manufacturer part
  1N5822U, LCC2B package, ESCC-qualified per QPL005
- BQ25887RGET (2S Charger): https://www.digikey.ca/en/products/detail/texas-instruments/BQ25887RGET/10270216
- CC-CV with op-amps: https://www.ti.com/lit/ab/slla619/slla619.pdf
- BQ25887 Application Notes: https://www.ti.com/lit/an/slua938/slua938.pdf
- STM32U3B5CIT6 Datasheet: https://www.st.com/resource/en/datasheet/stm32u3b5ci.pdf
- STM32U3 Series Application Note AN6011 (oscillator/reference design):
  https://www.st.com/resource/en/application_note/an6011.pdf
- NDK NX3225SA-16.000M-STD-CRS-2 Datasheet: https://media.digikey.com/pdf/data%20sheets/ndk%20pdfs/nx3225sa%20std-crs-2.pdf
- TPS3823-25DBVR Datasheet (MCU supervisor): https://www.ti.com/lit/ds/symlink/tps3823-25.pdf
- TCAN334GDCNT Datasheet: https://www.ti.com/lit/ds/symlink/tcan334.pdf
- NASA CubeSat 101: https://www.nasa.gov/wp-content/uploads/2017/03/nasa_csli_cubesat_101_508.pdf
- STM32 AN2867 Oscillator Design Guide
- Clyde Space EPS Manual (cc-cv charging reference, Figure 9-1, p. 28)
- LCL reference: https://www.3d-plus.com/products/space-radiation-tolerant-latch-up-current-limiter-lcl-protection/
- Sensitron LCL: https://www.sensitron.com/data_sheets/5100.pdf
- NASA-STD-8739.4 (workmanship / wire and cable derating)
- IPC-2221B (generic PCB trace sizing standard)
- ASTM E595 (outgassing)
