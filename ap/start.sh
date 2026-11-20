#!/usr/bin/env bash
#
# start.sh - Start a personal HTCondor Access Point (AP) from an existing,
# already-configured condor dir, and run it in the foreground. See
# install.sh.

set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") --condor-dir <path>

Start a personal HTCondor Access Point (AP) from an existing,
already-configured condor dir (see install.sh), and run it in the
foreground.

Options:
  --condor-dir <path>   The AP's condor install dir.
  --help                Print this help message and exit.
EOF
}

CONDOR_DIR=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --condor-dir)
            if [ $# -lt 2 ]; then
                echo "error: --condor-dir requires a path argument" >&2
                usage >&2
                exit 1
            fi
            CONDOR_DIR="$2"
            shift 2
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "$CONDOR_DIR" ]; then
    echo "error: --condor-dir is required" >&2
    usage >&2
    exit 1
fi

if [ ! -d "$CONDOR_DIR" ]; then
    echo "error: condor dir not found at $CONDOR_DIR" >&2
    exit 1
fi

if ! "$CONDOR_DIR/sbin/condor_master" -version >/dev/null 2>&1; then
    echo "error: the HTCondor binaries in $CONDOR_DIR cannot run on this host." >&2
    echo "       If it was installed with ap/docker.sh, start it with: ap/docker.sh start" >&2
    exit 1
fi

echo "==> Starting AP from $CONDOR_DIR"

echo "==> Updating shell environment with AP install"
# shellcheck disable=SC1091
. "$CONDOR_DIR/condor.sh"

# --- Run the AP ----------------------------------------------------------
# The AP listens on loopback only; expose it to the tailnet. Under
# ap/docker.sh, the host already did this before starting the container.
if [ "${PERSONAL_AP_IN_CONTAINER:-0}" != "1" ]; then
    "$(dirname "${BASH_SOURCE[0]}")/tailnet.sh"
fi

echo "==> Starting HTCondor AP"
"$CONDOR_DIR/sbin/condor_master" -f &
MASTER_PID=$!

# --- Mint the annex EP token ---------------------------------------------
# Wait up to 10 seconds for the AP to provision its signing key.
POOL_FILE="$CONDOR_DIR/local/passwords.d/POOL"
WAITED=0
while [ ! -f "$POOL_FILE" ] && [ "$WAITED" -lt 10 ]; do
    sleep 1
    WAITED=$((WAITED + 1))
done

# Mint the annex EPs' token here, on the AP. The bundled annex.token in the
# tarball has the wrong identity for the annex START policy; this
# replacement is minted offline against the AP's own signing key, using the
# pinned ANNEX_TOKEN_DOMAIN so it stays valid across AP resumes. See notes.md's
# "Explicit IDToken Creation". Its identity doesn't depend on the EP, so all
# EPs share it. Failures are logged but non-fatal, like annex preparation.
ANNEX_EP_TOKEN="$CONDOR_DIR/annex-ep.token"
rm -f "$ANNEX_EP_TOKEN"
echo "==> Minting the annex EP token"
ANNEX_TOKEN_DOMAIN="$(condor_config_val ANNEX_TOKEN_DOMAIN || true)"
if [ -z "$ANNEX_TOKEN_DOMAIN" ]; then
    # An empty domain would mint a token whose subject is "<user>@", which the
    # AP's annex jobs won't match.
    echo "WARNING: ANNEX_TOKEN_DOMAIN is not set; not minting the annex EP token"
elif (umask 077 && condor_token_create -key AP -identity "$(whoami)@$ANNEX_TOKEN_DOMAIN" \
    -authz READ -authz WRITE -authz ADVERTISE_STARTD -authz ADVERTISE_MASTER -authz DAEMON \
    >"$ANNEX_EP_TOKEN") && [ -s "$ANNEX_EP_TOKEN" ]; then
    echo "    Minted annex EP token at $ANNEX_EP_TOKEN"
else
    rm -f "$ANNEX_EP_TOKEN"
    echo "WARNING: could not mint the annex EP token"
fi

# --- Prepare the default annex ------------------------------------------
# Build the annex tarball for EPs at a well-known path (reachable via
# ~/personal-htcondor/current-ap). Failures here are logged but non-fatal:
# the AP keeps running regardless.
ANNEX_NAME="default-annex"
ANNEX_TARBALL="$CONDOR_DIR/annex-$ANNEX_NAME.tar"

# An annex "exists in the schedd" if any job in the queue has the
# hpc_annex_name attribute set to $ANNEX_NAME. This is a raw queue check; `htcondor annex
# status` proved unreliable (annex create then failed with "already created").
annex_exists_in_schedd() {
    local out
    out="$(condor_q -constraint "hpc_annex_name == \"$ANNEX_NAME\"" -af hpc_annex_name 2>/dev/null)" || return 1
    [ -n "$out" ]
}

prepare_annex() {
    echo "==> Waiting for the schedd to accept queries"
    local tries=0
    until condor_q >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ "$tries" -ge 30 ]; then
            echo "    schedd not reachable after 30s"
            return 1
        fi
        sleep 1
    done

    local verb
    if annex_exists_in_schedd; then
        if [ -s "$ANNEX_TARBALL" ]; then
            echo "==> Annex '$ANNEX_NAME' already exists with tarball at $ANNEX_TARBALL; nothing to do"
            return 0
        fi
        verb=add
    else
        verb=create
    fi
    # The CLI won't overwrite an existing tarball. One left over without its
    # annex job in the queue refers to a request that no longer exists.
    rm -f "$ANNEX_TARBALL"

    echo "==> Running 'htcondor annex $verb $ANNEX_NAME'"
    # The CLI writes annex-<name>.tar into its working directory.
    (cd "$CONDOR_DIR" && htcondor annex "$verb" --idle-time 3600 "$ANNEX_NAME") || return 1

    if [ ! -s "$ANNEX_TARBALL" ]; then
        echo "    expected tarball $ANNEX_TARBALL was not produced"
        return 1
    fi
    echo "==> Annex tarball at $ANNEX_TARBALL"
}

if ! prepare_annex; then
    echo "WARNING: could not prepare annex '$ANNEX_NAME'; the AP is still running"
fi

echo "==> To interact with this AP, source the condor env file at $CONDOR_DIR/condor.sh:"
echo "    '. $CONDOR_DIR/condor.sh'"
echo "    (if the AP runs via ap/docker.sh, use 'ap/docker.sh shell' instead)"

wait "$MASTER_PID"
