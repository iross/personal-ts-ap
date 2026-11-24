#!/usr/bin/env bash
#
# run-test-ep.sh - Run an EP bundle in a Docker container that stands in for
# an unprivileged HPC node: the tailnet range is unreachable from the kernel
# (so only run-ep.sh's userspace tailscaled can reach the AP), and run-ep.sh
# runs as a non-root user without capabilities. Each container has its own
# network namespace, so several of them act as separate EP hosts.

set -euo pipefail

IMAGE="almalinux:9.8-20261027@sha256:245f8aab832fe800aa42bdab5fad75ebbd8e0b4c9f24820a83c638b177857ae2"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") <bundle.tar.gz> <authkey-file> [name]

Start a detached container <name> (default: htc-test-ep; also its hostname)
that runs the bundle's htc-ep/run-ep.sh with TS_AUTHKEY=file:<authkey-file>.

  docker logs -f <name>          follow the EP
  docker stop -t 90 <name>       stop it (run-ep.sh shuts down gracefully)
  docker rm <name>               remove it afterwards
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

[ $# -ge 2 ] && [ $# -le 3 ] || {
    usage >&2
    exit 1
}
BUNDLE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
KEY_FILE="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
NAME="${3:-htc-test-ep}"
[ -f "$BUNDLE" ] || die "bundle not found: $1"
[ -s "$KEY_FILE" ] || die "auth key file not found or empty: $2"
command -v docker >/dev/null || die "docker is not installed or not on PATH"

# Runs as root only to block the tailnet route and create the user (NET_ADMIN
# is for the route); setpriv then drops to the user, and run-ep.sh becomes
# PID 1, so `docker stop` signals it directly, as on a real host.
# shellcheck disable=SC2016 # expanded inside the container
INIT='set -euo pipefail
dnf -y -q install iproute util-linux >/dev/null
ip route add unreachable 100.64.0.0/10
useradd -m ep
install -o ep -m 600 /run/secrets/ts-authkey /home/ep/ts-authkey
cd /home/ep
tar -xzf /bundle/ep-bundle.tar.gz
chown -R ep:ep htc-ep
exec setpriv --reuid=ep --regid=ep --init-groups env HOME=/home/ep USER=ep \
    TS_AUTHKEY=file:/home/ep/ts-authkey htc-ep/run-ep.sh'

docker run -d --name "$NAME" --hostname "$NAME" --cap-add NET_ADMIN \
    -v "$BUNDLE:/bundle/ep-bundle.tar.gz:ro" \
    -v "$KEY_FILE:/run/secrets/ts-authkey:ro" \
    "$IMAGE" bash -c "$INIT" >/dev/null
echo "Started EP container '$NAME'; follow it with: docker logs -f $NAME"
