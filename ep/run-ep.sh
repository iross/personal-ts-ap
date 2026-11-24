#!/usr/bin/env bash
#
# run-ep.sh - Run an HTCondor annex EP for a personal AP on your tailnet,
# without root. Joins this host to the tailnet with an unprivileged
# (userspace) tailscaled, forwards 127.0.0.1:9618 to the AP through it, and
# runs the annex until it is idle for the annex's idle time, or until
# interrupted. Leaves the tailnet on exit. Unpacked from the bundle that
# ap/make-ep-bundle.sh writes.

set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AP_PORT=9618
TAILSCALE_VERSION="1.104.7"
declare -A TAILSCALE_SHA256=(
    [amd64]=e56693ff74a64f2591b7e819c280635a100aae1ddfb0ef058fcd052b7cd8d16c
    [arm64]=d6bed2720310b328b861f943d7b4016c5358a9bad60575eb51e8143b79068484
)

usage() {
    cat <<EOF
Usage: TS_AUTHKEY=<key> $(basename "${BASH_SOURCE[0]}") [--config <file>]

Run an annex EP for the AP this bundle was made for, using this whole host.

Options:
  --config <file>  HTCondor configuration to add to this EP, for settings
                   specific to this host, e.g.
                   OFFLINE_MACHINE_RESOURCE_GPUs = GPU-a325ade4
                   to keep a GPU out of every slot.
  --help           Print this help message and exit.

Environment:
  TS_AUTHKEY   Tailscale auth key for joining the tailnet (an ephemeral,
               pre-approved key is recommended), or "file:<path>" to read it
               from a file.

Only one EP can run per host: it needs 127.0.0.1:$AP_PORT for its forwarder.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "$(date '+%F %T') ==> $*"
}

check_prerequisites() {
    [ -n "${TS_AUTHKEY:-}" ] ||
        die "TS_AUTHKEY is not set; create an auth key in the Tailscale admin console (Settings > Keys) and rerun as: TS_AUTHKEY=<key> $0"
    command -v curl >/dev/null || die "curl is required to download Tailscale and HTCondor"
    command -v python3 >/dev/null || die "python3 (3.6 or newer) is required for the forwarder"
    python3 -c 'import sys; sys.exit(sys.version_info < (3, 6))' ||
        die "python3 is older than 3.6: $(python3 --version 2>&1)"
    command -v setsid >/dev/null || die "setsid (util-linux) is required"
    case "$(uname -m)" in
        x86_64) TS_ARCH=amd64 ;;
        aarch64) TS_ARCH=arm64 ;;
        *) die "unsupported CPU architecture: $(uname -m) (supported: x86_64, aarch64)" ;;
    esac
    if (exec 3<>"/dev/tcp/127.0.0.1/$AP_PORT") 2>/dev/null; then
        die "127.0.0.1:$AP_PORT is already in use on this host (another EP, or the AP itself); only one EP can run per host"
    fi
}

# Download the static tailscale binaries into a per-user cache, verifying the
# pinned checksum, and set TS_BIN_DIR.
fetch_tailscale() {
    local name="tailscale_${TAILSCALE_VERSION}_${TS_ARCH}"
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/htc-ep"
    TS_BIN_DIR="$cache/$name"
    [ -x "$TS_BIN_DIR/tailscaled" ] && return 0
    mkdir -p "$cache"
    log "Downloading Tailscale $TAILSCALE_VERSION ($TS_ARCH)"
    curl -fsSL -o "$cache/$name.tgz" "https://pkgs.tailscale.com/stable/$name.tgz" ||
        die "failed to download Tailscale from pkgs.tailscale.com"
    echo "${TAILSCALE_SHA256[$TS_ARCH]}  $cache/$name.tgz" | sha256sum -c --quiet - ||
        die "checksum mismatch for $cache/$name.tgz; refusing to use it"
    tar -xzf "$cache/$name.tgz" -C "$cache"
    rm -f "$cache/$name.tgz"
}

