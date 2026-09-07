import Foundation

struct SubjectSuggestion: Codable, Equatable, Hashable {
    let subject: String
    let topic: String
    let accent: String
}

struct Question: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    let excerpt: String
    var subject: String
    var topic: String
    let source: String
    let capturedLabel: String
    let imagePath: String?
    let visualMark: String
    let accent: String
    var recognizedText: String?
    var searchIndex: QuestionIndex?
    var indexingError: String?
    var folderID: UUID?
    var isSubjectManuallyAssigned: Bool?
    var reviewProgress: Int

    init(
        id: UUID = UUID(),
        title: String,
        excerpt: String,
        subject: String,
        topic: String,
        source: String,
        capturedLabel: String,
        imagePath: String? = nil,
        visualMark: String,
        accent: String,
        reviewProgress: Int
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.subject = subject
        self.topic = topic
        self.source = source
        self.capturedLabel = capturedLabel
        self.imagePath = imagePath
        self.visualMark = visualMark
        self.accent = accent
        self.reviewProgress = reviewProgress
    }
}

struct CaptureNotice: Identifiable, Equatable {
    let id = UUID()
    let fileName: String
    let suggestion: SubjectSuggestion
}

enum SampleData {
    static let questions: [Question] = [
        Question(
            title: "Why do price ceilings create shortages?",
            excerpt: "I understand the graph, but not why the shortage persists when demand changes.",
            subject: "Economics",
            topic: "Microeconomics",
            source: "IB Economics",
            capturedLabel: "Today, 9:42 AM",
            visualMark: "Pmax  <  Peq",
            accent: "coral",
            reviewProgress: 28
        ),
        Question(
            title: "When should I use integration by parts?",
            excerpt: "The LIATE rule makes sense, but I keep choosing the wrong term for u.",
            subject: "Mathematics",
            topic: "Calculus",
            source: "Math HL · Paper 2",
            capturedLabel: "Yesterday, 4:18 PM",
            visualMark: "∫  u · dv",
            accent: "lilac",
            reviewProgress: 62
        ),
        Question(
            title: "Active vs. passive transport",
            excerpt: "Can a molecule move against the gradient without ATP being used directly?",
            subject: "Biology",
            topic: "Cell biology",
            source: "Biology notes",
            capturedLabel: "Mon, 11:06 AM",
            visualMark: "ATP  →  ADP",
            accent: "sage",
            reviewProgress: 0
        ),
        Question(
            title: "Inflation falls while nominal wages stay flat",
            excerpt: "I can calculate the real wage, but I want to explain the intuition clearly.",
            subject: "Economics",
            topic: "Macroeconomics",
            source: "Macro revision",
            capturedLabel: "Sun, 8:36 PM",
            visualMark: "real wage  ↑",
            accent: "blue",
            reviewProgress: 74
        ),
        Question(
            title: "Why is tension not always equal to mg?",
            excerpt: "The free-body diagram looks right, but my answer changes when the pulley moves.",
            subject: "Physics",
            topic: "Mechanics",
            source: "Physics · Forces",
            capturedLabel: "Sat, 2:12 PM",
            visualMark: "ΣF = ma",
            accent: "gold",
            reviewProgress: 41
        ),
        Question(
            title: "Was containment defensive or expansionist?",
            excerpt: "I need a cleaner line between the Truman Doctrine and the Marshall Plan.",
            subject: "History",
            topic: "Cold War",
            source: "History essay prep",
            capturedLabel: "Fri, 6:54 PM",
            visualMark: "1947  →  1949",
            accent: "coral",
            reviewProgress: 0
        )
    ]
}

struct LibraryFolder: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
}

struct LibrarySnapshot: Codable {
    var questions: [Question]
    var folders: [LibraryFolder]
    var subjects: [String]?
}
