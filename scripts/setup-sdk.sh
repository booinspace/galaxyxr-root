#!/usr/bin/env bash
set -euo pipefail

work=${XR_WORKDIR:-/work}
export ANDROID_HOME=${ANDROID_HOME:-$work/android-sdk}
mkdir -p "$ANDROID_HOME"

echo 'Review and accept the Android SDK licenses when prompted.'
sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" \
    'platforms;android-37.0' 'build-tools;37.0.0' \
    'ndk;28.2.13676358' 'ndk;29.0.14206865' 'cmake;3.22.1'

for path in "$ANDROID_HOME/platforms/android-37.0/android.jar" \
    "$ANDROID_HOME/build-tools/37.0.0/apksigner" \
    "$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang" \
    "$ANDROID_HOME/ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"; do
    [[ -e $path ]] || { echo "SDK package missing: $path" >&2; exit 1; }
done
