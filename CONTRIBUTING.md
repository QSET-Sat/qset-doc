# Contributing to the Design Documentation System

> 🚀 **Looking for environment setup or the "First 24 Hours" onboarding guide?** Check out the [Getting Started Guide](docs/getting_started/contributing.rst).

This document is mirrored in the Getting Started & Onboarding section at [`docs/getting_started/CONTRIBUTING.md`](docs/getting_started/CONTRIBUTING.md).

Welcome to the QSET team! Our documentation system keeps our design decisions transparent, organized, and reliable. We manage our design knowledge using two primary tools working in tandem: **Sphinx site** and **GitHub Discussions**, with **Pull Requests (PRs)** managing active changes.

---

## Overview

To keep our knowledge structured and maintainable, our team follows a simple core philosophy: **Discussions are for evolving ideas, Sphinx is for settled decisions, and Pull Requests are for active implementation.** We use **GitHub Discussions** as our open forum for brainstorming, interface definitions, meeting minutes, and team announcements. Once a decision or design spec is finalized, it is documented in our **Sphinx site**, which serves as our official, versioned Single Source of Truth (SSOT) for subteam specs, hardware/software interfaces, style guides, and onboarding docs. Finally, **Pull Requests (PRs)** are used to propose, review, and merge active documentation changes into Sphinx.

> **⚠️ IMPORTANT NOTE ON DOCUMENTATION STORAGE:**  
> **Please no longer store important notes locally or in MS Teams! Historically, people have just sent messages to each other, leaving team members unable to find critical documents. Put your documentation in your GitHub repository, or if stored externally, always link to it directly in a GitHub Discussion or on the Sphinx site.**

> **🔔 GETTING ATTENTION & STAYING UPDATED:**  
> - **@ Mention Team Members:** If you want to get someone's attention for a decision, review, or question, **@mention them directly** in your GitHub Discussion post or PR comment (e.g., `@username`).  
> - **Enable GitHub Notifications:** Every team member should **turn on notifications for this GitHub repository** (click **Watch** at the top right of the repo) and **check your notifications frequently** so discussions move forward without delays.

---

## Where Do I Start?

Use this simple decision guide whenever you are unsure where to begin:

```
                  What are you trying to do?
                              │
    ┌─────────────────────────┼─────────────────────────┐
    ▼                         ▼                         ▼
I have a new idea      I found a doc error     I want to propose a change
    │                         │                         │
    ▼                         ▼                         ▼
Start a GitHub Discussion   Is it a quick fix?        Submit a Pull Request
(Design & Brainstorming /   ├── Yes ──> Open a PR     Branch off main
 Integration & Interfaces)  └── No  ──> Start a       Link to Discussion
                                  Discussion          Request Lead Review
```

### Quick Decision Guide:

- **"I have a new idea or want to discuss a subsystem design"**
  - **Action:** Open a **GitHub Discussion** under 💡 `Design & Brainstorming` or 🔧 `Integration & Interfaces`.
  - **Why:** Debate options with the team and build consensus before updating official specs in Sphinx.

- **"I found an error, typo, or outdated spec in the Sphinx docs"**
  - **Minor Fix (typo, broken link, formatting):** Edit the file, create a branch, and open a **Pull Request (PR)** directly.
  - **Major Specification Conflict:** Start a **GitHub Discussion** under 💡 `Design & Brainstorming` or 🔧 `Integration & Interfaces` to re-evaluate the decision first.

- **"I want to publish meeting notes or make a team announcement"**
  - **Action:** Post a **GitHub Discussion** under 🗓️ `Meeting Minutes` or 📣 `Announcements`.

---

## Promotion Rule

Not every discussion thread belongs in official documentation. An idea or specification is promoted from a **GitHub Discussion** into the official **Sphinx site** only when all promotion criteria are met:

### Promotion Criteria
1. **Decision Reached:** The Discussion thread has clear team consensus or subteam lead alignment.
2. **Owner Assigned:** A team member is assigned to draft or update the official Sphinx documentation page.
3. **Written Up & Reviewed:** The specification or guide is written up under the appropriate `docs/` path and submitted as a GitHub Pull Request (PR).

### Merge & Approval Rights
- **Review Requirement:** All PRs modifying Sphinx documentation require at least **one approval** from a **Design Lead** or **Subteam Lead**.
- **Merge Rights:** Only designated **Subteam Leads** and **Documentation Leads** have write access to merge PRs into `main`. Self-merging without lead approval is not permitted.

---

## Linking Rule

To maintain full traceability between our discussions and our version-controlled documentation:

> **Mandatory Rule:** Every **Pull Request (PR)** that implements or updates a design decision **MUST** link back to:
> 1. The **GitHub Discussion** where the decision was debated and reached.
> 2. The **Sphinx documentation page** (relative path or live URL) being added or modified.

### Example PR Description:
```text
Closes Discussion: https://github.com/QSET-Sat/qset-doc/discussions/45
Updates Sphinx Specs: docs/subteams/comms/dsp_icd.rst

Summary of changes:
- Documented the ICD interface between COMMS and DSP board.
- Added pinout table and data packet specification.
```

