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
    @Query private var allTemplates: [WorkoutTemplate]

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        Form {
            Section {
                Button {
                    do {
                        exportDocument = BackupDocument(data: try buildExportData())
                        showingExporter = true
                    } catch {
                        statusIsError = true
                        statusMessage = "导出失败：\(error.localizedDescription)"
                    }
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
                Text("新备份包含逐组记录、RPE、体测、模板和课时流水。同一份新格式备份重复导入会自动跳过。")
            }
        }
        .navigationTitle(loc.t("设置"))
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName()
        ) { result in
            if case .failure(let error) = result {
                statusIsError = true
                statusMessage = "导出失败：\(error.localizedDescription)"
            }
        }
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

    private func buildExportData() throws -> Data {
        try BackupV2Service.encode(students: allStudents, templates: allTemplates)
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
                if let archive = try? BackupV2Service.decode(data) {
                    let result = try BackupV2Service.insert(archive, into: modelContext)
                    statusIsError = false
                    statusMessage = "导入成功：新增 \(result.importedStudents) 位，跳过 \(result.skippedStudents) 位"
                } else {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let payload = try decoder.decode(BackupPayload.self, from: data)
                    let result = try LegacyBackupService.insert(payload, sourceData: data, into: modelContext)
                    statusIsError = false
                    statusMessage = "旧版备份导入：新增 \(result.importedStudents) 位，跳过 \(result.skippedStudents) 位"
                }
            } catch {
                modelContext.rollback()
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
            .modelContainer(for: [Student.self, WorkoutSession.self, ExerciseEntry.self, WorkoutSet.self, BodyMeasurement.self, CreditTransaction.self, WorkoutTemplate.self, TemplateExercise.self], inMemory: true)
    }
}
