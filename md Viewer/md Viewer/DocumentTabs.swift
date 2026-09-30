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

/// Shared by the window-level and the iPhone-list confirmation.
func closeConfirmationMessage(for session: DocumentSession) -> String {
    session.isDraft
        ? String(localized: "This document has not been saved yet and will be lost.")
        : String(localized: "The changes to \(session.title) have not been saved and will be lost.")
}

// MARK: - Mac / iPad

/// Horizontal tab strip below the navigation bar (Mac and iPad, regular
/// width, two or more documents). Tap = switch, × = close, "+" = new / open.
struct DocumentTabBar: View {
    let store: OpenDocumentsStore

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(store.documents) { session in
                            DocumentTab(
                                session: session,
                                isActive: session.id == store.activeID,
                                onSelect: { store.activate(session.id) },
                                onClose: { store.userClose(session.id) }
                            )
                            .id(session.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                }
                .onAppear { proxy.scrollTo(store.activeID) }
                .onChange(of: store.activeID) { _, id in
                    withAnimation { proxy.scrollTo(id) }
                }
            }
            NewDocumentMenu(store: store)
                .padding(.trailing, 8)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct DocumentTab: View {
    let session: DocumentSession
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(isActive || isHovering ? 1 : 0.5)
            .accessibilityLabel(Text("Close \(session.title)"))

            Button(action: onSelect) {
                HStack(spacing: 4) {
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
                .font(.subheadline.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(minWidth: 60, maxWidth: 200)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(session.hasUnsavedChanges ? Text("Unsaved changes") : Text(""))
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isActive ? Color(uiColor: .systemBackground) : .clear)
                .shadow(color: .black.opacity(isActive ? 0.12 : 0), radius: 1, y: 0.5)
        }
        .onHover { isHovering = $0 }
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
