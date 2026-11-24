---
id: TASK-15
title: Warn when an EP can't run container jobs
status: To Do
assignee: []
created_date: '2026-11-20 21:07'
labels:
  - ep
dependencies: []
priority: medium
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The annex pilot (annex-node.sh) tests the Apptainer bundled with HTCondor, then a system apptainer on PATH. If neither works it starts HTCondor anyway, and the EP silently lacks HasContainer/HasDockerURL: container jobs never match, and the only clue is condor_q -better-analyze on the AP.

Seen on node17 (Ubuntu, kernel.apparmor_restrict_unprivileged_userns = 1): the bundled apptainer fails with 'Could not write info to setgroups: Permission denied' / 'Error while waiting event for user namespace mappings'. The namespace is created but unprivileged, so its ID maps can't be written. docker-ep.sh EPs hit the same failure earlier, at namespace creation, because Docker's default seccomp profile blocks it (seen in a local Docker test).

Fixes all need root on the EP host: install a system Apptainer (its package ships an AppArmor profile; the pilot falls back to it), add an AppArmor profile for the bundled starter, or set the sysctl to 0 host-wide.

Change: run-ep.sh checks before starting the EP whether unprivileged user namespaces work (or a system apptainer exists), and if not prints a warning naming the likely cause (AppArmor restriction, Docker seccomp, user namespaces disabled) and the fixes. Warning only: non-container jobs still run. README troubleshooting entry for 'container jobs never match'. Applies to personal and direct mode. docker-ep.sh opt-in relaxed security profile is out of scope (separate task if wanted).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 run-ep.sh warns before starting the EP when neither the bundled nor a system apptainer can work, naming the likely cause
- [ ] #2 No warning on a host where the pilot reports 'Our apptainer works' or 'System's apptainer works'
- [ ] #3 README troubleshooting covers container jobs that never match, with the root-side fixes
<!-- AC:END -->
