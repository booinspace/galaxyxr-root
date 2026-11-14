# XR Update Hold

A small local app for the Galaxy XR SM-I610. It changes only the two Samsung
firmware-update agents and Android's automatic-update scheduling setting. It does
not include a root exploit, boot module, network code or background polling.
Its dark cards take visual cues from [DirtyFrag](https://github.com/mitschud/DirtyFrag);
no DirtyFrag UI code is copied.

## Buttons

- **Hold updates** grants this app the boot-setting permission, sets
  `ota_disable_automatic_update=1`, and disables `com.wssyncmldm` and
  `com.sec.android.soagent` for user 0.
- **Allow manual update check** returns both packages to their manifest-default
  state and leaves automatic scheduling disabled. It does not restore a saved
  pre-install configuration. Open
  **Settings → Software updates** to check. Hold updates again when finished;
  the agents can show update prompts while they are enabled.
- **Refresh status** reads the package states, scheduling setting and boot
  permission. Neither update button runs without KernelSU root.

The Android setting alone prevents automatic scheduling; Android's definition
says an update notification can still appear. The package hold is what prevents
the inspected Samsung agents from checking and notifying. We have not captured
the owner of a future startup popup, so this app does not claim to block every
possible Google or Samsung update surface. It deliberately leaves Google Play
services and app updates alone.

## Install on the headset

Download the APK and `SHA256SUMS.txt` from the
[XR Update Hold 0.1.0 release](https://github.com/booinspace/galaxyxr-root/releases/tag/update-hold-v0.1.0).
From the directory containing both downloads, verify and install:

```sh
sha256sum -c SHA256SUMS.txt
adb install -r GXR-Update-Hold-0.1.0.apk
adb shell pm grant boo.puppy.gxr.updatehold android.permission.WRITE_SECURE_SETTINGS
```

Launch **XR Update Hold** once. The second command is a one-time grant that lets
its boot receiver set `ota_disable_automatic_update=1` after a full restart,
before temporary root is restored. The app also attempts this grant when either
root button succeeds. The setting and package-manager state persist across
normal reboots. The receiver runs on locked and unlocked boot broadcasts and
checks that the setting is still `1`; it does not launch DirtyFrag or obtain
root at boot. If the app is force-stopped, Android can skip boot broadcasts
until it is opened again, so check **Boot guard: Ready** in the app.

To use the buttons, first run DirtyFrag with Autorun off until KernelSU GXR
shows **Working**, then grant XR Update Hold Superuser access in KernelSU GXR.
The status screen works without root. No reboot is needed after Hold or Allow.

Uninstalling the APK leaves the chosen package states and scheduling setting in
place. Use **Allow manual update check** first if you want the Samsung update
agents available after removal. The automatic-update setting remains off.

If the app is unavailable, restore manual checking over ADB:

```sh
adb shell pm default-state --user 0 com.wssyncmldm
adb shell pm default-state --user 0 com.sec.android.soagent
```

To return to the hold over ADB:

```sh
adb shell settings put global ota_disable_automatic_update 1
adb shell pm disable-user --user 0 com.wssyncmldm
adb shell pm disable-user --user 0 com.sec.android.soagent
```

## Build

The app needs JDK 21, Android SDK platform `android-37.0`, build-tools `37.0.0`,
platform-tools, and the Linux tools `curl`, `unzip`, `openssl` and `sha256sum`.
It downloads Gradle 9.7.1 from Gradle's official distribution service and verifies its pinned
SHA-256. No Samsung source, DirtyFrag checkout or kernel build is needed.

On Linux or WSL with those dependencies installed, run from the repository root:

```sh
export ANDROID_HOME="$HOME/Android/Sdk"
apps/update-control/build.sh
```

Or use this repository's Docker environment. The SDK license command is
interactive; review and accept the licenses when prompted:

```sh
docker build --platform linux/amd64 -t galaxyxr-root:azj2 .
mkdir -p work
docker run --rm -it --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/home -e XR_WORKDIR=/work \
  -v "$PWD":/repo -v "$PWD/work":/work \
  galaxyxr-root:azj2 bash -ec '
    mkdir -p "$HOME"
    sdkmanager --sdk_root="$ANDROID_HOME" --licenses
    sdkmanager --sdk_root="$ANDROID_HOME" "platforms;android-37.0" "build-tools;37.0.0" "platform-tools"
    /repo/apps/update-control/build.sh
  '
```

The script keeps its signing key and password in `work/keys/` alongside the
KernelSU GXR and DirtyFrag signing files, then signs and verifies
`work/output/GXR-Update-Hold-0.1.0.apk`. `XR_WORKDIR` can select a different
working directory. Keep both `update-hold.p12` and `update-hold.pass` for future
builds. The public GitHub tree excludes signing keys.

Published APKs and checksums are attached to
[GitHub Releases](https://github.com/booinspace/galaxyxr-root/releases/tag/update-hold-v0.1.0).
The source tree contains no built APKs. A new build without the original key
creates its own identity and cannot update the published APK in place. Keep the
original signing identity for updates to an installed copy.

## Source and license

App code by [booinspace](https://github.com/booinspace), under this repository's
[MIT license](../../LICENSE). The app has no third-party runtime dependencies.
The interface takes visual cues from DirtyFrag, credited above; no DirtyFrag
code or root payload is included. Android SDK and Gradle retain their own terms.
