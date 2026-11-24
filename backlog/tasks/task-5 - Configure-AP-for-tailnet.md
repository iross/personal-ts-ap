---
id: TASK-5
title: Configure AP for tailnet
status: Done
assignee:
  - '@claude'
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 02:23'
labels:
  - ap
  - networking
dependencies:
  - TASK-2
  - TASK-3
references:
  - 'https://app.todoist.com/app/task/6j3gCvMMxjMp278v'
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Apply decision-1 to the AP. Every party addresses the AP as 127.0.0.1:9618: the AP host itself, and EPs via their local forwarder. The AP listens on loopback only; 'tailscale serve --tcp 9618' exposes it to the tailnet and nothing else (user's choice over leaving all interfaces open or a host firewall). Simplify start.sh now that the AP no longer moves between hosts. Make condor tools default to ap_collector instead of the condor_status alias.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AP daemons advertise 127.0.0.1:9618 and listen only on loopback (port 9618 not reachable from the LAN)
- [x] #2 tailscale serve forwards tailnet :9618 to the AP; ap/tailnet.sh sets it up idempotently and fails with an actionable message when tailscale is missing, down, or lacks operator permission
- [x] #3 ANNEX_COLLECTOR is 127.0.0.1:9618?sock=ap_collector and condor_status/condor_q work without aliases (native and ap/docker.sh shell)
- [x] #4 AP restart on the same machine resumes the existing queue
- [x] #5 Decision on custom EP token documented in notes.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ap/20-ap-tailnet.conf (copied by install.sh, sorts after 11-ap-annex.conf): NETWORK_INTERFACE=127.0.0.1, BIND_ALL_INTERFACES=false, ENABLE_IPV6=false, ANNEX_COLLECTOR=127.0.0.1:9618?sock=ap_collector, COLLECTOR_HOST=$(ANNEX_COLLECTOR). Drop the condor_status alias.
2. ap/tailnet.sh (host side): check tailscale is installed and running, check operator permission, 'tailscale serve --bg --tcp 9618 tcp://127.0.0.1:9618' if not already set, print the AP's tailnet IPv4.
3. start.sh: drop 13-ap-hostname.conf pinning; run tailnet.sh unless PERSONAL_AP_IN_CONTAINER=1; keep EP token minting; check whether the local READ/WRITE token is still needed with forced IDTOKENS, keep or drop accordingly.
4. docker.sh start: run tailnet.sh on the host, pass PERSONAL_AP_IN_CONTAINER=1.
5. notes.md: token decision, serve rationale. Verify on stacks with the laptop EP spike scripts.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike (decision-1): use TCP_FORWARDING_HOST=127.0.0.1, ENABLE_IPV6=false, ANNEX_COLLECTOR=127.0.0.1:9618?sock=ap_collector in a config.d file that sorts AFTER 11-ap-annex.conf. No PRIVATE_NETWORK_* knobs. Keep custom annex EP token minting (CLI-issued token has sub condor@password, 60s lifetime). Restrict bind to tailnet + loopback (AP otherwise listens on LAN). Make tools default to ap_collector (COLLECTOR_HOST) instead of a condor_status alias; plain condor_status/better-analyze otherwise hit a nonexistent default collector. condor_reconfig as the user is denied; use SIGHUP to the master.

Validated on stacks via ap/docker.sh (NixOS): ss shows HTCondor on 127.0.0.1:9618 only (100.x:9618 is tailscaled serve); laptop cannot connect via LAN 192.168.1.69:9618, can via 100.71.206.56:9618. All daemons advertise <127.0.0.1:9618...>. condor_status/condor_q work without alias. tailnet.sh: Access-denied path prints operator hint; second run is a no-op (matches TCPForward 127.0.0.1:9618). Local tools need no token (READ and WRITE succeed via FS with forced IDTOKENS on EP-facing daemons), so dropped the 'testing' token and the IDTOKENS client override in start.sh. Fixed: annex create failed when the annex job was gone but its tarball remained (CLI won't overwrite); start.sh now removes the stale tarball before create. Restart resumed queue (same schedd). End to end: unprivileged laptop EP ran hello_world through tailscale serve. Removed 13-ap-hostname.conf pinning and the condor_status alias.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
AP is addressed as 127.0.0.1:9618 by everyone, listens on loopback only, and is exposed to the tailnet (only) by tailscale serve via the new ap/tailnet.sh, run by start.sh natively or by docker.sh on the host. Tools default to ap_collector. Dropped Slurm-era hostname pinning, local token, and alias; fixed stale-tarball annex re-create. Verified on stacks with a laptop EP running hello_world.
<!-- SECTION:FINAL_SUMMARY:END -->
