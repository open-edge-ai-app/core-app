# Architecture

Open Edge AI is designed as a local-first mobile AI app. The React Native layer
owns the user experience, while native modules own model execution, indexing,
and platform-specific capabilities.

## High-Level Flow

```text
User
  -> React Native screens and components
  -> src/native/AIEngine.ts
  -> NativeModules.AIEngine
  -> Android bridge module
  -> QueryRouter
  -> Model runtime / embeddings / vector DB / indexing workers
```

## Layers

### React Native App

The app root lives in `App.tsx`. It coordinates:

- active screen state;
- selected model state;
- chat session persistence;
- work folder persistence;
- full-screen navigation menu;
- display personalization.

Reusable UI lives under `src/components`, screens under `src/screens`, and
shared visual tokens under `src/theme`.

### Native Bridge

`src/native/AIEngine.ts` is the typed TypeScript facade around
`NativeModules.AIEngine`. It normalizes the native API for React Native and
provides development fallbacks when a native implementation is unavailable.

The bridge currently covers:

- text generation;
- multimodal message routing;
- indexing status;
- model status;
- startup state;
- runtime status;
- model download, load, unload, and cancellation.

### Android Native Core

Android native code lives under `android/app/src/main/java/com/openedgeai`.

- `bridge/` registers and exposes React Native methods.
- `core/` owns routing, model lifecycle, runtime status, embeddings, vision, and
  multimodal request handling.
- `db/` owns vector persistence and similarity lookup helpers.
- `workers/` owns background indexing jobs.

### iOS Native Core

The iOS shell is present under `ios/`. The Swift native AI bridge is planned and
should mirror the TypeScript contract exposed by `src/native/AIEngine.ts`.

### Web Preview

The web target uses Vite and `react-native-web`. It exists for fast UI
iteration; native AI features fall back to development responses in this mode.

## Data Storage

React Native UI state is persisted with AsyncStorage:

- active chat session;
- chat messages by session;
- draft messages;
- recent sessions;
- work folders and folder sessions;
- selected model;
- display settings.

Android indexing and vector retrieval use local SQLite helpers in `db/`.

## Model Lifecycle

The model lifecycle is intentionally device-local:

1. Check startup state.
2. Check model status.
3. Download or locate the local model file.
4. Load runtime when generation is requested.
5. Unload runtime when the host is destroyed or the bridge is invalidated.

Large model binaries are not tracked by Git. See
[MODEL_ASSETS.md](MODEL_ASSETS.md).

## Privacy Model

Open Edge AI is intended to minimize server dependency by keeping chat context,
indexing, embeddings, and model execution on device wherever possible. Any
future network feature should document:

- what data leaves the device;
- why it is needed;
- whether it is optional;
- retention and deletion behavior.

## Current Limitations

- The iOS native AI bridge is not implemented yet.
- Model runtime support depends on the installed Android model asset and runtime
  compatibility.
- Streaming APIs are represented in contracts but not treated as stable public
  API yet.
