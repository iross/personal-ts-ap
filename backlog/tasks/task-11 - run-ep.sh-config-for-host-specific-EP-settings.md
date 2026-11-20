---
id: TASK-11
title: run-ep.sh --config for host-specific EP settings
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-20 17:36'
updated_date: '2026-11-20 17:40'
labels:
  - ep
dependencies: []
priority: medium
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Let the person running an EP add HTCondor config for that host without changing the AP's bundle: run-ep.sh --config <file> appends the file to the EP's annex config before HTCondor starts. First use: node17 has 4 GPUs but only 3 are ours; OFFLINE_MACHINE_RESOURCE_GPUs = GPU-a325ade4 keeps the fourth out of every slot.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 run-ep.sh --config <file> appends the file's settings to the EP config before HTCondor starts
- [x] #2 A missing or unreadable --config file fails fast, before anything is downloaded or the tailnet is joined
- [x] #3 README documents --config with the GPU example and how to verify DetectedGPUs/AssignedGPUs
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Parse --config <file> (absolute path, readable) alongside --help.
2. In prepare_annex, after annex-setup.sh writes 20-annex-pilot-instance, append the file with a header comment (annex-job-setup.sh copies that file into the EP's live config.d).
3. README + usage text.
4. Test in a Linux container with a stub annex (no AP needed): config lands in 20-annex-pilot-instance; missing file errors before downloads.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented run-ep.sh --config (appended to the annex's 20-annex-pilot-instance after annex-setup.sh, which annex-job-setup.sh copies into the EP's config.d) and passed it through ep/docker-ep.sh (mounted read-only at /run/ep-config.conf; empty-array expansion written for macOS bash 3.2). Tested with a stub bundle (no AP): native in a Linux container and via docker-ep.sh on macOS; the file lands after the annex's own settings; a bad path fails before any download. Not yet verified: HTCondor actually offlining the GPU on node17 (check DetectedGPUs vs AssignedGPUs there). Found and fixed while testing: tailscaled's socket lived in the work dir, and a long bundle path exceeded the ~108-byte Unix socket limit ('bind: invalid argument'); it now lives in a mktemp dir under /tmp, removed on exit.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-11-20 17:40
---
Remaining check on node17: condor_status -af Name DetectedGPUs AssignedGPUs shows GPU-a325ade4 detected but not assigned.
---
<!-- COMMENTS:END -->
