---
id: TASK-13
title: Use the AlmaLinux build on 64 KB-page aarch64 EPs
status: To Do
assignee: []
created_date: '2026-11-20 18:45'
labels:
  - ep
  - upstream-workaround
dependencies: []
priority: high
ordinal: 13000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On aarch64 hosts whose kernel uses 64 KB pages (node17: Ubuntu 26, kernel 7.0.0-2018-nvidia-bos-64k, getconf PAGESIZE = 65536, 352 CPUs, 4 GPUs), the HTCondor 25.15.15 aarch64_Ubuntu26 build's condor_startd segfaults in the dynamic loader before main: LD_DEBUG shows the crash during 'relocation processing: sbin/condor_startd', and gdb shows the fault in ld-linux-aarch64.so.1. Cause: in that binary the executable LOAD segment (vaddr 0x0-0x0e066c) and the writable LOAD segment (starting 0x0ed390) share one 64 KB page, which cannot be mapped both executable and writable. A readelf scan of the whole tarball finds condor_startd as the only such file, matching the observed behaviour (master, shared_port and gpu_discovery run). The aarch64_AlmaLinux9 build has no such overlap in any daemon (only condor_submit, unused on EPs), all its libraries resolve on Ubuntu 26, and its startd runs on node17.

Current manual workaround on node17: BINARIES_URL=<aarch64_AlmaLinux9 tarball URL> in ~/.condor/annex_config, after deleting the cached ~/.hpc-annex/binaries/condor-25.15.15-aarch64_Ubuntu26-stripped.tar.gz (annex-setup.sh prefers a cached file under the distro's name over BINARIES_URL, and saves the Alma download under the Ubuntu name). With it, an EP on node17 ran gpu.sub on 2026-11-20 (Assigned GPUs: GPU-f34a1a72).

Fix: run-ep.sh selects the AlmaLinux 9 aarch64 build itself when uname -m is aarch64 and getconf PAGESIZE > 4096, e.g. by exporting BINARIES_URL for annex-setup.sh (it honours the variable from the environment), and handles the cache-name collision so a cached distro build is not used instead. Other hosts unchanged. Worth reporting upstream; drop the workaround once the Ubuntu build is fixed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On an aarch64 host with a page size above 4 KB, run-ep.sh uses the AlmaLinux 9 aarch64 build and says so in its output; other hosts get the build annex-setup.sh picks today
- [ ] #2 A previously cached tarball under the distribution's name does not override the selected build
- [ ] #3 On node17, with ~/.condor/annex_config's BINARIES_URL removed, the EP starts and gpu.sub runs
- [ ] #4 README notes the behaviour and the upstream bug
<!-- AC:END -->
