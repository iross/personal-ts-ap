---
id: TASK-1
title: 'Add shell guardrails (prek, shellcheck, shfmt)'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:49'
updated_date: '2026-11-20 02:05'
labels:
  - tooling
dependencies: []
priority: high
ordinal: 1000
references:
  - https://app.todoist.com/app/task/6j3gCvMMxjMp278v
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up automated checks before the rework. All scripts in ap/ and the new EP scripts must pass shellcheck and shfmt and start with set -euo pipefail.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 prek installed with shellcheck and shfmt hooks covering all *.sh files
- [x] #2 prek auto-update configured with 7-day cooldown
- [x] #3 prek run is clean on the current tree
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add .pre-commit-config.yaml: pre-commit-hooks (shebang/exec, yaml, EOF, whitespace), shellcheck (koalaman/shellcheck-precommit), shfmt (scop/pre-commit-shfmt, -i 4 -ci), all pinned to commit SHAs.
2. prek install. Upgrade prek (0.2.21 -> 0.5.11 via uv tool) for --cooldown-days; document 'prek update --cooldown-days 7 --freeze' in notes.md (it is a CLI flag, not stored config).
3. Done after TASK-2's deletions: fix findings in surviving scripts, then prek run --all-files clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Hooks pinned: pre-commit-hooks v6.0.0, shellcheck-precommit v0.11.0, pre-commit-shfmt v3.14.1-1. Added set -euo pipefail and quoting to examples/dag_plot/square.sh and examples/hello_world/hello.sh; inline shellcheck source=/dev/null with justification for /etc/os-release in ap/install.sh. AC2 (7-day cooldown) open: prek 0.2.21 lacks --cooldown-days; needs a newer prek.

prek upgraded to 0.5.11 by the user. In 0.5.x the command is 'prek update' (was auto-update). 'prek update --cooldown-days 7 --freeze --dry-run' reports no updates. --freeze keeps SHA pins (without it, update rewrites revs to tag names).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-11-20 02:00
---
AC2 needs a prek upgrade (0.2.21 has no --cooldown-days). OK to leave open, or should I upgrade prek?
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added prek hooks (shellcheck, shfmt, file hygiene) pinned to SHAs; prek run --all-files is clean. Update procedure with 7-day cooldown documented in notes.md.
<!-- SECTION:FINAL_SUMMARY:END -->
