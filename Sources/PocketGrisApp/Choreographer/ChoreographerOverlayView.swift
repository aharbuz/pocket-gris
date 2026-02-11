import SwiftUI
import PocketGrisCore

/// SwiftUI view rendering waypoints, paths, and sprite preview on the overlay
struct ChoreographerOverlayView: View {
    @ObservedObject var viewModel: ChoreographerViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Click target (transparent) - only accepts hits during placement mode
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(viewModel.isPlacing)
                    .onTapGesture { location in
                        if viewModel.isPlacing {
                            let pos = Position(x: location.x, y: location.y)
                            viewModel.addWaypoint(at: pos)
                        }
                    }

                // Draw paths and waypoints for all tracks
                ForEach(Array(viewModel.currentScene.tracks.enumerated()), id: \.offset) { trackIndex, track in
                    TrackPathView(
                        track: track,
                        trackIndex: trackIndex,
                        isSelected: viewModel.selectedTrackIndex == trackIndex,
                        color: viewModel.colorForTrack(at: trackIndex),
                        onWaypointTap: { wpIndex in
                            viewModel.selectTrack(at: trackIndex)
                            viewModel.selectedSegmentIndex = wpIndex > 0 ? wpIndex - 1 : nil
                        },
                        onWaypointRightClick: { wpIndex in
                            viewModel.removeWaypoint(trackIndex: trackIndex, waypointIndex: wpIndex)
                        },
                        onWaypointDragStart: {
                            viewModel.beginWaypointDrag()
                        },
                        onWaypointDrag: { wpIndex, newPos in
                            viewModel.moveWaypoint(trackIndex: trackIndex, waypointIndex: wpIndex, to: newPos)
                        }
                    )
                }

                // Sprite preview at cursor
                if viewModel.isPlacing, let framePath = viewModel.previewFramePath,
                   let nsImage = ImageCache.shared.image(for: framePath) {
                    Image(nsImage: nsImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .opacity(0.7)
                        .position(
                            x: viewModel.previewPosition.x + 32,
                            y: viewModel.previewPosition.y - 32
                        )
                        .allowsHitTesting(false)
                }

                // Instructions overlay
                if viewModel.isPlacing {
                    VStack {
                        Spacer()
                        HStack {
                            Text("Click to place waypoints")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                            Text("Right-click to remove")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                            Text("Esc to stop placing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.7))
                                )
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

/// Renders a single track's path and waypoints
struct TrackPathView: View {
    let track: SceneTrack
    let trackIndex: Int
    let isSelected: Bool
    let color: Color
    var onWaypointTap: ((Int) -> Void)?
    var onWaypointRightClick: ((Int) -> Void)?
    var onWaypointDragStart: (() -> Void)?
    var onWaypointDrag: ((Int, Position) -> Void)?

    var body: some View {
        ZStack {
            // Draw path lines between waypoints
            if track.waypoints.count >= 2 {
                Path { path in
                    path.move(to: CGPoint(x: track.waypoints[0].x, y: track.waypoints[0].y))
                    for i in 1..<track.waypoints.count {
                        path.addLine(to: CGPoint(x: track.waypoints[i].x, y: track.waypoints[i].y))
                    }
                }
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: [8, 4])
                )
            }

            // Draw waypoints
            ForEach(Array(track.waypoints.enumerated()), id: \.offset) { wpIndex, waypoint in
                WaypointDot(
                    position: waypoint,
                    index: wpIndex,
                    animationLabel: animationLabel(for: wpIndex),
                    color: color,
                    isSelected: isSelected,
                    onTap: { onWaypointTap?(wpIndex) },
                    onRightClick: { onWaypointRightClick?(wpIndex) },
                    onDragStart: { onWaypointDragStart?() },
                    onDrag: { newPos in onWaypointDrag?(wpIndex, newPos) }
                )
            }
        }
    }

    /// Get animation label for a waypoint
    /// - Waypoint 0: shows the animation of segment 0 (what plays AFTER this waypoint)
    /// - Waypoint N (N > 0): shows the animation of segment N-1 (what plays TO reach this waypoint)
    private func animationLabel(for waypointIndex: Int) -> String? {
        guard !track.segments.isEmpty else { return nil }

        if waypointIndex == 0 {
            // First waypoint: show the animation that starts here
            return track.segments.first?.animationName
        } else {
            // Other waypoints: show the animation that ends here (segment N-1)
            let segmentIndex = waypointIndex - 1
            if segmentIndex < track.segments.count {
                return track.segments[segmentIndex].animationName
            }
        }
        return nil
    }
}

/// Single waypoint marker
struct WaypointDot: View {
    let position: Position
    let index: Int
    let animationLabel: String?
    let color: Color
    let isSelected: Bool
    var onTap: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDrag: ((Position) -> Void)?

    @State private var isDragging = false
    @State private var dragStartPosition: Position?

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(isDragging ? color.opacity(0.7) : color)
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)

            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)

            // Index label (above waypoint)
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .offset(y: -18)
                .shadow(color: .black, radius: 2)

            // Animation label (below waypoint)
            if let label = animationLabel {
                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.85))
                    )
                    .offset(y: 20)
            }
        }
        .position(x: position.x, y: position.y)
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if !isDragging {
                        // Capture the starting position at drag start
                        isDragging = true
                        dragStartPosition = position
                        onDragStart?()
                    }
                    // Use the captured start position, not the current (potentially updated) position
                    if let start = dragStartPosition {
                        let newPos = Position(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        )
                        onDrag?(newPos)
                    }
                }
                .onEnded { _ in
                    isDragging = false
                    dragStartPosition = nil
                }
        )
        .onTapGesture {
            onTap?()
        }
        .contextMenu {
            Button("Delete Waypoint") {
                onRightClick?()
            }
        }
    }
}
