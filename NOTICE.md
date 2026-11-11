# Provenance and local changes

This repository does not assert ownership of DirtyFrag, DFRoot, KernelSU GXR,
KernelSU, AOSP Clang, or Samsung's kernel. The README links each creator and
pins the exact fetched revision. The full upstream license files are in the
fetched source trees; they are not relicensed by this repository's MIT license.

| User-provided input | Expected SHA-256 |
| --- | --- |
| `SM-I610_NA_Opensource.zip` | `66e60981e510b5a76967e20189127373aa1c349197526008878acbc0e1216809` |
| `SM-I610_NA_Opensource_I610UES3AZJ2.zip` | `aeb7efc2ecabf89b9c556cfb1658f5cc06e59da109baa87bba822ba99806388a` |
| Decompressed `/proc/config.gz` from the tested AZJ2 headset | `9c02302c9173a4ec20aff02fa035d57f7dd48e57177113317c390fa9a6bf6712` |
| Generated build `.config` | `e2dff907c75a833093a9ace715fcc772e9e81eb614d346ff9a212926a4351d85` |

`prepare.sh` changes the running config's `CONFIG_LOCALVERSION` to the exact
AZJ2 kernel release, turns off `CONFIG_LOCALVERSION_AUTO`, and clears an
unavailable Samsung internal trusted-key path. `olddefconfig` resolves the
dependent kernel options. The full kernel build produces `Module.symvers` for
the two out-of-tree modules.

The only KernelSU GXR source edit raises `CERT_MAX_LENGTH` in
`kernel/manager/apk_sign.c` from 1024 to 2048 bytes. The tested local Manager's
1083-byte certificate exceeded the original parser limit. The build embeds
the new Manager certificate hash and size in the AZJ2 KernelSU module, then
inserts that module into `ksud` and the Manager APK. This local build is not
an official 4uva4ek release. The DirtyFrag build replaces its upstream
Android 12 / 5.10 helper `.ko` with the AZJ2 module; its other upstream module
inputs remain untouched. Upstream DirtyFrag selects NDK 28.2, while KernelSU
GXR selects NDK 29.

The published Samsung source and local `vmlinux` were not proven byte-for-byte
identical to the kernel shipped on the headset. Matching vermagic and a local
symbol check are necessary checks, not proof that every device state is safe.
