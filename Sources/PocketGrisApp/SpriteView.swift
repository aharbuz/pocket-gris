import SwiftUI
import PocketGrisCore

/// SwiftUI view for displaying an animated sprite
struct SpriteView: View {
    @ObservedObject var viewModel: CreatureViewModel

    private let spriteSize: CGFloat = 64

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.isVisible {
                    spriteImage
                        .position(
                            x: CGFloat(viewModel.displayPosition.x),
                            y: CGFloat(viewModel.displayPosition.y)
                        )
                        .scaleEffect(x: viewModel.flipHorizontal ? -1 : 1, y: 1)
                        .opacity(viewModel.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var spriteImage: some View {
        if let path = viewModel.currentFramePath,
           let nsImage = ImageCache.shared.image(for: path) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.none)  // Pixel-perfect scaling
                .frame(width: spriteSize, height: spriteSize)
        } else {
            // Placeholder when no sprite loaded
            PlaceholderSprite()
                .frame(width: spriteSize, height: spriteSize)
        }
    }
}

/// Placeholder sprite for testing without real assets
struct PlaceholderSprite: View {
    @State private var eyeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Body
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.8))

            // Eyes
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                            .offset(x: eyeOffset, y: 2)
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                            .offset(x: eyeOffset, y: 2)
                    )
            }
            .offset(y: -8)

            // Mouth
            Path { path in
                path.move(to: CGPoint(x: 22, y: 40))
                path.addQuadCurve(
                    to: CGPoint(x: 42, y: 40),
                    control: CGPoint(x: 32, y: 48)
                )
            }
            .stroke(Color.black, lineWidth: 2)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
            ) {
                eyeOffset = 2
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SpriteView_Previews: PreviewProvider {
    static var previews: some View {
        PlaceholderSprite()
            .frame(width: 64, height: 64)
            .background(Color.gray.opacity(0.3))
    }
}
#endif
