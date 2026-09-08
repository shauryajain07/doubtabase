import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum RecallHaptics {
    static func play(
        _ pattern: NSHapticFeedbackManager.FeedbackPattern,
        pulses: Int = 1,
        spacing: TimeInterval = 0.045
    ) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)

        guard pulses > 1 else { return }
        for pulse in 1..<pulses {
            DispatchQueue.main.asyncAfter(deadline: .now() + spacing * Double(pulse)) {
                NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
            }
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var query = ""
    @State private var selection = "All questions"
    @State private var selectedFolderID: UUID?
    @State private var folderEditor: FolderEditorRequest?
    @State private var subjectEditor = false
    private var selectedSubject: String? { selection.hasPrefix("subject:") ? String(selection.dropFirst(8)) : nil }
    private var sectionTitle: String { store.folders.first(where: { $0.id == selectedFolderID })?.name ?? selectedSubject ?? selection }
    private func addScreenshots() { store.importWithOpenPanel(into: selectedFolderID, subject: selectedFolderID == nil ? selectedSubject : nil) }
    @State private var opened: Question?
    @State private var matches: [RetrievedQuestion] = []
    @State private var semanticAvailable = true
    @State private var searching = false
    @State private var context: String?
    private var searchKey: String { query + "|" + selection + "|" + (selectedFolderID?.uuidString ?? "") + "|" + String(store.indexRevision) + "|" + store.questions.map { $0.id.uuidString + String($0.reviewProgress) + ($0.folderID?.uuidString ?? "") }.joined() }
    private var hasQuery: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var candidates: [Question] {
        store.questions.filter { question in
            if let selectedFolderID { return question.folderID == selectedFolderID }
            return selection == "All questions" || (selection == "Unfiled" && question.folderID == nil) || (selection == "To review" && question.reviewProgress < 100) || (selection == "Reviewed" && question.reviewProgress == 100) || question.subject == selectedSubject
        }
    }
    @FocusState private var searchFocused: Bool

    private var filtered: [Question] {
        guard hasQuery else { return candidates }
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
        return matches.compactMap { byID[$0.id] }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Search questions", systemImage: "magnifyingglass").labelStyle(.iconOnly).foregroundStyle(Color.recallMuted)
                    TextField("Search by meaning, subject, or screenshot text", text: $query)
                        .textFieldStyle(.plain).focused($searchFocused)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).help("Clear search")
                    }
                    Text("⌘ F").font(.system(size: 11)).foregroundStyle(Color.recallMuted)
                    Divider().frame(height: 20).padding(.horizontal, 14)
                    Button {
                        RecallHaptics.play(.levelChange, pulses: 2)
                        addScreenshots()
                    } label: {
                        Label("Add screenshots", systemImage: "plus")
                    }.buttonStyle(.borderedProminent).tint(.recallCoral).keyboardShortcut("o")
                }
                .padding(.horizontal, 24).padding(.vertical, 18).frame(minHeight: 72).background(.white)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(sectionTitle).font(.system(size: 30, weight: .semibold))
                                Text(selection == "To review" ? "Pick a question. Work through it. Mark it reviewed." : "Your questions, ready when you are.")
                                    .font(.system(size: 14)).foregroundStyle(Color.recallMuted)
                            }
                            Spacer()
                            Text("\(filtered.count) \(filtered.count == 1 ? "question" : "questions")").font(.system(size: 12)).foregroundStyle(Color.recallMuted)
                        }
                        HStack {
                            if store.indexingCount > 0 {
                                ProgressView().controlSize(.small)
                                Text("Indexing \(store.indexingCount) questions…")
                            } else {
                                Text(hasQuery ? (searching ? "Searching…" : semanticAvailable ? "Sorted by relevance" : "Keyword search · English embedding model unavailable") : "Search screenshot text and related concepts")
                            }
                            Spacer()
                            if store.questions.contains(where: { $0.indexingError != nil }) {
                                Button("Retry indexing", action: store.retryIndexing)
                            }
                            if hasQuery && !matches.isEmpty && !searching {
                                Button("View RAG context") {
                                    context = RAGContext.build(query: query, matches: matches, questions: candidates)
                                }
                            }
                        }.font(.system(size: 12)).foregroundStyle(Color.recallMuted)
                        if selectedFolderID == nil && selection == "All questions" && query.isEmpty {
                            HStack(spacing: 14) {
                                Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 25)).foregroundStyle(Color.recallCoral)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Save a question without leaving your work").font(.system(size: 13, weight: .semibold))
                                    Text("Drag a screenshot to the black capture area at the top of your screen, or use Add screenshots.")
                                        .font(.system(size: 12)).foregroundStyle(Color.recallMuted)
                                }
                                Spacer()
                            }.padding(20).background(Color.recallCoral.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if filtered.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: query.isEmpty ? "square.stack" : "magnifyingglass").font(.system(size: 32)).foregroundStyle(Color.recallMuted)
                                Text(query.isEmpty ? "Nothing here yet" : "No matching questions").font(.headline)
                                Text(query.isEmpty ? "Add a screenshot to start building your library." : "Try another word or clear your search.").foregroundStyle(Color.recallMuted)
                                if query.isEmpty { Button("Add screenshots", action: addScreenshots) }
                                else { Button("Clear search") { query = "" } }
                            }.frame(maxWidth: .infinity, minHeight: 300)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 20)], spacing: 20) {
                                ForEach(filtered) { question in
                                    Button { opened = question } label: { QuestionCard(question: question) }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .help("Open question")
                                        .contextMenu {
                                            Menu("Move to folder") {
                                                Button("Unfiled") { store.move(question, to: nil) }
                                                ForEach(store.folders) { folder in
                                                    Button(folder.name) { store.move(question, to: folder.id) }
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }.padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 32)
                }
            }
        }
        .foregroundStyle(Color.recallInk).background(Color.recallCanvas)
        .frame(minWidth: 900, minHeight: 620)
        .preferredColorScheme(.light)
        .task(id: searchKey) {
            matches = []
            guard hasQuery else { searching = false; return }
            searching = true
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            let result = await store.retrieval.search(query, questions: candidates)
            guard !Task.isCancelled else { return }
            matches = result.matches
            semanticAvailable = result.semanticAvailable
            searching = false
        }
        .sheet(isPresented: Binding(get: { context != nil }, set: { if !$0 { context = nil } })) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Retrieved study context").font(.title2)
                Text("Source excerpts for a language model. No answer has been generated.").foregroundStyle(Color.recallMuted)
                ScrollView { Text(context ?? "").textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack {
                    Button("Copy context") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(context ?? "", forType: .string)
                    }
                    Spacer()
                    Button("Done") { context = nil }
                }
            }.padding(24).frame(width: 650, height: 500)
        }
        .sheet(isPresented: $subjectEditor) {
            SubjectEditor { subject in
                selectedFolderID = nil; selection = "subject:" + subject; query = ""
            }.environmentObject(store)
        }
        .sheet(item: $folderEditor) { request in
            FolderEditor(folder: request.folder) { folder in
                selectedFolderID = folder.id
                query = ""
            }.environmentObject(store)
        }
        .sheet(item: $opened) { question in QuestionDetail(question: question).environmentObject(store) }
        .background(Button("") { searchFocused = true }.keyboardShortcut("f").hidden())
        .alert("Unable to save", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image("Doubtabase-logo-v2", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("Doubtabase logo")
                Text("doubtabase").font(.system(size: 19, weight: .bold))
            }.padding(.horizontal, 12).padding(.top, 28).padding(.bottom, 24)
            nav("All questions", icon: "square.grid.2x2", count: store.questions.count)
            nav("To review", icon: "circle.dashed", count: store.questions.filter { $0.reviewProgress < 100 }.count)
            nav("Reviewed", icon: "checkmark.circle", count: store.questions.filter { $0.reviewProgress == 100 }.count)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("FOLDERS").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                        Spacer()
                        Button { folderEditor = FolderEditorRequest(folder: nil) } label: {
                            Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        }.buttonStyle(.plain).help("New folder").accessibilityLabel("New folder")
                    }.foregroundStyle(Color.recallMuted).padding(.horizontal, 12).padding(.top, 24).padding(.bottom, 7)
                    nav("Unfiled", icon: "tray", count: store.questions.filter { $0.folderID == nil }.count)
                    ForEach(store.folders) { folder in
                        Button { selectedFolderID = folder.id; query = "" } label: {
                            HStack {
                                Label(folder.name, systemImage: "folder").lineLimit(1)
                                Spacer(minLength: 2)
                                Text("\(store.questions.filter { $0.folderID == folder.id }.count)").font(.system(size: 11)).monospacedDigit()
                            }.font(.system(size: 13, weight: selectedFolderID == folder.id ? .semibold : .regular))
                                .foregroundStyle(selectedFolderID == folder.id ? Color.recallCoral : Color.recallMuted)
                                .padding(.horizontal, 12).padding(.vertical, 11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedFolderID == folder.id ? Color.recallCoral.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .contextMenu {
                            Button("Rename folder") { folderEditor = FolderEditorRequest(folder: folder) }
                            Button("Remove folder (keep questions)") {
                                if store.removeFolder(folder), selectedFolderID == folder.id {
                                    selectedFolderID = nil; selection = "Unfiled"
                                }
                            }
                        }
                    }
                    HStack {
                        Text("SUBJECTS").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                        Spacer()
                        Button { subjectEditor = true } label: {
                            Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        }.buttonStyle(.plain).help("New subject").accessibilityLabel("New subject")
                    }.foregroundStyle(Color.recallMuted).padding(.top, 24).padding(.horizontal, 12).padding(.bottom, 5)
                    ForEach(store.subjectNames, id: \.self) { subject in
                        nav(subject, icon: "book.closed", count: store.questions.filter { $0.subject == subject }.count, key: "subject:" + subject)
                            .contextMenu {
                                if subject != "Unsorted" {
                                    Button("Delete subject (keep questions)", role: .destructive) {
                                        if store.removeSubject(subject), selectedSubject == subject {
                                            selection = "All questions"
                                            query = ""
                                        }
                                    }
                                }
                            }
                    }
                }
            }
            Spacer(minLength: 16)
            VStack(alignment: .leading, spacing: 7) {
                Label("Stored on this Mac", systemImage: "internaldrive").font(.system(size: 12, weight: .medium))
                Text("Screenshots stay in your local library.").font(.system(size: 11)).foregroundStyle(Color.recallMuted)
            }.padding(12)
        }.padding(.horizontal, 16).padding(.bottom, 20).frame(width: 224).background(Color.white.opacity(0.65))
    }

    private func nav(_ title: String, icon: String, count: Int, key: String? = nil) -> some View {
        let value = key ?? title
        return Button { selectedFolderID = nil; selection = value; query = "" } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(title).lineLimit(1)
                Spacer(minLength: 2)
                Text("\(count)").font(.system(size: 11)).monospacedDigit()
            }.font(.system(size: 13, weight: selectedFolderID == nil && selection == value ? .semibold : .regular))
                .foregroundStyle(selectedFolderID == nil && selection == value ? Color.recallCoral : Color.recallMuted)
                .padding(.horizontal, 12).padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selectedFolderID == nil && selection == value ? Color.recallCoral.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct QuestionCard: View {
    let question: Question
    @State private var hovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuestionVisual(question: question).frame(height: 176).clipped()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(question.subject).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.recallCoral)
                    Spacer()
                    if question.reviewProgress == 100 { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.recallSage) }
                    else { Text("To review").font(.system(size: 10)).foregroundStyle(Color.recallMuted) }
                }
                Text(question.title.replacingOccurrences(of: "New question from ", with: "")).font(.system(size: 15, weight: .semibold)).lineLimit(2).frame(height: 40, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(question.topic).lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.font(.system(size: 11)).foregroundStyle(Color.recallMuted)
            }.padding(20)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(hovered ? Color.recallCoral.opacity(0.45) : Color.recallLine, lineWidth: 1))
        .shadow(color: .black.opacity(hovered ? 0.07 : 0.025), radius: hovered ? 12 : 4, y: 4)
        .onHover { hovered = $0 }.animation(.easeOut(duration: 0.15), value: hovered)
    }
}

