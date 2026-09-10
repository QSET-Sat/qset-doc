Battery Board
=============

:Status: Draft
:Project Lead: Donovan Woo
:Reviewers: TBD
:Last Updated: 2026-09-08
:Revision: v0.3

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
   feeds a PCM stage directly. See `E-Fuse — TPS7H2140-SEP / TPS4H160-Q1`_ for the updated
   output path.

.. note::

   **Scope change (2026-09-02):** a single quad-channel e-Fuse can only supply four independent
   rails, but five downstream consumers now require raw battery voltage directly from this board
   (COMMS, S-band, OBC, Payload, and — newly identified — the MPPT board itself, at an estimated
   2–3 A). A second e-Fuse instance has been added to cover the fifth rail; see
   `Channel Topology`_.

This document covers:

- Battery topology and configuration rationale
- Cell-level protection and balancing architecture
- Power conditioning and switching circuitry
- IC selection with detailed justification
- Global label and schematic cross-reference mappings
- Charging methodology (CC/CV)
- Microcontroller pinout and interfacing
- PC104 bus integration
- Interboard reset, health-check, and e-Fuse-failover architecture between this board and OBC
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

Each parallel bank is treated as an independent group. Fault isolation for an internally shorted
cell is now handled at the pack level rather than per cell — see `Pack-Level Fusing`_ for the
current architecture and the rationale for retiring the earlier per-cell PPTC approach.

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The original design used stacked 1S cell protection ICs (BQ2970/BQ29723). This was replaced with
the BQ28Z610 2S dedicated IC for the following reasons:

- **Floating ground risk**: if the bottom bank faults, the top bank loses its connection to
  ``PACK_N``, allowing uncontrolled current paths.
- **Doubled series resistance**: stacked 1S configurations require 4 MOSFETs in the main current
  path; the 2S IC uses only 2.
- **1S ICs were not designed to be stacked**: floating ground voltages cause sensing errors. If
  the bottom protection IC opens its FET, the midpoint voltage is no longer anchored to anything
  and floats to whatever value parasitic capacitance, leakage currents, and any stray conductive
  path pulls it to. The top IC, whose VSS is at that midpoint, now has a completely undefined
  reference, and its voltage measurements become meaningless.
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
     - I2C address is fixed at 0x55 — both ICs share the same address, requiring two independent
       I2C peripherals on the MCU. Resolved by the STM32U3B5CIT6's four native I2C peripherals
       (see `Microcontroller — STM32U3B5CIT6`_); this was the original reason the board first
       moved off the STM32F030F4P6, and remains satisfied by the current MCU choice.

.. note::

   The BQ28Z610 replaces the original BQ2970/BQ29723 1S ICs. See
   `Why 2S Protection Instead of Stacked 1S`_ above for full justification. The
   cell-protection netlist and or-ing schematic (linking the
   BQ28Z610s to the LM74800-Q1 ideal diodes) were reviewed and corrected for errors as a
   dedicated task; no component-value changes resulted beyond what is documented below.

**Why Passive Cell Balancing?**

Passive balancing bleeds excess energy as heat through resistors and MOSFETs.
Active balancing uses DC-DC converters and inductors to transfer energy between cells.

For this application, passive balancing is preferred because:

- Only 2 series cells → voltage drift between series groups is minimal.
- DC-DC converters introduce switching noise (EMI) and reduce efficiency.
- Passive components are simpler, more space-efficient, and have no additional failure modes.




E-Fuse — TPS7H2140-SEP / TPS4H160-Q1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet (space-grade baseline): https://www.ti.com/lit/ds/symlink/tps7h2140-sep.pdf
:Datasheet (prototype substitute): search manufacturer part TPS4H160-Q1
:Replaces: TPS259472ARPWR (pack-output E-Fuse) **and** TPS24750 (high-side inhibit, see
   `Removal of TPS24750`_ below)

The pack-output protection IC was upgraded from the COTS TPS259472ARPWR to the
TPS7H2140-SEP, a Space Enhanced Plastic (SEP) grade quad e-Fuse rated for 30 krad(Si) TID
and SEL immunity up to 43 MeV·cm²/mg. This IC assumes the high-side inhibit role formerly
filled by the TPS24750 (a COTS, non-radiation-qualified part).

.. note::

   **Prototype substitution (2026-09-06):** the TPS4H160-Q1, an automotive-grade part, was
   found to be an almost exact functional equivalent of the TPS7H2140-SEP (same
   :math:`R_{\text{LIMx}}` programming behaviour — the current-limit resistor calculation below
   is unchanged and yields the same 1.35 A per-channel threshold). The automotive part is
   substituted for the first prototype run on cost grounds alone (rad-hard SEP grade is
   ~$1000/unit vs. under $5 for the automotive part). This is **not necessarily final** — the
   space-grade TPS7H2140-SEP may be reinstated for the flight unit. Everything else in this
   section (channel topology, protection behaviour, external component sizing) applies
   identically to both parts unless noted.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - What is it?
     - Function in this circuit
     - Limitations / Notes
   * - Radiation-tolerant (SEP) or automotive-grade (Q1) quad-channel programmable electronic
       fuse. Wide voltage headroom (4.5 V – 32 V; 35 V absolute max) clears the 8.4 V peak
       charge voltage with large margin against inductive/tether spikes.
     - Protects the battery pack output and serves as the CubeSat's mandatory high-side
       inhibit. Two instances are now used (see `Channel Topology`_) to cover five
       independently-metered downstream rails.
     - :math:`R_{ON}` rises from 40 mΩ (25 °C) to 70 mΩ (125 °C) on the SEP part, dissipating
       up to ~1.75 W at 5 A — requires extensive copper pour and thermal vias under the
       PowerPAD for vacuum conduction (no convective cooling in orbit). Simulation shows the
       combined two-IC dissipation could reach ~86.6 W if all five rails short
       simultaneously (see `Simulation Findings`_), which the ``/FAULT``-driven firmware
       response must clear within milliseconds.

**Why not the original COTS E-Fuse?**

PPTC fuses alone have a slow thermal response time; the original TPS259472ARPWR addressed
that but, like the TPS24750 it shared duty with, carries no TID/SEL qualification. Both are
replaced here by the parts above to close that radiation-hardening gap (pending the
automotive-vs-space-grade decision noted above).

Channel Topology
^^^^^^^^^^^^^^^^^

.. note::

   **Design evolution:**

   1. *(2026-07-15, superseded)* All four channels of a single e-Fuse were tied in parallel
      into one ~5.4 A raw-voltage rail feeding PC104 directly, with all four ``EN`` pins
      commoned to a single MCU GPIO.
   2. *(2026-08-08, VOID)* ``EN`` pulled permanently to 3.3 V so the e-Fuse defaults on
      regardless of MCU state — rejected for not satisfying the mandatory high-side-inhibit
      requirement.
   3. *(2026-08-19)* ``EN`` tied to ``EN_D1``, the ANDed output of the watchdog and deployment
      timers, so the e-Fuse is compliant with the CubeSat high-side-inhibit requirement
      regardless of firmware state.
   4. *(2026-08-28)* The four channels of the single e-Fuse were split electrically, one per
      downstream subsystem, so OBC could get independent per-bus current telemetry and an
      overcurrent fault on one subsystem would not blind or trip the others.
   5. *(2026-09-02, current)* A fifth raw-battery-voltage consumer was identified — the MPPT
      board itself draws an estimated 2–3 A — which a single quad-channel e-Fuse cannot
      supply alongside the other four rails. **A second e-Fuse instance was added.** Each
      1.35 A-rated channel is wired in parallel with others on the same rail according to
      that rail's current need, rather than one-channel-per-rail:

      .. list-table:: Rail-to-Channel Allocation
         :header-rows: 1

         * - Rail
           - Channels (of 8 total)
           - Approx. Trip Current (±6% mismatch)
         * - ``E_FUSE_PAYLOAD``
           - 3 (parallel)
           - ~4.05 A (simulation: 4.05–4.20 A)
         * - ``E_FUSE_MPPT``
           - 2 (parallel)
           - ~2.7 A (simulation: 2.7–2.8 A)
         * - ``E_FUSE_OBC``
           - 1
           - ~1.36 A (simulation: 1.4 A)
         * - ``E_FUSE_SBAND``
           - 1
           - ~1.36 A (simulation: 1.4 A)
         * - ``E_FUSE_COMMS``
           - 1
           - ~1.36 A (simulation: 1.4 A)

      Payload's 3-channel allocation is sized against its ~16 W peak power draw from the
      July 2026 power budget (~2–3 A at battery voltage before margin); MPPT's 2-channel
      allocation covers its identified 2–3 A draw. A 1 µF voltage-spike capacitor is retained
      on every individual 1.35 A rail regardless of how many are joined in parallel for a
      given downstream rail; see `Output Transient Protection`_ for how the negative-spike
      clamp diode is shared across a paralleled rail.

- **All-or-nothing enable within a rail, per-rail fault isolation across rails**: the
  ``EN_D1`` hardware signal continues to satisfy the CubeSat high-side-inhibit requirement for
  the whole pack (see below), while each rail's own current limit and diagnostics isolate a
  fault to just that rail.
- **Trade-off accepted**: per-subsystem power sequencing at the e-Fuse level is not available;
  downstream subsystems are responsible for their own inrush/startup sequencing.

EN Signal Path
^^^^^^^^^^^^^^^

.. note::

   Two earlier options were considered and voided:

   - Pulling ``EN`` permanently to 3.3 V (2026-08-08, VOID) — rejected because it does not
     satisfy the mandatory high-side-inhibit requirement.
   - Driving ``EN`` from an MCU GPIO — rejected in favour of the hardware ``EN_D1`` net so
     that inhibit behaviour does not depend on firmware being alive.

.. warning::

   **Open reconciliation item (2026-09-02):** with the move to five independently-metered
   rails, the firmware fault-handling design (`E-Fuse Fault Handling (Firmware)`_) calls for
   each rail's ``EN`` to be individually driven by its own MCU GPIO — five dedicated pins
   — so the auto-retry sequence can isolate a single shorted rail without dropping the other
   four. _.

**EN Polarity / Inverter Selection**

The enable signals are active-high, and the enable sense required by the e-Fuse needed inversion. A
discrete MOSFET or BJT inverter was considered:

- **BJT**: robust ESD tolerance and consistent :math:`V_{BE}` threshold, but a non-zero
  :math:`V_{CE(sat)}` (~0.1–0.3 V) sits uncomfortably close to the e-Fuse's shutdown
  threshold, and requires a series base resistor.
- **Discrete MOSFET**: near-zero :math:`R_{DS(on)}` pull-down gives wider noise margin, but
  discrete MOSFETs are more susceptible to Single-Event Gate Rupture (SEGR) and TID
  threshold shifts that can force a false-enable state.

**Selected: SN54SC6T06-SEP** — a rad-hard (30 krad TID), quad-package logic-level open-drain
inverter IC. A single package provides 6 independent inverters, enough to invert controls for
one full e-Fuse's worth of channels (4) from one small part rather than 4 discrete MOSFETs.
:math:`V_{OL} < 0.2\text{ V}`, comfortably clear of the e-Fuse's enable/disable threshold,
without the SEGR/TID risk of a bare discrete FET. With two e-Fuse instances now in the design,
a second inverter package (or the two spare channels of the first) covers the second IC's four
``EN`` lines.

Current-Limit Resistor Sizing
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Each channel's trip current is set independently by its own :math:`R_{\text{LIMx}}` resistor.
This calculation is identical for the TPS7H2140-SEP and the TPS4H160-Q1 automotive substitute.

