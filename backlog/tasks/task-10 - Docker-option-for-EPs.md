---
id: TASK-10
title: Docker option for EPs
status: In Progress
assignee:
  - '@claude'
created_date: '2026-11-20 15:57'
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
- [ ] #1 The EP bundle contains docker-ep.sh; 'TS_AUTHKEY=file:<path> htc-ep/docker-ep.sh' runs an EP with no extra container privileges
- [ ] #2 Ctrl-C / docker stop shut the EP down gracefully (withdrawn from the AP, leaves the tailnet)
- [ ] #3 Tailscale and HTCondor downloads are cached on the host across runs
- [ ] #4 README documents the Docker EP alongside the native one, including the Apptainer limitation
- [ ] #5 Tested on a real Linux host (stacks, x86_64) as well as the laptop
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ep/docker-ep.sh: build image htc-ep (pinned almalinux, python3 util-linux which hostname procps-ng; user from build args = caller's name/uid/gid/home); docker run --rm --init, default bridge network, --hostname <host short name>, bundle dir + ~/.cache/htc-ep + ~/.hpc-annex mounted at host paths, key file mounted read-only as file:, run-ep.sh as the command.
2. make-ep-bundle.sh: include docker-ep.sh.
3. README: Docker EP subsection under 'Run an EP' and requirements.
4. Test: laptop and stacks (EP container on the AP host works since the container has its own 127.0.0.1:9618).
<!-- SECTION:PLAN:END -->
