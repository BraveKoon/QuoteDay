import SwiftUI
import UniformTypeIdentifiers

/// 내보내기가 파일 앱에 넘기는 문서.
///
/// `ShareLink` 가 아니라 `fileExporter` 를 쓴다. 공유 시트는 **보내는** 동작이고
/// 백업은 **두는** 동작이다. 사용자가 파일 앱이나 iCloud Drive 안에 자기 자리를
/// 골라 두어야, 기기를 바꿀 때 찾아올 수 있다.
struct JournalArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// 백업을 마지막으로 한 때. 설정 화면이 경고를 띄울지 정하는 데 쓴다.
enum JournalBackupMark {
    static func lastBackup(defaults: UserDefaults = AppGroup.defaults) -> Date? {
        defaults.object(forKey: SharedDefaultsKey.lastJournalBackupAt) as? Date
    }

    static func markBackedUp(at date: Date = .now, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(date, forKey: SharedDefaultsKey.lastJournalBackupAt)
    }

    /// 백업하라고 재촉할 때가 되었는지.
    ///
    /// 기록이 몇 편 없을 때부터 붉은 글씨를 띄우면 잔소리가 된다. 열 편쯤
    /// 쌓이면 그때는 잃어서 아까운 분량이다.
    static func needsWarning(noteCount: Int, defaults: UserDefaults = AppGroup.defaults) -> Bool {
        noteCount >= 10 && lastBackup(defaults: defaults) == nil
    }
}
