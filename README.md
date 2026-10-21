# waweb

WhatsApp Web native untuk Android. Flutter, Material 3.

Author: aether · Versi: BETA

## Rilis lewat GitHub Actions

1. Push project ini ke repo GitHub.
2. Buat tag: `git tag v0.1.0-beta && git push origin v0.1.0-beta`
   atau buka tab Actions, pilih Build and Release, lalu Run workflow.
3. APK muncul di halaman Releases.

Folder `android/` dibuat otomatis oleh workflow dari `android_overlay/`.

## Jalan lokal

```
flutter create --platforms=android --org com.aether --project-name waweb _gen
cp -r _gen/android ./android && rm -rf _gen
rm -rf android/app/src/main/res/mipmap-*
cp -r android_overlay/. android/
flutter run
```
(ubah `minSdk` jadi 29 di `android/app/build.gradle*`)
