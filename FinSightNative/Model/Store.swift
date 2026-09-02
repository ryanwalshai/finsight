import Foundation
import Observation

/// Where the figures live, and the only thing allowed to write them.
///
/// The web app keeps its state in `localStorage` under `finsight.v1`. That store belongs to the
/// web view and cannot be read from native code in any way worth relying on, so this app keeps
/// its own file and moves data across as a backup — the same JSON, exported from one and imported
/// into the other. `FinState` round-trips unknown keys, so a file that has been through here and
/// back is the file that left.
///
/// Every mutation goes through `edit`, which saves. There is no path that changes the figures
/// without writing them down; an app people trust with their money does not lose an edit because
/// a screen forgot to call save.
@Observable
final class Store {

    private(set) var state: FinState
    /// Set when the last load or save went wrong, for a screen to surface. Nil is the happy path.
    private(set) var lastError: String?

    /// The file. Application Support rather than Documents: it is the app's own store, not a
    /// document the person manages, and it should not appear in Files.
    private let url: URL

    // MARK: - Lifecycle

    init(url: URL? = nil) {
        self.url = url ?? Store.defaultURL()
        self.state = FinState()
        load()
    }

    private static func defaultURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("FinSight", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("finsight.v1.json")
    }

    // MARK: - Reading and writing

    private func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }   // first run
        do {
            let data = try Data(contentsOf: url)
            state = try JSONDecoder().decode(FinState.self, from: data)
            lastError = nil
        } catch {
            // Keep the unreadable file rather than writing over it. Whatever is wrong with it,
            // it is the only copy of somebody's figures and a fresh empty state on top of it is
            // not a recovery, it is the loss.
            let broken = url.deletingLastPathComponent()
                .appendingPathComponent("finsight.v1.damaged-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: broken)
            lastError = "Your saved figures could not be read. The file has been kept as \(broken.lastPathComponent)."
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(state)
            // Atomic: a crash mid-write leaves the previous file, not half of this one.
            try data.write(to: url, options: .atomic)
            lastError = nil
        } catch {
            lastError = "That change could not be saved."
        }
    }

    /// The one way to change anything. Mutate in the closure; it is written to disk on return.
    func edit(_ change: (inout FinState) -> Void) {
        change(&state)
        save()
    }

    // MARK: - Backups

    /// The bytes to hand to a share sheet. The same shape the web app exports, so a backup taken
    /// here opens there.
    func exportBackup() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(state)
    }

    /// Replaces everything with the contents of a backup file.
    ///
    /// Decoded fully before anything is replaced, so a file that turns out to be unreadable
    /// leaves the current figures alone rather than half-overwriting them.
    func importBackup(_ data: Data) throws {
        let incoming = try JSONDecoder().decode(FinState.self, from: data)
        state = incoming
        save()
    }

    // MARK: - Recurring payments

    /// Everything due regularly, mortgages included. Derived on read — never stored.
    var recurring: [RecurringPayment] { Finance.recurringList(state) }

    /// Adds a new payment, or replaces the existing one with the same id.
    ///
    /// Refuses the rows owned by the Mortgage & loans screen: those are computed from the debt and
    /// writing one into the manual list would create a second, stale copy of it.
    func saveRecurring(_ payment: RecurringPayment) {
        guard !payment.isDerived else { return }
        edit { s in
            if let i = s.recurringManual.firstIndex(where: { $0.id == payment.id }) {
                // Keep any keys this version of the app does not know about.
                var merged = payment
                merged.extras = s.recurringManual[i].extras.merging(payment.extras) { _, new in new }
                s.recurringManual[i] = merged
            } else {
                s.recurringManual.append(payment)
            }
        }
    }

    func deleteRecurring(id: String) {
        edit { s in s.recurringManual.removeAll { $0.id == id } }
    }

    /// Switches a payment off without losing it: it stops counting towards the totals and the
    /// calendar, and its history stays.
    func toggleRecurringActive(id: String) {
        edit { s in
            guard let i = s.recurringManual.firstIndex(where: { $0.id == id }) else { return }
            s.recurringManual[i].active.toggle()
        }
    }
}
