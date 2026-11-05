import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan, .blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("GlassOS")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            Text("v\(AppVersion.current)")
                .font(.title3)
                .foregroundColor(.white.opacity(0.5))

            Text("Desktop Customization Engine for macOS")
                .font(.body)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Divider().opacity(0.2).frame(width: 200)

            VStack(spacing: 4) {
                Text("Video & Gradient Wallpapers")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("3D Carousel Browser")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("Glassmorphic Interface")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("F3 Window Navigator")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                Text("Auto-Update from GitHub")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