# Print the PIDs of this EP's HTCondor processes whose executable path matches
# the glob $1. condor_master gives each daemon its own process group, so they
# are found by executable path (all under $WORK) rather than by group.
htcondor_pids() {
    local p exe
    for p in /proc/[0-9]*; do
        exe="$(readlink "$p/exe" 2>/dev/null)" || continue
        # shellcheck disable=SC2053 # $1 is a glob on purpose
        [[ "$exe" == "$WORK"/* && "$exe" == $1 ]] && echo "${p#/proc/}"
    done
    return 0
}

# Shut HTCondor down gracefully through its master, so the EP's ads are
# withdrawn from the AP, then kill anything left after 60 seconds.
stop_htcondor() {
    local masters
    masters="$(htcondor_pids '*/condor_master')"
    if [ -n "$masters" ]; then
        log "Stopping HTCondor"
        # shellcheck disable=SC2086 # one PID per word
        kill -TERM $masters 2>/dev/null || true
        for _ in $(seq 60); do
            [ -z "$(htcondor_pids '*')" ] && break
            sleep 1
        done
        # shellcheck disable=SC2046 # one PID per word
        kill -KILL $(htcondor_pids '*') 2>/dev/null || true
    fi
    if [ -n "${PILOT_PID:-}" ]; then
        kill -TERM -- "-$PILOT_PID" 2>/dev/null || true
    fi
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM HUP
    # Best effort from here: after a hangup, even logging to the terminal
    # fails, and that must not stop the cleanup.
    set +e
    stop_htcondor
    [ -n "${FORWARDER_PID:-}" ] && kill "$FORWARDER_PID" 2>/dev/null || true
    if [ -n "${TAILSCALED_PID:-}" ]; then
        log "Leaving the tailnet"
        "${TS[@]}" logout >/dev/null 2>&1 || true
        kill "$TAILSCALED_PID" 2>/dev/null || true
    fi
    rm -f "${AUTHKEY_FILE:-}"
    if [ -n "${SOCKET_DIR:-}" ]; then
        rm -r "$SOCKET_DIR" 2>/dev/null || true
    fi
    exit "$status"
}

join_tailnet() {
    log "Starting userspace tailscaled (log: $WORK/tailscaled.log)"
    # Unix socket paths are limited to ~108 bytes, so the socket can't live in
    # $WORK, which may be deep (e.g. under a scratch filesystem).
    SOCKET_DIR="$(mktemp -d /tmp/htc-ep.XXXXXX)"
    local socket="$SOCKET_DIR/tailscaled.sock"
    # Own session, so a terminal Ctrl-C doesn't kill it before cleanup logs out.
    setsid "$TS_BIN_DIR/tailscaled" --tun=userspace-networking --state=mem: \
        --statedir="$WORK/tailscale" --socket="$socket" \
        >"$WORK/tailscaled.log" 2>&1 &
    TAILSCALED_PID=$!
    TS=("$TS_BIN_DIR/tailscale" --socket="$socket")
    for _ in $(seq 30); do
        [ -S "$socket" ] && break
        sleep 1
    done
    [ -S "$socket" ] || die "tailscaled did not start; see $WORK/tailscaled.log"

    # Pass the key through a private file so it never shows up in `ps`.
    AUTHKEY_FILE="$WORK/authkey"
    if [[ "$TS_AUTHKEY" == file:* ]]; then
        (umask 077 && cp "${TS_AUTHKEY#file:}" "$AUTHKEY_FILE") || die "cannot read auth key file ${TS_AUTHKEY#file:}"
    else
        (umask 077 && printf '%s' "$TS_AUTHKEY" >"$AUTHKEY_FILE")
    fi
    log "Joining the tailnet as htc-ep-$SHORT_HOST"
    "${TS[@]}" up --auth-key="file:$AUTHKEY_FILE" --hostname="htc-ep-$SHORT_HOST" --timeout=60s ||
        die "'tailscale up' failed; check that TS_AUTHKEY is a valid, unexpired auth key"
    rm -f "$AUTHKEY_FILE"

    log "Checking that the AP ($AP_TAILNET_IP) is reachable"
    "${TS[@]}" ping -c 5 --until-direct=false "$AP_TAILNET_IP" >/dev/null ||
        die "cannot reach the AP at $AP_TAILNET_IP over the tailnet; is the AP running, and do your tailnet's access rules allow this node to reach it?"
}

start_forwarder() {
    setsid python3 "$BUNDLE_DIR/forward.py" "$AP_PORT" "$AP_TAILNET_IP" "$AP_PORT" "${TS[@]}" \
        >"$WORK/forward.log" 2>&1 &
    FORWARDER_PID=$!
    for _ in $(seq 10); do
        (exec 3<>"/dev/tcp/127.0.0.1/$AP_PORT") 2>/dev/null && return 0
        kill -0 "$FORWARDER_PID" 2>/dev/null || break
        sleep 1
    done
    die "the forwarder did not start; see $WORK/forward.log"
}

# Unpack the annex and download HTCondor for this host. Needs no tailnet, so
# it runs first: an unsupported host fails before joining the tailnet.
prepare_annex() {
    ANNEX_DIR="$WORK/annex-$ANNEX_NAME"
    tar -xf "$BUNDLE_DIR/annex-$ANNEX_NAME.tar" -C "$WORK"
    (cd "$ANNEX_DIR" && bash annex-setup.sh) ||
        die "annex setup failed (see the output above); an 'Unrecognized linux distro' means HTCondor has no EP build for this host"
    install -m 600 "$BUNDLE_DIR/annex-ep.token" "$ANNEX_DIR/annex.token"
    # annex-job-setup.sh copies this file into the EP's config directory.
    if [ -n "$EP_CONFIG" ]; then
        log "Adding EP configuration from $EP_CONFIG"
        {
            printf '\n# From %s (run-ep.sh --config)\n' "$EP_CONFIG"
            cat "$EP_CONFIG"
        } >>"$ANNEX_DIR/20-annex-pilot-instance"
    fi
}

run_annex() {
    log "Starting the EP (logs under $ANNEX_DIR)"
    # Run in its own process group so cleanup can stop all of HTCondor.
    # Without SLURM_JOBID, hpc.slurm runs the EP directly on this host.
    (cd "$ANNEX_DIR" && unset SLURM_JOBID && exec setsid bash hpc.slurm) &
    PILOT_PID=$!
    wait "$PILOT_PID"
}

EP_CONFIG=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --config)
            [ $# -ge 2 ] || die "--config requires a file argument"
            [ -f "$2" ] && [ -r "$2" ] || die "--config file not found or not readable: $2"
            EP_CONFIG="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
            shift 2
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

# shellcheck source=/dev/null # written by ap/make-ep-bundle.sh
. "$BUNDLE_DIR/ep.env"
check_prerequisites
fetch_tailscale

SHORT_HOST="$(uname -n | cut -d. -f1)"
WORK="$BUNDLE_DIR/work-$SHORT_HOST-$$"
mkdir -p "$WORK"
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# A closed terminal or dropped SSH session; without this, HTCondor (in its
# own session) would keep running with no one to stop it.
trap 'exit 129' HUP

prepare_annex
join_tailnet
start_forwarder
run_annex
log "EP finished"
