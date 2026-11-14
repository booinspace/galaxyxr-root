# KernelSU GXR module sources

The locally built manager includes **booinspace/galaxyxr-modules** and
**4uva4ek/galaxyxr-modules** in its download-source selector. Fresh installs
select booinspace first. An upgrade adds it once, preserves existing sources
and the selected source, and respects later removal of the entry.

The source browser, archive verification, installer and conflict handling are
upstream 4uva4ek code. This build only changes source defaults and their
one-time migration. The patch is pinned to upstream commit
`ec924a8add6a89efda6a3c2e837e5812e0377ee8` and applied by both `prepare.sh` and
`build-gxr-azj2.sh`. It does not change DirtyFrag, the kernel module, daemon,
root permissions or module activation rules.

The catalogue belongs in the public modules repository: a root `modules.json`
plus `updates/<module-id>.json` feeds pointing to checksum-verified GitHub
Release ZIPs. See the [catalogue guide](https://github.com/booinspace/galaxyxr-modules/blob/main/docs/MODULE-CATALOGUE.md).
The manager can already add this source manually through Modules → download
button → Sources. Rebuilding supplies the source by default for other users.

## Rebuild only the manager

After a complete build, retain its signed Manager APK, signing key pair and
Android SDK. A catalogue-only rebuild can reuse that APK's embedded daemon:

```sh
XR_WORKDIR=/path/to/work \
GXR_BASE_MANAGER_APK=/path/to/previous/KernelSU-GXR-AZJ2-local.apk \
bash scripts/build-gxr-azj2.sh --manager-only
```

The base APK must verify with the same certificate as `work/keys/manager-azj2.p12`.
The script extracts its ARM64 `libksud.so`, runs the manager catalogue unit tests,
compiles the APK and signs it with the retained key using the existing v2-only
signature settings. It verifies alignment, certificate, package version and
embedded daemon. Kernel and Rust compilation are skipped in this mode.

Output: `work/output/KernelSU-GXR-AZJ2-catalogue.apk`, version code **32685**,
version **samsung-gxr-v1.0.16-azj2-local3**, with `SHA256SUMS-manager.txt`.
The existing full build still emits `KernelSU-GXR-AZJ2-local.apk` and includes
the same catalogue defaults. Keep signing inputs private; only source and
patches belong in the public mirror.

Update an existing manager with `adb install -r` after checking its certificate
matches. The package name is unchanged. This manager update does not require
rerunning DirtyFrag, reinstalling modules or restarting Android. A later full
headset reboot still ends temporary root in the usual way.
