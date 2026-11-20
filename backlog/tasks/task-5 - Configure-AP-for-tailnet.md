---
id: TASK-5
title: Configure AP for tailnet
status: To Do
assignee: []
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 01:53'
labels:
  - ap
  - networking
dependencies:
  - TASK-2
  - TASK-3
priority: high
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
At AP start, detect the tailnet IPv4 (tailscale ip -4; fail fast with a clear message if absent) and write a config.d file setting NETWORK_INTERFACE to it, ANNEX_COLLECTOR=<ip>:9618?sock=ap_collector (verify the HPC_ANNEX feature's default form first), IPv6 disabled or pinned, plus any private-network knobs from the spike. Simplify start.sh: AP no longer moves between nodes, so drop the 13-ap-hostname.conf pinning, the annex-ready marker, and the remote-CLI READ/WRITE 'testing' token (CLI runs locally with FS auth). Check whether htcondor annex create under FS auth now yields a correctly scoped annex.token; if so, remove the custom annex-ep.token minting, else keep it. Keep 11-ap-annex.conf, 12-ap-trust-domain.conf, 14-ap-force-idtoken.conf.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 condor_status -any shows AP daemons on the tailnet IP
- [ ] #2 condor_config_val ANNEX_COLLECTOR returns the tailnet address
- [ ] #3 AP restart on the same machine resumes the existing queue
- [ ] #4 Decision on custom EP token documented in notes.md
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From spike (decision-1): use TCP_FORWARDING_HOST=127.0.0.1, ENABLE_IPV6=false, ANNEX_COLLECTOR=127.0.0.1:9618?sock=ap_collector in a config.d file that sorts AFTER 11-ap-annex.conf. No PRIVATE_NETWORK_* knobs. Keep custom annex EP token minting (CLI-issued token has sub condor@password, 60s lifetime). Restrict bind to tailnet + loopback (AP otherwise listens on LAN). Make tools default to ap_collector (COLLECTOR_HOST) instead of a condor_status alias; plain condor_status/better-analyze otherwise hit a nonexistent default collector. condor_reconfig as the user is denied; use SIGHUP to the master.
<!-- SECTION:NOTES:END -->
