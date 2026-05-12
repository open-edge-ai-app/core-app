# Bundled LLM Assets

Place local MediaPipe LLM model files here for development builds.

Expected development model:

- `gemma-4-E2B-it.litertlm`
- `universal_sentence_encoder.tflite`
- `mobilenet_v3_small.tflite`

The binary model is intentionally ignored by Git because it is several GB. Keep
this directory populated locally when building an APK that should work offline.
The text and image embedder files are fixed to the MediaPipe recommended models:

- Text: https://storage.googleapis.com/mediapipe-models/text_embedder/universal_sentence_encoder/float32/latest/universal_sentence_encoder.tflite
- Image: https://storage.googleapis.com/mediapipe-models/image_embedder/mobilenet_v3_small/float32/latest/mobilenet_v3_small.tflite