struct QuestionVisual: View {
    let question: Question
    var body: some View {
        ZStack {
            Color(nsColor: .init(calibratedWhite: 0.965, alpha: 1))
            if let path = question.imagePath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFit().padding(12)
            } else {
                VStack(spacing: 18) {
                    Text(question.imagePath == nil ? "EXAMPLE QUESTION" : "PREVIEW UNAVAILABLE")
                        .font(.system(size: 9, weight: .medium)).tracking(1.7).foregroundStyle(Color.recallMuted)
                    Text(question.visualMark).font(.system(size: 28, weight: .medium, design: .serif)).foregroundStyle(Color.recallInk)
                    Rectangle().fill(Color.recallCoral.opacity(0.35)).frame(width: 28, height: 2)
                }.padding(16)
            }
        }
    }
}

struct QuestionDetail: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let question: Question
    private var current: Question { store.questions.first(where: { $0.id == question.id }) ?? question }
    private var reviewed: Bool { store.questions.first(where: { $0.id == question.id })?.reviewProgress == 100 }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(current.subject + " / " + current.topic).font(.system(size: 12)).foregroundStyle(Color.recallMuted)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(current.title).font(.system(size: 24, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subject").font(.caption).foregroundStyle(Color.recallMuted)
                    Picker("Subject", selection: Binding(get: { current.subject }, set: { store.setSubject(current, to: $0) })) {
                        ForEach(store.subjectNames, id: \.self) { Text($0).tag($0) }
                    }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder").font(.caption).foregroundStyle(Color.recallMuted)
                    Picker("Folder", selection: Binding<UUID?>(get: { current.folderID }, set: { store.move(current, to: $0) })) {
                        Text("Unfiled").tag(nil as UUID?)
                        ForEach(store.folders) { folder in Text(folder.name).tag(Optional(folder.id)) }
                    }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                }
            }.pickerStyle(.menu).padding(16)
                .background(Color.recallCanvas, in: RoundedRectangle(cornerRadius: 12))
            QuestionVisual(question: question).frame(maxWidth: .infinity, maxHeight: .infinity).clipShape(RoundedRectangle(cornerRadius: 12))
            if let issue = current.indexingError {
                Text(issue).font(.system(size: 12)).foregroundStyle(.orange)
            }
            if let text = current.recognizedText, !text.isEmpty {
                DisclosureGroup("Recognized question text") {
                    ScrollView { Text(text).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 130)
                }
            }
            Text(question.excerpt).font(.system(size: 14)).foregroundStyle(Color.recallMuted)
            Divider()
            HStack {
                if let path = question.imagePath {
                    Button { NSWorkspace.shared.open(URL(fileURLWithPath: path)) } label: { Label("Open original", systemImage: "arrow.up.right.square") }
                } else { Text("Example question").font(.system(size: 12)).foregroundStyle(Color.recallMuted) }
                Spacer()
                Button(reviewed ? "Move to review" : "Mark reviewed") {
                    RecallHaptics.play(reviewed ? .alignment : .levelChange, pulses: 2)
                    store.setReviewed(question, reviewed: !reviewed)
                }
                    .buttonStyle(.borderedProminent).tint(.recallCoral)
            }
        }.padding(32).frame(minWidth: 700, idealWidth: 820, minHeight: 600, idealHeight: 720).background(.white)
    }
}

