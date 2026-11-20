# Configuration Notes

`ap/` configures a personal HTCondor Access Point on a host on a Tailscale tailnet. EPs are
contributed through `htcondor annex create`'s tarball and connect to the AP over the tailnet,
without root on the EP. The AP is based on `bin/make-ap-from-tarball` from the non-root HTCondor
installation instructions. The EP is based on the configuration in the annex tarball.

Why the network is set up this way (a local forwarder on each EP, the AP addressed as
`127.0.0.1:9618`, CCB) is recorded in `backlog/decisions/decision-1`.

# AP Configuration

## Networking

Every party addresses the AP as `127.0.0.1:9618` (`20-ap-tailnet.conf`): on the AP host that is
the AP itself, and on an EP it is the EP's local forwarder to the tailnet. The AP listens on
loopback only (`NETWORK_INTERFACE = 127.0.0.1`, `BIND_ALL_INTERFACES = false`), and
`ap/tailnet.sh` runs `tailscale serve --tcp 9618 tcp://127.0.0.1:9618` so the tailnet, and nothing
else, can reach it. The LAN cannot connect to port 9618.

`tailscale serve` needs your user to be allowed to manage Tailscale; run once on the AP host:
`sudo tailscale set --operator=$USER`. The serve config persists in tailscaled.

`COLLECTOR_HOST` points at the annex collector (`ap_collector`), so `condor_status` and friends
work without `-pool`. `20-ap-tailnet.conf` must sort after `11-ap-annex.conf`, which sets its own
`ANNEX_COLLECTOR`.

## Job Routing

`11-ap-annex.conf` enables the `HPC_ANNEX` feature with `HPC_ANNEX_REQUIRE_JOB = false`, and a job
transform sets `TargetAnnexName = "default-annex"` on every job that doesn't name an annex, except
scheduler (7) and local (12) universe jobs, which run on the AP itself. Since all EPs come from
that annex, users don't need to add anything to their submit files.

## Docker Mode

On hosts without a native HTCondor build, `ap/docker.sh` runs `install.sh` and `start.sh` in an
AlmaLinux 9 image (`ap/Dockerfile`) with `--network host`. The image is built with the invoking
user's name, uid, gid and home, and `~/personal-htcondor` and `ap/` are bind-mounted at their host
paths, so the install and the `current-ap` symlink look the same inside and outside the container.
`tailscale` stays on the host: `docker.sh start` runs `tailnet.sh` there, and passes
`PERSONAL_AP_IN_CONTAINER=1` so `start.sh` skips it inside the container.

## Daemon Name Pinning

By default, AP daemon names are derived from the `FULL_HOSTNAME` of the host the AP runs on. To keep
AP daemon names and IDToken trust domains consistent if the AP is resumed on a different host, we set
the following explicitly:

* `TRUST_DOMAIN`: Subject domain of IDTokens that the AP accepts
* `ANNEX_TOKEN_DOMAIN`: EP subject domain checked in the start expressions of annex jobs.
* `SCHEDD_NAME`: Name of the AP's schedd. Used by annex EPs to locate the schedd for direct attach.

## Force IDToken Auth

Annex jobs' start expression requires that an EP have an `AuthenticatedIdentity` matching
`<submitter>@<annex token domain>`. An EP on the same host as its AP may otherwise attempt FS auth
and get an incorrect identity. We force IDToken auth from the EP to the AP:

```
AP_COLLECTOR.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS
SCHEDD.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS
```

We also grant DAEMON permissions to the IDToken's custom subject to allow schedd direct attach
and CCB registration, since it's not allowed for this subject by default:

```
AP_COLLECTOR.ALLOW_DAEMON = $(ALLOW_DAEMON), ...
SCHEDD.ALLOW_DAEMON = $(ALLOW_DAEMON), ...
```

Condor tools run on the AP host as the AP's owner still authenticate by FS, so no separate
token for local tools is needed.

# EP Configuration

## Launcher

`ap/make-ep-bundle.sh` packs the annex tarball, the EP token, the AP's tailnet IP (`ep.env`) and
`ep/run-ep.sh` + `ep/forward.py`. On the EP, `run-ep.sh`:

* runs the annex's `annex-setup.sh` first, which downloads HTCondor for the host; it needs no
  tailnet, so an unsupported host fails before joining it.
* starts `tailscaled --tun=userspace-networking --state=mem:`. Without root there is no tun
  device, so the kernel cannot route to the tailnet; only tailscaled can. `--state=mem:` makes the
  node ephemeral. The auth key is passed as `--auth-key=file:<0600 file>`, never on a command line.
* starts `forward.py`, which listens on 127.0.0.1:9618 and pipes each connection through
  `tailscale nc <AP-ip> 9618`. Because the AP advertises `127.0.0.1:9618`, every connection the
  EP makes (collector, CCB, direct attach, file transfer) goes through it. This is also why only
  one EP can run per host.
* runs `hpc.slurm` with `SLURM_JOBID` unset, which makes the annex run `annex-node.sh` directly on
  this host instead of through `srun`.

On exit it sends SIGTERM to the EP's `condor_master` and waits for all of its HTCondor processes,
so the EP's ads are withdrawn from the AP. `condor_master` gives each daemon its own process group,
so they are found by executable path (under the EP's work directory), not by process group.

## Explicit IDToken Creation

The `annex.token` that `htcondor annex create` puts in the tarball (via `condor_token_fetch`) does
not authorize an EP in this setup: its subject is `condor@password` rather than
`<submitter>@<annex token domain>`, and it expires after 60 seconds. The AP mints the EP token itself:

```
IDENTITY="$(whoami)@$(condor_config_val ANNEX_TOKEN_DOMAIN)"
condor_token_create -key AP -identity "$IDENTITY" \
    -authz READ -authz WRITE -authz ADVERTISE_STARTD -authz ADVERTISE_MASTER -authz DAEMON
```

# Development

Shell scripts are checked by prek hooks (`.pre-commit-config.yaml`): shellcheck, shfmt, and
file hygiene. Run `prek install` once per clone, and `prek run --all-files` before committing.

Hook revs are pinned to commit SHAs. Update them only to releases at least a week old:

```
prek update --cooldown-days 7 --freeze
```

`tests/run-test-ep.sh <bundle> <authkey-file> [name]` runs an EP bundle in a container that stands
in for an unprivileged HPC node (tailnet range unreachable from the kernel, non-root user). Start
two with different names to test several EPs against one AP.
