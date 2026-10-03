import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var store: ReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var importing = false
    @State private var importError: String?
    @FocusState private var editingText: Bool

    private var capacity: Int {
        let height = store.settings.panel.pixels.height - 2 * store.settings.padding
        return max(1, Int(floor((height + store.settings.lineGap) /
                               (store.settings.fontSize + store.settings.lineGap))))
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
                    Button("글 적용") {
                        editingText = false
                        store.updateText(draft)
                    }
                    .accessibilityIdentifier("settings.applyText")
                    Button("TXT 파일 불러오기", systemImage: "doc.text") {
                        editingText = false
                        importing = true
                    }
                    .accessibilityIdentifier("settings.import")
                } header: {
                    Text("읽을 글")
                } footer: {
                    Text("본문을 붙여넣고 글 적용을 눌러줘. 새 글은 처음부터 읽게 돼.")
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
                    Text("현재 설정의 패널에는 약 \(capacity)줄이 들어가. 과거 맥락은 설정한 줄 수와 남는 공간 안에서 표시해. px는 선택한 패널 해상도 기준이야.")
                }

                Section("기타") {
                    Toggle("진행 표시", isOn: $store.settings.showProgress)
                        .accessibilityIdentifier("settings.progress")
                    Toggle("햅틱", isOn: $store.settings.haptics)
                        .accessibilityIdentifier("settings.haptics")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .onAppear { draft = store.text }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard let text = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .utf16) else {
                        importError = "UTF-8 또는 UTF-16 형식의 TXT 파일을 선택해줘."
                        return
                    }
                    draft = text
                } catch {
                    importError = "파일을 읽지 못했어. 파일을 다운로드했는지 확인하고 다시 선택해줘."
                }
            }
            .alert("파일 불러오기", isPresented: Binding(
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
