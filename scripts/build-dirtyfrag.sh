#!/usr/bin/env bash
set -euo pipefail

work=${XR_WORKDIR:-/work}
export ANDROID_HOME=${ANDROID_HOME:-$work/android-sdk}
dirtyfrag=$work/upstream/DirtyFrag
module=$work/output/dfroot-azj2.ko
keydir=$work/keys
keystore=$keydir/dirtyfrag.jks
umask 077
mkdir -p "$keydir" "$work/output"
[[ -f $module && -f $dirtyfrag/gradlew ]] || { echo 'Build the AZJ2 module and fetch DirtyFrag first' >&2; exit 2; }

if [[ -e $dirtyfrag/app/keystore.jks || -L $dirtyfrag/app/keystore.jks ]]; then
    [[ $(readlink "$dirtyfrag/app/keystore.jks") == "$keystore" ]] || {
        echo 'Unexpected DirtyFrag signing key in upstream checkout' >&2
        exit 2
    }
else
    ln -s "$keystore" "$dirtyfrag/app/keystore.jks"
fi
if [[ ! -f $keystore ]]; then
    keytool -genkeypair -keystore "$keystore" -alias dirtyfrag \
        -storepass dirtyfrag -keypass dirtyfrag -keyalg RSA -keysize 3072 \
        -validity 3650 -dname 'CN=Local DirtyFrag AZJ2 Build'
fi
cp "$module" "$dirtyfrag/app/src/main/jni/ko/dfroot-android12-5.10.ko"
(
    cd "$dirtyfrag"
    ./gradlew assembleRelease
)
apk=$dirtyfrag/app/build/outputs/apk/release/dirtyfrag.apk
[[ -s $apk ]] || { echo 'DirtyFrag APK was not produced' >&2; exit 1; }
cp "$apk" "$work/output/DirtyFrag-AZJ2-local.apk"
"$ANDROID_HOME/build-tools/37.0.0/apksigner" verify --verbose \
    "$work/output/DirtyFrag-AZJ2-local.apk"
