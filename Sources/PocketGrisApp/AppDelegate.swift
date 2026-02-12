import AppKit
import PocketGrisCore

final class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var statusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Pocket Gris")
            button.image?.isTemplate = true
        }
        return item
    }()
    private var creatureWindow: CreatureWindow?
    private let spriteLoader = SpriteLoader()
    private let scheduler = BehaviorScheduler()
    private let ipcService = IPCService()
    private let windowTracker = AccessibilityWindowTracker()
    private let cursorTracker = GlobalCursorTracker()
    private var isEnabled = true
    private var scenesEnabled = true
    private let settingsWindowController = SettingsWindowController()
    private let sceneStorage = SceneStorage()
    private let scenePlayer = ScenePlayer()
    private var choreographerController: ChoreographerController?
    private var scenesSubmenu: NSMenu?
    private var behaviorsSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupIPC()
        loadCreatures()
        loadScenes()
        startScheduler()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ipcService.stopListening()
        ipcService.markGUIRunning(false)
        scheduler.stop()
        scenePlayer.cancel()
        choreographerController?.close()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let menu = NSMenu()
        menu.autoenablesItems = false  // Prevents hover lag from automatic enable/disable checks

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem(title: "Trigger Random", action: #selector(triggerNow), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())

        // Behaviors submenu
        let behaviorsItem = NSMenuItem(title: "Behaviors", action: nil, keyEquivalent: "")
        behaviorsSubmenu = NSMenu()
        behaviorsItem.submenu = behaviorsSubmenu
        menu.addItem(behaviorsItem)
        rebuildBehaviorsSubmenu()

        // Scenes submenu
        let scenesItem = NSMenuItem(title: "Scenes", action: nil, keyEquivalent: "")
        scenesSubmenu = NSMenu()
        scenesItem.submenu = scenesSubmenu
        menu.addItem(scenesItem)
        rebuildScenesSubmenu()

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))

        let choreoItem = NSMenuItem(title: "Choreographer...", action: #selector(openChoreographer), keyEquivalent: "C")
        choreoItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(choreoItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func rebuildBehaviorsSubmenu() {
        guard let submenu = behaviorsSubmenu else { return }
        submenu.removeAllItems()
        submenu.autoenablesItems = false

        // List all behaviors except .scene (scenes have their own submenu)
        for behaviorType in BehaviorType.allCases where behaviorType != .scene {
            let displayName = behaviorDisplayName(behaviorType)
            let item = NSMenuItem(title: displayName, action: #selector(previewBehavior(_:)), keyEquivalent: "")
            item.representedObject = behaviorType
            submenu.addItem(item)
        }
    }

    private func behaviorDisplayName(_ type: BehaviorType) -> String {
        switch type {
        case .peek: return "Peek"
        case .traverse: return "Traverse"
        case .stationary: return "Stationary"
        case .climber: return "Climber"
        case .cursorReactive: return "Follow Cursor"
        case .scene: return "Scene"
        }
    }

    @objc private func previewBehavior(_ sender: NSMenuItem) {
        guard let behaviorType = sender.representedObject as? BehaviorType else { return }

        // Pick first enabled creature, or fallback to any available creature
        let settings = Settings.load()
        let creatures = spriteLoader.allCreatures()
        let creature: Creature?

        if settings.enabledCreatures.isEmpty {
            // Empty set means all creatures are enabled, pick the first
            creature = creatures.first
        } else {
            // Pick first enabled creature
            creature = creatures.first { settings.enabledCreatures.contains($0.id) } ?? creatures.first
        }

        if let creature = creature {
            showCreature(creature, behavior: behaviorType)
        }
    }

    private func rebuildScenesSubmenu() {
        guard let submenu = scenesSubmenu else { return }
        submenu.removeAllItems()
        submenu.autoenablesItems = false

        // Global toggle for scenes
        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleScenesEnabled), keyEquivalent: "")
        toggleItem.state = scenesEnabled ? .on : .off
        submenu.addItem(toggleItem)
        submenu.addItem(NSMenuItem.separator())

        // List all scenes
        let scenes = sceneStorage.loadAll()
        if scenes.isEmpty {
            let emptyItem = NSMenuItem(title: "No scenes", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        } else {
            for scene in scenes {
                let sceneItem = NSMenuItem(title: scene.name, action: nil, keyEquivalent: "")

                // Create submenu for each scene with Preview and Delete options
                let sceneActions = NSMenu()
                sceneActions.autoenablesItems = false

                let previewItem = NSMenuItem(title: "Preview", action: #selector(previewScene(_:)), keyEquivalent: "")
                previewItem.representedObject = scene
                previewItem.isEnabled = scene.isPlayable
                sceneActions.addItem(previewItem)

                let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteScene(_:)), keyEquivalent: "")
                deleteItem.representedObject = scene
                sceneActions.addItem(deleteItem)

                sceneItem.submenu = sceneActions
                submenu.addItem(sceneItem)
            }
        }
    }

    @objc private func toggleScenesEnabled() {
        scenesEnabled.toggle()

        var settings = Settings.load()
        settings.scenesEnabled = scenesEnabled
        try? settings.save()
        scheduler.updateSettings(settings)

        rebuildScenesSubmenu()
    }

    @objc private func previewScene(_ sender: NSMenuItem) {
        guard let scene = sender.representedObject as? Scene else { return }
        playScene(scene)
    }

    @objc private func deleteScene(_ sender: NSMenuItem) {
        guard let scene = sender.representedObject as? Scene else { return }

        // Show confirmation alert
        let alert = NSAlert()
        alert.messageText = "Delete Scene"
        alert.informativeText = "Are you sure you want to delete \"\(scene.name)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try sceneStorage.delete(id: scene.id)
                loadScenes()  // Refresh scheduler's scene list
                rebuildScenesSubmenu()
            } catch {
                print("Failed to delete scene: \(error)")
            }
        }
    }

    @objc private func triggerNow() {
        scheduler.triggerNow()
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        updateMenuState()

        var settings = Settings.load()
        settings.enabled = isEnabled
        try? settings.save()
        scheduler.updateSettings(settings)
    }

    @objc private func openSettings() {
        let creatures = spriteLoader.allCreatures()
        settingsWindowController.show(
            creatures: creatures,
            sceneStorage: sceneStorage,
            onTestBehavior: { [weak self] creature, behavior in
                if let creature = creature {
                    let behaviorType = behavior ?? .peek
                    self?.showCreature(creature, behavior: behaviorType)
                } else {
                    self?.scheduler.triggerNow()
                }
            },
            onPreviewScene: { [weak self] scene in
                self?.playScene(scene)
            },
            onSettingsChanged: { [weak self] settings in
                self?.scheduler.updateSettings(settings)
                // Reload scenes menu in case scenes were deleted
                self?.loadScenes()
            }
        )
    }

    @objc private func openChoreographer() {
        if choreographerController == nil {
            choreographerController = ChoreographerController(
                spriteLoader: spriteLoader,
                sceneStorage: sceneStorage,
                scenePlayer: scenePlayer,
                windowTracker: windowTracker,
                cursorTracker: cursorTracker
            )
        }
        choreographerController?.open()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateMenuState() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items where item.action == #selector(toggleEnabled) {
            item.state = isEnabled ? .on : .off
        }
    }

    // MARK: - IPC

    private func setupIPC() {
        ipcService.markGUIRunning(true)
        ipcService.startListening { [weak self] message in
            self?.handleIPCMessage(message) ?? IPCResponse(success: false, message: "App not ready")
        }
    }

    private func handleIPCMessage(_ message: IPCMessage) -> IPCResponse {
        switch message.command {
        case .trigger:
            DispatchQueue.main.async { [weak self] in
                if let creatureId = message.creature,
                   let creature = self?.spriteLoader.creature(id: creatureId) {
                    let behavior = message.behavior.flatMap { BehaviorType(rawValue: $0) }
                    self?.scheduler.triggerNow(creature: creature, behavior: behavior)
                } else {
                    self?.scheduler.triggerNow()
                }
            }
            return IPCResponse(success: true, message: "Triggered")

        case .enable:
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = true
                self?.updateMenuState()
                var settings = Settings.load()
                settings.enabled = true
                try? settings.save()
                self?.scheduler.updateSettings(settings)
            }
            return IPCResponse(success: true, message: "Enabled")

        case .disable:
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = false
                self?.updateMenuState()
                var settings = Settings.load()
                settings.enabled = false
                try? settings.save()
                self?.scheduler.updateSettings(settings)
            }
            return IPCResponse(success: true, message: "Disabled")

        case .cancel:
            DispatchQueue.main.async { [weak self] in
                self?.creatureWindow?.close()
                self?.creatureWindow = nil
                self?.scenePlayer.cancel()
            }
            return IPCResponse(success: true, message: "Cancelled")

        case .status:
            let creatures = spriteLoader.allCreatures()
            return IPCResponse(
                success: true,
                message: nil,
                data: [
                    "enabled": String(isEnabled),
                    "creatures": String(creatures.count),
                    "windowVisible": String(creatureWindow != nil),
                    "sceneActive": String(scenePlayer.isActive)
                ]
            )
        }
    }

    // MARK: - Creatures & Scenes

    private func loadCreatures() {
        let creatures = spriteLoader.loadAllCreatures()
        scheduler.updateCreatures(creatures)
        print("Loaded \(creatures.count) creatures")

        if creatures.isEmpty {
            print("No creatures found in Resources/Sprites/")
            print("Add sprite folders with creature.json manifests")
        }
    }

    private func loadScenes() {
        let scenes = sceneStorage.loadAll()
        scheduler.updateScenes(scenes)
        if !scenes.isEmpty {
            print("Loaded \(scenes.count) scenes")
        }
    }

    func reloadScenes() {
        loadScenes()
        rebuildScenesSubmenu()
    }

    private func startScheduler() {
        let settings = Settings.load()
        scheduler.updateSettings(settings)
        isEnabled = settings.enabled
        scenesEnabled = settings.scenesEnabled

        scheduler.setUnifiedTriggerHandler { [weak self] trigger in
            switch trigger {
            case .behavior(let creature, let behaviorType):
                self?.showCreature(creature, behavior: behaviorType)
            case .scene(let scene):
                self?.playScene(scene)
            }
        }

        scheduler.start()
    }

    private func showCreature(_ creature: Creature, behavior behaviorType: BehaviorType) {
        guard isEnabled else { return }

        // Close any existing window
        creatureWindow?.close()

        // Pick a random screen for multi-monitor support
        let screens = NSScreen.screens
        let targetScreen = screens.isEmpty ? nil : screens[Int.random(in: 0..<screens.count)]

        // Create and show new creature window
        let window = CreatureWindow(screen: targetScreen)
        window.show(
            creature: creature,
            behavior: behaviorType,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        ) { [weak self] in
            self?.creatureWindow = nil
        }
        creatureWindow = window
    }

    private func playScene(_ scene: Scene) {
        guard isEnabled else { return }

        // Close any existing single-creature window
        creatureWindow?.close()
        creatureWindow = nil

        scenePlayer.play(
            scene: scene,
            spriteLoader: spriteLoader,
            windowTracker: windowTracker,
            cursorTracker: cursorTracker
        ) {
            // Scene completed
        }
    }
}