:Target: :math:`I_{OUTx,nom} = 1.35\text{ A}` per channel
:Given: :math:`K_{CL} = 2500`, :math:`V_{CL,TH} = 0.8\text{ V}`, silicon gain accuracy
        :math:`\pm 15\%`

.. math::

   R_{\text{LIMx}} = \frac{V_{CL,TH} \times K_{CL}}{I_{OUTx,nom}}
   = \frac{0.8\text{ V} \times 2500}{1.35\text{ A}} = 1481.48\ \Omega

**Selected:** :math:`R_{\text{LIMx}} = 1.47\text{ k}\Omega` (E96, 1%), giving an adjusted
nominal trip current of :math:`\approx 1.36\text{ A}`, applied identically on every channel of
both e-Fuse instances regardless of how many channels are paralleled onto a given rail.

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
   4-channel *parallel* topology feeding one combined rail, deriving a mismatch-adjusted
   system-level trip current of ~4.79 A. That analysis is superseded by the per-channel,
   per-rail-allocation topology above, but the per-channel resistor value it produced
   (1.47 kΩ) carried forward unchanged and is confirmed correct for the current architecture.

Diagnostics, Current Sense, and MCU Pin Budget
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``DIAG_EN`` on both e-Fuse instances is **enabled** (superseding an earlier VOID decision to
permanently ground it), connected so OBC can obtain per-rail current telemetry over CAN (see
`CAN Telemetry`_).

Two full e-Fuse ICs' worth of diagnostic and control signals must now share the MCU's limited
remaining GPIO budget: **5** rail disable (``EN``) lines, **4** diagnostic-multiplexing lines
(``SEL``/``SEH`` ×2 ICs), **2** current-sense lines, and **2** ``FAULT`` lines, against only
~7 free MCU pins. An I2C GPIO expander was evaluated for the disable lines and rejected;
a mixed strategy was selected instead:

- **``EN`` (×5, one per rail): direct MCU GPIOs, not multiplexed.** An I2C-based expander
  was ruled out for these specifically because (1) a heavy-ion strike or transient noise on an
  open-drain I2C bus can hang a slave device holding SDA low, which would strand the MCU's
  ability to disable a faulted rail until a full bus/MCU power cycle; and (2) common I2C GPIO
  expanders (e.g. the TCA9534-SEP) power up with all pins as high-impedance inputs with
  internal pull-ups, which — if the e-Fuse disable logic needs an active state to hold rails
  off during boot — could let power channels turn on before flight firmware has configured the
  expander's registers. Direct GPIO avoids both failure modes for a safety-critical function.
- **``SEL``/``SEH``/``FAULT`` (2 of each, one set per e-Fuse IC): TCA9534 I2C GPIO
  expander (TSSOP-16 package).** These are lower-consequence than the disable lines — a stuck
  I2C bus here degrades diagnostics rather than failing a rail off — so the pin savings are
  worth taking. TSSOP-16 (~5.0×4.4 mm) was chosen over the wider SOIC-16 (~10.3×7.5 mm) to
  conserve board area next to the e-Fuse controllers and level shifters.
- **``CS`` (×2, one per e-Fuse IC): SN74LVC1G3157 analog mux**, package SOT-SC70 (DCK). Gull-wing
  leaded small packages were preferred here over leadless (USON/X2SON) or BGA packages, which
  transfer launch-vibration mechanical stress directly into the die; the gull-wing leads flex
  and absorb PCB bending instead of cracking the solder joints.
- ``CS`` outputs a 1/300 current-sense ratio, capped at 4 V. :math:`R_{CS}` must be sized so a
  worst-case single-channel peak (accounting for ~6% :math:`R_{ON}` mismatch) maps safely to
  ≤ 3.3 V for the MCU's ADC; firmware toggles the mux select lines to sample and sum the
  channels feeding a given rail (see `E-Fuse Fault Handling (Firmware)`_ for the sampling
  sequence already worked out for MPPT and Payload).
- A dedicated fault-detection front end built from external voltage comparators (one per
  channel, plus a priority encoder) was considered and rejected: it would need 5 comparators
  and a 74HC148-class encoder (3 more pins), adds components that can individually fail with
  no redundancy benefit, and increases SEU-susceptible surface area for no gain over polling
  the existing ``FAULT``/``CS`` lines through the MCU. A resistor-ladder/weighted-summing DAC
  alternative was also rejected on temperature-drift grounds, since there isn't ADC/pin budget
  to add temperature compensation for it.
- All digital control lines (``EN`` ×5, ``SEL``, ``SEH``, ``DIAG_EN``) get 4.7 kΩ series
  isolation resistors to shield the MCU from negative transient spikes; ``FAULT`` uses a
  10 kΩ pull-up (VOL_FAULT ≤ 0.2 V at 2 mA sink; actual sink current through a 10 kΩ pull-up
  is only ~0.31 mA, well under the datasheet test point).
- All No-Connect (NC) pins are tied directly to GND per the datasheet's recommendation
  (p. 3) — unbonded floating pins act as high-impedance antennas susceptible to
  radiation-induced charge buildup.

.. warning::

   The exact MCU pin assignment for the 5 ``EN`` lines, the TCA9534 address/interrupt pins,
   and the ``SN74LVC1G3157`` select line has not yet been added to the pinout table in
   `Microcontroller — STM32U3B5CIT6`_. See `Open Risks & TBDs`_.

Output Transient Protection
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Two passive clamps protect each rail's output against inductive transients from fault trips,
dynamic load switching, and cosmic-ray single-event transients (SETs) on the gate driver.

**Positive spike — 1 µF flex-termination MLCC**, present on every individual 1.35 A channel
regardless of how many channels are paralleled onto a rail. Harness/trace inductance
(:math:`L \approx 2\ \mu\text{H}`) dumping into the output capacitor during a fast
(< 1 µs) trip event:

.. math::

   V_{peak} = \sqrt{V_{rail}^2 + \frac{L \cdot I^2}{C_{OUT}}}
   = \sqrt{(8.4\text{ V})^2 + \frac{(2\ \mu\text{H})(1.35\text{ A})^2}{1\ \mu\text{F}}}
   \approx 8.61\text{ V}

The resulting 0.21 V (~2.5%) rise sits comfortably under the 36 V absolute maximum. A
flex-termination MLCC was chosen over rigid ceramic to absorb launch vibration and thermal
flex without cracking (which would otherwise create a hard short to ground).

**Negative spike — JANTXV 1N5806/1N5806U ultra-fast silicon rectifier**, one per paralleled
rail (anode to GND, cathode to the rail), reverse-biased in normal operation.

