Getting Started & Contributing
==============================

Welcome to the QSET Documentation Hub! This guide will help you set up the documentation locally, learn how to contribute, and understand the "Docs-as-Code" workflow.

The "First 24 Hours" Guide
--------------------------

If you are a new member, follow these steps to get your environment ready:

1. **Install Prerequisites**: Ensure you have Python 3.10+ installed.
2. **Clone the Repository**:
   .. code-block:: bash

      git clone https://github.com/qset/qset_doc.git
      cd qset_doc

3. **Install Dependencies**:
   .. code-block:: bash

      pip install -r requirements.txt

4. **Build the Documentation**:
   .. code-block:: bash

      # On Windows
      .\make.bat serve

   This will build the HTML files and open them in your web browser. Whenever you make a change, re-run this command to see your updates.

Using the Documentation Tools
-----------------------------

We use several Sphinx extensions to make our documentation interactive and professional.

Mermaid Diagrams
^^^^^^^^^^^^^^^^
Use Mermaid to draw flowcharts, state machines, and architectures directly in text.

.. code-block:: rst

   .. mermaid::

      graph TD
         A[Start] --> B{Is it working?};
         B -- Yes --> C[Great!];
         B -- No --> D[Debug];

Sphinx Design (UI Elements)
^^^^^^^^^^^^^^^^^^^^^^^^^^^
Use grids, cards, and tabs to organize content cleanly.

.. code-block:: rst

   .. tab-set::

      .. tab-item:: Windows

         Windows instructions here.

      .. tab-item:: Linux

         Linux instructions here.

Heritage & Continuity
---------------------

As a student team, it's critical to preserve knowledge when members graduate. Please follow these guidelines:

1. **Lessons Learned Logs**: At the end of every project or testing phase, add a "Lessons Learned" section to your subteam's documentation. Document what failed, why it failed, and how you fixed it.
2. **Component Status Badges**: Clearly label hardware designs. Are they `Flight Proven`, `Prototype`, or `Experimental`?
3. **Traceability (The V-Model)**: Ensure every piece of code or hardware traces back to a system requirement. See the :doc:`/standards/v_model_example` for more details.

Adding New Subteam Documentation
--------------------------------

We want adding documentation to be as frictionless as possible. You do not need to edit any configuration or index files to make your new pages appear.

To add documentation for a new project/subsystem:

1. **Locate your subteam's folder** under ``docs/subteams/[subteam_name]/`` (e.g., [docs/subteams/adcs/](file:///c:/Users/Jaron/Downloads/QSET_Doc/docs/subteams/adcs/)).
2. **Create a new file** ending in ``.rst`` (or ``.md``). For example: ``sensor_calibration.rst``.
   * *Tip*: You can copy the design, status badges, Mermaid, and Sphinx-Needs templates from the [Project Template](file:///c:/Users/Jaron/Downloads/QSET_Doc/docs/subteams/project_template.rst) to get started quickly.
3. **Start writing!** The subteam's main index page uses a wildcard glob (``*``) in its table of contents. Your new file will be detected and added to the sidebar automatically the next time you build the site.

Docs-as-Code Workflow
---------------------

1. Create a new branch for your documentation updates.
2. Write your content using reStructuredText (``.rst``) or MyST Markdown (``.md``).
3. Run ``make html`` to verify there are no build errors or broken links.
4. Submit a Pull Request to the ``main`` branch. Our CI/CD pipeline will automatically build and deploy your changes to GitHub Pages once approved.
