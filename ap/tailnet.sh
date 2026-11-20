#!/usr/bin/env bash
#
# tailnet.sh - Expose the AP (listening on 127.0.0.1:9618) to the tailnet, and
# only the tailnet, with `tailscale serve`. Idempotent; run on the AP host
# (not inside the AP container) before starting the AP. Prints the AP's
# tailnet IPv4 address as its last line, as "AP_TAILNET_IP=<ip>".

set -euo pipefail

PORT=9618
TARGET="tcp://127.0.0.1:$PORT"

die() {
    echo "error: $*" >&2
    exit 1
}

command -v tailscale >/dev/null ||
    die "tailscale is not installed or not on PATH; install it and join this host to your tailnet"

if ! AP_IP="$(tailscale ip -4 2>/dev/null)" || [ -z "$AP_IP" ]; then
    die "tailscale is not connected; run 'tailscale up' (or check 'tailscale status')"
fi

if tailscale serve status --json 2>/dev/null | grep -q "\"TCPForward\": \"127.0.0.1:$PORT\""; then
    echo "==> tailscale serve already exposes port $PORT"
else
    echo "==> Exposing $TARGET to the tailnet on port $PORT"
    if ! tailscale serve --bg --tcp "$PORT" "$TARGET"; then
        echo "error: 'tailscale serve' failed. If it reported 'Access denied', allow your" >&2
        echo "       user to manage Tailscale once with: sudo tailscale set --operator=\$USER" >&2
        exit 1
    fi
fi

echo "AP_TAILNET_IP=$AP_IP"
