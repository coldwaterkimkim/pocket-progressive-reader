import XCTest
@testable import PocketReader

final class SourceDocumentTests: XCTestCase {
    func testRequestedAttentionExample() {
        let source = "## Attention\n\n**Attention** is limited.\n\n- Future content competes.\n- Past context can help.\n\n[OpenAI](https://openai.com)"
        XCTAssertEqual(MarkdownNormalizer.normalize(source), "Attention\n\nAttention is limited.\n\nFuture content competes.\n\nPast context can help.\n\nOpenAI")
    }

    func testMarkdownReadableTextAndStructuralBoundaries() {
        let document = SourceDocument(source: "# 제목\n\n첫 **문장**에는 *강조*가 있다.\n다음 줄이다.\n- 첫 항목\n- 두 번째 항목\n> 인용 내용", format: .markdown)
        XCTAssertEqual(document.normalizedText, "제목\n\n첫 문장에는 강조가 있다. 다음 줄이다.\n\n첫 항목\n\n두 번째 항목\n\n인용 내용")
        XCTAssertEqual(document.blocks.count, 5)
        let ns = document.normalizedText as NSString
        XCTAssertEqual(document.blocks.map { ns.substring(with: $0) }, ["제목", "첫 문장에는 강조가 있다. 다음 줄이다.", "첫 항목", "두 번째 항목", "인용 내용"])
    }

    func testEscapesLiteralUnderscoresAndInlineCode() {
        let text = #"\*literal\* file_name **bold _nested_** and `**code** file_name`"#
        XCTAssertEqual(MarkdownNormalizer.normalize(text), "*literal* file_name bold nested and **code** file_name")
    }

    func testLinksImagesHTMLAndFencedCode() {
        let source = "[설명](https://example.com) ![그림](photo.png) [참고][r]\n\n[r]: https://example.com\n\n<p>읽는 내용</p><!-- 숨김 --><script>alert('x')</script><style>body{}</style>\n\n```swift\nlet file_name = \"**code**\"\n```"
        let text = MarkdownNormalizer.normalize(source)
        XCTAssertEqual(text, "설명 그림 참고\n\n읽는 내용\n\nlet file_name = \"**code**\"")
        XCTAssertFalse(text.contains("https"))
        XCTAssertFalse(text.contains("alert"))
    }

    func testNestedLinkDestinationsLabelsAndHTMLEntities() {
        let source = "[한국어 [안쪽] 설명](https://example.com/a_(b)) ![그림 [보조]](img_(2).png) <a href=\"https://example.com\">HTML&nbsp;링크 &amp; 내용</a> &#xAC00; &#45208;"
        XCTAssertEqual(MarkdownNormalizer.normalize(source), "한국어 [안쪽] 설명 그림 [보조] HTML 링크 & 내용 가 나")
        XCTAssertEqual(MarkdownNormalizer.normalize("[보존](닫히지않은목적지"), "[보존](닫히지않은목적지")
        XCTAssertEqual(MarkdownNormalizer.normalize(#"\[문자\] `&amp;` file_name"#), "[문자] &amp; file_name")
    }

    func testPlainLinesRemainStructuralAndUnicodeRangesMatch() {
        let document = SourceDocument(source: "제목👨‍👩‍👧‍👦\r\n내용\r\n\r\n다음", format: .plain)
        XCTAssertEqual(document.normalizedText, "제목👨‍👩‍👧‍👦\n\n내용\n\n다음")
        let ns = document.normalizedText as NSString
        XCTAssertEqual(document.blocks.map { ns.substring(with: $0) }, ["제목👨‍👩‍👧‍👦", "내용", "다음"])
    }

    func testUTF8AndBOMUTF16Ingestion() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let text = "한국어 글 👋\n새 줄"
        let cases = [Data(text.utf8), Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8), Data([0xFF, 0xFE]) + text.data(using: .utf16LittleEndian)!, Data([0xFE, 0xFF]) + text.data(using: .utf16BigEndian)!]
        for data in cases {
            try data.write(to: url)
            XCTAssertEqual(try SourceIngestion.read(url: url), text)
        }
        try Data([0xFF, 0x00, 0x80]).write(to: url)
        XCTAssertThrowsError(try SourceIngestion.read(url: url))
    }

    func testLargeFileHasNoArtificialImportCap() throws {
        let source = String(repeating: "긴 본문 내용입니다.\n", count: 25_000)
        XCTAssertGreaterThan(source.utf16.count, 200_000)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(source.utf8).write(to: url)
        XCTAssertEqual(try SourceIngestion.read(url: url), source)
        let document = SourceDocument(source: source, format: .plain)
        XCTAssertEqual(document.blocks.count, 25_000)
    }
}
