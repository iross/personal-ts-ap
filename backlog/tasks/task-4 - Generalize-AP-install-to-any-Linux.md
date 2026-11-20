---
id: TASK-4
title: Generalize AP install to any Linux
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 01:53'
labels:
  - ap
dependencies:
  - TASK-2
priority: medium
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
ap/install.sh only accepts EL 8/9/10. Map /etc/os-release to the HTCondor tarball names on htcss-downloads.chtc.wisc.edu (AlmaLinux 8/9/10, Debian, Ubuntu; confirm exact names and current 25.x version). Default base dir ~/personal-htcondor instead of /scratch/$USER. Drop the shared-FS assumptions in comments/help.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Install succeeds on an EL and a Debian/Ubuntu host
- [ ] #2 Unsupported distro/arch fails fast with a message listing supported ones
- [ ] #3 Tarball version is pinned in one place
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tarball URL: 25.15.15 is under /release/, not /snapshot/ (current install.sh URL is broken). Newer: 25.15.17. NixOS hosts (e.g. stacks) cannot run the tarball natively; spike used an AlmaLinux 9 container with --network host. Decide: support via container wrapper, nix-ld, or document as unsupported.
<!-- SECTION:NOTES:END -->
