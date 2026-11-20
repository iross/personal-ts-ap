#!/usr/bin/env bash
#
# docker-ep.sh - Run this bundle's run-ep.sh in an AlmaLinux 9 container, for
# EP hosts without a distribution HTCondor builds for (e.g. NixOS), or where
# Docker is simply easier. The container runs as the invoking user with no
# extra privileges; run-ep.sh joins the tailnet from inside it as usual.

set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="htc-ep"
BASE_IMAGE="almalinux:9.8-20261027@sha256:245f8aab832fe800aa42bdab5fad75ebbd8e0b4c9f24820a83c638b177857ae2"
SHORT_HOST="$(uname -n | cut -d. -f1)"
CONTAINER="htc-ep-$SHORT_HOST"

usage() {
    cat <<EOF
Usage: TS_AUTHKEY=file:<path> $(basename "${BASH_SOURCE[0]}")

Run an EP for this bundle's AP in a Docker container named '$CONTAINER',
using this host's resources. Same as run-ep.sh otherwise: runs in the
foreground until idle for the annex's idle time, Ctrl-C, or
'docker stop -t 90 $CONTAINER'.

Environment:
  TS_AUTHKEY   Tailscale auth key, as "file:<path>" (recommended) or the key
               itself (then visible in 'docker inspect').
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    "") ;;
    *)
        usage >&2
        exit 1
        ;;
esac

command -v docker >/dev/null || die "docker is not installed or not on PATH"
[ -n "${TS_AUTHKEY:-}" ] ||
    die "TS_AUTHKEY is not set; create an auth key in the Tailscale admin console (Settings > Keys) and rerun as: TS_AUTHKEY=file:<path> $0"

KEY_ARGS=()
if [[ "$TS_AUTHKEY" == file:* ]]; then
    KEY_FILE="${TS_AUTHKEY#file:}"
    [ -r "$KEY_FILE" ] || die "cannot read auth key file $KEY_FILE"
    KEY_FILE="$(cd "$(dirname "$KEY_FILE")" && pwd)/$(basename "$KEY_FILE")"
    KEY_ARGS=(-v "$KEY_FILE:/run/secrets/ts-authkey:ro" -e TS_AUTHKEY=file:/run/secrets/ts-authkey)
else
    KEY_ARGS=(-e TS_AUTHKEY)
fi

echo "==> Building container image $IMAGE"
docker build --quiet --tag "$IMAGE" \
    --build-arg USER_NAME="$(id -un)" \
    --build-arg USER_UID="$(id -u)" \
    --build-arg USER_GID="$(id -g)" \
    --build-arg USER_HOME="$HOME" \
    - >/dev/null <<EOF
FROM $BASE_IMAGE
RUN dnf -y install findutils hostname procps-ng python3 util-linux which && dnf clean all
ARG USER_NAME
ARG USER_UID
ARG USER_GID
ARG USER_HOME
RUN { getent group "\$USER_GID" >/dev/null || groupadd -g "\$USER_GID" "\$USER_NAME"; } \\
    && useradd -M -u "\$USER_UID" -g "\$USER_GID" -d "\$USER_HOME" "\$USER_NAME" \\
    && mkdir -p "\$USER_HOME" && chown "\$USER_UID:\$USER_GID" "\$USER_HOME"
USER \$USER_NAME
WORKDIR \$USER_HOME
EOF

# Downloads are cached on the host: Tailscale by run-ep.sh, HTCondor by the
# annex setup. The bundle directory holds each run's work directory and logs.
mkdir -p "$HOME/.cache/htc-ep" "$HOME/.hpc-annex"
echo "==> Starting EP container $CONTAINER"
exec docker run --rm --init --name "$CONTAINER" --hostname "$SHORT_HOST" \
    -v "$BUNDLE_DIR:$BUNDLE_DIR" \
    -v "$HOME/.cache/htc-ep:$HOME/.cache/htc-ep" \
    -v "$HOME/.hpc-annex:$HOME/.hpc-annex" \
    "${KEY_ARGS[@]}" \
    "$IMAGE" "$BUNDLE_DIR/run-ep.sh"
