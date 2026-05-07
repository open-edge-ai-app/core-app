# On-Da Model Assets

Place lightweight local model assets here only when they are safe to ship inside
the APK.

- `use.tflite`: Universal Sentence Encoder embedding model.
- `gemma-4.bin`: Gemma model file, if the selected build variant can package it.

For large Gemma files, prefer downloading on first launch and storing the model
under app internal storage instead of committing it here.
