#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    exec sudo -- "$0" "$@"
fi
case ${1:-build} in
    build) command=(/repo/scripts/build-all.sh); tty=() ;;
    --shell) command=(/bin/bash); tty=(-it) ;;
    *) echo 'usage: build-fedora.sh [--shell]' >&2; exit 2 ;;
esac

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
uid=$(stat -c %u "$repo")
gid=$(stat -c %g "$repo")
owner=$(getent passwd "$uid" | cut -d: -f6)
sdk=$owner/Android/Sdk
[[ -d $sdk && -f $repo/work/inputs/SM-I610_NA_Opensource.zip ]] || {
    echo "Missing Android SDK or Samsung inputs; see README.md (Build section)" >&2
    exit 2
}
install -d -m 700 -o "$uid" -g "$gid" "$repo/work/output"
podman build --network=host --platform linux/amd64 -t localhost/galaxyxr-root:azj2 "$repo"
podman volume exists galaxyxr-azj2-work || podman volume create galaxyxr-azj2-work
podman run --rm --network=host --platform linux/amd64 \
    -e LOCAL_UID="$uid" -e LOCAL_GID="$gid" \
    -v galaxyxr-azj2-work:/work localhost/galaxyxr-root:azj2 \
    sh -c 'test "$(stat -c %u /work)" = "$LOCAL_UID" || chown -R "$LOCAL_UID:$LOCAL_GID" /work'

podman run --rm "${tty[@]}" --network=host --platform linux/amd64 \
    --user "$uid:$gid" \
    -e HOME=/work/home -e XR_WORKDIR=/work -e XR_INPUT_DIR=/inputs \
    -e JAVA_TOOL_OPTIONS=-Duser.home=/work/home \
    -v "$repo":/repo:ro -v galaxyxr-azj2-work:/work \
    -v "$sdk":/work/android-sdk \
    -v "$repo/work/inputs":/inputs:ro \
    -v "$repo/work/keys":/work/keys \
    -v "$repo/work/output":/work/output \
    localhost/galaxyxr-root:azj2 "${command[@]}"