.. note::

   **Component swap (2026-09-06):** the negative-spike clamp diode was changed from the
   1N5822U Schottky originally specified to the JANTXV 1N5806/1N5806U ultra-fast silicon
   rectifier. Motivation:

   - **Thermal-vacuum leakage.** At elevated temperature (85–125 °C), large power Schottkys
     like the 1N5822 suffer exponential growth in reverse leakage current (into the mA range),
     wasting power continuously across a multi-channel bus. The 1N5806 holds high-temperature
     reverse leakage in the µA range.
   - **Flight heritage / SEE characterization.** The 1N5806 (MIL-PRF-19500/477) has
     well-characterized TID and heavy-ion SEE performance, unlike the uncharacterized SEB risk
     of a commercial Schottky.
   - **Decoupling from the e-Fuse's internal clamp.** The 1N5806's higher forward voltage
     (~0.7–1.0 V) still turns on well before the TPS7H2140-SEP/TPS4H160-Q1's own internal
     active inductive clamp (:math:`V_{DS(clamp)} \approx -45\text{ V to } -60\text{ V}`), so
     the external diode still absorbs the bulk of the trip-event energy pulse ahead of the
     e-Fuse's internal single-pulse energy rating (:math:`E_{AS} = 40\text{ mJ}`).
   - The originally-assumed constraint — that the output pin has a hard :math:`-0.3\text{ V}`
     absolute-maximum limit requiring a very-low-:math:`V_F` Schottky — was found to be
     incorrect: the TPS7H2140-SEP output stage has its own active clamp rated to
     :math:`-45\text{ V}` to :math:`-60\text{ V}`, so the higher :math:`V_F` of a silicon
     rectifier does not risk device damage.
   - For rails with more than one channel paralleled (MPPT, Payload), a single shared 1N5806
     is used per rail rather than one per channel — the diode only conducts for a fraction of
     a microsecond per trip event, so its rating is not the limiting factor, and the small
     increase in reverse-bias voltage at the higher combined current (to roughly 0.4–0.5 V at
     temperature, from 0.3–0.35 V) is not enough to risk triggering internal ESD diodes or
     substrate parasitic latch-up.

   Paralleling multiple diodes on a single rail was considered and rejected: it roughly doubles
   reverse leakage current, and halving the current only reduces :math:`V_F` by 0.3–0.5 V
   regardless of temperature (per the diode's own datasheet curves) — a marginal benefit not
   worth the extra part.

Reverse-Current Protection at the E-Fuse Input
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The TPS7H2140-SEP / TPS4H160-Q1 provides no active reverse-current blocking of its own — under
a short-to-power or reverse-polarity fault, reverse current is only current-limited
(:math:`I_{R1} = 2.5\text{ A}` single-channel, :math:`I_{R2} = 2.0\text{ A}` all-channel), and
while a channel is enabled, current flows through the FET with no blocking behaviour at all.
Per TI's own guidance, a series blocking diode between the battery and each e-Fuse ``IN`` pin
(their "Method 1") is required.

Three options were evaluated:

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
same-lot/date-code sourcing and symmetric PCB layout. This series input-blocking diode pair is
unaffected by the 2026-09-06 negative-spike-clamp diode swap above (that change is at each
channel's output, not the shared series input diode).

:Accepted trade-off: fixed forward-voltage loss (~0.3–0.5 V), continuous under nominal
   operation.

**Removal of output Schottky diodes:** the e-Fuse's own output-side Schottky diodes previously
specified for reverse-current blocking were removed as redundant. The LM74800-Q1 ideal-diode
or-ing at the two 2S2P string outputs already prevents current from flowing backward through
the pack; because the input side is already blocked, an external voltage spike on
:math:`V_{OUT}` cannot complete a circuit back to a lower-potential node — the e-Fuse's input
rail simply floats up through its own internal body diode instead, eliminating the voltage
differential that would otherwise drive continuous reverse current.

Simulation Findings
^^^^^^^^^^^^^^^^^^^^

A PSpice transient simulation of the e-Fuse channel configuration (issue #139, closed) validated
the following before PCB layout:

- **Nominal trip currents** measured in simulation: MPPT rail (2 channels) trips at 2.8 A
  (stable, untripped at 2.7 A); OBC/S-band/Comms rails (1 channel each) trip at 1.4 A (stable
  at 1.3 A); Payload rail (3 channels) trips between 4.05–4.20 A. Response time to fully clear
  the output is ~0.2 ms in each case, with higher-current rails clearing faster.
- **Positive overvoltage transient (inductive load dump / bus surge):** a capacitive-coupling
  injection test (a 40 V pulse through a 1 µF coupling capacitor onto the Payload rail's 3 µF
  decoupling network) produced a peak of ~13.3 V before the e-Fuse recharged the decoupling
  capacitance and the rail recovered.
- **Negative voltage transient:** the same method at 50 V produced a brief −3.1 V spike before
  the negative-spike clamp diode engaged and held the rail at approximately −0.3 V for the rest
  of the transient (vs. an unclamped theoretical trough of about −4.7 V).
- **Start-up inrush:** with a 47 µF downstream bulk capacitor and a load step from 100 mA to
  3.5 A (under the channel limit) modeled on the Payload rail, the rail sags asymptotically to
  ~7.6 V under load and recovers to 7.8 V once the load step ends, with no false trips.
- **Short-circuit let-through:** modeling a hard short (0.01 Ω to ground) on the Payload rail
  showed the current clamps at the expected limit with only a ~50 mA transient spike, and a
  trip-response time of ~50 ns on the ``/FAULT`` line's leading edge.
- **Combined worst case:** if all five rails short simultaneously, total trip current sums to
  ~11.1 A and the two e-Fuse ICs together would dissipate ~86.6 W (99.65% of total system
  thermal load in that event, vs. ~0.31 W in the wiring) — this must clear within a few
  milliseconds via the firmware fault-handling sequence in
  `E-Fuse Fault Handling (Firmware)`_, or thermal shutdown will occur.

----

Pack-Level Fusing
~~~~~~~~~~~~~~~~~~

.. note::

   **Architecture change (2026-09-06/07, issue #201):** the original per-cell PPTC fusing
   architecture (four PPTC fuses, one per cell, 4.5 A trip each) has been replaced with a
   **single non-resettable time-lag fuse per 2S2P pack**, placed at the pack's positive output
   header. The July 2026 power budget review that triggered this issue originally asked only
   whether the PPTC *trip value* should drop from 18 A to 6–7 A; the resulting design review
   concluded the PPTC architecture itself should be retired. Rationale:

   - **PPTC resistance is thermally reactive**, and in a vacuum, heat leaves almost exclusively
     via conduction through traces/harnesses and radiation rather than convection. Heat
     generated at a PPTC fuse sitting close to the cells can feed back into the pack and lower
     the cells' thermal-runaway margin — the opposite of what a battery-protection fuse should
     do.
   - **Wide on-orbit temperature swings** can drift a PPTC's trip threshold enough to cause
     false trips with no underlying fault.
   - A PPTC's resettability is not actually available here: if a PPTC-to-battery thermal
     feedback loop begins, the fuse will not reliably reset even after the fault clears — the
     main advantage of a resettable fuse doesn't hold up under the failure mode it's most
     likely to see.
   - Active protection (a FET switch or e-Fuse-style IC) was explicitly ruled out at this
     level: the pack-level fuse is the "fuse of last resort" underneath everything else, and it
     needs to survive a radiation event that could otherwise disable an active switch.

**Why one fuse per pack, not per cell or per branch:** internal per-branch fuses add extra
:math:`R_{DCR}` that distorts the BQ28Z610 gas gauge and balancer's voltage readings, and
create a real risk of cascading branch trips during a current spike in one cell. Since each
2S2P module already behaves as one electrical unit with its own dedicated balancer and gas
gauge, a single pack-level fuse at the output header gives deterministic fault isolation for
the pack as a whole without those side effects.

**Sizing.** Each e-Fuse instance has a combined channel current limit of 10.8 A; with two
packs sharing the load, each pack nominally carries 5.4 A, but must be able to carry the full
10.8 A alone if the other pack's string fails. Applying an operational derating
(:math:`k_{op} = 0.75`), a thermal derating (:math:`k_{temp} = 0.70`, estimated from the
NCR18650GA datasheet's −10 °C to 25 °C capacity difference), and a vacuum/conduction derating
(:math:`k_{vac} = 0.80`, to account for slower heat dissipation with no convective cooling):

.. math::

   I_{\text{fuse, min}} = \frac{I_{\text{nom}}}{k_{op} \times k_{temp} \times k_{vac}}
   = \frac{10.8\text{ A}}{0.75 \times 0.70 \times 0.80} = \frac{10.8\text{ A}}{0.42}
   \approx 25.7\text{ A}

A 30 A-rated part is the smallest standard rating clearing this 25.7 A floor.

**Placement and fault coverage.** The fuse sits as physically close as layout allows to the
cell terminals or the pack's output header. This location is sized to clear *hard* shorts —
loose metallic debris bridging terminal pads in zero-g, a radiation burst punching through the
ORing FET's silicon substrate, or a direct terminal-to-terminal fault — which is the dominant
failure mode expected at this location. A soft short (e.g. through a 1 Ω resistive fault) would
not draw enough current to trip this fuse; that class of fault is caught downstream by the
e-Fuse's much lower per-channel thresholds instead.

**Asymmetric timing between the two packs.** If one string's LM74800-Q1 ideal diode fails and
the two packs' voltages become mismatched, current will loop between the packs and both fuses
would see the fault current simultaneously. If both pack fuses were identical, they could clear
together, killing both strings and eliminating the benefit of the dual-pack architecture (since
the ideal diode exists specifically to keep two simultaneously-healthy packs from back-feeding
each other — if one diode has already failed, only one pack is expected to remain usable
regardless). Two candidates with deliberately different melting-energy characteristics were
selected so that one pack reliably clears first, preserving the other:

.. list-table:: Pack Fuse Candidates
   :header-rows: 1
   :widths: 15 40 45

   * - Pack
     - Part
     - Role
   * - Pack A
     - Littelfuse 0456030 — fast/standard time-lag ceramic, 1206 SMD, 30 A, low/medium
       :math:`I^2t` (~15–25 A²s)
     - Clears first during a cross-pack loop fault (an 80–120 A+ back-feed from a shorted
       ORing FET), absorbing its melting energy quickly (~1–3 ms). Cold DCR ~1.5–2.0 mΩ,
       minimizing voltage-drop error seen by the gas gauge/balancer.
   * - Pack B
     - Eaton CB61F30A — high-inrush/heavy time-lag ceramic, 1206 SMD, 30 A, high
       :math:`I^2t` (~65–95 A², roughly 3–4× Pack A's)
     - Sees the same fault current but its greater thermal mass means it has absorbed only
       ~20–25% of its melting energy by the time Pack A clears at ~2 ms, so it rides through
       the transient and continues to safely supply the system bus alone. Cold DCR
       ~1.2–1.8 mΩ.

**Paralleling rejected.** Running two lower-rated fuses in parallel per pack (to halve
:math:`R_{DCR}` and spread heat across two locations) was considered and rejected: with a
30 A part's cold :math:`R_{DCR}` of ~1.5 mΩ, resistive power loss is already only
:math:`I^2R = (10.8\text{ A})^2 \times 0.0015\ \Omega \approx 0.175\text{ W}` — not enough to
justify the added complexity — and any real-world mismatch between two paralleled fuses risks
one tripping slightly early on thermal grounds and dragging the other down with it, which
defeats the purpose of splitting the current in the first place. Thermal management at 30 A is
instead handled with copper pour/plane sizing around the single fuse footprint.

----

Ideal Diodes — LM74800-Q1
~~~~~~~~~~~~~~~~~~~~~~~~~~

:Datasheet: https://www.ti.com/lit/ds/symlink/lm7480-q1.pdf

Ideal diodes were added between the outputs of the two 2S2P battery strings to prevent
back-feeding current from one string into the other when the strings are at different states
of charge. The gas-gauge-to-ideal-diode netlist was reviewed and corrected for labeling errors
(issue #135, closed); no component-value changes resulted.

.. note::

   Should an ideal diode itself fail and let the two strings back-feed each other, the pack
   fuses are now deliberately given *asymmetric* time-lag characteristics so that one pack
   clears before the other rather than both clearing together — see `Pack-Level Fusing`_.

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

**2-MOSFET Architecture (2 per Rail)**

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
     - How it's used:

       **Deployment Timer**: ensures ``EN_D1`` is only activated after the satellite has
       completed deployment. The timer output connects to the low-side inhibit gate-driver
       enable path (see `Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)`_);
       nothing can be activated during deployment. 
     - Supply voltage: max 6 V.
       Operating temperature: −40 °C to +125 °C.

----



Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::

   **Full redesign (2026-09-02 through 2026-09-07, issue #203).** The low-side inhibit
   requirement grew from "switch ~1.3 A" to "switch ~10 A without significant heating," which
   the previously-specified NTJD1155L (±1.3 A max) could not meet — see the Component Change
   Log for that history. The replacement below is a from-scratch design, not a drop-in part
   swap.

Low-side inhibits cut the *ground* connection of the load from the source, placed between the
load and ``PACK_N`` (pack negative terminal). This is a mandatory launch safety requirement to
prevent hazardous operation during launch. The design must conduct roughly 10–12 A continuously
with low :math:`R_{DS(on)}` and negligible heating, and turn on when ``EN_D3`` (from the
deployment timer) goes high.

**MOSFET over BJT.** Holding a BJT on at 10 A would waste a large amount of continuous base
drive current (0.5 A+), whereas a MOSFET gate draws essentially zero steady-state current. A
BJT's :math:`V_{CE(sat)}` also offsets the system ground reference by 0.3–0.7 V relative to
true battery negative, which would corrupt clean analog sensor readings referenced to that
ground. MOSFETs were selected on this basis, with the caveat that a rad-hard/rad-tolerant part
is required given MOSFETs' general susceptibility to cosmic-ray-induced failure.

**GaN vs. silicon MOSFET.** A GaN FET (EPC7019G) was compared against a rad-hard silicon
MOSFET (IRHF57034) and looked attractive on paper — roughly 10× lower :math:`R_{DS(on)}`
(4.5 mΩ vs. 48 mΩ), 10× less power dissipation at 10 A (0.45 W vs. 4.80 W), a lower required
gate-drive voltage, and a much smaller/lighter package. A more budget-friendly GaN candidate,
the EPC2204, was investigated further, but its 2.5 V gate threshold would require driving it
from the MPPT board's 5 V rail through a dedicated low-side GaN driver rather than directly
from 3.3 V logic — adding a rail dependency and a driver IC as new failure modes for an
efficiency gain that did not justify them.

**Final decision: silicon MOSFET, not GaN.** The BUK9Y4R8-60E,115, an automotive-grade
silicon MOSFET, was selected over the GaN candidates:

- It operates natively on 3.3 V gate drive, unlike the EPC2204's need for a 5 V-derived driver.
- Adopting GaN would add a dedicated driver IC and a dependency on the MPPT board's 5 V rail
  being stable — additional failure modes for an efficiency gain that matters less once the
  MOSFET is arranged in the redundant array below.
- GaN die are more mechanically fragile; the MOSFET's standard LFPAK56 (Power-SO8)
  copper-clip package handles mechanical shock and launch vibration well.
- With the series-pair arrangement below, the combined on-resistance per parallel branch is
  only ~14 mΩ, giving a total voltage drop across the whole low-side switch of only ~0.084 V
  at 12 A — close enough to the GaN option's headline number that GaN's advantages stopped
  being decisive.

**Quad-transistor redundancy arrangement.** Rather than a single switch, the design uses 8
discrete MOSFETs arranged as two parallel branches of two series-connected pairs, doubled
again into a back-to-back (bidirectional) pair of legs to block current in both directions
through the body diodes — the same principle used for the ideal-diode 4-MOSFET architecture
elsewhere in this document, but built from fully passive discrete devices instead of an active
controller IC:

- **Series pairs** double the effective breakdown-voltage margin (in the ideal case, voltage
  splits evenly across the pair) and mean that a single transistor failing *short* does not
  collapse the isolation — its series partner still blocks.
- **Parallel branches** split the current and mean a single transistor failing *open* does not
  interrupt the whole path — the parallel branch still carries current.
- **Net on-resistance** is unchanged from a single transistor: doubled by the series
  connection, then halved again by the parallel connection.
- This arrangement uses no active control logic, so it cannot suffer a single-event
  latch-up or software lockup — gate nodes are held to a defined state (see
  `Protection Components`_) purely by passive resistors and Zener clamps during launch, which
  was judged the most fail-safe hardware state achievable for a mission-critical, single-use
  deployment mechanism.
- A reliability model (probability of system failure vs. added redundant FET area) was used to
  quantify the benefit:

  .. list-table:: Redundancy vs. Reliability Trade-off
     :header-rows: 1
     :widths: 25 20 15 15 15 20

     * - Configuration
       - Auxiliary FET Area (S)
       - Fail-Short
       - Fail-Open
       - Total Failure
       - vs. Single FET
     * - Single MOSFET
       - 0.0×
       - 1.0000%
       - 0.0000%
       - 1.0000%
       - Baseline (1×)
     * - 2S2P array
       - 0.0× (no driver)
       - 0.0199%
       - 0.0396%
       - 0.0592%
       - 16.9× safer
     * - 2S2P array
       - 0.5× FET area
       - 0.0199%
       - 0.0614%
       - 0.0813%
       - 12.3× safer
     * - 2S2P array
       - 1.0× FET area
       - 0.0199%
       - 0.0880%
       - 0.1079%
       - 9.3× safer
     * - 2S2P array
       - 2.0× FET area
       - 0.0199%
       - 0.1568%
       - 0.1767%
       - 5.7× safer
     * - 2S2P array
       - 5.0× FET area
       - 0.0199%
       - 0.4603%
       - 0.4802%
       - 2.1× safer

  Every redundant configuration beats a single FET; larger auxiliary FETs trade a lower
  fail-short probability improvement for a *higher* fail-open probability (more silicon area
  means more that can fail open), so there is a diminishing-returns point rather than "bigger
  is always safer." The design does not lock in one specific auxiliary-area ratio from this
  table; it is retained as the sizing tool for the final layout pass.

**Why discrete MOSFETs over integrated dual/quad load-switch ICs.** Integrated switch ICs
with active current limiting, or with any mismatch in their internal :math:`R_{DS(on)}`, do not
share current equally when placed in parallel: one IC ends up carrying the majority of the
current, hits its own thermal or overcurrent limit, shuts itself down, and dumps the entire
load onto the remaining parallel IC — a cascading trip. Stacking two integrated low-side load
switches in series is also awkward: the "ground" pin of the top switch sits on top of the
bottom switch's :math:`V_{DS}` drop, which disturbs the top switch's internal control
thresholds, charge pump, and UVLO detection. Discrete, individually-biased MOSFETs avoid both
problems.

Protection Components
^^^^^^^^^^^^^^^^^^^^^^

.. warning::

   These values were derived while the EPC2204 GaN FET was still the leading candidate (its
   6.0 V absolute max gate rating specifically motivates the 5.1 V Zener clamp below), before
   the MOSFET-vs-GaN decision above was finalized. The pull-down and flyback-diode choices are
   generic and still apply, but the Zener clamp voltage should be re-checked against the
   BUK9Y4R8-60E,115's actual gate ratings before schematic capture. See `Open Risks & TBDs`_.

- **22 Ω series gate resistor** (revised from an initial 1 kΩ, which was found to be too high
  for the capacitive SSR gate driver below to adequately drive the MOSFET gates).
- **100 kΩ gate pull-down resistor**: holds the FET reliably OFF whenever the control signal is
  floating, disabled, or the board is initializing. A high value is used specifically so it
  doesn't form a voltage divider that could partially bias the gate, though this also makes it
  more susceptible to acting as an antenna for an SEU-induced spurious turn-on — trace length
  between this resistor and the gate should be minimized on the PCB.
- **BZT52B5V1 5.1 V Zener diode**: clamps :math:`V_{GS}` below the (GaN-era) 6.0 V absolute
  maximum to prevent gate dielectric breakdown.
- **1 µF drain-source snubber capacitor** with a 10 Ω series damping resistor: absorbs
  high-frequency inductive ringing across drain and source during switching transitions.
- **1N5822U Schottky flyback diode**: bypasses reverse inductive load current so the switch
  does not operate in its high-loss third-quadrant reverse-conduction mode.

Capacitive-Isolated Gate Driver — TPSI3050-Q1
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

:Datasheet: search manufacturer part TPSI3050-Q1 (isolated capacitive gate driver)

Because the 8-FET array stacks transistors in series, several of the gate nodes are floating —
referenced to a source that itself sits at an elevated, non-ground potential and drifts as the
switch state changes. Biasing a floating gate directly from a 3.3 V rail referenced to system
ground doesn't work: the source (and therefore the required gate voltage) drifts to an
unpredictable level with no defined DC reference, since it's only capacitively coupled to
system ground rather than tied to it.

An isolator solves this by referencing the gate-drive voltage directly to the floating source
itself, so the gate-to-source potential difference stays constant regardless of where the
source drifts to. Two isolation technologies were compared:

- **Optocoupling** — rejected: optical coupling paths degrade under total ionizing dose in
  LEO, which is exactly the environment this part needs to survive in.
- **Silicon-dioxide capacitive isolation** — **selected**. It avoids the TID-driven optical
  degradation of an optocoupler; it generates the ~10 V :math:`V_{GS}` needed on the secondary
  side locally (via an internal charge pump), avoiding a separate isolated DC-DC converter per
  stacked tier; and it draws zero secondary-side current when disabled, which matters for
  meeting the strict pre-deployment launch-isolation requirement.

**TPSI3050-Q1** was chosen specifically because it provides two isolated power rails from one
package with no extra signal accommodation needed, and because — unlike a general-purpose
isolator, which would still need an external converter to generate a high enough voltage to
bias a FET gate — it is purpose-built to drive MOSFETs directly via its integrated charge pump.
Using this driver instead of building the equivalent function from discrete parts reduces
component count by roughly an order of magnitude.

**Configuration choices:**

- **Three-wire mode** (not two-wire): the driver's primary :math:`V_{DD}` pin is powered from
  the board's steady 3.3 V rail, leaving the ``EN`` pin purely as a logic control line. This
  lets the internal oscillator/charge pump transfer maximum energy across the capacitive
  barrier to charge the MOSFET gate capacitance cleanly. Two-wire mode would instead source
  power from the ``EN`` line itself — a line not meant to be loaded — and gives less
  deterministic, slower behaviour. Since the 3.3 V rail is already present on the board,
  three-wire mode adds no extra components.
- **Standard Enable mode** (not One-Shot Enable): the IC outputs power whenever ``EN`` is high,
  matching the existing timer-driven enable signal directly. One-Shot Enable would require a
  latch at each MOSFET, adding components and failure modes for no benefit here.

**Component sizing** (one driver drives 2 MOSFETs in this design):

.. math::

   Q_{LOAD} = 2 \times Q_{G(tot)} = 2 \times 54.8\text{ nC} = 109.6\text{ nC}

Using TI's recommended sizing method (:math:`n = 1.0`, :math:`C_{DIV1} = C_{DIV2}`, maximum
allowable droop :math:`\Delta V = 0.5\text{ V}`):

.. math::

   C_{DIV1} = C_{DIV2} = \frac{1+1}{1} \times \frac{Q_{LOAD}}{\Delta V}
   = 2 \times \frac{109.6\text{ nC}}{0.5\text{ V}} = 438.4\text{ nF}

Derating 30–50% for DC bias (these capacitors sit across ~10 V on the secondary side) and
temperature variation in orbit, then applying a ×2 safety factor, gives a derated target of
~876.8 nF. **Selected: 1.0 µF, 50 V rating, X7R dielectric, 0805 (603 if space allows)** for
both :math:`C_{DIV1}` and :math:`C_{DIV2}` — comfortably above the 438 nF floor without going
so large that it risks leaving the isolator in undervoltage lockout (UVLO) during switch-on.

- :math:`R_{PXFR} = 7.32\text{ k}\Omega` (per the TPSI305x design calculator): since this is a
  static DC application (:math:`f_{MAX} \approx 0\text{ Hz}`), the minimum power-transfer
  setting is more than sufficient to hold the gates permanently ON, delivering
  :math:`I_{OUT} = 0.37\text{ mA}`.
- :math:`C_{VDDP}`: **1.0 µF in parallel with 100 nF** on the primary-side supply decoupling
  (VDDP to VSSP), per the datasheet's recommendation — the 1 µF acts as a ripple reservoir
  (the IC does not draw steady DC current) and the 100 nF handles high-frequency filtering.
- **Gate driver output resistor** :math:`R_G`: a single DC output needs only a simple
  low-pass filter against the MOSFET's gate capacitance (:math:`C_{ISS}`) and PCB trace
  inductance, which would otherwise ring at turn-on/turn-off and produce high-:math:`dV/dt`
  spikes on :math:`V_{GS}`. A **10–22 Ω** resistor critically damps this. Dedicated series
  resistors (:math:`R_{G1}`, :math:`R_{G2}`) are placed individually at each gate rather than
  one shared resistor at the driver's output pin, so that an internal gate-oxide breakdown in
  one MOSFET cannot directly short out the gate-drive signal feeding its parallel-leg partner.


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
       factory-fixed 200 ms/1.6 s timing windows. The ``-25`` suffix trips at ~2.25 V — a
       fairly loose margin for supervising a 3.3 V rail (a ``-30``/``-33`` suffix, tripping
       ~2.7–3.0 V, would catch a sagging 3.3 V rail earlier), addressed below by intentionally
       setting the MCU's own internal brownout threshold lower still.

**Manual reset:** ``MR`` uses a pull-down solder jumper (as on the MPPT board) in place of a
physical switch, with a standard 10 kΩ pull-up so ``MR`` is not randomly triggered.

**Reset-line network (revised 2026-09-05).** An earlier decision to omit any component between
the supervisor's ``RESET`` output and the MCU's ``NRST`` pin (reasoning: with the internal BOR0
threshold set below the supervisor's ~2.25 V trip point, there is no contention to arbitrate,
so a bare push-pull connection is the cleanest, fastest transition) was voided in favour of an
AC-coupled reset network, once it was recognized that this left no protection against the
supervisor IC itself failing and holding ``NRST`` low forever:

- A **1 µF series capacitor** in a high-pass configuration between ``RESET`` and ``NRST``
  ensures a stuck-low fault on the supervisor's output cannot hold the MCU in reset
  indefinitely — only a genuine edge (a real reset event) passes through.
- A **dual Schottky clamp** across the coupling node protects against the positive and
  negative voltage transients produced when that capacitor charges/discharges.
- A **100 Ω resistor** sits between the ground-referenced Schottky and ``NRST`` to limit
  current into the MCU if that diode fails short; a higher value was avoided because the
  resulting voltage drop would degrade the Schottky's own clamping performance.

.. list-table:: Reset Network Failure Modes
   :header-rows: 1
   :widths: 20 15 30 35

   * - Failed Component
     - Failure Mode
     - MCU Operational State
     - System Safety Result
   * - :math:`C_{series}`
     - Open
     - MCU runs normally
     - Safe (reset disabled)
   * - :math:`C_{series}`
     - Short
     - MCU runs normally (until driver fails)
     - Vulnerable to DC lockup (same exposure as before this change)
   * - :math:`R_{pullup}`
     - Open
     - MCU unstable / random reboots
     - Degraded, but no worse than the pre-existing exposure
   * - D1 (upper Schottky)
     - Short
     - MCU runs normally
     - Safe (reset disabled)
   * - D2 (lower Schottky)
     - Short
     - MCU trapped in perpetual reset
     - Increased temperature; the 100 Ω resistor limits the resulting current

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
primary programming header is unavailable or malfunctioning during bring-up testing. This, however, is likely
to be removed in order to implement the signals between the OBC and this Battery Board.

GPIO / Pin Budget Pressure (Open)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The second e-Fuse instance and the new interboard reset/failover architecture together add a
significant number of new signals that did not exist when the pinout table below was last
finalized:

- 5× individual e-Fuse ``EN`` lines (direct GPIO, not multiplexed — see
  `Diagnostics, Current Sense, and MCU Pin Budget`_)
- TCA9534 I2C GPIO expander address/interrupt lines
- ``SN74LVC1G3157`` current-sense mux select line
- ``RST_D'OBC`` (input, resets this MCU on OBC's command)
- ``BLK_D'OBC`` (Timer Input Capture peripheral, reads OBC's block/heartbeat signal)
- ``BLK_D'BB`` (standard GPIO output, drives this board's block/heartbeat signal to OBC)
- ``PRE_RESET_WARN`` (output, asserted low briefly as part of the BLOCK handshake — see
  `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_)
- ``MCU1_HEALTHY`` square-wave heartbeat output (feeds the discrete detector circuit in the
  same section, not a digital GPIO read by another device)

None of these have an assigned pin in the table below yet. See `Open Risks & TBDs`_.

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
     - Locked; input mode, no pull — fault flag from e-Fuse. Now shared conceptually across
       two e-Fuse ICs; see `GPIO / Pin Budget Pressure (Open)`_.
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
     - **Superseded.** ``BATT_INT``/``EPS_INT`` were removed by design decision (issue #156);
       this pin is free to reassign to one of the new interboard signals above. See
       `PC104 Bus Connector`_.
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
   charger timing and now also the TCA9534 e-Fuse diagnostics expander. Both peripherals are on
   dedicated pins with no address-based multiplexing required for the fuel gauges, and the
   part's two native FDCAN controllers (``FDCAN1``, ``FDCAN2``) replace the previous "no CAN
   peripheral" limitation outright — see `CAN Transceiver — TCAN334GDCNT`_.

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
- NVIC priority for ``EXTI8`` (``BATT_INT``, pending reassignment) relative to other enabled
  interrupts.


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

PC104 Bus Connector
-------------------

The PC104 stackthrough connector (``J?``) connects the EPS Battery Board to the rest of the
satellite subsystems. It carries both regulated and unregulated voltage buses, I2C telemetry,
and control signals.


.. note::

   **Superseded (2026-09-04): ``EPS_INT`` and ``BATT_INT`` removed.** These two discrete
   interrupt nets — previously resolved (issue #141) as, respectively, an OBC-driven hard-reset
   line into the watchdog timer's ``RST`` input, and a BMS-MCU-driven interrupt notifying OBC of
   a battery emergency — were deliberately **removed from the design** (issue #156) rather than
   kept. Reasoning:

   - Each discrete line costs a connector pin, routing trace, and ESD protection array, and a
     board-to-board harness run acts as an antenna: EMI or single-event transients can flood
     the receiving MCU with spurious interrupt requests, and in an RTOS this risks task
     starvation or deadlock — a concern raised directly in review.
   - Interrupts cause non-determinism issues in the RTOS firmware. The solution for cross-board interrupts would require a much more involved firmware architecture just to mitigate potential critical timing issues.
   - Dual-redundant CAN buses and hardware I2C bus buffers already provide bus-level fault
     tolerance without extra discrete wiring.

   **Replacement architecture:** the EPS/BMS now acts as an autonomous secondary supervisor for
   OBC, power-cycling OBC's e-Fuse rail if CAN heartbeats stop arriving, backed by a discrete
   ``RST_D'OBC``/``BLK_D'OBC``/``BLK_D'BB`` handshake for cases CAN itself cannot diagnose. See
   `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_ for the full design.

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
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In SOS/safe mode, the following subsystems must remain operational (per advisor recommendation):

- **ADCS** — attitude determination and control
- **EPS** — power management
- **COMMS** — communications

Combined power requirement in SOS mode: ~17 W. This figure was determined in April 2025, and may be subject to change.


----

Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture
----------------------------------------------------------------------

.. note::

   **New section (2026-09-05 through 2026-09-08, issues #219, #220, #221, #223).** This
   architecture replaces the retired ``EPS_INT``/``BATT_INT`` nets (see `PC104 Bus Connector`_)
   with a purpose-built set of mechanisms letting the Battery Board's MCU (MCU1) and OBC's MCU
   (MCU2) each detect the other's failure and, where appropriate, take corrective action —
   including letting OBC take direct control of the e-Fuse outputs if MCU1 or the CAN bus is
   unavailable.

Failure Detection: Three Independent Signals
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Battery Board can assess OBC's health via three largely-independent channels:

1. **CAN heartbeat** — presence/absence of OBC's periodic "alive" message on the CAN bus (see
   ``OBC_ALIVE`` in `CAN Telemetry`_).
2. **The BLOCK handshake** — a dedicated GPIO-level protocol (below), independent of CAN.
3. **Current draw analysis** — comparing OBC's actual current draw against its expected
   operating current (e.g. ~150 mA nominal) via the e-Fuse's per-rail current telemetry; a
   reading far below or above expectation is itself diagnostic.

The design explicitly notes that combining current-draw analysis with the other two checks
introduces a harder verification problem than a simple two-signal (CAN + BLOCK) pass/fail
check — a current reading needs at least a third independent corroborating signal or
statistical treatment before it can be trusted on its own, since a "strange" current reading
could equally indicate a faulty sensor rather than a faulted OBC.

The BLOCK Handshake Protocol
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Three dedicated GPIO signals implement a protocol that is deliberately resistant to being
spoofed by a radiation-induced Single-Event Transient (SET), which can only hold a trace high
or low for nanoseconds to microseconds — far too briefly to satisfy the protocol's timing
windows:

.. list-table:: BLOCK Handshake Signals
   :header-rows: 1
   :widths: 20 45 35

   * - Signal
     - Description
     - Peripheral Type
   * - ``RST_D'OBC``
     - Not an interrupt — a plain active-high GPIO that lets OBC reset MCU1.
     - Standard GPIO output (push-pull/open-drain) on OBC; reset input on MCU1 (see
       `MCU Supervisor — TPS3823-25DBVR`_ for the DTC013UB-based receive circuit).
   * - ``BLK_D'OBC``
     - Block signal: OBC writes, Battery Board reads.
     - Timer input capture on MCU1; standard GPIO output on OBC.
   * - ``BLK_D'BB``
     - Block signal: Battery Board writes, OBC reads.
     - Timer input capture on OBC; standard GPIO output on MCU1.

**Protocol (Battery Board checking OBC):**

1. **Precondition:** MCU1 asserts ``PRE_RESET_WARN`` HIGH (idle) and reads ``BLK_D'OBC``. If
   it is already HIGH, that in itself is a fault (MCU2's line is stuck high) and MCU1 proceeds
   directly to reset. If LOW, the line is clear and the test proceeds.
2. **Trigger:** MCU1 drops ``PRE_RESET_WARN`` LOW for 5 ms.
3. **Postcondition:** MCU2 must pull ``BLK_D'OBC`` HIGH and hold it continuously HIGH for at
   least 10 ms within the response window (~5 ms wait) for MCU1 to treat MCU2 as alive; a
   failure to transition correctly is treated as MCU2 being dead, and MCU1 executes a power
   cycle of OBC's e-Fuse rail.

A low-pass filter on the ``BLK`` GPIO lines filters out sub-millisecond radiation-induced
spikes so a heavy-ion SET cannot be misread as a valid 10 ms response. The same protocol runs
in the opposite direction so that OBC can decide whether to reset MCU1 via ``RST_D'OBC`` if it
concludes MCU1 has failed.

OBC E-Fuse Privilege Levels
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Combining the CAN-bus state, the BLOCK handshake result, and OBC's measured current draw
yields twelve distinct diagnoses, each mapped to a specific e-Fuse control policy for OBC:

.. list-table:: OBC E-Fuse Privilege Matrix
   :header-rows: 1
   :widths: 5 10 12 12 22 14 25

   * - Case
     - CAN Bus
     - BLK Handshake
     - Current Draw
     - System Diagnosis
     - OBC Privilege
     - Action / Policy
   * - 1
     - PASS
     - PASS
     - Normal
     - Fully healthy
     - Full control
     - Normal operation.
   * - 2
     - PASS
     - PASS
     - High (SEL)
     - Downstream latchup/short
     - Restricted (local only)
     - OBC software trips & cycles the specific downstream e-Fuse rail; global state changes
       blocked until cleared.
   * - 3
     - PASS
     - PASS
     - Low (zero)
     - Downstream open-circuit
     - Full control (logged)
     - OBC investigates the subsystem rail; main power bus maintained.
   * - 4
     - PASS
     - FAIL
     - Normal
     - Timer/GPIO peripheral failure
     - Revoked
     - Maintain current e-Fuse states; restrict changes; OBC resets its GPIO peripheral
       internally (MCU1 also signals MCU2 to reset that pin); MCU1 does not power-cycle.
   * - 5
     - PASS
     - FAIL
     - High (SEL)
     - Partial latchup
     - Revoked
     - MCU1 initiates one power cycle; if unresolved, raise a warning flag.
   * - 6
     - PASS
     - FAIL
     - Low (zero)
     - Open-circuit/GPIO rail failure
     - Revoked
     - Investigate the trace; maintain main power bus; no power cycle.
   * - 7
     - FAIL
     - PASS
     - Normal
     - CAN controller/transceiver freeze
     - Revoked
     - Maintain e-Fuse states; toggle the local CAN transceiver power switch if possible.
   * - 8
     - FAIL
     - PASS
     - High (SEL)
     - CAN transceiver latchup + high current
     - Revoked
     - Power-cycle the CAN transceiver rail immediately if possible.
   * - 9
     - FAIL
     - PASS
     - Low (zero)
     - CAN bus disconnect/power loss
     - Revoked
     - Flag the bus failure/open circuit.
   * - 10
     - FAIL
     - FAIL
     - Normal
     - Core CPU lockup (no latchup)
     - Revoked
     - Critical: revoke e-Fuses; MCU1 power-cycles OBC.
   * - 11
     - FAIL
     - FAIL
     - High (SEL)
     - Hard core latchup (thermal hazard)
     - Revoked
     - Emergency power cycle; if current stays high with no signals, cut power.
   * - 12
     - FAIL
     - FAIL
     - Low (zero)
     - Unpowered / hard brownout
     - Revoked
     - Revoke e-Fuses; execute the power-cycle reset sequence.

In normal operation OBC does not need e-Fuse authority at all — MCU1 retains it. OBC only needs
to take over if *both* CAN buses are unusable or MCU1 itself is dead.

**Delegating authority when MCU1's own command has no effect.** A separate failure mode is
possible even while MCU1, CAN, and OBC are all nominally healthy: MCU1 issues a disable command
to an e-Fuse rail, but current keeps flowing — for example because one ideal diode controlling the eFuse's EN pin has failed
short while OBC is independently holding that same node high, forcing the other ideal diode
into reverse and making MCU1's local command ineffective. MCU1 detects this by polling the
e-Fuse's current telemetry after issuing the disable command:

- If current continues to flow, MCU1 hands authority for that rail to OBC, which immediately
  re-asserts the disable command.
- If current then drops to zero, one ideal diode had failed short but the other remains
  functional and the system survives on the working diode.
- If current remains high even after OBC's attempt, the fault is downstream in the e-Fuse
  itself, or both ideal diodes have failed; if that rail is essential, the two MCUs coordinate
  over CAN so their commanded voltage levels match rather than fight each other.

MCU1_HEALTHY Signal Detector
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A discrete analog circuit — chosen over an IC specifically because discrete passives are far
less vulnerable to a single radiation burst taking out one part — converts an AC heartbeat
generated by MCU1's own firmware into a DC enable signal for a **MAX40200** ideal diode, which
in turn gates whether MCU1 or OBC has authority over the shared e-Fuse ``EN`` node for a given
rail:

- MCU1 outputs a 50%-duty-cycle square wave from within the same execution thread being
  monitored (so a genuine CPU lockup silences it).
- The square wave is rectified through a dual **BAT54S** Schottky pair (2 × :math:`V_F` ≈
  0.3 V drop each) and filtered through a **10 kΩ** bleed resistor with a **2.2 µF** filter
  capacitor (derated up to ~4.7 µF for tolerance/temperature margin in the actual BOM), giving
  a nominal DC level of 3.3 V − 0.6 V = 2.7 V with ~0.2 V of ripple.
- Solving for the discharge time constant against the target ripple gives a nominal heartbeat
  frequency of **~205 Hz**.
- If MCU1 freezes (0 Hz output), the filter capacitor discharges through the bleed resistor
  with a time constant :math:`\tau = R_L C_2 = 15\text{k}\Omega \times 2.2\ \mu\text{F}
  \approx 33\text{ ms}`; solving :math:`V(t) = V_0 e^{-t/\tau}` from the nominal 2.7 V down to
  the MAX40200's 0.6 V disable threshold gives a **time-to-disable of ~49.6 ms** after MCU1
  stops toggling — i.e. OBC can gain e-Fuse authority within about 50 ms of MCU1 going silent.
- **MAX40200** was selected as the ideal-diode part specifically because its enable pin can
  block current from either side and has a low 1.2 V logic-HIGH threshold, which lets the
  detector skip an extra BJT buffer stage that would otherwise be needed to boost the rectified
  signal up to a full 3.3 V logic level — saving components and an additional failure point.

**Topology choice: ideal diode over mux or logic-gate OR-ing.** Three approaches for letting
either MCU drive a shared e-Fuse ``EN`` node were compared:

.. list-table:: EN-Node Arbitration Options
   :header-rows: 1
   :widths: 30 40 30

   * - Approach
     - Risk
     - Severity
   * - Decentralized mini-mux (ISL43210/3157-class)
     - High single-point risk per rail — a silicon short or latch-up inside the mux locks or
       grounds that channel, disabling *both* MCUs' control of it.
     - Medium (localized to 1 of 5 rails)
   * - Active OR-ing / ideal diodes (selected)
     - Lowest overall risk; more passive parts means a slightly higher passive-assembly
       failure rate, but no single active IC failure can take the rail down.
     - Very low — a redundant path always remains
   * - Dual logic gates + series diodes
     - Diode forward-voltage drop (300–500 mV) reduces logic drive margin, risking erratic
       e-Fuse triggering at temperature extremes.
     - Medium-high

**What happens if an ideal diode itself fails.** The worst case is the input voltage shorting
and holding the downstream FET active; this is not immediately destructive if both MCUs remain
functional, since they must simply diagnose the broken diode and delegate control of that line
to whichever MCU's command path the broken diode has left intact (per the failover procedure
above). For the MCU1_HEALTHY signal specifically, forcing the node to a false logic-LOW would
require sinking more current than MCU1's own GPIO output buffer can source (~20–25 mA); because
the far side of the MAX40200 sees only another 3.3 V GPIO or the e-Fuse's 10 kΩ pull-down, there
is no strong path to ground available even if the ideal diode's internal comparator itself is
damaged by radiation — a heavy-ion strike is far more likely to break down the diode's FET
drain-source junction than its comparator, and even a comparator fault would only lock the
signal high or low (a state the MCUs can work around), not force a short.

MOSFET Redundancy (General Policy)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note::

   Issue #223, closed 2026-09-07, is a **board-wide hardening policy** distinct from (though
   philosophically related to) the bespoke 8-transistor array adopted specifically for the
   low-side inhibit (`Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)`_). Where
   this policy and the low-side inhibit's own analysis apply to the same physical switch, the
   more detailed low-side-inhibit-specific analysis should be treated as authoritative; where a
   MOSFET switch elsewhere in the design has not yet had its own bespoke redundancy analysis,
   this general policy is the current baseline.

Radiation-induced MOSFET failures are most commonly *short* failures (thermal overload, ESD,
Single-Event Gate Rupture, or electrical overstress melting the internal silicon or punching a
filament through the gate oxide or drain-source junction). Adding a second MOSFET in series
after any single critical MOSFET switch substantially reduces the probability that a single
radiation-induced short takes down that switch. The trade-off is that each additional series
MOSFET linearly increases both the open-circuit failure probability and :math:`R_{DS(on)}`
(and therefore heat). **Two MOSFETs in series is the current baseline** for switches not
otherwise covered by a bespoke analysis; a thermal analysis and the first PCB prototype should
be completed before deciding whether to add more.

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
     - Reverse-blocking diode → E-Fuse ``IN`` (×2 instances)
     - Power
     - Main battery bus. 2× parallel 1N5822U ESCC Schottky diodes provide series
       reverse-current blocking (TI Method 1) ahead of each e-Fuse. MOSFETs in the main path
       must be rated ≥ 2× battery voltage due to spikes from Electrodynamic Tether deployment.
   * - Pack-level fuses
     - Battery pack positive output header (×2, one per 2S2P pack)
     - Power
     - Asymmetric time-lag ceramic fuses (30 A) replacing the earlier per-cell PPTC scheme —
       see `Pack-Level Fusing`_.
   * - E-Fuse split outputs
     - ``E_FUSE_COMMS`` / ``E_FUSE_SBAND`` / ``E_FUSE_OBC`` / ``E_FUSE_PAYLOAD`` /
       ``E_FUSE_MPPT`` → PC104 bus
     - Power
     - Five independently current-limited raw battery voltage feeds built from 8 total
       channels across two e-Fuse instances. Replaces the former ``PCM_IN``/``BCR_OUT`` path
       now that PCM has moved to the MPPT/PDB.
   * - I2C1 / I2C2
     - STM32 ↔ BQ28Z610 ×2 (fuel gauges), charger timing, TCA9534 e-Fuse diagnostics expander
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
     - Stackthrough connector; carries the split e-Fuse feeds, I2C, CAN telemetry, and the
       interboard reset/handshake signals below.
   * - ``EN_D1``
     - E-Fuse ``EN`` lines (via SN54SC6T06-SEP inverter), one inverter package per e-Fuse
     - GPIO
     - Hardware launch-inhibit signal, ANDed (pending gate-topology confirmation — see
       `Open Risks & TBDs`_) from watchdog timer + deployment timer. Coexists with 5
       individual per-rail MCU ``EN`` GPIOs added for firmware fault handling; the exact way
       these combine at the schematic level is not yet finalized.
   * - ``EN_D3``
     - Low-side inhibit gate driver enable (TPSI3050-Q1)
     - GPIO
     - Deployment timer output. Enables the 8-transistor low-side inhibit array post-deployment.
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
     - ``DIAG_EN``/``CS``/``SEL``/``SEH`` → TCA9534 (SEL/SEH/FAULT) / SN74LVC1G3157 (CS) →
       STM32 GPIO/I2C/ADC
     - Data
     - Per-rail fault status and current sense, relayed to OBC over CAN. See
       `Diagnostics, Current Sense, and MCU Pin Budget`_.
   * - ``RST_D'OBC`` / ``BLK_D'OBC`` / ``BLK_D'BB``
     - PC104 ↔ OBC
     - GPIO
     - Interboard reset and health-handshake signals — see
       `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_. Replaces the
       retired ``EPS_INT``/``BATT_INT`` nets.
   * - ``MCU1_HEALTHY``
     - Discrete rectifier/filter network → MAX40200 ideal-diode ``EN``
     - Analog / GPIO
     - Lets OBC take over e-Fuse ``EN`` authority if MCU1's heartbeat stops. See
       `MCU1_HEALTHY Signal Detector`_.

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
- **1 µF flex-termination MLCC + JANTXV 1N5806/1N5806U rectifier** on each e-Fuse rail output
  to clamp positive/negative inductive transients from fault trips, load switching, and
  cosmic-ray SETs — see `Output Transient Protection`_ (the negative-spike clamp diode was
  changed from a 1N5822U Schottky to the 1N5806 on 2026-09-06 for better high-temperature
  leakage and TID/SEE characterization).
- **4.7 kΩ series isolation resistors** on all e-Fuse digital control lines
  (``EN`` ×5, ``SEL``, ``SEH``, ``DIAG_EN``) to shield the MCU from negative transient spikes.
- **Low-pass filters on the ``BLK_D'OBC``/``BLK_D'BB`` handshake lines**, sized to reject
  sub-millisecond radiation-induced SET spikes while passing the protocol's genuine 10 ms
  hold states — see `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_.
- **AC-coupled (1 µF high-pass) reset lines** on both the local supervisor→``NRST`` path and
  the ``RST_D'OBC``→``NRST`` path, each with its own dual-Schottky clamp, so that neither a
  stuck supervisor output nor a latched-up OBC can hold this board's MCU in reset indefinitely
  — see `MCU Supervisor — TPS3823-25DBVR`_.

.. note::

   The ferrite bead on ``PACK_N`` has strict current limits. Verify that the bead's rated
   current is sufficient for the full battery discharge current before finalising layout.

----

CAN Telemetry
-------------

Now that the MCU has native dual FDCAN (see `Microcontroller — STM32U3B5CIT6`_), the following
data dictionary and polling-rate plan is tentative (2026-08-29) and subject to change with the
OBC subteam.

.. note::

   The interboard reset/health-check signals introduced in
   `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_ (``RST_D'OBC``,
   ``BLK_D'OBC``, ``BLK_D'BB``, ``MCU1_HEALTHY``) are discrete hardware GPIO/analog signals,
   not CAN telemetry items, and are intentionally kept off this bus so they still function if
   CAN itself is one of the things that has failed. ``OBC_ALIVE`` below remains the CAN-side
   heartbeat that the BLOCK handshake backs up.

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

**Battery voltage distribution telemetry** (5 signals; rail count now reflects the 5-rail
e-Fuse architecture — MPPT was not present when this table was first drafted):

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

.. warning::

   ``E_FUSE_MPPT`` is not yet in this table even though it is now a physical rail (see
   `Channel Topology`_) — the CAN data dictionary needs a sixth telemetry row added. See
   `Open Risks & TBDs`_.

Combined, this gives **21 CAN commands** total across both tables (pending the
``E_FUSE_MPPT`` addition above).

----

E-Fuse Fault Handling (Firmware)
----------------------------------

.. note::

   **New section (issue #202, open).** The TPS7H2140-SEP/TPS4H160-Q1 has no native auto-retry
   capability, so this behaviour is implemented entirely in firmware.

Current Sampling for Paralleled Rails
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Because MPPT and Payload each combine multiple 1.35 A channels onto one rail (see
`Channel Topology`_), reading a single rail's total current means summing multiple ``CS``
mux samples rather than reading one value directly:

- **MPPT** (2 channels): set ``SEH=1, SEL=0`` to sample channel 3's current, then
  ``SEH=1, SEL=1`` to sample channel 4's current; sum both ADC readings for total
  :math:`I_{LOAD}`.
- **Payload** (3 channels): sampling sequence not yet defined (**TBD**).

Auto-Retry Latching Sequence
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Rather than try to determine which specific rail faulted from within the interrupt itself
(judged too slow), the design disables everything first and diagnoses afterward:

1. **ISR (hardware interrupt, < 10 µs):**

   a. Drive all ``EN`` GPIOs LOW immediately (both e-Fuse instances, all 5 rails).
   b. Mask the ``/FAULT`` pin's EXTI line, to prevent the ISR from re-firing on itself while
      diagnosis is in progress.
   c. Set a ``Diagnose_Required`` flag and exit the ISR.

2. **Sequential rail ping (main loop / task routine):** iterate through rails 1–5:

   a. Drive that rail's ``EN`` HIGH.
   b. Wait 100 µs.
   c. Read the ``/FAULT`` pin. If LOW (shorted), immediately drive that rail's ``EN`` back LOW
      and start a 5.0 s cooldown timer for it. If HIGH (healthy), leave that rail's ``EN`` HIGH.

3. **Resume:** unmask and clear the ``/FAULT`` EXTI interrupt; normal operation resumes with
   healthy rails ON and the shorted rail held OFF for the 5 s cooldown, after which the
   sequence can repeat if the fault persists.

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
       Eliminates floating ground risk and stacked-1S limitations.
   * - STM32F030F4P6
     - STM32F030C8T6 → **STM32U3B5CIT6**
     - F4P6 → C8T6: two BQ28Z610 ICs share I2C address 0x55; the F4P6 only has one I2C
       peripheral. C8T6 → U3B5CIT6: OBC requires a redundant dual-CAN bus, which the C8T6
       (and the whole F0 family) completely lacks.
   * - Per-cell PPTC fusing (4× at 4.5 A)
     - **Per-pack asymmetric time-lag ceramic fuses** (2× 30 A: Littelfuse 0456030 / Eaton
       CB61F30A)
     - PPTC resistance near the cells risks feeding heat back into the pack in vacuum and can
       false-trip under on-orbit temperature swings; a single pack-level fuse per 2S2P string
       avoids the balancer/gas-gauge measurement error a per-branch fuse would add. See
       `Pack-Level Fusing`_.
   * - No E-Fuse
     - TPS259472ARPWR → TPS7H2140-SEP → **TPS4H160-Q1 (prototype), TPS7H2140-SEP (baseline)**
     - COTS device replaced with a rad-hard SEP-grade part; automotive-grade TPS4H160-Q1
       substituted for the first prototype run on cost alone (~$5 vs. ~$1000/unit), pending a
       final flight-part decision. Also absorbs the TPS24750 high-side-inhibit role.
   * - Single e-Fuse, 4 channels (one per subsystem)
     - **Two e-Fuse instances, 8 channels allocated by rail current need**
     - A fifth raw-battery-voltage rail (MPPT, ~2–3 A) was identified that a single
       quad-channel e-Fuse cannot supply alongside COMMS/S-band/OBC/Payload. See
       `Channel Topology`_.
   * - E-Fuse output negative-spike clamp: 1N5822U Schottky
     - **JANTXV 1N5806/1N5806U ultra-fast silicon rectifier**
     - Better high-temperature reverse-leakage behaviour and characterized TID/SEE
       performance versus a commercial Schottky; the e-Fuse's own internal active clamp makes
       the Schottky's lower :math:`V_F` unnecessary. See `Output Transient Protection`_.
   * - TPS24750 (high-side inhibit)
     - Removed — role absorbed by the e-Fuse
     - COTS, non-radiation-qualified part; redundant once the e-Fuse's ``EN`` gating satisfies
       the same launch-inhibit requirement.
   * - No ideal diodes
     - LM74800-Q1 (×2)
     - Prevent back-feeding between the two 2S2P strings.
   * - No reverse-current blocking at pack output
     - 2× parallel 1N5822U (ESCC Schottky)
     - Series blocking diode (TI Method 1) ahead of each e-Fuse ``IN`` pin; sized for 6 A
       against the 34.8 W July 2026 power budget.
   * - NTJD1155L (low-side inhibit, ±1.3 A max)
     - **8× BUK9Y4R8-60E,115 automotive MOSFETs** (redundant series/parallel array) + TPSI3050-Q1
       capacitive-isolated gate driver
     - Original device could not carry the ~10–12 A full battery discharge current. A GaN
       candidate (EPC2204) was also evaluated and rejected in favor of the silicon MOSFET. See
       `Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)`_.
   * - No series cell balancing IC
     - BQ28Z610 (integrated passive balancing)
     - Prevents individual cell overcharge; extends pack lifespan.
   * - No MCU supervisor
     - TPS3823-25DBVR, later given an AC-coupled reset network (1 µF cap + dual Schottky +
       100 Ω resistor)
     - Hardware reset/brownout supervision independent of firmware; the reset network addition
       prevents a faulted supervisor from holding the MCU in permanent reset. See
       `MCU Supervisor — TPS3823-25DBVR`_.
   * - No CAN transceiver
     - TCAN334GDCNT (×2)
     - Required once the MCU gained native dual FDCAN; converts digital TX/RX to
       differential CAN-H/CAN-L for the primary/redundant OBC bus.
   * - ``EPS_INT`` / ``BATT_INT`` discrete interrupt lines
     - **Removed** — replaced by an autonomous CAN-heartbeat-timeout supervisor role for the
       EPS, plus ``RST_D'OBC``/``BLK_D'OBC``/``BLK_D'BB`` handshake signals
     - The old lines did not give the EPS actual autonomous authority to recover OBC from a
       Single-Event Latchup, and long discrete board-to-board lines raise EMI/RTOS-determinism
       concerns. See `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_.
   * - No OBC/MCU1 e-Fuse failover path
     - MAX40200 ideal-diode arbitration + MCU1_HEALTHY discrete heartbeat detector
     - Lets OBC take over e-Fuse ``EN`` control within ~50 ms if MCU1's heartbeat stops, without
       a single active IC failure being able to take a whole rail down.
   * - e-Fuse diagnostics: implied direct MCU GPIO wiring
     - TCA9534 I2C GPIO expander (SEL/SEH/FAULT) + SN74LVC1G3157 analog mux (CS)
     - Two e-Fuse ICs' worth of diagnostic signals exceed the MCU's remaining free-pin budget;
       the 5 rail ``EN`` lines remain direct GPIOs (safety-critical), while
       lower-consequence diagnostics are multiplexed.

----

Open Risks & TBDs
------------------

.. list-table::
   :header-rows: 1

   * - Risk / TBD
     - Owner
     - Target Resolution
   * - **Automotive-vs-space-grade e-Fuse.** The TPS4H160-Q1 is a cost-driven prototype
       substitute for the rad-hard TPS7H2140-SEP; confirm whether the flight unit reverts to
       the space-grade part.
     - TBD
     - Schematic review
   * - **MCU pin assignment for new signals.** The 5 e-Fuse ``EN`` lines, TCA9534
       address/interrupt pins, ``SN74LVC1G3157`` select line, ``RST_D'OBC``, ``BLK_D'OBC``,
       ``BLK_D'BB``, and ``MCU1_HEALTHY`` output are not yet mapped to specific MCU pins in the
       pinout table.
     - TBD
     - Before CubeMX finalization / layout freeze
   * - **Low-side inhibit protection-component recheck.** The Zener clamp / snubber / flyback
       diode values for the low-side inhibit's gate protection network were derived while the
       EPC2204 GaN FET was still the leading candidate (specifically the 5.1 V Zener, sized
       against GaN's 6.0 V max gate rating); confirm these against the BUK9Y4R8-60E,115's
       actual silicon MOSFET gate ratings.
     - TBD
     - After first PCB prototype
   * - **Second e-Fuse thermal budget.** Simulation shows the two e-Fuse ICs could jointly
       dissipate ~86.6 W if all five rails short simultaneously; verify the PCB copper pour and
       thermal via budget accommodates two ICs' worth of heat rather than one.
     - TBD
     - Before layout freeze
   * - **Pack fuse thermal layout.** The decision to use a single (not paralleled) 30 A
       time-lag fuse per pack relies on copper pour/plane sizing rather than parallel fuses to
       manage dissipation; this pour sizing has not yet been done.
     - TBD
     - Before layout freeze
   * - **MPPT rail current confirmation.** The MPPT board's ~2–3 A raw-battery-voltage need
       (driving the ``E_FUSE_MPPT`` rail and its 2-channel allocation) should be formally
       confirmed with the MPPT subteam rather than treated as a Battery-Board-side estimate.
     - TBD
     - MPPT subteam coordination
   * - **CAN telemetry dictionary gap.** ``E_FUSE_MPPT`` current telemetry is not yet listed in
       the `CAN Telemetry`_ data dictionary, which predates the second e-Fuse/fifth-rail
       decision.
     - TBD
     - Schematic/firmware update
   * - **Payload current-sense sampling sequence undefined.** Unlike MPPT's documented
       2-channel ``SEL``/``SEH`` sampling sequence, Payload's 3-channel sampling sequence for
       `E-Fuse Fault Handling (Firmware)`_ is not yet worked out.
     - TBD
     - Firmware design
   * - **Interboard reset/failover bench verification.** The BLOCK handshake protocol, the
       MCU1_HEALTHY detector's ~50 ms failover time, and the OBC e-Fuse privilege matrix are
       currently a paper design; none of it has been bench-verified yet.
     - TBD
     - Firmware + hardware bring-up
   * - Low-side inhibit (NTJD1155L) replacement — **superseded**; see Component Change Log for
       the current 8-transistor array design. Original risk entry retained for traceability.
     - Resolved
     - N/A
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
   * - MOSFET ratings — all MOSFETs in the main power path must be rated at ≥ 2× battery
       voltage to withstand spikes from Electrodynamic Tether deployment.
     - TBD
     - System-level power budget
   * - BQ28Z610 filter capacitor values (``VC1``, ``VC2``, ``SRP``, ``SRN``) — values not
       yet chosen. Document rationale when selected.
     - TBD
     - Architecture review
   * - What systems remain powered in SOS mode — formal power budget for safe mode not yet
       finalised. Maybe ADCS + EPS + COMMS (17 W).
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
   * - 3.3 V rail current budget — STM32U3B5CIT6 contribution to the connector-level current
       budget (alongside the ~138 µA typical / ~265 µA worst-case LTC6995 ×2 draw) is
       pending; see `3.3V Input Protection and Filtering`_.
     - TBD
     - Before layout freeze

----

Action Items
------------

TBD

----

Traceability (V-Model)
------------------------

Requirements
~~~~~~~~~~~~

TBD

.. req:: Battery pack bus voltage
   :id: REQ_EPS_001
   :status: draft

   The battery pack shall provide a nominal bus voltage of 7.2 V in a 2S Li-Ion
   configuration, with a maximum charge voltage not exceeding 8.4 V.



Design Specifications
~~~~~~~~~~~~~~~~~~~~~~

TBD

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
   :verifies: SPEC_EPS_005

   With deployment timer in the pre-deployment (inhibit) state, verify that no voltage appears
   at any load output. Simulate deployment switch activation and confirm power is enabled
   within the timer's specified delay.

.. test:: Telemetry Accuracy
   :id: TEST_EPS_004
   :verifies: SPEC_EPS_002

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

.. test:: Pack Fuse Asymmetric Clearing
   :id: TEST_EPS_006
   :verifies: SPEC_EPS_003
   :added: 2026-09-08

   Simulate a shorted ideal diode driving a cross-pack loop fault current (80–120 A+) and
   confirm Pack A's fuse clears first (within ~1–3 ms) while Pack B's fuse survives and
   continues to supply the 10.8 A system bus alone. Confirm via SPICE simulation before
   physical destructive testing.

.. test:: Five-Rail E-Fuse Fault Isolation and Auto-Retry
   :id: TEST_EPS_007
   :verifies: SPEC_EPS_004
   :added: 2026-09-08

   Fault-inject a hard short on each of the five e-Fuse rails in turn (with the other four
   healthy) and verify the auto-retry latching sequence (`E-Fuse Fault Handling (Firmware)`_)
   isolates only the faulted rail within its 5 s cooldown, leaving the other four powered.
   Repeat with all five rails shorted simultaneously and verify thermal shutdown does not
   occur before firmware response, per the ~86.6 W combined dissipation estimate in
   `Simulation Findings`_.

.. test:: Low-Side Inhibit Current and Switching
   :id: TEST_EPS_008
   :verifies: SPEC_EPS_009
   :added: 2026-09-08

   Bench-verify the 8-transistor low-side inhibit array conducts the full rated discharge
   current (~10–12 A) with voltage drop within simulation-predicted bounds (~0.084 V), and
   that ``EN_D3`` toggling produces clean, glitch-free switching with the TPSI3050-Q1 driver
   in place (building on the netlist-level SPICE verification in `Simulation Status`_).

.. test:: Interboard BLOCK Handshake and OBC E-Fuse Failover
   :id: TEST_EPS_009
   :verifies: SPEC_EPS_010
   :added: 2026-09-08

   With both MCUs powered and communicating normally, verify Case 1 of the
   `OBC E-Fuse Privilege Levels`_ matrix (full OBC control, normal operation). Then
   individually simulate a CAN failure, a BLOCK handshake failure, and an MCU1 heartbeat
   stoppage, and verify the system reaches the diagnosis and e-Fuse policy specified for the
   corresponding case in each instance, including the ~50 ms MCU1_HEALTHY failover window.


----

Bring-Up & Debug Procedure
----------------------------

#. **Pre-power checks**: Verify no short circuit between ``PACK_P``/``PACK_N`` and GND using
   a multimeter in continuity mode.
#. **Verify pack fuse placement**: Confirm each pack-level time-lag fuse is in series with its
   respective 2S2P pack's output header before connecting the battery pack.
#. **Inhibit state check**: With deployment timer in inhibit state, confirm that ``EN_D1``
   and ``EN_D3`` are logic LOW and no output voltage is present on any load rail, including
   the low-side inhibit's 8-transistor array (verify the TPSI3050-Q1 driver outputs are also
   at 0 V).
#. **Apply power at current limit**: Connect bench supply at 3.3 V, 100 mA current limit.
   Confirm STM32 powers up and crystal oscillator starts (measure PH0/PH1 for 16 MHz clock).
#. **I2C communication**: Scan I2C bus (using STM32 or a logic analyser) and confirm BQ28Z610
   responds at address 0x55 on both I2C peripherals, and confirm the TCA9534 e-Fuse
   diagnostics expander responds at its assigned address.
#. **Deployment timer simulation**: Simulate deployment switch activation. Verify that the
   low-side inhibit and high-side inhibit enable in sequence.
#. **Battery pack connection**: With all protection verified, connect battery pack. Monitor
   bus voltage and confirm it is within expected range (~7.2 V – 8.4 V).
#. **Charge cycle test**: Initiate a charge cycle and verify CC and CV phases transition
   correctly, and that the BQ28Z610 reports state-of-charge progression.
#. **Fault injection**: Force an overvoltage or overcurrent condition on each of the five
   e-Fuse rails and confirm the auto-retry latching sequence
   (`E-Fuse Fault Handling (Firmware)`_) isolates only the faulted rail within its expected
   5 s cooldown window, leaving the other four rails powered.
#. **Interboard handshake test**: With both boards powered and communicating, verify the
   BLOCK handshake protocol correctly reports MCU2 as alive; then simulate an OBC CPU lockup
   (holding ``BLK_D'OBC`` static) and confirm MCU1 declares MCU2 dead and executes the
   expected power-cycle response per the privilege matrix in
   `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_.

----

Errata
------

- No known errata for v0.1–v0.2. Update this section as issues are discovered and accepted
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
:Resolution: Both were replaced by a single TPS7H2140-SEP SEP-grade quad e-Fuse (30 krad(Si)
             TID, SEL-immune to 43 MeV·cm²/mg), which now absorbs both roles. Its channels
             were split (2026-08-28) to give OBC independent per-subsystem telemetry. See
             `E-Fuse — TPS7H2140-SEP / TPS4H160-Q1`_.

[2026-09-02] (Fifth Rail / Second E-Fuse)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: A single quad-channel e-Fuse cannot supply more than four independent rails,
              but a fifth raw-battery-voltage consumer (the MPPT board itself, ~2–3 A) was
              identified after the four-rail architecture was already finalized.
:Why It Failed: The original four-rail split (COMMS/S-band/OBC/Payload, 2026-08-28) did not
                anticipate MPPT needing its own raw feed from this board.
:Resolution: Added a second e-Fuse instance; channels are now allocated per rail by current
             need (Payload ×3, MPPT ×2, OBC/S-band/Comms ×1 each) rather than one channel per
             rail. See `Channel Topology`_.

[2026-09-04] (Low-Side Inhibit Current Rating)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: The NTJD1155L low-side inhibit (±1.3 A max) could not carry the full battery
              discharge current once the requirement grew to ~10 A.
:Why It Failed: The part was sized against an earlier, lower current requirement; the
              requirement grew without the low-side inhibit being re-sized alongside it.
:Resolution: Replaced with a redundant 8-transistor discrete MOSFET array (BUK9Y4R8-60E,115)
             driven by a TPSI3050-Q1 capacitive-isolated gate driver, after a GaN-vs-silicon
             evaluation favored silicon for driver simplicity and mechanical robustness. See
             `Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)`_.

[2026-09-04] (EPS_INT / BATT_INT Retirement)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: The formally-defined EPS_INT/BATT_INT interrupt lines, while functionally
              understood, did not actually give the EPS autonomous authority to recover OBC
              from a Single-Event Latchup, and introduced EMI/RTOS-nondeterminism risk as
              long board-to-board discrete lines.
:Why It Failed: The lines were inherited from a legacy schematic and only formally documented
              (issue #141), not re-evaluated against the mission's actual fault-recovery needs
              until this review.
:Resolution: Removed both nets; replaced with an autonomous CAN-heartbeat-timeout supervisor
             role for the EPS plus the dedicated BLOCK handshake / RST_D'OBC architecture. See
             `Interboard Reset, Health-Check, and OBC E-Fuse Failover Architecture`_.

[2026-09-05] (MCU Reset Line Robustness)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: The earlier decision to omit any component between the TPS3823-25's RESET
              output and NRST left no protection if the supervisor itself failed stuck-low,
              which would hold the MCU in permanent reset with no recovery path.
:Why It Failed: The original reasoning only considered contention between the supervisor and
              the MCU's internal BOR0, not the supervisor's own single-point failure modes.
:Resolution: Added a 1 µF high-pass coupling capacitor, a dual-Schottky transient clamp, and
             a 100 Ω current-limiting resistor between RESET and NRST. See
             `MCU Supervisor — TPS3823-25DBVR`_.

[2026-09-06/07] (Per-Cell PPTC Fusing Retirement)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

:What Failed: A routine request to re-tune the PPTC trip current for the July 2026 power
              budget surfaced a deeper problem: PPTC fuses placed near the cells can feed
              heat back into the pack in vacuum, lowering the cells' thermal-runaway margin,
              and their trip threshold can drift with on-orbit temperature swings.
:Why It Failed: PPTC was originally chosen for its resettability, without fully weighing its
              thermal-feedback risk this close to the battery cells.
:Resolution: Replaced per-cell PPTC fusing with a single non-resettable time-lag ceramic fuse
             per 2S2P pack, sized to a 30 A rating with deliberately mismatched (asymmetric)
             melting-energy characteristics between the two packs. See
             `Pack-Level Fusing`_.

----

References
----------

- BQ28Z610 Datasheet: https://www.ti.com/lit/ds/symlink/bq28z610.pdf
- BQ2970 Datasheet: https://www.ti.com/lit/ds/symlink/bq2970.pdf
- INA219 Datasheet: https://www.ti.com/lit/ds/symlink/ina219.pdf
- TPS63060 Datasheet: https://www.ti.com/lit/ds/symlink/tps63060.pdf
- LTC6995 Datasheet: https://www.analog.com/media/en/technical-documentation/datasheets/LTC6995-6695-1-6695-2.pdf
- TPS24750 Datasheet (superseded, see `Removal of TPS24750`_): https://www.ti.com/lit/ds/symlink/tps24750.pdf
- NTJD1155L Datasheet (superseded low-side inhibit, see Component Change Log):
  https://www.onsemi.com/pdf/datasheet/ntjd1155l-d.pdf
- FDC6318P Datasheet (superseded low-side inhibit candidate, not selected):
  https://www.onsemi.com/pdf/datasheet/fdc6318pd.pdf
- LM74800-Q1 Datasheet: https://www.ti.com/lit/ds/symlink/lm7480-q1.pdf
- TPS259472ARPWR Datasheet (superseded E-Fuse): https://www.digikey.com/en/products/detail/texas-instruments/TPS259472ARPWR/14124020
- TPS7H2140-SEP Datasheet (space-grade E-Fuse baseline): https://www.ti.com/lit/ds/symlink/tps7h2140-sep.pdf
- TPS4H160-Q1 (automotive-grade E-Fuse, current prototype substitute): search manufacturer
  part TPS4H160-Q1
- SN54SC6T06-SEP Datasheet (E-Fuse EN inverter): https://www.ti.com/lit/ds/symlink/sn54sc6t06-sep.pdf
- 1N5822U Datasheet (series input reverse-blocking Schottky): search manufacturer part
  1N5822U, LCC2B package, ESCC-qualified per QPL005
- JANTXV 1N5806/1N5806U Datasheet (e-Fuse output negative-spike clamp, current selection):
  search manufacturer part 1N5806, MIL-PRF-19500/477
- TCA9534 I2C GPIO Expander Datasheet (e-Fuse SEL/SEH/FAULT diagnostics mux): search
  manufacturer part TCA9534, TSSOP-16 package
- SN74LVC1G3157 Analog Mux Datasheet (e-Fuse current-sense mux): search manufacturer part
  SN74LVC1G3157, SOT-SC70 (DCK) package
- NCR18650GA Cell Datasheet: https://actec.dk/media/documents/45D7276ABE10.pdf
- Littelfuse 0456030 Datasheet (Pack A time-lag fuse):
  https://www.littelfuse.com/products/fuses-overcurrent-protection/fuses/surface-mount-fuses/nano-2-fuses/456
- Eaton CB61F30A Datasheet (Pack B time-lag fuse):
  https://www.eaton.com/content/dam/eaton/products/electronic-components/resources/data-sheet/eaton-cb61f-surface-mount-brick-fuses-data-sheet.pdf
- BUK9Y4R8-60E,115 Datasheet (low-side inhibit MOSFET): search manufacturer part
  BUK9Y4R8-60E,115
- EPC2204 / EPC7019G Datasheets (GaN FET candidates, not selected — see
  `Low-Side Inhibit — 8× BUK9Y4R8-60E,115 (Redundant MOSFET Array)`_): search manufacturer
  part EPC2204 / EPC7019G
- IRHF57034 Datasheet (rad-hard Si MOSFET candidate, not selected): search manufacturer part
  IRHF57034
- TPSI3050-Q1 Datasheet (capacitive-isolated MOSFET gate driver): search manufacturer part
  TPSI3050-Q1
- BZT52B5V1 Datasheet (gate Zener clamp): search manufacturer part BZT52B5V1
- MAX40200 Datasheet (ideal diode, OBC e-Fuse failover): https://www.analog.com/media/en/technical-documentation/data-sheets/max40200.pdf
- DTC013UB Datasheet (RST_D'OBC receive BJT, integrated base resistor): search manufacturer
  part DTC013UB, SOT-323 package
- BAT54SW / BAT54S Datasheet (dual Schottky, reset-line and heartbeat-detector clamps): search
  manufacturer part BAT54SW / BAT54S
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
