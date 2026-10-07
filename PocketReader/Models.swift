import Foundation

enum PresentationMode: String, Codable, CaseIterable, Identifiable {
    case current, past, sentence
    var id: String { rawValue }
    var title: String {
        switch self {
        case .current: return "현재 조각만"
        case .past: return "과거 맥락 누적"
        case .sentence: return "현재 문장 안의 맥락"
        }
    }
}

enum SegmentationMode: String, Codable, CaseIterable, Identifiable {
    case balanced, greedy, eojeol
    var id: String { rawValue }
    var title: String {
        switch self {
        case .balanced: return "Visual Balanced"
        case .greedy: return "Visual Greedy"
        case .eojeol: return "3–5어절 기준"
        }
    }
}

enum PanelPreset: String, Codable, CaseIterable, Identifiable {
    case bar223, bar225, bar219, spi190, bar240, control200
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bar223: return "2.23″ · 480 × 200"
        case .bar225: return "2.25″ · 284 × 76"
        case .bar219: return "2.19″ · 400 × 240"
        case .spi190: return "1.9″ · 320 × 170"
        case .bar240: return "2.4″ · 310 × 100"
        case .control200: return "2.0″ · 320 × 240"
        }
    }
    var pixels: (width: Double, height: Double) {
        switch self {
        case .bar223: return (480, 200)
        case .bar225: return (284, 76)
        case .bar219: return (400, 240)
        case .spi190: return (320, 170)
        case .bar240: return (310, 100)
        case .control200: return (320, 240)
        }
    }
    var millimeters: (width: Double, height: Double) {
        switch self {
        case .bar223: return (52.42, 21.72)
        case .bar225: return (55.29, 14.80)
        case .bar219: return (52.80, 31.68)
        case .spi190: return (42.72, 22.70)
        case .bar240: return (55.80, 18)
        case .control200: return (40.80, 30.60)
        }
    }
}

enum WordFocusStyle: String, Codable, CaseIterable, Identifiable {
    case yellow, color, underline, dimOthers, highContrast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .yellow: return "노란 배경"
        case .color: return "글자 색상"
        case .underline: return "밑줄"
        case .dimOthers: return "다른 어절 흐리게"
        case .highContrast: return "굵게 / 높은 대비"
        }
    }
}

struct ReaderSettings: Codable, Equatable {
    var presentation: PresentationMode = .past
    var segmentation: SegmentationMode = .balanced
    var wordFocusStyle: WordFocusStyle = .yellow
    var panel: PanelPreset = .bar223
    var fontSize: Double = 26
    var lineGap: Double = 6
    var padding: Double = 14
    var pastLines: Int = 3
    var actualSize: Bool = false
    // Points per mm is intentionally calibrated by the reader, never inferred from screen PPI.
    var pointsPerMM: Double = 6.0
    var showProgress: Bool = false
    var haptics: Bool = false
}

extension ReaderSettings {
    private enum CodingKeys: String, CodingKey {
        case presentation, segmentation, wordFocusStyle, panel, fontSize, lineGap, padding, pastLines, actualSize, pointsPerMM, showProgress, haptics
    }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        presentation = try c.decodeIfPresent(PresentationMode.self, forKey: .presentation) ?? presentation
        segmentation = try c.decodeIfPresent(SegmentationMode.self, forKey: .segmentation) ?? segmentation
        wordFocusStyle = try c.decodeIfPresent(WordFocusStyle.self, forKey: .wordFocusStyle) ?? wordFocusStyle
        panel = try c.decodeIfPresent(PanelPreset.self, forKey: .panel) ?? panel
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? fontSize
        lineGap = try c.decodeIfPresent(Double.self, forKey: .lineGap) ?? lineGap
        padding = try c.decodeIfPresent(Double.self, forKey: .padding) ?? padding
        pastLines = try c.decodeIfPresent(Int.self, forKey: .pastLines) ?? pastLines
        actualSize = try c.decodeIfPresent(Bool.self, forKey: .actualSize) ?? actualSize
        pointsPerMM = try c.decodeIfPresent(Double.self, forKey: .pointsPerMM) ?? pointsPerMM
        showProgress = try c.decodeIfPresent(Bool.self, forKey: .showProgress) ?? showProgress
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? haptics
    }
}

struct ReadingToken: Equatable {
    let text: String
    let sourceRange: NSRange
    let displayRange: NSRange
    let x: Double
    let width: Double
}

struct ReadingUnit: Identifiable, Equatable {
    let text: String
    let sentenceIndex: Int
    let sourceRange: NSRange
    let width: Double
    let tokens: [ReadingToken]
    let inkLeft: Double
    let fontScale: Double
    var id: Int { sourceRange.location }
}

enum ReaderSample {
    static let text = "읽는 동안 시선이 한곳에 머물 수 있도록 다음 조각을 천천히 읽는다.\n\n사람은 긴 글을 읽을 때 항상 같은 속도로 정보를 처리하지 않는다. 어떤 문장은 짧고 단순하지만, 어떤 문장은 여러 개의 절과 수식어를 포함하고 있어서 더 많은 생각이 필요하다.\n\n이 작은 리더는 지금 읽을 부분만 보여준다. 이미 읽은 내용은 위에 남기고, 아직 읽지 않은 내용은 숨긴다. 필요하면 언제든 돌아가 맥락을 확인할 수 있다.\n\n좋은 읽기 경험은 속도만으로 결정되지 않는다. 천천히 이해하고, 멈추고, 다시 읽을 수 있는 여유도 중요하다.\n\nThis reader keeps the current focus in one stable place. Take your time, move back whenever you need context, and continue at your own pace."
}
