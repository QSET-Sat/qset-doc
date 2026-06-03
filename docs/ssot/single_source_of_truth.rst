Single Source of Truth (SSOT)
=============================

Welcome to the QSET Documentation Hub. This page outlines our philosophy and practices regarding the **Single Source of Truth (SSOT)**.

Why SSOT Matters for QSET
-------------------------

As a student-run space engineering team, we face a unique challenge: members graduate, leads transition, and cohorts change every year. Without a disciplined approach to knowledge management, years of engineering design, testing results, and critical decisions can be lost—a phenomenon known as "brain drain."

To ensure continuity, safety, and operational excellence, QSET mandates that this documentation hub serves as the **Single Source of Truth** for all our projects.

Core Pillars of Our SSOT Philosophy
-----------------------------------

1. Requirements Traceability
^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Every component, interface, and line of flight software must satisfy a system requirement. We use the **V-Model** engineering process to trace:
- **System Requirements** to **Specifications**.
- **Specifications** to **Implementations (Code/CAD)**.
- **Implementations** to **Test Cases**.

For a practical demonstration of how this traceability is built and checked using Sphinx-Needs, see the :doc:`/standards/v_model_example`.

2. Docs-as-Code Workflow
^^^^^^^^^^^^^^^^^^^^^^^^
Documentation is treated with the same rigor as source code.
- **Plaintext**: All docs are written in reStructuredText (``.rst``) or Markdown (``.md``).
- **Version Control**: Every change is tracked via Git and reviewed through Pull Requests.
- **Automated Validation**: Our CI/CD pipeline validates links, checks requirements coverage, and compiles the site automatically on every commit.

To set up your local preview environment, refer to the :doc:`/getting_started/contributing` guide.

3. Knowledge Continuity & Heritage
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Every subteam maintains:
- **Lessons Learned Logs**: Documenting what failed during testing, why it failed, and how it was resolved.
- **Component Status Badges**: Clear visual states for hardware designs (e.g., `Flight Proven`, `Prototype`, `Experimental`).
- **Meeting Minutes and Design Decisions**: Documenting why architectural choices were made.

How to Practice SSOT Daily
--------------------------

- **Do not duplicate info**: Never copy-paste text or data (like pinouts, power budgets, or link budgets) across multiple files. Define it once and reference or link to it.
- **Update docs before code reviews**: A feature is not complete until its documentation and traceability links are updated.
- **Retire outdated files**: If a design changes, archive or delete the old files. Do not keep old, confusing design documents in active folders.
