import AppKit
import Observation
import PocketGrisCore

/// Orchestrates the choreographer overlay and panel windows
final class ChoreographerController {

    private static let lastSceneIdKey = "choreographer.lastSceneId"

    private var overlayWindow: ChoreographerOverlayWindow?
    private var panelController: ChoreographerPanelController?
    private var viewModel: ChoreographerViewModel?
    private var isObserving: Bool = false
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

        // Try to load last opened scene if none provided
        var sceneToLoad = scene
        if sceneToLoad == nil, let lastId = UserDefaults.standard.string(forKey: Self.lastSceneIdKey) {
            let allScenes = sceneStorage.loadAll()
            if let lastScene = allScenes.first(where: { $0.id == lastId }) {
                sceneToLoad = lastScene
            }
        }

        let vm = ChoreographerViewModel(scene: sceneToLoad, spriteLoader: spriteLoader, sceneStorage: sceneStorage)
        vm.onSave = { [weak self] scene in
            self?.saveScene(scene)
        }
        vm.onClose = { [weak self] in
            self?.close()
        }
        vm.onSceneDeleted = { [weak self] in
            self?.reloadScenes()
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

        // Start observing viewModel changes (scene ID and isPlacing)
        isObserving = true
        observeViewModel()
    }

    func close() {
        isObserving = false
        viewModel?.isPlacing = false
        overlayWindow?.teardown()
        overlayWindow = nil
        panelController?.close()
        panelController = nil
        viewModel = nil
    }

    // MARK: - Observation

    /// Observe viewModel changes using the Observation framework.
    /// Tracks currentScene.id (for persistence) and isPlacing (for overlay key management).
    private func observeViewModel() {
        guard isObserving, let vm = viewModel else { return }
        let currentSceneId = vm.currentScene.id

        withObservationTracking {
            // Access the properties we want to track
            _ = vm.currentScene.id
            _ = vm.isPlacing
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isObserving, let vm = self.viewModel else { return }

                // Handle scene ID change
                let newSceneId = vm.currentScene.id
                if newSceneId != currentSceneId {
                    self.persistLastSceneId(newSceneId)
                }

                // Handle isPlacing change
                if vm.isPlacing {
                    self.overlayWindow?.makeKey()
                }

                // Re-register for the next change
                self.observeViewModel()
            }
        }
    }

    // MARK: - Private

    private func saveScene(_ scene: Scene) {
        do {
            try sceneStorage.save(scene: scene)
            persistLastSceneId(scene.id)
            print("Scene saved: \(scene.name)")
            reloadScenes()
        } catch {
            print("Failed to save scene: \(error)")
        }
    }

    private func reloadScenes() {
        // Notify app to reload scenes into scheduler
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.reloadScenes()
        }
    }

    private func persistLastSceneId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.lastSceneIdKey)
    }
}
