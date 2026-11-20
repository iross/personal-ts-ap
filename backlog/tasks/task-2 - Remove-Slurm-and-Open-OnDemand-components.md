---
id: TASK-2
title: Remove Slurm and Open OnDemand components
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
labels:
  - cleanup
dependencies:
  - TASK-1
priority: high
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Repo becomes tailnet-only; git history is the archive (replace, don't deprecate). Delete: ood/ (both apps), entrypoint.sh, parse_args.sh, annex-ep.sub, update-annex-collector.sh, update-view.sh, wait-for-lock.py, root install.sh (OOD installer), INSTALL.md, ood-plan.md, docs/*.png OOD screenshots. Replace the ap -> ood/personal_condor_system/template symlink with a real ap/ directory holding install.sh, start.sh, 11-ap-annex.conf. Keep examples/.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 No sbatch/srun/SLURM_*/OOD references remain (rg -i 'slurm|sbatch|srun|ondemand' only hits hpc.slurm mentions in docs)
- [ ] #2 ap/ is a real directory, not a symlink
- [ ] #3 Slurm sections removed from notes.md and README.md (full rewrite is a later task)
<!-- AC:END -->
