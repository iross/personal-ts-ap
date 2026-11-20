---
id: TASK-1
title: 'Add shell guardrails (prek, shellcheck, shfmt)'
status: To Do
assignee: []
created_date: '2026-11-19 21:49'
labels:
  - tooling
dependencies: []
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up automated checks before the rework. All scripts in ap/ and the new EP scripts must pass shellcheck and shfmt and start with set -euo pipefail.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 prek installed with shellcheck and shfmt hooks covering all *.sh files
- [ ] #2 prek auto-update configured with 7-day cooldown
- [ ] #3 prek run is clean on the current tree
<!-- AC:END -->
