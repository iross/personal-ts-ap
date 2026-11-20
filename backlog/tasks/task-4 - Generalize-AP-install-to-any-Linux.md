---
id: TASK-4
title: Generalize AP install to any Linux
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:13'
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
- [x] #1 Install succeeds on an EL and a Debian/Ubuntu host
- [x] #2 Tarball version is pinned in one place
- [x] #3 Hosts without a native HTCondor build (e.g. NixOS) get an error that points to ap/docker.sh
- [x] #4 ap/docker.sh install/start/shell runs the AP in an AlmaLinux 9 container with host networking, as the invoking user
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. install.sh: map /etc/os-release ID + VERSION_ID + uname -m to the HTCondor tarball name (AlmaLinux/RHEL family, Debian, Ubuntu, AmazonLinux, openSUSE); confirm it exists under /release/ with a HEAD request; otherwise fail and point to ap/docker.sh. Default base dir ~/personal-htcondor. Require python3 (htcondor annex CLI). Version pinned once (25.15.15).
2. start.sh: fail with the docker hint if condor_master cannot execute on this host.
3. ap/Dockerfile: almalinux:9.8-20261027 pinned by digest; python3 + tools; user created from build args (name, uid, gid, home) so paths match the host.
4. ap/docker.sh install|start|shell: build image, run with --network host, bind-mount ~/personal-htcondor and ap/ at the same paths; start runs the AP in the foreground as container 'personal-htcondor-ap'; shell runs condor tools inside it.
5. Verify: shellcheck/shfmt; docker.sh install+start on stacks (NixOS); native install refusal on stacks; native install in a Debian/Ubuntu container.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Tarball URL: 25.15.15 is under /release/, not /snapshot/ (current install.sh URL is broken). Newer: 25.15.17. NixOS hosts (e.g. stacks) cannot run the tarball natively; spike used an AlmaLinux 9 container with --network host. Decide: support via container wrapper, nix-ld, or document as unsupported.

Native install detects the platform from /etc/os-release + uname -m and checks the tarball exists under /release/ (fixes the dead /snapshot/ URL); unsupported hosts get an error pointing to ap/docker.sh (replaces the old 'list supported distros' criterion, per user). Scripts use #!/usr/bin/env bash because NixOS has no /bin/bash. Platform check runs before the python3 check so NixOS users see the docker hint first. ap/docker.sh: image built from ap/Dockerfile (almalinux:9.8-20261027 pinned by digest) with the caller's name/uid/gid/home; ~/personal-htcondor and ap/ bind-mounted at host paths. Validation on stacks (NixOS): native install refused with docker hint; docker.sh install/start/shell work; native start.sh refuses an install it can't run; second start and shell-when-stopped give clear errors; restart resumes the same schedd and annex. Native install succeeded in debian:12 and ubuntu:24.04 containers; fedora:41 refused.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh now installs natively on AlmaLinux/RHEL-family, Debian, Ubuntu, Amazon Linux and openSUSE (x86_64; aarch64 where builds exist), from the /release/ URL, with the version pinned once. Other hosts (e.g. NixOS) are refused with a pointer to the new ap/docker.sh install|start|shell, which runs the same scripts in an AlmaLinux 9 container with host networking as the invoking user. Verified on stacks (NixOS) and in Debian 12 / Ubuntu 24.04 / Fedora 41 containers.
<!-- SECTION:FINAL_SUMMARY:END -->
