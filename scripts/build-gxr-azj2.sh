#!/usr/bin/env bash
set -euo pipefail

work=${XR_WORKDIR:-/work}
gxr="$work/upstream/KernelSU-GXR"
kernel="$work/source/kernel_platform/msm-kernel"
kernel_out="$work/kernel-out"
out="$work/output"
export ANDROID_HOME=${ANDROID_HOME:-$work/android-sdk}
export ANDROID_NDK_HOME=${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/29.0.14206865}
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-$work/gxr-target}
export RUSTUP_TOOLCHAIN=1.99.0
export PATH="$work/aosp-clang/clang-r416183b/bin:$PATH"
keydir="$work/keys"
keystore=${GXR_KEYSTORE:-$keydir/manager-azj2.p12}
pass_file=${GXR_SIGN_PASS_FILE:-$keydir/manager-azj2.pass}
expected_release=5.10.240-android12-9-perf-33775878-abI610UES3AZJ2

for input in "$kernel_out/vmlinux" "$kernel_out/Module.symvers" "$gxr/Cargo.lock" \
             "$keystore" "$pass_file" "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"; do
    [[ -f $input ]] || { echo "Missing build input: $input" >&2; exit 2; }
done
mkdir -p "$out"
GXR_SIGN_PASS=$(cat "$pass_file")
export GXR_SIGN_PASS
rm -f "$out/manager-azj2.cert.der"
keytool -exportcert -alias gxr -keystore "$keystore" -storetype PKCS12 \
    -storepass:env GXR_SIGN_PASS -file "$out/manager-azj2.cert.der" >/dev/null
cert_size=$(stat -c %s "$out/manager-azj2.cert.der")
cert_hash=$(sha256sum "$out/manager-azj2.cert.der" | cut -d ' ' -f 1)
(( cert_size <= 2048 )) || { echo 'Manager certificate exceeds patched KernelSU limit' >&2; exit 1; }

args=(-C "$kernel" O="$kernel_out" ARCH=arm64 LLVM=1 LLVM_IAS=1 \
      CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
      M="$gxr/kernel" CONFIG_KSU=m CONFIG_KSU_SAMSUNG_KDP=y \
      CONFIG_KSU_SAMSUNG_DEFEX=n CONFIG_KSU_RKP_NO_PATCH_TEXT=y \
      KBUILD_MODPOST_WARN=1 CONFIG_SECTION_MISMATCH_WARN_ONLY=y \
      "KSU_EXPECTED_SIZE2=$cert_size" "KSU_EXPECTED_HASH2=$cert_hash")
make "${args[@]}" clean > "$out/module-clean.log" 2>&1
make "${args[@]}" -j8 modules > "$out/module-build.log" 2>&1 || {
    tail -80 "$out/module-build.log" >&2
    exit 1
}
: > "$out/empty-section"
aarch64-linux-gnu-objcopy --update-section __versions="$out/empty-section" \
    "$gxr/kernel/kernelsu.ko" "$out/kernelsu-azj2.ko"
grep -aF "$cert_hash" "$out/kernelsu-azj2.ko" >/dev/null || {
    echo "Manager certificate hash missing from KernelSU module" >&2
    exit 1
}
cc "$gxr/kernel/tools/check_symbol.c" -o "$out/check_symbol"
"$out/check_symbol" "$out/kernelsu-azj2.ko" "$kernel_out/vmlinux" \
    > "$out/symbol-check.log" 2>&1 || {
    cat "$out/symbol-check.log" >&2
    exit 1
}
[[ $(modinfo -F vermagic "$out/kernelsu-azj2.ko") == "$expected_release "* ]] || {
    echo "Unexpected KernelSU module vermagic" >&2
    exit 1
}
cp "$out/kernelsu-azj2.ko" "$gxr/userspace/ksud/bin/aarch64/android12-5.10_kernelsu.ko"

