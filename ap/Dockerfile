# AlmaLinux 9 runtime for the personal AP on hosts without a native HTCondor
# build. Built by ap/docker.sh with the invoking user's name, uid, gid and home
# so files and paths inside the container match the host.
FROM almalinux:9.8-20261027@sha256:245f8aab832fe800aa42bdab5fad75ebbd8e0b4c9f24820a83c638b177857ae2

RUN dnf -y install findutils hostname procps-ng python3 tar which \
    && dnf clean all

ARG USER_NAME
ARG USER_UID
ARG USER_GID
ARG USER_HOME

RUN test -n "$USER_NAME" && test -n "$USER_UID" && test -n "$USER_GID" && test -n "$USER_HOME" \
    && { getent group "$USER_GID" >/dev/null || groupadd -g "$USER_GID" "$USER_NAME"; } \
    && useradd -M -u "$USER_UID" -g "$USER_GID" -d "$USER_HOME" "$USER_NAME" \
    && mkdir -p "$USER_HOME" \
    && chown "$USER_UID:$USER_GID" "$USER_HOME"

USER $USER_NAME
WORKDIR $USER_HOME
