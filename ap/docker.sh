#!/usr/bin/env bash
#
# docker.sh - Run the personal AP's install.sh and start.sh inside an
# AlmaLinux 9 container, for hosts without a native HTCondor build (e.g.
# NixOS). The container uses the host's network, runs as the invoking user,
# and sees ~/personal-htcondor and this directory at the same paths as the
# host, so the install is usable from either side.

set -euo pipefail

AP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/personal-htcondor"
IMAGE="personal-htcondor-ap"
CONTAINER="personal-htcondor-ap"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") <command> [args]

Commands:
  install          Build the container image and install a fresh AP under
                   $STATE_DIR (see install.sh).
  start            Run the current AP ($STATE_DIR/current-ap) in the
                   foreground in container '$CONTAINER' (see start.sh).
  shell [cmd...]   With no arguments, open an interactive shell in the
                   running AP container with the condor tools set up.
                   Otherwise run cmd there, e.g. '$(basename "${BASH_SOURCE[0]}") shell condor_q'.
  help             Print this help message and exit.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

build_image() {
    echo "==> Building container image $IMAGE"
    docker build --quiet --tag "$IMAGE" \
        --build-arg USER_NAME="$(id -un)" \
        --build-arg USER_UID="$(id -u)" \
        --build-arg USER_GID="$(id -g)" \
        --build-arg USER_HOME="$HOME" \
        "$AP_DIR" >/dev/null
}

# Resolve the current AP install, failing if there isn't one.
current_condor_dir() {
    local link="$STATE_DIR/current-ap"
    [ -L "$link" ] || die "no AP installed at $link; run '$0 install' first"
    readlink -f "$link"
}

container_running() {
    [ "$(docker container inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]
}

RUN_ARGS=(--network host -v "$STATE_DIR:$STATE_DIR" -v "$AP_DIR:$AP_DIR:ro")

cmd_install() {
    [ $# -eq 0 ] || die "'install' takes no arguments; the AP is installed under $STATE_DIR"
    build_image
    mkdir -p "$STATE_DIR"
    docker run --rm "${RUN_ARGS[@]}" "$IMAGE" "$AP_DIR/install.sh"
}

cmd_start() {
    [ $# -eq 0 ] || die "'start' takes no arguments"
    local condor_dir
    condor_dir="$(current_condor_dir)"
    container_running && die "container '$CONTAINER' is already running"
    build_image
    docker run --rm --init --name "$CONTAINER" "${RUN_ARGS[@]}" "$IMAGE" \
        "$AP_DIR/start.sh" --condor-dir "$condor_dir"
}

cmd_shell() {
    local condor_dir tty=()
    condor_dir="$(current_condor_dir)"
    container_running || die "container '$CONTAINER' is not running; start it with '$0 start'"
    [ -t 0 ] && tty=(-t)
    if [ $# -eq 0 ]; then
        docker exec -it "$CONTAINER" bash --rcfile "$condor_dir/condor.sh" -i
    else
        # shellcheck disable=SC2016 # expanded by the container's bash
        docker exec -i "${tty[@]}" "$CONTAINER" \
            bash -O expand_aliases -c '. "$1/condor.sh"; shift; eval "$(printf "%q " "$@")"' \
            _ "$condor_dir" "$@"
    fi
}

command -v docker >/dev/null || die "docker is not installed or not on PATH"

case "${1:-help}" in
    install) shift && cmd_install "$@" ;;
    start) shift && cmd_start "$@" ;;
    shell) shift && cmd_shell "$@" ;;
    help | --help | -h) usage ;;
    *)
        usage >&2
        exit 1
        ;;
esac
