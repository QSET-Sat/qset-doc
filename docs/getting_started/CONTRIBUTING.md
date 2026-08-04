# Contributing to the Design Documentation System

Welcome to the design team! Our documentation system keeps our design decisions transparent, organized, and reliable. We use three core tools to manage our workflow, each with a distinct role and purpose.

---

## Overview

To keep our knowledge structured and maintainable, our team follows a simple core philosophy: **Discussions are for evolving ideas, Sphinx is for settled decisions, and Projects is for active work tracking.** We use **GitHub Discussions** as our open forum for brainstorming, RFCs, and design debates before any commitments are made. Once a decision is finalized, it is documented in our **Sphinx site**, which serves as our official, versioned source of truth for style guides, component specs, design system rules, and onboarding resources. Finally, **GitHub Projects** manages task and ticket tracking to ensure active work, issues, and pull requests are organized and executed efficiently.

---

## Where Do I Start?

Use this simple decision guide whenever you are unsure where to begin:

```
                  What are you trying to do?
                              │
    ┌─────────────────────────┼─────────────────────────┐
    ▼                         ▼                         ▼
I have a new idea      I found a doc error     I want to pick up a task
    │                         │                         │
    ▼                         ▼                         ▼
Start a GitHub Discussion   Is it a quick fix?        Go to GitHub Projects
(RFC / Brainstorming)        ├── Yes ──> Open Issue /      Find unassigned card
                                   Sphinx PR               Assign yourself
                             └── No  ──> Start GitHub      Move card to "In Progress"
                                   Discussion
```

### Quick Decision Guide:

- **"I have a new idea or want to change a design rule"**
  - **Action:** Open a **GitHub Discussion** under the `RFCs` or `Brainstorming` category.
  - **Why:** Discuss options with the team and get consensus before writing formal documentation or building components.

- **"I found an error, typo, or outdated information in the Sphinx docs"**
  - **Minor Fix (typo, broken link, formatting):** Create a **GitHub Project ticket** (or Issue), create a branch, fix the file in Sphinx, and open a PR.
  - **Major Conflict (outdated spec, conflicting rule):** Start a **GitHub Discussion** to re-evaluate the decision first.

- **"I want to pick up an open task or start building"**
  - **Action:** Visit our **GitHub Projects** board.
  - **Why:** Browse the "Backlog" column, pick an unassigned ticket, assign yourself, and move it to "In Progress".

---

## Promotion Rule

Not every discussion belongs in official documentation. An idea is promoted from a **GitHub Discussion** into the official **Sphinx site** only when all promotion criteria are met:

### Promotion Criteria
1. **Decision Reached:** The Discussion has clear team alignment or lead approval, and the Discussion thread is marked as **Answered** or **Resolved**.
2. **Owner Assigned:** A team member is assigned to draft the official Sphinx documentation.
3. **Written Up & Reviewed:** The specification or guide is written up, following our documentation standards, and submitted as a GitHub Pull Request (PR).

### Merge & Approval Rights
- **Review Requirement:** All PRs modifying Sphinx documentation require at least **one approval** from a **Design System Lead** or **Subteam Lead**.
- **Merge Rights:** Only designated **Design System Leads** and **Subteam Leads** have write access to merge PRs into the `main` branch. Self-merging without lead approval is not permitted.

---

## Linking Rule

To maintain full traceability between our discussions, task execution, and final documentation:

> **Mandatory Rule:** Every closed **GitHub Project ticket** or **Issue** that results in a new or updated design decision **MUST** link back to:
> 1. The **GitHub Discussion** where the decision was originally debated and reached.
> 2. The **Sphinx documentation page** (URL or relative path) where the final decision was published.

### Example Ticket Closing Comment:
```text
Closes #142.
- Decision Discussion: https://github.com/QSET-Sat-Launch-1/qset-doc/discussions/45
- Updated Sphinx Specs: docs/standards/color_system.md
```

---

## Staleness Rule

Documentation is only useful if it remains accurate. We use the following mechanisms to prevent Sphinx pages from becoming stale over time:

1. **"Last Verified" Metadata:** Every major component spec and design guideline in Sphinx must include a header tag at the top of the file:
   ```markdown
   > **Last Verified:** 2026-08-04 | **Owner:** @design-lead
   ```
2. **Quarterly Review Cadence:** At the start of each academic term/quarter, the design team performs a documentation audit. Pages not verified within 6 months are flagged for review.
3. **Stale Content Tickets:** If you encounter a Sphinx page that no longer reflects production designs, open a **GitHub Project ticket** tagged `docs-stale` to trigger a review.

---

## Naming & Tagging Conventions

Keeping item titles and tags consistent across all three tools makes cross-referencing effortless.

### 1. GitHub Discussions
- **Categories:** `RFC`, `Brainstorming`, `Q&A`, `Design Specs`
- **Title Format:** `[Category] [Component/Subsystem] Brief Description`
- *Example:* `[RFC] [Buttons] Standardizing Primary Button Active & Hover States`

### 2. GitHub Projects & Issues
- **Labels:** `design-system`, `docs`, `component`, `bug`, `enhancement`
- **Title Format:** `type(scope): concise description`
- *Example:* `docs(colors): add high-contrast theme tokens to Sphinx`

### 3. Sphinx Site (Source Code)
- **Filenames:** Use lowercase with underscores (snake_case).
- *Example:* `docs/standards/button_component.md` or `docs/getting_started/onboarding_guide.md`
- **Section Headers:** Use standard Title Case for `# H1` headers and Sentence case for `## H2` subheadings.

---

## Quick Reference Table

| Tool | Primary Purpose | When to Use It | Tool Owner / Authority |
| :--- | :--- | :--- | :--- |
| **GitHub Discussions** | Open-ended conversations, RFCs, brainstorming, & design debates | When exploring new ideas, proposing changes, or seeking team consensus | **Entire Design Team** (Community-driven) |
| **Sphinx Site** | Official, versioned documentation & single source of truth | When referencing settled design rules, component specs, or onboarding docs | **Design System Leads** & **Subteam Leads** |
| **GitHub Projects** | Task & ticket tracking for active design work | When executing work, tracking progress, assigning tasks, and managing PRs | **Project Managers** & **Sprint Leads** |

---

## Frequently Asked Questions (FAQ)

### Q1: Where should I propose a completely new UI component before drafting any code?
**A:** Start a **GitHub Discussion** under the `RFC` category. Use this space to share wireframes, propose variants, and gather feedback from the team before committing to a final design or documentation page.

### Q2: I found a small typo on a Sphinx documentation page. Do I need to create a Discussion first?
**A:** No! For typos, broken links, or minor layout fixes, skip Discussions. Create a branch, edit the Sphinx page directly, and submit a Pull Request referencing a quick **GitHub Project ticket**.

### Q3: Where do finalized color tokens or component specifications live once agreed upon?
**A:** Finalized specifications live exclusively on the **Sphinx site**. Discussions are un-versioned and can become outdated, so settled decisions must always be promoted to Sphinx.

### Q4: Can I merge my own Pull Request to the Sphinx documentation if I am confident in the changes?
**A:** No. To maintain our Single Source of Truth integrity, all Sphinx PRs require review and approval from a **Design System Lead** or **Subteam Lead** before merging into `main`.
