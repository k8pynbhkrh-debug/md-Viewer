import SwiftUI

/// The window's root: the empty state while nothing is open, otherwise the
/// active tab's `DocumentView`. Only the active tab has a view — inactive tabs
/// keep just their `DocumentSession` (text + editing state), which keeps memory
/// flat no matter how many documents are open.
struct DocumentWorkspaceView: View {
    let store: OpenDocumentsStore
    let imageAccessStore: ImageFolderAccessStore
    /// Opens "Folder Access" from the empty state.
    var onManageFolderAccess: () -> Void = {}

    @State private var showDocumentList = false

    var body: some View {
        Group {
            if let active = store.active {
                NavigationStack {
                    DocumentView(session: active, store: store, imageAccessStore: imageAccessStore,
                                 onShowDocumentList: { showDocumentList = true })
                        .id(active.id)
                }
            } else {
                ContentView(
                    onNewDocument: { initialText in store.newDraft(text: initialText) },
                    onManageFolderAccess: onManageFolderAccess
                )
            }
        }
        .sheet(isPresented: $showDocumentList) {
            OpenDocumentsList(store: store)
        }
        #if targetEnvironment(macCatalyst)
        // The Mac title bar follows the active tab. `.navigationTitle` alone
        // is not enough: with one NavigationStack for all tabs the window
        // title can stay on an earlier tab's name.
        .background { WindowSceneTitle(title: store.active?.title ?? "") }
        #endif
        #if DEBUG
        // Screenshot-/Smoke-Test-Hook: „-mdviewerDocumentList" zeigt beim Start
        // die Liste der (wiederhergestellten) Dokumente — synthetische Taps im
        // Simulator sind unzuverlässig. Nur DEBUG.
        .task {
            if ProcessInfo.processInfo.arguments.contains("-mdviewerDocumentList"),
               !store.documents.isEmpty {
                showDocumentList = true
            }
        }
        #endif
        .confirmationDialog(
            pendingSession?.isDraft == true ? "Discard Document?" : "Discard Changes?",
            isPresented: pendingCloseBinding,
            titleVisibility: .visible,
            presenting: pendingSession
        ) { _ in
            Button("Discard", role: .destructive) { store.confirmPendingClose() }
            Button("Cancel", role: .cancel) { store.pendingCloseID = nil }
        } message: { session in
            Text(closeConfirmationMessage(for: session))
        }
    }

    private var pendingSession: DocumentSession? {
        store.documents.first { $0.id == store.pendingCloseID }
    }

    private var pendingCloseBinding: Binding<Bool> {
        Binding(get: { store.pendingCloseID != nil },
                set: { if !$0 { store.pendingCloseID = nil } })
    }
}

#if targetEnvironment(macCatalyst)
/// Sets the hosting `UIWindowScene`'s title (= the Mac window title). An
/// empty title lets macOS show the app name.
private struct WindowSceneTitle: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> TitleView { TitleView() }

    func updateUIView(_ view: TitleView, context: Context) {
        view.title = title
    }

    final class TitleView: UIView {
        var title = "" { didSet { apply() } }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        private func apply() {
            guard let scene = window?.windowScene, scene.title != title else { return }
            scene.title = title
        }
    }
}
#endif

/// Shared by the window-level and the iPhone-list confirmation.
func closeConfirmationMessage(for session: DocumentSession) -> String {
    session.isDraft
        ? String(localized: "This document has not been saved yet and will be lost.")
        : String(localized: "The changes to \(session.title) have not been saved and will be lost.")
}

// MARK: - Mac / iPad

/// Narrowest a tab gets before the bar scrolls instead (like Safari).
let documentTabMinWidth: CGFloat = 140

/// Width of every tab in a bar `available` points wide: the width split evenly,
/// but never below `minWidth` — past that the bar scrolls.
///
/// - Precondition: `available >= 0`, `count >= 0`, `minWidth > 0`.
/// - Postcondition: result `>= minWidth`; while `count * minWidth <= available`
///   the tabs fill the bar exactly (`count * result == available`).
func documentTabWidth(available: CGFloat, count: Int, minWidth: CGFloat = documentTabMinWidth) -> CGFloat {
    precondition(available >= 0 && count >= 0 && minWidth > 0,
                 "documentTabWidth: invalid input \(available), \(count), \(minWidth)")
    guard count > 0 else { return minWidth }
    return max(available / CGFloat(count), minWidth)
}

