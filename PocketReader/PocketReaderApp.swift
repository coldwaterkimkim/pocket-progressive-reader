import SwiftUI

@main
struct PocketReaderApp: App {
    init() {
        #if DEBUG
        // A real file in the system Files picker exercises the import path in UI tests.
        // This creates no fixture in Release or normal launches.
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            try? "파일에서 온 첫 문장. 파일에서 온 다음 문장.".write(
                to: documents.appendingPathComponent("Reader-Import-Test.txt"), atomically: true, encoding: .utf8)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.light)
                .statusBarHidden()
        }
    }
}
