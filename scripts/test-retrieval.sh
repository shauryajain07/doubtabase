#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -parse-as-library Sources/RecallMac/Models.swift Sources/RecallMac/QuestionRetrieval.swift Tests/RecallMacTests/RetrievalTests.swift -o .build/retrieval-tests
.build/retrieval-tests
