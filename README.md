<div align="center">
  <img src="src/assets/logo.png" alt="Open Edge AI" width="360" />

  <h1>Open Edge AI</h1>

  <p>
    Local-first AI chat for mobile. Built with React Native, backed by native
    on-device AI modules, and designed to keep private context close to the user.
  </p>

  <p>
    <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-111111.svg" /></a>
    <a href="https://github.com/open-edge-ai-app/open-edge-ai/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/open-edge-ai-app/open-edge-ai/actions/workflows/ci.yml/badge.svg" /></a>
    <img alt="React Native" src="https://img.shields.io/badge/React%20Native-0.85-61dafb.svg" />
    <img alt="TypeScript" src="https://img.shields.io/badge/TypeScript-ready-3178c6.svg" />
  </p>
</div>

## Overview

Open Edge AI is an open-source React Native application for building a modern
AI chat experience around local models, multimodal inputs, and device-side
retrieval. The app currently includes:

- a polished iOS-inspired chat interface;
- persistent chat sessions and work folders;
- a typed React Native bridge for native AI calls;
- Android Kotlin modules for model status, model loading, routing, embeddings,
  vector search, and background indexing;
- a web preview target for fast UI iteration with `react-native-web`.

The project is under active development. APIs and native model integration
details may change before the first stable release.

## Features

- Local-first chat UI with model selection and session management.
- Work folder tree with rename, settings, pin, remove, and delete actions.
- Persisted chat sessions, folders, selected model, and display settings.
- FontAwesome/SVG icon pipeline for consistent cross-platform rendering.
- Native AI bridge contract in TypeScript.
- Android native AI engine scaffolding and implementation under `com.onda`.
- Web preview for frontend-only development.

## Project Status

| Area                     | Status      |
| ------------------------ | ----------- |
| React Native chat UI     | Active      |
| Android native bridge    | Active      |
| Local model lifecycle    | Active      |
| Vector DB / RAG pipeline | Active      |
| iOS native AI module     | Planned     |
| Public release process   | In progress |

## Repository Structure

```text
.
├── App.tsx                     # React Native root component
├── src/                        # Cross-platform UI, bridge, theme, and web shims
│   ├── assets/                 # App logo and static assets
│   ├── components/             # Reusable React Native components
│   ├── native/                 # TypeScript wrapper around NativeModules.AIEngine
│   ├── screens/                # Chat and settings screens
│   ├── theme/                  # Tokens, icons, and display scaling
│   └── web/                    # React Native Web compatibility shims
├── android/                    # Android app and Kotlin on-device AI core
│   └── app/src/main/java/com/onda/
│       ├── bridge/             # React Native <-> Kotlin bridge
│       ├── core/               # Model runtime, routing, embeddings, vision
│       ├── db/                 # SQLite vector store helpers
│       └── workers/            # Background indexing workers
├── ios/                        # iOS app shell and future Swift AI module home
├── docs/                       # Architecture, development, and structure docs
├── .github/                    # Issue templates, PR template, CI, Dependabot
├── COMMERCIAL_SUPPORT.md       # Voluntary commercial support notice
└── LICENSE                     # MIT License
```

For a more detailed tree, see [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md).

## Getting Started

### Requirements

- Node.js `>= 22.11.0`
- npm
- OpenJDK 17 for Android builds
- Android Studio and Android SDK for Android development
- Xcode and CocoaPods for iOS development on macOS

### Install

```sh
npm install
```

### Run

```sh
# Metro for the default React Native port
npm start

# Metro on port 8082, useful when 8081 is occupied
npm run start:android

# Android app
npm run android
npm run android:8082

# iOS app
npm run ios

# Browser preview
npm run web
```

## Model Assets

Large local model binaries are intentionally not committed. Development builds
can use placeholder files under `android/app/src/main/assets/`, while real model
files should be downloaded on device or stored locally outside Git.

Expected development model path:

```text
android/app/src/main/assets/models/gemma-4-E2B-it.litertlm
```

See [docs/MODEL_ASSETS.md](docs/MODEL_ASSETS.md) for model asset policy and
runtime notes.

## Development

Common quality checks:

```sh
npm run lint
npx tsc --noEmit
npm test -- --runInBand
```

More setup and troubleshooting notes are available in
[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).

## Architecture

Open Edge AI is split into a cross-platform React Native shell and native model
execution modules.

```text
React Native UI
  -> src/native/AIEngine.ts
  -> NativeModules.AIEngine
  -> Android Kotlin bridge
  -> Query router / model runtime / vector DB / indexing workers
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Contributing

Contributions are welcome. Please read:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- [SECURITY.md](SECURITY.md)

## Commercial Support

Open Edge AI is MIT-licensed and can be used commercially under the license
terms. Organizations that rely on the project commercially are encouraged to
support maintenance. See [COMMERCIAL_SUPPORT.md](COMMERCIAL_SUPPORT.md).

## License

Open Edge AI is released under the [MIT License](LICENSE).
