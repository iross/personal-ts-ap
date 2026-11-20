---
id: TASK-2
title: Remove Slurm and Open OnDemand components
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:00'
labels:
  - cleanup
dependencies:
  - TASK-1
priority: high
ordinal: 2000
references:
  - https://app.todoist.com/app/task/6j3gCvMMxjMp278v
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Repo becomes tailnet-only; git history is the archive (replace, don't deprecate). Delete: ood/ (both apps), entrypoint.sh, parse_args.sh, annex-ep.sub, update-annex-collector.sh, update-view.sh, wait-for-lock.py, root install.sh (OOD installer), INSTALL.md, ood-plan.md, docs/*.png OOD screenshots. Replace the ap -> ood/personal_condor_system/template symlink with a real ap/ directory holding install.sh, start.sh, 11-ap-annex.conf. Keep examples/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 No sbatch/srun/SLURM_*/OOD references remain (rg -i 'slurm|sbatch|srun|ondemand' only hits hpc.slurm mentions in docs)
- [x] #2 ap/ is a real directory, not a symlink
- [x] #3 Slurm sections removed from notes.md and README.md (full rewrite is a later task)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the ap symlink with a real ap/ dir holding install.sh, start.sh, 11-ap-annex.conf (git mv from ood/personal_condor_system/template).
2. git rm: ood/, root install.sh, INSTALL.md, ood-plan.md, docs/*.png.
3. Strip Slurm/OOD sections from notes.md and README.md, leaving short placeholders for TASK-8; fix Slurm references in remaining comments of ap/ scripts minimally (full rework is TASK-4/5).
4. rg check for slurm/sbatch/srun/ondemand.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Removed 27 tracked files (ood/, entrypoint.sh, parse_args.sh, annex-ep.sub, update-annex-collector.sh, update-view.sh, wait-for-lock.py, root install.sh, INSTALL.md, ood-plan.md, docs/*.png). ap/ is now a real directory (install.sh, start.sh, 11-ap-annex.conf moved with history). examples/hello_world was a symlink into ood/; replaced with a real directory. Removed dead code that only entrypoint.sh used: start.sh annex-ready marker, install.sh 15-ap-lock.conf. notes.md trimmed to still-true sections + updated token note; README is a short placeholder until TASK-8.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Repo is Slurm/OOD-free: ap/ holds install.sh, start.sh, 11-ap-annex.conf; examples/ are real dirs. Verified: rg -i 'slurm|sbatch|srun|ondemand|OOD' finds nothing outside backlog/; prek run --all-files clean.
<!-- SECTION:FINAL_SUMMARY:END -->
