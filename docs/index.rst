.. raw:: html

   <div class="index-page-hide">

QSET Documentation Hub
=======================

.. raw:: html

   </div>

   <div class="hero-section">
     <span class="hero-badge">📘 QSET Documentation</span>
     <h1>QSET Documentation Hub</h1>
     <p>The central knowledge base for Queen's Space Engineering Team. Browse subteam documentation, design specs, and project resources.</p>
     <div class="stats-row">
       <div class="stat-item"><span class="stat-number">8</span> Subteams</div>
       <div class="stat-item"><span class="stat-number">30+</span> Projects</div>
       <div class="stat-item"><span class="stat-number">📍</span> Queen's University</div>
     </div>
   </div>

Quick Links
-----------

.. raw:: html

   <div class="quick-links">
     <a href="getting_started/contributing.html" class="quick-link">🚀 Getting Started</a>
     <a href="getting_started/team_info.html" class="quick-link">👥 Team Info</a>
     <a href="getting_started/glossary.html" class="quick-link">📖 Glossary</a>
     <a href="genindex.html" class="quick-link">📑 Index</a>
     <a href="search.html" class="quick-link">🔍 Search Docs</a>
   </div>

Getting Started & Onboarding
----------------------------

.. raw:: html

   <p class="section-subtitle">Essential steps for new QSET members to get onboarded and set up their environment.</p>

   <div class="info-grid">
     <div class="info-card">
       <span class="info-icon">🚀</span>
       <h3>1. Join the Team</h3>
       <p>Contact your subteam lead to get added to the team Slack, GitHub organization, and shared drives.</p>
     </div>
     <div class="info-card">
       <span class="info-icon">💻</span>
       <h3>2. Setup Environment</h3>
       <p>Follow our step-by-step <a href="getting_started/contributing.html">First 24 Hours Guide</a> to install Python, clone the repo, and build the docs locally.</p>
     </div>
     <div class="info-card">
       <span class="info-icon">📚</span>
       <h3>3. Learn the Tools</h3>
       <p>Read about our documentation tools (Mermaid, Sphinx-Needs, Sphinx Design) in the <a href="getting_started/contributing.html#using-the-documentation-tools">Contributing Guide</a>.</p>
     </div>
   </div>

Single Source of Truth
----------------------

.. raw:: html

   <p class="section-subtitle">Our philosophy of maintaining a unified, reliable, and version-controlled knowledge base.</p>

   <div class="ssot-box">
     <div class="ssot-content">
       <p>To prevent "brain drain" and ensure seamless handovers between student cohorts, QSET operates under a <strong>Single Source of Truth (SSOT)</strong> philosophy. All system requirements, hardware interfaces, software protocols, and lessons learned must be documented here in this repository, version-controlled, and verified on every commit.</p>
        <ul>
          <li><strong>Requirements Traceability</strong>: Every design decision and test case traces back to a requirement. (See the <a href="standards/v_model_example.html">V-Model Example</a>)</li>
          <li><strong>Docs-as-Code</strong>: Documentation is treated like software: written in plaintext, reviewed via Pull Requests, and built automatically.</li>
          <li><strong>Knowledge Continuity</strong>: Hardware status and lessons learned logs are captured permanently within each subteam folder.</li>
        </ul>
     </div>
   </div>

Subteams
--------

.. raw:: html

   <p class="section-subtitle">Select a subteam to browse its project documentation and resources.</p>

   <div class="subteam-grid">
     <a href="subteams/adcs/index.html" class="subteam-card">
       <span class="card-emoji">🛰️</span>
       <div class="card-title">ADCS</div>
       <div class="card-desc">Attitude Determination & Control — star trackers, reaction wheels, sun sensors, and simulation.</div>
       <span class="card-count">4 projects</span>
     </a>
     <a href="subteams/obc/index.html" class="subteam-card">
       <span class="card-emoji">💻</span>
       <div class="card-title">OBC</div>
       <div class="card-desc">On-Board Computer — flight software, fault detection, data storage, and telemetry protocols.</div>
       <span class="card-count">4 projects</span>
     </a>
     <a href="subteams/ground/index.html" class="subteam-card">
       <span class="card-emoji">📡</span>
       <div class="card-title">Ground Segment</div>
       <div class="card-desc">Ground Station & Operations — tracking, mission control, and link budget analysis.</div>
       <span class="card-count">3 projects</span>
     </a>
     <a href="subteams/comms/index.html" class="subteam-card">
       <span class="card-emoji">📻</span>
       <div class="card-title">Comms</div>
       <div class="card-desc">Communications Subsystem — UHF transceiver, antenna deployment, AX.25 protocol, and RF testing.</div>
       <span class="card-count">4 projects</span>
     </a>
     <a href="subteams/eps/index.html" class="subteam-card">
       <span class="card-emoji">⚡</span>
       <div class="card-title">EPS</div>
       <div class="card-desc">Electrical Power System — solar panels, battery management, power distribution, and budget analysis.</div>
       <span class="card-count">4 projects</span>
     </a>
     <a href="subteams/mech/index.html" class="subteam-card">
       <span class="card-emoji">🔧</span>
       <div class="card-title">Mech</div>
       <div class="card-desc">Mechanical & Structures — chassis design, thermal analysis, vibration testing, and CAD assembly.</div>
       <span class="card-count">4 projects</span>
     </a>
     <a href="subteams/spaceschool/index.html" class="subteam-card">
       <span class="card-emoji">🎓</span>
       <div class="card-title">Space School</div>
       <div class="card-desc">Education & Outreach — curriculum development, school visits, and hands-on workshop materials.</div>
       <span class="card-count">3 projects</span>
     </a>
     <a href="subteams/payload/index.html" class="subteam-card">
       <span class="card-emoji">🔬</span>
       <div class="card-title">Payload</div>
       <div class="card-desc">Scientific Payload — instrument design, data acquisition, science processing, and integration.</div>
       <span class="card-count">4 projects</span>
     </a>
   </div>

.. toctree::
   :maxdepth: 2
   :caption: Getting Started & Onboarding:
   :hidden:
   :glob:

   getting_started/*

.. toctree::
   :maxdepth: 2
   :caption: Single Source of Truth:
   :hidden:
   :glob:

   ssot/*

.. toctree::
   :maxdepth: 2
   :caption: Subteam Documentation:
   :hidden:

   subteams/adcs/index
   subteams/obc/index
   subteams/ground/index
   subteams/comms/index
   subteams/eps/index
   subteams/mech/index
   subteams/spaceschool/index
   subteams/payload/index

.. toctree::
   :maxdepth: 2
   :caption: Engineering Standards:
   :hidden:
   :glob:

   standards/*
