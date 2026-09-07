import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var questions: [Question]
    @Published private(set) var folders: [LibraryFolder] = []
    @Published private(set) var customSubjects: [String] = []
    private let indexAutomatically: Bool
    @Published private(set) var lastCapture: CaptureNotice?
    @Published var errorMessage: String?

    @Published private(set) var indexingCount = 0
    @Published private(set) var indexRevision = 0
    let retrieval = QuestionRetrieval()
    private var pendingIndexIDs = Set<UUID>()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let libraryDirectory: URL
    private let capturesDirectory: URL
    private let indexURL: URL

    init(libraryDirectory suppliedDirectory: URL? = nil, indexAutomatically: Bool = true) {
        self.indexAutomatically = indexAutomatically
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        libraryDirectory = suppliedDirectory ?? applicationSupport.appendingPathComponent("Recall", isDirectory: true)
        capturesDirectory = libraryDirectory.appendingPathComponent("Captures", isDirectory: true)
        indexURL = libraryDirectory.appendingPathComponent("library.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        questions = []
        load()
        questions.forEach(scheduleIndex)
    }

    var subjectNames: [String] {
        let subjects = Set(questions.map(\.subject) + customSubjects)
        return subjects.sorted()
    }

    func importProviders(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, _ in
                    guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    Task { @MainActor [weak self] in
                        self?.importFile(at: url)
                    }
                }
                continue
            }

            let imageTypeIdentifiers = [
                UTType.png.identifier,
                UTType.tiff.identifier,
                UTType.image.identifier,
                UTType.data.identifier
            ]

            if let imageTypeIdentifier = imageTypeIdentifiers.first(where: provider.hasItemConformingToTypeIdentifier) {
                provider.loadDataRepresentation(forTypeIdentifier: imageTypeIdentifier) { [weak self] data, _ in
                    guard let data else { return }
                    Task { @MainActor [weak self] in
                        let extensionName = imageTypeIdentifier == UTType.tiff.identifier ? "tiff" : "png"
                        self?.importData(data, fileName: "Screenshot \(Self.timestampLabel()).\(extensionName)")
                    }
                }
            }
        }
    }

    func importFile(at url: URL, folderID: UUID? = nil, subject: String? = nil) {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else { return }
        importData(data, fileName: url.lastPathComponent, folderID: folderID, subject: subject)
    }

    func importWithOpenPanel() { importWithOpenPanel(into: nil) }

    func importWithOpenPanel(into folderID: UUID?, subject: String? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { importFile(at: $0, folderID: folderID, subject: subject) }
    }

    func setReviewed(_ question: Question, reviewed: Bool) {
        guard let index = questions.firstIndex(where: { $0.id == question.id }) else { return }
        questions[index].reviewProgress = reviewed ? 100 : 0
        persist()
    }

    func delete(_ question: Question) {
        if let imagePath = question.imagePath {
            try? fileManager.removeItem(atPath: imagePath)
        }
        questions.removeAll { $0.id == question.id }
        persist()
    }

    private func importData(_ data: Data, fileName: String, folderID: UUID? = nil, subject: String? = nil) {
        guard NSImage(data: data) != nil else {
            errorMessage = "Choose a valid image file to add to your library."
            return
        }
        let suggestion = SubjectSuggestion(subject: "Unsorted", topic: "Indexing…", accent: "coral")
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.isEmpty
            ? "png"
            : URL(fileURLWithPath: fileName).pathExtension.lowercased()
        let destination = capturesDirectory.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")

        do {
            try fileManager.createDirectory(at: capturesDirectory, withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        } catch {
            errorMessage = "The screenshot could not be saved. Check available disk space and try again."
            return
        }

        var question = Question(
            title: title(for: fileName),
            excerpt: "Work through this question, then mark it reviewed. Subject labels are suggested from screenshot text.",
            subject: suggestion.subject,
            topic: suggestion.topic,
            source: "Imported screenshot",
            capturedLabel: "Just now",
            imagePath: destination.path,
            visualMark: "New capture",
            accent: suggestion.accent,
            reviewProgress: 0
        )

        question.folderID = folders.contains(where: { $0.id == folderID }) ? folderID : nil
        if let subject, subjectNames.contains(subject) {
            question.subject = subject
            question.topic = "General"
            question.isSubjectManuallyAssigned = true
        }
        questions.insert(question, at: 0)
        scheduleIndex(question)
        lastCapture = CaptureNotice(fileName: fileName, suggestion: suggestion)
        persist()
    }

    func retryIndexing() {
        for var question in questions where question.indexingError != nil {
            question.recognizedText = nil
            question.searchIndex = nil
            scheduleIndex(question)
        }
    }

    private func scheduleIndex(_ question: Question) {
        guard indexAutomatically, pendingIndexIDs.insert(question.id).inserted else { return }
        indexingCount = pendingIndexIDs.count
        Task {
            defer {
                pendingIndexIDs.remove(question.id)
                indexingCount = pendingIndexIDs.count
                indexRevision += 1
            }
            do {
                let (index, recognized, suggestion) = try await retrieval.index(question)
                guard let position = questions.firstIndex(where: { $0.id == question.id }) else { return }
                questions[position].recognizedText = recognized
                questions[position].searchIndex = index
                questions[position].indexingError = question.imagePath != nil && recognized.isEmpty
                    ? "No readable text found. Search uses the filename." : nil
                if let suggestion, questions[position].isSubjectManuallyAssigned != true {
                    questions[position].subject = suggestion.subject
                    questions[position].topic = suggestion.topic
                }
                persist()
            } catch {
                guard let position = questions.firstIndex(where: { $0.id == question.id }) else { return }
                questions[position].indexingError = "Text recognition failed. Use Retry indexing to try again."
                persist()
            }
        }
    }

    func subjectNameError(_ name: String) -> String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "Enter a subject name." }
        if clean.count > 80 { return "Use 80 characters or fewer." }
        if subjectNames.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) {
            return "This subject already exists."
        }
        return nil
    }

    @discardableResult
    func createSubject(named name: String) -> String? {
        guard subjectNameError(name) == nil else { return nil }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        customSubjects.append(clean)
        guard persist() else { customSubjects.removeAll { $0 == clean }; return nil }
        return clean
    }

    @discardableResult
    func setSubject(_ question: Question, to subject: String) -> Bool {
        guard subjectNames.contains(subject), let index = questions.firstIndex(where: { $0.id == question.id }) else { return false }
        let old = questions[index]
        questions[index].subject = subject
        questions[index].topic = "General"
        questions[index].isSubjectManuallyAssigned = true
        guard persist() else { questions[index] = old; return false }
        indexRevision += 1
        return true
    }

    func folderNameError(_ name: String, excluding id: UUID? = nil) -> String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "Enter a folder name." }
        if clean.count > 80 { return "Use 80 characters or fewer." }
        if folders.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) {
            return "A folder with this name already exists."
        }
        return nil
    }

    @discardableResult
    func createFolder(named name: String) -> LibraryFolder? {
        guard folderNameError(name) == nil else { return nil }
        let folder = LibraryFolder(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        folders.append(folder)
        guard persist() else { folders.removeAll { $0.id == folder.id }; return nil }
        return folder
    }

    @discardableResult
    func renameFolder(_ folder: LibraryFolder, to name: String) -> Bool {
        guard folderNameError(name, excluding: folder.id) == nil,
              let index = folders.firstIndex(where: { $0.id == folder.id }) else { return false }
        let old = folders[index]
        folders[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard persist() else { folders[index] = old; return false }
        return true
    }

    @discardableResult
    func removeFolder(_ folder: LibraryFolder) -> Bool {
        let oldFolders = folders
        let oldQuestions = questions
        folders.removeAll { $0.id == folder.id }
        for index in questions.indices where questions[index].folderID == folder.id {
            questions[index].folderID = nil
        }
        guard persist() else { folders = oldFolders; questions = oldQuestions; return false }
        return true
    }

    @discardableResult
    func move(_ question: Question, to folderID: UUID?) -> Bool {
        guard folderID == nil || folders.contains(where: { $0.id == folderID }),
              let index = questions.firstIndex(where: { $0.id == question.id }) else { return false }
        let previous = questions[index].folderID
        questions[index].folderID = folderID
        guard persist() else { questions[index].folderID = previous; return false }
        return true
    }

    private func load() {
        guard fileManager.fileExists(atPath: indexURL.path) else { return }
        do {
            let data = try Data(contentsOf: indexURL)
            if let snapshot = try? decoder.decode(LibrarySnapshot.self, from: data) {
                questions = snapshot.questions
                folders = snapshot.folders
                customSubjects = snapshot.subjects ?? []
            } else {
                // Libraries from before folders retain their original question IDs.
                questions = try decoder.decode([Question].self, from: data)
            }
        } catch {
            errorMessage = "Your library could not be read. The saved file has been left untouched."
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            try fileManager.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(LibrarySnapshot(questions: questions, folders: folders, subjects: customSubjects))
            try data.write(to: indexURL, options: .atomic)
            return true
        } catch {
            errorMessage = "Your changes could not be saved. Check available disk space and try again."
            return false
        }
    }

    private func title(for fileName: String) -> String {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let cleaned = baseName.replacingOccurrences(of: "[_-]", with: " ", options: .regularExpression)
        return cleaned.isEmpty ? "New question from screenshot" : "New question from \(cleaned)"
    }

    private static func timestampLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        return formatter.string(from: Date())
    }
}
