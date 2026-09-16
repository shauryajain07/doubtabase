# Doubtabase

Doubtabase is a native SwiftUI macOS app for turning difficult question screenshots into a local, searchable learning library.

The idea is simple: a question you got wrong should not disappear into a screenshot folder. Doubtabase keeps the original question, extracts what it can understand, and makes it easier to find the same kind of mistake again.

## What it does

- Captures screenshots through a compact top-center drop panel.
- Accepts files, screenshot thumbnails, PNG, TIFF, and generic image data.
- Stores images and the question library locally in Application Support.
- Extracts text on-device with Apple Vision OCR.
- Splits recognized text into overlapping chunks and indexes it with local English sentence embeddings.
- Suggests subjects and keeps ambiguous captures in **Unsorted**.
- Combines keyword search with cosine-similarity retrieval.
- Shows cited context from the five most relevant questions and can copy that context to the clipboard.
- Tracks folders, subjects, review status, and question counts.
- Opens uncropped previews and the original image when needed.

## Retrieval, not generated answers

Doubtabase assembles useful context for a language model; it does not generate answers or send source material anywhere automatically. The screenshot, OCR text, and vectors stay on the Mac. If the embedding model is unavailable, keyword search still works.

This boundary is deliberate. The first job is to remember and retrieve the mistakes accurately. A future answer layer can build on that grounded context without hiding where it came from.

## Local development

The project needs Swift 6 and macOS 14 or newer.

```bash
swift build
swift run
```

To create a local app bundle:

```bash
./scripts/build-app.sh
open .build/Recall.app
```

Run the retrieval and folder persistence checks with:

```bash
./scripts/test-retrieval.sh
./scripts/test-folders.sh
```

The available verification path uses Swift Package Manager and the macOS SDK. Signing, entitlements, and App Store distribution still need to be completed in Xcode with an Apple Developer account.

## Current boundaries

- OCR can miss handwriting, equations, and diagram-only questions.
- Subject labels are suggestions, not verified classifications.
- The index uses a linear scan, which is appropriate for a personal library rather than a large shared corpus.
- A library starts empty and grows as screenshots are added.
