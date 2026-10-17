import CarPlay

/// The CarPlay scene. It shares ``AppModel/shared`` with the phone UI, which may never have been opened.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interface: CarPlayInterface?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        interface = CarPlayInterface(appModel: .shared, interfaceController: interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        interface?.invalidate()
        interface = nil
        guard let player = AppModel.shared.session?.player else { return }
        Task { await player.saveQueue() }
    }
}
