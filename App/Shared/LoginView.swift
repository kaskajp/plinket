import SwiftUI

/// Collects server address and credentials, and signs in once the server accepts them.
struct LoginView: View {
    private enum Field: Hashable {
        case serverAddress, username, password
    }

    @Environment(AppModel.self) private var appModel
    @State private var serverAddress = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    var body: some View {
        // Header and button live in the section's header and footer: macOS forms ignore clear row backgrounds.
        Form {
            Section {
                TextField("Server", text: $serverAddress, prompt: Text("Server address"))
                    .serverAddressInput()
                    .focused($focusedField, equals: .serverAddress)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
                TextField("Username", text: $username, prompt: Text("Username"))
                    .textContentType(.username)
                    .credentialInput()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                SecureField("Password", text: $password, prompt: Text("Password"))
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            } header: {
                LoginHeader()
                    .frame(maxWidth: .infinity)
            } footer: {
                VStack(spacing: 24) {
                    LoginFooter(errorMessage: errorMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SignInButton(isSigningIn: isSigningIn, isEnabled: canSubmit, action: signIn)
                }
            }
            .labelsHidden()
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        #if os(macOS)
        // A grouped form scrolls instead of growing, so keep the window tall enough to show all of it.
        .frame(minHeight: Self.minimumMacHeight)
        #endif
    }

    #if os(macOS)
    private static var minimumMacHeight: CGFloat { 560 }
    #endif

    private var canSubmit: Bool {
        !isSigningIn && !serverAddress.isEmpty && !username.isEmpty && !password.isEmpty
    }

    private func signIn() {
        guard canSubmit else { return }
        isSigningIn = true
        errorMessage = nil
        focusedField = nil
        Task {
            defer { isSigningIn = false }
            do {
                try await appModel.signIn(serverAddress: serverAddress, username: username, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct LoginHeader: View {
    private let logoSize: CGFloat = 96

    var body: some View {
        VStack(spacing: 12) {
            AppLogo(size: logoSize)
            Text("Plinket")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.primary)
            Text("Sign in to your Navidrome server")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 24)
    }
}

private struct LoginFooter: View {
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else {
            Text("For example music.example.com or 192.168.1.10:4533")
        }
    }
}

private struct SignInButton: View {
    let isSigningIn: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text("Sign In")
                    .opacity(isSigningIn ? 0 : 1)
                ProgressView()
                    .opacity(isSigningIn ? 1 : 0)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

private extension View {
    func serverAddressInput() -> some View {
        #if os(iOS)
        credentialInput()
            .keyboardType(.URL)
            .textContentType(.URL)
        #else
        credentialInput()
        #endif
    }

    func credentialInput() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }
}
