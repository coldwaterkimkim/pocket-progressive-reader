import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var importing = false
    @State private var draftFormat: SourceFormat = .plain
    @State private var importFormat: SourceFormat = .plain
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
                    Picker("입력 형식", selection: $draftFormat) {
                        ForEach(SourceFormat.allCases) { format in Text(format.title).tag(format) }
                    }
                    .accessibilityIdentifier("settings.sourceFormat")
                    TextEditor(text: $draft)
                        .frame(height: 180)
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
                        importFormat = .plain
                        importing = true
                    }
                    .accessibilityIdentifier("settings.import")
                    Button("Markdown 파일 불러오기", systemImage: "doc.text") {
                        editingText = false
                        importFormat = .markdown
                        importing = true
                    }
                    .accessibilityIdentifier("settings.importMD")
                } header: {
                    Text("소스")
                } footer: {
                    Text("입력 형식을 선택하고 글 적용을 눌러줘. Markdown은 제목·목록·인용·코드·표·링크·이미지 서식으로 표시돼. 크기 제한은 두지 않지만, 큰 문서의 처리 가능 크기는 기기 메모리에 따라 달라.")
                }

                Section {
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
                } header: {
                    Text("읽기 방식")
                } footer: {
                    Text("Full은 전체 본문을 자연스럽게 줄바꿈해서 보여줘. 한 줄 가로 스크롤은 전체 본문을 한 줄로 펼쳐 보여주며, 블록 서식은 순서대로 이어져.")
                }

                Section("WORD FOCUS") {
                    Picker("강조 스타일", selection: $store.settings.wordFocusStyle) {
                        ForEach(WordFocusStyle.allCases) { style in Text(style.title).tag(style) }
                    }
                    .accessibilityIdentifier("settings.wordFocusStyle")
                    Text("휠을 돌리면 어절 포커스가 시작돼. 방향 버튼은 조각·문장을 이동하고 포커스를 해제해.")
                        .font(.caption).foregroundStyle(.secondary)
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
                    Text("디스플레이 / 실험")
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
                    .disabled(store.settings.presentation != .past || store.settings.segmentation == .full)
                } header: {
                    Text("글자와 여백")
                } footer: {
                    Text("현재 조각 1줄과 과거 맥락 최대 \(capacity)줄을 표시할 수 있어. 과거 맥락은 설정한 줄 수 안에서 같은 대비로 표시해. Full과 가로 스크롤에서는 전체 본문을 스크롤해. px는 선택한 패널 해상도 기준이야.")
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
                        if isDirty { confirmingClose = true }
                        else { dismiss() }
                    }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .onAppear {
                guard !loadedDraft else { return }
                draft = store.text
                draftFormat = store.sourceFormat
                loadedDraft = true
            }
            .onChange(of: draft) { _, _ in applied = false }
            .onChange(of: draftFormat) { _, _ in applied = false }
            .interactiveDismissDisabled(isDirty)
            .confirmationDialog("적용하지 않은 글이 있어", isPresented: $confirmingClose, titleVisibility: .visible) {
                Button("글 적용하고 닫기") {
                    if applyDraft() { dismiss() }
                }
                Button("변경한 글 버리고 닫기", role: .destructive) { dismiss() }
                Button("계속 편집") { confirmingClose = false }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: importFormat == .plain
                ? [.plainText] : [UTType(filenameExtension: "md") ?? .plainText, .plainText]) { result in
                do {
                    let url = try result.get()
                    draft = try SourceIngestion.read(url: url)
                    draftFormat = importFormat
                } catch {
                    importError = "파일을 읽지 못했어. UTF-8 또는 UTF-16 파일인지, 다운로드됐는지 확인해줘."
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

    private var isDirty: Bool { draft != store.text || draftFormat != store.sourceFormat }

    @discardableResult
    private func applyDraft() -> Bool {
        store.updateText(draft, format: draftFormat)
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
