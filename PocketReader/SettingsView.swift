import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var importing = false
    @State private var importError: String?
    @State private var confirmingClose = false
    @State private var applied = false
    @State private var loadedDraft = false
    @FocusState private var editingText: Bool

    private var capacity: Int {
        ReadingEngine.capacity(store.settings)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $draft)
                        .frame(minHeight: 160)
                        .focused($editingText)
                        .accessibilityLabel("읽을 글")
                        .accessibilityIdentifier("settings.text")
                    Button("본문 비우기") {
                        draft = ""
                        editingText = true
                    }
                    .accessibilityIdentifier("settings.clearText")
                    Button("글 적용") {
                        editingText = false
                        _ = applyDraft()
                    }
                    .accessibilityIdentifier("settings.applyText")
                    if applied {
                        Label("글을 적용했어", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("TXT 파일 불러오기", systemImage: "doc.text") {
                        editingText = false
                        importing = true
                    }
                    .accessibilityIdentifier("settings.import")
                } header: {
                    Text("읽을 글")
                } footer: {
                    Text("본문을 붙여넣고 글 적용을 눌러줘. 새 글은 처음부터 읽게 돼. 최대 200,000 UTF-16 문자까지 지원해.")
                }

                Section("읽기 방식") {
                    Picker("표시", selection: $store.settings.presentation) {
                        ForEach(PresentationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settings.presentation")
                    Picker("조각 분할", selection: $store.settings.segmentation) {
                        ForEach(SegmentationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .accessibilityIdentifier("settings.segmentation")
                }

                Section {
                    Picker("패널", selection: $store.settings.panel) {
                        ForEach(PanelPreset.allCases) { panel in
                            Text(panel.title).tag(panel)
                        }
                    }
                    .accessibilityIdentifier("settings.panel")
                    Toggle("실제 크기로 표시", isOn: $store.settings.actualSize)
                        .accessibilityIdentifier("settings.actualSize")
                    if store.settings.actualSize {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("50 mm 보정 자")
                                .font(.subheadline)
                            ScrollView(.horizontal, showsIndicators: true) {
                                calibrationRuler
                            }
                            Slider(value: $store.settings.pointsPerMM, in: 3...8, step: 0.01)
                                .accessibilityLabel("실제 크기 보정")
                            Text("실물 자의 50 mm와 위 눈금의 양 끝을 맞춰줘. 길면 옆으로 밀어 확인할 수 있어. 보정값은 기기마다 달라.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("디스플레이")
                } footer: {
                    Text("기본은 화면에 맞춘 크기야. 실제 크기는 보정에 따른 근사치이며, 화면보다 큰 패널은 들어갈 크기로 줄여 표시해.")
                }

                Section {
                    Stepper(value: $store.settings.fontSize, in: 10...34, step: 1) {
                        valueRow("글자 크기", value: "\(Int(store.settings.fontSize)) px")
                    }
                    .accessibilityIdentifier("settings.fontSize")
                    Stepper(value: $store.settings.lineGap, in: 0...18, step: 1) {
                        valueRow("줄 간격", value: "\(Int(store.settings.lineGap)) px")
                    }
                    Stepper(value: $store.settings.padding, in: 2...30, step: 1) {
                        valueRow("안쪽 여백", value: "\(Int(store.settings.padding)) px")
                    }
                    Stepper(value: $store.settings.pastLines, in: 0...6) {
                        valueRow("과거 표시 줄 수", value: "\(store.settings.pastLines)줄")
                    }
                    .disabled(store.settings.presentation == .current)
                } header: {
                    Text("글자와 여백")
                } footer: {
                    Text("현재 조각 1줄과 과거 맥락 최대 \(capacity)줄을 표시할 수 있어. 과거 맥락은 설정한 줄 수 안에서 표시해. px는 선택한 패널 해상도 기준이야.")
                }

                Section("기타") {
                    Toggle("진행 표시", isOn: $store.settings.showProgress)
                        .accessibilityIdentifier("settings.progress")
                    Toggle("햅틱", isOn: $store.settings.haptics)
                        .accessibilityIdentifier("settings.haptics")
                }
                if let error = store.persistenceError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } header: {
                        Text("저장 상태")
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        editingText = false
                        if draft != store.text { confirmingClose = true }
                        else { dismiss() }
                    }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .onAppear {
                guard !loadedDraft else { return }
                draft = store.text
                loadedDraft = true
            }
            .onChange(of: draft) { _, _ in applied = false }
            .interactiveDismissDisabled(draft != store.text)
            .confirmationDialog("적용하지 않은 글이 있어", isPresented: $confirmingClose, titleVisibility: .visible) {
                Button("글 적용하고 닫기") {
                    if applyDraft() { dismiss() }
                }
                Button("변경한 글 버리고 닫기", role: .destructive) { dismiss() }
                Button("계속 편집") { confirmingClose = false }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 800_004 else {
                        importError = "파일이 너무 커. 최대 200,000 UTF-16 문자의 TXT 파일을 선택해줘."
                        return
                    }
                    let data = try Data(contentsOf: url)
                    guard let text = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .utf16) else {
                        importError = "UTF-8 또는 UTF-16 형식의 TXT 파일을 선택해줘."
                        return
                    }
                    guard text.utf16.count <= 200_000 else {
                        importError = "글이 너무 길어. 최대 200,000 UTF-16 문자까지 지원하며 글은 자르지 않았어."
                        return
                    }
                    draft = text
                } catch {
                    importError = "파일을 읽지 못했어. 파일을 다운로드했는지 확인하고 다시 선택해줘."
                }
            }
            .alert("글 적용 및 불러오기", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("확인", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
        .preferredColorScheme(.light)
    }

    @discardableResult
    private func applyDraft() -> Bool {
        guard draft.utf16.count <= 200_000 else {
            importError = "글이 너무 길어. 최대 200,000 UTF-16 문자까지 지원하며 글은 자르지 않았어."
            return false
        }
        store.updateText(draft)
        applied = true
        return true
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var calibrationRuler: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 28))
            path.addLine(to: CGPoint(x: size.width, y: 28))
            for mm in 0...50 {
                let x = Double(mm) * store.settings.pointsPerMM
                let height: Double = mm.isMultiple(of: 10) ? 18 : (mm.isMultiple(of: 5) ? 12 : 7)
                path.move(to: CGPoint(x: x, y: 28))
                path.addLine(to: CGPoint(x: x, y: 28 - height))
            }
            context.stroke(path, with: .color(.primary), lineWidth: 1)
            context.draw(Text("0").font(.caption2), at: CGPoint(x: 0, y: 38), anchor: .leading)
            context.draw(Text("50 mm").font(.caption2), at: CGPoint(x: size.width, y: 38), anchor: .trailing)
        }
        .frame(width: 50 * store.settings.pointsPerMM, height: 48)
        .padding(.horizontal, 1)
        .accessibilityLabel("보정용 50 밀리미터 눈금")
    }
}
