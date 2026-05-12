# Contributing to Open Edge AI

Thank you for considering a contribution to Open Edge AI. This project welcomes
bug reports, documentation improvements, design refinements, tests, and focused
feature work.

## Code of Conduct

All participants are expected to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Development Setup

1. Fork and clone the repository.
2. Install dependencies:

   ```sh
   npm install
   ```

3. Run the app target you are working on:

   ```sh
   npm run web
   npm run start:android
   npm run android:8082
   npm run ios
   ```

4. Run checks before opening a pull request:

   ```sh
   npm run lint
   npx tsc --noEmit
   npm test -- --runInBand
   ```

## Contribution Workflow

- Keep pull requests focused on one change.
- Prefer small, reviewable commits with clear messages.
- Include screenshots or screen recordings for UI changes when practical.
- Update documentation when behavior, setup, architecture, or public contracts
  change.
- Do not commit local model binaries, credentials, generated build outputs, or
  personal machine configuration.

## Areas to Contribute

- React Native chat UI and interaction polish.
- Android native AI runtime integration.
- Model download and lifecycle management.
- Vector DB and indexing reliability.
- iOS native AI bridge implementation.
- Accessibility, localization, tests, and documentation.

## Pull Request Checklist

- [ ] The change is scoped and explained.
- [ ] Lint, type check, and tests pass locally.
- [ ] UI changes include visual evidence when relevant.
- [ ] New files follow the existing project structure.
- [ ] Documentation is updated where needed.

## Security Issues

Please do not report security vulnerabilities in public issues. Follow
[SECURITY.md](SECURITY.md) instead.
