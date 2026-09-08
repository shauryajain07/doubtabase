# Doubtabase for Mac

Doubtabase is a native SwiftUI macOS foundation for saving difficult question screenshots during study.

## Current slice

- Compact top-center borderless capture panel that blends into the menu-bar/notch area when idle.
- Expanded drop target when an image is dragged over the panel.
- Public SwiftUI drag-and-drop support for image files and macOS screenshot thumbnails (file URL, PNG, TIFF, and generic image data).
- Lightweight expansion while a drag is over the target, with a stable hit region so the panel does not chase the pointer.
- Local image copies and a JSON library stored in the app's Application Support directory.
- On-device OCR of screenshot text using Apple Vision.
- Local English sentence embeddings, persisted with overlapping text chunks in the JSON library.
- Vector-based subject suggestions; ambiguous or unreadable captures stay Unsorted.
- Hybrid keyword and cosine-similarity search, sorted by relevance within the selected sidebar filter.
- Cited RAG context preview and clipboard export from the top five retrieved questions.
- Sidebar navigation for all questions, questions to review, reviewed questions, and subjects.
- Search with Command-F and image import with Command-O.
- Uncropped image previews, a full question viewer, and Open original.
- Persistent review status with live counts; sample questions are labeled.
- A black capture panel that expands on hover, with space reserved below the physical notch.

The panel is a normal floating app window positioned at the top center of the display. It does not access or integrate with the physical Mac notch, and no private APIs are used.

## Run locally

```bash
swift build
swift run
```

To create a local `.app` bundle for opening in Finder or with `open`:

```bash
./scripts/build-app.sh
open .build/Recall.app
```

The local environment has the Swift compiler and macOS SDK, but not the full Xcode app. `swift build` and the local `.app` launch are the available verification paths here; signing, entitlements, and App Store submission still need to be completed in Xcode on a development machine with an Apple Developer account.

## Semantic retrieval

Existing captures are indexed automatically on launch; new captures are indexed in the background.
Open a question to inspect recognized text. OCR failures can be retried using **Retry indexing**.
Screenshots, recognized text, and vectors remain on this Mac; no credentials or remote database are required.
The embedding cache includes the Apple model revision and chunking version and is refreshed when either changes.

Enter a study concept in search to rank questions by relevance. Exact text matches are preferred,
with semantic similarity extending retrieval to related wording. English embeddings depend on the
model being available on macOS; when unavailable, keyword search still works. OCR may miss handwriting,
equations, or diagram-only questions. Subject labels are suggestions, not verified classifications.
The index uses a linear scan, intended for a personal library rather than a large shared collection.

**View RAG context** shows bounded source excerpts with stable question IDs and numbered citations.
**Copy context** exports a grounding prompt for a language model. This version implements retrieval
and context assembly, not generated answers or a chat model. No source content is sent anywhere automatically.

Run the retrieval checks (compatible with Command Line Tools without XCTest):

```bash
./scripts/test-retrieval.sh
```

Apple API references: [sentence embeddings](https://developer.apple.com/documentation/naturallanguage/nlembedding)
and [text recognition](https://developer.apple.com/documentation/vision/vnrecognizetextrequest).

## Organizing questions

Use the + beside Folders or Subjects to create your own groups. Add screenshots while viewing a folder or subject to assign them on import. A question can belong to one folder and one subject. Open a question to change either assignment, or right-click a card to move it to a folder. Right-click a folder to rename it or remove it while keeping its questions in Unfiled. Manually chosen subjects are preserved during text recognition.

New libraries start empty. Existing question-only library files are migrated on the next save; questions, folders, and custom subjects are saved together in the local library index.

Run `./scripts/test-folders.sh` for isolated folder/subject persistence and migration checks (no Xcode test runtime required).

Automatic classification uses only the subjects explicitly added by the user through New subject. No built-in subject catalog is used. With no subjects or no confident match, captures remain Unsorted. Adding a subject refreshes automatic classifications; manually assigned subjects are preserved.
