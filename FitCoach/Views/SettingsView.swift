import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 简单的 JSON 文件包装，配合 .fileExporter / .fileImporter 使用
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

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

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var loc: LocalizationManager
    @Query private var allStudents: [Student]

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section {
                Button {
                    exportDocument = BackupDocument(data: buildExportData())
                    showingExporter = true
                } label: {
                    Label(loc.t("导出数据"), systemImage: "square.and.arrow.up")
                }
            } header: {
                Text(loc.t("数据备份"))
            } footer: {
                Text(loc.t("导出为一个文件，换手机或重装App后可以导入回来。"))
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label(loc.t("导入数据"), systemImage: "square.and.arrow.down")
                }
                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(statusIsError ? .red : .secondary)
                }
            } footer: {
                Text(loc.t("导入会把备份文件里的学员和训练记录新增进来，不会覆盖或删除现有数据，注意避免重复导入同一份备份。"))
            }
        }
        .navigationTitle(loc.t("设置"))
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName()
        ) { _ in }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleImport(result)
        }
    }

    private func exportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "FitCoach-\(formatter.string(from: Date()))"
    }

    private func buildExportData() -> Data {
        let payload = BackupPayload(
            exportedAt: Date(),
            students: allStudents.map { $0.toBackup() }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(payload)) ?? Data()
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            statusIsError = true
            statusMessage = "\(loc.t("导入失败"))：\(error.localizedDescription)"

        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                statusIsError = true
                statusMessage = loc.t("导入失败")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(BackupPayload.self, from: data)

                for studentBackup in payload.students {
                    insertBackupStudent(studentBackup, into: modelContext)
                }

                statusIsError = false
                statusMessage = "\(loc.t("导入成功"))：\(payload.students.count) \(loc.t("位学员"))"
            } catch {
                statusIsError = true
                statusMessage = "\(loc.t("导入失败"))：\(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LocalizationManager.shared)
            .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self], inMemory: true)
    }
}
