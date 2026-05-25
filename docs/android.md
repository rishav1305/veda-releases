# Android install

The shell installer (`install.sh`) does **not** handle Android. Phones download the
APK directly through a browser and tap to install. If you pipe the script on an
Android shell (Termux, etc.) it will detect the platform and exit with a pointer
back here.

## Browser install (recommended)

1. Open <https://rishavchatterjee.com/veda/download/android> on your phone.
   This redirects to the latest `veda-android-<arch>-<version>.apk` on the
   GitHub Release page.
2. Your browser will download the APK to `Downloads/`.
3. Open the APK from the notification or file manager.
4. Android will prompt: **"Install unknown apps"**. Tap **Settings**, enable the
   toggle for the browser (or file manager) you used to download the APK, then
   tap **Back** and **Install**.
5. Launch Veda from the app drawer.

## Power-user: adb install

If you have ADB set up against the device:

```bash
TAG=v6.0.0-rc1
ARCH=arm64-v8a   # or x86_64 on an emulator
APK=veda-android-${ARCH}-${TAG}.apk
BASE=https://github.com/rishav1305/veda-releases/releases/download/${TAG}

curl -fLO ${BASE}/${APK}
curl -fLO ${BASE}/${APK}.minisig
curl -fLO https://raw.githubusercontent.com/rishav1305/veda-releases/main/keys/veda-release.pub

minisign -Vm ${APK} -p veda-release.pub
adb install -r ${APK}
```

`adb install -r` reinstalls in place; drop the `-r` for a first install.

## Verify the APK signature

The APK is signed twice — once by the Android signing scheme baked into the APK,
and once by minisign (the `.minisig` file). Verify the minisign envelope before
installing if you downloaded from anywhere other than the official release page.

## Updates

Veda does not auto-update on Android. Re-run the browser flow or `adb install -r`
against a newer tag when a new release lands.
