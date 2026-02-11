import SwiftUI
import PocketGrisCore

/// SwiftUI view rendering waypoints, paths, and sprite preview on the overlay
struct ChoreographerOverlayView: View {
    @ObservedObject var viewModel: ChoreographerViewModel

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Click target (transparent)
                Color.clear
                    .contentShape(Rectangle())
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
                    color: color,
                    isSelected: isSelected,
                    onTap: { onWaypointTap?(wpIndex) },
                    onRightClick: { onWaypointRightClick?(wpIndex) }
                )
            }
        }
    }
}

/// Single waypoint marker
struct WaypointDot: View {
    let position: Position
    let index: Int
    let color: Color
    let isSelected: Bool
    var onTap: (() -> Void)?
    var onRightClick: (() -> Void)?

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .fill(color)
                .frame(width: isSelected ? 16 : 12, height: isSelected ? 16 : 12)

            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)

            // Index label
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .offset(y: -18)
                .shadow(color: .black, radius: 2)
        }
        .position(x: position.x, y: position.y)
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
