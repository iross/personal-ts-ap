---
id: TASK-9
title: 'End-to-end test: AP on tailnet, unprivileged EP'
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:59'
labels:
  - testing
dependencies:
  - TASK-5
  - TASK-6
references:
  - 'https://app.todoist.com/app/task/6j3gCvMMxjMp278v'
priority: high
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
End-to-end networking and lifecycle test of the tailnet AP and unprivileged EPs. AP: stacks (via ap/docker.sh). EPs: containers on another machine with the tailnet range blocked and an unprivileged user, so the kernel cannot reach the tailnet (each container has its own network namespace, so several act as separate hosts). Script the EP container so the test is repeatable. Out of scope (user decision 2026-11-20): examples/dag_plot, which exercises Apptainer on the AP and EPs rather than the tailnet setup; the README notes it is untested here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 hello_world completes with output from the EP host
- [x] #2 Two EPs on different hosts connect to the same AP at once and both run jobs
- [x] #3 A running EP reconnects after the AP restarts, and runs jobs submitted afterwards
- [x] #4 An EP that exits leaves the tailnet and is withdrawn from the AP
- [x] #5 The EP test container is scripted in the repo so the test can be rerun
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Script the EP test container (tests/run-test-ep.sh): pinned AlmaLinux image, 100.64/10 blocked, non-root user via setpriv, run-ep.sh as PID 1.
2. Two EPs (htc-test-ep1/2) against the AP on stacks; one hello_world job pinned to each.
3. Restart the AP with both EPs running; check they reappear and a new job runs.
4. Stop both EPs; check withdrawal from the AP and the tailnet.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike: an aarch64 EP (Mac laptop) needs jobs submitted with requirements = Arch == "aarch64" since the x86_64 AP adds Arch == X86_64 by default. Apptainer inside a default Docker EP fails (no unprivileged user namespaces), so dag_plot's container_image stage needs a different test bed or docker --security-opt.

From README review: examples/dag_plot/mksif.sub has no queue statement; check whether condor_submit/DAGMan queues it. mksif needs Apptainer on the AP host (not in the Docker AP); plot needs Apptainer-capable EPs.

Results (AP on stacks via ap/docker.sh, EPs as laptop containers, 2026-11-20): both EPs registered; jobs 7 and 8 ran concurrently on htc-test-ep1 and htc-test-ep2. AP stopped 02:57:23, back up 02:57:32, both EPs back in the collector by 02:57:37; job 9 submitted afterwards ran on htc-test-ep2. docker stop on both EPs: each logged 'Stopping HTCondor' and 'Leaving the tailnet'; neither listed on the AP or the tailnet afterwards. dag_plot dropped from scope by the user (exercises Apptainer, not the tailnet setup); README says it is untested here.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Verified the tailnet setup end to end with two unprivileged EPs (containers that cannot route to the tailnet) against the AP on stacks: concurrent jobs on both EPs, reconnection within seconds of an AP restart, and clean withdrawal from the AP and tailnet on stop. Added tests/run-test-ep.sh to rerun this.
<!-- SECTION:FINAL_SUMMARY:END -->
