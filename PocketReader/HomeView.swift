import SwiftUI

struct HomeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MetalSurface()
                RoundedRectangle(cornerRadius: 12)
                    .fill(ReaderPalette.lcd)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.65), lineWidth: 3))
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.38)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.25)
                IvorySurface().clipShape(Circle())
                    .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                    .frame(width: geometry.size.width * 0.78, height: geometry.size.width * 0.78)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.65)
            }
        }
        .ignoresSafeArea()
    }
}
