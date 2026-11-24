---
id: TASK-10
title: Docker option for EPs
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-20 15:57'
updated_date: '2026-11-20 16:06'
labels:
  - ep
  - docker
dependencies: []
priority: high
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Let users run an EP in Docker as easily as ap/docker.sh runs the AP, for EP hosts without a supported distro (e.g. NixOS) or where Docker is simply easier. All EP testing so far ran run-ep.sh inside Docker containers (tests/run-test-ep.sh), yet the README only documented the native path; the user flagged this gap. Ship a docker-ep.sh in the EP bundle that runs the same run-ep.sh in the pinned AlmaLinux 9 image as the invoking user, with no extra privileges.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The EP bundle contains docker-ep.sh; 'TS_AUTHKEY=file:<path> htc-ep/docker-ep.sh' runs an EP with no extra container privileges
- [x] #2 Ctrl-C / docker stop shut the EP down gracefully (withdrawn from the AP, leaves the tailnet)
- [x] #3 Tailscale and HTCondor downloads are cached on the host across runs
- [x] #4 README documents the Docker EP alongside the native one, including the Apptainer limitation
- [ ] #5 Tested on a real Linux host (stacks, x86_64) as well as the laptop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ep/docker-ep.sh: build image htc-ep (pinned almalinux, python3 util-linux which hostname procps-ng; user from build args = caller's name/uid/gid/home); docker run --rm --init, default bridge network, --hostname <host short name>, bundle dir + ~/.cache/htc-ep + ~/.hpc-annex mounted at host paths, key file mounted read-only as file:, run-ep.sh as the command.
2. make-ep-bundle.sh: include docker-ep.sh.
3. README: Docker EP subsection under 'Run an EP' and requirements.
4. Test: laptop and stacks (EP container on the AP host works since the container has its own 127.0.0.1:9618).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
2026-11-20: user ran htc-ep/docker-ep.sh on the macOS laptop (aarch64) against their AP on stacks (ap/docker.sh). EP registered as slot1@Ians-MacBook-Pro; the new test job (~/personal-htcondor/test-job, added in 10e016b) ran on it: 'Hello from Ians-MacBook-Pro (aarch64)'. Still to verify: graceful stop (AC2), cached downloads on rerun (AC3), x86_64 run on stacks (AC5).

After the user stopped the laptop Docker EP: container gone (--rm), AP's condor_status lists no EPs, no htc-ep node on the tailnet. Host caches populated for reuse: ~/.cache/htc-ep/tailscale_1.104.7_arm64 and ~/.hpc-annex/binaries/condor-25.15.15-aarch64_AlmaLinux9-stripped.tar.gz. README documents the Docker EP (requirements + 'In Docker' subsection with the Apptainer limitation). Also added in 10e016b: start.sh writes ~/personal-htcondor/test-job (hello.sub names the annex and accepts x86_64/aarch64); README 'Test job' section. Open: AC5, a Docker EP on stacks (x86_64, real Linux host); needs an auth key file on stacks.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-11-20 16:06
---
Only AC5 left: run htc-ep/docker-ep.sh on stacks next to the AP once a key file is there.
---
<!-- COMMENTS:END -->