struct CaptureOverlay: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onBrowse: () -> Void
    var compactMode = false
    var panelState: CapturePanelController.PanelState = .expanded
    var onPanelStateChange: ((CapturePanelController.PanelState) -> Void)? = nil
    var topInset: CGFloat = 0
    var compactWidth: CGFloat = 156
    @State private var isTargeted = false
    @State private var savedNotice: CaptureNotice?
    @State private var isHovering = false
    @State private var chooseHovered = false
    @State private var lastHoverHaptic: TimeInterval = -.infinity
    @State private var lastTargetHaptic: TimeInterval = -.infinity
    @State private var lastSaveHaptic: TimeInterval = -.infinity
    @State private var expansionAnchor = UnitPoint(x: 0.5, y: 0)

    private var isCompact: Bool { compactMode && !isTargeted }
    private var expandedWidth: CGFloat { min(max(360, compactWidth + 48), 520) }
    private var compactHeight: CGFloat { topInset > 0 ? topInset + 2 : 20 }
    private var expandedHeight: CGFloat { topInset + 72 }
    private var width: CGFloat { isCompact ? compactWidth : expandedWidth }
    private var height: CGFloat { isCompact ? compactHeight : expandedHeight }
    private var notchShape: NotchShape { NotchShape(bottomRadius: isCompact ? 11 : 22) }
    private var statusKey: String {
        if savedNotice != nil { return "saved" }
        if isTargeted { return "targeted" }
        return "ready"
    }
    private var statusAccent: Color { savedNotice != nil ? .recallSage : .recallCoral }
    private var statusTitle: String {
        if savedNotice != nil { return "Saved to library" }
        if isTargeted { return "Release to save" }
        return "Drop to save"
    }
    private var statusDetail: String {
        if savedNotice != nil { return "Added to your questions" }
        if isTargeted { return "Your screenshot is ready" }
        return "Drag a screenshot here"
    }
    private var statusSymbol: String {
        if savedNotice != nil { return "checkmark" }
        if isTargeted { return "arrow.down" }
        return "photo.badge.plus"
    }
    private var outlineColor: Color {
        if isCompact { return Color.white.opacity(0.18) }
        if isTargeted || savedNotice != nil { return statusAccent.opacity(0.68) }
        return Color.white.opacity(0.32)
    }
    private var outlineWidth: CGFloat { isCompact ? 0.8 : 1.2 }

    @ViewBuilder
    private var panelBackground: some View {
        notchShape.fill(Color.black)
        .overlay {
            notchShape.stroke(outlineColor, lineWidth: outlineWidth)
        }
    }

    private var pointerExpansionAnchor: UnitPoint {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
                ?? NSScreen.main
                ?? NSScreen.screens.first else { return .top }
        let expandedLeft = screen.frame.midX - expandedWidth / 2
        let normalizedX = (mouseLocation.x - expandedLeft) / expandedWidth
        return UnitPoint(x: min(max(normalizedX, 0.10), 0.90), y: 0)
    }

    private var panelTransition: AnyTransition {
        let collapseX = compactWidth / expandedWidth
        let collapseY = compactHeight / expandedHeight
        return .asymmetric(
            insertion: .scale(scale: 0.82, anchor: expansionAnchor).combined(with: .opacity),
            removal: .modifier(
                active: PointerScaleEffect(
                    scaleX: collapseX,
                    scaleY: collapseY,
                    anchor: expansionAnchor
                ),
                identity: PointerScaleEffect(
                    scaleX: 1,
                    scaleY: 1,
                    anchor: expansionAnchor
                )
            )
        )
    }

    private func expandFromPointer() {
        expansionAnchor = pointerExpansionAnchor
        onPanelStateChange?(.expanded)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if isCompact {
                    panelBackground
                    if topInset == 0 {
                        Capsule()
                            .fill(.white.opacity(isHovering ? 0.62 : 0.30))
                            .frame(width: isHovering ? 28 : 22, height: 3)
                            .padding(.top, 11)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isHovering)
                    }
                } else {
                    ZStack(alignment: .top) {
                        panelBackground
                        if isTargeted || savedNotice != nil {
                            Capsule()
                                .fill(statusAccent.opacity(0.92))
                                .frame(width: savedNotice != nil ? 46 : 68, height: 3)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .padding(.bottom, 8)
                        }
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(statusAccent.opacity(savedNotice != nil || isTargeted ? 0.19 : 0.11))
                                Image(systemName: statusSymbol)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(statusAccent)
                                    .contentTransition(.symbolEffect(.replace))
                                    .scaleEffect(isTargeted || savedNotice != nil ? 1.06 : 1)
                            }
                            .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(statusTitle)
                                    .id(statusKey + ".title")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                Text(statusDetail)
                                    .id(statusKey + ".detail")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.48))
                                    .lineLimit(1)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipped()
                            Spacer(minLength: 4)
                            if savedNotice == nil {
                                Button {
                                    onBrowse()
                                } label: {
                                    Label("Choose", systemImage: "plus")
                                        .labelStyle(.titleAndIcon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white.opacity(chooseHovered ? 1 : 0.84))
                                        .padding(.horizontal, 11)
                                        .frame(height: 31)
                                        .background(.white.opacity(chooseHovered ? 0.17 : 0.10), in: Capsule())
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .onHover { chooseHovered = $0 }
                                .help("Choose screenshots")
                                .accessibilityLabel("Choose screenshots")
                                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: chooseHovered)
                            }
                        }
                        .padding(.horizontal, 22)
                        .frame(width: width, height: 72)
                        .padding(.top, topInset)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: statusKey)
                    }
                    .transition(panelTransition)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84), value: isCompact)
        }
        .frame(width: width, height: height)
        .clipShape(notchShape)
        .contentShape(notchShape)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84), value: isCompact)
        .onDrop(of: [UTType.fileURL.identifier, UTType.png.identifier, UTType.tiff.identifier, UTType.image.identifier], isTargeted: $isTargeted) { providers in
            guard !providers.isEmpty else { return false }
            store.importProviders(providers)
            return true
        }
        .onChange(of: store.lastCapture?.id) { _, _ in
            guard let notice = store.lastCapture else { return }
            savedNotice = notice
            let now = ProcessInfo.processInfo.systemUptime
            // Multiple files saved together should feel like one confirmation.
            if now - lastSaveHaptic > 0.3 {
                RecallHaptics.play(.generic, pulses: 2)
                lastSaveHaptic = now
            }
            onPanelStateChange?(.saved)
        }
        .onChange(of: isTargeted) { _, targeted in
            if targeted {
                let now = ProcessInfo.processInfo.systemUptime
                // Resizing can briefly retrigger drag entry; avoid repeated taps.
                if now - lastTargetHaptic > 0.3 {
                    RecallHaptics.play(.alignment, pulses: 2)
                    lastTargetHaptic = now
                }
                savedNotice = nil
                expandFromPointer()
            } else if savedNotice == nil {
                onPanelStateChange?(.compact)
            }
        }
        .onChange(of: panelState) { _, state in
            // Preserve the success content during the saved-state hold, then
            // clear it before the next hover can expand the compact affordance.
            if state == .expanded || state == .compact {
                savedNotice = nil
            }
        }
        .onTapGesture {
            if isCompact {
                expandFromPointer()
            }
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                if isCompact {
                    triggerHoverHaptic()
                    expandFromPointer()
                }
            } else if !isTargeted && savedNotice == nil {
                onPanelStateChange?(.compact)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Screenshot capture")
        .accessibilityValue(statusTitle)
        .accessibilityHint("Drop a screenshot here, or expand to choose a file")
    }

    private func triggerHoverHaptic() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHoverHaptic > 0.65 else { return }
        RecallHaptics.play(.levelChange, pulses: 2)
        lastHoverHaptic = now
    }
}

