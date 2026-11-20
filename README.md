# Personal HTCondor AP over Tailscale

Run your own single-user HTCondor Access Point (AP) on a machine on your
[Tailscale](https://tailscale.com) tailnet, then add Execution Points (EPs) from any Linux
machine you can log in to, with no root needed on the EP. EPs join the tailnet themselves, so they
work from behind NAT and firewalls, and nothing is exposed outside your tailnet.

```
   AP host (on your tailnet)                          EP host (any Linux, no root)
  ┌──────────────────────────────┐                   ┌─────────────────────────────────┐
  │ HTCondor AP  127.0.0.1:9618  │◄─ tailscale ──────┤ run-ep.sh                       │
  │   ▲                          │   serve :9618     │  ├ tailscaled (userspace)       │
  │   └─ tailscale serve ◄───────┼──── tailnet ◄─────┤  ├ forwarder 127.0.0.1:9618    │
  └──────────────────────────────┘                   │  └ HTCondor EP (annex)          │
                                                     └─────────────────────────────────┘
```

The workflow:

1. [Start an AP](#1-start-the-ap) on a host that is on your tailnet.
2. [Build an EP bundle](#2-build-an-ep-bundle) on the AP.
3. [Copy the bundle to the to-be-EP and run it](#3-run-an-ep) with a Tailscale auth key. The EP
   joins the tailnet and offers its whole machine to your AP.
4. [Submit jobs](#submit-jobs) to the AP; they run on your EPs.

## Requirements

**AP host**

- Linux, joined to your tailnet with Tailscale installed and running.
- Either a distribution HTCondor builds for (AlmaLinux/Rocky/RHEL/CentOS 8–10, Debian 12–13,
  Ubuntu 22.04–26.04, Amazon Linux 2023, openSUSE Leap 15–16) with `python3`, `curl` and `tar`;
  or, for anything else (for example NixOS), Docker that your user can run without `sudo`. The
  `tailscale` CLI must be on the host either way.
- `sudo` once, to let your user manage `tailscale serve` (see below).

**EP host**, either natively:

- Linux that the annex setup recognizes: AlmaLinux/Rocky/RHEL/CentOS 8–10, Debian 12–13,
  Ubuntu 22.04–26.04 or openSUSE Leap 15–16 on x86_64; AlmaLinux-family 8–10 or Ubuntu 24.04+ on
  aarch64.
- `bash` 4 or newer, `curl`, `tar`, `sha256sum`, `python3` 3.6 or newer, and `setsid`
  (util-linux). No root.
- Outbound internet access: the EP downloads Tailscale and HTCondor when it starts.
- Port 127.0.0.1:9618 free: one EP per host, and it uses the whole machine. For the same reason
  an EP can't run on the AP host itself.

or in Docker, on any Linux host (for example NixOS):

- Docker that your user can run without `sudo`. Nothing else; no root, and no extra container
  privileges.
- Outbound internet access, as above.

## 1. Start the AP

Clone this repository on the AP host, then allow your user to manage Tailscale (once per host).
This is needed so the AP can publish itself to the tailnet with `tailscale serve`:

```
sudo tailscale set --operator=$USER
```

**On a supported distribution**, install and start the AP:

```
ap/install.sh
ap/start.sh --condor-dir ~/personal-htcondor/current-ap
```

**Anywhere else** (`install.sh` tells you when), use Docker. This runs the same scripts in an
AlmaLinux 9 container with host networking, as your user:

```
ap/docker.sh install
ap/docker.sh start
```

The AP runs in the foreground; use `tmux` or similar to keep it running after you log out.
Ctrl-C (or `docker stop personal-htcondor-ap`) shuts it down. Starting it again resumes the same
job queue. `install.sh` always creates a new, empty AP and points `~/personal-htcondor/current-ap`
at it.

At startup the AP:

- listens on 127.0.0.1:9618 only, and runs `ap/tailnet.sh` so that `tailscale serve` exposes
  port 9618 to your tailnet, and nothing else;
- creates an annex named `default-annex` and an EP token, which the EP bundle carries.

## 2. Build an EP bundle

With the AP running, on the AP host:

```
ap/make-ep-bundle.sh
```

This writes `~/personal-htcondor/ep-bundle-default-annex.tar.gz`. It contains your AP's tailnet
address, the annex setup, the EP launcher, and a token that lets an EP join your AP: **treat it
like a password**. One bundle can be used for any number of EP hosts. Rebuild it after reinstalling
the AP.

## 3. Run an EP

Create a Tailscale auth key in the admin console under
[Settings → Keys](https://login.tailscale.com/admin/settings/keys) (see
[Tailnet access](#tailnet-access-keys-and-policy) for the recommended settings; to tag it,
set up the tag in your tailnet policy first). Copy the bundle to the EP host, save the key in a
file only you can read, and run:

```
tar -xzf ep-bundle-default-annex.tar.gz
(umask 077 && cat > ~/my-ts-authkey)          # paste the key, then Ctrl-D
TS_AUTHKEY=file:$HOME/my-ts-authkey htc-ep/run-ep.sh
```

`TS_AUTHKEY` is either `file:<path>` as above, or the key itself (`TS_AUTHKEY=tskey-auth-...`),
which then ends up in your shell history. `run-ep.sh` then:

1. downloads Tailscale (version and checksum pinned) to `~/.cache/htc-ep`;
2. downloads HTCondor for this host (cached in `~/.hpc-annex`) and sets up the annex;
3. joins the tailnet as `htc-ep-<hostname>`, in userspace mode with in-memory state;
4. checks that it can reach the AP, and starts the forwarder on 127.0.0.1:9618;
5. runs the EP until it has been idle (no jobs) for an hour, or until you press Ctrl-C or send it
   SIGTERM.

On exit it shuts HTCondor down, which withdraws the EP from the AP, and leaves the tailnet. Its
working files are under `htc-ep/work-<hostname>-<pid>/`, including the HTCondor logs.

**Host-specific settings.** To change what this EP offers without changing the bundle, put
HTCondor configuration in a file on the EP host and pass it with `--config` (also accepted by
`docker-ep.sh`). For example, to keep one of the machine's GPUs out of every slot:

```
# ep-local.conf
OFFLINE_MACHINE_RESOURCE_GPUs = GPU-a325ade4
```

```
TS_AUTHKEY=file:$HOME/my-ts-authkey htc-ep/run-ep.sh --config ep-local.conf
```

The GPU ID must match what HTCondor detects. Once the EP is up, check on the AP with
`condor_status -af Name DetectedGPUs AssignedGPUs`: `DetectedGPUs` lists every GPU, and the
offline one should be missing from `AssignedGPUs`.

**In Docker.** On a host whose distribution the annex setup doesn't recognize (for example
NixOS), or wherever Docker is easier, run the same thing in a container instead:

```
TS_AUTHKEY=file:$HOME/my-ts-authkey htc-ep/docker-ep.sh
```

This builds a small AlmaLinux 9 image as your user and runs `run-ep.sh` in it, in the foreground,
as container `htc-ep-<hostname>`. Ctrl-C or `docker stop -t 90 htc-ep-<hostname>` stops it
gracefully. Downloads are cached on the host (`~/.cache/htc-ep`, `~/.hpc-annex`), and work
directories and logs land in `htc-ep/` as above. The container has its own network namespace, so
a Docker EP can also run on the AP host. Jobs that use `container_image` won't run in a Docker EP:
Apptainer needs user namespaces, which Docker blocks by default.

## Submit jobs

Use the condor tools on the AP host:

- native AP: `. ~/personal-htcondor/current-ap/condor.sh`, then `condor_submit`, `condor_q`, ...
- Docker AP: `ap/docker.sh shell` for an interactive shell, or `ap/docker.sh shell condor_q` for
  one command. Only `~/personal-htcondor` (and this repository's `ap/`) are visible inside the
  container, so keep your job directories under `~/personal-htcondor`.

`condor_status` lists the EPs connected to your AP. Every job is routed to `default-annex`
automatically.

**Test jobs.** At startup the AP writes ready-to-submit test jobs to
`~/personal-htcondor/test-job/` (any that are missing; your edits are kept). They match EPs of
either architecture:

- `hello.sub` reports where it ran.
- `gpu.sub` requests one GPU and reports which one HTCondor assigned (`Assigned GPUs`,
  `CUDA_VISIBLE_DEVICES`) next to `nvidia-smi`'s list of the machine's GPUs.

```
cd ~/personal-htcondor/test-job && condor_submit hello.sub       # native AP
ap/docker.sh shell bash -c 'cd ~/personal-htcondor/test-job && condor_submit hello.sub'   # Docker AP
cat ~/personal-htcondor/test-job/hello.out    # after it finishes: "Hello from <EP> (<arch>)"
```

**Hello world**

```
cd examples/hello_world        # Docker AP: copy it under ~/personal-htcondor first
condor_submit hello.sub
condor_q
cat hello.out                  # after it finishes: "I am running on <EP hostname>"
```

HTCondor requires jobs to run on the CPU architecture of the machine you submit from. To run on
EPs of another architecture (for example an aarch64 EP with an x86_64 AP), add
`requirements = Arch == "aarch64"` to the submit file.

**Multi-stage DAG**

`examples/dag_plot` squares a list of numbers, builds an R container, and plots the results. It
predates the tailnet setup and has not been tested with it.

```
cd examples/dag_plot           # Docker AP: copy it under ~/personal-htcondor first
condor_submit_dag square_and_plot.dag
```

Its `mksif` step runs `apptainer build` on the AP itself, so it needs Apptainer installed on the
AP host (it is not available inside the Docker AP). The `plot` step runs in that container, so
it needs EPs that can run Apptainer. `mksif` ignores build failures (`|| true`), so if
Apptainer is missing on the AP, the error shows up later, when `plot` can't find `r.sif`.

## Tailnet access: keys and policy

**Auth keys.** For EPs, generate keys that are:

- **Ephemeral**: EP nodes are removed from the tailnet when `run-ep.sh` exits (it logs out), or
  30–60 minutes after a crash.
- **Reusable**, if you want one key for several EPs.
- **Pre-approved**, if your tailnet requires device approval.
- **Tagged** `tag:htcondor-ep` (recommended), so EPs are owned by the tag rather than by you and
  your tailnet policy can limit them to the AP (below).

An auth key expires after the number of days you choose (1–90). Revoke it on the Keys page when
you no longer need it. Revoking a key does not disconnect EPs already running with it; stop those
EPs, or remove them on the Machines page.

**Policy.** If your tailnet still has the default allow-all rule, EPs can reach the AP (and
everything else) without changes; you only need the `tagOwners` entry below to create tagged
keys. To let tagged EPs reach only the AP's port 9618, add this to your
[tailnet policy file](https://login.tailscale.com/admin/acls/file), replacing the address with
your AP's (`tailscale ip -4` on the AP host):

```jsonc
{
  "tagOwners": {
    "tag:htcondor-ep": ["autogroup:admin"]
  },
  "hosts": {
    "htcondor-ap": "100.71.206.56"
  },
  "grants": [
    // EPs open every connection to the AP (the AP calls back through them), so
    // this one rule is all they need.
    { "src": ["tag:htcondor-ep"], "dst": ["htcondor-ap"], "ip": ["tcp:9618"] }
  ],
  "tests": [
    { "src": "tag:htcondor-ep", "accept": ["htcondor-ap:9618"], "deny": ["htcondor-ap:22"] }
  ]
}
```

Merge these into your existing sections rather than replacing them. The `tests` entry makes the
policy editor reject a policy that doesn't allow EPs to reach the AP, or allows them more than port
9618; its `deny` check fails (and the editor refuses to save) while an allow-all rule is still
present, so remove that rule or drop the `deny` line.

## Stopping and cleaning up

- **AP**: Ctrl-C, or `docker stop personal-htcondor-ap` for a Docker AP. The job queue is kept for
  the next start. `tailscale serve` keeps forwarding port 9618 (to nothing) until you turn it off
  with `tailscale serve --tcp=9618 off`.
- **EP**: Ctrl-C or SIGTERM; it also exits on its own after an hour without jobs. Each run leaves a
  `htc-ep/work-<hostname>-<pid>/` directory with its logs and a copy of the HTCondor tarball;
  delete old ones when you no longer need the logs.

## Troubleshooting

- **`install.sh`: unsupported Linux distribution**: use `ap/docker.sh install` instead.
- **`tailscale serve` failed / Access denied**: run `sudo tailscale set --operator=$USER` on the
  AP host once.
- **`run-ep.sh`: cannot reach the AP**: check that the AP is running, and that your tailnet policy
  lets the EP's tag reach the AP on port 9618.
- **`run-ep.sh`: annex setup failed / Unrecognized linux distro**: HTCondor has no EP build for
  that host.
- **Job stays idle**: `condor_status` should list the EP. Check the job's `Arch` requirement (see
  above), and `condor_q -better-analyze <job id>`.

## How it works

See [`notes.md`](notes.md) for the configuration details, and
[`backlog/decisions/`](backlog/decisions/) for why the network is set up this way.
