import SwiftUI
import UniformTypeIdentifiers

/// A backup on its way to a share sheet or the Files app.
///
/// It carries the bytes already encoded rather than a `FinState`, so that what leaves the app is
/// exactly what `Store.exportBackup()` produced — one encoder, one shape, no chance of the
/// exported file and the saved file drifting apart.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
