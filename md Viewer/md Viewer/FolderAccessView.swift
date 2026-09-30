import SwiftUI

/// "Folder Access": lists the folders the user has shared with md Viewer for
/// showing images (folder name only, never the path) and lets them revoke
/// one or all of them. Reached from the start screen and, on the Mac, from
/// the app menu. Revoking only drops md Viewer's stored permission — no
/// files are touched.
struct FolderAccessView: View {
    @Environment(ImageFolderAccessStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveAllConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if store.folders.isEmpty {
                    ContentUnavailableView {
                        Label("No Folders Shared", systemImage: "folder")
                    } description: {
                        Text("When a document shows images from its folder, md Viewer asks once for access. Those folders appear here and can be removed at any time.")
                    }
                } else {
                    folderList
                }
            }
            .navigationTitle("Folder Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Remove access to all folders?",
                isPresented: $showRemoveAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove All", role: .destructive) { store.removeAll() }
            } message: {
                Text("Images from these folders will no longer be shown until you choose the folder again.")
            }
        }
        .onAppear { store.removeUnresolvableBookmarks() }
    }

    private var folderList: some View {
        List {
            Section {
                ForEach(store.folders) { folder in
                    HStack {
                        Label(folder.displayName, systemImage: "folder")
                        #if targetEnvironment(macCatalyst)
                        // Swipe-to-delete is awkward with a mouse — offer
                        // a visible button per row on the Mac.
                        Spacer()
                        Button(role: .destructive) {
                            store.removeAccess(id: folder.id)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(folder.displayName)")
                        #endif
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { store.folders[$0].id }
                    ids.forEach(store.removeAccess(id:))
                }
            } footer: {
                Text("md Viewer may read images from these folders. Removing a folder only revokes this permission; no files are deleted.")
            }

            Section {
                Button("Remove All", role: .destructive) {
                    showRemoveAllConfirmation = true
                }
            }
        }
    }
}
