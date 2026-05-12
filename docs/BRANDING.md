# Branding

Open Edge AI keeps brand-facing values in one generated runtime config:

```text
src/config/branding.ts
```

Use the branding script when changing app names, launcher names, bundle IDs, or
brand assets.

## Quick Start

```sh
cp .env.example .env
npm run branding:apply
```

Edit `.env` before running the script.

## Environment Variables

| Variable                          | Purpose                                                                                   |
| --------------------------------- | ----------------------------------------------------------------------------------------- |
| `OPEN_EDGE_AI_APP_NAME`           | React Native app registry name. Keep this stable unless native entry points are updated.  |
| `OPEN_EDGE_AI_DISPLAY_NAME`       | Product display name used by shared runtime branding.                                     |
| `OPEN_EDGE_AI_PRODUCT_NAME`       | Human-readable product name for UI/documentation-facing config.                           |
| `OPEN_EDGE_AI_WEB_TITLE`          | Browser title for the web preview.                                                        |
| `OPEN_EDGE_AI_ANDROID_APP_NAME`   | Android launcher label in `strings.xml`.                                                  |
| `OPEN_EDGE_AI_IOS_DISPLAY_NAME`   | iOS launcher display name in `Info.plist` and launch screen.                              |
| `OPEN_EDGE_AI_BUNDLE_IDENTIFIER`  | Android `applicationId` and iOS `PRODUCT_BUNDLE_IDENTIFIER`.                              |
| `OPEN_EDGE_AI_LOGO_SOURCE`        | Optional source file copied to `src/assets/logo.png`.                                     |
| `OPEN_EDGE_AI_README_LOGO_SOURCE` | Optional source file copied to `docs/assets/open-edge-ai-logo.png`.                       |
| `OPEN_EDGE_AI_ANDROID_ICON_DIR`   | Optional prepared Android icon resource directory copied into `android/app/src/main/res`. |
| `OPEN_EDGE_AI_IOS_ICON_DIR`       | Optional prepared iOS `AppIcon.appiconset` directory copied into the iOS asset catalog.   |

## Logo

The in-app menu logo is imported from `src/config/branding.ts` and currently
points to:

```text
src/assets/logo.png
```

To replace it:

```sh
OPEN_EDGE_AI_LOGO_SOURCE=branding/logo.png npm run branding:apply
```

The source image can be absolute or relative to the repository root.

## App Icons

Native app icons are platform asset sets, not runtime images. Prepare the
correctly sized files first, then point the script to the generated directories.

Android directory shape:

```text
branding/android/
├── mipmap-mdpi/ic_launcher.png
├── mipmap-mdpi/ic_launcher_round.png
├── mipmap-hdpi/ic_launcher.png
├── mipmap-hdpi/ic_launcher_round.png
└── ...
```

iOS directory shape:

```text
branding/ios/AppIcon.appiconset/
├── Contents.json
├── Icon-App-1024x1024@1x.png
└── ...
```

Then run:

```sh
OPEN_EDGE_AI_ANDROID_ICON_DIR=branding/android \
OPEN_EDGE_AI_IOS_ICON_DIR=branding/ios/AppIcon.appiconset \
npm run branding:apply
```

## Native Name Notes

`OPEN_EDGE_AI_APP_NAME` is the React Native registry name. The branding script
updates the JavaScript app config and native React Native entry points, but it
does not rename the iOS Xcode target, scheme, Android package directory, or
Kotlin package namespace. Prefer changing `OPEN_EDGE_AI_DISPLAY_NAME`,
`OPEN_EDGE_AI_ANDROID_APP_NAME`, and `OPEN_EDGE_AI_IOS_DISPLAY_NAME` for ordinary
launcher-facing rebranding.
