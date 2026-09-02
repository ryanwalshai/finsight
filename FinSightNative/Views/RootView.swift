import SwiftUI
import UniformTypeIdentifiers

/// The shell. Five destinations, matching the web app's tab bar, so that moving between the two
/// does not mean learning a second app.
///
/// Four of them are honest placeholders. The native app is being built a screen at a time and
/// the web app still has everything; a placeholder that says which is which is worth more than a
/// half-built screen that looks finished and quietly shows the wrong number.
struct RootView: View {
    @State private var store = Store()

    var body: some View {
        TabView {
            NotBuiltYet(
                screen: "Home",
                detail: "Net worth, the month so far and what changed since last month."
            )
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { RecurringView() }
                .tabItem { Label("Budget", systemImage: "creditcard") }

            NotBuiltYet(
                screen: "Goals",
                detail: "What you are saving towards, and whether the rate you are going gets you there."
            )
            .tabItem { Label("Goals", systemImage: "target") }

            NotBuiltYet(
                screen: "Strategies",
                detail: "Debt payoff order, the emergency fund, and the long projections."
            )
            .tabItem { Label("Strategies", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Menu", systemImage: "line.3.horizontal") }
        }
        .tint(Color.fsAccent)
        .environment(store)
        .background(Color.fsBg)
    }
}

/// Says plainly that a screen is still in the web app, rather than pretending.
struct NotBuiltYet: View {
    let screen: String
    let detail: String

    var body: some View {
        ZStack {
            Color.fsBg.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "hammer")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.fsDim)
                Text("\(screen) is still in the web app")
                    .font(FSFont.display(18, .semibold))
                    .foregroundStyle(Color.fsText)
                Text(detail)
                    .font(FSFont.body(14))
                    .foregroundStyle(Color.fsMuted)
                    .multilineTextAlignment(.center)
                Text("It is being moved across a screen at a time. Nothing here is missing from the web app.")
                    .font(FSFont.body(12))
                    .foregroundStyle(Color.fsDim)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(28)
        }
    }
}

/// Enough of a Menu to get figures in and out while the rest is built.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var importing = false
    @State private var exportDocument: BackupDocument?
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.fsBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    FSSectionHead(
                        title: "Menu",
                        sub: "Moving your figures between the web app and this one, while the rest is built."
                    ) { EmptyView() }

                    FSCard(title: "Your figures", systemImage: "arrow.left.arrow.right") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("This app keeps its own copy, separate from the web app's. A backup is the same file in both, so exporting from one and importing into the other moves everything across — including the parts this app has no screens for yet, which are carried through untouched.")
                                .font(FSFont.body(13))
                                .foregroundStyle(Color.fsMuted)

                            HStack(spacing: 10) {
                                Button("Import a backup") { importing = true }
                                    .buttonStyle(FSPrimaryButtonStyle())
                                Button("Export") {
                                    if let data = try? store.exportBackup() {
                                        exportDocument = BackupDocument(data: data)
                                    } else {
                                        message = "That backup could not be prepared."
                                    }
                                }
                                .font(FSFont.body(15, .medium))
                                .foregroundStyle(Color.fsText)
                            }

                            Text("Importing replaces everything already here.")
                                .font(FSFont.body(12))
                                .foregroundStyle(Color.fsDim)
                        }
                    }

                    if let err = store.lastError {
                        FSCard(title: "Something went wrong", systemImage: "exclamationmark.triangle") {
                            Text(err)
                                .font(FSFont.body(13))
                                .foregroundStyle(Color.fsRed)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                // A file from outside the app's own container has to be asked for by name first.
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    try store.importBackup(try Data(contentsOf: url))
                    message = "Backup imported."
                } catch {
                    message = "That file could not be read as a FinSight backup. Nothing has been changed."
                }
            case .failure:
                message = "That file could not be opened."
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "finsight-backup-\(ISODate.today)"
        ) { _ in exportDocument = nil }
        .alert("FinSight", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}
