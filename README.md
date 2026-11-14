# Galaxy XR AZJ2 root build

Build instructions and scripts for a **Samsung Galaxy XR SM-I610 on
`I610UES3AZJ2`**, plus the source and signed APK for **XR Update Hold**, a small
app that blocks Samsung firmware updates. This repository contains no Samsung
archive, upstream source snapshot, kernel module, exploit binary, or signing key.
The root build fetches pinned public source revisions and uses Samsung source
archives that you download under Samsung's own terms. The resulting root APKs
are local builds, not releases from the credited maintainers.

The root chain tested on this firmware uses a locally built DirtyFrag helper
module and a locally built KernelSU GXR Manager. It changes the running kernel
temporarily; a full reboot removes the loaded kernel module, while anything
written under `/data/adb` or changed with root can persist. This build is
specific to AZJ2 and does not establish support for a later OTA.

The [AZJ2 root release](https://github.com/booinspace/galaxyxr-root/releases/tag/azj2-root-2026.11.12)
provides the two locally signed APKs and a checksum file. Both APKs match those
installed on the AZJ2 test headset byte for byte. Read the install and recovery
steps below before running DirtyFrag.

## XR Update Hold

[Download XR Update Hold 0.1.0](https://github.com/booinspace/galaxyxr-root/raw/refs/heads/main/releases/GXR-Update-Hold-0.1.0.apk)
or read its [source, installation and build instructions](apps/update-control/README.md).
It uses existing root to disable the two Samsung update agents. Its manual-check
button restores the agents' manifest defaults while keeping automatic scheduling
off. The saved block survives a full reboot; a boot receiver also reasserts the
automatic-update setting using a one-time Android permission.

The app contains no exploit. Building it needs only Java and the Android SDK;
it does not need Samsung's kernel source or the root build below.

## Requirements

- Linux x86-64 or WSL2 with Docker, enough disk and memory for a full Android
  kernel build, and Internet access for upstream source, Gradle, Rust and SDK
  dependencies. On Apple Silicon, use Docker's `linux/amd64` platform; it will
  be slower.
- A Galaxy XR on the exact build above, USB debugging and host `adb` to capture
  `/proc/config.gz`. If you already have the exact running config, ADB is not
  needed during the build.
- The base `SM-I610_NA_Opensource.zip` and overlay
  `SM-I610_NA_Opensource_I610UES3AZJ2.zip` from
  [Samsung Open Source](https://opensource.samsung.com/uploadSearch?searchValue=SM-I610).
  Download them yourself and accept Samsung's download terms on its site. The
  scripts verify their SHA-256 hashes before extraction.
- A terminal for Android's interactive SDK license acceptance. No script
  pre-accepts those terms.

## Build

Run from this repository's root. Save the downloaded Samsung ZIPs with the
exact names above in `work/inputs/`, then capture the running config:

```sh
mkdir -p work/inputs work/keys work/output
adb shell getprop ro.build.display.id
adb shell uname -r
adb exec-out cat /proc/config.gz > work/inputs/AZJ2-running-config.gz
```

The first two commands should report `UML2.260301.001.I610UES3AZJ2` and
`5.10.240-android12-9-perf-33775878-abI610UES3AZJ2`. Stop if they do not.
`prepare.sh` also checks the config against the tested AZJ2 config before
building. Keep `work/` private; it holds downloaded archives, signing keys and
locally built exploit APKs. The extracted source and intermediate build files
stay in the Docker volume.

```sh
docker build --platform linux/amd64 -t galaxyxr-root:azj2 .
docker volume create galaxyxr-azj2-work
docker run --rm --platform linux/amd64 \
  -e LOCAL_UID="$(id -u)" -e LOCAL_GID="$(id -g)" \
  -v galaxyxr-azj2-work:/work galaxyxr-root:azj2 \
  sh -c 'chown -R "$LOCAL_UID:$LOCAL_GID" /work'
docker run --rm -it --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/home -e XR_WORKDIR=/work -e XR_INPUT_DIR=/inputs \
  -v "$PWD":/repo:ro -v galaxyxr-azj2-work:/work \
  -v "$PWD/work/inputs":/inputs:ro \
  -v "$PWD/work/keys":/work/keys \
  -v "$PWD/work/output":/work/output \
  galaxyxr-root:azj2 /repo/scripts/build-all.sh
```

The named volume is necessary on macOS: Samsung's kernel archive contains
paths that do not extract reliably on a macOS bind mount. Run the ownership
command once when creating the volume; it lets the normal user build inside
it. The inputs are mounted read-only. `work/keys/` and `work/output/` remain
on the host so you can retain the signing identity and install the APKs.

`scripts/build-all.sh` prepares the pinned source, prompts for Android SDK
licenses, builds the Samsung kernel and both AZJ2 modules, embeds the modules
in the appropriate upstream apps, then signs and checks the APKs. It uses
kernel Make, CMake/Gradle for Android, and Cargo for KernelSU's daemon. Its
outputs and `SHA256SUMS.txt` appear in `work/output/`. The first build is
substantial; keep the Docker volume for subsequent runs and back up the signing
identities in `work/keys/`, including `dirtyfrag.jks`.

If you prefer native Linux/WSL, install the dependencies shown in
[`Dockerfile`](Dockerfile), the official Android command-line tools, and the
same SDK packages installed by [`setup-sdk.sh`](scripts/setup-sdk.sh). Set
`XR_WORKDIR` to an absolute working directory, place the inputs there, and run
`scripts/build-all.sh` from the repository root. The scripts require GNU
`stat`, `sha256sum`, `sed`, and x86-64 Android NDK tools.

The build intentionally creates a new local Manager signing identity if none
exists. To update a Manager already installed from an earlier local build,
restore **that build's** `manager-azj2.p12` and `manager-azj2.pass` into
`work/keys/` before running. Android rejects an in-place update signed by a
different key. Back up those files securely; neither is part of this repo.

## Install and recover

After checking `work/output/SHA256SUMS.txt`, install the two APKs:

```sh
adb install -r work/output/KernelSU-GXR-AZJ2-local.apk
adb install -r work/output/DirtyFrag-AZJ2-local.apk
```

If Android reports a signing conflict, stop and decide whether to uninstall
the existing app. Uninstalling a Manager can remove its settings and root
grants. Keep DirtyFrag **Autorun off**, select the installed KernelSU GXR app
in DirtyFrag's **SU Manager** card, and use DirtyFrag's explicit **Run exploit**
action once. The first tap asks for confirmation and the second begins the
attempt. A successful test showed KernelSU GXR **Working [Jailbreak mode]** on
AZJ2. Do not use KernelSU's **Install → Use local LKM file** for the
`dfroot-azj2.ko` helper; the Manager APK already embeds the AZJ2 KernelSU
module for DirtyFrag's late-load route.

For a failed attempt, leave Autorun off and fully reboot before another run.
To remove the APKs, disable Autorun, remove any root modules you installed
while root is available, then uninstall `df.root` and `me.weishu.kernelsu`.
Rebooting clears temporary kernel changes, but is **not a factory restore**:
files or settings changed with root may remain. The exploit can crash/reboot
the headset and its SELinux-disable path may affect Samsung Knox's warranty
state. Keep a recovery path and do not flash any build output.

## Source, credit and license

| Component | Creator/source | Build input |
| --- | --- | --- |
| Galaxy XR kernel | [Samsung Open Source](https://opensource.samsung.com/uploadSearch?searchValue=SM-I610) | User-downloaded base and AZJ2 overlay archives |
| DirtyFrag | [mitschud/DirtyFrag](https://github.com/mitschud/DirtyFrag), derived from [diabl0w/DFRoot](https://github.com/diabl0w/DFRoot) | `e6a4923545b05fdd8a0847ea1c85cd85aa363146` |
| KernelSU GXR | [4uva4ek/KernelSU-GXR](https://github.com/4uva4ek/KernelSU-GXR), building on [diabl0w/KernelSU](https://github.com/diabl0w/KernelSU) and [tiann/KernelSU](https://github.com/tiann/KernelSU) | `ec924a8add6a89efda6a3c2e837e5812e0377ee8` (`gxr-v1.0.16`) |
| Android compiler | [AOSP Clang prebuilt](https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/) | `clang-r416183b` at `3f17560d9bd078537f29294c2bcf80b591821a09` |
| XR Update Hold | [booinspace](apps/update-control/README.md) | App source in this repository; no third-party runtime dependencies |

The scripts, documentation and XR Update Hold source are MIT-licensed; see [LICENSE](LICENSE).
Downloaded components retain their own licenses: DirtyFrag is GPL-2.0,
KernelSU GXR's repository is GPL-3.0 and its kernel code is GPL-2.0. Read the
license files in the fetched source and Samsung's terms before distributing
any derived artifact. See [NOTICE.md](NOTICE.md) for exact input hashes and
local source changes. This layout reduces redistribution and attribution
issues; no repository layout can guarantee against a copyright complaint.

For Home Space UI modules, use the separate
[booinspace/galaxyxr-modules](https://github.com/booinspace/galaxyxr-modules)
repository.
