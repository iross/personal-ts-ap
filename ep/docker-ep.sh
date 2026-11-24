#!/usr/bin/env bash
#
# docker-ep.sh - Run run-ep.sh (next to this script) in an AlmaLinux 9
# container, for EP hosts without a distribution HTCondor builds for (e.g.
# NixOS), or where Docker is simply easier. The container runs as the invoking
# user with no extra privileges; for the personal AP, run-ep.sh joins the
# tailnet from inside it as usual.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="htc-ep"
BASE_IMAGE="almalinux:9.8-20261027@sha256:245f8aab832fe800aa42bdab5fad75ebbd8e0b4c9f24820a83c638b177857ae2"
SHORT_HOST="$(uname -n | cut -d. -f1)"
CONTAINER="htc-ep-$SHORT_HOST"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [--config <file>] annex-NAME.tar
       TS_AUTHKEY=file:<path> $(basename "${BASH_SOURCE[0]}") [--config <file>]

Run run-ep.sh in a Docker container named '$CONTAINER', using this host's
resources. Same as run-ep.sh otherwise (see its --help): runs in the
foreground until idle for the annex's idle time, Ctrl-C, or
'docker stop -t 90 $CONTAINER'.

Options:
  --config <file>  HTCondor configuration to add to this EP (see run-ep.sh
                   --help).
  --help           Print this help message and exit.

Environment:
  TS_AUTHKEY   Personal AP bundles only: Tailscale auth key, as
               "file:<path>" (recommended) or the key itself (then visible in
               'docker inspect').
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

CONFIG_ARGS=()
ANNEX_TAR=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --config)
            [ $# -ge 2 ] || die "--config requires a file argument"
            [ -f "$2" ] && [ -r "$2" ] || die "--config file not found or not readable: $2"
            CONFIG_FILE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
            CONFIG_ARGS=(--config /run/ep-config.conf)
            shift 2
            ;;
        -*)
            usage >&2
            exit 1
            ;;
        *)
            [ -z "$ANNEX_TAR" ] || die "only one annex tarball can be given"
            [ -f "$1" ] && [ -r "$1" ] || die "annex tarball not found or not readable: $1"
            ANNEX_TAR="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
            shift
            ;;
    esac
done

command -v docker >/dev/null || die "docker is not installed or not on PATH"

# run-ep.sh checks the tarball and the bundle; here, only what the container
# needs: the directory holding the tarball (and the EP's work directory), and
# for the personal AP, the auth key.
MOUNT_ARGS=(-v "$SCRIPT_DIR:$SCRIPT_DIR")
KEY_ARGS=()
if [ -n "$ANNEX_TAR" ]; then
    TAR_DIR="$(dirname "$ANNEX_TAR")"
    [ "$TAR_DIR" = "$SCRIPT_DIR" ] || MOUNT_ARGS+=(-v "$TAR_DIR:$TAR_DIR")
else
    [ -f "$SCRIPT_DIR/ep.env" ] ||
        die "give the annex-NAME.tar that 'htcondor annex create' wrote (see --help); without it, docker-ep.sh must be run from a personal AP bundle"
    [ -n "${TS_AUTHKEY:-}" ] ||
        die "TS_AUTHKEY is not set; create an auth key in the Tailscale admin console (Settings > Keys) and rerun as: TS_AUTHKEY=file:<path> $0"
    if [[ "$TS_AUTHKEY" == file:* ]]; then
        KEY_FILE="${TS_AUTHKEY#file:}"
        [ -r "$KEY_FILE" ] || die "cannot read auth key file $KEY_FILE"
        KEY_FILE="$(cd "$(dirname "$KEY_FILE")" && pwd)/$(basename "$KEY_FILE")"
        KEY_ARGS=(-v "$KEY_FILE:/run/secrets/ts-authkey:ro" -e TS_AUTHKEY=file:/run/secrets/ts-authkey)
    else
        KEY_ARGS=(-e TS_AUTHKEY)
    fi
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
# annex setup. The annex tarball's directory holds each run's work directory.
mkdir -p "$HOME/.cache/htc-ep" "$HOME/.hpc-annex"
echo "==> Starting EP container $CONTAINER"
exec docker run --rm --init --name "$CONTAINER" --hostname "$SHORT_HOST" \
    "${MOUNT_ARGS[@]}" \
    -v "$HOME/.cache/htc-ep:$HOME/.cache/htc-ep" \
    -v "$HOME/.hpc-annex:$HOME/.hpc-annex" \
    ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} \
    ${CONFIG_FILE:+-v "$CONFIG_FILE:/run/ep-config.conf:ro"} \
    "$IMAGE" "$SCRIPT_DIR/run-ep.sh" ${CONFIG_ARGS[@]+"${CONFIG_ARGS[@]}"} ${ANNEX_TAR:+"$ANNEX_TAR"}
