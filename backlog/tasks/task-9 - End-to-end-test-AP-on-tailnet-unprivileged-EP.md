---
id: TASK-9
title: 'End-to-end test: AP on tailnet, unprivileged EP'
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 01:53'
labels:
  - testing
dependencies:
  - TASK-5
  - TASK-6
priority: high
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
AP on a Linux host on the tailnet; EP in an unprivileged container (no NET_ADMIN, no /dev/net/tun) on a different network. Run examples/hello_world and examples/dag_plot (includes container_image job). Also: two concurrent EPs, EP restart, AP restart while EP running. Script the container EP so the test is repeatable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 hello_world and dag_plot complete with output from the EP host
- [ ] #2 Two concurrent EPs both get matched
- [ ] #3 EP recovers after AP restart
- [ ] #4 Ephemeral EP node disappears from tailnet after exit
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike: an aarch64 EP (Mac laptop) needs jobs submitted with requirements = Arch == "aarch64" since the x86_64 AP adds Arch == X86_64 by default. Apptainer inside a default Docker EP fails (no unprivileged user namespaces), so dag_plot's container_image stage needs a different test bed or docker --security-opt.
<!-- SECTION:NOTES:END -->
