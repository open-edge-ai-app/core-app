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
| `npm run android`         | Build and run Android using the default Metro port. |
| `npm run android:8082`    | Build and run Android using port `8082`.            |
| `npm run ios`             | Build and run the iOS app.                          |
| `npm run web`             | Start the Vite web preview.                         |
| `npm run lint`            | Run ESLint.                                         |
| `npx tsc --noEmit`        | Run TypeScript type checking.                       |
| `npm test -- --runInBand` | Run Jest tests serially.                            |

## Android Development

For local Android testing when port `8081` is occupied:

```sh
npm run start:android
npm run android:8082
```

For a physical Android device, make sure USB debugging is enabled and the device
is visible:

```sh
adb devices
adb reverse tcp:8081 tcp:8082
```

Then run the Android target with the `8082` script.

## iOS Development

Install CocoaPods dependencies when needed:

```sh
cd ios
bundle install
bundle exec pod install
cd ..
npm run ios
```

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
