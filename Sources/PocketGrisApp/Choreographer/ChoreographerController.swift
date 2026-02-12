import AppKit
import Combine
import PocketGrisCore

/// Orchestrates the choreographer overlay and panel windows
final class ChoreographerController {

    private static let lastSceneIdKey = "choreographer.lastSceneId"

    private var overlayWindow: ChoreographerOverlayWindow?
    private var panelController: ChoreographerPanelController?
    private var viewModel: ChoreographerViewModel?
    private var placingCancellable: AnyCancellable?
    private var sceneCancellable: AnyCancellable?
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
        self.viewModel = vm

        // Track scene changes to persist last opened scene
        sceneCancellable = vm.$currentScene.sink { [weak self] scene in
            self?.persistLastSceneId(scene.id)
        }

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

        // Keep panel above overlay during placement so it stays interactive
        placingCancellable = vm.$isPlacing.sink { [weak panel, weak overlay] isPlacing in
            panel?.setAboveOverlay(isPlacing)
            if isPlacing {
                overlay?.makeKey()
            }
        }
    }

    func close() {
        placingCancellable?.cancel()
        placingCancellable = nil
        sceneCancellable?.cancel()
        sceneCancellable = nil
        viewModel?.isPlacing = false
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
            persistLastSceneId(scene.id)
            print("Scene saved: \(scene.name)")
            // Notify app to reload scenes into scheduler
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.reloadScenes()
            }
        } catch {
            print("Failed to save scene: \(error)")
        }
    }

    private func persistLastSceneId(_ id: String) {
        UserDefaults.standard.set(id, forKey: Self.lastSceneIdKey)
    }
}