cd "$gxr"
# shellcheck source=/dev/null
source .github/scripts/setup-rust-build.sh aarch64-linux-android 26
builtins="$($CLANG_PATH --print-resource-dir)/lib/linux/libclang_rt.builtins-aarch64-android.a"
[[ -f $builtins ]] || { echo "Missing NDK builtins: $builtins" >&2; exit 2; }
RUSTFLAGS="-C target-feature=+crt-static -C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wno-unused-command-line-argument -C link-arg=$builtins" \
    cargo build --locked --package ksuinit --target aarch64-linux-android --release \
    > "$out/ksuinit-build.log" 2>&1 || {
    tail -80 "$out/ksuinit-build.log" >&2
    exit 1
}
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/ksuinit" "$gxr/userspace/ksud/bin/aarch64/"
cargo clean --package ksud --target aarch64-linux-android --release >/dev/null
cargo build --locked --package ksud --target aarch64-linux-android --release \
    > "$out/ksud-build.log" 2>&1 || {
    tail -80 "$out/ksud-build.log" >&2
    exit 1
}
cp "$CARGO_TARGET_DIR/aarch64-linux-android/release/ksud" "$out/ksud-azj2"
mkdir -p "$gxr/manager/app/src/main/jniLibs/arm64-v8a"
cp "$out/ksud-azj2" "$gxr/manager/app/src/main/jniLibs/arm64-v8a/libksud.so"
(
    cd manager
    bash gradlew clean assembleRelease -Pandroid.injected.build.abi=arm64-v8a \
        -Pandroid.injected.testOnly=false \
        -PKSU_VERSION_NAME=gxr-v1.0.16-azj2-local2 -PKSU_VERSION_CODE=32684
) > "$out/manager-build.log" 2>&1 || {
    tail -80 "$out/manager-build.log" >&2
    exit 1
}
mapfile -t apks < <(find "$gxr/manager/app/build/intermediates/apk/release" -maxdepth 1 -name '*.apk')
[[ ${#apks[@]} == 1 ]] || { echo "Expected one Manager APK" >&2; exit 1; }
bt="$ANDROID_HOME/build-tools/37.0.0"
ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
"$bt/zipalign" -f -P 16 4 "${apks[0]}" "$out/manager-aligned.apk"
"$bt/apksigner" sign --ks "$keystore" --ks-type PKCS12 --ks-key-alias gxr \
    --ks-pass env:GXR_SIGN_PASS --key-pass env:GXR_SIGN_PASS \
    --v1-signing-enabled false --v2-signing-enabled true \
    --v3-signing-enabled false --v4-signing-enabled false \
    --out "$out/KernelSU-GXR-AZJ2-local.apk" "$out/manager-aligned.apk"
unset GXR_SIGN_PASS
"$bt/apksigner" verify --verbose --print-certs "$out/KernelSU-GXR-AZJ2-local.apk" \
    > "$out/apksigner-verify.txt"
"$bt/zipalign" -c -P 16 4 "$out/KernelSU-GXR-AZJ2-local.apk"
grep -F "V2 Signer: certificate SHA-256 digest: $cert_hash" "$out/apksigner-verify.txt" >/dev/null
grep -F "Verified using v2 scheme (APK Signature Scheme v2): true" "$out/apksigner-verify.txt" >/dev/null
grep -F "Verified using v3 scheme (APK Signature Scheme v3): false" "$out/apksigner-verify.txt" >/dev/null
"$ndk_bin/llvm-strip" --strip-unneeded "$out/ksud-azj2" -o "$out/ksud-stripped"
python3 "$gxr/scripts/gxr-apk.py" verify-source "$out/KernelSU-GXR-AZJ2-local.apk" "$out/ksud-stripped"
"$bt/aapt2" dump badging "$out/KernelSU-GXR-AZJ2-local.apk" > "$out/apk-badging.txt"
grep -F "package: name='me.weishu.kernelsu' versionCode='32684' versionName='samsung-gxr-v1.0.16-azj2-local2'" "$out/apk-badging.txt" >/dev/null
(cd "$out" && sha256sum KernelSU-GXR-AZJ2-local.apk kernelsu-azj2.ko ksud-azj2 manager-azj2.cert.der > SHA256SUMS.txt)
echo "Built AZJ2 GXR artifacts in $out"
