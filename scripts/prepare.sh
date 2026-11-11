#!/usr/bin/env bash
set -euo pipefail

work=${XR_WORKDIR:-/work}
inputs=${XR_INPUT_DIR:-$work/inputs}
upstream=$work/upstream
source_dir=$work/source
mkdir -p "$inputs" "$upstream" "$source_dir" "$work/kernel-out"

check_file() {
    local expected=$1 path=$2
    [[ -f $path ]] || { echo "Missing $path; see README.md" >&2; exit 2; }
    printf '%s  %s\n' "$expected" "$path" | sha256sum -c -
}

fetch_commit() {
    local url=$1 commit=$2 dest=$3
    if [[ ! -d $dest/.git ]]; then
        [[ ! -e $dest ]] || { echo "Incomplete checkout: $dest" >&2; exit 2; }
        git init -q "$dest"
        git -C "$dest" remote add origin "$url"
    fi
    if [[ $(git -C "$dest" rev-parse -q --verify HEAD 2>/dev/null || :) != "$commit" ]]; then
        git -C "$dest" fetch --depth=1 origin "$commit"
        git -C "$dest" -c advice.detachedHead=false checkout -f FETCH_HEAD
    fi
    [[ $(git -C "$dest" rev-parse HEAD) == "$commit" ]] || { echo "Wrong revision: $dest" >&2; exit 1; }
}

check_file 66e60981e510b5a76967e20189127373aa1c349197526008878acbc0e1216809 \
    "$inputs/SM-I610_NA_Opensource.zip"
check_file aeb7efc2ecabf89b9c556cfb1658f5cc06e59da109baa87bba822ba99806388a \
    "$inputs/SM-I610_NA_Opensource_I610UES3AZJ2.zip"

if [[ ! -e $source_dir/.azj2-extracted ]]; then
    unzip -p "$inputs/SM-I610_NA_Opensource.zip" Kernel.tar.gz | tar -xz -C "$source_dir"
    unzip -p "$inputs/SM-I610_NA_Opensource_I610UES3AZJ2.zip" \
        I610UES3AZJ2_kernel.tar.gz | tar -xz -C "$source_dir" --strip-components=1
    [[ -f $source_dir/kernel_platform/msm-kernel/Makefile ]] || { echo 'Samsung source extraction failed' >&2; exit 1; }
    touch "$source_dir/.azj2-extracted"
fi

[[ -f $inputs/AZJ2-running-config.gz ]] || { echo "Missing $inputs/AZJ2-running-config.gz" >&2; exit 2; }
python3 - "$inputs/AZJ2-running-config.gz" "$work/kernel-out/.config" <<'PY'
import gzip
import hashlib
import pathlib
import re
import sys

source = gzip.decompress(pathlib.Path(sys.argv[1]).read_bytes())
expected = '9c02302c9173a4ec20aff02fa035d57f7dd48e57177113317c390fa9a6bf6712'
if hashlib.sha256(source).hexdigest() != expected:
    raise SystemExit('Running config differs from the tested AZJ2 config; stop here')
config = source.decode('ascii')
changes = (
    (r'^CONFIG_LOCALVERSION="-perf"$', 'CONFIG_LOCALVERSION="-android12-9-perf-33775878-abI610UES3AZJ2"'),
    (r'^CONFIG_LOCALVERSION_AUTO=y$', '# CONFIG_LOCALVERSION_AUTO is not set'),
    (r'^CONFIG_SYSTEM_TRUSTED_KEYS="[^"]+"$', 'CONFIG_SYSTEM_TRUSTED_KEYS=""'),
)
for pattern, replacement in changes:
    config, count = re.subn(pattern, replacement, config, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f'Expected exactly one match for {pattern}, found {count}')
result = config.encode('ascii')
if hashlib.sha256(result).hexdigest() != 'e2dff907c75a833093a9ace715fcc772e9e81eb614d346ff9a212926a4351d85':
    raise SystemExit('Generated kernel config differs from the tested build config')
pathlib.Path(sys.argv[2]).write_bytes(result)
PY

fetch_commit https://github.com/mitschud/DirtyFrag.git \
    e6a4923545b05fdd8a0847ea1c85cd85aa363146 "$upstream/DirtyFrag"
fetch_commit https://github.com/4uva4ek/KernelSU-GXR.git \
    ec924a8add6a89efda6a3c2e837e5812e0377ee8 "$upstream/KernelSU-GXR"

clang=$work/aosp-clang
if [[ ! -d $clang/.git ]]; then
    git init -q "$clang"
    git -C "$clang" remote add origin \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86
    git -C "$clang" config core.sparseCheckout true
    git -C "$clang" sparse-checkout set clang-r416183b
fi
if [[ $(git -C "$clang" rev-parse -q --verify HEAD 2>/dev/null || :) != 3f17560d9bd078537f29294c2bcf80b591821a09 ]]; then
    git -C "$clang" fetch --depth=1 origin 3f17560d9bd078537f29294c2bcf80b591821a09
    git -C "$clang" -c advice.detachedHead=false checkout -f FETCH_HEAD
fi
[[ $(git -C "$clang" rev-parse HEAD) == 3f17560d9bd078537f29294c2bcf80b591821a09 ]] || {
    echo 'AOSP Clang revision mismatch' >&2; exit 1;
}
[[ -x $clang/clang-r416183b/bin/clang ]] || { echo 'AOSP Clang checkout incomplete' >&2; exit 1; }

patch_file=$upstream/KernelSU-GXR/kernel/manager/apk_sign.c
if grep -q '^#define CERT_MAX_LENGTH 1024$' "$patch_file"; then
    sed -i 's/^#define CERT_MAX_LENGTH 1024$/#define CERT_MAX_LENGTH 2048/' "$patch_file"
fi
[[ $(grep -c '^#define CERT_MAX_LENGTH 2048$' "$patch_file") == 1 ]] || {
    echo 'KernelSU GXR certificate-length patch did not apply' >&2
    exit 1
}
echo "AZJ2 build inputs prepared in $work"
