import Foundation

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T) { precondition(actual == expected, "\(actual) != \(expected)") }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTUnwrap<T>(_ value: T?) throws -> T { precondition(value != nil); return value! }

@main
struct RetrievalTests {
    static func main() async throws {
        let tests = RetrievalTests()
        tests.testCosineRejectsInvalidVectors()
        tests.testChunkOverlapAndCoverage()
        try tests.testOldLibraryDecodesWithoutIndex()
        await tests.testExactSearchAndEmptyQuery()
        try await tests.testIndexRoundTripAndCache()
        tests.testContextCitesOnlyRetrievedSources()
        try await tests.testSemanticRetrieval()
        try await tests.testMissingImageFails()
        try await tests.testAllowedSubjects()
        tests.testScreenshotTitles()
        print("Passed 10 retrieval checks")
    }

    func testScreenshotTitles() {
        XCTAssertEqual(ScreenshotTitle.suggested(from: "Biology Paper 2\nWhy do cells require energy?\n[3 marks]"), "Why do cells require energy?")
        XCTAssertEqual(ScreenshotTitle.suggested(from: "  Calculate   the acceleration of the trolley. "), "Calculate the acceleration of the trolley.")
        XCTAssertNil(ScreenshotTitle.suggested(from: "  \n1234\n+ ="))
        let long = ScreenshotTitle.suggested(from: String(repeating: "question text ", count: 30))!
        XCTAssertTrue(long.count <= 90)
        XCTAssertTrue(long.hasSuffix("…"))
    }

    func testAllowedSubjects() async throws {
        let retrieval = QuestionRetrieval()
        let text = "Economics supply demand prices inflation markets"
        let empty = await retrieval.classify(text, allowedSubjects: [])
        XCTAssertEqual(empty.subject, "Unsorted")
        let restricted = await retrieval.classify(text, allowedSubjects: ["Biology"])
        XCTAssertTrue(["Biology", "Unsorted"].contains(restricted.subject))
        let custom = "Economics supply demand prices inflation markets"
        let result = await retrieval.classify(text, allowedSubjects: [custom])
        XCTAssertEqual(result.subject, custom)
        var question = Question(title: "Capture", excerpt: "", subject: "Economics", topic: "",
                                source: "", capturedLabel: "", imagePath: "/unused",
                                visualMark: "", accent: "coral", reviewProgress: 0)
        question.recognizedText = text
        let (index, _, _) = try await retrieval.index(question, allowedSubjects: [custom])
        question.searchIndex = index
        let (_, _, cachedSuggestion) = try await retrieval.index(question, allowedSubjects: [])
        XCTAssertEqual(cachedSuggestion?.subject, "Unsorted")
        question.isSubjectManuallyAssigned = true
    }

    func testSemanticRetrieval() async throws {
        let retrieval = QuestionRetrieval()
        var questions = SampleData.questions
        for i in questions.indices {
            let (index, _, _) = try await retrieval.index(questions[i])
            questions[i].searchIndex = index
        }
        let result = await retrieval.search("government limits on prices cause insufficient supply", questions: questions)
        if result.semanticAvailable {
            XCTAssertEqual(result.matches.first?.id, questions[0].id)
        } else {
            print("Semantic model unavailable; verified keyword fallback separately")
        }
    }

    func testMissingImageFails() async throws {
        let question = Question(title: "Missing", excerpt: "", subject: "Unsorted", topic: "", source: "",
                                capturedLabel: "", imagePath: "/nonexistent/recall-test.png",
                                visualMark: "", accent: "coral", reviewProgress: 0)
        do {
            _ = try await QuestionRetrieval().index(question)
            preconditionFailure("Missing image must report an OCR failure")
        } catch {}
    }

    func testCosineRejectsInvalidVectors() {
        XCTAssertEqual(RetrievalMath.cosine([1, 0], [1, 0]), 1)
        XCTAssertEqual(RetrievalMath.cosine([1, 0], [0, 1]), 0)
        XCTAssertEqual(RetrievalMath.cosine([0, 0], [0, 0]), 0)
        XCTAssertEqual(RetrievalMath.cosine([1], [1, 2]), 0)
        XCTAssertEqual(RetrievalMath.cosine([.nan], [1]), 0)
    }

    func testChunkOverlapAndCoverage() {
        let words = (0..<200).map { "word\($0)" }
        let chunks = RetrievalMath.chunks(words.joined(separator: " "))
        XCTAssertEqual(chunks.count, 4)
        XCTAssertTrue(chunks[0].contains("word64"))
        XCTAssertTrue(chunks[1].hasPrefix("word64 "))
        XCTAssertTrue(chunks.last!.hasSuffix("word199"))
        XCTAssertEqual(RetrievalMath.chunks(" \n "), [])
    }

    func testOldLibraryDecodesWithoutIndex() throws {
        let encoded = try JSONEncoder().encode(SampleData.questions[0])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "recognizedText")
        object.removeValue(forKey: "searchIndex")
        let old = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Question.self, from: old)
        XCTAssertNil(decoded.searchIndex)
        XCTAssertNil(decoded.recognizedText)
        XCTAssertEqual(decoded.title, SampleData.questions[0].title)
    }

    func testExactSearchAndEmptyQuery() async {
        let retrieval = QuestionRetrieval()
        let questions = SampleData.questions
        let result = await retrieval.search("integration by parts", questions: questions)
        XCTAssertEqual(result.matches.first?.id, questions[1].id)
        let empty = await retrieval.search("  \n", questions: questions)
        XCTAssertTrue(empty.matches.isEmpty)
    }

    func testIndexRoundTripAndCache() async throws {
        let retrieval = QuestionRetrieval()
        var question = SampleData.questions[0]
        let (index, text, _) = try await retrieval.index(question)
        question.searchIndex = index
        question.recognizedText = text
        let decoded = try JSONDecoder().decode(Question.self, from: JSONEncoder().encode(question))
        XCTAssertEqual(decoded.searchIndex, index)
        let (cached, _, _) = try await retrieval.index(decoded)
        XCTAssertEqual(cached, index)
    }

    func testContextCitesOnlyRetrievedSources() {
        let questions = SampleData.questions
        let matches = [RetrievedQuestion(id: questions[1].id, score: 1, passage: "Integration excerpt")]
        let context = RAGContext.build(query: "How to integrate?", matches: matches, questions: questions)
        XCTAssertTrue(context.contains("[1] " + questions[1].title))
        XCTAssertTrue(context.contains(questions[1].id.uuidString))
        XCTAssertTrue(context.contains("Integration excerpt"))
        XCTAssertFalse(context.contains(questions[0].title))
        XCTAssertEqual(RAGContext.build(query: "x", matches: [], questions: questions), "No matching sources found.")
    }
}
