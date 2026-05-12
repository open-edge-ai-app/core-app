# Project Structure

This document describes the intended open-source structure of the repository.

```text
open-edge-ai/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── config.yml
│   │   └── feature_request.yml
│   ├── workflows/
│   │   └── ci.yml
│   ├── dependabot.yml
│   └── PULL_REQUEST_TEMPLATE.md
├── .agents/
│   └── skills/
│       └── shadcn/
├── __tests__/
│   └── App.test.tsx
├── android/
│   ├── app/
│   │   ├── src/main/assets/
│   │   └── src/main/java/com/onda/
│   │       ├── bridge/
│   │       ├── core/
│   │       ├── db/
│   │       └── workers/
│   ├── build.gradle
│   └── settings.gradle
├── docs/
│   ├── ARCHITECTURE.md
│   ├── BRANDING.md
│   ├── DEVELOPMENT.md
│   ├── MODEL_ASSETS.md
│   └── PROJECT_STRUCTURE.md
├── ios/
│   ├── OpenEdgeAI/
│   ├── OpenEdgeAI.xcodeproj/
│   └── Podfile
├── scripts/
│   └── apply-branding.mjs
├── src/
│   ├── assets/
│   ├── components/
│   │   ├── ui/
│   │   ├── AppIcon.tsx
│   │   ├── ChatBubble.tsx
│   │   ├── FloatingSelect.tsx
│   │   ├── LoadingDots.tsx
│   │   └── PastelBackground.tsx
│   ├── config/
│   │   └── branding.ts
│   ├── native/
│   │   └── AIEngine.ts
│   ├── screens/
│   │   ├── ChatScreen.tsx
│   │   └── Settings.tsx
│   ├── theme/
│   │   ├── display.tsx
│   │   ├── icons.ts
│   │   └── tokens.ts
│   ├── types/
│   │   └── assets.d.ts
│   └── web/
│       ├── ReactNativeSvg.tsx
│       └── SafeAreaContext.tsx
├── App.tsx
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── COMMERCIAL_SUPPORT.md
├── CONTRIBUTING.md
├── LICENSE
├── README.md
├── SECURITY.md
├── SUPPORT.md
├── app.json
├── index.js
├── index.web.tsx
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## Directory Responsibilities

| Path                 | Responsibility                                           |
| -------------------- | -------------------------------------------------------- |
| `.github/`           | GitHub automation, issue templates, PR template, and CI. |
| `.agents/`           | Local Codex/shadcn skill context used by this project.   |
| `__tests__/`         | Jest tests.                                              |
| `android/`           | Android app shell and Kotlin native AI implementation.   |
| `docs/`              | Long-form documentation.                                 |
| `ios/`               | iOS app shell and future native AI implementation.       |
| `scripts/`           | Repository maintenance scripts.                          |
| `src/assets/`        | Static assets used by the React Native app.              |
| `src/components/`    | Reusable UI components.                                  |
| `src/components/ui/` | shadcn-inspired local UI component exports.              |
| `src/config/`        | App-level generated configuration such as branding.      |
| `src/native/`        | Typed React Native native module wrappers.               |
| `src/screens/`       | Top-level app screens.                                   |
| `src/theme/`         | Shared icons, tokens, and display scaling utilities.     |
| `src/types/`         | Shared TypeScript declarations.                          |
| `src/web/`           | Web compatibility shims for browser preview.             |

## Naming Guidelines

- React components use `PascalCase.tsx`.
- TypeScript utilities use clear domain names.
- Native bridge files should mirror the public TypeScript contract.
- Android package ownership stays under `com.onda`.
- Documentation files use uppercase names for repository-level docs and
  descriptive uppercase names under `docs/`.
