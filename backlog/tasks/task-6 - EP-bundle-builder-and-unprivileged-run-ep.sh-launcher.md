---
id: TASK-6
title: EP bundle builder and unprivileged run-ep.sh launcher
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 01:53'
labels:
  - ep
dependencies:
  - TASK-3
  - TASK-5
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
make-ep-bundle.sh (on AP): packages annex-<name>.tar, the EP token (if still needed), run-ep.sh, the forwarder from the spike, and ep.env (AP tailnet IP, annex name) into ep-bundle-<name>.tar.gz. Never put a Tailscale auth key in the bundle. run-ep.sh (on EP, no root): fetch static tailscale binaries if missing; start tailscaled --tun=userspace-networking --state=mem: --socket=<workdir>/ts.sock --socks5-server=localhost:1055; tailscale up --auth-key=$TS_AUTHKEY --hostname=htc-ep-<host>-<pid>; wait for AP:9618; start forwarder; unpack annex, run annex-setup.sh, append EP config (unique UID_DOMAIN/STARTD_NAME/MASTER_NAME), run 'bash hpc.slurm' with SLURM_JOBID unset (non-Slurm pid mode). Trap on exit: stop condor_master, tailscale logout, stop tailscaled and forwarder. Optional --cpus/--memory caps only if the spike/test shows a need.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Missing TS_AUTHKEY, AP unreachable, and unsupported distro each fail fast with an actionable message
- [ ] #2 Two EPs on the same host run concurrently in separate work dirs
- [ ] #3 EP exits cleanly after the annex idle timeout and leaves the tailnet
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike: forwarder = socat TCP-LISTEN:9618,bind=127.0.0.1,fork,reuseaddr EXEC:'tailscale --socket=<sock> nc <AP-ip> 9618'; ship a Python fallback for hosts without socat. tailscaled flags that worked unprivileged: --tun=userspace-networking --state=mem: --statedir=<dir> --socket=<dir>/ts.sock. annex-setup.sh needs 'which' (annex-node.sh calls it). EP config must NOT set PRIVATE_NETWORK_NAME. Unique UID_DOMAIN/STARTD_NAME/MASTER_NAME suffix appended to 20-annex-pilot-instance. The EP's live config.d is <pilot>/condor-*/<hostname>/config.d, not local/config.d.
<!-- SECTION:NOTES:END -->
