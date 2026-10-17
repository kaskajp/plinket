import CarPlay

/// Shows the library while signed in and a sign-in prompt otherwise, following the shared session.
@MainActor
final class CarPlayInterface {
    private let interfaceController: CPInterfaceController
    private var browser: CarPlayLibraryBrowser?
    private var sessionObservation: Task<Void, Never>?

    init(appModel: AppModel, interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        sessionObservation = observeChanges(of: { appModel.session?.id }) { [weak self] _ in
            self?.show(appModel.session)
        }
    }

    func invalidate() {
        sessionObservation?.cancel()
        browser?.invalidate()
        browser = nil
    }

    private func show(_ session: SignedInSession?) {
        browser?.invalidate()
        guard let session else {
            browser = nil
            interfaceController.setRootTemplate(Self.signInPrompt(), animated: true, completion: nil)
            return
        }
        let browser = CarPlayLibraryBrowser(session: session, interfaceController: interfaceController)
        self.browser = browser
        interfaceController.setRootTemplate(browser.rootTemplate, animated: true, completion: nil)
    }

    /// Audio apps may not use information templates, so an empty list carries the message.
    private static func signInPrompt() -> CPListTemplate {
        let template = CPListTemplate(title: String(localized: "Plinket"), sections: [])
        template.emptyViewTitleVariants = [String(localized: "Not Signed In")]
        template.emptyViewSubtitleVariants = [String(localized: "Open Plinket on your iPhone and sign in to your server.")]
        return template
    }
}
