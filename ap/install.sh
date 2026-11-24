#!/usr/bin/env bash
#
# install.sh - Install a personal HTCondor Access Point (AP) from the HTCondor
# tarball built for this host's Linux distribution (downloaded if not already
# present). See start.sh to run the installed AP. On hosts without a native
# HTCondor build, use ap/docker.sh instead.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONDOR_VERSION="25.15.15"
DOWNLOAD_BASE="https://htcss-downloads.chtc.wisc.edu/tarball/25.x/$CONDOR_VERSION/release"
BASE_DIR_DEFAULT="$HOME/personal-htcondor"

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS]

Install a personal HTCondor $CONDOR_VERSION Access Point (AP) into a new
directory under <base-dir>, downloading the HTCondor tarball for this host's
Linux distribution and CPU architecture if it is not already there. Leaves a
symlink to the install at ~/personal-htcondor/current-ap and prints the install
directory as "CONDOR_DIR=<path>" as its last line of output; see start.sh to
run the installed AP.

Hosts without a native HTCondor build (e.g. NixOS) are refused; run the AP in
a container with ap/docker.sh instead.

Options:
  --base-dir <path>       Base directory for the AP install
                          (default: ${BASE_DIR_DEFAULT}).
  --help                  Print this help message and exit.
EOF
}

die() {
    echo "error: $*" >&2
    exit 1
}

die_unsupported() {
    echo "error: $1" >&2
    echo "       HTCondor $CONDOR_VERSION has no native build for this host." >&2
    echo "       Run the AP in a container instead: $REPO_DIR/docker.sh install" >&2
    exit 1
}

# Print this host's HTCondor platform name (e.g. "x86_64_AlmaLinux9"), or fail
# with a pointer to the container option.
detect_platform() {
    local arch id version_id pretty major distro
    arch="$(uname -m)"
    [ -r /etc/os-release ] || die_unsupported "/etc/os-release not found"
    # shellcheck source=/dev/null # host file, not part of this repo
    IFS='|' read -r id version_id pretty < <(. /etc/os-release && echo "${ID:-}|${VERSION_ID:-}|${PRETTY_NAME:-}")
    major="${version_id%%.*}"
    case "$id" in
        almalinux | rocky | rhel | centos) distro="AlmaLinux$major" ;;
        debian) distro="Debian$major" ;;
        ubuntu) distro="Ubuntu$major" ;;
        amzn) distro="AmazonLinux$major" ;;
        opensuse-leap) distro="openSUSE$major" ;;
        *) die_unsupported "unsupported Linux distribution: ${pretty:-$id}" ;;
    esac
    echo "${arch}_${distro}"
}

# Download the tarball for $1 (platform name) into $BASE_DIR unless present,
# and print its path.
fetch_tarball() {
    local platform="$1" name url path
    name="condor-$CONDOR_VERSION-$platform-stripped.tar.gz"
    url="$DOWNLOAD_BASE/$name"
    path="$BASE_DIR/$name"
    if [ ! -f "$path" ]; then
        if ! curl -fsSI -o /dev/null "$url"; then
            die_unsupported "no HTCondor tarball for $platform at $url"
        fi
        echo "==> Downloading $url" >&2
        if ! curl -fsSL -o "$path.part" "$url"; then
            rm -f "$path.part"
            die "failed to download $url"
        fi
        mv "$path.part" "$path"
    fi
    echo "$path"
}

BASE_DIR="$BASE_DIR_DEFAULT"

while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --base-dir)
            if [ $# -lt 2 ]; then
                echo "error: --base-dir requires a path argument" >&2
                usage >&2
                exit 1
            fi
            BASE_DIR="$2"
            shift 2
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

PLATFORM="$(detect_platform)"
echo "==> Host platform: $PLATFORM"

# The `htcondor annex` CLI that start.sh uses is Python.
command -v python3 >/dev/null || die "python3 is required (for the htcondor CLI); install it and rerun"
echo "==> Using base directory $BASE_DIR"
mkdir -p "$BASE_DIR"
TARBALL_PATH="$(fetch_tarball "$PLATFORM")"

# Use a randomly-suffixed install directory.
SUFFIX="$RANDOM$RANDOM"
CONDOR_DIR="$BASE_DIR/condor-$SUFFIX"

# --- Install HTCondor --------------------------------------------------
# Unpack the tarball and configure it as a single-user AP.
echo "==> Unpacking HTCondor to $CONDOR_DIR"
mkdir -p "$CONDOR_DIR"
tar -xf "$TARBALL_PATH" -C "$CONDOR_DIR" --strip-components=1

echo "==> Configuring HTCondor as a single-user AP"
(cd "$CONDOR_DIR" && bin/make-ap-from-tarball)

# Pin daemon names, which otherwise default to this node's FULL_HOSTNAME,
# so they stay consistent if the AP is resumed on a different host. See
# notes.md's "Daemon Name Pinning".
cat >"$CONDOR_DIR/local/config.d/12-ap-trust-domain.conf" <<EOF
TRUST_DOMAIN = condor-$SUFFIX
ANNEX_TOKEN_DOMAIN = condor-$SUFFIX
SCHEDD_NAME = condor-$SUFFIX@condor-$SUFFIX
EOF

# --- Configure HTCondor for Annex Mode --------------------------------------
# Enable the optional Annex feature, and address the AP as 127.0.0.1:9618 on
# loopback only (see 20-ap-tailnet.conf and ap/tailnet.sh).
echo "==> Installing Annex and tailnet configuration"
cp "$REPO_DIR/11-ap-annex.conf" "$REPO_DIR/20-ap-tailnet.conf" "$CONDOR_DIR/local/config.d/"

# Force IDToken auth for the EP-facing daemons (an EP on the AP's own host
# could otherwise authenticate via FS with the wrong identity), and grant its
# custom subject DAEMON access for schedd direct attach and CCB registration.
# See notes.md's "Force IDToken Auth".
cat >"$CONDOR_DIR/local/config.d/14-ap-force-idtoken.conf" <<EOF
AP_COLLECTOR.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS
SCHEDD.SEC_DEFAULT_AUTHENTICATION_METHODS = IDTOKENS

AP_COLLECTOR.ALLOW_DAEMON = \$(ALLOW_DAEMON), $(whoami)@condor-$SUFFIX
SCHEDD.ALLOW_DAEMON = \$(ALLOW_DAEMON), $(whoami)@condor-$SUFFIX
EOF

# Leave a well-known symlink so later runs can find and resume this AP.
mkdir -p "$HOME/personal-htcondor"
ln -sfn "$CONDOR_DIR" "$HOME/personal-htcondor/current-ap"

echo "==> Install complete"
echo "CONDOR_DIR=$CONDOR_DIR"
