#!/usr/bin/env bash
#
# make-ep-bundle.sh - Package everything an EP needs to join this AP over the
# tailnet: the annex tarball, the EP token, the AP's tailnet address, and the
# EP launcher (ep/run-ep.sh). Run on the AP host while the AP is running (it
# writes the annex tarball and token at startup); works for both native and
# ap/docker.sh installs.

set -euo pipefail

AP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EP_SRC_DIR="$(cd "$AP_DIR/../ep" && pwd)"
STATE_DIR="$HOME/personal-htcondor"
ANNEX_NAME="default-annex"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [--output <path>]

Write an EP bundle for the current AP ($STATE_DIR/current-ap). Copy it to
the to-be-EP, then run there:

  tar -xzf <bundle> && TS_AUTHKEY=<key> htc-ep/run-ep.sh

The bundle contains the AP's EP token: keep it private.

Options:
  --output <path>   Where to write the bundle
                    (default: $STATE_DIR/ep-bundle-$ANNEX_NAME.tar.gz).
  --help            Print this help message and exit.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

OUTPUT="$STATE_DIR/ep-bundle-$ANNEX_NAME.tar.gz"
while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --output)
            [ $# -ge 2 ] || die "--output requires a path argument"
            OUTPUT="$2"
            shift 2
            ;;
        *)
            usage >&2
            exit 1
            ;;
    esac
done

[ -L "$STATE_DIR/current-ap" ] || die "no AP installed at $STATE_DIR/current-ap; run ap/install.sh (or ap/docker.sh install) first"
CONDOR_DIR="$(readlink -f "$STATE_DIR/current-ap")"
ANNEX_TARBALL="$CONDOR_DIR/annex-$ANNEX_NAME.tar"
EP_TOKEN="$CONDOR_DIR/annex-ep.token"
for f in "$ANNEX_TARBALL" "$EP_TOKEN"; do
    [ -s "$f" ] || die "$f is missing; start the AP (ap/start.sh or ap/docker.sh start) and check its log"
done

AP_TAILNET_IP="$("$AP_DIR/tailnet.sh" | sed -n 's/^AP_TAILNET_IP=//p')"
[ -n "$AP_TAILNET_IP" ] || die "could not determine the AP's tailnet address"

STAGE="$(mktemp -d)"
trap 'rm -r "$STAGE"' EXIT
mkdir "$STAGE/htc-ep"
cp "$EP_SRC_DIR/run-ep.sh" "$EP_SRC_DIR/forward.py" "$ANNEX_TARBALL" "$EP_TOKEN" "$STAGE/htc-ep/"
cat >"$STAGE/htc-ep/ep.env" <<EOF
AP_TAILNET_IP=$AP_TAILNET_IP
ANNEX_NAME=$ANNEX_NAME
EOF

(umask 077 && tar -czf "$OUTPUT" -C "$STAGE" htc-ep)
echo "==> Wrote $OUTPUT (AP at $AP_TAILNET_IP; contains the EP token, keep it private)"
echo "    On the EP: tar -xzf $(basename "$OUTPUT") && TS_AUTHKEY=<key> htc-ep/run-ep.sh"
