# LiteRT-LM iOS Runtime

This directory is for locally built LiteRT-LM XCFrameworks:

- `LiteRTLM.xcframework`
- `GemmaModelConstraintProvider.xcframework`

Google's LiteRT-LM repository currently does not publish a ready-to-use iOS
runtime binary. Build the frameworks locally:

```sh
bash scripts/build-ios-litertlm-runtime.sh sim
cd ios && pod install
```

Use `all` instead of `sim` when you need both simulator and device slices.
The generated frameworks are intentionally ignored by git because they are
large local build artifacts.