/// Finder-/Safari-style tab strip below the navigation bar (Mac and iPad,
/// regular width, two or more documents): equally wide tabs across the full
/// width, separated by lines; the active tab stands out. Tap = switch,
/// × (on hover) = close, "+" = new / open.
struct DocumentTabBar: View {
    let store: OpenDocumentsStore

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { geometry in
                let width = documentTabWidth(available: geometry.size.width,
                                             count: store.documents.count)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(store.documents) { session in
                                DocumentTab(
                                    session: session,
                                    isActive: session.id == store.activeID,
                                    onSelect: { store.activate(session.id) },
                                    onClose: { store.userClose(session.id) }
                                )
                                .frame(width: width)
                                .overlay(alignment: .trailing) {
                                    if session.id != store.documents.last?.id {
                                        tabSeparator
                                    }
                                }
                                .id(session.id)
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                    .onAppear { proxy.scrollTo(store.activeID) }
                    .onChange(of: store.activeID) { _, id in
                        withAnimation { proxy.scrollTo(id) }
                    }
                }
            }
            tabSeparator
            NewDocumentMenu(store: store)
                .padding(.horizontal, 4)
        }
        .frame(height: DocumentTab.height)
        .background(Color(uiColor: .systemGray5))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var tabSeparator: some View {
        Rectangle()
            .fill(Color(uiColor: .separator))
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

private struct DocumentTab: View {
    static let height: CGFloat = 30

    let session: DocumentSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    /// Mac: × only while the pointer is over the tab (like Finder). iPad
    /// without a pointer has no hover, so the active tab keeps its × there.
    private var showsCloseButton: Bool {
        #if targetEnvironment(macCatalyst)
        isHovering
        #else
        isHovering || isActive
        #endif
    }

    var body: some View {
        ZStack {
            Button(action: onSelect) {
                HStack(spacing: 5) {
                    Text(session.title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if session.hasUnsavedChanges {
                        Circle()
                            .frame(width: 6, height: 6)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                .font(.subheadline.weight(isActive ? .medium : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                // Room for the × on the left, symmetric so the title stays centred.
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(session.title)
            .accessibilityLabel(Text(session.title))
            .accessibilityValue(session.hasUnsavedChanges ? Text("Unsaved changes") : Text(""))
            .accessibilityAddTraits(isActive ? .isSelected : [])

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .opacity(showsCloseButton ? 1 : 0)
                // A hidden × must not swallow taps meant for switching tabs.
                .allowsHitTesting(showsCloseButton)
                // Invisible, but still reachable for VoiceOver / Full Keyboard Access.
                .accessibilityLabel(Text("Close \(session.title)"))
                Spacer(minLength: 0)
            }
            .padding(.leading, 6)
        }
        .background(background)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    /// Active tab: the document's own background, so it reads as the front
    /// sheet; inactive tabs stay on the bar's grey and lighten on hover.
    private var background: Color {
        if isActive { return Color(uiColor: .systemBackground) }
        return isHovering ? Color(uiColor: .systemGray4).opacity(0.6) : .clear
    }
}

/// "+" with "New Document" / "Open…". The same two actions as the empty state
/// and the ⌘N / ⌘O menu commands. Sits in the tab bar, and on the iPad in the
/// toolbar while there is no tab bar yet (one document).
struct NewDocumentMenu: View {
    let store: OpenDocumentsStore

    var body: some View {
        Menu {
            Button("New Document", systemImage: "square.and.pencil") {
                store.newDraft(text: "")
            }
            Button("Open…", systemImage: "folder") {
                store.isPresentingOpenDialog = true
            }
        } label: {
            Image(systemName: "plus")
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .accessibilityLabel(Text("New Tab"))
    }
}

// MARK: - iPhone

/// Sheet listing all open documents (iPhone, compact width) — like the
/// document switcher in Preview: tap to switch, swipe to close, plus "New
/// Document" and "Open…".
struct OpenDocumentsList: View {
    let store: OpenDocumentsStore

    @Environment(\.dismiss) private var dismiss
    /// Closing a tab with unsaved changes from the list is confirmed here —
    /// the window-level dialog sits under this sheet.
    @State private var pendingClose: DocumentSession?
    /// "Open…" is presented from the window once this sheet is gone.
    @State private var openAfterDismiss = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.documents) { session in
                        Button {
                            store.activate(session.id)
                            dismiss()
                        } label: {
                            row(for: session)
                        }
                        // Plain text color for the names; icons keep the tint.
                        .foregroundStyle(.primary)
                        .swipeActions(edge: .trailing) {
                            Button("Close", role: .destructive) { close(session) }
                        }
                    }
                }
                Section {
                    Button("New Document", systemImage: "square.and.pencil") {
                        store.newDraft(text: "")
                        dismiss()
                    }
                    Button("Open…", systemImage: "folder") {
                        openAfterDismiss = true
                        dismiss()
                    }
                }
            }
            .navigationTitle("Open Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                pendingClose?.isDraft == true ? "Discard Document?" : "Discard Changes?",
                isPresented: Binding(get: { pendingClose != nil },
                                     set: { if !$0 { pendingClose = nil } }),
                titleVisibility: .visible,
                presenting: pendingClose
            ) { session in
                Button("Discard", role: .destructive) {
                    if store.documents.contains(where: { $0 === session }) {
                        store.close(session.id, discardingChanges: true)
                    }
                    pendingClose = nil
                    if store.documents.isEmpty { dismiss() }
                }
                Button("Cancel", role: .cancel) { pendingClose = nil }
            } message: { session in
                Text(closeConfirmationMessage(for: session))
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            if openAfterDismiss { store.isPresentingOpenDialog = true }
        }
    }

    private func row(for session: DocumentSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: session.isDraft ? "square.and.pencil" : "doc.text")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let subtitle = subtitle(for: session) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if session.id == store.activeID {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(session.id == store.activeID ? .isSelected : [])
    }

    private func subtitle(for session: DocumentSession) -> String? {
        if session.hasUnsavedChanges { return String(localized: "Unsaved changes") }
        if session.isEditing { return String(localized: "Editing") }
        return session.documentFolderURL?.lastPathComponent
    }

    private func close(_ session: DocumentSession) {
        switch store.requestClose(session.id) {
        case .closed:
            if store.documents.isEmpty { dismiss() }
        case .needsConfirmation:
            pendingClose = session
        case .busy:
            break
        }
    }
}