---

## Staleness Rule

Documentation is only useful if it remains accurate. We use the following mechanisms to keep Sphinx pages accurate over time:

1. **"Last Verified" Metadata:** Major subteam specs and integration pages in Sphinx should include a header block at the top:
   ```rst
   .. note::
      **Last Verified:** 2026-08-04 | **Owner:** @comms-lead
   ```
2. **Review Cadence:** At the start of each term/quarter, subteam leads audit their respective folders under `docs/subteams/`. Pages not verified within 6 months are reviewed.
3. **Outdated Content:** If you notice a Sphinx page that no longer reflects current designs, start a discussion in 🔧 `Integration & Interfaces` or 💡 `Design & Brainstorming` to update it.

---

## Naming & Tagging Conventions

Keeping titles consistent makes discussions and docs easy to search across the entire team.

### 1. GitHub Discussions Categories
When creating a discussion, select the exact matching category:
- 📣 **Announcements** — Team-wide announcements and operational updates.
- 💡 **Design & Brainstorming** — Open-ended design discussions, trade studies, and research.
- 🔧 **Integration & Interfaces** — Interface control documents (ICDs), subsystem connections, and integration calls.
- 🗓️ **Meeting Minutes** — Notes and action items from subteam alignment meetings.
- 🙏 **Q&A** — Questions, technical help requests, and general inquiries.

### 2. GitHub Discussions Title Format
Always prefix discussion titles with the relevant **Subteam Tag** in brackets:

`[SUBTEAM] - Description` or `[SUBTEAM1/SUBTEAM2] - Description`

**Examples from our repository:**
- `[ADCS] - Hardware, Software, and Simulation open-source/research`
- `[OBC/EPS] - Backup power source in case EPS fails`
- `[EPS Meeting] - EPS & Battery / MPPT Alignment Call`
- `[COMMS] - Integration Control Document (ICD) for DSP board`

### 3. Sphinx Site Files & Sections
- **Filenames:** Use lowercase with underscores (`snake_case`) under your subteam folder (e.g., `docs/subteams/comms/dsp_icd.rst`).
- **Section Titles:** Use clear Title Case headers (`===` for H1, `---` for H2).

---

## Quick Reference Table

| Tool / Section | Primary Purpose | When to Use It | Owner / Authority |
| :--- | :--- | :--- | :--- |
| 💡 **Design & Brainstorming** *(Discussions)* | Open-ended design debates, trade studies, & research | Exploring new concepts, proposing subsystem changes | **Entire Team** (Community-driven) |
| 🔧 **Integration & Interfaces** *(Discussions)* | Subsystem interface debates & ICD proposals | Coordinating cross-subteam connections (e.g. OBC/EPS, COMMS/DSP) | **Subteam Leads & System Engineers** |
| 🗓️ **Meeting Minutes** *(Discussions)* | Archival of meeting notes & action items | Documenting decisions and tasks after team/subteam syncs | **Meeting Lead / Note Taker** |
| 📣 **Announcements** *(Discussions)* | Team broadcast messages | Sharing major team milestones, deadlines, or logistics | **Team Execs & Leads** |
| 🙏 **Q&A** *(Discussions)* | Technical questions and help requests | Asking for guidance or clarification on subteam tools/specs | **All Members** |
| 📘 **Sphinx Site** | Versioned Single Source of Truth (SSOT) | Referencing settled specs, component standards, & onboarding | **Subteam Leads & Doc Leads** |
| 🔀 **Pull Requests (PRs)** | Reviewing & merging official doc changes | Submitting new `.rst` / `.md` pages or updates to Sphinx | **PR Author** *(Approve: Leads)* |

---

## Frequently Asked Questions (FAQ)

### Q1: Where should I propose a new subsystem feature or backup power scheme?
**A:** Start a **GitHub Discussion** under 💡 `Design & Brainstorming` (or 🔧 `Integration & Interfaces` if it spans multiple subteams) using the title format `[SUBTEAM] - Topic` (e.g., `[OBC/EPS] - Backup power source in case EPS fails`).

### Q2: How do I document notes from our subteam meeting?
**A:** Post a **GitHub Discussion** under 🗓️ `Meeting Minutes` titled `[SUBTEAM Meeting] - Meeting Name / Date` (e.g., `[EPS Meeting] - EPS & Battery / MPPT Alignment Call`).

### Q3: I found a small typo in a Sphinx document. Do I need to start a Discussion first?
**A:** No! For typos or formatting fixes, edit the file in your branch and submit a **Pull Request (PR)** directly against `main`.

### Q4: Where do settled specifications and ICDs live once agreed upon?
**A:** Settled specifications must be promoted to the **Sphinx site** under `docs/subteams/[subteam_name]/`. Discussions serve as the debate space, but Sphinx is our official version-controlled source of truth.

### Q5: Can I merge my own Pull Request to Sphinx?
**A:** No. All PRs modifying Sphinx documentation require review and approval from at least one **Subteam Lead** or **Documentation Lead** before merging to `main`.
