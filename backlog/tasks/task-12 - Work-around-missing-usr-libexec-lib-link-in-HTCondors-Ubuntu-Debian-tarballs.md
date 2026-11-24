---
id: TASK-12
title: Work around missing usr/libexec/lib link in HTCondor's Ubuntu/Debian tarballs
status: To Do
assignee: []
created_date: '2026-11-20 18:45'
labels:
  - ep
  - ap
  - upstream-workaround
dependencies: []
priority: high
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
HTCondor 25.15.15's Ubuntu and Debian tarballs (seen in aarch64_Ubuntu26, aarch64_Ubuntu24, and by layout x86_64_Ubuntu24/Debian12) lack the symlink usr/libexec/lib -> ../lib. Binaries in usr/libexec/condor have RUNPATH $ORIGIN/../lib:$ORIGIN/../lib/condor, which then resolves to the nonexistent usr/libexec/lib, so 33 libexec programs cannot load libcondor_utils/libclassad and exit 127 before running. Affected include condor_shared_port (the EP's master restarts it forever and never starts the startd), condor_gpu_discovery, curl_plugin and condor_chirp. AlmaLinux tarballs ship the equivalent usr/libexec/lib64 -> ../lib64 and are fine. Found on node17 (Ubuntu 26 aarch64) on 2026-11-20 and reproduced in an ubuntu:26.04 container; adding the link makes shared_port and gpu_discovery run (only ce-audit.so, an HTCondor-CE plugin, still misses libs).

This also breaks a native AP on Ubuntu/Debian (ap/install.sh): TASK-4 only tested installation there, not starting daemons.

Fix: add the link wherever it is missing. EP: in run-ep.sh prepare_annex, after annex-setup.sh, patch $ANNEX_DIR/condor.tar.gz (the copy annex-job-setup.sh unpacks) when it has usr/lib/libcondor_utils* but no usr/libexec/lib. AP: in install.sh, add the link after unpacking. Both must be no-ops for tarballs that already have it. Also worth reporting upstream to the HTCondor team.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 run-ep.sh adds usr/libexec/lib -> ../lib to the HTCondor tarball the annex unpacks when it is missing, and leaves AlmaLinux tarballs unchanged
- [ ] #2 install.sh adds the same link after unpacking when it is missing
- [ ] #3 An EP on Ubuntu 26.04 (container is enough) starts condor_shared_port and runs a job without manual patching
- [ ] #4 A native AP on Debian 12 or Ubuntu 24.04 starts (master, schedd, shared_port, ap_collector) and accepts condor_q
<!-- AC:END -->
