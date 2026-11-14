#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_dir=${1:?Usage: patch-gxr-manager.sh /path/to/KernelSU-GXR}
expected=ec924a8add6a89efda6a3c2e837e5812e0377ee8
[[ $(git -C "$source_dir" rev-parse HEAD) == "$expected" ]] || {
    echo 'Module source patch requires the pinned KernelSU GXR revision' >&2
    exit 1
}
patch_file=$repo/patches/manager-module-catalogue.patch
if git -C "$source_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
    echo 'Manager catalogue patch already applied'
else
    git -C "$source_dir" apply --check "$patch_file"
    git -C "$source_dir" apply "$patch_file"
    echo 'Added booinspace module catalogue defaults'
fi
