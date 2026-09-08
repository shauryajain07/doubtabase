import Foundation

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T) { precondition(actual == expected) }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }
func XCTAssertNil<T>(_ value: T?) { precondition(value == nil) }
func XCTAssertNotNil<T>(_ value: T?) { precondition(value != nil) }
func XCTUnwrap<T>(_ value: T?) throws -> T { precondition(value != nil); return value! }

@main
struct FolderTests {
    @MainActor static func main() throws {
        let tests = FolderTests()
        try tests.testFoldersMigrateAndPersistWithoutLosingQuestions()
        try tests.testEmptyLibraryStaysEmptyAndEmptyFoldersPersist()
        try tests.testSubjectsPersistAndKeepManualAssignments()
        try tests.testSubjectDeletionKeepsQuestions()
        print("Passed subject and folder migration, validation, membership, removal, and persistence checks")
    }
    @MainActor
    func testSubjectDeletionKeepsQuestions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = SampleData.questions[0]
        try JSONEncoder().encode([original]).write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertTrue(store.removeSubject("Economics"))
        XCTAssertEqual(store.questions.first?.id, original.id)
        XCTAssertEqual(store.questions.first?.subject, "Unsorted")
        XCTAssertEqual(store.questions.first?.isSubjectManuallyAssigned, true)
        XCTAssertFalse(store.removeSubject("Unsorted"))
        XCTAssertFalse(store.removeSubject("Missing"))
        XCTAssertEqual(store.createSubject(named: "Engineering"), "Engineering")
        XCTAssertTrue(store.removeSubject("Engineering"))
        let restored = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertEqual(restored.subjectNames, ["Unsorted"])
        XCTAssertTrue(restored.customSubjects.isEmpty)
        XCTAssertEqual(restored.questions.first?.title, original.title)
        XCTAssertEqual(restored.questions.count, 1)
    }

    @MainActor
    func testFoldersMigrateAndPersistWithoutLosingQuestions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = SampleData.questions[0]
        try JSONEncoder().encode([original]).write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertEqual(store.questions, [original])
        let folder = try XCTUnwrap(store.createFolder(named: "  Revision  "))
        XCTAssertEqual(folder.name, "Revision")
        XCTAssertNil(store.createFolder(named: "revision"))
        XCTAssertNil(store.createFolder(named: "   "))
        XCTAssertTrue(store.move(original, to: folder.id))
        XCTAssertFalse(store.move(original, to: UUID()))
        XCTAssertTrue(store.renameFolder(folder, to: "Exam prep"))

        let restored = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertEqual(restored.folders.first?.name, "Exam prep")
        XCTAssertEqual(restored.questions.first?.folderID, folder.id)
        XCTAssertEqual(restored.questions.first?.id, original.id)
        XCTAssertTrue(restored.removeFolder(folder))
        let afterRemoval = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertTrue(afterRemoval.folders.isEmpty)
        XCTAssertEqual(afterRemoval.questions.count, 1)
        XCTAssertNil(afterRemoval.questions.first?.folderID)
        XCTAssertEqual(afterRemoval.questions.first?.title, original.title)
    }

    @MainActor
    func testEmptyLibraryStaysEmptyAndEmptyFoldersPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertTrue(store.questions.isEmpty)
        let folder = try XCTUnwrap(store.createFolder(named: "Mathematics"))
        let restored = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertTrue(restored.questions.isEmpty)
        XCTAssertEqual(restored.folders, [folder])
        XCTAssertNotNil(restored.folderNameError(String(repeating: "x", count: 81)))
    }
    @MainActor
    func testSubjectsPersistAndKeepManualAssignments() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = SampleData.questions[0]
        try JSONEncoder().encode([original]).write(to: directory.appendingPathComponent("library.json"))
        let store = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertEqual(store.createSubject(named: "  Engineering  "), "Engineering")
        XCTAssertNil(store.createSubject(named: "engineering"))
        XCTAssertNil(store.createSubject(named: "Economics"))
        XCTAssertNil(store.createSubject(named: " "))
        XCTAssertTrue(store.setSubject(original, to: "Engineering"))
        XCTAssertFalse(store.setSubject(original, to: "Nonexistent"))
        let restored = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertEqual(restored.customSubjects, ["Engineering"])
        XCTAssertEqual(restored.questions.first?.subject, "Engineering")
        XCTAssertEqual(restored.questions.first?.isSubjectManuallyAssigned, true)
        restored.delete(restored.questions[0])
        let empty = LibraryStore(libraryDirectory: directory, indexAutomatically: false)
        XCTAssertTrue(empty.questions.isEmpty)
        XCTAssertEqual(empty.subjectNames, ["Engineering"])
    }

}
