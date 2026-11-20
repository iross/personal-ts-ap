---
id: TASK-1
title: 'Add shell guardrails (prek, shellcheck, shfmt)'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-19 21:49'
updated_date: '2026-11-20 02:00'
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
- [x] #1 prek installed with shellcheck and shfmt hooks covering all *.sh files
- [ ] #2 prek auto-update configured with 7-day cooldown
- [x] #3 prek run is clean on the current tree
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add .pre-commit-config.yaml: pre-commit-hooks (shebang/exec, yaml, EOF, whitespace), shellcheck (koalaman/shellcheck-precommit), shfmt (scop/pre-commit-shfmt, -i 4 -ci), all pinned to commit SHAs.
2. prek install. Cooldown auto-update blocked: installed prek 0.2.21 has no --cooldown-days.
3. Done after TASK-2's deletions: fix findings in surviving scripts, then prek run --all-files clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Hooks pinned: pre-commit-hooks v6.0.0, shellcheck-precommit v0.11.0, pre-commit-shfmt v3.14.1-1. Added set -euo pipefail and quoting to examples/dag_plot/square.sh and examples/hello_world/hello.sh; inline shellcheck source=/dev/null with justification for /etc/os-release in ap/install.sh. AC2 (7-day cooldown) open: prek 0.2.21 lacks --cooldown-days; needs a newer prek.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-11-20 02:00
---
AC2 needs a prek upgrade (0.2.21 has no --cooldown-days). OK to leave open, or should I upgrade prek?
---
<!-- COMMENTS:END -->
