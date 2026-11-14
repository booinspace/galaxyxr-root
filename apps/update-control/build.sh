#!/usr/bin/env bash
set -euo pipefail

app_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$app_dir/../.." && pwd)
work=${XR_WORKDIR:-$repo/work}
key_dir=${XDG_DATA_HOME:-$HOME/.local/share}/galaxyxr-root
keystore=$key_dir/update-hold.p12
pass_file=$key_dir/update-hold.pass

: "${ANDROID_HOME:?Set ANDROID_HOME to an Android SDK with platform and build-tools 37.0.0}"
[[ -f $ANDROID_HOME/platforms/android-37.0/android.jar && -x $ANDROID_HOME/build-tools/37.0.0/apksigner ]] || {
    echo 'Install SDK platform android-37.0 and build-tools 37.0.0 first; see README.md' >&2
    exit 2
}
mkdir -p "$work/output"
gradle=$work/gradle-9.7.1/bin/gradle
if [[ ! -x $gradle ]]; then
    archive=$work/gradle-9.7.1-bin.zip
    curl -fsSL https://services.gradle.org/distributions/gradle-9.7.1-bin.zip -o "$archive"
    printf '%s  %s\n' acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a "$archive" | sha256sum -c -
    unzip -q "$archive" -d "$work"
fi

umask 077
mkdir -p "$key_dir"
if [[ ! -f $pass_file ]]; then
    openssl rand -hex 24 > "$pass_file"
fi
if [[ ! -f $keystore ]]; then
    keytool -genkeypair -storetype PKCS12 -keystore "$keystore" \
        -alias update-hold -keyalg RSA -keysize 3072 -validity 3650 \
        -dname 'CN=Galaxy XR Update Hold/' \
        -storepass "$(cat "$pass_file")" -keypass "$(cat "$pass_file")"
fi

export GXR_UPDATE_KEYSTORE=$keystore
export GXR_UPDATE_KEYPASS=$(cat "$pass_file")
"$gradle" --no-daemon --no-watch-fs --project-dir "$app_dir" :app:assembleRelease

out=$work/output/GXR-Update-Hold-0.1.0.apk
cp "$app_dir/app/build/outputs/apk/release/app-release.apk" "$out"
"$ANDROID_HOME/build-tools/37.0.0/apksigner" verify "$out"
sha256sum "$out"
