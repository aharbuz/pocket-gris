import AppKit
import PocketGrisCore

/// Orchestrates the choreographer overlay and panel windows
final class ChoreographerController {

    private var overlayWindow: ChoreographerOverlayWindow?
    private var panelController: ChoreographerPanelController?
    private var viewModel: ChoreographerViewModel?
    private let spriteLoader: SpriteLoader
    private let sceneStorage: SceneStorage
    private let scenePlayer: ScenePlayer
    private let windowTracker: WindowTracker?
    private let cursorTracker: CursorTracker?

    var isOpen: Bool { overlayWindow?.isVisible ?? false }

    init(
        spriteLoader: SpriteLoader,
        sceneStorage: SceneStorage,
        scenePlayer: ScenePlayer,
        windowTracker: WindowTracker? = nil,
        cursorTracker: CursorTracker? = nil
    ) {
        self.spriteLoader = spriteLoader
        self.sceneStorage = sceneStorage
        self.scenePlayer = scenePlayer
        self.windowTracker = windowTracker
        self.cursorTracker = cursorTracker
    }

    func open(scene: Scene? = nil) {
        if isOpen {
            close()
        }

        let vm = ChoreographerViewModel(scene: scene, spriteLoader: spriteLoader)
        vm.onSave = { [weak self] scene in
            self?.saveScene(scene)
        }
        vm.onClose = { [weak self] in
            self?.close()
        }
        self.viewModel = vm

        // Create overlay window
        let overlay = ChoreographerOverlayWindow()
        overlay.setup(viewModel: vm)
        overlay.makeKeyAndOrderFront(nil)
        self.overlayWindow = overlay

        // Create panel
        let panel = ChoreographerPanelController(
            viewModel: vm,
            sceneStorage: sceneStorage,
            scenePlayer: scenePlayer,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        )
        panel.show()
        self.panelController = panel
    }

    func close() {
        overlayWindow?.teardown()
        overlayWindow = nil
        panelController?.close()
        panelController = nil
        viewModel = nil
    }

    // MARK: - Private

    private func saveScene(_ scene: Scene) {
        do {
            try sceneStorage.save(scene: scene)
            print("Scene saved: \(scene.name)")
            // Notify app to reload scenes into scheduler
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.reloadScenes()
            }
        } catch {
            print("Failed to save scene: \(error)")
        }
    }
}
