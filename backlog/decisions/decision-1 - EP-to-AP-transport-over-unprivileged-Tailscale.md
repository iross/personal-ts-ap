---
id: decision-1
title: EP-to-AP transport over unprivileged Tailscale
date: '2026-11-20 01:53'
status: accepted
---
## Context

EPs run without root (HPC-like), so Tailscale on the EP runs as
`tailscaled --tun=userspace-networking`. The EP's kernel has no route to
100.64/10: only tailscaled can reach the tailnet (SOCKS5, or `tailscale nc`),
and HTCondor has no SOCKS support. Inbound tailnet traffic is delivered to the
EP's 127.0.0.1. Every annex EP->AP connection is outbound from the EP:
collector updates, CCB registration, direct attach to the schedd, and the
starter's connections to the shadow (including file transfer).

The AP is entirely behind shared port 9618.

Spike (TASK-3, 2026-11-20): AP in an AlmaLinux 9 container with host networking
on a NixOS tailnet host; EP in a Docker container on a laptop with
`ip route add unreachable 100.64.0.0/10`, running as a non-root user with no
/dev/net/tun. hello_world ran end to end, with input and output transfer.

## Decision

**The AP's address is 127.0.0.1:9618 for every party.**

- AP: `TCP_FORWARDING_HOST = 127.0.0.1`, `ENABLE_IPV6 = false`,
  `ANNEX_COLLECTOR = 127.0.0.1:9618?sock=ap_collector`. This file must sort
  after `11-ap-annex.conf`, because the HPC_ANNEX feature sets its own
  `ANNEX_COLLECTOR` (`$(FULL_HOSTNAME)`-based).
  - On the AP host, 127.0.0.1:9618 is the AP itself.
- EP: a local forwarder listens on 127.0.0.1:9618 and pipes each connection
  into `tailscale nc <AP-tailnet-IP> 9618`.
  - On the EP, 127.0.0.1:9618 is the forwarder, which leads to the AP.
- EP: no `PRIVATE_NETWORK_NAME`. Its address carries
  `CCBID=127.0.0.1:9618...`, so the AP reaches the EP only via CCB reversal.
  The EP then calls back to 127.0.0.1:9618, which is its forwarder.

Rejected: `PRIVATE_NETWORK_NAME` + `PRIVATE_NETWORK_INTERFACE = 127.0.0.1` on
the AP. The EP correctly used the AP's 127.0.0.1 PrivAddr. But sharing the
network name made the schedd skip CCB and connect directly to the EP's
non-routable address (`<172.17.0.3:...>`, Connection refused). The network
name is symmetric, so it cannot apply to the EP's outbound connections only.

Not needed: proxychains (LD_PRELOAD), or the EP advertising its tailnet IP.

## Consequences

- Nothing else on the tailnet can talk to the AP's daemons directly; only EPs
  (via their forwarders) and tools on the AP host. Remote `condor_q` from
  another tailnet machine would need its own forwarder.
- The AP still binds all interfaces (`BIND_ALL_INTERFACES` default), so port
  9618 is also open on the AP host's LAN. TASK-5 should restrict this to the
  tailnet and loopback interfaces.
- EPs need `tailscale` (static binary, fetchable without root) and a forwarder
  (socat here; HPC nodes may lack it, so ship a small Python one).
- The annex token from `htcondor annex create` has the right scopes when run
  locally, but subject `condor@password` and a 60-second lifetime. The annex
  START policy needs `<user>@<ANNEX_TOKEN_DOMAIN>`, so the AP must still mint
  the EP token itself (`condor_token_create -key AP -identity ...`).
