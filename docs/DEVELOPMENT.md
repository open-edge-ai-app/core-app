# Development Guide

## Requirements

- Node.js `>= 22.11.0`
- npm
- OpenJDK 17
- Android Studio with Android SDK
- Xcode and CocoaPods for iOS work on macOS

## Install

```sh
npm install
```

## Scripts

| Command                   | Purpose                                             |
| ------------------------- | --------------------------------------------------- |
| `npm start`               | Start Metro on the default port.                    |
| `npm run start:android`   | Start Metro on port `8082`.                         |
| `npm run android`         | Install debug with Metro port `8082`, apply reverse, and launch Android. |
| `npm run android:8082`    | Same as `npm run android`; kept for explicit Android 8082 workflows. |
| `npm run android:activate`| Re-apply the Android port reverse and foreground the app.             |
| `npm run android:reverse` | Re-apply only `adb reverse tcp:8082 tcp:8082`.                         |
| `npm run ios`             | Build and run the iOS app.                          |
| `npm run web`             | Start the Vite web preview.                         |
| `npm run lint`            | Run ESLint.                                         |
| `npx tsc --noEmit`        | Run TypeScript type checking.                       |
| `npm test -- --runInBand` | Run Jest tests serially.                            |

## Android Development

For local Android testing when port `8081` is occupied:

```sh
npm run start:android
npm run android
```

The Android script builds the debug APK with React Native's dev server port set
to `8082` and maps device `8082` to host `8082`:

```sh
adb devices
npm run android:reverse
```

This avoids failures where another local process owns host `127.0.0.1:8081`
and returns HTML instead of the React Native bundle.

## iOS Development

Install CocoaPods dependencies when needed:

```sh
npm run ios:pods
npm run ios
```

The iOS helper checks that full Xcode is selected, installs Pods when they are
missing, and runs the `OpenEdgeAI` scheme on the simulator. You can set
`OPEN_EDGE_AI_IOS_SIMULATOR` to target a specific simulator name.

The iOS app shell exists, but the native AI bridge is planned future work.

## Web Preview

The web target is for UI iteration:

```sh
npm run web
```

Native AI calls use development fallbacks in the browser.

## Quality Checks

Run these before opening a pull request:

```sh
npm run lint
npx tsc --noEmit
npm test -- --runInBand
```

## Generated and Local Files

Do not commit:

- `node_modules/`;
- `dist/`;
- CocoaPods directories;
- Android or Xcode build output;
- local model binaries;
- local machine config;
- credentials or signing secrets.

## Troubleshooting

### Metro Port Conflict

Use the `8082` scripts:

```sh
npm run start:android
npm run android:8082
```

### Missing Android SDK

Confirm `ANDROID_HOME` or `ANDROID_SDK_ROOT` points to your SDK location and
that platform tools are available on `PATH`.

### Missing Model File

The app can start without a bundled model, but generation may ask the user to
download or install a compatible model file.

See [MODEL_ASSETS.md](MODEL_ASSETS.md).
