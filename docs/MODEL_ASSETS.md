# Model Assets

Open Edge AI is designed to support local AI model files without committing
large binaries to the repository.

## Git Policy

Do not commit model binaries, generated runtime artifacts, or downloaded
weights. The `.gitignore` file excludes common model asset locations and file
types.

Tracked placeholder files document the expected locations only.

## Android Development Asset

Expected development model:

```text
android/app/src/main/assets/models/gemma-4-E2B-it.litertlm
```

This file is intentionally ignored by Git. Keep it locally when you need an APK
that can run offline immediately after install.

## Runtime Download

For production-like flows, prefer downloading the model on first launch and
storing it in app internal storage. This keeps the repository small and avoids
shipping incompatible model files to every build variant.

## Placeholders

The repository includes placeholder files under:

```text
android/app/src/main/assets/
android/app/src/main/assets/models/
```

These files are documentation aids, not usable model binaries.

## Security Notes

Future model download implementations should validate:

- expected file name;
- expected size;
- checksum or signature;
- storage location;
- partial download cleanup;
- cancellation behavior.
