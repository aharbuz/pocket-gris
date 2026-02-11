import SwiftUI
import PocketGrisCore

/// SwiftUI view rendering waypoints, paths, and sprite preview on the overlay
struct ChoreographerOverlayView: View {
    @ObservedObject var viewModel: ChoreographerViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Click target (transparent) - handles placement and deselection
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        if viewModel.isPlacing {
                            let pos = Position(x: location.x, y: location.y)
                            viewModel.addWaypoint(at: pos)
                        } else {
                            // Click on empty area deselects segment
                            viewModel.selectedSegmentIndex = nil
                        }
                    }

                // Draw paths and waypoints for all tracks
                ForEach(Array(viewModel.currentScene.tracks.enumerated()), id: \.offset) { trackIndex, track in
                    TrackPathView(
                        track: track,
                        trackIndex: trackIndex,
                        isSelected: viewModel.selectedTrackIndex == trackIndex,
                        selectedSegmentIndex: viewModel.selectedTrackIndex == trackIndex ? viewModel.selectedSegmentIndex : nil,
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
    let selectedSegmentIndex: Int?
    let color: Color
    var onWaypointTap: ((Int) -> Void)?
    var onWaypointRightClick: ((Int) -> Void)?
    var onWaypointDragStart: (() -> Void)?
    var onWaypointDrag: ((Int, Position) -> Void)?

    var body: some View {
        ZStack {
            // Draw path lines between waypoints (each segment drawn separately)
            if track.waypoints.count >= 2 {
                let segmentCount = track.waypoints.count - 1
                ForEach(0..<segmentCount, id: \.self) { segmentIndex in
                    let start = track.waypoints[segmentIndex]
                    let end = track.waypoints[segmentIndex + 1]
                    let isSegmentSelected = selectedSegmentIndex == segmentIndex

                    Path { path in
                        path.move(to: CGPoint(x: start.x, y: start.y))
                        path.addLine(to: CGPoint(x: end.x, y: end.y))
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: isSegmentSelected ? 4.0 : (isSelected ? 2.5 : 1.5),
                            dash: [8, 4]
                        )
                    )
                }
            }

            // Draw waypoints
            ForEach(Array(track.waypoints.enumerated()), id: \.offset) { wpIndex, waypoint in
                WaypointDot(
                    position: waypoint,
                    index: wpIndex,
                    animationLabel: animationLabel(for: wpIndex),
                    color: color,
                    isTrackSelected: isSelected,
                    isSegmentEndpoint: isEndpointOfSelectedSegment(wpIndex),
                    onTap: { onWaypointTap?(wpIndex) },
                    onRightClick: { onWaypointRightClick?(wpIndex) },
                    onDragStart: { onWaypointDragStart?() },
                    onDrag: { newPos in onWaypointDrag?(wpIndex, newPos) }
                )
            }
        }
    }

    /// Check if a waypoint is an endpoint of the selected segment
    private func isEndpointOfSelectedSegment(_ waypointIndex: Int) -> Bool {
        guard let segIdx = selectedSegmentIndex else { return false }
        // Segment N connects waypoints N and N+1
        return waypointIndex == segIdx || waypointIndex == segIdx + 1
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
    let isTrackSelected: Bool
    let isSegmentEndpoint: Bool
    var onTap: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onDragStart: (() -> Void)?
    var onDrag: ((Position) -> Void)?

    @State private var isDragging = false
    @State private var dragStartPosition: Position?

    // Compute sizes based on selection state
    private var outerSize: CGFloat {
        if isSegmentEndpoint { return 20 }
        if isTrackSelected { return 16 }
        return 12
    }

    private var innerSize: CGFloat {
        if isSegmentEndpoint { return 10 }
        if isTrackSelected { return 8 }
        return 6
    }

    var body: some View {
        ZStack {
            // Glow effect for segment endpoint
            if isSegmentEndpoint {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: outerSize + 8, height: outerSize + 8)
            }

            // Outer ring
            Circle()
                .fill(isDragging ? color.opacity(0.7) : color)
                .frame(width: outerSize, height: outerSize)

            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: innerSize, height: innerSize)

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
