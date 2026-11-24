---
id: TASK-3
title: 'Spike: no-root EP-to-AP connectivity over userspace Tailscale'
status: Done
assignee: []
created_date: '2026-11-19 21:50'
updated_date: '2026-11-20 01:53'
labels:
  - spike
  - networking
dependencies: []
references:
  - https://tailscale.com/kb/1112/userspace-networking
  - https://htcondor.readthedocs.io/en/latest/admin-manual/networking.html
  - https://github.com/htcondor/htcondor/blob/v25.15.15/src/condor_utils/condor_sockaddr.cpp
  - https://app.todoist.com/app/task/6j3gCvMMxjMp278v
priority: high
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Get HTCondor's EP->AP connections across an unprivileged (userspace-networking) tailscaled. The EP host has no tun device, so its kernel cannot route to 100.64/10; only tailscaled can reach the tailnet (SOCKS5 or 'tailscale nc'). The AP is entirely behind shared port 9618, so one local forwarder on the EP is enough.

Design under test:
- Forwarder on the EP: 127.0.0.1:9618 -> 'tailscale nc <AP-tailnet-IP> 9618' (socat if present, else a small bundled Python forwarder).
- EP COLLECTOR_HOST / CCB_ADDRESS = 127.0.0.1:9618?sock=ap_collector, so the EP's own outbound connections go through the forwarder.
- AP->EP traffic uses CCB: the AP sends requests back over the EP's existing CCB connection, so the EP opens no listening ports.
- Schedd/shadow addresses the EP learns from the collector contain the AP's 100.x IP. The AP also advertises PRIVATE_NETWORK_INTERFACE=127.0.0.1 under a PRIVATE_NETWORK_NAME the EP shares, so the EP picks the 127.0.0.1 address (the forwarder). Verify the AP does not, in turn, try the EP's private address directly instead of CCB.

Fallbacks, in order: (1) proxychains-ng (LD_PRELOAD) on the EP's condor_master via tailscaled's SOCKS5 listener; (2) EP advertises its tailnet IP via TCP_FORWARDING_HOST + EP shared port, relying on userspace inbound forwarding to localhost.

Test bed: EP in a container with no NET_ADMIN and no /dev/net/tun.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An unprivileged EP's startd appears in the AP's ap_collector and runs a hello-world job end to end
- [x] #2 File transfer in both directions works
- [x] #3 Winning config and rejected options recorded in backlog/decisions/
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Scope: the annex EP -> AP flow itself is already proven without Tailscale (OSPool AP + Slurm EP, AP publicly reachable). This spike only covers the transport: getting HTCondor's outbound EP->AP connections across an unprivileged userspace-networking tailscaled.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
hello_world ran end to end (input+output transfer) on an unprivileged EP whose kernel cannot reach the tailnet. Winning design: AP advertises TCP_FORWARDING_HOST=127.0.0.1; EP runs a forwarder 127.0.0.1:9618 -> 'tailscale nc <AP-ip> 9618'; AP->EP via CCB. The PRIVATE_NETWORK_NAME approach was rejected (makes schedd bypass CCB). See decision-1. Spike scripts kept in the session scratchpad (container-init.sh, run-ep-spike.sh).
<!-- SECTION:FINAL_SUMMARY:END -->
