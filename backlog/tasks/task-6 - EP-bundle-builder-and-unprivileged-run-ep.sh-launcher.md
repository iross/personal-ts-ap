---
id: TASK-6
title: EP bundle builder and unprivileged run-ep.sh launcher
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:43'
labels:
  - ep
dependencies:
  - TASK-3
  - TASK-5
references:
  - 'https://app.todoist.com/app/task/6j3gCvMMxjMp278v'
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
make-ep-bundle.sh (on AP): packages annex-<name>.tar, the EP token (if still needed), run-ep.sh, the forwarder from the spike, and ep.env (AP tailnet IP, annex name) into ep-bundle-<name>.tar.gz. Never put a Tailscale auth key in the bundle. run-ep.sh (on EP, no root): fetch static tailscale binaries if missing; start tailscaled --tun=userspace-networking --state=mem: --socket=<workdir>/ts.sock --socks5-server=localhost:1055; tailscale up --auth-key=$TS_AUTHKEY --hostname=htc-ep-<host>-<pid>; wait for AP:9618; start forwarder; unpack annex, run annex-setup.sh, append EP config (unique UID_DOMAIN/STARTD_NAME/MASTER_NAME), run 'bash hpc.slurm' with SLURM_JOBID unset (non-Slurm pid mode). Trap on exit: stop condor_master, tailscale logout, stop tailscaled and forwarder. Optional --cpus/--memory caps only if the spike/test shows a need.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Missing TS_AUTHKEY, AP unreachable, and unsupported distro each fail fast with an actionable message
- [x] #2 EP exits cleanly after the annex idle timeout and leaves the tailnet
- [x] #3 A second run-ep.sh on a host whose 127.0.0.1:9618 is taken fails fast (one EP per host; it uses the whole machine)
- [x] #4 The Tailscale auth key never appears in the bundle or on a command line
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ep/forward.py: asyncio TCP listener on 127.0.0.1:9618; each connection piped through 'tailscale --socket=S nc <AP-ip> 9618'. Python 3.6 compatible. Add ruff hook.
2. ep/run-ep.sh: read ep.env; check TS_AUTHKEY, python3, curl, arch, port 9618 free; fetch tailscale 1.104.7 static (sha256 pinned) into ~/.cache/htc-ep; start userspace tailscaled (--state=mem:), tailscale up with --auth-key=file:<0600 file>; tailscale ping the AP; start forwarder; unpack annex, annex-setup.sh, install EP token; run hpc.slurm under setsid with SLURM_JOBID unset; trap: TERM the pilot's process group, stop forwarder, tailscale logout, stop tailscaled.
3. ap/make-ep-bundle.sh: find current AP, require annex tarball + EP token, get AP tailnet IP via tailnet.sh, write ep-bundle-<annex>.tar.gz (0600) with htc-ep/{run-ep.sh,forward.py,ep.env,annex tar,token}.
4. Verify: hooks; bundle from stacks; laptop container EP (unprivileged, 100.64/10 blocked) runs hello_world; failure paths (no key, bad AP IP, unsupported arch/no python, port taken); Ctrl-C/TERM cleanup; short idle timeout exit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike: forwarder = socat TCP-LISTEN:9618,bind=127.0.0.1,fork,reuseaddr EXEC:'tailscale --socket=<sock> nc <AP-ip> 9618'; ship a Python fallback for hosts without socat. tailscaled flags that worked unprivileged: --tun=userspace-networking --state=mem: --statedir=<dir> --socket=<dir>/ts.sock. annex-setup.sh needs 'which' (annex-node.sh calls it). EP config must NOT set PRIVATE_NETWORK_NAME. Unique UID_DOMAIN/STARTD_NAME/MASTER_NAME suffix appended to 20-annex-pilot-instance. The EP's live config.d is <pilot>/condor-*/<hostname>/config.d, not local/config.d.

Implemented ap/make-ep-bundle.sh, ep/run-ep.sh, ep/forward.py (Python 3.6+, one forwarder implementation instead of socat-or-python). Added ruff hooks (v0.17.5) + ruff.toml. Two-EPs-per-host criterion replaced by fail-fast (both would need 127.0.0.1:9618). Found and fixed: condor_master gives each daemon its own process group, so signalling the pilot's group left HTCondor running orphaned; cleanup now TERMs condor_master found via /proc/<pid>/exe under the EP work dir, waits up to 60s for all of them, then KILLs. With that, the EP's slot is withdrawn from the AP immediately on stop. Annex setup moved before the tailnet join so unsupported distros (annex-setup.sh: 'Unrecognized linux distro') fail without creating a tailnet node. Validation (laptop container, unprivileged user via setpriv, 100.64/10 blocked; AP on stacks via docker.sh): hello_world ran; SIGTERM -> graceful stop, slot withdrawn, node left tailnet; 60s idle annex -> run-ep exit 0, slot withdrawn, left tailnet; missing key, invalid key, unreachable AP, port 9618 taken each fail with actionable messages and leave no tailnet node; Fedora fails in annex setup. Bundle is 0600; key passed to tailscale up only as file:<0600 file>, removed after join.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
EPs now come from a single bundle: ap/make-ep-bundle.sh packs the annex tarball, EP token, AP tailnet IP, run-ep.sh and forward.py; on the EP, 'TS_AUTHKEY=<key> htc-ep/run-ep.sh' joins the tailnet unprivileged, forwards 127.0.0.1:9618 to the AP, runs the annex, and on exit or idle timeout stops HTCondor gracefully and leaves the tailnet. Verified end to end against the AP on stacks, including stop, idle exit and failure paths.
<!-- SECTION:FINAL_SUMMARY:END -->
