#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=${XR_WORKDIR:-/work}
export ANDROID_HOME=${ANDROID_HOME:-$work/android-sdk}
export ANDROID_NDK_HOME=${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/29.0.14206865}
mkdir -p "$HOME" "$work/output" "$work/keys"
umask 077

"$repo/scripts/prepare.sh"
"$repo/scripts/setup-sdk.sh"

keydir=$work/keys
if [[ ! -f $keydir/manager-azj2.p12 && ! -f $keydir/manager-azj2.pass ]]; then
    openssl rand -hex 24 > "$keydir/manager-azj2.pass"
    openssl req -x509 -newkey rsa:3072 -nodes -days 3650 \
        -subj '/CN=Galaxy XR AZJ2 Local GXR Manager/' \
        -keyout "$keydir/manager-azj2.key.pem" \
        -out "$keydir/manager-azj2.cert.pem"
    openssl pkcs12 -export -name gxr \
        -inkey "$keydir/manager-azj2.key.pem" \
        -in "$keydir/manager-azj2.cert.pem" \
        -out "$keydir/manager-azj2.p12" \
        -passout "file:$keydir/manager-azj2.pass"
    rm "$keydir/manager-azj2.key.pem"
fi
[[ -f $keydir/manager-azj2.p12 && -f $keydir/manager-azj2.pass ]] || {
    echo 'Incomplete Manager signing identity in work/keys; restore the pair from backup' >&2
    exit 2
}

"$repo/scripts/build-azj2.sh" config
"$repo/scripts/build-azj2.sh" prepare
"$repo/scripts/build-azj2.sh" kernel
"$repo/scripts/build-azj2.sh" module
"$repo/scripts/build-gxr-azj2.sh"
"$repo/scripts/build-dirtyfrag.sh"
(
    cd "$work/output"
    sha256sum DirtyFrag-AZJ2-local.apk KernelSU-GXR-AZJ2-local.apk \
        dfroot-azj2.ko kernelsu-azj2.ko > SHA256SUMS.txt
)
echo "Built APKs and modules in $work/output"
