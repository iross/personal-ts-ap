---
id: TASK-8
title: Rewrite README and notes.md for the tailnet workflow
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:51'
labels:
  - docs
dependencies:
  - TASK-5
  - TASK-6
references:
  - 'https://app.todoist.com/app/task/6j3gCvMMxjMp278v'
priority: medium
ordinal: 8000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
README covers the 4 steps: start AP on a tailnet host, build EP bundle, copy to EP and join tailnet, run EP; plus submitting examples/hello_world and examples/dag_plot. notes.md keeps still-true design notes (daemon name pinning, forced IDToken auth, annex transform) and adds tailnet/forwarder rationale.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 No Slurm/OOD instructions remain
- [x] #2 A new user can follow README end to end
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Rewrite README around the 4-step workflow: requirements (AP native/Docker, EP), start AP, build bundle, run EP, submit jobs (hello_world, dag_plot), tailnet keys/policy, stop/cleanup, troubleshooting.
2. notes.md: add job routing, Docker mode, EP launcher; keep still-true AP notes.
3. Independent read-through against the code; fix what it finds.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
An independent review (subagent, read-only, checked README against every script) found no wrong commands/paths, plus gaps that were fixed: run-ep step order, tagOwners needed before a tagged key, policy tests' deny fails while allow-all is present, key-file example, dag_plot copy note for Docker APs, EP needs bash 4+/sha256sum, Docker AP needs host tailscale CLI and sudo-less docker, CentOS listed, stop/cleanup section (tailscale serve off, work dirs). It also flagged that start.sh had no signal handling: Ctrl-C/docker stop did not reach the backgrounded condor_master. Fixed with an INT/TERM trap that sends SIGTERM and waits; verified docker stop now logs a graceful master shutdown.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
README rewritten for the tailnet workflow (AP native or Docker, EP bundle, keys and grants policy, jobs, cleanup, troubleshooting); notes.md documents routing, Docker mode and the EP launcher. Checked by an independent read against the code; its findings are fixed, including a start.sh signal-handling bug.
<!-- SECTION:FINAL_SUMMARY:END -->
