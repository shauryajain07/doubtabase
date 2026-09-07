#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -parse-as-library Sources/RecallMac/Models.swift Sources/RecallMac/QuestionRetrieval.swift Sources/RecallMac/LibraryStore.swift Tests/RecallMacTests/FolderTests.swift -o .build/folder-tests
.build/folder-tests
