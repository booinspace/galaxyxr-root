#!/usr/bin/env bash
set -euo pipefail

work=${XR_WORKDIR:-/work}
phase=${1:?usage: build-azj2.sh config|prepare|kernel|module}
kernel=$work/source/kernel_platform/msm-kernel
out=$work/kernel-out
module=$work/upstream/DirtyFrag/lkm
release_dir=$work/output
clang_bin=${XR_CLANG_BIN:-$work/aosp-clang/clang-r416183b/bin}
expected=5.10.240-android12-9-perf-33775878-abI610UES3AZJ2

[[ -d $kernel && -x $clang_bin/clang ]] || {
    echo "Extract Samsung source and install AOSP clang-r416183b first; see docs/BUILD.md" >&2
    exit 2
}
mkdir -p "$out" "$release_dir"
export PATH="$clang_bin:$PATH"
exec > >(tee "$work/build-$phase.log") 2>&1

args=(-C "$kernel" O="$out" ARCH=arm64 LLVM=1 LLVM_IAS=1
      CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-)

case $phase in
    config)
        [[ -f $out/.config ]] || { echo "Run scripts/prepare.sh first" >&2; exit 2; }
        make "${args[@]}" olddefconfig
        ;;
    prepare)
        [[ -f $out/.config ]] || { echo "Run config first" >&2; exit 2; }
        make "${args[@]}" -j8 modules_prepare
        ;;
    kernel)
        [[ -f $out/.config ]] || { echo "Run config first" >&2; exit 2; }
        make "${args[@]}" -j8 Image modules
        ;;
    module)
        [[ -f $out/Module.symvers ]] || { echo "Run kernel first" >&2; exit 2; }
        make "${args[@]}" M="$module" -j8 modules
        "$clang_bin/llvm-objcopy" --strip-unneeded \
            -R .comment -R .note.gnu.property -R .note.Linux -R .note.GNU-stack \
            -R .BTF -R .BTF.base -R .llvm_addrsig \
            -R .hyp.text -R .hyp.bss -R .hyp.rodata -R .hyp.event_ids \
            -R .hyp.patchable_function_entries -R .hyp.data \
            "$module/dfroot.ko" "$release_dir/dfroot-azj2.ko"
        [[ $(modinfo -F vermagic "$release_dir/dfroot-azj2.ko") == "$expected "* ]] || {
            echo "Unexpected DirtyFrag module vermagic" >&2
            exit 1
        }
        ;;
    *)
        echo "usage: build-azj2.sh config|prepare|kernel|module" >&2
        exit 2
        ;;
esac

release=$(make -s "${args[@]}" kernelrelease)
[[ $release == "$expected" ]] || {
    echo "Unexpected kernel release: $release" >&2
    exit 1
}
echo "Kernel release: $release"
