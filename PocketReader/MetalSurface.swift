import SwiftUI
import UIKit

enum ReaderPalette {
    static let ink = Color(red: 0.09, green: 0.09, blue: 0.085)
    static let lcd = Color(red: 0.947, green: 0.933, blue: 0.896)
}

struct MetalSurface: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.83), Color(white: 0.76), Color(white: 0.84), Color(white: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(uiImage: SurfaceGrain.image)
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(0.35)
            LinearGradient(colors: [.white.opacity(0.14), .clear, .black.opacity(0.035)], startPoint: .leading, endPoint: .trailing)
        }
        .accessibilityHidden(true)
    }
}

struct IvorySurface: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.91), Color(white: 0.85), Color(white: 0.88)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(uiImage: SurfaceGrain.image)
                .resizable(resizingMode: .tile)
                .blendMode(.softLight)
                .opacity(0.13)
        }
    }
}

private enum SurfaceGrain {
    // Deterministic procedural grain, rendered once. No flattened UI screenshot assets.
    static let image: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 192, height: 192), format: format).image { renderer in
            let context = renderer.cgContext
            var seed: UInt64 = 41
            for y in 0..<192 {
                for x in 0..<192 {
                    seed = seed &* 6364136223846793005 &+ 1
                    let value = CGFloat((seed >> 33) % 90 + 85) / 255
                    context.setFillColor(UIColor(white: value, alpha: 1).cgColor)
                    context.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
            for y in stride(from: 0, to: 192, by: 3) {
                context.setFillColor(UIColor(white: 0.75, alpha: 0.14).cgColor)
                context.fill(CGRect(x: 0, y: CGFloat(y), width: 192, height: 0.5))
            }
        }
    }()
}