private struct PointerScaleEffect: GeometryEffect {
    var scaleX: CGFloat
    var scaleY: CGFloat
    let anchor: UnitPoint

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(scaleX, scaleY) }
        set {
            scaleX = newValue.first
            scaleY = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let anchorPoint = CGPoint(x: size.width * anchor.x, y: size.height * anchor.y)
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: anchorPoint.x, y: anchorPoint.y)
        transform = transform.scaledBy(x: scaleX, y: scaleY)
        transform = transform.translatedBy(x: -anchorPoint.x, y: -anchorPoint.y)
        return ProjectionTransform(transform)
    }
}

// Concave shoulders join the screen edge; continuous lower corners tuck underneath.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }
    func path(in rect: CGRect) -> Path {
        let shoulder: CGFloat = 8
        let radius = min(bottomRadius, (rect.height - shoulder) / 2)
        let left = rect.minX + shoulder
        let right = rect.maxX - shoulder
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: right, y: rect.minY + shoulder), control: CGPoint(x: right, y: rect.minY))
        path.addLine(to: CGPoint(x: right, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: rect.maxY), control: CGPoint(x: right, y: rect.maxY))
        path.addLine(to: CGPoint(x: left + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: left, y: rect.maxY - radius), control: CGPoint(x: left, y: rect.maxY))
        path.addLine(to: CGPoint(x: left, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: left, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

extension Color {
    static let recallCanvas = Color(nsColor: NSColor(calibratedWhite: 0.975, alpha: 1))
    static let recallInk = Color(nsColor: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.10, alpha: 1))
    static let recallMuted = Color(nsColor: NSColor(calibratedRed: 0.39, green: 0.40, blue: 0.39, alpha: 1))
    static let recallLine = Color(nsColor: NSColor(calibratedRed: 0.89, green: 0.90, blue: 0.92, alpha: 1))
    static let recallCoral = Color(nsColor: NSColor(calibratedRed: 0.29, green: 0.34, blue: 0.83, alpha: 1))
    static let recallLilac = Color(nsColor: NSColor(calibratedRed: 0.55, green: 0.47, blue: 0.72, alpha: 1))
    static let recallSage = Color(nsColor: NSColor(calibratedRed: 0.35, green: 0.58, blue: 0.43, alpha: 1))
    static let recallBlue = Color(nsColor: NSColor(calibratedRed: 0.27, green: 0.49, blue: 0.66, alpha: 1))
    static let recallGold = Color(nsColor: NSColor(calibratedRed: 0.71, green: 0.51, blue: 0.21, alpha: 1))
}

private struct FolderEditorRequest: Identifiable {
    let id = UUID()
    let folder: LibraryFolder?
}

private struct FolderEditor: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let folder: LibraryFolder?
    let onSave: (LibraryFolder) -> Void
    @State private var name: String
    @State private var saveError: String?
    @FocusState private var focused: Bool

    init(folder: LibraryFolder?, onSave: @escaping (LibraryFolder) -> Void) {
        self.folder = folder
        self.onSave = onSave
        _name = State(initialValue: folder?.name ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(folder == nil ? "New folder" : "Rename folder", systemImage: "folder.badge.plus").font(.title2.weight(.semibold))
            Text("Group questions your way. Subjects stay unchanged.").font(.system(size: 13)).foregroundStyle(Color.recallMuted)
            TextField("Folder name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(save)
            if let error = saveError ?? (name.isEmpty ? nil : store.folderNameError(name, excluding: folder?.id)) {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(folder == nil ? "Create folder" : "Save", action: save)
                    .buttonStyle(.borderedProminent).tint(.recallCoral).keyboardShortcut(.defaultAction)
                    .disabled(store.folderNameError(name, excluding: folder?.id) != nil)
            }
        }.padding(24).frame(width: 380).onAppear { focused = true }
    }

    private func save() {
        guard store.folderNameError(name, excluding: folder?.id) == nil else { return }
        if let folder {
            guard store.renameFolder(folder, to: name), let updated = store.folders.first(where: { $0.id == folder.id }) else {
                saveError = store.errorMessage; return
            }
            onSave(updated)
        } else {
            guard let created = store.createFolder(named: name) else { saveError = store.errorMessage; return }
            onSave(created)
        }
        dismiss()
    }
}

private struct SubjectEditor: View {
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void
    @State private var name = ""
    @State private var saveError: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("New subject", systemImage: "book.closed").font(.title2.weight(.semibold))
            Text("Automatic sorting chooses only from subjects you add here. Uncertain matches stay Unsorted.").font(.system(size: 13)).foregroundStyle(Color.recallMuted)
            TextField("Subject name", text: $name).textFieldStyle(.roundedBorder).focused($focused).onSubmit(save)
            if let error = saveError ?? (name.isEmpty ? nil : store.subjectNameError(name)) {
                Text(error).font(.system(size: 12)).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Create subject", action: save).buttonStyle(.borderedProminent).tint(.recallCoral).keyboardShortcut(.defaultAction)
                    .disabled(store.subjectNameError(name) != nil)
            }
        }.padding(24).frame(width: 380).onAppear { focused = true }
    }

    private func save() {
        guard store.subjectNameError(name) == nil else { return }
        guard let subject = store.createSubject(named: name) else { saveError = store.errorMessage; return }
        onSave(subject)
        dismiss()
    }
}
