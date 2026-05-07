# Open Edge AI

React Native 기반 온디바이스 AI 채팅 앱의 프론트엔드 초기 세팅입니다.

현재 범위는 UI와 TypeScript 브릿지 인터페이스까지입니다. Kotlin 기반 AI 추론, 인덱싱, 벡터 DB 로직은 이후 `android/app/src/main/java/com/onda` 아래에 붙이면 됩니다.

## Stack

- React Native 0.85.2
- React 19.2.3
- TypeScript
- Android package / iOS bundle ID: `com.onda`

## Scripts

```sh
npm start
npm run start:android
npm run android
npm run android:8082
npm run ios
npm run web
npm test
npm run lint
```

## Frontend Structure

```text
src/
  components/
    ChatBubble.tsx
    LoadingDots.tsx
  native/
    AIEngine.ts
  screens/
    ChatScreen.tsx
    Settings.tsx
```

## Native Bridge Contract

`src/native/AIEngine.ts` wraps `NativeModules.AIEngine`.

Expected native methods:

- `generateResponse(prompt, history)`
- `getIndexingStatus()`
- `startIndexing()`

If the native module is not connected yet, the frontend returns a development response so UI work can continue independently.

## Notes

- `android/app/src/main/assets/` is prepared for future local model assets.
- `npm run web` starts a browser preview for frontend-only testing with `react-native-web`.
- For Android device/emulator testing in this local environment, use `npm run start:android` and `npm run android:8082` because port `8081` is already occupied.
- CocoaPods were not installed during scaffolding. For iOS, run `bundle install` and `bundle exec pod install` inside `ios/` when needed.
- Android testing is configured with OpenJDK 17 and Android SDK at `~/Library/Android/sdk`.
